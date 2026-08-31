import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

const Size _desktopSize = Size(1440, 900);

void main() {
  late AppDatabase database;

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

  testWidgets('offers nothing when the loaded archive is current', (
    tester,
  ) async {
    database = await registerTestDependencies();
    await openApp(tester);

    // No update, no button: an always-present refresh invites a pointless
    // 1.4 GB download.
    expect(find.text('Update available'), findsNothing);
    expect(find.byIcon(LucideIcons.refreshCw), findsNothing);
  });

  testWidgets('offers a refresh once SEC has rebuilt the archive', (
    tester,
  ) async {
    database = await registerTestDependencies(withUpdateAvailable: true);
    await openApp(tester);

    expect(find.text('Update available'), findsOneWidget);
  });

  testWidgets(
    'records the archive date so the check has something to compare',
    (tester) async {
      database = await registerTestDependencies();
      await openApp(tester);

      final run = await database.lastIngest();
      expect(run!.archiveLastModified, isNotNull);
    },
  );
}
