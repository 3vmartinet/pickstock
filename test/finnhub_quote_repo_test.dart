import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/repo/quote/finnhub_quote_repo.dart';

/// The shape Finnhub's `/quote` actually returns, confirmed against the live
/// endpoint: current price in `c`, exchange timestamp in `t`.
String _quoteBody({required double price, int? timestamp}) => jsonEncode({
  'c': price,
  'd': 2.09,
  'dp': 0.96,
  'h': 220.6,
  'l': 216.21,
  'o': 218.8,
  'pc': 217.55,
  't': timestamp ?? 1788199438,
});

FinnhubQuoteRepo _repo(MockClient client, {String apiKey = 'test-key'}) =>
    FinnhubQuoteRepo(client: client, apiKey: apiKey);

void main() {
  test('reads the price and the exchange timestamp', () async {
    final repo = _repo(
      MockClient((_) async => http.Response(_quoteBody(price: 219.64), 200)),
    );

    final quote = await repo.quoteFor('NVDA');

    expect(quote.pricePerShare, 219.64);
    expect(quote.isQuoted, isTrue);
    expect(quote.asOf, DateTime.fromMillisecondsSinceEpoch(1788199438 * 1000));
  });

  test('spells share classes the way the provider does', () async {
    late Uri asked;
    final repo = _repo(
      MockClient((request) async {
        asked = request.url;
        return http.Response(_quoteBody(price: 755710.01), 200);
      }),
    );

    await repo.quoteFor('BRK-A');

    // EDGAR writes BRK-A, Finnhub quotes BRK.A and returns nothing for the
    // hyphenated form.
    expect(asked.queryParameters['symbol'], 'BRK.A');
    expect(FinnhubQuoteRepo.providerSymbol('brk-b'), 'BRK.B');
  });

  test('keeps the key out of the path and in the query', () async {
    late Uri asked;
    final repo = _repo(
      MockClient((request) async {
        asked = request.url;
        return http.Response(_quoteBody(price: 100), 200);
      }),
      apiKey: 'secret',
    );

    await repo.quoteFor('AAPL');

    expect(asked.host, 'finnhub.io');
    expect(asked.path, '/api/v1/quote');
    expect(asked.queryParameters['token'], 'secret');
  });

  test('reads a price of zero as no coverage, not as free', () async {
    // What Finnhub returns for an OTC or delisted symbol, verified live.
    final repo = _repo(
      MockClient(
        (_) async => http.Response(
          jsonEncode({'c': 0, 'd': null, 'dp': null, 't': 0}),
          200,
        ),
      ),
    );

    await expectLater(
      repo.quoteFor('ITXP'),
      throwsA(
        isA<QuoteException>().having(
          (error) => error.failure,
          'failure',
          QuoteFailure.noCoverage,
        ),
      ),
    );
  });

  test('reports the provider turning it away', () async {
    final tooMany = _repo(MockClient((_) async => http.Response('', 429)));
    await expectLater(
      tooMany.quoteFor('AAPL'),
      throwsA(
        isA<QuoteException>().having(
          (error) => error.failure,
          'failure',
          QuoteFailure.rateLimited,
        ),
      ),
    );

    final refused = _repo(MockClient((_) async => http.Response('', 401)));
    await expectLater(
      refused.quoteFor('AAPL'),
      throwsA(
        isA<QuoteException>().having(
          (error) => error.failure,
          'failure',
          QuoteFailure.service,
        ),
      ),
    );
  });

  test('reports an unreachable provider as a network failure', () async {
    final repo = _repo(
      MockClient((_) async => throw http.ClientException('offline')),
    );

    await expectLater(
      repo.quoteFor('AAPL'),
      throwsA(
        isA<QuoteException>().having(
          (error) => error.failure,
          'failure',
          QuoteFailure.network,
        ),
      ),
    );
  });

  test('asks for nothing without a key', () async {
    var asked = false;
    final repo = _repo(
      MockClient((_) async {
        asked = true;
        return http.Response(_quoteBody(price: 100), 200);
      }),
      apiKey: '',
    );

    expect(repo.isConfigured, isFalse);
    await expectLater(
      repo.quoteFor('AAPL'),
      throwsA(
        isA<QuoteException>().having(
          (error) => error.failure,
          'failure',
          QuoteFailure.notConfigured,
        ),
      ),
    );
    expect(asked, isFalse);
  });

  test('stops itself before the provider has to', () async {
    // Finnhub's free tier allows 60 calls a minute and answers 429 beyond it,
    // so the budget is spent locally rather than by being refused.
    var calls = 0;
    final repo = _repo(
      MockClient((_) async {
        calls++;
        return http.Response(_quoteBody(price: 100), 200);
      }),
    );

    var refusals = 0;
    for (var attempt = 0; attempt < 70; attempt++) {
      try {
        await repo.quoteFor('AAPL');
      } on QuoteException catch (error) {
        expect(error.failure, QuoteFailure.rateLimited);
        refusals++;
      }
    }

    expect(calls, lessThan(60));
    expect(refusals, greaterThan(0));
    expect(calls + refusals, 70);
  });
}
