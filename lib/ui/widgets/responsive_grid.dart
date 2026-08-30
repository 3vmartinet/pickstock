import 'package:pickstock/repo/theme_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Lays [children] out in as many equal columns as [minItemWidth] allows,
/// collapsing to a single column on narrow windows.
///
/// A plain `Wrap` would leave ragged trailing rows and a `GridView` would need
/// a fixed aspect ratio; this keeps every card the same width and lets each
/// one be as tall as its own content.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    required this.minItemWidth,
    this.spacing = ThemeRepo.spaceMedium,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.maxWidth);
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }

  int _columnsFor(double availableWidth) {
    final fitting = ((availableWidth + spacing) / (minItemWidth + spacing))
        .floor();
    return fitting.clamp(1, children.length);
  }
}
