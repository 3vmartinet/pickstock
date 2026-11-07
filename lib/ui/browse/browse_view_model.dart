import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/browse_sort.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/growth_metric.dart';
import 'package:pickstock/data/snapshot/sic_industry.dart';
import 'package:pickstock/data/snapshot/sic_sector.dart';
import 'package:pickstock/data/valuation/valuation_verdict.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/sec/ticker_directory_repo.dart';
import 'package:pickstock/repo/settings/settings_repo.dart';

AppDatabase get _database => GetIt.I.get<AppDatabase>();
TickerDirectoryRepo get _tickerDirectoryRepo =>
    GetIt.I.get<TickerDirectoryRepo>();
SettingsRepo get _settingsRepo => GetIt.I.get<SettingsRepo>();

/// Drives the browsable list of every symbol EDGAR knows about.
///
/// The directory is already parsed and held by [TickerDirectoryRepo], so
/// filtering is a pass over an in-memory list. Growth figures come from the
/// database, once per ordering rather than once per row.
class BrowseViewModel extends ChangeNotifier {
  BrowseViewModel() {
    // Both are read before the first frame, so the list is ordered and
    // filtered from the outset rather than rearranging itself once loaded.
    _sort = _settingsRepo.browseSort;
    _sector = _settingsRepo.sector;
    _industries = _settingsRepo.industries;
    _cashToDebtMin = _settingsRepo.cashToDebtMin;
    _cashGenerative = _settingsRepo.cashGenerative;
    _revenueGrowthFilter = _settingsRepo.revenueGrowthFilter;
    _directoryRevision = _tickerDirectoryRepo.revision;
    _results = _unjudged = _tickerDirectoryRepo.allCompanies;
    _loadSamples();
  }

  final TextEditingController filterController = TextEditingController();

  /// Where the list was left. Popping the route destroys the grid's scroll
  /// position, so the offset is remembered here and a fresh controller is
  /// seeded with it on the way back in.
  double scrollOffset = 0;

  /// The directory revision these results were built from.
  int _directoryRevision = 0;

  String _query = '';
  String get query => _query;

  late BrowseSort _sort;
  BrowseSort get sort => _sort;

  SicSector? _sector;

  /// The sector filter, or `null` for every sector.
  SicSector? get sector => _sector;

  /// Industry code per company, loaded once. Empty until an ingest has run
  /// that collected them.
  Map<String, int> _sicByCik = const {};

  /// Whether any sector is known at all. Where none is, the filter row would
  /// hide the entire list behind chips that match nothing.
  bool get hasSectors => _sicByCik.isNotEmpty;

  /// Selects a whole sector, clearing any narrowing it was left with.
  ///
  /// The chip's label reads as the sector entire, so tapping it means all of
  /// it: a tap that silently kept a two-of-nine narrowing would show a list
  /// that does not match what the chip says.
  void selectSector(SicSector? sector) {
    if (sector == _sector && _industries.isEmpty) return;
    _sector = sector;
    _industries = const {};
    _reorder();
    notifyListeners();
    _settingsRepo.setSector(sector);
    _settingsRepo.setIndustries(const {});
  }

  /// The SIC codes [_sector] is narrowed to. Empty for the whole sector,
  /// which is the default.
  Set<int> _industries = const {};

  /// Every SEC industry present in the data, by sector, built once alongside
  /// [_sicByCik]. Precomputed rather than derived per build: the chips ask for
  /// their counts on every frame, and the directory runs to ten thousand
  /// filers.
  Map<SicSector, List<SicIndustryOption>> _industriesBySector = const {};

  /// The industries [sector] holds, by title, or empty where the ingest
  /// classified none of them.
  List<SicIndustryOption> industriesIn(SicSector sector) =>
      _industriesBySector[sector] ?? const [];

  /// How many of [sector]'s industries the filter is narrowed to, or zero
  /// where the whole sector is in play. What the chip shows to say it is
  /// carrying more than its label admits.
  int narrowedCountIn(SicSector sector) =>
      _sector == sector ? _industries.length : 0;

  /// Whether [sic] is one of the industries [sector] is narrowed to.
  ///
  /// False for every industry of an unnarrowed sector: the boxes stand for
  /// "narrow to these", so none is ticked until one is chosen, and the menu's
  /// own "all industries" row carries that state instead.
  bool isIndustrySelected(SicSector sector, int sic) =>
      _sector == sector && _industries.contains(sic);

  /// Adds or removes one industry from the narrowing.
  ///
  /// Selects [sector] on the way if it was not the sector in play, so a pick
  /// made in another chip's menu takes effect where it was made rather than
  /// changing nothing visible. Unticking the last industry lands back on the
  /// whole sector, because a narrowing that selects nothing would show an
  /// empty list that looks like a broken filter.
  void toggleIndustry(SicSector sector, int sic) {
    final narrowed = _sector == sector ? {..._industries} : <int>{};
    if (!narrowed.remove(sic)) narrowed.add(sic);
    _applyNarrowing(sector, narrowed);
  }

  /// Narrows [sector] to [sic] alone, dropping whatever else was picked.
  ///
  /// What a plain press means: one industry, chosen outright. Adding to a
  /// selection is the shift-press, and goes through [toggleIndustry].
  void selectOnlyIndustry(SicSector sector, int sic) =>
      _applyNarrowing(sector, {sic});

  /// Widens [sector] back to every industry in it.
  void clearNarrowing(SicSector sector) => _applyNarrowing(sector, const {});

  void _applyNarrowing(SicSector sector, Set<int> narrowed) {
    if (sector == _sector &&
        const SetEquality<int>().equals(_industries, narrowed)) {
      return;
    }
    _sector = sector;
    _industries = narrowed;
    _reorder();
    notifyListeners();
    _settingsRepo.setSector(sector);
    _settingsRepo.setIndustries(narrowed);
  }

  double? _cashToDebtMin;

  /// The multiple of its debt a company's cash has to cover for it to stay in
  /// the list, or `null` with the filter off. 1 is "more cash than debt".
  double? get cashToDebtMin => _cashToDebtMin;

  /// Each company's cash over its debt as of its latest filed year, loaded
  /// once alongside the sectors; infinite for a company that owes nothing.
  /// Empty until an ingest has run that collected the figures.
  Map<String, double> _cashToDebtByCik = const {};

  /// Whether the cash filter can say anything. On a database written before
  /// interest expense was extracted it cannot, and offering a filter that
  /// hides the whole directory would look like a broken list.
  bool get canFilterCashToDebt => _cashToDebtByCik.isNotEmpty;

  /// Narrows the list to companies whose cash covers their debt [ratio]
  /// times over, or lifts the filter with `null`.
  ///
  /// Synchronous and in memory, so the slider can call it on every step and
  /// the list follows the thumb.
  void setCashToDebtMin(double? ratio) {
    if (ratio == _cashToDebtMin) return;
    _cashToDebtMin = ratio;
    _reorder();
    notifyListeners();
    _settingsRepo.setCashToDebtMin(ratio);
  }

  CashGenerativeWindow? _cashGenerative;

  /// How many years running a company has to have generated free cash flow,
  /// or `null` with the filter off.
  CashGenerativeWindow? get cashGenerative => _cashGenerative;

  /// The cash-generative companies per window, each loaded the first time it
  /// is asked for. The latest year is loaded up front, both to answer
  /// [canFilterPositiveCashFlow] and because it is the first window offered.
  final Map<CashGenerativeWindow, Set<String>> _cashGenerativeCiks = {};

  /// Whether the cash-flow filter can say anything. On a database written
  /// before cash flows were extracted it cannot, and offering a filter that
  /// hides the whole directory would look like a broken list.
  bool get canFilterPositiveCashFlow =>
      _cashGenerativeCiks[CashGenerativeWindow.latestYear]?.isNotEmpty ?? false;

  Future<void> setCashGenerative(CashGenerativeWindow? window) async {
    if (window == _cashGenerative) return;
    _cashGenerative = window;
    unawaited(_settingsRepo.setCashGenerative(window));
    if (window != null && !_cashGenerativeCiks.containsKey(window)) {
      _cashGenerativeCiks[window] = await _database.positiveFreeCashFlowCiks(
        years: window.years,
      );
      // Picked again while that was loading: the newer choice has its own
      // load under way, and it is the one that should land.
      if (window != _cashGenerative) return;
    }
    _reorder();
    notifyListeners();
  }

  RevenueGrowthFilter? _revenueGrowthFilter;

  /// The revenue growth a company has to show to stay in the list, or `null`
  /// with the filter off. Also the window "Revenue growth" ranks over.
  RevenueGrowthFilter? get revenueGrowthFilter => _revenueGrowthFilter;

  /// The companies passing [_revenueGrowthFilter], loaded with it.
  Set<String> _revenueGrowthCiks = const {};

  Future<void> setRevenueGrowthFilter(RevenueGrowthFilter? filter) async {
    if (filter == _revenueGrowthFilter) return;
    _revenueGrowthFilter = filter;
    unawaited(_settingsRepo.setRevenueGrowthFilter(filter));
    // The ranking's window follows the filter's, so the samples may change
    // with it as well as the set that passes.
    await _loadSamples();
  }

  /// The window "Revenue growth" ranks over: the filter's, so the figure in
  /// each row is the one the filter tested, or the latest year without one.
  int get _revenueYears => _revenueGrowthFilter?.years ?? 1;
  bool get _revenueUnbroken => _revenueGrowthFilter?.needsUnbrokenRun ?? false;

  ValuationVerdict? _verdictFilter;

  /// The valuation verdict a company has to carry to stay in the list, or
  /// `null` with the filter off.
  ///
  /// Not kept across launches, unlike the other filters: it rests on share
  /// prices, which are a quarter of an hour old at best, and a list opening
  /// already narrowed to them would start spending the quote budget before
  /// anyone asked it to.
  ValuationVerdict? get verdictFilter => _verdictFilter;

  /// Picks the verdict to narrow to, or lifts the filter with `null`.
  void setVerdictFilter(ValuationVerdict? verdict) {
    if (verdict == _verdictFilter) return;
    _verdictFilter = verdict;
    _applyVerdictFilter();
    notifyListeners();
  }

  /// The verdicts known so far, by CIK, pushed in by [applyVerdicts].
  Map<String, ValuationVerdict> _verdicts = const {};
  int _verdictRevision = -1;

  /// Takes the list valuation's latest verdicts, which is what the verdict
  /// filter tests against.
  ///
  /// Pushed in for the same reason as [applyWatchlist]: the two view models
  /// are siblings. Cheap when nothing changed, and with the filter off it
  /// only remembers them.
  void applyVerdicts(Map<String, ValuationVerdict> verdicts, int revision) {
    if (revision == _verdictRevision) return;
    _verdictRevision = revision;
    _verdicts = verdicts;
    if (_verdictFilter == null) return;
    _applyVerdictFilter();
    // Pushed in from a build, like the watchlist.
    scheduleMicrotask(notifyListeners);
  }

  /// The list as every other filter leaves it, before the verdict filter.
  List<Company> _unjudged = const [];

  /// The companies the verdict filter is choosing among, for the list
  /// valuation to price; empty with the filter off.
  ///
  /// The same list until another filter changes it, however many verdicts
  /// land, so whoever hands it on can tell a new list from the same one.
  List<Company> get verdictCandidates =>
      _verdictFilter == null ? const [] : _unjudged;

  void _applyVerdictFilter() {
    final verdict = _verdictFilter;
    _results = verdict == null
        ? _unjudged
        : [
            for (final company in _unjudged)
              if (_verdicts[company.cik] == verdict) company,
          ];
  }

  /// Growth window ends for the figure the current ordering shows, by CIK.
  Map<String, GrowthSample> _samplesByCik = const {};

  /// Whether the figures behind the current ordering are still loading.
  bool _isLoadingSamples = true;
  bool get isLoadingSamples => _isLoadingSamples;

  List<Company> _results = const [];

  /// Companies matching [query], in the chosen order.
  List<Company> get results => _results;

  int get totalCount => _tickerDirectoryRepo.tickerCount;
  int get resultCount => _results.length;
  bool get hasResults => _results.isNotEmpty;
  bool get isFiltered => _query.isNotEmpty;

  void setQuery(String query) {
    final trimmed = query.trim();
    if (trimmed == _query) return;
    _query = trimmed;
    _reorder();
    notifyListeners();
  }

  Future<void> selectSort(BrowseSort sort) async {
    if (sort == _sort) return;
    _sort = sort;
    unawaited(_settingsRepo.setBrowseSort(sort));
    // The window changes with the ordering, so the samples do too.
    await _loadSamples();
  }

  /// The company at [index] of the current results, or `null` once the list
  /// has shrunk past it.
  /// Records the scroll position without notifying: listeners have no reason
  /// to rebuild as the list scrolls.
  void rememberScrollOffset(double offset) => scrollOffset = offset;

  /// Rebuilds the list if an ingest has replaced the directory since it was
  /// last built. Cheap enough to call on every build of the browse screen.
  void ensureCurrent() {
    if (_directoryRevision == _tickerDirectoryRepo.revision) return;
    // Recorded before the reload rather than inside it, so the builds between
    // here and the microtask see the revision as handled and do not queue the
    // load again.
    _directoryRevision = _tickerDirectoryRepo.revision;
    // Deferred for the same reason as `applyWatchlist`: this is called from a
    // build, and `_loadSamples` notifies listeners on its first line to raise
    // the spinner. Notifying while the tree is building throws.
    scheduleMicrotask(_loadSamples);
  }

  Company? companyAt(int index) =>
      index >= 0 && index < _results.length ? _results[index] : null;

  /// The figure to show beside [company]: a growth rate under a growth
  /// ordering, the latest revenue when the list is alphabetical.
  double? figureFor(Company company) {
    final sample = _samplesByCik[company.cik];
    if (sample == null) return null;
    return _sort.ranksByGrowth ? sample.annualisedPercent : sample.endValue;
  }

  /// Whether the row figure is a percentage rather than an amount.
  bool get showsGrowth => _sort.ranksByGrowth;

  Future<void> _loadSamples() async {
    _isLoadingSamples = true;
    notifyListeners();

    if (_sicByCik.isEmpty) {
      _sicByCik = await _database.sicByCik();
      _industriesBySector = _groupIndustries(_sicByCik);
    }
    if (_cashToDebtByCik.isEmpty) {
      _cashToDebtByCik = await _database.cashToDebtRatios();
    }
    if (_cashGenerativeCiks.isEmpty) {
      _cashGenerativeCiks[CashGenerativeWindow.latestYear] = await _database
          .positiveFreeCashFlowCiks();
    }
    final cashWindow = _cashGenerative;
    if (cashWindow != null && !_cashGenerativeCiks.containsKey(cashWindow)) {
      _cashGenerativeCiks[cashWindow] = await _database
          .positiveFreeCashFlowCiks(years: cashWindow.years);
    }

    final revenueFilter = _revenueGrowthFilter;
    final revenueSamples = await _database.growthSamples(
      metric: GrowthMetric.revenue,
      years: _revenueYears,
      unbrokenOnly: _revenueUnbroken,
    );
    _revenueGrowthCiks = revenueFilter == null
        ? const {}
        : {
            for (final MapEntry(key: cik, value: sample)
                in revenueSamples.entries)
              if ((sample.annualisedPercent ?? 0) > 0) cik,
          };
    _samplesByCik = _sort.displayedMetric == GrowthMetric.revenue
        ? revenueSamples
        : await _database.growthSamples(
            metric: _sort.displayedMetric,
            years: 1,
          );
    _isLoadingSamples = false;
    _reorder();
    notifyListeners();
  }

  Set<String>? _watchlistMembers;

  /// Which list the grid is narrowed to, as the set of CIKs in it, or `null`
  /// for the whole directory.
  ///
  /// Pushed in by the watchlist view model rather than read from it: the two
  /// are siblings, and a browse model that reached into another would have to
  /// know when it changed.
  ///
  /// Carries no opinion about the rest of the filter. This runs whenever the
  /// members change — starring a company while its list is open is one — and
  /// clearing here would pull the filters out from under someone mid-browse.
  /// Choosing a list is [clearNarrowings], which the menu calls when it is
  /// pressed.
  void applyWatchlist(Set<String>? members) {
    if (const SetEquality<String>().equals(_watchlistMembers, members)) return;
    _watchlistMembers = members;
    _reorder();
    // Deferred: this is pushed in from a build, and notifying listeners while
    // the tree is building rebuilds widgets that have already been laid out
    // this frame.
    scheduleMicrotask(notifyListeners);
  }

  /// Drops every narrowing except the list itself.
  ///
  /// Called when a list is picked from the menu. A list is a small, deliberate
  /// set of companies, and whatever narrowed the whole directory a moment ago
  /// has no bearing on them: left on, a sector or a search can hide most of a
  /// list — or all of it, which reads as an empty list rather than as a filter
  /// still in force.
  ///
  /// Driven by the press rather than by the list changing underneath, because
  /// pressing the list you are already on is still a request to see it. Read
  /// off a change of list, that press changes nothing and so did nothing,
  /// which is exactly when the filters are most likely to be hiding it.
  void clearNarrowings() {
    if (_query.isEmpty &&
        _sector == null &&
        _industries.isEmpty &&
        _cashToDebtMin == null &&
        _cashGenerative == null &&
        _revenueGrowthFilter == null &&
        _verdictFilter == null) {
      return;
    }

    _query = '';
    filterController.clear();
    _sector = null;
    _industries = const {};
    _cashToDebtMin = null;
    _cashGenerative = null;
    final hadRevenueFilter = _revenueGrowthFilter != null;
    _revenueGrowthFilter = null;
    _revenueGrowthCiks = const {};
    _verdictFilter = null;
    _reorder();
    notifyListeners();
    // The ranking's window was the filter's, so it goes back to a year.
    if (hadRevenueFilter && _sort == BrowseSort.revenueGrowth) {
      unawaited(_loadSamples());
    }

    _settingsRepo.setSector(null);
    _settingsRepo.setIndustries(const {});
    _settingsRepo.setCashToDebtMin(null);
    _settingsRepo.setCashGenerative(null);
    _settingsRepo.setRevenueGrowthFilter(null);
  }

  /// What the current filter is, in a few words, to name a report after.
  String describeFilter(AppLocalizations strings) {
    final parts = [
      if (_sector case final sector?) _describeSector(strings, sector),
      if (_cashToDebtMin case final ratio?)
        strings.cashToDebtChip(formatCashToDebt(ratio)),
      if (_cashGenerative case final window?) window.getChipLabel(strings),
      if (_revenueGrowthFilter case final filter?) filter.getChipLabel(strings),
      if (_verdictFilter case final verdict?) verdict.getLabel(strings),
      if (_query.isNotEmpty) '"$_query"',
      if (_watchlistMembers != null) strings.watchlistFilterLabel,
    ];
    return parts.isEmpty ? strings.watchlistAll : parts.join(' · ');
  }

  /// The sector as filtered, which is not always the sector entire: a report
  /// named "Tech" that in fact covered two of its nine industries would be
  /// mislabelled for as long as it is kept.
  String _describeSector(AppLocalizations strings, SicSector sector) {
    final label = sector.getLabel(strings);
    if (_industries.isEmpty) return label;
    // One industry names itself; several are only summarised, since the
    // titles run to fifty characters each.
    if (_industries.length == 1) {
      return SicIndustry.labelFor(_industries.single);
    }
    return strings.browseIndustriesFilter(label, _industries.length);
  }

  /// Whether the grid is narrowed to a list that happens to be empty, as
  /// opposed to a search that found nothing.
  bool get isEmptyWatchlist => _watchlistMembers?.isEmpty ?? false;

  void _reorder() {
    var matches = _tickerDirectoryRepo.search(_query);

    final members = _watchlistMembers;
    if (members != null) {
      matches = matches
          .where((company) => members.contains(company.cik))
          .toList();
    }

    final sector = _sector;
    if (sector != null) {
      final narrowed = _industries;
      matches = matches.where((company) {
        final sic = _sicByCik[company.cik];
        if (SicSector.of(sic) != sector) return false;
        return narrowed.isEmpty || narrowed.contains(sic);
      }).toList();
    }

    if (_cashToDebtMin case final ratio?) {
      matches = matches.where((company) {
        final covered = _cashToDebtByCik[company.cik];
        return covered != null && covered >= ratio;
      }).toList();
    }

    if (_cashGenerative case final window?) {
      // Still loading: nothing passes yet, which the next notify corrects.
      final passing = _cashGenerativeCiks[window] ?? const <String>{};
      matches = matches
          .where((company) => passing.contains(company.cik))
          .toList();
    }

    if (_revenueGrowthFilter != null) {
      matches = matches
          .where((company) => _revenueGrowthCiks.contains(company.cik))
          .toList();
    }

    if (!_sort.ranksByGrowth) {
      // Case-insensitive, so `abc Corp` and `ABC Corp` sit together.
      _unjudged = matches.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _applyVerdictFilter();
      return;
    }

    // Fastest growth first, and companies whose growth cannot be stated last
    // rather than interleaved at zero.
    _unjudged = matches.toList()
      ..sort((a, b) {
        final left = figureFor(a);
        final right = figureFor(b);
        if (left == null && right == null) {
          return a.ticker.compareTo(b.ticker);
        }
        if (left == null) return 1;
        if (right == null) return -1;
        return right.compareTo(left);
      });
    _applyVerdictFilter();
  }

  @override
  void dispose() {
    filterController.dispose();
    super.dispose();
  }
}

/// Groups every SIC code the ingest collected into the sector holding it,
/// counting the filers under each.
///
/// Codes outside every sector's ranges are dropped — public administration
/// and the like, which no chip can reach — so a sector's options always add
/// up to what selecting that sector shows.
Map<SicSector, List<SicIndustryOption>> _groupIndustries(
  Map<String, int> sicByCik,
) {
  final counts = <int, int>{};
  for (final sic in sicByCik.values) {
    counts.update(sic, (count) => count + 1, ifAbsent: () => 1);
  }

  final grouped = <SicSector, List<SicIndustryOption>>{};
  for (final MapEntry(key: sic, value: count) in counts.entries) {
    final sector = SicSector.of(sic);
    if (sector == null) continue;
    grouped
        .putIfAbsent(sector, () => [])
        .add(
          SicIndustryOption(
            sic: sic,
            title: SicIndustry.labelFor(sic),
            companyCount: count,
          ),
        );
  }

  // By title, which is the order the menu reads in. Sorting by code would
  // order them by SEC's numbering, which means nothing to the eye.
  for (final options in grouped.values) {
    options.sort((a, b) => a.title.compareTo(b.title));
  }
  return grouped;
}
