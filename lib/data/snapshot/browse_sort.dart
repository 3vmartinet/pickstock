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
  freeCashFlowOneYear(metric: GrowthMetric.freeCashFlow, years: 1);

  const BrowseSort({this.metric, this.years = 1});

  /// `null` for [BrowseSort.name], which ranks on the name itself.
  final GrowthMetric? metric;

  /// The window growth is measured over.
  final int years;

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
    BrowseSort.freeCashFlowOneYear => strings.sortFreeCashFlowOneYear,
  };
}
