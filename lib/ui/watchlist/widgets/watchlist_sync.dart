import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/watchlist/watchlist_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Keeps the grid's filter in step with the chosen list.
///
/// The two view models are siblings, so neither can watch the other. This sits
/// in the widget tree where both are visible and pushes one into the other,
/// which keeps the dependency in the layer that already knows about both.
class WatchlistSync extends StatelessWidget {
  const WatchlistSync({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final members = context.select<WatchlistViewModel, Set<String>?>(
      (viewModel) => viewModel.selectedMembers,
    );
    // In the build rather than a listener: `applyWatchlist` is a no-op when
    // nothing changed, and this way the grid never renders a frame behind.
    context.read<BrowseViewModel>().applyWatchlist(members);
    return child;
  }
}
