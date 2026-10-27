import 'dart:math' as math;

import 'package:get_it/get_it.dart';
import 'package:pickstock/data/research/framework_evidence.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();
ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// What the filings say about one question, beside what the model wrote.
///
/// On a muted surface rather than a card of its own: it belongs to the answer
/// next to it, and a second bordered box inside the card read as a second
/// answer. Rendered whether or not the model has been asked — the filings are
/// on hand before any of the reading is.
class EvidencePanel extends StatelessWidget {
  const EvidencePanel({super.key, required this.evidence});

  final FrameworkEvidence evidence;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Container(
      padding: const EdgeInsets.all(ThemeRepo.spaceMedium),
      decoration: BoxDecoration(
        color: theme.colorScheme.muted.withValues(
          alpha: ThemeRepo.eventsPanelTint,
        ),
        borderRadius: theme.borderRadiusMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: ThemeRepo.spaceMedium,
        children: [
          Row(
            spacing: ThemeRepo.spaceXSmall,
            children: [
              const Icon(LucideIcons.fileText)
                  .iconXSmall()
                  .iconMutedForeground(),
              Text(context.strings.frameworkFromFilings)
                  .muted()
                  .xSmall()
                  .semiBold(),
            ],
          ),
          if (evidence.awaitsPrice)
            Text(context.strings.evidenceNoPrice).muted().xSmall()
          else if (evidence.isEmpty)
            Text(context.strings.evidenceNone).muted().xSmall()
          else ...[
            if (evidence.series.isNotEmpty)
              EvidenceChart(series: evidence.series),
            if (evidence.lacksGrossMargin)
              Text(context.strings.evidenceGrossMarginMissing).muted().xSmall(),
            for (final stat in evidence.stats) _StatRow(stat: stat),
          ],
        ],
      ),
    );
  }
}

/// One figure as a definition: what it is on the left, the value on the
/// right, so a column of them lines up for comparison.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.stat});

  final EvidenceStat stat;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: ThemeRepo.spaceSmall,
      children: [
        Expanded(child: Text(labelOf(context.strings, stat)).muted().xSmall()),
        Text(valueOf(context.strings, stat)).small().semiBold(),
      ],
    );
  }
}

/// What a measure is called, with its window where it has one.
String labelOf(AppLocalizations strings, EvidenceStat stat) {
  final years = stat.years ?? 0;
  return switch (stat.measure) {
    EvidenceMeasure.revenueGrowthShort || EvidenceMeasure.revenueGrowthLong =>
      strings.evidenceRevenueGrowthYears(years),
    EvidenceMeasure.operatingMarginChange =>
      strings.evidenceOperatingMarginChange(years),
    EvidenceMeasure.shareCountChange => strings.evidenceShareCountChange(years),
    final measure => measureLabel(strings, measure),
  };
}

String measureLabel(AppLocalizations strings, EvidenceMeasure measure) =>
    switch (measure) {
      EvidenceMeasure.revenue => strings.evidenceRevenue,
      EvidenceMeasure.revenueGrowthLatest =>
        strings.evidenceRevenueGrowthLatest,
      EvidenceMeasure.revenueGrowthShort ||
      EvidenceMeasure.revenueGrowthLong => strings.evidenceRevenue,
      EvidenceMeasure.grossMargin => strings.evidenceGrossMargin,
      EvidenceMeasure.operatingMargin => strings.evidenceOperatingMargin,
      EvidenceMeasure.operatingMarginChange => strings.evidenceOperatingMargin,
      EvidenceMeasure.impairment => strings.evidenceImpairment,
      EvidenceMeasure.operatingMarginBeforeImpairment =>
        strings.evidenceOperatingMarginBeforeImpairment,
      EvidenceMeasure.returnOnEquity => strings.evidenceReturnOnEquity,
      EvidenceMeasure.shareCountChange => strings.evidenceShareCount,
      EvidenceMeasure.capitalReturned => strings.evidenceCapitalReturned,
      EvidenceMeasure.stockPay => strings.evidenceStockPay,
      EvidenceMeasure.freeCashFlow => strings.evidenceFreeCashFlow,
      EvidenceMeasure.cashConversion => strings.evidenceCashConversion,
      EvidenceMeasure.netDebt => strings.evidenceNetDebt,
      EvidenceMeasure.netCash => strings.evidenceNetCash,
      EvidenceMeasure.debtPayback => strings.evidenceDebtPayback,
      EvidenceMeasure.interestCover => strings.evidenceInterestCover,
      EvidenceMeasure.price => strings.evidencePrice,
      EvidenceMeasure.fairRange => strings.evidenceFairRange,
      EvidenceMeasure.toRangeLow => strings.evidenceToRangeLow,
    };

/// A figure written the way its measure is read.
String valueOf(AppLocalizations strings, EvidenceStat stat) =>
    switch (stat.upper) {
      final upper? =>
        '${_formatRepo.price(stat.value)} – ${_formatRepo.price(upper)}',
      null => formatMeasure(strings, stat.measure, stat.value),
    };

String formatMeasure(
  AppLocalizations strings,
  EvidenceMeasure measure,
  double value,
) => switch (measure) {
  EvidenceMeasure.revenue ||
  EvidenceMeasure.freeCashFlow ||
  EvidenceMeasure.netDebt ||
  EvidenceMeasure.netCash ||
  EvidenceMeasure.impairment => _formatRepo.compactCurrency(value),
  // Changes carry their sign: "+4.2%" and "4.2%" are different claims.
  EvidenceMeasure.revenueGrowthLatest ||
  EvidenceMeasure.revenueGrowthShort ||
  EvidenceMeasure.revenueGrowthLong ||
  EvidenceMeasure.shareCountChange ||
  EvidenceMeasure.toRangeLow => _formatRepo.signedPercent(value),
  EvidenceMeasure.grossMargin ||
  EvidenceMeasure.operatingMargin ||
  EvidenceMeasure.operatingMarginBeforeImpairment ||
  EvidenceMeasure.returnOnEquity ||
  EvidenceMeasure.capitalReturned ||
  EvidenceMeasure.stockPay => _formatRepo.percent(value),
  EvidenceMeasure.operatingMarginChange => strings.evidencePointsValue(
    '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}',
  ),
  EvidenceMeasure.cashConversion || EvidenceMeasure.interestCover =>
    strings.evidenceTimesValue(_formatRepo.ratio(value)),
  EvidenceMeasure.debtPayback => strings.evidenceYearsValue(
    value.toStringAsFixed(1),
  ),
  EvidenceMeasure.price ||
  EvidenceMeasure.fairRange => _formatRepo.price(value),
};

/// A small chart of one or two measures by fiscal year.
///
/// Bars for money, which is a magnitude read against zero; lines for margins,
/// which are a rate read for its direction. Two series only ever share a
/// chart when they share a unit — gross and operating margin, both percent of
/// revenue — so there is never a second axis.
///
/// Each series is named in a legend with its latest value, so identity is
/// never carried by colour alone and the figure a reader wants is written out
/// rather than estimated from a bar. Every year answers hover with its exact
/// values.
class EvidenceChart extends StatelessWidget {
  const EvidenceChart({super.key, required this.series});

  final List<EvidenceSeries> series;

  bool get _isLine =>
      series.first.measure != EvidenceMeasure.revenue &&
      series.first.measure != EvidenceMeasure.freeCashFlow;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colours = [
      _themeRepo.chartPrimary(theme),
      _themeRepo.chartSecondary(theme),
    ];
    final years = {
      for (final line in series)
        for (final (year, _) in line.points) year,
    }.toList()..sort();
    if (years.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: ThemeRepo.spaceXSmall,
      children: [
        Wrap(
          spacing: ThemeRepo.spaceMedium,
          runSpacing: ThemeRepo.spaceXSmall,
          children: [
            for (var i = 0; i < series.length; i++)
              _LegendEntry(series: series[i], colour: colours[i]),
          ],
        ),
        SizedBox(
          height: ThemeRepo.evidenceChartHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ChartPainter(
                    series: series,
                    years: years,
                    colours: colours,
                    isLine: _isLine,
                    baseline: theme.colorScheme.border,
                    // What the panel is drawn on, so a marker's ring reads as
                    // a gap rather than a halo.
                    surface: Color.alphaBlend(
                      theme.colorScheme.muted.withValues(
                        alpha: ThemeRepo.eventsPanelTint,
                      ),
                      theme.colorScheme.card,
                    ),
                  ),
                ),
              ),
              // One hit target per year, the full height of the chart: far
              // larger than a 6-pixel marker or a thin bar, which is what a
              // pointer can actually find.
              Positioned.fill(
                child: Row(
                  children: [
                    for (final year in years)
                      Expanded(
                        child: Tooltip(
                          tooltip: HintTooltip(_hoverText(context, year)).call,
                          child: const SizedBox.expand(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('FY${years.first}').muted().xSmall(),
            if (years.length > 1) Text('FY${years.last}').muted().xSmall(),
          ],
        ),
      ],
    );
  }

  String _hoverText(BuildContext context, int year) {
    final strings = context.strings;
    final values = [
      for (final line in series)
        for (final (pointYear, value) in line.points)
          if (pointYear == year)
            series.length == 1
                ? formatMeasure(strings, line.measure, value)
                : '${measureLabel(strings, line.measure)} '
                      '${formatMeasure(strings, line.measure, value)}',
    ];
    return strings.evidenceChartHint(year, values.join(' · '));
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({required this.series, required this.colour});

  final EvidenceSeries series;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final latest = series.points.last.$2;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: ThemeRepo.spaceXSmall,
      children: [
        Container(
          width: ThemeRepo.evidenceLegendSwatch,
          height: ThemeRepo.evidenceLegendSwatch,
          decoration: BoxDecoration(
            color: colour,
            borderRadius: BorderRadius.circular(
              ThemeRepo.evidenceLegendSwatch / 4,
            ),
          ),
        ),
        Text(measureLabel(context.strings, series.measure)).muted().xSmall(),
        Text(formatMeasure(context.strings, series.measure, latest))
            .xSmall()
            .semiBold(),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.series,
    required this.years,
    required this.colours,
    required this.isLine,
    required this.baseline,
    required this.surface,
  });

  final List<EvidenceSeries> series;
  final List<int> years;
  final List<Color> colours;
  final bool isLine;
  final Color baseline;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final values = [
      for (final line in series)
        for (final (_, value) in line.points) value,
    ];
    // Zero always in range: a bar measured from anywhere else exaggerates the
    // difference between years, and a margin below zero is a loss worth
    // seeing as one.
    final low = math.min(0.0, values.reduce(math.min));
    final high = math.max(0.0, values.reduce(math.max));
    final span = high - low == 0 ? 1.0 : high - low;
    // Room inside the edges for a marker's radius, so the highest point is
    // not cut in half.
    const inset = ThemeRepo.evidenceMarkerSize / 2 + 1;
    final plotHeight = size.height - inset * 2;
    double yOf(double value) => inset + (high - value) / span * plotHeight;

    final slot = size.width / years.length;
    double xOf(int year) => slot * years.indexOf(year) + slot / 2;

    final zero = yOf(0);
    canvas.drawLine(
      Offset(0, zero),
      Offset(size.width, zero),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );

    for (var i = 0; i < series.length; i++) {
      final paint = Paint()..color = colours[i];
      final points = series[i].points;
      if (!isLine) {
        for (final (year, value) in points) {
          final left =
              slot * years.indexOf(year) + ThemeRepo.evidenceBarGap / 2;
          final right = left + slot - ThemeRepo.evidenceBarGap;
          final top = math.min(yOf(value), zero);
          final bottom = math.max(yOf(value), zero);
          const radius = Radius.circular(ThemeRepo.evidenceBarRadius);
          // Rounded at the data end only, square where it meets the baseline.
          canvas.drawRRect(
            RRect.fromLTRBAndCorners(
              left,
              top,
              right,
              bottom,
              topLeft: value >= 0 ? radius : Radius.zero,
              topRight: value >= 0 ? radius : Radius.zero,
              bottomLeft: value < 0 ? radius : Radius.zero,
              bottomRight: value < 0 ? radius : Radius.zero,
            ),
            paint,
          );
        }
        continue;
      }

      final path = Path();
      for (var p = 0; p < points.length; p++) {
        final (year, value) = points[p];
        final offset = Offset(xOf(year), yOf(value));
        p == 0
            ? path.moveTo(offset.dx, offset.dy)
            : path.lineTo(offset.dx, offset.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = colours[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = ThemeRepo.evidenceLineWidth
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      // Only the latest point is marked: it is the one the legend quotes, and
      // a marker on every year turns two lines into two strings of beads.
      final (lastYear, lastValue) = points.last;
      final centre = Offset(xOf(lastYear), yOf(lastValue));
      canvas
        ..drawCircle(
          centre,
          ThemeRepo.evidenceMarkerSize / 2 + ThemeRepo.evidenceMarkerRing,
          Paint()..color = surface,
        )
        ..drawCircle(centre, ThemeRepo.evidenceMarkerSize / 2, paint);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.series != series ||
      old.colours != colours ||
      old.isLine != isLine ||
      old.baseline != baseline;
}
