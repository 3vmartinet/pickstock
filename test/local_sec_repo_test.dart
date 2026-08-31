import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/sec/local_sec_repo.dart';
import 'package:pickstock/repo/sec/sec_repo.dart';

import 'support/test_directory.dart';

const String _appleCik = '0000320193';

void main() {
  late AppDatabase database;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    database = await registerTestDependencies();
  });

  tearDown(() async {
    await database.close();
    await GetIt.I.reset();
  });

  Future<void> seed({required int years, int firstYear = 2016}) async {
    await database
        .into(database.companies)
        .insert(CompaniesCompanion.insert(cik: _appleCik, name: 'Apple Inc.'));
    for (var i = 0; i < years; i++) {
      await database
          .into(database.fiscalYears)
          .insert(
            FiscalYearsCompanion.insert(
              cik: _appleCik,
              fiscalYear: firstYear + i,
              revenue: Value(100.0 + i),
              operatingCashFlow: const Value(50),
            ),
          );
    }
    await database.recordIngest(1);
  }

  test('says the database is empty before any ingest', () async {
    await database.clearFinancials();
    await expectLater(
      const LocalSecRepo().fetchSnapshot('AAPL'),
      throwsA(
        isA<SecException>().having(
          (e) => e.failure,
          'failure',
          SecFailure.databaseEmpty,
        ),
      ),
    );
  });

  test('reads a snapshot back out of the database', () async {
    await seed(years: 3);
    final snapshot = await const LocalSecRepo().fetchSnapshot('aapl');

    expect(snapshot.company.ticker, 'AAPL');
    expect(snapshot.company.cik, _appleCik);
    expect(snapshot.years.map((y) => y.fiscalYear), [2016, 2017, 2018]);
  });

  test('keeps only the ten most recent years', () async {
    await seed(years: 19, firstYear: 2007);
    final snapshot = await const LocalSecRepo().fetchSnapshot('AAPL');

    expect(snapshot.years, hasLength(reportedYears));
    expect(snapshot.years.last.fiscalYear, 2025);
    expect(snapshot.years.first.fiscalYear, 2016);
  });

  test('carries prior-year revenue in from outside the window', () async {
    await seed(years: 19, firstYear: 2007);
    final snapshot = await const LocalSecRepo().fetchSnapshot('AAPL');

    // FY2016 is the oldest year shown, but FY2015 is still on file, so its
    // growth is known rather than blank.
    expect(snapshot.years.first.priorRevenue, isNotNull);
    expect(snapshot.years.first.revenueGrowthPercent, isNotNull);
  });

  test('reports an unknown symbol without touching the database', () async {
    await expectLater(
      const LocalSecRepo().fetchSnapshot('ZZZZ'),
      throwsA(
        isA<SecException>().having(
          (e) => e.failure,
          'failure',
          SecFailure.unknownTicker,
        ),
      ),
    );
  });

  test('reports a filer that has no annual rows', () async {
    await database.recordIngest(0);
    await expectLater(
      const LocalSecRepo().fetchSnapshot('AAPL'),
      throwsA(
        isA<SecException>().having(
          (e) => e.failure,
          'failure',
          SecFailure.noAnnualData,
        ),
      ),
    );
  });
}
