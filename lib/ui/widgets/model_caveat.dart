import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

/// The note under a model's answer that it is a model's, as a tag: an
/// information glyph and the line on a soft fill, hugging its text.
///
/// Said every time, not once in a settings screen: the answer above it reads
/// exactly like the app's own text and did not come from the filings. A tag
/// rather than a line of italics, so it reads as a note about the answer and
/// never as one more line of it — or one more of the links beside it.
class ModelCaveat extends StatelessWidget {
  const ModelCaveat({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    // Held to its own width wherever it is placed, a column stretching its
    // children included.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.muted,
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Padding(
          padding: ThemeRepo.modelCaveatPadding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: ThemeRepo.spaceXSmall,
            children: [
              const Icon(LucideIcons.info).iconXSmall().iconMutedForeground(),
              Flexible(
                child: Text(context.strings.insightCaveat).muted().xSmall(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
