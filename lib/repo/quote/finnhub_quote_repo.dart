import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/extensions/object_extensions.dart';
import 'package:pickstock/repo/quote/quote_repo.dart';

/// Supplied at build time with `--dart-define-from-file=env.json`, so the key
/// never enters the repository. Empty by default, which leaves quotes off.
const String finnhubApiKey = String.fromEnvironment('FINNHUB_API_KEY');

const String _quoteHost = 'finnhub.io';
const String _quotePath = '/api/v1/quote';
const String _symbolParameter = 'symbol';
const String _tokenParameter = 'token';

/// Finnhub's current-price field, and the exchange timestamp beside it.
const String _priceKey = 'c';
const String _timestampKey = 't';

/// Finnhub's free tier, confirmed against the `x-ratelimit-limit` header it
/// returns. Exceeding it answers 429, so the budget is tracked locally and the
/// request is refused before it is made rather than after.
const int _callsPerWindow = 60;
const Duration _window = Duration(minutes: 1);

/// A margin left unspent, so a burst of report views cannot leave the user
/// locked out of the next one.
const int _reservedCalls = 5;

class FinnhubQuoteRepo implements QuoteRepo {
  FinnhubQuoteRepo({http.Client? client, String apiKey = finnhubApiKey})
    : _client = client ?? http.Client(),
      // A named parameter cannot be private, and the key has no business
      // being readable back off the instance, so the field stays private.
      // ignore: prefer_initializing_formals
      _apiKey = apiKey;

  final http.Client _client;
  final String _apiKey;

  /// When each call in the current window was made, oldest first.
  final List<DateTime> _calls = [];

  @override
  bool get isConfigured => _apiKey.isNotEmpty;

  @override
  Future<Quote> quoteFor(String ticker) async {
    if (!isConfigured) {
      throw const QuoteException(QuoteFailure.notConfigured);
    }
    if (!_claimCall()) {
      logWarning(() => 'Quote budget spent; refusing to ask for $ticker');
      throw const QuoteException(QuoteFailure.rateLimited);
    }

    final uri = Uri.https(_quoteHost, _quotePath, {
      _symbolParameter: providerSymbol(ticker),
      _tokenParameter: _apiKey,
    });

    final http.Response response;
    try {
      response = await _client.get(uri);
    } on Exception catch (error) {
      // Deliberately not logging the URI: it carries the key.
      logWarning(() => 'Quote for $ticker failed: $error');
      throw QuoteException(QuoteFailure.network, cause: error);
    }

    if (response.statusCode == 429) {
      throw const QuoteException(QuoteFailure.rateLimited);
    }
    if (response.statusCode != 200) {
      throw QuoteException(QuoteFailure.service, cause: response.statusCode);
    }

    return _parse(response.body, ticker);
  }

  Quote _parse(String body, String ticker) {
    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(body) as Map<String, dynamic>;
    } on FormatException catch (error) {
      throw QuoteException(QuoteFailure.service, cause: error);
    }

    final price = (payload[_priceKey] as num?)?.toDouble();
    // A symbol Finnhub does not cover comes back as a well-formed quote of
    // zero rather than an error, so zero is read as "no price".
    if (price == null || price <= 0) {
      logInfo(() => 'No quote coverage for $ticker');
      throw const QuoteException(QuoteFailure.noCoverage);
    }

    final seconds = (payload[_timestampKey] as num?)?.toInt();
    return Quote(
      pricePerShare: price,
      asOf: seconds == null || seconds <= 0
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(
              seconds * Duration.millisecondsPerSecond,
            ),
      isQuoted: true,
    );
  }

  /// EDGAR separates share classes with a hyphen (`BRK-A`), Finnhub with a dot
  /// (`BRK.A`). Verified against both: `BRK-A` returns nothing, `BRK.A` quotes.
  static String providerSymbol(String ticker) =>
      ticker.trim().toUpperCase().replaceAll('-', '.');

  /// Takes one call out of the current window's budget, or refuses.
  bool _claimCall() {
    final now = DateTime.now();
    _calls.removeWhere((call) => now.difference(call) >= _window);
    if (_calls.length >= _callsPerWindow - _reservedCalls) return false;
    _calls.add(now);
    return true;
  }
}
