import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/sec/bulk_ingest_repo.dart';
import 'package:pickstock/ui/ingest/ingest_screen.dart';
import 'package:pickstock/ui/ingest_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

/// Pins a view model at one progress stage so the screen can be inspected.
class _StubIngestViewModel extends IngestViewModel {
  _StubIngestViewModel(this.stub, {this.rate, this.remaining});

  final IngestState stub;
  final double? rate;
  final Duration? remaining;

  @override
  IngestState get state => stub;
  @override
  double? get ratePerSecond => rate;
  @override
  Duration? get estimatedRemaining => remaining;
  @override
  Future<void> check() async {}
}

void main() {
  late AppDatabase database;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    database = await registerTestDependencies();
  });

  tearDown(() async {
    await database.close();
    await GetIt.I.reset();
  });

  Future<void> pumpAt(
    WidgetTester tester,
    IngestProgress progress, {
    double? rate,
    Duration? remaining,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<IngestViewModel>(
        // A fresh element per pump: provider would otherwise keep the notifier
        // built for the previous stage.
        key: UniqueKey(),
        create: (_) => _StubIngestViewModel(
          IngestActive(progress),
          rate: rate,
          remaining: remaining,
        ),
        child: ShadcnApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const IngestScreen(),
        ),
      ),
    );
    // flutter_animate starts its controllers from a Timer, and the running
    // stage's marker pulses forever — so advance time enough for the timers to
    // fire, but do not wait for the animation to settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('titles the panel with the running stage', (tester) async {
    await pumpAt(tester, const IngestFetchingDirectory());
    expect(find.text('Preparing your data'), findsOneWidget);
    expect(find.text('Ticker directory'), findsWidgets);

    await pumpAt(
      tester,
      const IngestDownloading(receivedBytes: 700, totalBytes: 1000),
    );
    expect(find.text('SEC bulk archive'), findsWidgets);

    await pumpAt(
      tester,
      const IngestLoading(companiesLoaded: 4300, totalCompanies: 20290),
    );
    expect(find.text('Local database'), findsWidgets);
  });

  testWidgets('the ring shows the percentage through the stage', (
    tester,
  ) async {
    await pumpAt(
      tester,
      const IngestLoading(companiesLoaded: 5000, totalCompanies: 20000),
    );

    // Behind the faint track there is a determinate arc at a quarter.
    final rings = tester
        .widgetList<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        )
        .toList();
    expect(rings.map((r) => r.value), contains(0.25));
    expect(find.text('25'), findsOneWidget);
  });

  testWidgets('reports what is done, and lists every stage', (tester) async {
    await pumpAt(
      tester,
      const IngestLoading(companiesLoaded: 4300, totalCompanies: 20290),
    );

    expect(find.text('4,300 / 20,290'), findsOneWidget);
    // All three stages are always listed, so the wait is bounded.
    expect(find.text('Ticker directory'), findsOneWidget);
    expect(find.text('SEC bulk archive'), findsOneWidget);
    expect(find.text('Local database'), findsWidgets);
  });

  testWidgets('shows throughput and how much longer it will take', (
    tester,
  ) async {
    await pumpAt(
      tester,
      const IngestDownloading(
        receivedBytes: 400 * 1048576,
        totalBytes: 1407685214,
      ),
      rate: 12.4 * 1048576,
      remaining: const Duration(minutes: 1, seconds: 20),
    );

    // Each figure sits under a heading that does not move as it changes.
    expect(find.text('Downloaded'), findsOneWidget);
    expect(find.text('400 MB / 1.31 GB'), findsOneWidget);
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('12 MB/s'), findsOneWidget);
    expect(find.text('Remaining'), findsOneWidget);
    expect(find.text('1m 20s'), findsOneWidget);
  });

  testWidgets('says seconds alone when under a minute', (tester) async {
    await pumpAt(
      tester,
      const IngestLoading(companiesLoaded: 19000, totalCompanies: 20290),
      rate: 120,
      remaining: const Duration(seconds: 11),
    );

    expect(find.text('11s'), findsOneWidget);
    expect(find.text('120/s'), findsOneWidget);
    expect(find.text('Companies read'), findsOneWidget);
  });

  testWidgets('omits throughput until there is enough to average', (
    tester,
  ) async {
    await pumpAt(
      tester,
      const IngestDownloading(receivedBytes: 1024, totalBytes: 1407685214),
    );

    // The headings are there from the start; the values they will carry are
    // placeheld, so nothing shifts when the first measurement lands.
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('Remaining'), findsOneWidget);
    expect(find.textContaining('/s'), findsNothing);
    expect(find.text('—'), findsNWidgets(2));
  });

  testWidgets('the headings hold position as the values change', (
    tester,
  ) async {
    // The point of the layout: three numbers changing at once used to shove
    // each other sideways, which is what made the line unreadable.
    List<double> headingLefts() => [
      'Downloaded',
      'Speed',
      'Remaining',
    ].map((label) => tester.getRect(find.text(label)).left).toList();

    await pumpAt(
      tester,
      const IngestDownloading(
        receivedBytes: 9 * 1048576,
        totalBytes: 1407685214,
      ),
    );
    final beforeAnyMeasurement = headingLefts();

    await pumpAt(
      tester,
      const IngestDownloading(
        receivedBytes: 412 * 1048576,
        totalBytes: 1407685214,
      ),
      rate: 13 * 1048576,
      remaining: const Duration(minutes: 1, seconds: 14),
    );
    expect(headingLefts(), beforeAnyMeasurement);

    await pumpAt(
      tester,
      const IngestDownloading(
        receivedBytes: 1300 * 1048576,
        totalBytes: 1407685214,
      ),
      rate: 9 * 1048576,
      remaining: const Duration(seconds: 8),
    );
    expect(headingLefts(), beforeAnyMeasurement);
  });

  testWidgets('shows the amount downloaded at human scale', (tester) async {
    await pumpAt(
      tester,
      const IngestDownloading(
        receivedBytes: 412 * 1048576,
        totalBytes: 1407685214,
      ),
    );
    expect(find.text('412 MB / 1.31 GB'), findsOneWidget);
  });
}
