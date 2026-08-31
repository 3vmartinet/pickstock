import 'package:equatable/equatable.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/fiscal_quarter_figures.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';

/// A company plus the handful of fiscal years PickStock reports on.
class FinancialSnapshot extends Equatable {
  const FinancialSnapshot({
    required this.company,
    required this.years,
    this.quarters = const [],
  });

  final Company company;

  /// Oldest fiscal year first; never empty.
  final List<FiscalYearFigures> years;

  /// Oldest quarter first. Empty where a filer reports nothing quarterly.
  final List<FiscalQuarterFigures> quarters;

  /// The most recent fiscal year on file.
  FiscalYearFigures get latest => years.last;

  @override
  List<Object?> get props => [company, years, quarters];
}
