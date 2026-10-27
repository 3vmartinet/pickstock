import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/repo/sec/company_facts_parser.dart';

const double _billion = 1000000000;

Map<String, dynamic> _duration(num value) => {
  'accn': 'a-2025',
  'fy': 2025,
  'fp': 'FY',
  'form': '10-K',
  'start': '2025-01-01',
  'end': '2025-12-31',
  'val': value,
};

Map<String, dynamic> _usd(num value) => {
  'units': {
    'USD': [_duration(value)],
  },
};

/// One year of a filing: revenue and the cash flow that makes it a year, plus
/// whichever of the gross-profit concepts the caller passes.
Map<String, dynamic> _facts({num? grossProfit, num? costOfRevenue}) => {
  'facts': {
    'us-gaap': {
      'Revenues': _usd(100 * _billion),
      'NetCashProvidedByUsedInOperatingActivities': _usd(20 * _billion),
      'GrossProfit': ?(grossProfit == null ? null : _usd(grossProfit)),
      'CostOfRevenue': ?(costOfRevenue == null ? null : _usd(costOfRevenue)),
    },
  },
};

void main() {
  test('reads gross profit where the filer tags it', () {
    final year = CompanyFactsParser.parse(
      _facts(grossProfit: 46 * _billion, costOfRevenue: 50 * _billion),
    ).single;
    // The tag wins over the arithmetic: the filer decided what the cost was.
    expect(year.grossProfit, 46 * _billion);
    expect(year.grossMarginPercent, closeTo(46, 0.01));
  });

  test('works it out from the cost where only that is tagged', () {
    final year = CompanyFactsParser.parse(
      _facts(costOfRevenue: 58 * _billion),
    ).single;
    expect(year.grossProfit, 42 * _billion);
    expect(year.grossMarginPercent, closeTo(42, 0.01));
  });

  test('says nothing rather than guessing where neither is tagged', () {
    final year = CompanyFactsParser.parse(_facts()).single;
    expect(year.grossProfit, isNull);
    expect(year.grossMarginPercent, isNull);
  });

  test('drops a gross profit larger than the revenue it came from', () {
    final year = CompanyFactsParser.parse(
      _facts(grossProfit: 140 * _billion),
    ).single;
    expect(year.grossProfit, isNull);
  });
}
