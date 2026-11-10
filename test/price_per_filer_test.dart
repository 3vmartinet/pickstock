import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/repo/db/app_database.dart';

/// Quotes an earlier build fetched under a warrant's or a preferred share's
/// symbol are dropped once, the first time the database is opened by a build
/// that quotes the common share.
void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    directory = await Directory.systemTemp.createTemp('pickstock-prices');
    file = File('${directory.path}/pickstock.sqlite');
  });

  tearDown(() => directory.delete(recursive: true));

  AppDatabase open() => AppDatabase.forTesting(NativeDatabase(file));

  test('drops fetched prices of multi-symbol filers, once', () async {
    // What an install from before the fix looks like: prices on file, and no
    // record of the clean-up having run.
    var database = open();
    await database.batch(
      (batch) => batch.insertAll(database.tickers, [
        TickersCompanion.insert(symbol: 'OPEN', cik: '1', name: 'Opendoor'),
        TickersCompanion.insert(symbol: 'OPENW', cik: '1', name: 'Opendoor'),
        TickersCompanion.insert(symbol: 'KO', cik: '2', name: 'Coca-Cola'),
        TickersCompanion.insert(symbol: 'TSLA', cik: '3', name: 'Tesla'),
      ]),
    );
    final now = DateTime.now();
    // Opendoor: the warrant's price, fetched. Coca-Cola: a single listing,
    // fetched. Tesla: typed by the reader, under a second symbol as well.
    await database
        .into(database.tickers)
        .insert(TickersCompanion.insert(symbol: 'TSLAW', cik: '3', name: 'T'));
    await database.savePrice(
      '1',
      pricePerShare: 0.035,
      asOf: now,
      isQuoted: true,
      fetchedAt: now,
    );
    await database.savePrice(
      '2',
      pricePerShare: 96,
      asOf: now,
      isQuoted: true,
      fetchedAt: now,
    );
    await database.savePrice(
      '3',
      pricePerShare: 380,
      asOf: now,
      isQuoted: false,
    );
    await database.clearSetting(pricesQuotedPerFilerKey);
    await database.close();

    database = open();
    expect(await database.priceFor('1'), isNull);
    expect((await database.priceFor('2'))?.pricePerShare, 96);
    expect((await database.priceFor('3'))?.pricePerShare, 380);

    // Done once: a price fetched afterwards is a common share's and stays.
    await database.savePrice(
      '1',
      pricePerShare: 7.5,
      asOf: now,
      isQuoted: true,
      fetchedAt: now,
    );
    await database.close();
    database = open();
    expect((await database.priceFor('1'))?.pricePerShare, 7.5);
    await database.close();
  });

  test('a fresh database records the clean-up as done', () async {
    final database = open();
    expect((await database.allSettings())[pricesQuotedPerFilerKey], 'true');
    await database.close();
  });
}
