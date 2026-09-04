import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/snapshot/report_tab.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/research/ollama_repo.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/repo/research/research_note_repo.dart';
import 'package:pickstock/repo/research/web_search_repo.dart';
import 'package:pickstock/repo/sec/sec_repo.dart';
import 'package:pickstock/ui/snapshot/widgets/company_insight_card.dart';
import 'package:pickstock/ui/snapshot/widgets/expectation_card.dart';
import 'package:pickstock/ui/snapshot/widgets/napkin_math.dart';
import 'package:pickstock/ui/snapshot/widgets/price_target_card.dart';
import 'package:pickstock/ui/snapshot/widgets/source_pane.dart';
import 'package:pickstock/ui/snapshot/widgets/valuation_grid.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

/// Wide enough for the list and a report side by side, and tall enough that a
/// block at the foot of a tab is on screen.
const Size _wideSize = Size(1600, 1400);

/// What the model comes back with: a paragraph, and the pages behind it.
const ResearchAnswer _answer = ResearchAnswer(
  text:
      'Apple designs and sells consumer hardware, and increasingly earns from '
      'services attached to it.',
  sources: [
    SearchResult(
      title: 'Apple Inc. Form 10-K',
      url: 'https://www.sec.gov/Archives/edgar/data/320193/aapl-10k.htm',
      content: 'x',
    ),
    SearchResult(
      title: 'Apple Newsroom',
      url: 'https://www.apple.com/newsroom/',
      content: 'y',
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

  Future<void> openApple(WidgetTester tester) async {
    tester.view
      ..physicalSize = _wideSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apple Inc.').first);
    await tester.pumpAndSettle();
  }

  /// Presses the CTA on whichever insight block the tab holds.
  ///
  /// Scrolled to first: the valuation tab runs well past a screen, and its
  /// block sits under the arithmetic it is a check on.
  Future<void> ask(WidgetTester tester, String action) async {
    await tester.ensureVisible(find.text(action));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  testWidgets('the overview asks what the filings do not say', (tester) async {
    await openApple(tester);

    // Framed as the question, not as a feature: the reader is told what EDGAR
    // does not carry, which is why the offer is there at all.
    expect(find.text('What the filings do not say'), findsOneWidget);
    expect(
      find.textContaining('EDGAR publishes no description'),
      findsOneWidget,
    );
    expect(find.text('Describe the business'), findsOneWidget);
    expect(research.questions, isEmpty);
  });

  testWidgets('each tab asks its own question of its own figures', (
    tester,
  ) async {
    await openApple(tester);
    // The two later questions quote the band and the implied rate, neither of
    // which exists without a price.
    await openReportTab(tester, ReportTab.valuation);
    await enterPriceByHand(tester, '250');

    await openReportTab(tester, ReportTab.overview);
    await ask(tester, 'Describe the business');
    await openReportTab(tester, ReportTab.valuation);
    await ask(tester, 'Check against the filing');
    await openReportTab(tester, ReportTab.expectations);
    await ask(tester, 'Find what is expected');

    expect(research.questions, hasLength(3));
    // The business question wants prose about the company.
    expect(research.questions[0], contains('what does'));
    expect(research.questions[0], contains('Apple Inc.'));
    // The audit hands back the very figures the band was struck from, which
    // is the whole point of asking.
    expect(research.questions[1], contains('free cash flow'));
    expect(research.questions[1], contains('non-controlling'));
    // The comparison sets the implied rate against the delivered one.
    expect(research.questions[2], contains('a year for a decade'));
    expect(research.questions[2], contains('management guided'));
  });

  testWidgets('the answer replaces the invitation in the same block', (
    tester,
  ) async {
    await openApple(tester);
    await ask(tester, 'Describe the business');

    // The question and its answer are never in two places.
    expect(find.textContaining('Apple designs and sells'), findsOneWidget);
    expect(find.textContaining('EDGAR publishes no description'), findsNothing);
    // And the offer is gone: it would be offering work already done.
    expect(find.text('Describe the business'), findsNothing);
  });

  testWidgets('cites every page it read, each one openable', (tester) async {
    await openApple(tester);
    await ask(tester, 'Describe the business');

    expect(find.text('Read from'), findsOneWidget);
    expect(find.text('Apple Inc. Form 10-K'), findsOneWidget);
    expect(find.text('Apple Newsroom'), findsOneWidget);

    // A claim a reader cannot check is one they have to take on trust.
    await tester.tap(find.text('Apple Inc. Form 10-K'));
    await tester.pumpAndSettle();
    expect(find.byType(SourcePane), findsOneWidget);
  });

  testWidgets('says every time that a model wrote it', (tester) async {
    await openApple(tester);
    await ask(tester, 'Describe the business');

    // The paragraph reads exactly like the app's own text and did not come
    // from the filings, so it says so where it is read.
    expect(find.textContaining('Written by a model'), findsOneWidget);
  });

  testWidgets('reports itself while it reads, and refuses a second press', (
    tester,
  ) async {
    research.finishAsk = Completer<void>();
    await openApple(tester);

    await tester.tap(find.text('Describe the business'));
    await tester.pump();

    expect(find.text('Reading…'), findsOneWidget);
    expect(find.byType(Progress), findsOneWidget);
    final button = find.ancestor(
      of: find.text('Reading…'),
      matching: find.byType(OutlineButton),
    );
    expect(tester.widget<OutlineButton>(button).enabled, isFalse);

    research.finishAsk!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Apple designs and sells'), findsOneWidget);
    expect(research.questions, hasLength(1));
  });

  testWidgets('names which part is missing when it cannot read', (
    tester,
  ) async {
    research.failure = ResearchFailure.serverUnreachable;
    await openApple(tester);
    await ask(tester, 'Describe the business');

    expect(find.textContaining('Start Ollama'), findsOneWidget);
  });

  testWidgets('offers nothing at all without a key', (tester) async {
    await database.close();
    await GetIt.I.reset();
    research = FakeOllamaRepo(search: FakeWebSearchRepo());
    database = await registerTestDependencies(
      withFinancials: true,
      researchRepo: research,
    );

    await openApple(tester);

    // A block that only ever explains why it cannot work is worse than none.
    expect(find.text('What the filings do not say'), findsNothing);
    expect(find.text('Describe the business'), findsNothing);
  });

  testWidgets('asks again for another company', (tester) async {
    await openApple(tester);
    await ask(tester, 'Describe the business');
    expect(find.textContaining('Apple designs and sells'), findsOneWidget);

    await tester.tap(find.text('NVIDIA CORP'));
    await tester.pumpAndSettle();

    // Last company's answer says nothing about this one, and a minute of work
    // nobody asked for is not started on their behalf.
    expect(find.textContaining('Apple designs and sells'), findsNothing);
    expect(find.text('Describe the business'), findsOneWidget);
    expect(research.questions, hasLength(1));
  });

  testWidgets('an answer already on file comes straight back', (tester) async {
    // What the last session left behind.
    final notes = MemoryResearchNoteRepo();
    await notes.saveAnswer(
      cik: '0000320193',
      kind: 'business',
      text: 'Read some time ago and kept.',
      sources: const [
        SearchResult(title: 'Form 10-K', url: 'https://sec.gov/a', content: ''),
      ],
    );
    await database.close();
    await GetIt.I.reset();
    research = FakeOllamaRepo(search: FakeWebSearchRepo(isConfigured: true))
      ..answer = _answer;
    database = await registerTestDependencies(
      withFinancials: true,
      researchRepo: research,
      researchNoteRepo: notes,
    );

    await openApple(tester);

    // On screen without being asked for, and without a minute of a local
    // model to get it back.
    expect(find.textContaining('Read some time ago'), findsOneWidget);
    expect(find.text('Form 10-K'), findsOneWidget);
    expect(research.questions, isEmpty);
    expect(find.text('Describe the business'), findsNothing);
  });

  testWidgets('a restored answer says how old it is', (tester) async {
    final notes = MemoryResearchNoteRepo();
    await notes.saveAnswer(
      cik: '0000320193',
      kind: 'business',
      text: 'Kept.',
      sources: const [],
    );
    await database.close();
    await GetIt.I.reset();
    research = FakeOllamaRepo(search: FakeWebSearchRepo(isConfigured: true))
      ..answer = _answer;
    database = await registerTestDependencies(
      withFinancials: true,
      researchRepo: research,
      researchNoteRepo: notes,
    );

    await openApple(tester);

    // A month-old answer and this morning's look identical otherwise.
    expect(find.text('just now'), findsOneWidget);
  });

  testWidgets('and can be read again on request', (tester) async {
    await openApple(tester);
    await ask(tester, 'Describe the business');
    expect(research.questions, hasLength(1));

    // The one press that is not refused: the reader is saying the answer is
    // out of date, which is the only thing the app cannot judge for them.
    await tester.tap(
      find.descendant(
        of: find.byType(CompanyInsightCard),
        matching: find.byIcon(LucideIcons.refreshCw),
      ),
    );
    await tester.pumpAndSettle();

    expect(research.questions, hasLength(2));
    expect(find.textContaining('Apple designs and sells'), findsOneWidget);
  });

  testWidgets('the audit sits under the ratios, beside the working', (
    tester,
  ) async {
    await openApple(tester);
    await openReportTab(tester, ReportTab.valuation);
    await enterPriceByHand(tester, '250');

    final grid = tester.getRect(find.byType(ValuationGrid));
    final napkin = tester.getRect(find.byType(NapkinMath));
    final audit = tester.getRect(
      find.text('Do these figures mean what they appear to?'),
    );

    // Under the ratios and level with the working, so the check on the
    // figures is read at the same height as the figures rather than a screen
    // below them.
    expect(audit.top, greaterThan(grid.top));
    expect(audit.left, lessThan(napkin.left));
    expect(audit.top, lessThan(napkin.bottom));
  });

  testWidgets('there is nothing to audit before there is a price', (
    tester,
  ) async {
    await openApple(tester);
    await openReportTab(tester, ReportTab.valuation);

    // The question quotes the cash flow and share count the band was struck
    // from, and there is no band until a price is in.
    expect(
      find.text('Do these figures mean what they appear to?'),
      findsNothing,
    );
  });

  testWidgets('the expectations pair sits level, the insight under both', (
    tester,
  ) async {
    // A record needs more than three years on file, and the fixture's Apple
    // has exactly three — so without this the targets card renders nothing and
    // the assertions below would pass against an empty box.
    GetIt.I.unregister<SecRepo>();
    GetIt.I.registerSingleton<SecRepo>(const LongHistorySecRepo());

    await openApple(tester);
    await openReportTab(tester, ReportTab.valuation);
    await enterPriceByHand(tester, '250');
    await openReportTab(tester, ReportTab.expectations);

    final targets = tester.getRect(find.byType(PriceTargetCard));
    final verdict = tester.getRect(find.byType(ExpectationCard));
    final insight = tester.getRect(find.text('What anyone else expects'));

    // Halves of one question, compared rather than read in turn.
    expect(targets.top, verdict.top);
    expect(targets.width, greaterThan(0));
    expect(verdict.left, greaterThan(targets.right - 1));
    // And what anyone else expects is set against the pair, so it comes after
    // both.
    expect(insight.top, greaterThan(targets.bottom));
    expect(insight.top, greaterThan(verdict.bottom));
  });

  testWidgets('one card alone takes the row rather than half of it', (
    tester,
  ) async {
    await openApple(tester);
    await openReportTab(tester, ReportTab.valuation);
    await enterPriceByHand(tester, '250');
    await openReportTab(tester, ReportTab.expectations);

    // The fixture has too few years for price cases, so that card has nothing
    // to show. Level with its neighbour it held half the row open for a void.
    expect(find.byType(PriceTargetCard), findsNothing);
    // The block below spans the tab, so the card matching it is full width.
    final verdict = tester.getRect(find.byType(ExpectationCard));
    final insight = tester.getRect(find.byType(CompanyInsightCard));
    expect(verdict.width, closeTo(insight.width, 1));
  });
}

/// Apple with enough years behind it to have a record, which the fixture's
/// three-year snapshot cannot support.
class LongHistorySecRepo implements SecRepo {
  const LongHistorySecRepo();

  @override
  Future<FinancialSnapshot> fetchSnapshot(String ticker) async {
    const million = 1000000.0;
    return FinancialSnapshot(
      company: const Company(
        ticker: 'AAPL',
        cik: '0000320193',
        name: 'Apple Inc.',
        sharesOutstanding: 15000 * million,
      ),
      years: [
        for (var year = 2019; year <= 2025; year++)
          FiscalYearFigures(
            fiscalYear: year,
            revenue: (200000 + (year - 2019) * 20000) * million,
            priorRevenue: year == 2019
                ? null
                : (200000 + (year - 2020) * 20000) * million,
            netIncome: 50000 * million,
            operatingIncome: 60000 * million,
            operatingCashFlow: 90000 * million,
            capitalExpenditure: 10000 * million,
            dilutedShares: 15000 * million,
          ),
      ],
    );
  }
}
