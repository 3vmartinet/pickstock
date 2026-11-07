import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/valuation/valuation.dart';
import 'package:pickstock/data/valuation/valuation_verdict.dart';
import 'package:pickstock/extensions/object_extensions.dart';
import 'package:pickstock/repo/market/market_rates_repo.dart';
import 'package:pickstock/repo/price_repo.dart';
import 'package:pickstock/repo/quote/quote_repo.dart';
import 'package:pickstock/repo/sec/sec_repo.dart';

SecRepo get _secRepo => GetIt.I.get<SecRepo>();
QuoteRepo get _quoteRepo => GetIt.I.get<QuoteRepo>();
PriceRepo get _priceRepo => GetIt.I.get<PriceRepo>();
MarketRatesRepo get _marketRatesRepo => GetIt.I.get<MarketRatesRepo>();

/// How long a company's price is left alone after it was last asked for.
///
/// The list prices whatever scrolls into view, and a list is scrolled back and
/// forth: without a guard, every pass over the same tiles would ask again for
/// prices that cannot have moved enough to change a verdict. Read from the
/// time stored with the price, so it holds across launches too.
const Duration listPriceGuard = Duration(minutes: 15);

/// The pause between two quotes asked for by the list.
///
/// Finnhub allows sixty calls a minute. Two seconds apart is thirty, which
/// leaves the other half to the report the reader opens — a price they are
/// waiting for should never queue behind tiles they scrolled past.
const Duration listQuoteSpacing = Duration(seconds: 2);

/// How long to stand back when the budget is spent or held by a bulk run.
const Duration _blockedRetry = Duration(minutes: 1);

/// The most tiles waiting to be priced. Past this the oldest requests are the
/// tiles scrolled past longest ago, and are dropped first.
const int _maxQueued = 60;

/// The valuation verdict for each company tile in the list, priced in the
/// background as tiles come into view.
///
/// The same verdict the valuation tab shows, from the same arithmetic: the
/// filed figures and a share price. The price is the stored one while it is
/// fresh, and a new quote once it is older than [listPriceGuard]. The discount
/// rate is the company's own only if it is already held — fetching it is a
/// second request per company — and the assumed rate otherwise, as the bulk
/// scan does; the selected tile follows the report, which has the real one.
///
/// Newest request first: the tiles on screen now are the ones the reader is
/// looking at, and a tile scrolled past a minute ago can wait or be dropped.
class ListValuationViewModel extends ChangeNotifier {
  /// Whether tiles are priced at all. On in the app; the test harness turns
  /// it off, because a test about anything else that happens to configure a
  /// quote key would otherwise have quotes spent and filings read behind its
  /// back, and fail on whichever of them was still in flight when it ended.
  static bool isEnabled = true;

  final Map<String, ValuationVerdict> _verdicts = {};

  /// When each company was last priced or looked at, this session. The stored
  /// fetch time covers earlier sessions; this covers companies with no price
  /// to store, so a symbol the provider does not cover is not asked about on
  /// every rebuild.
  final Map<String, DateTime> _lastAsked = {};

  /// When the report last handed over its verdict for a company. A pricing
  /// that started before then is older news and does not overwrite it.
  final Map<String, DateTime> _reportedAt = {};

  /// Waiting to be priced, the most recent request last.
  final List<Company> _queue = [];

  /// The rest of the list, worked through once [_queue] is empty while the
  /// list is filtered by verdict: see [sweep].
  List<Company> _sweep = const [];
  int _sweepNext = 0;

  /// The list [_sweep] was taken from, so the same list handed over again on
  /// every rebuild does not start the sweep over.
  List<Company>? _sweepSource;

  /// Bumped whenever a verdict changes, so a listener can tell a new verdict
  /// from any other notification without comparing every one of them.
  int _revision = 0;
  int get revision => _revision;

  /// The company being priced right now, if any.
  String? _inFlight;

  bool _isWorking = false;
  bool _isDisposed = false;

  /// The pause in progress, cancelled on dispose so nothing outlives the app.
  Timer? _pause;
  Completer<void>? _pauseDone;

  /// The verdict for [cik], or `null` until it is known.
  ValuationVerdict? verdictFor(String cik) => _verdicts[cik];

  /// Every verdict known, by CIK. A view, not a copy: read it again after
  /// [revision] moves rather than holding on to what it said.
  Map<String, ValuationVerdict> get verdicts => UnmodifiableMapView(_verdicts);

  /// Whether tiles can be priced at all, which is what the verdict filter
  /// needs to be offered.
  bool get canValue => isEnabled && _quoteRepo.isConfigured;

  /// How many companies of the [sweep] are still to be looked at.
  int get sweepRemaining => _sweep.length - _sweepNext;

  /// Whether [cik] is waiting to be priced or being priced, which is what the
  /// tile animates while it has no verdict to show yet.
  bool isPending(String cik) =>
      _inFlight == cik || _queue.any((company) => company.cik == cik);

  /// Asks for [company] to be priced, if it has not been lately.
  ///
  /// Called by a tile as it is built, so it does no work synchronously and
  /// notifies nobody until a verdict has actually changed.
  void request(Company company) {
    // Without a key there is nothing to fetch, and the list says nothing
    // rather than half of it.
    if (!isEnabled || !_quoteRepo.isConfigured || _isDisposed) return;
    if (_isGuarded(company.cik)) return;

    // Moved to the front if it was already waiting: it is on screen again.
    _queue.removeWhere((queued) => queued.cik == company.cik);
    _queue.add(company);
    if (_queue.length > _maxQueued) {
      _queue.removeAt(0);
      // The dropped tile was animating as pending; tell it, but not from
      // inside the build that is asking.
      scheduleMicrotask(_notify);
    }
    unawaited(_work());
  }

  /// Takes the report's [verdict] for [cik] as the tile's own.
  ///
  /// The report judges with the company's own discount rate, where the list
  /// makes do with a cached or assumed one. Without this, a tile would show
  /// the report's verdict while selected and fall back to its own, possibly
  /// different, the moment another tile was picked.
  void adopt(String cik, ValuationVerdict verdict) {
    if (_isDisposed) return;
    final now = DateTime.now();
    _reportedAt[cik] = now;
    // Nothing to price that the report has not just priced better.
    _lastAsked[cik] = now;
    _queue.removeWhere((company) => company.cik == cik);
    if (_verdicts[cik] == verdict) return;
    _verdicts[cik] = verdict;
    _revision++;
    notifyListeners();
  }

  /// Prices every company in [candidates] that has no verdict yet, after
  /// the tiles on screen, or stops with an empty list.
  ///
  /// What filtering by verdict needs: a tile is only priced once it is on
  /// screen, and with the list narrowed to one verdict the companies not yet
  /// judged are never on screen to be priced. Top of the list first, so the
  /// filtered list fills in from the top; companies already judged are
  /// skipped rather than asked about again.
  ///
  /// Called from a build, so it notifies nobody.
  void sweep(List<Company> candidates) {
    if (identical(candidates, _sweepSource)) return;
    _sweepSource = candidates;
    if (!canValue || _isDisposed) {
      _sweep = const [];
      _sweepNext = 0;
      return;
    }
    _sweep = [
      for (final company in candidates)
        if (!_verdicts.containsKey(company.cik) && !_isGuarded(company.cik))
          company,
    ];
    _sweepNext = 0;
    if (_sweep.isNotEmpty) unawaited(_work());
  }

  /// Drops whatever is waiting that is no longer in the list, so a filter
  /// change does not spend the budget on companies it just took away.
  void retainWithin(List<Company> results) {
    if (_queue.isEmpty) return;
    final shown = {for (final company in results) company.cik};
    _queue.removeWhere((company) => !shown.contains(company.cik));
  }

  bool _isGuarded(String cik) {
    final last = _lastAsked[cik];
    return last != null && DateTime.now().difference(last) < listPriceGuard;
  }

  Future<void> _work() async {
    if (_isWorking) return;
    _isWorking = true;
    try {
      while ((_queue.isNotEmpty || sweepRemaining > 0) && !_isDisposed) {
        final fromSweep = _queue.isEmpty;
        final company = fromSweep ? _sweep[_sweepNext++] : _queue.removeLast();
        if (_isGuarded(company.cik)) continue;
        // Judged since the sweep was set, by its tile or by the report.
        if (fromSweep && _verdicts.containsKey(company.cik)) continue;
        _lastAsked[company.cik] = DateTime.now();

        _inFlight = company.cik;
        final outcome = await _price(
          company,
          startedAt: _lastAsked[company.cik]!,
        );
        _inFlight = null;
        if (_isDisposed) return;
        // Pending no longer, whether or not a verdict came of it — a symbol
        // with no price still has to stop animating.
        if (outcome != _Outcome.blocked) _notify();
        switch (outcome) {
          case _Outcome.blocked:
            // Asked again once the budget frees up, at the front of the line.
            _lastAsked.remove(company.cik);
            if (fromSweep) {
              // Unless the sweep was replaced while this was out, in which
              // case its place is gone; the tile asks for it if it shows.
              if (_sweepNext > 0 && _sweep[_sweepNext - 1].cik == company.cik) {
                _sweepNext--;
              }
            } else {
              _queue.add(company);
            }
            await _sleep(_blockedRetry);
          case _Outcome.quoted:
            await _sleep(listQuoteSpacing);
          case _Outcome.fromStore:
            break;
        }
      }
    } finally {
      _isWorking = false;
    }
  }

  Future<_Outcome> _price(
    Company company, {
    required DateTime startedAt,
  }) async {
    try {
      final stored = await _priceRepo.priceFor(company.cik);
      var quote = stored;
      var outcome = _Outcome.fromStore;

      if (!_isFresh(stored)) {
        final wait = _quoteRepo.timeUntilSlot;
        if (wait > Duration.zero) return _Outcome.blocked;
        try {
          final fetched = await _quoteRepo.quoteFor(company.ticker);
          await _priceRepo.save(company.cik, fetched);
          quote = fetched;
          outcome = _Outcome.quoted;
        } on QuoteException catch (error) {
          if (error.failure == QuoteFailure.jobRunning ||
              error.failure == QuoteFailure.rateLimited) {
            return _Outcome.blocked;
          }
          // No price to be had — an uncovered symbol, a dropped connection.
          // The call was still spent, and the stored price, if any, still
          // stands.
          outcome = _Outcome.quoted;
        }
      }

      if (quote != null) {
        final askedForRate = await _judge(company, quote, startedAt: startedAt);
        // The company's rate cost a request of its own: pause for it as for
        // a quote, so the two together stay inside the same allowance.
        if (askedForRate) outcome = _Outcome.quoted;
      }
      return outcome;
    } on SecException {
      return _Outcome.fromStore;
    } on Object catch (error, trace) {
      // One company's oddity costs that company its mark and nothing more.
      logWarning(() => 'Could not value ${company.ticker}: $error\n$trace');
      return _Outcome.fromStore;
    }
  }

  /// Whether [stored] can stand without asking again: a typed price always
  /// can, since asking would overwrite the reader's own figure; a quote can
  /// while it is younger than the guard.
  static bool _isFresh(Quote? stored) {
    if (stored == null) return false;
    if (!stored.isQuoted) return true;
    final fetchedAt = stored.fetchedAt;
    return fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < listPriceGuard;
  }

  /// Judges [company] at [quote], on the same rate the report would use, and
  /// says whether that rate had to be asked for.
  ///
  /// The company's own rate rather than the assumed one: judged on the
  /// assumed rate, a tile disagreed with the report the moment it was
  /// opened, and changed its mark when the report fetched the real one. The
  /// rate is kept between launches, so it is asked for about once a week per
  /// company, not on every pricing.
  Future<bool> _judge(
    Company company,
    Quote quote, {
    required DateTime startedAt,
  }) async {
    final snapshot = await _secRepo.fetchSnapshot(company.ticker);
    if (_isDisposed) return false;
    // Nothing is asked for where no rate can be built, nor where it is held.
    final wasHeld =
        !_marketRatesRepo.isConfigured ||
        _marketRatesRepo.cachedRateFor(company.ticker) != null;
    final rate = await _marketRatesRepo.rateFor(company.ticker);
    if (_isDisposed) return !wasHeld;
    final reportedAt = _reportedAt[company.cik];
    if (reportedAt != null && !reportedAt.isBefore(startedAt)) {
      return !wasHeld;
    }
    final verdict = Valuation(
      snapshot: snapshot,
      pricePerShare: quote.pricePerShare,
      discountRatePercent: rate?.percent,
    ).verdict;
    if (_verdicts[company.cik] == verdict) return !wasHeld;
    _verdicts[company.cik] = verdict;
    _revision++;
    notifyListeners();
    return !wasHeld;
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  Future<void> _sleep(Duration duration) {
    final done = Completer<void>();
    _pauseDone = done;
    _pause = Timer(duration, () {
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _queue.clear();
    _sweep = const [];
    _pause?.cancel();
    final done = _pauseDone;
    if (done != null && !done.isCompleted) done.complete();
    super.dispose();
  }
}

/// What pricing one company cost.
enum _Outcome {
  /// Answered from the stored price, without a call.
  fromStore,

  /// A quote was asked for, answered or not, so the next one waits.
  quoted,

  /// The budget was not there to ask with; try again later.
  blocked,
}
