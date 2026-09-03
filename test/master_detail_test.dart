import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/ui/browse/widgets/ticker_grid.dart';
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

  /// The list is the app's main screen, so there is nothing to open.
  Future<void> openBrowser(WidgetTester tester, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();
  }

  testWidgets('shows the report beside the list on a wide window', (
    tester,
  ) async {
    await openBrowser(tester, _wideSize);

    // Both panes at once: the list, and the report's own empty state.
    expect(find.text('PickStock'), findsOneWidget);
    expect(find.text('Check a company before you invest'), findsOneWidget);
  });

  testWidgets('picking a company swaps the detail without leaving the list', (
    tester,
  ) async {
    await openBrowser(tester, _wideSize);

    await tester.tap(find.text('Apple Inc.'));
    await tester.pumpAndSettle();

    // Still on the list, now with Apple's report beside it.
    expect(find.text('PickStock'), findsOneWidget);
    expect(find.text('FY2025 highlights'), findsOneWidget);
  });

  testWidgets('switching company swaps only the detail', (tester) async {
    await openBrowser(tester, _wideSize);

    await tester.tap(find.text('Apple Inc.'));
    await tester.pumpAndSettle();
    expect(find.textContaining('CIK 0000320193'), findsOneWidget);

    // Straight to another company, no navigation in between.
    await tester.tap(find.text('NVIDIA CORP'));
    await tester.pumpAndSettle();

    expect(find.textContaining('CIK 0001045810'), findsOneWidget);
    expect(find.textContaining('CIK 0000320193'), findsNothing);
    expect(find.text('PickStock'), findsOneWidget);
  });

  testWidgets('marks which tile the report beside the list is about', (
    tester,
  ) async {
    await openBrowser(tester, _wideSize);

    /// The tile for [ticker], if it is the one the report is showing.
    ///
    /// Read off the selected semantics rather than off the tile's colours:
    /// what matters is that exactly one tile claims to be the selected one,
    /// and a screen reader has to be told which as much as the eye does.
    Finder selectedTile(String ticker) => find.ancestor(
      of: find.text(ticker),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && (widget.properties.selected ?? false),
      ),
    );

    // Nothing picked yet, so nothing is marked.
    expect(selectedTile('AAPL'), findsNothing);

    await tester.tap(find.text('Apple Inc.'));
    await tester.pumpAndSettle();
    expect(selectedTile('AAPL'), findsOneWidget);
    expect(selectedTile('NVDA'), findsNothing);

    // The mark follows the report rather than accumulating.
    await tester.tap(find.text('NVIDIA CORP'));
    await tester.pumpAndSettle();
    expect(selectedTile('NVDA'), findsOneWidget);
    expect(selectedTile('AAPL'), findsNothing);
  });

  testWidgets('the list pane can be dragged wider to fit more columns', (
    tester,
  ) async {
    await openBrowser(tester, _wideSize);

    int columns() {
      final tiles = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(Button),
      );
      final top = tester.getRect(tiles.at(0)).top;
      var count = 0;
      for (var i = 0; i < tester.widgetList(tiles).length; i++) {
        if (tester.getRect(tiles.at(i)).top == top) count++;
      }
      return count;
    }

    final before = tester.getRect(find.byType(TickerGrid)).width;
    final columnsBefore = columns();

    // Drag the divider to the right.
    final pane = tester.getRect(find.byType(TickerGrid));
    await tester.dragFrom(
      Offset(pane.right + 2, pane.center.dy),
      const Offset(300, 0),
    );
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byType(TickerGrid)).width, greaterThan(before));
    expect(columns(), greaterThan(columnsBefore));
    // The report is still beside it.
    expect(find.text('PickStock'), findsOneWidget);
  });

  testWidgets('tiles are twice as wide as tall, with the figure on the right', (
    tester,
  ) async {
    await openBrowser(tester, _wideSize);

    final tile = find
        .descendant(of: find.byType(GridView), matching: find.byType(Button))
        .at(0);
    final rect = tester.getRect(tile);
    expect(rect.width / rect.height, closeTo(2, 0.01));

    // The ranked figure sits to the right of the symbol.
    final symbol = tester.getRect(
      find.descendant(of: tile, matching: find.text('AAPL')),
    );
    final figure = tester.getRect(
      find.descendant(of: tile, matching: find.textContaining(r'$')),
    );
    expect(figure.left, greaterThan(symbol.right));
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
    expect(find.text('PickStock'), findsNothing);
    expect(find.text('FY2025 highlights'), findsOneWidget);
  });
}
