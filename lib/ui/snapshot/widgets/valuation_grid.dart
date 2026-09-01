import 'package:get_it/get_it.dart';
import 'package:pickstock/data/valuation/valuation.dart';
import 'package:pickstock/data/valuation/valuation_metric.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/widgets/responsive_grid.dart';
import 'package:provider/provider.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// The ratios behind the verdict, each coloured by where it falls.
///
/// The verdict card says cheap or dear in one word; this is the evidence, so
/// the reader can disagree with it on a metric they trust more.
class ValuationGrid extends StatelessWidget {
  const ValuationGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      minItemWidth: ThemeRepo.ratioCardMinWidth,
      spacing: ThemeRepo.spaceSmall,
      children: [
        for (final metric in ValuationMetric.values) _RatioCard(metric),
      ],
    );
  }
}

class _RatioCard extends StatelessWidget {
  const _RatioCard(this.metric);

  final ValuationMetric metric;

  @override
  Widget build(BuildContext context) {
    final valuation = context.select<SnapshotViewModel, Valuation?>(
      (viewModel) => viewModel.valuation,
    );
    if (valuation == null) return const SizedBox.shrink();

    final value = metric.getFormattedValue(valuation);
    // A ratio with nothing to say reads muted rather than being dropped: which
    // ratios a company cannot support is itself informative.
    final colour = value == null
        ? _themeRepo.unknown(context.theme)
        : _themeRepo.forOutcome(
            context.theme,
            isGood: metric.getSentiment(valuation),
          );

    return Card(
      padding: const EdgeInsets.all(ThemeRepo.spaceMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: ThemeRepo.spaceXSmall,
        children: [
          Row(
            spacing: ThemeRepo.spaceXSmall,
            children: [
              Expanded(
                child: Text(metric.getLabel(context.strings))
                    .muted()
                    .xSmall()
                    .singleLine(),
              ),
              Tooltip(
                tooltip: HintTooltip(metric.getHint(context.strings)).call,
                child: const Icon(LucideIcons.info)
                    .iconXSmall()
                    .iconMutedForeground(),
              ),
            ],
          ),
          Text(value ?? context.strings.verdictUnknown)
              .large()
              .semiBold(color: colour)
              .singleLine(),
        ],
      ),
    );
  }
}
