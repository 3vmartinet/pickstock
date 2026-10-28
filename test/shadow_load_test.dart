import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/repo/db/app_database.dart';

/// The company already loaded, and the one only the new archive has.
const String _apple = '0000320193';
const String _newcomer = '0002000001';

void main() {
  late AppDatabase database;

  // One test opens a file database while the in-memory one is still open.
  // They share nothing, which is the case drift's warning is not about.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    // What is loaded before the update: one company, one year, and the
    // reader's own things around it.
    await database.batch((batch) {
      batch
        ..insert(
          database.tickers,
          TickersCompanion.insert(symbol: 'AAPL', cik: _apple, name: 'Apple'),
        )
        ..insert(
          database.companies,
          CompaniesCompanion.insert(cik: _apple, name: 'Apple'),
        )
        ..insert(
          database.fiscalYears,
          FiscalYearsCompanion.insert(
            cik: _apple,
            fiscalYear: 2024,
            revenue: const Value(391e9),
          ),
        );
    });
    await database.recordIngest(1);
    await database.saveSetting('themeMode', 'dark');
    await database.saveResearchNote(
      cik: _apple,
      kind: 'business',
      generatedAt: DateTime(2026, 10, 1),
      body: 'Kept',
      lines: const [],
    );
  });

  tearDown(() => database.close());

  /// Fills the copies with what the new archive says: Apple a year on, and a
  /// company the live tables have never heard of.
  Future<void> fillShadows() async {
    await database.createShadowTables();
    await database.batch((batch) {
      database
        ..insertIntoShadow(batch, database.tickers, [
          TickersCompanion.insert(symbol: 'AAPL', cik: _apple, name: 'Apple'),
          TickersCompanion.insert(symbol: 'NEW', cik: _newcomer, name: 'New'),
        ])
        ..insertIntoShadow(batch, database.companies, [
          CompaniesCompanion.insert(
            cik: _apple,
            name: 'Apple',
            sharesLastFiled: Value(DateTime(2026, 10, 20)),
          ),
          CompaniesCompanion.insert(cik: _newcomer, name: 'New'),
        ])
        // The newcomer's years are the case a copy still pointing its
        // foreign key at the live `companies` would refuse.
        ..insertIntoShadow(batch, database.fiscalYears, [
          FiscalYearsCompanion.insert(
            cik: _apple,
            fiscalYear: 2025,
            revenue: const Value(416e9),
          ),
          FiscalYearsCompanion.insert(
            cik: _newcomer,
            fiscalYear: 2025,
            revenue: const Value(1e9),
          ),
        ]);
    });
  }

  test('the live tables are read untouched while the copies fill', () async {
    await fillShadows();

    expect((await database.yearsFor(_apple)).single.fiscalYear, 2024);
    expect(await database.yearsFor(_newcomer), isEmpty);
    expect(await database.lastIngest(), isNotNull);
  });

  test('the swap puts every new figure in at once', () async {
    await fillShadows();
    await database.swapInShadowTables(
      companyCount: 2,
      archiveLastModified: DateTime.utc(2026, 10, 27),
      loadDuration: const Duration(seconds: 231),
    );

    // The old year is gone with the table it was in, not merged with the new.
    expect((await database.yearsFor(_apple)).single.fiscalYear, 2025);
    expect((await database.yearsFor(_newcomer)).single.revenue, 1e9);
    expect(
      (await database.companyFor(_apple))?.sharesLastFiled,
      DateTime(2026, 10, 20),
    );
    final run = await database.lastIngest();
    expect(run?.companyCount, 2);
    expect(run?.loadSeconds, 231);
  });

  test('the reader’s own things are not part of it', () async {
    await fillShadows();
    await database.swapInShadowTables(companyCount: 2);

    expect(await database.allSettings(), containsPair('themeMode', 'dark'));
    expect((await database.researchNote(_apple, 'business'))?.$1.body, 'Kept');
    expect(await database.allWatchlists(), isNotEmpty);
  });

  test('the foreign keys still point at the live tables afterwards', () async {
    await fillShadows();
    await database.swapInShadowTables(companyCount: 2);

    final definition = await database
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE name = 'fiscal_years'",
        )
        .getSingle();
    final sql = definition.read<String>('sql');
    expect(sql, contains('REFERENCES "companies"'));
    expect(sql, isNot(contains('_next')));
    // And are enforced: a year for a company nobody filed is refused.
    await expectLater(
      database
          .into(database.fiscalYears)
          .insert(
            FiscalYearsCompanion.insert(cik: '0009999999', fiscalYear: 2025),
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('a load that is given up on leaves nothing behind', () async {
    await fillShadows();
    await database.dropShadowTables();

    expect((await database.yearsFor(_apple)).single.fiscalYear, 2024);
    expect(await _shadowTables(database), isEmpty);
  });

  test('copies left by a load the app was closed during go at the next '
      'start', () async {
    final directory = await Directory.systemTemp.createTemp('pickstock');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/shadow.sqlite');

    final first = AppDatabase.forTesting(NativeDatabase(file));
    await first.createShadowTables();
    expect(await _shadowTables(first), hasLength(4));
    await first.close();

    final reopened = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(reopened.close);
    expect(await _shadowTables(reopened), isEmpty);
  });

  test('the swapped tables carry no index a swap would lose', () async {
    // Only the primary keys, which come with each table's definition. An
    // index added later would be dropped with the live table and not made on
    // the copy; this fails first, so whoever adds one adds it there too.
    final indexes = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND sql IS NOT NULL AND tbl_name IN "
          "('tickers', 'companies', 'fiscal_years', 'fiscal_quarters')",
        )
        .get();
    expect(indexes, isEmpty);
  });
}

Future<List<String>> _shadowTables(AppDatabase database) async => [
  for (final row
      in await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name LIKE '%\\_next' ESCAPE '\\'",
          )
          .get())
    row.read<String>('name'),
];
