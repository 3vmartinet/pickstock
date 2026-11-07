import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/report/research_queue.dart';
import 'package:pickstock/ui/report/widgets/jobs_button.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

void main() {
  late AppDatabase database;
  late ResearchQueue queue;
  late Completer<void> hold;

  setUp(() async {
    database = await registerTestDependencies(withFinancials: true);
    queue = GetIt.I.get<ResearchQueue>();
    hold = Completer<void>();
  });

  tearDown(() async {
    if (!hold.isCompleted) hold.complete();
    await database.close();
    await GetIt.I.reset();
  });

  /// [count] questions answered at once, each left unopened.
  Future<void> answered(WidgetTester tester, List<String> tickers) async {
    for (final ticker in tickers) {
      queue.enqueue(
        cik: 'done-$ticker',
        ticker: ticker,
        companyName: ticker,
        insight: null,
        work: (_) async {},
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
  }

  /// Questions that run until [hold] completes: the first is answered now,
  /// the rest wait their turn.
  void owed(List<String> tickers) {
    for (final ticker in tickers) {
      queue.enqueue(
        cik: 'owed-$ticker',
        ticker: ticker,
        companyName: ticker,
        insight: null,
        work: (_) => hold.future,
      );
    }
  }

  Future<void> openApp(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1400, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PickStockApp());
    // A spinner runs while work is owed, so the frames never settle.
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('while work runs, only what is under way is counted', (
    tester,
  ) async {
    await answered(tester, ['ZETA']);
    owed(['B', 'C', 'D', 'E']);
    await openApp(tester);

    // The answer waiting to be opened is not counted while work runs.
    expect(find.byKey(jobsUnseenBadgeKey), findsNothing);
    final count = find.byKey(jobsCountBadgeKey);
    expect(
      find.descendant(of: count, matching: find.text('4')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: count, matching: find.byKey(jobsRunningMarkKey)),
      findsOneWidget,
    );

    // Inside the button, centred on it, and slid in against the spinner: its
    // end's corners on a circle an even gap outside the ring.
    final button = tester.getRect(
      find.descendant(
        of: find.byType(JobsButton),
        matching: find.byType(GhostButton),
      ),
    );
    final pill = tester.getRect(count);
    final ring = tester.getRect(
      find.descendant(
        of: find.byType(JobsButton),
        matching: find.byType(CircularProgressIndicator),
      ),
    );
    expect(pill.left, greaterThan(button.left));
    expect(pill.center.dy, closeTo(button.center.dy, 0.5));
    expect(
      (ring.center - Offset(pill.right, pill.top)).distance,
      closeTo(
        ring.width / 2 +
            ThemeRepo.jobsSpinnerStroke / 2 +
            ThemeRepo.countRingGap,
        0.5,
      ),
    );

    // A press on the count is a press on the button.
    await tester.tapAt(Offset(pill.left + 3, pill.center.dy));
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('ZETA'), findsWidgets);
  });

  testWidgets('once the work is done, the answers waiting are counted', (
    tester,
  ) async {
    await answered(tester, ['A']);
    owed(['B']);
    await openApp(tester);
    expect(find.byKey(jobsUnseenBadgeKey), findsNothing);

    hold.complete();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    final count = find.byKey(jobsUnseenBadgeKey);
    expect(
      find.descendant(of: count, matching: find.text('2')),
      findsOneWidget,
    );
    // Nothing running, so nothing to tell it apart from: plain.
    expect(find.byKey(jobsDoneMarkKey), findsNothing);
  });

  testWidgets('the list opens on the question being answered', (tester) async {
    // Newest first: the waiting questions above the running one, the
    // finished ones below — enough of either to push it out of view.
    await answered(tester, [for (var n = 0; n < 8; n++) 'DONE$n']);
    owed(['RUNNING', for (var n = 0; n < 8; n++) 'WAIT$n']);
    await openApp(tester);

    await tester.tap(find.byType(JobsButton));
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final running = find.textContaining('RUNNING');
    expect(running, findsOneWidget);
    final list = tester.getRect(
      find
          .ancestor(of: running, matching: find.byType(SingleChildScrollView))
          .first,
    );
    final row = tester.getRect(running);
    expect(row.top, greaterThanOrEqualTo(list.top));
    expect(row.bottom, lessThanOrEqualTo(list.bottom));
  });
}
