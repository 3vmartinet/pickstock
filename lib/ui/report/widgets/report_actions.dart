import 'package:pickstock/data/report/valuation_report.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/report/jobs_view_model.dart';
import 'package:pickstock/ui/widgets/app_dialog.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Rename or delete one saved report.
class ReportActions extends StatelessWidget {
  const ReportActions({super.key, required this.report, this.onDeleted});

  final ValuationReport report;

  /// Called after a delete, so a screen showing the report can leave.
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<JobsViewModel>();

    return Tooltip(
      tooltip: HintTooltip(context.strings.jobsTooltip).call,
      child: GhostButton(
        density: ButtonDensity.icon,
        onPressed: () => showDropdown(
          context: context,
          builder: (_) => DropdownMenu(
            children: [
              MenuButton(
                leading: const Icon(LucideIcons.pencil).iconXSmall(),
                onPressed: (menuContext) => _rename(menuContext, viewModel),
                child: Text(context.strings.reportRename),
              ),
              MenuButton(
                leading: const Icon(LucideIcons.trash2).iconXSmall(),
                onPressed: (menuContext) => _delete(menuContext, viewModel),
                child: Text(context.strings.reportDelete),
              ),
            ],
          ),
        ),
        child: const Icon(LucideIcons.ellipsis).iconXSmall(),
      ),
    );
  }

  Future<void> _rename(BuildContext context, JobsViewModel viewModel) {
    return showAppDialog<void>(
      context,
      builder: (_) => ChangeNotifierProvider<JobsViewModel>.value(
        value: viewModel,
        child: _RenameDialog(report: report),
      ),
    );
  }

  Future<void> _delete(BuildContext context, JobsViewModel viewModel) async {
    final confirmed = await showAppDialog<bool>(
      context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.strings.reportDelete),
        content: Text(context.strings.reportDeleteConfirm(report.name)),
        actions: [
          OutlineButton(
            onPressed: () => closeAppDialog(dialogContext, false),
            child: Text(context.strings.watchlistCancel),
          ),
          DestructiveButton(
            onPressed: () => closeAppDialog(dialogContext, true),
            child: Text(context.strings.reportDelete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await viewModel.deleteReport(report.id);
      onDeleted?.call();
    }
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.report});

  final ValuationReport report;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.report.name,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    context.read<JobsViewModel>().renameReport(widget.report.id, name);
    closeAppDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.strings.reportRename),
      content: SizedBox(
        width: ThemeRepo.dialogWidth,
        child: TextField(
          controller: _name,
          autofocus: true,
          maxLength: reportNameMaxLength,
          onSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        OutlineButton(
          onPressed: () => closeAppDialog(context),
          child: Text(context.strings.watchlistCancel),
        ),
        PrimaryButton(
          onPressed: _save,
          child: Text(context.strings.watchlistSave),
        ),
      ],
    );
  }
}
