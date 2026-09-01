import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/data/report/valuation_job.dart';
import 'package:pickstock/data/report/valuation_report.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/valuation/valuation.dart';
import 'package:pickstock/extensions/object_extensions.dart';
import 'package:pickstock/repo/price_repo.dart';
import 'package:pickstock/repo/quote/quote_repo.dart';
import 'package:pickstock/repo/report/report_repo.dart';
import 'package:pickstock/repo/sec/sec_repo.dart';

SecRepo get _secRepo => GetIt.I.get<SecRepo>();
QuoteRepo get _quoteRepo => GetIt.I.get<QuoteRepo>();
PriceRepo get _priceRepo => GetIt.I.get<PriceRepo>();
ReportRepo get _reportRepo => GetIt.I.get<ReportRepo>();

/// How often the running job republishes its progress.
///
/// Every company would rebuild the overlay hundreds of times a minute for no
/// visible gain; a second is fast enough to look live.
const Duration jobTickInterval = Duration(seconds: 1);

/// Added to the wait for a free call, to cover the clock drifting between the
/// moment the wait is computed and the moment the call is claimed.
const Duration _budgetMargin = Duration(milliseconds: 500);

/// How many times to wait again before giving up on a company.
const int _budgetRetries = 3;

/// Runs bulk valuations and keeps the finished ones.
///
/// App-level and long-lived: a run takes tens of minutes, and navigating away
/// from the list that started it must not abandon it.
class JobsViewModel extends ChangeNotifier {
  JobsViewModel() {
    unawaited(_loadReports());
  }

  final List<ValuationJob> _jobs = [];

  /// Runs first, then the ones that have finished this session.
  List<ValuationJob> get jobs => List.unmodifiable(_jobs);

  List<ValuationReport> _reports = const [];

  /// Saved reports, newest first.
  List<ValuationReport> get reports => _reports;

  bool get hasRunning => _jobs.any((job) => job.isRunning);

  int get runningCount => _jobs.where((job) => job.isRunning).length;

  /// Anything worth opening the overlay for.
  bool get hasAnything => _jobs.isNotEmpty || _reports.isNotEmpty;

  int _nextJobId = 1;
  Timer? _ticker;

  /// Starts a run over [companies], naming the report after [name].
  ///
  /// Refuses a second run: the two would fight over one per-minute budget and
  /// both would take twice as long.
  bool start({required String name, required List<Company> companies}) {
    if (hasRunning) return false;
    final subjects = _oneTickerPerCompany(companies);
    if (subjects.isEmpty) return false;

    final job = ValuationJob(
      id: _nextJobId++,
      name: name,
      total: subjects.length,
      startedAt: DateTime.now(),
    );
    _jobs.insert(0, job);
    notifyListeners();

    // A steady tick, so the remaining-time estimate moves even between
    // companies rather than freezing on a slow one.
    _ticker = Timer.periodic(jobTickInterval, (_) => notifyListeners());
    unawaited(_run(job.id, subjects));
    return true;
  }

  /// One entry per filer, keeping whichever symbol the ordering puts first.
  ///
  /// A company can list many times — Bank of America has seventeen tickers,
  /// mostly preferred shares, and a warrant shares its issuer's filings. All of
  /// them resolve to the same CIK and the same figures, so pricing each one
  /// would spend the budget several times over on one answer, and two rows for
  /// one company cannot both be stored against a report.
  static List<Company> _oneTickerPerCompany(List<Company> companies) {
    final seen = <String>{};
    return [
      for (final company in companies)
        if (seen.add(company.cik)) company,
    ];
  }

  /// Stops the running job. What it has found so far is kept.
  void cancel(int jobId) {
    final index = _jobs.indexWhere((job) => job.id == jobId);
    if (index < 0 || !_jobs[index].isRunning) return;
    _jobs[index] = _jobs[index].copyWith(state: JobState.cancelled);
    notifyListeners();
  }

  Future<void> _run(int jobId, List<Company> companies) async {
    _quoteRepo.reserveForJob();
    final found = <ReportEntry>[];
    var valued = 0;

    try {
      for (final company in companies) {
        if (_jobOf(jobId)?.isRunning != true) break;

        final entry = await _valueOf(company);
        if (entry != null) {
          valued++;
          // Only the undervalued make the report: it answers "what is cheap",
          // and two thousand rows of "not cheap" would bury the answer.
          if (entry.upsidePercent > 0) found.add(entry);
        }
        _update(
          jobId,
          (job) =>
              job.copyWith(processed: job.processed + 1, found: found.length),
        );
      }
    } finally {
      _quoteRepo.releaseJob();
      _ticker?.cancel();
      _ticker = null;
    }

    found.sort((a, b) => b.upsidePercent.compareTo(a.upsidePercent));
    final job = _jobOf(jobId);
    if (job == null) return;

    final reportId = await _reportRepo.save(
      name: job.name,
      consideredCount: job.total,
      valuedCount: valued,
      entries: found,
    );
    await _loadReports();

    _update(
      jobId,
      (current) => current.copyWith(
        state: current.state == JobState.cancelled
            ? JobState.cancelled
            : JobState.done,
        reportId: reportId,
        found: found.length,
      ),
    );
  }

  /// Values one company, or `null` where it cannot be valued or priced.
  ///
  /// The same bar the valuation tab applies: no share count, no positive cash
  /// stream, or no quote means no verdict rather than a guessed one.
  Future<ReportEntry?> _valueOf(Company company) async {
    try {
      final snapshot = await _secRepo.fetchSnapshot(company.ticker);
      if ((snapshot.company.sharesOutstanding ??
              snapshot.latest.dilutedShares) ==
          null) {
        return null;
      }

      final quote = await _pacedQuote(company.ticker);
      await _priceRepo.save(company.cik, quote);

      final valuation = Valuation(
        snapshot: snapshot,
        pricePerShare: quote.pricePerShare,
      );
      final low = valuation.fairValueLow;
      final high = valuation.fairValueHigh;
      final upside = valuation.percentToLow;
      if (low == null || high == null || upside == null) return null;

      return ReportEntry(
        cik: company.cik,
        ticker: company.ticker,
        name: company.name,
        pricePerShare: quote.pricePerShare,
        fairValueLow: low,
        fairValueHigh: high,
        upsidePercent: upside,
      );
    } on QuoteException catch (error) {
      logInfo(() => 'No quote for ${company.ticker}: ${error.failure.name}');
      return null;
    } on SecException {
      return null;
    }
  }

  /// Waits for the budget rather than walking into a refusal.
  ///
  /// Waiting the exact time a slot needs leaves it a hair short — the window
  /// is measured against the clock at both ends — and the call is refused,
  /// which used to drop the company from the report silently. A small margin
  /// and a couple of retries turn that into a pause.
  Future<Quote> _pacedQuote(String ticker) async {
    for (var attempt = 0; ; attempt++) {
      final wait = _quoteRepo.timeUntilSlot;
      if (wait > Duration.zero) {
        await Future<void>.delayed(wait + _budgetMargin);
      }
      try {
        return await _quoteRepo.quoteFor(ticker, forJob: true);
      } on QuoteException catch (error) {
        if (error.failure != QuoteFailure.rateLimited ||
            attempt >= _budgetRetries) {
          rethrow;
        }
      }
    }
  }

  Future<void> _loadReports() async {
    _reports = await _reportRepo.all();
    notifyListeners();
  }

  Future<void> renameReport(int id, String name) async {
    await _reportRepo.rename(id, name);
    await _loadReports();
  }

  Future<void> deleteReport(int id) async {
    await _reportRepo.delete(id);
    // A finished job pointing at a deleted report has nothing left to open.
    _jobs.removeWhere((job) => job.reportId == id);
    await _loadReports();
  }

  Future<ValuationReport?> load(int id) => _reportRepo.withEntries(id);

  ValuationJob? _jobOf(int id) =>
      _jobs.where((job) => job.id == id).firstOrNull;

  void _update(int id, ValuationJob Function(ValuationJob) change) {
    final index = _jobs.indexWhere((job) => job.id == id);
    if (index < 0) return;
    _jobs[index] = change(_jobs[index]);
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
