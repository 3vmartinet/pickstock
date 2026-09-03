import 'package:equatable/equatable.dart';

/// The equity risk premium: what a buyer wants on top of a government bond
/// for holding shares instead.
///
/// A judgment, not a measurement — nobody publishes it, and the estimates that
/// exist sit between four and six points. Fixed here rather than fetched
/// because a number this soft has no business looking precise, and because
/// moving it moves every company in the directory by the same amount, which
/// tells a reader nothing about any of them.
const double equityRiskPremium = 5.0;

/// The band a computed rate is held inside.
///
/// A borrowed beta is an estimate of an estimate, and a wrong one at either
/// end produces a rate that is not a return anybody would ask for. Outside
/// this the figure says more about the beta than about the company.
const double minimumDiscountRate = 5.0;
const double maximumDiscountRate = 18.0;

/// What a buyer should want back each year for holding this company's shares,
/// and where each part of it came from.
///
/// The capital asset pricing model, which is the plainest way to turn a
/// government bond yield and a company's own volatility into a required
/// return: what you could earn risk-free, plus a premium for taking equity
/// risk at all, scaled by how much more than the market this share moves.
///
/// Kept as a value rather than a bare double so the report can show its
/// working. A discount rate is the most consequential number in a valuation
/// and the least visible — a reader who cannot see what it was built from has
/// no way to disagree with it.
class DiscountRate extends Equatable {
  const DiscountRate({
    required this.riskFreePercent,
    required this.beta,
    required this.asOf,
  });

  /// The ten-year US Treasury yield, in percentage points.
  final double riskFreePercent;

  /// How much the share moves against the market. One is the market itself.
  final double beta;

  /// The day the Treasury published the yield.
  final DateTime asOf;

  /// The rate before the band is applied, which is what the working shows.
  double get uncappedPercent => riskFreePercent + beta * equityRiskPremium;

  /// The rate actually discounted at.
  double get percent =>
      uncappedPercent.clamp(minimumDiscountRate, maximumDiscountRate);

  /// Whether the band moved the answer, so the report can say it did rather
  /// than quietly showing a figure the arithmetic above it does not reach.
  bool get isCapped => (uncappedPercent - percent).abs() > 0.005;

  @override
  List<Object?> get props => [riskFreePercent, beta, asOf];
}
