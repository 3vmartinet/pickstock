import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:pickstock/data/snapshot/growth_metric.dart';
import 'package:pickstock/extensions/object_extensions.dart';

part 'app_database.g.dart';

/// Bumped whenever the XBRL extraction changes meaning. Rows written by an
/// older extractor are discarded rather than served, because a stale row is
/// indistinguishable from a correct one once it is in the table.
const int extractorVersion = 7;

/// The starred list is seeded rather than special-cased, so it needs a name
/// before the localisations exist. Renaming it is allowed; it is a list.
const String defaultWatchlistName = 'Favourites';
const int defaultWatchlistColourIndex = 0;

/// Long enough for a descriptive name, short enough to fit a chip.
const int watchlistNameMaxLength = 40;

/// A report's name carries a filter and a date, so it needs more room.
const int reportNameMaxLength = 80;

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

  /// Shares on the cover of the newest filing, for a market value.
  RealColumn get sharesOutstanding => real().nullable()();

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
  RealColumn get dilutedShares => real().nullable()();
  RealColumn get operatingIncome => real().nullable()();
  RealColumn get depreciationAmortisation => real().nullable()();
  RealColumn get totalAssets => real().nullable()();
  RealColumn get shareholdersEquity => real().nullable()();

  /// What the year's borrowings cost. Read for its absence: it is how a
  /// company with no debt line is told from one whose debt is filed under a
  /// concept the parser cannot see.
  RealColumn get interestExpense => real().nullable()();

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

/// The last share price entered for a company.
///
/// Unlike every other table this is not a cache of the archive: PickStock ships
/// no market data, so the price is the user's own input and is the one thing a
/// schema rebuild must not throw away.
@DataClassName('SharePriceRow')
class SharePrices extends Table {
  TextColumn get cik => text()();
  RealColumn get pricePerShare => real()();

  /// When the price was true: the exchange timestamp for a quoted price, or
  /// when it was typed for an entered one.
  DateTimeColumn get asOf => dateTime()();

  /// Whether a provider quoted this price. A stale quote and a typed guess are
  /// both prices, and the report must not present them as the same thing.
  BoolColumn get isQuoted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {cik};
}

/// One finished screen of undervalued companies, kept so a run that took
/// three quarters of an hour is not lost when the app closes.
///
/// User data like [Watchlists]: it cannot be downloaded again, so it sits out a
/// schema rebuild.
@DataClassName('ReportRow')
class Reports extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Renameable, and seeded from whatever the directory was filtered to.
  TextColumn get name => text().withLength(min: 1, max: reportNameMaxLength)();

  DateTimeColumn get createdAt => dateTime()();

  /// How many companies the run looked at, against how many it could value.
  IntColumn get consideredCount => integer()();
  IntColumn get valuedCount => integer()();
}

/// One undervalued company as the report found it.
///
/// The figures are copied rather than referenced: a report is a record of what
/// was true when it ran, and prices move.
@DataClassName('ReportEntryRow')
class ReportEntries extends Table {
  IntColumn get reportId =>
      integer().references(Reports, #id, onDelete: KeyAction.cascade)();
  TextColumn get cik => text()();
  TextColumn get ticker => text()();
  TextColumn get name => text()();
  RealColumn get pricePerShare => real()();
  RealColumn get fairValueLow => real()();
  RealColumn get fairValueHigh => real()();

  /// How far the price would have to rise to reach the bottom of the range.
  RealColumn get upsidePercent => real()();

  @override
  Set<Column<Object>> get primaryKey => {reportId, cik};
}

/// Small choices the app remembers between launches: the theme, and whatever
/// the directory was last filtered and ordered by.
///
/// A key/value table rather than a column per setting, because each new one
/// would otherwise be a migration. User data like [SharePrices], so it sits out
/// a schema rebuild.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// A named list of companies the user is following.
///
/// User data, like [SharePrices] and unlike everything else here, so it sits
/// out a schema rebuild rather than being dropped with the caches.
@DataClassName('WatchlistRow')
class Watchlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name =>
      text().withLength(min: 1, max: watchlistNameMaxLength)();

  /// An index into the palette in `ThemeRepo`, not a colour value: the palette
  /// has to change with the theme, so storing an ARGB int would pin a list to
  /// one appearance for ever.
  IntColumn get colourIndex => integer()();

  /// The list every star goes into. Seeded once, cannot be deleted, and sorts
  /// first. Making favourites an ordinary list keeps one mechanism instead of
  /// a flag beside a table that does the same job.
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();
}

/// One company's membership of one list.
@DataClassName('WatchlistEntryRow')
class WatchlistEntries extends Table {
  IntColumn get watchlistId =>
      integer().references(Watchlists, #id, onDelete: KeyAction.cascade)();
  TextColumn get cik => text()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {watchlistId, cik};
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
  tables: [
    Companies,
    Tickers,
    FiscalYears,
    FiscalQuarters,
    IngestRuns,
    SharePrices,
    Watchlists,
    WatchlistEntries,
    Settings,
    Reports,
    ReportEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: _databaseName));

  /// Used by tests to run against an in-memory database.
  AppDatabase.forTesting(super.executor);

  /// Bump this whenever a table or column changes — adding a table without it
  /// leaves an existing database on the old schema, and queries against the new
  /// table fail with `no such table`.
  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      // Every version from 2 on is reachable by additive steps, applied in
      // order for whatever range is being crossed. Worth the care: rebuilding
      // costs a 1.7 GB re-download for columns the app can live without, and
      // matching exact version pairs meant the next bump silently fell through
      // to the rebuild.
      if (from >= 2) {
        if (from < 3) {
          logInfo(() => 'Adding ingest_runs.archive_last_modified');
          await migrator.addColumn(ingestRuns, ingestRuns.archiveLastModified);
        }
        if (from < 4) {
          // Added, not populated: sectors appear after the next ingest.
          logInfo(() => 'Adding companies.sic');
          await migrator.addColumn(companies, companies.sic);
        }
        if (from < 5) {
          // Added, not populated: share counts appear after the next ingest.
          logInfo(() => 'Adding share counts and share_prices');
          await migrator.addColumn(companies, companies.sharesOutstanding);
          await migrator.addColumn(fiscalYears, fiscalYears.dilutedShares);
          // Created at today's definition, so the v6 step below is already
          // covered for anything upgrading from before v5.
          await migrator.createTable(sharePrices);
        } else if (from < 6) {
          logInfo(() => 'Teaching share_prices where a price came from');
          await migrator.renameColumn(
            sharePrices,
            'entered_at',
            sharePrices.asOf,
          );
          await migrator.addColumn(sharePrices, sharePrices.isQuoted);
        }
        if (from < 11) {
          // Added, not populated: the figure arrives with the next ingest,
          // which the extractor version already insists on.
          logInfo(() => 'Adding fiscal_years.interest_expense');
          await migrator.addColumn(fiscalYears, fiscalYears.interestExpense);
        }
        if (from < 10) {
          logInfo(() => 'Adding reports');
          await migrator.createTable(reports);
          await migrator.createTable(reportEntries);
        }
        if (from < 9) {
          logInfo(() => 'Adding settings');
          await migrator.createTable(settings);
        }
        if (from < 8) {
          logInfo(() => 'Adding watchlists');
          await migrator.createTable(watchlists);
          await migrator.createTable(watchlistEntries);
          await _seedDefaultWatchlist();
        }
        if (from < 7) {
          // Added, not populated: these arrive with the next ingest, which the
          // extractor version already insists on.
          logInfo(() => 'Adding margin and capital columns');
          await migrator.addColumn(fiscalYears, fiscalYears.operatingIncome);
          await migrator.addColumn(
            fiscalYears,
            fiscalYears.depreciationAmortisation,
          );
          await migrator.addColumn(fiscalYears, fiscalYears.totalAssets);
          await migrator.addColumn(fiscalYears, fiscalYears.shareholdersEquity);
        }
        return;
      }

      // Otherwise rebuild. Every table is a cache of one downloadable archive,
      // so nothing is lost that cannot be fetched again, and there are no
      // hand-written migrations to get subtly wrong. Dropping `ingest_runs`
      // with the rest is what makes the gate ask for a fresh ingest.
      logInfo(() => 'Rebuilding the database schema, v$from -> v$to');
      for (final entity in allSchemaEntities.toList().reversed) {
        // Entered prices and watchlists are the user's own and cannot be
        // downloaded again, so they sit out the rebuild. `createAll` below
        // creates only what is missing.
        if (entity == sharePrices ||
            entity == watchlists ||
            entity == watchlistEntries ||
            entity == settings ||
            entity == reports ||
            entity == reportEntries) {
          continue;
        }
        await migrator.drop(entity);
      }
      await migrator.createAll();
      await _seedDefaultWatchlist();
    },
    beforeOpen: (details) async {
      // Foreign keys are off by default in SQLite, and without them deleting a
      // list would leave its entries behind for ever.
      await customStatement('PRAGMA foreign_keys = ON');
      if (details.wasCreated) await _seedDefaultWatchlist();
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
    bool unbrokenOnly = false,
  }) async {
    // A constant per metric and per table alias, never anything
    // caller-supplied.
    String valueOf(String alias) => switch (metric) {
      GrowthMetric.revenue => '$alias.revenue',
      GrowthMetric.freeCashFlow =>
        '($alias.operating_cash_flow - $alias.capital_expenditure)',
    };

    // The window ends at the company's latest fiscal year, whether or not it
    // reports this figure — the same year the report headlines. Picking the
    // latest year that happens to have a figure would rank a company on a
    // window its own report cannot corroborate.
    //
    // `rising_steps` counts the year-on-year steps inside the window that went
    // up. An unbroken run needs every step in the window present and every one
    // of them rising, so a gap in the filings breaks the run rather than being
    // read through.
    final rows = await customSelect(
      'WITH latest AS ('
      '  SELECT cik, MAX(fiscal_year) AS end_year FROM fiscal_years'
      '  GROUP BY cik'
      ') '
      'SELECT l.cik AS cik, '
      '  (SELECT ${valueOf('f')} FROM fiscal_years f '
      '     WHERE f.cik = l.cik AND f.fiscal_year = l.end_year) AS end_value, '
      '  (SELECT ${valueOf('f')} FROM fiscal_years f '
      '     WHERE f.cik = l.cik AND f.fiscal_year = l.end_year - ?1) '
      '     AS start_value, '
      '  (SELECT COUNT(*) FROM fiscal_years f '
      '     JOIN fiscal_years p '
      '       ON p.cik = f.cik AND p.fiscal_year = f.fiscal_year - 1 '
      '    WHERE f.cik = l.cik '
      '      AND f.fiscal_year > l.end_year - ?1 '
      '      AND f.fiscal_year <= l.end_year '
      '      AND ${valueOf('f')} IS NOT NULL '
      '      AND ${valueOf('p')} IS NOT NULL '
      '      AND ${valueOf('f')} > ${valueOf('p')}) AS rising_steps '
      'FROM latest l',
      variables: [Variable.withInt(years)],
      readsFrom: {fiscalYears},
    ).get();

    return {
      for (final row in rows)
        row.read<String>('cik'): GrowthSample(
          // A broken run is unrankable under this ordering rather than badly
          // ranked: without a start value no rate can be stated, which is how
          // every other gap in the filings already behaves.
          startValue: unbrokenOnly && row.read<int>('rising_steps') < years
              ? null
              : row.readNullable<double>('start_value'),
          endValue: row.readNullable<double>('end_value'),
          years: years,
        ),
    };
  }

  /// The companies whose latest filed year shows no borrowings.
  ///
  /// Debt-free is read as: nothing owed on the balance sheet — either a debt
  /// line of zero or no debt line at all, since a company that owes nothing
  /// has nothing to tag — and no interest expense to service any. The second
  /// half is what makes the first half safe. Ford, Berkshire and KKR report
  /// their borrowings under concepts the parser cannot see and would
  /// otherwise all read as debt-free; their interest gives them away.
  ///
  /// A balance sheet has to be there at all (`total_assets`), so a filing
  /// thin enough to say nothing is not read as saying no.
  ///
  /// Two filers still slip through — Textron and NVR report both their debt
  /// and their interest only inside dimensioned segment facts, which the bulk
  /// company facts archive does not carry at all. There is nothing in the
  /// archive to catch them with.
  ///
  /// Computed in SQL for the same reason [growthSamples] is: the answer
  /// covers the whole directory, and the alternative is reading every
  /// company's every fiscal year into Dart to look at one of them.
  Future<Set<String>> debtFreeCiks() async {
    final rows = await customSelect(
      'WITH latest AS ('
      '  SELECT cik, MAX(fiscal_year) AS end_year FROM fiscal_years'
      '  GROUP BY cik'
      ') '
      'SELECT f.cik AS cik FROM fiscal_years f '
      'JOIN latest l ON l.cik = f.cik AND l.end_year = f.fiscal_year '
      'WHERE COALESCE(f.total_debt, 0) = 0 '
      '  AND COALESCE(f.interest_expense, 0) = 0 '
      '  AND f.total_assets IS NOT NULL',
      readsFrom: {fiscalYears},
    ).get();
    return {for (final row in rows) row.read<String>('cik')};
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

  /// Creates the starred list once, on a database that has none.
  Future<void> _seedDefaultWatchlist() async {
    final existing = await (select(
      watchlists,
    )..where((row) => row.isDefault.equals(true))).getSingleOrNull();
    if (existing != null) return;
    await into(watchlists).insert(
      WatchlistsCompanion.insert(
        name: defaultWatchlistName,
        colourIndex: defaultWatchlistColourIndex,
        isDefault: const Value(true),
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Every list with the number of companies in it, the starred one first and
  /// the rest oldest first.
  ///
  /// Counted in SQL rather than by reading the membership separately, so the
  /// two cannot disagree.
  Future<List<({WatchlistRow list, int companyCount})>> allWatchlists() {
    final count = watchlistEntries.cik.count();
    final query =
        select(watchlists).join([
            leftOuterJoin(
              watchlistEntries,
              watchlistEntries.watchlistId.equalsExp(watchlists.id),
            ),
          ])
          ..addColumns([count])
          ..groupBy([watchlists.id])
          ..orderBy([
            OrderingTerm.desc(watchlists.isDefault),
            OrderingTerm.asc(watchlists.id),
          ]);

    return query.get().then(
      (rows) => [
        for (final row in rows)
          (list: row.readTable(watchlists), companyCount: row.read(count) ?? 0),
      ],
    );
  }

  /// Which companies are in which list.
  Future<Map<int, Set<String>>> watchlistMembership() async {
    final rows = await select(watchlistEntries).get();
    final membership = <int, Set<String>>{};
    for (final row in rows) {
      (membership[row.watchlistId] ??= <String>{}).add(row.cik);
    }
    return membership;
  }

  Future<int> createWatchlist(String name, int colourIndex) {
    return into(watchlists).insert(
      WatchlistsCompanion.insert(
        name: name,
        colourIndex: colourIndex,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> renameWatchlist(int id, String name, int colourIndex) {
    return (update(watchlists)..where((row) => row.id.equals(id))).write(
      WatchlistsCompanion(name: Value(name), colourIndex: Value(colourIndex)),
    );
  }

  /// Removes a list and, through the cascade, everything in it.
  Future<void> deleteWatchlist(int id) {
    return (delete(watchlists)..where((row) => row.id.equals(id))).go();
  }

  Future<void> addToWatchlist(int watchlistId, String cik) {
    return into(watchlistEntries).insertOnConflictUpdate(
      WatchlistEntriesCompanion.insert(
        watchlistId: watchlistId,
        cik: cik,
        addedAt: DateTime.now(),
      ),
    );
  }

  Future<void> removeFromWatchlist(int watchlistId, String cik) {
    return (delete(watchlistEntries)..where(
          (row) => row.watchlistId.equals(watchlistId) & row.cik.equals(cik),
        ))
        .go();
  }

  /// Every saved report, newest first, without their entries.
  Future<List<ReportRow>> allReports() {
    return (select(
      reports,
    )..orderBy([(row) => OrderingTerm.desc(row.createdAt)])).get();
  }

  /// One report's companies, most undervalued first.
  Future<List<ReportEntryRow>> entriesForReport(int reportId) {
    return (select(reportEntries)
          ..where((row) => row.reportId.equals(reportId))
          ..orderBy([(row) => OrderingTerm.desc(row.upsidePercent)]))
        .get();
  }

  /// Stores a finished run and everything it found, in one transaction: a
  /// report without its entries would look like a run that found nothing.
  ///
  /// Entries replace on conflict rather than failing. A company reached twice
  /// in one run is a bug in the run, not a reason to throw away forty minutes
  /// of work at the moment it finishes.
  Future<int> saveReport({
    required String name,
    required int consideredCount,
    required int valuedCount,
    required List<ReportEntriesCompanion> entries,
  }) {
    return transaction(() async {
      final id = await into(reports).insert(
        ReportsCompanion.insert(
          name: name,
          createdAt: DateTime.now(),
          consideredCount: consideredCount,
          valuedCount: valuedCount,
        ),
      );
      await batch(
        (batch) => batch.insertAll(reportEntries, [
          for (final entry in entries) entry.copyWith(reportId: Value(id)),
        ], mode: InsertMode.insertOrReplace),
      );
      return id;
    });
  }

  Future<void> renameReport(int id, String name) {
    return (update(reports)..where((row) => row.id.equals(id))).write(
      ReportsCompanion(name: Value(name)),
    );
  }

  /// Removes a report and, through the cascade, its entries.
  Future<void> deleteReport(int id) {
    return (delete(reports)..where((row) => row.id.equals(id))).go();
  }

  /// Every remembered setting, as one read at startup.
  Future<Map<String, String>> allSettings() async {
    final rows = await select(settings).get();
    return {for (final row in rows) row.key: row.value};
  }

  Future<void> saveSetting(String key, String value) {
    return into(
      settings,
    ).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
  }

  Future<void> clearSetting(String key) {
    return (delete(settings)..where((row) => row.key.equals(key))).go();
  }

  /// The price last entered for [cik], or `null` if none has been.
  Future<SharePriceRow?> priceFor(String cik) {
    return (select(
      sharePrices,
    )..where((row) => row.cik.equals(cik))).getSingleOrNull();
  }

  /// Records a price for [cik], replacing any earlier entry.
  Future<void> savePrice(
    String cik, {
    required double pricePerShare,
    required DateTime asOf,
    required bool isQuoted,
  }) {
    return into(sharePrices).insertOnConflictUpdate(
      SharePricesCompanion.insert(
        cik: cik,
        pricePerShare: pricePerShare,
        asOf: asOf,
        isQuoted: Value(isQuoted),
      ),
    );
  }

  /// Forgets the price entered for [cik].
  Future<void> clearPrice(String cik) {
    return (delete(sharePrices)..where((row) => row.cik.equals(cik))).go();
  }

  Future<void> clearFinancials() async {
    await delete(fiscalQuarters).go();
    await delete(fiscalYears).go();
    await delete(companies).go();
    await delete(tickers).go();
    await delete(ingestRuns).go();
  }
}
