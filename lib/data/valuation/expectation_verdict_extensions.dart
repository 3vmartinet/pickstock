import 'package:pickstock/data/valuation/growth_expectation.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// How each verdict on the market's expectations reads.
///
/// Kept beside the enum rather than in it: [GrowthExpectation] is pure
/// arithmetic and has no business importing an icon set.
extension ExpectationVerdictExtensions on ExpectationVerdict {
  IconData get icon => switch (this) {
    ExpectationVerdict.belowRecord => LucideIcons.trendingDown,
    ExpectationVerdict.inLineWithRecord => LucideIcons.equal,
    ExpectationVerdict.beyondRecord => LucideIcons.trendingUp,
    ExpectationVerdict.unknown => LucideIcons.circleHelp,
  };

  /// Whether the reading favours a buyer. A price asking less than the record
  /// leaves room; one asking more has spent it.
  bool? get isGood => switch (this) {
    ExpectationVerdict.belowRecord => true,
    ExpectationVerdict.inLineWithRecord => null,
    ExpectationVerdict.beyondRecord => false,
    ExpectationVerdict.unknown => null,
  };

  String getLabel(AppLocalizations strings) => switch (this) {
    ExpectationVerdict.belowRecord => strings.verdictBelowRecord,
    ExpectationVerdict.inLineWithRecord => strings.verdictInLineWithRecord,
    ExpectationVerdict.beyondRecord => strings.verdictBeyondRecord,
    ExpectationVerdict.unknown => strings.verdictExpectationUnknown,
  };

  String getDetail(AppLocalizations strings) => switch (this) {
    ExpectationVerdict.belowRecord => strings.detailBelowRecord,
    ExpectationVerdict.inLineWithRecord => strings.detailInLineWithRecord,
    ExpectationVerdict.beyondRecord => strings.detailBeyondRecord,
    ExpectationVerdict.unknown => strings.detailExpectationUnknown,
  };
}
