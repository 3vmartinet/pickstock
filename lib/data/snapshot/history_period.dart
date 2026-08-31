import 'package:pickstock/l10n/app_localizations.dart';

/// Which cadence the history section is showing.
enum HistoryPeriod {
  annual,
  quarterly;

  String getLabel(AppLocalizations strings) => switch (this) {
    HistoryPeriod.annual => strings.periodAnnual,
    HistoryPeriod.quarterly => strings.periodQuarterly,
  };
}
