import 'package:equatable/equatable.dart';

/// One fiscal year of figures, in whole US dollars as filed.
///
/// Every field is nullable: a company only has to tag the concepts its own
/// filings use, so any single line can legitimately be missing for a year.
class FiscalYearFigures extends Equatable {
  const FiscalYearFigures({
    required this.fiscalYear,
    this.revenue,
    this.priorRevenue,
    this.netIncome,
    this.operatingCashFlow,
    this.capitalExpenditure,
    this.totalDebt,
    this.cash,
  });

  final int fiscalYear;
  final double? revenue;

  /// Prior year's revenue, carried here so year-over-year growth stays a
  /// property of the year rather than something the UI has to look up.
  final double? priorRevenue;
  final double? netIncome;
  final double? operatingCashFlow;
  final double? capitalExpenditure;

  /// Long-term plus current debt, commercial paper and short-term borrowings.
  final double? totalDebt;
  final double? cash;

  /// Operating cash flow less capital expenditure.
  double? get freeCashFlow {
    final operating = operatingCashFlow;
    final capex = capitalExpenditure;
    if (operating == null || capex == null) return null;
    return operating - capex;
  }

  /// Total debt less cash. Negative means the company holds more cash than
  /// debt — a net cash position.
  double? get netDebt {
    final debt = totalDebt;
    final held = cash;
    if (debt == null || held == null) return null;
    return debt - held;
  }

  /// Year-over-year revenue growth as a percentage, or `null` when either
  /// year is missing or the base year is zero.
  double? get revenueGrowthPercent {
    final current = revenue;
    final previous = priorRevenue;
    if (current == null || previous == null || previous == 0) return null;
    return (current - previous) / previous * 100;
  }

  bool get isProfitable => (netIncome ?? 0) >= 0;

  bool get holdsNetCash => (netDebt ?? 0) < 0;

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
  ];
}
