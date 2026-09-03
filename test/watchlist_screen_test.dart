import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/ui/watchlist/widgets/watchlist_dot.dart';
import 'package:pickstock/ui/watchlist/widgets/watchlist_editor.dart';
import 'package:pickstock/ui/watchlist/widgets/watchlist_star.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

const Size _wideSize = Size(1600, 1200);

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

  Future<void> openHome(WidgetTester tester) async {
    tester.view
      ..physicalSize = _wideSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();
  }

  /// Runs [body] with the platform reported as macOS.
  ///
  /// The app ships for macOS and Linux, where the list menu is a popover. On
  /// the platform a widget test reports by default it is a bottom sheet
  /// instead, which dismisses differently — so a menu exercised without this
  /// is not the menu the app shows.
  Future<void> onDesktop(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  /// Settles the frames after opening or closing a menu. Not `pumpAndSettle`:
  /// the popover re-reads its anchor's position every frame while it is up.
  Future<void> pumpMenu(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> openApple(WidgetTester tester) async {
    await openHome(tester);
    await tester.tap(find.text('Apple Inc.'));
    await tester.pumpAndSettle();
  }

  testWidgets('starts on the whole directory, not a list', (tester) async {
    await openHome(tester);

    expect(find.text('All companies'), findsOneWidget);
    expect(find.text('${testTickers.length} matches'), findsOneWidget);
  });

  testWidgets('starring a company marks it on the list too', (tester) async {
    await openApple(tester);

    expect(find.byType(WatchlistStar), findsOneWidget);
    // No dot on the tile until the company is followed.
    expect(find.byType(WatchlistDot), findsNothing);

    await tester.tap(find.byType(WatchlistStar));
    await tester.pumpAndSettle();

    // The report and the tile beside it agree, without either telling the
    // other: both read the one view model.
    expect(find.byType(WatchlistDot), findsWidgets);
  });

  testWidgets('filtering to a list narrows the directory to it', (
    tester,
  ) async {
    await openApple(tester);
    await tester.tap(find.byType(WatchlistStar));
    await tester.pumpAndSettle();

    await tester.tap(find.text('All companies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favourites').last);
    await tester.pumpAndSettle();

    expect(find.text('1 match'), findsOneWidget);
    // Scoped to the grid: the report open beside it also names the company.
    final inGrid = find.descendant(
      of: find.byType(GridView),
      matching: find.text('Apple Inc.'),
    );
    expect(inGrid, findsOneWidget);
    expect(find.text('MICROSOFT CORP'), findsNothing);
  });

  testWidgets('picking a list clears the filters that would hide it', (
    tester,
  ) async {
    await onDesktop(() async {
      await openApple(tester);
      await tester.tap(find.byType(WatchlistStar));
      await tester.pumpAndSettle();

      // Narrow the whole directory to something Apple is not in, the way you
      // would arrive at a list after browsing: Apple borrows, so the
      // debt-free filter alone already hides it.
      await tester.tap(find.text('Debt-free'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finance'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No matches'), findsOneWidget);

      await tester.tap(find.text('All companies'));
      await pumpMenu(tester);
      await tester.tap(find.text('Favourites').last);
      await pumpMenu(tester);

      // The list itself, not what was left of the directory before it.
      expect(find.text('1 match'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GridView),
          matching: find.text('Apple Inc.'),
        ),
        findsOneWidget,
      );
      // And the controls say so too, rather than showing a filter that is no
      // longer in force.
      expect(find.text('All'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        isEmpty,
      );
    });
  });

  testWidgets('and clears them for the list already showing', (tester) async {
    await onDesktop(() async {
      await openApple(tester);
      await tester.tap(find.byType(WatchlistStar));
      await tester.pumpAndSettle();

      // On the list first, the way someone who keeps one selected is.
      await tester.tap(find.text('All companies'));
      await pumpMenu(tester);
      await tester.tap(find.text('Favourites').last);
      await pumpMenu(tester);
      expect(find.text('1 match'), findsOneWidget);

      // A filter that hides the only company in it.
      await tester.tap(find.text('Debt-free'));
      await tester.pumpAndSettle();
      expect(find.text('No matches'), findsOneWidget);

      // Pressing the list you are already on is still a request to see it.
      // Read off a change of list this changed nothing, and so did nothing,
      // which left the list hidden behind the filter.
      await tester.tap(find.text('Favourites').first);
      await pumpMenu(tester);
      await tester.tap(find.text('Favourites').last);
      await pumpMenu(tester);

      expect(find.text('1 match'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GridView),
          matching: find.text('Apple Inc.'),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('a chosen list reads as the filter that is in force', (
    tester,
  ) async {
    await onDesktop(() async {
      await openApple(tester);
      await tester.tap(find.byType(WatchlistStar));
      await tester.pumpAndSettle();

      /// Whether the control [of] sits in is drawn as a filter that is on.
      bool isFilled(Finder of) {
        final style = tester
            .widget<Button>(
              find.ancestor(of: of, matching: find.byType(Button)).first,
            )
            .style;
        return style is ButtonStyle && style.variance == ButtonVariance.primary;
      }

      // Nothing chosen: the directory is everything, and says so.
      expect(isFilled(find.text('All')), isTrue);
      expect(isFilled(find.text('All companies')), isFalse);

      await tester.tap(find.text('All companies'));
      await pumpMenu(tester);
      await tester.tap(find.text('Favourites').last);
      await pumpMenu(tester);

      // The pane is a handful of companies now. The control that chose them
      // reads as on, and the chip claiming everything does not.
      expect(isFilled(find.text('Favourites')), isTrue);
      expect(isFilled(find.text('All')), isFalse);

      // And pressing that chip makes true what it claims, rather than being
      // a control that reads as off and stays off.
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('All companies'), findsOneWidget);
      expect(find.text('7 matches'), findsOneWidget);
      expect(isFilled(find.text('All')), isTrue);
    });
  });

  testWidgets('picking a list closes the menu it was picked from', (
    tester,
  ) async {
    await onDesktop(() async {
      await openApple(tester);
      await tester.tap(find.byType(WatchlistStar));
      await tester.pumpAndSettle();

      await tester.tap(find.text('All companies'));
      await pumpMenu(tester);
      expect(find.text('New list'), findsOneWidget);

      await tester.tap(find.text('Favourites').last);
      await pumpMenu(tester);

      // The row used to carry the edit actions as a submenu, and a menu
      // button that has one opens it instead of closing — so picking a list
      // left the menu standing with the actions sprung out beside it.
      expect(find.text('New list'), findsNothing);
      expect(find.text('1 match'), findsOneWidget);
    });
  });

  testWidgets('the actions are behind an arrow of their own', (tester) async {
    await onDesktop(() async {
      await openApple(tester);
      await tester.tap(find.byType(WatchlistStar));
      await tester.pumpAndSettle();

      await tester.tap(find.text('All companies'));
      await pumpMenu(tester);
      // Not sprung open merely by the menu being up.
      expect(find.text('Edit list'), findsNothing);

      final arrow = find.byIcon(LucideIcons.chevronRight);
      expect(arrow, findsOneWidget);

      await tester.tap(arrow);
      await pumpMenu(tester);
      expect(find.text('Edit list'), findsOneWidget);
      // Reaching for the actions is not picking the list: the menu stays up
      // and the directory is untouched.
      expect(find.text('New list'), findsOneWidget);
      expect(find.text('7 matches'), findsOneWidget);

      // And the same arrow puts them away again.
      await tester.tap(arrow, warnIfMissed: false);
      await pumpMenu(tester);
      expect(find.text('Edit list'), findsNothing);
      expect(find.text('New list'), findsOneWidget);
    });
  });

  testWidgets('the name and the arrow are two halves of one row', (
    tester,
  ) async {
    await onDesktop(() async {
      await openApple(tester);
      await tester.tap(find.byType(WatchlistStar));
      await tester.pumpAndSettle();

      await tester.tap(find.text('All companies'));
      await pumpMenu(tester);

      Rect halfAround(Finder of) => tester.getRect(
        find.ancestor(of: of, matching: find.byType(Button)).first,
      );
      final name = halfAround(find.text('Favourites').last);
      final arrow = halfAround(find.byIcon(LucideIcons.chevronRight));

      // Each half is a button of its own, so each lights up on its own
      // rather than the whole row lighting up under the arrow.
      expect(name.right, closeTo(arrow.left, 0.5));
      expect(arrow.width, greaterThan(0));
      // Meeting on one edge, and the same height, so they read as two cells
      // of one row rather than a tall half beside a short one.
      expect(name.top, closeTo(arrow.top, 0.5));
      expect(name.bottom, closeTo(arrow.bottom, 0.5));
    });
  });

  testWidgets('editing from the arrow leaves no menu behind it', (
    tester,
  ) async {
    await onDesktop(() async {
      await openApple(tester);
      await tester.tap(find.byType(WatchlistStar));
      await tester.pumpAndSettle();

      await tester.tap(find.text('All companies'));
      await pumpMenu(tester);
      await tester.tap(find.byIcon(LucideIcons.chevronRight));
      await pumpMenu(tester);

      await tester.tap(find.text('Edit list'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // The editor is a dialog on the screen, not a step inside the menu, so
      // neither menu should still be waiting underneath it. Counted rather
      // than absent: the dialog titles itself "Edit list" too, so the one
      // left is the dialog's and not the menu row that opened it.
      expect(find.byType(WatchlistEditor), findsOneWidget);
      expect(find.text('Edit list'), findsOneWidget);
      // "New list" lives only inside the menu, so its absence is the menu's.
      expect(find.text('New list'), findsNothing);
    });
  });

  testWidgets('an empty list says so rather than looking like no results', (
    tester,
  ) async {
    await openHome(tester);

    await tester.tap(find.text('All companies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favourites').last);
    await tester.pumpAndSettle();

    expect(find.text('Nothing in this list'), findsOneWidget);
    expect(find.textContaining('Open a company and add it to'), findsOneWidget);
  });

  testWidgets('the starred list marks a tile with a star, others a dot', (
    tester,
  ) async {
    await openApple(tester);
    await tester.tap(find.byType(WatchlistStar));
    await tester.pumpAndSettle();

    Finder markerIn(String ticker) =>
        find.ancestor(of: find.text(ticker), matching: find.byType(Row)).first;

    // Apple is in the starred list, which is the one the star on a report
    // writes into — so its tile carries the same glyph that put it there.
    expect(
      find.descendant(
        of: markerIn('AAPL'),
        matching: find.byIcon(BootstrapIcons.starFill),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: markerIn('AAPL'),
        matching: find.byType(WatchlistDot),
      ),
      findsNothing,
    );

    // A list of your own is one of many, so it stays a dot.
    await tester.tap(find.text('NVIDIA CORP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not in any list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Semiconductors');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: markerIn('NVDA'),
        matching: find.byType(WatchlistDot),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: markerIn('NVDA'),
        matching: find.byIcon(BootstrapIcons.starFill),
      ),
      findsNothing,
    );
  });

  testWidgets('makes a list, names it and colours it', (tester) async {
    await openHome(tester);

    await tester.tap(find.text('All companies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New list'));
    await tester.pumpAndSettle();

    expect(find.text('Colour'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Semiconductors');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('All companies'));
    await tester.pumpAndSettle();
    expect(find.text('Semiconductors'), findsOneWidget);
    // Both the new list and the starred one are empty, and each says so.
    expect(find.text('empty'), findsNWidgets(2));
  });
}
