import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/app_view_model.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

/// A line of text that opens the page it came from.
///
/// Muted until the pointer is over it and the accent colour under it, which is
/// how the rest of the app marks something that will do something — and the
/// only way a line of text among other lines can say it is more than a
/// caption.
///
/// Opens beside the report rather than in a browser: a source is worth reading
/// next to the figures it is about. The pane's own toolbar hands it to the
/// browser for anyone who would rather have it there.
class SourceLink extends StatefulWidget {
  const SourceLink({
    super.key,
    required this.label,
    required this.url,
    required this.cik,
    this.fontSize = ThemeRepo.eventFontSize,
  });

  final String label;
  final String url;

  /// Whose report the link was read from, carried so the pane it opens cannot
  /// outlive that report.
  final String cik;

  final double fontSize;

  @override
  State<SourceLink> createState() => _SourceLinkState();
}

class _SourceLinkState extends State<SourceLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Tooltip(
      // The label as well as the link: the line is often cut short by the
      // width it has, and the tooltip is where the rest of it goes.
      tooltip: HintTooltip(
        context.strings.eventsOpenHint(_sentence(widget.label), widget.url),
      ).call,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: () => context.read<AppViewModel>().openSource(
            widget.url,
            cik: widget.cik,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: widget.fontSize,
              color: _isHovered
                  ? theme.colorScheme.primary
                  : theme.colorScheme.mutedForeground,
              // Underlined only under the pointer, as shadcn's own links are:
              // several underlined lines together would read as a menu.
              decoration: _isHovered ? TextDecoration.underline : null,
              decorationColor: theme.colorScheme.primary,
            ),
          ).singleLine().ellipsis(),
        ),
      ),
    );
  }
}

/// [label] with a full stop, so the tooltip breaks it off the sentence that
/// follows rather than running the two together.
String _sentence(String label) => label.endsWith('.') ? label : '$label.';
