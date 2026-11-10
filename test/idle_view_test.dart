import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/repo/price_repo.dart';
import 'package:pickstock/repo/settings/settings_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

const Size _desktopSize = Size(1600, 1200);

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await registerTestDependencies();
  });

  tearDown(GetIt.I.reset);

  testWidgets('a first launch shows only the introduction', (tester) async {
    await _pumpApp(tester);

    expect(find.text('Select a company'), findsOneWidget);
    // Nothing opened yet, and nothing priced to rank.
    expect(find.text('Recently viewed'), findsNothing);
    expect(find.text('Largest by market value'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ranks the largest companies by stored price', (tester) async {
    final prices = GetIt.I.get<PriceRepo>();
    final asOf = DateTime(2026, 11, 6, 21);
    // Apple: 14.84B shares at $300 = $4.45T. NVIDIA: 24.3B at $150 = $3.65T.
    await prices.save(
      '0000320193',
      Quote(pricePerShare: 300, asOf: asOf, isQuoted: true),
    );
    await prices.save(
      '0001045810',
      Quote(pricePerShare: 150, asOf: asOf, isQuoted: true),
    );

    await _pumpApp(tester);

    expect(find.text('Largest by market value'), findsOneWidget);
    final apple = tester.getTopLeft(find.text('Apple Inc.').last);
    final nvidia = tester.getTopLeft(find.text('NVIDIA CORP').last);
    expect(apple.dy, lessThan(nvidia.dy));
    expect(find.text(r'$4.45T'), findsOneWidget);
    expect(find.text(r'$3.65T'), findsOneWidget);
    expect(
      find.text('Share price × shares outstanding. Prices as of 6 Nov 21:00.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('remembers the companies opened, across launches', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _search(tester, 'NVDA');
    await _search(tester, 'AAPL');
    await _search(tester, 'NVDA');

    // Most recent first, each company once.
    expect(GetIt.I.get<SettingsRepo>().recentTickers, ['NVDA', 'AAPL']);

    // A new launch, with the remembered list read back from the database.
    await tester.pumpWidget(const SizedBox());
    await GetIt.I.get<SettingsRepo>().load();
    await _pumpApp(tester);

    expect(find.text('Recently viewed'), findsOneWidget);
    final chips = find.ancestor(
      of: find.text('NVDA'),
      matching: find.byType(OutlineButton),
    );
    expect(chips, findsOneWidget);

    await tester.tap(chips);
    await tester.pumpAndSettle();
    expect(find.text('Recently viewed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps no more than ten companies', (tester) async {
    final settings = GetIt.I.get<SettingsRepo>();
    await settings.setRecentTickers([for (var i = 0; i < 10; i++) 'T$i']);
    await _pumpApp(tester);
    await _search(tester, 'AAPL');

    final recent = settings.recentTickers;
    expect(recent, hasLength(10));
    expect(recent.first, 'AAPL');
    expect(recent, isNot(contains('T9')));
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view
    ..physicalSize = _desktopSize
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const PickStockApp());
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester, String ticker) async {
  await tester.enterText(find.byType(TextField), ticker);
  await tester.pump();
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}
