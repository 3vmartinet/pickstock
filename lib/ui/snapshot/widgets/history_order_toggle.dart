import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Flips the history between newest-first and oldest-first.
///
/// Lives in the section heading rather than the table header so that the
/// compact layout, which shows cards and has no header row, has the same
/// control in the same place.
class HistoryOrderToggle extends StatelessWidget {
  const HistoryOrderToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final isNewestFirst = context.select<SnapshotViewModel, bool>(
      (viewModel) => viewModel.isHistoryNewestFirst,
    );

    return Tooltip(
      tooltip: TooltipContainer(child: Text(context.strings.sortByYear)).call,
      child: GhostButton(
        size: ButtonSize.small,
        onPressed: context.read<SnapshotViewModel>().toggleHistoryOrder,
        leading: Icon(
          isNewestFirst
              ? LucideIcons.arrowDownWideNarrow
              : LucideIcons.arrowUpNarrowWide,
        ),
        child: Text(
          isNewestFirst
              ? context.strings.sortNewestFirst
              : context.strings.sortOldestFirst,
        ),
      ),
    );
  }
}
