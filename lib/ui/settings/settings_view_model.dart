import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/repo/settings/settings_repo.dart';

SettingsRepo get _settingsRepo => GetIt.I.get<SettingsRepo>();

/// The choices on the settings screen, as the screen shows them.
///
/// Seeded from the repository in the constructor, which is safe because the
/// repository is read before the first frame: the screen never shows a default
/// and then corrects itself.
class SettingsViewModel extends ChangeNotifier {
  bool _autoDownloadUpdates = _settingsRepo.autoDownloadUpdates;
  bool _autoApplyUpdates = _settingsRepo.autoApplyUpdates;
  bool _autoFetchBusinessDescription =
      _settingsRepo.autoFetchBusinessDescription;

  /// Whether a newer SEC archive downloads as soon as it is offered.
  bool get autoDownloadUpdates => _autoDownloadUpdates;

  /// Whether a downloaded update is automatically applied without waiting for confirmation.
  bool get autoApplyUpdates => _autoApplyUpdates;

  /// Whether the business description is fetched automatically with an LLM.
  bool get autoFetchBusinessDescription => _autoFetchBusinessDescription;

  Future<void> setAutoDownloadUpdates(bool value) async {
    if (value == _autoDownloadUpdates) return;
    _autoDownloadUpdates = value;
    notifyListeners();
    await _settingsRepo.setAutoDownloadUpdates(value);
  }

  Future<void> setAutoApplyUpdates(bool value) async {
    if (value == _autoApplyUpdates) return;
    _autoApplyUpdates = value;
    notifyListeners();
    await _settingsRepo.setAutoApplyUpdates(value);
  }

  Future<void> setAutoFetchBusinessDescription(bool value) async {
    if (value == _autoFetchBusinessDescription) return;
    _autoFetchBusinessDescription = value;
    notifyListeners();
    await _settingsRepo.setAutoFetchBusinessDescription(value);
  }
}
