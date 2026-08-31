import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/snapshot/sic_sector.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
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
    await tester.tap(find.byIcon(LucideIcons.list));
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
    await tester.tap(find.byIcon(LucideIcons.list));
    await tester.pumpAndSettle();

    expect(find.text('Tech'), findsNothing);
    expect(find.text('All'), findsNothing);
  });
}
