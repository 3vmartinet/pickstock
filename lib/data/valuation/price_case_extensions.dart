import 'package:pickstock/data/valuation/price_target.dart';
import 'package:pickstock/l10n/app_localizations.dart';

/// What each reading is called on the report.
extension PriceCaseLabel on PriceCase {
  String getLabel(AppLocalizations strings) => switch (this) {
    PriceCase.bear => strings.targetsBear,
    PriceCase.neutral => strings.targetsNeutral,
    PriceCase.bull => strings.targetsBull,
  };
}
