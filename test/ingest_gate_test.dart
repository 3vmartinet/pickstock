import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/ui/widgets/ingest_button.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

const Size _desktopSize = Size(1440, 1000);

/// Long enough for flutter_animate's zero-duration start timers to fire, which
/// a test must not leave pending.
const Duration _animationStart = Duration(milliseconds: 50);

/// Presses "Finish update" and says yes to the confirmation behind it.
///
/// The database step shuts the app for minutes, so it asks first.
Future<void> confirmFinishUpdate(WidgetTester tester) async {
  await tester.tap(find.text('Finish update'));
  await tester.pumpAndSettle();
  expect(find.text('Refresh the database now?'), findsOneWidget);
  await tester.tap(find.text('Refresh now'));
  await tester.pump();
}

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

  testWidgets('keeps the app usable while an update downloads', (tester) async {
    final ingest = FakeBulkIngestRepo();
    database = await registerTestDependencies(bulkIngestRepo: ingest);
    await pumpApp(tester);

    expect(find.text('Update available'), findsOneWidget);
    await tester.tap(find.text('Update available'));
    await tester.pump();
    // The turning arrows schedule a start timer, which has to be let go of
    // before the test ends.
    await tester.pump(_animationStart);

    // The downloads touch no table, so there is no reason to lock the app for
    // the several minutes they take: only the app bar changes.
    expect(find.text('Downloading update…'), findsOneWidget);
    expect(find.text('PickStock'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Preparing your data'), findsNothing);
  });

  testWidgets('shows how far a background download has got', (tester) async {
    final ingest = FakeBulkIngestRepo();
    database = await registerTestDependencies(bulkIngestRepo: ingest);
    await pumpApp(tester);

    await tester.tap(find.text('Update available'));
    await tester.pump();
    await tester.pump(_animationStart);

    // On the button's own bottom edge rather than in a bar of its own, which
    // would make the app bar taller the moment a download started.
    final bar = find.byType(Progress);
    expect(bar, findsOneWidget);
    expect(tester.widget<Progress>(bar).progress, 0.42);
    expect(
      tester.getRect(bar).bottom,
      tester
          .getRect(
            find.ancestor(
              of: find.text('Downloading update…'),
              matching: find.byType(PrimaryButton),
            ),
          )
          .bottom,
    );
  });

  testWidgets('stops a background download when asked, keeping nothing', (
    tester,
  ) async {
    final ingest = FakeBulkIngestRepo();
    database = await registerTestDependencies(bulkIngestRepo: ingest);
    await pumpApp(tester);

    await tester.tap(find.text('Update available'));
    await tester.pump();
    await tester.pump(_animationStart);

    await tester.tap(find.byKey(updateCancelKey));
    // A download is stopped at its next report, so the fake has to send one —
    // and it sends its last, which is the case worth pinning down: a cancel
    // that lands as the download finishes still cancels.
    ingest.finishDownload.complete();
    await tester.pumpAndSettle();

    // Half an archive is no use, so it goes, and the offer is back as it was.
    expect(ingest.wasCancelled, isTrue);
    expect(ingest.wasDiscarded, isTrue);
    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Downloading update…'), findsNothing);
    expect(find.byKey(updateCancelKey), findsNothing);
    // And the app was never in the way of any of it.
    expect(find.text('PickStock'), findsOneWidget);
  });

  testWidgets('waits to be told before it touches the database', (
    tester,
  ) async {
    final ingest = FakeBulkIngestRepo();
    database = await registerTestDependencies(bulkIngestRepo: ingest);
    await pumpApp(tester);

    await tester.tap(find.text('Update available'));
    await tester.pump();
    await tester.pump(_animationStart);
    ingest.finishDownload.complete();
    await tester.pump();

    // Everything is downloaded and the app is still usable: the step that
    // clears the tables is a decision, not a consequence.
    expect(find.text('Finish update'), findsOneWidget);
    expect(find.text('PickStock'), findsOneWidget);

    await confirmFinishUpdate(tester);
    // Enough for flutter_animate's start timers; the panel's pulse repeats
    // forever, so settling is not an option.
    await tester.pump(const Duration(milliseconds: 500));

    // Now the app has to go: the tables are cleared before they are
    // repopulated, so there is nothing behind the panel to use.
    expect(find.text('PickStock'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('Preparing your data'), findsOneWidget);
  });

  testWidgets('lets the app back in, with nothing left on offer', (
    tester,
  ) async {
    final ingest = FakeBulkIngestRepo();
    database = await registerTestDependencies(bulkIngestRepo: ingest);
    await pumpApp(tester);

    await tester.tap(find.text('Update available'));
    await tester.pump();
    await tester.pump(_animationStart);
    ingest.finishDownload.complete();
    await tester.pump();
    await confirmFinishUpdate(tester);
    await tester.pump(_animationStart);

    ingest.finishLoad.complete();
    // The directory is re-read and the ingest row looked up before the gate
    // opens, so the app comes back a few turns of the loop later. Settling is
    // an option again here: the panel with the repeating pulse has gone.
    await tester.pumpAndSettle();

    expect(find.text('PickStock'), findsOneWidget);
    // The archive just loaded is the newest one, so the button goes away.
    expect(find.text('Update available'), findsNothing);
    expect(find.text('Finish update'), findsNothing);
  });
}
