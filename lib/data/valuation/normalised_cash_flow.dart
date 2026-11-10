import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/valuation/cash_flow_model.dart';

/// The cash a business ordinarily throws off, read across its years rather
/// than off the last one.
///
/// One year is a poor anchor. Microsoft spent 63% of its operating cash flow
/// on capital projects in FY2026 and Coca-Cola paid a one-off tax deposit in
/// 2025, each roughly halving reported free cash flow without changing what
/// the business earns; against a $96 share, Coca-Cola's one bad year valued
/// it at $19 to $26. So the stream every valuation discounts is the median
/// free cash flow margin over the last decade, applied to the latest revenue
/// — the twelve months to the newest quarter where one is on file.
///
/// After stock pay. The cash flow statement adds it back because no cash
/// left the building, which is true and beside the point: the shares were
/// printed, and every holder owns a little less for it. Taken off year by
/// year, before the median, so a company that always pays a fifth of its
/// cash in shares is read as one that keeps four fifths.
///
/// Shared by the fair-value band and the expectations tab, so the two cannot
/// discount different streams for the same company.
class NormalisedCashFlow {
  const NormalisedCashFlow._({
    required this.flow,
    required this.marginPercent,
    required this.reported,
    required this.yearsRead,
  });

  /// The median margin applied to the latest revenue, or the latest year
  /// alone where a filer reports no revenue to normalise against — in which
  /// case [yearsRead] is one.
  final double flow;

  /// The median free cash flow margin after stock pay, in percent, or `null`
  /// where no revenue was on file to measure one against.
  final double? marginPercent;

  /// The latest year's free cash flow after stock pay as filed, which is
  /// what the normalised figure replaces. `null` where the latest year
  /// reports none.
  final double? reported;

  /// How many years the median was read over.
  final int yearsRead;

  /// Whether the figure is a median rather than the single year on file.
  bool get isNormalised => yearsRead > 1;

  /// How far the reported year sits from the normalised base, as a
  /// percentage, or `null` where there is nothing to compare.
  double? get normalisationEffectPercent {
    final latest = reported;
    if (latest == null || flow <= 0 || !isNormalised) return null;
    return (latest - flow) / flow * 100;
  }

  /// Reads the stream off [snapshot], or `null` where the filings carry no
  /// cash flow at all.
  static NormalisedCashFlow? of(FinancialSnapshot snapshot) {
    final years = snapshot.years;
    final latest = snapshot.latest;
    final reported = latest.freeCashFlowAfterStockPay;
    // What it sells today: the twelve months to the newest quarter where a
    // 10-Q is newer than the annual report. The margin is a decade's; the
    // scale it is applied to should be now's.
    final revenue = snapshot.trailing?.revenue ?? latest.revenue;

    final window = years.length > CashFlowModel.horizon
        ? years.sublist(years.length - CashFlowModel.horizon)
        : years;
    final margins = <double>[
      for (final year in window)
        if (year.revenue case final sales? when sales > 0)
          if (year.freeCashFlowAfterStockPay case final cash?) cash / sales,
    ]..sort();

    if (revenue == null || revenue <= 0 || margins.isEmpty) {
      // Nothing to normalise against: the year as filed, or nothing.
      if (reported == null) return null;
      return NormalisedCashFlow._(
        flow: reported,
        marginPercent: null,
        reported: reported,
        yearsRead: 1,
      );
    }

    // The median, not the mean: one disastrous year should not drag the base
    // down for a decade, nor one exceptional year hold it up.
    final margin = margins[margins.length ~/ 2];
    return NormalisedCashFlow._(
      flow: margin * revenue,
      marginPercent: margin * 100,
      reported: reported,
      yearsRead: margins.length,
    );
  }
}
