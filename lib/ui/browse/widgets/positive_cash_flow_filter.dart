import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/browse/widgets/browse_toggle_filter.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Narrows the directory to companies whose latest filed year generated cash
/// rather than consumed it.
///
/// The sibling of the debt-free filter, and the other half of the same
/// question: one asks whether a company owes anything, this asks whether it
/// pays for itself.
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

    final isOn = context.select<BrowseViewModel, bool>(
      (viewModel) => viewModel.positiveCashFlowOnly,
    );

    return BrowseToggleFilter(
      // The same glyph the report gives free cash flow, which is the figure
      // this asks about.
      icon: LucideIcons.coins,
      label: context.strings.browsePositiveCashFlow,
      hint: context.strings.browsePositiveCashFlowHint,
      isOn: isOn,
      onPressed: context.read<BrowseViewModel>().togglePositiveCashFlow,
    );
  }
}
