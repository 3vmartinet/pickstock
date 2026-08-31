import 'package:pickstock/data/quote/quote.dart';

/// Fetches a live share price for a symbol.
///
/// EDGAR files statements, not prices, so this is the one part of PickStock
/// that talks to a commercial provider — and the only part that needs a key.
abstract interface class QuoteRepo {
  /// Whether a key was built in. Without one the app behaves exactly as it did
  /// before quotes existed: the price is typed in.
  bool get isConfigured;

  /// The current price for [ticker], as EDGAR spells the symbol.
  ///
  /// Throws a [QuoteException] for every expected failure.
  Future<Quote> quoteFor(String ticker);
}
