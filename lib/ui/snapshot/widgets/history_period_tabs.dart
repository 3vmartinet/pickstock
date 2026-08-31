import 'package:pickstock/data/snapshot/history_period.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Switches the history between annual and quarterly.
///
/// `Tabs` is the header-only control in shadcn — it reports an index and
/// leaves the body alone — which suits a section whose content is already
/// driven by the view model.
class HistoryPeriodTabs extends StatelessWidget {
  const HistoryPeriodTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final period = context.select<SnapshotViewModel, HistoryPeriod>(
      (viewModel) => viewModel.historyPeriod,
    );
    final hasQuarters = context.select<SnapshotViewModel, bool>(
      (viewModel) => viewModel.hasQuarterlyHistory,
    );

    // Nothing quarterly on file: a tab that opens onto an empty table is
    // worse than no tab at all.
    if (!hasQuarters) return const SizedBox.shrink();

    return Tabs(
      index: period.index,
      onChanged: (index) => context
          .read<SnapshotViewModel>()
          .selectHistoryPeriod(HistoryPeriod.values[index]),
      children: [
        for (final option in HistoryPeriod.values)
          TabItem(child: Text(option.getLabel(context.strings))),
      ],
    );
  }
}
