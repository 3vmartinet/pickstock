import 'dart:math' as math;

import 'package:pickstock/data/research/framework_question.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/valuation/valuation.dart';

/// How many years a chart on the framework tab spans: the framework's own
/// "three to five years", with the sixth giving the first its change.
const int evidenceYears = 6;

/// The windows the growth and margin figures are read over.
const int _shortWindow = 3;
const int _longWindow = 5;

/// What a figure is, which decides both its label and how it is written.
enum EvidenceMeasure {
  revenue,
  revenueGrowthLatest,
  revenueGrowthShort,
  revenueGrowthLong,
  grossMargin,
  operatingMargin,
  operatingMarginChange,
  impairment,
  operatingMarginBeforeImpairment,
  returnOnEquity,
  shareCountChange,
  capitalReturned,
  stockPay,
  freeCashFlow,
  cashConversion,
  netDebt,
  netCash,
  debtPayback,
  interestCover,
  price,
  fairRange,
  toRangeLow,
}

/// One figure beside an answer.
class EvidenceStat {
  const EvidenceStat(this.measure, this.value, {this.upper, this.years});

  final EvidenceMeasure measure;
  final double value;

  /// The window a change was measured over, for the figures that are one.
  final int? years;

  /// The top of a range, for the one figure that is a range.
  final double? upper;
}

/// One measure by fiscal year, oldest first.
class EvidenceSeries {
  const EvidenceSeries(this.measure, this.points);

  final EvidenceMeasure measure;
  final List<(int, double)> points;
}

/// What the filings say about one of the seven questions, before any model
/// has been asked.
///
/// The point of having it: four of the seven are questions about figures the
/// app already holds, and the answer a model writes should be read beside
/// those figures rather than taken on its word. The others get what the
/// filings can contribute — margins as evidence of a moat, capital returned
/// as evidence of management — and say nothing where they have nothing.
class FrameworkEvidence {
  const FrameworkEvidence({
    this.series = const [],
    this.stats = const [],
    this.awaitsPrice = false,
  });

  /// Charts. Two series share a chart only when they share a unit.
  final List<EvidenceSeries> series;

  final List<EvidenceStat> stats;

  /// Whether what is missing is a share price rather than anything the
  /// filings could hold — the timing question with no quote yet.
  final bool awaitsPrice;

  bool get isEmpty => series.isEmpty && stats.isEmpty;

  /// Whether the margins chart is missing gross margin because the filer
  /// does not tag it, which the card says rather than leave a line missing.
  bool get lacksGrossMargin =>
      series.isNotEmpty &&
      series.first.measure == EvidenceMeasure.operatingMargin;

  static FrameworkEvidence forQuestion(
    FrameworkQuestion question,
    FinancialSnapshot snapshot, {
    Valuation? valuation,
  }) {
    final all = snapshot.years;
    final years = all.sublist(math.max(0, all.length - evidenceYears));
    final latest = snapshot.latest;

    EvidenceSeries? seriesOf(
      EvidenceMeasure measure,
      double? Function(FiscalYearFigures) read,
    ) {
      final points = [
        for (final year in years)
          if (read(year) case final value?) (year.fiscalYear, value),
      ];
      // One point is a figure, not a trend; the stats already carry it.
      return points.length < 2 ? null : EvidenceSeries(measure, points);
    }

    EvidenceStat? statOf(EvidenceMeasure measure, double? value, {int? over}) =>
        value == null || !value.isFinite
        ? null
        : EvidenceStat(measure, value, years: over);

    return switch (question) {
      FrameworkQuestion.growth => FrameworkEvidence(
        series: [?seriesOf(EvidenceMeasure.revenue, (year) => year.revenue)],
        stats: [
          ?statOf(
            EvidenceMeasure.revenueGrowthLatest,
            latest.revenueGrowthPercent,
          ),
          ?statOf(
            EvidenceMeasure.revenueGrowthShort,
            _cagr(all, _shortWindow),
            over: _shortWindow,
          ),
          ?statOf(
            EvidenceMeasure.revenueGrowthLong,
            _cagr(all, _longWindow),
            over: _longWindow,
          ),
        ],
      ),
      FrameworkQuestion.moat => FrameworkEvidence(
        stats: [
          ?statOf(EvidenceMeasure.grossMargin, latest.grossMarginPercent),
          ?statOf(
            EvidenceMeasure.operatingMargin,
            latest.operatingMarginPercent,
          ),
          ?statOf(EvidenceMeasure.returnOnEquity, latest.returnOnEquityPercent),
        ],
      ),
      FrameworkQuestion.management => FrameworkEvidence(
        stats: [
          ?statOf(
            EvidenceMeasure.shareCountChange,
            _change(years.first.dilutedShares, latest.dilutedShares),
            over: latest.fiscalYear - years.first.fiscalYear,
          ),
          ?statOf(
            EvidenceMeasure.capitalReturned,
            latest.capitalReturnedPercent,
          ),
          ?statOf(EvidenceMeasure.stockPay, latest.stockPayShareOfCashPercent),
          ?statOf(EvidenceMeasure.returnOnEquity, latest.returnOnEquityPercent),
        ],
      ),
      FrameworkQuestion.margins => FrameworkEvidence(
        series: [
          ?seriesOf(
            EvidenceMeasure.grossMargin,
            (year) => year.grossMarginPercent,
          ),
          ?seriesOf(
            EvidenceMeasure.operatingMargin,
            (year) => year.operatingMarginPercent,
          ),
        ],
        stats: [
          // Above the change, which a write-down can make look like a
          // collapse: the reader sees the charge before the drop it caused.
          ..._writeDown(latest),
          ?statOf(
            EvidenceMeasure.operatingMarginChange,
            _marginChange(all, _shortWindow),
            over: _shortWindow,
          ),
        ],
      ),
      FrameworkQuestion.cash => FrameworkEvidence(
        series: [
          ?seriesOf(EvidenceMeasure.freeCashFlow, (year) => year.freeCashFlow),
        ],
        stats: [
          ?statOf(EvidenceMeasure.cashConversion, _conversion(latest)),
          ?_netDebtStat(latest),
        ],
      ),
      FrameworkQuestion.risk => FrameworkEvidence(
        stats: [
          ..._writeDown(latest),
          ?_netDebtStat(latest),
          ?statOf(EvidenceMeasure.debtPayback, _payback(latest)),
          ?statOf(EvidenceMeasure.interestCover, _interestCover(latest)),
        ],
      ),
      FrameworkQuestion.timing => FrameworkEvidence(
        awaitsPrice: valuation == null,
        stats: [
          if (valuation != null) ...[
            EvidenceStat(EvidenceMeasure.price, valuation.pricePerShare),
            if ((valuation.fairValueLow, valuation.fairValueHigh) case (
              final low?,
              final high?,
            ))
              EvidenceStat(EvidenceMeasure.fairRange, low, upper: high),
            ?statOf(EvidenceMeasure.toRangeLow, valuation.percentToLow),
          ],
        ],
      ),
    };
  }

  /// Compound annual revenue growth over the last [span] years, as the
  /// directory ranks it: both ends present and positive, or nothing.
  static double? _cagr(List<FiscalYearFigures> years, int span) {
    if (years.length <= span) return null;
    final end = years.last.revenue;
    final start = years[years.length - 1 - span].revenue;
    if (end == null || start == null || start <= 0 || end <= 0) return null;
    return (math.pow(end / start, 1 / span) - 1) * 100;
  }

  /// How many points operating margin has moved over the last [span] years.
  static double? _marginChange(List<FiscalYearFigures> years, int span) {
    if (years.length <= span) return null;
    final end = years.last.operatingMarginPercent;
    final start = years[years.length - 1 - span].operatingMarginPercent;
    if (end == null || start == null) return null;
    return end - start;
  }

  static double? _change(double? from, double? to) {
    if (from == null || to == null || from <= 0) return null;
    return (to - from) / from * 100;
  }

  /// Operating cash flow against net income: above 1 means the profit is
  /// arriving as cash. Meaningless against a loss, so not offered for one.
  static double? _conversion(FiscalYearFigures year) {
    final cash = year.operatingCashFlow;
    final profit = year.netIncome;
    if (cash == null || profit == null || profit <= 0) return null;
    return cash / profit;
  }

  /// The year's write-down and the margin before it, or nothing in a year
  /// that had none.
  static List<EvidenceStat> _writeDown(FiscalYearFigures year) {
    final charge = year.impairment;
    final margin = year.operatingMarginBeforeImpairmentPercent;
    if (charge == null || charge <= 0 || margin == null) return const [];
    return [
      EvidenceStat(EvidenceMeasure.impairment, charge),
      EvidenceStat(EvidenceMeasure.operatingMarginBeforeImpairment, margin),
    ];
  }

  static EvidenceStat? _netDebtStat(FiscalYearFigures year) {
    final net = year.netDebt;
    if (net == null) return null;
    return net < 0
        ? EvidenceStat(EvidenceMeasure.netCash, -net)
        : EvidenceStat(EvidenceMeasure.netDebt, net);
  }

  /// Net debt over free cash flow: how many years of spare cash would clear
  /// it. Not offered for a company holding net cash, which owes nothing on
  /// this measure, or one with no spare cash, which could never repay.
  static double? _payback(FiscalYearFigures year) {
    final net = year.netDebt;
    final cash = year.freeCashFlow;
    if (net == null || cash == null || net <= 0 || cash <= 0) return null;
    return net / cash;
  }

  static double? _interestCover(FiscalYearFigures year) {
    final profit = year.operatingIncome;
    final interest = year.interestExpense;
    if (profit == null || interest == null || interest <= 0) return null;
    return profit / interest;
  }
}
