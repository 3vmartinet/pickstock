import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pickstock/extensions/object_extensions.dart';

/// Supplied at build time with `--dart-define-from-file=env.json`, like the
/// Finnhub key. Empty by default, which leaves bulk prices off.
const String massiveApiKey = String.fromEnvironment('MASSIVE_API_KEY');

const String _host = 'api.massive.com';
const String _groupedPath = '/v2/aggs/grouped/locale/us/market/stocks/';
const Duration _requestTimeout = Duration(seconds: 30);

/// How many days back from yesterday to look for the last trading day. A
/// weekend and a Monday holiday are three; a fourth is a margin, and the free
/// plan allows five requests a minute.
const int _daysTried = 4;

/// Every US stock's closing price on one trading day.
class BulkPrices {
  const BulkPrices({required this.tradingDay, required this.closeBySymbol});

  /// The day the closes are from, as a UTC date.
  final DateTime tradingDay;

  /// Closing price by the provider's own symbol.
  final Map<String, double> closeBySymbol;
}

/// The one request that prices the whole directory.
///
/// A quote a company at a time is what Finnhub offers for free, and at sixty
/// a minute that is forty minutes for the directory. An end-of-day price for
/// every US stock in one request is what Massive's free plan offers, and it
/// is what makes a verdict on every tile, a sort by upside across the whole
/// directory and a scan that finishes in seconds possible at all. The report
/// still asks Finnhub for a live price when a company is opened; this fills
/// in everything the reader has not opened.
abstract interface class BulkPriceRepo {
  /// Whether a key was built in.
  bool get isConfigured;

  /// Every close from the most recent trading day the provider will serve,
  /// or `null` where none could be had — no key, no network, the budget
  /// spent, or no trading day found within reach.
  Future<BulkPrices?> fetchLatest();
}

/// Reads Massive's grouped daily bars.
///
/// On the free plan a day's bars are served only after midnight Eastern, so
/// the request starts from yesterday (Eastern) and walks back until it finds
/// a day with bars: a 403 is a day the plan will not serve yet, and an empty
/// day is a weekend or a holiday.
class MassiveBulkPriceRepo implements BulkPriceRepo {
  MassiveBulkPriceRepo({
    http.Client? client,
    String apiKey = massiveApiKey,
    DateTime Function()? now,
  }) : _client = client ?? http.Client(),
       // ignore: prefer_initializing_formals
       _apiKey = apiKey,
       _now = now ?? DateTime.now;

  final http.Client _client;
  final String _apiKey;
  final DateTime Function() _now;

  @override
  bool get isConfigured => _apiKey.isNotEmpty;

  @override
  Future<BulkPrices?> fetchLatest() async {
    if (!isConfigured) return null;
    var day = _yesterdayEastern(_now());
    for (var attempt = 0; attempt < _daysTried; attempt++) {
      final found = await _fetch(day);
      switch (found) {
        case _Day(:final prices?):
          return prices;
        case _Day(prices: null, stop: true):
          return null;
        case _Day():
          day = day.subtract(const Duration(days: 1));
      }
    }
    return null;
  }

  Future<_Day> _fetch(DateTime day) async {
    final uri = Uri.https(_host, '$_groupedPath${_date(day)}', {
      'adjusted': 'true',
      'apiKey': _apiKey,
    });
    try {
      final response = await _client.get(uri).timeout(_requestTimeout);
      switch (response.statusCode) {
        case 200:
          return _Day(prices: _parse(response.body, day));
        // Too early for this day on the free plan: the day before may do.
        case 403:
          return const _Day();
        case 429:
          logWarning(() => 'Bulk prices: the request budget is spent');
          return const _Day(stop: true);
        default:
          logWarning(() => 'Bulk prices: HTTP ${response.statusCode}');
          return const _Day(stop: true);
      }
    } on Object catch (error) {
      logWarning(() => 'Bulk prices unavailable: $error');
      return const _Day(stop: true);
    }
  }

  /// The closes in [body], or `null` for a day with none — a weekend or a
  /// holiday, which the provider answers with an empty result rather than
  /// an error.
  static BulkPrices? _parse(String body, DateTime day) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;
    final results = decoded['results'];
    if (results is! List || results.isEmpty) return null;
    final closes = <String, double>{};
    for (final raw in results) {
      if (raw is! Map<String, dynamic>) continue;
      final symbol = raw['T'];
      final close = raw['c'];
      if (symbol is! String || close is! num || close <= 0) continue;
      closes[symbol.toUpperCase()] = close.toDouble();
    }
    return closes.isEmpty
        ? null
        : BulkPrices(tradingDay: day, closeBySymbol: closes);
  }

  /// The calendar day before today in New York, as a UTC date.
  ///
  /// Eastern is UTC−5 or UTC−4; taking five hours off is right in winter and
  /// an hour early in summer, which only matters in the hour after midnight
  /// and errs towards asking for a day the plan has not released, which the
  /// walk back handles.
  static DateTime _yesterdayEastern(DateTime now) {
    final eastern = now.toUtc().subtract(const Duration(hours: 5));
    return DateTime.utc(
      eastern.year,
      eastern.month,
      eastern.day,
    ).subtract(const Duration(days: 1));
  }

  static String _date(DateTime day) =>
      '${day.year}-${_two(day.month)}-${_two(day.day)}';

  static String _two(int value) => value.toString().padLeft(2, '0');
}

/// One day's answer: bars, nothing for that day, or a reason to stop asking.
class _Day {
  const _Day({this.prices, this.stop = false});

  final BulkPrices? prices;
  final bool stop;
}

/// Answers nothing, for builds with no key and for tests that must not reach
/// the network.
class UnavailableBulkPriceRepo implements BulkPriceRepo {
  const UnavailableBulkPriceRepo();

  @override
  bool get isConfigured => false;

  @override
  Future<BulkPrices?> fetchLatest() async => null;
}
