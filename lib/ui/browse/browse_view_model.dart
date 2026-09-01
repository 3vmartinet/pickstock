import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/browse_sort.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/growth_metric.dart';
import 'package:pickstock/data/snapshot/sic_sector.dart';
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
    _directoryRevision = _tickerDirectoryRepo.revision;
    _results = _tickerDirectoryRepo.allCompanies;
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

  void selectSector(SicSector? sector) {
    if (sector == _sector) return;
    _sector = sector;
    _reorder();
    notifyListeners();
    _settingsRepo.setSector(sector);
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
    _directoryRevision = _tickerDirectoryRepo.revision;
    _loadSamples();
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

    if (_sicByCik.isEmpty) _sicByCik = await _database.sicByCik();
    _samplesByCik = await _database.growthSamples(
      metric: _sort.displayedMetric,
      years: _sort.years,
      unbrokenOnly: _sort.needsUnbrokenRun,
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
  void applyWatchlist(Set<String>? members) {
    if (const SetEquality<String>().equals(_watchlistMembers, members)) return;
    _watchlistMembers = members;
    _reorder();
    // Deferred: this is pushed in from a build, and notifying listeners while
    // the tree is building rebuilds widgets that have already been laid out
    // this frame.
    scheduleMicrotask(notifyListeners);
  }

  /// What the current filter is, in a few words, to name a report after.
  String describeFilter(AppLocalizations strings) {
    final parts = [
      if (_sector case final sector?) sector.getLabel(strings),
      if (_query.isNotEmpty) '"$_query"',
      if (_watchlistMembers != null) strings.watchlistFilterLabel,
    ];
    return parts.isEmpty ? strings.watchlistAll : parts.join(' · ');
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
      matches = matches
          .where((company) => SicSector.of(_sicByCik[company.cik]) == sector)
          .toList();
    }

    if (!_sort.ranksByGrowth) {
      // Case-insensitive, so `abc Corp` and `ABC Corp` sit together.
      _results = matches.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return;
    }

    // Fastest growth first, and companies whose growth cannot be stated last
    // rather than interleaved at zero.
    _results = matches.toList()
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
  }

  @override
  void dispose() {
    filterController.dispose();
    super.dispose();
  }
}
