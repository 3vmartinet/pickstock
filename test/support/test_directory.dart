import 'package:drift/drift.dart' show InsertMode, Value;

import 'dart:io' show HttpDate;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pickstock/data/snapshot/growth_metric.dart';
import 'package:drift/native.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/format_repo.dart';
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
];

/// Industry codes for the fixture's filers: two in tech, one in finance, one
/// left unclassified.
const Map<String, int> _testSicByCik = {
  '0000320193': 3571, // Apple — electronic computers
  '0001045810': 3674, // NVIDIA — semiconductors
  '0000789019': 7372, // Microsoft — prepackaged software
  '0001067983': 6331, // Berkshire — fire, marine & casualty insurance
};

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

Future<AppDatabase> registerTestDependencies({
  bool withIngest = true,
  bool withFinancials = false,
  bool withUpdateAvailable = false,
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
    ..registerLazySingleton<SecRepo>(() => const MockSecRepo());

  if (withIngest) await directory.load();
  return database;
}
