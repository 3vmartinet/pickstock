import 'package:flutter/services.dart';
import 'package:pickstock/data/snapshot/browse_sort.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/app_route.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/watchlist/widgets/watchlist_filter.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Narrows the directory by symbol or company name.
class TickerFilterBar extends StatelessWidget {
  const TickerFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.pageGutter,
        vertical: ThemeRepo.spaceMedium,
      ),
      alignment: Alignment.centerLeft,
      child: const Wrap(
        spacing: ThemeRepo.spaceMedium,
        runSpacing: ThemeRepo.spaceSmall,
        crossAxisAlignment: WrapCrossAlignment.center,
        // Wrap, not Row: the filter, the sort and the count together are too
        // wide for a narrow window.
        children: [
          _FilterField(),
          WatchlistFilter(),
          _SortSelect(),
          _MatchCount(),
        ],
      ),
    );
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<BrowseViewModel>();
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: ThemeRepo.filterFieldMaxWidth,
      ),
      child: TextField(
        controller: viewModel.filterController,
        placeholder: Text(context.strings.browseFilterPlaceholder),
        onChanged: viewModel.setQuery,
        textInputAction: TextInputAction.search,
        // The list is the result set, so enter takes whatever is at the top of
        // it rather than needing a separate suggestion dropdown.
        onSubmitted: (_) => _openBestMatch(context),
        features: const [
          InputFeature.leading(Icon(LucideIcons.search)),
          InputFeature.clear(),
        ],
      ),
    );
  }
}

/// Chooses what the list is ranked by, and with it what each row shows.
/// Opens the first company in the current results, if there is one.
void _openBestMatch(BuildContext context) {
  final best = context.read<BrowseViewModel>().companyAt(0);
  if (best == null) return;
  context.read<SnapshotViewModel>().search(best.ticker);
  if (!context.showsMasterDetail) {
    Navigator.of(context).pushNamed(AppRoute.company.path);
  }
}

class _SortSelect extends StatelessWidget {
  const _SortSelect();

  @override
  Widget build(BuildContext context) {
    final sort = context.select<BrowseViewModel, BrowseSort>(
      (viewModel) => viewModel.sort,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: ThemeRepo.sortSelectMaxWidth),
      child: Select<BrowseSort>(
        value: sort,
        itemBuilder: (context, item) => Text(item.getLabel(context.strings)),
        onChanged: (value) => value == null
            ? null
            : context.read<BrowseViewModel>().selectSort(value),
        popupConstraints: const BoxConstraints(
          minWidth: ThemeRepo.sortPopupMinWidth,
          maxHeight: ThemeRepo.sortPopupMaxHeight,
        ),
        // The popup defaults to the button's exact width, which wraps the
        // longer options over three lines. Letting it size to its content and
        // treating the button as a floor keeps every option on one line.
        overlayConfiguration: const PopoverConfiguration(
          // The same anchoring shadcn's own default uses, with only the width
          // rule changed.
          alignment: Alignment.topCenter,
          widthConstraint: PopoverConstraint.anchorMinSize,
        ),
        popup: SelectPopup(
          items: SelectItemList(
            children: [
              for (final option in BrowseSort.values)
                SelectItemButton(
                  value: option,
                  child: Text(option.getLabel(context.strings)).singleLine(),
                ),
            ],
          ),
        ).call,
      ),
    );
  }
}

class _MatchCount extends StatelessWidget {
  const _MatchCount();

  @override
  Widget build(BuildContext context) {
    final count = context.select<BrowseViewModel, int>(
      (viewModel) => viewModel.resultCount,
    );
    return Text(context.strings.browseMatchCount(count)).muted().small();
  }
}
