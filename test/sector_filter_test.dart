import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/snapshot/sic_sector.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/browse/widgets/sector_filter_row.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

// The view-model cases use plain `test`: they await real database queries,
// which a widget test's fake clock never lets complete.

const Size _wideSize = Size(1440, 900);

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  late AppDatabase database;

  tearDown(() async {
    await database.close();
    await GetIt.I.reset();
  });

  test('filters the list down to one sector', () async {
    database = await registerTestDependencies(withFinancials: true);
    final viewModel = BrowseViewModel();
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.hasSectors, isTrue);

    // Apple (3571), NVIDIA (3674) and Microsoft (7372) are all tech; the two
    // Berkshire symbols are insurance.
    viewModel.selectSector(SicSector.technology);
    expect(
      viewModel.results.map((c) => c.ticker),
      containsAll(<String>['AAPL', 'NVDA', 'MSFT']),
    );
    expect(viewModel.results.map((c) => c.ticker), isNot(contains('BRK-A')));

    viewModel.selectSector(SicSector.financials);
    expect(
      viewModel.results.map((c) => c.ticker),
      containsAll(<String>['BRK-A', 'BRK-B']),
    );
    expect(viewModel.results.map((c) => c.ticker), isNot(contains('AAPL')));

    // Cleared again.
    viewModel.selectSector(null);
    expect(viewModel.results.map((c) => c.ticker), contains('AAPL'));
  });

  test('the sector filter and the text filter apply together', () async {
    database = await registerTestDependencies(withFinancials: true);
    final viewModel = BrowseViewModel();
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);

    viewModel.selectSector(SicSector.technology);
    viewModel.setQuery('NV');

    expect(viewModel.results.map((c) => c.ticker), ['NVDA']);
  });

  testWidgets('offers a chip per sector, and one to clear', (tester) async {
    database = await registerTestDependencies(withFinancials: true);
    tester.view
      ..physicalSize = _wideSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Tech'), findsOneWidget);
    expect(find.text('Automotive'), findsOneWidget);

    await tester.tap(find.text('Tech'));
    await tester.pumpAndSettle();

    // Berkshire is insurance, so it drops out.
    expect(find.text('BERKSHIRE HATHAWAY INC'), findsNothing);
    expect(find.text('NVIDIA CORP'), findsOneWidget);
  });

  testWidgets('hides the row entirely when nothing is classified', (
    tester,
  ) async {
    // An ingest from before sectors were collected.
    database = await registerTestDependencies();
    tester.view
      ..physicalSize = _wideSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();

    expect(find.text('Tech'), findsNothing);
    expect(find.text('All'), findsNothing);
  });

  /// A model with the fixture loaded and its first sample pass finished.
  Future<BrowseViewModel> loadedViewModel() async {
    database = await registerTestDependencies(withFinancials: true);
    final viewModel = BrowseViewModel();
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);
    return viewModel;
  }

  test('lists the SEC industries present in a sector, by title', () async {
    final viewModel = await loadedViewModel();

    // Apple is 3571, NVIDIA 3674 and Microsoft 7372 — three industries in
    // one sector, alphabetical by SEC's own title.
    expect(viewModel.industriesIn(SicSector.technology).map((o) => o.title), [
      'Electronic Computers',
      'Semiconductors & Related Devices',
      'Services-Prepackaged Software',
    ]);
    // Counted by filer, not by symbol.
    expect(
      viewModel.industriesIn(SicSector.financials).map((o) => o.companyCount),
      [1],
    );
  });

  test('narrows a sector to one of its industries', () async {
    final viewModel = await loadedViewModel();

    viewModel.selectSector(SicSector.technology);
    expect(
      viewModel.results.map((c) => c.ticker),
      containsAll(<String>['AAPL', 'NVDA', 'MSFT']),
    );

    // Semiconductors alone: NVIDIA stays, the other two tech filers go.
    viewModel.toggleIndustry(SicSector.technology, 3674);
    expect(viewModel.results.map((c) => c.ticker), ['NVDA']);
    expect(viewModel.narrowedCountIn(SicSector.technology), 1);
    expect(viewModel.isIndustrySelected(SicSector.technology, 3674), isTrue);
    expect(viewModel.isIndustrySelected(SicSector.technology, 3571), isFalse);

    // A second industry widens the narrowing rather than replacing it.
    viewModel.toggleIndustry(SicSector.technology, 3571);
    expect(
      viewModel.results.map((c) => c.ticker),
      containsAll(<String>['AAPL', 'NVDA']),
    );
    expect(viewModel.results.map((c) => c.ticker), isNot(contains('MSFT')));
    expect(viewModel.narrowedCountIn(SicSector.technology), 2);
  });

  test('unticking the last industry lands back on the whole sector', () async {
    final viewModel = await loadedViewModel();

    viewModel.toggleIndustry(SicSector.technology, 3674);
    expect(viewModel.results.map((c) => c.ticker), ['NVDA']);

    // Rather than an empty list, which would look like a broken filter.
    viewModel.toggleIndustry(SicSector.technology, 3674);
    expect(viewModel.narrowedCountIn(SicSector.technology), 0);
    expect(
      viewModel.results.map((c) => c.ticker),
      containsAll(<String>['AAPL', 'NVDA', 'MSFT']),
    );
  });

  test('narrowing another sector moves the filter to it', () async {
    final viewModel = await loadedViewModel();

    viewModel.toggleIndustry(SicSector.technology, 3674);
    // Insurance, picked from a chip that was not the one selected.
    viewModel.toggleIndustry(SicSector.financials, 6331);

    expect(viewModel.sector, SicSector.financials);
    expect(viewModel.narrowedCountIn(SicSector.technology), 0);
    expect(
      viewModel.results.map((c) => c.ticker),
      containsAll(<String>['BRK-A', 'BRK-B']),
    );
  });

  test('selecting the sector widens it past any narrowing', () async {
    final viewModel = await loadedViewModel();

    viewModel.toggleIndustry(SicSector.technology, 3674);
    expect(viewModel.narrowedCountIn(SicSector.technology), 1);

    // The chip reads as the sector entire, so pressing it means all of it.
    viewModel.selectSector(SicSector.technology);
    expect(viewModel.narrowedCountIn(SicSector.technology), 0);
    expect(
      viewModel.results.map((c) => c.ticker),
      containsAll(<String>['AAPL', 'NVDA', 'MSFT']),
    );
  });

  test('showing a list clears the narrowings that could hide it', () async {
    final viewModel = await loadedViewModel();

    viewModel.selectSector(SicSector.technology);
    viewModel.toggleIndustry(SicSector.technology, 3674);
    viewModel.toggleDebtFree();
    viewModel.togglePositiveCashFlow();
    viewModel.setQuery('zzz');
    expect(viewModel.results, isEmpty);

    // Berkshire, which none of those narrowings would have let through.
    viewModel.applyWatchlist(const {'0001067983'});
    await Future<void>.delayed(Duration.zero);
    viewModel.clearNarrowings();

    expect(viewModel.sector, isNull);
    expect(viewModel.narrowedCountIn(SicSector.technology), 0);
    expect(viewModel.debtFreeOnly, isFalse);
    expect(viewModel.positiveCashFlowOnly, isFalse);
    expect(viewModel.query, isEmpty);
    expect(viewModel.filterController.text, isEmpty);
    expect(
      viewModel.results.map((company) => company.ticker),
      containsAll(<String>['BRK-A', 'BRK-B']),
    );
  });

  test('a change to the open list leaves the narrowings alone', () async {
    final viewModel = await loadedViewModel();

    viewModel.applyWatchlist(const {'0000320193'});
    await Future<void>.delayed(Duration.zero);
    viewModel.selectSector(SicSector.technology);
    expect(viewModel.sector, SicSector.technology);

    // Starring another company adds it to the list that is already open. That
    // is not a choice of list, and clearing here would pull the filters out
    // from under someone mid-browse.
    viewModel.applyWatchlist(const {'0000320193', '0001045810'});
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.sector, SicSector.technology);
  });

  test('names a report after what was actually filtered', () async {
    final viewModel = await loadedViewModel();
    final strings = await AppLocalizations.delegate.load(const Locale('en'));

    viewModel.selectSector(SicSector.technology);
    expect(viewModel.describeFilter(strings), 'Tech');

    // One industry names itself; the sector label alone would be a lie.
    viewModel.toggleIndustry(SicSector.technology, 3674);
    expect(
      viewModel.describeFilter(strings),
      'Semiconductors & Related Devices',
    );

    viewModel.toggleIndustry(SicSector.technology, 3571);
    expect(viewModel.describeFilter(strings), 'Tech, 2 industries');
  });

  /// Runs [body] with the platform reported as macOS.
  ///
  /// The app ships for macOS and Linux only, and shadcn presents a dropdown
  /// as a popover there. On the platform a widget test reports by default it
  /// presents the same dropdown as a mobile bottom sheet instead — a
  /// different widget, sized differently and dismissed differently — so a
  /// menu exercised without this is not the menu the app shows.
  Future<void> onDesktop(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  /// Settles the frames after opening or closing the menu.
  ///
  /// Not `pumpAndSettle`: the popover re-reads its anchor's position every
  /// frame while it is up, so the tree never goes quiet and settling times
  /// out.
  Future<void> pumpMenu(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Clicks with frames between the press and the release, as a hand does.
  ///
  /// `tap` sends both in one go. That hides anything depending on a rebuild
  /// landing between them, and the reopen these cases guard against is
  /// exactly that: the menu dismisses on the press going down, the chip
  /// rebuilds, and the release then lands on a chip that opens again.
  Future<void> click(WidgetTester tester, Finder finder) async {
    final gesture = await tester.startGesture(tester.getCenter(finder));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));
    await gesture.up();
    await pumpMenu(tester);
  }

  Future<void> openApp(WidgetTester tester) async {
    database = await registerTestDependencies(withFinancials: true);
    tester.view
      ..physicalSize = _wideSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();
  }

  final techArrow = find.byKey(sectorNarrowKey(SicSector.technology));

  testWidgets('the chips wrap onto more lines as the window narrows', (
    tester,
  ) async {
    await openApp(tester);

    double rowHeight() => tester.getSize(find.byType(SectorFilterRow)).height;
    final onWide = rowHeight();

    tester.view.physicalSize = const Size(620, 700);
    await tester.pumpAndSettle();
    expect(rowHeight(), greaterThan(onWide));

    // And every chip is still on screen. Scrolling sideways instead would
    // leave the ones that no longer fit past the right edge, with nothing to
    // say they were there.
    final row = tester.getRect(find.byType(SectorFilterRow));
    final chips = find.descendant(
      of: find.byType(SectorFilterRow),
      matching: find.byType(Button),
    );
    expect(chips, findsWidgets);
    for (var i = 0; i < tester.widgetList(chips).length; i++) {
      final chip = tester.getRect(chips.at(i));
      expect(chip.left, greaterThanOrEqualTo(row.left - 0.5));
      expect(chip.right, lessThanOrEqualTo(row.right + 0.5));
    }
  });

  testWidgets('narrows a sector through the chip\'s second half', (
    tester,
  ) async {
    await onDesktop(() async {
      await openApp(tester);

      // The label half still filters the whole sector.
      await tester.tap(find.text('Tech'));
      await tester.pumpAndSettle();
      expect(find.text('NVIDIA CORP'), findsOneWidget);
      expect(find.text('MICROSOFT CORP'), findsOneWidget);

      // The other half opens SEC's industries for that sector.
      await tester.tap(techArrow);
      await pumpMenu(tester);
      expect(find.text('SEC industries'), findsOneWidget);
      expect(find.text('All industries'), findsOneWidget);
      expect(find.text('Semiconductors & Related Devices'), findsOneWidget);

      await tester.tap(find.text('Semiconductors & Related Devices'));
      await pumpMenu(tester);

      // Still open, so a second industry can be picked without reopening.
      expect(find.text('All industries'), findsOneWidget);
      // And the chip says it is carrying less than its label.
      expect(find.text('1/3'), findsOneWidget);

      await tester.tap(find.text('Electronic Computers'));
      await pumpMenu(tester);
      expect(find.text('2/3'), findsOneWidget);

      await tester.tap(techArrow);
      await pumpMenu(tester);

      // Narrowed to the two industries picked.
      expect(find.text('NVIDIA CORP'), findsOneWidget);
      expect(find.text('Apple Inc.'), findsOneWidget);
      expect(find.text('MICROSOFT CORP'), findsNothing);
    });
  });

  testWidgets('either half of the chip shuts the open menu', (tester) async {
    await onDesktop(() async {
      await openApp(tester);

      await tester.tap(techArrow);
      await pumpMenu(tester);
      expect(find.text('SEC industries'), findsOneWidget);
      // Turned over, to say it is the way back out.
      expect(
        find.descendant(
          of: techArrow,
          matching: find.byIcon(LucideIcons.chevronUp),
        ),
        findsOneWidget,
      );

      // The arrow. This used to dismiss the menu on the press going down and
      // reopen it on the way back up, leaving it open.
      await click(tester, techArrow);
      expect(find.text('SEC industries'), findsNothing);
      expect(
        find.descendant(
          of: techArrow,
          matching: find.byIcon(LucideIcons.chevronDown),
        ),
        findsOneWidget,
      );

      // The label half shuts it too, and without filtering on the way: the
      // list under a menu the user is still reading must not move.
      await tester.tap(techArrow);
      await pumpMenu(tester);
      await click(tester, find.text('Tech'));
      expect(find.text('SEC industries'), findsNothing);
      expect(find.text('7 matches'), findsOneWidget);

      // And the chip still filters once the menu is down.
      await tester.tap(find.text('Tech'));
      await tester.pumpAndSettle();
      expect(find.text('3 matches'), findsOneWidget);
    });
  });

  testWidgets('reopening lifts the picked industries to the top', (
    tester,
  ) async {
    await onDesktop(() async {
      await openApp(tester);

      await tester.tap(techArrow);
      await pumpMenu(tester);

      // Last of the three by title, so the one that would need scrolling to.
      await tester.tap(find.text('Services-Prepackaged Software'));
      await pumpMenu(tester);

      // It stays put while the menu is open: a row that jumped as it was
      // ticked would move the next one out from under the pointer.
      expect(
        tester.getCenter(find.text('Services-Prepackaged Software')).dy,
        greaterThan(tester.getCenter(find.text('Electronic Computers')).dy),
      );

      await tester.tap(techArrow);
      await pumpMenu(tester);
      await tester.tap(techArrow);
      await pumpMenu(tester);

      // Reopened, it now leads the list.
      expect(
        tester.getCenter(find.text('Services-Prepackaged Software')).dy,
        lessThan(tester.getCenter(find.text('Electronic Computers')).dy),
      );

      await tester.tap(techArrow);
      await pumpMenu(tester);
    });
  });

  testWidgets('sizes the menu to its longest title, not to the window', (
    tester,
  ) async {
    await onDesktop(() async {
      await openApp(tester);

      await tester.tap(techArrow);
      await pumpMenu(tester);

      final menu = tester.getSize(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == 'MenuPopup'),
      );
      // Capped, the menu wrapped its titles; uncapped it must still not take
      // the whole window.
      expect(menu.width, lessThan(_wideSize.width));

      // Wide enough that the longest of SEC's titles sits on one line: a
      // single-line box, not a wrapped two-line one.
      final longest = tester.getSize(
        find.text('Semiconductors & Related Devices'),
      );
      expect(longest.width, lessThan(menu.width));
      expect(longest.height, lessThan(30));

      await tester.tap(techArrow);
      await pumpMenu(tester);
    });
  });
}
