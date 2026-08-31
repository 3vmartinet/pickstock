import 'package:pickstock/l10n/app_localizations.dart';

/// One reporting period's figures, whether a fiscal year or a quarter.
///
/// The report renders annual and quarterly history through the same table, so
/// both shapes answer the same questions and only their labels differ.
abstract interface class PeriodFigures {
  /// How the period reads in a heading, e.g. `FY2025` or `Q2 FY2027`.
  String getPeriodLabel(AppLocalizations strings);

  double? get revenue;

  /// Revenue for the period this one is compared against: the previous fiscal
  /// year, or the same quarter a year earlier.
  double? get priorRevenue;

  double? get netIncome;
  double? get operatingCashFlow;
  double? get capitalExpenditure;
  double? get totalDebt;
  double? get cash;

  /// Operating cash flow less capital expenditure.
  double? get freeCashFlow;

  /// Total debt less cash; negative means a net cash position.
  double? get netDebt;

  /// Revenue growth against [priorRevenue], as a percentage.
  double? get revenueGrowthPercent;
}
