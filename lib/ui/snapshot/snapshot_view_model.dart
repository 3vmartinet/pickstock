import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/history_period.dart';
import 'package:pickstock/data/snapshot/period_figures.dart';
import 'package:pickstock/data/research/company_event.dart';
import 'package:pickstock/data/research/company_insight.dart';
import 'package:pickstock/data/snapshot/report_tab.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/data/valuation/growth_expectation.dart';
import 'package:pickstock/data/valuation/valuation.dart';
import 'package:pickstock/extensions/object_extensions.dart';
import 'package:pickstock/repo/price_repo.dart';
import 'package:pickstock/repo/research/ollama_repo.dart';
import 'package:pickstock/repo/research/research_note_repo.dart';
import 'package:pickstock/data/valuation/discount_rate.dart';
import 'package:pickstock/repo/market/market_rates_repo.dart';
import 'package:pickstock/repo/quote/quote_repo.dart';
import 'package:pickstock/repo/sec/sec_repo.dart';
import 'package:pickstock/ui/snapshot/snapshot_state.dart';

SecRepo get _secRepo => GetIt.I.get<SecRepo>();
PriceRepo get _priceRepo => GetIt.I.get<PriceRepo>();
QuoteRepo get _quoteRepo => GetIt.I.get<QuoteRepo>();
OllamaRepo get _researchRepo => GetIt.I.get<OllamaRepo>();
ResearchNoteRepo get _noteRepo => GetIt.I.get<ResearchNoteRepo>();
MarketRatesRepo get _marketRatesRepo => GetIt.I.get<MarketRatesRepo>();

/// How old a stored quote may be before opening a company refetches it.
///
/// Long enough that clicking between companies does not spend the per-minute
/// budget, short enough that a price on screen is one a person would still act
/// on.
const Duration quoteFreshness = Duration(minutes: 15);

/// Tickers offered as a starting point on the empty screen.
const List<String> suggestedTickers = ['AAPL', 'MSFT', 'NVDA', 'KO', 'F'];

const int _maxRecentTickers = 6;

/// Where a company's reading-around has got to.
enum EventsState {
  /// Never asked. The header offers the press and shows nothing else.
  idle,

  /// The model is searching and reading, which takes about a minute.
  loading,

  /// Found and shown.
  ready,

  /// Asked, and there was nothing recent worth reporting.
  empty,

  /// The key, the local server or the model was not there.
  failed,
}

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

  EventsState _eventsState = EventsState.idle;

  /// Where the header's reading-around has got to. Idle until asked: it costs
  /// a minute of a local model's time, so it happens on a press and not on
  /// every company opened.
  EventsState get eventsState => _eventsState;

  DateTime? _eventsGeneratedAt;

  /// When the news on screen was read, or `null` if it has not been.
  ///
  /// Shown rather than hidden: restored from disk an answer can be a month
  /// old, and a reader has no way to tell this morning's reading from last
  /// month's without being told.
  DateTime? get eventsGeneratedAt => _eventsGeneratedAt;

  List<CompanyEvent> _events = const [];

  /// What the model found, newest first, or empty until it has been asked.
  List<CompanyEvent> get events => _events;

  ResearchFailure? _eventsFailure;

  /// Why the last attempt came to nothing, so the button can say which of the
  /// several things that have to be running is not.
  ResearchFailure? get eventsFailure => _eventsFailure;

  /// Whether reading around is on offer at all: a key has to be built in.
  bool get canResearchEvents => _researchRepo.isConfigured;

  /// Whether the header has anything to give the middle of its row to.
  ///
  /// The name gets the whole row until there is news, and takes it back when
  /// the reader moves to another company: an empty column that still claimed
  /// its share truncated the company's own name to make room for nothing.
  bool get hasEventsToShow => switch (_eventsState) {
    EventsState.idle || EventsState.loading => false,
    EventsState.ready || EventsState.empty || EventsState.failed => true,
  };

  /// Asks the local model what has been happening to the company on screen.
  ///
  /// Nothing is cached beyond the company: the news moves, and a reader
  /// pressing again means "again".
  Future<void> loadEvents({bool afresh = false}) async {
    final company = snapshot?.company;
    if (company == null || _eventsState == EventsState.loading) return;
    // Refused unless the reader asked again: the answer is on screen, and a
    // second run would spend another minute to say the same thing.
    if (!afresh && _eventsState != EventsState.idle) return;

    final generation = _requestGeneration;
    _eventsFailure = null;
    _eventsGeneratedAt = null;
    if (afresh) await _noteRepo.clear(company.cik, eventsNoteKind);
    _setEventsState(EventsState.loading);

    try {
      final found = await _researchRepo.eventsFor(
        ticker: company.ticker,
        name: company.name,
      );
      if (found.isNotEmpty) {
        await _noteRepo.saveEvents(
          cik: company.cik,
          kind: eventsNoteKind,
          events: found,
        );
      }
      // The reader has moved on; the answer is about a company no longer on
      // screen.
      if (generation != _requestGeneration) return;
      _events = found;
      _eventsGeneratedAt = DateTime.now();
      _setEventsState(found.isEmpty ? EventsState.empty : EventsState.ready);
    } on ResearchException catch (error) {
      if (generation != _requestGeneration) return;
      logWarning(() => 'Could not read around ${company.ticker}: $error');
      _eventsFailure = error.failure;
      _setEventsState(EventsState.failed);
    } on Object catch (error) {
      if (generation != _requestGeneration) return;
      logSevere(() => 'Reading around ${company.ticker} failed: $error');
      _eventsFailure = ResearchFailure.failed;
      _setEventsState(EventsState.failed);
    }
  }

  /// Whether there are price cases to show beside the verdict.
  ///
  /// Asked by the layout rather than left to the card: the card collapses to
  /// nothing when it has none, and level with its neighbour that reserved half
  /// the row for a void.
  bool get hasPriceTargets {
    final expectation = growthExpectation;
    final shares = valuation?.sharesOutstanding;
    if (expectation == null || shares == null || shares <= 0) return false;
    return expectation.growthRatesOnFile.isNotEmpty;
  }

  final Map<CompanyInsight, InsightState> _insightStates = {};
  final Map<CompanyInsight, ResearchAnswer> _insightAnswers = {};
  final Map<CompanyInsight, ResearchFailure> _insightFailures = {};
  final Map<CompanyInsight, DateTime> _insightGeneratedAt = {};

  /// When [insight] was answered, or `null` if it has not been.
  DateTime? insightGeneratedAt(CompanyInsight insight) =>
      _insightGeneratedAt[insight];

  InsightState insightState(CompanyInsight insight) =>
      _insightStates[insight] ?? InsightState.idle;

  ResearchAnswer? insightAnswer(CompanyInsight insight) =>
      _insightAnswers[insight];

  ResearchFailure? insightFailure(CompanyInsight insight) =>
      _insightFailures[insight];

  /// Whether reading around is on offer at all: a key has to be built in.
  bool get canResearch => _researchRepo.isConfigured;

  /// Asks the local model the one question [insight] exists for.
  ///
  /// Each is asked on its own: three questions is three minutes of a local
  /// model, and a reader on the overview has no use for the valuation's audit.
  /// Pressing again is refused for the same reason the news is — the answer is
  /// already there, and the company is what changes it.
  Future<void> loadInsight(
    CompanyInsight insight, {
    bool afresh = false,
  }) async {
    final company = snapshot?.company;
    if (company == null) return;
    final state = insightState(insight);
    if (state == InsightState.loading) return;
    if (!afresh && state != InsightState.idle) return;

    final question = _questionFor(insight);
    if (question == null) return;

    final generation = _requestGeneration;
    _insightFailures.remove(insight);
    _insightGeneratedAt.remove(insight);
    if (afresh) await _noteRepo.clear(company.cik, insight.name);
    _setInsightState(insight, InsightState.loading);

    try {
      final answer = await _researchRepo.ask(question, context: _brief());
      if (answer.text.isNotEmpty) {
        await _noteRepo.saveAnswer(
          cik: company.cik,
          kind: insight.name,
          text: answer.text,
          sources: answer.sources,
        );
      }
      // The reader has moved on; the answer is about a company no longer on
      // screen.
      if (generation != _requestGeneration) return;
      _insightAnswers[insight] = answer;
      _insightGeneratedAt[insight] = DateTime.now();
      _setInsightState(insight, InsightState.ready);
    } on ResearchException catch (error) {
      if (generation != _requestGeneration) return;
      logWarning(() => 'Insight ${insight.name} failed: $error');
      _insightFailures[insight] = error.failure;
      _setInsightState(insight, InsightState.failed);
    } on Object catch (error) {
      if (generation != _requestGeneration) return;
      logSevere(() => 'Insight ${insight.name} failed: $error');
      _insightFailures[insight] = ResearchFailure.failed;
      _setInsightState(insight, InsightState.failed);
    }
  }

  void _setInsightState(CompanyInsight insight, InsightState state) {
    _insightStates[insight] = state;
    notifyListeners();
  }

  /// What the app already knows, handed over so the model comments on the
  /// company in front of the reader rather than on whatever shares its name.
  String _brief() {
    final company = snapshot?.company;
    final latest = latestFigures;
    return [
      'The reader is looking at ${company?.name} (${company?.ticker}) in '
          'PickStock, which reads US SEC filings and nothing else.',
      'Today is ${DateTime.now().toIso8601String()}.',
      if (latest != null)
        'Its newest filed year is FY${latest.fiscalYear}: revenue '
            '${_millions(latest.revenue)}, net income '
            '${_millions(latest.netIncome)}, operating income '
            '${_millions(latest.operatingIncome)}, free cash flow '
            '${_millions(latest.freeCashFlow)}.',
    ].join(' ');
  }

  /// The question behind each insight, built where the figures are.
  ///
  /// Written out rather than templated: what makes these worth asking is that
  /// each names the thing the filings cannot settle, and that is different
  /// wording every time.
  String? _questionFor(CompanyInsight insight) {
    final company = snapshot?.company;
    if (company == null) return null;
    final subject = '${company.name} (${company.ticker})';

    return switch (insight) {
      // EDGAR carries no description of a business anywhere, so this is the
      // one thing a reader cannot get from the report at all.
      CompanyInsight.business =>
        'Search the web and tell me, in three or four sentences: what does '
            '$subject actually sell, and to whom? Then say in one sentence '
            'what has been driving its revenue in that direction lately. Do '
            'not repeat the figures I gave you; explain the business behind '
            'them.',
      CompanyInsight.inputs => _inputsQuestion(subject),
      CompanyInsight.expectations => _expectationsQuestion(subject),
    };
  }

  /// The audit: the figures the band was struck from, handed back for checking
  /// against what the filing says they are.
  String _inputsQuestion(String subject) {
    final current = valuation;
    return 'PickStock valued $subject from its latest annual filing, using '
        'free cash flow ${_millions(current?.freeCashFlow)} and '
        '${_count(current?.sharesOutstanding)} shares, and reads it as '
        '${current?.verdict.name}. Search the web, read the latest 10-K or '
        '20-F, and tell me in three or four sentences whether any of those '
        'figures does not mean what it appears to — a non-controlling '
        'interest, a one-off gain or tax release, a share class or reverse '
        'split, discontinued operations, a change of fiscal year. If they all '
        'look sound, say so plainly and briefly.';
  }

  /// The comparison: what the price asks, against what anyone expects.
  String _expectationsQuestion(String subject) {
    final expectation = growthExpectation;
    return 'At its current price, $subject has to grow its cash flow by about '
        '${_percent(expectation?.requiredGrowthPercent)} a year for a decade '
        'to be worth what it costs. Over its own history it has managed about '
        '${_percent(expectation?.deliveredGrowthPercent)}. Search the web and '
        'tell me in three or four sentences: what has management guided to, or '
        'what does the market expect, and what would have to go right or wrong '
        'for the first figure rather than the second?';
  }

  /// A figure in millions, or a phrase: a prompt with `null` in it invites the
  /// model to fill the gap itself.
  static String _millions(double? value) => value == null
      ? 'not reported'
      : '\$${(value / 1000000).toStringAsFixed(1)}M';

  static String _count(double? value) => value == null
      ? 'an unknown number of'
      : '${(value / 1000000).toStringAsFixed(1)}M';

  static String _percent(double? value) =>
      value == null ? 'an unknown rate' : '${value.toStringAsFixed(1)}%';

  /// Reads back what is on file for this company, in one pass over the four
  /// questions.
  ///
  /// Off the critical path: the report renders from the filings, and an answer
  /// arriving a frame later costs nothing. Failures are swallowed — a note
  /// that cannot be read is a note that was never taken, and the offer to ask
  /// stands.
  Future<void> _restoreNotes(String cik, int generation) async {
    try {
      final news = await _noteRepo.noteFor(cik, eventsNoteKind);
      if (generation != _requestGeneration) return;
      if (news != null && news.events.isNotEmpty) {
        _events = news.events;
        _eventsGeneratedAt = news.generatedAt;
        _eventsState = EventsState.ready;
      }

      for (final insight in CompanyInsight.values) {
        final note = await _noteRepo.noteFor(cik, insight.name);
        if (generation != _requestGeneration) return;
        final text = note?.text;
        if (note == null || text == null || text.isEmpty) continue;
        _insightAnswers[insight] = ResearchAnswer(
          text: text,
          sources: note.sources,
        );
        _insightGeneratedAt[insight] = note.generatedAt;
        _insightStates[insight] = InsightState.ready;
      }
      notifyListeners();
    } on Object catch (error) {
      logWarning(() => 'Could not read the notes for $cik: $error');
    }
  }

  void _setEventsState(EventsState state) {
    _eventsState = state;
    notifyListeners();
  }

  ReportTab _reportTab = ReportTab.overview;

  /// Which part of the report is on screen.
  ///
  /// Overview to begin with: it answers "is this worth a look" before the
  /// price does. It then stays wherever it is put, across companies as well —
  /// see [search].
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

  DiscountRate? _discountRate;

  /// The company's own required return, where both figures behind it could be
  /// reached. `null` leaves the report on its assumed rate, which is what an
  /// offline or keyless build gets.
  ///
  /// Fetched beside the figures rather than with them: it comes from two
  /// providers that have nothing to do with EDGAR, and a report should appear
  /// whether or not either answers.
  DiscountRate? get discountRate => _discountRate;

  Future<void> _loadDiscountRate(String ticker, int generation) async {
    final rate = await _marketRatesRepo.rateFor(ticker);
    if (generation != _requestGeneration) return;
    _discountRate = rate;
    notifyListeners();
  }

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
    return Valuation(
      snapshot: current,
      pricePerShare: price,
      // The same return the expectations tab discounts at, so a
      // multiple and a discounted cash flow cannot disagree about the
      // same company.
      discountRatePercent: _discountRate?.percent,
    );
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
      // The open tab is deliberately left where it is. Companies are read one
      // after another with the same question in mind, and re-picking the same
      // tab for each of them was the cost of starting every one on the
      // overview.
      _discountRate = null;
      // Cleared, unlike the tab: last company's news says nothing about this
      // one, and it is a minute of work nobody asked for yet.
      _events = const [];
      _eventsFailure = null;
      _eventsState = EventsState.idle;
      _insightStates.clear();
      _insightAnswers.clear();
      _insightFailures.clear();
      _insightGeneratedAt.clear();
      _setState(SnapshotLoaded(snapshot));
      // Whatever a model has already said about this company, straight back on
      // screen: it cost a minute each to get and nothing about it has gone
      // stale in the time it took to open the company again.
      unawaited(_restoreNotes(snapshot.company.cik, generation));
      unawaited(_loadDiscountRate(symbol, generation));
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
