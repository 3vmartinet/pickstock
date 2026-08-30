import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/snapshot/snapshot_state.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// What the screen shows when a lookup could not be completed.
class SnapshotFailureView extends StatelessWidget {
  const SnapshotFailureView({super.key});

  @override
  Widget build(BuildContext context) {
    final failed = context.select<SnapshotViewModel, SnapshotFailed?>(
      (viewModel) => viewModel.state is SnapshotFailed
          ? viewModel.state as SnapshotFailed
          : null,
    );
    if (failed == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ThemeRepo.spaceLarge),
      child: Alert.destructive(
        leading: const Icon(LucideIcons.triangleAlert),
        title: Text(context.strings.errorTitle),
        content: Text(failed.failure.describe(context.strings, failed.ticker)),
        trailing: const _RetryButton(),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton();

  @override
  Widget build(BuildContext context) {
    return SecondaryButton(
      size: ButtonSize.small,
      onPressed: () => context.read<SnapshotViewModel>().retry(),
      leading: const Icon(LucideIcons.refreshCw),
      child: Text(context.strings.retry),
    );
  }
}
