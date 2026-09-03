import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/snapshot/sic_sector.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/settings/settings_repo.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/browse/widgets/positive_cash_flow_filter.dart';
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

  Future<BrowseViewModel> loadedViewModel() async {
    database = await registerTestDependencies(withFinancials: true);
    final viewModel = BrowseViewModel();
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);
    return viewModel;
  }

  test('keeps the companies that generate cash and drops the rest', () async {
    final viewModel = await loadedViewModel();

    expect(viewModel.canFilterPositiveCashFlow, isTrue);

    viewModel.togglePositiveCashFlow();
    final tickers = viewModel.results.map((company) => company.ticker);

    // Every filer with real operations turns more cash from them than it
    // spends on equipment.
    expect(tickers, containsAll(<String>['AAPL', 'NVDA', 'MSFT', 'BRK-A']));
    // Kensington spends $30M of the $5M it brings in.
    expect(tickers, isNot(contains('KCAC-UN')));
    // And a filer with no figures at all says nothing either way, so it is
    // not read as generating cash.
    expect(tickers, isNot(contains('AAPI')));
  });

  test('reads a missing figure as unknown rather than as zero', () async {
    database = await registerTestDependencies(withFinancials: true);
    // Microsoft's capital spending goes off the record, which leaves its free
    // cash flow unanswerable — not equal to its operating cash flow.
    await database.customStatement(
      'UPDATE fiscal_years SET capital_expenditure = NULL '
      "WHERE cik = '0000789019' AND fiscal_year = 2025",
    );

    final viewModel = BrowseViewModel();
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);

    viewModel.togglePositiveCashFlow();
    final tickers = viewModel.results.map((company) => company.ticker);
    expect(tickers, isNot(contains('MSFT')));
    expect(tickers, contains('AAPL'));
  });

  test('applies alongside the other filters', () async {
    final viewModel = await loadedViewModel();

    viewModel.togglePositiveCashFlow();
    viewModel.selectSector(SicSector.technology);
    expect(
      viewModel.results.map((company) => company.ticker),
      containsAll(<String>['AAPL', 'NVDA', 'MSFT']),
    );

    // Stacked on the debt-free filter, both narrowings hold: Apple borrows.
    viewModel.toggleDebtFree();
    final tickers = viewModel.results.map((company) => company.ticker);
    expect(tickers, containsAll(<String>['NVDA', 'MSFT']));
    expect(tickers, isNot(contains('AAPL')));

    viewModel.setQuery('NV');
    expect(viewModel.results.map((company) => company.ticker), ['NVDA']);

    // Cleared again, and the whole directory is back.
    viewModel.togglePositiveCashFlow();
    viewModel.toggleDebtFree();
    viewModel.selectSector(null);
    viewModel.setQuery('');
    expect(
      viewModel.results.map((company) => company.ticker),
      contains('KCAC-UN'),
    );
  });

  test('names a report after the filter that produced it', () async {
    final viewModel = await loadedViewModel();

    viewModel.togglePositiveCashFlow();
    expect(
      viewModel.describeFilter(await _strings()),
      contains('Cash generative'),
    );
  });

  test('is remembered between launches', () async {
    final settings = LocalSettingsRepo();
    database = await registerTestDependencies(
      withFinancials: true,
      settingsRepo: settings,
    );
    final first = BrowseViewModel();
    addTearDown(first.dispose);
    await Future<void>.delayed(Duration.zero);

    first.togglePositiveCashFlow();
    // The write is awaited through the repo, not the toggle, so give it a turn.
    await Future<void>.delayed(Duration.zero);
    await settings.load();

    expect(settings.positiveCashFlowOnly, isTrue);
    final second = BrowseViewModel();
    addTearDown(second.dispose);
    // Read before its own figures land: the filter is remembered in the
    // constructor so the list is narrowed from the first frame.
    expect(second.positiveCashFlowOnly, isTrue);
    // Let the second model finish loading, so it is not notifying listeners
    // after the test has disposed it.
    await Future<void>.delayed(Duration.zero);
  });

  testWidgets('offers a toggle in the filter bar', (tester) async {
    database = await registerTestDependencies(withFinancials: true);
    tester.view
      ..physicalSize = _wideSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();

    expect(find.byType(PositiveCashFlowFilter), findsOneWidget);
    expect(find.text('Kensington Capital Acquisition Corp'), findsWidgets);

    await tester.tap(find.text('Cash generative'));
    await tester.pumpAndSettle();

    // Kensington burns cash, so it leaves the list; Apple stays.
    expect(find.text('Kensington Capital Acquisition Corp'), findsNothing);
    expect(find.text('Apple Inc.'), findsWidgets);

    await tester.tap(find.text('Cash generative'));
    await tester.pumpAndSettle();
    expect(find.text('Kensington Capital Acquisition Corp'), findsWidgets);
  });

  testWidgets('is not offered on a database that cannot answer', (
    tester,
  ) async {
    // No financials: nothing on file says whether anyone generates cash, and
    // a filter that emptied the list would read as a broken directory.
    database = await registerTestDependencies();
    tester.view
      ..physicalSize = _wideSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();

    expect(find.byType(PositiveCashFlowFilter), findsOneWidget);
    expect(find.text('Cash generative'), findsNothing);
  });
}

/// The English strings, which is what the tests read against.
Future<AppLocalizations> _strings() =>
    AppLocalizations.delegate.load(const Locale('en'));
