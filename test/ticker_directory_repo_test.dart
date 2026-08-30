import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/repo/sec/ticker_directory_repo.dart';

void main() {
  late TickerDirectoryRepo repo;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    repo = TickerDirectoryRepo();
    await repo.load();
  });

  test('parses the whole bundled directory', () {
    expect(repo.isLoaded, isTrue);
    expect(repo.tickerCount, greaterThan(10000));
  });

  test('resolves a plain symbol to its zero-padded CIK', () {
    final apple = repo.lookup('AAPL');
    expect(apple, isNotNull);
    expect(apple!.cik, '0000320193');
    expect(apple.name, 'Apple Inc.');
  });

  test('resolves symbols the old input rules made unreachable', () {
    // Hyphenated, and seven characters — both previously rejected.
    expect(repo.lookup('BRK-B')?.name, 'BERKSHIRE HATHAWAY INC');
    expect(repo.lookup('KCAC-UN'), isNotNull);
    expect(repo.lookup('KCAC-UN')!.ticker.length, 7);
  });

  test('is case- and whitespace-insensitive', () {
    expect(repo.lookup('  brk-b  ')?.ticker, 'BRK-B');
  });

  test('returns null rather than throwing for an unlisted symbol', () {
    expect(repo.lookup('ZZZZ'), isNull);
  });

  test('several symbols can share one filer', () {
    final classA = repo.lookup('BRK-A');
    final classB = repo.lookup('BRK-B');
    expect(classA!.cik, classB!.cik);
    expect(classA.ticker, isNot(classB.ticker));
  });

  test('refuses lookups before the directory is parsed', () {
    expect(() => TickerDirectoryRepo().lookup('AAPL'), throwsStateError);
  });
}
