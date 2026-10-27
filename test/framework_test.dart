import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/research/framework_question.dart';
import 'package:pickstock/data/snapshot/report_tab.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/research/ollama_repo.dart';
import 'package:pickstock/repo/research/web_search_repo.dart';
import 'package:pickstock/ui/report/research_queue.dart';
import 'package:pickstock/ui/report/widgets/jobs_button.dart';
import 'package:pickstock/ui/snapshot/widgets/framework/framework_question_card.dart';
import 'package:pickstock/ui/snapshot/widgets/framework/framework_scorecard.dart';
import 'package:pickstock/ui/snapshot/widgets/snapshot_report.dart';
import 'package:pickstock/ui/watchlist/widgets/add_to_watchlist_button.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

/// Wide enough for the list and a report side by side, and tall enough for
/// the scorecard and the first cards under it.
const Size _wideSize = Size(1600, 1400);

const String _tenK = 'https://www.sec.gov/Archives/edgar/data/320193/10k.htm';

void main() {
  late AppDatabase database;
  late FakeOllamaRepo research;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    research = FakeOllamaRepo(search: FakeWebSearchRepo(isConfigured: true));
    database = await registerTestDependencies(
      withFinancials: true,
      researchRepo: research,
    );
  });

  tearDown(() async {
    await database.close();
    await GetIt.I.reset();
  });

  /// A fixed run of frames, for wherever settling cannot be used: a card
  /// being answered wears an indeterminate bar, so the tree never goes quiet.
  Future<void> pumpFrames(WidgetTester tester, {int frames = 12}) async {
    for (var frame = 0; frame < frames; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openFramework(WidgetTester tester) async {
    tester.view
      ..physicalSize = _wideSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apple Inc.').first);
    await tester.pumpAndSettle();
    await openReportTab(tester, ReportTab.framework);
  }

  Future<void> run(WidgetTester tester) async {
    await tester.tap(find.text('Run the seven questions'));
    await pumpFrames(tester);
  }

  testWidgets('a fourth tab lays out all seven before anything is asked', (
    tester,
  ) async {
    await openFramework(tester);

    expect(find.byType(FrameworkScorecard), findsOneWidget);
    expect(find.text('Not screened yet'), findsOneWidget);
    expect(find.byType(FrameworkQuestionCard), findsNWidgets(7));
    // Each card says what it will be judged on, and shows what the filings
    // already say — the second needs no model at all.
    expect(find.text('Is the business growing?'), findsOneWidget);
    expect(find.text('Look for'), findsWidgets);
    expect(find.text('From the filings'), findsWidgets);
    expect(research.screened, isEmpty);
  });

  testWidgets('one press puts all seven to the model, in order, as one task', (
    tester,
  ) async {
    await openFramework(tester);
    await run(tester);

    expect([
      for (final (question, _) in research.screened) question,
    ], FrameworkQuestion.values);
    // Each question is its own prompt, written for what it asks.
    final prompts = {
      for (final (question, prompt) in research.screened) question: prompt,
    };
    expect(prompts[FrameworkQuestion.growth], contains('quarterly results'));
    expect(prompts[FrameworkQuestion.moat], contains('unlimited capital'));
    expect(prompts[FrameworkQuestion.management], contains('insider'));
    expect(prompts[FrameworkQuestion.risk], contains('three specific things'));
    expect(prompts[FrameworkQuestion.timing], contains('catalysts'));
    for (final prompt in prompts.values) {
      expect(prompt, contains('Apple Inc. (AAPL)'));
    }

    // Seven yeses: the framework's one way onto a watchlist, offered there.
    expect(find.text('Watchlist candidate'), findsOneWidget);
    expect(find.byType(AddToWatchlistButton), findsWidgets);
    expect(find.text('Yes to growth'), findsOneWidget);
    expect(find.byType(VerdictPill), findsNWidgets(7));
  });

  testWidgets('a single No is enough to move on, and says which', (
    tester,
  ) async {
    research.frameworkAnswers = {
      FrameworkQuestion.margins: const FrameworkAnswer(
        verdict: FrameworkVerdict.no,
        headline: 'Operating margin fell from 30% to 24%',
        explanation: 'Compressing three years running.',
      ),
    };
    await openFramework(tester);
    await run(tester);

    expect(find.text('Move on'), findsOneWidget);
    expect(find.textContaining('Fails on Margins'), findsOneWidget);
    expect(find.text('Operating margin fell from 30% to 24%'), findsOneWidget);
  });

  testWidgets('an unclear answer leaves it unsettled rather than failed', (
    tester,
  ) async {
    research.frameworkAnswers = {
      FrameworkQuestion.management: const FrameworkAnswer(
        verdict: FrameworkVerdict.unclear,
        headline: 'No record of guidance could be found',
        explanation: 'The search turned up nothing either way.',
      ),
    };
    await openFramework(tester);
    await run(tester);

    expect(find.text('Not settled yet'), findsOneWidget);
    expect(find.textContaining('6 Yes, 1 unclear'), findsOneWidget);
  });

  testWidgets('evidence links to the page it was read on, or the filings', (
    tester,
  ) async {
    research
      ..frameworkSources = const [
        SearchResult(title: 'Apple 10-K', url: _tenK, content: ''),
      ]
      ..frameworkAnswers = {
        FrameworkQuestion.growth: const FrameworkAnswer(
          verdict: FrameworkVerdict.yes,
          headline: 'Revenue up 6% a year for five years',
          explanation: 'Steady.',
          points: [
            FrameworkPoint(text: 'Services grew 14%.', url: _tenK),
            FrameworkPoint(
              text: 'Revenue rose every year.',
              isFromFilings: true,
            ),
            FrameworkPoint(text: 'The brand is in fashion again.'),
          ],
        ),
      };
    await openFramework(tester);
    await run(tester);

    final growth = find.byWidgetPredicate(
      (widget) =>
          widget is FrameworkQuestionCard &&
          widget.question == FrameworkQuestion.growth,
    );
    expect(
      find.descendant(of: growth, matching: find.text('sec.gov')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: growth, matching: find.text('Filings')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: growth, matching: find.text("Model's reading")),
      findsOneWidget,
    );
    expect(
      find.descendant(of: growth, matching: find.text('Read from (1)')),
      findsOneWidget,
    );
  });

  testWidgets('one question can be asked again on its own', (tester) async {
    await openFramework(tester);
    await run(tester);
    research.screened.clear();

    final ages = find.byIcon(LucideIcons.refreshCw);
    // The scorecard's refresh runs all seven; each card's runs its own.
    await tester.ensureVisible(ages.at(1));
    await tester.pumpAndSettle();
    await tester.tap(ages.at(1));
    await pumpFrames(tester);

    expect(
      [for (final (question, _) in research.screened) question],
      [FrameworkQuestion.growth],
    );
  });

  testWidgets('a missing server fails every question at once, and says why', (
    tester,
  ) async {
    research.failure = ResearchFailure.serverUnreachable;
    await openFramework(tester);
    await run(tester);

    // Asked once, not seven times: every question after the first would
    // wait out the same timeout to fail the same way.
    expect(research.screened, hasLength(1));
    expect(find.textContaining('Not answered:'), findsWidgets);
  });

  testWidgets('a rate-limited search stops the run and says so', (
    tester,
  ) async {
    research.failure = ResearchFailure.searchRefused;
    await openFramework(tester);
    await run(tester);

    // The next question would meet the same limit; the reader is told to come
    // back rather than shown seven answers written without reading.
    expect(research.screened, hasLength(1));
    expect(find.textContaining('most likely rate limited'), findsWidgets);
  });

  testWidgets('a limit with a wait says when to come back', (tester) async {
    // What Ollama's search answered the day this was written: two hours.
    research
      ..failure = ResearchFailure.searchRefused
      ..retryAfter = const Duration(hours: 2);
    await openFramework(tester);
    await run(tester);

    expect(find.textContaining('rate limited until about'), findsWidgets);
    expect(find.textContaining('a few minutes'), findsNothing);
  });

  testWidgets('without a key there is nothing to run, but the filings show', (
    tester,
  ) async {
    await GetIt.I.reset();
    await database.close();
    database = await registerTestDependencies(
      withFinancials: true,
      researchRepo: FakeOllamaRepo(search: FakeWebSearchRepo()),
    );
    await openFramework(tester);

    expect(find.text('Run the seven questions'), findsNothing);
    expect(
      find.textContaining('neither of which is configured'),
      findsOneWidget,
    );
    expect(find.text('From the filings'), findsWidgets);
  });

  testWidgets('answers come back when the company is opened again', (
    tester,
  ) async {
    await openFramework(tester);
    await run(tester);
    await tester.tap(find.text('NVIDIA CORP').first);
    await tester.pumpAndSettle();
    expect(find.text('Yes to growth'), findsNothing);

    await tester.tap(find.text('Apple Inc.').first);
    await tester.pumpAndSettle();
    expect(find.text('Watchlist candidate'), findsOneWidget);
    expect(find.text('Yes to growth'), findsOneWidget);
  });

  testWidgets('the run is one row in the jobs list, and the way back to it', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      research.finishScreen = Completer<void>();
      await openFramework(tester);
      await run(tester);

      final queue = GetIt.I.get<ResearchQueue>();
      expect(queue.tasks, hasLength(1));
      expect(queue.tasks.single.frameworkQuestions, FrameworkQuestion.values);
      expect(find.text('Answering Is the business growing?'), findsOneWidget);
      expect(find.text('0 of 7 answered'), findsOneWidget);

      // The reader goes elsewhere while it runs.
      await tester.tap(find.text('NVIDIA CORP').first);
      await pumpFrames(tester);
      // Not `openReportTab`, which settles: the jobs button spins while the
      // run is held open, so the tree never goes quiet.
      await tester.tap(
        find.descendant(
          of: find.byType(ReportTabs),
          matching: find.text('Overview'),
        ),
      );
      await pumpFrames(tester);
      research.finishScreen!.complete();
      await pumpFrames(tester);

      await tester.tap(find.byType(JobsButton));
      await pumpFrames(tester, frames: 4);
      expect(find.text('AAPL · Run the seven questions'), findsOneWidget);
      await tester.tap(find.text('AAPL · Run the seven questions'));
      await pumpFrames(tester);

      // Back on Apple, on the framework tab, with the scorecard marked.
      expect(find.byType(FrameworkScorecard), findsOneWidget);
      expect(find.text('Watchlist candidate'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FrameworkScorecard),
          matching: find.text('Just fetched'),
        ),
        findsOneWidget,
      );
      expect(queue.tasks, isEmpty);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  group('reading the distilled reply', () {
    // Built inside each test: its HTTP client cannot be made outside one.
    late OllamaRepo repo;
    setUp(
      () => repo = OllamaRepo(search: FakeWebSearchRepo(isConfigured: true)),
    );
    const pages = ['https://a.example/one', 'https://b.example/two'];

    test('takes the JSON out of a fenced reply and links by number', () {
      final answer = repo.frameworkAnswerFrom('''
```json
{"verdict":"no","headline":"Revenue fell 1.5%","explanation":"Down.",
 "points":[{"text":"Q3 down 6%","source":2},{"text":"FY down","source":0}]}
```''', pages)!;

      expect(answer.verdict, FrameworkVerdict.no);
      expect(answer.headline, 'Revenue fell 1.5%');
      expect(answer.points.first.url, 'https://b.example/two');
      // Zero is the filings, which have no page.
      expect(answer.points.last.url, isNull);
    });

    group('crediting a point to the filings', () {
      const filings =
          'FY2025: revenue 4040.6 (-1.5% y/y); operating income 149.5 '
          '(3.7% margin); debt 1613.8\n'
          'FY2025 includes a non-cash write-down (impairment) of 738.1. '
          'Before it, operating income was 887.6 (22.0% margin).';

      FrameworkPoint point(String text) => repo
          .frameworkAnswerFrom(
            '{"headline":"h","points":[{"text":"$text","source":0}]}',
            pages,
            filings: filings,
          )!
          .points
          .single;

      test('only where it quotes one of their figures', () {
        expect(
          point('Margin was 22.0% before the write-down.').isFromFilings,
          isTrue,
        );
        // Said the way a person says it, rounded and in billions.
        expect(point('Debt stands at \$1.61 billion.').isFromFilings, isTrue);
        expect(point('Revenue was \$4,040.6 million.').isFromFilings, isTrue);
      });

      test("and otherwise marks it as the model's own reading", () {
        // The point that prompted this: claimed for the filings, in them
        // nowhere.
        expect(
          point('Geopolitical and trade tensions threaten supply.')
              .isFromFilings,
          isFalse,
        );
        // A year is in every answer and proves nothing.
        expect(point('FY2025 was a hard year.').isFromFilings, isFalse);
        expect(point('Margins fell to 31.4%.').isFromFilings, isFalse);
      });

      test('never for a point that has a page', () {
        final answer = repo.frameworkAnswerFrom(
          '{"headline":"h","points":[{"text":"Debt 1613.8","source":1}]}',
          pages,
          filings: filings,
        )!;
        expect(answer.points.single.url, pages.first);
        expect(answer.points.single.isFromFilings, isFalse);
      });
    });

    test('keeps a point but drops a link the search never returned', () {
      final answer = repo.frameworkAnswerFrom(
        '{"verdict":"yes","headline":"Fine","points":['
        '{"text":"made up","url":"https://invented.example"},'
        '{"text":"out of range","source":9},'
        '{"text":"copied","url":"https://a.example/one"},'
        '"a bare string"]}',
        pages,
      )!;

      expect(
        [for (final point in answer.points) point.url],
        [null, null, 'https://a.example/one', null],
      );
      expect(answer.points.last.text, 'a bare string');
    });

    test('reads anything but a plain yes or no as unclear', () {
      final answer = repo.frameworkAnswerFrom(
        '{"verdict":"probably","headline":"Hard to say"}',
        pages,
      )!;
      expect(answer.verdict, FrameworkVerdict.unclear);
    });

    test('gives up on a reply with no answer in it', () {
      expect(
        repo.frameworkAnswerFrom('I could not find anything.', pages),
        isNull,
      );
      expect(repo.frameworkAnswerFrom('{"verdict":"yes"}', pages), isNull);
    });
  });

  test('an answer survives being filed and read back', () {
    const answer = FrameworkAnswer(
      verdict: FrameworkVerdict.unclear,
      headline: 'h',
      explanation: 'e',
      points: [
        FrameworkPoint(text: 't', url: _tenK),
        FrameworkPoint(text: 'f', isFromFilings: true),
        FrameworkPoint(text: 'm'),
      ],
    );
    expect(FrameworkAnswer.fromJson(answer.toJson()), answer);
  });

  test('the outcome is the framework rule, applied literally', () {
    const yes = FrameworkVerdict.yes;
    expect(FrameworkOutcome.from([]), FrameworkOutcome.notStarted);
    expect(
      FrameworkOutcome.from([yes, FrameworkVerdict.no]),
      FrameworkOutcome.moveOn,
    );
    expect(FrameworkOutcome.from([yes, yes]), FrameworkOutcome.incomplete);
    expect(
      FrameworkOutcome.from(List.filled(7, yes)),
      FrameworkOutcome.watchlist,
    );
    expect(
      FrameworkOutcome.from([...List.filled(6, yes), FrameworkVerdict.unclear]),
      FrameworkOutcome.incomplete,
    );
  });
}
