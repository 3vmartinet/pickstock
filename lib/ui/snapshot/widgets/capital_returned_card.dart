import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:pickstock/ui/widgets/responsive_grid.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();
ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// What the owners actually got, against what the business earned.
///
/// The question none of the three tabs answered: a company can generate cash
/// for a decade and hand none of it back, and the price is being asked to
/// believe one story or the other. Absent for a filer that reports neither a
/// dividend nor a buyback, which is most of them.
class CapitalReturnedCard extends StatelessWidget {
  const CapitalReturnedCard({super.key});

  @override
  Widget build(BuildContext context) {
    final figures = context.select<SnapshotViewModel, FiscalYearFigures?>(
      (viewModel) => viewModel.latestFigures,
    );
    final returned = figures?.capitalReturned;
    if (figures == null || returned == null || returned <= 0) {
      return const SizedBox.shrink();
    }

    final share = figures.capitalReturnedPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: ThemeRepo.spaceSmall,
      children: [
        Row(
          spacing: ThemeRepo.spaceSmall,
          children: [
            const Icon(LucideIcons.handCoins).iconSmall().iconMutedForeground(),
            Text(context.strings.sectionCapitalReturned).semiBold().small(),
            Tooltip(
              tooltip: HintTooltip(context.strings.capitalReturnedHint).call,
              child: const Icon(LucideIcons.info)
                  .iconXSmall()
                  .iconMutedForeground(),
            ),
          ],
        ),
        ResponsiveGrid(
          minItemWidth: ThemeRepo.ratioCardMinWidth,
          spacing: ThemeRepo.spaceSmall,
          children: [
            _Figure(
              label: context.strings.labelCapitalReturned,
              value: _formatRepo.compactCurrency(returned),
              note: share == null
                  ? context.strings.capitalReturnedNote
                  : context.strings.capitalReturnedShare(
                      _formatRepo.percent(share),
                    ),
              // Returning more than the year earned is not a fault — a company
              // can pay out of the bank — but it is not repeatable either, so
              // it is left uncoloured rather than called good news.
              isGood: share == null ? null : share <= _allOfIt,
            ),
            _Figure(
              label: context.strings.labelDividends,
              value: figures.dividendsPaid == null
                  ? null
                  : _formatRepo.compactCurrency(figures.dividendsPaid!),
              note: context.strings.capitalReturnedNote,
            ),
            _Figure(
              label: context.strings.labelBuybacks,
              value: figures.buybacks == null
                  ? null
                  : _formatRepo.compactCurrency(figures.buybacks!),
              note: context.strings.capitalReturnedNote,
            ),
          ],
        ),
      ],
    );
  }
}

/// Everything the year generated. Past this a company is paying out of the
/// bank rather than out of the business.
const double _allOfIt = 100;

/// One labelled figure, shaped like the ratios on the valuation tab.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.note,
    this.isGood,
  });

  final String label;

  /// `null` reads muted rather than being dropped: a company that pays a
  /// dividend and never buys back is saying something by the absence.
  final String? value;

  final String note;
  final bool? isGood;

  @override
  Widget build(BuildContext context) {
    return Card(
      padding: const EdgeInsets.all(ThemeRepo.spaceMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: ThemeRepo.spaceXSmall,
        children: [
          Text(label).muted().xSmall().singleLine(),
          Text(value ?? context.strings.capitalReturnedNothing)
              .large()
              .semiBold(
                color: value == null
                    ? _themeRepo.unknown(context.theme)
                    : _themeRepo.forOutcome(context.theme, isGood: isGood),
              )
              .singleLine(),
          Text(note).muted().xSmall(),
        ],
      ),
    );
  }
}
