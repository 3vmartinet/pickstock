import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/data/snapshot/growth_metric.dart';

/// The unit tests work in millions so every base clears [minimumGrowthBase].
const double _m = 1000000;

void main() {
  test('a single year is the plain change', () {
    final sample = GrowthSample(
      startValue: 100 * _m,
      endValue: 125 * _m,
      years: 1,
    );
    expect(sample.annualisedPercent, closeTo(25, 0.001));
  });

  test('several years compound rather than average', () {
    // Doubling over three years is ~26% a year, not 33%.
    final sample = GrowthSample(
      startValue: 100 * _m,
      endValue: 200 * _m,
      years: 3,
    );
    expect(sample.annualisedPercent, closeTo(25.992, 0.001));
  });

  test('a fall over one year is negative', () {
    final sample = GrowthSample(
      startValue: 100 * _m,
      endValue: 60 * _m,
      years: 1,
    );
    expect(sample.annualisedPercent, closeTo(-40, 0.001));
  });

  test('a loss at either end has no annual rate', () {
    // There is no real growth rate from -50 to 100, and quoting one would be
    // worse than saying nothing.
    final fromLoss = GrowthSample(
      startValue: -50 * _m,
      endValue: 100 * _m,
      years: 5,
    );
    final toLoss = GrowthSample(
      startValue: 100 * _m,
      endValue: -50 * _m,
      years: 5,
    );
    expect(fromLoss.annualisedPercent, isNull);
    expect(toLoss.annualisedPercent, isNull);
  });

  test('a one-year swing through zero is still reportable', () {
    // Over a single year the plain change is meaningful even into a loss.
    final sample = GrowthSample(
      startValue: 100 * _m,
      endValue: -50 * _m,
      years: 1,
    );
    expect(sample.annualisedPercent, closeTo(-150, 0.001));
  });

  test('a missing end of the window has no rate', () {
    expect(
      GrowthSample(
        startValue: null,
        endValue: 100 * _m,
        years: 1,
      ).annualisedPercent,
      isNull,
    );
    expect(
      GrowthSample(
        startValue: 100 * _m,
        endValue: null,
        years: 3,
      ).annualisedPercent,
      isNull,
    );
  });

  test('a zero start has no rate rather than infinity', () {
    final sample = GrowthSample(startValue: 0, endValue: 100 * _m, years: 1);
    expect(sample.annualisedPercent, isNull);
  });

  test('a negligible base has no rate, however fast it grew', () {
    // A shell company going from 8,000 dollars to 97 million is arithmetically
    // a 10,000% annual rate and tells you nothing about the business.
    const shell = GrowthSample(startValue: 8000, endValue: 97207466, years: 2);
    expect(shell.annualisedPercent, isNull);
  });
}
