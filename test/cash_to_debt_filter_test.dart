import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/snapshot/sic_sector.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/settings/settings_repo.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/browse/widgets/cash_to_debt_filter.dart';
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

  test('keeps the companies whose cash covers their debt', () async {
    database = await registerTestDependencies(withFinancials: true);
    final viewModel = BrowseViewModel();
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.canFilterCashToDebt, isTrue);

    viewModel.setCashToDebtMin(1);
    final tickers = viewModel.results.map((company) => company.ticker);

    // Apple holds $150M against $50M of borrowings. NVIDIA reports no debt
    // line and no interest; Microsoft reports its borrowings as an explicit
    // zero. Owing nothing is covered at any multiple.
    expect(tickers, containsAll(<String>['AAPL', 'NVDA', 'MSFT']));
    // Berkshire is the case the interest test exists for: it reports no debt
    // line at all, and $5M of interest on the debt it does not show.
    expect(tickers, isNot(contains('BRK-A')));
    expect(tickers, isNot(contains('BRK-B')));
    // Kensington files figures but no balance sheet with them, which says
    // nothing either way.
    expect(tickers, isNot(contains('KCAC-UN')));
  });

  test('raises the bar with the multiple', () async {
    database = await registerTestDependencies(withFinancials: true);
    final viewModel = BrowseViewModel();
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);

    Iterable<String> tickersAt(double ratio) {
      viewModel.setCashToDebtMin(ratio);
      return viewModel.results.map((company) => company.ticker);
    }

    // Apple's cash is exactly three times its debt: in at 3x, out above it.
    expect(tickersAt(3), contains('AAPL'));
    expect(tickersAt(3.5), isNot(contains('AAPL')));
    // The debt-free stay at the top of the scale.
    expect(tickersAt(10), containsAll(<String>['NVDA', 'MSFT']));

    // Lifted, and the whole directory is back.
    viewModel.setCashToDebtMin(null);
    expect(
      viewModel.results.map((company) => company.ticker),
      containsAll(<String>['AAPL', 'BRK-A', 'KCAC-UN']),
    );
  });

  test('applies alongside the sector and text filters', () async {
    database = await registerTestDependencies(withFinancials: true);
    final viewModel = BrowseViewModel();
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);

    viewModel.setCashToDebtMin(5);
    viewModel.selectSector(SicSector.technology);
    final tickers = viewModel.results.map((company) => company.ticker);
    expect(tickers, containsAll(<String>['NVDA', 'MSFT']));
    expect(tickers, isNot(contains('AAPL')));

    viewModel.setQuery('NV');
    expect(viewModel.results.map((company) => company.ticker), ['NVDA']);
  });

  test('names a report after the filter that produced it', () async {
    database = await registerTestDependencies(withFinancials: true);
    final viewModel = BrowseViewModel();
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);

    viewModel.setCashToDebtMin(2.5);
    expect(
      viewModel.describeFilter(await _strings()),
      contains('Cash ≥ 2.5× debt'),
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

    first.setCashToDebtMin(3);
    // The write is awaited through the repo, not the setter, so give it a
    // turn.
    await Future<void>.delayed(Duration.zero);
    await settings.load();

    expect(settings.cashToDebtMin, 3);
    final second = BrowseViewModel();
    addTearDown(second.dispose);
    // Read before its own figures land: the filter is remembered in the
    // constructor so the list is narrowed from the first frame.
    expect(second.cashToDebtMin, 3);
    await Future<void>.delayed(Duration.zero);
  });

  testWidgets('offers presets and a slider in a dropdown', (tester) async {
    database = await registerTestDependencies(withFinancials: true);
    tester.view
      ..physicalSize = _wideSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();

    expect(find.byType(CashToDebtFilter), findsOneWidget);
    expect(find.text('Apple Inc.'), findsWidgets);

    await tester.tap(find.text('Cash > debt'));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsOneWidget);

    await tester.tap(find.text('5× debt'));
    await tester.pumpAndSettle();

    // Apple holds three times its debt, not five, so it leaves the list;
    // NVIDIA owes nothing and stays. The chip says what is in force.
    expect(find.text('Apple Inc.'), findsNothing);
    expect(find.text('NVIDIA CORP'), findsWidgets);
    expect(find.text('Cash ≥ 5× debt'), findsOneWidget);

    await tester.tap(find.text('Cash ≥ 5× debt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Any balance sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Apple Inc.'), findsWidgets);
    expect(find.text('Cash > debt'), findsOneWidget);
  });

  testWidgets('is not offered on a database that cannot answer', (
    tester,
  ) async {
    // No financials: nothing on file says what anyone owes, and a filter that
    // emptied the list would read as a broken directory.
    database = await registerTestDependencies();
    tester.view
      ..physicalSize = _wideSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();

    expect(find.byType(CashToDebtFilter), findsOneWidget);
    expect(find.text('Cash > debt'), findsNothing);
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
Future<AppLocalizations> _strings() =>
    AppLocalizations.delegate.load(const Locale('en'));
