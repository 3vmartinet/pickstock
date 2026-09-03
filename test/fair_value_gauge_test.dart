import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/snapshot/report_tab.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/ui/snapshot/widgets/fair_value_gauge.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

const Size _wideSize = Size(1600, 1400);

Rect _band(WidgetTester tester) => tester.getRect(find.byKey(fairValueBandKey));

Rect _marker(WidgetTester tester) =>
    tester.getRect(find.byKey(fairValuePriceMarkerKey));

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

  Future<void> priceApple(WidgetTester tester, String price) async {
    tester.view
      ..physicalSize = _wideSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apple Inc.'));
    await tester.pumpAndSettle();
    await openReportTab(tester, ReportTab.valuation);
    await enterPriceByHand(tester, price);
  }

  testWidgets('states each bound and how far the price is from it', (
    tester,
  ) async {
    // Apple's band is \$98.11 to \$134.29 on the fixture.
    await priceApple(tester, '250');

    expect(find.text('Range low'), findsOneWidget);
    expect(find.text('Range high'), findsOneWidget);
    expect(find.text('Price today'), findsOneWidget);
    expect(find.text('\$98.11'), findsOneWidget);
    expect(find.text('\$134.29'), findsOneWidget);
    expect(find.text('\$250.00'), findsOneWidget);
    // Both bounds are below the price, so both readings are negative: this is
    // how far it would have to fall, per bound, with no midpoint invented.
    expect(find.text('-60.8%'), findsOneWidget);
    expect(find.text('-46.3%'), findsOneWidget);
  });

  testWidgets('puts the marker inside the band when the price is fair', (
    tester,
  ) async {
    await priceApple(tester, '110');

    final band = _band(tester);
    final marker = _marker(tester);
    expect(marker.center.dx, greaterThan(band.left));
    expect(marker.center.dx, lessThan(band.right));
  });

  testWidgets('puts the marker left of the band when the price is low', (
    tester,
  ) async {
    await priceApple(tester, '40');

    expect(_marker(tester).center.dx, lessThan(_band(tester).left));
  });

  testWidgets('puts the marker right of the band when the price is high', (
    tester,
  ) async {
    await priceApple(tester, '250');

    expect(_marker(tester).center.dx, greaterThan(_band(tester).right));
  });

  testWidgets('keeps the marker on the track at an absurd price', (
    tester,
  ) async {
    await priceApple(tester, '99999');

    final gauge = tester.getRect(find.byType(FairValueGauge));
    final marker = _marker(tester);
    // Clamped rather than hanging off the end, and the band is still drawn.
    expect(marker.right, lessThanOrEqualTo(gauge.right));
    expect(_band(tester).width, greaterThan(0));
  });

  testWidgets('reads left to right in value order', (tester) async {
    await priceApple(tester, '40');

    double xOf(String label) => tester.getTopLeft(find.text(label)).dx;

    // Price below the band, so the price column comes first — the figures
    // underneath run in the same order as the marks above them.
    expect(xOf('Price today'), lessThan(xOf('Range low')));
    expect(xOf('Range low'), lessThan(xOf('Range high')));
  });
}
