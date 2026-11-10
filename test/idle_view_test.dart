import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/price_repo.dart';
import 'package:pickstock/repo/settings/settings_repo.dart';
import 'package:pickstock/ui/snapshot/market_leaders_view_model.dart';
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

  testWidgets('ranks the largest companies overall and by sector', (
    tester,
  ) async {
    await _seedCompanies();
    final prices = GetIt.I.get<PriceRepo>();
    final asOf = DateTime(2026, 11, 6, 21);
    Future<void> price(String cik, double perShare) => prices.save(
      cik,
      Quote(pricePerShare: perShare, asOf: asOf, isQuoted: true),
    );
    // Apple $4.45T and NVIDIA $3.65T in tech, Microsoft $3.00T in tech too,
    // Berkshire $1.08T on its own in finance.
    await price(_apple, 300);
    await price(_nvidia, 150);
    await price(_microsoft, 400);
    await price(_berkshire, 500);

    await _pumpApp(tester);

    expect(find.text('Largest by market value'), findsOneWidget);
    double top(String text) => tester.getTopLeft(find.text(text).first).dy;
    expect(top(r'$4.45T'), lessThan(top(r'$3.65T')));
    expect(top(r'$3.65T'), lessThan(top(r'$3.00T')));
    expect(top(r'$3.00T'), lessThan(top(r'$1.08T')));
    expect(
      find.text('Share price × shares outstanding. Prices as of 6 Nov 21:00.'),
      findsOneWidget,
    );

    // Each again in its own sector, in the filter's order: tech, then
    // finance, which holds Berkshire alone.
    expect(find.text('Largest by sector'), findsOneWidget);
    expect(find.text('Tech'), findsWidgets);
    expect(find.text('Finance'), findsWidgets);
    expect(find.text(r'$4.45T'), findsNWidgets(2));
    expect(find.text(r'$1.08T'), findsNWidgets(2));
    // Berkshire trades only under share classes, so the first of them.
    expect(find.text('BRK-A'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('quotes the common stock, never a foreign OTC line', () {
    expect(primarySymbol(['JPM', 'JPM-PC', 'VYLD']), 'JPM');
    expect(primarySymbol(['CMCSA', 'CCZ']), 'CMCSA');
    expect(primarySymbol(['ORCL-PD', 'ORCL']), 'ORCL');
    expect(primarySymbol(['BRK-A', 'BRK-B']), 'BRK-A');
    expect(primarySymbol(['BEIGF']), isNull);
    expect(primarySymbol(['BEIGF', 'ONC']), 'ONC');
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

const String _apple = '0000320193';
const String _nvidia = '0001045810';
const String _microsoft = '0000789019';
const String _berkshire = '0001067983';

/// Share counts, industries and a year of earnings for four of the test
/// directory's filers: what picks them as worth pricing.
Future<void> _seedCompanies() async {
  final database = GetIt.I.get<AppDatabase>();
  const companies = [
    (_apple, 'Apple Inc.', 3571, 14.84e9, 112e9),
    (_nvidia, 'NVIDIA CORP', 3674, 24.3e9, 73e9),
    (_microsoft, 'MICROSOFT CORP', 7372, 7.5e9, 88e9),
    (_berkshire, 'BERKSHIRE HATHAWAY INC', 6331, 2.16e9, 89e9),
  ];
  await database.batch((batch) {
    batch.insertAll(database.companies, [
      for (final (cik, name, sic, shares, _) in companies)
        CompaniesCompanion.insert(
          cik: cik,
          name: name,
          sic: Value(sic),
          sharesOutstanding: Value(shares),
        ),
    ], mode: InsertMode.insertOrReplace);
    batch.insertAll(database.fiscalYears, [
      for (final (cik, _, _, _, netIncome) in companies)
        FiscalYearsCompanion.insert(
          cik: cik,
          fiscalYear: 2025,
          netIncome: Value(netIncome),
        ),
    ], mode: InsertMode.insertOrReplace);
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
