import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pickstock/data/research/framework_question.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/repo/research/framework_prompts.dart';
import 'package:pickstock/repo/research/ollama_repo.dart';
import 'package:pickstock/repo/research/web_search_repo.dart';

const SearchResult _page = SearchResult(
  title: 'Crocs Q3',
  url: 'https://investors.crocs.com/q3',
  content: 'Revenue fell 6%.',
);

/// A search that always finds the one page.
class _OnePageSearch implements WebSearchRepo {
  @override
  bool get isConfigured => true;

  @override
  Future<List<SearchResult>> search(String query, {int maxResults = 5}) async =>
      const [_page];

  @override
  Future<SearchResult> fetch(String url) async => _page;
}

/// A search that has been rate limited, as Ollama's hosted one is after a
/// day of live runs.
class _RateLimitedSearch implements WebSearchRepo {
  _RateLimitedSearch({this.wait});

  /// The wait the refusal asks for, if any.
  final Duration? wait;

  @override
  bool get isConfigured => true;

  @override
  Future<List<SearchResult>> search(String query, {int maxResults = 5}) =>
      throw SearchException(SearchFailure.rateLimited, retryAfter: wait);

  @override
  Future<SearchResult> fetch(String url) =>
      throw SearchException(SearchFailure.rateLimited, retryAfter: wait);
}

/// The model's turns, in order, and every request it was sent.
class _ScriptedModel {
  _ScriptedModel(this.turns);

  final List<Map<String, Object?>> turns;
  final List<List<dynamic>> sent = [];

  http.Client get client => MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    sent.add(body['messages'] as List<dynamic>);
    return http.Response(jsonEncode({'message': turns[sent.length - 1]}), 200);
  });
}

const Map<String, Object?> _answersFromMemory = {
  'role': 'assistant',
  'content': 'Crocs is fine.',
};

const Map<String, Object?> _searches = {
  'role': 'assistant',
  'content': '',
  'tool_calls': [
    {
      'function': {
        'name': 'web_search',
        // A list, as the 12B model sometimes sends: searched as one query.
        'arguments': {
          'query': ['Crocs', 'Q3'],
        },
      },
    },
  ],
};

const Map<String, Object?> _answersFromReading = {
  'role': 'assistant',
  'content': 'Revenue fell 6% in Q3.',
};

void main() {
  test(
    'a reading question answered from memory is sent back to search',
    () async {
      final model = _ScriptedModel([
        _answersFromMemory,
        _searches,
        _answersFromReading,
      ]);
      final repo = OllamaRepo(search: _OnePageSearch(), client: model.client);

      final answer = await repo.ask('Is Crocs growing?', mustSearch: true);

      expect(answer.text, 'Revenue fell 6% in Q3.');
      expect(answer.sources.single.url, _page.url);
      // The first answer went back with the instruction after it, so the
      // model knows what it said and why it is being asked again.
      final second = model.sent[1];
      expect((second[second.length - 2] as Map)['content'], 'Crocs is fine.');
      expect((second.last as Map)['content'], contains('Call web_search now'));
    },
  );

  test('a reading question whose every search was refused fails, and says '
      'why', () async {
    // What a live run turned up: six searches, all refused, and then an
    // answer from the figures alone that read exactly like a researched one.
    final model = _ScriptedModel([_searches, _answersFromMemory]);
    final repo = OllamaRepo(search: _RateLimitedSearch(), client: model.client);

    await expectLater(
      repo.ask('Is Crocs growing?', mustSearch: true),
      throwsA(
        isA<ResearchException>().having(
          (error) => error.failure,
          'failure',
          ResearchFailure.searchRefused,
        ),
      ),
    );
  });

  group('reading Retry-After', () {
    test('as seconds', () {
      expect(retryAfterOf('7150'), const Duration(seconds: 7150));
    });

    test('as the date to wait until', () {
      final now = DateTime.utc(2026, 10, 27, 16);
      expect(
        retryAfterOf('Tue, 27 Oct 2026 18:00:00 GMT', now: now),
        const Duration(hours: 2),
      );
    });

    test('as nothing, where it is missing or nonsense', () {
      expect(retryAfterOf(null), isNull);
      expect(retryAfterOf('soon'), isNull);
    });

    test('from the search service, onto the refusal', () async {
      final search = OllamaWebSearchRepo(
        apiKey: 'test',
        client: MockClient(
          (_) async => http.Response('', 429, headers: {'retry-after': '7150'}),
        ),
      );
      await expectLater(
        search.search('AppLovin'),
        throwsA(
          isA<SearchException>().having(
            (error) => error.retryAfter,
            'retryAfter',
            const Duration(seconds: 7150),
          ),
        ),
      );
    });

    test('through to the question that could not be read up on', () async {
      final model = _ScriptedModel([_searches, _answersFromMemory]);
      final repo = OllamaRepo(
        search: _RateLimitedSearch(wait: const Duration(hours: 2)),
        client: model.client,
      );
      await expectLater(
        repo.ask('Is AppLovin growing?', mustSearch: true),
        throwsA(
          isA<ResearchException>().having(
            (error) => error.retryAfter,
            'retryAfter',
            const Duration(hours: 2),
          ),
        ),
      );
    });
  });

  test('a refused search still leaves other questions their answer', () async {
    final model = _ScriptedModel([_searches, _answersFromMemory]);
    final repo = OllamaRepo(search: _RateLimitedSearch(), client: model.client);

    final answer = await repo.ask('Is Crocs making cash?');
    expect(answer.text, 'Crocs is fine.');
  });

  test('a reply that is not the JSON asked for is asked for again', () async {
    // Seen live: the reading took half a minute and the JSON came back
    // unreadable once, then fine when asked again.
    final model = _ScriptedModel([
      _answersFromMemory,
      {'role': 'assistant', 'content': 'Sure! Crocs looks fine to me.'},
      {
        'role': 'assistant',
        'content': '{"verdict":"yes","headline":"Cash flow covers profit"}',
      },
    ]);
    final repo = OllamaRepo(search: _OnePageSearch(), client: model.client);
    final prompts = FrameworkPrompts(
      snapshot: const FinancialSnapshot(
        company: Company(ticker: 'CROX', cik: '1', name: 'Crocs, Inc.'),
        years: [FiscalYearFigures(fiscalYear: 2025)],
      ),
    );

    // Cash, which may answer from the filings, so the reading is one turn.
    final reading = await repo.screen(prompts, FrameworkQuestion.cash);

    expect(reading!.answer.headline, 'Cash flow covers profit');
    expect(model.sent, hasLength(3));
  });

  test('is told only once, and its answer then stands', () async {
    final model = _ScriptedModel([_answersFromMemory, _answersFromMemory]);
    final repo = OllamaRepo(search: _OnePageSearch(), client: model.client);

    final answer = await repo.ask('Is Crocs growing?', mustSearch: true);

    expect(answer.text, 'Crocs is fine.');
    expect(answer.sources, isEmpty);
    expect(model.sent, hasLength(2));
  });

  test(
    'a question that may answer from the filings is not sent back',
    () async {
      final model = _ScriptedModel([_answersFromMemory]);
      final repo = OllamaRepo(search: _OnePageSearch(), client: model.client);

      final answer = await repo.ask('Is Crocs making cash?');

      expect(answer.text, 'Crocs is fine.');
      expect(model.sent, hasLength(1));
    },
  );
}
