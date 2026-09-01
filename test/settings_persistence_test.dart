import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/browse_sort.dart';
import 'package:pickstock/data/snapshot/sic_sector.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/settings/settings_repo.dart';
import 'package:pickstock/repo/watchlist/watchlist_repo.dart';
import 'package:pickstock/ui/app_view_model.dart';
import 'package:pickstock/ui/watchlist/watchlist_view_model.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  late AppDatabase database;

  /// A fresh repo over the same database, which is what the next launch gets.
  Future<SettingsRepo> reopen() async {
    final repo = LocalSettingsRepo();
    await repo.load();
    if (GetIt.I.isRegistered<SettingsRepo>()) {
      await GetIt.I.unregister<SettingsRepo>();
    }
    GetIt.I.registerSingleton<SettingsRepo>(repo);
    return repo;
  }

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    database = AppDatabase.forTesting(NativeDatabase.memory());
    GetIt.I
      ..registerSingleton<AppDatabase>(database)
      ..registerLazySingleton<WatchlistRepo>(LocalWatchlistRepo.new);
    await reopen();
  });

  tearDown(() async {
    await database.close();
    await GetIt.I.reset();
  });

  test('remembers nothing on a first launch', () async {
    final settings = GetIt.I.get<SettingsRepo>();

    expect(settings.themeMode, ThemeMode.system);
    expect(settings.browseSort, BrowseSort.name);
    expect(settings.sector, isNull);
    expect(settings.watchlistId, isNull);
  });

  test('remembers the theme across a launch', () async {
    await GetIt.I.get<SettingsRepo>().setThemeMode(ThemeMode.dark);

    expect((await reopen()).themeMode, ThemeMode.dark);
  });

  test('remembers the ordering and the sector', () async {
    final settings = GetIt.I.get<SettingsRepo>();
    await settings.setBrowseSort(BrowseSort.revenueFiveYears);
    await settings.setSector(SicSector.technology);

    final next = await reopen();
    expect(next.browseSort, BrowseSort.revenueFiveYears);
    expect(next.sector, SicSector.technology);
  });

  test('clearing a filter is remembered as cleared', () async {
    final settings = GetIt.I.get<SettingsRepo>();
    await settings.setSector(SicSector.energy);
    await settings.setSector(null);

    expect((await reopen()).sector, isNull);
  });

  test('shrugs off a value this build no longer has', () async {
    // A renamed or removed sector should reset the filter, not stop the app
    // from starting.
    await database.saveSetting('browseSector', 'aquacultureAndSpaceMining');

    expect((await reopen()).sector, isNull);
  });

  test(
    'the theme a toggle picked is the theme the next launch opens in',
    () async {
      final viewModel = AppViewModel()..toggleTheme(Brightness.light);
      expect(viewModel.themeMode, ThemeMode.dark);
      // The write is not awaited by the toggle, so let it land.
      await Future<void>.delayed(Duration.zero);

      await reopen();
      expect(AppViewModel().themeMode, ThemeMode.dark);
      viewModel.dispose();
    },
  );

  test('remembers the chosen list, and forgets a deleted one', () async {
    final watchlists = WatchlistViewModel();
    await Future<void>.delayed(Duration.zero);
    final id = await watchlists.create('Semiconductors', 2);
    watchlists.select(id);
    await Future<void>.delayed(Duration.zero);

    expect((await reopen()).watchlistId, id);

    // Delete it, and the next launch opens on the whole directory rather than
    // filtering to a list that is gone.
    await watchlists.delete(id);
    final next = WatchlistViewModel();
    await Future<void>.delayed(Duration.zero);
    expect(next.selectedId, isNull);
    await Future<void>.delayed(Duration.zero);
    expect((await reopen()).watchlistId, isNull);

    watchlists.dispose();
    next.dispose();
  });
}
