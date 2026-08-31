import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:pickstock/data/watchlist/watchlist.dart';
import 'package:pickstock/repo/db/app_database.dart';

AppDatabase get _database => GetIt.I.get<AppDatabase>();

/// Reads and writes the user's lists.
///
/// Plain reads rather than query streams: nothing outside the app writes these
/// tables, so one view model reloading after each of its own mutations keeps
/// every screen in step — and a stream per screen would only add a cache to
/// invalidate.
abstract interface class WatchlistRepo {
  /// Every list, the starred one first, each with its count.
  Future<List<Watchlist>> all();

  /// Which companies are in which list.
  Future<Map<int, Set<String>>> membership();

  Future<int> create(String name, int colourIndex);

  Future<void> update(int id, {required String name, required int colourIndex});

  Future<void> delete(int id);

  Future<void> add(int watchlistId, String cik);

  Future<void> remove(int watchlistId, String cik);
}

class LocalWatchlistRepo implements WatchlistRepo {
  const LocalWatchlistRepo();

  @override
  Future<List<Watchlist>> all() {
    return _database.allWatchlists().then(
      (rows) => [
        for (final row in rows)
          Watchlist(
            id: row.list.id,
            name: row.list.name,
            colourIndex: row.list.colourIndex,
            isDefault: row.list.isDefault,
            companyCount: row.companyCount,
          ),
      ],
    );
  }

  @override
  Future<Map<int, Set<String>>> membership() => _database.watchlistMembership();

  @override
  Future<int> create(String name, int colourIndex) =>
      _database.createWatchlist(name, colourIndex);

  @override
  Future<void> update(
    int id, {
    required String name,
    required int colourIndex,
  }) => _database.renameWatchlist(id, name, colourIndex);

  @override
  Future<void> delete(int id) => _database.deleteWatchlist(id);

  @override
  Future<void> add(int watchlistId, String cik) =>
      _database.addToWatchlist(watchlistId, cik);

  @override
  Future<void> remove(int watchlistId, String cik) =>
      _database.removeFromWatchlist(watchlistId, cik);
}
