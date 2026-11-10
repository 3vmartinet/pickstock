import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/price_repo.dart';
import 'package:pickstock/repo/quote/bulk_price_refresh.dart';

import 'support/test_directory.dart';

const String _appleCik = '0000320193';
const String _berkshireCik = '0001067983';
const String _nvidiaCik = '0001045810';

void main() {
  late AppDatabase database;
  late FakeBulkPriceRepo closes;

  Future<void> boot(Map<String, double> prices) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    closes = FakeBulkPriceRepo(prices);
    database = await registerTestDependencies(
      withFinancials: true,
      bulkPriceRepo: closes,
    );
  }

  tearDown(() async {
    await database.close();
    await GetIt.I.reset();
  });

  test('stores each close against its filer, under the common share', () async {
    // BRK.A is how the provider spells SEC's BRK-A; AAPLW would be a
    // warrant, which is nobody's common share and is left alone.
    await boot({'AAPL': 250, 'BRK.A': 700000, 'AAPLW': 0.5, 'ZZZZ': 1});
    final refresh = GetIt.I.get<BulkPriceRefresh>();
    var notified = 0;
    refresh.addListener(() => notified++);

    await refresh.refreshIfDue();

    final prices = GetIt.I.get<PriceRepo>();
    final apple = await prices.priceFor(_appleCik);
    expect(apple?.pricePerShare, 250);
    expect(apple?.isQuoted, isTrue);
    expect(apple?.fetchedAt, isNotNull);
    expect((await prices.priceFor(_berkshireCik))?.pricePerShare, 700000);
    expect(await prices.priceFor(_nvidiaCik), isNull);
    expect(refresh.tradingDay, closes.tradingDay);
    expect(notified, 1);
  });

  test('leaves a price the reader typed alone', () async {
    await boot({'AAPL': 250, 'NVDA': 180});
    final prices = GetIt.I.get<PriceRepo>();
    await prices.save(_appleCik, Quote.entered(99));

    await GetIt.I.get<BulkPriceRefresh>().refreshIfDue();

    expect((await prices.priceFor(_appleCik))?.pricePerShare, 99);
    expect((await prices.priceFor(_appleCik))?.isQuoted, isFalse);
    expect((await prices.priceFor(_nvidiaCik))?.pricePerShare, 180);
  });

  test('asks once a day, not on every launch', () async {
    await boot({'AAPL': 250});
    final refresh = GetIt.I.get<BulkPriceRefresh>();
    await refresh.refreshIfDue();
    await refresh.refreshIfDue();
    expect(closes.fetched, 1);

    // A new session inside the window reads the record and asks nothing.
    final again = BulkPriceRefresh();
    await again.refreshIfDue();
    expect(closes.fetched, 1);
    expect(again.tradingDay, closes.tradingDay);

    // Outside it, the next session asks again.
    final later = BulkPriceRefresh(
      now: () => DateTime.now().add(bulkPriceFreshness * 2),
    );
    await later.refreshIfDue();
    expect(closes.fetched, 2);
  });

  test('a day that could not be fetched is tried again next time', () async {
    await boot(const {});
    final refresh = GetIt.I.get<BulkPriceRefresh>();
    await refresh.refreshIfDue();
    await refresh.refreshIfDue();
    expect(closes.fetched, 2);
    expect(await GetIt.I.get<PriceRepo>().priceFor(_appleCik), isNull);
  });
}
