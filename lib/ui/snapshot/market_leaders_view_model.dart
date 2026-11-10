import 'dart:async';

export 'package:pickstock/repo/sec/ticker_directory_repo.dart'
    show primarySymbol;
import 'package:pickstock/repo/sec/ticker_directory_repo.dart'
    show primarySymbol;

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/sic_sector.dart';
import 'package:pickstock/extensions/object_extensions.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/price_repo.dart';
import 'package:pickstock/repo/quote/quote_repo.dart';
import 'package:pickstock/ui/browse/list_valuation_view_model.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';

AppDatabase get _database => GetIt.I.get<AppDatabase>();
PriceRepo get _priceRepo => GetIt.I.get<PriceRepo>();
QuoteRepo get _quoteRepo => GetIt.I.get<QuoteRepo>();

/// How many companies each ranking lists.
const int marketLeaderCount = 10;

/// How many of a sector's companies are priced. They are drawn in turn from
/// the sector's largest by each measure of size the filings give before a
/// price is known: earnings and cash flow track market value most closely,
/// and revenue catches the thin-margin giants they miss, such as retailers
/// and distributors. The three overlap heavily, so they are interleaved until
/// this many distinct companies are found, comfortably more than the ten the
/// ranking shows.
const int _perSector = 15;

/// The same, across every filer, so a giant without an industry code still
/// makes the overall ranking. These are also the companies priced first and
/// kept freshest, being the ones the overall ranking is drawn from.
const int _overall = 25;

/// How long a price may stand for the sector rankings before it is asked for
/// again. Longer than [quoteFreshness]: ranking ten companies by size does
/// not turn on the day's moves, and the sectors together hold nearly two
/// hundred companies, which is minutes of the quote budget to price.
const Duration sectorPriceGuard = Duration(hours: 24);

/// Commodity trusts (GLD, SLV, IAU) file under this code: their "market
/// value" is the metal they hold, not a business.
const Set<int> _excludedSics = {6221};

/// How many years old a company's latest filing may be and still count.
const int _maxFilingAgeYears = 3;

/// One company in a ranking, valued at the last price known for it.
class MarketLeader {
  const MarketLeader({
    required this.company,
    required this.quote,
    required this.shares,
    required this.sector,
  });

  final Company company;
  final Quote quote;
  final double shares;

  /// The sector its industry code falls in, or `null` for none.
  final SicSector? sector;

  /// Price times shares: what the market says the equity is worth.
  double get marketCap => quote.pricePerShare * shares;
}

/// A company worth pricing, and how soon its price goes stale.
class _Candidate {
  const _Candidate({
    required this.company,
    required this.shares,
    required this.sector,
    required this.isOverall,
    required this.netIncome,
  });

  final Company company;
  final double shares;
  final SicSector? sector;

  /// Drawn for the overall ranking, which is kept to [quoteFreshness].
  final bool isOverall;

  final double netIncome;
}

/// The largest companies by market value, overall and within each sector,
/// for the empty report pane.
///
/// Which companies to price is read from the filings: the largest of each
/// sector by earnings, cash flow and revenue. Stored prices go up first, so
/// the rankings are on screen at once, offline and without a key; stale ones
/// are then re-quoted one at a time, paced like the list's own pricing, and
/// the rankings re-sort as each arrives.
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

  /// The largest companies of all, largest first.
  List<MarketLeader> get leaders => _ranked(_byCik.values);

  /// The largest companies in [sector], largest first.
  List<MarketLeader> leadersIn(SicSector sector) =>
      _ranked(_byCik.values.where((leader) => leader.sector == sector));

  /// The sectors with at least one priced company, in the filter's order.
  List<SicSector> get sectors => [
    for (final sector in SicSector.values)
      if (_byCik.values.any((leader) => leader.sector == sector)) sector,
  ];

  static List<MarketLeader> _ranked(Iterable<MarketLeader> leaders) {
    final ranked = leaders.toList()
      ..sort((a, b) => b.marketCap.compareTo(a.marketCap));
    return ranked.take(marketLeaderCount).toList();
  }

  /// Loads the rankings unless they were loaded within [quoteFreshness].
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
      final stale = await _readStored(await _candidates());
      _hasLoaded = true;
      _notify();
      if (isRefreshEnabled && _quoteRepo.isConfigured) await _refresh(stale);
    } catch (error) {
      logWarning(() => 'Market leaders could not be read: $error');
    } finally {
      _hasLoaded = true;
      _isLoading = false;
      _notify();
    }
  }

  /// The companies worth pricing: the largest of each sector, and of all of
  /// them, by each measure of size the filings give.
  Future<List<_Candidate>> _candidates() async {
    final year = DateTime.now().year;
    final samples = [
      for (final sample in await _database.sizeSamples(
        fromYear: year - _maxFilingAgeYears,
        toYear: year + 1,
      ))
        if (!_excludedSics.contains(sample.sic)) sample,
    ];

    List<SizeSample> largest(
      Iterable<SizeSample> pool,
      double? Function(SizeSample) measure,
    ) =>
        pool.where((sample) => (measure(sample) ?? 0) > 0).toList()
          ..sort((a, b) => measure(b)!.compareTo(measure(a)!));

    // The largest by each measure in turn, until [count] distinct companies
    // are found or every ranking has run out.
    Set<SizeSample> pick(Iterable<SizeSample> pool, int count) {
      final rankings = [
        largest(pool, (s) => s.netIncome),
        largest(pool, (s) => s.operatingCashFlow),
        largest(pool, (s) => s.revenue),
      ];
      final picked = <SizeSample>{};
      for (var depth = 0; picked.length < count; depth++) {
        final reached = rankings.where((ranking) => depth < ranking.length);
        if (reached.isEmpty) break;
        for (final ranking in reached) {
          if (picked.length < count) picked.add(ranking[depth]);
        }
      }
      return picked;
    }

    final overall = pick(samples, _overall);
    final chosen = {...overall};
    for (final sector in SicSector.values) {
      chosen.addAll(
        pick(
          samples.where((sample) => SicSector.of(sample.sic) == sector),
          _perSector,
        ),
      );
    }

    return [
      for (final sample in chosen)
        if (primarySymbol(sample.symbols) case final ticker?)
          _Candidate(
            company: Company(
              ticker: ticker,
              cik: sample.cik,
              name: sample.name,
              sic: sample.sic,
              sharesOutstanding: sample.shares,
            ),
            shares: sample.shares,
            sector: SicSector.of(sample.sic),
            isOverall: overall.contains(sample),
            netIncome: sample.netIncome ?? 0,
          ),
    ];
  }

  /// Puts every candidate with a stored price into the rankings, and returns
  /// the ones whose price should be asked for again: the overall ranking's
  /// first, then the rest, each largest first so the heads of the rankings
  /// settle soonest.
  Future<List<_Candidate>> _readStored(List<_Candidate> candidates) async {
    final stored = await Future.wait(
      candidates.map((candidate) => _priceRepo.priceFor(candidate.company.cik)),
    );
    final stale = <(_Candidate, double)>[];
    for (final (index, candidate) in candidates.indexed) {
      final quote = stored[index];
      if (quote != null) _put(candidate, quote);
      final guard = candidate.isOverall ? quoteFreshness : sectorPriceGuard;
      if (_isStale(quote, guard)) {
        // Unpriced companies rank behind every priced one, by earnings.
        final size = quote == null
            ? candidate.netIncome / double.maxFinite
            : quote.pricePerShare * candidate.shares;
        stale.add((candidate, size));
      }
    }
    stale.sort((a, b) {
      if (a.$1.isOverall != b.$1.isOverall) return a.$1.isOverall ? -1 : 1;
      return b.$2.compareTo(a.$2);
    });
    return [for (final (candidate, _) in stale) candidate];
  }

  Future<void> _refresh(List<_Candidate> stale) async {
    for (final (index, candidate) in stale.indexed) {
      if (_isDisposed) return;
      if (index > 0) await Future<void>.delayed(listQuoteSpacing);
      final wait = _quoteRepo.timeUntilSlot;
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      if (_isDisposed) return;
      final company = candidate.company;
      try {
        final quote = await _quoteRepo.quoteFor(company.ticker);
        await _priceRepo.save(company.cik, quote);
        _put(candidate, quote);
        _notify();
      } on QuoteException catch (error) {
        logWarning(() => 'Market leader quote ${company.ticker}: $error');
        // A spent budget, a bulk run or no network will refuse the rest too;
        // the stored prices stay up and the next visit tries again.
        if (error.failure == QuoteFailure.rateLimited ||
            error.failure == QuoteFailure.jobRunning ||
            error.failure == QuoteFailure.network) {
          return;
        }
      }
    }
  }

  void _put(_Candidate candidate, Quote quote) {
    _byCik[candidate.company.cik] = MarketLeader(
      company: candidate.company,
      quote: quote,
      shares: candidate.shares,
      sector: candidate.sector,
    );
  }

  /// Due a new quote when there is none, it was typed, or it was asked for
  /// longer ago than [guard].
  static bool _isStale(Quote? stored, Duration guard) {
    if (stored == null || !stored.isQuoted) return true;
    final asked = stored.fetchedAt ?? stored.asOf;
    return DateTime.now().difference(asked) > guard;
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
