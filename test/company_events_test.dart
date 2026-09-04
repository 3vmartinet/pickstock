import 'dart:async';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/research/company_event.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/data/research/company_insight.dart';
import 'package:pickstock/repo/research/ollama_repo.dart';
import 'package:pickstock/repo/research/research_note_repo.dart';
import 'package:pickstock/ui/snapshot/widgets/company_events.dart';
import 'package:pickstock/ui/snapshot/widgets/company_header.dart';
import 'package:pickstock/ui/snapshot/widgets/source_pane.dart';
import 'package:pickstock/ui/watchlist/widgets/add_to_watchlist_button.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

/// Wide enough for the list and a report side by side.
const Size _wideSize = Size(1600, 1000);

/// Three developments as the model returns them: dated, captioned, and each
/// on a page of its own.
final List<CompanyEvent> _found = [
  CompanyEvent(
    caption: 'Settles Siri class action for \$250 million',
    url: 'https://apnews.com/article/apple-siri',
    date: DateTime(2026, 9, 2),
  ),
  CompanyEvent(
    caption: 'Introduces the M6 and M5 Ultra',
    url: 'https://www.apple.com/newsroom/2026/08/m6',
    date: DateTime(2026, 8, 25),
  ),
  CompanyEvent(
    caption: 'Overhauls EU App Store fees',
    url: 'https://thenextweb.com/news/apple-eu-fees',
    date: DateTime(2026, 8),
  ),
];

void main() {
  late AppDatabase database;
  late FakeOllamaRepo research;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    research = FakeOllamaRepo(
      search: FakeWebSearchRepo(isConfigured: true),
      events: _found,
    );
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
    await tester.tap(find.text('Apple Inc.'));
    await tester.pumpAndSettle();
  }

  Future<void> readAround(WidgetTester tester) async {
    await tester.tap(find.text('Fetch latest news'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows nothing at all until it is pressed', (tester) async {
    await openApple(tester);

    // Nothing shown until it is pressed: reading around costs a minute of a
    // local model's time.
    expect(find.text('Fetch latest news'), findsOneWidget);
    expect(find.byKey(eventsPanelKey), findsNothing);
    expect(find.textContaining('Settles Siri'), findsNothing);
    expect(research.asked, 0);
  });

  testWidgets('does not offer it at all without a key', (tester) async {
    // A build with no Ollama key has nothing to search with, and a button
    // that only ever explains itself is worse than no button.
    await database.close();
    await GetIt.I.reset();
    research = FakeOllamaRepo(search: FakeWebSearchRepo());
    database = await registerTestDependencies(
      withFinancials: true,
      researchRepo: research,
    );

    await openApple(tester);
    expect(find.text('Fetch latest news'), findsNothing);
  });

  testWidgets('lists what it found, a development to a line', (tester) async {
    await openApple(tester);
    await readAround(tester);

    expect(research.asked, 1);
    for (final event in _found) {
      expect(find.textContaining(event.caption), findsOneWidget);
    }
    // Each line carries the date it happened, so a reader can tell last week
    // from last year without opening anything.
    expect(find.textContaining('2 Sep'), findsOneWidget);
    expect(find.textContaining('25 Aug'), findsOneWidget);
  });

  testWidgets('puts them in a titled block between name and controls', (
    tester,
  ) async {
    await openApple(tester);
    await readAround(tester);

    Rect inHeader(Finder finder) => tester.getRect(
      find.descendant(of: find.byType(CompanyHeader), matching: finder),
    );

    // Its own bordered block, titled, so a reader can see where the app's own
    // figures stop and somebody else's reporting starts.
    expect(find.text('Recent developments'), findsOneWidget);

    // In the middle of the header's row: the gap between the company and the
    // controls that follow it, which the header always reserved and never
    // used.
    final panel = inHeader(find.byKey(eventsPanelKey));
    final name = inHeader(find.text('Apple Inc.'));
    final lists = inHeader(find.byType(AddToWatchlistButton));
    expect(panel.left, greaterThan(name.right));
    expect(panel.right, lessThan(lists.left));
  });

  testWidgets('offers the press under the lists', (tester) async {
    await openApple(tester);

    Rect inHeader(Finder finder) => tester.getRect(
      find.descendant(of: find.byType(CompanyHeader), matching: finder),
    );

    // With the other two things you can do to a company, rather than in the
    // middle of the title row where it left neither the name nor the captions
    // enough width.
    final lists = inHeader(find.byType(AddToWatchlistButton));
    // The button itself, not its label, which sits inside its padding.
    final button = inHeader(
      find.ancestor(
        of: find.text('Fetch latest news'),
        matching: find.byType(OutlineButton),
      ),
    );
    expect(button.top, greaterThanOrEqualTo(lists.bottom));
    expect(button.right, closeTo(lists.right, 1));
  });

  testWidgets('marks a line as something that will act, under the pointer', (
    tester,
  ) async {
    await openApple(tester);
    await readAround(tester);

    // Scoped to the header: once hovered, the tooltip repeats the caption.
    final line = find.descendant(
      of: find.byType(CompanyHeader),
      matching: find.textContaining('Settles Siri'),
    );
    final before = tester.widget<Text>(line).style;
    expect(before?.decoration, isNot(TextDecoration.underline));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(line));
    await tester.pumpAndSettle();

    // Colour and underline both change: the colour says it is live and the
    // underline says it is a link, and the cursor beside them agrees.
    final after = tester.widget<Text>(line).style;
    expect(after?.color, isNot(before?.color));
    expect(after?.decoration, TextDecoration.underline);
  });

  testWidgets('will not be pressed twice for the same company', (tester) async {
    await openApple(tester);
    await readAround(tester);

    // Spent: the answer is on screen, and asking the same question of the
    // same company again would take another minute to say the same thing.
    final button = find.ancestor(
      of: find.text('Fetch latest news'),
      matching: find.byType(OutlineButton),
    );
    expect(tester.widget<OutlineButton>(button).enabled, isFalse);

    await tester.tap(find.text('Fetch latest news'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(research.asked, 1);
  });

  testWidgets('reports itself while it is reading', (tester) async {
    research.finishEvents = Completer<void>();
    await openApple(tester);

    await tester.tap(find.text('Fetch latest news'));
    await tester.pump();

    // Says what it is doing, carries a bar along its own edge — as the archive
    // download does — and refuses a second run on top of the first.
    expect(find.text('Reading…'), findsOneWidget);
    expect(find.byType(Progress), findsOneWidget);
    // Indeterminate: a model reading the web reports no fraction of anything.
    expect(tester.widget<Progress>(find.byType(Progress)).progress, isNull);
    final button = find.ancestor(
      of: find.text('Reading…'),
      matching: find.byType(OutlineButton),
    );
    expect(tester.widget<OutlineButton>(button).enabled, isFalse);

    research.finishEvents!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Settles Siri'), findsOneWidget);
  });

  testWidgets('says which part is missing when it cannot read', (tester) async {
    research.failure = ResearchFailure.serverUnreachable;
    await openApple(tester);
    await readAround(tester);

    // Named, not merely refused: which of the several things that have to be
    // running is not is the only useful thing to say.
    expect(find.textContaining('Start Ollama'), findsOneWidget);
  });

  testWidgets('clears the news when another company is opened', (tester) async {
    await openApple(tester);
    await readAround(tester);
    expect(find.textContaining('Settles Siri'), findsOneWidget);

    await tester.tap(find.text('NVIDIA CORP'));
    await tester.pumpAndSettle();

    // Last company's news says nothing about this one, and a minute of work
    // nobody asked for is not started on their behalf.
    expect(find.textContaining('Settles Siri'), findsNothing);
    expect(research.asked, 1);
  });

  testWidgets('a headline opens its source beside the report', (tester) async {
    await openApple(tester);
    await readAround(tester);

    expect(find.byType(SourcePane), findsNothing);
    await tester.tap(find.textContaining('Settles Siri').first);
    await tester.pumpAndSettle();

    // Read next to the figures it is about, rather than in another
    // application with the figures behind it.
    expect(find.byType(SourcePane), findsOneWidget);
    // Named by its publisher: a headline's link runs to a hundred characters
    // of path, and which paper it is is the part worth reading.
    expect(find.text('apnews.com'), findsOneWidget);
    // The report is still there beside it.
    expect(find.byType(CompanyHeader), findsOneWidget);
  });

  testWidgets('the pane gives way to a second headline', (tester) async {
    await openApple(tester);
    await readAround(tester);

    await tester.tap(find.textContaining('Settles Siri').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Introduces the M6').first);
    await tester.pumpAndSettle();

    // One pane, showing the second source: two panes of two headlines would
    // leave no room for the report they are about.
    expect(find.byType(SourcePane), findsOneWidget);
    expect(find.text('www.apple.com'), findsOneWidget);
    expect(find.text('apnews.com'), findsNothing);
  });

  testWidgets('the pane can be closed', (tester) async {
    await openApple(tester);
    await readAround(tester);
    await tester.tap(find.textContaining('Settles Siri').first);
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(SourcePane),
        matching: find.byIcon(LucideIcons.x),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SourcePane), findsNothing);
  });

  testWidgets('handing the page to the browser gives up the pane', (
    tester,
  ) async {
    await openApple(tester);
    await readAround(tester);
    await tester.tap(find.textContaining('Settles Siri').first);
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(SourcePane),
        matching: find.byIcon(LucideIcons.externalLink),
      ),
    );
    await tester.pumpAndSettle();

    // Two copies of the same page, one of them behind the app, is worse than
    // either on its own.
    expect(find.byType(SourcePane), findsNothing);
  });

  testWidgets('says so where there is no web view to be had', (tester) async {
    // Which is every test: the plugin is not registered, so the controller
    // cannot be built. The pane says where the page is instead of showing a
    // blank rectangle.
    await openApple(tester);
    await readAround(tester);
    await tester.tap(find.textContaining('Settles Siri').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('cannot be shown here'), findsOneWidget);
  });

  testWidgets('the pane closes when another company is selected', (
    tester,
  ) async {
    await openApple(tester);
    await readAround(tester);
    await tester.tap(find.textContaining('Settles Siri').first);
    await tester.pumpAndSettle();
    expect(find.byType(SourcePane), findsOneWidget);

    await tester.tap(find.text('NVIDIA CORP'));
    await tester.pumpAndSettle();

    // An article about Apple beside NVIDIA's figures reads as though it were
    // about NVIDIA, which is worse than no article.
    expect(find.byType(SourcePane), findsNothing);
  });

  testWidgets('and stays shut on the way back', (tester) async {
    await openApple(tester);
    await readAround(tester);
    await tester.tap(find.textContaining('Settles Siri').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('NVIDIA CORP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apple Inc.').first);
    await tester.pumpAndSettle();

    // Closed means closed: a pane that sprang back would be showing something
    // the reader had already navigated away from.
    expect(find.byType(SourcePane), findsNothing);
  });

  testWidgets('but survives reading a second headline about the same one', (
    tester,
  ) async {
    await openApple(tester);
    await readAround(tester);
    await tester.tap(find.textContaining('Settles Siri').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Introduces the M6').first);
    await tester.pumpAndSettle();

    // The company has not changed, so nothing should have closed.
    expect(find.byType(SourcePane), findsOneWidget);
    expect(find.text('www.apple.com'), findsOneWidget);
  });

  testWidgets('news already on file comes straight back, with its age', (
    tester,
  ) async {
    final notes = MemoryResearchNoteRepo();
    await notes.saveEvents(
      cik: '0000320193',
      kind: eventsNoteKind,
      events: _found,
    );
    await database.close();
    await GetIt.I.reset();
    research = FakeOllamaRepo(
      search: FakeWebSearchRepo(isConfigured: true),
      events: _found,
    );
    database = await registerTestDependencies(
      withFinancials: true,
      researchRepo: research,
      researchNoteRepo: notes,
    );

    await openApple(tester);

    // On screen without being asked for, so re-opening a company does not
    // cost a minute of a local model to see what it already knew.
    expect(find.textContaining('Settles Siri'), findsOneWidget);
    expect(find.text('just now'), findsOneWidget);
    expect(research.asked, 0);
    // And the press is spent, as it is after a fresh read.
    expect(
      tester
          .widget<OutlineButton>(
            find.ancestor(
              of: find.text('Fetch latest news'),
              matching: find.byType(OutlineButton),
            ),
          )
          .enabled,
      isFalse,
    );
  });

  testWidgets('the news can be read again on request', (tester) async {
    await openApple(tester);
    await readAround(tester);
    expect(research.asked, 1);

    await tester.tap(
      find.descendant(
        of: find.byType(CompanyEvents),
        matching: find.byIcon(LucideIcons.refreshCw),
      ),
    );
    await tester.pumpAndSettle();

    expect(research.asked, 2);
    expect(find.textContaining('Settles Siri'), findsOneWidget);
  });
}
