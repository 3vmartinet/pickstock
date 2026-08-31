import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/snapshot/period_figures.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();

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

  /// The card's heading.
  ///
  /// The balance-sheet card names its own side of zero — `Net cash` or `Net
  /// debt` — because a bare amount under a heading of `Net debt / (cash)` read
  /// identically whether the company was owed money or owed it.
  String getLabel(AppLocalizations strings, PeriodFigures figures) =>
      switch (this) {
        SnapshotMetric.revenue => strings.labelRevenue,
        SnapshotMetric.netIncome => strings.labelNetIncome,
        SnapshotMetric.freeCashFlow => strings.labelFreeCashFlow,
        SnapshotMetric.netCashPosition => switch (figures.netDebt) {
          final debt? when debt < 0 => strings.labelNetCashPosition,
          _ => strings.labelNetDebtPosition,
        },
      };

  String getHint(AppLocalizations strings) => switch (this) {
    SnapshotMetric.revenue => strings.hintRevenue,
    SnapshotMetric.netIncome => strings.hintNetIncome,
    SnapshotMetric.freeCashFlow => strings.hintFreeCashFlow,
    SnapshotMetric.netCashPosition => strings.hintNetDebt,
  };

  /// Where the prior year stood, for the balance-sheet card.
  ///
  /// A percentage change is meaningless on a figure that crosses zero — net
  /// debt turning into net cash is not "−140% growth" — so the comparison is
  /// stated in words instead.
  String? getPriorPosition(AppLocalizations strings, PeriodFigures? previous) {
    if (this != SnapshotMetric.netCashPosition) return null;
    final netDebt = previous?.netDebt;
    if (netDebt == null) return null;

    final amount = _formatRepo.compactCurrencyMagnitude(netDebt);
    return netDebt < 0
        ? strings.priorNetCash(amount)
        : strings.priorNetDebt(amount);
  }

  /// Whether the headline figure is shown without its sign, because
  /// [getLabel] already names which side of zero it is on.
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
