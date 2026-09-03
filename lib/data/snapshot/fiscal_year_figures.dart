import 'package:equatable/equatable.dart';
import 'package:pickstock/data/snapshot/period_figures.dart';
import 'package:pickstock/l10n/app_localizations.dart';

/// One fiscal year of figures, in whole US dollars as filed.
///
/// Every field is nullable: a company only has to tag the concepts its own
/// filings use, so any single line can legitimately be missing for a year.
class FiscalYearFigures extends Equatable implements PeriodFigures {
  const FiscalYearFigures({
    required this.fiscalYear,
    this.revenue,
    this.priorRevenue,
    this.netIncome,
    this.operatingCashFlow,
    this.capitalExpenditure,
    this.totalDebt,
    this.cash,
    this.dilutedShares,
    this.operatingIncome,
    this.depreciationAmortisation,
    this.totalAssets,
    this.shareholdersEquity,
    this.interestExpense,
  });

  final int fiscalYear;
  @override
  final double? revenue;

  /// Prior year's revenue, carried here so year-over-year growth stays a
  /// property of the year rather than something the UI has to look up.
  @override
  final double? priorRevenue;
  @override
  final double? netIncome;
  @override
  final double? operatingCashFlow;
  @override
  final double? capitalExpenditure;

  /// Long-term plus current debt, commercial paper and short-term borrowings.
  @override
  final double? totalDebt;
  @override
  final double? cash;

  /// Diluted shares for the year — the divisor earnings per share is struck
  /// against, so per-share figures line up with what the company reports.
  final double? dilutedShares;

  /// Profit from the business before interest, tax and one-offs.
  final double? operatingIncome;

  /// Depreciation and amortisation for the year.
  final double? depreciationAmortisation;

  final double? totalAssets;
  final double? shareholdersEquity;

  /// What the year's borrowings cost. `null` where the filer reported none of
  /// the interest concepts, which for a company with no debt is the usual
  /// case — see `XbrlMetric.interestExpense` for why the absence is read.
  final double? interestExpense;

  /// Operating profit as a percentage of revenue. The line that says whether
  /// growth is being bought or earned.
  double? get operatingMarginPercent {
    final profit = operatingIncome;
    final sales = revenue;
    if (profit == null || sales == null || sales <= 0) return null;
    return profit / sales * 100;
  }

  /// Capital spending against the depreciation it has to cover.
  ///
  /// Around 1 means the company is replacing what wears out. Well above it
  /// means it is building — which depresses free cash flow now for capacity
  /// later, and is the difference between Microsoft's capex and a decline.
  double? get capexToDepreciation {
    final capex = capitalExpenditure;
    final depreciation = depreciationAmortisation;
    if (capex == null || depreciation == null || depreciation <= 0) return null;
    return capex / depreciation;
  }

  /// Net income against the owners' capital.
  double? get returnOnEquityPercent {
    final profit = netIncome;
    final equity = shareholdersEquity;
    if (profit == null || equity == null || equity <= 0) return null;
    return profit / equity * 100;
  }

  /// Operating cash flow less capital expenditure.
  @override
  double? get freeCashFlow {
    final operating = operatingCashFlow;
    final capex = capitalExpenditure;
    if (operating == null || capex == null) return null;
    return operating - capex;
  }

  /// Total debt less cash. Negative means the company holds more cash than
  /// debt — a net cash position.
  @override
  double? get netDebt {
    final debt = totalDebt;
    final held = cash;
    if (debt == null || held == null) return null;
    return debt - held;
  }

  /// Year-over-year revenue growth as a percentage, or `null` when either
  /// year is missing or the base year is zero.
  @override
  double? get revenueGrowthPercent {
    final current = revenue;
    final previous = priorRevenue;
    if (current == null || previous == null || previous == 0) return null;
    return (current - previous) / previous * 100;
  }

  @override
  String getPeriodLabel(AppLocalizations strings) =>
      '${strings.labelFiscalYear}$fiscalYear';

  bool get isProfitable => (netIncome ?? 0) >= 0;

  bool get holdsNetCash => (netDebt ?? 0) < 0;

  /// Whether the year shows no borrowings at all.
  ///
  /// A debt line of zero and no debt line whatsoever both qualify — a company
  /// that owes nothing has nothing to tag — but only alongside an interest
  /// expense that is absent or zero. Interest without debt means the
  /// borrowings are real and filed under a concept the parser cannot see, and
  /// EDGAR is full of those.
  bool get isDebtFree =>
      (totalDebt ?? 0) == 0 &&
      (interestExpense ?? 0) == 0 &&
      // A filing with no balance sheet in it says nothing either way.
      totalAssets != null;

  @override
  List<Object?> get props => [
    fiscalYear,
    revenue,
    priorRevenue,
    netIncome,
    operatingCashFlow,
    capitalExpenditure,
    totalDebt,
    cash,
    dilutedShares,
    operatingIncome,
    depreciationAmortisation,
    totalAssets,
    shareholdersEquity,
    interestExpense,
  ];
}
