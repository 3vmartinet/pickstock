import 'package:drift/drift.dart' show InsertMode, Value;

import 'dart:io' show HttpDate;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/data/snapshot/growth_metric.dart';
import 'package:pickstock/data/snapshot/report_tab.dart';
import 'package:pickstock/ui/snapshot/widgets/fair_value_gauge.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:pickstock/ui/snapshot/widgets/snapshot_report.dart';
import 'package:drift/native.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/repo/price_repo.dart';
import 'package:pickstock/repo/quote/quote_repo.dart';
import 'package:pickstock/repo/report/report_repo.dart';
import 'package:pickstock/repo/settings/settings_repo.dart';
import 'package:pickstock/repo/watchlist/watchlist_repo.dart';
import 'package:pickstock/repo/sec/bulk_ingest_repo.dart';
import 'package:pickstock/repo/sec/mock_sec_repo.dart';
import 'package:pickstock/repo/sec/sec_repo.dart';
import 'package:pickstock/repo/sec/ticker_directory_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';

/// A small stand-in for SEC's directory, covering the shapes the app has to
/// handle: a hyphenated symbol, a seven-character one, two symbols sharing a
/// filer, and two names that both begin "Apple".
const List<(String symbol, String cik, String name)> testTickers = [
  ('AAPI', '0001824920', 'Apple iSports Group, Inc.'),
  ('AAPL', '0000320193', 'Apple Inc.'),
  ('BRK-A', '0001067983', 'BERKSHIRE HATHAWAY INC'),
  ('BRK-B', '0001067983', 'BERKSHIRE HATHAWAY INC'),
  ('KCAC-UN', '0001818605', 'Kensington Capital Acquisition Corp'),
  ('MSFT', '0000789019', 'MICROSOFT CORP'),
  ('NVDA', '0001045810', 'NVIDIA CORP'),
];

/// Registers everything the app resolves from `get_it`, against an in-memory
/// database seeded with [testTickers].
///
/// [withIngest] false leaves the database unpopulated, which is what the app
/// looks like before the bulk download has run.
/// Fiscal years for the fixture's filers, enough to rank them by growth over
/// several windows. Values are in millions of dollars, scaled below, so every
/// filer clears [minimumGrowthBase] and is actually rankable.
const List<(String cik, int year, double revenue, double ocf, double capex)>
testFiscalYears = [
  // Apple: steady growth — 10% over the last year, and over ten years.
  ('0000320193', 2015, 100, 60, 10),
  ('0000320193', 2024, 236, 150, 20),
  ('0000320193', 2025, 260, 200, 20),
  // NVIDIA: explosive over one year, and strongest over ten.
  ('0001045810', 2015, 10, 5, 1),
  ('0001045810', 2024, 100, 60, 10),
  ('0001045810', 2025, 300, 220, 20),
  // Microsoft: shrinking, so it ranks last among companies with figures.
  ('0000789019', 2015, 500, 300, 40),
  ('0000789019', 2024, 400, 250, 30),
  ('0000789019', 2025, 380, 240, 30),
  // Berkshire: one year only, so multi-year windows cannot rank it.
  ('0001067983', 2025, 900, 500, 50),
  // Kensington: a shell that spends more on equipment than it earns back,
  // which is the only shape in the fixture with free cash flow below zero.
  // One year, like Berkshire, so it cannot be ranked over a window either.
  ('0001818605', 2025, 20, 5, 30),
];

/// The balance-sheet side of each filer's latest year, which is what the
/// debt-free filter reads. Figures are in millions like the rest, and cover
/// the four shapes the filter has to tell apart: Apple borrows and pays
/// interest on it; NVIDIA reports no debt line at all and no interest either,
/// which is what owing nothing looks like in EDGAR; Microsoft reports its
/// borrowings as an explicit zero; and Berkshire reports no debt line but
/// $5M of interest, which is the shape that reads as debt-free until the
/// interest is looked at.
const Map<String, ({double? assets, double? debt, double? interest})>
testLatestBalanceSheets = {
  '0000320193': (assets: 300, debt: 50, interest: 2),
  '0001045810': (assets: 200, debt: null, interest: null),
  '0000789019': (assets: 400, debt: 0, interest: null),
  '0001067983': (assets: 900, debt: null, interest: 5),
};

/// Industry codes for the fixture's filers: two in tech, one in finance, one
/// left unclassified.
const Map<String, int> _testSicByCik = {
  '0000320193': 3571, // Apple — electronic computers
  '0001045810': 3674, // NVIDIA — semiconductors
  '0000789019': 7372, // Microsoft — prepackaged software
  '0001067983': 6331, // Berkshire — fire, marine & casualty insurance
};

/// The balance sheet for one row, or `null` for a year that is not the
/// filer's newest — earlier years carry no balance sheet in the fixture.
({double? assets, double? debt, double? interest})? _balanceSheetFor(
  String cik,
  int year,
  Map<String, int> latestYearByCik,
) => latestYearByCik[cik] == year ? testLatestBalanceSheets[cik] : null;

double? _scaled(double? millions) =>
    millions == null ? null : millions * _millions;

/// The fixture's figures are written in millions for readability.
const double _millions = 1000000;

/// An archive date old enough that the fake HEAD response looks newer.
final DateTime _loadedArchiveDate = DateTime.utc(2026, 1, 1);
final DateTime _newerArchiveDate = DateTime.utc(2026, 8, 29);

/// Stands in for SEC. HEAD answers the update check; nothing here reaches the
/// network, so tests never depend on it.
BulkIngestRepo _fakeIngestRepo({required bool withUpdate}) => BulkIngestRepo(
  client: MockClient((request) async {
    if (request.method == 'HEAD') {
      return http.Response(
        '',
        200,
        headers: withUpdate
            ? {'last-modified': HttpDate.format(_newerArchiveDate)}
            : const {},
      );
    }
    return http.Response('{}', 200);
  }),
);

/// A quote source for tests: unconfigured by default, so the price is typed in
/// exactly as it is in a build with no API key.
class FakeQuoteRepo implements QuoteRepo {
  FakeQuoteRepo({this.isConfigured = false, this.price, this.failure});

  @override
  bool isConfigured;

  /// What the next quote returns, if [failure] is not set.
  double? price;

  /// What the next quote throws instead of answering.
  QuoteFailure? failure;

  /// Symbols asked for, newest last, so tests can assert the provider is asked
  /// with its own spelling of a symbol.
  final List<String> requested = [];

  @override
  Duration get timeUntilSlot => Duration.zero;

  @override
  void reserveForJob() {}

  @override
  void releaseJob() {}

  @override
  Future<Quote> quoteFor(String ticker, {bool forJob = false}) async {
    requested.add(ticker);
    final thrown = failure;
    if (thrown != null) throw QuoteException(thrown);
    final quoted = price;
    if (quoted == null) throw const QuoteException(QuoteFailure.noCoverage);
    return Quote(pricePerShare: quoted, asOf: DateTime.now(), isQuoted: true);
  }
}

Future<AppDatabase> registerTestDependencies({
  bool withIngest = true,
  bool withFinancials = false,
  bool withUpdateAvailable = false,
  QuoteRepo? quoteRepo,
  SettingsRepo? settingsRepo,
}) async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());

  if (withIngest) {
    await database.batch(
      (batch) => batch.insertAll(database.tickers, [
        for (final (symbol, cik, name) in testTickers)
          TickersCompanion.insert(symbol: symbol, cik: cik, name: name),
      ]),
    );
    await database.recordIngest(
      testTickers.length,
      archiveLastModified: _loadedArchiveDate,
    );
  }

  if (withFinancials) {
    final ciks = {for (final row in testFiscalYears) row.$1};
    // The balance sheet belongs to the newest year on file, which is the only
    // one the debt-free filter looks at.
    final latestYearByCik = <String, int>{};
    for (final (cik, year, _, _, _) in testFiscalYears) {
      final known = latestYearByCik[cik];
      if (known == null || year > known) latestYearByCik[cik] = year;
    }
    await database.batch((batch) {
      batch.insertAll(database.companies, [
        for (final cik in ciks)
          CompaniesCompanion.insert(
            cik: cik,
            name: cik,
            sic: Value(_testSicByCik[cik]),
          ),
      ], mode: InsertMode.insertOrReplace);
      batch.insertAll(database.fiscalYears, [
        for (final (cik, year, revenue, ocf, capex) in testFiscalYears)
          FiscalYearsCompanion.insert(
            cik: cik,
            fiscalYear: year,
            revenue: Value(revenue * _millions),
            operatingCashFlow: Value(ocf * _millions),
            capitalExpenditure: Value(capex * _millions),
            totalAssets: Value(
              _scaled(_balanceSheetFor(cik, year, latestYearByCik)?.assets),
            ),
            totalDebt: Value(
              _scaled(_balanceSheetFor(cik, year, latestYearByCik)?.debt),
            ),
            interestExpense: Value(
              _scaled(_balanceSheetFor(cik, year, latestYearByCik)?.interest),
            ),
          ),
      ], mode: InsertMode.insertOrReplace);
    });
  }

  final directory = TickerDirectoryRepo();

  GetIt.I
    ..registerLazySingleton<ThemeRepo>(ThemeRepo.new)
    ..registerLazySingleton<FormatRepo>(FormatRepo.new)
    ..registerSingleton<AppDatabase>(database)
    ..registerSingleton<TickerDirectoryRepo>(directory)
    ..registerLazySingleton<BulkIngestRepo>(
      () => _fakeIngestRepo(withUpdate: withUpdateAvailable),
    )
    ..registerLazySingleton<SecRepo>(() => const MockSecRepo())
    // The real implementation, against the in-memory database: remembering a
    // price is a round trip through drift and is worth exercising as one.
    ..registerLazySingleton<PriceRepo>(() => const LocalPriceRepo())
    ..registerSingleton<QuoteRepo>(quoteRepo ?? FakeQuoteRepo())
    // The real implementation against the in-memory database: a list is a
    // couple of tables and a cascade, all of which is worth exercising.
    ..registerLazySingleton<WatchlistRepo>(LocalWatchlistRepo.new)
    ..registerSingleton<SettingsRepo>(settingsRepo ?? LocalSettingsRepo())
    ..registerLazySingleton<ReportRepo>(LocalReportRepo.new);

  // Read before anything builds, exactly as `main` does.
  await GetIt.I.get<SettingsRepo>().load();

  if (withIngest) await directory.load();
  // Opens the database and runs `beforeOpen`, so the seeded list exists before
  // the first widget builds rather than arriving mid-test.
  await database.allWatchlists();
  return database;
}

/// Opens a tab of the report.
///
/// Scoped to [ReportTabs] rather than to `Tabs`: the history's annual against
/// quarterly control is a `Tabs` as well, and both are on screen at once.
Future<void> openReportTab(WidgetTester tester, ReportTab tab) async {
  await tester.tap(
    find.descendant(
      of: find.byType(ReportTabs),
      matching: find.text(_tabLabels[tab]!),
    ),
  );
  await tester.pumpAndSettle();
}

/// The English labels, which is what the tests run against.
const Map<ReportTab, String> _tabLabels = {
  ReportTab.overview: 'Overview',
  ReportTab.valuation: 'Valuation',
  ReportTab.expectations: 'Expectations',
};

/// Types a share price by hand.
///
/// There is no field on the report any more: the price is a quote, and typing
/// over it opens an editor. Uses the button on the empty state when there is no
/// price yet, and the price itself once there is one.
Future<void> enterPriceByHand(WidgetTester tester, String price) async {
  final entryPoint = find.text('Set a price');
  await tester.tap(
    entryPoint.evaluate().isNotEmpty
        ? entryPoint
        : find.descendant(
            of: find.byType(FairValueGauge),
            matching: find.byKey(priceValueKey),
          ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, price);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}
