import 'package:pickstock/ui/app_view_model.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Closes the source pane when the reader moves to another company.
///
/// The two view models are siblings, so neither can watch the other. This sits
/// in the widget tree where both are visible and pushes one into the other,
/// which keeps the dependency in the layer that already knows about both — the
/// same arrangement the watchlist filter uses.
///
/// An article about Apple beside NVIDIA's figures is worse than no article:
/// side by side, it reads as though it were about NVIDIA.
class SourceSync extends StatelessWidget {
  const SourceSync({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cik = context.select<SnapshotViewModel, String?>(
      (viewModel) => viewModel.snapshot?.company.cik,
    );
    // In the build rather than a listener: `applySelectedCompany` is a no-op
    // while the company is the one the page was opened from, and this way the
    // pane never renders a frame beside the wrong report.
    context.read<AppViewModel>().applySelectedCompany(cik);
    return child;
  }
}
