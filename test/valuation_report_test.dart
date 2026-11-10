import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/data/report/valuation_job.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/quote/quote_repo.dart';
import 'package:pickstock/ui/report/jobs_view_model.dart';

import 'support/test_directory.dart';

/// Prices whatever it is asked for, from a table the test controls.
class ScriptedQuoteRepo implements QuoteRepo {
  ScriptedQuoteRepo(this.prices);

  final Map<String, double> prices;
  final List<String> asked = [];
  bool reserved = false;

  @override
  bool isConfigured = true;

  @override
  Duration get timeUntilSlot => Duration.zero;

  @override
  void reserveForJob() => reserved = true;

  @override
  void releaseJob() => reserved = false;

  @override
  Future<Quote> quoteFor(String ticker, {bool forJob = false}) async {
    asked.add(ticker);
    final price = prices[ticker];
    if (price == null) throw const QuoteException(QuoteFailure.noCoverage);
    return Quote(pricePerShare: price, asOf: DateTime.now(), isQuoted: true);
  }
}

const _apple = Company(ticker: 'AAPL', cik: '0000320193', name: 'Apple Inc.');
const _nvidia = Company(ticker: 'NVDA', cik: '0001045810', name: 'NVIDIA CORP');
const _berkshire = Company(
  ticker: 'BRK-A',
  cik: '0001067983',
  name: 'BERKSHIRE HATHAWAY INC',
);

/// Waits for the run to finish.
///
/// Real delays, not zero-duration ones: the fixture's SEC repo answers after
/// 900ms per company to imitate a fetch, so a busy loop would spin without
/// letting any of it happen.
Future<void> _finish(JobsViewModel jobs) async {
  for (var i = 0; i < 200; i++) {
    if (!jobs.hasRunning) {
      // The report is saved just after the run stops.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('the job never finished');
}

void main() {
  late AppDatabase database;
  late ScriptedQuoteRepo quotes;
  late JobsViewModel jobs;

  Future<void> boot(Map<String, double> prices) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    quotes = ScriptedQuoteRepo(prices);
    database = await registerTestDependencies(
      withFinancials: true,
      quoteRepo: quotes,
    );
    jobs = JobsViewModel();
    await Future<void>.delayed(Duration.zero);
  }

  tearDown(() async {
    jobs.dispose();
    await database.close();
    await GetIt.I.reset();
  });

  test('keeps only the companies priced below their range', () async {
    // Apple's band on the fixture is $96.64–$136.57 and NVIDIA's is far above
    // $200, so a cheap Apple and a dear NVIDIA split the two ways.
    await boot({'AAPL': 40, 'NVDA': 100000});

    jobs.start(name: 'Test scan', companies: [_apple, _nvidia]);
    await _finish(jobs);

    final report = await jobs.load(jobs.reports.single.id);
    expect(report!.entries.map((e) => e.ticker), ['AAPL']);
    expect(report.entries.single.upsidePercent, greaterThan(0));
    expect(report.consideredCount, 2);
    expect(report.valuedCount, 2);
  });

  test('ranks the most undervalued first', () async {
    await boot({'AAPL': 40, 'NVDA': 1});

    jobs.start(name: 'Test scan', companies: [_apple, _nvidia]);
    await _finish(jobs);

    final report = await jobs.load(jobs.reports.single.id);
    final upsides = report!.entries.map((e) => e.upsidePercent).toList();
    expect(upsides, hasLength(2));
    expect(upsides.first, greaterThan(upsides.last));
  });

  test('skips companies it cannot value, and says how many', () async {
    // Berkshire has one fiscal year in the fixture and no share count.
    await boot({'AAPL': 40, 'BRK-A': 100});

    jobs.start(name: 'Test scan', companies: [_apple, _berkshire]);
    await _finish(jobs);

    final report = await jobs.load(jobs.reports.single.id);
    expect(report!.consideredCount, 2);
    expect(report.valuedCount, 1, reason: 'Berkshire cannot be valued');
    expect(report.entries.map((e) => e.ticker), ['AAPL']);
  });

  test(
    'a company with no quote is skipped rather than failing the run',
    () async {
      await boot({'AAPL': 40});

      jobs.start(name: 'Test scan', companies: [_apple, _nvidia]);
      await _finish(jobs);

      expect(quotes.asked, containsAll(['AAPL', 'NVDA']));
      final report = await jobs.load(jobs.reports.single.id);
      expect(report!.entries.map((e) => e.ticker), ['AAPL']);
    },
  );

  test('prices a company once however many tickers it lists under', () async {
    await boot({'AAPL': 40, 'AAPL-P': 40});

    // XBP and its warrant XBPEW share one CIK, as do Bank of America's
    // seventeen listings. Pricing each symbol spends the budget several times
    // on one answer, and two rows for one company cannot both be stored.
    const preferred = Company(
      ticker: 'AAPL-P',
      cik: '0000320193',
      name: 'Apple Inc.',
    );
    jobs.start(name: 'Test scan', companies: [_apple, preferred]);
    await _finish(jobs);

    expect(jobs.jobs.single.total, 1, reason: 'one company, not two symbols');
    expect(quotes.asked, ['AAPL']);

    final report = await jobs.load(jobs.reports.single.id);
    expect(report!.entries, hasLength(1));
    expect(report.consideredCount, 1);
  });

  test('holds the quote budget only while it runs', () async {
    await boot({'AAPL': 40});

    jobs.start(name: 'Test scan', companies: [_apple]);
    await _finish(jobs);

    // Released even though the run is over, so browsing works again.
    expect(quotes.reserved, isFalse);
  });

  test('refuses a second run while one is going', () async {
    await boot({'AAPL': 40, 'NVDA': 100});

    expect(jobs.start(name: 'First', companies: [_apple, _nvidia]), isTrue);
    expect(jobs.start(name: 'Second', companies: [_apple]), isFalse);
    await _finish(jobs);
    expect(jobs.reports, hasLength(1));
  });

  test('a finished job points at the report it saved', () async {
    await boot({'AAPL': 40});

    jobs.start(name: 'Test scan', companies: [_apple]);
    await _finish(jobs);

    final job = jobs.jobs.single;
    expect(job.state, JobState.done);
    expect(job.reportId, jobs.reports.single.id);
    expect(job.progress, 1.0);
  });

  test(
    'reports survive a new view model, and can be renamed and deleted',
    () async {
      await boot({'AAPL': 40});
      jobs.start(name: 'Test scan', companies: [_apple]);
      await _finish(jobs);
      final id = jobs.reports.single.id;

      // A fresh view model over the same database is what the next launch gets.
      final next = JobsViewModel();
      await Future<void>.delayed(Duration.zero);
      expect(next.reports.single.name, 'Test scan');

      await next.renameReport(id, 'Cheap tech');
      expect(next.reports.single.name, 'Cheap tech');

      await next.deleteReport(id);
      expect(next.reports, isEmpty);
      expect(await database.entriesForReport(id), isEmpty);
      next.dispose();
    },
  );
}
