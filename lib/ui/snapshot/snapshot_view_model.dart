import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/history_period.dart';
import 'package:pickstock/data/snapshot/period_figures.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/extensions/object_extensions.dart';
import 'package:pickstock/repo/sec/sec_repo.dart';
import 'package:pickstock/repo/sec/ticker_directory_repo.dart';
import 'package:pickstock/ui/snapshot/snapshot_state.dart';

SecRepo get _secRepo => GetIt.I.get<SecRepo>();
TickerDirectoryRepo get _tickerDirectoryRepo =>
    GetIt.I.get<TickerDirectoryRepo>();

/// Tickers offered as a starting point on the empty screen.
const List<String> suggestedTickers = ['AAPL', 'MSFT', 'NVDA', 'KO', 'F'];

const int _maxRecentTickers = 6;

/// How many type-ahead rows fit under the field without covering the report.
const int _maxSuggestions = 8;

/// Separates the symbol from the company name in a suggestion row. Chosen
/// because no EDGAR company name contains it.
const String suggestionSeparator = '  ·  ';

class SnapshotViewModel extends ChangeNotifier {
  final TextEditingController tickerController = TextEditingController();

  SnapshotState _state = const SnapshotIdle();
  SnapshotState get state => _state;

  final List<String> _recentTickers = [];

  /// Most recently searched first.
  List<String> get recentTickers => List.unmodifiable(_recentTickers);

  bool get isLoading => _state is SnapshotLoading;

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

  /// Guards against a slow first request overwriting a newer one's result.
  int _requestGeneration = 0;

  List<Company> _suggestions = const [];

  /// Rows for the type-ahead under the field, best match first. Rebuilt only
  /// when the query changes, so the list keeps its identity between keystrokes
  /// and `context.select` does not rebuild the field for unrelated updates.
  List<String> _suggestionLabels = const [];
  List<String> get suggestionLabels => _suggestionLabels;

  /// Recomputes the type-ahead for what is currently typed.
  void onQueryChanged(String query) {
    final typed = query.trim();
    _suggestions = typed.isEmpty
        ? const []
        : _tickerDirectoryRepo.search(typed, limit: _maxSuggestions);
    _suggestionLabels = [
      for (final company in _suggestions)
        '${company.ticker}$suggestionSeparator${company.name}',
    ];
    notifyListeners();
  }

  /// Accepts a suggestion row, returning the symbol that should replace the
  /// text in the field.
  ///
  /// The lookup is scheduled rather than awaited because this is called while
  /// the autocomplete is applying its own text edit.
  String acceptSuggestion(String label) {
    final ticker = label.split(suggestionSeparator).first;
    _clearSuggestions();
    scheduleMicrotask(() => search(ticker));
    return ticker;
  }

  /// Looks up whatever is currently typed, which may be a symbol or the start
  /// of a company name.
  ///
  /// A name is resolved to the best-matching symbol rather than sent to EDGAR
  /// as-is, so pressing enter on `berkshire` opens BRK-A instead of failing.
  Future<void> submitTypedTicker() {
    final typed = tickerController.text.trim();
    if (typed.isEmpty) return Future<void>.value();

    final exactSymbol = _tickerDirectoryRepo.lookup(typed);
    if (exactSymbol != null) return search(exactSymbol.ticker);

    final best = _tickerDirectoryRepo.search(typed, limit: 1);
    return search(best.isEmpty ? typed : best.first.ticker);
  }

  /// Looks up [ticker], syncing the text field so the two never disagree.
  Future<void> search(String ticker) async {
    final symbol = ticker.trim().toUpperCase();
    if (symbol.isEmpty) return;

    if (tickerController.text != symbol) {
      tickerController.text = symbol;
    }

    final generation = ++_requestGeneration;
    _clearSuggestions();
    _setState(SnapshotLoading(symbol));

    try {
      final snapshot = await _secRepo.fetchSnapshot(symbol);
      if (generation != _requestGeneration) return;
      _rememberTicker(symbol);
      _setState(SnapshotLoaded(snapshot));
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

  void _clearSuggestions() {
    _suggestions = const [];
    _suggestionLabels = const [];
  }

  void _setState(SnapshotState state) {
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    tickerController.dispose();
    super.dispose();
  }
}
