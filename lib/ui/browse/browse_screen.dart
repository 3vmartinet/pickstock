import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/browse/widgets/sector_filter_row.dart';
import 'package:pickstock/ui/browse/widgets/ticker_filter_bar.dart';
import 'package:pickstock/ui/browse/widgets/ticker_grid.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/snapshot/widgets/snapshot_body.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The whole EDGAR ticker directory, filterable, with every row a shortcut
/// into the report for that symbol.
class BrowseScreen extends StatelessWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The view model outlives this route, so a re-ingest since the last visit
    // has to be picked up on the way in.
    context.read<BrowseViewModel>().ensureCurrent();

    return Scaffold(
      headers: const [
        _BrowseAppBar(),
        TickerFilterBar(),
        SectorFilterRow(),
        Divider(),
      ],
      // Side by side where there is room: picking a company then swaps the
      // report beside the list instead of navigating away from it.
      child: context.showsMasterDetail
          ? const _MasterDetail()
          : const TickerGrid(),
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

/// The list beside the selected company's report.
class _MasterDetail extends StatelessWidget {
  const _MasterDetail();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(width: ThemeRepo.masterListWidth, child: TickerGrid()),
        VerticalDivider(),
        Expanded(child: SnapshotBody()),
      ],
    );
  }
}
