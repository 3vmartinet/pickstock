import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/app_view_model.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/browse/widgets/sector_filter_row.dart';
import 'package:pickstock/ui/browse/widgets/ticker_filter_bar.dart';
import 'package:pickstock/ui/browse/widgets/ticker_grid.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/snapshot/widgets/snapshot_body.dart';
import 'package:pickstock/ui/snapshot/widgets/source_pane.dart';
import 'package:pickstock/ui/snapshot/widgets/source_sync.dart';
import 'package:pickstock/ui/watchlist/widgets/watchlist_sync.dart';
import 'package:pickstock/ui/widgets/brand_mark.dart';
import 'package:pickstock/ui/report/widgets/jobs_button.dart';
import 'package:pickstock/ui/widgets/ingest_button.dart';
import 'package:pickstock/ui/widgets/theme_toggle_button.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The app's main screen: every symbol EDGAR knows about, filterable and
/// sortable, with the selected company's report beside it where there is room.
///
/// There is no separate search screen — the filter above the list is the
/// search, and the list is its results.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The view model outlives this route, so a re-ingest since the last visit
    // has to be picked up on the way in.
    context.read<BrowseViewModel>().ensureCurrent();

    final isLoading = context.select<SnapshotViewModel, bool>(
      (viewModel) => viewModel.isLoading,
    );

    return Scaffold(
      loadingProgressIndeterminate: isLoading,
      headers: const [
        _HomeAppBar(),
        TickerFilterBar(),
        SectorFilterRow(),
        Divider(),
      ],
      // Side by side where there is room: picking a company then swaps the
      // report beside the list instead of navigating away from it.
      child: const WatchlistSync(child: SourceSync(child: _Body())),
    );
  }
}

class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar();

  @override
  Widget build(BuildContext context) {
    final total = context.select<BrowseViewModel, int>(
      (viewModel) => viewModel.totalCount,
    );

    return AppBar(
      // Overridden so the mark starts on the same left edge as the filter
      // below it; shadcn's own default is 22.5, which lines up with nothing.
      padding: EdgeInsets.symmetric(
        horizontal: context.pageGutter,
        vertical: ThemeRepo.appBarVerticalPadding,
      ),
      leading: const [BrandMark()],
      title: Text(context.strings.appTitle),
      subtitle: context.isCompact
          ? null
          : Text(context.strings.browseSubtitle(total)),
      // The ingest button last: it is the only one of the three that is
      // sometimes a labelled button and sometimes a line of text, and a slot
      // that changes width belongs at the end of the row rather than between
      // two icons it would shove about.
      trailing: const [JobsButton(), ThemeToggleButton(), IngestButton()],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) =>
      context.showsMasterDetail ? const _MasterDetail() : const TickerGrid();
}

/// The list beside the selected company's report, and a source beside both.
class _MasterDetail extends StatelessWidget {
  const _MasterDetail();

  @override
  Widget build(BuildContext context) {
    // Read, not watched: the width is only needed to seed the divider, and
    // recording a drag must not rebuild the panel that reported it.
    final viewModel = context.read<AppViewModel>();
    // Watched: a headline opening a source adds a pane.
    final source = context.select<AppViewModel, String?>(
      (model) => model.openedSource,
    );

    // Draggable dividers: widening the list fits more tile columns without
    // giving up the report beside it. Where the first was left is remembered,
    // so the split survives a relaunch.
    return ResizablePanel.horizontal(
      children: [
        ResizablePane(
          initialSize: viewModel.masterPaneWidth,
          minSize: ThemeRepo.masterListMinWidth,
          maxSize: ThemeRepo.masterListMaxWidth,
          // On release rather than on every frame of the drag: one write at
          // the end of a gesture instead of sixty a second.
          onSizeChangeEnd: viewModel.rememberMasterPaneWidth,
          child: const TickerGrid(),
        ),
        const ResizablePane.flex(child: SnapshotBody()),
        // Only while a source is open. Not remembered like the list's width:
        // the pane comes and goes with a headline, and a width saved for
        // something that is usually closed is a width nobody chose.
        if (source != null)
          ResizablePane(
            initialSize: ThemeRepo.sourcePaneWidth,
            minSize: ThemeRepo.sourcePaneMinWidth,
            child: SourcePane(url: source),
          ),
      ],
    );
  }
}
