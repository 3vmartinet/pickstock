import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/quote/quote_repo.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';

import 'support/test_directory.dart';

/// A quote source whose replies are held open until the test releases them,
/// which is what a slow provider looks like from here.
class SlowQuoteRepo implements QuoteRepo {
  @override
  bool isConfigured = true;

  final List<String> asked = [];
  final List<Completer<Quote>> pending = [];

  @override
  Future<Quote> quoteFor(String ticker) {
    asked.add(ticker);
    final completer = Completer<Quote>();
    pending.add(completer);
    return completer.future;
  }

  void answer(int index, double price) => pending[index].complete(
    Quote(pricePerShare: price, asOf: DateTime.now(), isQuoted: true),
  );

  void fail(int index, QuoteFailure failure) =>
      pending[index].completeError(QuoteException(failure));
}

/// Lets the awaits inside the view model run.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late AppDatabase database;
  late SlowQuoteRepo quotes;
  late SnapshotViewModel viewModel;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    quotes = SlowQuoteRepo();
    database = await registerTestDependencies(
      withFinancials: true,
      quoteRepo: quotes,
    );
    viewModel = SnapshotViewModel();
  });

  tearDown(() async {
    viewModel.dispose();
    await database.close();
    await GetIt.I.reset();
  });

  test('a slow quote does not hold up the report', () async {
    // The search completes on the filings alone. It used to await the quote,
    // which handed a stalled provider the power to stall the whole screen.
    await viewModel.search('AAPL').timeout(const Duration(seconds: 5));

    expect(viewModel.snapshot?.company.ticker, 'AAPL');
    expect(viewModel.isQuoting, isTrue);
    expect(viewModel.pricePerShare, isNull);
  });

  test('the price lands when the quote finally answers', () async {
    await viewModel.search('AAPL');
    quotes.answer(0, 250);
    await _settle();

    expect(viewModel.pricePerShare, 250);
    expect(viewModel.quote?.isQuoted, isTrue);
    expect(viewModel.isQuoting, isFalse);
  });

  test('switching company mid-request quotes the new one', () async {
    await viewModel.search('AAPL');
    await viewModel.search('NVDA');

    // Both were asked for. A single in-flight flag used to refuse the second,
    // so the company actually on screen never got a price.
    expect(quotes.asked, ['AAPL', 'NVDA']);
    expect(viewModel.isQuoting, isTrue);
  });

  test('a superseded reply does not land on the company on screen', () async {
    await viewModel.search('AAPL');
    await viewModel.search('NVDA');

    quotes.answer(0, 250); // Apple's, arriving late.
    await _settle();
    expect(viewModel.pricePerShare, isNull);

    quotes.answer(1, 200); // NVIDIA's.
    await _settle();
    expect(viewModel.pricePerShare, 200);
  });

  test(
    'the in-flight flag does not outlive the company it belonged to',
    () async {
      await viewModel.search('AAPL');
      await viewModel.search('NVDA');
      quotes.answer(0, 250); // The stale one finishes.
      await _settle();
      quotes.answer(1, 200);
      await _settle();

      expect(viewModel.isQuoting, isFalse);

      // The flag used to stay set for ever once a company was switched
      // mid-request, and every later quote was refused by its own guard. Not
      // awaited: the fake never answers, and a button does not wait either.
      unawaited(viewModel.refreshQuote());
      await _settle();
      expect(quotes.asked, ['AAPL', 'NVDA', 'NVDA']);
    },
  );

  test('a failure clears the flag and says what happened', () async {
    await viewModel.search('AAPL');
    quotes.fail(0, QuoteFailure.timedOut);
    await _settle();

    expect(viewModel.isQuoting, isFalse);
    expect(viewModel.quoteFailure, QuoteFailure.timedOut);
    // Still askable afterwards.
    unawaited(viewModel.refreshQuote());
    await _settle();
    expect(quotes.asked, ['AAPL', 'AAPL']);
  });

  test('one refresh at a time for the company on screen', () async {
    await viewModel.search('AAPL');
    unawaited(viewModel.refreshQuote());
    await _settle();

    // The search already has one in flight; a second is pointless.
    expect(quotes.asked, ['AAPL']);
  });
}
