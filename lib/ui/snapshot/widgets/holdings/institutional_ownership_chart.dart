import 'dart:math' as math;

import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/institutional_shareholding.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:pickstock/ui/widgets/section_header.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();
ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// Visualizes the evolution of the institutional ownership percentage over time as a graph.
class InstitutionalOwnershipChart extends StatelessWidget {
  const InstitutionalOwnershipChart({super.key, required this.holdings});

  final InstitutionalShareholding holdings;

  @override
  Widget build(BuildContext context) {
    final trends = holdings.quarterlyTrends;
    if (trends.length < 2) {
      return const SizedBox.shrink();
    }

    final firstPct = trends.first.institutionalOwnershipPercent;
    final lastPct = trends.last.institutionalOwnershipPercent;
    final diffPct = lastPct - firstPct;
    final isPositive = diffPct >= 0;
    final sign = diffPct > 0 ? '+' : '';
    final diffText = '$sign${_formatRepo.percent(diffPct)}';
    final changeLabel = context.strings.ownershipTrendChange(
      diffText,
      trends.length,
    );
    final accent = _themeRepo.forOutcome(context.theme, isGood: isPositive);

    return Card(
      padding: context.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: ThemeRepo.spaceMedium,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionHeader(
                  icon: LucideIcons.chartLine,
                  title: context.strings.sectionOwnershipTrend,
                ),
              ),
              Tooltip(
                tooltip: HintTooltip(context.strings.hintOwnershipTrend).call,
                child: const Icon(LucideIcons.info)
                    .iconXSmall()
                    .iconMutedForeground(),
              ),
              const SizedBox(width: ThemeRepo.spaceSmall),
              OutlineBadge(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: ThemeRepo.spaceXSmall,
                  children: [
                    Icon(
                      isPositive
                          ? LucideIcons.trendingUp
                          : LucideIcons.trendingDown,
                      color: accent,
                    ).iconXSmall(),
                    Text(changeLabel).semiBold().xSmall(color: accent),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(
            height: 180,
            child: _TrendGraph(
              trends: trends,
              lineColour: context.theme.colorScheme.primary,
              surfaceColour: context.theme.colorScheme.card,
              gridColour: context.theme.colorScheme.border.withValues(
                alpha: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendGraph extends StatelessWidget {
  const _TrendGraph({
    required this.trends,
    required this.lineColour,
    required this.surfaceColour,
    required this.gridColour,
  });

  final List<InstitutionalQuarterlyTrend> trends;
  final Color lineColour;
  final Color surfaceColour;
  final Color gridColour;

  @override
  Widget build(BuildContext context) {
    final pcts = trends.map((t) => t.institutionalOwnershipPercent).toList();
    final minVal = pcts.reduce(math.min);
    final maxVal = pcts.reduce(math.max);
    final pad = math.max(0.8, (maxVal - minVal) * 0.25);
    final yMin = math.max(0.0, minVal - pad);
    final yMax = math.min(100.0, maxVal + pad);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        const chartH = 120.0;
        final slotW = w / trends.length;

        return Column(
          children: [
            SizedBox(
              height: chartH,
              width: w,
              child: CustomPaint(
                painter: _TrendChartPainter(
                  pcts: pcts,
                  yMin: yMin,
                  yMax: yMax,
                  lineColour: lineColour,
                  surfaceColour: surfaceColour,
                  gridColour: gridColour,
                ),
                child: Stack(
                  children: [
                    for (var i = 0; i < trends.length; i++)
                      _PointLabel(
                        x: slotW * i + slotW / 2,
                        y: _calculateY(pcts[i], yMin, yMax, chartH),
                        text: _formatRepo.percent(pcts[i]),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: ThemeRepo.spaceSmall),
            Row(
              children: [
                for (final trend in trends)
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(trend.calendarQuarter)
                            .semiBold()
                            .xSmall()
                            .singleLine(),
                        Text(_formatRepo.compactCount(trend.totalSharesHeld))
                            .muted()
                            .xSmall()
                            .singleLine(),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  static double _calculateY(
    double val,
    double yMin,
    double yMax,
    double height,
  ) {
    const insetTop = 24.0;
    const insetBottom = 16.0;
    final plotH = height - insetTop - insetBottom;
    final span = yMax - yMin == 0 ? 1.0 : yMax - yMin;
    return insetTop + (1.0 - ((val - yMin) / span)) * plotH;
  }
}

class _PointLabel extends StatelessWidget {
  const _PointLabel({required this.x, required this.y, required this.text});

  final double x;
  final double y;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x - 32,
      top: y - 24,
      width: 64,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: context.theme.colorScheme.muted.withValues(alpha: 0.6),
            borderRadius: context.theme.borderRadiusSm,
          ),
          child: Text(text).semiBold().xSmall().singleLine(),
        ),
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  _TrendChartPainter({
    required this.pcts,
    required this.yMin,
    required this.yMax,
    required this.lineColour,
    required this.surfaceColour,
    required this.gridColour,
  });

  final List<double> pcts;
  final double yMin;
  final double yMax;
  final Color lineColour;
  final Color surfaceColour;
  final Color gridColour;

  @override
  void paint(Canvas canvas, Size size) {
    if (pcts.length < 2) return;

    const insetTop = 24.0;
    const insetBottom = 16.0;
    final plotH = size.height - insetTop - insetBottom;
    final span = yMax - yMin == 0 ? 1.0 : yMax - yMin;
    final slotW = size.width / pcts.length;

    double xOf(int index) => slotW * index + slotW / 2;
    double yOf(double val) => insetTop + (1.0 - ((val - yMin) / span)) * plotH;

    // Draw horizontal grid lines.
    final gridPaint = Paint()
      ..color = gridColour
      ..strokeWidth = 1.0;

    for (var step = 0; step <= 2; step++) {
      final y = insetTop + (plotH / 2) * step;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Build the curve path.
    final path = Path();
    for (var i = 0; i < pcts.length; i++) {
      final pt = Offset(xOf(i), yOf(pcts[i]));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }

    // Gradient fill under the path.
    final fillPath = Path.from(path)
      ..lineTo(xOf(pcts.length - 1), size.height - insetBottom)
      ..lineTo(xOf(0), size.height - insetBottom)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColour.withValues(alpha: 0.22),
          lineColour.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, insetTop, size.width, plotH))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Draw the main line.
    final linePaint = Paint()
      ..color = lineColour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // Draw circular dots at each point.
    for (var i = 0; i < pcts.length; i++) {
      final pt = Offset(xOf(i), yOf(pcts[i]));
      canvas.drawCircle(pt, 4.5, Paint()..color = surfaceColour);
      canvas.drawCircle(pt, 3.0, Paint()..color = lineColour);
    }
  }

  @override
  bool shouldRepaint(_TrendChartPainter old) =>
      old.pcts != pcts ||
      old.lineColour != lineColour ||
      old.gridColour != gridColour;
}
