import 'package:get_it/get_it.dart';
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

  /// Whether the directory was left narrowed to companies that owe nothing.
  bool get debtFreeOnly;
  Future<void> setDebtFreeOnly(bool value);

  /// Whether the directory was left narrowed to companies whose latest filed
  /// year generated cash rather than consumed it.
  bool get positiveCashFlowOnly;
  Future<void> setPositiveCashFlowOnly(bool value);
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
      _read(_sortKey, BrowseSort.values) ?? BrowseSort.name;

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

  @override
  bool get debtFreeOnly => _values[_debtFreeKey] == 'true';

  @override
  Future<void> setDebtFreeOnly(bool value) =>
      value ? _write(_debtFreeKey, 'true') : _erase(_debtFreeKey);

  @override
  bool get positiveCashFlowOnly => _values[_positiveCashFlowKey] == 'true';

  @override
  Future<void> setPositiveCashFlowOnly(bool value) => value
      ? _write(_positiveCashFlowKey, 'true')
      : _erase(_positiveCashFlowKey);

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
  bool _debtFreeOnly = false;
  bool _positiveCashFlowOnly = false;

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
  bool get debtFreeOnly => _debtFreeOnly;

  @override
  Future<void> setDebtFreeOnly(bool value) async => _debtFreeOnly = value;

  @override
  bool get positiveCashFlowOnly => _positiveCashFlowOnly;

  @override
  Future<void> setPositiveCashFlowOnly(bool value) async =>
      _positiveCashFlowOnly = value;
}
