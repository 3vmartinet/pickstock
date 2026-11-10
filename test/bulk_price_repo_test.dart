import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pickstock/repo/quote/bulk_price_repo.dart';

/// A Tuesday evening in New York, so yesterday Eastern is Monday the 9th.
final DateTime _tuesdayEvening = DateTime.utc(2026, 11, 11, 1, 30);

String _day(http.Request request) => request.url.pathSegments.last;

String _bars(List<(String, double)> closes) =>
    '{"status":"OK","resultsCount":${closes.length},"results":['
    '${closes.map((c) => '{"T":"${c.$1}","c":${c.$2},"o":1,"h":1,"l":1,"v":1,"t":0}').join(',')}'
    ']}';

MassiveBulkPriceRepo _repo(
  Future<http.Response> Function(http.Request) handler, {
  String apiKey = 'test-key',
}) => MassiveBulkPriceRepo(
  apiKey: apiKey,
  client: MockClient(handler),
  now: () => _tuesdayEvening,
);

void main() {
  test('reads every close from the last trading day served', () async {
    final asked = <String>[];
    final repo = _repo((request) async {
      asked.add(_day(request));
      return http.Response(_bars([('AAPL', 250.5), ('BRK.A', 700000)]), 200);
    });

    final prices = await repo.fetchLatest();
    expect(asked, ['2026-11-09']);
    expect(prices!.tradingDay, DateTime.utc(2026, 11, 9));
    expect(prices.closeBySymbol, {'AAPL': 250.5, 'BRK.A': 700000});
  });

  test(
    'walks back past a day the plan will not serve yet and a weekend',
    () async {
      // Monday evening: yesterday is Sunday, Saturday has no bars, Friday has.
      final asked = <String>[];
      final repo = MassiveBulkPriceRepo(
        apiKey: 'test-key',
        now: () => DateTime.utc(2026, 11, 10, 1, 30),
        client: MockClient((request) async {
          asked.add(_day(request));
          return switch (_day(request)) {
            '2026-11-08' => http.Response('{"status":"NOT_AUTHORIZED"}', 403),
            '2026-11-07' => http.Response(
              '{"status":"OK","resultsCount":0,"results":[]}',
              200,
            ),
            _ => http.Response(_bars([('AAPL', 240)]), 200),
          };
        }),
      );

      final prices = await repo.fetchLatest();
      expect(asked, ['2026-11-08', '2026-11-07', '2026-11-06']);
      expect(prices!.tradingDay, DateTime.utc(2026, 11, 6));
    },
  );

  test('gives up when the budget is spent rather than spending more', () async {
    var calls = 0;
    final repo = _repo((request) async {
      calls++;
      return http.Response('{"status":"ERROR"}', 429);
    });
    expect(await repo.fetchLatest(), isNull);
    expect(calls, 1);
  });

  test('gives up after a few days with nothing', () async {
    var calls = 0;
    final repo = _repo((request) async {
      calls++;
      return http.Response('{"status":"NOT_AUTHORIZED"}', 403);
    });
    expect(await repo.fetchLatest(), isNull);
    expect(calls, 4);
  });

  test('drops a close it cannot use rather than the whole day', () async {
    final repo = _repo(
      (request) async => http.Response(
        '{"status":"OK","results":[{"T":"AAPL","c":250},{"T":"BAD","c":0},'
        '{"T":"ODD","c":"x"},{"c":5}]}',
        200,
      ),
    );
    expect((await repo.fetchLatest())!.closeBySymbol, {'AAPL': 250});
  });

  test('asks nothing without a key', () async {
    var calls = 0;
    final repo = _repo((request) async {
      calls++;
      return http.Response('', 200);
    }, apiKey: '');
    expect(repo.isConfigured, isFalse);
    expect(await repo.fetchLatest(), isNull);
    expect(calls, 0);
  });
}
