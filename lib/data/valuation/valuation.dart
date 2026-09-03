import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/growth_metric.dart';
import 'package:pickstock/data/valuation/valuation_basis.dart';
import 'package:pickstock/data/valuation/valuation_verdict.dart';

/// How many years of revenue history the growth premium looks back over.
const int _growthWindowYears = 5;

/// The multiple range a no-growth company is worth, before any premium.
///
/// Twelve to eighteen times owner earnings is the long-run range the broad US
/// market has traded in. It is a stake in the ground, not a law: the band is
/// shown with its own multiples so the number can be argued with.
const double _baseLowMultiple = 12;
const double _baseHighMultiple = 18;

/// Growth is paid for, so the band widens with it — but only up to a point,
/// since no company compounds at 40% for the decade a multiple implies.
const double _maxCreditedGrowthPercent = 25;
const double _multiplePerGrowthPoint = 0.6;

/// A share price judged against what the filings say the business earns.
///
/// Every figure here comes from the latest fiscal year on file plus the price
/// the user supplies; nothing is forecast. The verdict is a heuristic and says
/// so — it exists to frame the price, not to replace reading the filings.
class Valuation extends Equatable {
  factory Valuation({
    required FinancialSnapshot snapshot,
    required double pricePerShare,
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
      freeCashFlow: latest.freeCashFlow,
      revenue: latest.revenue,
      netDebt: latest.netDebt,
      fiscalYear: latest.fiscalYear,
      revenueGrowthPercent: _revenueGrowthPercent(snapshot),
    );
  }

  const Valuation._({
    required this.pricePerShare,
    required this.sharesOutstanding,
    required this.countIsCurrent,
    required this.sharesLastFiled,
    required this.dilutedShares,
    required this.netIncome,
    required this.freeCashFlow,
    required this.revenue,
    required this.netDebt,
    required this.fiscalYear,
    required this.revenueGrowthPercent,
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
  final double? freeCashFlow;
  final double? revenue;
  final double? netDebt;

  /// The fiscal year every figure above is taken from.
  final int fiscalYear;

  /// Annualised revenue growth over the window the band's premium uses.
  final double? revenueGrowthPercent;

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
    if ((freeCashFlow ?? 0) > 0) return ValuationBasis.freeCashFlow;
    if ((netIncome ?? 0) > 0) return ValuationBasis.earnings;
    return null;
  }

  /// The amount [basis] refers to, so the report can state the working without
  /// having to know which stream was chosen.
  double? get basisAmount => switch (basis) {
    ValuationBasis.freeCashFlow => freeCashFlow,
    ValuationBasis.earnings => netIncome,
    null => null,
  };

  /// Growth credited to the multiple, in percentage points.
  double get creditedGrowthPercent => math.min(
    math.max(revenueGrowthPercent ?? 0, 0),
    _maxCreditedGrowthPercent,
  );

  /// Turns of multiple added for growth, on top of the no-growth range.
  double get growthPremiumMultiple =>
      creditedGrowthPercent * _multiplePerGrowthPoint;

  double get lowMultiple => _baseLowMultiple + growthPremiumMultiple;

  double get highMultiple => _baseHighMultiple + growthPremiumMultiple;

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

  /// Annualised revenue growth over the longest window up to
  /// [_growthWindowYears] the filings support.
  static double? _revenueGrowthPercent(FinancialSnapshot snapshot) {
    final years = snapshot.years;
    if (years.length < 2) return null;
    final span = math.min(_growthWindowYears, years.length - 1);
    for (var window = span; window >= 1; window--) {
      final growth = GrowthSample(
        startValue: years[years.length - 1 - window].revenue,
        endValue: years.last.revenue,
        years: window,
      ).annualisedPercent;
      if (growth != null) return growth;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    pricePerShare,
    sharesOutstanding,
    countIsCurrent,
    sharesLastFiled,
    dilutedShares,
    netIncome,
    freeCashFlow,
    revenue,
    netDebt,
    fiscalYear,
    revenueGrowthPercent,
  ];
}
