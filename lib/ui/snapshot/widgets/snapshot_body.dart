import 'package:flutter_animate/flutter_animate.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/snapshot/snapshot_state.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/snapshot/widgets/snapshot_failure_view.dart';
import 'package:pickstock/ui/snapshot/widgets/snapshot_idle_view.dart';
import 'package:pickstock/ui/snapshot/widgets/snapshot_loading_view.dart';
import 'package:pickstock/ui/snapshot/widgets/snapshot_report.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The report itself, without any surrounding chrome.
///
/// Used both as the snapshot screen's body and as the detail pane beside the
/// ticker list, so switching company there shows exactly the same report.
class SnapshotBody extends StatelessWidget {
  const SnapshotBody({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.select<SnapshotViewModel, SnapshotState>(
      (viewModel) => viewModel.state,
    );

    final body = switch (state) {
      SnapshotIdle() => const SnapshotIdleView(),
      SnapshotLoading() => const SnapshotLoadingView(),
      SnapshotFailed() => const SnapshotFailureView(),
      SnapshotLoaded() => const SnapshotReport(),
    };

    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ThemeRepo.contentMaxWidth,
          ),
          // Keyed on the state's runtime type so switching states replays the
          // entrance rather than morphing one layout into the next.
          child: KeyedSubtree(
            key: ValueKey(state.runtimeType),
            child: body.animate().fadeIn(duration: ThemeRepo.entranceDuration),
          ),
        ),
      ),
    );
  }
}
