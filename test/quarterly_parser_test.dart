import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/data/snapshot/fiscal_quarter_figures.dart';
import 'package:pickstock/repo/sec/company_facts_parser.dart';

Map<String, dynamic> _fact({
  required String accn,
  required int fy,
  required String fp,
  String? start,
  required String end,
  required num val,
  String form = '10-Q',
}) => {
  'accn': accn,
  'fy': fy,
  'fp': fp,
  'form': form,
  'start': ?start,
  'end': end,
  'val': val,
};

/// A September-year-end filer: three 10-Qs and a 10-K, as EDGAR holds them.
/// The 10-K carries only the full year, which is why Q4 has to be derived.
final Map<String, dynamic> _facts = {
  'entityName': 'Example Corp',
  'facts': {
    'us-gaap': {
      'Revenues': {
        'units': {
          'USD': [
            _fact(
              accn: 'q1',
              fy: 2025,
              fp: 'Q1',
              start: '2024-10-01',
              end: '2024-12-31',
              val: 100,
            ),
            _fact(
              accn: 'q2',
              fy: 2025,
              fp: 'Q2',
              start: '2025-01-01',
              end: '2025-03-31',
              val: 110,
            ),
            // A 10-Q also restates the year-to-date figure; not a quarter.
            _fact(
              accn: 'q2',
              fy: 2025,
              fp: 'Q2',
              start: '2024-10-01',
              end: '2025-03-31',
              val: 210,
            ),
            _fact(
              accn: 'q3',
              fy: 2025,
              fp: 'Q3',
              start: '2025-04-01',
              end: '2025-06-30',
              val: 120,
            ),
            _fact(
              accn: 'k25',
              fy: 2025,
              fp: 'FY',
              start: '2024-10-01',
              end: '2025-09-30',
              val: 500,
              form: '10-K',
            ),
          ],
        },
      },
      'NetCashProvidedByUsedInOperatingActivities': {
        'units': {
          'USD': [
            _fact(
              accn: 'k25',
              fy: 2025,
              fp: 'FY',
              start: '2024-10-01',
              end: '2025-09-30',
              val: 50,
              form: '10-K',
            ),
          ],
        },
      },
      'CashAndCashEquivalentsAtCarryingValue': {
        'units': {
          'USD': [
            _fact(accn: 'q1', fy: 2025, fp: 'Q1', end: '2024-12-31', val: 5),
            _fact(accn: 'q2', fy: 2025, fp: 'Q2', end: '2025-03-31', val: 6),
            _fact(accn: 'q3', fy: 2025, fp: 'Q3', end: '2025-06-30', val: 7),
            _fact(
              accn: 'k25',
              fy: 2025,
              fp: 'FY',
              end: '2025-09-30',
              val: 8,
              form: '10-K',
            ),
          ],
        },
      },
    },
  },
};

void main() {
  List<FiscalQuarterFigures> parsed() =>
      CompanyFactsParser.parseQuarters(_facts);

  test('reads each quarter from the filing that reported it', () {
    expect(parsed().map((q) => (q.fiscalYear, q.quarter)), [
      (2025, 1),
      (2025, 2),
      (2025, 3),
      (2025, 4),
    ]);
    expect(parsed().take(3).map((q) => q.revenue), [100, 110, 120]);
  });

  test('ignores year-to-date durations filed alongside the quarter', () {
    // Q2 is 110 for the quarter; 210 is the six months to date.
    expect(parsed().map((q) => q.revenue), isNot(contains(210)));
  });

  test('derives the fourth quarter, which is rarely filed', () {
    // 500 for the year less 100 + 110 + 120 already reported.
    final fourth = parsed().firstWhere((q) => q.quarter == 4);
    expect(fourth.revenue, 170);
  });

  test('takes the fourth quarter balance sheet as filed', () {
    // A year-end instant is the closing position; no arithmetic needed.
    expect(parsed().map((q) => q.cash), [5, 6, 7, 8]);
  });

  test('leaves a flow line null when the quarters to subtract are missing', () {
    // Operating cash flow is filed annually only here.
    expect(parsed().every((q) => q.operatingCashFlow == null), isTrue);
  });

  test('labels a quarter the way the filer numbers it', () {
    expect(parsed().last.quarter, 4);
    expect(parsed().last.fiscalYear, 2025);
  });

  test('measures growth against the same quarter a year earlier', () {
    const previous = FiscalQuarterFigures(
      fiscalYear: 2024,
      quarter: 1,
      revenue: 80,
    );
    const current = FiscalQuarterFigures(
      fiscalYear: 2025,
      quarter: 1,
      revenue: 100,
      priorRevenue: 80,
    );
    expect(previous.revenueGrowthPercent, isNull);
    expect(current.revenueGrowthPercent, closeTo(25, 0.001));
  });
}
