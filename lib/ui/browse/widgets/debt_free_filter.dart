import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/browse/widgets/browse_toggle_filter.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Narrows the directory to companies that owe nothing.
class DebtFreeFilter extends StatelessWidget {
  const DebtFreeFilter({super.key});

  @override
  Widget build(BuildContext context) {
    final canFilter = context.select<BrowseViewModel, bool>(
      (viewModel) => viewModel.canFilterDebtFree,
    );
    // A database written before interest expense was extracted cannot answer
    // the question, and a filter that emptied the list would read as a bug.
    if (!canFilter) return const SizedBox.shrink();

    final isOn = context.select<BrowseViewModel, bool>(
      (viewModel) => viewModel.debtFreeOnly,
    );

    return BrowseToggleFilter(
      // The same glyph the report gives a company's net cash position, which
      // is the figure this asks about.
      icon: LucideIcons.scale,
      label: context.strings.browseDebtFree,
      hint: context.strings.browseDebtFreeHint,
      isOn: isOn,
      onPressed: context.read<BrowseViewModel>().toggleDebtFree,
    );
  }
}
