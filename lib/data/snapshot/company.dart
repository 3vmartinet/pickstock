import 'package:equatable/equatable.dart';

/// A company as SEC EDGAR identifies it.
class Company extends Equatable {
  const Company({
    required this.ticker,
    required this.cik,
    required this.name,
    this.sic,
    this.sharesOutstanding,
  });

  /// Upper-case exchange symbol, e.g. `AAPL`.
  final String ticker;

  /// Ten-digit, zero-padded Central Index Key, e.g. `0000320193`.
  final String cik;

  /// Registrant name as filed, e.g. `Apple Inc.`.
  final String name;

  /// Standard Industrial Classification code, e.g. `3571`. `null` where no
  /// data set covering the company was found.
  final int? sic;

  /// Shares on the cover of the newest filing. Multiplied by a share price
  /// this gives a market value; `null` where none is filed.
  final double? sharesOutstanding;

  @override
  List<Object?> get props => [ticker, cik, name, sic, sharesOutstanding];
}
