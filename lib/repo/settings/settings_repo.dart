import 'package:get_it/get_it.dart';
import 'package:pickstock/data/research/framework_layout.dart';
import 'package:pickstock/data/snapshot/browse_sort.dart';
import 'package:pickstock/data/snapshot/sic_sector.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

AppDatabase get _database => GetIt.I.get<AppDatabase>();

const String _themeKey = 'themeMode';
const String _sortKey = 'browseSort';
const String _sectorKey = 'browseSector';
const String _watchlistKey = 'browseWatchlist';
const String _debtFreeKey = 'browseDebtFree';
const String _industriesKey = 'browseIndustries';
const String _positiveCashFlowKey = 'browsePositiveCashFlow';
const String _cashToDebtKey = 'browseCashToDebt';
const String _cashGenerativeKey = 'browseCashGenerative';
const String _revenueGrowthKey = 'browseRevenueGrowth';
const String _masterPaneKey = 'masterPaneWidth';
const String _autoDownloadKey = 'autoDownloadUpdates';
const String _autoApplyKey = 'autoApplyUpdates';
const String _frameworkLayoutKey = 'frameworkLayout';
const String _frameworkVerticalCollapsedKey = 'frameworkVerticalCollapsed';
const String _frameworkListStickyKey = 'frameworkListSticky';
const String _autoFetchBusinessDescriptionKey = 'autoFetchBusinessDescription';

/// The handful of choices the app remembers between launches.
///
/// Read once into memory before the first frame, so every getter is
/// synchronous: a view model that had to await its own initial state would
/// render the default first and the remembered one a frame later, which is a
/// flash of the wrong theme and a list that reorders itself as you look at it.
abstract interface class SettingsRepo {
  /// Reads everything into memory. Call once, before the app is built.
  Future<void> load();

  ThemeMode get themeMode;
  Future<void> setThemeMode(ThemeMode mode);

  BrowseSort get browseSort;
  Future<void> setBrowseSort(BrowseSort sort);

  /// The sector the directory was left filtered to, or `null` for all of them.
  SicSector? get sector;
  Future<void> setSector(SicSector? sector);

  /// The SIC codes within [sector] the directory was left narrowed to, empty
  /// for the whole sector. Meaningless without [sector], and cleared with it.
  Set<int> get industries;
  Future<void> setIndustries(Set<int> codes);

  /// The list the directory was left filtered to, or `null` for the whole
  /// directory. The list may since have been deleted, so the caller checks.
  int? get watchlistId;
  Future<void> setWatchlistId(int? id);

  /// The multiple of its debt a company's cash was left having to cover, or
  /// `null` with the filter off.
  double? get cashToDebtMin;
  Future<void> setCashToDebtMin(double? ratio);

  /// How many years running a company was left having to generate cash, or
  /// `null` with the filter off.
  CashGenerativeWindow? get cashGenerative;
  Future<void> setCashGenerative(CashGenerativeWindow? window);

  /// The revenue growth the directory was left narrowed to, or `null` with
  /// the filter off.
  RevenueGrowthFilter? get revenueGrowthFilter;
  Future<void> setRevenueGrowthFilter(RevenueGrowthFilter? filter);

  /// How wide the list was left beside the report, or `null` if the divider
  /// has never been dragged. How much of the window goes to the list and how
  /// much to the report is a working preference, and re-dragging it at every
  /// launch is the kind of small tax that adds up.
  double? get masterPaneWidth;
  Future<void> setMasterPaneWidth(double width);

  /// Whether a newer SEC archive is downloaded as soon as it is offered,
  /// rather than waiting for a press.
  ///
  /// On unless turned off: the download runs behind a working app and touches
  /// nothing, so fetching it unasked costs only bandwidth, while leaving it
  /// to a press means the 1.4 GB starts only once somebody remembers. Loading
  /// it is another matter — that shuts the app for minutes — and stays a
  /// press either way.
  bool get autoDownloadUpdates;
  Future<void> setAutoDownloadUpdates(bool value);

  /// Whether a downloaded SEC archive is automatically applied to the database
  /// once downloading finishes, rather than waiting for manual confirmation.
  bool get autoApplyUpdates;
  Future<void> setAutoApplyUpdates(bool value);

  /// The active layout option for the seven-questions Framework tab.
  FrameworkLayout get frameworkLayout;
  Future<void> setFrameworkLayout(FrameworkLayout layout);

  /// Whether the vertical pane layout shows only the selected question's answer
  /// (collapsed mode) or the full list of answers (expanded mode).
  bool get frameworkVerticalCollapsed;
  Future<void> setFrameworkVerticalCollapsed(bool value);

  /// Whether the seven-questions scorecard is pinned to the top in the list layout.
  bool get frameworkListSticky;
  Future<void> setFrameworkListSticky(bool value);

  /// Whether the business description is automatically fetched with an LLM
  /// when opening a company that does not already have one.
  bool get autoFetchBusinessDescription;
  Future<void> setAutoFetchBusinessDescription(bool value);
}

class LocalSettingsRepo implements SettingsRepo {
  Map<String, String> _values = const {};

  @override
  Future<void> load() async => _values = await _database.allSettings();

  @override
  ThemeMode get themeMode =>
      _read(_themeKey, ThemeMode.values) ?? ThemeMode.system;

  @override
  Future<void> setThemeMode(ThemeMode mode) => _write(_themeKey, mode.name);

  @override
  BrowseSort get browseSort =>
      BrowseSort.parse(_values[_sortKey]) ?? BrowseSort.name;

  @override
  Future<void> setBrowseSort(BrowseSort sort) => _write(_sortKey, sort.name);

  @override
  SicSector? get sector => _read(_sectorKey, SicSector.values);

  @override
  Future<void> setSector(SicSector? sector) =>
      sector == null ? _erase(_sectorKey) : _write(_sectorKey, sector.name);

  /// Stored as the codes joined by commas. Anything unparseable is dropped
  /// rather than thrown over: a corrupt row should widen the filter, not stop
  /// the app from opening.
  @override
  Set<int> get industries {
    final stored = _values[_industriesKey];
    if (stored == null || stored.isEmpty) return const {};
    return {for (final code in stored.split(',')) ?int.tryParse(code)};
  }

  @override
  Future<void> setIndustries(Set<int> codes) => codes.isEmpty
      ? _erase(_industriesKey)
      : _write(_industriesKey, codes.join(','));

  @override
  int? get watchlistId => int.tryParse(_values[_watchlistKey] ?? '');

  @override
  Future<void> setWatchlistId(int? id) =>
      id == null ? _erase(_watchlistKey) : _write(_watchlistKey, '$id');

  /// An earlier version could only ask for no debt at all, stored as a flag.
  /// The nearest the ratio comes to that is the top of its scale.
  @override
  double? get cashToDebtMin {
    final stored = double.tryParse(_values[_cashToDebtKey] ?? '');
    if (stored != null) return stored;
    return _values[_debtFreeKey] == 'true' ? cashToDebtMax : null;
  }

  @override
  Future<void> setCashToDebtMin(double? ratio) => Future.wait([
    // The flag goes either way, so it cannot outlive the setting it stood for.
    // Both writes start now rather than one after the other, so neither is
    // left queued behind the other once the caller has moved on.
    _erase(_debtFreeKey),
    ratio == null ? _erase(_cashToDebtKey) : _write(_cashToDebtKey, '$ratio'),
  ]);

  /// An earlier version only tested the latest year, stored as a flag.
  @override
  CashGenerativeWindow? get cashGenerative =>
      CashGenerativeWindow.parse(_values[_cashGenerativeKey]) ??
      (_values[_positiveCashFlowKey] == 'true'
          ? CashGenerativeWindow.latestYear
          : null);

  @override
  Future<void> setCashGenerative(CashGenerativeWindow? window) => Future.wait([
    _erase(_positiveCashFlowKey),
    window == null
        ? _erase(_cashGenerativeKey)
        : _write(_cashGenerativeKey, window.name),
  ]);

  @override
  RevenueGrowthFilter? get revenueGrowthFilter =>
      RevenueGrowthFilter.parse(_values[_revenueGrowthKey]);

  @override
  Future<void> setRevenueGrowthFilter(RevenueGrowthFilter? filter) =>
      filter == null
      ? _erase(_revenueGrowthKey)
      : _write(_revenueGrowthKey, filter.name);

  /// Anything unparseable reads as never set, which opens at the default
  /// width rather than stopping the app.
  @override
  double? get masterPaneWidth => double.tryParse(_values[_masterPaneKey] ?? '');

  @override
  Future<void> setMasterPaneWidth(double width) =>
      _write(_masterPaneKey, '$width');

  /// Stored only when turned off, so the default is the absence of a row.
  @override
  bool get autoDownloadUpdates => _values[_autoDownloadKey] != 'false';

  @override
  Future<void> setAutoDownloadUpdates(bool value) =>
      value ? _erase(_autoDownloadKey) : _write(_autoDownloadKey, 'false');

  /// Stored only when turned on, so the default is false (manual intervention required).
  @override
  bool get autoApplyUpdates => _values[_autoApplyKey] == 'true';

  @override
  Future<void> setAutoApplyUpdates(bool value) =>
      value ? _write(_autoApplyKey, 'true') : _erase(_autoApplyKey);

  @override
  FrameworkLayout get frameworkLayout =>
      _read(_frameworkLayoutKey, FrameworkLayout.values) ??
      FrameworkLayout.list;

  @override
  Future<void> setFrameworkLayout(FrameworkLayout layout) =>
      layout == FrameworkLayout.list
      ? _erase(_frameworkLayoutKey)
      : _write(_frameworkLayoutKey, layout.name);

  @override
  bool get frameworkVerticalCollapsed =>
      _values[_frameworkVerticalCollapsedKey] == 'true';

  @override
  Future<void> setFrameworkVerticalCollapsed(bool value) => value
      ? _write(_frameworkVerticalCollapsedKey, 'true')
      : _erase(_frameworkVerticalCollapsedKey);

  @override
  bool get frameworkListSticky => _values[_frameworkListStickyKey] != 'false';

  @override
  Future<void> setFrameworkListSticky(bool value) => value
      ? _erase(_frameworkListStickyKey)
      : _write(_frameworkListStickyKey, 'false');

  @override
  bool get autoFetchBusinessDescription =>
      _values[_autoFetchBusinessDescriptionKey] != 'false';

  @override
  Future<void> setAutoFetchBusinessDescription(bool value) => value
      ? _erase(_autoFetchBusinessDescriptionKey)
      : _write(_autoFetchBusinessDescriptionKey, 'false');

  /// Reads an enum by name, tolerating a value this build no longer has: a
  /// renamed sector should reset the filter, not crash the app on launch.
  T? _read<T extends Enum>(String key, List<T> values) {
    final stored = _values[key];
    if (stored == null) return null;
    for (final value in values) {
      if (value.name == stored) return value;
    }
    return null;
  }

  Future<void> _write(String key, String value) async {
    _values = {..._values, key: value};
    await _database.saveSetting(key, value);
  }

  Future<void> _erase(String key) async {
    _values = {..._values}..remove(key);
    await _database.clearSetting(key);
  }
}

/// Remembers nothing beyond the run, for the mock build and for tests that
/// have no database.
class MemorySettingsRepo implements SettingsRepo {
  ThemeMode _themeMode = ThemeMode.system;
  BrowseSort _browseSort = BrowseSort.name;
  SicSector? _sector;
  Set<int> _industries = const {};
  int? _watchlistId;
  double? _cashToDebtMin;
  CashGenerativeWindow? _cashGenerative;
  RevenueGrowthFilter? _revenueGrowthFilter;
  double? _masterPaneWidth;
  bool _autoDownloadUpdates = true;
  bool _autoApplyUpdates = false;
  FrameworkLayout _frameworkLayout = FrameworkLayout.list;
  bool _frameworkVerticalCollapsed = false;
  bool _frameworkListSticky = true;
  bool _autoFetchBusinessDescription = true;

  @override
  Future<void> load() async {}

  @override
  ThemeMode get themeMode => _themeMode;

  @override
  Future<void> setThemeMode(ThemeMode mode) async => _themeMode = mode;

  @override
  BrowseSort get browseSort => _browseSort;

  @override
  Future<void> setBrowseSort(BrowseSort sort) async => _browseSort = sort;

  @override
  SicSector? get sector => _sector;

  @override
  Future<void> setSector(SicSector? sector) async => _sector = sector;

  @override
  Set<int> get industries => _industries;

  @override
  Future<void> setIndustries(Set<int> codes) async => _industries = codes;

  @override
  int? get watchlistId => _watchlistId;

  @override
  Future<void> setWatchlistId(int? id) async => _watchlistId = id;

  @override
  double? get cashToDebtMin => _cashToDebtMin;

  @override
  Future<void> setCashToDebtMin(double? ratio) async => _cashToDebtMin = ratio;

  @override
  CashGenerativeWindow? get cashGenerative => _cashGenerative;

  @override
  Future<void> setCashGenerative(CashGenerativeWindow? window) async =>
      _cashGenerative = window;

  @override
  RevenueGrowthFilter? get revenueGrowthFilter => _revenueGrowthFilter;

  @override
  Future<void> setRevenueGrowthFilter(RevenueGrowthFilter? filter) async =>
      _revenueGrowthFilter = filter;

  @override
  double? get masterPaneWidth => _masterPaneWidth;

  @override
  Future<void> setMasterPaneWidth(double width) async =>
      _masterPaneWidth = width;

  @override
  bool get autoDownloadUpdates => _autoDownloadUpdates;

  @override
  Future<void> setAutoDownloadUpdates(bool value) async =>
      _autoDownloadUpdates = value;

  @override
  bool get autoApplyUpdates => _autoApplyUpdates;

  @override
  Future<void> setAutoApplyUpdates(bool value) async =>
      _autoApplyUpdates = value;

  @override
  FrameworkLayout get frameworkLayout => _frameworkLayout;

  @override
  Future<void> setFrameworkLayout(FrameworkLayout layout) async =>
      _frameworkLayout = layout;

  @override
  bool get frameworkVerticalCollapsed => _frameworkVerticalCollapsed;

  @override
  Future<void> setFrameworkVerticalCollapsed(bool value) async =>
      _frameworkVerticalCollapsed = value;

  @override
  bool get frameworkListSticky => _frameworkListSticky;

  @override
  Future<void> setFrameworkListSticky(bool value) async =>
      _frameworkListSticky = value;

  @override
  bool get autoFetchBusinessDescription => _autoFetchBusinessDescription;

  @override
  Future<void> setAutoFetchBusinessDescription(bool value) async =>
      _autoFetchBusinessDescription = value;
}
