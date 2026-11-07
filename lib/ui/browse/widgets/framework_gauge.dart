import 'dart:math' as math;

import 'package:get_it/get_it.dart';
import 'package:pickstock/data/research/framework_question.dart';
import 'package:pickstock/data/research/framework_score.dart';
import 'package:pickstock/data/snapshot/report_tab.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// The framework rating on one company's tile.
Key frameworkGaugeKey(String cik) => ValueKey('frameworkGauge-$cik');

/// How many of the seven questions a company passed, as a small outlined pie
/// drawn as a glyph: the share earned as a wedge in its colour.
///
/// A pie rather than a row of seven marks: it is one glyph, the size of the
/// other marks around it, and reads as a share of a whole at a glance. Drawn
/// here because shadcn's charts stop at a ring, and in Lucide's own stroke so
/// it sits among the icons it stands beside.
///
/// Coloured by how many it earned, from rose at one through amber to
/// emerald at seven: a scale rather than the framework's pass-or-fail, since
/// six of seven is a strong showing even where the seventh was a no. The
/// tooltip says the count and how many were answered.
class FrameworkGauge extends StatelessWidget {
  const FrameworkGauge({
    super.key,
    required this.score,
    this.size = ThemeRepo.frameworkPieSize,
    this.isIcon = false,
  });

  final FrameworkScore score;

  /// The box it takes: a tile's trailing slot by default, an icon's after a
  /// tab's label.
  final double size;

  /// Whether the glyph fills its box, as an icon does beside a label, rather
  /// than sitting a glyph's size inside a tile's larger slot.
  final bool isIcon;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final scheme = theme.colorScheme;
    final steps = FrameworkQuestion.values.length;
    final description = context.strings.frameworkGaugeTooltip(
      score.satisfied,
      steps,
      score.answered,
    );
    final colour = _themeRepo.forScore(theme, score.satisfied, outOf: steps);
    // Smaller than a tile's slot and centred in it: a glyph drawn to the full
    // slot stood a size larger than the marks around it and, its lines
    // scaling with it, a weight heavier too.
    final glyph = isIcon ? size : size * ThemeRepo.frameworkPassedIconScale;

    return Tooltip(
      tooltip: HintTooltip(description).call,
      child: Semantics(
        label: description,
        child: SizedBox.square(
          dimension: size,
          child: Center(
            // Every question passed: no pie at all, only the Framework tab's
            // own glyph in the green the full score earns — a pie with
            // nothing missing from it says less than the mark that says so.
            child: score.satisfied >= steps
                ? Icon(_passedIcon, size: glyph, color: colour)
                : SizedBox.square(
                    dimension: glyph,
                    child: CustomPaint(
                      painter: _OutlinedPiePainter(
                        value: score.satisfied,
                        steps: steps,
                        earned: colour,
                        rest: scheme.mutedForeground.withValues(
                          alpha: ThemeRepo.frameworkPieOutlineRestOpacity,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// What a full pie carries: the Framework tab's own glyph, so a company that
/// passed everything is marked with the tab that says so.
final IconData _passedIcon = ReportTab.framework.icon;

/// The pie as a glyph: the share earned as an outlined wedge in its colour,
/// in a Lucide glyph's stroke on its twenty-four unit grid.
class _OutlinedPiePainter extends CustomPainter {
  const _OutlinedPiePainter({
    required this.value,
    required this.steps,
    required this.earned,
    required this.rest,
  });

  final int value;
  final int steps;
  final Color earned;
  final Color rest;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / ThemeRepo.lucideGrid;
    final centre = size.center(Offset.zero);
    final radius = ThemeRepo.lucideCircleRadius * unit;
    final circle = Rect.fromCircle(center: centre, radius: radius);
    final stroke = ThemeRepo.lucideStroke * unit;
    const start = -math.pi / 2;
    final sweep = 2 * math.pi * value.clamp(0, steps) / steps;

    Paint line(Color colour) => Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // The share earned alone, with nothing drawn for the rest: the wedge is
    // the figure, and an outline round it only competed with it. Only where
    // nothing was earned is the circle drawn, faintly, so a company whose
    // every answer was a no still shows it was asked rather than nothing.
    if (sweep == 0) {
      canvas.drawCircle(centre, radius, line(rest));
      return;
    }

    canvas.drawPath(
      Path()
        ..moveTo(centre.dx, centre.dy)
        ..lineTo(centre.dx, centre.dy - radius)
        ..arcTo(circle, start, sweep, false)
        ..close(),
      line(earned),
    );
  }

  @override
  bool shouldRepaint(_OutlinedPiePainter old) =>
      old.value != value ||
      old.steps != steps ||
      old.earned != earned ||
      old.rest != rest;
}
