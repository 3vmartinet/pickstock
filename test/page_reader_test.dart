import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pickstock/repo/research/page_reader.dart';
import 'package:pickstock/repo/research/web_search_repo.dart';

final String _longParagraph = 'Revenue grew strongly this year. ' * 20;

String _article(String body) =>
    '''
<html><head><title>Crocs Q3</title><style>p { color: red }</style></head>
<body>
  <nav>Home | Markets | Login</nav>
  <article>
    <h1>Crocs results</h1>
    <p>$body</p>
    <script>track();</script>
    <table><tr><td>Revenue</td><td>1.1bn</td></tr></table>
  </article>
  <footer>Copyright</footer>
</body></html>''';

http.Response _html(String body, {int status = 200}) => http.Response.bytes(
  utf8.encode(body),
  status,
  headers: {'content-type': 'text/html; charset=utf-8'},
);

void main() {
  group('the text of an HTML page', () {
    test('keeps the article and drops the furniture', () {
      final page = pageFromHtml(_article('Sales rose.'), url: 'https://x.test');
      expect(page.title, 'Crocs Q3');
      expect(page.content, contains('Crocs results'));
      expect(page.content, contains('Sales rose.'));
      expect(page.content, contains('Revenue | 1.1bn'));
      expect(page.content, isNot(contains('Login')));
      expect(page.content, isNot(contains('track()')));
      expect(page.content, isNot(contains('color: red')));
      expect(page.content, isNot(contains('Copyright')));
    });

    test('falls back to the body where no article is marked', () {
      final page = pageFromHtml(
        '<html><body><p>One</p><p>Two</p></body></html>',
        url: 'https://x.test',
      );
      expect(page.content, 'One\n\nTwo');
    });
  });

  group('reading a page', () {
    test('happens on this machine', () async {
      final reader = PageReader(
        client: MockClient((_) async => _html(_article('Sales rose.'))),
      );
      final page = await reader.read('https://x.test/crocs');
      expect(page.url, 'https://x.test/crocs');
      expect(page.content, contains('Sales rose.'));
    });

    test('a refusing site is unavailable, not a spent allowance', () async {
      final reader = PageReader(
        client: MockClient((_) async => _html('', status: 429)),
      );
      await expectLater(
        reader.read('https://x.test'),
        throwsA(
          isA<SearchException>().having(
            (error) => error.failure,
            'failure',
            SearchFailure.unavailable,
          ),
        ),
      );
    });

    test('a PDF is not read as text', () async {
      final reader = PageReader(
        client: MockClient(
          (_) async => http.Response.bytes(
            [37, 80, 68, 70],
            200,
            headers: {'content-type': 'application/pdf'},
          ),
        ),
      );
      await expectLater(
        reader.read('https://x.test/10-k.pdf'),
        throwsA(isA<SearchException>()),
      );
    });
  });

  group('the search repo reading a page', () {
    test('does not reach the hosted fetch when it reads it here', () async {
      final asked = <Uri>[];
      final repo = OllamaWebSearchRepo(
        apiKey: 'test',
        client: MockClient((request) async {
          asked.add(request.url);
          return _html(_article(_longParagraph));
        }),
      );
      final page = await repo.fetch('https://x.test/crocs');
      expect(page.content, contains('Revenue grew'));
      expect(asked, [Uri.parse('https://x.test/crocs')]);
    });

    test('goes to the hosted fetch for a page it could not read', () async {
      final asked = <Uri>[];
      final repo = OllamaWebSearchRepo(
        apiKey: 'test',
        client: MockClient((request) async {
          asked.add(request.url);
          if (request.url.host == 'ollama.com') {
            return http.Response(
              jsonEncode({'title': 'Rendered', 'content': 'From Ollama'}),
              200,
            );
          }
          // A page built by script: next to nothing until it runs.
          return _html('<html><body><div id="app"></div></body></html>');
        }),
      );
      final page = await repo.fetch('https://x.test/app');
      expect(page.content, 'From Ollama');
      expect(asked.last.host, 'ollama.com');
    });
  });
}
