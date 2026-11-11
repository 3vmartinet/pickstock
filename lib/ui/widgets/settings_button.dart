import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/ui/settings/widgets/settings_dialog.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Opens the settings from the app bar where there is no app menu to.
///
/// On a Mac the native menu's Settings… (⌘,) is the only way in, as Apple
/// asks; on Linux the window has no such menu, and Ctrl+, alone would leave
/// the settings with nothing on screen pointing at them.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  /// Whether [platform] gets the button: every platform but macOS.
  static bool isShown(TargetPlatform platform) =>
      platform != TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      tooltip: HintTooltip(context.strings.settingsTitle).call,
      child: GhostButton(
        density: ButtonDensity.icon,
        onPressed: () => showSettings(context),
        child: const Icon(LucideIcons.settings),
      ),
    );
  }
}
