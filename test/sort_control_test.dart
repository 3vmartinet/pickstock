import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/snapshot/browse_sort.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/theme_repo.dart';
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

  double controlWidth(WidgetTester tester) =>
      tester.getRect(find.byType(Select<BrowseSort>)).width;

  testWidgets('is the same width whichever option is chosen', (tester) async {
    await openHome(tester);
    final withShortest = controlWidth(tester);

    await tester.tap(find.text('Name (A–Z)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revenue growth, 10-year annualised').last);
    await tester.pumpAndSettle();

    // Sized to the longest option, not to the chosen one, so picking a long
    // option does not shove the match count sideways.
    expect(controlWidth(tester), withShortest);
  });

  testWidgets('does not span the window when opened', (tester) async {
    await openHome(tester);

    await tester.tap(find.text('Name (A–Z)'));
    await tester.pumpAndSettle();

    // The popup used to stretch the full width of the app.
    final option = tester.getRect(
      find.text('Revenue growth, 10-year annualised').last,
    );
    expect(option.right, lessThan(_wideSize.width * 0.6));
    expect(
      controlWidth(tester),
      lessThanOrEqualTo(ThemeRepo.sortSelectMaxWidth),
    );
  });
}
