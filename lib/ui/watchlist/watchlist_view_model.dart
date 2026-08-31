import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/watchlist/watchlist.dart';
import 'package:pickstock/repo/watchlist/watchlist_repo.dart';

WatchlistRepo get _watchlistRepo => GetIt.I.get<WatchlistRepo>();

/// The user's lists, live.
///
/// App-level and long-lived: a star tapped on a report has to show up on the
/// list beside it, and the chosen list has to survive navigating into a company
/// and back.
class WatchlistViewModel extends ChangeNotifier {
  WatchlistViewModel() {
    unawaited(_reload());
  }

  /// Rereads both tables and republishes them together, so the lists and their
  /// membership are never a step apart on screen.
  Future<void> _reload() async {
    final lists = await _watchlistRepo.all();
    final membership = await _watchlistRepo.membership();
    _watchlists = lists;
    _membership = membership;
    // A deleted list must not stay selected, or the grid filters to something
    // that no longer exists.
    if (_selectedId != null && !lists.any((list) => list.id == _selectedId)) {
      _selectedId = null;
    }
    notifyListeners();
  }

  List<Watchlist> _watchlists = const [];
  List<Watchlist> get watchlists => _watchlists;

  Map<int, Set<String>> _membership = const {};

  int? _selectedId;

  /// Which list the directory is filtered to, or `null` for all companies.
  int? get selectedId => _selectedId;

  Watchlist? get selected =>
      _watchlists.where((list) => list.id == _selectedId).firstOrNull;

  /// The starred list, which the star button toggles.
  Watchlist? get favourites =>
      _watchlists.where((list) => list.isDefault).firstOrNull;

  bool get hasCustomLists => _watchlists.any((list) => !list.isDefault);

  /// The next palette colour that no list is using, so a new list looks
  /// distinct without the user having to choose.
  int get suggestedColourIndex {
    final taken = _watchlists.map((list) => list.colourIndex).toSet();
    for (var index = 0; index < _paletteSize; index++) {
      if (!taken.contains(index)) return index;
    }
    return _watchlists.length % _paletteSize;
  }

  /// The lists [cik] belongs to, in display order.
  List<Watchlist> listsFor(String cik) => [
    for (final list in _watchlists)
      if (_membership[list.id]?.contains(cik) ?? false) list,
  ];

  bool isStarred(String cik) {
    final starred = favourites;
    return starred != null && (_membership[starred.id]?.contains(cik) ?? false);
  }

  bool contains(int watchlistId, String cik) =>
      _membership[watchlistId]?.contains(cik) ?? false;

  /// The companies in the selected list, or `null` when no list is selected —
  /// which is not the same as an empty list, and the grid treats it differently.
  Set<String>? get selectedMembers {
    final id = _selectedId;
    return id == null ? null : (_membership[id] ?? const <String>{});
  }

  void select(int? watchlistId) {
    if (_selectedId == watchlistId) return;
    _selectedId = watchlistId;
    notifyListeners();
  }

  Future<void> toggleStar(String cik) async {
    final starred = favourites;
    if (starred == null) return;
    await toggle(starred.id, cik);
  }

  Future<void> add(int watchlistId, String cik) async {
    await _watchlistRepo.add(watchlistId, cik);
    await _reload();
  }

  Future<void> toggle(int watchlistId, String cik) async {
    if (contains(watchlistId, cik)) {
      await _watchlistRepo.remove(watchlistId, cik);
    } else {
      await _watchlistRepo.add(watchlistId, cik);
    }
    await _reload();
  }

  Future<int> create(String name, int colourIndex) async {
    final id = await _watchlistRepo.create(name.trim(), colourIndex);
    await _reload();
    return id;
  }

  Future<void> rename(int id, String name, int colourIndex) async {
    await _watchlistRepo.update(
      id,
      name: name.trim(),
      colourIndex: colourIndex,
    );
    await _reload();
  }

  Future<void> delete(int id) async {
    await _watchlistRepo.delete(id);
    await _reload();
  }
}

/// Kept in step with the palette in `ThemeRepo`, which the view model cannot
/// read because picking a colour must not depend on a `BuildContext`.
const int _paletteSize = 8;
