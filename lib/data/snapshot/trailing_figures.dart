import 'package:equatable/equatable.dart';

/// The twelve months to the newest quarterly report, where it is newer than
/// the annual one.
///
/// By the time a December filer's third-quarter 10-Q lands, its 10-K is ten
/// months old: the revenue a valuation scales its margin by is a year stale,
/// and the cash and debt can have moved by a sale, a buyback or a bond issue
/// since. This is what the filings say now.
///
/// Flows are read the standard way — the last full year, plus this year to
/// date, less the same months a year earlier, which a 10-Q states beside its
/// own — so a cash-flow line a filer only ever reports year-to-date is read as
/// well as one it reports by quarter. Balance-sheet lines are as at the
/// quarter end.
///
/// Only what the valuation reads from the quarter is kept: the revenue its
/// typical margin is applied to, the cash and debt, and the diluted share
/// count. The margins and the growth stay the years', so the quarter's
/// earnings and cash flows are not carried.
///
/// Every line is nullable, as in a fiscal year, and for one more reason: a
/// line whose three pieces are not all on file is left out rather than taken
/// from somewhere else.
class TrailingFigures extends Equatable {
  const TrailingFigures({
    required this.periodEnd,
    required this.fiscalYear,
    required this.quarter,
    this.revenue,
    this.totalDebt,
    this.cash,
    this.dilutedShares,
  });

  /// The last day of the newest quarter.
  final DateTime periodEnd;

  /// The fiscal year and quarter that quarter is, as the filer numbers them.
  final int fiscalYear;
  final int quarter;

  final double? revenue;

  /// Borrowings and leases at the quarter end, summed as a fiscal year sums
  /// them. `null` where the quarter's balance sheet is missing a line the
  /// annual one carried — see `CompanyFactsParser.parseTrailing`.
  final double? totalDebt;
  final double? cash;

  /// Diluted average shares over the year to date.
  final double? dilutedShares;

  /// Total debt less cash, or `null` where either is missing.
  double? get netDebt {
    final debt = totalDebt;
    final held = cash;
    if (debt == null || held == null) return null;
    return debt - held;
  }

  @override
  List<Object?> get props => [
    periodEnd,
    fiscalYear,
    quarter,
    revenue,
    totalDebt,
    cash,
    dilutedShares,
  ];
}
