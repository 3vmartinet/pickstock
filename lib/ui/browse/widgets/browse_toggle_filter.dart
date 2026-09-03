import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// One yes-or-no narrowing of the directory, as a button on the filter bar.
///
/// A toggle rather than a chip in the sector row: these are different
/// questions from which industry a company is in, and every one of them
/// applies on top of the others.
///
/// Shared rather than written out per filter, so a second question about a
/// company's finances is a call site and not another copy of the button —
/// and so the row of them cannot drift apart in height or weight.
class BrowseToggleFilter extends StatelessWidget {
  const BrowseToggleFilter({
    super.key,
    required this.icon,
    required this.label,
    required this.hint,
    required this.isOn,
    required this.onPressed,
  });

  final IconData icon;
  final String label;

  /// What the filter actually tests, in a sentence. The labels are short
  /// enough to be read as looser than they are.
  final String hint;

  final bool isOn;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // The same two buttons the list filter beside it uses, so the pair are
    // the same height on the bar's row.
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: ThemeRepo.spaceSmall,
      children: [Icon(icon).iconXSmall(), Text(label)],
    );

    return Tooltip(
      tooltip: HintTooltip(hint).call,
      child: isOn
          ? PrimaryButton(onPressed: onPressed, child: content)
          : OutlineButton(onPressed: onPressed, child: content),
    );
  }
}
