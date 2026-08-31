import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/browse_sort.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';

import 'support/test_directory.dart';

void main() {
  late AppDatabase database;
  late BrowseViewModel viewModel;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    database = await registerTestDependencies(withFinancials: true);
    viewModel = BrowseViewModel();
    // The constructor loads the figures behind the default ordering.
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() async {
    viewModel.dispose();
    await database.close();
    await GetIt.I.reset();
  });

  List<String> symbolsAfter(BrowseSort sort) =>
      viewModel.results.map((company) => company.ticker).toList();

  test('orders by name, case-insensitively', () {
    // 'Apple iSports' and 'Apple Inc.' sit together despite BERKSHIRE and
    // MICROSOFT being upper-case in the directory.
    expect(
      viewModel.results.map((c) => c.name.toLowerCase()),
      orderedEquals(
        viewModel.results.map((c) => c.name.toLowerCase()).toList()..sort(),
      ),
    );
  });

  test('ranks by one-year revenue growth, fastest first', () async {
    await viewModel.selectSort(BrowseSort.revenueOneYear);

    // NVDA tripled, AAPL grew a tenth, MSFT shrank.
    final ranked = symbolsAfter(BrowseSort.revenueOneYear)
        .where((s) => const ['NVDA', 'AAPL', 'MSFT'].contains(s))
        .toList();
    expect(ranked, ['NVDA', 'AAPL', 'MSFT']);
  });

  test('a ten-year window ranks on the whole decade', () async {
    await viewModel.selectSort(BrowseSort.revenueTenYears);
    final ranked = symbolsAfter(BrowseSort.revenueTenYears)
        .where((s) => const ['NVDA', 'AAPL', 'MSFT'].contains(s))
        .toList();
    expect(ranked, ['NVDA', 'AAPL', 'MSFT']);
  });

  test('companies without the window are ranked last, not at zero', () async {
    await viewModel.selectSort(BrowseSort.revenueTenYears);

    // Berkshire has one year on file, so a decade cannot be measured.
    final berkshire = viewModel.results.indexWhere((c) => c.ticker == 'BRK-A');
    final microsoft = viewModel.results.indexWhere((c) => c.ticker == 'MSFT');
    expect(berkshire, greaterThan(microsoft));
    expect(
      viewModel.figureFor(
        viewModel.results.firstWhere((c) => c.ticker == 'BRK-A'),
      ),
      isNull,
    );
  });

  test('ranks by free cash flow growth', () async {
    await viewModel.selectSort(BrowseSort.freeCashFlowOneYear);

    // NVDA: 50 -> 200. AAPL: 130 -> 180. MSFT: 220 -> 210.
    final ranked = symbolsAfter(BrowseSort.freeCashFlowOneYear)
        .where((s) => const ['NVDA', 'AAPL', 'MSFT'].contains(s))
        .toList();
    expect(ranked, ['NVDA', 'AAPL', 'MSFT']);
  });

  test('shows a growth rate under a growth ordering', () async {
    await viewModel.selectSort(BrowseSort.revenueOneYear);
    expect(viewModel.showsGrowth, isTrue);

    final nvidia = viewModel.results.firstWhere((c) => c.ticker == 'NVDA');
    expect(viewModel.figureFor(nvidia), closeTo(200, 0.001));
  });

  test('shows the latest revenue when ordered by name', () async {
    await viewModel.selectSort(BrowseSort.revenueOneYear);
    await viewModel.selectSort(BrowseSort.name);

    expect(viewModel.showsGrowth, isFalse);
    final nvidia = viewModel.results.firstWhere((c) => c.ticker == 'NVDA');
    expect(viewModel.figureFor(nvidia), 300000000);
  });

  test('filtering and ranking apply together', () async {
    await viewModel.selectSort(BrowseSort.revenueOneYear);
    viewModel.setQuery('BRK');

    expect(viewModel.results.every((c) => c.ticker.startsWith('BRK')), isTrue);
    expect(viewModel.resultCount, 2);
  });
}
