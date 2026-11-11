import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/price_repo.dart';
import 'package:pickstock/repo/quote/bulk_price_refresh.dart';
import 'package:pickstock/ui/snapshot/market_leaders_view_model.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart'
    show quoteFreshness;

import 'support/test_directory.dart';

const String _apple = '0000320193';
const String _nvidia = '0001045810';
const String _microsoft = '0000789019';
const String _berkshire = '0001067983';

// Plain `test`: the rankings await real database queries, which a widget
// test's fake clock never lets finish.

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  late AppDatabase database;
  late FakeQuoteRepo quotes;

  Future<void> boot({FakeBulkPriceRepo? closes, bool canQuote = true}) async {
    quotes = FakeQuoteRepo(isConfigured: canQuote, price: 100);
    database = await registerTestDependencies(
      quoteRepo: quotes,
      bulkPriceRepo: closes,
    );
    // The harness leaves re-quoting off; this is the test of it.
    MarketLeadersViewModel.isRefreshEnabled = true;
    await _seedCompanies(database);
  }

  tearDown(() async {
    await database.close();
    await GetIt.I.reset();
  });

  /// Stores [perShare] for [cik], asked for [age] ago, and true as of then
  /// unless [asOf] says otherwise.
  Future<void> price(
    String cik,
    double perShare, {
    Duration? age,
    DateTime? asOf,
  }) {
    final asked = DateTime.now().subtract(age ?? Duration.zero);
    return GetIt.I.get<PriceRepo>().save(
      cik,
      Quote(
        pricePerShare: perShare,
        asOf: asOf ?? asked,
        isQuoted: true,
        fetchedAt: asked,
      ),
    );
  }

  test('re-quotes the overall ranking once its prices are stale', () async {
    await boot();
    await price(_apple, 300, age: quoteFreshness * 2);
    await price(_nvidia, 150);
    await price(_microsoft, 400);
    await price(_berkshire, 500);
    final viewModel = MarketLeadersViewModel();
    addTearDown(viewModel.dispose);

    await viewModel.ensureFresh();

    // No bulk closes, so a stale price is quoted again, and only that one.
    expect(quotes.requested, ['AAPL']);
  });

  test(
    'with the day\'s closes loaded, a stored close is never re-quoted',
    () async {
      // The rankings are a screen, and a screen is about the day: however
      // long ago the closes were stored, Finnhub is not asked for one of them.
      await boot(closes: FakeBulkPriceRepo({'AAPL': 300}));
      for (final (cik, perShare) in [
        (_apple, 300.0),
        (_nvidia, 150.0),
        (_microsoft, 400.0),
      ]) {
        await price(cik, perShare, age: const Duration(days: 2));
      }
      final viewModel = MarketLeadersViewModel();
      addTearDown(viewModel.dispose);

      await viewModel.ensureFresh();

      expect(viewModel.leaders.first.company.cik, _apple);
      // Berkshire has no price at all, so it alone is asked for.
      expect(quotes.requested, hasLength(1));
      expect(quotes.requested.single, startsWith('BRK'));
    },
  );

  test(
    'with the day\'s closes loaded, a typed price is left alone too',
    () async {
      // The closes and the scan keep the reader's own price; the rankings
      // do not overwrite it with a quote either.
      await boot(closes: FakeBulkPriceRepo({'AAPL': 300}));
      await GetIt.I.get<PriceRepo>().save(_apple, Quote.entered(300));
      await price(_nvidia, 150);
      await price(_microsoft, 400);
      await price(_berkshire, 500);
      final viewModel = MarketLeadersViewModel();
      addTearDown(viewModel.dispose);

      await viewModel.ensureFresh();

      expect(quotes.requested, isEmpty);
      expect(
        (await GetIt.I.get<PriceRepo>().priceFor(_apple))?.isQuoted,
        isFalse,
      );
    },
  );

  test('re-ranks on the stored prices when the day\'s closes land', () async {
    final closes = FakeBulkPriceRepo({'AAPL': 10});
    await boot(closes: closes, canQuote: false);
    // Quoted before the closes' day, so the close replaces it.
    await price(_apple, 300, asOf: DateTime.utc(2026, 11, 6, 21));
    await price(_nvidia, 150);
    await price(_microsoft, 400);
    await price(_berkshire, 500);
    final viewModel = MarketLeadersViewModel();
    addTearDown(viewModel.dispose);
    await viewModel.ensureFresh();
    expect(viewModel.leaders.first.company.cik, _apple);

    // Apple closes at $10, which drops it to the bottom of the ranking
    // without the pane being shown again.
    await GetIt.I.get<BulkPriceRefresh>().refreshIfDue();
    for (var tries = 0; tries < 40; tries++) {
      if (viewModel.leaders.last.company.cik == _apple) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(viewModel.leaders.first.company.cik, _nvidia);
    expect(viewModel.leaders.last.company.cik, _apple);
    expect(quotes.requested, isEmpty);
  });

  test('sizes a filer with no cover count on its newest quarter', () async {
    await boot();
    // Apple's cover count is dropped, and it split four for one after its
    // annual report: the quarter's diluted count is the current one.
    await database.customStatement(
      "UPDATE companies SET shares_outstanding = NULL WHERE cik = '$_apple'",
    );
    await database.customStatement(
      "UPDATE fiscal_years SET diluted_shares = 3.7e9 WHERE cik = '$_apple'",
    );
    await database
        .into(database.trailingYears)
        .insert(
          TrailingYearsCompanion.insert(
            cik: _apple,
            periodEnd: DateTime(2026, 6, 30),
            fiscalYear: 2026,
            quarter: 3,
            dilutedShares: const Value(14.8e9),
          ),
        );

    final samples = await database.sizeSamples(fromYear: 2023, toYear: 2027);
    final apple = samples.singleWhere((sample) => sample.cik == _apple);
    expect(apple.shares, 14.8e9);
    // A cover count still comes first, as it does in the valuation.
    final nvidia = samples.singleWhere((sample) => sample.cik == _nvidia);
    expect(nvidia.shares, 24.3e9);
  });
}

/// Share counts, industries and a year of earnings for four of the test
/// directory's filers: what picks them as worth pricing.
Future<void> _seedCompanies(AppDatabase database) async {
  const companies = [
    (_apple, 'Apple Inc.', 3571, 14.84e9, 112e9),
    (_nvidia, 'NVIDIA CORP', 3674, 24.3e9, 73e9),
    (_microsoft, 'MICROSOFT CORP', 7372, 7.5e9, 88e9),
    (_berkshire, 'BERKSHIRE HATHAWAY INC', 6331, 2.16e9, 89e9),
  ];
  await database.batch((batch) {
    batch.insertAll(database.companies, [
      for (final (cik, name, sic, shares, _) in companies)
        CompaniesCompanion.insert(
          cik: cik,
          name: name,
          sic: Value(sic),
          sharesOutstanding: Value(shares),
        ),
    ], mode: InsertMode.insertOrReplace);
    batch.insertAll(database.fiscalYears, [
      for (final (cik, _, _, _, netIncome) in companies)
        FiscalYearsCompanion.insert(
          cik: cik,
          fiscalYear: 2025,
          netIncome: Value(netIncome),
        ),
    ], mode: InsertMode.insertOrReplace);
  });
}
