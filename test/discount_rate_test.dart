import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pickstock/data/valuation/discount_rate.dart';
import 'package:pickstock/repo/market/market_rates_repo.dart';

/// Two rows of the Treasury's daily curve, oldest first — so a reader of the
/// newest row cannot get it by taking whichever came first.
const String _curve = '''
Date,"1 Mo","3 Mo","1 Yr","2 Yr","10 Yr","30 Yr"
08/31/2026,4.10,4.15,4.20,4.30,4.75,5.20
09/02/2026,4.11,4.16,4.21,4.31,4.79,5.24
''';

String _metric(num? beta) =>
    '{"metric":{"beta":${beta ?? 'null'},"52WeekHigh":601.6}}';

MarketRatesRepo _repo({String curve = _curve, num? beta = 1.094}) {
  return LiveMarketRatesRepo(
    apiKey: 'test-key',
    client: MockClient((request) async {
      if (request.url.host.contains('treasury')) {
        return http.Response(curve, 200);
      }
      return http.Response(_metric(beta), 200);
    }),
  );
}

void main() {
  group('the required return', () {
    test('is built from the yield and the beta', () async {
      final rate = await _repo().rateFor('AAPL');
      expect(rate, isNotNull);
      // The newest row of the curve, not the first one in the file.
      expect(rate!.riskFreePercent, 4.79);
      expect(rate.asOf, DateTime.utc(2026, 9, 2));
      expect(rate.beta, closeTo(1.094, 0.001));
      // 4.79 + 1.094 x 5.0
      expect(rate.percent, closeTo(10.26, 0.01));
      expect(rate.isCapped, isFalse);
    });

    test('is held inside a band a borrowed beta cannot leave', () {
      // A beta this high says more about the regression behind it than about
      // the company, and the rate it implies is not a return anybody asks for.
      final wild = DiscountRate(
        riskFreePercent: 4.79,
        beta: 4.0,
        asOf: _anyDay,
      );
      expect(wild.uncappedPercent, closeTo(24.79, 0.01));
      expect(wild.percent, maximumDiscountRate);
      expect(wild.isCapped, isTrue);

      final placid = DiscountRate(
        riskFreePercent: 0.5,
        beta: 0.1,
        asOf: _anyDay,
      );
      expect(placid.percent, minimumDiscountRate);
      expect(placid.isCapped, isTrue);
    });

    test('states nothing rather than half of it', () async {
      // Either figure missing leaves the report on its assumed rate, which is
      // also what a build with no key shows.
      expect(await _repo(beta: null).rateFor('AAPL'), isNull);
      expect(await _repo(curve: 'Date\n').rateFor('AAPL'), isNull);
      expect(await LiveMarketRatesRepo(apiKey: '').rateFor('AAPL'), isNull);
      expect(const UnavailableMarketRatesRepo().isConfigured, isFalse);
    });

    test('asks each provider once and remembers the answer', () async {
      var calls = 0;
      final repo = LiveMarketRatesRepo(
        apiKey: 'test-key',
        client: MockClient((request) async {
          calls++;
          return request.url.host.contains('treasury')
              ? http.Response(_curve, 200)
              : http.Response(_metric(1.094), 200);
        }),
      );

      await repo.rateFor('AAPL');
      expect(calls, 2);
      // The yield is published once a day and a beta is a regression over
      // years; opening the same report again should cost neither.
      await repo.rateFor('AAPL');
      expect(calls, 2);
      // A second company still needs its own beta, but not the yield again.
      await repo.rateFor('MSFT');
      expect(calls, 3);
    });
  });
}

final DateTime _anyDay = DateTime.utc(2026);
