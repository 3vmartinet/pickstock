import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/app.dart';
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/repo/quote/quote_repo.dart';
import 'package:pickstock/repo/sec/mock_sec_repo.dart';
import 'package:pickstock/data/report/valuation_report.dart';
import 'package:pickstock/repo/report/report_repo.dart';
import 'package:pickstock/repo/sec/sec_repo.dart';
import 'package:pickstock/ui/report/report_screen.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/test_directory.dart';

const Size _wideSize = Size(1600, 1200);

/// A reader that trips over one filer, which is what a bug in the snapshot
/// path looks like from the run's side.
///
/// [SecRepo] is explicit that anything but a [SecException] is a bug and
/// propagates, and over ten thousand real filers some will.
class BrokenSecRepo implements SecRepo {
  const BrokenSecRepo(this.brokenTicker);

  final String brokenTicker;

  @override
  Future<FinancialSnapshot> fetchSnapshot(String ticker) {
    if (ticker == brokenTicker) throw StateError('an unexpected bug');
    return const MockSecRepo().fetchSnapshot(ticker);
  }
}

/// A store that refuses the finished report, which is what a disk or database
/// failure looks like at the end of a run.
class UnwritableReportRepo implements ReportRepo {
  UnwritableReportRepo(this._inner);

  final ReportRepo _inner;

  @override
  Future<List<ValuationReport>> all() => _inner.all();

  @override
  Future<ValuationReport?> withEntries(int id) => _inner.withEntries(id);

  @override
  Future<int> save({
    required String name,
    required int consideredCount,
    required int valuedCount,
    required List<ReportEntry> entries,
  }) async => throw StateError('the disk said no');

  @override
  Future<void> rename(int id, String name) => _inner.rename(id, name);

  @override
  Future<void> delete(int id) => _inner.delete(id);
}

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

  testWidgets('one bad filer costs its own company, not the run', (
    tester,
  ) async {
    // Apple is the first filer the fixture can price and NVIDIA the last, so
    // breaking Apple leaves a company the run has yet to reach behind it.
    GetIt.I.unregister<SecRepo>();
    GetIt.I.registerSingleton<SecRepo>(const BrokenSecRepo('AAPL'));

    await openPanel(tester);
    await tester.tap(find.text('Scan 7 companies'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.listChecks));
    await tester.pumpAndSettle();

    // A scan is on offer again. Left looking like one still going, the run
    // would hold this disabled and the app bar spinning for the rest of the
    // session — which is how a single unreadable filer used to cost the
    // feature entirely.
    final scan = find.text('Scan 7 companies');
    expect(scan, findsOneWidget);
    expect(
      tester
          .widget<PrimaryButton>(
            find.ancestor(of: scan, matching: find.byType(PrimaryButton)),
          )
          .enabled,
      isTrue,
    );
    expect(find.textContaining('already running'), findsNothing);
    // And the quote budget is back, so browsing can price a company again.
    expect(quotes.reserved, isFalse);

    // The run also carried on past the filer it could not read: NVIDIA comes
    // after Apple, and a run abandoned at Apple never reaches it.
    await tester.tap(find.textContaining('undervalued').last);
    await tester.pumpAndSettle();
    expect(find.byType(ReportScreen), findsOneWidget);
    expect(find.text('NVDA'), findsWidgets);
    expect(find.text('AAPL'), findsNothing);
  });

  testWidgets('a run whose report cannot be saved still ends', (tester) async {
    final inner = GetIt.I.get<ReportRepo>();
    GetIt.I.unregister<ReportRepo>();
    GetIt.I.registerSingleton<ReportRepo>(UnwritableReportRepo(inner));

    await openPanel(tester);
    await tester.tap(find.text('Scan 7 companies'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.listChecks));
    await tester.pumpAndSettle();

    // Nothing to open, and nothing pretending to still be running: three
    // hours of work is lost either way, and a job frozen at running would
    // cost every scan after it as well.
    final scan = find.text('Scan 7 companies');
    expect(
      tester
          .widget<PrimaryButton>(
            find.ancestor(of: scan, matching: find.byType(PrimaryButton)),
          )
          .enabled,
      isTrue,
    );
    expect(find.textContaining('already running'), findsNothing);
    expect(quotes.reserved, isFalse);
  });
}
