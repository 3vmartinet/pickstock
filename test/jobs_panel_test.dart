import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/quote/quote_repo.dart';
import 'package:pickstock/ui/report/report_screen.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

const Size _wideSize = Size(1600, 1200);

/// Answers instantly, so a scan started in a widget test finishes in a pump.
class InstantQuoteRepo implements QuoteRepo {
  @override
  bool isConfigured = true;
  bool reserved = false;

  @override
  Duration get timeUntilSlot => Duration.zero;

  @override
  void reserveForJob() => reserved = true;

  @override
  void releaseJob() => reserved = false;

  @override
  Future<Quote> quoteFor(String ticker, {bool forJob = false}) async {
    if (reserved && !forJob) {
      throw const QuoteException(QuoteFailure.jobRunning);
    }
    // Well below Apple's $96.64 floor, so every company it prices is a find.
    return Quote(pricePerShare: 20, asOf: DateTime.now(), isQuoted: true);
  }
}

void main() {
  late AppDatabase database;
  late InstantQuoteRepo quotes;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    quotes = InstantQuoteRepo();
    database = await registerTestDependencies(
      withFinancials: true,
      quoteRepo: quotes,
    );
  });

  tearDown(() async {
    await database.close();
    await GetIt.I.reset();
  });

  Future<void> openPanel(WidgetTester tester) async {
    tester.view
      ..physicalSize = _wideSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PickStockApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.listChecks));
    await tester.pumpAndSettle();
  }

  testWidgets('offers a scan of whatever is filtered', (tester) async {
    await openPanel(tester);

    // Seven fixture tickers, so the button says what it is about to do.
    expect(find.text('Scan 7 companies'), findsOneWidget);
    expect(find.textContaining('No reports yet'), findsNothing);
  });

  testWidgets('a scan produces a report you can open', (tester) async {
    await openPanel(tester);
    await tester.tap(find.text('Scan 7 companies'));
    await tester.pumpAndSettle();

    // Reopen the panel: the finished report is listed.
    await tester.tap(find.byIcon(LucideIcons.listChecks));
    await tester.pumpAndSettle();
    expect(find.textContaining('undervalued'), findsWidgets);

    await tester.tap(find.textContaining('undervalued').last);
    await tester.pumpAndSettle();

    expect(find.byType(ReportScreen), findsOneWidget);
    expect(find.text('Upside to low'), findsWidgets);
    // Apple is priced at $20 against a floor of $96.64, so it is in there.
    expect(find.text('AAPL'), findsWidgets);
  });

  testWidgets('the scan takes the quote budget while it runs', (tester) async {
    await openPanel(tester);
    expect(quotes.reserved, isFalse);

    await tester.tap(find.text('Scan 7 companies'));
    await tester.pumpAndSettle();

    // Handed back once the run is over, so browsing works again.
    expect(quotes.reserved, isFalse);
  });
}
