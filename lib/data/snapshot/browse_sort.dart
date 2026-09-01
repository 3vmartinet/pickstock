import 'package:pickstock/data/snapshot/growth_metric.dart';
import 'package:pickstock/l10n/app_localizations.dart';

/// How the browsable ticker list is ordered.
///
/// Each option carries the figure and window it ranks on, so the list, the
/// query behind it and the value shown in each row all come from one place.
enum BrowseSort {
  name(),
  revenueOneYear(metric: GrowthMetric.revenue, years: 1),
  revenueTwoYears(metric: GrowthMetric.revenue, years: 2),
  revenueThreeYears(metric: GrowthMetric.revenue, years: 3),
  revenueFiveYears(metric: GrowthMetric.revenue, years: 5),
  revenueTenYears(metric: GrowthMetric.revenue, years: 10),

  /// An unbroken run: revenue higher than the year before it, every year in
  /// the window. Ranked among those by the annual rate over the same window,
  /// so the steadiest compounders lead rather than one lucky year.
  revenueRisingTwoYears(
    metric: GrowthMetric.revenue,
    years: 2,
    needsUnbrokenRun: true,
  ),
  revenueRisingThreeYears(
    metric: GrowthMetric.revenue,
    years: 3,
    needsUnbrokenRun: true,
  ),
  revenueRisingFiveYears(
    metric: GrowthMetric.revenue,
    years: 5,
    needsUnbrokenRun: true,
  ),
  revenueRisingTenYears(
    metric: GrowthMetric.revenue,
    years: 10,
    needsUnbrokenRun: true,
  ),

  freeCashFlowOneYear(metric: GrowthMetric.freeCashFlow, years: 1);

  const BrowseSort({
    this.metric,
    this.years = 1,
    this.needsUnbrokenRun = false,
  });

  /// `null` for [BrowseSort.name], which ranks on the name itself.
  final GrowthMetric? metric;

  /// The window growth is measured over.
  final int years;

  /// Whether a company has to have grown in every year of the window to be
  /// ranked at all. Those that did not are unrankable here rather than badly
  /// ranked, and sort last with the rest of them.
  final bool needsUnbrokenRun;

  /// Whether rows are ranked by a growth rate rather than alphabetically.
  bool get ranksByGrowth => metric != null;

  /// The figure each row shows under this ordering: a growth rate, or the
  /// latest revenue when the list is alphabetical.
  GrowthMetric get displayedMetric => metric ?? GrowthMetric.revenue;

  String getLabel(AppLocalizations strings) => switch (this) {
    BrowseSort.name => strings.sortByName,
    BrowseSort.revenueOneYear => strings.sortRevenueOneYear,
    BrowseSort.revenueTwoYears => strings.sortRevenueYears(2),
    BrowseSort.revenueThreeYears => strings.sortRevenueYears(3),
    BrowseSort.revenueFiveYears => strings.sortRevenueYears(5),
    BrowseSort.revenueTenYears => strings.sortRevenueYears(10),
    BrowseSort.revenueRisingTwoYears => strings.sortRevenueRising(2),
    BrowseSort.revenueRisingThreeYears => strings.sortRevenueRising(3),
    BrowseSort.revenueRisingFiveYears => strings.sortRevenueRising(5),
    BrowseSort.revenueRisingTenYears => strings.sortRevenueRising(10),
    BrowseSort.freeCashFlowOneYear => strings.sortFreeCashFlowOneYear,
  };
}
