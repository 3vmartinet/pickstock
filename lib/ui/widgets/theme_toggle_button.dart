import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/ui/app_view_model.dart';
import 'package:provider/provider.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

/// Flips between the light and dark themes.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.theme.brightness == Brightness.dark;
    return Tooltip(
      tooltip: HintTooltip(context.strings.toggleTheme).call,
      child: GhostButton(
        density: ButtonDensity.icon,
        onPressed: () =>
            context.read<AppViewModel>().toggleTheme(context.theme.brightness),
        child: Icon(isDark ? LucideIcons.sun : LucideIcons.moon),
      ),
    );
  }
}
