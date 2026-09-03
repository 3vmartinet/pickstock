import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/repo/sec/company_facts_parser.dart';

/// A single-year filing carrying whichever concepts a case names.
///
/// Figures are the real ones the filers below report, so a case that stops
/// holding says something about the directory rather than about the fixture.
Map<String, dynamic> _filing(Map<String, num> concepts, {num? assets}) {
  // A fiscal year exists in the payload only where operating cash flow is
  // reported for it, so every case carries one whether or not it is the
  // subject. Cases that are about it pass their own and override this.
  concepts = {'NetCashProvidedByUsedInOperatingActivities': 1e9, ...concepts};
  return {
    'entityName': 'Example Corp',
    'facts': {
      'us-gaap': {
        if (assets != null)
          'Assets': {
            'units': {
              'USD': [
                {
                  'accn': 'a',
                  'fy': 2025,
                  'fp': 'FY',
                  'form': '10-K',
                  'end': '2025-12-31',
                  'val': assets,
                },
              ],
            },
          },
        for (final MapEntry(key: tag, value: value) in concepts.entries)
          tag: {
            'units': {
              'USD': [
                {
                  'accn': 'a',
                  'fy': 2025,
                  'fp': 'FY',
                  'form': '10-K',
                  'start': '2025-01-01',
                  'end': '2025-12-31',
                  'val': value,
                },
              ],
            },
          },
      },
    },
  };
}

void main() {
  group('capital spending is read from the concept the filer chose', () {
    // Every figure below is that company's own latest-year filing. Between
    // them they were a third of the directory: operating cash flow on file
    // and no capital spending the parser could see, which left the question
    // the cash-generative filter asks unanswerable for them.
    const cases = {
      'Verizon': (
        'PaymentsToAcquireOtherProductiveAssets',
        17.01e9,
        37.14e9,
        20.13e9,
      ),
      'Eli Lilly': (
        'PaymentsToAcquireOtherPropertyPlantAndEquipment',
        7.84e9,
        16.81e9,
        8.97e9,
      ),
      'EOG Resources': (
        'PaymentsToAcquireOilAndGasPropertyAndEquipment',
        6.12e9,
        10.04e9,
        3.92e9,
      ),
      'Diamondback': (
        'PaymentsToExploreAndDevelopOilAndGasProperties',
        3.52e9,
        8.76e9,
        5.24e9,
      ),
    };

    cases.forEach((name, data) {
      final (tag, capex, ocf, fcf) = data;
      test(name, () {
        final years = CompanyFactsParser.parse(
          _filing({
            'NetCashProvidedByUsedInOperatingActivities': ocf,
            tag: capex,
          }),
        );
        expect(years.single.capitalExpenditure, capex);
        expect(years.single.freeCashFlow, closeTo(fcf, 0.02e9));
      });
    });

    test('the primary concept still wins where a filer reports both', () {
      final years = CompanyFactsParser.parse(
        _filing({
          'NetCashProvidedByUsedInOperatingActivities': 10e9,
          'PaymentsToAcquirePropertyPlantAndEquipment': 4e9,
          'PaymentsToAcquireOtherPropertyPlantAndEquipment': 1e9,
        }),
      );
      // Summed they would be 5e9. These are alternate names for one line, so
      // reading both would double-count what EOG reports under each.
      expect(years.single.capitalExpenditure, 4e9);
    });

    test('buying acreage is an acquisition, not the cost of running', () {
      // Diamondback reports $5.94B of property acquisitions beside the $3.52B
      // it spent drilling. Reading both shows a company that funds itself as
      // one that cannot.
      final years = CompanyFactsParser.parse(
        _filing({
          'NetCashProvidedByUsedInOperatingActivities': 8.76e9,
          'PaymentsToAcquireOilAndGasProperty': 5.94e9,
          'PaymentsToExploreAndDevelopOilAndGasProperties': 3.52e9,
        }),
      );
      expect(years.single.capitalExpenditure, 3.52e9);
      expect(years.single.freeCashFlow, closeTo(5.24e9, 0.02e9));
    });

    test('spending incurred but not yet paid is not a payment', () {
      // NextEra reports $7.64B of it and no cash capex concept at all. Read
      // as capex it would state a figure the company never paid out.
      final years = CompanyFactsParser.parse(
        _filing({
          'NetCashProvidedByUsedInOperatingActivities': 12.48e9,
          'CapitalExpendituresIncurredButNotYetPaid': 7.64e9,
        }),
      );
      expect(years.single.capitalExpenditure, isNull);
      expect(years.single.freeCashFlow, isNull);
    });
  });

  group('borrowings are found through what they cost', () {
    test('a mortgage REIT pays interest on its repurchase agreements', () {
      // ARMOUR Residential funds itself entirely through repo and tags no
      // debt concept at all, so it read as owing nothing.
      final years = CompanyFactsParser.parse(
        _filing({
          'InterestExpenseSecuritiesSoldUnderAgreementsToRepurchase': 642e6,
        }, assets: 21.0e9),
      );
      expect(years.single.interestExpense, 642e6);
      expect(years.single.isDebtFree, isFalse);
    });

    test('cash interest counts where it is the price of borrowings', () {
      // PACCAR: $692.8M paid against $44.3B of assets, and neither its
      // captive finance arm's debt nor an accrual interest concept on file.
      final years = CompanyFactsParser.parse(
        _filing({'InterestPaid': 692.8e6}, assets: 44.3e9),
      );
      expect(years.single.interestExpense, 692.8e6);
      expect(years.single.isDebtFree, isFalse);
    });

    test('and does not where it is the fee on a facility nobody drew on', () {
      // Lululemon: $1.0M against $8.5B, which is a revolver commitment fee.
      final years = CompanyFactsParser.parse(
        _filing({'InterestPaidNet': 1.0e6}, assets: 8.5e9),
      );
      expect(years.single.interestExpense, isNull);
      expect(years.single.isDebtFree, isTrue);
    });

    test('the line between them sits where the filings put it', () {
      // American Eagle's fees are the largest that are not borrowings, at
      // 0.18% of assets; Green Dot's borrowings are the smallest that are,
      // at 0.21%. Anything between would be guesswork, so the threshold is
      // read off that gap rather than chosen.
      final fees = CompanyFactsParser.parse(
        _filing({'InterestPaid': 7.3e6}, assets: 4.0e9),
      );
      expect(fees.single.isDebtFree, isTrue);

      final borrowings = CompanyFactsParser.parse(
        _filing({'InterestPaidNet': 12.4e6}, assets: 6.0e9),
      );
      expect(borrowings.single.isDebtFree, isFalse);
    });

    test('an accrual concept is believed at any size', () {
      // Only cash interest is judged on its size: a filer that names the
      // expense outright is taken at its word, however small.
      final years = CompanyFactsParser.parse(
        _filing({'InterestExpense': 1.0e6}, assets: 8.5e9),
      );
      expect(years.single.interestExpense, 1.0e6);
      expect(years.single.isDebtFree, isFalse);
    });

    test('cash interest is a last resort, not a second opinion', () {
      final years = CompanyFactsParser.parse(
        _filing({
          'InterestExpense': 500e6,
          'InterestPaidNet': 480e6,
        }, assets: 40e9),
      );
      expect(years.single.interestExpense, 500e6);
    });
  });
}
