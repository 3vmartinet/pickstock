import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The directory itself: ten thousand-odd symbols, laid out in as many columns
/// as the window allows.
///
/// `GridView.builder` rather than a `Wrap`: only the visible tiles are ever
/// built, which is what keeps a list this long scrolling smoothly.
class TickerGrid extends StatelessWidget {
  const TickerGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.select<BrowseViewModel, int>(
      (viewModel) => viewModel.resultCount,
    );
    if (count == 0) return const _NoMatches();

    return GridView.builder(
      padding: context.pagePadding,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: ThemeRepo.tickerTileMaxWidth,
        mainAxisExtent: ThemeRepo.tickerTileHeight,
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
      style: const ButtonStyle.outline(density: ButtonDensity.compact),
      // Run the lookup, then step back to the report that is already mounted
      // behind this screen.
      onPressed: () {
        context.read<SnapshotViewModel>().search(company.ticker);
        Navigator.of(context).pop();
      },
      child: Row(
        spacing: ThemeRepo.spaceSmall,
        children: [
          SizedBox(
            width: ThemeRepo.tickerSymbolColumnWidth,
            child: Text(company.ticker).mono().small().semiBold().singleLine(),
          ),
          Expanded(
            child: Text(company.name)
                .muted()
                .xSmall()
                .singleLine()
                .ellipsis()
                .textStart(),
          ),
        ],
      ),
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
