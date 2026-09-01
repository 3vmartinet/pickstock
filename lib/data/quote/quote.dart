import 'package:equatable/equatable.dart';
import 'package:pickstock/l10n/app_localizations.dart';

/// A share price, and where it came from.
class Quote extends Equatable {
  const Quote({
    required this.pricePerShare,
    required this.asOf,
    required this.isQuoted,
  });

  /// A price the user typed, with no market timestamp behind it.
  Quote.entered(this.pricePerShare) : asOf = DateTime.now(), isQuoted = false;

  final double pricePerShare;

  /// When the price was true: the exchange's own timestamp for a quote, or
  /// when it was typed for an entered one.
  final DateTime asOf;

  /// Whether a provider quoted this, as opposed to the user entering it. The
  /// report says which, because a stale quote and a typed guess should not
  /// look alike.
  final bool isQuoted;

  Quote copyWith({double? pricePerShare}) => Quote(
    pricePerShare: pricePerShare ?? this.pricePerShare,
    asOf: asOf,
    isQuoted: isQuoted,
  );

  @override
  List<Object?> get props => [pricePerShare, asOf, isQuoted];
}

/// The ways a quote can fail to arrive, each of which the UI states plainly
/// rather than pretending the price is simply missing.
enum QuoteFailure {
  /// No API key was built in, which is the default and not an error.
  notConfigured,

  /// The provider has no price for this symbol — delisted, OTC, or never
  /// covered. Finnhub answers these with a price of zero.
  noCoverage,

  /// The per-minute budget is spent.
  rateLimited,

  network,

  /// The provider accepted the connection and then said nothing.
  timedOut,

  /// A bulk run holds the per-minute budget.
  jobRunning,

  service;

  String describe(AppLocalizations strings) => switch (this) {
    QuoteFailure.notConfigured => strings.quoteNotConfigured,
    QuoteFailure.noCoverage => strings.quoteNoCoverage,
    QuoteFailure.rateLimited => strings.quoteRateLimited,
    QuoteFailure.network => strings.quoteNetwork,
    QuoteFailure.timedOut => strings.quoteTimedOut,
    QuoteFailure.jobRunning => strings.quoteJobRunning,
    QuoteFailure.service => strings.quoteService,
  };
}

class QuoteException implements Exception {
  const QuoteException(this.failure, {this.cause});

  final QuoteFailure failure;
  final Object? cause;

  @override
  String toString() => 'QuoteException(${failure.name}, cause: $cause)';
}
