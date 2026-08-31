import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/extensions/object_extensions.dart';
import 'package:pickstock/repo/db/app_database.dart';

AppDatabase get _database => GetIt.I.get<AppDatabase>();

/// Maps ticker symbols to the SEC filers behind them.
///
/// Loaded from the database once per session and held in memory: filtering ten
/// thousand symbols as the user types is a map read rather than a query per
/// keystroke. The rows themselves are written by the bulk ingest — nothing is
/// bundled with the app, so the list is as current as the last ingest.
class TickerDirectoryRepo {
  Map<String, Company>? _companiesByTicker;
  List<Company>? _companiesByTickerOrder;

  int _revision = 0;

  /// Incremented on every [load]. Anything holding a derived list can compare
  /// this to know whether an ingest has replaced the directory underneath it.
  int get revision => _revision;

  /// Whether [load] has run and found symbols.
  bool get isLoaded => _companiesByTicker?.isNotEmpty ?? false;

  /// How many symbols the directory knows about.
  int get tickerCount => _companiesByTicker?.length ?? 0;

  /// Every symbol, alphabetically. Sorted by the database, not here.
  List<Company> get allCompanies =>
      List.unmodifiable(_companiesByTickerOrder ?? const []);

  /// Reads the directory out of the database, replacing anything held.
  ///
  /// Safe to call again after an ingest to pick up the new rows.
  Future<void> load() async {
    final rows = await _database.allTickers();
    final companiesByTicker = {
      for (final row in rows)
        row.symbol: Company(
          ticker: row.symbol,
          cik: row.cik,
          name: row.name.isEmpty ? row.symbol : row.name,
        ),
    };

    _revision++;
    _companiesByTicker = companiesByTicker;
    _companiesByTickerOrder = [
      for (final row in rows) companiesByTicker[row.symbol]!,
    ];
    logInfo(
      () => 'Loaded ${companiesByTicker.length} tickers from the database',
    );
  }

  /// The filer trading under [ticker], or `null` if no such symbol is known.
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
