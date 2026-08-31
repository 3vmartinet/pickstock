import 'package:pickstock/l10n/app_localizations.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Where a share price sits against the fair-value band derived for it.
///
/// Each case owns its own wording, icon and sentiment, so the widget that
/// renders the verdict never has to know what any of them mean.
enum ValuationVerdict {
  undervalued(icon: LucideIcons.trendingDown, isGood: true),
  fairlyValued(icon: LucideIcons.equal, isGood: null),
  overvalued(icon: LucideIcons.trendingUp, isGood: false),
  unknown(icon: LucideIcons.circleHelp, isGood: null);

  const ValuationVerdict({required this.icon, required this.isGood});

  final IconData icon;

  /// Whether the verdict is good news for a buyer. Fairly valued is neither,
  /// so it reads neutral rather than borrowing a colour it has not earned.
  final bool? isGood;

  String getLabel(AppLocalizations strings) => switch (this) {
    ValuationVerdict.undervalued => strings.verdictUndervalued,
    ValuationVerdict.fairlyValued => strings.verdictFairlyValued,
    ValuationVerdict.overvalued => strings.verdictOvervalued,
    ValuationVerdict.unknown => strings.verdictNotValuable,
  };

  String getDetail(AppLocalizations strings) => switch (this) {
    ValuationVerdict.undervalued => strings.detailUndervalued,
    ValuationVerdict.fairlyValued => strings.detailFairlyValued,
    ValuationVerdict.overvalued => strings.detailOvervalued,
    ValuationVerdict.unknown => strings.detailNotValuable,
  };
}
