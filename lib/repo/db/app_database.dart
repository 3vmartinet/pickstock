import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Bumped whenever the XBRL extraction changes meaning. Rows written by an
/// older extractor are discarded rather than served, because a stale row is
/// indistinguishable from a correct one once it is in the table.
const int extractorVersion = 2;

const String _databaseName = 'pickstock';

/// One SEC filer.
@DataClassName('CompanyRow')
class Companies extends Table {
  /// Ten-digit, zero-padded Central Index Key.
  TextColumn get cik => text()();
  TextColumn get name => text()();

  @override
  Set<Column<Object>> get primaryKey => {cik};
}

/// One fiscal year of figures for one filer, in whole US dollars.
///
/// Every figure is nullable: a company only tags the concepts its own filings
/// use, so any line can legitimately be absent for a year.
@DataClassName('FiscalYearRow')
class FiscalYears extends Table {
  TextColumn get cik => text().references(Companies, #cik)();
  IntColumn get fiscalYear => integer()();
  RealColumn get revenue => real().nullable()();
  RealColumn get netIncome => real().nullable()();
  RealColumn get operatingCashFlow => real().nullable()();
  RealColumn get capitalExpenditure => real().nullable()();
  RealColumn get totalDebt => real().nullable()();
  RealColumn get cash => real().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {cik, fiscalYear};
}

/// A single row recording what the last completed bulk ingest loaded.
@DataClassName('IngestRunRow')
class IngestRuns extends Table {
  IntColumn get id => integer()();
  DateTimeColumn get completedAt => dateTime()();
  IntColumn get companyCount => integer()();
  IntColumn get extractorVersion => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Companies, FiscalYears, IngestRuns])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: _databaseName));

  /// Used by tests to run against an in-memory database.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  /// The years on file for [cik], oldest first.
  Future<List<FiscalYearRow>> yearsFor(String cik) {
    return (select(fiscalYears)
          ..where((row) => row.cik.equals(cik))
          ..orderBy([(row) => OrderingTerm.asc(row.fiscalYear)]))
        .get();
  }

  Future<CompanyRow?> companyFor(String cik) {
    return (select(
      companies,
    )..where((row) => row.cik.equals(cik))).getSingleOrNull();
  }

  /// The last completed ingest, or `null` if the database has never been
  /// populated or was written by an incompatible extractor.
  Future<IngestRunRow?> lastIngest() async {
    final run = await select(ingestRuns).getSingleOrNull();
    if (run == null || run.extractorVersion != extractorVersion) return null;
    return run;
  }

  /// Replaces the contents of the database with a freshly ingested set.
  Future<void> recordIngest(int companyCount) {
    return into(ingestRuns).insertOnConflictUpdate(
      IngestRunsCompanion.insert(
        id: const Value(1),
        completedAt: DateTime.now(),
        companyCount: companyCount,
        extractorVersion: extractorVersion,
      ),
    );
  }

  Future<void> clearFinancials() async {
    await delete(fiscalYears).go();
    await delete(companies).go();
    await delete(ingestRuns).go();
  }
}
