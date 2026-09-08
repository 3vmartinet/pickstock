import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/research/ollama_repo.dart';
import 'package:pickstock/repo/research/web_search_repo.dart';
import 'package:pickstock/ui/report/research_queue.dart';
import 'package:pickstock/ui/report/widgets/jobs_button.dart';
import 'package:pickstock/ui/snapshot/widgets/company_insight_card.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

/// Wide enough for the list and a report side by side, and tall enough that
/// the block at the foot of the overview is on screen.
const Size _wideSize = Size(1600, 1400);

const ResearchAnswer _answer = ResearchAnswer(
  text: 'Apple designs and sells consumer hardware.',
  sources: [
    SearchResult(
      title: 'Apple Newsroom',
      url: 'https://www.apple.com/newsroom/',
      content: 'x',
    ),
  ],
);

void main() {
  late AppDatabase database;
  late FakeOllamaRepo research;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    research = FakeOllamaRepo(search: FakeWebSearchRepo(isConfigured: true))
      ..answer = _answer;
    database = await registerTestDependencies(
      withFinancials: true,
      researchRepo: research,
    );
  });

  tearDown(() async {
    await database.close();
    await GetIt.I.reset();
  });

  /// The app ships for macOS, where shadcn presents the panel as a popover.
  /// On the platform a widget test reports by default it is a mobile bottom
  /// sheet instead — a different widget, dismissed differently — so a panel
  /// exercised without this is not the panel the app shows.
  Future<void> onDesktop(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  /// Settles the frames around the panel without `pumpAndSettle`, which never
  /// returns while a popover is up: it re-reads its anchor every frame.
  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// A fixed run of frames, standing in for settling wherever settling cannot
  /// be used: the block being answered wears an indeterminate progress bar,
  /// and an open popover re-reads its anchor, so neither tree goes quiet.
  Future<void> pumpFrames(WidgetTester tester, {int frames = 12}) async {
    for (var frame = 0; frame < frames; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Clicks with frames between press and release, as a hand does. `tap`
  /// sends both in one go, which hides anything depending on a rebuild
  /// landing in between — and a panel that reopened itself is exactly that.
  Future<void> click(WidgetTester tester, Finder finder) async {
    final gesture = await tester.startGesture(tester.getCenter(finder));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));
    await gesture.up();
    await pumpPanel(tester);
  }

  Future<void> openApp(WidgetTester tester) async {
    tester.view
      ..physicalSize = _wideSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();
  }

  Future<void> openCompany(WidgetTester tester, String name) async {
    await tester.tap(find.text(name).first);
    await tester.pumpAndSettle();
  }

  /// Presses one of the three questions.
  ///
  /// Explicit pumps, not `pumpAndSettle`: the block being answered wears an
  /// indeterminate progress bar, so with a question held open the tree never
  /// goes quiet.
  Future<void> ask(WidgetTester tester, String action) async {
    await tester.ensureVisible(find.text(action));
    await pumpPanel(tester);
    await tester.tap(find.text(action));
    await pumpPanel(tester);
  }

  /// Opens a company while a question is in flight, for the same reason.
  ///
  /// A fixed run of frames stands in for settling: the report is several
  /// asynchronous hops from the database, and each pump advances one.
  Future<void> openBusyCompany(WidgetTester tester, String name) async {
    await tester.tap(find.text(name).first);
    await pumpFrames(tester);
  }

  /// Presses the reports button, found by type rather than by its glyph: with
  /// anything running it wears a spinner instead of one.
  Future<void> openPanel(WidgetTester tester) async {
    await click(tester, find.byType(JobsButton));
  }

  testWidgets('a second press on the reports button closes its panel', (
    tester,
  ) async {
    await onDesktop(() async {
      await openApp(tester);
      await openPanel(tester);
      expect(find.text('Reports'), findsOneWidget);

      // The press that dismisses a popover used to carry on to the button
      // underneath, which opened it again — so the panel could not be shut
      // with the control that opened it.
      await openPanel(tester);
      expect(find.text('Reports'), findsNothing);
    });
  });

  testWidgets('questions wait their turn rather than running together', (
    tester,
  ) async {
    research.finishAsk = Completer<void>();
    await openApp(tester);
    await openCompany(tester, 'Apple Inc.');
    await ask(tester, 'Describe the business');
    await openBusyCompany(tester, 'NVIDIA CORP');
    await ask(tester, 'Describe the business');

    // One in flight. The other has not been put to the model at all: a local
    // model answering two at once answers both at half the speed.
    expect(research.questions, hasLength(1));
    expect(research.questions.single, contains('Apple Inc.'));

    // And the report says which of the two it is, rather than both claiming
    // to be reading.
    expect(find.text('Queued'), findsOneWidget);

    await onDesktop(() async {
      await openPanel(tester);
      expect(find.text('AAPL · Describe the business'), findsOneWidget);
      expect(find.text('NVDA · Describe the business'), findsOneWidget);
      expect(find.text('Searching and reading…'), findsOneWidget);
      expect(find.text('Waiting its turn'), findsOneWidget);
    });

    // And the app bar says so without being opened: the glyph gives way to a
    // spinner while anything is owed.
    expect(find.byIcon(LucideIcons.listChecks), findsNothing);

    research.finishAsk!.complete();
    await pumpFrames(tester);
    // The line moves on by itself, without a second press.
    expect(research.questions, hasLength(2));
    expect(research.questions.last, contains('NVIDIA'));
  });

  testWidgets('a cancelled question leaves the list and is never asked', (
    tester,
  ) async {
    research.finishAsk = Completer<void>();
    await openApp(tester);
    await openCompany(tester, 'Apple Inc.');
    await ask(tester, 'Describe the business');
    await openBusyCompany(tester, 'NVIDIA CORP');
    await ask(tester, 'Describe the business');

    final queue = GetIt.I.get<ResearchQueue>();
    final waiting = queue.tasks.firstWhere((task) => task.isPending);

    await onDesktop(() async {
      await openPanel(tester);
      await click(tester, find.byKey(researchCancelKey(waiting.id)));
      // The row goes rather than staying to say it was stopped: the list is
      // what is still owed, and a cancelled question is owed nothing.
      expect(find.text('NVDA · Describe the business'), findsNothing);
      expect(find.text('AAPL · Describe the business'), findsOneWidget);
    });

    research.finishAsk!.complete();
    await pumpFrames(tester);
    // Never put to the model at all.
    expect(research.questions, hasLength(1));
    expect(research.questions.single, contains('Apple Inc.'));
  });

  testWidgets('cancelling the running question frees the line for the next', (
    tester,
  ) async {
    research.finishAsk = Completer<void>();
    await openApp(tester);
    await openCompany(tester, 'Apple Inc.');
    await ask(tester, 'Describe the business');
    await openBusyCompany(tester, 'NVIDIA CORP');
    await ask(tester, 'Describe the business');

    final queue = GetIt.I.get<ResearchQueue>();
    final running = queue.tasks.firstWhere((task) => task.isRunning);

    await onDesktop(() async {
      await openPanel(tester);
      await click(tester, find.byKey(researchCancelKey(running.id)));
    });
    await pumpFrames(tester);

    // The one that was waiting is put to the model without waiting for an
    // answer nobody wants any more.
    expect(research.questions, hasLength(2));
    expect(research.questions.last, contains('NVIDIA'));
    expect(queue.tasks.any((task) => task.ticker == 'AAPL'), isFalse);
  });

  testWidgets('the button counts the queue once it is worth counting', (
    tester,
  ) async {
    research
      ..finishAsk = Completer<void>()
      ..finishEvents = Completer<void>();
    await openApp(tester);
    await openCompany(tester, 'Apple Inc.');

    await ask(tester, 'Describe the business');
    await ask(tester, 'Fetch latest news');
    // Two outstanding, and no count: the spinner already says something is
    // running, and a badge reading "2" beside it says it a second time.
    expect(find.byKey(jobsCountBadgeKey), findsNothing);

    await openBusyCompany(tester, 'NVIDIA CORP');
    await ask(tester, 'Describe the business');

    // Three, which the spinner cannot say.
    expect(
      find.descendant(
        of: find.byKey(jobsCountBadgeKey),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );

    // And it counts back down as the line clears.
    research.finishEvents!.complete();
    research.finishAsk!.complete();
    await pumpFrames(tester);
    expect(find.byKey(jobsCountBadgeKey), findsNothing);
    expect(find.byIcon(LucideIcons.listChecks), findsOneWidget);
  });

  testWidgets('a finished question is the way back to its answer', (
    tester,
  ) async {
    research.finishAsk = Completer<void>();
    await openApp(tester);
    await openCompany(tester, 'Apple Inc.');
    await ask(tester, 'Describe the business');
    // The reader moves on while the model reads, which is the whole reason
    // the row exists.
    await openBusyCompany(tester, 'NVIDIA CORP');

    research.finishAsk!.complete();
    await pumpFrames(tester);

    await onDesktop(() async {
      await openPanel(tester);
      expect(find.text('Ready — open it'), findsOneWidget);
      await click(tester, find.text('AAPL · Describe the business'));
    });
    await pumpFrames(tester);

    // Back on Apple, on the tab the question was asked from, with the answer
    // in the block that asked it.
    expect(find.textContaining('Apple designs and sells'), findsOneWidget);
    // And marked, because a report is a dozen cards and only one of them is
    // what the trip was for.
    expect(find.text('Just fetched'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CompanyInsightCard),
        matching: find.text('Just fetched'),
      ),
      findsOneWidget,
    );

    // Collected, so the row has nothing left to say.
    expect(GetIt.I.get<ResearchQueue>().tasks, isEmpty);
  });
}
