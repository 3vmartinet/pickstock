import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// One narrowing of the directory with a setting to it, as a chip on the
/// filter bar that opens a menu of its settings.
///
/// shadcn's dropdown-menu trigger: an outline button with a chevron while the
/// filter is off, filled while it is on — the same rule the list filter and
/// the sector chips follow — and the held grey of a control whose menu is down
/// while it is open. Its label states the setting in force, so the bar reads
/// as the filter it is applying without opening anything.
///
/// Shared rather than written out per filter, so the row of them cannot drift
/// apart in height or weight, and a new question about a company's finances is
/// a menu and not another copy of the chip.
class BrowseDropdownFilter extends StatefulWidget {
  const BrowseDropdownFilter({
    super.key,
    required this.icon,
    required this.label,
    required this.hint,
    required this.isOn,
    required this.menuBuilder,
  });

  final IconData icon;
  final String label;

  /// What the filter actually tests, in a sentence. The labels are short
  /// enough to be read as looser than they are.
  final String hint;

  final bool isOn;

  /// Builds the menu: a `DropdownMenu`, under a provider of the browse model
  /// so its rows can watch what they set.
  final WidgetBuilder menuBuilder;

  @override
  State<BrowseDropdownFilter> createState() => _BrowseDropdownFilterState();
}

class _BrowseDropdownFilterState extends State<BrowseDropdownFilter> {
  final OverlayController _menu = OverlayController();

  @override
  void dispose() {
    _menu.dispose();
    super.dispose();
  }

  void _open() {
    final viewModel = context.read<BrowseViewModel>();
    final theme = Theme.of(context);
    _menu.show<void>(
      context,
      MenuConfiguration(
        alignment: Alignment.topCenter,
        offset: const Offset(0, ThemeRepo.spaceXSmall),
        // Consumed, so the press that dismisses the menu is the whole of what
        // that press does: left to carry on, a press on the chip would close
        // the menu and then open it again. The sector chips do the same.
        consumeOutsideTaps: true,
        overlayBarrier: OverlayBarrier(
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
      ),
      // Handed down explicitly, so the menu can watch the model wherever the
      // overlay lands — a slider in it has to follow what it sets.
      builder: (_) => ChangeNotifierProvider<BrowseViewModel>.value(
        value: viewModel,
        child: Builder(builder: widget.menuBuilder),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _menu,
      builder: (context, _) {
        final isOpen = _menu.hasOpenOverlay;
        final style = isOpen
            ? const ButtonStyle.secondary()
            : widget.isOn
            ? const ButtonStyle.primary()
            : const ButtonStyle.outline();

        return Tooltip(
          tooltip: HintTooltip(widget.hint).call,
          child: Button(
            style: style,
            onPressed: isOpen ? _menu.close : _open,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: ThemeRepo.spaceSmall,
              children: [
                Icon(widget.icon).iconXSmall(),
                Text(widget.label),
                Icon(isOpen ? LucideIcons.chevronUp : LucideIcons.chevronDown)
                    .iconXSmall(),
              ],
            ),
          ),
        );
      },
    );
  }
}
