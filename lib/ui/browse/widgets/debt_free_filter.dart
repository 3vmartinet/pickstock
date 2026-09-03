import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Narrows the directory to companies that owe nothing.
///
/// A toggle rather than a chip in the sector row: it is a different question
/// from which industry a company is in, and the two apply together.
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

    final toggle = context.read<BrowseViewModel>().toggleDebtFree;
    // The same two buttons the list filter beside it uses, so the pair are
    // the same height on the bar's row.
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: ThemeRepo.spaceSmall,
      children: [
        const Icon(LucideIcons.scale).iconXSmall(),
        Text(context.strings.browseDebtFree),
      ],
    );

    return Tooltip(
      tooltip: HintTooltip(context.strings.browseDebtFreeHint).call,
      child: isOn
          ? PrimaryButton(onPressed: toggle, child: label)
          : OutlineButton(onPressed: toggle, child: label),
    );
  }
}
