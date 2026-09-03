import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/snapshot/sic_sector.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/settings/settings_repo.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/browse/widgets/debt_free_filter.dart';
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

  test('keeps the companies that owe nothing and drops the rest', () async {
    database = await registerTestDependencies(withFinancials: true);
    final viewModel = BrowseViewModel();
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.canFilterDebtFree, isTrue);

    viewModel.toggleDebtFree();
    final tickers = viewModel.results.map((company) => company.ticker);

    // NVIDIA reports no debt line and no interest; Microsoft reports its
    // borrowings as an explicit zero. Both owe nothing.
    expect(tickers, containsAll(<String>['NVDA', 'MSFT']));
    // Apple borrows.
    expect(tickers, isNot(contains('AAPL')));
    // Berkshire is the case the interest test exists for: it reports no debt
    // line at all, and $5M of interest on the debt it does not show.
    expect(tickers, isNot(contains('BRK-A')));
    expect(tickers, isNot(contains('BRK-B')));
    // A filer with no fiscal years on file says nothing either way, so it is
    // not read as owing nothing.
    expect(tickers, isNot(contains('KCAC-UN')));
  });

  test('applies alongside the sector and text filters', () async {
    database = await registerTestDependencies(withFinancials: true);
    final viewModel = BrowseViewModel();
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);

    viewModel.toggleDebtFree();
    viewModel.selectSector(SicSector.technology);
    expect(
      viewModel.results.map((company) => company.ticker),
      containsAll(<String>['NVDA', 'MSFT']),
    );

    viewModel.setQuery('NV');
    expect(viewModel.results.map((company) => company.ticker), ['NVDA']);

    // Cleared again, and the whole directory is back.
    viewModel.toggleDebtFree();
    viewModel.selectSector(null);
    viewModel.setQuery('');
    expect(
      viewModel.results.map((company) => company.ticker),
      contains('AAPL'),
    );
  });

  test('names a report after the filter that produced it', () async {
    database = await registerTestDependencies(withFinancials: true);
    final viewModel = BrowseViewModel();
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);

    viewModel.toggleDebtFree();
    expect(viewModel.describeFilter(await _strings()), contains('Debt-free'));
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

    first.toggleDebtFree();
    // The write is awaited through the repo, not the toggle, so give it a turn.
    await Future<void>.delayed(Duration.zero);
    await settings.load();

    expect(settings.debtFreeOnly, isTrue);
    final second = BrowseViewModel();
    addTearDown(second.dispose);
    // Read before its own figures land: the filter is remembered in the
    // constructor so the list is narrowed from the first frame.
    expect(second.debtFreeOnly, isTrue);
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

    expect(find.byType(DebtFreeFilter), findsOneWidget);
    expect(find.text('Apple Inc.'), findsWidgets);

    await tester.tap(find.text('Debt-free'));
    await tester.pumpAndSettle();

    // Apple borrows, so it leaves the list; NVIDIA owes nothing and stays.
    expect(find.text('Apple Inc.'), findsNothing);
    expect(find.text('NVIDIA CORP'), findsWidgets);

    await tester.tap(find.text('Debt-free'));
    await tester.pumpAndSettle();
    expect(find.text('Apple Inc.'), findsWidgets);
  });

  testWidgets('is not offered on a database that cannot answer', (
    tester,
  ) async {
    // No financials: nothing on file says whether anyone owes anything, and a
    // filter that emptied the list would read as a broken directory.
    database = await registerTestDependencies();
    tester.view
      ..physicalSize = _wideSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();

    expect(find.byType(DebtFreeFilter), findsOneWidget);
    expect(find.text('Debt-free'), findsNothing);
  });

  group('a year of figures reads its own borrowings', () {
    test('no debt line and no interest means nothing is owed', () {
      const year = FiscalYearFigures(fiscalYear: 2025, totalAssets: 1000);
      expect(year.isDebtFree, isTrue);
    });

    test('a debt line of zero says the same thing', () {
      const year = FiscalYearFigures(
        fiscalYear: 2025,
        totalAssets: 1000,
        totalDebt: 0,
      );
      expect(year.isDebtFree, isTrue);
    });

    test('interest without a debt line means the debt is simply hidden', () {
      const year = FiscalYearFigures(
        fiscalYear: 2025,
        totalAssets: 1000,
        interestExpense: 5,
      );
      expect(year.isDebtFree, isFalse);
    });

    test('borrowings are borrowings', () {
      const year = FiscalYearFigures(
        fiscalYear: 2025,
        totalAssets: 1000,
        totalDebt: 50,
      );
      expect(year.isDebtFree, isFalse);
    });

    test('a filing with no balance sheet in it says nothing either way', () {
      const year = FiscalYearFigures(fiscalYear: 2025);
      expect(year.isDebtFree, isFalse);
    });
  });
}

/// The English strings, which is what the tests read against.
Future<AppLocalizations> _strings() => AppLocalizations.delegate.load(
  const Locale('en'),
);
