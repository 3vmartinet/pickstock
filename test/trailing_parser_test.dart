import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/repo/sec/company_facts_parser.dart';

/// A calendar-year filer whose newest report is the Q3 2026 10-Q.
///
/// The 10-K for 2025 states the year; the 10-Q states nine months of 2026
/// beside nine months of 2025, and the quarter beside the quarter.
Map<String, dynamic> _flow({
  required num year2025,
  required num nineMonths2026,
  required num nineMonths2025,
  bool withComparative = true,
}) => {
  'units': {
    'USD': [
      _duration('10-K', 'FY', 2025, '2025-01-01', '2025-12-31', year2025),
      _duration('10-Q', 'Q3', 2026, '2026-01-01', '2026-09-30', nineMonths2026),
      _duration('10-Q', 'Q3', 2026, '2026-07-01', '2026-09-30', 1),
      if (withComparative)
        _duration(
          '10-Q',
          'Q3',
          2026,
          '2025-01-01',
          '2025-09-30',
          nineMonths2025,
        ),
    ],
  },
};

Map<String, dynamic> _duration(
  String form,
  String fp,
  int fy,
  String start,
  String end,
  num val,
) => {
  'form': form,
  'fp': fp,
  'fy': fy,
  'start': start,
  'end': end,
  'val': val,
  'accn': '$form-$fy-$fp',
  'filed': form == '10-K' ? '2026-02-15' : '2026-10-30',
};

Map<String, dynamic> _instant({num? yearEnd, num? quarterEnd}) => {
  'units': {
    'USD': [
      if (yearEnd != null)
        {
          'form': '10-K',
          'fp': 'FY',
          'fy': 2025,
          'end': '2025-12-31',
          'val': yearEnd,
          'accn': '10-K-2025-FY',
          'filed': '2026-02-15',
        },
      if (quarterEnd != null)
        {
          'form': '10-Q',
          'fp': 'Q3',
          'fy': 2026,
          'end': '2026-09-30',
          'val': quarterEnd,
          'accn': '10-Q-2026-Q3',
          'filed': '2026-10-30',
        },
    ],
  },
};

Map<String, dynamic> _facts(Map<String, dynamic> tags) => {
  'facts': {
    'us-gaap': {
      'NetCashProvidedByUsedInOperatingActivities': _flow(
        year2025: 100,
        nineMonths2026: 90,
        nineMonths2025: 70,
      ),
      ...tags,
    },
  },
};

void main() {
  test('is the last year, plus this year to date, less last year\'s', () {
    final trailing = CompanyFactsParser.parseTrailing(
      _facts({
        'Revenues': _flow(
          year2025: 1000,
          nineMonths2026: 900,
          nineMonths2025: 750,
        ),
      }),
    )!;
    expect(trailing.periodEnd, DateTime(2026, 9, 30));
    expect(trailing.fiscalYear, 2026);
    expect(trailing.quarter, 3);
    expect(trailing.revenue, 1150);
  });

  test('is nothing once the annual report is as recent', () {
    final facts = _facts({});
    (facts['facts']['us-gaap']['NetCashProvidedByUsedInOperatingActivities']['units']['USD']
            as List)
        .add(_duration('10-K', 'FY', 2026, '2026-01-01', '2026-12-31', 130));
    expect(CompanyFactsParser.parseTrailing(facts), isNull);
  });

  test('leaves out a line whose comparative months are not stated', () {
    final trailing = CompanyFactsParser.parseTrailing(
      _facts({
        'Revenues': _flow(
          year2025: 1000,
          nineMonths2026: 900,
          nineMonths2025: 750,
          withComparative: false,
        ),
      }),
    )!;
    expect(trailing.revenue, isNull);
    // The rest of the quarter still stands, dated by the operating cash flow.
    expect(trailing.periodEnd, DateTime(2026, 9, 30));
  });

  test('takes the larger of contract and total revenue, as a year does', () {
    final trailing = CompanyFactsParser.parseTrailing(
      _facts({
        'RevenueFromContractWithCustomerExcludingAssessedTax': _flow(
          year2025: 300,
          nineMonths2026: 250,
          nineMonths2025: 200,
        ),
        'Revenues': _flow(
          year2025: 1000,
          nineMonths2026: 900,
          nineMonths2025: 750,
        ),
      }),
    )!;
    expect(trailing.revenue, 1150);
  });

  test('reads the balance sheet at the quarter end', () {
    // Amazon's 2026: it borrowed $107B in nine months.
    final trailing = CompanyFactsParser.parseTrailing(
      _facts({
        'LongTermDebtNoncurrent': _instant(yearEnd: 65.6, quarterEnd: 173.1),
        'CashAndCashEquivalentsAtCarryingValue': _instant(
          yearEnd: 86.8,
          quarterEnd: 55.8,
        ),
      }),
    )!;
    expect(trailing.totalDebt, 173.1);
    expect(trailing.cash, 55.8);
    expect(trailing.netDebt, closeTo(117.3, 1e-9));
  });

  test('keeps the annual balance sheet where the quarter drops a debt line '
      'the year carried', () {
    // Current debt stated only in the annual report: reading the quarter
    // would lose it, and the company would look less indebted than it is.
    final trailing = CompanyFactsParser.parseTrailing(
      _facts({
        'LongTermDebtNoncurrent': _instant(yearEnd: 50, quarterEnd: 50),
        'LongTermDebtCurrent': _instant(yearEnd: 20),
        'CashAndCashEquivalentsAtCarryingValue': _instant(
          yearEnd: 10,
          quarterEnd: 30,
        ),
      }),
    )!;
    expect(trailing.totalDebt, isNull);
    expect(trailing.cash, isNull);
    expect(trailing.netDebt, isNull);
  });

  test('carries the year-end leases where the quarter does not restate '
      'them', () {
    final trailing = CompanyFactsParser.parseTrailing(
      _facts({
        'LongTermDebtNoncurrent': _instant(yearEnd: 50, quarterEnd: 60),
        'OperatingLeaseLiabilityNoncurrent': _instant(yearEnd: 8),
        'OperatingLeaseLiabilityCurrent': _instant(yearEnd: 2),
        'CashAndCashEquivalentsAtCarryingValue': _instant(
          yearEnd: 10,
          quarterEnd: 15,
        ),
      }),
    )!;
    expect(trailing.totalDebt, 70);
    expect(trailing.cash, 15);
  });

  test('takes the diluted average as the quarter states it, after a '
      'split', () {
    // Amphenol's two-for-one: the 10-K's average is in the old shares.
    final facts = _facts({
      'WeightedAverageNumberOfDilutedSharesOutstanding': {
        'units': {
          'shares': [
            _duration('10-K', 'FY', 2025, '2025-01-01', '2025-12-31', 1.278e9),
            _duration('10-Q', 'Q3', 2026, '2026-01-01', '2026-09-30', 2.58e9),
            _duration('10-Q', 'Q3', 2026, '2026-07-01', '2026-09-30', 2.583e9),
          ],
        },
      },
    });
    expect(CompanyFactsParser.parseTrailing(facts)!.dilutedShares, 2.58e9);
  });

  test('is nothing for a filer with no quarterly report', () {
    final facts = {
      'facts': {
        'us-gaap': {
          'NetCashProvidedByUsedInOperatingActivities': {
            'units': {
              'USD': [
                _duration('10-K', 'FY', 2025, '2025-01-01', '2025-12-31', 1),
              ],
            },
          },
        },
      },
    };
    expect(CompanyFactsParser.parseTrailing(facts), isNull);
  });
}
