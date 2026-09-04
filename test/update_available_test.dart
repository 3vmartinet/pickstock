import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/widgets/ingest_button.dart';
import 'package:pickstock/ui/widgets/theme_toggle_button.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

const Size _desktopSize = Size(1440, 900);

/// Phone width, where the app bar drops what it can spare.
const Size _compactSize = Size(420, 900);

/// The colour of the dot on the update button, which says which of the two
/// things needing attention it is.
Color badgeColour(WidgetTester tester) {
  final badge = tester.widget<Container>(find.byKey(updateBadgeKey));
  return (badge.decoration! as BoxDecoration).color!;
}

/// The theme the badge is drawn against.
ThemeData themeAtBadge(WidgetTester tester) =>
    Theme.of(tester.element(find.byKey(updateBadgeKey)));

void main() {
  late AppDatabase database;

  tearDown(() async {
    await database.close();
    await GetIt.I.reset();
  });

  Future<void> openApp(WidgetTester tester, {Size size = _desktopSize}) async {
    tester.view
      ..physicalSize = size
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
    expect(find.byKey(updateBadgeKey), findsNothing);
    // Instead, which day's data the figures are from — an empty app bar
    // leaves that unanswered. On two lines, the date under its heading.
    expect(find.text('SEC data'), findsOneWidget);
    expect(find.text('Jan 1, 2026'), findsOneWidget);
  });

  testWidgets('offers a refresh once SEC has rebuilt the archive', (
    tester,
  ) async {
    database = await registerTestDependencies(withUpdateAvailable: true);
    await openApp(tester);

    expect(find.text('Update available'), findsOneWidget);
    // Dotted, so it registers with someone who was not reading the app bar.
    expect(find.byKey(updateBadgeKey), findsOneWidget);
    // And the date it replaced has given way rather than doubling up.
    expect(find.textContaining('SEC data'), findsNothing);

    // On the top-left corner, clear of the label it is marking.
    final badge = tester.getRect(find.byKey(updateBadgeKey));
    final button = tester.getRect(find.byType(IngestButton));
    expect(badge.left, lessThan(button.left));
    expect(badge.top, lessThan(button.top));
    // Red: newly published, nothing fetched yet.
    expect(badgeColour(tester), themeAtBadge(tester).colorScheme.destructive);
  });

  testWidgets('drops the date label where the app bar has no room', (
    tester,
  ) async {
    database = await registerTestDependencies();
    await openApp(tester, size: _compactSize);

    // The same rule the subtitle follows: at phone width the row has nothing
    // to spare, and the label pushed the list off the bottom of the screen.
    expect(find.textContaining('SEC data'), findsNothing);
  });

  testWidgets('sits at the right-hand end of the app bar', (tester) async {
    database = await registerTestDependencies(withUpdateAvailable: true);
    await openApp(tester);

    // Last of the three trailing controls: it is the only one that changes
    // width, and from the middle of the row it shoved the icons about.
    expect(
      tester.getRect(find.byType(IngestButton)).left,
      greaterThan(tester.getRect(find.byType(ThemeToggleButton)).right),
    );
  });

  testWidgets('picks up a download an earlier session left staged', (
    tester,
  ) async {
    final ingest = FakeBulkIngestRepo()
      ..staged = fakeStagedIngest(testNewerArchiveDate);
    database = await registerTestDependencies(bulkIngestRepo: ingest);
    await openApp(tester);

    // The 1.4 GB does not have to come down twice: the app opens straight
    // onto the step the download was waiting for.
    expect(find.text('Finish update'), findsOneWidget);
    expect(find.text('Update available'), findsNothing);
    // Still dotted, in orange rather than red: a different thing to do, and
    // the colour is the quicker of the two to read at a glance.
    expect(find.byKey(updateBadgeKey), findsOneWidget);
    expect(
      badgeColour(tester),
      GetIt.I.get<ThemeRepo>().caution(themeAtBadge(tester)),
    );
  });

  testWidgets('asks before it shuts the app, and says for how long', (
    tester,
  ) async {
    final ingest = FakeBulkIngestRepo()
      ..staged = fakeStagedIngest(testNewerArchiveDate);
    database = await registerTestDependencies(
      bulkIngestRepo: ingest,
      // What the last database step took, rounded to seven minutes.
      lastLoadDuration: const Duration(minutes: 6, seconds: 50),
    );
    await openApp(tester);

    await tester.tap(find.text('Finish update'));
    await tester.pumpAndSettle();

    expect(find.text('Refresh the database now?'), findsOneWidget);
    // Measured, not guessed: the last run was timed, and the archive and the
    // machine are much the same again.
    expect(find.text('Last time this took about 7 minutes.'), findsOneWidget);

    // And backing out leaves the app exactly as it was.
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('PickStock'), findsOneWidget);
    expect(find.text('Finish update'), findsOneWidget);
    expect(find.text('Preparing your data'), findsNothing);
  });

  testWidgets('owns up to guessing when nothing has been timed', (
    tester,
  ) async {
    final ingest = FakeBulkIngestRepo()
      ..staged = fakeStagedIngest(testNewerArchiveDate);
    // An install from before the load was timed has nothing to quote.
    database = await registerTestDependencies(bulkIngestRepo: ingest);
    await openApp(tester);

    await tester.tap(find.text('Finish update'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Nothing has been timed on this machine yet'),
      findsOneWidget,
    );
  });

  testWidgets('clears out a staged download the database has already had', (
    tester,
  ) async {
    final ingest = FakeBulkIngestRepo()
      // Older than the archive on record, so it is the leftovers of an update
      // that already went in rather than one waiting to.
      ..staged = fakeStagedIngest(
        testLoadedArchiveDate.subtract(const Duration(days: 30)),
      );
    database = await registerTestDependencies(bulkIngestRepo: ingest);
    await openApp(tester);

    expect(find.text('Finish update'), findsNothing);
    expect(ingest.staged, isNull, reason: 'the leftovers were kept');
    // SEC has rebuilt the archive since, so the offer itself stands.
    expect(find.text('Update available'), findsOneWidget);
  });

  testWidgets('still offers a refresh when the staged archive was behind', (
    tester,
  ) async {
    final ingest = FakeBulkIngestRepo()
      // Newer than what is loaded, so worth loading — but SEC has rebuilt the
      // archive again since it was fetched.
      ..staged = fakeStagedIngest(
        testLoadedArchiveDate.add(const Duration(days: 30)),
      );
    database = await registerTestDependencies(bulkIngestRepo: ingest);
    await openApp(tester);

    // The database step asks before it shuts the app for minutes.
    await tester.tap(find.text('Finish update'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refresh now'));
    await tester.pump();

    ingest.finishLoad.complete();
    await tester.pumpAndSettle();

    // What went in is not the newest there is, and saying otherwise would
    // hide an update until the next launch.
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
