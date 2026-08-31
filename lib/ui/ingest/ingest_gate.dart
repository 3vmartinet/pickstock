import 'package:pickstock/ui/ingest/ingest_screen.dart';
import 'package:pickstock/ui/ingest_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Stands in front of every screen until the local database holds data.
///
/// The app has nothing to show without it — no ticker directory to search and
/// no figures to report — so the download is a full-screen step rather than a
/// background task with a disabled UI behind it. It also blocks during a
/// refresh, because an ingest clears the tables before repopulating them.
class IngestGate extends StatelessWidget {
  const IngestGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final state = context.select<IngestViewModel, IngestState>(
      (viewModel) => viewModel.state,
    );

    return switch (state) {
      IngestReady() => child,
      IngestChecking() => const IngestScreen(isChecking: true),
      IngestRequired() ||
      IngestFailed() ||
      IngestActive() => const IngestScreen(),
    };
  }
}
