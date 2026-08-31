import 'package:fluf/ui/breakpoint.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Window-size questions the layout asks, answered in one place.
///
/// Only `fluf`'s [Breakpoint] scale is reused here; its `BuildContext`
/// extensions are Material-bound and would collide with shadcn's own
/// `context.theme`.
extension ResponsiveExtensions on BuildContext {
  Breakpoint get breakpoint {
    final width = MediaQuery.sizeOf(this).width;
    if (width < Breakpoint.compact.maxWidth) return Breakpoint.compact;
    if (width < Breakpoint.medium.maxWidth) return Breakpoint.medium;
    if (width < Breakpoint.expanded.maxWidth) return Breakpoint.expanded;
    if (width < Breakpoint.large.maxWidth) return Breakpoint.large;
    return Breakpoint.extraLarge;
  }

  /// Phone-width, or a browser window narrowed to about that.
  bool get isCompact => breakpoint == Breakpoint.compact;

  /// Wide enough for side-by-side headline blocks and a full-width table.
  bool get isExpanded => breakpoint.index >= Breakpoint.expanded.index;

  /// Wide enough to show the ticker list and a company's report side by side.
  ///
  /// Below this the list takes the whole window and picking a company returns
  /// to the report, because splitting the width leaves neither pane usable.
  bool get showsMasterDetail =>
      MediaQuery.sizeOf(this).width >= ThemeRepo.masterDetailMinWidth;

  /// The inset every page-level row starts at, on all four sides.
  ///
  /// One value for the app bar, the filter, the sector chips and the grid:
  /// each row setting its own inset left four different left edges down the
  /// screen, which read as sloppy however carefully each one was chosen. The
  /// same value vertically, so a divider has equal air above and below it and
  /// the margin around the content is even rather than twice as wide as tall.
  double get pageGutter => ThemeRepo.pageGutter;

  /// Gutter around every page-level section.
  EdgeInsets get pagePadding => const EdgeInsets.all(ThemeRepo.pageGutter);

  /// Padding inside a card, tightened on narrow windows.
  EdgeInsets get cardPadding =>
      isCompact ? ThemeRepo.compactCardPadding : ThemeRepo.cardPadding;
}
