import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/fiscal_quarter_figures.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/sec/sec_repo.dart';
import 'package:pickstock/repo/sec/ticker_directory_repo.dart';

AppDatabase get _database => GetIt.I.get<AppDatabase>();
TickerDirectoryRepo get _tickerDirectoryRepo =>
    GetIt.I.get<TickerDirectoryRepo>();

/// How many fiscal years a report shows, newest last.
const int reportedYears = 10;

/// How many quarters a report shows. Two years is enough to see a trend
/// without the table becoming a wall of rows.
const int reportedQuarters = 8;

/// Serves snapshots from the local database populated by the bulk ingest.
///
/// No network: everything the app reports comes from the one archive
/// downloaded by [BulkIngestRepo].
class LocalSecRepo implements SecRepo {
  const LocalSecRepo();

  @override
  Future<FinancialSnapshot> fetchSnapshot(String ticker) async {
    // The bundled directory maps symbols to CIKs; the archive is keyed by CIK
    // and carries no ticker of its own.
    final listing = _tickerDirectoryRepo.lookup(ticker);
    if (listing == null) throw const SecException(SecFailure.unknownTicker);

    if (await _database.lastIngest() == null) {
      throw const SecException(SecFailure.databaseEmpty);
    }

    final rows = await _database.yearsFor(listing.cik);
    if (rows.isEmpty) throw const SecException(SecFailure.noAnnualData);

    final quarterRows = await _database.quartersFor(listing.cik);

    final stored = await _database.companyFor(listing.cik);
    final reported = rows.length > reportedYears
        ? rows.sublist(rows.length - reportedYears)
        : rows;

    return FinancialSnapshot(
      company: Company(
        ticker: listing.ticker,
        cik: listing.cik,
        // The registrant name as filed is more current than the directory's.
        name: stored?.name ?? listing.name,
        sic: stored?.sic,
        sharesOutstanding: stored?.sharesOutstanding,
        sharesLastFiled: stored?.sharesLastFiled,
      ),
      years: [
        for (final row in reported)
          FiscalYearFigures(
            fiscalYear: row.fiscalYear,
            revenue: row.revenue,
            // Growth needs the year before, which may sit outside the window.
            priorRevenue: rows
                .where((other) => other.fiscalYear == row.fiscalYear - 1)
                .firstOrNull
                ?.revenue,
            netIncome: row.netIncome,
            operatingCashFlow: row.operatingCashFlow,
            capitalExpenditure: row.capitalExpenditure,
            totalDebt: row.totalDebt,
            cash: row.cash,
            dilutedShares: row.dilutedShares,
            operatingIncome: row.operatingIncome,
            depreciationAmortisation: row.depreciationAmortisation,
            totalAssets: row.totalAssets,
            shareholdersEquity: row.shareholdersEquity,
            interestExpense: row.interestExpense,
            profitLoss: row.profitLoss,
          ),
      ],
      quarters: _quartersFrom(quarterRows),
    );
  }

  /// The most recent quarters, each carrying the same quarter a year earlier so
  /// growth is like-for-like even at the edge of the window.
  List<FiscalQuarterFigures> _quartersFrom(List<FiscalQuarterRow> rows) {
    final reported = rows.length > reportedQuarters
        ? rows.sublist(rows.length - reportedQuarters)
        : rows;

    return [
      for (final row in reported)
        FiscalQuarterFigures(
          fiscalYear: row.fiscalYear,
          quarter: row.quarter,
          revenue: row.revenue,
          priorRevenue: rows
              .where(
                (other) =>
                    other.fiscalYear == row.fiscalYear - 1 &&
                    other.quarter == row.quarter,
              )
              .firstOrNull
              ?.revenue,
          netIncome: row.netIncome,
          operatingCashFlow: row.operatingCashFlow,
          capitalExpenditure: row.capitalExpenditure,
          totalDebt: row.totalDebt,
          cash: row.cash,
        ),
    ];
  }
}
