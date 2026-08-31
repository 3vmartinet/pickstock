import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/valuation/cash_flow_model.dart';
import 'package:pickstock/data/valuation/growth_expectation.dart';

const double _million = 1000000;
const double _shares = 100 * _million;

/// A company compounding revenue at [growth] a year for [years], converting a
/// steady [margin] of it into free cash flow.
FinancialSnapshot _snapshot({
  double growth = 0.10,
  double margin = 0.20,
  int years = 11,
  double? finalCashFlow,
}) {
  var revenue = 1000 * _million;
  final history = <FiscalYearFigures>[];
  for (var i = 0; i < years; i++) {
    final isLast = i == years - 1;
    final cash = isLast && finalCashFlow != null
        ? finalCashFlow
        : revenue * margin;
    history.add(
      FiscalYearFigures(
        fiscalYear: 2015 + i,
        revenue: revenue,
        operatingCashFlow: cash,
        capitalExpenditure: 0,
      ),
    );
    revenue *= 1 + growth;
  }
  return FinancialSnapshot(
    company: const Company(
      ticker: 'TEST',
      cik: '1',
      name: 'Test Corp',
      sharesOutstanding: _shares,
    ),
    years: history,
  );
}

void main() {
  group('the discounted cash flow itself', () {
    test('values a flat stream near the textbook multiple', () {
      // With no growth beyond the terminal rate, a stream is worth about
      // 1 / (discount - terminal) times itself.
      final value = CashFlowModel.presentValue(
        100,
        growth: CashFlowModel.terminalGrowth,
        discountRate: 0.09,
      );
      expect(value / 100, closeTo(1 / (0.09 - 0.025), 0.5));
    });

    test(
      'is worth more the faster it grows and less the more it is discounted',
      () {
        double at(double growth, double rate) =>
            CashFlowModel.presentValue(100, growth: growth, discountRate: rate);

        expect(at(0.15, 0.09), greaterThan(at(0.05, 0.09)));
        expect(at(0.10, 0.07), greaterThan(at(0.10, 0.11)));
      },
    );

    test('solves back to the growth it was given', () {
      // The round trip is the property the whole reading depends on: value a
      // stream at a known rate, then ask what rate that value implies.
      for (final growth in [0.0, 0.05, 0.12, 0.25]) {
        final target = CashFlowModel.presentValue(
          100,
          growth: growth,
          discountRate: 0.09,
        );
        expect(
          CashFlowModel.impliedGrowth(100, target: target, discountRate: 0.09),
          closeTo(growth, 0.0001),
          reason: 'did not recover $growth',
        );
      }
    });

    test('declines to answer outside a sane band', () {
      // A price no plausible growth rate reaches gets no number rather than a
      // pinned one at the edge of the search.
      expect(
        CashFlowModel.impliedGrowth(100, target: 1e9, discountRate: 0.09),
        isNull,
      );
      expect(
        CashFlowModel.impliedGrowth(100, target: 1, discountRate: 0.09),
        isNull,
      );
      expect(
        CashFlowModel.impliedGrowth(-100, target: 1000, discountRate: 0.09),
        isNull,
      );
    });
  });

  group('what the price is asking', () {
    test('reads back the growth a price was built from', () {
      final snapshot = _snapshot(growth: 0.10, margin: 0.20);
      final base = snapshot.latest.revenue! * 0.20;
      final marketCap = CashFlowModel.presentValue(
        base,
        growth: 0.12,
        discountRate: CashFlowModel.defaultDiscountRate,
      );

      final expectation = GrowthExpectation.of(snapshot, marketCap)!;

      expect(expectation.normalisedCashFlow, closeTo(base, 1));
      expect(expectation.medianCashFlowMargin, closeTo(20, 0.01));
      expect(expectation.requiredGrowthPercent, closeTo(12, 0.01));
      expect(expectation.deliveredGrowthPercent, closeTo(10, 0.01));
      expect(expectation.deliveredOverYears, 10);
    });

    test('normalises away a year the business did not really have', () {
      // A capex spike or a one-off tax bill halves the reported figure; the
      // base should barely move, because the median margin does not.
      final normal = GrowthExpectation.of(_snapshot(), 1e12)!;
      final distorted = GrowthExpectation.of(
        _snapshot(finalCashFlow: 10 * _million),
        1e12,
      )!;

      expect(distorted.normalisedCashFlow, normal.normalisedCashFlow);
      expect(distorted.reportedCashFlow, 10 * _million);
      // Reported is far below the base, and the report says by how much.
      expect(distorted.normalisationEffectPercent, lessThan(-90));
    });

    test('calls a price asking beyond the record', () {
      final snapshot = _snapshot(growth: 0.05, margin: 0.20);
      final base = snapshot.latest.revenue! * 0.20;
      // Priced for 20% by a buyer who would settle for the lowest return in
      // the band, against a company that has managed 5%.
      final marketCap = CashFlowModel.presentValue(
        base,
        growth: 0.20,
        discountRate: CashFlowModel.discountRates.first,
      );

      final expectation = GrowthExpectation.of(snapshot, marketCap)!;
      expect(expectation.verdict, ExpectationVerdict.beyondRecord);
    });

    test('calls a price asking less than the record', () {
      final snapshot = _snapshot(growth: 0.20, margin: 0.20);
      final base = snapshot.latest.revenue! * 0.20;
      // Even the most demanding buyer in the band needs only 5% from a company
      // that has compounded at 20%.
      final marketCap = CashFlowModel.presentValue(
        base,
        growth: 0.05,
        discountRate: CashFlowModel.discountRates.last,
      );

      final expectation = GrowthExpectation.of(snapshot, marketCap)!;
      expect(expectation.verdict, ExpectationVerdict.belowRecord);
    });

    test('shows the answer across the whole discount band', () {
      final snapshot = _snapshot();
      // Priced at a multiple every rate in the band can actually solve for.
      final marketCap = snapshot.latest.revenue! * 0.20 * 25;
      final expectation = GrowthExpectation.of(snapshot, marketCap)!;
      final band = expectation.sensitivity;

      expect(band.length, CashFlowModel.discountRates.length);
      // A buyer wanting more return needs more growth to justify one price.
      for (var i = 1; i < band.length; i++) {
        expect(band[i].growthPercent, greaterThan(band[i - 1].growthPercent!));
      }
    });

    test('values a share at the record, capped for the hypergrowers', () {
      final wild = GrowthExpectation.of(_snapshot(growth: 0.60), 1e12)!;
      final capped = GrowthExpectation.of(
        _snapshot(growth: CashFlowModel.maximumCreditedGrowth),
        1e12,
      )!;

      // 60% a year is not extrapolated for a decade; both are valued at the
      // ceiling, so the only difference left is their own revenue base.
      expect(wild.deliveredGrowthPercent, closeTo(60, 0.01));
      final wildPerUnit =
          wild.equityValues(_shares).first.value / wild.normalisedCashFlow;
      final cappedPerUnit =
          capped.equityValues(_shares).first.value / capped.normalisedCashFlow;
      expect(wildPerUnit, closeTo(cappedPerUnit, 1e-9));
    });

    test('declines where there is nothing to discount', () {
      expect(GrowthExpectation.of(_snapshot(), 0), isNull);
      expect(GrowthExpectation.of(_snapshot(margin: -0.1), 1e10), isNull);
    });
  });
}
