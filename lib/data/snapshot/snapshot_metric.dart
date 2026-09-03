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

  /// Where the prior year stood, for the balance-sheet card, and whether
  /// getting from there to here was good news.
  ///
  /// Stated in words rather than as a percentage, because a percentage on
  /// this figure is worse than useless. Net debt turning into net cash is not
  /// "−140% growth"; and net cash merely shrinking — Adobe's $2.26B down to
  /// $385M — is a *rise* in net debt of 83%, which the other cards' colouring
  /// would paint green.
  ///
  /// The direction is in the words for the same reason: the amount is shown
  /// unsigned under a heading that names its side of zero, so on its own it
  /// says nothing about which way the year went.
  ({String text, bool? isGood})? getPriorPosition(
    AppLocalizations strings,
    PeriodFigures figures,
    PeriodFigures? previous,
  ) {
    if (this != SnapshotMetric.netCashPosition) return null;
    final before = previous?.netDebt;
    final now = figures.netDebt;
    if (before == null || now == null) return null;

    final amount = _formatRepo.compactCurrencyMagnitude(before);
    // Owing less, or holding more: either way the position improved.
    final isGood = now == before ? null : now < before;

    // Crossing zero renames the card, which is the whole story — "down from
    // net debt" under a heading of Net cash would compare two different
    // quantities.
    final heldCashBefore = before < 0;
    if (heldCashBefore != (now < 0) || isGood == null) {
      return (
        text: heldCashBefore
            ? strings.priorNetCash(amount)
            : strings.priorNetDebt(amount),
        isGood: isGood,
      );
    }

    // Same side of zero, so it is the named quantity's own size that moved.
    final grew = now.abs() > before.abs();
    return (
      text: heldCashBefore
          ? (grew
                ? strings.priorNetCashUp(amount)
                : strings.priorNetCashDown(amount))
          : (grew
                ? strings.priorNetDebtUp(amount)
                : strings.priorNetDebtDown(amount)),
      isGood: isGood,
    );
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
