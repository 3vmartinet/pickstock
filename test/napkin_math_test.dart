import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/snapshot/report_tab.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/theme_repo.dart';
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
    // The typical year rather than the last one: Apple's three years on the
    // fixture convert 26%, 27.8% and 23.7% of revenue, and the middle one
    // applied to FY2025's revenue is $108.1B against the $98.8B it reported.
    expect(find.textContaining('keeps \$108B'), findsOneWidget);
    expect(find.textContaining('middle year of the last 3'), findsOneWidget);
    expect(find.textContaining('not a pile it has saved up'), findsOneWidget);
    // Apple owes more than it holds, and the step says why that is already
    // reflected in the cash figure rather than subtracted from it again.
    expect(
      find.text('It owes money, and that is already counted'),
      findsOneWidget,
    );
    expect(
      find.textContaining('owes \$44B more than it holds'),
      findsOneWidget,
    );
    expect(find.text('It owes more than it can carry'), findsNothing);
    // The no-growth multiple is stated rather than asserted: at the 9.0% a
    // buyer is assumed to want, a flat business is worth 14.1 years of its
    // cash, and the range either side is what a point of that return does.
    expect(
      find.textContaining('worth about 14.1 years of its cash'),
      findsOneWidget,
    );
    // Growth is per share: 4.7% and 9.4% over Apple's two changes, whose
    // middle is 7.0%, where plain revenue grew 2.0% and 6.4%.
    expect(find.textContaining('grew 7.0% per share'), findsOneWidget);
    // Step five states the range; step six restates it on the way to a
    // price, so the phrase either side pins which one this is.
    expect(
      find.textContaining('worth more: 16.7 to 22.9 years'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Divide by 14.8B shares: \$121.43 to \$167.16'),
      findsOneWidget,
    );
    // The margin of safety, stated with the figure it produces.
    expect(find.textContaining('cut by 30.0%, to \$85.00'), findsOneWidget);
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
    // NVIDIA files a current share count, so the step-one figure is the
    // company's own and needs no qualifying.
    expect(find.textContaining('files no current share count'), findsNothing);
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

  testWidgets('sets the figures apart from the prose', (tester) async {
    await openApple(tester, _wideSize, '250');

    // Every step is one rich sentence: the words muted, the numbers in the
    // foreground weight, so a reader can find them without parsing the line.
    final sentences = find.descendant(
      of: find.byType(NapkinMath),
      matching: find.byType(Text),
    );
    var emphasised = 0;
    for (final element in sentences.evaluate()) {
      final span = (element.widget as Text).textSpan;
      if (span == null) continue;
      span.visitChildren((child) {
        if (child is TextSpan &&
            child.style?.fontWeight == ThemeRepo.napkinFigureWeight) {
          emphasised++;
          // Only figures are picked out, never the words around them.
          expect(child.text, matches(RegExp(r'^\$?\d')));
        }
        return true;
      });
    }
    // Seven steps, each carrying at least one figure.
    expect(emphasised, greaterThan(10));
  });

  testWidgets('says nothing without a price to work from', (tester) async {
    await openApple(tester, _wideSize, '');

    expect(find.byType(NapkinMath), findsNothing);
  });
}
