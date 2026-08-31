import 'package:equatable/equatable.dart';
import 'package:pickstock/data/snapshot/period_figures.dart';
import 'package:pickstock/l10n/app_localizations.dart';

/// One fiscal quarter of figures, in whole US dollars as filed.
///
/// Quarterly filings are thinner than annual ones — cash-flow lines in
/// particular are often reported year-to-date rather than for the quarter — so
/// every field stays nullable and the UI shows what is actually there.
class FiscalQuarterFigures extends Equatable implements PeriodFigures {
  const FiscalQuarterFigures({
    required this.fiscalYear,
    required this.quarter,
    this.revenue,
    this.priorRevenue,
    this.netIncome,
    this.operatingCashFlow,
    this.capitalExpenditure,
    this.totalDebt,
    this.cash,
  });

  final int fiscalYear;

  /// 1 to 4, as the company numbers its own quarters.
  final int quarter;

  @override
  final double? revenue;

  /// The same quarter a year earlier, which is the comparison that means
  /// something for a seasonal business — not the quarter just gone.
  @override
  final double? priorRevenue;

  @override
  final double? netIncome;
  @override
  final double? operatingCashFlow;
  @override
  final double? capitalExpenditure;
  @override
  final double? totalDebt;
  @override
  final double? cash;

  @override
  String getPeriodLabel(AppLocalizations strings) =>
      strings.labelQuarterOfYear(quarter, fiscalYear);

  @override
  double? get freeCashFlow {
    final operating = operatingCashFlow;
    final capex = capitalExpenditure;
    if (operating == null || capex == null) return null;
    return operating - capex;
  }

  @override
  double? get netDebt {
    final debt = totalDebt;
    final held = cash;
    if (debt == null || held == null) return null;
    return debt - held;
  }

  @override
  double? get revenueGrowthPercent {
    final current = revenue;
    final previous = priorRevenue;
    if (current == null || previous == null || previous == 0) return null;
    return (current - previous) / previous * 100;
  }

  @override
  List<Object?> get props => [
    fiscalYear,
    quarter,
    revenue,
    priorRevenue,
    netIncome,
    operatingCashFlow,
    capitalExpenditure,
    totalDebt,
    cash,
  ];
}
