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

  /// Gutter around every page-level section, tightened on narrow windows.
  EdgeInsets get pagePadding => EdgeInsets.symmetric(
    horizontal: isCompact ? ThemeRepo.spaceMedium : ThemeRepo.spaceXLarge,
    vertical: isCompact ? ThemeRepo.spaceMedium : ThemeRepo.spaceLarge,
  );

  /// Padding inside a card, tightened on narrow windows.
  EdgeInsets get cardPadding =>
      isCompact ? ThemeRepo.compactCardPadding : ThemeRepo.cardPadding;
}
