import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/snapshot/snapshot_metric.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/widgets/responsive_grid.dart';
import 'package:provider/provider.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();
ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// The four headline figures for the most recent fiscal year.
class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      minItemWidth: ThemeRepo.metricCardMinWidth,
      children: [
        for (final metric in SnapshotMetric.values) _MetricCard(metric),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.metric);

  final SnapshotMetric metric;

  @override
  Widget build(BuildContext context) {
    final figures = context.select<SnapshotViewModel, FiscalYearFigures?>(
      (viewModel) => viewModel.latestFigures,
    );
    if (figures == null) return const SizedBox.shrink();

    return Card(
      padding: context.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: ThemeRepo.spaceXSmall,
        children: [
          _MetricLabel(metric),
          _MetricFigure(metric),
          _MetricChange(metric),
        ],
      ),
    );
  }
}

class _MetricLabel extends StatelessWidget {
  const _MetricLabel(this.metric);

  final SnapshotMetric metric;

  @override
  Widget build(BuildContext context) {
    final figures = context.select<SnapshotViewModel, FiscalYearFigures?>(
      (viewModel) => viewModel.latestFigures,
    );
    if (figures == null) return const SizedBox.shrink();

    return Row(
      spacing: ThemeRepo.spaceXSmall,
      children: [
        Icon(metric.icon).iconXSmall().iconMutedForeground(),
        Expanded(
          child: Text(metric.getLabel(context.strings, figures))
              .muted()
              .small(),
        ),
        Tooltip(
          tooltip: HintTooltip(metric.getHint(context.strings)).call,
          child: const Icon(LucideIcons.info)
              .iconXSmall()
              .iconMutedForeground(),
        ),
      ],
    );
  }
}

class _MetricFigure extends StatelessWidget {
  const _MetricFigure(this.metric);

  final SnapshotMetric metric;

  @override
  Widget build(BuildContext context) {
    final figures = context.select<SnapshotViewModel, FiscalYearFigures?>(
      (viewModel) => viewModel.latestFigures,
    );
    if (figures == null) return const SizedBox.shrink();

    final value = metric.getValue(figures);
    // Deliberately not `.h2()`: that modifier is shadcn's section heading,
    // complete with a 40px top margin and an underline.
    if (value == null) {
      return Text(context.strings.verdictUnknown).x3Large(
        color: _themeRepo.unknown(context.theme),
        fontWeight: ThemeRepo.headlineFigureWeight,
        height: ThemeRepo.headlineFigureHeight,
      );
    }

    return Text(
      metric.showsMagnitudeOnly
          ? _formatRepo.compactCurrencyMagnitude(value)
          : _formatRepo.compactCurrency(value),
    ).x3Large(
      color: _themeRepo.forOutcome(
        context.theme,
        isGood: metric.getSentiment(figures),
      ),
      fontWeight: ThemeRepo.headlineFigureWeight,
      height: ThemeRepo.headlineFigureHeight,
    );
  }
}

/// The line under the figure: either what side of zero a balance-sheet figure
/// sits on, or how it moved against the year before.
class _MetricChange extends StatelessWidget {
  const _MetricChange(this.metric);

  final SnapshotMetric metric;

  @override
  Widget build(BuildContext context) {
    final years = context.select<SnapshotViewModel, List<FiscalYearFigures>?>(
      (viewModel) => viewModel.snapshot?.years,
    );
    if (years == null || years.isEmpty) return const SizedBox.shrink();

    final figures = years.last;
    final previous = years.length > 1 ? years[years.length - 2] : null;

    // The balance-sheet card compares in words: a figure that crosses zero has
    // no sensible percentage change.
    final priorPosition = metric.getPriorPosition(context.strings, previous);
    if (priorPosition != null) {
      return Text(priorPosition).muted().xSmall();
    }

    final change = metric.getChangePercent(figures, previous);
    if (change == null || previous == null) {
      return const SizedBox(height: ThemeRepo.spaceMedium);
    }

    return Row(
      spacing: ThemeRepo.spaceXSmall,
      children: [
        Text(_formatRepo.signedPercent(change)).xSmall().semiBold(
          color: _themeRepo.forOutcome(context.theme, isGood: change >= 0),
        ),
        Text(context.strings.deltaVersusPriorYear('${previous.fiscalYear}'))
            .muted()
            .xSmall(),
      ],
    );
  }
}
