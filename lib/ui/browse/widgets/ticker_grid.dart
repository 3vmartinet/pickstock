import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/app_route.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/data/watchlist/watchlist.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/watchlist/watchlist_view_model.dart';
import 'package:pickstock/ui/watchlist/widgets/watchlist_marker.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();
ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// The directory itself: ten thousand-odd symbols, laid out in as many columns
/// as the window allows.
///
/// `GridView.builder` rather than a `Wrap`: only the visible tiles are ever
/// built, which is what keeps a list this long scrolling smoothly.
class TickerGrid extends StatefulWidget {
  const TickerGrid({super.key});

  @override
  State<TickerGrid> createState() => _TickerGridState();
}

class _TickerGridState extends State<TickerGrid> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    // Seeded from the view model, which outlives this route, so returning to
    // the list lands where it was left rather than back at the top.
    final viewModel = context.read<BrowseViewModel>();
    _controller = ScrollController(initialScrollOffset: viewModel.scrollOffset)
      ..addListener(() => viewModel.rememberScrollOffset(_controller.offset));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = context.select<BrowseViewModel, int>(
      (viewModel) => viewModel.resultCount,
    );
    if (count == 0) return const _NoMatches();

    return GridView.builder(
      controller: _controller,
      padding: context.pagePadding,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: ThemeRepo.tickerTileMaxWidth,
        childAspectRatio: ThemeRepo.tickerTileAspectRatio,
        crossAxisSpacing: ThemeRepo.spaceSmall,
        mainAxisSpacing: ThemeRepo.spaceSmall,
      ),
      itemCount: count,
      itemBuilder: (context, index) => _TickerTile(index),
    );
  }
}

class _TickerTile extends StatelessWidget {
  const _TickerTile(this.index);

  final int index;

  @override
  Widget build(BuildContext context) {
    final company = context.select<BrowseViewModel, Company?>(
      (viewModel) => viewModel.companyAt(index),
    );
    if (company == null) return const SizedBox.shrink();

    // Which tile the report beside the list is about. Without it the pane is
    // a hundred identical tiles and nothing says which one is open.
    final isSelected = context.select<SnapshotViewModel, bool>(
      (viewModel) => viewModel.selectedTicker == company.ticker,
    );

    final tile = Button(
      // Normal density rather than compact: the tile needs room to breathe,
      // and the ranked figure was running into the edge.
      //
      // Filled when it is the one on show: against a pane of outlined tiles a
      // filled one is findable without reading any of them. Filled rather
      // than inverted, because the figures on a tile are coloured for a pale
      // background — green for growth, red against it — and they stop
      // meaning anything on a dark one.
      style: isSelected
          ? const ButtonStyle.secondary()
          : const ButtonStyle.outline(),
      alignment: AlignmentDirectional.centerStart,
      onPressed: () {
        context.read<SnapshotViewModel>().search(company.ticker);
        // Beside the list the report is already on screen; on a narrow window
        // it gets a screen of its own.
        if (!context.showsMasterDetail) {
          Navigator.of(context).pushNamed(AppRoute.company.path);
        }
      },
      // Symbol over name on the left, ranked figure on the right: the figure
      // is what the list is sorted by, so it lines up down the right edge for
      // comparison rather than sitting under each name.
      child: Row(
        spacing: ThemeRepo.spaceSmall,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: ThemeRepo.spaceXSmall,
              children: [
                Row(
                  spacing: ThemeRepo.spaceXSmall,
                  children: [
                    Flexible(
                      child: Text(company.ticker)
                          .mono()
                          .small()
                          .semiBold()
                          .singleLine(),
                    ),
                    _WatchlistMarkers(cik: company.cik),
                  ],
                ),
                Text(
                  company.name,
                  maxLines: ThemeRepo.tickerNameMaxLines,
                  overflow: TextOverflow.ellipsis,
                ).muted().xSmall().textStart(),
              ],
            ),
          ),
          _Figure(company: company),
        ],
      ),
    );

    if (!isSelected) return tile;

    // The fill alone is close in weight to the tiles around it, so the
    // selected one also takes a ring in the accent colour. Applied over the
    // button's own decoration rather than by wrapping the tile in a border,
    // which would grow it and jog the grid every time the selection moved.
    return Semantics(
      selected: true,
      child: ButtonStyleOverride(
        decoration: (context, states, value) => value is BoxDecoration
            ? value.copyWith(
                border: Border.all(
                  color: context.theme.colorScheme.primary,
                  width: ThemeRepo.tickerTileSelectedRing,
                ),
              )
            : value,
        child: tile,
      ),
    );
  }
}

/// The lists a company belongs to, as coloured marks beside its symbol.
///
/// A tile is small, so this stops at a few of them: the point is to recognise
/// a company you are already following while scanning, not to enumerate.
class _WatchlistMarkers extends StatelessWidget {
  const _WatchlistMarkers({required this.cik});

  final String cik;

  @override
  Widget build(BuildContext context) {
    final lists = context.select<WatchlistViewModel, List<Watchlist>>(
      (viewModel) => viewModel.listsFor(cik),
    );
    if (lists.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: ThemeRepo.spaceXSmall,
      children: [
        for (final list in lists.take(ThemeRepo.watchlistDotsPerTile))
          WatchlistMarker(list: list),
      ],
    );
  }
}

/// The figure for whatever the list is ranked by: a growth rate, or the
/// latest revenue when the ordering is alphabetical.
///
/// The row has the space, and a name alone gives no reason to pick one company
/// over another.
class _Figure extends StatelessWidget {
  const _Figure({required this.company});

  final Company company;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BrowseViewModel>();
    final figure = viewModel.figureFor(company);

    if (figure == null) {
      return Text(context.strings.browseNoFigure).muted().xSmall();
    }

    return Text(
      viewModel.showsGrowth
          ? _formatRepo.signedPercent(figure)
          : _formatRepo.compactCurrency(figure),
    ).mono().xSmall().singleLine(
      color: viewModel.showsGrowth
          ? _themeRepo.forOutcome(context.theme, isGood: figure >= 0)
          : null,
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    final query = context.select<BrowseViewModel, String>(
      (viewModel) => viewModel.query,
    );
    // An empty list is not a failed search, and telling the user to try
    // another spelling would be nonsense.
    final emptyList = context.select<BrowseViewModel, bool>(
      (viewModel) => viewModel.isEmptyWatchlist && !viewModel.isFiltered,
    );
    final listName = context.select<WatchlistViewModel, String?>(
      (viewModel) => viewModel.selected?.name,
    );

    return Padding(
      padding: const EdgeInsets.all(ThemeRepo.spaceXXLarge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: ThemeRepo.spaceSmall,
        children: [
          Icon(emptyList ? LucideIcons.listX : LucideIcons.searchX)
              .iconXLarge()
              .iconMutedForeground(),
          Text(
            emptyList
                ? context.strings.watchlistNoMatchesTitle
                : context.strings.browseEmptyTitle,
          ).h4().textCenter(),
          Text(
            emptyList
                ? context.strings.watchlistNoMatchesBody(listName ?? '')
                : context.strings.browseEmptyBody(query),
          ).muted().textCenter(),
        ],
      ),
    );
  }
}
