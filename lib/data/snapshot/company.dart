import 'package:equatable/equatable.dart';

/// A company as SEC EDGAR identifies it.
class Company extends Equatable {
  const Company({required this.ticker, required this.cik, required this.name});

  /// Upper-case exchange symbol, e.g. `AAPL`.
  final String ticker;

  /// Ten-digit, zero-padded Central Index Key, e.g. `0000320193`.
  final String cik;

  /// Registrant name as filed, e.g. `Apple Inc.`.
  final String name;

  @override
  List<Object?> get props => [ticker, cik, name];
}
