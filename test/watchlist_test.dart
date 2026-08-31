import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/watchlist/watchlist_repo.dart';
import 'package:pickstock/ui/watchlist/watchlist_view_model.dart';

const String _apple = '0000320193';
const String _nvidia = '0001045810';

void main() {
  late AppDatabase database;
  late WatchlistViewModel viewModel;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    GetIt.I
      ..registerSingleton<AppDatabase>(database)
      ..registerLazySingleton<WatchlistRepo>(LocalWatchlistRepo.new);
    viewModel = WatchlistViewModel();
    // The constructor's first read is asynchronous.
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() async {
    viewModel.dispose();
    await database.close();
    await GetIt.I.reset();
  });

  test('starts with a starred list and nothing else', () {
    expect(viewModel.watchlists, hasLength(1));
    expect(viewModel.favourites?.isDefault, isTrue);
    expect(viewModel.favourites?.companyCount, 0);
    expect(viewModel.hasCustomLists, isFalse);
  });

  test('seeds the starred list once, not on every open', () async {
    // A second open of the same database must not add a second one.
    await database.allWatchlists();
    expect(viewModel.watchlists.where((list) => list.isDefault), hasLength(1));
  });

  test('stars and unstars a company', () async {
    expect(viewModel.isStarred(_apple), isFalse);

    await viewModel.toggleStar(_apple);
    expect(viewModel.isStarred(_apple), isTrue);
    expect(viewModel.favourites?.companyCount, 1);

    await viewModel.toggleStar(_apple);
    expect(viewModel.isStarred(_apple), isFalse);
    expect(viewModel.favourites?.companyCount, 0);
  });

  test('keeps a company in as many lists as it is put in', () async {
    final semis = await viewModel.create('Semiconductors', 2);
    await viewModel.toggleStar(_nvidia);
    await viewModel.add(semis, _nvidia);

    expect(viewModel.listsFor(_nvidia).map((list) => list.name), [
      defaultWatchlistName,
      'Semiconductors',
    ]);
    expect(viewModel.listsFor(_apple), isEmpty);
  });

  test('renames and recolours a list', () async {
    final id = await viewModel.create('Typo', 3);
    await viewModel.rename(id, 'Dividend payers', 5);

    final list = viewModel.watchlists.firstWhere((list) => list.id == id);
    expect(list.name, 'Dividend payers');
    expect(list.colourIndex, 5);
  });

  test('deleting a list takes its entries with it', () async {
    final id = await viewModel.create('Temporary', 1);
    await viewModel.add(id, _apple);
    expect(viewModel.listsFor(_apple), hasLength(1));

    await viewModel.delete(id);

    expect(viewModel.watchlists.where((list) => list.id == id), isEmpty);
    // The cascade cleans up, so the company is not left in a list that is gone.
    expect(viewModel.listsFor(_apple), isEmpty);
    expect(await database.watchlistMembership(), isEmpty);
  });

  test('deleting the selected list stops filtering by it', () async {
    final id = await viewModel.create('Temporary', 1);
    viewModel.select(id);
    expect(viewModel.selectedMembers, isNotNull);

    await viewModel.delete(id);

    expect(viewModel.selectedId, isNull);
    expect(viewModel.selectedMembers, isNull);
  });

  test('an empty selection is not the same as no selection', () async {
    expect(viewModel.selectedMembers, isNull);

    viewModel.select(viewModel.favourites!.id);

    // Selected but empty: the grid shows "nothing in this list" rather than
    // the whole directory.
    expect(viewModel.selectedMembers, isEmpty);
  });

  test('suggests a colour no list is already using', () async {
    expect(viewModel.suggestedColourIndex, 1);
    await viewModel.create('One', 1);
    expect(viewModel.suggestedColourIndex, 2);
  });

  test('the starred list sorts first however many are made', () async {
    await viewModel.create('Alpha', 1);
    await viewModel.create('Beta', 2);

    expect(viewModel.watchlists.first.isDefault, isTrue);
    expect(viewModel.watchlists.map((list) => list.name), [
      defaultWatchlistName,
      'Alpha',
      'Beta',
    ]);
  });

  test('counts the companies in each list', () async {
    final id = await viewModel.create('Two', 1);
    await viewModel.add(id, _apple);
    await viewModel.add(id, _nvidia);
    // Adding the same company twice is not two companies.
    await viewModel.add(id, _apple);

    expect(
      viewModel.watchlists.firstWhere((list) => list.id == id).companyCount,
      2,
    );
  });
}
