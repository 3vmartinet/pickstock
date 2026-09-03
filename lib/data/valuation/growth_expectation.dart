import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/snapshot/growth_metric.dart';
import 'package:pickstock/data/valuation/cash_flow_model.dart';
import 'package:pickstock/data/valuation/price_target.dart';

/// How the growth a price requires compares with the growth a company has
/// actually produced.
enum ExpectationVerdict {
  /// The price asks for less than the company has delivered. Either the market
  /// doubts the record repeats, or it has not noticed it.
  belowRecord,

  /// The price asks for roughly what the company has delivered.
  inLineWithRecord,

  /// The price asks for more than the company has ever delivered, at every
  /// discount rate worth considering.
  beyondRecord,

  /// Not enough history, or no cash flow to discount.
  unknown,
}

/// How many years of history the record is read over, longest first: a decade
/// is the fairest test, but a company that has only been filing five years
/// still has a record worth measuring.
const List<int> _recordWindows = [10, 5, 3];

/// The band within which required and delivered growth count as the same. Two
/// points either way is well inside the precision of any of these inputs.
const double _inLineTolerance = 2;

/// A margin this many points below its own median is a slide, not noise.
const double _marginErosionPoints = 3;

/// Capital spending this many times depreciation is building, not maintaining.
const double _buildingCapexRatio = 1.5;

/// What the market's price is asking of a company, set against what the
/// company has done.
///
/// This is the honest form of "is it undervalued". A fair value depends
/// entirely on assumed growth and an assumed discount rate, so quoting one
/// number hides the assumptions inside it. Turning the question round — taking
/// the price as given and reporting the growth it requires — moves the guess
/// out of PickStock and into the market, leaving a claim that the filings can
/// actually be used to judge.
class GrowthExpectation extends Equatable {
  const GrowthExpectation._({
    required this.normalisedCashFlow,
    required this.medianCashFlowMargin,
    required this.reportedCashFlow,
    required this.marketCap,
    required this.deliveredGrowthPercent,
    required this.deliveredOverYears,
    required this.operatingMarginPercent,
    required this.marginChangePoints,
    required this.growthRatesOnFile,
  });

  /// Builds the comparison, or `null` where the company cannot support one.
  static GrowthExpectation? of(FinancialSnapshot snapshot, double marketCap) {
    if (marketCap <= 0) return null;
    final normalised = _normalisedCashFlow(snapshot);
    if (normalised == null) return null;

    final record = _delivered(snapshot);
    final margin = _marginTrend(snapshot);
    return GrowthExpectation._(
      normalisedCashFlow: normalised.flow,
      medianCashFlowMargin: normalised.margin,
      reportedCashFlow: snapshot.latest.freeCashFlow,
      marketCap: marketCap,
      deliveredGrowthPercent: record?.growth,
      deliveredOverYears: record?.years,
      operatingMarginPercent: margin?.latest,
      marginChangePoints: margin?.change,
      growthRatesOnFile: _growthRates(snapshot, record?.years),
    );
  }

  /// The cash flow the model discounts: this company's own typical cash
  /// conversion applied to what it sells today.
  ///
  /// A single year is a poor base. Microsoft spent 63% of its operating cash
  /// flow on capital projects in FY2026 and Coca-Cola paid a one-off tax
  /// deposit in 2025, which halved each company's reported free cash flow
  /// without changing what the business ordinarily throws off.
  final double normalisedCashFlow;

  /// The median free cash flow margin the normalised figure is built from.
  final double medianCashFlowMargin;

  /// The latest year as filed, kept so the report can show what was normalised
  /// away.
  final double? reportedCashFlow;

  final double marketCap;

  /// Annualised revenue growth over the longest window on file.
  ///
  /// Revenue rather than free cash flow: it is the line least distorted by
  /// capital cycles and one-off tax events, and a filer that reports anything
  /// reports this.
  final double? deliveredGrowthPercent;

  /// How many years that record covers.
  final int? deliveredOverYears;

  /// The latest operating margin.
  final double? operatingMarginPercent;

  /// How far that margin sits from the median of the record window, in
  /// percentage points.
  ///
  /// Revenue growth alone cannot tell bought growth from earned growth: a
  /// company can compound sales for a decade while its margin drains away.
  /// This is the check on the record the verdict leans on.
  final double? marginChangePoints;

  /// Every year-on-year revenue change inside the record window, smallest
  /// first.
  ///
  /// Each year's own growth, which is the figure the report prints beside its
  /// revenue — so the targets and the history above them are read off one set
  /// of numbers rather than two.
  final List<double> growthRatesOnFile;

  /// Whether growth has come at the cost of profitability, by enough to be
  /// worth saying out loud.
  bool get isMarginEroding =>
      (marginChangePoints ?? 0) <= -_marginErosionPoints;

  /// Whether the company is spending well beyond what wears out — which is why
  /// its reported cash flow may understate the business.
  bool isBuildingCapacity(FiscalYearFigures latest) =>
      (latest.capexToDepreciation ?? 0) >= _buildingCapexRatio;

  /// How far the reported year sits from the normalised base, as a percentage.
  double? get normalisationEffectPercent {
    final reported = reportedCashFlow;
    if (reported == null || normalisedCashFlow <= 0) return null;
    return (reported - normalisedCashFlow) / normalisedCashFlow * 100;
  }

  /// The growth the current price requires, at [rate].
  double? requiredGrowthPercentAt(double rate) {
    final growth = CashFlowModel.impliedGrowth(
      normalisedCashFlow,
      target: marketCap,
      discountRate: rate,
    );
    return growth == null ? null : growth * 100;
  }

  /// The growth the price requires at the default discount rate.
  double? get requiredGrowthPercent =>
      requiredGrowthPercentAt(CashFlowModel.defaultDiscountRate);

  /// The required growth across the whole discount band, lowest rate first.
  ///
  /// Shown rather than hidden because the figure moves a long way across it —
  /// Microsoft needs 13% at a 7% required return and 30% at 11% — and a reader
  /// who cannot see that would take one number far too seriously.
  List<({double rate, double? growthPercent})> get sensitivity => [
    for (final rate in CashFlowModel.discountRates)
      (rate: rate, growthPercent: requiredGrowthPercentAt(rate)),
  ];

  /// What a share is worth if the company merely repeats its record, across
  /// the discount band. Empty where there is no record to repeat.
  List<({double rate, double value})> equityValues(double shares) {
    final delivered = deliveredGrowthPercent;
    if (delivered == null || shares <= 0) return const [];
    // Credited only so far: a decade at 45% is not a forecast, it is a wish.
    final growth = math.min(
      delivered / 100,
      CashFlowModel.maximumCreditedGrowth,
    );
    return [
      for (final rate in CashFlowModel.discountRates)
        (
          rate: rate,
          value:
              CashFlowModel.presentValue(
                normalisedCashFlow,
                growth: growth,
                discountRate: rate,
              ) /
              shares,
        ),
    ];
  }

  /// What a share is worth under each reading of the company's own record.
  ///
  /// One discounted cash flow, run three times: the worst year the company has
  /// had, its middle year, and its best.
  ///
  /// The ends are the actual worst and best years rather than quartiles.
  /// Quartiles kept the middle honest but left nothing at the edges: Adobe
  /// grew 10.2, 10.5, 10.8, 11.5 and 22.7 per cent, and its upper quartile is
  /// 11.5 — so its best year was thrown away and bear, neutral and bull landed
  /// within a point of each other, which is three ways of saying one thing.
  /// The extremes are what a bull and a bear case are for; the caps in
  /// [_targetAt] keep them from becoming fiction, and the middle is still the
  /// median, so the neutral case is unmoved by either end. Held at one discount rate, because
  /// bundling a pessimistic return into the bear case and an optimistic one
  /// into the bull compounds two guesses into a spread so wide it says
  /// nothing — the rate's own effect is reported separately, across the band.
  ///
  /// Empty where the filings carry too little to read a record from.
  List<PriceTarget> priceTargets(
    double shares, {
    double discountRate = CashFlowModel.defaultDiscountRate,
  }) {
    if (shares <= 0) return const [];
    final rates = growthRatesOnFile;
    if (rates.isEmpty) return const [];

    return [
      for (final (scenario, rate) in [
        (PriceCase.bear, rates.first),
        (PriceCase.neutral, _median(rates)),
        (PriceCase.bull, rates.last),
      ])
        _targetAt(scenario, rate, shares, discountRate),
    ];
  }

  PriceTarget _targetAt(
    PriceCase scenario,
    double growthPercent,
    double shares,
    double discountRate,
  ) {
    // Credited only so far in either direction: a decade at 45% is a wish,
    // and a decade at -40% is a liquidation rather than a business.
    final growth = math.max(
      math.min(growthPercent / 100, CashFlowModel.maximumCreditedGrowth),
      CashFlowModel.minimumCreditedGrowth,
    );
    return PriceTarget(
      scenario: scenario,
      growthPercent: growth * 100,
      valuePerShare:
          CashFlowModel.presentValue(
            normalisedCashFlow,
            growth: growth,
            discountRate: discountRate,
          ) /
          shares,
    );
  }

  /// The middle of [sorted], averaging the two middle years where there is an
  /// even number of them.
  static double _median(List<double> sorted) {
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }

  /// Whether the price asks for less, about the same, or more than the record.
  ///
  /// Judged on the most generous discount rate in the band. If even a buyer
  /// content with a 7% return needs growth beyond anything the company has
  /// managed, the price is demanding on any reading — which is a conclusion
  /// that survives the assumption, unlike the rate-specific number itself.
  ExpectationVerdict get verdict {
    final delivered = deliveredGrowthPercent;
    final generous = requiredGrowthPercentAt(CashFlowModel.discountRates.first);
    if (delivered == null || generous == null) {
      return ExpectationVerdict.unknown;
    }

    if (generous > delivered + _inLineTolerance) {
      return ExpectationVerdict.beyondRecord;
    }
    final demanding = requiredGrowthPercentAt(CashFlowModel.discountRates.last);
    if (demanding != null && demanding < delivered - _inLineTolerance) {
      return ExpectationVerdict.belowRecord;
    }
    return ExpectationVerdict.inLineWithRecord;
  }

  /// The median free cash flow margin over the last decade, applied to the
  /// latest year's revenue.
  static ({double flow, double margin})? _normalisedCashFlow(
    FinancialSnapshot snapshot,
  ) {
    final revenue = snapshot.latest.revenue;
    if (revenue == null || revenue <= 0) return null;

    final window = snapshot.years.length > CashFlowModel.horizon
        ? snapshot.years.sublist(snapshot.years.length - CashFlowModel.horizon)
        : snapshot.years;
    final margins = <double>[
      for (final year in window)
        if (year.revenue != null &&
            year.revenue! > 0 &&
            year.freeCashFlow != null)
          year.freeCashFlow! / year.revenue!,
    ]..sort();
    if (margins.isEmpty) return null;

    // The median, not the mean: one disastrous year should not drag the base
    // down for a decade, nor one exceptional year hold it up.
    final margin = margins[margins.length ~/ 2];
    final flow = margin * revenue;
    return flow <= 0 ? null : (flow: flow, margin: margin * 100);
  }

  /// The latest operating margin, and how far it sits from its own median
  /// over the window.
  static ({double latest, double? change})? _marginTrend(
    FinancialSnapshot snapshot,
  ) {
    final latest = snapshot.latest.operatingMarginPercent;
    if (latest == null) return null;

    final window = snapshot.years.length > CashFlowModel.horizon
        ? snapshot.years.sublist(snapshot.years.length - CashFlowModel.horizon)
        : snapshot.years;
    final margins = <double>[
      for (final year in window) ?year.operatingMarginPercent,
    ]..sort();
    if (margins.length < 2) return (latest: latest, change: null);

    return (latest: latest, change: latest - margins[margins.length ~/ 2]);
  }

  /// Annualised revenue growth over the longest window the filings support.
  /// The year-on-year changes across the record window, smallest first.
  static List<double> _growthRates(FinancialSnapshot snapshot, int? window) {
    if (window == null) return const [];
    final years = snapshot.years;
    return [
      for (final year in years.skip(math.max(0, years.length - window)))
        ?year.revenueGrowthPercent,
    ]..sort();
  }

  static ({double growth, int years})? _delivered(FinancialSnapshot snapshot) {
    final years = snapshot.years;
    for (final window in _recordWindows) {
      if (years.length <= window) {
        continue;
      }
      final growth = GrowthSample(
        startValue: years[years.length - 1 - window].revenue,
        endValue: years.last.revenue,
        years: window,
      ).annualisedPercent;
      if (growth != null) return (growth: growth, years: window);
    }
    return null;
  }

  @override
  List<Object?> get props => [
    normalisedCashFlow,
    marketCap,
    deliveredGrowthPercent,
    deliveredOverYears,
    operatingMarginPercent,
    marginChangePoints,
    growthRatesOnFile,
  ];
}
