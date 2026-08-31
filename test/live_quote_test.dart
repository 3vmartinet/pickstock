import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/repo/quote/finnhub_quote_repo.dart';

/// Hits Finnhub for real, to prove the key reaches the app and the endpoint
/// still answers the shape the parser expects.
///
/// Skipped unless a key is built in, so the suite stays offline by default:
///
/// ```sh
/// fvm flutter test --dart-define-from-file=env.json test/live_quote_test.dart
/// ```
/// Skipped rather than silently absent, so a run without a key says so.
final Object? _skip = finnhubApiKey.isEmpty
    ? 'no FINNHUB_API_KEY built in; pass --dart-define-from-file=env.json'
    : null;

void main() {
  test('quotes a real symbol with the configured key', () async {
    final repo = FinnhubQuoteRepo();
    expect(repo.isConfigured, isTrue);

    final quote = await repo.quoteFor('AAPL');

    expect(quote.pricePerShare, greaterThan(0));
    expect(quote.isQuoted, isTrue);
    // A real exchange timestamp, not the fallback of "now".
    expect(quote.asOf.isBefore(DateTime.now()), isTrue);
    expect(
      quote.asOf.isAfter(DateTime.now().subtract(const Duration(days: 7))),
      isTrue,
    );
  }, skip: _skip);

  test('reports a symbol the provider does not cover', () async {
    // A hyphenated class share is translated; an OTC shell is not covered.
    await expectLater(
      FinnhubQuoteRepo().quoteFor('ITXP'),
      throwsA(
        isA<QuoteException>().having(
          (error) => error.failure,
          'failure',
          QuoteFailure.noCoverage,
        ),
      ),
    );
  }, skip: _skip);
}
