import 'package:pickstock/data/snapshot/browse_sort.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/browse/widgets/browse_dropdown_filter.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Narrows the directory to companies that generated cash rather than
/// consumed it, over the latest year or several years running.
///
/// The sibling of the cash filter, and the other half of the same question:
/// one asks what a company holds against what it owes, this asks whether it
/// pays for itself — and for how long it has.
class PositiveCashFlowFilter extends StatelessWidget {
  const PositiveCashFlowFilter({super.key});

  @override
  Widget build(BuildContext context) {
    final canFilter = context.select<BrowseViewModel, bool>(
      (viewModel) => viewModel.canFilterPositiveCashFlow,
    );
    // A database written before cash flows were extracted cannot answer the
    // question, and a filter that emptied the list would read as a bug.
    if (!canFilter) return const SizedBox.shrink();

    final window = context.select<BrowseViewModel, CashGenerativeWindow?>(
      (viewModel) => viewModel.cashGenerative,
    );
    final strings = context.strings;

    return BrowseDropdownFilter(
      // The same glyph the report gives free cash flow, which is the figure
      // this asks about.
      icon: LucideIcons.coins,
      label: window?.getChipLabel(strings) ?? strings.browsePositiveCashFlow,
      hint: strings.browsePositiveCashFlowHint,
      isOn: window != null,
      menuBuilder: (_) => const _CashFlowMenu(),
    );
  }
}

class _CashFlowMenu extends StatelessWidget {
  const _CashFlowMenu();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BrowseViewModel>();
    final strings = context.strings;

    return DropdownMenu(
      children: [
        MenuRadioGroup<CashGenerativeWindow?>(
          value: viewModel.cashGenerative,
          onChanged: (_, window) => viewModel.setCashGenerative(window),
          children: [
            MenuRadio<CashGenerativeWindow?>(
              value: null,
              child: Text(strings.cashFilterAny),
            ),
          ],
        ),
        const MenuDivider(),
        MenuLabel(child: Text(strings.cashFilterHeader)),
        MenuRadioGroup<CashGenerativeWindow?>(
          value: viewModel.cashGenerative,
          onChanged: (_, window) => viewModel.setCashGenerative(window),
          children: [
            for (final window in CashGenerativeWindow.values)
              MenuRadio<CashGenerativeWindow?>(
                value: window,
                child: Text(window.getMenuLabel(strings)),
              ),
          ],
        ),
      ],
    );
  }
}
