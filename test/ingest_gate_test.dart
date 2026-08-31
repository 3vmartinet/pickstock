import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

const Size _desktopSize = Size(1440, 1000);

void main() {
  late AppDatabase database;

  tearDown(() async {
    await database.close();
    await GetIt.I.reset();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view
      ..physicalSize = _desktopSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();
  }

  testWidgets('blocks the whole app until data has been ingested', (
    tester,
  ) async {
    database = await registerTestDependencies(withIngest: false);
    await pumpApp(tester);

    // The setup step, and nothing of the app behind it.
    expect(find.text('Financial data required'), findsOneWidget);
    expect(find.text('Download SEC data'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('PickStock'), findsNothing);
    expect(find.text('Check a company before you invest'), findsNothing);
  });

  testWidgets('lets the app through once the database holds data', (
    tester,
  ) async {
    database = await registerTestDependencies();
    await pumpApp(tester);

    expect(find.text('Financial data required'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('PickStock'), findsOneWidget);
  });

  testWidgets('blocks again while a refresh is running', (tester) async {
    // The refresh is only offered when SEC has published a newer archive.
    database = await registerTestDependencies(withUpdateAvailable: true);
    await pumpApp(tester);
    expect(find.text('PickStock'), findsOneWidget);

    // A refresh clears the tables before repopulating them, so the app must
    // not stay usable behind it.
    expect(find.text('Update available'), findsOneWidget);
    await tester.tap(find.text('Update available'));
    // Enough for flutter_animate's start timers; the panel's pulse repeats
    // forever, so settling is not an option.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('PickStock'), findsNothing);
    // The setup panel, with its progress ring, has taken the screen.
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('Preparing your data'), findsOneWidget);
  });
}
