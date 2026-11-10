import 'dart:math' as math;

/// Discounted cash flow, in the two directions it can be run.
///
/// Forwards it turns a growth rate into what the equity is worth. Backwards it
/// turns today's price into the growth rate that price requires — which is the
/// more useful direction, because the price is a fact and the growth rate is
/// the guess. Run backwards, the guess belongs to the market and PickStock only
/// has to report it.
abstract final class CashFlowModel {
  /// Years of explicit forecast before the terminal value takes over.
  static const int horizon = 10;

  /// Where growth lands by the end of the horizon: roughly long-run nominal
  /// GDP. Nothing outgrows the economy for ever.
  static const double terminalGrowth = 0.025;

  /// The return an equity holder is assumed to want. This is the single most
  /// consequential assumption in the model — at 7% a company can look fairly
  /// priced and at 11% badly overpriced — so the expectations tab shows its
  /// answer across the whole band rather than asserting one.
  static const List<double> discountRates = [0.07, 0.08, 0.09, 0.10, 0.11];

  /// The return every company is valued at.
  ///
  /// The same for all of them, on purpose. The band used to be struck at a
  /// rate built from each company's own beta, and the beta did most of the
  /// work: the betas on file ran from 0.08 to 6.75, and between the tenth
  /// and ninetieth percentile alone a business going nowhere was worth 19
  /// years of its cash or 7. A beta measures how a price has swung, not what
  /// a business is worth, and a verdict that moved with it said more about
  /// the share's last two years of trading than about the company. Nine per
  /// cent is roughly what equities have returned over long stretches, and
  /// is what a buyer can reasonably want of any of them.
  static const double defaultDiscountRate = 0.09;

  /// No company compounds fast for a decade, so a rate read off history is
  /// credited only this far when valuing forwards.
  ///
  /// Fifteen per cent, where it was thirty: a start of 15% fading to 2.5%
  /// still compounds to 2.3x over the decade, which is a good decade. At
  /// thirty the cap held for one company in eight and bought them 44 to 62
  /// years of their cash, and the ones it bought it for were the cyclical
  /// peaks — Micron at the top of a memory cycle, the gas producers after a
  /// price spike — which is exactly the growth a multiple must not pay for.
  static const double maximumCreditedGrowth = 0.15;

  /// How far below what the arithmetic gives the bottom of the band is
  /// drawn: the margin for the stream, the growth, the rate or the share
  /// count being wrong, which across ten thousand filers some always are.
  static const double marginOfSafety = 0.30;

  /// How many years of its cash flow a business can owe before the debt
  /// starts coming off what the shares are worth. Up to this the lenders are
  /// paid out of the stream, which is already after interest; beyond it the
  /// lenders own the business and the shares are the remainder.
  static const double carriedDebtYears = 3;

  /// How far either side of the required return the fair range is drawn.
  ///
  /// The rate is the least certain input and the one the answer moves most
  /// with, so the band is drawn across it rather than around the growth —
  /// which the expectations tab already reads three ways.
  static const double discountRateBand = 0.01;

  /// What a stream growing at [growth] is worth, as a number of years of
  /// itself.
  ///
  /// The same discounted cash flow, run against one unit of cash flow: a
  /// multiple is a present value with the amount divided back out. Derived
  /// rather than picked so that a multiple and a discounted cash flow cannot
  /// disagree about the same company, which is what a rule of thumb bolted to
  /// a growth premium was doing — pricing Nextpower at 28 years of its cash
  /// while the model beside it discounted at 14.7% and said 18.
  static double multipleFor({
    required double growth,
    required double discountRate,
  }) => presentValue(1, growth: growth, discountRate: discountRate);

  /// And no going concern shrinks at this rate for one either. A bear case is
  /// a bad decade, not a wind-up: past this the model is valuing a company
  /// that has stopped existing, which is a question for the balance sheet
  /// rather than for a cash flow.
  static const double minimumCreditedGrowth = -0.10;

  /// What a stream of [baseFlow] is worth today if it grows at [growth],
  /// fading to [terminalGrowth] across the horizon.
  ///
  /// The fade matters: holding a high rate flat for ten years and then dropping
  /// it to 2.5% overnight values a cliff no business falls off.
  static double presentValue(
    double baseFlow, {
    required double growth,
    required double discountRate,
  }) {
    var flow = baseFlow;
    var present = 0.0;
    for (var year = 1; year <= horizon; year++) {
      final faded = growth + (terminalGrowth - growth) * (year - 1) / horizon;
      flow *= 1 + faded;
      present += flow / math.pow(1 + discountRate, year);
    }
    final terminal =
        flow * (1 + terminalGrowth) / (discountRate - terminalGrowth);
    return present + terminal / math.pow(1 + discountRate, horizon);
  }

  /// The growth rate that makes [baseFlow] worth exactly [target] today, or
  /// `null` where no rate in a sane band does.
  ///
  /// Solved by bisection rather than algebraically: the fade makes the closed
  /// form unpleasant, and forty iterations settle it to well under a basis
  /// point.
  static double? impliedGrowth(
    double baseFlow, {
    required double target,
    required double discountRate,
  }) {
    if (baseFlow <= 0 || target <= 0) return null;

    double valueAt(double growth) =>
        presentValue(baseFlow, growth: growth, discountRate: discountRate);

    var low = _minimumSolvableGrowth;
    var high = _maximumSolvableGrowth;
    // Outside the band the answer is "shrinking faster than this model
    // describes" or "growth no business sustains", and either way a number
    // would be false precision.
    if (valueAt(low) > target || valueAt(high) < target) return null;

    for (var iteration = 0; iteration < _bisectionSteps; iteration++) {
      final middle = (low + high) / 2;
      if (valueAt(middle) < target) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return (low + high) / 2;
  }

  static const double _minimumSolvableGrowth = -0.5;
  static const double _maximumSolvableGrowth = 1;
  static const int _bisectionSteps = 60;
}
