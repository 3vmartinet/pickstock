import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/research/framework_question.dart';
import 'package:pickstock/data/research/framework_score.dart';
import 'package:pickstock/data/snapshot/report_tab.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/repo/research/research_note_repo.dart';
import 'package:pickstock/ui/browse/framework_scores_view_model.dart';
import 'package:pickstock/ui/browse/widgets/framework_gauge.dart';
import 'package:pickstock/ui/report/research_queue.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

const String _appleCik = '0000320193';
const String _microsoftCik = '0000789019';

const Size _wideSize = Size(1600, 1000);

ResearchNoteRepo get _notes => GetIt.I.get<ResearchNoteRepo>();

/// Files [verdict] as [cik]'s answer to [question], as a framework run does.
Future<void> _answer(
  String cik,
  FrameworkQuestion question,
  FrameworkVerdict verdict,
) => _notes.saveAnswer(
  cik: cik,
  kind: question.noteKind,
  text: jsonEncode(
    FrameworkAnswer(
      verdict: verdict,
      headline: 'Answered',
      explanation: '',
    ).toJson(),
  ),
  sources: const [],
);

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  late AppDatabase database;

  setUp(() async {
    database = await registerTestDependencies(withFinancials: true);
  });

  tearDown(() async {
    await database.close();
    await GetIt.I.reset();
  });

  Future<void> until(bool Function() condition) async {
    for (var tries = 0; tries < 40 && !condition(); tries++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  test('counts the yeses among the answers on file', () async {
    for (final question in FrameworkQuestion.values.take(5)) {
      await _answer(_appleCik, question, FrameworkVerdict.yes);
    }
    await _answer(_appleCik, FrameworkQuestion.risk, FrameworkVerdict.unclear);

    final viewModel = FrameworkScoresViewModel();
    addTearDown(viewModel.dispose);
    await until(() => viewModel.scoreFor(_appleCik) != null);

    final score = viewModel.scoreFor(_appleCik)!;
    expect(score.satisfied, 5);
    expect(score.answered, 6);
    expect(score.outcome, FrameworkOutcome.incomplete);
    // Never asked, so no gauge at all rather than one at nought.
    expect(viewModel.scoreFor(_microsoftCik), isNull);
  });

  test('a single no puts the company out, whatever else passed', () async {
    for (final question in FrameworkQuestion.values.take(6)) {
      await _answer(_appleCik, question, FrameworkVerdict.yes);
    }
    await _answer(_appleCik, FrameworkQuestion.timing, FrameworkVerdict.no);

    final viewModel = FrameworkScoresViewModel();
    addTearDown(viewModel.dispose);
    await until(() => viewModel.scoreFor(_appleCik) != null);

    expect(viewModel.scoreFor(_appleCik)!.satisfied, 6);
    expect(viewModel.scoreFor(_appleCik)!.outcome, FrameworkOutcome.moveOn);
  });

  test('picks up answers a framework run files', () async {
    final viewModel = FrameworkScoresViewModel();
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(viewModel.scoreFor(_appleCik), isNull);

    GetIt.I.get<ResearchQueue>().enqueue(
      cik: _appleCik,
      ticker: 'AAPL',
      companyName: 'Apple Inc.',
      insight: null,
      frameworkQuestions: const [FrameworkQuestion.growth],
      work: (_) =>
          _answer(_appleCik, FrameworkQuestion.growth, FrameworkVerdict.yes),
    );
    await until(() => viewModel.scoreFor(_appleCik) != null);

    expect(viewModel.scoreFor(_appleCik)?.satisfied, 1);
  });

  test('colours a score on a scale between the outcome colours', () {
    final repo = ThemeRepo();
    for (final theme in [repo.lightTheme, repo.darkTheme]) {
      // The ends are exactly the app's red and green; six of seven is not
      // painted red for the one it missed.
      expect(repo.forScore(theme, 1, outOf: 7), repo.negative(theme));
      expect(repo.forScore(theme, 7, outOf: 7), repo.positive(theme));
      expect(repo.forScore(theme, 6, outOf: 7), isNot(repo.negative(theme)));
      // Every score from one to seven a colour of its own.
      expect({
        for (var score = 1; score <= 7; score++)
          repo.forScore(theme, score, outOf: 7),
      }, hasLength(7));
    }
  });

  testWidgets('a full score is the Framework tab\'s glyph alone, in green', (
    tester,
  ) async {
    Widget gauge(int yes) => ShadcnApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Center(
        child: FrameworkGauge(
          score: FrameworkScore(
            verdicts: {
              for (final question in FrameworkQuestion.values)
                question: question.index < yes
                    ? FrameworkVerdict.yes
                    : FrameworkVerdict.no,
            },
          ),
        ),
      ),
    );

    // The glyph alone, in the full score's green, and no pie under it.
    await tester.pumpWidget(gauge(7));
    final mark = find.byIcon(ReportTab.framework.icon);
    expect(mark, findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FrameworkGauge),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
    final theme = Theme.of(tester.element(mark));
    expect(
      tester.widget<Icon>(mark).color,
      GetIt.I.get<ThemeRepo>().positive(theme),
    );

    await tester.pumpWidget(gauge(6));
    expect(find.byIcon(ReportTab.framework.icon), findsNothing);
  });

  testWidgets('a tile shows the gauge in place of its figure', (tester) async {
    tester.view
      ..physicalSize = _wideSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      for (final question in FrameworkQuestion.values.take(4)) {
        await _answer(_appleCik, question, FrameworkVerdict.yes);
      }
    });

    await tester.pumpWidget(const PickStockApp());
    // The stored answers are read in real time, outside the fake clock.
    for (var turn = 0; turn < 5; turn++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    final gauge = find.byKey(frameworkGaugeKey(_appleCik));
    expect(gauge, findsOneWidget);
    expect(tester.widget<FrameworkGauge>(gauge).score.satisfied, 4);
    // Asked nothing, so it keeps its figure.
    expect(find.byKey(frameworkGaugeKey(_microsoftCik)), findsNothing);
  });
}
