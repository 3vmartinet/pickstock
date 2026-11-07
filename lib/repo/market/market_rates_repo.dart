import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pickstock/data/valuation/discount_rate.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/extensions/object_extensions.dart';
import 'package:pickstock/repo/quote/finnhub_quote_repo.dart';

/// The two figures a required return needs that SEC filings do not carry.
///
/// A company's own cost of equity cannot be read out of its filings: it turns
/// on what government bonds pay and on how the share moves against the market,
/// neither of which is anything a filer reports. Both are published elsewhere,
/// and this is where the app goes to get them.
abstract interface class MarketRatesRepo {
  /// Whether a rate could be built at all. False leaves the report on its
  /// assumed rate rather than showing a computed one it cannot compute.
  bool get isConfigured;

  /// The required return for [ticker], or `null` where either figure is out of
  /// reach — no key, no network, or a symbol the provider does not cover.
  Future<DiscountRate?> rateFor(String ticker);

  /// The rate for [ticker] if both its figures are already held, without
  /// asking anyone for them. For callers pricing many companies at once, who
  /// cannot afford a second request per company and would rather fall back to
  /// the assumed rate than wait for one.
  DiscountRate? cachedRateFor(String ticker);
}

const String _treasuryHost = 'home.treasury.gov';
const String _treasuryPath =
    '/resource-center/data-chart-center/interest-rates/daily-treasury-rates.csv/'
    '{year}/all';

/// The column carrying the ten-year yield, which is the maturity a valuation
/// over a ten-year horizon is measured against.
const String _tenYearColumn = '10 Yr';

const String _metricHost = 'finnhub.io';
const String _metricPath = '/api/v1/stock/metric';
const String _betaKey = 'beta';

/// Long enough that the app is not asking twice for a figure published once a
/// day, short enough that a session left open overnight picks up the new one.
const Duration _yieldFreshness = Duration(hours: 6);

/// A beta is a regression over years of prices. It does not move by lunchtime,
/// nor much in a week — and kept that long, a list priced on every launch
/// does not spend a request per company each time to learn the same figure.
const Duration _betaFreshness = Duration(days: 7);

/// Where the figures are kept between launches, in the settings table.
const String _betaKeyPrefix = 'marketRates.beta.';
const String _yieldKey = 'marketRates.tenYear';

const Duration _requestTimeout = Duration(seconds: 12);

/// Reads the yield off the US Treasury's own daily publication and the beta
/// off Finnhub.
///
/// Kept between launches, each with the time it was read and held to the
/// same freshness as in memory: without them, every launch began with no
/// company's own rate, so the list judged every company on the assumed one
/// and then changed its mind about any company the reader opened, once the
/// report had fetched the real rate. A session that cannot reach either
/// source simply has no computed rate, and the report says so.
class LiveMarketRatesRepo implements MarketRatesRepo {
  LiveMarketRatesRepo({
    http.Client? client,
    String apiKey = finnhubApiKey,
    AppDatabase? database,
  }) : _client = client ?? http.Client(),
       // ignore: prefer_initializing_formals
       _apiKey = apiKey,
       // ignore: prefer_initializing_formals
       _database = database;

  final http.Client _client;
  final String _apiKey;

  /// Where the figures are kept between launches, or `null` to keep them for
  /// the session only.
  final AppDatabase? _database;

  /// The kept figures, read in once, before the first rate is asked for.
  late final Future<void> _restored = _restore();

  Future<void> _restore() async {
    final database = _database;
    if (database == null) return;
    try {
      final kept = await database.allSettings();
      for (final MapEntry(:key, :value) in kept.entries) {
        if (key == _yieldKey) {
          final parts = value.split('@');
          final percent = double.tryParse(parts.first);
          final asOf = int.tryParse(parts.elementAtOrNull(1) ?? '');
          final read = int.tryParse(parts.elementAtOrNull(2) ?? '');
          if (percent == null || asOf == null || read == null) continue;
          _yield ??= (
            percent: percent,
            asOf: DateTime.fromMillisecondsSinceEpoch(asOf, isUtc: true),
            read: DateTime.fromMillisecondsSinceEpoch(read),
          );
        } else if (key.startsWith(_betaKeyPrefix)) {
          final parts = value.split('@');
          final beta = double.tryParse(parts.first);
          final read = int.tryParse(parts.elementAtOrNull(1) ?? '');
          if (beta == null || read == null) continue;
          _betas.putIfAbsent(
            key.substring(_betaKeyPrefix.length),
            () => (beta: beta, read: DateTime.fromMillisecondsSinceEpoch(read)),
          );
        }
      }
    } on Object catch (error) {
      logWarning(() => 'Kept market rates unreadable: $error');
    }
  }

  void _keep(String key, String value) {
    final database = _database;
    if (database == null) return;
    unawaited(
      database.saveSetting(key, value).catchError((Object error) {
        logWarning(() => 'Could not keep $key: $error');
      }),
    );
  }

  /// Reads the kept figures in now, so [cachedRateFor] can answer from the
  /// first frame.
  Future<void> restore() => _restored;

  ({double percent, DateTime asOf, DateTime read})? _yield;
  final Map<String, ({double beta, DateTime read})> _betas = {};

  @override
  bool get isConfigured => _apiKey.isNotEmpty;

  @override
  Future<DiscountRate?> rateFor(String ticker) async {
    if (!isConfigured) return null;
    await _restored;
    // Asked for together: neither is any use without the other, and failing
    // early costs nothing since both are cached.
    final treasury = await _riskFreeRate();
    if (treasury == null) return null;
    final beta = await _betaFor(ticker);
    if (beta == null) return null;

    return DiscountRate(
      riskFreePercent: treasury.percent,
      beta: beta,
      asOf: treasury.asOf,
    );
  }

  /// The newest ten-year yield the Treasury has published this year.
  Future<({double percent, DateTime asOf})?> _riskFreeRate() async {
    final held = _yield;
    if (held != null &&
        DateTime.now().difference(held.read) < _yieldFreshness) {
      return (percent: held.percent, asOf: held.asOf);
    }

    final year = DateTime.now().year;
    final uri = Uri.https(
      _treasuryHost,
      _treasuryPath.replaceFirst('{year}', '$year'),
      {'type': 'daily_treasury_yield_curve', '_format': 'csv'},
    );

    try {
      final response = await _client.get(uri).timeout(_requestTimeout);
      if (response.statusCode != 200) return null;
      final parsed = _parseYieldCurve(response.body);
      if (parsed == null) return null;
      final read = DateTime.now();
      _yield = (percent: parsed.percent, asOf: parsed.asOf, read: read);
      _keep(
        _yieldKey,
        '${parsed.percent}@${parsed.asOf.millisecondsSinceEpoch}'
        '@${read.millisecondsSinceEpoch}',
      );
      return parsed;
    } on Object catch (error) {
      logWarning(() => 'Treasury yield unavailable: $error');
      return null;
    }
  }

  /// The newest row of the daily curve, by date rather than by position: the
  /// file is published newest-first today, and nothing says it must stay that
  /// way.
  static ({double percent, DateTime asOf})? _parseYieldCurve(String csv) {
    final lines = const LineSplitter().convert(csv);
    if (lines.length < 2) return null;

    final headers = _splitRow(lines.first);
    final column = headers.indexWhere((name) => name.contains(_tenYearColumn));
    if (column < 0) return null;

    ({double percent, DateTime asOf})? newest;
    for (final line in lines.skip(1)) {
      final cells = _splitRow(line);
      if (cells.length <= column) continue;
      final date = _parseDate(cells.first);
      final percent = double.tryParse(cells[column]);
      if (date == null || percent == null) continue;
      if (newest == null || date.isAfter(newest.asOf)) {
        newest = (percent: percent, asOf: date);
      }
    }
    return newest;
  }

  /// Splits a CSV row, honouring the quotes the Treasury puts around headers
  /// that contain a space.
  static List<String> _splitRow(String line) {
    final cells = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    for (final rune in line.runes) {
      final character = String.fromCharCode(rune);
      if (character == '"') {
        quoted = !quoted;
      } else if (character == ',' && !quoted) {
        cells.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(character);
      }
    }
    cells.add(buffer.toString().trim());
    return cells;
  }

  /// The Treasury dates its rows `MM/DD/YYYY`, which `DateTime.parse` will
  /// not take.
  static DateTime? _parseDate(String value) {
    final parts = value.split('/');
    if (parts.length != 3) return null;
    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (month == null || day == null || year == null) return null;
    return DateTime.utc(year, month, day);
  }

  @override
  DiscountRate? cachedRateFor(String ticker) {
    final now = DateTime.now();
    final treasury = _yield;
    final beta = _betas[ticker.toUpperCase()];
    if (treasury == null ||
        beta == null ||
        now.difference(treasury.read) >= _yieldFreshness ||
        now.difference(beta.read) >= _betaFreshness) {
      return null;
    }
    return DiscountRate(
      riskFreePercent: treasury.percent,
      beta: beta.beta,
      asOf: treasury.asOf,
    );
  }

  Future<double?> _betaFor(String ticker) async {
    final symbol = ticker.toUpperCase();
    final held = _betas[symbol];
    if (held != null && DateTime.now().difference(held.read) < _betaFreshness) {
      return held.beta;
    }

    final uri = Uri.https(_metricHost, _metricPath, {
      'symbol': symbol,
      'metric': 'all',
      'token': _apiKey,
    });

    try {
      final response = await _client.get(uri).timeout(_requestTimeout);
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;
      final metric = body['metric'];
      final beta = metric is Map<String, dynamic> ? metric[_betaKey] : null;
      if (beta is! num || beta <= 0) return null;
      final read = DateTime.now();
      _betas[symbol] = (beta: beta.toDouble(), read: read);
      _keep('$_betaKeyPrefix$symbol', '$beta@${read.millisecondsSinceEpoch}');
      return beta.toDouble();
    } on Object catch (error) {
      logWarning(() => 'Beta for $symbol unavailable: $error');
      return null;
    }
  }
}

/// Answers nothing, for builds with no key and for tests that must not reach
/// the network.
class UnavailableMarketRatesRepo implements MarketRatesRepo {
  const UnavailableMarketRatesRepo();

  @override
  bool get isConfigured => false;

  @override
  Future<DiscountRate?> rateFor(String ticker) async => null;

  @override
  DiscountRate? cachedRateFor(String ticker) => null;
}
