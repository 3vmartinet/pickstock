import 'package:get_it/get_it.dart';
import 'package:pickstock/data/report/valuation_report.dart';
import 'package:pickstock/repo/db/app_database.dart';

AppDatabase get _database => GetIt.I.get<AppDatabase>();

/// Stores and reads finished valuation runs.
abstract interface class ReportRepo {
  /// Every saved report, newest first, without their entries.
  Future<List<ValuationReport>> all();

  /// One report with its companies loaded.
  Future<ValuationReport?> withEntries(int id);

  Future<int> save({
    required String name,
    required int consideredCount,
    required int valuedCount,
    required List<ReportEntry> entries,
  });

  Future<void> rename(int id, String name);

  Future<void> delete(int id);
}

class LocalReportRepo implements ReportRepo {
  const LocalReportRepo();

  @override
  Future<List<ValuationReport>> all() async => [
    for (final row in await _database.allReports()) _reportOf(row),
  ];

  @override
  Future<ValuationReport?> withEntries(int id) async {
    final report = (await _database.allReports())
        .where((row) => row.id == id)
        .firstOrNull;
    if (report == null) return null;

    final rows = await _database.entriesForReport(id);
    return _reportOf(report).withEntries([
      for (final row in rows)
        ReportEntry(
          cik: row.cik,
          ticker: row.ticker,
          name: row.name,
          pricePerShare: row.pricePerShare,
          fairValueLow: row.fairValueLow,
          fairValueHigh: row.fairValueHigh,
          upsidePercent: row.upsidePercent,
        ),
    ]);
  }

  @override
  Future<int> save({
    required String name,
    required int consideredCount,
    required int valuedCount,
    required List<ReportEntry> entries,
  }) {
    return _database.saveReport(
      name: name,
      consideredCount: consideredCount,
      valuedCount: valuedCount,
      entries: [
        for (final entry in entries)
          ReportEntriesCompanion.insert(
            // Overwritten by the insert, which knows the report's own id.
            reportId: 0,
            cik: entry.cik,
            ticker: entry.ticker,
            name: entry.name,
            pricePerShare: entry.pricePerShare,
            fairValueLow: entry.fairValueLow,
            fairValueHigh: entry.fairValueHigh,
            upsidePercent: entry.upsidePercent,
          ),
      ],
    );
  }

  @override
  Future<void> rename(int id, String name) =>
      _database.renameReport(id, name.trim());

  @override
  Future<void> delete(int id) => _database.deleteReport(id);

  static ValuationReport _reportOf(ReportRow row) => ValuationReport(
    id: row.id,
    name: row.name,
    createdAt: row.createdAt,
    consideredCount: row.consideredCount,
    valuedCount: row.valuedCount,
  );
}
