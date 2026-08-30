import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();

/// The answer to one sanity check, and how it should read.
enum SanityVerdict {
  pass(icon: LucideIcons.circleCheck, isGood: true),
  fail(icon: LucideIcons.circleX, isGood: false),
  unknown(icon: LucideIcons.circleMinus, isGood: null);

  const SanityVerdict({required this.icon, required this.isGood});

  final IconData icon;

  /// `null` where the filings simply do not say.
  final bool? isGood;

  String getLabel(AppLocalizations strings) => switch (this) {
    SanityVerdict.pass => strings.verdictYes,
    SanityVerdict.fail => strings.verdictNo,
    SanityVerdict.unknown => strings.verdictUnknown,
  };
}

/// The three questions PickStock answers about the most recent fiscal year.
///
/// Each case owns its own question, verdict and one-line justification, so the
/// UI renders the list without knowing what any of them mean.
enum SanityCheck {
  revenueGrowth(icon: LucideIcons.trendingUp),
  profitability(icon: LucideIcons.banknote),
  balanceSheet(icon: LucideIcons.landmark);

  const SanityCheck({required this.icon});

  final IconData icon;

  String getQuestion(AppLocalizations strings) => switch (this) {
    SanityCheck.revenueGrowth => strings.checkRevenueGrowth,
    SanityCheck.profitability => strings.checkProfitable,
    SanityCheck.balanceSheet => strings.checkNetCash,
  };

  SanityVerdict getVerdict(FiscalYearFigures figures) => switch (this) {
    SanityCheck.revenueGrowth => _verdictOf(
      figures.revenueGrowthPercent,
      (growth) => growth >= 0,
    ),
    SanityCheck.profitability => _verdictOf(
      figures.netIncome,
      (income) => income >= 0,
    ),
    SanityCheck.balanceSheet => _verdictOf(
      figures.netDebt,
      (netDebt) => netDebt < 0,
    ),
  };

  String getDetail(AppLocalizations strings, FiscalYearFigures figures) =>
      switch (this) {
        SanityCheck.revenueGrowth => _describeRevenue(strings, figures),
        SanityCheck.profitability => _describeProfit(strings, figures),
        SanityCheck.balanceSheet => _describeBalanceSheet(strings, figures),
      };

  static SanityVerdict _verdictOf(double? value, bool Function(double) isGood) {
    if (value == null) return SanityVerdict.unknown;
    return isGood(value) ? SanityVerdict.pass : SanityVerdict.fail;
  }

  static String _describeRevenue(
    AppLocalizations strings,
    FiscalYearFigures figures,
  ) {
    final growth = figures.revenueGrowthPercent;
    if (growth == null) return strings.detailNotEnoughHistory;
    final percent = _formatRepo.signedPercent(growth);
    return growth >= 0
        ? strings.detailRevenueGrowing(percent)
        : strings.detailRevenueShrinking(percent);
  }

  static String _describeProfit(
    AppLocalizations strings,
    FiscalYearFigures figures,
  ) {
    final netIncome = figures.netIncome;
    if (netIncome == null) return strings.detailUnavailable;
    final amount = _formatRepo.compactCurrencyMagnitude(netIncome);
    return netIncome >= 0
        ? strings.detailProfitable(amount)
        : strings.detailUnprofitable(amount);
  }

  static String _describeBalanceSheet(
    AppLocalizations strings,
    FiscalYearFigures figures,
  ) {
    final netDebt = figures.netDebt;
    if (netDebt == null) return strings.detailUnavailable;
    final amount = _formatRepo.compactCurrencyMagnitude(netDebt);
    return netDebt < 0
        ? strings.detailNetCash(amount)
        : strings.detailNetDebt(amount);
  }
}
