import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:pickstock/extensions/object_extensions.dart';
import 'package:pickstock/repo/research/web_search_repo.dart';

/// A page that never finishes loading should not hold a model's tool call
/// open for longer than the hosted fetch would have.
const Duration _readTimeout = Duration(seconds: 20);

/// Some sites turn away clients that do not look like a browser.
const String _userAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
    '(KHTML, like Gecko) Version/18.0 Safari/605.1.15';

/// Elements that are never the page's content: code, chrome and furniture.
const List<String> _noise = [
  'script',
  'style',
  'noscript',
  'template',
  'svg',
  'canvas',
  'iframe',
  'form',
  'button',
  'nav',
  'header',
  'footer',
  'aside',
];

/// Elements after which the text breaks, so paragraphs and table rows do not
/// run together into one line.
const Set<String> _blocks = {
  'p',
  'div',
  'section',
  'article',
  'main',
  'br',
  'li',
  'tr',
  'table',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'blockquote',
  'pre',
  'dt',
  'dd',
};

/// Reads a page on this machine rather than through a hosted service, so a
/// model reading a page in full costs nothing against a search allowance.
class PageReader {
  PageReader({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<SearchResult> read(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw SearchException(SearchFailure.unavailable, cause: 'Bad URL: $url');
    }

    final http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: {
              HttpHeaders.userAgentHeader: _userAgent,
              HttpHeaders.acceptHeader:
                  'text/html,application/xhtml+xml,text/plain;q=0.9,*/*;q=0.5',
            },
          )
          .timeout(_readTimeout);
    } on Object catch (error) {
      logWarning(() => 'Page could not be reached: $error');
      throw SearchException(SearchFailure.unavailable, cause: error);
    }

    // A site turning this client away is not the search allowance running
    // out, so every refusal reads as unavailable rather than rate limited.
    if (response.statusCode != HttpStatus.ok) {
      logWarning(() => 'Page answered ${response.statusCode}');
      throw SearchException(
        SearchFailure.unavailable,
        cause: 'HTTP ${response.statusCode}',
      );
    }

    final type = ContentType.parse(
      response.headers[HttpHeaders.contentTypeHeader] ?? 'text/html',
    );
    final body = _decoded(response.bodyBytes, type.charset);

    if (type.subType == 'html' || type.subType == 'xhtml+xml') {
      return pageFromHtml(body, url: url);
    }
    if (type.primaryType == 'text' || type.subType == 'json') {
      return SearchResult(title: '', url: url, content: body.trim());
    }
    // A PDF or an image has no text this can read.
    throw SearchException(
      SearchFailure.unavailable,
      cause: 'Unreadable ${type.mimeType}',
    );
  }

  String _decoded(List<int> bytes, String? charset) {
    final encoding = Encoding.getByName(charset) ?? utf8;
    return encoding == utf8
        ? utf8.decode(bytes, allowMalformed: true)
        : encoding.decode(bytes);
  }
}

/// The readable text of an HTML page: its article or main region where it
/// marks one, otherwise its body, with the furniture taken out.
SearchResult pageFromHtml(String source, {required String url}) {
  final document = html_parser.parse(source);
  final title = document.querySelector('title')?.text.trim() ?? '';

  for (final element in document.querySelectorAll(_noise.join(','))) {
    element.remove();
  }

  final root =
      document.querySelector('article') ??
      document.querySelector('main') ??
      document.querySelector('[role=main]') ??
      document.body;

  final buffer = StringBuffer();
  if (root != null) _writeText(root, buffer);

  return SearchResult(title: title, url: url, content: _tidied('$buffer'));
}

void _writeText(dom.Node node, StringBuffer buffer) {
  if (node is dom.Text) {
    buffer.write(node.text);
    return;
  }
  final isBlock = node is dom.Element && _blocks.contains(node.localName);
  if (isBlock) buffer.write('\n');
  for (final child in node.nodes) {
    _writeText(child, buffer);
    // Cells in one row stay on one line, apart from each other.
    if (child is dom.Element &&
        (child.localName == 'td' || child.localName == 'th')) {
      buffer.write(' | ');
    }
  }
  if (isBlock) buffer.write('\n');
}

/// Runs of spaces become one, and blank lines no more than one.
String _tidied(String text) => text
    .split('\n')
    .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
    .join('\n')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();
