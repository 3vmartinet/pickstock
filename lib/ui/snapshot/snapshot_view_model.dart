import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/history_period.dart';
import 'package:pickstock/data/snapshot/period_figures.dart';
import 'package:pickstock/data/snapshot/report_tab.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/data/valuation/growth_expectation.dart';
import 'package:pickstock/data/valuation/valuation.dart';
import 'package:pickstock/extensions/object_extensions.dart';
import 'package:pickstock/repo/price_repo.dart';
import 'package:pickstock/repo/quote/quote_repo.dart';
import 'package:pickstock/repo/sec/sec_repo.dart';
import 'package:pickstock/ui/snapshot/snapshot_state.dart';

SecRepo get _secRepo => GetIt.I.get<SecRepo>();
PriceRepo get _priceRepo => GetIt.I.get<PriceRepo>();
QuoteRepo get _quoteRepo => GetIt.I.get<QuoteRepo>();

/// How old a stored quote may be before opening a company refetches it.
///
/// Long enough that clicking between companies does not spend the per-minute
/// budget, short enough that a price on screen is one a person would still act
/// on.
const Duration quoteFreshness = Duration(minutes: 15);

/// Tickers offered as a starting point on the empty screen.
const List<String> suggestedTickers = ['AAPL', 'MSFT', 'NVDA', 'KO', 'F'];

const int _maxRecentTickers = 6;

class SnapshotViewModel extends ChangeNotifier {
  SnapshotState _state = const SnapshotIdle();
  SnapshotState get state => _state;

  final List<String> _recentTickers = [];

  /// Most recently searched first.
  List<String> get recentTickers => List.unmodifiable(_recentTickers);

  bool get isLoading => _state is SnapshotLoading;

  /// The symbol the report is about, whether its figures have arrived yet or
  /// not, and `null` before anything has been looked up.
  ///
  /// Read by the directory beside the report to mark which of its tiles the
  /// report belongs to. It answers while the lookup is still in flight on
  /// purpose: a tile that only lit up once the figures landed would leave a
  /// click looking unregistered for as long as the fetch takes, and would go
  /// dark again if the company turned out not to be reportable.
  String? get selectedTicker => switch (_state) {
    SnapshotIdle() => null,
    SnapshotLoading(:final ticker) => ticker,
    SnapshotLoaded(:final snapshot) => snapshot.company.ticker,
    SnapshotFailed(:final ticker) => ticker,
  };

  /// The figures on screen, or `null` while idle, loading or failed.
  FinancialSnapshot? get snapshot {
    final current = _state;
    return current is SnapshotLoaded ? current.snapshot : null;
  }

  /// The most recent fiscal year on screen.
  FiscalYearFigures? get latestFigures => snapshot?.latest;

  /// How many fiscal years the report covers.
  int get reportedYearCount => snapshot?.years.length ?? 0;

  /// The figures at [index], oldest year first.
  FiscalYearFigures? figuresAt(int index) {
    final years = snapshot?.years;
    if (years == null || index < 0 || index >= years.length) return null;
    return years[index];
  }

  /// The year immediately before [index], for year-over-year comparisons.
  FiscalYearFigures? previousFiguresAt(int index) => figuresAt(index - 1);

  ReportTab _reportTab = ReportTab.overview;

  /// Which part of the report is on screen. Overview first: it answers "is
  /// this worth a look" before the price does.
  ReportTab get reportTab => _reportTab;

  void selectReportTab(ReportTab tab) {
    if (tab == _reportTab) return;
    _reportTab = tab;
    notifyListeners();
  }

  HistoryPeriod _historyPeriod = HistoryPeriod.annual;

  /// Annual by default: the sanity checks and highlights are annual, so the
  /// history opens on the same cadence.
  HistoryPeriod get historyPeriod => _historyPeriod;

  /// Whether the filer reports anything quarterly. Where it does not, the
  /// quarterly tab would open onto an empty table.
  bool get hasQuarterlyHistory => snapshot?.quarters.isNotEmpty ?? false;

  void selectHistoryPeriod(HistoryPeriod period) {
    if (period == _historyPeriod) return;
    _historyPeriod = period;
    notifyListeners();
  }

  bool _isHistoryNewestFirst = true;

  /// Which way the history section is ordered. Newest first by default: the
  /// most recent year is the one being judged, so it leads.
  bool get isHistoryNewestFirst => _isHistoryNewestFirst;

  void toggleHistoryOrder() {
    _isHistoryNewestFirst = !_isHistoryNewestFirst;
    notifyListeners();
  }

  /// The rows the history section should show, in the chosen cadence and order.
  ///
  /// Only the history respects these choices; the highlight cards always
  /// compare the latest year with the one before it.
  List<PeriodFigures> get historyRows {
    final rows = switch (_historyPeriod) {
      HistoryPeriod.annual => snapshot?.years ?? const <PeriodFigures>[],
      HistoryPeriod.quarterly => snapshot?.quarters ?? const <PeriodFigures>[],
    };
    return _isHistoryNewestFirst ? rows.reversed.toList() : rows.toList();
  }

  /// The figures at [index] of [historyRows].
  PeriodFigures? historyFiguresAt(int index) {
    final rows = historyRows;
    return index >= 0 && index < rows.length ? rows[index] : null;
  }

  /// How many rows the history section shows.
  int get historyRowCount => historyRows.length;

  Quote? _quote;

  /// The price on screen and where it came from, or `null` while none is known.
  Quote? get quote => _quote;

  /// The price the valuation is struck at, or `null` while the field is empty
  /// or holds something that is not a price.
  double? get pricePerShare => _quote?.pricePerShare;

  /// Which request a quote is in flight for, or `null` when none is.
  ///
  /// A plain flag leaked: cleared only when the generation still matched, it
  /// stayed set for ever once a company was switched mid-request, and every
  /// later quote was then refused by its own guard.
  int? _quotingGeneration;

  /// Whether a quote for the company on screen is in flight, so the field can
  /// show it is working.
  bool get isQuoting => _quotingGeneration == _requestGeneration;

  QuoteFailure? _quoteFailure;

  /// Why the last quote attempt came back empty-handed, or `null` if it did
  /// not. Kept so the report can say what happened rather than leaving the
  /// field mysteriously blank.
  QuoteFailure? get quoteFailure => _quoteFailure;

  /// Whether quotes are available at all: without a key the price is typed in,
  /// and no refresh control is offered.
  bool get canFetchQuotes => _quoteRepo.isConfigured;

  /// The valuation of the loaded company at [pricePerShare], or `null` while
  /// there is no snapshot or no price to value it at.
  Valuation? get valuation {
    final current = snapshot;
    final price = pricePerShare;
    if (current == null || price == null || price <= 0) return null;
    return Valuation(snapshot: current, pricePerShare: price);
  }

  /// What the entered price is asking of the company, set against what the
  /// company has actually produced.
  GrowthExpectation? get growthExpectation {
    final current = snapshot;
    final capitalisation = valuation?.marketCap;
    if (current == null || capitalisation == null) return null;
    return GrowthExpectation.of(current, capitalisation);
  }

  /// Whether a per-share value can be derived at all: without a share count
  /// there is nothing to divide the business by.
  bool get canBeValued {
    final current = snapshot;
    if (current == null) return false;
    return (current.company.sharesOutstanding ??
            current.latest.dilutedShares) !=
        null;
  }

  /// Takes the price as typed, keeping it whether or not it parses so the field
  /// never fights the user mid-entry.
  ///
  /// A typed price overrides a quote: the user may well know something the
  /// provider does not, or simply want to ask "what if it were this".
  Future<void> enterPrice(String text) async {
    final price = _parsePrice(text);
    if (price == pricePerShare) return;
    _quote = price == null ? null : Quote.entered(price);
    _quoteFailure = null;
    notifyListeners();

    final cik = snapshot?.company.cik;
    if (cik == null) return;
    final entered = _quote;
    if (entered == null) {
      await _priceRepo.clear(cik);
    } else {
      await _priceRepo.save(cik, entered);
    }
  }

  /// Accepts what a person actually types: a currency symbol, thin spaces, and
  /// a comma where a decimal point belongs.
  static double? _parsePrice(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'[^0-9.,]'), '')
        .replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    final price = double.tryParse(cleaned);
    return price == null || price <= 0 ? null : price;
  }

  /// Puts the last known price back on screen, then fetches a fresh quote if
  /// the stored one is stale and quotes are available.
  ///
  /// The stored price goes up first on purpose: the report is readable
  /// immediately, offline, and stays readable if the quote never arrives.
  Future<void> _restorePrice(String cik, int generation) async {
    final stored = await _priceRepo.priceFor(cik);
    // A newer search may have landed while the read was in flight; its own
    // price is the one that belongs on screen.
    if (generation != _requestGeneration) return;
    _showPrice(stored);
    _quoteFailure = null;
    notifyListeners();

    if (!_isStale(stored)) return;
    // Not awaited: the report is complete without a quote, and making the
    // search wait on the network would hand a slow provider the power to stall
    // the whole screen.
    unawaited(_fetchQuote(generation));
  }

  /// Asks the provider for a price, from the refresh control.
  Future<void> refreshQuote() => _fetchQuote(_requestGeneration);

  Future<void> _fetchQuote(int generation) async {
    final current = snapshot;
    if (current == null || !canFetchQuotes) return;
    // Only one request per company on screen. A different company supersedes
    // rather than being turned away, which is what a single flag did.
    if (_quotingGeneration == generation) return;

    _quotingGeneration = generation;
    _quoteFailure = null;
    notifyListeners();

    try {
      final quoted = await _quoteRepo.quoteFor(current.company.ticker);
      if (generation != _requestGeneration) return;
      _showPrice(quoted);
      await _priceRepo.save(current.company.cik, quoted);
    } on QuoteException catch (error) {
      if (generation != _requestGeneration) return;
      logWarning(() => 'Quote for ${current.company.ticker} failed: $error');
      // The stored price stays on screen: a failed refresh is not a reason to
      // throw away the last price known.
      _quoteFailure = error.failure;
    } finally {
      // Only if a newer request has not already claimed the slot.
      if (_quotingGeneration == generation) {
        _quotingGeneration = null;
        notifyListeners();
      }
    }
  }

  /// A stored price is refetched when it is absent, older than
  /// [quoteFreshness], or was typed rather than quoted — a real quote beats a
  /// guess, and the user can always type over it again.
  bool _isStale(Quote? stored) {
    if (!canFetchQuotes) return false;
    if (stored == null || !stored.isQuoted) return true;
    return DateTime.now().difference(stored.asOf) > quoteFreshness;
  }

  void _showPrice(Quote? price) => _quote = price;

  /// Guards against a slow first request overwriting a newer one's result.
  int _requestGeneration = 0;

  /// Looks up [ticker].
  Future<void> search(String ticker) async {
    final symbol = ticker.trim().toUpperCase();
    if (symbol.isEmpty) return;

    final generation = ++_requestGeneration;
    _setState(SnapshotLoading(symbol));

    try {
      final snapshot = await _secRepo.fetchSnapshot(symbol);
      if (generation != _requestGeneration) return;
      _rememberTicker(symbol);
      // A different company starts on the overview: the tab left open for the
      // last one says nothing about this one.
      _reportTab = ReportTab.overview;
      _setState(SnapshotLoaded(snapshot));
      await _restorePrice(snapshot.company.cik, generation);
    } on SecException catch (error) {
      if (generation != _requestGeneration) return;
      logWarning(() => 'Snapshot for $symbol failed: $error');
      _setState(SnapshotFailed(ticker: symbol, failure: error.failure));
    }
  }

  /// Re-runs the search that failed, from the error state's retry button.
  Future<void> retry() async {
    final current = _state;
    if (current is SnapshotFailed) return search(current.ticker);
  }

  void _rememberTicker(String ticker) {
    _recentTickers
      ..remove(ticker)
      ..insert(0, ticker);
    if (_recentTickers.length > _maxRecentTickers) {
      _recentTickers.removeLast();
    }
  }

  void _setState(SnapshotState state) {
    _state = state;
    notifyListeners();
  }
}
