import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/valuation/valuation.dart';
import 'package:pickstock/repo/sec/company_facts_parser.dart';

const double _billion = 1000000000;

Map<String, dynamic> _duration(int year, num value) => {
  'accn': 'a-$year',
  'fy': year,
  'fp': 'FY',
  'form': '10-K',
  'start': '$year-01-01',
  'end': '$year-12-31',
  'val': value,
};

Map<String, dynamic> _instant(int year, num value) => {
  'accn': 'a-$year',
  'fy': year,
  'fp': 'FY',
  'form': '10-K',
  'end': '$year-12-31',
  'val': value,
};

/// A filing carrying the concepts under test, with whatever the caller leaves
/// out simply absent — which is how most filers report most of them.
Map<String, dynamic> _facts({
  num? stockPay,
  num? leaseNoncurrent,
  num? leaseCurrent,
  num? leaseTotal,
  num? borrowings,
  num? dividends,
  num? buybacks,
}) => {
  'facts': {
    'us-gaap': {
      'RevenueFromContractWithCustomerExcludingAssessedTax': {
        'units': {
          'USD': [
            _duration(2024, 300 * _billion),
            _duration(2025, 350 * _billion),
          ],
        },
      },
      'NetCashProvidedByUsedInOperatingActivities': {
        'units': {
          'USD': [
            _duration(2024, 90 * _billion),
            _duration(2025, 100 * _billion),
          ],
        },
      },
      'PaymentsToAcquirePropertyPlantAndEquipment': {
        'units': {
          'USD': [
            _duration(2024, 5 * _billion),
            _duration(2025, 10 * _billion),
          ],
        },
      },
      if (stockPay != null)
        'ShareBasedCompensation': {
          'units': {
            'USD': [_duration(2025, stockPay)],
          },
        },
      if (leaseNoncurrent != null)
        'OperatingLeaseLiabilityNoncurrent': {
          'units': {
            'USD': [_instant(2025, leaseNoncurrent)],
          },
        },
      if (leaseCurrent != null)
        'OperatingLeaseLiabilityCurrent': {
          'units': {
            'USD': [_instant(2025, leaseCurrent)],
          },
        },
      if (leaseTotal != null)
        'OperatingLeaseLiability': {
          'units': {
            'USD': [_instant(2025, leaseTotal)],
          },
        },
      if (borrowings != null)
        'LongTermDebtNoncurrent': {
          'units': {
            'USD': [_instant(2025, borrowings)],
          },
        },
      if (dividends != null)
        'PaymentsOfDividendsCommonStock': {
          'units': {
            'USD': [_duration(2025, dividends)],
          },
        },
      if (buybacks != null)
        'PaymentsForRepurchaseOfCommonStock': {
          'units': {
            'USD': [_duration(2025, buybacks)],
          },
        },
    },
  },
};

/// Alphabet's FY2025 shape: $73.3B of spare cash, $25.0B of it paid in shares.
Valuation _valuationOf(FiscalYearFigures latest) => Valuation(
  snapshot: FinancialSnapshot(
    company: const Company(
      ticker: 'GOOGL',
      cik: '0001652044',
      name: 'Alphabet Inc.',
      sharesOutstanding: 12 * _billion,
    ),
    years: [
      const FiscalYearFigures(fiscalYear: 2024, revenue: 300 * _billion),
      latest,
    ],
  ),
  pricePerShare: 200,
);

void main() {
  group('pay handed out in shares', () {
    test('is read off the filing', () {
      final years = CompanyFactsParser.parse(_facts(stockPay: 25 * _billion));
      expect(years.last.shareBasedCompensation, 25 * _billion);
      // $100B in, $10B of equipment out, $25B of it paid in shares.
      expect(years.last.freeCashFlow, 90 * _billion);
      expect(years.last.freeCashFlowAfterStockPay, 65 * _billion);
      expect(years.last.stockPayShareOfCashPercent, closeTo(27.8, 0.1));
    });

    test('comes off the cash the band is struck on', () {
      const withoutStockPay = FiscalYearFigures(
        fiscalYear: 2025,
        revenue: 350 * _billion,
        priorRevenue: 300 * _billion,
        netIncome: 60 * _billion,
        operatingCashFlow: 100 * _billion,
        capitalExpenditure: 10 * _billion,
      );
      const withStockPay = FiscalYearFigures(
        fiscalYear: 2025,
        revenue: 350 * _billion,
        priorRevenue: 300 * _billion,
        netIncome: 60 * _billion,
        operatingCashFlow: 100 * _billion,
        capitalExpenditure: 10 * _billion,
        shareBasedCompensation: 25 * _billion,
      );

      final before = _valuationOf(withoutStockPay);
      final after = _valuationOf(withStockPay);

      // A quarter of the spare cash was printed shares, so the band is a
      // quarter lower: the whole point of reading it.
      expect(before.freeCashFlowToShareholders, 90 * _billion);
      expect(after.freeCashFlowToShareholders, 65 * _billion);
      expect(after.fairValueLow, lessThan(before.fairValueLow!));
      expect(
        after.fairValueLow! / before.fairValueLow!,
        closeTo(65 / 90, 0.001),
      );
      expect(after.hasStockPay, isTrue);
      expect(before.hasStockPay, isFalse);
    });

    test('leaves a filer that reports none exactly as it was', () {
      final years = CompanyFactsParser.parse(_facts());
      expect(years.last.shareBasedCompensation, isNull);
      // Which is a quarter of them, and nothing about their band changes.
      expect(years.last.freeCashFlowAfterStockPay, years.last.freeCashFlow);
      expect(years.last.stockPayShareOfCashPercent, isNull);
    });
  });

  group('rent committed to', () {
    test('counts as debt, because that is what it is', () {
      // Starbucks' shape: $14.6B borrowed, $9.0B committed in rent.
      final years = CompanyFactsParser.parse(
        _facts(
          borrowings: 14.6 * _billion,
          leaseNoncurrent: 7.5 * _billion,
          leaseCurrent: 1.5 * _billion,
        ),
      );

      expect(years.last.operatingLeases, closeTo(9 * _billion, 1000));
      // The figure every downstream answer is struck against — net debt, the
      // balance-sheet check, the enterprise value, the debt-free filter.
      expect(years.last.totalDebt, closeTo(23.6 * _billion, 1000));
      expect(years.last.leaseShareOfDebtPercent, closeTo(38.1, 0.5));
    });

    test('is not counted twice where a filer reports the total as well', () {
      final years = CompanyFactsParser.parse(
        _facts(
          borrowings: 10 * _billion,
          leaseNoncurrent: 7 * _billion,
          leaseCurrent: 2 * _billion,
          leaseTotal: 9 * _billion,
        ),
      );

      // The halves win; the total is only read where neither half is filed.
      expect(years.last.operatingLeases, 9 * _billion);
      expect(years.last.totalDebt, 19 * _billion);
    });

    test('reads the total where that is all the filer gives', () {
      final years = CompanyFactsParser.parse(
        _facts(borrowings: 10 * _billion, leaseTotal: 4 * _billion),
      );
      expect(years.last.operatingLeases, 4 * _billion);
      expect(years.last.totalDebt, 14 * _billion);
    });

    test('a company with neither still owes an unknown, not nothing', () {
      final years = CompanyFactsParser.parse(_facts());
      // Which is the distinction the debt-free filter turns on.
      expect(years.last.totalDebt, isNull);
      expect(years.last.operatingLeases, isNull);
      expect(years.last.leaseShareOfDebtPercent, isNull);
    });
  });

  group('what came back to owners', () {
    test('adds the dividend to the buyback', () {
      final years = CompanyFactsParser.parse(
        _facts(dividends: 15 * _billion, buybacks: 60 * _billion),
      );

      expect(years.last.dividendsPaid, 15 * _billion);
      expect(years.last.buybacks, 60 * _billion);
      expect(years.last.capitalReturned, 75 * _billion);
      // Against $90B of spare cash.
      expect(years.last.capitalReturnedPercent, closeTo(83.3, 0.1));
    });

    test('counts one where a company does only one', () {
      final years = CompanyFactsParser.parse(_facts(dividends: 9 * _billion));
      expect(years.last.capitalReturned, 9 * _billion);
      expect(years.last.buybacks, isNull);
    });

    test('says nothing for a company that returns nothing', () {
      final years = CompanyFactsParser.parse(_facts());
      // Most of them: four filers in five pay no dividend at all.
      expect(years.last.capitalReturned, isNull);
      expect(years.last.capitalReturnedPercent, isNull);
    });
  });

  group('the tags filers actually use', () {
    test('follows a company that moved to a different dividend tag', () {
      // Accenture tagged `...CommonStock` until 2022 and `...Ordinary` after
      // it. Reading only the first left its $3.7B dividend as nothing.
      final facts = _facts();
      final tags =
          (facts['facts']! as Map<String, dynamic>)['us-gaap']!
              as Map<String, dynamic>;
      tags['PaymentsOfOrdinaryDividends'] = {
        'units': {
          'USD': [_duration(2025, 3.7 * _billion)],
        },
      };

      final years = CompanyFactsParser.parse(facts);
      expect(years.last.dividendsPaid, closeTo(3.7 * _billion, 1000));
    });

    test('never counts a dividend paid to somebody else as one paid to you', () {
      // `...MinorityInterest` is money leaving for the owners of the bits of
      // the group somebody else holds. Taken as a fallback it read Accenture's
      // dividend as the $0.00B its non-controlling interests were paid.
      final facts = _facts();
      final tags =
          (facts['facts']! as Map<String, dynamic>)['us-gaap']!
              as Map<String, dynamic>;
      tags['PaymentsOfDividendsMinorityInterest'] = {
        'units': {
          'USD': [_duration(2025, 0)],
        },
      };

      final years = CompanyFactsParser.parse(facts);
      expect(years.last.dividendsPaid, isNull);
      expect(years.last.capitalReturned, isNull);
    });
  });
}
