import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/research/framework_layout.dart';
import 'package:pickstock/data/snapshot/report_tab.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/settings/settings_repo.dart';
import 'package:pickstock/ui/snapshot/widgets/framework/framework_carousel_view.dart';
import 'package:pickstock/ui/snapshot/widgets/framework/framework_layout_toggle.dart';
import 'package:pickstock/ui/snapshot/widgets/framework/framework_question_card.dart';
import 'package:pickstock/ui/snapshot/widgets/framework/framework_scorecard.dart';
import 'package:pickstock/ui/snapshot/widgets/framework/framework_vertical_scorecard.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

const Size _wideSize = Size(1600, 1400);

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

  test('SettingsRepo persists frameworkLayout and collapsed preferences', () async {
    final settings = GetIt.I.get<SettingsRepo>();
    expect(settings.frameworkLayout, FrameworkLayout.list);
    expect(settings.frameworkVerticalCollapsed, false);

    await settings.setFrameworkLayout(FrameworkLayout.carousel);
    expect(settings.frameworkLayout, FrameworkLayout.carousel);

    await settings.setFrameworkLayout(FrameworkLayout.verticalPanel);
    expect(settings.frameworkLayout, FrameworkLayout.verticalPanel);

    await settings.setFrameworkVerticalCollapsed(true);
    expect(settings.frameworkVerticalCollapsed, true);

    await settings.setFrameworkVerticalCollapsed(false);
    expect(settings.frameworkVerticalCollapsed, false);

    await settings.setFrameworkLayout(FrameworkLayout.list);
    expect(settings.frameworkLayout, FrameworkLayout.list);
  });

  testWidgets('framework tab includes layout toggle with rows3 icon and defaults to list view', (
    tester,
  ) async {
    await openFramework(tester);

    expect(find.byType(FrameworkLayoutToggle), findsOneWidget);
    // List view icon is rows3 (3 stacked rows/lines)
    expect(find.byIcon(LucideIcons.rows3), findsOneWidget);
    expect(find.byType(FrameworkScorecard), findsOneWidget);
    expect(find.byType(FrameworkQuestionCard), findsNWidgets(7));
    expect(find.byType(FrameworkCarouselView), findsNothing);
    expect(find.byType(FrameworkVerticalScorecard), findsNothing);
  });

  testWidgets('switching to carousel layout uses scorecard as selector without extra pager view', (
    tester,
  ) async {
    await openFramework(tester);

    // Switch to carousel layout.
    final carouselToggle = find.byIcon(LucideIcons.galleryHorizontal);
    expect(carouselToggle, findsOneWidget);
    await tester.tap(carouselToggle);
    await tester.pumpAndSettle();

    expect(find.byType(FrameworkCarouselView), findsOneWidget);
    expect(find.byType(FrameworkScorecard), findsOneWidget);
    // Carousel shows 1 question card at a time.
    expect(find.byType(FrameworkQuestionCard), findsOneWidget);
    expect(find.text('Is the business growing?'), findsOneWidget);

    // No extra pager controls view (e.g. chevrons or counter) in the carousel view.
    expect(find.byIcon(LucideIcons.chevronLeft), findsNothing);
    expect(find.byIcon(LucideIcons.chevronRight), findsNothing);

    // Clicking step 4 in the top scorecard directly selects question 4 (Margins).
    await tester.tap(find.text('Margins').first);
    await tester.pumpAndSettle();

    expect(find.byType(FrameworkQuestionCard), findsOneWidget);
    expect(find.text('Are margins improving or declining?'), findsOneWidget);

    // Clicking step 2 in the top scorecard directly selects question 2 (Moat).
    await tester.tap(find.text('Moat').first);
    await tester.pumpAndSettle();

    expect(find.byType(FrameworkQuestionCard), findsOneWidget);
    expect(find.text('Can they defend their position?'), findsOneWidget);
  });

  testWidgets('vertical pane layout is sticky and supports collapsed/expanded modes', (
    tester,
  ) async {
    await openFramework(tester);

    // Switch to vertical panel layout.
    final verticalToggle = find.byIcon(LucideIcons.layoutPanelLeft);
    expect(verticalToggle, findsOneWidget);
    await tester.tap(verticalToggle);
    await tester.pumpAndSettle();

    expect(find.byType(FrameworkVerticalScorecard), findsOneWidget);
    expect(find.byType(FrameworkScorecard), findsNothing);
    expect(find.byType(FrameworkCarouselView), findsNothing);

    // In expanded mode (default), all 7 answer cards are displayed.
    expect(find.byType(FrameworkQuestionCard), findsNWidgets(7));

    // Vertical steps list includes labels.
    expect(find.text('1. Growth'), findsOneWidget);
    expect(find.text('2. Moat'), findsOneWidget);
    expect(find.text('3. Management'), findsOneWidget);
    expect(find.text('4. Margins'), findsOneWidget);
    expect(find.text('5. Cash'), findsOneWidget);
    expect(find.text('6. Risk'), findsOneWidget);
    expect(find.text('7. Timing'), findsOneWidget);

    // Switch to collapsed mode using the collapse button.
    final collapseBtn = find.byIcon(LucideIcons.listCollapse);
    expect(collapseBtn, findsOneWidget);
    await tester.tap(collapseBtn);
    await tester.pumpAndSettle();

    // In collapsed mode, only the focused question card is shown.
    expect(find.byType(FrameworkQuestionCard), findsOneWidget);

    // Clicking question 3 in vertical scorecard switches focused question to question 3.
    await tester.tap(find.text('3. Management').first);
    await tester.pumpAndSettle();

    expect(find.byType(FrameworkQuestionCard), findsOneWidget);
    expect(find.text('Is management competent?'), findsOneWidget);

    // Switch back to expanded mode.
    // The expanded button uses rows3. In vertical layout, there is rows3 in the layout toggle
    // and rows3 in the expand/collapse toggle. Tap the expand button in the actions.
    final expandBtn = find.descendant(
      of: find.byType(FrameworkVerticalScorecard),
      matching: find.byIcon(LucideIcons.rows3),
    );
    // Tap the expand button (which is in the expand/collapse ButtonGroup).
    await tester.tap(expandBtn.last);
    await tester.pumpAndSettle();

    // All 7 answer cards are back.
    expect(find.byType(FrameworkQuestionCard), findsNWidgets(7));
  });

  testWidgets('switching back to list layout restores single column list', (
    tester,
  ) async {
    await openFramework(tester);

    // Switch to vertical.
    await tester.tap(find.byIcon(LucideIcons.layoutPanelLeft));
    await tester.pumpAndSettle();
    expect(find.byType(FrameworkVerticalScorecard), findsOneWidget);

    // Switch back to list using the rows3 icon in the layout toggle.
    final listToggle = find.descendant(
      of: find.byType(FrameworkLayoutToggle),
      matching: find.byIcon(LucideIcons.rows3),
    );
    await tester.tap(listToggle);
    await tester.pumpAndSettle();

    expect(find.byType(FrameworkScorecard), findsOneWidget);
    expect(find.byType(FrameworkVerticalScorecard), findsNothing);
    expect(find.byType(FrameworkQuestionCard), findsNWidgets(7));
  });

  testWidgets('switching companies resets focused question to question 1', (
    tester,
  ) async {
    await openFramework(tester);

    // Switch to vertical layout and collapsed mode.
    await tester.tap(find.byIcon(LucideIcons.layoutPanelLeft));
    await tester.pumpAndSettle();

    final collapseBtn = find.byIcon(LucideIcons.listCollapse);
    expect(collapseBtn, findsOneWidget);
    await tester.tap(collapseBtn);
    await tester.pumpAndSettle();

    // Select question 3.
    await tester.tap(find.text('3. Management').first);
    await tester.pumpAndSettle();
    expect(find.text('Is management competent?'), findsOneWidget);

    // Switch to another company from the directory list.
    await tester.tap(find.text('NVIDIA CORP'));
    await tester.pumpAndSettle();

    // Focused question should have refreshed to Question 1: Growth.
    expect(find.text('Is the business growing?'), findsOneWidget);
  });
}
