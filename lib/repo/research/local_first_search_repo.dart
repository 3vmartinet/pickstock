import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:pickstock/extensions/object_extensions.dart';
import 'package:pickstock/repo/research/page_reader.dart';
import 'package:pickstock/repo/research/searxng_search_repo.dart';
import 'package:pickstock/repo/research/web_search_repo.dart';
import 'package:pickstock/repo/settings/settings_repo.dart';

/// Searches on the reader's own SearXNG server where they have set one up,
/// and through Ollama's hosted search otherwise or when it fails.
///
/// Local first because it has no quota; Ollama behind it because a search
/// server is somebody's Docker container, and Docker is not always running.
/// Pages are read the same way either way: here first, hosted only for a page
/// this machine could not read, and only with a key to do it with.
class LocalFirstSearchRepo implements WebSearchRepo {
  LocalFirstSearchRepo({
    WebSearchRepo? hosted,
    SettingsRepo? settings,
    http.Client? client,
  }) : _hosted = hosted ?? OllamaWebSearchRepo(client: client),
       _settingsOverride = settings,
       _client = client;

  final WebSearchRepo _hosted;
  final SettingsRepo? _settingsOverride;
  final http.Client? _client;

  SettingsRepo get _settingsRepo =>
      _settingsOverride ?? GetIt.I.get<SettingsRepo>();

  /// The reader's server, read at each call so a change in the settings takes
  /// effect without a restart.
  SearxngSearchRepo? get _local {
    final settings = _settingsRepo;
    if (!settings.localSearchEnabled) return null;
    return SearxngSearchRepo(baseUrl: settings.localSearchUrl, client: _client);
  }

  @override
  bool get isConfigured =>
      _settingsRepo.localSearchEnabled || _hosted.isConfigured;

  /// Until when Ollama is left alone, having refused for want of allowance.
  ///
  /// Asking again sooner spends nothing and only fails again; with the
  /// reader's own server there to answer, it is not asked at all until then.
  DateTime? _hostedRestsUntil;

  /// How long to leave Ollama alone when it refuses without saying.
  static const Duration _defaultRest = Duration(hours: 1);

  bool get _isHostedResting {
    final until = _hostedRestsUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void _rest(SearchException refusal) {
    _hostedRestsUntil = DateTime.now().add(refusal.retryAfter ?? _defaultRest);
  }

  @override
  Future<List<SearchResult>> search(
    String query, {
    int maxResults = defaultSearchResults,
  }) async {
    final local = _local;
    if (local == null) return _hosted.search(query, maxResults: maxResults);

    List<SearchResult>? found;
    SearchException? localFailure;
    try {
      found = await local.search(query, maxResults: maxResults);
      if (found.isNotEmpty) return found;
    } on SearchException catch (error) {
      localFailure = error;
    }

    if (!_hosted.isConfigured || _isHostedResting) {
      // The reader's own server is the search: what it said stands, nothing
      // found or failed, and Ollama's allowance does not come into it.
      if (localFailure != null) throw localFailure;
      return found ?? const [];
    }

    logInfo(
      () => localFailure == null
          ? 'Local search found nothing; asking Ollama'
          : 'Local search failed; asking Ollama: $localFailure',
    );
    try {
      return await _hosted.search(query, maxResults: maxResults);
    } on SearchException catch (error) {
      if (error.failure == SearchFailure.rateLimited) _rest(error);
      // Ollama was only ever the second try: its refusal is not the answer.
      // The local server's failure is, or its finding nothing.
      if (localFailure != null) throw localFailure;
      return found ?? const [];
    }
  }

  @override
  Future<SearchResult> fetch(String url) async {
    // Read here, and through Ollama only for a page this machine could not
    // read; with the local server on and Ollama refusing, the page as read
    // here is what there is.
    if (!(_settingsRepo.localSearchEnabled && _isHostedResting)) {
      try {
        return await _hosted.fetch(url);
      } on SearchException catch (error) {
        if (!_settingsRepo.localSearchEnabled ||
            error.failure != SearchFailure.rateLimited) {
          rethrow;
        }
        _rest(error);
      }
    }
    return PageReader(client: _client).read(url);
  }
}
