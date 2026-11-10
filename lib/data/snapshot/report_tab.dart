import 'package:pickstock/l10n/app_localizations.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The jobs a report does, each on its own tab.
///
/// One scrolling column ran to 3,445 pixels once a price arrived — nearly four
/// screens on a laptop, with the figures table below all of it. What made it
/// unreadable was the valuation, which grows by two thousand pixels the moment
/// a quote lands; the filings themselves are a fixed height and belong beside
/// the summary of them.
enum ReportTab {
  overview(icon: LucideIcons.shieldCheck),
  valuation(icon: LucideIcons.scale),
  expectations(icon: LucideIcons.target),

  /// The seven questions that rule a company out, answered by the local model
  /// from the filings and the web. Last, because it draws on everything the
  /// three before it show.
  framework(icon: LucideIcons.clipboardCheck);

  const ReportTab({required this.icon});

  final IconData icon;

  String getLabel(AppLocalizations strings) => switch (this) {
    ReportTab.overview => strings.tabOverview,
    ReportTab.valuation => strings.tabValuation,
    ReportTab.expectations => strings.tabExpectations,
    ReportTab.framework => strings.tabFramework,
  };
}
