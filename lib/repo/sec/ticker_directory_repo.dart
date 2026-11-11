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
  Map<String, Company>? _primaryCompanyByCik;
  List<Company>? _uniqueCompanies;
  List<Company>? _companiesByTickerOrder;

  int _revision = 0;

  /// Incremented on every [load]. Anything holding a derived list can compare
  /// this to know whether an ingest has replaced the directory underneath it.
  int get revision => _revision;

  /// Whether [load] has run and found symbols.
  bool get isLoaded => _companiesByTicker?.isNotEmpty ?? false;

  /// How many symbols the directory knows about.
  int get tickerCount => _companiesByTicker?.length ?? 0;

  /// Every company, deduplicated by CIK so that multi-class or multi-ticker
  /// filers appear exactly once under their primary common stock symbol.
  List<Company> get allCompanies =>
      List.unmodifiable(_uniqueCompanies ?? const []);

  /// Reads the directory out of the database, replacing anything held.
  ///
  /// Safe to call again after an ingest to pick up the new rows.
  Future<void> load() async {
    final rows = await _database.allTickers();
    final companiesByTicker = <String, Company>{};
    final symbolsByCik = <String, List<String>>{};

    for (final row in rows) {
      final company = Company(
        ticker: row.symbol,
        cik: row.cik,
        name: row.name.isEmpty ? row.symbol : row.name,
      );
      companiesByTicker[row.symbol] = company;
      (symbolsByCik[row.cik] ??= []).add(row.symbol);
    }

    final primaryCompanyByCik = <String, Company>{};
    for (final entry in symbolsByCik.entries) {
      final cik = entry.key;
      final symbols = entry.value;
      final primary = primarySymbol(symbols) ?? symbols.first;
      primaryCompanyByCik[cik] = companiesByTicker[primary]!;
    }

    final uniqueCompanies = primaryCompanyByCik.values.toList()
      ..sort((a, b) => a.ticker.compareTo(b.ticker));

    _revision++;
    _companiesByTicker = companiesByTicker;
    _primaryCompanyByCik = primaryCompanyByCik;
    _uniqueCompanies = uniqueCompanies;
    // The rows arrive in SEC's order, which [primarySymbol] above depends on;
    // the search scans alphabetically so its ranking does not depend on it.
    _companiesByTickerOrder = companiesByTicker.values.toList()
      ..sort((a, b) => a.ticker.compareTo(b.ticker));
    logInfo(
      () =>
          'Loaded ${companiesByTicker.length} tickers (${uniqueCompanies.length} companies) from the database',
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

  /// The symbol to ask a price for on behalf of [company]: its filer's common
  /// stock, whichever of the filer's symbols [company] carries.
  ///
  /// A price is stored per filer, so a quote for a warrant or a preferred
  /// share would otherwise be kept as the company's share price and
  /// multiplied by its common share count. Opendoor's `OPENW` warrant was,
  /// at 3.5 cents, and the company read as 32,000% undervalued.
  ///
  /// [company]'s own symbol where the directory knows nothing better — a
  /// filer listed only once, or a company not in the directory at all.
  String quoteSymbolFor(Company company) =>
      _primaryCompanyByCik?[company.cik]?.ticker ?? company.ticker;

  /// Every company whose symbol or name matches [query], symbol matches first
  /// so that typing `AAP` puts `AAPL` above `Advance Auto Parts`.
  ///
  /// Results are deduplicated by CIK so that companies with multiple tickers
  /// appear only once. When multiple tickers for the same CIK match (or when
  /// matching by company name), the company's primary ticker is preferred.
  ///
  /// An empty query returns the whole directory. [limit] caps the result, which
  /// a type-ahead wants and the browsable list does not.
  List<Company> search(String query, {int? limit}) {
    final needle = query.trim().toUpperCase();
    if (needle.isEmpty) {
      return limit == null ? allCompanies : allCompanies.take(limit).toList();
    }

    final prefixByCik = <String, Company>{};
    final containsByCik = <String, Company>{};
    final nameByCik = <String, Company>{};

    for (final company in _companiesByTickerOrder ?? const <Company>[]) {
      final cik = company.cik;
      final primary = _primaryCompanyByCik?[cik];
      final isPrimary = primary != null && primary.ticker == company.ticker;

      if (company.ticker.startsWith(needle)) {
        if (!prefixByCik.containsKey(cik) || isPrimary) {
          prefixByCik[cik] = company;
        }
      } else if (!prefixByCik.containsKey(cik) &&
          company.ticker.contains(needle)) {
        if (!containsByCik.containsKey(cik) || isPrimary) {
          containsByCik[cik] = company;
        }
      } else if (!prefixByCik.containsKey(cik) &&
          !containsByCik.containsKey(cik) &&
          company.name.toUpperCase().contains(needle)) {
        nameByCik[cik] ??= primary ?? company;
      }
    }

    final ranked = [
      ...prefixByCik.values,
      ...containsByCik.values.where((c) => !prefixByCik.containsKey(c.cik)),
      ...nameByCik.values.where(
        (c) =>
            !prefixByCik.containsKey(c.cik) &&
            !containsByCik.containsKey(c.cik),
      ),
    ];
    return limit == null ? ranked : ranked.take(limit).toList();
  }
}

/// The primary ticker symbol for a filer among its listed [symbols].
///
/// SEC's directory often lists multiple classes of common stock, preferred
/// shares, units or warrants for a single filer (e.g. `FNMA` vs `FNMAG`,
/// `BAC` vs `BAC-PB`, `BRK-A` vs `BRK-B`).
///
/// The selection rules:
/// 1. Foreign ordinaries traded over the counter (five letters ending in F or Y,
///    such as `BEIGF`) are discarded because their price is per a share the
///    filed count does not count in.
/// 2. Suffixed symbols (`-` or `.`, such as `BAC-PB` or `BRK-B`) are skipped
///    in favor of non-suffixed common stock if available.
/// 3. If multiple non-suffixed symbols exist and one is a base prefix of
///    another (e.g. `FNMA` and `FNMAG`), the shorter base symbol is chosen.
/// 4. Otherwise, the first eligible symbol is returned.
String? primarySymbol(List<String> symbols) {
  bool isForeignOtc(String symbol) =>
      symbol.length == 5 && (symbol.endsWith('F') || symbol.endsWith('Y'));
  bool hasSuffix(String symbol) => symbol.contains('-') || symbol.contains('.');

  final usable = symbols.where((symbol) => !isForeignOtc(symbol)).toList();
  final nonSuffixed = usable.where((symbol) => !hasSuffix(symbol)).toList();
  if (nonSuffixed.isNotEmpty) {
    for (final candidate in nonSuffixed) {
      if (nonSuffixed.any(
        (other) => other != candidate && other.startsWith(candidate),
      )) {
        return candidate;
      }
    }
    return nonSuffixed.first;
  }
  return usable.firstOrNull;
}
