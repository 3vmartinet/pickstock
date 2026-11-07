import 'package:get_it/get_it.dart';
import 'package:pickstock/data/valuation/valuation_verdict.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/browse/list_valuation_view_model.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// The verdicts the group offers, in the order they sit: cheap, fair, dear.
const List<ValuationVerdict> verdictFilterOptions = [
  ValuationVerdict.undervalued,
  ValuationVerdict.fairlyValued,
  ValuationVerdict.overvalued,
];

/// One button of the verdict filter.
Key verdictFilterKey(ValuationVerdict verdict) =>
    ValueKey('verdictFilter-${verdict.name}');

/// Narrows the list to one valuation verdict: undervalued, fairly valued or
/// overvalued, as the tiles mark them.
///
/// Three joined buttons rather than a dropdown: there are only three answers,
/// each already has a glyph the reader has learned from the tiles, and a
/// quick filter is one press. Pressing the one in force lifts it, the way a
/// toggle does.
///
/// Absent without a quote key: nothing can be priced, so every press would
/// empty the list.
class VerdictFilter extends StatelessWidget {
  const VerdictFilter({super.key});

  @override
  Widget build(BuildContext context) {
    if (!context.read<ListValuationViewModel>().canValue) {
      return const SizedBox.shrink();
    }
    final selected = context.select<BrowseViewModel, ValuationVerdict?>(
      (viewModel) => viewModel.verdictFilter,
    );
    final viewModel = context.read<BrowseViewModel>();

    return Semantics(
      label: context.strings.verdictFilterLabel,
      container: true,
      child: ButtonGroup(
        children: [
          for (final verdict in verdictFilterOptions)
            _VerdictButton(
              verdict: verdict,
              isSelected: verdict == selected,
              onPressed: () => viewModel.setVerdictFilter(
                verdict == selected ? null : verdict,
              ),
            ),
        ],
      ),
    );
  }
}

class _VerdictButton extends StatelessWidget {
  const _VerdictButton({
    required this.verdict,
    required this.isSelected,
    required this.onPressed,
  });

  final ValuationVerdict verdict;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = verdict.getLabel(context.strings);
    // In the tiles' colours while off, so each button reads as the mark it
    // filters for; in the fill's own colour once on, where green or red on
    // the primary fill would be hard to see and the fill already says which.
    final icon = Icon(
      verdict.icon,
      color: isSelected
          ? null
          : _themeRepo.forOutcome(context.theme, isGood: verdict.isGood),
    ).iconSmall();

    return Tooltip(
      tooltip: HintTooltip(
        isSelected ? context.strings.verdictFilterClear(label) : label,
      ).call,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: Button(
          key: verdictFilterKey(verdict),
          // Filled while in force, like every other filter that is on.
          style: isSelected
              ? const ButtonStyle.primary(density: ButtonDensity.icon)
              : const ButtonStyle.outline(density: ButtonDensity.icon),
          onPressed: onPressed,
          // Stood beside an empty line of the button's own text, so the
          // button is as tall as the labelled filters next to it: the
          // padding is the same, and an icon alone is shorter than a line.
          child: Stack(
            alignment: Alignment.center,
            children: [const Text('​'), icon],
          ),
        ),
      ),
    );
  }
}
