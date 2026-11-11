import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/data/research/framework_question.dart';
import 'package:pickstock/data/research/framework_score.dart';
import 'package:pickstock/data/snapshot/report_tab.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/price_repo.dart';
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

  // Microsoft has no figures in the mock filings, so its answers are scored
  // as filed: there is nothing to read the filings again from.
  test('counts the yeses among the answers on file', () async {
    for (final question in FrameworkQuestion.values.take(5)) {
      await _answer(_microsoftCik, question, FrameworkVerdict.yes);
    }
    await _answer(
      _microsoftCik,
      FrameworkQuestion.risk,
      FrameworkVerdict.unclear,
    );

    final viewModel = FrameworkScoresViewModel();
    addTearDown(viewModel.dispose);
    await until(() => viewModel.scoreFor(_microsoftCik) != null);

    final score = viewModel.scoreFor(_microsoftCik)!;
    expect(score.satisfied, 5);
    expect(score.answered, 6);
    expect(score.outcome, FrameworkOutcome.incomplete);
    // Never asked, so no gauge at all rather than one at nought.
    expect(viewModel.scoreFor(_appleCik), isNull);
  });

  test('a single no puts the company out, whatever else passed', () async {
    for (final question in FrameworkQuestion.values.take(6)) {
      await _answer(_microsoftCik, question, FrameworkVerdict.yes);
    }
    await _answer(_microsoftCik, FrameworkQuestion.timing, FrameworkVerdict.no);

    final viewModel = FrameworkScoresViewModel();
    addTearDown(viewModel.dispose);
    await until(() => viewModel.scoreFor(_microsoftCik) != null);

    expect(viewModel.scoreFor(_microsoftCik)!.satisfied, 6);
    expect(viewModel.scoreFor(_microsoftCik)!.outcome, FrameworkOutcome.moveOn);
  });

  test('picks up answers a framework run files', () async {
    final viewModel = FrameworkScoresViewModel();
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(viewModel.scoreFor(_microsoftCik), isNull);

    GetIt.I.get<ResearchQueue>().enqueue(
      cik: _microsoftCik,
      ticker: 'MSFT',
      companyName: 'Microsoft',
      insight: null,
      frameworkQuestions: const [FrameworkQuestion.growth],
      work: (_) => _answer(
        _microsoftCik,
        FrameworkQuestion.growth,
        FrameworkVerdict.yes,
      ),
    );
    await until(() => viewModel.scoreFor(_microsoftCik) != null);

    expect(viewModel.scoreFor(_microsoftCik)?.satisfied, 1);
  });

  test(
    'reads the filings and the stored price again, as the report does',
    () async {
      // Apple's mock filings settle cash as a yes, and timing against the
      // price; growth they leave to the reading.
      await _answer(_appleCik, FrameworkQuestion.cash, FrameworkVerdict.no);
      // Filed at a price below the band, since gone.
      await _answer(_appleCik, FrameworkQuestion.timing, FrameworkVerdict.yes);
      // Filed while the filings said yes over the model's no: they no longer
      // settle it, so the model's own reading is what counts.
      await _notes.saveAnswer(
        cik: _appleCik,
        kind: FrameworkQuestion.growth.noteKind,
        text: jsonEncode(
          const FrameworkAnswer(
            verdict: FrameworkVerdict.yes,
            modelVerdict: FrameworkVerdict.no,
            headline: 'Growth is stalling',
            explanation: '',
          ).toJson(),
        ),
        sources: const [],
      );

      final viewModel = FrameworkScoresViewModel();
      addTearDown(viewModel.dispose);
      await until(() => viewModel.scoreFor(_appleCik) != null);

      var score = viewModel.scoreFor(_appleCik)!;
      expect(score.verdicts[FrameworkQuestion.cash], FrameworkVerdict.yes);
      expect(score.verdicts[FrameworkQuestion.growth], FrameworkVerdict.no);
      // No price on file: unclear, not the yes filed at the old one.
      expect(
        score.verdicts[FrameworkQuestion.timing],
        FrameworkVerdict.unclear,
      );

      // Far above the band: timing moves with the price, without a run.
      await GetIt.I.get<PriceRepo>().save(_appleCik, Quote.entered(1000));
      await viewModel.reloadFigures();
      score = viewModel.scoreFor(_appleCik)!;
      expect(score.verdicts[FrameworkQuestion.timing], FrameworkVerdict.no);
    },
  );

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
    final gauge = find.byKey(frameworkGaugeKey(_appleCik));
    // The stored answers and the figures they are settled against are read
    // in real time, outside the fake clock.
    for (var turn = 0; turn < 40 && gauge.evaluate().isEmpty; turn++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    expect(gauge, findsOneWidget);
    // The four answered, and cash, which the filings settle as a yes.
    expect(tester.widget<FrameworkGauge>(gauge).score.satisfied, 5);
    // Asked nothing, so it keeps its figure.
    expect(find.byKey(frameworkGaugeKey(_microsoftCik)), findsNothing);
  });
}
