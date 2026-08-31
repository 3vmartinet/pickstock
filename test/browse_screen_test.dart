import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

const Size _desktopSize = Size(1440, 1200);

/// Below the master-detail breakpoint, so picking a company navigates back.
const Size _narrowSize = Size(820, 1200);

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await registerTestDependencies();
  });

  tearDown(GetIt.I.reset);

  testWidgets('lists the whole directory and narrows it on a query', (
    tester,
  ) async {
    await _openBrowser(tester);

    expect(find.text('PickStock'), findsOneWidget);
    // Counts are grouped, not bare digits.
    expect(
      find.text('${testTickers.length} symbols filed with SEC EDGAR'),
      findsOneWidget,
    );
    expect(find.text('${testTickers.length} matches'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'BRK-');
    await tester.pumpAndSettle();

    expect(find.text('2 matches'), findsOneWidget);
    expect(find.text('BRK-A'), findsOneWidget);
    expect(find.text('BRK-B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('matches company names as well as symbols', (tester) async {
    await _openBrowser(tester);

    await tester.enterText(find.byType(TextField).last, 'berkshire');
    await tester.pumpAndSettle();

    expect(find.text('BRK-A'), findsOneWidget);
    expect(find.text('BRK-B'), findsOneWidget);
  });

  testWidgets('explains an empty result rather than showing a blank grid', (
    tester,
  ) async {
    await _openBrowser(tester);

    await tester.enterText(find.byType(TextField).last, 'zzzzzzz');
    await tester.pumpAndSettle();

    expect(find.text('No matches'), findsOneWidget);
    expect(find.text('No matching symbols'), findsOneWidget);
  });

  testWidgets('picking a symbol returns to the report and looks it up', (
    tester,
  ) async {
    await _openBrowser(tester, size: _narrowSize);

    await tester.enterText(find.byType(TextField).last, 'AAPL');
    await tester.pumpAndSettle();
    // By name, not symbol: the symbol also appears in the filter field.
    await tester.tap(find.text('Apple Inc.'));
    await tester.pumpAndSettle();

    // On the company's own screen, with the picked symbol fetched.
    expect(find.text('PickStock'), findsNothing);
    expect(find.text('Apple Inc.'), findsWidgets);
    expect(find.text('FY2025 highlights'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openBrowser(
  WidgetTester tester, {
  Size size = _desktopSize,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const PickStockApp());
  await tester.pumpAndSettle();
}
