import 'package:equatable/equatable.dart';

/// One undervalued company as a finished run found it.
class ReportEntry extends Equatable {
  const ReportEntry({
    required this.cik,
    required this.ticker,
    required this.name,
    required this.pricePerShare,
    required this.fairValueLow,
    required this.fairValueHigh,
    required this.upsidePercent,
  });

  final String cik;
  final String ticker;
  final String name;

  /// What the share cost when the run priced it. Copied rather than looked up
  /// again: a report is a record of a moment, and prices move.
  final double pricePerShare;

  final double fairValueLow;
  final double fairValueHigh;

  /// How far the price would have to rise to reach the bottom of the range.
  final double upsidePercent;

  @override
  List<Object?> get props => [cik, ticker, pricePerShare, upsidePercent];
}

/// A finished run: what it looked at, and what it found.
class ValuationReport extends Equatable {
  const ValuationReport({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.consideredCount,
    required this.valuedCount,
    this.entries = const [],
  });

  final int id;
  final String name;
  final DateTime createdAt;

  /// How many companies were in the filter when the run started.
  final int consideredCount;

  /// How many of them could be valued at all. The rest had no share count, no
  /// revenue, or no positive cash stream — the same bar the valuation tab uses.
  final int valuedCount;

  /// The undervalued ones, most upside first. Empty until loaded.
  final List<ReportEntry> entries;

  ValuationReport withEntries(List<ReportEntry> loaded) => ValuationReport(
    id: id,
    name: name,
    createdAt: createdAt,
    consideredCount: consideredCount,
    valuedCount: valuedCount,
    entries: loaded,
  );

  @override
  List<Object?> get props => [id, name, createdAt, valuedCount, entries];
}
