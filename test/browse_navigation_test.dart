import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/sec/ticker_directory_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

/// Enough rows that the grid actually scrolls.
const int _extraTickers = 80;

/// Narrow enough that the list takes the whole window and picking a company
/// returns to the report — the behaviour these tests are about. The side-by-side
/// layout is covered separately.
const Size _desktopSize = Size(820, 700);

/// The first grid tile whose centre lies inside the viewport.
Finder _visibleTile(WidgetTester tester) {
  final grid = find.byType(GridView);
  final viewport = tester.getRect(grid);
  final tiles = find.descendant(of: grid, matching: find.byType(Button));
  for (var i = 0; i < tester.widgetList(tiles).length; i++) {
    if (viewport.contains(tester.getRect(tiles.at(i)).center)) {
      return tiles.at(i);
    }
  }
  throw StateError('no tile is visible');
}

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

  Future<void> openApp(WidgetTester tester) async {
    tester.view
      ..physicalSize = _desktopSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();
  }

  /// Back from a company's report to the list.
  Future<void> returnToList(WidgetTester tester) async {
    await tester.tap(find.byIcon(LucideIcons.arrowLeft));
    await tester.pumpAndSettle();
  }

  testWidgets('the chosen ordering survives a trip into a report', (
    tester,
  ) async {
    await openApp(tester);

    await tester.tap(find.text('Name (A–Z)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revenue growth, 1 year').last);
    await tester.pumpAndSettle();
    expect(find.text('Revenue growth, 1 year'), findsOneWidget);

    // Into a company's report and straight back.
    await tester.tap(find.text('NVIDIA CORP'));
    await tester.pumpAndSettle();
    expect(find.text('PickStock'), findsNothing);

    await returnToList(tester);

    // Still ranked by growth, not reset to the default ordering.
    expect(find.text('Revenue growth, 1 year'), findsOneWidget);
    expect(find.text('Name (A–Z)'), findsNothing);
  });

  testWidgets('the filter survives too', (tester) async {
    await openApp(tester);

    await tester.enterText(find.byType(TextField).last, 'BRK');
    await tester.pumpAndSettle();
    expect(find.text('2 matches'), findsOneWidget);

    await tester.tap(find.text('BERKSHIRE HATHAWAY INC').first);
    await tester.pumpAndSettle();
    await returnToList(tester);

    expect(find.text('2 matches'), findsOneWidget);
  });

  testWidgets('the list comes back where it was left', (tester) async {
    // The seven-symbol fixture fits on screen; scrolling needs more than that.
    await database.batch(
      (batch) => batch.insertAll(database.tickers, [
        for (var i = 0; i < _extraTickers; i++)
          TickersCompanion.insert(
            symbol: 'SYM$i',
            cik: '900000000$i',
            name: 'Filler Company $i',
          ),
      ]),
    );
    await GetIt.I.get<TickerDirectoryRepo>().load();

    await openApp(tester);

    final grid = find.byType(GridView);
    await tester.drag(grid, const Offset(0, -200));
    await tester.pumpAndSettle();
    final offset = tester.widget<GridView>(grid).controller!.offset;
    expect(offset, greaterThan(0));

    // A tile that is actually on screen: after scrolling, the first built tile
    // may sit in the cache extent above the viewport, and the grid's own centre
    // can fall in the gap between tiles.
    await tester.tap(_visibleTile(tester));
    await tester.pumpAndSettle();
    // The grid is gone, so we are on the company's own screen. (Its app bar
    // falls back to the app title for a filler symbol with no report, so the
    // title is not a reliable marker here.)
    expect(find.byType(GridView), findsNothing);

    await returnToList(tester);

    // Same scroll position, not back at the top.
    expect(
      tester.widget<GridView>(find.byType(GridView)).controller!.offset,
      offset,
    );
  });
}
