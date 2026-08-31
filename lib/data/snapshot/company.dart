import 'package:equatable/equatable.dart';

/// A company as SEC EDGAR identifies it.
class Company extends Equatable {
  const Company({
    required this.ticker,
    required this.cik,
    required this.name,
    this.sharesOutstanding,
  });

  /// Upper-case exchange symbol, e.g. `AAPL`.
  final String ticker;

  /// Ten-digit, zero-padded Central Index Key, e.g. `0000320193`.
  final String cik;

  /// Registrant name as filed, e.g. `Apple Inc.`.
  final String name;

  /// Shares on the cover of the newest filing. Multiplied by a share price
  /// this gives a market value; `null` where none is filed.
  final double? sharesOutstanding;

  @override
  List<Object?> get props => [ticker, cik, name, sharesOutstanding];
}
