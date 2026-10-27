import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pickstock/data/research/company_event.dart';
import 'package:pickstock/data/research/framework_question.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/extensions/object_extensions.dart';
import 'package:pickstock/repo/research/framework_prompts.dart';
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
  const ResearchAnswer({required this.text, this.sources = const []});

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

  /// The web search refused every request — rate limited, most often — so
  /// a question that has to be read up on was not.
  searchRefused,

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
    ResearchFailure.searchRefused => strings.researchFailedSearchRefused,
    ResearchFailure.failed => strings.eventsFailedOther,
  };
}

class ResearchException implements Exception {
  const ResearchException(this.failure, {this.cause, this.retryAfter});

  final ResearchFailure failure;
  final Object? cause;

  /// For a refused search, how long the service said to wait, if it said.
  final Duration? retryAfter;

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
  /// [isCancelled] is asked between rounds. A question is several minutes of
  /// searching and reading, and a reader who has withdrawn it should not have
  /// the machine still working through it — nor should the next question in
  /// the line wait behind one nobody wants. What comes back then is empty,
  /// which is what a caller that no longer wants an answer does with one.
  /// [mustSearch] sends a reply that read nothing back once, with an
  /// instruction to search: given figures in its brief, a 12B model will
  /// sometimes answer a question about competitors or the share price from
  /// those alone, and say so with the confidence of having looked.
  Future<ResearchAnswer> ask(
    String question, {
    String? context,
    bool Function()? isCancelled,
    bool mustSearch = false,
  }) async {
    if (!search.isConfigured) {
      throw const ResearchException(ResearchFailure.searchNotConfigured);
    }

    final messages = <Map<String, Object?>>[
      if (context != null) {_roleKey: _systemRole, _contentKey: context},
      {_roleKey: _userRole, _contentKey: question},
    ];
    final sources = <SearchResult>[];
    final refusals = <SearchException>[];
    var hasBeenTold = false;

    for (var round = 0; round <= _maximumToolRounds; round++) {
      if (isCancelled?.call() ?? false) return const ResearchAnswer(text: '');
      final reply = await _chat(
        messages,
        withTools: round < _maximumToolRounds,
      );
      final calls = reply[_toolCallsKey] as List<dynamic>? ?? const [];

      // Searched and refused every time: what follows was written from the
      // brief alone, and would read exactly like an answer that was not. For
      // a question that has to be read up on, that is a failure to say so.
      if (calls.isEmpty &&
          mustSearch &&
          sources.isEmpty &&
          refusals.isNotEmpty) {
        throw ResearchException(
          ResearchFailure.searchRefused,
          cause: refusals.last.failure,
          retryAfter: refusals.last.retryAfter,
        );
      }

      // Once, and only while tools are still on offer: a model that will not
      // search when told is answered with what it wrote, not asked forever.
      if (calls.isEmpty &&
          mustSearch &&
          sources.isEmpty &&
          !hasBeenTold &&
          round < _maximumToolRounds - 1) {
        hasBeenTold = true;
        messages
          ..add(reply.cast<String, Object?>())
          ..add({_roleKey: _userRole, _contentKey: _searchFirst});
        continue;
      }

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
        messages.add(await _answerCall(call, sources, refusals));
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
    bool Function()? isCancelled,
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
      isCancelled: isCancelled,
    );

    // Also the shape a withdrawn question comes back in, which is why the
    // second pass — a minute of distilling — is never reached for one.
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

  /// One of the framework's questions, answered with a verdict.
  ///
  /// Two passes, for the reason [eventsFor] takes two: the first searches and
  /// reads, the second turns what was read into the verdict, a headline and
  /// the evidence, as JSON. The second is handed the filings again, so the
  /// verdict is struck against the company's own figures rather than only
  /// against what the search happened to turn up.
  ///
  /// `null` when the question was withdrawn while it was being read.
  Future<FrameworkReading?> screen(
    FrameworkPrompts prompts,
    FrameworkQuestion question, {
    bool Function()? isCancelled,
  }) async {
    final prompt = prompts.promptFor(question);
    final research = await ask(
      prompt.research,
      context: prompts.brief,
      isCancelled: isCancelled,
      mustSearch: prompt.needsReading,
    );
    if (isCancelled?.call() ?? false) return null;

    // Ordered and without repeats, because the model cites them by number.
    final pages = [
      ...{for (final source in research.sources) source.url},
    ];
    // Asked twice before giving up: the 12B model now and then replies with
    // something that is not the JSON asked for, and the same question put
    // again comes back right. Seconds to ask again, against the half minute
    // of reading that would otherwise be thrown away with it.
    for (var attempt = 0; attempt < _distilAttempts; attempt++) {
      if (isCancelled?.call() ?? false) return null;
      final distilled = await _chat([
        {
          _roleKey: _systemRole,
          _contentKey:
              'You turn research into JSON. Reply with JSON and nothing else.',
        },
        {
          _roleKey: _userRole,
          _contentKey: prompts.distil(prompt, research.text, pages),
        },
      ], withTools: false);

      final answer = frameworkAnswerFrom(
        distilled[_contentKey] as String? ?? '',
        pages,
        filings: prompts.figures,
      );
      if (answer != null) {
        return FrameworkReading(answer: answer, sources: research.sources);
      }
    }
    throw const ResearchException(ResearchFailure.failed);
  }

  /// Reads a framework answer out of whatever the model replied with, or `null`
  /// if there is none to read.
  ///
  /// Tolerant the way [eventsFor]'s reader is — the JSON is taken
  /// from the first brace to the last, since it arrives fenced as often as not —
  /// and tolerant of the shapes a point comes back in: the object asked for, a
  /// bare string, or an object with a `url` instead of a page number. A page
  /// number that is not on the list, or a URL the search never returned, leaves
  /// the point standing without a link: the point may well be true, but a link
  /// that was invented opens nothing.
  ///
  /// A point without a page is only credited to [filings] if it quotes one of
  /// their figures. The model is told to cite page 0 for a point from the
  /// filings, and uses it for anything it did not read anywhere: Crocs' risk
  /// answer credited "geopolitical and trade tensions" to the filings, which
  /// say nothing of the kind. Such a point is kept and marked as the model's
  /// own reading, which is what it is.
  FrameworkAnswer? frameworkAnswerFrom(
    String reply,
    List<String> pages, {
    String filings = '',
  }) {
    final start = reply.indexOf('{');
    final end = reply.lastIndexOf('}');
    if (start < 0 || end <= start) {
      logWarning(() => 'No JSON in the framework reply');
      return null;
    }

    final Map<String, dynamic> payload;
    try {
      payload =
          jsonDecode(reply.substring(start, end + 1)) as Map<String, dynamic>;
    } on Object catch (error) {
      logWarning(() => 'Could not read the framework reply: $error');
      return null;
    }

    final headline = (payload[_headlineKey] as String? ?? '').trim();
    if (headline.isEmpty) return null;

    String? linkFor(Object? source, Object? url) {
      if (source is num) {
        final index = source.toInt() - 1;
        return index >= 0 && index < pages.length ? pages[index] : null;
      }
      if (url is String && pages.contains(url.trim())) return url.trim();
      return null;
    }

    final onFile = _figuresIn(filings);
    FrameworkPoint pointOf(String text, String? url) => FrameworkPoint(
      text: text,
      url: url,
      isFromFilings: url == null && _quotesAny(text, onFile),
    );

    final rawPoints = payload[_pointsKey];
    return FrameworkAnswer(
      verdict: FrameworkVerdict.parse(payload[_verdictKey] as String?),
      headline: headline,
      explanation: (payload[_explanationKey] as String? ?? '').trim(),
      points: [
        if (rawPoints is List)
          for (final raw in rawPoints)
            if (raw is String && raw.trim().isNotEmpty)
              pointOf(raw.trim(), null)
            else if (raw case {_textKey: final String text}
                when text.trim().isNotEmpty)
              pointOf(text.trim(), linkFor(raw[_sourceKey], raw[_urlArgument])),
      ],
    );
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
    List<SearchException> refusals,
  ) async {
    final function = call[_functionKey] as Map<String, dynamic>? ?? const {};
    final name = function[_nameKey] as String? ?? '';
    final arguments =
        function[_argumentsKey] as Map<String, dynamic>? ?? const {};

    String content;
    try {
      final found = switch (name) {
        searchToolName => await search.search(
          _text(arguments[_queryArgument]),
          maxResults:
              (arguments[_maxResultsArgument] as num?)?.toInt() ??
              defaultSearchResults,
        ),
        fetchToolName => [await search.fetch(_text(arguments[_urlArgument]))],
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
      refusals.add(error);
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

/// A tool argument as the text it should have been.
///
/// The model is told each argument is a string and mostly sends one, but now
/// and then sends a list of queries instead — seen from the 12B model on the
/// framework's moat question — and a cast that throws there ends the whole
/// answer over one search. A list is searched as one query.
String _text(Object? argument) => switch (argument) {
  null => '',
  final String text => text,
  final List<dynamic> parts => parts.join(' '),
  _ => argument.toString(),
};

/// How many times a framework answer is asked to be put as JSON.
const int _distilAttempts = 2;

/// Said to a model that answered a reading question without reading.
const String _searchFirst =
    'You answered without searching. Call web_search now — at least once — '
    'and answer again from what you read, citing it. The figures you were '
    'given cannot answer this on their own.';

/// A number in prose, with what it is counted in.
final RegExp _figurePattern = RegExp(
  r'(\d[\d,]*(?:\.\d+)?)\s*(%|billion|bn|million|m\b)?',
  caseSensitive: false,
);

/// Every figure in [text], in the brief's unit: millions, or percent.
///
/// Years and small whole numbers are left out — "FY2025" and "three risks"
/// are in every answer and would credit anything to the filings.
List<double> _figuresIn(String text) => [
  for (final match in _figurePattern.allMatches(text))
    if (double.tryParse(match.group(1)!.replaceAll(',', '')) case final value?)
      if (_isFigure(match.group(1)!, value, match.group(2)))
        switch (match.group(2)?.toLowerCase()) {
          'billion' || 'bn' => value * 1000,
          _ => value,
        },
];

bool _isFigure(String written, double value, String? unit) {
  if (unit != null || written.contains('.')) return true;
  return value >= 10 && (value < 1900 || value > 2100);
}

/// Whether [text] quotes any of [onFile], allowing for rounding: "$1.61
/// billion" is the brief's 1613.8, said the way a person says it.
bool _quotesAny(String text, List<double> onFile) => _figuresIn(text).any(
  (figure) => onFile.any(
    (known) => (figure - known).abs() <= math.max(0.051, known.abs() * 0.006),
  ),
);

/// A framework question's answer, and the pages read to reach it.
class FrameworkReading {
  const FrameworkReading({required this.answer, required this.sources});

  final FrameworkAnswer answer;
  final List<SearchResult> sources;
}

const String _verdictKey = 'verdict';
const String _headlineKey = 'headline';
const String _explanationKey = 'explanation';
const String _pointsKey = 'points';
const String _textKey = 'text';
const String _sourceKey = 'source';

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
