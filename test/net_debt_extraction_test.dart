import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/repo/sec/company_facts_parser.dart';

/// Builds a company facts payload with one 10-K's worth of instant facts.
///
/// Balance-sheet concepts are instants, so each tag carries a single fact at
/// the year end — which is all the net-debt arithmetic reads.
Map<String, dynamic> _facts(Map<String, double> tags) => jsonDecode(
  jsonEncode({
    'cik': 1,
    'entityName': 'Test Corp',
    'facts': {
      'us-gaap': {
        for (final tag in tags.entries)
          tag.key: {
            'units': {
              'USD': [
                {
                  'end': '2025-12-31',
                  'val': tag.value,
                  'fy': 2025,
                  'fp': 'FY',
                  'form': '10-K',
                  'accn': '0000000000-25-000001',
                },
              ],
            },
          },
        // The parser keys its years off operating cash flow, so the fixture
        // files a year's worth of it for the instants to hang from.
        'NetCashProvidedByUsedInOperatingActivities': {
          'units': {
            'USD': [
              {
                'start': '2025-01-01',
                'end': '2025-12-31',
                'val': 1000.0,
                'fy': 2025,
                'fp': 'FY',
                'form': '10-K',
                'accn': '0000000000-25-000001',
              },
            ],
          },
        },
      },
    },
  }),
) as Map<String, dynamic>;

void main() {
  group('liquid holdings', () {
    test('counts short-term investments as cash', () {
      // Microsoft's FY2026 shape: most of the money is in treasuries, not in
      // the cash line. Counting only cash made it a net borrower.
      final years = CompanyFactsParser.parse(
        _facts({
          'CashAndCashEquivalentsAtCarryingValue': 20.9e9,
          'ShortTermInvestments': 55.9e9,
          'LongTermDebtNoncurrent': 31.1e9,
          'LongTermDebtCurrent': 9.2e9,
        }),
      );

      final year = years.single;
      expect(year.cash, 76.8e9);
      expect(year.totalDebt, closeTo(40.3e9, 1));
      expect(year.netDebt, closeTo(-36.5e9, 1));
      expect(year.holdsNetCash, isTrue);
    });

    test('takes one short-term investment tag, not every alias', () {
      // A filer using two names for the same line must not have it counted
      // twice; these are alternates, unlike the debt components.
      final years = CompanyFactsParser.parse(
        _facts({
          'CashAndCashEquivalentsAtCarryingValue': 10e9,
          'ShortTermInvestments': 40e9,
          'AvailableForSaleSecuritiesCurrent': 40e9,
        }),
      );

      expect(years.single.cash, 50e9);
    });

    test('leaves cash unstated where nothing is filed', () {
      final years = CompanyFactsParser.parse(
        _facts({'LongTermDebtNoncurrent': 5e9}),
      );

      expect(years.single.cash, isNull);
      expect(years.single.netDebt, isNull);
    });
  });

  group('total borrowings', () {
    test('reads debt folded in with capital leases', () {
      // Coca-Cola's shape: nothing under the plain concepts, so the company
      // looked as though it owed only its commercial paper.
      final years = CompanyFactsParser.parse(
        _facts({
          'CashAndCashEquivalentsAtCarryingValue': 10.3e9,
          'OtherShortTermInvestments': 3.6e9,
          'LongTermDebtAndCapitalLeaseObligations': 42.1e9,
          'LongTermDebtAndCapitalLeaseObligationsCurrent': 1.8e9,
          'CommercialPaper': 1.5e9,
        }),
      );

      final year = years.single;
      expect(year.totalDebt, closeTo(45.4e9, 1));
      expect(year.cash, closeTo(13.9e9, 1));
      expect(year.holdsNetCash, isFalse);
    });

    test('reads debt that is entirely convertible notes', () {
      // Super Micro's shape: no plain long-term debt concept anywhere, so it
      // read as owing nothing while carrying $4.6B of convertible notes.
      final years = CompanyFactsParser.parse(
        _facts({
          'CashAndCashEquivalentsAtCarryingValue': 7.5e9,
          'ConvertibleLongTermNotesPayable': 4.66e9,
        }),
      );

      expect(years.single.totalDebt, 4.66e9);
      expect(years.single.holdsNetCash, isTrue);
    });

    test('does not add convertible notes to debt that already counts them', () {
      // A filer reporting both has the notes inside its long-term debt
      // already; reading them again would double the borrowings.
      final years = CompanyFactsParser.parse(
        _facts({
          'LongTermDebtNoncurrent': 30e9,
          'ConvertibleDebtNoncurrent': 12e9,
          'LongTermDebtCurrent': 5e9,
        }),
      );

      expect(years.single.totalDebt, 35e9);
    });

    test('prefers the plain concept where a filer reports both', () {
      final years = CompanyFactsParser.parse(
        _facts({
          'LongTermDebtNoncurrent': 30e9,
          'LongTermDebtAndCapitalLeaseObligations': 31e9,
          'LongTermDebtCurrent': 5e9,
        }),
      );

      // 30 + 5, not 61 + 5: the two long-term tags are alternate names.
      expect(years.single.totalDebt, 35e9);
    });

    test('still sums the genuinely separate borrowings', () {
      final years = CompanyFactsParser.parse(
        _facts({
          'LongTermDebtNoncurrent': 10e9,
          'LongTermDebtCurrent': 2e9,
          'CommercialPaper': 1e9,
          'ShortTermBorrowings': 3e9,
        }),
      );

      expect(years.single.totalDebt, 16e9);
    });
  });
}
