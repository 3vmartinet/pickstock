import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/repo/sec/company_facts_parser.dart';

/// One us-gaap fact as EDGAR shapes it.
Map<String, dynamic> _fact({
  required String accn,
  required int fy,
  String? start,
  required String end,
  required num val,
  String form = '10-K',
}) => {
  'accn': accn,
  'fy': fy,
  'fp': 'FY',
  'form': form,
  'start': ?start,
  'end': end,
  'val': val,
};

/// One calendar-year annual fact, for the cases that only need a single year.
Map<String, dynamic> _year(int year, num value) => _fact(
  accn: 'a-$year',
  fy: year,
  start: '$year-01-01',
  end: '$year-12-31',
  val: value,
);

/// Two filings of a September-year-end company. Each 10-K restates the two
/// years before it, and the FY2024 filing also carries a quarterly figure —
/// the shape that used to be read as an annual one.
final Map<String, dynamic> _companyFacts = {
  'entityName': 'Example Corp',
  'facts': {
    'us-gaap': {
      'RevenueFromContractWithCustomerExcludingAssessedTax': {
        'units': {
          'USD': [
            _fact(
              accn: 'a-2024',
              fy: 2024,
              start: '2021-10-01',
              end: '2022-09-30',
              val: 100,
            ),
            _fact(
              accn: 'a-2024',
              fy: 2024,
              start: '2022-10-01',
              end: '2023-09-30',
              val: 200,
            ),
            _fact(
              accn: 'a-2024',
              fy: 2024,
              start: '2023-10-01',
              end: '2024-09-30',
              val: 300,
            ),
            // A quarter inside the same 10-K.
            _fact(
              accn: 'a-2024',
              fy: 2024,
              start: '2024-07-01',
              end: '2024-09-30',
              val: 77,
            ),
            _fact(
              accn: 'a-2025',
              fy: 2025,
              start: '2022-10-01',
              end: '2023-09-30',
              val: 200,
            ),
            // FY2024 restated by the later filing.
            _fact(
              accn: 'a-2025',
              fy: 2025,
              start: '2023-10-01',
              end: '2024-09-30',
              val: 305,
            ),
            _fact(
              accn: 'a-2025',
              fy: 2025,
              start: '2024-10-01',
              end: '2025-09-30',
              val: 400,
            ),
          ],
        },
      },
      'NetCashProvidedByUsedInOperatingActivities': {
        'units': {
          'USD': [
            _fact(
              accn: 'a-2024',
              fy: 2024,
              start: '2022-10-01',
              end: '2023-09-30',
              val: 20,
            ),
            _fact(
              accn: 'a-2024',
              fy: 2024,
              start: '2023-10-01',
              end: '2024-09-30',
              val: 30,
            ),
            _fact(
              accn: 'a-2025',
              fy: 2025,
              start: '2024-10-01',
              end: '2025-09-30',
              val: 40,
            ),
          ],
        },
      },
      'CashAndCashEquivalentsAtCarryingValue': {
        'units': {
          'USD': [
            // Balance-sheet facts: two instants per filing, no start date.
            _fact(accn: 'a-2024', fy: 2024, end: '2023-09-30', val: 5),
            _fact(accn: 'a-2024', fy: 2024, end: '2024-09-30', val: 6),
            _fact(accn: 'a-2025', fy: 2025, end: '2025-09-30', val: 7),
          ],
        },
      },
    },
  },
};

void main() {
  List<FiscalYearFigures> parsed() => CompanyFactsParser.parse(_companyFacts);

  test('labels each year the way the filing company does', () {
    // Comparatives inside a filing belong to earlier years, not the filing's.
    expect(parsed().map((y) => y.fiscalYear), [2023, 2024, 2025]);
    expect(parsed().map((y) => y.revenue), [200, 305, 400]);
  });

  test('ignores quarterly facts filed inside a 10-K', () {
    // 77 covers one quarter of FY2024; reading it as the year understates it.
    expect(parsed().map((y) => y.revenue), isNot(contains(77)));
  });

  test('lets a later filing restate an earlier year', () {
    // FY2024 was 300 as first filed and 305 once restated.
    expect(parsed().firstWhere((y) => y.fiscalYear == 2024).revenue, 305);
  });

  test('attributes balance-sheet instants to their own year', () {
    expect(parsed().map((y) => y.cash), [5, 6, 7]);
  });

  test('carries the prior year forward for growth', () {
    expect(parsed().firstWhere((y) => y.fiscalYear == 2025).priorRevenue, 305);
  });

  test('reads the registrant name from the payload', () {
    expect(CompanyFactsParser.entityName(_companyFacts), 'Example Corp');
  });

  test('reads the whole group\'s profit beside the parent\'s share of it', () {
    // MarketWise's FY2025 shape: the parent earned $5.62M of a group $64.0M,
    // the rest belonging to Class B unitholders outside the listed company.
    final facts = {
      'facts': {
        'us-gaap': {
          'RevenueFromContractWithCustomerExcludingAssessedTax': {
            'units': {
              'USD': [_year(2024, 408701000), _year(2025, 328122000)],
            },
          },
          'NetCashProvidedByUsedInOperatingActivities': {
            'units': {
              'USD': [_year(2024, -22150000), _year(2025, 45958000)],
            },
          },
          'NetIncomeLoss': {
            'units': {
              'USD': [_year(2024, 7059000), _year(2025, 5620000)],
            },
          },
          'ProfitLoss': {
            'units': {
              'USD': [_year(2024, 93108000), _year(2025, 64041000)],
            },
          },
        },
      },
    };

    final years = CompanyFactsParser.parse(facts);
    expect(years.last.netIncome, 5620000);
    expect(years.last.profitLoss, 64041000);
    // Which is what says how much of the group the listed shares own.
    expect(years.last.parentStake, closeTo(0.0878, 0.0005));
    expect(years.last.hasOutsideOwners, isTrue);
  });

  test('reads no split where the filer states none', () {
    final facts = {
      'facts': {
        'us-gaap': {
          'RevenueFromContractWithCustomerExcludingAssessedTax': {
            'units': {
              'USD': [_year(2024, 408701000), _year(2025, 328122000)],
            },
          },
          'NetCashProvidedByUsedInOperatingActivities': {
            'units': {
              'USD': [_year(2024, -22150000), _year(2025, 45958000)],
            },
          },
          'NetIncomeLoss': {
            'units': {
              'USD': [_year(2024, 7059000), _year(2025, 5620000)],
            },
          },
        },
      },
    };

    final years = CompanyFactsParser.parse(facts);
    expect(years.last.profitLoss, isNull);
    // The whole of it belongs to the listed shares, which is the usual case.
    expect(years.last.parentStake, 1);
  });
}
