import 'dart:async';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/research/framework_score.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/valuation/valuation_verdict.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/app_route.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/browse/framework_scores_view_model.dart';
import 'package:pickstock/ui/browse/widgets/framework_gauge.dart';
import 'package:pickstock/ui/browse/list_valuation_view_model.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/data/watchlist/watchlist.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/watchlist/watchlist_view_model.dart';
import 'package:pickstock/ui/watchlist/widgets/watchlist_marker.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

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
    // A new filter takes companies away; whatever of them was waiting to be
    // priced is dropped rather than spending the quote budget on tiles that
    // are no longer there.
    final results = context.select<BrowseViewModel, List<Company>>(
      (viewModel) => viewModel.results,
    );
    context.read<ListValuationViewModel>().retainWithin(results);
    // Narrowed to a verdict while the rest of the list is still being priced,
    // the matches so far are not all there will be. Placeholder tiles after
    // them say so, until the last of the candidates has been judged.
    final isFilteredByVerdict = context.select<BrowseViewModel, bool>(
      (viewModel) => viewModel.verdictFilter != null,
    );
    final isSweeping = context.select<ListValuationViewModel, bool>(
      (viewModel) => viewModel.isSweeping,
    );
    final isValuing = isFilteredByVerdict && isSweeping;
    if (count == 0 && !isValuing) return const _NoMatches();

    // The tile's shape depends on how many fit across, so the width has to be
    // known before the delegate is built.
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = context.pagePadding;
        final available = constraints.maxWidth - padding.horizontal;
        // The delegate's own arithmetic, so the shape chosen here is the
        // shape it lays out: it divides by the tile's width plus the gap
        // between two of them, not by the width alone.
        const stride = ThemeRepo.tickerTileMaxWidth + ThemeRepo.spaceSmall;
        final columns = (available / stride).ceil();
        // Enough to finish the row the matches end on and fill a few more,
        // so the list keeps its grid while it waits.
        final placeholders = isValuing
            ? (columns - count % columns) % columns +
                  columns * ThemeRepo.tickerPlaceholderRows
            : 0;

        return GridView.builder(
          controller: _controller,
          padding: padding,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: ThemeRepo.tickerTileMaxWidth,
            childAspectRatio: columns == 1
                ? ThemeRepo.tickerTileWideAspectRatio
                : ThemeRepo.tickerTileAspectRatio,
            crossAxisSpacing: ThemeRepo.spaceSmall,
            mainAxisSpacing: ThemeRepo.spaceSmall,
          ),
          itemCount: count + placeholders,
          itemBuilder: (context, index) => index < count
              ? _TickerTile(index)
              : _PlaceholderTile(key: tilePlaceholderKey(index - count)),
        );
      },
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
      // Symbol over name on the left, the framework rating on the right, where
      // it lines up down the right edge of a column of tiles for comparison.
      child: Row(
        spacing: ThemeRepo.spaceMedium,
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
                    _VerdictMark(company: company, isSelected: isSelected),
                    _WatchlistMarkers(cik: company.cik),
                  ],
                ),
                // Flexible so the name yields when the tile is short rather
                // than running out of the bottom of it: given less room than
                // two lines need, the text ends in an ellipsis instead of
                // being cut through the middle of a letter.
                Flexible(
                  child: Text(
                    company.name,
                    maxLines: ThemeRepo.tickerNameMaxLines,
                    overflow: TextOverflow.ellipsis,
                  ).muted().xSmall().textStart(),
                ),
              ],
            ),
          ),
          _FrameworkRating(company: company),
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

/// One of the placeholder tiles after a verdict-filtered list still being
/// priced, by its position among them.
Key tilePlaceholderKey(int index) => ValueKey('tilePlaceholder-$index');

/// A tile-shaped stand-in for a match that may yet come in: the outline of a
/// tile, with the symbol and name greyed out and shimmering, as the report
/// does while it loads.
///
/// The outline stays out of the skeleton so the placeholder keeps the
/// tile's edge; only what would be text shimmers.
class _PlaceholderTile extends StatelessWidget {
  const _PlaceholderTile({super.key});

  /// Never legible, but it gives the bones their line lengths.
  static const String _ticker = 'TICK';
  static const String _name = 'Placeholder company name';

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.border),
          borderRadius: theme.borderRadiusMd,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ThemeRepo.spaceMedium,
            vertical: ThemeRepo.spaceSmall,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: ThemeRepo.spaceXSmall,
            children: [
              const Text(_ticker).mono().small().semiBold().singleLine(),
              const Text(_name, maxLines: 1).muted().xSmall(),
            ],
          ).asSkeleton(),
        ),
      ),
    );
  }
}

/// The lists a company belongs to, as coloured marks beside its symbol.
///
/// A tile is small, so this stops at a few of them: the point is to recognise
/// a company you are already following while scanning, not to enumerate.
/// The valuation verdict after the symbol, as the valuation tab carries it
/// after its label: the same glyph, size and colour, and nothing at all until
/// there is a price to judge against.
///
/// Asks for the company to be priced as the tile is built, which is what
/// limits the pricing to the tiles actually on screen.
///
/// The selected tile follows the report beside it instead: the report has
/// the company's own discount rate, where the list makes do with a cached one
/// or the assumed one, and a tile disagreeing with the tab next to it would
/// leave the reader wondering which to believe.
class _VerdictMark extends StatelessWidget {
  const _VerdictMark({required this.company, required this.isSelected});

  final Company company;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final listValuation = context.read<ListValuationViewModel>();
    listValuation.request(company);

    final listed = context.select<ListValuationViewModel, ValuationVerdict?>(
      (viewModel) => viewModel.verdictFor(company.cik),
    );
    final reported = context.select<SnapshotViewModel, ValuationVerdict?>(
      (viewModel) => isSelected ? viewModel.valuation?.verdict : null,
    );
    // Kept by the list too, so the tile still says the same once another
    // company is selected. Not from inside this build, which may not notify.
    // An unknown verdict is the report short of a price, not a judgement, and
    // would only hide the list's own.
    if (reported != null &&
        reported != ValuationVerdict.unknown &&
        reported != listed) {
      scheduleMicrotask(() => listValuation.adopt(company.cik, reported));
    }
    final verdict = reported ?? listed;
    if (verdict == null) {
      final isPending = context.select<ListValuationViewModel, bool>(
        (viewModel) => viewModel.isPending(company.cik),
      );
      return isPending
          ? _PendingVerdictMark(key: tilePendingKey(company.cik))
          : const SizedBox.shrink();
    }
    if (verdict == ValuationVerdict.unknown) return const SizedBox.shrink();

    return Icon(
      key: tileVerdictKey(company.cik),
      verdict.icon,
      color: _themeRepo.forOutcome(context.theme, isGood: verdict.isGood),
    ).iconXSmall();
  }
}

/// The verdict mark on one company's tile.
Key tileVerdictKey(String cik) => ValueKey('tileVerdict-$cik');

/// The animated placeholder on a tile still waiting to be priced.
Key tilePendingKey(String cik) => ValueKey('tilePending-$cik');

/// A verdict not yet in: the arrow flipping between up and down, swept by a
/// highlight from left to right — the way a working session's title shimmers
/// in Claude Code.
///
/// Muted, and neither green nor red: it has not found anything, and a colour
/// would read as an answer. The flip says which question is being asked —
/// up or down — and the sweep says it is being asked now, which a still arrow
/// in grey would not.
///
/// Held still where the system asks for less motion, as one muted arrow.
class _PendingVerdictMark extends StatelessWidget {
  const _PendingVerdictMark({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    final muted = scheme.mutedForeground;

    Widget arrow(IconData icon) => Icon(icon, color: muted).iconXSmall();

    if (MediaQuery.disableAnimationsOf(context)) {
      return arrow(LucideIcons.trendingUp);
    }

    const flip = ThemeRepo.verdictPendingFlip;
    return Animate(
      onPlay: (controller) => controller.repeat(),
      effects: [
        // One cycle is both arrows: up for the first half, down for the
        // second.
        CustomEffect(
          duration: flip * 2,
          builder: (context, value, _) => arrow(
            value < 0.5 ? LucideIcons.trendingUp : LucideIcons.trendingDown,
          ),
        ),
        // A sweep across each arrow, level rather than at the default slant,
        // in the text colour so it reads as light passing over the glyph.
        ShimmerEffect(duration: flip, color: scheme.foreground, angle: 0),
        ShimmerEffect(
          delay: flip,
          duration: flip,
          color: scheme.foreground,
          angle: 0,
        ),
      ],
      child: arrow(LucideIcons.trendingUp),
    );
  }
}

/// The coloured dots for the lists a company is on, other than the starred
/// one: the star sat badly beside the symbol and the rating, and is left off
/// the tile for now. The report still shows it.
class _WatchlistMarkers extends StatelessWidget {
  const _WatchlistMarkers({required this.cik});

  final String cik;

  @override
  Widget build(BuildContext context) {
    final lists = context
        .select<WatchlistViewModel, List<Watchlist>>(
          (viewModel) => viewModel.listsFor(cik),
        )
        .where((list) => !list.isDefault)
        .toList();
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

/// The framework rating where the seven questions have been asked about the
/// company, and nothing where they have not.
///
/// No ranked figure beside it: the sort still orders the list by one, but
/// what a company made of the framework says more than a ratio any of them
/// has.
class _FrameworkRating extends StatelessWidget {
  const _FrameworkRating({required this.company});

  final Company company;

  @override
  Widget build(BuildContext context) {
    final score = context.select<FrameworkScoresViewModel, FrameworkScore?>(
      (viewModel) => viewModel.scoreFor(company.cik),
    );
    if (score == null) return const SizedBox.shrink();
    return FrameworkGauge(key: frameworkGaugeKey(company.cik), score: score);
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
    // Narrowed to a verdict and priced through, an empty list is short of
    // matches, not a failed search. While it is still being priced the grid
    // shows placeholder tiles instead of this.
    final byVerdict = context.select<BrowseViewModel, bool>(
      (viewModel) =>
          viewModel.verdictFilter != null &&
          viewModel.verdictCandidates.isNotEmpty,
    );
    if (byVerdict) {
      return _EmptyMessage(
        icon: LucideIcons.searchX,
        title: context.strings.verdictFilterNoneTitle,
        body: context.strings.verdictFilterNoneBody,
      );
    }

    return _EmptyMessage(
      icon: emptyList ? LucideIcons.listX : LucideIcons.searchX,
      title: emptyList
          ? context.strings.watchlistNoMatchesTitle
          : context.strings.browseEmptyTitle,
      body: emptyList
          ? context.strings.watchlistNoMatchesBody(listName ?? '')
          : context.strings.browseEmptyBody(query),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ThemeRepo.spaceXXLarge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: ThemeRepo.spaceSmall,
        children: [
          Icon(icon).iconXLarge().iconMutedForeground(),
          Text(title).h4().textCenter(),
          Text(body).muted().textCenter(),
        ],
      ),
    );
  }
}
