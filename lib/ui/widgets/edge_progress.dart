import 'package:pickstock/repo/theme_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

/// Draws [fraction] along the bottom edge of [child].
///
/// Inside the button's own outline rather than under it: a bar of its own
/// underneath would move whatever sits below the button the moment work
/// started, and the button is the thing the progress belongs to.
///
/// Shared by the two places that report a long job from a button — the app
/// bar's archive download and the company header's reading-around — so the
/// two cannot drift apart.
class EdgeProgress extends StatelessWidget {
  const EdgeProgress({
    super.key,
    required this.fraction,
    required this.colour,
    required this.child,
  });

  /// `null` shows the indeterminate bar, for work with no knowable size.
  final double? fraction;

  /// What the filled part is drawn in. Given rather than taken from the theme
  /// because it depends on what the bar is drawn on: a filled button wants its
  /// own foreground, an outlined one the accent colour.
  final Color colour;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      // The same radius the button draws itself with, so the bar picks up its
      // corners instead of squaring them off.
      borderRadius: context.theme.borderRadiusMd,
      child: Stack(
        children: [
          child,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ComponentTheme<ProgressTheme>(
              // Squared off, because the clip above supplies the only corners
              // the bar should have.
              data: ProgressTheme(
                minHeight: ThemeRepo.updateProgressHeight,
                borderRadius: BorderRadius.zero,
                color: colour,
                backgroundColor: colour.withValues(
                  alpha: ThemeRepo.updateProgressTrack,
                ),
              ),
              child: Progress(progress: fraction),
            ),
          ),
        ],
      ),
    );
  }
}
