import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/valuation/valuation_verdict.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/browse/list_valuation_view_model.dart';
import 'package:pickstock/ui/browse/widgets/ticker_grid.dart';
import 'package:pickstock/ui/browse/widgets/verdict_filter.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

const Company _apple = Company(
  cik: '0000320193',
  ticker: 'AAPL',
  name: 'Apple Inc.',
);

const Company _nvidia = Company(
  cik: '0001045810',
  ticker: 'NVDA',
  name: 'NVIDIA CORP',
);

const String _microsoftCik = '0000789019';

const Size _wideSize = Size(1600, 1000);

/// [ticker] on a tile, as opposed to in the report beside the list.
Finder inGrid(String ticker) =>
    find.descendant(of: find.byType(TickerGrid), matching: find.text(ticker));

// The view-model cases use plain `test`: they await real database queries and
// the mock filings' latency, which a widget test's fake clock never lets pass.

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  late AppDatabase database;
  late FakeQuoteRepo quotes;

  setUp(() async {
    // Apple's band is roughly $92 to $132, so $80 is below it.
    quotes = FakeQuoteRepo(isConfigured: true, price: 80);
    database = await registerTestDependencies(
      withFinancials: true,
      quoteRepo: quotes,
    );
  });

  tearDown(() async {
    ListValuationViewModel.isEnabled = false;
    await database.close();
    await GetIt.I.reset();
  });

  /// Polls [condition] until it holds, or for long enough that it plainly
  /// will not.
  Future<void> until(bool Function() condition) async {
    for (var tries = 0; tries < 80 && !condition(); tries++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<BrowseViewModel> loadedBrowse() async {
    final browse = BrowseViewModel();
    addTearDown(browse.dispose);
    await until(() => !browse.isLoadingSamples);
    return browse;
  }

  group('the browse model', () {
    test('narrows to the companies carrying the chosen verdict', () async {
      final browse = await loadedBrowse();
      final everything = browse.resultCount;

      browse
        ..applyVerdicts({
          _apple.cik: ValuationVerdict.undervalued,
          _microsoftCik: ValuationVerdict.overvalued,
        }, 1)
        ..setVerdictFilter(ValuationVerdict.undervalued);

      expect(browse.results.map((company) => company.cik), [_apple.cik]);
      // What the sweep is handed: the list as the other filters leave it.
      expect(browse.verdictCandidates, hasLength(everything));

      browse.setVerdictFilter(ValuationVerdict.overvalued);
      expect(browse.results.map((company) => company.cik), [_microsoftCik]);

      browse.setVerdictFilter(null);
      expect(browse.resultCount, everything);
      expect(browse.verdictCandidates, isEmpty);
    });

    test('takes in new verdicts without handing over a new list', () async {
      final browse = await loadedBrowse();
      browse
        ..applyVerdicts({_apple.cik: ValuationVerdict.undervalued}, 1)
        ..setVerdictFilter(ValuationVerdict.undervalued);
      final candidates = browse.verdictCandidates;

      browse.applyVerdicts({
        _apple.cik: ValuationVerdict.undervalued,
        _nvidia.cik: ValuationVerdict.undervalued,
      }, 2);

      expect(browse.results.map((company) => company.cik), {
        _apple.cik,
        _nvidia.cik,
      });
      // The same list, so the sweep under way is not started over.
      expect(identical(browse.verdictCandidates, candidates), isTrue);
    });

    test('is lifted with the other narrowings', () async {
      final browse = await loadedBrowse();
      browse
        ..applyVerdicts({_apple.cik: ValuationVerdict.undervalued}, 1)
        ..setVerdictFilter(ValuationVerdict.undervalued)
        ..clearNarrowings();

      expect(browse.verdictFilter, isNull);
      expect(browse.resultCount, greaterThan(1));
    });
  });

  group('the sweep', () {
    setUp(() => ListValuationViewModel.isEnabled = true);

    test('prices companies that never came on screen', () async {
      final viewModel = ListValuationViewModel();
      addTearDown(viewModel.dispose);

      viewModel.sweep([_apple, _nvidia]);
      // The first is under way already; the second waits behind it.
      expect(viewModel.sweepRemaining, 1);
      // Waiting in the sweep is not pending: there is no tile to animate.
      expect(viewModel.isPending(_nvidia.cik), isFalse);

      await until(
        () => viewModel.sweepRemaining == 0 && quotes.requested.length == 2,
      );

      expect(quotes.requested, ['AAPL', 'NVDA']);
      expect(viewModel.verdictFor(_apple.cik), ValuationVerdict.undervalued);
    });

    test('skips companies already judged', () async {
      final viewModel = ListValuationViewModel();
      addTearDown(viewModel.dispose);
      viewModel.adopt(_apple.cik, ValuationVerdict.fairlyValued);

      viewModel.sweep([_apple]);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(viewModel.sweepRemaining, 0);
      expect(quotes.requested, isEmpty);
    });

    test('is not started over when handed the same list again', () async {
      final viewModel = ListValuationViewModel();
      addTearDown(viewModel.dispose);
      final candidates = [_apple, _nvidia];

      viewModel.sweep(candidates);
      await until(() => quotes.requested.isNotEmpty);
      // Every rebuild hands it over again.
      viewModel.sweep(candidates);

      expect(viewModel.sweepRemaining, lessThan(2));
    });

    test('stops when the filter is lifted', () async {
      final viewModel = ListValuationViewModel();
      addTearDown(viewModel.dispose);

      viewModel
        ..sweep([_apple, _nvidia])
        ..sweep(const []);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(viewModel.sweepRemaining, 0);
      // Apple was already out when the sweep was lifted; NVIDIA never goes.
      expect(quotes.requested, isNot(contains('NVDA')));
    });
  });

  testWidgets('is not offered without a quote key', (tester) async {
    tester.view
      ..physicalSize = _wideSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // The harness leaves pricing off, which is what no key looks like here.
    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();

    expect(
      find.byKey(verdictFilterKey(ValuationVerdict.undervalued)),
      findsNothing,
    );
  });

  testWidgets('pressing a verdict narrows the list to it, and again lifts it', (
    tester,
  ) async {
    tester.view
      ..physicalSize = _wideSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ListValuationViewModel.isEnabled = true;

    // Pumped by hand: tiles waiting for a price animate, so frames never
    // settle.
    await tester.pumpWidget(const PickStockApp());
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    for (final verdict in verdictFilterOptions) {
      expect(find.byKey(verdictFilterKey(verdict)), findsOneWidget);
    }

    await tester.tap(
      find.byKey(verdictFilterKey(ValuationVerdict.undervalued)),
    );
    await tester.pump();

    // The database answers in real time and the mock filings on the fake
    // clock, so the two are let run turn about until the prices are in.
    for (var turn = 0; turn < 24; turn++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 1500));
    }

    expect(inGrid('AAPL'), findsOneWidget);
    expect(inGrid('MSFT'), findsNothing);

    await tester.tap(
      find.byKey(verdictFilterKey(ValuationVerdict.undervalued)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(inGrid('MSFT'), findsOneWidget);
  });
}
