import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/repo/format_repo.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();

/// One column of the three-year history table.
///
/// The column owns its heading, its alignment and how a year's figure turns
/// into text, so adding a line item is a single enum case rather than an edit
/// to every row-building widget.
enum HistoryColumn {
  fiscalYear(isNumeric: false),
  revenue(),
  revenueGrowth(),
  netIncome(),
  freeCashFlow(),
  totalDebt(),
  cash(),
  netCashPosition();

  const HistoryColumn({this.isNumeric = true});

  /// Numeric columns are right-aligned so digits line up down the column.
  final bool isNumeric;

  String getHeading(AppLocalizations strings) => switch (this) {
    HistoryColumn.fiscalYear => strings.labelYear,
    HistoryColumn.revenue => strings.labelRevenue,
    HistoryColumn.revenueGrowth => strings.labelRevenueGrowth,
    HistoryColumn.netIncome => strings.labelNetIncome,
    HistoryColumn.freeCashFlow => strings.labelFreeCashFlow,
    HistoryColumn.totalDebt => strings.labelTotalDebt,
    HistoryColumn.cash => strings.labelCash,
    HistoryColumn.netCashPosition => strings.labelNetDebt,
  };

  String getCellText(AppLocalizations strings, FiscalYearFigures figures) =>
      switch (this) {
        HistoryColumn.fiscalYear =>
          '${strings.labelFiscalYear}${figures.fiscalYear}',
        HistoryColumn.revenueGrowth => _percentOrDash(
          strings,
          figures.revenueGrowthPercent,
        ),
        // Net debt is the one line where the accounting convention matters:
        // a parenthesised figure is a net cash position.
        HistoryColumn.netCashPosition => _millionsOrDash(
          strings,
          figures.netDebt,
          parenthesiseNegatives: true,
        ),
        _ => _millionsOrDash(strings, _dollarValue(figures)),
      };

  /// Whether this cell's value is good news, `false` for bad, `null` when the
  /// column carries no sentiment or the figure is missing.
  bool? getSentiment(FiscalYearFigures figures) => switch (this) {
    HistoryColumn.revenueGrowth => _sentimentOf(
      figures.revenueGrowthPercent,
      positiveIsGood: true,
    ),
    HistoryColumn.netIncome => _sentimentOf(
      figures.netIncome,
      positiveIsGood: true,
    ),
    HistoryColumn.netCashPosition => _sentimentOf(
      figures.netDebt,
      positiveIsGood: false,
    ),
    _ => null,
  };

  double? _dollarValue(FiscalYearFigures figures) => switch (this) {
    HistoryColumn.revenue => figures.revenue,
    HistoryColumn.netIncome => figures.netIncome,
    HistoryColumn.freeCashFlow => figures.freeCashFlow,
    HistoryColumn.totalDebt => figures.totalDebt,
    HistoryColumn.cash => figures.cash,
    _ => null,
  };

  static bool? _sentimentOf(double? value, {required bool positiveIsGood}) {
    if (value == null) return null;
    return positiveIsGood ? value >= 0 : value < 0;
  }

  static String _millionsOrDash(
    AppLocalizations strings,
    double? dollars, {
    bool parenthesiseNegatives = false,
  }) {
    if (dollars == null) return strings.verdictUnknown;
    return parenthesiseNegatives
        ? _formatRepo.parenthesisedMillions(dollars)
        : _formatRepo.millions(dollars);
  }

  static String _percentOrDash(AppLocalizations strings, double? percent) =>
      percent == null
      ? strings.verdictUnknown
      : _formatRepo.signedPercent(percent);
}
