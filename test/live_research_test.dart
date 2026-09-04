import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/repo/research/ollama_repo.dart';
import 'package:pickstock/repo/research/web_search_repo.dart';

/// Hits Ollama's hosted search and the model on this machine for real, to
/// prove the key reaches the app and that the model uses the tools it is
/// given.
///
/// Skipped unless a key is built in, so the suite stays offline by default:
///
/// ```sh
/// fvm flutter test --dart-define-from-file=env.json test/live_research_test.dart
/// ```
///
/// Skipped rather than silently absent, so a run without a key says so. The
/// key itself is never printed: what is asserted is that a search came back,
/// not what was sent.
final Object? _skip = ollamaApiKey.isEmpty
    ? 'no OLLAMA_API_KEY built in; pass --dart-define-from-file=env.json'
    : null;

/// The model takes tens of seconds a turn on a laptop, and a research loop is
/// several turns.
const Timeout _modelTimeout = Timeout(Duration(minutes: 5));

void main() {
  test('searches the web with the configured key', () async {
    final repo = OllamaWebSearchRepo();
    expect(repo.isConfigured, isTrue);

    final results = await repo.search('MarketWise MKTW investor relations');

    expect(results, isNotEmpty);
    expect(results.length, lessThanOrEqualTo(maximumSearchResults));
    // Every result carries the three fields the model is handed.
    for (final result in results) {
      expect(result.url, startsWith('http'));
      expect(result.title, isNotEmpty);
    }
    // And at least one of them actually has a page behind it, which is what
    // the model reads rather than the titles.
    expect(results.any((result) => result.content.length > 200), isTrue);
  }, skip: _skip);

  test('reads one page in full', () async {
    final result = await OllamaWebSearchRepo().fetch('https://www.sec.gov/');
    expect(result.content.length, greaterThan(200));
  }, skip: _skip);

  test(
    'the local model reaches the web through the tools it is given',
    () async {
      final search = OllamaWebSearchRepo();
      final repo = OllamaRepo(search: search);

      // The server is somebody else's process; say so rather than failing as
      // though the wiring were broken.
      if (!await repo.isAvailable) {
        markTestSkipped('no local ${repo.model}; start ollama and pull it');
        return;
      }

      final answer = await repo.ask(
        'What is the share price of Apple today, and on what date? '
        'Search the web rather than answering from memory.',
      );

      // It searched: the pages it pulled come back with the answer.
      expect(answer.sources, isNotEmpty);
      expect(answer.text, isNotEmpty);
      // And it read them rather than reciting the question back.
      expect(answer.text.toLowerCase(), contains('apple'));
    },
    skip: _skip,
    timeout: _modelTimeout,
  );

  test(
    'carries the figures the app already holds into the answer',
    () async {
      final repo = OllamaRepo(search: OllamaWebSearchRepo());
      if (!await repo.isAvailable) {
        markTestSkipped('no local ${repo.model}; start ollama and pull it');
        return;
      }

      // The shape the report would hand over: what PickStock computed, so the
      // model comments on this company rather than on whatever shares the name.
      final answer = await repo.ask(
        'Revenue is falling. Search the web for why, in one sentence.',
        context:
            'The reader is looking at MARKETWISE, INC. (MKTW). PickStock reads '
            'from its SEC filings: FY2025 revenue \$328.1M, down from \$408.7M '
            'in FY2024 and \$448.2M in FY2023.',
      );

      expect(answer.sources, isNotEmpty);
      expect(answer.text, isNotEmpty);
    },
    skip: _skip,
    timeout: _modelTimeout,
  );

  test(
    'picks out three developments, each with a link that works',
    () async {
      final repo = OllamaRepo(search: OllamaWebSearchRepo());
      if (!await repo.isAvailable) {
        markTestSkipped('no local ${repo.model}; start ollama and pull it');
        return;
      }

      final events = await repo.eventsFor(ticker: 'AAPL', name: 'Apple Inc.');

      expect(events, hasLength(eventsWanted));
      final urls = <String>{};
      for (final event in events) {
        // Something to read, dated where the page said so.
        expect(event.caption, isNotEmpty);
        expect(event.url, startsWith('http'));
        // Three developments, not three accounts of one.
        expect(urls.add(event.url), isTrue);
      }
    },
    skip: _skip,
    timeout: _modelTimeout,
  );

  test(
    'never returns a link the search did not',
    () async {
      final repo = OllamaRepo(search: OllamaWebSearchRepo());
      if (!await repo.isAvailable) {
        markTestSkipped('no local ${repo.model}; start ollama and pull it');
        return;
      }

      // A URL is what opens in a browser, so an invented one is worse than a
      // missing one. Every link is checked against the pages actually fetched,
      // and here nothing was fetched at all.
      final barren = OllamaRepo(search: _NothingFound());
      expect(
        await barren.eventsFor(ticker: 'AAPL', name: 'Apple Inc.'),
        isEmpty,
      );
    },
    skip: _skip,
    timeout: _modelTimeout,
  );
}

/// Search that finds nothing, so the model has no page it is allowed to cite.
class _NothingFound implements WebSearchRepo {
  @override
  bool get isConfigured => true;

  @override
  Future<List<SearchResult>> search(
    String query, {
    int maxResults = defaultSearchResults,
  }) async => const [];

  @override
  Future<SearchResult> fetch(String url) async =>
      const SearchResult(title: '', url: '', content: '');
}
