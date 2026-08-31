import 'package:pickstock/l10n/app_localizations.dart';

/// The cash stream a fair-value band is struck against.
///
/// Free cash flow is preferred: it is the money that actually reaches the
/// owners. Accounting profit stands in where a company reports no usable cash
/// flow, and the report says which one was used.
enum ValuationBasis {
  freeCashFlow,
  earnings;

  String getLabel(AppLocalizations strings) => switch (this) {
    ValuationBasis.freeCashFlow => strings.basisFreeCashFlow,
    ValuationBasis.earnings => strings.basisEarnings,
  };
}
