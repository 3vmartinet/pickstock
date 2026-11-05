import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/institutional_shareholding.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/snapshot/widgets/holdings/holder_sparkline.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:pickstock/ui/widgets/responsive_grid.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();
ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// The four headline figures for institutional ownership.
class OwnershipMetricGrid extends StatelessWidget {
  const OwnershipMetricGrid({super.key, required this.holdings});

  final InstitutionalShareholding holdings;

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      minItemWidth: ThemeRepo.metricCardMinWidth,
      children: [
        _TotalCard(holdings: holdings),
        _ConcentrationCard(holdings: holdings),
        _FlowCard(holdings: holdings),
        _ActivistCard(holdings: holdings),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.holdings});

  final InstitutionalShareholding holdings;

  @override
  Widget build(BuildContext context) {
    final pctList = holdings.quarterlyTrends
        .map((t) => t.institutionalOwnershipPercent)
        .toList();
    final isUp = pctList.length >= 2 && pctList.last >= pctList.first;
    final trendColor = _themeRepo.forOutcome(context.theme, isGood: isUp);

    return Card(
      padding: context.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: ThemeRepo.spaceXSmall,
        children: [
          Row(
            spacing: ThemeRepo.spaceXSmall,
            children: [
              const Icon(LucideIcons.building2).iconXSmall().iconMutedForeground(),
              Expanded(
                child: Text(context.strings.holdingsTotalTitle).muted().small(),
              ),
              Tooltip(
                tooltip: HintTooltip(context.strings.hintInstitutionalOwnership).call,
                child: const Icon(LucideIcons.info).iconXSmall().iconMutedForeground(),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_formatRepo.percent(holdings.institutionalOwnershipPercent)).h3(),
              if (pctList.length >= 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: HolderSparkline(
                    values: pctList,
                    colour: trendColor,
                    width: 54,
                    height: 20,
                  ),
                ),
            ],
          ),
          Text(context.strings.holdingsFilersCount(holdings.totalInstitutionsCount))
              .muted()
              .xSmall(),
        ],
      ),
    );
  }
}

class _ConcentrationCard extends StatelessWidget {
  const _ConcentrationCard({required this.holdings});

  final InstitutionalShareholding holdings;

  @override
  Widget build(BuildContext context) {
    final concentration = holdings.top10ConcentrationPercent;
    final level = concentration >= 50.0
        ? context.strings.concentrationHigh
        : concentration >= 30.0
            ? context.strings.concentrationModerate
            : context.strings.concentrationBroad;

    return Card(
      padding: context.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: ThemeRepo.spaceXSmall,
        children: [
          Row(
            spacing: ThemeRepo.spaceXSmall,
            children: [
              const Icon(LucideIcons.chartPie).iconXSmall().iconMutedForeground(),
              Expanded(
                child: Text(context.strings.holdingsTop10Title).muted().small(),
              ),
              Tooltip(
                tooltip: HintTooltip(context.strings.hintTop10Concentration).call,
                child: const Icon(LucideIcons.info).iconXSmall().iconMutedForeground(),
              ),
            ],
          ),
          Text(_formatRepo.percent(concentration)).h3(),
          Text(level).muted().xSmall(),
        ],
      ),
    );
  }
}

class _FlowCard extends StatelessWidget {
  const _FlowCard({required this.holdings});

  final InstitutionalShareholding holdings;

  @override
  Widget build(BuildContext context) {
    final netChange = holdings.netSharesChange;
    final isPositive = netChange >= 0;
    final accent = _themeRepo.forOutcome(context.theme, isGood: isPositive);
    final sign = isPositive ? '+' : '';
    final countText = '$sign${_formatRepo.compactCount(netChange)} shares';

    return Card(
      padding: context.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: ThemeRepo.spaceXSmall,
        children: [
          Row(
            spacing: ThemeRepo.spaceXSmall,
            children: [
              Icon(isPositive ? LucideIcons.trendingUp : LucideIcons.trendingDown, color: accent)
                  .iconXSmall(),
              Expanded(
                child: Text(context.strings.holdingsNetFlowTitle).muted().small(),
              ),
              Tooltip(
                tooltip: HintTooltip(context.strings.hintNetInstitutionalFlow).call,
                child: const Icon(LucideIcons.info).iconXSmall().iconMutedForeground(),
              ),
            ],
          ),
          Text(countText).h3(color: accent),
          Text(
            context.strings.holdingsFlowBuyersSellers(
              holdings.buyersCount,
              holdings.sellersCount,
            ),
          ).muted().xSmall(),
        ],
      ),
    );
  }
}

class _ActivistCard extends StatelessWidget {
  const _ActivistCard({required this.holdings});

  final InstitutionalShareholding holdings;

  @override
  Widget build(BuildContext context) {
    final hasActive = holdings.hasActivistStakes;
    final accent = hasActive
        ? _themeRepo.caution(context.theme)
        : context.theme.colorScheme.mutedForeground;

    return Card(
      padding: context.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: ThemeRepo.spaceXSmall,
        children: [
          Row(
            spacing: ThemeRepo.spaceXSmall,
            children: [
              Icon(LucideIcons.megaphone, color: accent).iconXSmall(),
              Expanded(
                child: Text(context.strings.holdingsActivistTitle).muted().small(),
              ),
              Tooltip(
                tooltip: HintTooltip(context.strings.hintActivistStakes).call,
                child: const Icon(LucideIcons.info).iconXSmall().iconMutedForeground(),
              ),
            ],
          ),
          Text(
            hasActive
                ? context.strings.holdingsActivistActive(holdings.activistStakes.length)
                : context.strings.holdingsActivistNone,
          ).h3(color: hasActive ? accent : null),
          Text(hasActive ? 'Schedule 13D active filings' : 'Schedule 13G passive filers')
              .muted()
              .xSmall(),
        ],
      ),
    );
  }
}

