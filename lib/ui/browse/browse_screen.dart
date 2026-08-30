import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/browse/widgets/ticker_filter_bar.dart';
import 'package:pickstock/ui/browse/widgets/ticker_grid.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The whole EDGAR ticker directory, filterable, with every row a shortcut
/// into the report for that symbol.
class BrowseScreen extends StatelessWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BrowseViewModel(),
      child: const _BrowseView(),
    );
  }
}

class _BrowseView extends StatelessWidget {
  const _BrowseView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      headers: [_BrowseAppBar(), TickerFilterBar(), Divider()],
      child: TickerGrid(),
    );
  }
}

class _BrowseAppBar extends StatelessWidget {
  const _BrowseAppBar();

  @override
  Widget build(BuildContext context) {
    final total = context.select<BrowseViewModel, int>(
      (viewModel) => viewModel.totalCount,
    );

    return AppBar(
      leading: const [_BackButton()],
      title: Text(context.strings.browseTitle),
      subtitle: Text(context.strings.browseSubtitle(total)),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      tooltip: TooltipContainer(child: Text(context.strings.browseBack)).call,
      child: GhostButton(
        density: ButtonDensity.icon,
        onPressed: Navigator.of(context).pop,
        child: const Icon(LucideIcons.arrowLeft),
      ),
    );
  }
}
