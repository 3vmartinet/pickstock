import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/sec/company_facts_parser.dart';
import 'package:pickstock/repo/sec/sec_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

const double _billion = 1000000000;

/// Wide enough for the list and a report side by side.
const Size _wideSize = Size(1600, 1400);

/// Accenture's order book as EDGAR carries it: an instant, dated to the year
/// end, with no start — which is what tells it apart from a year's revenue.
Map<String, dynamic> _factsWithBook({
  required num book2024,
  required num book2025,
  required num revenue2024,
  required num revenue2025,
}) => {
  'facts': {
    'us-gaap': {
      'RevenueFromContractWithCustomerExcludingAssessedTax': {
        'units': {
          'USD': [_duration(2024, revenue2024), _duration(2025, revenue2025)],
        },
      },
      'NetCashProvidedByUsedInOperatingActivities': {
        'units': {
          'USD': [_duration(2024, 9000), _duration(2025, 10000)],
        },
      },
      'RevenueRemainingPerformanceObligation': {
        'units': {
          'USD': [_instant(2024, book2024), _instant(2025, book2025)],
        },
      },
    },
  },
};

Map<String, dynamic> _duration(int year, num value) => {
  'accn': 'a-$year',
  'fy': year,
  'fp': 'FY',
  'form': '10-K',
  'start': '${year - 1}-09-01',
  'end': '$year-08-31',
  'val': value,
};

Map<String, dynamic> _instant(int year, num value) => {
  'accn': 'a-$year',
  'fy': year,
  'fp': 'FY',
  'form': '10-K',
  'end': '$year-08-31',
  'val': value,
};

/// A filer that reports a book, for the report to render.
class BookkeepingSecRepo implements SecRepo {
  const BookkeepingSecRepo({
    this.book = 34 * _billion,
    this.priorBook = 30 * _billion,
    this.revenue = 69 * _billion,
    this.priorRevenue = 65 * _billion,
  });

  final double book;
  final double priorBook;
  final double revenue;
  final double priorRevenue;

  @override
  Future<FinancialSnapshot> fetchSnapshot(String ticker) async =>
      FinancialSnapshot(
        company: const Company(
          ticker: 'AAPL',
          cik: '0000320193',
          name: 'Apple Inc.',
          sharesOutstanding: 15 * _billion,
        ),
        years: [
          FiscalYearFigures(
            fiscalYear: 2024,
            revenue: priorRevenue,
            backlog: priorBook,
          ),
          FiscalYearFigures(
            fiscalYear: 2025,
            revenue: revenue,
            priorRevenue: priorRevenue,
            netIncome: 7 * _billion,
            operatingCashFlow: 10 * _billion,
            capitalExpenditure: 1 * _billion,
            backlog: book,
            priorBacklog: priorBook,
          ),
        ],
      );
}

void main() {
  group('reading the book out of a filing', () {
    test('reads it as an instant at the year end', () {
      final years = CompanyFactsParser.parse(
        _factsWithBook(
          book2024: 30 * _billion,
          book2025: 34 * _billion,
          revenue2024: 65 * _billion,
          revenue2025: 69 * _billion,
        ),
      );

      // Accenture's own figures: $30B of contracted revenue at FY2024, $34B a
      // year later.
      expect(years.last.backlog, 34 * _billion);
      expect(years.last.priorBacklog, 30 * _billion);
      expect(years.first.backlog, 30 * _billion);
    });

    test('says how much of the future is already sold', () {
      final years = CompanyFactsParser.parse(
        _factsWithBook(
          book2024: 30 * _billion,
          book2025: 34 * _billion,
          revenue2024: 65 * _billion,
          revenue2025: 68 * _billion,
        ),
      );

      // Half a year of revenue under contract, and a book growing faster than
      // the revenue underneath it.
      expect(years.last.backlogYears, closeTo(0.5, 0.01));
      expect(years.last.backlogGrowthPercent, closeTo(13.3, 0.1));
      expect(years.last.isBookShrinkingUnderRevenue, isFalse);
    });

    test('spots a book shrinking under revenue that is not', () {
      final years = CompanyFactsParser.parse(
        _factsWithBook(
          // Sold more slowly than delivered: the earliest warning a filing
          // gives, and invisible in every other figure on the report.
          book2024: 40 * _billion,
          book2025: 34 * _billion,
          revenue2024: 65 * _billion,
          revenue2025: 69 * _billion,
        ),
      );

      expect(years.last.backlogGrowthPercent, lessThan(0));
      expect(years.last.revenueGrowthPercent, greaterThan(0));
      expect(years.last.isBookShrinkingUnderRevenue, isTrue);
    });

    test('leaves it unstated for a filer that reports none', () {
      final facts = _factsWithBook(
        book2024: 30 * _billion,
        book2025: 34 * _billion,
        revenue2024: 65 * _billion,
        revenue2025: 69 * _billion,
      );
      (facts['facts']! as Map<String, dynamic>)['us-gaap']!.remove(
        'RevenueRemainingPerformanceObligation',
      );

      // Which is the great majority of the directory, and nothing about the
      // rest of the report changes for them.
      final years = CompanyFactsParser.parse(facts);
      expect(years.last.backlog, isNull);
      expect(years.last.backlogYears, isNull);
      expect(years.last.isBookShrinkingUnderRevenue, isNull);
    });
  });

  group('showing it', () {
    late AppDatabase database;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      database = await registerTestDependencies(withFinancials: true);
    });

    tearDown(() async {
      await database.close();
      await GetIt.I.reset();
    });

    Future<void> openApple(WidgetTester tester) async {
      tester.view
        ..physicalSize = _wideSize
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const PickStockApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apple Inc.').first);
      await tester.pumpAndSettle();
    }

    testWidgets('shows nothing at all for a filer with no book', (
      tester,
    ) async {
      await openApple(tester);

      // A block that appears, rather than a column of dashes down the history
      // for the nineteen filers in twenty that report none.
      expect(find.text('Order book'), findsNothing);
    });

    testWidgets('states the book, its reach and its direction', (tester) async {
      GetIt.I.unregister<SecRepo>();
      GetIt.I.registerSingleton<SecRepo>(const BookkeepingSecRepo());

      await openApple(tester);

      expect(find.text('Order book'), findsOneWidget);
      expect(find.text('0.5 years'), findsOneWidget);
      expect(find.text('+13.3%'), findsOneWidget);
      // No warning: the book grew.
      expect(find.textContaining('shrank while revenue'), findsNothing);
    });

    testWidgets('warns when the book falls under revenue that holds', (
      tester,
    ) async {
      GetIt.I.unregister<SecRepo>();
      GetIt.I.registerSingleton<SecRepo>(
        const BookkeepingSecRepo(priorBook: 40 * _billion),
      );

      await openApple(tester);

      // The whole reason the book is worth reading, said out loud.
      expect(find.textContaining('shrank while revenue'), findsOneWidget);
    });
  });
}
