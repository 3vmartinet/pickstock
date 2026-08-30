import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Mirrors the logging surface of the internal `fluff` package.
///
/// `fluff` itself is not depended upon here: it pulls in audio, timezone and
/// device-info plugins that have no place in a web-only app. This keeps the
/// exact call sites the constitution mandates (`logInfo`, `logWarning`,
/// `logSevere`, …) so a later swap to `fluff` is a pure import change.
extension ObjectExtensions<T> on T {
  void logInfo(String Function() messageProvider) =>
      _log(messageProvider, Level.INFO);

  void logWarning(String Function() messageProvider) =>
      _log(messageProvider, Level.WARNING);

  void logSevere(String Function() messageProvider) =>
      _log(messageProvider, Level.SEVERE);

  void logFine(String Function() messageProvider) =>
      _log(messageProvider, Level.FINE);

  void _log(String Function() messageProvider, Level level) {
    if (kDebugMode) {
      log(messageProvider(), name: runtimeType.toString(), level: level.value);
    }
  }
}
