import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Days in the units nobody agrees on, taken at their averages: this is a
/// label reading "3 months ago", not a calculation.
const int _daysPerMonth = 30;
const int _daysPerYear = 365;

/// When an answer was read, and the offer to read it again.
///
/// Restored from disk an answer can be a month old, and a reader has no way to
/// tell this morning's reading from last month's unless told. The age rather
/// than the timestamp, because "2 days ago" is the question a reader is
/// actually asking; the timestamp is in the tooltip for anyone who wants it.
class NoteAge extends StatelessWidget {
  const NoteAge({
    super.key,
    required this.generatedAt,
    required this.onRefresh,
  });

  final DateTime generatedAt;

  /// Reads it again. Its own control rather than a press on the block: the
  /// block is now the answer, and answers are not buttons.
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      tooltip: HintTooltip(context.strings.noteGeneratedOn(generatedAt)).call,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: ThemeRepo.spaceXSmall,
        children: [
          Text(
            describeAge(context.strings, generatedAt),
            style: const TextStyle(fontSize: ThemeRepo.noteAgeFontSize),
          ).muted().singleLine(),
          Tooltip(
            tooltip: HintTooltip(context.strings.noteRegenerate).call,
            child: GhostButton(
              density: ButtonDensity.icon,
              onPressed: onRefresh,
              child: const Icon(LucideIcons.refreshCw).iconXSmall(),
            ),
          ),
        ],
      ),
    );
  }
}

/// How long ago [when] was, in the largest unit that says something.
///
/// Coarse on purpose: the exact minute of a piece of research is never the
/// question, and "3 months ago" answers "should I read this again?" where a
/// date makes the reader work it out.
String describeAge(AppLocalizations strings, DateTime when) {
  final elapsed = DateTime.now().difference(when);
  if (elapsed.inMinutes < 1) return strings.agoJustNow;
  if (elapsed.inHours < 1) return strings.agoMinutes(elapsed.inMinutes);
  if (elapsed.inDays < 1) return strings.agoHours(elapsed.inHours);
  if (elapsed.inDays < _daysPerMonth) return strings.agoDays(elapsed.inDays);
  if (elapsed.inDays < _daysPerYear) {
    return strings.agoMonths(elapsed.inDays ~/ _daysPerMonth);
  }
  return strings.agoYears(elapsed.inDays ~/ _daysPerYear);
}
