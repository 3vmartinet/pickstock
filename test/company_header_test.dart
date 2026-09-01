import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/ui/snapshot/widgets/company_header.dart';
import 'package:pickstock/ui/watchlist/widgets/add_to_watchlist_button.dart';
import 'package:pickstock/ui/watchlist/widgets/watchlist_star.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

const Size _wideSize = Size(1600, 1200);

/// Narrow enough that the header has no room for a label on the list button.
const Size _narrowSize = Size(420, 900);

/// A header holding the title, the CIK under it and the controls beside them,
/// with the card's padding. Anything taller means something wrapped.
const double _oneRowHeaderHeight = 120;

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

  Future<void> openApple(WidgetTester tester, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apple Inc.'));
    await tester.pumpAndSettle();
  }

  testWidgets('follows the company from the title\'s own row', (tester) async {
    await openApple(tester, _wideSize);

    final title = tester.getRect(find.text('Apple Inc.').last);
    final star = tester.getRect(find.byType(WatchlistStar));
    final list = tester.getRect(find.byType(AddToWatchlistButton));
    final header = tester.getRect(find.byType(CompanyHeader));

    // Beside the title rather than on a row of its own underneath.
    expect(star.center.dy, closeTo(title.center.dy, 8));
    expect(star.left, greaterThan(title.right));
    // And hard right, on the card's own padding.
    expect(header.right - list.right, closeTo(ThemeRepo.spaceLarge, 2));
  });

  testWidgets('no longer badges the years it covers', (tester) async {
    await openApple(tester, _wideSize);

    // The span used to sit in the header; the table below names the years it
    // actually shows.
    expect(find.textContaining(' – FY'), findsNothing);
  });

  testWidgets('keeps the header one row tall on a narrow window', (
    tester,
  ) async {
    await openApple(tester, _narrowSize);

    final header = tester.getRect(find.byType(CompanyHeader));
    final title = tester.getRect(find.text('Apple Inc.').last);
    final star = tester.getRect(find.byType(WatchlistStar));

    // The list button's label used to wrap here, which took the header from
    // 84 pixels to 264 — two and a half times a wide window's.
    expect(header.height, lessThan(_oneRowHeaderHeight));
    // And the controls still share the title's row rather than dropping below.
    expect(star.center.dy, closeTo(title.center.dy, 8));
  });

  testWidgets('the list button stays a real target without its label', (
    tester,
  ) async {
    await openApple(tester, _narrowSize);

    final list = tester.getRect(find.byType(AddToWatchlistButton));
    expect(list.width, greaterThanOrEqualTo(ThemeRepo.spaceXLarge));
    expect(list.height, greaterThanOrEqualTo(ThemeRepo.spaceXLarge));

    // And still opens the menu.
    await tester.tap(find.byType(AddToWatchlistButton));
    await tester.pumpAndSettle();
    expect(find.text('Add to a list'), findsOneWidget);
  });
}
