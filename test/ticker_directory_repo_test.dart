import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/company.dart';
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
    expect(repo.search(''), hasLength(testCompanyCount));
  });

  test('deduplicates multi-ticker filers to 1 company per CIK', () {
    // allCompanies has exactly 1 entry per filer.
    expect(repo.allCompanies, hasLength(testCompanyCount));
    final ciks = repo.allCompanies.map((c) => c.cik).toSet();
    expect(ciks, hasLength(testCompanyCount));

    // Prefix match returns primary ticker (BRK-A) rather than duplicates.
    final prefixMatches = repo.search('BRK');
    expect(prefixMatches, hasLength(1));
    expect(prefixMatches.single.ticker, 'BRK-A');

    // Searching an alternate ticker explicitly returns that company with that ticker.
    final alternateMatches = repo.search('BRK-B');
    expect(alternateMatches, hasLength(1));
    expect(alternateMatches.single.ticker, 'BRK-B');

    // Name match returns primary ticker.
    final nameMatches = repo.search('berkshire');
    expect(nameMatches, hasLength(1));
    expect(nameMatches.single.ticker, 'BRK-A');
  });

  test('quotes a filer under its common share, whichever symbol is held', () {
    // Both Berkshire classes are suffixed, so the first SEC lists is quoted
    // for either tile; a filer listed once is quoted as itself.
    expect(repo.quoteSymbolFor(repo.lookup('BRK-B')!), 'BRK-A');
    expect(repo.quoteSymbolFor(repo.lookup('BRK-A')!), 'BRK-A');
    expect(repo.quoteSymbolFor(repo.lookup('KCAC-UN')!), 'KCAC-UN');
    // A company the directory has never heard of keeps its own symbol.
    expect(
      repo.quoteSymbolFor(const Company(ticker: 'ZZZZ', cik: '9', name: 'Z')),
      'ZZZZ',
    );
  });

  test('picks the common share in the order SEC lists symbols', () async {
    // JPMorgan lists its common stock first and an exchange-traded note,
    // AMJB, further down. Alphabetically the note comes first, and quoting
    // it would value the bank at the note's price.
    await database.batch(
      (batch) => batch.insertAll(database.tickers, [
        for (final symbol in ['JPM', 'JPM-PC', 'AMJB', 'VYLD'])
          TickersCompanion.insert(
            symbol: symbol,
            cik: '0000019617',
            name: 'JPMORGAN CHASE & CO',
          ),
      ]),
    );
    await repo.load();

    expect(repo.quoteSymbolFor(repo.lookup('AMJB')!), 'JPM');
    expect(repo.quoteSymbolFor(repo.lookup('JPM-PC')!), 'JPM');
    expect(
      repo.allCompanies.where((c) => c.cik == '0000019617').single.ticker,
      'JPM',
    );
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
