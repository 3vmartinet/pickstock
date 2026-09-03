import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/valuation/valuation.dart';
import 'package:pickstock/repo/sec/company_facts_parser.dart';

Map<String, dynamic> _shareFact(String end, num val) => {
  'accn': 'a',
  'fy': int.parse(end.substring(0, 4)),
  'fp': 'FY',
  'form': '10-K',
  'end': end,
  'val': val,
};

Map<String, dynamic> _durationFact(String start, String end, num val) => {
  'accn': 'a',
  'fy': int.parse(end.substring(0, 4)),
  'fp': 'FY',
  'form': '10-K',
  'start': start,
  'end': end,
  'val': val,
};

/// A payload with a cover-page share series, a balance sheet dating it, and
/// the diluted average that stands in when the cover count cannot be used.
Map<String, dynamic> _filing({
  List<(String end, num val)> cover = const [],
  List<(String end, num val)> balanceSheetCover = const [],
  String assetsEnd = '2025-12-31',
  num? diluted,
  num? dilutedAdjustment,
}) => {
  'entityName': 'Example Corp',
  'facts': {
    'dei': {
      if (cover.isNotEmpty)
        'EntityCommonStockSharesOutstanding': {
          'units': {
            'shares': [for (final (end, val) in cover) _shareFact(end, val)],
          },
        },
    },
    'us-gaap': {
      'Assets': {
        'units': {
          'USD': [_shareFact(assetsEnd, 1000)],
        },
      },
      'NetCashProvidedByUsedInOperatingActivities': {
        'units': {
          'USD': [
            _durationFact(
              '${int.parse(assetsEnd.substring(0, 4)) - 1}-12-31',
              assetsEnd,
              500,
            ),
          ],
        },
      },
      if (balanceSheetCover.isNotEmpty)
        'CommonStockSharesOutstanding': {
          'units': {
            'shares': [
              for (final (end, val) in balanceSheetCover) _shareFact(end, val),
            ],
          },
        },
      if (diluted != null)
        'WeightedAverageNumberOfDilutedSharesOutstanding': {
          'units': {
            'shares': [
              _durationFact(
                '${int.parse(assetsEnd.substring(0, 4)) - 1}-12-31',
                assetsEnd,
                diluted,
              ),
            ],
          },
        },
      if (dilutedAdjustment != null)
        'WeightedAverageNumberOfDilutedSharesOutstandingAdjustment': {
          'units': {
            'shares': [
              _durationFact(
                '${int.parse(assetsEnd.substring(0, 4)) - 1}-12-31',
                assetsEnd,
                dilutedAdjustment,
              ),
            ],
          },
        },
    },
  },
};

void main() {
  group('the cover-page share count has to be current', () {
    test('a count filed with the newest balance sheet is used', () {
      // The cover is dated the day the filing goes in, so it runs ahead of
      // the period it reports on.
      final shares = CompanyFactsParser.latestSharesOutstanding(
        _filing(cover: const [('2026-02-06', 14.59e9)]),
      );
      expect(shares, 14.59e9);
    });

    test('a series that stopped years ago is not', () {
      // Mastercard's shape: it stopped tagging the concept in 2010, and what
      // it said then was 122.5M shares — before a ten-for-one split and
      // fifteen years of buybacks, against a real price.
      final shares = CompanyFactsParser.latestSharesOutstanding(
        _filing(
          cover: const [('2010-02-11', 110.4e6), ('2010-10-27', 122.5e6)],
        ),
      );
      expect(shares, isNull);
    });

    test('a count a quarter behind the annual report is still current', () {
      // Measured against the annual report, not the newest filing of any
      // kind: a count filed with the 10-K is a quarter old by the time the
      // next 10-Q lands, and a quarter-old count of the shares that exist
      // beats a twelve-month average of them.
      final shares = CompanyFactsParser.latestSharesOutstanding(
        _filing(cover: const [('2025-12-31', 140e6)], assetsEnd: '2025-12-31'),
      );
      expect(shares, 140e6);
    });

    test('and the balance-sheet count is tried before giving up', () {
      final shares = CompanyFactsParser.latestSharesOutstanding(
        _filing(
          cover: const [('2010-10-27', 122.5e6)],
          balanceSheetCover: const [('2025-12-31', 888e6)],
        ),
      );
      expect(shares, 888e6);
    });

    test('a payload with no balance sheet dates nothing, so it is taken as '
        'filed', () {
      final facts = _filing(cover: const [('2010-10-27', 122.5e6)]);
      (facts['facts'] as Map<String, dynamic>).remove('us-gaap');
      expect(CompanyFactsParser.latestSharesOutstanding(facts), 122.5e6);
    });
  });

  group('what the valuation divides by', () {
    Valuation valuationFor(Map<String, dynamic> facts) {
      final years = CompanyFactsParser.parse(facts);
      return Valuation(
        snapshot: FinancialSnapshot(
          company: Company(
            ticker: 'EG',
            cik: '1',
            name: 'Example Corp',
            sharesOutstanding: CompanyFactsParser.latestSharesOutstanding(
              facts,
            ),
          ),
          years: years,
        ),
        pricePerShare: 10,
      );
    }

    test('falls through to the diluted average where no cover count holds', () {
      // The figure every filer restates every quarter, so a stale cover count
      // costs a little precision rather than an order of magnitude.
      final valuation = valuationFor(
        _filing(cover: const [('2010-10-27', 122.5e6)], diluted: 906e6),
      );
      expect(valuation.sharesOutstanding, 906e6);
    });

    test('and says so, rather than passing it off as the count', () {
      final current = valuationFor(
        _filing(cover: const [('2026-02-06', 888e6)], diluted: 906e6),
      );
      expect(current.countIsCurrent, isTrue);

      final standIn = valuationFor(
        _filing(cover: const [('2010-10-27', 122.5e6)], diluted: 906e6),
      );
      expect(standIn.countIsCurrent, isFalse);
    });

    test('a filer that stopped is told apart from one that never filed', () {
      // Mastercard stopped in 2010; Lennar tags its counts per share class,
      // which the bulk archive does not carry, so it has never filed one this
      // parser can see. Both fall back to the average, and only the first has
      // a year to name for it.
      final stopped = _filing(cover: const [('2010-10-27', 122.5e6)]);
      expect(CompanyFactsParser.lastFiledShareCount(stopped)?.year, 2010);

      final never = _filing();
      expect(CompanyFactsParser.lastFiledShareCount(never), isNull);
    });

    test('the dilution adjustment is not a share count', () {
      // Mastercard reports 1M of it against 888M shares. Read as a count it
      // would state a company a thousandth of its size.
      final valuation = valuationFor(_filing(dilutedAdjustment: 1e6));
      expect(valuation.sharesOutstanding, isNull);
    });
  });
}
