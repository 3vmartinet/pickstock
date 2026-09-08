import 'package:flutter_animate/flutter_animate.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

/// Points at the one card an answer has just landed in.
///
/// A question to the local model takes about a minute, so the answer arrives
/// on a screen the reader has since left. The way back is a row in the app
/// bar — and following it lands on a report of a dozen cards, one of which is
/// new. Without something saying which, the trip ends nowhere.
///
/// Two marks rather than one, because they answer different questions. The
/// ring pulses once and goes: it catches the eye of someone arriving and is
/// out of the way before they read anything. The badge stays for as long as
/// the answer counts as fresh, so someone who looked away and back can still
/// tell which card was the point.
class JustFetched extends StatelessWidget {
  const JustFetched({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Stack(
      children: [
        child,
        // Over the card rather than around it: a border of its own would
        // resize what it is marking, and everything below would step down the
        // page as it appeared.
        Positioned.fill(
          child: IgnorePointer(
            child:
                DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: theme.borderRadiusLg,
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: ThemeRepo.freshRingWidth,
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: ThemeRepo.freshRingIn)
                    .then()
                    .fadeOut(duration: ThemeRepo.freshRingOut),
          ),
        ),
      ],
    );
  }
}

/// The badge that says this is the answer that just came back.
///
/// A tick rather than a dot: it is the end of something the reader started
/// and waited for, and the shape says so without a sentence.
class JustFetchedBadge extends StatelessWidget {
  const JustFetchedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return PrimaryBadge(
      leading: const Icon(LucideIcons.check).iconXSmall(),
      child: Text(context.strings.researchJustFetched).xSmall(),
    );
  }
}
