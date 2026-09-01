import 'package:flutter_animate/flutter_animate.dart';
import 'package:pickstock/data/snapshot/report_tab.dart';
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
    final tab = context.select<SnapshotViewModel, ReportTab>(
      (viewModel) => viewModel.reportTab,
    );

    // The loaded report scrolls itself, so its header and tabs can stay pinned
    // above the part that moves. The other states are a single card and scroll
    // as a whole.
    if (state is SnapshotLoaded) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ThemeRepo.contentMaxWidth,
          ),
          // No fade of its own: the pinned header would blink on every tab
          // change, and the tab body underneath already animates itself.
          child: KeyedSubtree(
            // A new key builds a new scroll position, so opening a tab starts
            // at the top of it rather than wherever the last one was left.
            key: ValueKey(tab),
            child: const SnapshotReport(),
          ),
        ),
      );
    }

    final body = switch (state) {
      SnapshotLoading() => const SnapshotLoadingView(),
      SnapshotFailed() => const SnapshotFailureView(),
      _ => const SnapshotIdleView(),
    };

    return SingleChildScrollView(
      // Keyed on the state's runtime type so switching states replays the
      // entrance rather than morphing one layout into the next.
      key: ValueKey(state.runtimeType),
      padding: context.pagePadding,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ThemeRepo.contentMaxWidth,
          ),
          child: body.animate().fadeIn(duration: ThemeRepo.entranceDuration),
        ),
      ),
    );
  }
}
