import 'package:pickstock/l10n/app_localizations.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The layout options for presenting the seven-questions Framework tab.
enum FrameworkLayout {
  /// All cards and scorecard stacked vertically in a single list.
  list(icon: LucideIcons.rows3),

  /// Scorecard on top, with question cards navigated in a horizontal carousel.
  carousel(icon: LucideIcons.galleryHorizontal),

  /// Scorecard and steps on a vertical left pane, with question cards on the right.
  verticalPanel(icon: LucideIcons.layoutPanelLeft);

  const FrameworkLayout({required this.icon});

  final IconData icon;

  String getLabel(AppLocalizations strings) => switch (this) {
    FrameworkLayout.list => strings.frameworkLayoutList,
    FrameworkLayout.carousel => strings.frameworkLayoutCarousel,
    FrameworkLayout.verticalPanel => strings.frameworkLayoutVertical,
  };

  String getHint(AppLocalizations strings) => switch (this) {
    FrameworkLayout.list => strings.frameworkLayoutListHint,
    FrameworkLayout.carousel => strings.frameworkLayoutCarouselHint,
    FrameworkLayout.verticalPanel => strings.frameworkLayoutVerticalHint,
  };
}
