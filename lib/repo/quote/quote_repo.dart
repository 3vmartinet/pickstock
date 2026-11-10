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
  /// Throws a [QuoteException] for every expected failure. [forJob] marks a
  /// call made by a bulk run, which is allowed through while the budget is
  /// reserved.
  Future<Quote> quoteFor(String ticker, {bool forJob = false});

  /// How long until the next call would be allowed, so a bulk run can pace
  /// itself instead of walking into a refusal.
  Duration get timeUntilSlot;

  /// Hands the whole per-minute budget to a bulk run. Interactive quotes are
  /// refused with [QuoteFailure.jobRunning] until it is released, which is
  /// what makes a long run finish in a predictable time.
  void reserveForJob();

  void releaseJob();
}
