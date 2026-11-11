import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/research/framework_question.dart';
import 'package:pickstock/data/snapshot/report_tab.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/research/research_note_repo.dart';
import 'package:pickstock/ui/snapshot/widgets/framework/framework_question_card.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

/// Wide enough for the list and a report side by side, and tall enough for
/// the scorecard and the first cards under it.
const Size _wideSize = Size(1600, 1400);

const String _appleCik = '0000320193';

const String _disagreed = "The model's reading of its research was no.";

/// Files [answer] as Apple's answer on cash, as a framework run would have.
Future<void> _fileCash(FrameworkAnswer answer) =>
    GetIt.I.get<ResearchNoteRepo>().saveAnswer(
      cik: _appleCik,
      kind: FrameworkQuestion.cash.noteKind,
      text: jsonEncode(answer.toJson()),
      sources: const [],
    );

/// The fixture's cash from operations is 1.12x its profit and positive every
/// year, so the filings, read now, answer cash yes. Each test files an
/// answer as it might have been filed on another day, and the card compares
/// the model's own reading with the filings as they read today.
void main() {
  late AppDatabase database;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    database = await registerTestDependencies(withFinancials: true);
  });

  tearDown(() async {
    await database.close();
    await GetIt.I.reset();
  });

  Future<Finder> openCash(WidgetTester tester) async {
    tester.view
      ..physicalSize = _wideSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apple Inc.').first);
    await tester.pumpAndSettle();
    await openReportTab(tester, ReportTab.framework);
    final card = find.byWidgetPredicate(
      (widget) =>
          widget is FrameworkQuestionCard &&
          widget.question == FrameworkQuestion.cash,
    );
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    return card;
  }

  testWidgets('says so where the model read it differently from the filings', (
    tester,
  ) async {
    await tester.runAsync(
      () => _fileCash(
        const FrameworkAnswer(
          verdict: FrameworkVerdict.yes,
          modelVerdict: FrameworkVerdict.no,
          headline: 'Cash flow fell short of profit last year',
          explanation: '',
        ),
      ),
    );
    final card = await openCash(tester);

    expect(
      find.descendant(of: card, matching: find.text(_disagreed)),
      findsOneWidget,
    );
  });

  testWidgets('says nothing where the model agrees with the filings as they '
      'read now, whatever they said when it was filed', (tester) async {
    // Filed on a day the filings answered no; they have come round to the
    // model's yes since, so there is no disagreement left to report.
    await tester.runAsync(
      () => _fileCash(
        const FrameworkAnswer(
          verdict: FrameworkVerdict.no,
          modelVerdict: FrameworkVerdict.yes,
          headline: 'Cash flow backs the profit',
          explanation: '',
        ),
      ),
    );
    final card = await openCash(tester);

    expect(
      find.descendant(
        of: card,
        matching: find.text('Cash flow backs the profit'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.textContaining("The model's reading of its research"),
      ),
      findsNothing,
    );
    // And the pill is the filings' yes, not the no filed that day.
    expect(
      tester
          .widgetList<VerdictPill>(
            find.descendant(of: card, matching: find.byType(VerdictPill)),
          )
          .single
          .verdict,
      FrameworkVerdict.yes,
    );
  });

  testWidgets('reads a note filed before the model\'s verdict was always '
      'kept as the model\'s, and says where it differs', (tester) async {
    // Filed when the filings did not settle cash: its one verdict is the
    // model's.
    await tester.runAsync(
      () => _fileCash(
        const FrameworkAnswer(
          verdict: FrameworkVerdict.no,
          headline: 'Cash flow fell short of profit last year',
          explanation: '',
        ),
      ),
    );
    final card = await openCash(tester);

    expect(
      find.descendant(of: card, matching: find.text(_disagreed)),
      findsOneWidget,
    );
  });
}
