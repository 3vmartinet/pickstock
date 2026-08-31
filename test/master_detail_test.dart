import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

/// Wide enough for the list and a report side by side.
const Size _wideSize = Size(1440, 900);

/// Below the breakpoint: one pane at a time.
const Size _narrowSize = Size(820, 900);

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

  Future<void> openBrowser(WidgetTester tester, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.list));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the report beside the list on a wide window', (
    tester,
  ) async {
    await openBrowser(tester, _wideSize);

    // Both panes at once: the list, and the report's own empty state.
    expect(find.text('All tickers'), findsOneWidget);
    expect(find.text('Check a company before you invest'), findsOneWidget);
  });

  testWidgets('picking a company swaps the detail without leaving the list', (
    tester,
  ) async {
    await openBrowser(tester, _wideSize);

    await tester.tap(find.text('Apple Inc.'));
    await tester.pumpAndSettle();

    // Still on the list, now with Apple's report beside it.
    expect(find.text('All tickers'), findsOneWidget);
    expect(find.text('FY2025 highlights'), findsOneWidget);
  });

  testWidgets('switching company swaps only the detail', (tester) async {
    await openBrowser(tester, _wideSize);

    await tester.tap(find.text('Apple Inc.'));
    await tester.pumpAndSettle();
    expect(find.text('CIK 0000320193'), findsOneWidget);

    // Straight to another company, no navigation in between.
    await tester.tap(find.text('NVIDIA CORP'));
    await tester.pumpAndSettle();

    expect(find.text('CIK 0001045810'), findsOneWidget);
    expect(find.text('CIK 0000320193'), findsNothing);
    expect(find.text('All tickers'), findsOneWidget);
  });

  testWidgets('a narrow window keeps one pane and navigates back', (
    tester,
  ) async {
    await openBrowser(tester, _narrowSize);

    // No detail pane beside the list.
    expect(find.text('Check a company before you invest'), findsNothing);

    await tester.tap(find.text('Apple Inc.'));
    await tester.pumpAndSettle();

    // Left the list for the report.
    expect(find.text('All tickers'), findsNothing);
    expect(find.text('FY2025 highlights'), findsOneWidget);
  });
}
