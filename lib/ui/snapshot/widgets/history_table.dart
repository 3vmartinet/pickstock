import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/snapshot/history_column.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// Every reported fiscal year, line by line.
///
/// The table is only used where all eight columns actually fit: squeezed any
/// narrower it wraps figures mid-number, and scrolling it sideways hides the
/// very columns being compared. Below that width the same figures are restated
/// as one card per year, which stays readable down to the narrowest phone.
class HistoryTable extends StatelessWidget {
  const HistoryTable({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth < ThemeRepo.historyTableMinWidth
          ? const _YearCards()
          : const _WideTable(),
    );
  }
}

class _WideTable extends StatelessWidget {
  const _WideTable();

  @override
  Widget build(BuildContext context) {
    final years = context.select<SnapshotViewModel, List<FiscalYearFigures>>(
      (viewModel) => viewModel.historyYears,
    );
    if (years.isEmpty) return const SizedBox.shrink();

    // Only reached at widths where every column fits, so the table lays out at
    // its natural width with no scrolling and no squeezing.
    return Card(
      padding: EdgeInsets.zero,
      child: Table(
        rows: [
          TableHeader(
            cells: [
              for (final column in HistoryColumn.values)
                _headingCell(context, column),
            ],
          ),
          for (final figures in years)
            TableRow(
              cells: [
                for (final column in HistoryColumn.values)
                  _valueCell(context, column, figures),
              ],
            ),
        ],
      ),
    );
  }

  TableCell _headingCell(BuildContext context, HistoryColumn column) {
    if (column == HistoryColumn.fiscalYear) {
      return const TableCell(child: _SortableYearHeading());
    }
    return TableCell(
      child: Container(
        padding: ThemeRepo.tableCellPadding,
        alignment: column.isNumeric
            ? Alignment.centerRight
            : Alignment.centerLeft,
        // Single-line throughout: a wrapped cell would split a figure across
        // two lines, which reads as two numbers.
        child: Text(column.getHeading(context.strings))
            .muted()
            .semiBold()
            .xSmall()
            .singleLine(),
      ),
    );
  }

  TableCell _valueCell(
    BuildContext context,
    HistoryColumn column,
    FiscalYearFigures figures,
  ) {
    final sentiment = column.getSentiment(figures);
    final text = Text(column.getCellText(context.strings, figures))
        .small()
        .singleLine();

    return TableCell(
      child: Container(
        padding: ThemeRepo.tableCellPadding,
        alignment: column.isNumeric
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: column == HistoryColumn.fiscalYear
            ? text.semiBold()
            : sentiment == null
            ? text.mono()
            : text.mono(
                color: _themeRepo.forOutcome(context.theme, isGood: sentiment),
              ),
      ),
    );
  }
}

/// One card per fiscal year, for windows too narrow to hold the table.
class _YearCards extends StatelessWidget {
  const _YearCards();

  @override
  Widget build(BuildContext context) {
    final yearCount = context.select<SnapshotViewModel, int>(
      (viewModel) => viewModel.reportedYearCount,
    );

    return Column(
      spacing: ThemeRepo.spaceSmall,
      children: [
        for (int index = 0; index < yearCount; index++) _YearCard(index),
      ],
    );
  }
}

class _YearCard extends StatelessWidget {
  const _YearCard(this.yearIndex);

  final int yearIndex;

  @override
  Widget build(BuildContext context) {
    final figures = context.select<SnapshotViewModel, FiscalYearFigures?>(
      (viewModel) => viewModel.historyFiguresAt(yearIndex),
    );
    if (figures == null) return const SizedBox.shrink();

    return Card(
      padding: context.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: ThemeRepo.spaceSmall,
        children: [
          Text(HistoryColumn.fiscalYear.getCellText(context.strings, figures))
              .semiBold(),
          for (final column in HistoryColumn.values)
            if (column != HistoryColumn.fiscalYear)
              _YearCardRow(column: column, yearIndex: yearIndex),
        ],
      ),
    );
  }
}

class _YearCardRow extends StatelessWidget {
  const _YearCardRow({required this.column, required this.yearIndex});

  final HistoryColumn column;
  final int yearIndex;

  @override
  Widget build(BuildContext context) {
    final figures = context.select<SnapshotViewModel, FiscalYearFigures?>(
      (viewModel) => viewModel.historyFiguresAt(yearIndex),
    );
    if (figures == null) return const SizedBox.shrink();

    final sentiment = column.getSentiment(figures);
    return Row(
      children: [
        Expanded(
          child: Text(column.getHeading(context.strings)).muted().small(),
        ),
        Text(column.getCellText(context.strings, figures)).mono().small(
          color: sentiment == null
              ? null
              : _themeRepo.forOutcome(context.theme, isGood: sentiment),
        ),
      ],
    );
  }
}

/// The `Year` column heading, which also sorts the table.
class _SortableYearHeading extends StatelessWidget {
  const _SortableYearHeading();

  @override
  Widget build(BuildContext context) {
    final isNewestFirst = context.select<SnapshotViewModel, bool>(
      (viewModel) => viewModel.isHistoryNewestFirst,
    );

    return Padding(
      padding: ThemeRepo.tableCellPadding,
      child: Align(
        alignment: Alignment.centerLeft,
        child: GhostButton(
          size: ButtonSize.small,
          density: ButtonDensity.compact,
          onPressed: context.read<SnapshotViewModel>().toggleHistoryOrder,
          trailing: Icon(
            isNewestFirst ? LucideIcons.arrowDown : LucideIcons.arrowUp,
          ).iconXSmall(),
          child: Text(HistoryColumn.fiscalYear.getHeading(context.strings))
              .muted()
              .semiBold()
              .xSmall(),
        ),
      ),
    );
  }
}
