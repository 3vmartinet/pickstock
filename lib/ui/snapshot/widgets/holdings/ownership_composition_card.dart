import 'dart:math' as math;

import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/institutional_shareholding.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/widgets/section_header.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();
ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// Visual breakdown of the company's equity float across passive indexers,
/// active managers, corporate insiders, and retail float.
class OwnershipCompositionCard extends StatelessWidget {
  const OwnershipCompositionCard({super.key, required this.holdings});

  final InstitutionalShareholding holdings;

  @override
  Widget build(BuildContext context) {
    return Card(
      padding: context.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: ThemeRepo.spaceMedium,
        children: [
          SectionHeader(
            icon: LucideIcons.chartPie,
            title: context.strings.sectionOwnershipComposition,
          ),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _CompositionDonut(holdings: holdings),
                const SizedBox(width: ThemeRepo.spaceLarge),
                Expanded(
                  child: _CompositionLegend(holdings: holdings),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompositionDonut extends StatelessWidget {
  const _CompositionDonut({required this.holdings});

  final InstitutionalShareholding holdings;

  @override
  Widget build(BuildContext context) {
    final passiveColor = context.theme.colorScheme.primary;
    final activeColor =
        context.theme.colorScheme.primary.withValues(alpha: 0.55);
    final insiderColor = _themeRepo.caution(context.theme);
    final floatColor = context.theme.colorScheme.muted;

    final passiveWeight = holdings.passiveIndexPercent.clamp(0.0, 100.0);
    final activeWeight = holdings.activeFundsPercent.clamp(0.0, 100.0);
    final insiderWeight = holdings.insiderPercent.clamp(0.0, 100.0);
    final floatWeight =
        (100.0 - (passiveWeight + activeWeight + insiderWeight))
            .clamp(0.0, 100.0);

    final totalInstitutional = (passiveWeight + activeWeight).clamp(0.0, 100.0);

    return Center(
      child: SizedBox(
        width: 150,
        height: 150,
        child: CustomPaint(
          painter: _DonutPainter(segments: [
            _DonutSegment(
                color: passiveColor, fraction: passiveWeight / 100.0),
            _DonutSegment(color: activeColor, fraction: activeWeight / 100.0),
            _DonutSegment(
                color: insiderColor, fraction: insiderWeight / 100.0),
            _DonutSegment(color: floatColor, fraction: floatWeight / 100.0),
          ]),
          child: Center(
            child: SizedBox(
              width: 90,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_formatRepo.percent(totalInstitutional))
                      .semiBold()
                      .base(),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      context.strings.holdingsTotalTitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.15,
                      ),
                    ).muted(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.segments});

  final List<_DonutSegment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 18.0;
    final rect =
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    var startAngle = -math.pi / 2; // Start from top
    for (final segment in segments) {
      if (segment.fraction <= 0) continue;
      final sweepAngle = segment.fraction * 2 * math.pi;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.segments != segments;
}

class _DonutSegment {
  const _DonutSegment({required this.color, required this.fraction});
  final Color color;
  final double fraction;
}

class _CompositionLegend extends StatelessWidget {
  const _CompositionLegend({required this.holdings});

  final InstitutionalShareholding holdings;

  @override
  Widget build(BuildContext context) {
    final passiveColor = context.theme.colorScheme.primary;
    final activeColor = context.theme.colorScheme.primary.withValues(alpha: 0.55);
    final insiderColor = _themeRepo.caution(context.theme);
    final floatColor = context.theme.colorScheme.muted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: ThemeRepo.spaceSmall,
      children: [
        _LegendItem(
          color: passiveColor,
          label: context.strings.ownershipPassive,
          percent: holdings.passiveIndexPercent,
        ),
        _LegendItem(
          color: activeColor,
          label: context.strings.ownershipActive,
          percent: holdings.activeFundsPercent,
        ),
        _LegendItem(
          color: insiderColor,
          label: context.strings.ownershipInsiders,
          percent: holdings.insiderPercent,
        ),
        _LegendItem(
          color: floatColor,
          label: context.strings.ownershipFloat,
          percent: holdings.publicFloatPercent,
          border: true,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.percent,
    this.border = false,
  });

  final Color color;
  final String label;
  final double percent;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: ThemeRepo.spaceSmall,
      children: [
        Container(
          width: ThemeRepo.watchlistDotSize,
          height: ThemeRepo.watchlistDotSize,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: border ? Border.all(color: context.theme.colorScheme.border) : null,
          ),
        ),
        Text(label).muted().xSmall(),
        Text(_formatRepo.percent(percent)).semiBold().xSmall(),
      ],
    );
  }
}

