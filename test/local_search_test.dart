import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/research/local_first_search_repo.dart';
import 'package:pickstock/repo/research/searxng_search_repo.dart';
import 'package:pickstock/repo/research/web_search_repo.dart';
import 'package:pickstock/repo/settings/settings_repo.dart';
import 'package:pickstock/ui/settings/app_menu.dart';
import 'package:pickstock/ui/settings/settings_view_model.dart';
import 'package:pickstock/ui/settings/widgets/search_setup_dialog.dart';
import 'package:pickstock/ui/settings/widgets/settings_dialog.dart';

import 'support/test_directory.dart';

String _searxngJson(List<String> urls) => jsonEncode({
  'query': 'x',
  'results': [
    for (final url in urls) {'url': url, 'title': 'T $url', 'content': 'c'},
  ],
});

MockClient _answering(http.Response Function(http.Request) answer) =>
    MockClient((request) async => answer(request));

/// A hosted search that says which query it was asked, or that is not there,
/// or that refuses as Ollama's does once its allowance is spent.
class _Hosted implements WebSearchRepo {
  _Hosted({this.isConfigured = true, this.isSpent = false});

  @override
  final bool isConfigured;

  /// Whether every request is refused for want of allowance.
  final bool isSpent;

  final List<String> asked = [];
  final List<String> fetched = [];

  @override
  Future<List<SearchResult>> search(String query, {int maxResults = 5}) async {
    asked.add(query);
    if (isSpent) {
      throw const SearchException(
        SearchFailure.rateLimited,
        retryAfter: Duration(hours: 2),
      );
    }
    return const [SearchResult(title: 'hosted', url: 'https://h', content: '')];
  }

  @override
  Future<SearchResult> fetch(String url) async {
    fetched.add(url);
    if (isSpent) {
      throw const SearchException(
        SearchFailure.rateLimited,
        retryAfter: Duration(hours: 2),
      );
    }
    return SearchResult(title: '', url: url, content: '');
  }
}

void main() {
  group('SearXNG', () {
    test('answers a search with its results, each page once', () async {
      late Uri asked;
      final repo = SearxngSearchRepo(
        baseUrl: 'http://localhost:8888/',
        client: _answering((request) {
          asked = request.url;
          return http.Response(
            _searxngJson(['https://a', 'https://a', 'https://b', 'https://c']),
            200,
          );
        }),
      );

      final found = await repo.search('Crocs revenue', maxResults: 2);

      expect(asked.path, '/search');
      expect(asked.queryParameters, {'q': 'Crocs revenue', 'format': 'json'});
      expect(found.map((result) => result.url), ['https://a', 'https://b']);
    });

    test('says what is at its address', () async {
      Future<LocalSearchStatus> probe(MockClient client) =>
          SearxngSearchRepo(baseUrl: defaultSearxngUrl, client: client).probe();

      expect(
        await probe(_answering((_) => http.Response(_searxngJson([]), 200))),
        LocalSearchStatus.connected,
      );
      expect(
        await probe(_answering((_) => http.Response('Forbidden', 403))),
        LocalSearchStatus.jsonDisabled,
      );
      expect(
        await probe(_answering((_) => http.Response('<html></html>', 200))),
        LocalSearchStatus.notSearxng,
      );
      expect(
        await probe(
          MockClient((_) async => throw http.ClientException('refused')),
        ),
        LocalSearchStatus.notRunning,
      );
    });

    test('is started by one command that turns JSON on', () {
      final command = searxngStartCommand(secret: 'abc123');
      expect(command, contains('formats: [html, json]'));
      expect(command, contains('secret_key: "abc123"'));
      expect(command, contains('limiter: false'));
      // Reachable from this machine only.
      expect(command, contains('-p 127.0.0.1:8888:8080'));
      expect(command, contains('--restart unless-stopped'));
      // No here-document: fish has none.
      expect(command, isNot(contains('<<')));
      expect(newSearxngSecret(), hasLength(64));

      final fish = searxngStartCommand(
        secret: 'abc123',
        shell: SetupShell.fish,
      );
      expect(fish, isNot(contains('&&')));
      expect(fish, contains('; and printf'));
      expect(fish, contains('formats: [html, json]'));
      expect(
        SetupShell.fromEnvironment({'SHELL': '/opt/homebrew/bin/fish'}),
        SetupShell.fish,
      );
      expect(
        SetupShell.fromEnvironment({'SHELL': '/bin/zsh'}),
        SetupShell.posix,
      );
      expect(SetupShell.fromEnvironment({}), SetupShell.posix);
    });
  });

  group('searching local first', () {
    late MemorySettingsRepo settings;

    setUp(() => settings = MemorySettingsRepo());

    LocalFirstSearchRepo repo(WebSearchRepo hosted, MockClient client) =>
        LocalFirstSearchRepo(
          hosted: hosted,
          settings: settings,
          client: client,
        );

    test('asks the local server, and not Ollama, once it is on', () async {
      await settings.setLocalSearchEnabled(true);
      final hosted = _Hosted();
      final found = await repo(
        hosted,
        _answering((_) => http.Response(_searxngJson(['https://a']), 200)),
      ).search('x');

      expect(found.single.url, 'https://a');
      expect(hosted.asked, isEmpty);
    });

    test('falls back to Ollama when the local server is down', () async {
      await settings.setLocalSearchEnabled(true);
      final hosted = _Hosted();
      final found = await repo(
        hosted,
        MockClient((_) async => throw http.ClientException('refused')),
      ).search('x');

      expect(found.single.title, 'hosted');
      expect(hosted.asked, ['x']);
    });

    test('falls back to Ollama when the local server finds nothing', () async {
      await settings.setLocalSearchEnabled(true);
      final hosted = _Hosted();
      await repo(
        hosted,
        _answering((_) => http.Response(_searxngJson([]), 200)),
      ).search('x');

      expect(hosted.asked, ['x']);
    });

    test('works without an Ollama key, and fails without one', () async {
      await settings.setLocalSearchEnabled(true);
      final down = repo(
        _Hosted(isConfigured: false),
        MockClient((_) async => throw http.ClientException('refused')),
      );
      expect(down.isConfigured, isTrue);
      await expectLater(down.search('x'), throwsA(isA<SearchException>()));
    });

    test('a spent Ollama turns a local "nothing" into nothing, not a limit, '
        'and is left alone after', () async {
      await settings.setLocalSearchEnabled(true);
      final hosted = _Hosted(isSpent: true);
      final search = repo(
        hosted,
        _answering((_) => http.Response(_searxngJson([]), 200)),
      );

      expect(await search.search('x'), isEmpty);
      expect(await search.search('y'), isEmpty);
      // Asked once, refused, and not asked again within its wait.
      expect(hosted.asked, ['x']);
    });

    test('a spent Ollama leaves the local failure as the failure', () async {
      await settings.setLocalSearchEnabled(true);
      final search = repo(
        _Hosted(isSpent: true),
        MockClient((_) async => throw http.ClientException('refused')),
      );

      await expectLater(
        search.search('x'),
        throwsA(
          isA<SearchException>().having(
            (error) => error.failure,
            'failure',
            SearchFailure.unavailable,
          ),
        ),
      );
    });

    test('a page Ollama will not fetch is read here instead', () async {
      await settings.setLocalSearchEnabled(true);
      final hosted = _Hosted(isSpent: true);
      final page = await repo(
        hosted,
        _answering(
          (_) => http.Response(
            '<html><body><p>${'Revenue rose. ' * 40}</p></body></html>',
            200,
            headers: {'content-type': 'text/html'},
          ),
        ),
      ).fetch('https://example.com/a');

      expect(hosted.fetched, ['https://example.com/a']);
      expect(page.content, contains('Revenue rose.'));
    });

    test('goes straight to Ollama while it is off', () async {
      final hosted = _Hosted();
      await repo(
        hosted,
        MockClient((_) async => fail('the local server was asked')),
      ).search('x');
      expect(hosted.asked, ['x']);
    });
  });

  group('the setup guide', () {
    late AppDatabase database;
    late MemorySettingsRepo settings;

    setUp(() async {
      settings = MemorySettingsRepo();
      database = await registerTestDependencies(settingsRepo: settings);
      SettingsViewModel.hasHostedSearch = true;
    });

    tearDown(() async {
      SettingsViewModel.searxngAt = (url) => SearxngSearchRepo(baseUrl: url);
      await database.close();
      await GetIt.I.reset();
    });

    Future<void> pumpFrames(WidgetTester tester, {int frames = 10}) async {
      for (var frame = 0; frame < frames; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> openSettings(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1400, 1000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const PickStockApp());
      await pumpFrames(tester);
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        appMenuChannel.name,
        appMenuChannel.codec.encodeMethodCall(
          const MethodCall(openSettingsMethod),
        ),
        (_) {},
      );
      await pumpFrames(tester);
    }

    testWidgets('finds the server and switches to it', (tester) async {
      var isRunning = false;
      SettingsViewModel.searxngAt = (url) => SearxngSearchRepo(
        baseUrl: url,
        client: MockClient((_) async {
          if (!isRunning) throw http.ClientException('refused');
          return http.Response(_searxngJson([]), 200);
        }),
      );

      await openSettings(tester);
      expect(
        find.text('Hosted search, which has a usage limit.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(searchSetupOpenKey));
      await pumpFrames(tester);
      expect(find.text('Unlimited web search'), findsOneWidget);
      expect(
        find.text('Not running: start your container app'),
        findsOneWidget,
      );

      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.ensureVisible(find.byKey(searchSetupCopyKey));
      await tester.tap(find.byKey(searchSetupCopyKey));
      await pumpFrames(tester, frames: 2);
      expect(find.text('Copied'), findsOneWidget);
      expect(copied, contains('docker run'));

      // Each shell gets its own spelling of the command.
      Future<void> copyFor(String shell) async {
        await tester.tap(find.text(shell));
        await pumpFrames(tester, frames: 2);
        await tester.tap(find.byKey(searchSetupCopyKey));
        await pumpFrames(tester, frames: 2);
      }

      await copyFor('zsh / bash');
      expect(copied, contains(' && '));
      await copyFor('fish');
      expect(copied, contains('; and '));
      expect(copied, isNot(contains('&&')));

      // The reader pastes the command; the guide notices on its own.
      isRunning = true;
      await pumpFrames(tester, frames: 40);

      expect(find.text('Connected: searches run on this Mac'), findsWidgets);
      expect(settings.localSearchEnabled, isTrue);

      await tester.ensureVisible(find.byKey(searchSetupDoneKey));
      await tester.pump();
      await tester.tap(find.byKey(searchSetupDoneKey));
      await pumpFrames(tester);
      expect(find.byKey(searchSetupDoneKey), findsNothing);
      // The settings now offer to turn it off rather than to set it up.
      expect(find.byKey(localSearchSwitchKey), findsOneWidget);
    });
  });
}
