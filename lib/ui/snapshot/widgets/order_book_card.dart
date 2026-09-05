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

/// Revenue already under contract, and what it says about the years ahead.
///
/// Absent for the great majority of filers, which report no order book at all
/// — so this is a block that appears rather than a column of dashes in the
/// history. Where it does appear it is the only figure in the report that
/// looks forwards: everything else is what has already been earned.
class OrderBookCard extends StatelessWidget {
  const OrderBookCard({super.key});

  @override
  Widget build(BuildContext context) {
    final figures = context.select<SnapshotViewModel, FiscalYearFigures?>(
      (viewModel) => viewModel.latestFigures,
    );
    final book = figures?.backlog;
    if (figures == null || book == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: ThemeRepo.spaceLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: ThemeRepo.spaceSmall,
        children: [
          Row(
            spacing: ThemeRepo.spaceSmall,
            children: [
              const Icon(LucideIcons.clipboardList)
                  .iconSmall()
                  .iconMutedForeground(),
              Text(context.strings.sectionOrderBook).semiBold().small(),
              Tooltip(
                tooltip: HintTooltip(context.strings.orderBookHint).call,
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
                label: context.strings.labelOrderBook,
                // At human scale, like the market value on the valuation
                // card: a book runs to hundreds of billions, and the same
                // figure in millions is seven digits nobody reads.
                value: _formatRepo.compactCurrency(book),
                note: context.strings.orderBookAsAt(figures.fiscalYear),
              ),
              _Figure(
                label: context.strings.labelOrderBookYears,
                value: figures.backlogYears == null
                    ? null
                    : context.strings.orderBookYears(
                        _formatRepo.ratio(figures.backlogYears!),
                      ),
                note: context.strings.orderBookYearsNote,
              ),
              _Figure(
                label: context.strings.labelOrderBookChange,
                value: figures.backlogGrowthPercent == null
                    ? null
                    : _formatRepo.signedPercent(figures.backlogGrowthPercent!),
                note: context.strings.orderBookChangeNote,
                // The one figure here with a direction worth colouring: a book
                // that grew is next year's revenue already sold.
                isGood: figures.backlogGrowthPercent == null
                    ? null
                    : figures.backlogGrowthPercent! >= 0,
              ),
            ],
          ),
          // Said out loud, because it is the whole reason the book is worth
          // reading: revenue is what has been earned and the book is what has
          // been sold, and the second falling under the first is the earliest
          // warning a filing gives.
          if (figures.isBookShrinkingUnderRevenue ?? false)
            Text(context.strings.orderBookWarning).muted().xSmall(),
        ],
      ),
    );
  }
}

/// One labelled figure, shaped like the ratios on the valuation tab.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.note,
    this.isGood,
  });

  final String label;

  /// `null` reads muted rather than being dropped: which figures a company
  /// cannot support is itself informative.
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
          Text(value ?? context.strings.verdictUnknown)
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
