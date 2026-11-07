import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/valuation/valuation_verdict.dart';
import 'package:pickstock/data/valuation/discount_rate.dart';
import 'package:pickstock/data/valuation/valuation.dart';
import 'package:pickstock/repo/sec/mock_sec_repo.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/market/market_rates_repo.dart';
import 'package:pickstock/repo/price_repo.dart';
import 'package:pickstock/ui/browse/list_valuation_view_model.dart';
import 'package:pickstock/ui/browse/widgets/ticker_grid.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

const Company _apple = Company(
  cik: '0000320193',
  ticker: 'AAPL',
  name: 'Apple Inc.',
);

const Size _wideSize = Size(1600, 1000);

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
    // The harness leaves background pricing off; this is the test of it.
    ListValuationViewModel.isEnabled = true;
  });

  tearDown(() async {
    await database.close();
    await GetIt.I.reset();
  });

  /// Waits for [viewModel] to have a verdict for Apple, or for long enough
  /// that it plainly is not going to.
  Future<ValuationVerdict?> verdictOf(ListValuationViewModel viewModel) async {
    for (var tries = 0; tries < 40; tries++) {
      final verdict = viewModel.verdictFor(_apple.cik);
      if (verdict != null) return verdict;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return null;
  }

  test('prices a requested company and judges it', () async {
    final viewModel = ListValuationViewModel();
    addTearDown(viewModel.dispose);

    viewModel.request(_apple);
    expect(viewModel.isPending(_apple.cik), isTrue);

    expect(await verdictOf(viewModel), ValuationVerdict.undervalued);
    expect(viewModel.isPending(_apple.cik), isFalse);
    expect(quotes.requested, ['AAPL']);
    // Stored, with the time it was asked for, so the report and the next
    // launch both have it.
    final stored = await GetIt.I.get<PriceRepo>().priceFor(_apple.cik);
    expect(stored?.pricePerShare, 80);
    expect(stored?.fetchedAt, isNotNull);
  });

  test('does not ask again inside the guard', () async {
    final viewModel = ListValuationViewModel();
    addTearDown(viewModel.dispose);

    viewModel.request(_apple);
    await verdictOf(viewModel);
    // Every rebuild of the tile asks; only the first is answered.
    viewModel
      ..request(_apple)
      ..request(_apple);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(quotes.requested, ['AAPL']);
  });

  test('a stored quote inside the guard holds across a relaunch', () async {
    await GetIt.I.get<PriceRepo>().save(
      _apple.cik,
      Quote(
        pricePerShare: 250,
        asOf: DateTime.now(),
        isQuoted: true,
        fetchedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    );
    final viewModel = ListValuationViewModel();
    addTearDown(viewModel.dispose);

    viewModel.request(_apple);

    // Judged on the stored $250, without a call.
    expect(await verdictOf(viewModel), ValuationVerdict.overvalued);
    expect(quotes.requested, isEmpty);
  });

  test('a stored quote older than the guard is asked for again', () async {
    await GetIt.I.get<PriceRepo>().save(
      _apple.cik,
      Quote(
        pricePerShare: 250,
        asOf: DateTime.now(),
        isQuoted: true,
        fetchedAt: DateTime.now().subtract(
          listPriceGuard + const Duration(minutes: 1),
        ),
      ),
    );
    final viewModel = ListValuationViewModel();
    addTearDown(viewModel.dispose);

    viewModel.request(_apple);

    expect(await verdictOf(viewModel), ValuationVerdict.undervalued);
    expect(quotes.requested, ['AAPL']);
  });

  test('a typed price is never overwritten by a quote', () async {
    await GetIt.I.get<PriceRepo>().save(_apple.cik, Quote.entered(250));
    final viewModel = ListValuationViewModel();
    addTearDown(viewModel.dispose);

    viewModel.request(_apple);

    expect(await verdictOf(viewModel), ValuationVerdict.overvalued);
    expect(quotes.requested, isEmpty);
  });

  test('asks nothing without a key', () async {
    quotes.isConfigured = false;
    final viewModel = ListValuationViewModel();
    addTearDown(viewModel.dispose);

    viewModel.request(_apple);

    // Nothing asked, so nothing pending to animate either.
    expect(viewModel.isPending(_apple.cik), isFalse);
    expect(await verdictOf(viewModel), isNull);
    expect(quotes.requested, isEmpty);
  });

  test('a symbol with no price stops pending without a verdict', () async {
    quotes.price = null;
    final viewModel = ListValuationViewModel();
    addTearDown(viewModel.dispose);
    var notified = 0;
    viewModel.addListener(() => notified++);

    viewModel.request(_apple);
    expect(viewModel.isPending(_apple.cik), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(viewModel.isPending(_apple.cik), isFalse);
    expect(viewModel.verdictFor(_apple.cik), isNull);
    // Told, so the tile stops animating.
    expect(notified, greaterThan(0));
  });

  test('stands back while a bulk run holds the budget', () async {
    quotes.failure = QuoteFailure.jobRunning;
    final viewModel = ListValuationViewModel();
    addTearDown(viewModel.dispose);

    viewModel.request(_apple);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // Turned away once, and not asked about again on every rebuild while it
    // waits its minute.
    viewModel.request(_apple);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(quotes.requested, ['AAPL']);
    expect(viewModel.verdictFor(_apple.cik), isNull);
  });

  test(
    'keeps the report\'s verdict once the tile is no longer selected',
    () async {
      final viewModel = ListValuationViewModel();
      addTearDown(viewModel.dispose);

      // The report, on the company's own discount rate, judged it fairly
      // priced; the list on its own would have said undervalued at \$80.
      viewModel.adopt(_apple.cik, ValuationVerdict.fairlyValued);
      viewModel.request(_apple);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(viewModel.verdictFor(_apple.cik), ValuationVerdict.fairlyValued);
      // Priced by the report already, so not asked for again.
      expect(quotes.requested, isEmpty);
    },
  );

  test('a pricing already under way does not overwrite the report', () async {
    final viewModel = ListValuationViewModel();
    addTearDown(viewModel.dispose);

    viewModel.request(_apple);
    viewModel.adopt(_apple.cik, ValuationVerdict.fairlyValued);
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    expect(viewModel.verdictFor(_apple.cik), ValuationVerdict.fairlyValued);
  });

  test('judges on the company\'s own rate, as the report does', () async {
    const rate = _FixedRate(20);
    await database.close();
    await GetIt.I.reset();
    quotes = FakeQuoteRepo(isConfigured: true, price: 100);
    database = await registerTestDependencies(
      withFinancials: true,
      quoteRepo: quotes,
      marketRatesRepo: rate,
    );
    ListValuationViewModel.isEnabled = true;

    // What the report would say, on the company's own rate — and, so the
    // test means something, not what the assumed rate would say.
    final snapshot = await const MockSecRepo().fetchSnapshot('AAPL');
    Valuation at(double? percent) => Valuation(
      snapshot: snapshot,
      pricePerShare: 100,
      discountRatePercent: percent,
    );
    final own = at(rate.cachedRateFor('AAPL')!.percent).verdict;
    expect(own, isNot(at(null).verdict));

    final viewModel = ListValuationViewModel();
    addTearDown(viewModel.dispose);
    viewModel.request(_apple);

    expect(await verdictOf(viewModel), own);
  });

  testWidgets('the tile carries the verdict once it is priced', (tester) async {
    tester.view
      ..physicalSize = _wideSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Pumped by hand: a tile waiting for its price animates for as long as
    // it waits, so the frames never settle.
    await tester.pumpWidget(const PickStockApp());
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(tileVerdictKey(_apple.cik)), findsNothing);
    // Waiting its turn, and saying so.
    expect(find.byKey(tilePendingKey(_apple.cik)), findsOneWidget);

    // The database answers in real time, while the mock filings and the pause
    // between quotes run on the fake clock, so the two are let run turn about.
    // Every tile on screen asks, newest first, so Apple — built first — is
    // priced after the rest.
    for (var turn = 0; turn < 24; turn++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 1500));
    }

    final mark = find.byKey(tileVerdictKey(_apple.cik));
    expect(mark, findsOneWidget);
    expect(find.byKey(tilePendingKey(_apple.cik)), findsNothing);
    expect(tester.widget<Icon>(mark).icon, ValuationVerdict.undervalued.icon);
    expect(quotes.requested, contains('AAPL'));
  });
}

/// A company rate that is always [percent], as a fetched one would be.
class _FixedRate implements MarketRatesRepo {
  const _FixedRate(this.percent);

  final double percent;

  @override
  bool get isConfigured => true;

  @override
  Future<DiscountRate?> rateFor(String ticker) async => cachedRateFor(ticker);

  @override
  DiscountRate? cachedRateFor(String ticker) => DiscountRate(
    riskFreePercent: percent - 5,
    beta: 1,
    asOf: DateTime.utc(2026),
  );
}
