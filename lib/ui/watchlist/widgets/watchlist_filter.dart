import 'package:pickstock/data/watchlist/watchlist.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/watchlist/watchlist_view_model.dart';
import 'package:pickstock/ui/watchlist/widgets/watchlist_dot.dart';
import 'package:pickstock/ui/watchlist/widgets/watchlist_editor.dart';
import 'package:pickstock/ui/widgets/app_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Narrows the directory to one list, and manages the lists themselves.
///
/// One control for both: the place you go to see a list is the natural place to
/// rename it, and a separate management screen for four fields would be a
/// screen nobody finds.
class WatchlistFilter extends StatelessWidget {
  const WatchlistFilter({super.key});

  @override
  Widget build(BuildContext context) {
    final lists = context.select<WatchlistViewModel, List<Watchlist>>(
      (viewModel) => viewModel.watchlists,
    );
    final selected = context.select<WatchlistViewModel, Watchlist?>(
      (viewModel) => viewModel.selected,
    );
    final viewModel = context.read<WatchlistViewModel>();

    return OutlineButton(
      onPressed: () => showDropdown(
        context: context,
        builder: (_) => DropdownMenu(
          children: [
            MenuButton(
              leading: const Icon(LucideIcons.layoutGrid).iconXSmall(),
              onPressed: (_) => viewModel.select(null),
              child: Text(context.strings.watchlistAll),
            ),
            if (lists.isNotEmpty) const MenuDivider(),
            for (final list in lists)
              MenuButton(
                leading: WatchlistDot(colourIndex: list.colourIndex),
                trailing: Text(
                  context.strings.watchlistCount(list.companyCount),
                ).muted().xSmall(),
                subMenu: [
                  MenuButton(
                    leading: const Icon(LucideIcons.pencil).iconXSmall(),
                    onPressed: (menuContext) =>
                        _edit(menuContext, viewModel, list),
                    child: Text(context.strings.watchlistEdit),
                  ),
                  MenuButton(
                    // The starred list is where the star puts things, so it
                    // always has to exist.
                    enabled: !list.isDefault,
                    leading: const Icon(LucideIcons.trash2).iconXSmall(),
                    onPressed: (menuContext) =>
                        _confirmDelete(menuContext, viewModel, list),
                    child: Text(context.strings.watchlistDelete),
                  ),
                ],
                onPressed: (_) => viewModel.select(list.id),
                child: Text(list.name),
              ),
            const MenuDivider(),
            MenuButton(
              leading: const Icon(LucideIcons.plus).iconXSmall(),
              onPressed: (menuContext) => _edit(menuContext, viewModel, null),
              child: Text(context.strings.watchlistNew),
            ),
          ],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: ThemeRepo.spaceSmall,
        children: [
          if (selected == null)
            const Icon(LucideIcons.listFilter).iconXSmall()
          else
            WatchlistDot(colourIndex: selected.colourIndex),
          Text(selected?.name ?? context.strings.watchlistAll),
          const Icon(LucideIcons.chevronDown).iconXSmall(),
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WatchlistViewModel viewModel,
    Watchlist? existing,
  ) {
    return showAppDialog<void>(
      context,
      builder: (_) => ChangeNotifierProvider<WatchlistViewModel>.value(
        value: viewModel,
        child: WatchlistEditor(
          existing: existing,
          initialColour: viewModel.suggestedColourIndex,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WatchlistViewModel viewModel,
    Watchlist list,
  ) async {
    final confirmed = await showAppDialog<bool>(
      context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.strings.watchlistDelete),
        content: Text(context.strings.watchlistDeleteConfirm(list.name)),
        actions: [
          OutlineButton(
            onPressed: () => closeAppDialog(dialogContext, false),
            child: Text(context.strings.watchlistCancel),
          ),
          DestructiveButton(
            onPressed: () => closeAppDialog(dialogContext, true),
            child: Text(context.strings.watchlistDelete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await viewModel.delete(list.id);
  }
}
