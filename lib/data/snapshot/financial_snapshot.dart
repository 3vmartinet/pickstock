import 'package:equatable/equatable.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/fiscal_quarter_figures.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/snapshot/trailing_figures.dart';

/// A company plus the handful of fiscal years PickStock reports on.
class FinancialSnapshot extends Equatable {
  const FinancialSnapshot({
    required this.company,
    required this.years,
    this.quarters = const [],
    this.trailing,
  });

  final Company company;

  /// Oldest fiscal year first; never empty.
  final List<FiscalYearFigures> years;

  /// Oldest quarter first. Empty where a filer reports nothing quarterly.
  final List<FiscalQuarterFigures> quarters;

  /// The twelve months to the newest 10-Q, where it is newer than the 10-K.
  ///
  /// Read only for what a valuation needs to be current — the revenue the
  /// typical margin is applied to, the cash and debt, the share count. The
  /// margins and the growth are read off full years, which is what makes
  /// them typical.
  final TrailingFigures? trailing;

  /// The most recent fiscal year on file.
  FiscalYearFigures get latest => years.last;

  @override
  List<Object?> get props => [company, years, quarters, trailing];
}
