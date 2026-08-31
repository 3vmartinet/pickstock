import 'package:pickstock/data/snapshot/browse_sort.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Narrows the directory by symbol or company name.
class TickerFilterBar extends StatelessWidget {
  const TickerFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.isCompact
            ? ThemeRepo.spaceMedium
            : ThemeRepo.spaceXLarge,
        vertical: ThemeRepo.spaceMedium,
      ),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: ThemeRepo.contentMaxWidth),
        // Wrap, not Row: the filter, the sort and the count together are too
        // wide for a narrow window.
        child: const Wrap(
          spacing: ThemeRepo.spaceMedium,
          runSpacing: ThemeRepo.spaceSmall,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [_FilterField(), _SortSelect(), _MatchCount()],
        ),
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
        features: const [
          InputFeature.leading(Icon(LucideIcons.search)),
          InputFeature.clear(),
        ],
      ),
    );
  }
}

/// Chooses what the list is ranked by, and with it what each row shows.
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
          maxHeight: ThemeRepo.sortPopupMaxHeight,
        ),
        popup: SelectPopup(
          items: SelectItemList(
            children: [
              for (final option in BrowseSort.values)
                SelectItemButton(
                  value: option,
                  child: Text(option.getLabel(context.strings)),
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
