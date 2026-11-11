import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/snapshot/sic_sector.dart';
import 'package:pickstock/data/valuation/cash_flow_model.dart';
import 'package:pickstock/data/valuation/normalised_cash_flow.dart';
import 'package:pickstock/data/valuation/quarter_figure.dart';
import 'package:pickstock/data/valuation/valuation_basis.dart';
import 'package:pickstock/data/valuation/valuation_verdict.dart';

/// How many years of history the growth the multiple pays for looks back over.
const int _growthWindowYears = 5;

/// A margin this many points below its own median is a slide, not noise.
const double _marginErosionPoints = 3;

/// Capital spending this many times depreciation is building, not maintaining.
const double _buildingCapexRatio = 1.5;

/// Real estate investment trusts, which file under this industry code. Their
/// capital spending is their business, so free cash flow says nothing about
/// what they earn; they are read like the banks.
const int _reitSic = 6798;

/// A share price judged against what the filings say the business earns.
///
/// The band is one discounted cash flow, run on the cash the business
/// ordinarily keeps for its owners, at a fixed required return, paying for
/// the growth each share has typically had. The balance sheet is added or
/// taken off, and the low end carries a margin for all of it being wrong.
/// Every input is on the card; the verdict is a heuristic and says so — it
/// exists to frame the price, not to replace reading the filings.
class Valuation extends Equatable {
  factory Valuation({
    required FinancialSnapshot snapshot,
    required double pricePerShare,
  }) {
    final latest = snapshot.latest;
    final trailing = snapshot.trailing;
    // The cover-page count is the current one; the diluted average is the
    // divisor earnings are reported against. Each is used where it fits, and
    // either can stand in for the other. The average is the newest quarter's
    // where there is one: a split since the annual report leaves the annual
    // average in the old shares — Amphenol's 1.28B against 2.58B after its
    // two-for-one, Booking's 33M against 772M after its twenty-five — and
    // earnings per share, and the fair value of a filer with no cover count,
    // that many times too high.
    final yearDiluted = _dilutedSharesOf(snapshot);
    final outstanding = shareCountOf(snapshot);
    final diluted = yearDiluted ?? snapshot.company.sharesOutstanding;
    // What the business sells and owes now, from the newest quarter where it
    // is newer than the annual report; the year's otherwise.
    final revenue = trailing?.revenue ?? latest.revenue;
    final netDebt = trailing?.netDebt ?? latest.netDebt;
    final rates = _growthRates(snapshot);
    // Each line is taken from the quarter on its own, so any of them can be
    // the year's while the others are the quarter's — a 10-Q whose balance
    // sheet is missing a line leaves the cash and debt annual.
    final fromQuarter = <QuarterFigure>{
      if (trailing?.revenue != null) QuarterFigure.revenue,
      if (trailing?.netDebt != null) QuarterFigure.netDebt,
      if (trailing?.dilutedShares != null) QuarterFigure.dilutedShares,
    };

    return Valuation._(
      pricePerShare: pricePerShare,
      sharesOutstanding: outstanding,
      // Whether the count multiplied by today's price is today's count.
      countIsCurrent: snapshot.company.sharesOutstanding != null,
      sharesLastFiled: snapshot.company.sharesLastFiled,
      dilutedShares: diluted,
      netIncome: latest.netIncome,
      operatingIncome: latest.operatingIncome,
      freeCashFlow: latest.freeCashFlow,
      normalisedCashFlow: NormalisedCashFlow.of(snapshot),
      shareBasedCompensation: latest.shareBasedCompensation,
      parentStake: latest.parentStake,
      revenue: revenue,
      netDebt: netDebt,
      fiscalYear: latest.fiscalYear,
      currentThrough: fromQuarter.isEmpty ? null : trailing?.periodEnd,
      fromQuarter: fromQuarter,
      capexToDepreciation: latest.capexToDepreciation,
      marginChangePoints: _marginChange(snapshot),
      growthPercent: _median(rates),
      windowYears: rates.length,
      isCovered: covers(snapshot.company.sic),
    );
  }

  const Valuation._({
    required this.pricePerShare,
    required this.sharesOutstanding,
    required this.countIsCurrent,
    required this.sharesLastFiled,
    required this.dilutedShares,
    required this.netIncome,
    required this.operatingIncome,
    required this.freeCashFlow,
    required this.normalisedCashFlow,
    required this.shareBasedCompensation,
    required this.parentStake,
    required this.revenue,
    required this.netDebt,
    required this.fiscalYear,
    required this.currentThrough,
    required this.fromQuarter,
    required this.capexToDepreciation,
    required this.marginChangePoints,
    required this.growthPercent,
    required int windowYears,
    required this.isCovered,
  }) : _windowYears = windowYears; // ignore: prefer_initializing_formals

  final double pricePerShare;

  /// Shares on the cover of the newest filing.
  final double? sharesOutstanding;

  /// Whether [sharesOutstanding] is the count on the cover of the newest
  /// filing, rather than the diluted average standing in for it.
  ///
  /// The two are different figures. The cover count is what the company had
  /// on the day it filed; the diluted average is the divisor its earnings are
  /// reported against — an average over the fiscal year, dilution included.
  /// Where a filer tags no usable cover count the average is the closest
  /// thing on file, and for Mastercard it lands within 2%. But it is a
  /// year-old average being multiplied by a live price, and the worked example
  /// says so rather than presenting it as the company's share count.
  final bool countIsCurrent;

  /// When the filer last put a share count on a cover. Where
  /// [countIsCurrent] is false this says whether it stopped filing one — and
  /// when — or never filed one at all.
  final DateTime? sharesLastFiled;

  /// Diluted average shares for [fiscalYear], the earnings-per-share divisor.
  final double? dilutedShares;

  final double? netIncome;

  /// Profit from the business itself, before interest and tax. The ceiling
  /// on what the earnings basis may credit.
  final double? operatingIncome;

  /// The latest year's free cash flow as filed, before stock pay. What the
  /// ratio grid quotes; the band is struck on [normalisedCashFlow].
  final double? freeCashFlow;

  /// The cash the business ordinarily keeps for its owners, read across its
  /// years, or `null` where the filings carry no cash flow at all.
  final NormalisedCashFlow? normalisedCashFlow;

  /// What the year's staff were paid in shares rather than money.
  final double? shareBasedCompensation;

  final double? revenue;
  final double? netDebt;

  /// How much of the group the shares being priced own, as a fraction.
  ///
  /// `1` for all but a handful of filers. Where a listed company holds only a
  /// slice of the business it consolidates, its cash flow and operating profit
  /// are the whole group's while its share count is its own, and the two are
  /// not divisible by one another until the first is brought down to this.
  final double parentStake;

  /// Whether this kind of company can be valued on its cash flow at all.
  ///
  /// Banks, insurers, brokers and lenders are not: their borrowing is their
  /// raw material, their "operating cash flow" swings with deposits and
  /// trading books, and the debt the parser reads is the business itself.
  /// JPMorgan reported operating cash flow of -$148B for FY2025 and Bank of
  /// America +$13B, and neither figure says anything about what either bank
  /// earns. Real estate investment trusts are read the same way: their
  /// capital spending is the business. All of them say so rather than
  /// producing a band.
  ///
  /// Managed care — UnitedHealth, Centene, Humana — files under the insurers'
  /// codes and stays out with them, deliberately: its cash flow runs on
  /// premiums collected ahead of claims paid, which is float, and a year's
  /// free cash flow says as little about it as a property insurer's does.
  final bool isCovered;

  /// Whether the figures below have been brought down to the parent's slice,
  /// so the worked example can say that they were.
  bool get hasOutsideOwners => parentStake < 1;

  /// How much of the spare cash went out in shares, as a percentage — the
  /// figure the worked example states so the subtraction is not a surprise.
  double? get stockPayShareOfCashPercent {
    final cash = freeCashFlow;
    final stock = shareBasedCompensation;
    if (cash == null || stock == null || cash <= 0) return null;
    return stock / cash * 100;
  }

  /// Whether stock pay is doing anything here, so the report can say it is.
  bool get hasStockPay => (shareBasedCompensation ?? 0) > 0;

  /// The normalised cash flow, less the part of it that belongs to owners
  /// outside the listed company.
  ///
  /// The cash the filing reports is the whole group's, and only this much of
  /// it reaches the shares. MarketWise generated $45.6M in FY2025 against 2.4M
  /// diluted shares — $18.71 a share, or so it read, when 91% of the group's
  /// profit went to its Class B unitholders and the shares' own claim was
  /// $1.64.
  double? get freeCashFlowToShareholders {
    final cash = normalisedCashFlow?.flow;
    return cash == null ? null : cash * parentStake;
  }

  /// The fiscal year every figure above is taken from.
  final int fiscalYear;

  /// The quarter end of the 10-Q that supplied any of [fromQuarter], where
  /// one newer than the annual report did; `null` where every figure is the
  /// annual report's.
  final DateTime? currentThrough;

  /// Which figures were read from that quarter rather than the year, so the
  /// worked example names those and only those.
  final Set<QuarterFigure> fromQuarter;

  /// The latest year's capital spending over its depreciation, or `null`
  /// where either is missing.
  final double? capexToDepreciation;

  /// How far the latest operating margin sits from its own median over the
  /// last decade, in percentage points, or `null` where there are too few
  /// margins on file to have a median.
  ///
  /// Revenue growth alone cannot tell bought growth from earned growth: a
  /// company can compound sales for a decade while its margin drains away.
  /// Read off the filings rather than the cash flow, so it is said whichever
  /// stream the band is struck on.
  final double? marginChangePoints;

  /// Whether growth has come at the cost of profitability, by enough to be
  /// worth saying out loud.
  bool get isMarginEroding =>
      (marginChangePoints ?? 0) <= -_marginErosionPoints;

  /// Whether the company is spending well beyond what wears out — which is
  /// why one year's cash or profit may understate the business.
  bool get isBuildingCapacity =>
      (capexToDepreciation ?? 0) >= _buildingCapexRatio;

  /// Typical growth of revenue per share over the window, in percentage
  /// points, before the band's floor and ceiling: what the company has
  /// actually done, so the worked example can say what was credited and why.
  final double? growthPercent;

  final int _windowYears;

  /// The return a buyer is assumed to want, in percent. The same for every
  /// company, on purpose: see [CashFlowModel.defaultDiscountRate].
  double get discountRatePercent => CashFlowModel.defaultDiscountRate * 100;

  /// Price times shares: what the market says the equity is worth.
  double? get marketCap {
    final shares = sharesOutstanding;
    return shares == null ? null : pricePerShare * shares;
  }

  /// Market value plus net debt: what an acquirer pays for the whole business.
  ///
  /// `null` where the debt is not on file as well as where the market value
  /// is not: a missing debt counted as none would print the market value
  /// under the enterprise value's name, which reads as a company owing
  /// nothing.
  double? get enterpriseValue {
    final equity = marketCap;
    final debt = netDebt;
    if (equity == null || debt == null) return null;
    return equity + debt;
  }

  /// Earnings per diluted share, as the company would report it.
  double? get earningsPerShare {
    final earnings = netIncome;
    final shares = dilutedShares;
    if (earnings == null || shares == null || shares <= 0) return null;
    return earnings / shares;
  }

  /// Years of current earnings the price costs. `null` at a loss, where the
  /// ratio is not merely high but meaningless.
  double? get priceEarningsRatio {
    final eps = earningsPerShare;
    if (eps == null || eps <= 0) return null;
    return pricePerShare / eps;
  }

  /// Free cash flow as a percentage of market value — the yield an owner buying
  /// at this price gets, before any growth.
  double? get freeCashFlowYieldPercent {
    final cash = freeCashFlow;
    final equity = marketCap;
    if (cash == null || equity == null || equity <= 0) return null;
    return cash / equity * 100;
  }

  /// Market value over free cash flow: the years of cash the shares cost.
  ///
  /// Against the market value rather than the enterprise value. Free cash flow
  /// here is operating cash flow less capital spending, and US filers put
  /// interest paid in the operating section — so it is already net of what the
  /// lenders take, which makes it the shareholders' cash. Dividing enterprise
  /// value by it charges for the debt twice: once in the numerator and again
  /// through the interest already deducted from the denominator.
  double? get priceToFreeCashFlow {
    final cash = freeCashFlow;
    final equity = marketCap;
    if (cash == null || equity == null || cash <= 0 || equity <= 0) return null;
    return equity / cash;
  }

  double? get priceToSalesRatio {
    final sales = revenue;
    final equity = marketCap;
    if (sales == null || equity == null || sales <= 0) return null;
    return equity / sales;
  }

  /// The earnings multiple set against the growth rate that has to justify it.
  /// Under one is the classic Lynch reading of cheap.
  double? get growthAdjustedRatio {
    final ratio = priceEarningsRatio;
    final growth = growthPercent;
    if (ratio == null || growth == null || growth <= 0) return null;
    return ratio / growth;
  }

  /// Which stream the band is struck against, preferring cash over accounting
  /// profit, or `null` where the company generates neither.
  ValuationBasis? get basis {
    if ((freeCashFlowToShareholders ?? 0) > 0) {
      return ValuationBasis.freeCashFlow;
    }
    if ((_earningsFromOperations ?? 0) > 0) return ValuationBasis.earnings;
    return null;
  }

  /// The amount [basis] refers to, so the report can state the working without
  /// having to know which stream was chosen.
  double? get basisAmount => switch (basis) {
    ValuationBasis.freeCashFlow => freeCashFlowToShareholders,
    ValuationBasis.earnings => _earningsFromOperations,
    null => null,
  };

  /// How many years the stream was read over: one where it is the year as
  /// filed, which is what the earnings basis always is.
  int get basisYears => switch (basis) {
    ValuationBasis.freeCashFlow => normalisedCashFlow?.yearsRead ?? 1,
    _ => 1,
  };

  /// Profit, but no more of it than the business itself produced.
  ///
  /// Operating income is struck before tax and before financing, so for a
  /// company earning its way it sits above net income and this changes
  /// nothing. Where net income is the larger, the difference did not come
  /// from selling anything — and a multiple of it values something the
  /// company does not do.
  ///
  /// Lyft is why. In FY2025 it lost $53M before tax and released $2.9B of
  /// deferred tax, reporting $2,844M of net income against an operating loss
  /// of $188M. Valued on that, its shares were worth $203 to $248 against a
  /// price of $17 — a thirteen-fold upside, on a year the business lost
  /// money. Held to operating income the figure is negative, there is no
  /// stream to value, and the report says so instead.
  /// Net income needs no such treatment: it is already the parent's share.
  /// Operating income is the group's, so the ceiling is brought down before
  /// it is applied — otherwise a company whose operating profit is the smaller
  /// of the two would be held to a figure most of which is not its own.
  double? get _earningsFromOperations {
    final profit = netIncome;
    if (profit == null) return null;
    final operating = operatingIncome;
    if (operating == null) return profit;
    return math.min(profit, operating * parentStake);
  }

  /// Growth credited to the multiple, in percentage points: the typical
  /// per-share growth, held between the model's floor and ceiling.
  ///
  /// Negative where the business is shrinking. A company whose sales per
  /// share fall 5% a year is not worth what a flat one is, and the old floor
  /// at zero valued AT&T, Verizon and Comcast as if their decline had
  /// stopped — which is how all three screened as deeply undervalued.
  double get creditedGrowthPercent => (growthPercent ?? 0).clamp(
    CashFlowModel.minimumCreditedGrowth * 100,
    CashFlowModel.maximumCreditedGrowth * 100,
  );

  /// The years of cash a buyer wanting no growth would pay, at this rate.
  ///
  /// Shown beside the range so a reader can see what the growth is worth: the
  /// difference between the two is the premium, stated rather than assumed.
  double get flatMultiple =>
      CashFlowModel.multipleFor(growth: 0, discountRate: _discountRate);

  /// What the growth is worth, at the rate itself: the same stream valued
  /// with and without it. Compared against [flatMultiple], which is struck at
  /// the same rate — the band either side of it is a separate question.
  double get centralMultiple => CashFlowModel.multipleFor(
    growth: creditedGrowthPercent / 100,
    discountRate: _discountRate,
  );

  /// The band is drawn across the required return rather than the growth: it
  /// is the least certain input and the one the answer moves most with, and
  /// the growth is already read three ways on the tab next door.
  double get lowMultiple => CashFlowModel.multipleFor(
    growth: creditedGrowthPercent / 100,
    discountRate: _discountRate + CashFlowModel.discountRateBand,
  );

  double get highMultiple => CashFlowModel.multipleFor(
    growth: creditedGrowthPercent / 100,
    discountRate: _discountRate - CashFlowModel.discountRateBand,
  );

  double get _discountRate => CashFlowModel.defaultDiscountRate;

  /// Cash the company holds beyond what it owes, added to what the stream is
  /// worth: it is the owners' as surely as next year's cash is. Zero for a
  /// company owing more than it holds, or saying nothing about either.
  double get netCashAdded {
    final net = netDebt;
    return net == null || net >= 0 ? 0 : -net;
  }

  /// Debt beyond what the cash flow can carry, taken off what the stream is
  /// worth.
  ///
  /// Not all of the debt: the stream is already after interest, so a
  /// multiple of it is already what the shares are worth with the lenders
  /// paid, and subtracting the principal as well would charge for the same
  /// debt twice. But a company owing twenty years of its cash flow is not
  /// worth a multiple of that cash flow either — the lenders own it. So the
  /// first [CashFlowModel.carriedDebtYears] years' worth is the debt a
  /// business carries, and only what lies beyond that comes off.
  double get excessDebtDeducted {
    final net = netDebt;
    final stream = basisAmount;
    if (net == null || net <= 0 || stream == null || stream <= 0) return 0;
    return math.max(0, net - CashFlowModel.carriedDebtYears * stream);
  }

  /// Whether the balance sheet moved the answer at all, so the worked example
  /// can say which way.
  bool get hasBalanceSheetAdjustment =>
      netCashAdded > 0 || excessDebtDeducted > 0;

  /// What the whole equity is worth at [multiple] years of the stream, with
  /// the balance sheet counted, or `null` where there is no stream.
  double? equityValueAt(double multiple) {
    final stream = basisAmount;
    if (stream == null || !isCovered) return null;
    return math.max(0, stream * multiple + netCashAdded - excessDebtDeducted);
  }

  /// The bottom of the fair range, per share.
  ///
  /// A third below what the arithmetic gives: the margin for the stream, the
  /// growth, the rate or the share count being wrong, which across ten
  /// thousand filers some of them always are. A price has to clear it before
  /// the company is called cheap. Without it, a band a point of return wide
  /// called a third of the directory undervalued, and a third of those by
  /// more than 100%.
  double? get fairValueLow {
    final value = equityValueAt(lowMultiple);
    final shares = sharesOutstanding;
    if (value == null || shares == null || shares <= 0) return null;
    return value * (1 - CashFlowModel.marginOfSafety) / shares;
  }

  /// The top of the fair range, per share: what the arithmetic gives at the
  /// generous end of the return, with no margin taken.
  double? get fairValueHigh {
    final value = equityValueAt(highMultiple);
    final shares = sharesOutstanding;
    if (value == null || shares == null || shares <= 0) return null;
    return value / shares;
  }

  /// The bottom of the band before the margin of safety is taken, per share,
  /// so the worked example can show both.
  double? get fairValueLowBeforeMargin {
    final value = equityValueAt(lowMultiple);
    final shares = sharesOutstanding;
    if (value == null || shares == null || shares <= 0) return null;
    return value / shares;
  }

  /// How far the price would have to move to reach [target], as a percentage.
  /// Positive means the target is above the current price.
  ///
  /// Measured to each end of the band rather than to its middle: a single
  /// figure against an invented midpoint is hard to tie back to either bound,
  /// which is the only part of the band the arithmetic actually produced.
  double? percentTo(double? target) {
    if (target == null || pricePerShare <= 0) return null;
    return (target - pricePerShare) / pricePerShare * 100;
  }

  /// How far the price is from the bottom of the band.
  double? get percentToLow => percentTo(fairValueLow);

  /// How far the price is from the top of the band.
  double? get percentToHigh => percentTo(fairValueHigh);

  ValuationVerdict get verdict {
    if (!isCovered) return ValuationVerdict.notCovered;
    final low = fairValueLow;
    final high = fairValueHigh;
    if (low == null || high == null) return ValuationVerdict.unknown;
    if (pricePerShare < low) return ValuationVerdict.undervalued;
    if (pricePerShare > high) return ValuationVerdict.overvalued;
    return ValuationVerdict.fairlyValued;
  }

  /// How many year-on-year changes the median was taken over, so the worked
  /// example can say what "typical" was measured across.
  int get growthWindowYears => _windowYears;

  /// The year-on-year changes in revenue per share inside the window, in
  /// order, smallest first.
  ///
  /// Per share, because the shares are what is being valued. Revenue bought
  /// with newly printed shares is not growth to the holder of an old one:
  /// Realty Income grew revenue 26% a year and its share count 20%, and on
  /// revenue alone it earned nearly ten extra turns of multiple for growth
  /// its owners never saw. Where a year has no share count, the plain
  /// revenue change stands in.
  ///
  /// A median rather than the rate from one end of the window to the other.
  /// Zoom is why: $2.65B to $4.87B over five years annualises to 12.9%, all
  /// of it the tail of one pandemic year, while its last four years grew
  /// 7.1%, 3.1%, 3.1% and 4.4%. Its middle year is 4.4%. And a median rather
  /// than the latest year, which would be just as blind the other way: one
  /// flat year in a long climb would price the climb away.
  static List<double> _growthRates(FinancialSnapshot snapshot) {
    final years = snapshot.years;
    if (years.length < 2) return const [];
    final window = math.min(_growthWindowYears, years.length - 1);
    return [
      for (var i = years.length - window; i < years.length; i++)
        ?_perShareGrowth(years[i], years[i - 1]),
    ]..sort();
  }

  static double? _perShareGrowth(
    FiscalYearFigures year,
    FiscalYearFigures before,
  ) {
    final sales = year.revenue;
    final priorSales = year.priorRevenue ?? before.revenue;
    final shares = year.dilutedShares;
    final priorShares = before.dilutedShares;
    if (sales == null || priorSales == null || priorSales <= 0) return null;
    if (shares == null || priorShares == null || shares <= 0) {
      return (sales - priorSales) / priorSales * 100;
    }
    final perShare = sales / shares;
    final priorPerShare = priorSales / priorShares;
    return (perShare - priorPerShare) / priorPerShare * 100;
  }

  /// The share count the band divides by: the cover count where there is
  /// one, the diluted average otherwise — the same resolution the valuation
  /// itself makes, so a report can ask whether a company can be valued
  /// without building one.
  static double? shareCountOf(FinancialSnapshot snapshot) =>
      snapshot.company.sharesOutstanding ?? _dilutedSharesOf(snapshot);

  /// The diluted average, the newest quarter's where there is one.
  static double? _dilutedSharesOf(FinancialSnapshot snapshot) =>
      snapshot.trailing?.dilutedShares ?? snapshot.latest.dilutedShares;

  /// The latest operating margin less its median over the last
  /// [CashFlowModel.horizon] years, or `null` where there are fewer than two
  /// margins to take a median of.
  static double? _marginChange(FinancialSnapshot snapshot) {
    final latest = snapshot.latest.operatingMarginPercent;
    if (latest == null) return null;

    final years = snapshot.years;
    final window = years.length > CashFlowModel.horizon
        ? years.sublist(years.length - CashFlowModel.horizon)
        : years;
    final margins = <double>[
      for (final year in window) ?year.operatingMarginPercent,
    ]..sort();
    if (margins.length < 2) return null;
    return latest - margins[margins.length ~/ 2];
  }

  static double? _median(List<double> sorted) {
    if (sorted.isEmpty) return null;
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }

  /// Whether a filer of industry [sic] can be valued on its cash flow — not
  /// a bank, insurer, lender, broker or REIT. Read too by the framework's
  /// filings checks, which ask the same of the same figures.
  static bool covers(int? sic) =>
      sic != _reitSic && SicSector.of(sic) != SicSector.financials;

  @override
  List<Object?> get props => [
    pricePerShare,
    sharesOutstanding,
    countIsCurrent,
    sharesLastFiled,
    dilutedShares,
    netIncome,
    operatingIncome,
    freeCashFlow,
    normalisedCashFlow?.flow,
    shareBasedCompensation,
    parentStake,
    revenue,
    netDebt,
    fiscalYear,
    currentThrough,
    fromQuarter,
    capexToDepreciation,
    marginChangePoints,
    growthPercent,
    _windowYears,
    isCovered,
  ];
}
