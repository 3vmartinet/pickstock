import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:pickstock/data/snapshot/growth_metric.dart';
import 'package:pickstock/extensions/object_extensions.dart';

part 'app_database.g.dart';

/// Bumped whenever the XBRL extraction changes meaning. Rows written by an
/// older extractor are discarded rather than served, because a stale row is
/// indistinguishable from a correct one once it is in the table.
const int extractorVersion = 3;

const String _databaseName = 'pickstock';

/// One SEC filer.
@DataClassName('CompanyRow')
class Companies extends Table {
  /// Ten-digit, zero-padded Central Index Key.
  TextColumn get cik => text()();
  TextColumn get name => text()();

  /// Standard Industrial Classification code, which is how SEC categorises a
  /// filer. Null where no dataset covering the company was found.
  IntColumn get sic => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {cik};
}

/// Ticker symbols, from SEC's directory. A filer often has several, and the
/// bulk company facts archive carries none — its files are named by CIK only.
@DataClassName('TickerRow')
class Tickers extends Table {
  TextColumn get symbol => text()();
  TextColumn get cik => text()();
  TextColumn get name => text()();

  @override
  Set<Column<Object>> get primaryKey => {symbol};
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

/// One fiscal quarter of figures for one filer, in whole US dollars.
///
/// Quarterly filings are thinner than annual ones, so nulls are common —
/// cash-flow lines in particular are often filed year-to-date.
@DataClassName('FiscalQuarterRow')
class FiscalQuarters extends Table {
  TextColumn get cik => text().references(Companies, #cik)();
  IntColumn get fiscalYear => integer()();
  IntColumn get quarter => integer()();
  RealColumn get revenue => real().nullable()();
  RealColumn get netIncome => real().nullable()();
  RealColumn get operatingCashFlow => real().nullable()();
  RealColumn get capitalExpenditure => real().nullable()();
  RealColumn get totalDebt => real().nullable()();
  RealColumn get cash => real().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {cik, fiscalYear, quarter};
}

/// A single row recording what the last completed bulk ingest loaded.
@DataClassName('IngestRunRow')
class IngestRuns extends Table {
  IntColumn get id => integer()();
  DateTimeColumn get completedAt => dateTime()();
  IntColumn get companyCount => integer()();
  IntColumn get extractorVersion => integer()();

  /// When SEC last rebuilt the archive this ingest loaded, from the download's
  /// `Last-Modified` header. Compared against a HEAD request to tell whether a
  /// newer archive is out.
  DateTimeColumn get archiveLastModified => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [Companies, Tickers, FiscalYears, FiscalQuarters, IngestRuns],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: _databaseName));

  /// Used by tests to run against an in-memory database.
  AppDatabase.forTesting(super.executor);

  /// Bump this whenever a table or column changes — adding a table without it
  /// leaves an existing database on the old schema, and queries against the new
  /// table fail with `no such table`.
  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      // An added column is worth migrating properly: rebuilding would cost a
      // 1.4 GB re-download for a field the app can live without.
      if (from == 2 && to == 3) {
        logInfo(() => 'Adding ingest_runs.archive_last_modified');
        await migrator.addColumn(ingestRuns, ingestRuns.archiveLastModified);
        return;
      }
      if (from == 3 && to == 4) {
        // Added, not populated: sectors appear after the next ingest.
        logInfo(() => 'Adding companies.sic');
        await migrator.addColumn(companies, companies.sic);
        return;
      }

      // Otherwise rebuild. Every table is a cache of one downloadable archive,
      // so nothing is lost that cannot be fetched again, and there are no
      // hand-written migrations to get subtly wrong. Dropping `ingest_runs`
      // with the rest is what makes the gate ask for a fresh ingest.
      logInfo(() => 'Rebuilding the database schema, v$from -> v$to');
      for (final entity in allSchemaEntities.toList().reversed) {
        await migrator.drop(entity);
      }
      await migrator.createAll();
    },
  );

  /// The years on file for [cik], oldest first.
  Future<List<FiscalYearRow>> yearsFor(String cik) {
    return (select(fiscalYears)
          ..where((row) => row.cik.equals(cik))
          ..orderBy([(row) => OrderingTerm.asc(row.fiscalYear)]))
        .get();
  }

  /// The quarters on file for [cik], oldest first.
  Future<List<FiscalQuarterRow>> quartersFor(String cik) {
    return (select(fiscalQuarters)
          ..where((row) => row.cik.equals(cik))
          ..orderBy([
            (row) => OrderingTerm.asc(row.fiscalYear),
            (row) => OrderingTerm.asc(row.quarter),
          ]))
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
  Future<void> recordIngest(int companyCount, {DateTime? archiveLastModified}) {
    return into(ingestRuns).insertOnConflictUpdate(
      IngestRunsCompanion.insert(
        id: const Value(1),
        completedAt: DateTime.now(),
        companyCount: companyCount,
        extractorVersion: extractorVersion,
        archiveLastModified: Value(archiveLastModified),
      ),
    );
  }

  /// The two ends of a [years]-long window for every company that reports
  /// [metric] at both ends, keyed by CIK.
  ///
  /// Computed in SQL because ranking ten thousand companies means touching
  /// every fiscal year they have on file; pulling those rows into Dart to do
  /// the same arithmetic would move megabytes for two numbers per company.
  Future<Map<String, GrowthSample>> growthSamples({
    required GrowthMetric metric,
    required int years,
  }) async {
    // A constant per metric, never anything caller-supplied.
    final value = switch (metric) {
      GrowthMetric.revenue => 'revenue',
      GrowthMetric.freeCashFlow =>
        '(operating_cash_flow - capital_expenditure)',
    };

    // The window ends at the company's latest fiscal year, whether or not it
    // reports this figure — the same year the report headlines. Picking the
    // latest year that happens to have a figure would rank a company on a
    // window its own report cannot corroborate.
    final rows = await customSelect(
      'WITH latest AS ('
      '  SELECT cik, MAX(fiscal_year) AS end_year FROM fiscal_years'
      '  GROUP BY cik'
      ') '
      'SELECT l.cik AS cik, '
      '  (SELECT $value FROM fiscal_years f '
      '     WHERE f.cik = l.cik AND f.fiscal_year = l.end_year) AS end_value, '
      '  (SELECT $value FROM fiscal_years f '
      '     WHERE f.cik = l.cik AND f.fiscal_year = l.end_year - ?1) '
      '     AS start_value '
      'FROM latest l',
      variables: [Variable.withInt(years)],
      readsFrom: {fiscalYears},
    ).get();

    return {
      for (final row in rows)
        row.read<String>('cik'): GrowthSample(
          startValue: row.readNullable<double>('start_value'),
          endValue: row.readNullable<double>('end_value'),
          years: years,
        ),
    };
  }

  /// The SIC code of every company that has one, keyed by CIK.
  Future<Map<String, int>> sicByCik() async {
    final rows =
        await (selectOnly(companies)
              ..addColumns([companies.cik, companies.sic])
              ..where(companies.sic.isNotNull()))
            .get();
    return {
      for (final row in rows)
        row.read(companies.cik)!: row.read(companies.sic)!,
    };
  }

  /// Every known symbol, ordered alphabetically.
  Future<List<TickerRow>> allTickers() {
    return (select(
      tickers,
    )..orderBy([(row) => OrderingTerm.asc(row.symbol)])).get();
  }

  Future<void> clearFinancials() async {
    await delete(fiscalQuarters).go();
    await delete(fiscalYears).go();
    await delete(companies).go();
    await delete(tickers).go();
    await delete(ingestRuns).go();
  }
}
