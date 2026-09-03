import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:pickstock/data/snapshot/browse_sort.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/browse/widgets/debt_free_filter.dart';
import 'package:pickstock/ui/browse/widgets/positive_cash_flow_filter.dart';
import 'package:pickstock/ui/app_route.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/watchlist/widgets/watchlist_filter.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

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
          DebtFreeFilter(),
          PositiveCashFlowFilter(),
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

/// How wide the longest option's label renders at.
///
/// Measured rather than guessed: the options are localised and the list grows,
/// so a hand-picked constant would be wrong the first time either changed.
double _widestOptionWidth(BuildContext context) {
  final style = context.theme.typography.small;
  var widest = 0.0;
  for (final option in BrowseSort.values) {
    final painter = TextPainter(
      text: TextSpan(text: option.getLabel(context.strings), style: style),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    widest = math.max(widest, painter.width);
  }
  return widest;
}

/// Opens the first company in the current results, if there is one.
void _openBestMatch(BuildContext context) {
  final best = context.read<BrowseViewModel>().companyAt(0);
  if (best == null) return;
  context.read<SnapshotViewModel>().search(best.ticker);
  if (!context.showsMasterDetail) {
    Navigator.of(context).pushNamed(AppRoute.company.path);
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

    // Sized to the longest option rather than to whichever one is chosen, so
    // the control does not resize as you use it and the popup — which matches
    // its anchor — fits every option on one line without stretching to the
    // window.
    //
    // Capped rather than clamped to the available width: the bar is a `Wrap`,
    // which hands its children unbounded constraints, so there is no available
    // width to clamp against. The cap is well clear of what the labels
    // measure and only bites on a font or a locale that runs long.
    return SizedBox(
      width: math.min(
        _widestOptionWidth(context) + ThemeRepo.selectChromeWidth,
        ThemeRepo.sortSelectMaxWidth,
      ),
      child: _SortDropdown(sort: sort),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.sort});

  final BrowseSort sort;

  @override
  Widget build(BuildContext context) {
    return Select<BrowseSort>(
      value: sort,
      itemBuilder: (context, item) =>
          Text(item.getLabel(context.strings)).singleLine(),
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
                child: Text(option.getLabel(context.strings)).singleLine(),
              ),
          ],
        ),
      ).call,
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
