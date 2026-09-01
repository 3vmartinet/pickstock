import 'package:pickstock/repo/theme_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A tooltip that stays a readable shape.
///
/// `TooltipContainer` sizes to its content, so a two-sentence explanation ran
/// the full width of the window in one line 1,500 pixels long — unreadable, and
/// covering whatever it was explaining. This caps the width and puts each
/// sentence on its own line, so a long hint grows downwards instead of
/// sideways.
class HintTooltip extends StatelessWidget {
  const HintTooltip(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final sentences = splitIntoSentences(text);

    return TooltipContainer(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: ThemeRepo.tooltipMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: ThemeRepo.spaceXSmall,
          children: [for (final sentence in sentences) Text(sentence)],
        ),
      ),
    );
  }

  /// Ready to hand to a `Tooltip`'s `tooltip` argument.
  WidgetBuilder get call =>
      (context) => this;
}

/// Splits [text] on sentence ends.
///
/// A full stop only ends a sentence when whitespace and a capital follow it,
/// which leaves `$3.71T`, `2.5 years` and `e.g.` alone.
List<String> splitIntoSentences(String text) =>
    text.split(RegExp(r'(?<=[.!?])\s+(?=[A-Z0-9$])'));
