import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

/// Width the idle copy is held to, so the paragraph stays readable on a wide
/// monitor instead of running the full content width.
const double _proseMaxWidth = 560;

/// What the screen shows before anything has been searched.
class SnapshotIdleView extends StatelessWidget {
  const SnapshotIdleView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ThemeRepo.spaceXXLarge),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _proseMaxWidth),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            spacing: ThemeRepo.spaceLarge,
            children: [_IdleGlyph(), _IdleCopy(), _SuggestedTickers()],
          ),
        ),
      ),
    );
  }
}

class _IdleGlyph extends StatelessWidget {
  const _IdleGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ThemeRepo.spaceMedium),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.muted,
        borderRadius: context.theme.borderRadiusLg,
      ),
      child: const Icon(LucideIcons.chartLine)
          .iconXLarge()
          .iconMutedForeground(),
    );
  }
}

class _IdleCopy extends StatelessWidget {
  const _IdleCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: ThemeRepo.spaceSmall,
      children: [
        Text(context.strings.idleTitle).h3().textCenter(),
        Text(context.strings.idleBody).muted().textCenter(),
      ],
    );
  }
}

class _SuggestedTickers extends StatelessWidget {
  const _SuggestedTickers();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: ThemeRepo.spaceSmall,
      children: [
        Text(context.strings.idleShortcuts).muted().xSmall(),
        Wrap(
          spacing: ThemeRepo.spaceSmall,
          runSpacing: ThemeRepo.spaceSmall,
          alignment: WrapAlignment.center,
          children: [
            for (final ticker in suggestedTickers)
              OutlineButton(
                size: ButtonSize.small,
                onPressed: () =>
                    context.read<SnapshotViewModel>().search(ticker),
                child: Text(ticker),
              ),
          ],
        ),
      ],
    );
  }
}
