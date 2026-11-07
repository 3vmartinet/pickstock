import 'package:pickstock/data/snapshot/browse_sort.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/browse/widgets/browse_dropdown_filter.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Narrows the directory to companies whose revenue grew, on average over a
/// window or in every year of it.
///
/// A filter of its own rather than a family of orderings: which companies
/// grew is a question about who is in the list, and the sort control can only
/// rearrange the list it is given. Ranking by revenue growth ranks over the
/// window chosen here, so the two still work as a pair.
class RevenueGrowthFilterChip extends StatelessWidget {
  const RevenueGrowthFilterChip({super.key});

  @override
  Widget build(BuildContext context) {
    final filter = context.select<BrowseViewModel, RevenueGrowthFilter?>(
      (viewModel) => viewModel.revenueGrowthFilter,
    );
    final strings = context.strings;

    return BrowseDropdownFilter(
      // The same glyph the report gives revenue growth.
      icon: LucideIcons.trendingUp,
      label: filter?.getChipLabel(strings) ?? strings.revenueFilterLabel,
      hint: strings.revenueFilterHint,
      isOn: filter != null,
      menuBuilder: (_) => const _RevenueMenu(),
    );
  }
}

class _RevenueMenu extends StatelessWidget {
  const _RevenueMenu();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BrowseViewModel>();
    final strings = context.strings;

    // One radio group per heading, all bound to the same value, so exactly
    // one row across the menu carries the dot.
    MenuRadioGroup<RevenueGrowthFilter?> group(
      Iterable<RevenueGrowthFilter?> options,
    ) => MenuRadioGroup<RevenueGrowthFilter?>(
      value: viewModel.revenueGrowthFilter,
      onChanged: (_, filter) => viewModel.setRevenueGrowthFilter(filter),
      children: [
        for (final option in options)
          MenuRadio<RevenueGrowthFilter?>(
            value: option,
            child: Text(
              option?.getMenuLabel(strings) ?? strings.revenueFilterAny,
            ),
          ),
      ],
    );

    const growing = RevenueGrowthFilter.values;
    return DropdownMenu(
      children: [
        group(const [null]),
        const MenuDivider(),
        MenuLabel(child: Text(strings.revenueFilterGrowingHeader)),
        group(growing.where((option) => !option.needsUnbrokenRun)),
        const MenuDivider(),
        MenuLabel(child: Text(strings.revenueFilterRisingHeader)),
        group(growing.where((option) => option.needsUnbrokenRun)),
      ],
    );
  }
}
