import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/l10n/app_localizations.dart';

/// Reads company financials from a filings source.
abstract interface class SecRepo {
  /// Builds a snapshot for [ticker], newest fiscal year last.
  ///
  /// Throws a [SecException] for every expected failure; anything else is a
  /// bug and is allowed to propagate.
  Future<FinancialSnapshot> fetchSnapshot(String ticker);
}

/// The ways a snapshot can fail to be built, each able to explain itself.
enum SecFailure {
  unknownTicker,
  noAnnualData,
  network,
  databaseEmpty,
  service;

  String describe(AppLocalizations strings, String ticker) => switch (this) {
    SecFailure.unknownTicker => strings.errorUnknownTicker(ticker),
    SecFailure.noAnnualData => strings.errorNoAnnualData(ticker),
    SecFailure.network => strings.errorNetwork,
    SecFailure.databaseEmpty => strings.errorDatabaseEmpty,
    SecFailure.service => strings.errorService,
  };
}

/// An expected failure while building a snapshot.
class SecException implements Exception {
  const SecException(this.failure, {this.cause});

  final SecFailure failure;
  final Object? cause;

  @override
  String toString() => 'SecException(${failure.name}, cause: $cause)';
}
