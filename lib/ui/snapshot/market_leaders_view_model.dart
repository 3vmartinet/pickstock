import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/extensions/object_extensions.dart';
import 'package:pickstock/repo/price_repo.dart';
import 'package:pickstock/repo/quote/quote_repo.dart';
import 'package:pickstock/repo/sec/sec_repo.dart';
import 'package:pickstock/ui/browse/list_valuation_view_model.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';

SecRepo get _secRepo => GetIt.I.get<SecRepo>();
PriceRepo get _priceRepo => GetIt.I.get<PriceRepo>();
QuoteRepo get _quoteRepo => GetIt.I.get<QuoteRepo>();

/// The companies that could plausibly be among the largest US-listed filers.
///
/// A fixed pool rather than the whole directory: ranking every filer would
/// mean pricing ten thousand of them, and the stored prices alone cover only
/// what has been opened, so a ranking read from them would miss whichever
/// giant nobody looked at yet. Wide enough that the top ten can reshuffle
/// within it. Filers without a usable share count simply drop out.
const List<String> marketLeaderCandidates = [
  'NVDA',
  'MSFT',
  'AAPL',
  'GOOGL',
  'AMZN',
  'META',
  'AVGO',
  'TSLA',
  'BRK-B',
  'LLY',
  'JPM',
  'WMT',
  'ORCL',
  'V',
  'MA',
  'NFLX',
  'XOM',
  'COST',
  'PLTR',
  'AMD',
  'JNJ',
  'UNH',
];

/// How many of the largest companies the empty report pane lists.
const int marketLeaderCount = 10;

/// One company in the ranking, valued at the last price known for it.
class MarketLeader {
  const MarketLeader({
    required this.company,
    required this.quote,
    required this.shares,
  });

  final Company company;
  final Quote quote;
  final double shares;

  /// Price times shares: what the market says the equity is worth.
  double get marketCap => quote.pricePerShare * shares;
}

/// The largest companies by market value, for the empty report pane.
///
/// Stored prices go up first so the ranking is on screen at once, offline
/// and without a key; stale ones are then re-quoted one at a time, paced like
/// the list's own pricing, and the ranking re-sorts as each arrives.
class MarketLeadersViewModel extends ChangeNotifier {
  /// Whether stale prices are re-quoted. Off in tests, for the same reason as
  /// [ListValuationViewModel.isEnabled].
  static bool isRefreshEnabled = true;

  final Map<String, MarketLeader> _byCik = {};
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _isDisposed = false;
  DateTime? _loadedAt;

  /// Whether the first read of stored prices is still under way.
  bool get isLoading => _isLoading && !_hasLoaded;

  /// The largest first, at most [marketLeaderCount] of them.
  List<MarketLeader> get leaders {
    final ranked = _byCik.values.toList()
      ..sort((a, b) => b.marketCap.compareTo(a.marketCap));
    return ranked.take(marketLeaderCount).toList();
  }

  /// Loads the ranking unless it was loaded within [quoteFreshness].
  ///
  /// Called each time the empty pane is shown, so coming back to it after a
  /// while brings the prices up to date without re-asking on every visit.
  Future<void> ensureFresh() async {
    if (_isLoading) return;
    final loadedAt = _loadedAt;
    if (loadedAt != null &&
        DateTime.now().difference(loadedAt) < quoteFreshness) {
      return;
    }
    _isLoading = true;
    _loadedAt = DateTime.now();
    _notify();
    try {
      final stale = await _readStored();
      _hasLoaded = true;
      _notify();
      if (isRefreshEnabled && _quoteRepo.isConfigured) await _refresh(stale);
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  /// Reads every candidate's filed share count and stored price, and returns
  /// the companies whose price should be asked for again, largest first.
  ///
  /// All at once: each is a local read, and one at a time the pane would sit
  /// on its placeholder for as long as the slowest twenty of them added up.
  Future<List<(Company, double)>> _readStored() async {
    final read = await Future.wait(marketLeaderCandidates.map(_readOne));
    final stale = <(Company, double, double)>[];
    for (final entry in read.nonNulls) {
      final (company, shares, stored) = entry;
      if (stored != null) {
        _byCik[company.cik] = MarketLeader(
          company: company,
          quote: stored,
          shares: shares,
        );
      }
      if (_isStale(stored)) {
        stale.add((company, shares, stored?.pricePerShare ?? 0));
      }
    }
    // Largest first, so the head of the ranking settles soonest; companies
    // never priced go last, in the order the pool lists them.
    stale.sort((a, b) => (b.$3 * b.$2).compareTo(a.$3 * a.$2));
    return [for (final (company, shares, _) in stale) (company, shares)];
  }

  /// One candidate's filer, share count and stored price, or `null` when it
  /// cannot be valued at all.
  Future<(Company, double, Quote?)?> _readOne(String ticker) async {
    try {
      final snapshot = await _secRepo.fetchSnapshot(ticker);
      final company = snapshot.company;
      final shares =
          company.sharesOutstanding ?? snapshot.years.lastOrNull?.dilutedShares;
      if (shares == null || shares <= 0) return null;
      return (company, shares, await _priceRepo.priceFor(company.cik));
    } catch (error) {
      // Not in this archive, or filed under another symbol. One missing giant
      // is no reason to show none of them.
      logWarning(() => 'Market leader $ticker unavailable: $error');
      return null;
    }
  }

  Future<void> _refresh(List<(Company, double)> stale) async {
    for (final (index, (company, shares)) in stale.indexed) {
      if (_isDisposed) return;
      if (index > 0) await Future<void>.delayed(listQuoteSpacing);
      final wait = _quoteRepo.timeUntilSlot;
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      if (_isDisposed) return;
      try {
        final quote = await _quoteRepo.quoteFor(company.ticker);
        await _priceRepo.save(company.cik, quote);
        _byCik[company.cik] = MarketLeader(
          company: company,
          quote: quote,
          shares: shares,
        );
        _notify();
      } on QuoteException catch (error) {
        logWarning(() => 'Market leader quote ${company.ticker}: $error');
        // A spent budget or a bulk run will refuse the rest too; the stored
        // prices stay up and the next visit tries again.
        if (error.failure == QuoteFailure.rateLimited ||
            error.failure == QuoteFailure.jobRunning ||
            error.failure == QuoteFailure.network) {
          return;
        }
      }
    }
  }

  /// Due a new quote when there is none, it was typed, or it was asked for
  /// longer ago than [quoteFreshness].
  bool _isStale(Quote? stored) {
    if (stored == null || !stored.isQuoted) return true;
    final asked = stored.fetchedAt ?? stored.asOf;
    return DateTime.now().difference(asked) > quoteFreshness;
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
