import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pickstock/extensions/object_extensions.dart';

/// Supplied at build time with `--dart-define-from-file=env.json`, so the key
/// never enters the repository. Empty by default, which leaves research off.
const String ollamaApiKey = String.fromEnvironment('OLLAMA_API_KEY');

/// Ollama's hosted search, which is a separate service from the local server
/// that runs the model: the model is on this machine, the searching is not.
const String _searchUrl = 'https://ollama.com/api/web_search';
const String _fetchUrl = 'https://ollama.com/api/web_fetch';

const String _queryKey = 'query';
const String _maxResultsKey = 'max_results';
const String _urlKey = 'url';
const String _resultsKey = 'results';
const String _titleKey = 'title';
const String _contentKey = 'content';

/// The most the endpoint will return, and what it returns when unasked.
const int maximumSearchResults = 10;
const int defaultSearchResults = 5;

/// Long enough for a search that has to fetch several pages, short enough that
/// a stalled request does not hold a model's tool call open indefinitely.
const Duration _requestTimeout = Duration(seconds: 30);

/// One page the search turned up.
class SearchResult {
  const SearchResult({
    required this.title,
    required this.url,
    required this.content,
  });

  final String title;
  final String url;

  /// The page as text. Runs to thousands of tokens, which is why the model
  /// asking for it needs a context to match.
  final String content;
}

/// The ways a search can fail in a way worth reporting rather than throwing.
enum SearchFailure {
  /// No key was built in, so the service was never asked.
  notConfigured,

  /// The key was refused.
  unauthorised,

  /// Asked too often.
  rateLimited,

  /// Reached but unhappy, or unreachable.
  unavailable,
}

class SearchException implements Exception {
  const SearchException(this.failure, {this.cause});

  final SearchFailure failure;
  final Object? cause;

  @override
  String toString() => 'SearchException(${failure.name}, cause: $cause)';
}

/// Searches the web, and reads a page in full.
///
/// An interface so the model's tool calls can be answered from a fixture in a
/// test without reaching the network.
abstract interface class WebSearchRepo {
  /// Whether a key was built in. False leaves every caller to say the feature
  /// is off rather than to fail mid-answer.
  bool get isConfigured;

  Future<List<SearchResult>> search(String query, {int maxResults});

  /// One page in full, for a model that wants more than the search returned.
  Future<SearchResult> fetch(String url);
}

class OllamaWebSearchRepo implements WebSearchRepo {
  OllamaWebSearchRepo({http.Client? client, String? apiKey})
    : _client = client ?? http.Client(),
      _apiKey = apiKey ?? ollamaApiKey;

  final http.Client _client;

  /// Held rather than read at each call so a test can supply its own without
  /// a build-time define.
  final String _apiKey;

  @override
  bool get isConfigured => _apiKey.isNotEmpty;

  @override
  Future<List<SearchResult>> search(
    String query, {
    int maxResults = defaultSearchResults,
  }) async {
    final payload = await _post(_searchUrl, {
      _queryKey: query,
      _maxResultsKey: maxResults.clamp(1, maximumSearchResults),
    });

    final results = payload[_resultsKey] as List<dynamic>? ?? const [];
    return [
      for (final raw in results)
        if (raw case final Map<String, dynamic> result)
          SearchResult(
            title: result[_titleKey] as String? ?? '',
            url: result[_urlKey] as String? ?? '',
            content: result[_contentKey] as String? ?? '',
          ),
    ];
  }

  @override
  Future<SearchResult> fetch(String url) async {
    final payload = await _post(_fetchUrl, {_urlKey: url});
    return SearchResult(
      title: payload[_titleKey] as String? ?? '',
      url: url,
      content: payload[_contentKey] as String? ?? '',
    );
  }

  Future<Map<String, dynamic>> _post(
    String url,
    Map<String, Object?> body,
  ) async {
    if (!isConfigured) {
      throw const SearchException(SearchFailure.notConfigured);
    }

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(url),
            headers: {
              // The one place the key is used. Never logged: the failure
              // below reports the status and nothing of the request.
              HttpHeaders.authorizationHeader: 'Bearer $_apiKey',
              HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
            },
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
    } on Object catch (error) {
      logWarning(() => 'Web search could not be reached: $error');
      throw SearchException(SearchFailure.unavailable, cause: error);
    }

    switch (response.statusCode) {
      case HttpStatus.ok:
        return jsonDecode(response.body) as Map<String, dynamic>;
      case HttpStatus.unauthorized:
      case HttpStatus.forbidden:
        throw const SearchException(SearchFailure.unauthorised);
      case HttpStatus.tooManyRequests:
        throw const SearchException(SearchFailure.rateLimited);
      default:
        logWarning(() => 'Web search answered ${response.statusCode}');
        throw const SearchException(SearchFailure.unavailable);
    }
  }
}
