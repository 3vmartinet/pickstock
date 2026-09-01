import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/snapshot/report_tab.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/ui/snapshot/widgets/napkin_math.dart';
import 'package:pickstock/ui/snapshot/widgets/valuation_verdict_card.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

/// Wide enough for the worked example to sit beside the verdict.
const Size _wideSize = Size(1900, 1600);

/// Wide enough for the report, too narrow to split it.
const Size _narrowSize = Size(1100, 1600);

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

  Future<void> openApple(WidgetTester tester, Size size, String price) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apple Inc.'));
    await tester.pumpAndSettle();
    await openReportTab(tester, ReportTab.valuation);
    await enterPriceByHand(tester, price);
  }

  testWidgets('walks through the arithmetic with the real figures', (
    tester,
  ) async {
    await openApple(tester, _wideSize, '250');

    // Every step states its own numbers, so the reader can check them rather
    // than trust them.
    expect(
      find.textContaining('A share costs \$250.00. There are 14.8B of them'),
      findsOneWidget,
    );
    expect(
      find.textContaining('buying every share costs \$3.71T'),
      findsOneWidget,
    );
    expect(find.textContaining('kept \$98.8B'), findsOneWidget);
    // Apple owes more than it holds, so the buyer inherits the difference.
    expect(find.text('You also inherit the debts'), findsOneWidget);
    expect(
      find.textContaining('It owes \$44B more than it holds'),
      findsOneWidget,
    );
    expect(
      find.textContaining('one share is worth \$93.67 to \$133.61'),
      findsOneWidget,
    );
    expect(
      find.textContaining('You are paying \$250.00, above the'),
      findsOneWidget,
    );
  });

  testWidgets('follows the verdict when the price changes', (tester) async {
    await openApple(tester, _wideSize, '80');

    expect(
      find.textContaining('You are paying \$80.00, below the'),
      findsOneWidget,
    );

    await enterPriceByHand(tester, '110');
    expect(
      find.textContaining('You are paying \$110.00, inside the'),
      findsOneWidget,
    );
  });

  testWidgets('warns where the plain reading would mislead', (tester) async {
    // NVIDIA's FY2026 capital spending is well above what wore out, so the
    // year's leftover cash understates the business.
    await openApple(tester, _wideSize, '250');
    await tester.tap(find.text('NVIDIA CORP'));
    await tester.pumpAndSettle();
    await openReportTab(tester, ReportTab.valuation);
    await enterPriceByHand(tester, '200');

    expect(find.text('Worth knowing'), findsOneWidget);
    expect(
      find.textContaining('more on equipment than wore out'),
      findsOneWidget,
    );
  });

  testWidgets('sits beside the verdict, and below it when narrow', (
    tester,
  ) async {
    await openApple(tester, _wideSize, '250');
    final card = tester.getRect(find.byType(ValuationVerdictCard));
    final napkin = tester.getRect(find.byType(NapkinMath));
    expect(napkin.left, greaterThan(card.right));

    tester.view.physicalSize = _narrowSize;
    await tester.pumpAndSettle();
    final stackedCard = tester.getRect(find.byType(ValuationVerdictCard));
    final stackedNapkin = tester.getRect(find.byType(NapkinMath));
    expect(stackedNapkin.top, greaterThan(stackedCard.top));
    expect(stackedNapkin.left, stackedCard.left);
  });

  testWidgets('says nothing without a price to work from', (tester) async {
    await openApple(tester, _wideSize, '');

    expect(find.byType(NapkinMath), findsNothing);
  });
}
