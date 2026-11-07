import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/repo/research/searxng_search_repo.dart';
import 'package:pickstock/repo/research/web_search_repo.dart';
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
  bool _localSearchEnabled = _settingsRepo.localSearchEnabled;
  String _localSearchUrl = _settingsRepo.localSearchUrl;
  LocalSearchStatus _localSearchStatus = LocalSearchStatus.unknown;
  bool _isCheckingLocalSearch = false;

  /// How the status check reaches a server, swapped in a test for one that
  /// answers from a fixture.
  @visibleForTesting
  static SearxngSearchRepo Function(String url) searxngAt = (url) =>
      SearxngSearchRepo(baseUrl: url);

  /// Whether Ollama's hosted search is there behind the local one. Read from
  /// the build rather than the settings: the key is built in.
  @visibleForTesting
  static bool hasHostedSearch = ollamaApiKey.isNotEmpty;

  /// Whether searches go first to the reader's own SearXNG server.
  bool get localSearchEnabled => _localSearchEnabled;

  /// Where that server answers.
  String get localSearchUrl => _localSearchUrl;

  /// What was found there the last time anyone looked.
  LocalSearchStatus get localSearchStatus => _localSearchStatus;

  bool get isCheckingLocalSearch => _isCheckingLocalSearch;

  bool get hostedSearchAvailable => hasHostedSearch;

  /// Looks at the server's address, and turns local search on the first time
  /// something is found there: the guide has done its job, and asking the
  /// reader to flip a switch as well would be one more step to miss.
  Future<LocalSearchStatus> checkLocalSearch() async {
    if (_isCheckingLocalSearch) return _localSearchStatus;
    _isCheckingLocalSearch = true;
    notifyListeners();
    final url = _localSearchUrl;
    final LocalSearchStatus status;
    try {
      status = await searxngAt(url).probe();
    } finally {
      _isCheckingLocalSearch = false;
    }
    // The address changed while this looked at the old one.
    if (url != _localSearchUrl) {
      notifyListeners();
      return _localSearchStatus;
    }
    _localSearchStatus = status;
    notifyListeners();
    if (status == LocalSearchStatus.connected && !_localSearchEnabled) {
      await setLocalSearchEnabled(true);
    }
    return status;
  }

  Future<void> setLocalSearchEnabled(bool value) async {
    if (value == _localSearchEnabled) return;
    _localSearchEnabled = value;
    notifyListeners();
    await _settingsRepo.setLocalSearchEnabled(value);
  }

  Future<void> setLocalSearchUrl(String url) async {
    final trimmed = url.trim().isEmpty ? defaultSearxngUrl : url.trim();
    if (trimmed == _localSearchUrl) return;
    _localSearchUrl = trimmed;
    _localSearchStatus = LocalSearchStatus.unknown;
    notifyListeners();
    await _settingsRepo.setLocalSearchUrl(trimmed);
  }

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
