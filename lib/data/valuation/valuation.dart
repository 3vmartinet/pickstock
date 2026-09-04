import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/valuation/cash_flow_model.dart';
import 'package:pickstock/data/valuation/valuation_basis.dart';
import 'package:pickstock/data/valuation/valuation_verdict.dart';

/// How many years of revenue history the growth premium looks back over.
const int _growthWindowYears = 5;

/// The multiple is no longer a rule of thumb with a growth premium bolted on.
///
/// Twelve to eighteen times earnings, plus six tenths of a turn per point of
/// growth, priced Nextpower at 28 years of its cash while the discounted cash
/// flow on the tab beside it — at the 14.7% its own beta asks for — said 18.
/// Two models, one company, two answers, and no way for a reader to know
/// which to believe. The multiple now comes out of that same model, so there
/// is only one.
///
/// The old range was not wrong so much as unstated: at 9% and no growth the
/// model returns 14.1 years, which is the middle of it. What it could not do
/// was move with the return a particular company has to earn.

/// A share price judged against what the filings say the business earns.
///
/// Every figure here comes from the latest fiscal year on file plus the price
/// the user supplies; nothing is forecast. The verdict is a heuristic and says
/// so — it exists to frame the price, not to replace reading the filings.
class Valuation extends Equatable {
  factory Valuation({
    required FinancialSnapshot snapshot,
    required double pricePerShare,
    double? discountRatePercent,
  }) {
    final latest = snapshot.latest;
    // The cover-page count is the current one; the annual diluted average is
    // the divisor earnings are reported against. Each is used where it fits,
    // and either can stand in for the other.
    final outstanding =
        snapshot.company.sharesOutstanding ?? latest.dilutedShares;
    final diluted = latest.dilutedShares ?? snapshot.company.sharesOutstanding;

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
      parentStake: latest.parentStake,
      revenue: latest.revenue,
      netDebt: latest.netDebt,
      fiscalYear: latest.fiscalYear,
      revenueGrowthPercent: _revenueGrowthPercent(snapshot),
      discountRatePercent:
          discountRatePercent ?? CashFlowModel.defaultDiscountRate * 100,
      windowYears: _growthRates(snapshot).length,
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
    required this.parentStake,
    required this.revenue,
    required this.netDebt,
    required this.fiscalYear,
    required this.revenueGrowthPercent,
    required this.discountRatePercent,
    required this._windowYears,
  });

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

  final double? freeCashFlow;
  final double? revenue;
  final double? netDebt;

  /// How much of the group the shares being priced own, as a fraction.
  ///
  /// `1` for all but a handful of filers. Where a listed company holds only a
  /// slice of the business it consolidates, its cash flow and operating profit
  /// are the whole group's while its share count is its own, and the two are
  /// not divisible by one another until the first is brought down to this.
  final double parentStake;

  /// Whether the figures below have been brought down to the parent's slice,
  /// so the worked example can say that they were.
  bool get hasOutsideOwners => parentStake < 1;

  /// Free cash flow, less the part of it that belongs to owners outside the
  /// listed company.
  ///
  /// The cash the filing reports is the whole group's, and only this much of
  /// it reaches the shares. MarketWise generated $45.6M in FY2025 against 2.4M
  /// diluted shares — $18.71 a share, or so it read, when 91% of the group's
  /// profit went to its Class B unitholders and the shares' own claim was
  /// $1.64.
  double? get freeCashFlowToShareholders {
    final cash = freeCashFlow;
    return cash == null ? null : cash * parentStake;
  }

  /// The fiscal year every figure above is taken from.
  final int fiscalYear;

  /// Annualised revenue growth over the window the band's premium uses.
  final double? revenueGrowthPercent;

  /// The return a buyer is assumed to want, which is what turns a stream
  /// of cash into a number of years' worth of it.
  final double discountRatePercent;

  final int _windowYears;

  /// Price times shares: what the market says the equity is worth.
  double? get marketCap {
    final shares = sharesOutstanding;
    return shares == null ? null : pricePerShare * shares;
  }

  /// Market value plus net debt: what an acquirer pays for the whole business.
  double? get enterpriseValue {
    final equity = marketCap;
    if (equity == null) return null;
    return equity + (netDebt ?? 0);
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
    final growth = revenueGrowthPercent;
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

  /// Growth credited to the multiple, in percentage points.
  double get creditedGrowthPercent => math.min(
    math.max(revenueGrowthPercent ?? 0, 0),
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

  double get _discountRate => discountRatePercent / 100;

  /// The bottom of the fair range, per share.
  double? get fairValueLow => _fairValueAt(lowMultiple);

  /// The top of the fair range, per share.
  double? get fairValueHigh => _fairValueAt(highMultiple);

  double? _fairValueAt(double multiple) {
    final stream = basisAmount;
    final shares = sharesOutstanding;
    if (stream == null || shares == null || shares <= 0) return null;
    // No net-debt adjustment: the stream is already after interest, so it is
    // what reaches the shareholders and a multiple of it is what their shares
    // are worth. Subtracting the debt on top would charge for it twice.
    return stream * multiple / shares;
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
    final low = fairValueLow;
    final high = fairValueHigh;
    if (low == null || high == null) return ValuationVerdict.unknown;
    if (pricePerShare < low) return ValuationVerdict.undervalued;
    if (pricePerShare > high) return ValuationVerdict.overvalued;
    return ValuationVerdict.fairlyValued;
  }

  /// The growth the multiple is allowed to pay for: the company's middle
  /// year, not its average one.
  ///
  /// A median over the window rather than the rate from one end of it to the
  /// other. Zoom is why. Its revenue went from $2.65B to $4.87B over five
  /// years, which annualises to 12.9% — but all of that is the tail of one
  /// pandemic year, and its last four years grew 7.1%, 3.1%, 3.1% and 4.4%.
  /// On the annualised rate it earned nearly eight extra turns of multiple
  /// for growth it has not had since 2022, on a report whose own overview
  /// said 4.4% at the top of the page. Its middle year is 4.4%.
  ///
  /// A median rather than the latest year, which would be just as blind the
  /// other way: one flat year in a long climb would price the climb away.
  /// The middle year survives an exceptional year at either end, which is
  /// what a multiple is supposed to be paid on.
  static double? _revenueGrowthPercent(FinancialSnapshot snapshot) {
    final rates = _growthRates(snapshot);
    if (rates.isEmpty) return null;
    final middle = rates.length ~/ 2;
    return rates.length.isOdd
        ? rates[middle]
        : (rates[middle - 1] + rates[middle]) / 2;
  }

  /// How many year-on-year changes the median was taken over, so the worked
  /// example can say what "typical" was measured across.
  int get growthWindowYears => _windowYears;

  /// The year-on-year changes inside the window, in order, smallest first.
  ///
  /// Read off each year's own growth, which is the figure the report prints
  /// beside its revenue — so the worked example and the overview above it
  /// cannot state different rates for the same company.
  static List<double> _growthRates(FinancialSnapshot snapshot) {
    final years = snapshot.years;
    if (years.length < 2) return const [];
    final window = math.min(_growthWindowYears, years.length - 1);
    return [
      for (final year in years.skip(years.length - window))
        ?year.revenueGrowthPercent,
    ]..sort();
  }

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
    parentStake,
    revenue,
    netDebt,
    fiscalYear,
    revenueGrowthPercent,
    discountRatePercent,
    _windowYears,
  ];
}
