import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/report_tab.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/sec/institutional_repo.dart';
import 'package:pickstock/ui/snapshot/widgets/holdings/holders_table.dart';
import 'package:pickstock/ui/snapshot/widgets/holdings/institutional_ownership_chart.dart';
import 'package:pickstock/ui/snapshot/widgets/holdings/ownership_composition_card.dart';
import 'package:pickstock/ui/snapshot/widgets/holdings/ownership_metric_grid.dart';

import 'support/test_directory.dart';

const Size _laptopSize = Size(1440, 900);

void main() {
  late AppDatabase database;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    database = await registerTestDependencies(withFinancials: true);
  });

  tearDown(() async {
    await database.close();
    await GetIt.I.reset();
  });

  Future<void> openApple(WidgetTester tester, {Size size = _laptopSize}) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apple Inc.'));
    await tester.pumpAndSettle();
  }

  test('institutional repo builds authentic shareholding for Apple', () async {
    const repo = MockInstitutionalRepo();
    const apple = Company(
      ticker: 'AAPL',
      cik: '0000320193',
      name: 'Apple Inc.',
      sic: 3571,
      sharesOutstanding: 14840390000,
    );

    final holdings = await repo.fetchShareholding(apple, currentPrice: 228.0);
    expect(holdings, isNotNull);
    expect(holdings!.institutionalOwnershipPercent, closeTo(61.4, 0.1));
    expect(holdings.totalInstitutionsCount, 5942);
    expect(holdings.topHolders.length, 10);
    expect(holdings.topHolders.first.name, 'The Vanguard Group, Inc.');
    expect(holdings.topHolders.first.percentOfClass, closeTo(8.95, 0.05));
    expect(holdings.topHolders[1].name, 'BlackRock, Inc.');
  });

  testWidgets('holdings tab displays institutional metrics and top holders', (
    tester,
  ) async {
    await openApple(tester);
    await openReportTab(tester, ReportTab.holdings);

    // Headline metric cards
    expect(find.byType(OwnershipMetricGrid), findsOneWidget);
    expect(find.text('Institutional ownership'), findsWidgets);
    expect(find.text('Top 10 concentration'), findsOneWidget);
    expect(find.text('Net quarterly flow'), findsOneWidget);

    // Ownership structure breakdown
    expect(find.byType(OwnershipCompositionCard), findsOneWidget);
    expect(find.text('Ownership structure'), findsOneWidget);
    expect(find.text('Passive index'), findsOneWidget);

    // Top holders table
    expect(find.byType(HoldingsTable), findsOneWidget);
    expect(find.text('Top institutional holders'), findsOneWidget);
    expect(find.text('The Vanguard Group, Inc.'), findsWidgets);
    expect(find.text('BlackRock, Inc.'), findsWidgets);
    expect(find.text('Berkshire Hathaway Inc'), findsWidgets);
  });

  testWidgets('sorts holders by stake or flow', (tester) async {
    await openApple(tester);
    await openReportTab(tester, ReportTab.holdings);

    final sortBtn = find.text('Sort: Stake');
    await tester.scrollUntilVisible(
      sortBtn,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(sortBtn, findsOneWidget);
    await tester.tap(sortBtn);
    await tester.pumpAndSettle();

    expect(find.text('Sort: Flow'), findsOneWidget);
  });

  testWidgets('displays institutional ownership trend graph over time', (
    tester,
  ) async {
    await openApple(tester);
    await openReportTab(tester, ReportTab.holdings);

    // Trend graph card is present
    expect(find.byType(InstitutionalOwnershipChart), findsOneWidget);
    expect(find.text('Institutional ownership over time'), findsOneWidget);
    expect(find.text('Q3 2024'), findsWidgets);
  });
}

