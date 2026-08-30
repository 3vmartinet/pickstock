import 'package:flutter/widgets.dart';
import 'package:pickstock/l10n/app_localizations.dart';

extension LocalizationExtensions on BuildContext {
  /// The single entry point to every user-facing string in the app.
  AppLocalizations get strings => AppLocalizations.of(this);
}
