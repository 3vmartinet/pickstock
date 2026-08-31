import 'dart:math' as math;

/// The figure a growth ranking is measured on.
enum GrowthMetric { revenue, freeCashFlow }

/// The smallest figure a growth rate may be measured from.
///
/// A shell company going from 8,000 dollars of revenue to 97 million is a 10,000% annual
/// rate and tells you nothing; at this floor those companies drop out of the
/// ranking instead of heading it.
const double minimumGrowthBase = 1000000;

/// The two ends of a growth window for one company.
///
/// Growth is derived rather than stored so the same sample can serve both a
/// rate and the underlying figure the cell displays.
class GrowthSample {
  const GrowthSample({
    required this.startValue,
    required this.endValue,
    required this.years,
  });

  final double? startValue;
  final double? endValue;

  /// How many years apart the two ends are.
  final int years;

  /// Annualised growth as a percentage, or `null` where it cannot be stated.
  ///
  /// Over a single year this is the plain change. Over several it is the
  /// compound annual rate, which needs both ends positive: there is no real
  /// growth rate from a loss to a profit, and quoting one would be nonsense.
  double? get annualisedPercent {
    final start = startValue;
    final end = endValue;
    if (start == null || end == null) return null;
    // Rules out both a zero base and the negligible ones whose rates swamp
    // any ranking they appear in.
    if (start.abs() < minimumGrowthBase) return null;

    if (years <= 1) return (end - start) / start.abs() * 100;
    if (start <= 0 || end <= 0) return null;
    return (_nthRoot(end / start, years) - 1) * 100;
  }

  static double _nthRoot(double value, int n) =>
      math.pow(value, 1 / n) as double;
}
