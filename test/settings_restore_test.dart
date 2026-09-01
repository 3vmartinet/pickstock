import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/snapshot/browse_sort.dart';
import 'package:pickstock/data/snapshot/sic_sector.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/settings/settings_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

const Size _wideSize = Size(1600, 1200);

void main() {
  late AppDatabase database;
  late MemorySettingsRepo settings;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    settings = MemorySettingsRepo();
    database = await registerTestDependencies(
      withFinancials: true,
      settingsRepo: settings,
    );
  });

  tearDown(() async {
    await database.close();
    await GetIt.I.reset();
  });

  Future<void> launch(WidgetTester tester) async {
    tester.view
      ..physicalSize = _wideSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the sector left selected', (tester) async {
    await launch(tester);
    await tester.tap(find.text('Tech'));
    await tester.pumpAndSettle();
    expect(settings.sector, SicSector.technology);

    // Relaunched against the same settings, as the next start would be.
    await launch(tester);

    // Still filtered: the tech filers are listed and the insurer is not.
    expect(find.text('NVIDIA CORP'), findsOneWidget);
    expect(find.text('BERKSHIRE HATHAWAY INC'), findsNothing);
  });

  testWidgets('opens in the ordering left chosen', (tester) async {
    await launch(tester);
    await tester.tap(find.text('Name (A–Z)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revenue growth, 1 year').last);
    await tester.pumpAndSettle();
    expect(settings.browseSort, BrowseSort.revenueOneYear);

    await launch(tester);

    expect(find.text('Revenue growth, 1 year'), findsOneWidget);
  });

  testWidgets('opens in the theme left chosen', (tester) async {
    await launch(tester);
    expect(settings.themeMode, ThemeMode.system);

    await tester.tap(find.byIcon(LucideIcons.moon));
    await tester.pumpAndSettle();

    expect(settings.themeMode, isNot(ThemeMode.system));
  });
}
