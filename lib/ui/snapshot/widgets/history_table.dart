import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/period_figures.dart';
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
          ? const _PeriodCards()
          : const _WideTable(),
    );
  }
}

class _WideTable extends StatelessWidget {
  const _WideTable();

  @override
  Widget build(BuildContext context) {
    final rows = context.select<SnapshotViewModel, List<PeriodFigures>>(
      (viewModel) => viewModel.historyRows,
    );
    if (rows.isEmpty) return const SizedBox.shrink();

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
          for (final figures in rows)
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
    if (column == HistoryColumn.period) {
      return const TableCell(child: _SortablePeriodHeading());
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
    PeriodFigures figures,
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
        child: column == HistoryColumn.period
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
class _PeriodCards extends StatelessWidget {
  const _PeriodCards();

  @override
  Widget build(BuildContext context) {
    final rowCount = context.select<SnapshotViewModel, int>(
      (viewModel) => viewModel.historyRowCount,
    );

    return Column(
      spacing: ThemeRepo.spaceSmall,
      children: [
        for (int index = 0; index < rowCount; index++) _PeriodCard(index),
      ],
    );
  }
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard(this.rowIndex);

  final int rowIndex;

  @override
  Widget build(BuildContext context) {
    final figures = context.select<SnapshotViewModel, PeriodFigures?>(
      (viewModel) => viewModel.historyFiguresAt(rowIndex),
    );
    if (figures == null) return const SizedBox.shrink();

    return Card(
      padding: context.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: ThemeRepo.spaceSmall,
        children: [
          Text(HistoryColumn.period.getCellText(context.strings, figures))
              .semiBold(),
          for (final column in HistoryColumn.values)
            if (column != HistoryColumn.period)
              _PeriodCardRow(column: column, rowIndex: rowIndex),
        ],
      ),
    );
  }
}

class _PeriodCardRow extends StatelessWidget {
  const _PeriodCardRow({required this.column, required this.rowIndex});

  final HistoryColumn column;
  final int rowIndex;

  @override
  Widget build(BuildContext context) {
    final figures = context.select<SnapshotViewModel, PeriodFigures?>(
      (viewModel) => viewModel.historyFiguresAt(rowIndex),
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

/// The period column heading, which also sorts the table.
class _SortablePeriodHeading extends StatelessWidget {
  const _SortablePeriodHeading();

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
          child: Text(HistoryColumn.period.getHeading(context.strings))
              .muted()
              .semiBold()
              .xSmall(),
        ),
      ),
    );
  }
}
