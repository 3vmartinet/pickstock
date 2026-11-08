import 'package:pickstock/data/snapshot/growth_metric.dart';
import 'package:pickstock/l10n/app_localizations.dart';

/// How the browsable ticker list is ordered.
///
/// Only the order: which companies are in the list is the filter bar's
/// business. Revenue growth used to be offered here once per window, with the
/// unbroken runs among them, which made the sort control the place to ask
/// "which companies grew" — a filtering question asked of a control that
/// cannot filter. The window now comes from the revenue growth filter
/// ([RevenueGrowthFilter]), and ranking by revenue growth ranks over that
/// same window, so the figure in each row is the one the filter tested.
///
/// The upside orderings rank by how far the price is from one end of the
/// company's fair-value band, which is only known once the list valuation has
/// priced the company: those not yet priced, or that cannot be valued, sit at
/// the end in either direction.
enum BrowseSort {
  name(),
  revenueGrowth(metric: GrowthMetric.revenue),
  freeCashFlowOneYear(metric: GrowthMetric.freeCashFlow),
  upsideToLowDescending(upsideBound: FairValueBound.low, isDescending: true),
  upsideToLowAscending(upsideBound: FairValueBound.low),
  upsideToHighDescending(upsideBound: FairValueBound.high, isDescending: true),
  upsideToHighAscending(upsideBound: FairValueBound.high);

  const BrowseSort({this.metric, this.upsideBound, this.isDescending = false});

  /// The growth rate ranked by, or `null` for orderings that rank on
  /// something else.
  final GrowthMetric? metric;

  /// The end of the fair-value band whose upside is ranked by, or `null` for
  /// orderings that do not rank by upside.
  final FairValueBound? upsideBound;

  /// Whether an upside ordering puts the largest upside first.
  final bool isDescending;

  /// Whether rows are ranked by a growth rate rather than alphabetically.
  bool get ranksByGrowth => metric != null;

  /// Whether rows are ranked by their upside to a bound of the fair range.
  bool get ranksByUpside => upsideBound != null;

  /// The figure each row shows under this ordering: a growth rate, or the
  /// latest revenue when the list is alphabetical.
  GrowthMetric get displayedMetric => metric ?? GrowthMetric.revenue;

  /// Reads a stored ordering, including the per-window revenue orderings an
  /// earlier version wrote. Those all rank by revenue growth, which is what
  /// they become.
  static BrowseSort? parse(String? stored) {
    if (stored == null) return null;
    for (final option in values) {
      if (option.name == stored) return option;
    }
    return stored.startsWith('revenue') ? revenueGrowth : null;
  }

  String getLabel(AppLocalizations strings) => switch (this) {
    BrowseSort.name => strings.sortByName,
    BrowseSort.revenueGrowth => strings.sortRevenueGrowth,
    BrowseSort.freeCashFlowOneYear => strings.sortFreeCashFlowOneYear,
    BrowseSort.upsideToLowDescending => strings.sortUpsideToLowDescending,
    BrowseSort.upsideToLowAscending => strings.sortUpsideToLowAscending,
    BrowseSort.upsideToHighDescending => strings.sortUpsideToHighDescending,
    BrowseSort.upsideToHighAscending => strings.sortUpsideToHighAscending,
  };
}

/// One end of a company's fair-value band.
enum FairValueBound { low, high }

/// Narrows the directory to companies whose revenue grew over a window.
///
/// Two kinds of window, as two groups in its menu: growth on average over the
/// window (the compound annual rate, above zero), and growth in every single
/// year of it. The second is the stricter: a company that halved and then
/// tripled grew on average, but not every year.
enum RevenueGrowthFilter {
  growingOneYear(years: 1),
  growingTwoYears(years: 2),
  growingThreeYears(years: 3),
  growingFiveYears(years: 5),
  growingTenYears(years: 10),
  risingTwoYears(years: 2, needsUnbrokenRun: true),
  risingThreeYears(years: 3, needsUnbrokenRun: true),
  risingFiveYears(years: 5, needsUnbrokenRun: true),
  risingTenYears(years: 10, needsUnbrokenRun: true);

  const RevenueGrowthFilter({
    required this.years,
    this.needsUnbrokenRun = false,
  });

  /// The window growth is measured over, ending at the latest filed year.
  final int years;

  /// Whether revenue has to have risen in every year of the window rather
  /// than on average across it.
  final bool needsUnbrokenRun;

  static RevenueGrowthFilter? parse(String? stored) {
    for (final option in values) {
      if (option.name == stored) return option;
    }
    return null;
  }

  /// The option's row in the menu, which sits under a group heading that
  /// already says which kind of growth it is.
  String getMenuLabel(AppLocalizations strings) => strings.filterYears(years);

  /// The chip's label while this is in force: the whole condition, since the
  /// chip has no heading to lean on.
  String getChipLabel(AppLocalizations strings) => needsUnbrokenRun
      ? strings.revenueFilterRisingChip(years)
      : strings.revenueFilterGrowingChip(years);
}

/// How many years running a company has to have generated free cash flow to
/// count as cash generative.
///
/// The latest year alone is the loosest reading — one good year can come from
/// a working-capital swing or a deferred investment — so longer runs are on
/// offer for the same reason the revenue filter has them.
enum CashGenerativeWindow {
  latestYear(1),
  twoYears(2),
  threeYears(3),
  fiveYears(5),
  tenYears(10);

  const CashGenerativeWindow(this.years);

  final int years;

  static CashGenerativeWindow? parse(String? stored) {
    for (final option in values) {
      if (option.name == stored) return option;
    }
    return null;
  }

  String getMenuLabel(AppLocalizations strings) => years == 1
      ? strings.cashFilterLatestYear
      : strings.cashFilterYearsRunning(years);

  String getChipLabel(AppLocalizations strings) => years == 1
      ? strings.browsePositiveCashFlow
      : strings.cashFilterChip(years);
}

/// The cash-to-debt multiples the cash filter offers as one press each.
///
/// 1× is plain "more cash than debt"; the rest are the round multiples worth
/// asking for. Anything between them is the slider's job.
const List<double> cashToDebtPresets = [1, 2, 3, 5];

/// The range the cash filter's slider covers, and its step. Past ten times
/// its debt a company's borrowings are a rounding error, which is the
/// debt-free end of the scale and needs no finer setting than that.
const double cashToDebtMin = 1;
const double cashToDebtMax = 10;
const double cashToDebtStep = 0.5;

/// A multiple as the chip and the menu show it: `2×`, `2.5×`.
String formatCashToDebt(double ratio) {
  final whole = ratio == ratio.roundToDouble();
  return '${whole ? ratio.toStringAsFixed(0) : ratio.toStringAsFixed(1)}×';
}
