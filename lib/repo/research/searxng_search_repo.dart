import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:pickstock/extensions/object_extensions.dart';
import 'package:pickstock/repo/research/page_reader.dart';
import 'package:pickstock/repo/research/web_search_repo.dart';

/// Where the setup guide's command publishes the search server: this machine
/// only, on a port unlikely to be taken by anything a reader runs already.
const String defaultSearxngUrl = 'http://localhost:8888';

/// The container the setup guide starts, by name, so running the command a
/// second time replaces it rather than failing on a clash.
const String searxngContainerName = 'pickstock-search';

/// Where the setup guide's command keeps SearXNG's settings.
const String _settingsDirectory = '~/.pickstock/searxng';

/// Long enough for SearXNG to ask its engines and gather their answers, which
/// it does in parallel within a few seconds.
const Duration _searchTimeout = Duration(seconds: 15);

/// A status check is a question about whether anything is there, and should
/// be answered before the reader wonders whether the button worked.
const Duration _probeTimeout = Duration(seconds: 5);

const String _resultsKey = 'results';
const String _titleKey = 'title';
const String _urlKey = 'url';
const String _contentKey = 'content';

/// What is at the address the reader gave for their search server.
enum LocalSearchStatus {
  /// Not checked yet.
  unknown,

  /// SearXNG answered a search in JSON: ready to use.
  connected,

  /// Nothing is listening there: Docker or the container is not running.
  notRunning,

  /// SearXNG is there, but refuses JSON, which is its default. The settings
  /// the guide's command writes turn it on.
  jsonDisabled,

  /// Something answered, but not as SearXNG would.
  notSearxng,
}

/// Searches through a SearXNG server the reader runs on their own machine.
///
/// SearXNG asks several public engines at once and has no quota of its own,
/// which is the point: Ollama's hosted search runs out, and this does not.
/// It returns snippets rather than pages, so the model reads the pages it
/// wants in full through [PageReader], also on this machine.
class SearxngSearchRepo {
  SearxngSearchRepo({required String baseUrl, http.Client? client})
    : _baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  Uri _searchUri(String query) =>
      Uri.parse('$_baseUrl/search')
          .replace(queryParameters: {'q': query, 'format': 'json'});

  Future<List<SearchResult>> search(
    String query, {
    int maxResults = defaultSearchResults,
  }) async {
    final http.Response response;
    try {
      response = await _client.get(_searchUri(query)).timeout(_searchTimeout);
    } on Object catch (error) {
      logWarning(() => 'Local search could not be reached: $error');
      throw SearchException(SearchFailure.unavailable, cause: error);
    }
    if (response.statusCode != HttpStatus.ok) {
      logWarning(() => 'Local search answered ${response.statusCode}');
      throw SearchException(
        SearchFailure.unavailable,
        cause: 'HTTP ${response.statusCode}',
      );
    }

    final Object? payload;
    try {
      payload = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (error) {
      throw SearchException(SearchFailure.unavailable, cause: error);
    }
    final results = payload is Map<String, dynamic>
        ? payload[_resultsKey] as List<dynamic>? ?? const []
        : const [];

    final found = <SearchResult>[];
    final seen = <String>{};
    for (final raw in results) {
      if (raw is! Map<String, dynamic>) continue;
      final url = raw[_urlKey] as String? ?? '';
      // The same page from two engines is one page.
      if (url.isEmpty || !seen.add(url)) continue;
      found.add(
        SearchResult(
          title: raw[_titleKey] as String? ?? '',
          url: url,
          content: raw[_contentKey] as String? ?? '',
        ),
      );
      if (found.length == maxResults.clamp(1, maximumSearchResults)) break;
    }
    return found;
  }

  /// What is at the address, from one small search.
  Future<LocalSearchStatus> probe() async {
    final http.Response response;
    try {
      response = await _client
          .get(_searchUri('pickstock'))
          .timeout(_probeTimeout);
    } on Object catch (error) {
      logInfo(() => 'No local search at $_baseUrl: $error');
      return LocalSearchStatus.notRunning;
    }
    if (response.statusCode == HttpStatus.forbidden) {
      return LocalSearchStatus.jsonDisabled;
    }
    if (response.statusCode != HttpStatus.ok) {
      return LocalSearchStatus.notSearxng;
    }
    try {
      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      return payload is Map<String, dynamic> && payload[_resultsKey] is List
          ? LocalSearchStatus.connected
          : LocalSearchStatus.notSearxng;
    } on FormatException {
      return LocalSearchStatus.notSearxng;
    }
  }
}

/// A fresh secret for SearXNG's settings. It signs nothing the reader relies
/// on, but SearXNG refuses to start on the default one.
String newSearxngSecret({Random? random}) {
  final source = random ?? Random.secure();
  return [
    for (var index = 0; index < 32; index++)
      source.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

/// The one command the setup guide hands over to paste into Terminal.
///
/// Writes SearXNG's settings — JSON answers on, which it ships off, and the
/// limiter off, which is meant for public servers — then starts the
/// container, replacing one already started by an earlier paste, and has it
/// come back after a restart.
///
/// Written with `printf` rather than a here-document so it runs the same in
/// zsh, bash and fish, and published on 127.0.0.1 so nothing beyond this
/// machine can reach it.
/// The shells the setup command is written for. zsh is what Terminal opens
/// on a Mac, and bash reads the same command.
enum SetupShell {
  posix,
  fish;

  /// The reader's login shell, from the environment the app was started in;
  /// zsh's syntax where it cannot tell.
  static SetupShell fromEnvironment(Map<String, String> environment) =>
      (environment['SHELL'] ?? '').endsWith('fish') ? fish : posix;
}

String searxngStartCommand({
  required String secret,
  SetupShell shell = SetupShell.posix,
  int port = 8888,
}) {
  // fish before 3.0 has no `&&`; `; and` works in every version.
  final then = switch (shell) {
    SetupShell.posix => ' && ',
    SetupShell.fish => '; and ',
  };
  final lines = [
    'use_default_settings: true',
    'server:',
    '  secret_key: "$secret"',
    '  limiter: false',
    'search:',
    '  formats: [html, json]',
  ].map((line) => "'$line'").join(' ');
  return 'mkdir -p $_settingsDirectory$then'
      "printf '%s\\n' $lines > $_settingsDirectory/settings.yml$then"
      'docker rm -f $searxngContainerName 2>/dev/null; '
      'docker run -d --name $searxngContainerName --restart unless-stopped '
      '-p 127.0.0.1:$port:8080 -v $_settingsDirectory:/etc/searxng '
      'searxng/searxng';
}
