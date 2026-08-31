import 'package:pickstock/data/watchlist/watchlist.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/watchlist/watchlist_view_model.dart';
import 'package:pickstock/ui/watchlist/widgets/watchlist_dot.dart';
import 'package:pickstock/ui/watchlist/widgets/watchlist_editor.dart';
import 'package:pickstock/ui/widgets/app_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Puts the open company into any of the user's lists.
///
/// A menu of checkboxes rather than a picker: a company belongs to as many
/// lists as the user likes, and each one is a toggle that leaves the menu open
/// so several can be set in a row.
class AddToWatchlistButton extends StatelessWidget {
  const AddToWatchlistButton({super.key, required this.cik});

  final String cik;

  @override
  Widget build(BuildContext context) {
    final lists = context.select<WatchlistViewModel, List<Watchlist>>(
      (viewModel) => viewModel.watchlists,
    );
    final memberships = context.select<WatchlistViewModel, List<Watchlist>>(
      (viewModel) => viewModel.listsFor(cik),
    );
    final viewModel = context.read<WatchlistViewModel>();

    return Tooltip(
      tooltip: TooltipContainer(child: Text(context.strings.watchlistAddTo))
          .call,
      child: OutlineButton(
        density: ButtonDensity.compact,
        onPressed: () => showDropdown(
          context: context,
          builder: (menuContext) => DropdownMenu(
            children: [
              MenuLabel(child: Text(context.strings.watchlistAddTo)),
              for (final list in lists)
                MenuCheckbox(
                  value: memberships.contains(list),
                  // Left open: adding one company to three lists should not
                  // mean opening the menu three times.
                  autoClose: false,
                  onChanged: (_, _) => viewModel.toggle(list.id, cik),
                  trailing: WatchlistDot(colourIndex: list.colourIndex),
                  child: Text(list.name),
                ),
              const MenuDivider(),
              MenuButton(
                leading: const Icon(LucideIcons.plus).iconXSmall(),
                onPressed: (_) => _createList(context, viewModel),
                child: Text(context.strings.watchlistNew),
              ),
            ],
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: ThemeRepo.spaceSmall,
          children: [
            const Icon(LucideIcons.listPlus).iconXSmall(),
            Text(
              memberships.isEmpty
                  ? context.strings.watchlistNotInAny
                  : context.strings.watchlistInLists(memberships.length),
            ).small(),
            for (final list in memberships.take(ThemeRepo.watchlistDotsPerTile))
              WatchlistDot(colourIndex: list.colourIndex),
          ],
        ),
      ),
    );
  }

  /// Makes a list and drops the company straight into it, which is what
  /// "new list" from this menu is always for.
  Future<void> _createList(
    BuildContext context,
    WatchlistViewModel viewModel,
  ) async {
    final created = await showAppDialog<int>(
      context,
      builder: (_) => ChangeNotifierProvider<WatchlistViewModel>.value(
        value: viewModel,
        child: WatchlistEditor(initialColour: viewModel.suggestedColourIndex),
      ),
    );
    if (created != null) await viewModel.add(created, cik);
  }
}
