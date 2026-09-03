import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:pickstock/data/snapshot/sic_industry.dart';
import 'package:pickstock/data/snapshot/sic_sector.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/watchlist/watchlist_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// One tap per sector, wrapping onto as many lines as the window needs.
///
/// A `Wrap` rather than a sideways scroll: twelve chips do fit one line on a
/// wide window, and on a narrow one the chips that no longer fit would
/// otherwise be off the edge with nothing to say they were there. The filter
/// bar above it wraps for the same reason, so the two behave alike as the
/// window closes.
class SectorFilterRow extends StatelessWidget {
  const SectorFilterRow({super.key});

  @override
  Widget build(BuildContext context) {
    final hasSectors = context.select<BrowseViewModel, bool>(
      (viewModel) => viewModel.hasSectors,
    );
    // Nothing classified: an ingest before sectors were collected, or a
    // company set the data sets do not cover.
    if (!hasSectors) return const SizedBox.shrink();

    return Padding(
      // The filter above already ends on a full gutter, so the chips take
      // none at the top and the same gutter below: even space either side of
      // the row, and the divider is no longer sitting on them.
      padding: EdgeInsets.fromLTRB(
        context.pageGutter,
        0,
        context.pageGutter,
        ThemeRepo.spaceMedium,
      ),
      child: Wrap(
        spacing: ThemeRepo.spaceSmall,
        runSpacing: ThemeRepo.spaceSmall,
        children: [
          const _AllChip(),
          for (final sector in SicSector.values) _SectorChip(sector),
        ],
      ),
    );
  }
}

/// The whole directory. Nothing to narrow, so no second half.
///
/// Filled only while the list really is everything. A chosen watchlist takes
/// it out too, not just a sector: with one in force the pane is showing a
/// handful of companies, and a lit "All" above them says the opposite.
class _AllChip extends StatelessWidget {
  const _AllChip();

  @override
  Widget build(BuildContext context) {
    final noSector = context.select<BrowseViewModel, bool>(
      (viewModel) => viewModel.sector == null,
    );
    final noList = context.select<WatchlistViewModel, bool>(
      (viewModel) => viewModel.selectedId == null,
    );

    return Button(
      style: _chipStyle(isSelected: noSector && noList, isOpen: false),
      // And it clears both, so that pressing it makes true what it claims.
      // Clearing only the sector would leave a chip that reads as unlit,
      // does nothing when pressed, and stays unlit.
      onPressed: () {
        context.read<BrowseViewModel>().selectSector(null);
        context.read<WatchlistViewModel>().select(null);
      },
      child: Text(context.strings.sectorAll),
    );
  }
}

/// One sector, as a split chip.
///
/// Two touch areas in one control, which is shadcn's split button: the label
/// filters the sector entire, as the chip always did, and the chevron beside
/// it opens the SEC industries inside that sector to narrow the filter to a
/// few of them. Built as a [ButtonGroup] so the seam between the two halves
/// is the group's own border — one chip to look at, two things to press,
/// without a second control in the row to explain.
class _SectorChip extends StatefulWidget {
  const _SectorChip(this.sector);

  final SicSector sector;

  @override
  State<_SectorChip> createState() => _SectorChipState();
}

class _SectorChipState extends State<_SectorChip> {
  final OverlayController _menu = OverlayController();

  @override
  void dispose() {
    _menu.dispose();
    super.dispose();
  }

  void _close() => _menu.close();

  /// Filters by sector, and drops the list filter on the way.
  ///
  /// A list and a sector are two answers to the same question — which of the
  /// directory am I looking at — so narrowing by one puts the other away
  /// rather than quietly intersecting with it and showing neither.
  void _select(BuildContext context, bool isWhole, SicSector sector) {
    context.read<BrowseViewModel>().selectSector(isWhole ? null : sector);
    context.read<WatchlistViewModel>().select(null);
  }

  void _open() {
    final viewModel = context.read<BrowseViewModel>();
    final theme = Theme.of(context);
    _menu.show<void>(
      context,
      MenuConfiguration(
        alignment: Alignment.topCenter,
        offset: const Offset(0, ThemeRepo.spaceXSmall),
        // The reason the arrow used to be unable to shut its own menu.
        // Left false — which is what `showDropdown` passes, and why this
        // builds the configuration by hand instead — the press that
        // dismisses the menu carries on to whatever is under it, so a press
        // on the chip closed the menu and then reopened it. Consumed, the
        // dismissal is the whole of what that press does, and any press on
        // the chip is a way out of the menu.
        consumeOutsideTaps: true,
        overlayBarrier: OverlayBarrier(
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
      ),
      // The menu ticks its own boxes as they are pressed, so it has to watch
      // the model rather than read it once. The providers sit above the
      // router and so above this overlay, but handing the model down
      // explicitly keeps the menu buildable wherever the overlay lands.
      builder: (_) => ChangeNotifierProvider<BrowseViewModel>.value(
        value: viewModel,
        child: _IndustryMenu(widget.sector),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sector = widget.sector;
    // As a record, so the three rebuild the chip together and a change to any
    // of them is one comparison rather than three subscriptions.
    final (isSelected, narrowedCount, industryCount) = context
        .select<BrowseViewModel, (bool, int, int)>(
          (viewModel) => (
            viewModel.sector == sector,
            viewModel.narrowedCountIn(sector),
            viewModel.industriesIn(sector).length,
          ),
        );

    // The controller notifies on opening and on closing, however the close
    // came about, so the chip's held look and the arrow follow the menu
    // rather than having to be kept in step with it by hand.
    return ListenableBuilder(
      listenable: _menu,
      builder: (context, _) => _chip(
        context,
        isSelected: isSelected,
        narrowedCount: narrowedCount,
        industryCount: industryCount,
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required bool isSelected,
    required int narrowedCount,
    required int industryCount,
  }) {
    final sector = widget.sector;
    final isOpen = _menu.hasOpenOverlay;

    // The label reads as the sector entire, so it hands back the sector
    // entire: from narrowed it widens rather than clearing, and only a chip
    // already showing all of its sector turns off. Clearing straight from a
    // narrowing would drop the sector on the way to widening it, which is the
    // opposite of what pressing its name asks for.
    final isWhole = isSelected && narrowedCount == 0;
    final label = Button(
      style: _chipStyle(isSelected: isSelected, isOpen: isOpen),
      // While the menu is down the whole chip is the way out of it. The
      // press is consumed by the dismissal before it arrives, so this is a
      // guard rather than the mechanism — but it is the guard that keeps a
      // press meant to close the menu from also refiltering the list under
      // it, which is worth keeping against a change in that consumption.
      onPressed: isOpen ? _close : () => _select(context, isWhole, sector),
      leading: Icon(sector.icon).iconXSmall(),
      // Set smaller than the label rather than in another colour: the chip
      // has a light and a dark variant and two states, and a size reads as
      // secondary in all four without a palette for each.
      trailing: narrowedCount == 0
          ? null
          : Text(
              context.strings.sectorNarrowedCount(narrowedCount, industryCount),
            ).xSmall(),
      child: Text(sector.getLabel(context.strings)),
    );

    // A sector the ingest found no filers for has nothing to narrow to, and a
    // menu of no options is worse than no menu.
    if (industryCount == 0) return label;

    return ButtonGroup(
      children: [
        ButtonGroupItem(child: label),
        ButtonGroupItem(
          child: Button(
            key: sectorNarrowKey(sector),
            style: _chipStyle(
              isSelected: isSelected,
              isOpen: isOpen,
              isIcon: true,
            ),
            onPressed: isOpen ? _close : _open,
            // The arrow turns over while the menu is down, so the half that
            // opened it reads as the half that will shut it.
            child: Icon(
              isOpen ? LucideIcons.chevronUp : LucideIcons.chevronDown,
            ).iconXSmall(),
          ),
        ),
      ],
    );
  }
}

/// The SEC industries inside one sector, each a checkbox.
///
/// The industries already picked are lifted to the top on opening, so a
/// narrowing stays visible without scrolling the whole sector to find it. The
/// order is taken once and held: a row that reshuffled itself as it was
/// ticked would move the next one out from under the pointer.
class _IndustryMenu extends StatefulWidget {
  const _IndustryMenu(this.sector);

  final SicSector sector;

  @override
  State<_IndustryMenu> createState() => _IndustryMenuState();
}

class _IndustryMenuState extends State<_IndustryMenu> {
  late final List<SicIndustryOption> _picked;
  late final List<SicIndustryOption> _rest;

  @override
  void initState() {
    super.initState();
    final viewModel = context.read<BrowseViewModel>();
    final options = viewModel.industriesIn(widget.sector);
    bool isPicked(SicIndustryOption option) =>
        viewModel.isIndustrySelected(widget.sector, option.sic);
    _picked = options.where(isPicked).toList();
    _rest = options.whereNot(isPicked).toList();
  }

  /// Whether the press that is being handled was made with shift held.
  ///
  /// Read from the keyboard rather than tracked, because a menu item hands on
  /// no modifiers with its callback. Live state, so it has to be read inside
  /// the press and not before it.
  static bool get _isAdding {
    final held = HardwareKeyboard.instance.logicalKeysPressed;
    return held.contains(LogicalKeyboardKey.shiftLeft) ||
        held.contains(LogicalKeyboardKey.shiftRight) ||
        held.contains(LogicalKeyboardKey.shift);
  }

  /// Picks industries, and drops the list filter on the way.
  ///
  /// A list and a sector are two answers to the same question — which of the
  /// directory am I looking at — so narrowing by one puts the other away
  /// rather than quietly intersecting with it and showing neither.
  void _narrow(void Function(BrowseViewModel) pick) {
    pick(context.read<BrowseViewModel>());
    context.read<WatchlistViewModel>().select(null);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BrowseViewModel>();
    final sector = widget.sector;
    final picked = viewModel.narrowedCountIn(sector);

    return ConstrainedBox(
      // Capped downwards only: a sector can hold forty industries, and SEC's
      // titles are long enough that wrapping them would cost more width in
      // height than letting the menu take the width it needs.
      constraints: const BoxConstraints(
        maxHeight: ThemeRepo.industryPopupMaxHeight,
      ),
      child: DropdownMenu(
        children: [
          MenuLabel(
            // The shift hint sits under the title rather than beside it: it
            // is an instruction, and a reader who already knows it should be
            // able to skip the line rather than read past it.
            trailing: picked > 1
                ? Button(
                    style: const ButtonStyle.primary(
                      size: ButtonSize.small,
                      density: ButtonDensity.dense,
                    ),
                    onPressed: () => closeOverlay(context),
                    child: Text(context.strings.sectorApplySelection),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.strings.sectorIndustriesHeader),
                Text(context.strings.sectorIndustriesHint).muted().xSmall(),
              ],
            ),
          ),
          // The row that carries the unnarrowed state, so an unticked list
          // never reads as a filter that has excluded everything.
          MenuCheckbox(
            value: picked == 0,
            autoClose: false,
            onChanged: (_, _) =>
                _narrow((model) => model.clearNarrowing(sector)),
            child: Text(context.strings.sectorAllIndustries).singleLine(),
          ),
          const MenuDivider(),
          for (final option in _picked) _checkbox(viewModel, option),
          if (_picked.isNotEmpty && _rest.isNotEmpty) const MenuDivider(),
          for (final option in _rest) _checkbox(viewModel, option),
        ],
      ),
    );
  }

  MenuCheckbox _checkbox(BrowseViewModel viewModel, SicIndustryOption option) {
    return MenuCheckbox(
      value: viewModel.isIndustrySelected(widget.sector, option.sic),
      // Closed by hand rather than by the menu, so that a plain press can
      // shut it and a shift-press cannot.
      autoClose: false,
      onChanged: (itemContext, _) {
        if (_isAdding) {
          // Building a selection: the menu stays up, and the header offers
          // the way out once there is more than one industry in it.
          _narrow((model) => model.toggleIndustry(widget.sector, option.sic));
          return;
        }
        // One industry, chosen outright, and done with the menu.
        _narrow((model) => model.selectOnlyIndustry(widget.sector, option.sic));
        closeOverlay(itemContext);
      },
      // The menu is only as wide as its longest title, so on that row the
      // count would otherwise sit flush against it.
      trailing: Padding(
        padding: const EdgeInsets.only(left: ThemeRepo.spaceMedium),
        child: Text(context.strings.sectorIndustryCount(option.companyCount))
            .muted()
            .xSmall(),
      ),
      child: Text(option.title).singleLine().ellipsis(),
    );
  }
}

/// Selected chips are filled, the rest outlined — as true of half a chip as
/// it was of the whole one.
///
/// A chip with its menu down takes a third look, neither of those: the filled
/// grey shadcn uses for a control being held open. It says the chip is in a
/// state it is waiting to come back out of, and it says so on both halves at
/// once, which is what makes the whole chip read as the way out. A dashed
/// outline would say the same, but only by adding a ring the chip does not
/// otherwise have — and every chip along the row would shift as it appeared.
ButtonStyle _chipStyle({
  required bool isSelected,
  required bool isOpen,
  bool isIcon = false,
}) {
  final density = isIcon ? ButtonDensity.icon : ButtonDensity.normal;
  if (isOpen) {
    return ButtonStyle.secondary(size: ButtonSize.small, density: density);
  }
  return isSelected
      ? ButtonStyle.primary(size: ButtonSize.small, density: density)
      : ButtonStyle.outline(size: ButtonSize.small, density: density);
}

/// The half of a sector's chip that opens its industries. Every chip carries
/// a chevron, and the sort control above the row carries another, so the half
/// is addressed by sector rather than by icon.
Key sectorNarrowKey(SicSector sector) => Key('sectorNarrow-${sector.name}');
