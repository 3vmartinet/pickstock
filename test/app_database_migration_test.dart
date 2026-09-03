import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// The schema as it stood before `fiscal_quarters` was added: an existing
/// install on disk looks like this.
const List<String> _schemaVersion1 = [
  'CREATE TABLE companies (cik TEXT NOT NULL, name TEXT NOT NULL, '
      'PRIMARY KEY (cik));',
  'CREATE TABLE tickers (symbol TEXT NOT NULL, cik TEXT NOT NULL, '
      'name TEXT NOT NULL, PRIMARY KEY (symbol));',
  'CREATE TABLE fiscal_years (cik TEXT NOT NULL, fiscal_year INTEGER NOT NULL, '
      'revenue REAL, net_income REAL, operating_cash_flow REAL, '
      'capital_expenditure REAL, total_debt REAL, cash REAL, '
      'PRIMARY KEY (cik, fiscal_year));',
  'CREATE TABLE ingest_runs (id INTEGER NOT NULL, completed_at INTEGER NOT NULL, '
      'company_count INTEGER NOT NULL, extractor_version INTEGER NOT NULL, '
      'PRIMARY KEY (id));',
];

/// The schema as it stood at version 11, taken from a live install.
///
/// An install on this version has a 1.4 GB ingest behind it, so the upgrade
/// to 12 has to add the new column and leave everything else alone — a
/// rebuild would cost that download again.
const List<String> _schemaVersion11 = [
  'CREATE TABLE IF NOT EXISTS "companies" ("cik" TEXT NOT NULL, "name" TEXT NOT NULL, "sic" INTEGER NULL, "shares_outstanding" REAL NULL, PRIMARY KEY ("cik"));',
  'CREATE TABLE IF NOT EXISTS "tickers" ("symbol" TEXT NOT NULL, "cik" TEXT NOT NULL, "name" TEXT NOT NULL, PRIMARY KEY ("symbol"));',
  'CREATE TABLE IF NOT EXISTS "fiscal_years" ("cik" TEXT NOT NULL REFERENCES companies (cik), "fiscal_year" INTEGER NOT NULL, "revenue" REAL NULL, "net_income" REAL NULL, "operating_cash_flow" REAL NULL, "capital_expenditure" REAL NULL, "total_debt" REAL NULL, "cash" REAL NULL, "diluted_shares" REAL NULL, "operating_income" REAL NULL, "depreciation_amortisation" REAL NULL, "total_assets" REAL NULL, "shareholders_equity" REAL NULL, "interest_expense" REAL NULL, PRIMARY KEY ("cik", "fiscal_year"));',
  'CREATE TABLE IF NOT EXISTS "fiscal_quarters" ("cik" TEXT NOT NULL REFERENCES companies (cik), "fiscal_year" INTEGER NOT NULL, "quarter" INTEGER NOT NULL, "revenue" REAL NULL, "net_income" REAL NULL, "operating_cash_flow" REAL NULL, "capital_expenditure" REAL NULL, "total_debt" REAL NULL, "cash" REAL NULL, PRIMARY KEY ("cik", "fiscal_year", "quarter"));',
  'CREATE TABLE IF NOT EXISTS "ingest_runs" ("id" INTEGER NOT NULL, "completed_at" INTEGER NOT NULL, "company_count" INTEGER NOT NULL, "extractor_version" INTEGER NOT NULL, "archive_last_modified" INTEGER NULL, PRIMARY KEY ("id"));',
  'CREATE TABLE IF NOT EXISTS "share_prices" ("cik" TEXT NOT NULL, "price_per_share" REAL NOT NULL, "as_of" INTEGER NOT NULL, "is_quoted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_quoted" IN (0, 1)), PRIMARY KEY ("cik"));',
  'CREATE TABLE IF NOT EXISTS "watchlists" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "name" TEXT NOT NULL, "colour_index" INTEGER NOT NULL, "is_default" INTEGER NOT NULL DEFAULT 0 CHECK ("is_default" IN (0, 1)), "created_at" INTEGER NOT NULL);',
  'CREATE TABLE IF NOT EXISTS "watchlist_entries" ("watchlist_id" INTEGER NOT NULL REFERENCES watchlists (id) ON DELETE CASCADE, "cik" TEXT NOT NULL, "added_at" INTEGER NOT NULL, PRIMARY KEY ("watchlist_id", "cik"));',
  'CREATE TABLE IF NOT EXISTS "settings" ("key" TEXT NOT NULL, "value" TEXT NOT NULL, PRIMARY KEY ("key"));',
  'CREATE TABLE IF NOT EXISTS "reports" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "name" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "considered_count" INTEGER NOT NULL, "valued_count" INTEGER NOT NULL);',
  'CREATE TABLE IF NOT EXISTS "report_entries" ("report_id" INTEGER NOT NULL REFERENCES reports (id) ON DELETE CASCADE, "cik" TEXT NOT NULL, "ticker" TEXT NOT NULL, "name" TEXT NOT NULL, "price_per_share" REAL NOT NULL, "fair_value_low" REAL NOT NULL, "fair_value_high" REAL NOT NULL, "upside_percent" REAL NOT NULL, PRIMARY KEY ("report_id", "cik"));',
];

void main() {
  late Directory directory;
  late File databaseFile;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    directory = await Directory.systemTemp.createTemp('pickstock-migration');
    databaseFile = File('${directory.path}/pickstock.sqlite');

    final raw = sqlite.sqlite3.open(databaseFile.path);
    for (final statement in _schemaVersion1) {
      raw.execute(statement);
    }
    raw.execute(
      "INSERT INTO companies (cik, name) VALUES ('0000320193', 'Apple Inc.');",
    );
    raw.execute('PRAGMA user_version = 1;');
    raw.close();
  });

  tearDown(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  test(
    'an existing database on the old schema is rebuilt, not broken',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase(databaseFile));
      addTearDown(database.close);

      // This is the statement that failed in the field: `no such table:
      // fiscal_quarters`.
      await database.clearFinancials();
      expect(await database.quartersFor('0000320193'), isEmpty);
    },
  );

  test('the rebuilt database asks for a fresh ingest', () async {
    // Pretend the old install had completed an ingest.
    final raw = sqlite.sqlite3.open(databaseFile.path);
    raw.execute(
      'INSERT INTO ingest_runs (id, completed_at, company_count, '
      'extractor_version) VALUES (1, 0, 20000, 2);',
    );
    raw.execute('PRAGMA user_version = 1;');
    raw.close();

    final database = AppDatabase.forTesting(NativeDatabase(databaseFile));
    addTearDown(database.close);

    // Rebuilt from scratch, so the gate blocks until the archive is loaded
    // again rather than reading half a schema.
    expect(await database.lastIngest(), isNull);
  });

  test('a fresh database still opens at the current schema', () async {
    final fresh = File('${directory.path}/fresh.sqlite');
    final database = AppDatabase.forTesting(NativeDatabase(fresh));
    addTearDown(database.close);

    await database.clearFinancials();
    expect(await database.lastIngest(), isNull);
    expect(await database.allTickers(), isEmpty);
  });

  test('a version 11 install gains the column and keeps its ingest', () async {
    final upgradeFile = File('${directory.path}/v11.sqlite');
    final raw = sqlite.sqlite3.open(upgradeFile.path);
    for (final statement in _schemaVersion11) {
      raw.execute(statement);
    }
    raw.execute(
      "INSERT INTO companies (cik, name, shares_outstanding) "
      "VALUES ('0000320193', 'Apple Inc.', 14594200000.0);",
    );
    raw.execute(
      'INSERT INTO ingest_runs (id, completed_at, company_count, '
      'extractor_version) VALUES (1, 0, 13582, $extractorVersion);',
    );
    raw.execute('PRAGMA user_version = 11;');
    raw.close();

    final database = AppDatabase.forTesting(NativeDatabase(upgradeFile));
    addTearDown(database.close);

    // The row and its share count came through untouched.
    final company = await database.companyFor('0000320193');
    expect(company, isNotNull);
    expect(company!.sharesOutstanding, 14594200000.0);
    // Null until the next ingest, which is what "added, not populated" means.
    expect(company.sharesLastFiled, isNull);

    // Written to rather than only read: a column that was never added still
    // reads as null on a nullable field, so reading proves nothing. Writing
    // to one that is missing throws.
    await database.customStatement(
      "UPDATE companies SET shares_last_filed = 0 WHERE cik = '0000320193'",
    );
    expect(
      (await database.companyFor('0000320193'))?.sharesLastFiled,
      isNotNull,
    );

    // And the ingest behind it survived, rather than being rebuilt: an
    // upgrade that dropped the tables would cost the download again.
    expect((await database.lastIngest())?.companyCount, 13582);
  });
}
