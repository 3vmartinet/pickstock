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
}
