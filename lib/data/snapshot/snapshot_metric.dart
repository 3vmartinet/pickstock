import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The four headline figures shown for the most recent fiscal year.
///
/// Each case knows how to pull its own value out of a [FiscalYearFigures] and
/// whether that value reads as good or bad news, so the card widget stays a
/// pure renderer.
enum SnapshotMetric {
  revenue(icon: LucideIcons.chartLine),
  netIncome(icon: LucideIcons.banknote),
  freeCashFlow(icon: LucideIcons.coins),
  netCashPosition(icon: LucideIcons.scale);

  const SnapshotMetric({required this.icon});

  final IconData icon;

  String getLabel(AppLocalizations strings) => switch (this) {
    SnapshotMetric.revenue => strings.labelRevenue,
    SnapshotMetric.netIncome => strings.labelNetIncome,
    SnapshotMetric.freeCashFlow => strings.labelFreeCashFlow,
    SnapshotMetric.netCashPosition => strings.labelNetDebt,
  };

  String getHint(AppLocalizations strings) => switch (this) {
    SnapshotMetric.revenue => strings.hintRevenue,
    SnapshotMetric.netIncome => strings.hintNetIncome,
    SnapshotMetric.freeCashFlow => strings.hintFreeCashFlow,
    SnapshotMetric.netCashPosition => strings.hintNetDebt,
  };

  /// A short word placed under the figure where the number's sign alone would
  /// not say what it means. Only the balance-sheet metric needs one.
  String? getQualifier(AppLocalizations strings, FiscalYearFigures figures) {
    if (this != SnapshotMetric.netCashPosition) return null;
    final netDebt = figures.netDebt;
    if (netDebt == null) return null;
    return netDebt < 0
        ? strings.labelNetCashPosition
        : strings.labelNetDebtPosition;
  }

  /// Whether the headline figure should be shown without its sign, because a
  /// [getQualifier] already says which side of zero it is on.
  bool get showsMagnitudeOnly => this == SnapshotMetric.netCashPosition;

  double? getValue(FiscalYearFigures figures) => switch (this) {
    SnapshotMetric.revenue => figures.revenue,
    SnapshotMetric.netIncome => figures.netIncome,
    SnapshotMetric.freeCashFlow => figures.freeCashFlow,
    SnapshotMetric.netCashPosition => figures.netDebt,
  };

  /// Whether the metric's own sign is good news, or `null` when it is not
  /// reported. Net debt is the odd one out: less than zero is the good side.
  bool? getSentiment(FiscalYearFigures figures) {
    final value = getValue(figures);
    if (value == null) return null;
    return this == SnapshotMetric.netCashPosition ? value < 0 : value >= 0;
  }

  /// Growth against the prior fiscal year, where a prior year is on file.
  double? getChangePercent(
    FiscalYearFigures figures,
    FiscalYearFigures? previous,
  ) {
    final current = getValue(figures);
    final before = previous == null ? null : getValue(previous);
    if (current == null || before == null || before == 0) return null;
    return (current - before) / before.abs() * 100;
  }
}
