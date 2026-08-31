import 'package:get_it/get_it.dart';
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/repo/db/app_database.dart';

AppDatabase get _database => GetIt.I.get<AppDatabase>();

/// Remembers the last share price known for a company, however it was found.
///
/// A stored price is what makes the report work with the network down and
/// without a key: a quote fetched today is still the last thing PickStock knew
/// tomorrow, and it says so rather than pretending to be live.
abstract interface class PriceRepo {
  /// The last price known for [cik], or `null` if none is.
  Future<Quote?> priceFor(String cik);

  Future<void> save(String cik, Quote quote);

  Future<void> clear(String cik);
}

class LocalPriceRepo implements PriceRepo {
  const LocalPriceRepo();

  @override
  Future<Quote?> priceFor(String cik) async {
    final row = await _database.priceFor(cik);
    if (row == null) return null;
    return Quote(
      pricePerShare: row.pricePerShare,
      asOf: row.asOf,
      isQuoted: row.isQuoted,
    );
  }

  @override
  Future<void> save(String cik, Quote quote) => _database.savePrice(
    cik,
    pricePerShare: quote.pricePerShare,
    asOf: quote.asOf,
    isQuoted: quote.isQuoted,
  );

  @override
  Future<void> clear(String cik) => _database.clearPrice(cik);
}

/// Holds prices for the run only, for the mock-data build and for tests that
/// have no database.
class MemoryPriceRepo implements PriceRepo {
  final Map<String, Quote> _prices = {};

  @override
  Future<Quote?> priceFor(String cik) async => _prices[cik];

  @override
  Future<void> save(String cik, Quote quote) async => _prices[cik] = quote;

  @override
  Future<void> clear(String cik) async => _prices.remove(cik);
}
