import 'package:pickstock/data/snapshot/browse_sort.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/browse/widgets/browse_dropdown_filter.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Narrows the directory to companies holding more cash than they owe, by a
/// chosen multiple.
///
/// Replaces a plain debt-free switch, which asked a question few healthy
/// companies can answer yes to: plenty of the strongest balance sheets carry
/// some debt and many times that in cash. Debt-free companies still pass at
/// every multiple, since nothing owed is covered any number of times over.
class CashToDebtFilter extends StatelessWidget {
  const CashToDebtFilter({super.key});

  @override
  Widget build(BuildContext context) {
    final canFilter = context.select<BrowseViewModel, bool>(
      (viewModel) => viewModel.canFilterCashToDebt,
    );
    // A database written before the figures were extracted cannot answer the
    // question, and a filter that emptied the list would read as a bug.
    if (!canFilter) return const SizedBox.shrink();

    final ratio = context.select<BrowseViewModel, double?>(
      (viewModel) => viewModel.cashToDebtMin,
    );
    final strings = context.strings;

    return BrowseDropdownFilter(
      // The same glyph the report gives a company's net cash position, which
      // is the figure this asks about.
      icon: LucideIcons.scale,
      label: ratio == null
          ? strings.cashToDebtLabel
          : strings.cashToDebtChip(formatCashToDebt(ratio)),
      hint: strings.cashToDebtHint,
      isOn: ratio != null,
      menuBuilder: (_) => const _CashToDebtMenu(),
    );
  }
}

class _CashToDebtMenu extends StatelessWidget {
  const _CashToDebtMenu();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BrowseViewModel>();
    final strings = context.strings;

    return DropdownMenu(
      children: [
        MenuRadioGroup<double?>(
          value: viewModel.cashToDebtMin,
          onChanged: (_, ratio) => viewModel.setCashToDebtMin(ratio),
          children: [
            MenuRadio<double?>(value: null, child: Text(strings.cashToDebtAny)),
          ],
        ),
        const MenuDivider(),
        MenuLabel(child: Text(strings.cashToDebtHeader)),
        MenuRadioGroup<double?>(
          value: viewModel.cashToDebtMin,
          onChanged: (_, ratio) => viewModel.setCashToDebtMin(ratio),
          children: [
            for (final preset in cashToDebtPresets)
              MenuRadio<double?>(
                value: preset,
                // The multiple sits at the right of every row, so the column
                // of them reads as the scale the slider below continues.
                trailing: Text(formatCashToDebt(preset)).muted().xSmall(),
                child: Text(
                  preset == 1
                      ? strings.cashToDebtMoreThan
                      : strings.cashToDebtPreset(formatCashToDebt(preset)),
                ),
              ),
          ],
        ),
        const MenuDivider(),
        const _RatioSlider(),
      ],
    );
  }
}

/// Any multiple between the presets, set by dragging.
///
/// A row of the menu rather than a control beside it, so the presets and the
/// fine setting are one place to look. The list narrows as the thumb moves —
/// the filter is an in-memory pass, cheap enough to run on every step — so
/// the count beside the search field is the feedback for where to let go.
class _RatioSlider extends StatelessWidget implements MenuItem {
  const _RatioSlider();

  @override
  bool get hasLeading => false;

  @override
  OverlayController? get overlayController => null;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BrowseViewModel>();
    final ratio = viewModel.cashToDebtMin;
    final count = viewModel.resultCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ThemeRepo.spaceSmall,
        ThemeRepo.spaceXSmall,
        ThemeRepo.spaceSmall,
        ThemeRepo.spaceSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: ThemeRepo.spaceSmall,
        children: [
          Row(
            children: [
              Text(context.strings.cashToDebtCustom).small().medium(),
              const Spacer(),
              // Tabular, so the figure does not shuffle sideways as it
              // changes under the thumb.
              Text(ratio == null ? '—' : formatCashToDebt(ratio))
                  .small()
                  .mono(),
            ],
          ),
          SizedBox(
            width: ThemeRepo.filterSliderWidth,
            child: Slider(
              // Off sits at the bottom of the scale, which is where the first
              // drag would start anyway.
              value: SliderValue.single(
                (ratio ?? cashToDebtMin).clamp(cashToDebtMin, cashToDebtMax),
              ),
              min: cashToDebtMin,
              max: cashToDebtMax,
              divisions: ((cashToDebtMax - cashToDebtMin) / cashToDebtStep)
                  .round(),
              onChanged: (value) => viewModel.setCashToDebtMin(
                // Snapped, so the stored multiple is the one the label shows
                // rather than a float a hair off it.
                (value.value / cashToDebtStep).round() * cashToDebtStep,
              ),
            ),
          ),
          Text(context.strings.browseMatchCount(count)).muted().xSmall(),
        ],
      ),
    );
  }
}
