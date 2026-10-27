import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/settings/settings_repo.dart';
import 'package:pickstock/ui/ingest_view_model.dart';
import 'package:pickstock/ui/settings/app_menu.dart';
import 'package:pickstock/ui/settings/widgets/settings_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

const Size _desktopSize = Size(1400, 900);

void main() {
  late AppDatabase database;

  tearDown(() async {
    await database.close();
    await GetIt.I.reset();
  });

  /// Frames without settling: a download under way spins its button for as
  /// long as it runs, so the tree never goes quiet.
  Future<void> pumpFrames(WidgetTester tester, {int frames = 10}) async {
    for (var frame = 0; frame < frames; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view
      ..physicalSize = _desktopSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PickStockApp());
    await pumpFrames(tester);
  }

  /// What the native menu sends when Settings… is chosen, or ⌘, pressed.
  Future<void> chooseSettingsFromMenu(WidgetTester tester) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      appMenuChannel.name,
      appMenuChannel.codec.encodeMethodCall(
        const MethodCall(openSettingsMethod),
      ),
      (_) {},
    );
    await pumpFrames(tester);
  }

  UpdatePhase phaseOf(WidgetTester tester) => tester
      .element(find.byType(Scaffold).first)
      .read<IngestViewModel>()
      .updatePhase;

  Switch autoDownloadSwitch(WidgetTester tester) => tester.widget<Switch>(
    find.descendant(
      of: find.byKey(autoDownloadSwitchKey),
      matching: find.byType(Switch),
    ),
  );

  group('opened from the app menu', () {
    testWidgets('as a window titled the way Apple names it', (tester) async {
      database = await registerTestDependencies();
      await pumpApp(tester);
      expect(find.byType(SettingsDialog), findsNothing);

      await chooseSettingsFromMenu(tester);

      expect(find.byType(SettingsDialog), findsOneWidget);
      // A settings window with a single pane is "App Name Settings".
      expect(find.text('PickStock Settings'), findsOneWidget);
      expect(find.text('Download updates automatically'), findsOneWidget);
      // Every change applies as it is made: there is nothing to confirm.
      expect(find.text('OK'), findsNothing);
      expect(find.text('Apply'), findsNothing);
    });

    testWidgets('only once, however often it is asked for', (tester) async {
      database = await registerTestDependencies();
      await pumpApp(tester);

      await chooseSettingsFromMenu(tester);
      await chooseSettingsFromMenu(tester);

      expect(find.byType(SettingsDialog), findsOneWidget);
    });

    testWidgets('and closed by its own button', (tester) async {
      database = await registerTestDependencies();
      await pumpApp(tester);
      await chooseSettingsFromMenu(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(SettingsDialog),
          matching: find.byIcon(LucideIcons.x),
        ),
      );
      await pumpFrames(tester);

      expect(find.byType(SettingsDialog), findsNothing);
      // And can be opened again: the guard against a second copy lets go.
      await chooseSettingsFromMenu(tester);
      expect(find.byType(SettingsDialog), findsOneWidget);
    });
  });

  group('downloading updates automatically', () {
    testWidgets('is on to begin with', (tester) async {
      database = await registerTestDependencies(autoDownloadUpdates: true);
      await pumpApp(tester);
      await chooseSettingsFromMenu(tester);

      expect(autoDownloadSwitch(tester).value, isTrue);
    });

    testWidgets('fetches a newer archive without being asked', (tester) async {
      final ingest = FakeBulkIngestRepo();
      database = await registerTestDependencies(
        bulkIngestRepo: ingest,
        autoDownloadUpdates: true,
      );
      await pumpApp(tester);

      // Straight past the offer: nobody pressed anything.
      expect(phaseOf(tester), UpdatePhase.downloading);
      expect(find.text('Update available'), findsNothing);

      ingest.finishDownload.complete();
      await pumpFrames(tester);
      // Downloaded, and then waits: loading shuts the app, so that stays a
      // press whatever the setting says.
      expect(phaseOf(tester), UpdatePhase.staged);
    });

    testWidgets('does not fetch again what an earlier session left', (
      tester,
    ) async {
      final ingest = FakeBulkIngestRepo()
        ..staged = fakeStagedIngest(testNewerArchiveDate);
      database = await registerTestDependencies(
        bulkIngestRepo: ingest,
        autoDownloadUpdates: true,
      );
      await pumpApp(tester);

      expect(phaseOf(tester), UpdatePhase.staged);
    });

    testWidgets('turned off, leaves the offer to a press', (tester) async {
      database = await registerTestDependencies(
        bulkIngestRepo: FakeBulkIngestRepo(),
      );
      await pumpApp(tester);

      expect(phaseOf(tester), UpdatePhase.offered);
      expect(find.text('Update available'), findsOneWidget);
    });

    testWidgets('turned on with an update waiting, fetches it there and then', (
      tester,
    ) async {
      database = await registerTestDependencies(
        bulkIngestRepo: FakeBulkIngestRepo(),
      );
      await pumpApp(tester);
      await chooseSettingsFromMenu(tester);
      expect(autoDownloadSwitch(tester).value, isFalse);
      expect(find.textContaining('It has not been downloaded'), findsOneWidget);

      // The row's words, not only its switch: the whole row is the target.
      await tester.tap(find.text('Download updates automatically'));
      await pumpFrames(tester);

      expect(autoDownloadSwitch(tester).value, isTrue);
      expect(phaseOf(tester), UpdatePhase.downloading);
      expect(
        find.textContaining('Downloading the update in the background'),
        findsOneWidget,
      );
      expect(GetIt.I.get<SettingsRepo>().autoDownloadUpdates, isTrue);
    });

    testWidgets('turned off, is remembered', (tester) async {
      database = await registerTestDependencies(autoDownloadUpdates: true);
      await pumpApp(tester);
      await chooseSettingsFromMenu(tester);

      await tester.tap(find.byType(Switch));
      await pumpFrames(tester);

      expect(autoDownloadSwitch(tester).value, isFalse);
      expect(GetIt.I.get<SettingsRepo>().autoDownloadUpdates, isFalse);
    });
  });

  group('stored', () {
    late AppDatabase store;

    setUp(() {
      store = AppDatabase.forTesting(NativeDatabase.memory());
      GetIt.I.registerSingleton<AppDatabase>(store);
      database = store;
    });

    test('as nothing at all while it is on, the default', () async {
      final settings = LocalSettingsRepo();
      await settings.load();
      expect(settings.autoDownloadUpdates, isTrue);

      await settings.setAutoDownloadUpdates(false);
      expect(
        await store.allSettings(),
        containsPair('autoDownloadUpdates', 'false'),
      );

      // A new launch reads it back off.
      final relaunched = LocalSettingsRepo();
      await relaunched.load();
      expect(relaunched.autoDownloadUpdates, isFalse);

      // And turning it back on removes the row rather than writing "true".
      await relaunched.setAutoDownloadUpdates(true);
      expect(await store.allSettings(), isNot(contains('autoDownloadUpdates')));
    });
  });
}
