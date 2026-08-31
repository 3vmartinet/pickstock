import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

/// Wide enough for the list and the report side by side.
const Size _wideSize = Size(1600, 1400);

/// The price field, told apart from the directory filter by its placeholder.
final Finder priceField = find.ancestor(
  of: find.text('0.00'),
  matching: find.byType(TextField),
);

void main() {
  late AppDatabase database;
  late FakeQuoteRepo quotes;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    quotes = FakeQuoteRepo();
    database = await registerTestDependencies(
      withFinancials: true,
      quoteRepo: quotes,
    );
  });

  tearDown(() async {
    await database.close();
    await GetIt.I.reset();
  });

  Future<void> openApple(WidgetTester tester, {Size size = _wideSize}) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apple Inc.'));
    await tester.pumpAndSettle();
  }

  Future<void> enterPrice(WidgetTester tester, String price) async {
    await tester.enterText(priceField, price);
    await tester.pumpAndSettle();
  }

  testWidgets('asks for a price before it will judge one', (tester) async {
    await openApple(tester);

    expect(find.text('Valuation'), findsOneWidget);
    expect(priceField, findsOneWidget);
    expect(
      find.textContaining('Enter the current share price'),
      findsOneWidget,
    );
    expect(find.text('Overvalued'), findsNothing);
  });

  testWidgets('judges the price against the band, either way', (tester) async {
    await openApple(tester);

    // Apple's FY2025 free cash flow over its share count puts the band at
    // roughly $92 to $132, so these three prices land on either side and in.
    await enterPrice(tester, '250');
    expect(find.text('Overvalued'), findsOneWidget);

    await enterPrice(tester, '80');
    expect(find.text('Undervalued'), findsOneWidget);

    await enterPrice(tester, '110');
    expect(find.text('Fairly valued'), findsOneWidget);
  });

  testWidgets('shows the working, not just the verdict', (tester) async {
    await openApple(tester);
    await enterPrice(tester, '250');

    expect(find.text('Fair range'), findsOneWidget);
    expect(find.text('To mid-range'), findsOneWidget);
    expect(find.text('Market value'), findsOneWidget);
    // The multiples and the stream they are struck against are on the card.
    expect(find.textContaining('free cash flow of \$98.8B'), findsOneWidget);
    // And the supporting ratios are there to be argued with.
    expect(find.text('P/E'), findsOneWidget);
    expect(find.text('EV/FCF'), findsOneWidget);
    expect(find.text('FCF yield'), findsOneWidget);
  });

  testWidgets('reads a comma as the decimal point', (tester) async {
    await openApple(tester);
    await enterPrice(tester, '110,50');

    expect(find.text('Fairly valued'), findsOneWidget);
  });

  // The price field sits in the section heading, beside a title that has to
  // give way to it rather than overflowing.
  testWidgets('fits a phone-width window', (tester) async {
    await openApple(tester, size: const Size(420, 900));
    await enterPrice(tester, '250');

    expect(find.text('Overvalued'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers no refresh control without a key', (tester) async {
    await openApple(tester);

    expect(find.byIcon(LucideIcons.refreshCw), findsNothing);
    expect(quotes.requested, isEmpty);
  });

  group('with a quote service configured', () {
    setUp(() {
      quotes
        ..isConfigured = true
        ..price = 250;
    });

    testWidgets('fills the price in on its own', (tester) async {
      await openApple(tester);

      expect(quotes.requested, ['AAPL']);
      expect(find.text('Overvalued'), findsOneWidget);
      expect(find.textContaining('Live · '), findsOneWidget);
      expect(find.byIcon(LucideIcons.refreshCw), findsOneWidget);
    });

    testWidgets('lets a typed price override the quote', (tester) async {
      await openApple(tester);
      expect(find.text('Overvalued'), findsOneWidget);

      await enterPrice(tester, '80');

      expect(find.text('Undervalued'), findsOneWidget);
      expect(find.text('Your price'), findsOneWidget);
    });

    testWidgets('refetches on demand', (tester) async {
      await openApple(tester);
      quotes.price = 80;

      await tester.tap(find.byIcon(LucideIcons.refreshCw));
      await tester.pumpAndSettle();

      expect(quotes.requested, ['AAPL', 'AAPL']);
      expect(find.text('Undervalued'), findsOneWidget);
    });

    testWidgets('says why a quote did not arrive', (tester) async {
      quotes
        ..price = null
        ..failure = QuoteFailure.noCoverage;

      await openApple(tester);

      expect(find.textContaining('No quote for this symbol'), findsOneWidget);
      // No price, so no verdict is invented.
      expect(find.text('Overvalued'), findsNothing);
    });

    testWidgets('keeps the last price when a refresh fails', (tester) async {
      await openApple(tester);
      expect(find.text('Overvalued'), findsOneWidget);

      quotes
        ..price = null
        ..failure = QuoteFailure.network;
      await tester.tap(find.byIcon(LucideIcons.refreshCw));
      await tester.pumpAndSettle();

      // The price stands, with the reason it is not newer.
      expect(find.text('Overvalued'), findsOneWidget);
      expect(
        find.textContaining('Could not reach the quote service'),
        findsOneWidget,
      );
    });

    testWidgets('does not requote a company just looked at', (tester) async {
      await openApple(tester);
      expect(quotes.requested, ['AAPL']);

      await tester.tap(find.text('NVIDIA CORP'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apple Inc.'));
      await tester.pumpAndSettle();

      // Apple's stored quote is still fresh, so only NVIDIA was asked for.
      expect(quotes.requested, ['AAPL', 'NVDA']);
      expect(find.text('Overvalued'), findsOneWidget);
    });
  });

  testWidgets('says what growth the price requires', (tester) async {
    await openApple(tester);
    await enterPrice(tester, '250');

    expect(find.text('What the price is asking'), findsOneWidget);
    expect(find.text('Growth the price requires'), findsOneWidget);
    // The whole discount band is on the card, not one number pretending to be
    // precise.
    expect(
      find.text('Required growth by the return a buyer wants'),
      findsOneWidget,
    );
    expect(find.textContaining('return'), findsWidgets);
  });

  testWidgets('will not judge a price against three years of filings', (
    tester,
  ) async {
    await openApple(tester);
    await enterPrice(tester, '250');

    // The fixture files three years, and a record needs more than that. The
    // required growth is still shown — it comes from the price, not the past —
    // but nothing is compared with it.
    expect(find.text('Not enough history to judge the price'), findsOneWidget);
    expect(find.text('Worth a share if it repeats its record'), findsNothing);
  });

  testWidgets('remembers the price per company', (tester) async {
    await openApple(tester);
    await enterPrice(tester, '250');
    expect(find.text('Overvalued'), findsOneWidget);

    // NVIDIA has no price of its own, so the field empties rather than
    // carrying Apple's over.
    await tester.tap(find.text('NVIDIA CORP'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Enter the current share price'),
      findsOneWidget,
    );

    // Back to Apple, and the price it was left at is still there.
    await tester.tap(find.text('Apple Inc.'));
    await tester.pumpAndSettle();
    expect(find.text('Overvalued'), findsOneWidget);
    expect((tester.widget(priceField) as TextField).controller?.text, '250.0');
  });
}
