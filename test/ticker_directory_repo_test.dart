import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/sec/ticker_directory_repo.dart';

import 'support/test_directory.dart';

void main() {
  late AppDatabase database;
  late TickerDirectoryRepo repo;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    database = await registerTestDependencies();
    repo = GetIt.I.get<TickerDirectoryRepo>();
  });

  tearDown(() async {
    await database.close();
    await GetIt.I.reset();
  });

  test('loads every symbol the ingest wrote', () {
    expect(repo.isLoaded, isTrue);
    expect(repo.tickerCount, testTickers.length);
  });

  test('resolves a plain symbol to its zero-padded CIK', () {
    final apple = repo.lookup('AAPL');
    expect(apple, isNotNull);
    expect(apple!.cik, '0000320193');
    expect(apple.name, 'Apple Inc.');
  });

  test('resolves symbols the old input rules made unreachable', () {
    expect(repo.lookup('BRK-B')?.name, 'BERKSHIRE HATHAWAY INC');
    expect(repo.lookup('KCAC-UN')!.ticker.length, 7);
  });

  test('is case- and whitespace-insensitive', () {
    expect(repo.lookup('  brk-b  ')?.ticker, 'BRK-B');
  });

  test('returns null rather than throwing for an unlisted symbol', () {
    expect(repo.lookup('ZZZZ'), isNull);
  });

  test('several symbols can share one filer', () {
    expect(repo.lookup('BRK-A')!.cik, repo.lookup('BRK-B')!.cik);
  });

  test('ranks symbol matches above name matches', () {
    // Both companies are called "Apple …", but AAPL is the symbol match.
    final matches = repo.search('AAPL');
    expect(matches.first.ticker, 'AAPL');
    expect(repo.search('apple').map((c) => c.ticker), contains('AAPI'));
  });

  test('caps results when a limit is given', () {
    // An empty query deliberately returns everything; a real one is capped.
    expect(repo.search('A', limit: 2), hasLength(2));
    expect(repo.search(''), hasLength(testTickers.length));
  });

  test('reads nothing when the database has never been ingested', () async {
    // Same database, emptied — a second open instance makes drift complain.
    await database.clearFinancials();
    await repo.load();

    expect(repo.isLoaded, isFalse);
    expect(repo.tickerCount, 0);
  });

  test('refuses lookups before the directory is loaded', () {
    expect(() => TickerDirectoryRepo().lookup('AAPL'), throwsStateError);
  });
}
