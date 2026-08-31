import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
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
      // Square cells: the symbol, the name over a few lines and the ranked
      // figure each get their own row inside the tile, instead of the name
      // being squeezed between two fixed columns.
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: ThemeRepo.tickerTileMaxWidth,
        childAspectRatio: 1,
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

    return Button(
      // Normal density rather than compact: the tile needs room to breathe,
      // and the ranked figure was running into the edge.
      style: const ButtonStyle.outline(),
      alignment: AlignmentDirectional.topStart,
      onPressed: () {
        context.read<SnapshotViewModel>().search(company.ticker);
        // Beside the list the report is already on screen, so there is
        // nothing to go back to; on a narrow window it lives behind this
        // route.
        if (!context.showsMasterDetail) Navigator.of(context).pop();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: ThemeRepo.spaceXSmall,
        children: [
          Text(company.ticker).mono().small().semiBold().singleLine(),
          Expanded(
            child: Text(
              company.name,
              maxLines: ThemeRepo.tickerNameMaxLines,
              overflow: TextOverflow.ellipsis,
            ).muted().xSmall().textStart(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _Figure(company: company),
          ),
        ],
      ),
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

    return Padding(
      padding: const EdgeInsets.all(ThemeRepo.spaceXXLarge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: ThemeRepo.spaceSmall,
        children: [
          const Icon(LucideIcons.searchX).iconXLarge().iconMutedForeground(),
          Text(context.strings.browseEmptyTitle).h4().textCenter(),
          Text(context.strings.browseEmptyBody(query)).muted().textCenter(),
        ],
      ),
    );
  }
}
