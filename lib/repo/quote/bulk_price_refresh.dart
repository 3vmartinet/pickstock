import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/extensions/object_extensions.dart';
import 'package:pickstock/repo/db/app_database.dart';
import 'package:pickstock/repo/quote/bulk_price_repo.dart';
import 'package:pickstock/repo/sec/ticker_directory_repo.dart';

AppDatabase get _database => GetIt.I.get<AppDatabase>();
BulkPriceRepo get _bulkPrices => GetIt.I.get<BulkPriceRepo>();
TickerDirectoryRepo get _directory => GetIt.I.get<TickerDirectoryRepo>();

/// How long after a check before the prices are asked for again. The bars
/// change once a day, after midnight Eastern, so a session left open picks
/// the new day up within a few hours of it; a launch inside the window costs
/// no request at all.
const Duration bulkPriceFreshness = Duration(hours: 6);

/// Where the last check is recorded, in the settings table.
const String bulkPricesCheckedKey = 'bulkPrices.checkedAt';
const String bulkPricesTradingDayKey = 'bulkPrices.tradingDay';

/// Puts the day's closing price against every filer in the directory, once
/// a day, in the background.
///
/// Stored exactly as a Finnhub quote is — per filer, under its common share —
/// so everything that reads a stored price reads these: the tiles judge from
/// them without a quote each, the scan values from them without waiting on
/// the budget, and the largest-by-value rankings are current for every
/// company rather than the handful quoted so far. A price the reader typed
/// is theirs and is left alone.
///
/// A [ChangeNotifier] so the list can hear that every price moved and judge
/// its tiles again, rather than keeping yesterday's verdicts until relaunch.
class BulkPriceRefresh extends ChangeNotifier {
  BulkPriceRefresh({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  bool _isRunning = false;

  /// Whether a bulk source is built in at all.
  bool get isConfigured => _bulkPrices.isConfigured;

  DateTime? _tradingDay;

  /// The trading day the stored prices are from, once one has been loaded
  /// this session.
  DateTime? get tradingDay => _tradingDay;

  /// Fetches and stores the latest closes unless that was done within
  /// [bulkPriceFreshness]. Safe to call on every launch and after every
  /// ingest; it does nothing without a key.
  Future<void> refreshIfDue() async {
    if (!isConfigured || _isRunning) return;
    _isRunning = true;
    try {
      final settings = await _database.allSettings();
      final checked = int.tryParse(settings[bulkPricesCheckedKey] ?? '');
      final tradingDay = int.tryParse(settings[bulkPricesTradingDayKey] ?? '');
      if (tradingDay != null) {
        _tradingDay ??= DateTime.fromMillisecondsSinceEpoch(
          tradingDay,
          isUtc: true,
        );
      }
      if (checked != null &&
          _now()
                  .difference(DateTime.fromMillisecondsSinceEpoch(checked))
                  .abs() <
              bulkPriceFreshness) {
        return;
      }
      await _refresh();
    } on Object catch (error) {
      logWarning(() => 'Bulk price refresh failed: $error');
    } finally {
      _isRunning = false;
    }
  }

  Future<void> _refresh() async {
    final prices = await _bulkPrices.fetchLatest();
    // A failed fetch is not recorded as a check: the next launch tries again
    // rather than waiting out a window on nothing.
    if (prices == null) return;

    final typed = await _database.typedPriceCiks();
    final now = _now();
    final rows = <SharePricesCompanion>[];
    for (final company in _directory.allCompanies) {
      // The directory lists each filer once, under its common share. The
      // provider writes a share class with a dot where SEC writes a hyphen.
      final close =
          prices.closeBySymbol[company.ticker] ??
          prices.closeBySymbol[company.ticker.replaceAll('-', '.')];
      if (close == null || typed.contains(company.cik)) continue;
      rows.add(
        SharePricesCompanion.insert(
          cik: company.cik,
          pricePerShare: close,
          asOf: prices.tradingDay,
          isQuoted: const Value(true),
          fetchedAt: Value(now),
        ),
      );
    }
    await _database.savePrices(rows);
    await _database.saveSetting(
      bulkPricesCheckedKey,
      '${now.millisecondsSinceEpoch}',
    );
    await _database.saveSetting(
      bulkPricesTradingDayKey,
      '${prices.tradingDay.millisecondsSinceEpoch}',
    );
    _tradingDay = prices.tradingDay;
    logInfo(
      () =>
          'Stored ${rows.length} closing prices from '
          '${prices.tradingDay.toIso8601String().substring(0, 10)}',
    );
    notifyListeners();
  }
}
