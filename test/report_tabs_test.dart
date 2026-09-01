import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/snapshot/report_tab.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/snapshot/widgets/company_header.dart';
import 'package:pickstock/ui/snapshot/widgets/history_table.dart';
import 'package:pickstock/ui/snapshot/widgets/snapshot_report.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

/// A laptop window, which is where the one-column report ran to four screens.
const Size _laptopSize = Size(1440, 900);

/// Narrow enough that the report is a screen of its own.
const Size _narrowSize = Size(420, 900);

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

  double reportHeight(WidgetTester tester) =>
      tester.getRect(find.byType(SnapshotReport)).height;

  testWidgets('opens on the filings, summary and table together', (
    tester,
  ) async {
    await openApple(tester);

    expect(find.text('Sanity check'), findsOneWidget);
    expect(find.text('FY2025 highlights'), findsOneWidget);
    // The table sits with the summary of it, a short scroll down rather than
    // below three screens of valuation.
    expect(find.byType(HistoryTable), findsOneWidget);
    expect(reportHeight(tester), lessThan(_laptopSize.height * 2));
  });

  testWidgets('a price arriving does not move the figures', (tester) async {
    await openApple(tester);
    final before = tester.getRect(find.byType(HistoryTable));

    // Price the company, then come back.
    await openReportTab(tester, ReportTab.valuation);
    await enterPriceByHand(tester, '250');
    expect(find.text('Overvalued'), findsOneWidget);

    await openReportTab(tester, ReportTab.overview);

    // The valuation grew by two thousand pixels and the table did not move a
    // pixel, which is what putting it on its own tab buys.
    expect(tester.getRect(find.byType(HistoryTable)), before);
  });

  testWidgets('a different company starts on its own overview', (tester) async {
    await openApple(tester);
    await openReportTab(tester, ReportTab.valuation);

    await tester.tap(find.text('NVIDIA CORP'));
    await tester.pumpAndSettle();

    // The tab left open for the last company says nothing about this one.
    expect(find.text('Sanity check'), findsOneWidget);
    expect(find.text('Fair value'), findsNothing);
  });

  testWidgets('gives the expectations a tab of their own', (tester) async {
    await openApple(tester);
    await openReportTab(tester, ReportTab.valuation);
    await enterPriceByHand(tester, '250');

    // The band and the growth it implies are two questions, and together they
    // made one tab three screens long.
    expect(find.text('Fair value'), findsOneWidget);
    expect(find.text('What the price is asking'), findsNothing);

    await openReportTab(tester, ReportTab.expectations);

    expect(find.text('What the price is asking'), findsOneWidget);
    expect(find.text('Fair value'), findsNothing);
  });

  testWidgets('the expectations tab asks for a price of its own', (
    tester,
  ) async {
    await openApple(tester);
    await openReportTab(tester, ReportTab.expectations);

    // Nothing to compute without a price, so the same way in is offered
    // rather than an empty tab.
    expect(find.text('Set a price'), findsOneWidget);
  });

  testWidgets('keeps the company and its tabs on screen while scrolling', (
    tester,
  ) async {
    await openApple(tester);

    final headerBefore = tester.getRect(find.byType(CompanyHeader));
    final tabsBefore = tester.getRect(find.byType(ReportTabs));

    // Scroll the report a long way down.
    await tester.drag(find.byType(HistoryTable), const Offset(0, -400));
    await tester.pumpAndSettle();

    // The name of what you are reading, and the way to the other tab, are
    // both still there and have not moved.
    expect(tester.getRect(find.byType(CompanyHeader)), headerBefore);
    expect(tester.getRect(find.byType(ReportTabs)), tabsBefore);
    expect(find.text('Apple Inc.'), findsWidgets);
  });

  testWidgets('the tab bar sits close under the company', (tester) async {
    await openApple(tester);

    final header = tester.getRect(find.byType(CompanyHeader));
    // The bar itself, not the widget that pads it.
    final bar = tester.getRect(
      find.descendant(of: find.byType(ReportTabs), matching: find.byType(Tabs)),
    );

    // Half a section's spacing: the two are one block, not two sections.
    expect(bar.top - header.bottom, ThemeRepo.reportTabsGap);
  });

  testWidgets('every tab is reachable on a narrow window', (tester) async {
    await openApple(tester, size: _narrowSize);

    final bar = tester.getRect(find.byType(ReportTabs));
    for (final tab in ReportTab.values) {
      final label = tester.getRect(
        find
            .descendant(
              of: find.byType(ReportTabs),
              matching: find.byType(Text),
            )
            .at(tab.index),
      );
      // Tabs sized to their own content ran past the edge of the window,
      // unreachable and with nothing to say there was more.
      expect(
        label.right,
        lessThanOrEqualTo(bar.right),
        reason: '${tab.name} runs past the tab bar',
      );
    }
  });
}
