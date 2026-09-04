import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pickstock/data/research/company_event.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/extensions/object_extensions.dart';
import 'package:pickstock/repo/research/web_search_repo.dart';

/// The local server, which is where the model runs. Overridable at build time
/// for a machine that hosts it elsewhere.
const String ollamaHost = String.fromEnvironment(
  'OLLAMA_HOST',
  defaultValue: 'http://localhost:11434',
);

/// The model asked to do the reading. Overridable for the same reason: which
/// models are pulled is a property of the machine, not of the app.
const String ollamaModel = String.fromEnvironment(
  'OLLAMA_MODEL',
  defaultValue: 'gemma4:12b-mlx',
);

const String _chatPath = '/api/chat';
const String _tagsPath = '/api/tags';

const String _modelKey = 'model';
const String _messagesKey = 'messages';
const String _toolsKey = 'tools';
const String _streamKey = 'stream';
const String _thinkKey = 'think';
const String _optionsKey = 'options';
const String _contextLengthKey = 'num_ctx';
const String _roleKey = 'role';
const String _contentKey = 'content';
const String _messageKey = 'message';
const String _toolCallsKey = 'tool_calls';
const String _toolNameKey = 'tool_name';
const String _functionKey = 'function';
const String _nameKey = 'name';
const String _argumentsKey = 'arguments';
const String _modelsKey = 'models';

const String _userRole = 'user';
const String _systemRole = 'system';
const String _toolRole = 'tool';

/// The tools the model is given, named as the hosted service names them.
const String searchToolName = 'web_search';
const String fetchToolName = 'web_fetch';

/// Ollama's own advice for web search: a page comes back as thousands of
/// tokens, and the default window truncates the answer out of existence.
const int _contextLength = 32768;

/// How many developments the header has room for.
const int eventsWanted = 3;

/// How much of a page the model is handed.
///
/// Ollama's own note is that a search can return thousands of tokens a page,
/// and five of those is a prompt a 12B model on a laptop spends minutes
/// re-reading on every round of the loop — a research question that answered
/// in ninety seconds on one search took past four minutes on two. The top of
/// a page carries the substance; what follows is mostly navigation. The whole
/// page is still kept for the reader, who is not the one paying for it.
const int _charactersPerResult = 4000;

/// How many times the model may call a tool before the answer is taken as it
/// stands.
///
/// A loop, because one search is often not enough — it reads the results and
/// asks again. Bounded, because a model that keeps searching would otherwise
/// hold the request open for as long as it liked.
const int _maximumToolRounds = 6;

/// Generous: a 12B model on a laptop takes tens of seconds a turn, and there
/// are several turns to a search.
const Duration _chatTimeout = Duration(minutes: 4);
const Duration _probeTimeout = Duration(seconds: 5);

/// What the model came back with, and what it read to get there.
class ResearchAnswer {
  const ResearchAnswer({required this.text, required this.sources});

  final String text;

  /// Every page the model actually pulled, in the order it asked for them, so
  /// the answer can be checked against what it read.
  final List<SearchResult> sources;
}

/// The ways the local model can be unavailable.
enum ResearchFailure {
  /// No search key, so the model would be answering from memory alone.
  searchNotConfigured,

  /// Nothing listening on the local port.
  serverUnreachable,

  /// The server is there but has not pulled the model.
  modelMissing,

  /// The model cannot call tools, so it cannot search.
  modelCannotSearch,

  /// Reached, and unhappy.
  failed;

  /// Which of the several things that have to be running is not.
  ///
  /// On the failure rather than in each widget that shows it: three tabs and
  /// the header all report the same handful of causes, and a copy per caller
  /// is three chances to word one of them differently.
  String describe(AppLocalizations strings) => switch (this) {
    ResearchFailure.searchNotConfigured => strings.eventsFailedNoKey,
    ResearchFailure.serverUnreachable => strings.eventsFailedNoServer,
    ResearchFailure.modelMissing ||
    ResearchFailure.modelCannotSearch => strings.eventsFailedNoModel,
    ResearchFailure.failed => strings.eventsFailedOther,
  };
}

class ResearchException implements Exception {
  const ResearchException(this.failure, {this.cause});

  final ResearchFailure failure;
  final Object? cause;

  @override
  String toString() => 'ResearchException(${failure.name}, cause: $cause)';
}

/// Asks a model running on this machine to read the web and answer.
///
/// The split is deliberate: the model is local, so nothing about the company
/// being looked at leaves the machine except the search terms the model
/// chooses. The searching itself is a hosted service, because a local model
/// has no way to reach the web on its own.
class OllamaRepo {
  OllamaRepo({
    required this.search,
    http.Client? client,
    this.model = ollamaModel,
    this.host = ollamaHost,
  }) : _client = client ?? http.Client();

  /// Where the model's reading is actually done.
  final WebSearchRepo search;
  final http.Client _client;
  final String model;
  final String host;

  /// Whether a search key was built in. The model can be asked without one,
  /// but not to read anything, which is the whole point.
  bool get isConfigured => search.isConfigured;

  /// Whether the local server is up and has [model].
  ///
  /// Checked rather than assumed: the server is somebody else's process and
  /// may well not be running, and a feature that offers itself and then fails
  /// is worse than one that says it is unavailable.
  Future<bool> get isAvailable async {
    try {
      final response = await _client
          .get(Uri.parse('$host$_tagsPath'))
          .timeout(_probeTimeout);
      if (response.statusCode != HttpStatus.ok) return false;
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final models = payload[_modelsKey] as List<dynamic>? ?? const [];
      return models.any(
        (raw) => (raw as Map<String, dynamic>)[_nameKey] == model,
      );
    } on Object catch (error) {
      logInfo(() => 'No local model server: $error');
      return false;
    }
  }

  /// Answers [question], letting the model search the web as it needs to.
  ///
  /// [context] is handed over as a system message: the figures the app already
  /// holds, so the model comments on the company in front of the reader rather
  /// than on whatever it finds under the same name.
  Future<ResearchAnswer> ask(String question, {String? context}) async {
    if (!search.isConfigured) {
      throw const ResearchException(ResearchFailure.searchNotConfigured);
    }

    final messages = <Map<String, Object?>>[
      if (context != null) {_roleKey: _systemRole, _contentKey: context},
      {_roleKey: _userRole, _contentKey: question},
    ];
    final sources = <SearchResult>[];

    for (var round = 0; round <= _maximumToolRounds; round++) {
      final reply = await _chat(
        messages,
        withTools: round < _maximumToolRounds,
      );
      final calls = reply[_toolCallsKey] as List<dynamic>? ?? const [];

      if (calls.isEmpty) {
        return ResearchAnswer(
          text: (reply[_contentKey] as String? ?? '').trim(),
          sources: sources,
        );
      }

      // The assistant's turn goes back verbatim, tool calls included: without
      // it the answers below belong to nothing and the model asks again.
      messages.add(reply.cast<String, Object?>());
      for (final raw in calls) {
        final call = raw as Map<String, dynamic>;
        messages.add(await _answerCall(call, sources));
      }
    }

    // The loop above runs its last round with no tools, so the model has to
    // answer; reaching here means it did not.
    throw const ResearchException(ResearchFailure.failed);
  }

  /// The three most recent developments worth an investor's attention, each
  /// with the page it was read on.
  ///
  /// Two passes. The first lets the model search and read, which is where the
  /// time goes; the second asks it to boil what it found down to three lines
  /// of JSON, which takes a second or two. Splitting them is not merely tidy:
  /// this runner ignores the `format` schema, so the shape has to be asked for
  /// in words — and a model juggling tool calls and an output shape at once
  /// does neither well.
  ///
  /// Every returned link is checked against the pages the search actually
  /// handed over. A made-up URL is worse than a missing one here, because
  /// clicking it opens a browser.
  Future<List<CompanyEvent>> eventsFor({
    required String ticker,
    required String name,
  }) async {
    final research = await ask(
      'Find the three most recent developments at $name ($ticker) that would '
      'matter to someone deciding whether to own the shares. Search the web. '
      'Include developments that are not about the results — a product, a '
      'lawsuit, an acquisition, a change of management, a regulator — as well '
      'as any that are. Three distinct events, not three accounts of one. For '
      'each, note the date it happened and the page you read it on.',
      context:
          'You are researching one company for an investor who is looking at '
          'its SEC filings. Today is ${DateTime.now().toIso8601String()}.',
    );

    if (research.sources.isEmpty) return const [];
    final pages = {for (final source in research.sources) source.url};

    final distilled = await _chat([
      {
        _roleKey: _systemRole,
        _contentKey:
            'You turn research into JSON. Reply with JSON and nothing else.',
      },
      {
        _roleKey: _userRole,
        _contentKey:
            'Here is research about $name ($ticker):\n\n${research.text}\n\n'
            'These are the only pages that were read:\n'
            '${pages.join('\n')}\n\n'
            'Return {"events":[{"date","caption","url"}]} with the three most '
            'recent distinct developments. `date` is YYYY-MM-DD, or "" if the '
            'research does not say. `caption` is one short line, under twelve '
            'words, saying what happened. `url` must be copied exactly from '
            'the list above — never write a URL that is not on it.',
      },
    ], withTools: false);

    return _eventsFrom(distilled[_contentKey] as String? ?? '', pages);
  }

  /// Reads the events out of whatever the model replied with.
  ///
  /// Tolerant by necessity: the reply arrives wrapped in a code fence as often
  /// as not, so the JSON is taken from the first brace to the last rather than
  /// by trusting the whole string to parse.
  List<CompanyEvent> _eventsFrom(String reply, Set<String> pages) {
    final start = reply.indexOf('{');
    final end = reply.lastIndexOf('}');
    if (start < 0 || end <= start) {
      logWarning(() => 'No JSON in the distilled reply');
      return const [];
    }

    final List<dynamic> raw;
    try {
      final payload =
          jsonDecode(reply.substring(start, end + 1)) as Map<String, dynamic>;
      raw = payload[_eventsKey] as List<dynamic>? ?? const [];
    } on Object catch (error) {
      logWarning(() => 'Could not read the distilled reply: $error');
      return const [];
    }

    final events = <CompanyEvent>[];
    final seen = <String>{};
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) continue;
      final url = (entry[_urlArgument] as String? ?? '').trim();
      final caption = (entry[_captionKey] as String? ?? '').trim();
      // A link the search never returned was invented, and an event with
      // nothing to open is not one a reader can check.
      if (caption.isEmpty || !pages.contains(url)) continue;
      // Three accounts of one event share a page; only the first is news.
      if (!seen.add(url)) continue;
      events.add(
        CompanyEvent(
          caption: caption,
          url: url,
          date: DateTime.tryParse((entry[_dateKey] as String? ?? '').trim()),
        ),
      );
      if (events.length == eventsWanted) break;
    }
    return events;
  }

  /// Runs one tool call and shapes the result as the message the model expects
  /// back.
  Future<Map<String, Object?>> _answerCall(
    Map<String, dynamic> call,
    List<SearchResult> sources,
  ) async {
    final function = call[_functionKey] as Map<String, dynamic>? ?? const {};
    final name = function[_nameKey] as String? ?? '';
    final arguments =
        function[_argumentsKey] as Map<String, dynamic>? ?? const {};

    String content;
    try {
      final found = switch (name) {
        searchToolName => await search.search(
          arguments[_queryArgument] as String? ?? '',
          maxResults:
              (arguments[_maxResultsArgument] as num?)?.toInt() ??
              defaultSearchResults,
        ),
        fetchToolName => [
          await search.fetch(arguments[_urlArgument] as String? ?? ''),
        ],
        _ => throw const ResearchException(ResearchFailure.failed),
      };
      // The reader gets the page whole; the model gets as much of it as it
      // can afford to read again on every round.
      sources.addAll(found);
      content = jsonEncode([
        for (final result in found)
          {
            _titleArgument: result.title,
            _urlArgument: result.url,
            _contentArgument: _trimmed(result.content),
          },
      ]);
    } on SearchException catch (error) {
      // Handed back to the model rather than thrown: a search that failed is
      // something it can work around, and an answer with a gap in it beats no
      // answer at all.
      logWarning(() => 'Tool $name failed: $error');
      content = jsonEncode({_errorArgument: error.failure.name});
    }

    return {_roleKey: _toolRole, _toolNameKey: name, _contentKey: content};
  }

  Future<Map<String, dynamic>> _chat(
    List<Map<String, Object?>> messages, {
    required bool withTools,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$host$_chatPath'),
            headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
            body: jsonEncode({
              _modelKey: model,
              _messagesKey: messages,
              if (withTools) _toolsKey: _toolDefinitions,
              _streamKey: false,
              // Off: the reasoning is not shown to anyone, and on a laptop it
              // is most of the wait.
              _thinkKey: false,
              _optionsKey: {_contextLengthKey: _contextLength},
            }),
          )
          .timeout(_chatTimeout);
    } on Object catch (error) {
      throw ResearchException(ResearchFailure.serverUnreachable, cause: error);
    }

    if (response.statusCode == HttpStatus.notFound) {
      throw const ResearchException(ResearchFailure.modelMissing);
    }
    if (response.statusCode != HttpStatus.ok) {
      logWarning(() => 'Local model answered ${response.statusCode}');
      throw const ResearchException(ResearchFailure.failed);
    }

    final payload =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return payload[_messageKey] as Map<String, dynamic>? ?? const {};
  }
}

/// [text] cut to what the model is given, on a word boundary so it does not
/// end mid-token.
String _trimmed(String text) {
  if (text.length <= _charactersPerResult) return text;
  final cut = text.substring(0, _charactersPerResult);
  final lastSpace = cut.lastIndexOf(' ');
  return lastSpace <= 0 ? cut : cut.substring(0, lastSpace);
}

const String _eventsKey = 'events';
const String _captionKey = 'caption';
const String _dateKey = 'date';

const String _queryArgument = 'query';
const String _maxResultsArgument = 'max_results';
const String _urlArgument = 'url';
const String _titleArgument = 'title';
const String _contentArgument = 'content';
const String _errorArgument = 'error';

/// The tools as the model is told about them.
const List<Map<String, Object?>> _toolDefinitions = [
  {
    'type': 'function',
    _functionKey: {
      _nameKey: searchToolName,
      'description':
          'Search the web. Returns a list of pages, each with a title, a url '
          'and its text.',
      'parameters': {
        'type': 'object',
        'properties': {
          _queryArgument: {
            'type': 'string',
            'description': 'What to search for',
          },
          _maxResultsArgument: {
            'type': 'integer',
            'description': 'How many pages to return, 1 to 10',
          },
        },
        'required': [_queryArgument],
      },
    },
  },
  {
    'type': 'function',
    _functionKey: {
      _nameKey: fetchToolName,
      'description':
          'Read one web page in full, for when a search result is not enough.',
      'parameters': {
        'type': 'object',
        'properties': {
          _urlArgument: {'type': 'string', 'description': 'The page to read'},
        },
        'required': [_urlArgument],
      },
    },
  },
];
