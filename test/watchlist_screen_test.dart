import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/ui/watchlist/widgets/watchlist_dot.dart';
import 'package:pickstock/ui/watchlist/widgets/watchlist_star.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

const Size _wideSize = Size(1600, 1200);

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

  Future<void> openHome(WidgetTester tester) async {
    tester.view
      ..physicalSize = _wideSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();
  }

  Future<void> openApple(WidgetTester tester) async {
    await openHome(tester);
    await tester.tap(find.text('Apple Inc.'));
    await tester.pumpAndSettle();
  }

  testWidgets('starts on the whole directory, not a list', (tester) async {
    await openHome(tester);

    expect(find.text('All companies'), findsOneWidget);
    expect(find.text('${testTickers.length} matches'), findsOneWidget);
  });

  testWidgets('starring a company marks it on the list too', (tester) async {
    await openApple(tester);

    expect(find.byType(WatchlistStar), findsOneWidget);
    // No dot on the tile until the company is followed.
    expect(find.byType(WatchlistDot), findsNothing);

    await tester.tap(find.byType(WatchlistStar));
    await tester.pumpAndSettle();

    // The report and the tile beside it agree, without either telling the
    // other: both read the one view model.
    expect(find.byType(WatchlistDot), findsWidgets);
  });

  testWidgets('filtering to a list narrows the directory to it', (
    tester,
  ) async {
    await openApple(tester);
    await tester.tap(find.byType(WatchlistStar));
    await tester.pumpAndSettle();

    await tester.tap(find.text('All companies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favourites').last);
    await tester.pumpAndSettle();

    expect(find.text('1 match'), findsOneWidget);
    // Scoped to the grid: the report open beside it also names the company.
    final inGrid = find.descendant(
      of: find.byType(GridView),
      matching: find.text('Apple Inc.'),
    );
    expect(inGrid, findsOneWidget);
    expect(find.text('MICROSOFT CORP'), findsNothing);
  });

  testWidgets('an empty list says so rather than looking like no results', (
    tester,
  ) async {
    await openHome(tester);

    await tester.tap(find.text('All companies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favourites').last);
    await tester.pumpAndSettle();

    expect(find.text('Nothing in this list'), findsOneWidget);
    expect(find.textContaining('Open a company and add it to'), findsOneWidget);
  });

  testWidgets('makes a list, names it and colours it', (tester) async {
    await openHome(tester);

    await tester.tap(find.text('All companies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New list'));
    await tester.pumpAndSettle();

    expect(find.text('Colour'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Semiconductors');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('All companies'));
    await tester.pumpAndSettle();
    expect(find.text('Semiconductors'), findsOneWidget);
    // Both the new list and the starred one are empty, and each says so.
    expect(find.text('empty'), findsNWidgets(2));
  });
}
