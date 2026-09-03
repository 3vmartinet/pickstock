import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/valuation/cash_flow_model.dart';
import 'package:pickstock/data/valuation/growth_expectation.dart';
import 'package:pickstock/data/valuation/price_target.dart';

const double _billion = 1000000000;
const double _shares = 300000000;

/// A filer with [revenues] in billions, oldest first, converting a steady
/// fifth of what it sells into spare cash.
FinancialSnapshot _snapshot(List<double> revenues) {
  final years = <FiscalYearFigures>[];
  double? prior;
  for (var index = 0; index < revenues.length; index++) {
    final revenue = revenues[index] * _billion;
    years.add(
      FiscalYearFigures(
        fiscalYear: 2026 - revenues.length + 1 + index,
        revenue: revenue,
        priorRevenue: prior,
        operatingCashFlow: revenue * 0.25,
        capitalExpenditure: revenue * 0.05,
        operatingIncome: revenue * 0.2,
      ),
    );
    prior = revenue;
  }
  return FinancialSnapshot(
    company: const Company(
      ticker: 'TEST',
      cik: '0000000001',
      name: 'Test Corp',
      sharesOutstanding: _shares,
    ),
    years: years,
  );
}

GrowthExpectation _expectation(List<double> revenues) =>
    GrowthExpectation.of(_snapshot(revenues), 100 * _shares)!;

void main() {
  group('price targets', () {
    // Zoom's filed revenue: a pandemic year and then five quiet ones.
    final zoom = _expectation(const [
      0.151,
      0.331,
      0.623,
      2.651,
      4.100,
      4.393,
      4.527,
      4.665,
      4.869,
    ]);

    test('reads its three rates off the years the company has had', () {
      // The window is the last five changes: +54.7, +7.1, +3.1, +3.0, +4.4.
      expect(zoom.growthRatesOnFile.map((rate) => rate.round()), [
        3,
        3,
        4,
        7,
        55,
      ]);

      final targets = zoom.priceTargets(_shares);
      expect(targets.map((target) => target.scenario), [
        PriceCase.bear,
        PriceCase.neutral,
        PriceCase.bull,
      ]);

      // Worst year, middle year, best year. The middle is the median, so the
      // pandemic year does not move the neutral case; the bull is that year,
      // held to the cap rather than compounding 55% for a decade.
      expect(targets[0].growthPercent, closeTo(3.0, 0.1));
      expect(targets[1].growthPercent, closeTo(4.4, 0.1));
      expect(
        targets[2].growthPercent,
        closeTo(CashFlowModel.maximumCreditedGrowth * 100, 0.01),
      );
    });

    test('spreads the three cases wide enough to differ', () {
      // Adobe's five years, which is what quartiles could not handle: its
      // best year was 22.7% and its upper quartile only 11.5, so bear,
      // neutral and bull all landed within a point of each other and said
      // the same thing three times.
      final adobe = _expectation(const [
        12.868,
        15.785,
        17.606,
        19.409,
        21.505,
        23.760,
      ]);
      final targets = adobe.priceTargets(_shares);
      expect(targets[0].growthPercent, closeTo(10.2, 0.2));
      expect(targets[1].growthPercent, closeTo(10.8, 0.2));
      // Its best year was 22.7%, which is inside the cap and so stands as
      // filed — where the upper quartile gave 11.5 and no bull case at all.
      expect(targets[2].growthPercent, closeTo(22.7, 0.2));

      // A range worth reading, rather than three ways of saying one number.
      expect(
        targets[2].valuePerShare - targets[0].valuePerShare,
        greaterThan(targets[1].valuePerShare * 0.5),
      );
    });

    test('values each rate through the same discounted cash flow', () {
      final targets = zoom.priceTargets(_shares);

      // Nothing new is being computed here: each target is the model the rest
      // of the tab runs, at that target's own rate.
      for (final target in targets) {
        expect(
          target.valuePerShare,
          closeTo(
            CashFlowModel.presentValue(
                  zoom.normalisedCashFlow,
                  growth: target.growthPercent / 100,
                  discountRate: CashFlowModel.defaultDiscountRate,
                ) /
                _shares,
            0.01,
          ),
        );
      }

      // And more growth is worth more, in order.
      expect(targets[0].valuePerShare, lessThan(targets[1].valuePerShare));
      expect(targets[1].valuePerShare, lessThan(targets[2].valuePerShare));
    });

    test('will not extrapolate a boom or a collapse for a decade', () {
      final boom = _expectation(const [1, 2, 4, 8, 16, 32, 64]);
      expect(
        boom.priceTargets(_shares).last.growthPercent,
        closeTo(CashFlowModel.maximumCreditedGrowth * 100, 0.01),
      );

      final collapse = _expectation(const [64, 32, 16, 8, 4, 2, 1]);
      expect(
        collapse.priceTargets(_shares).first.growthPercent,
        closeTo(CashFlowModel.minimumCreditedGrowth * 100, 0.01),
      );
    });

    test('states nothing where there is no record to read', () {
      // The same bar the verdict uses: too few years on file to say what a
      // typical one looks like.
      expect(
        _expectation(const [4.0, 4.2, 4.4]).priceTargets(_shares),
        isEmpty,
      );
      expect(zoom.priceTargets(0), isEmpty);
    });

    test('measures each target against what a share costs', () {
      final target = zoom.priceTargets(_shares)[1];
      expect(
        target.upsidePercentFrom(target.valuePerShare / 2),
        closeTo(100, 0.01),
      );
      expect(target.upsidePercentFrom(0), 0);
    });
  });
}
