import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

const Size _desktopSize = Size(1440, 1200);

void main() {
  late AppDatabase database;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    database = await registerTestDependencies();
  });

  tearDown(() async {
    await database.close();
    await GetIt.I.reset();
  });

  Future<void> report(WidgetTester tester, String ticker) async {
    tester.view
      ..physicalSize = _desktopSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ticker);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  testWidgets('a filer that owes money is headed Net debt', (tester) async {
    await report(tester, 'AAPL');

    // The card names its own side of zero, so the amount needs no sign.
    expect(find.text('Net debt'), findsWidgets);
    expect(find.text('Net cash'), findsNothing);
    // And the sanity check agrees with it.
    expect(find.text('More cash than debt?'), findsOneWidget);
    expect(find.text('Net debt of \$44B'), findsOneWidget);
  });

  testWidgets('a filer holding more cash than debt is headed Net cash', (
    tester,
  ) async {
    await report(tester, 'NVDA');

    expect(find.text('Net cash'), findsWidgets);
    expect(find.text('Net cash of \$2.14B'), findsOneWidget);
  });

  testWidgets('the card says where the prior year stood', (tester) async {
    await report(tester, 'AAPL');

    // Not a percentage: net debt turning into net cash has no sensible rate.
    expect(find.text('was net debt of \$41.5B'), findsOneWidget);
  });

  testWidgets('the table signs net debt rather than bracketing it', (
    tester,
  ) async {
    await report(tester, 'NVDA');

    // FY2026: debt 8,468 less cash 10,605 is a net cash position.
    expect(find.text('-2,137'), findsOneWidget);
    expect(find.textContaining('(2,137)'), findsNothing);
    // The column heading no longer reads like a division.
    expect(find.text('Net debt / (cash)'), findsNothing);
  });

  testWidgets('the footnote explains the sign', (tester) async {
    await report(tester, 'AAPL');

    expect(
      find.text(
        'Cash includes short-term investments. Net debt is negative when a '
        'company holds more of it than it owes.',
      ),
      findsOneWidget,
    );
  });
}
