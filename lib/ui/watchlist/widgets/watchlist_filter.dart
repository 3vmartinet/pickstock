import 'package:pickstock/data/watchlist/watchlist.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/watchlist/watchlist_view_model.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/watchlist/widgets/watchlist_marker.dart';
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

    // Filled while a list is in force, like every other filter that is on:
    // the pane is showing that list's companies and the control that chose
    // them should say so rather than looking like an untouched dropdown.
    return Button(
      style: selected == null
          ? const ButtonStyle.outline()
          : const ButtonStyle.primary(),
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
              _ListRow(list: list, viewModel: viewModel),
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
            WatchlistMarker(list: selected),
          Text(selected?.name ?? context.strings.watchlistAll),
          const Icon(LucideIcons.chevronDown).iconXSmall(),
        ],
      ),
    );
  }
}

/// One list in the menu: its name, and the way into renaming or deleting it.
///
/// Two buttons rather than one row, so each half has its own bounds and
/// lights up on its own. A single row would light up whole while the pointer
/// sat on the arrow, which says the whole row is about to do one thing when
/// the two halves do different ones.
///
/// A [MenuItem] because that is what the menu takes; the halves are ordinary
/// buttons in a row, and the left one is a `MenuButton` so it keeps the
/// padding, the leading alignment and the keyboard handling of every other
/// row in the menu.
class _ListRow extends StatelessWidget implements MenuItem {
  const _ListRow({required this.list, required this.viewModel});

  final Watchlist list;
  final WatchlistViewModel viewModel;

  /// Shows the list, from the top.
  ///
  /// The clearing rides on the press rather than on the list changing,
  /// because pressing the list you are already on is still a request to see
  /// it — and that is exactly when a filter is most likely to be hiding it.
  /// Read off a change of list instead, that press changes nothing and so
  /// does nothing, which is how it came to leave the list hidden.
  void _show(BuildContext context) {
    viewModel.select(list.id);
    context.read<BrowseViewModel>().clearNarrowings();
  }

  @override
  bool get hasLeading => true;

  @override
  OverlayController? get overlayController => null;

  @override
  Widget build(BuildContext context) {
    // Stretched to a common height, so the two halves light up as two cells of
    // one row rather than as a tall one beside a short one.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            // No `subMenu` here, which is what used to keep the menu open: a
            // `MenuButton` carrying one opens that instead of closing, so
            // picking a list left the menu standing with the edit actions
            // sprung out beside it.
            child: MenuButton(
              leading: WatchlistMarker(list: list),
              trailing: Text(context.strings.watchlistCount(list.companyCount))
                  .muted()
                  .xSmall(),
              onPressed: (_) => _show(context),
              child: Text(list.name).singleLine(),
            ),
          ),
          _ListActions(list: list, viewModel: viewModel),
        ],
      ),
    );
  }
}

/// The arrow half: the way into renaming or deleting the list.
///
/// Its own press rather than part of the row, so the row can mean one thing —
/// show me this list — and reaching for the actions is a decision rather than
/// something a passing cursor does. On press rather than on hover: a menu
/// that opens as the pointer crosses it has to guess when the pointer is on
/// its way somewhere else, and guesses wrong on the way to the actions
/// themselves.
class _ListActions extends StatefulWidget {
  const _ListActions({required this.list, required this.viewModel});

  final Watchlist list;
  final WatchlistViewModel viewModel;

  @override
  State<_ListActions> createState() => _ListActionsState();
}

class _ListActionsState extends State<_ListActions> {
  final OverlayController _menu = OverlayController();

  @override
  void dispose() {
    _menu.dispose();
    super.dispose();
  }

  /// Runs an action on the list, with both menus out of its way first.
  ///
  /// The dialog belongs to the screen, not to the menu it was reached from,
  /// and a menu left standing behind it would still be there once it closed.
  void _run(void Function(BuildContext) action) {
    final host = context;
    _menu.close();
    closeOverlay(host);
    action(host);
  }

  void _toggle() {
    if (_menu.hasOpenOverlay) {
      _menu.close();
      return;
    }
    final theme = Theme.of(context);
    _menu.show<void>(
      context,
      MenuConfiguration(
        // Out to the side, where a submenu belongs.
        alignment: Alignment.topLeft,
        anchorAlignment: Alignment.topRight,
        offset: const Offset(ThemeRepo.spaceXSmall, 0),
        // Without this the press that dismisses the menu carries on to the
        // arrow underneath and opens it straight back up.
        consumeOutsideTaps: true,
        overlayBarrier: OverlayBarrier(
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        // The parent menu is a `MenuGroup`, and this is not part of it; kept
        // out of that group it survives the pointer moving across the rows
        // beneath it.
        regionGroupId: _menu,
      ),
      builder: (_) => DropdownMenu(
        children: [
          MenuButton(
            leading: const Icon(LucideIcons.pencil).iconXSmall(),
            onPressed: (_) =>
                _run((host) => _edit(host, widget.viewModel, widget.list)),
            child: Text(context.strings.watchlistEdit),
          ),
          // The starred list is where the star puts things, so it always has
          // to exist. Left out rather than greyed out: an option that is
          // never available on this list is not an option, and a row that
          // only ever refuses is a question the menu keeps asking.
          if (!widget.list.isDefault)
            MenuButton(
              leading: const Icon(LucideIcons.trash2).iconXSmall(),
              onPressed: (_) => _run(
                (host) => _confirmDelete(host, widget.viewModel, widget.list),
              ),
              child: Text(context.strings.watchlistDelete),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _menu,
      builder: (context, _) => Button(
        // The same variance the rows themselves use, so the half lights up in
        // the same colour as the half beside it rather than looking like a
        // control that wandered into a menu.
        style: const ButtonStyle(
          variance: ButtonVariance.menu,
          density: ButtonDensity.icon,
        ),
        onPressed: _toggle,
        child: const Icon(LucideIcons.chevronRight).iconSmall(),
      ),
    );
  }
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
