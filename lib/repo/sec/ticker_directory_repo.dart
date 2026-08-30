import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/extensions/object_extensions.dart';

/// A snapshot of SEC EDGAR's ticker directory, taken on 2026-08-30 from
/// https://www.sec.gov/files/company_tickers.json.
///
/// Bundled rather than fetched: it is the same ~800 KB for every user, changes
/// only as companies list and delist, and fetching it made the first lookup of
/// a session wait on a download that the browser could not even make without a
/// proxy. Refreshing it is a separate concern, not yet wired up.
const String _directoryAsset = 'assets/sec/company_tickers.json';

const String _tickerKey = 'ticker';
const String _cikKey = 'cik_str';
const String _titleKey = 'title';
const int _cikDigits = 10;
const String _cikPadding = '0';

/// Maps ticker symbols to the SEC filers behind them.
///
/// The directory is parsed once and held for the life of the process; every
/// lookup after that is a map read.
class TickerDirectoryRepo {
  Map<String, Company>? _companiesByTicker;
  List<Company>? _companiesByTickerOrder;

  /// Whether [load] has already run.
  bool get isLoaded => _companiesByTicker != null;

  /// How many symbols the directory knows about.
  int get tickerCount => _companiesByTicker?.length ?? 0;

  /// Every symbol, ordered alphabetically. Sorted once at load so browsing
  /// never pays for it.
  List<Company> get allCompanies =>
      List.unmodifiable(_companiesByTickerOrder ?? const []);

  /// Parses the bundled directory. Safe to call more than once; the second
  /// call is a no-op.
  Future<void> load() async {
    if (_companiesByTicker != null) return;

    final payload = jsonDecode(
      await rootBundle.loadString(_directoryAsset),
    ) as Map<String, dynamic>;

    final companiesByTicker = <String, Company>{};
    for (final raw in payload.values) {
      final entry = raw as Map<String, dynamic>;
      // Tickers carry '-' and '.' as well as letters, e.g. BRK-B, and a filer
      // often has several of them, so the ticker is the key, not the CIK.
      final ticker = (entry[_tickerKey] as String).toUpperCase();
      companiesByTicker[ticker] = Company(
        ticker: ticker,
        cik: entry[_cikKey].toString().padLeft(_cikDigits, _cikPadding),
        name: entry[_titleKey] as String? ?? ticker,
      );
    }

    _companiesByTicker = companiesByTicker;
    _companiesByTickerOrder = companiesByTicker.values.toList()
      ..sort((a, b) => a.ticker.compareTo(b.ticker));
    logInfo(() => 'Loaded ${companiesByTicker.length} tickers from the bundle');
  }

  /// The filer trading under [ticker], or `null` if EDGAR lists no such symbol.
  ///
  /// Throws a [StateError] if called before [load] completes.
  Company? lookup(String ticker) {
    final directory = _companiesByTicker;
    if (directory == null) {
      throw StateError('TickerDirectoryRepo.load() has not completed');
    }
    return directory[ticker.trim().toUpperCase()];
  }

  /// Every company whose symbol or name matches [query], symbol matches first
  /// so that typing `AAP` puts `AAPL` above `Advance Auto Parts`.
  ///
  /// An empty query returns the whole directory. [limit] caps the result, which
  /// a type-ahead wants and the browsable list does not.
  List<Company> search(String query, {int? limit}) {
    final needle = query.trim().toUpperCase();
    if (needle.isEmpty) return allCompanies;

    final symbolPrefix = <Company>[];
    final symbolContains = <Company>[];
    final nameContains = <Company>[];

    for (final company in _companiesByTickerOrder ?? const <Company>[]) {
      if (company.ticker.startsWith(needle)) {
        symbolPrefix.add(company);
        // Scanning in symbol order, so the first [limit] prefix matches are
        // already the best ones — nothing found later can outrank them.
        if (limit != null && symbolPrefix.length >= limit) return symbolPrefix;
      } else if (company.ticker.contains(needle)) {
        symbolContains.add(company);
      } else if (company.name.toUpperCase().contains(needle)) {
        nameContains.add(company);
      }
    }

    final ranked = [...symbolPrefix, ...symbolContains, ...nameContains];
    return limit == null ? ranked : ranked.take(limit).toList();
  }
}
