import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/snapshot/trailing_figures.dart';
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
  double parentStake = 1,
  TrailingFigures? trailing,
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
        // The group's profit and the listed shares' part of it, from which
        // the stake is read.
        netIncome: isLast && parentStake < 1
            ? 10 * _million * parentStake
            : null,
        profitLoss: isLast && parentStake < 1 ? 10 * _million : null,
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
    trailing: trailing,
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

    test('holds a shrinking record to the same floor as the targets', () {
      // A business shrinking 30% a year is valued as a bad decade, not a
      // wind-up — the same -10% the bear target and the band are held to.
      final shrinking = GrowthExpectation.of(_snapshot(growth: -0.30), 1e9)!;
      final floored = GrowthExpectation.of(
        _snapshot(growth: CashFlowModel.minimumCreditedGrowth),
        1e9,
      )!;

      expect(shrinking.deliveredGrowthPercent, closeTo(-30, 0.01));
      final shrinkingPerUnit =
          shrinking.equityValues(_shares).first.value /
          shrinking.normalisedCashFlow;
      final flooredPerUnit =
          floored.equityValues(_shares).first.value /
          floored.normalisedCashFlow;
      expect(shrinkingPerUnit, closeTo(flooredPerUnit, 1e-9));
    });

    test('declines where there is nothing to discount', () {
      expect(GrowthExpectation.of(_snapshot(), 0), isNull);
      expect(GrowthExpectation.of(_snapshot(margin: -0.1), 1e10), isNull);
    });
  });

  group('a business the listed shares only part own', () {
    // A tenth of the group's profit is the listed shares': the rest belongs
    // to owners outside the company, as MarketWise's Class B unitholders.
    final whole = GrowthExpectation.of(_snapshot(), 1e10)!;
    final tenth = GrowthExpectation.of(_snapshot(parentStake: 0.1), 1e10)!;

    test('discounts only the cash that reaches those shares', () {
      expect(whole.hasOutsideOwners, isFalse);
      expect(tenth.hasOutsideOwners, isTrue);
      expect(tenth.parentStake, closeTo(0.1, 1e-9));
      expect(tenth.groupCashFlow, whole.groupCashFlow);
      expect(
        tenth.normalisedCashFlow,
        closeTo(whole.normalisedCashFlow * 0.1, 1),
      );
    });

    test('so the targets and the worth row are the stake\'s too', () {
      final wholeTargets = whole.priceTargets(_shares);
      final tenthTargets = tenth.priceTargets(_shares);
      for (var i = 0; i < wholeTargets.length; i++) {
        expect(
          tenthTargets[i].valuePerShare,
          closeTo(wholeTargets[i].valuePerShare * 0.1, 1e-6),
        );
      }
      expect(
        tenth.equityValues(_shares).first.value,
        closeTo(whole.equityValues(_shares).first.value * 0.1, 1e-6),
      );
    });

    test('and the price has to ask more growth of a smaller stream', () {
      expect(
        tenth.requiredGrowthPercent!,
        greaterThan(whole.requiredGrowthPercent!),
      );
    });

    test('while the year as filed is still set against the group', () {
      // Both figures are the whole group's, so the stake does not move the
      // gap between them.
      final distorted = GrowthExpectation.of(
        _snapshot(finalCashFlow: 10 * _million, parentStake: 0.1),
        1e10,
      )!;
      final plain = GrowthExpectation.of(
        _snapshot(finalCashFlow: 10 * _million),
        1e10,
      )!;
      expect(
        distorted.normalisationEffectPercent,
        closeTo(plain.normalisationEffectPercent!, 1e-9),
      );
    });

    test('and the year as filed is shown at the stake beside the stake', () {
      // The card reads the discounted figure and the year as filed one under
      // the other; at a tenth each, the gap between them is the group's gap.
      final distorted = GrowthExpectation.of(
        _snapshot(finalCashFlow: 10 * _million, parentStake: 0.1),
        1e10,
      )!;
      final shown = distorted.reportedStakeCashFlow!;
      expect(shown, closeTo(distorted.reportedCashFlow! * 0.1, 1e-6));
      expect(
        (shown - distorted.normalisedCashFlow) /
            distorted.normalisedCashFlow *
            100,
        closeTo(distorted.normalisationEffectPercent!, 1e-9),
      );
    });

    test('and the sales the cash comes from are the group\'s', () {
      expect(tenth.revenue, closeTo(whole.revenue, 1));
      expect(
        tenth.revenue * tenth.medianCashFlowMargin / 100,
        closeTo(tenth.groupCashFlow, 1),
      );
    });
  });

  group('the sales the cash is scaled to', () {
    test('are the latest fiscal year\'s without a newer quarter', () {
      final expectation = GrowthExpectation.of(_snapshot(), 1e10)!;
      expect(expectation.revenue, closeTo(_snapshot().latest.revenue!, 1));
      expect(expectation.revenueThrough, isNull);
    });

    test('and the twelve months to the quarter where one supplied them', () {
      final quarter = DateTime(2026, 9, 30);
      final expectation = GrowthExpectation.of(
        _snapshot(
          trailing: TrailingFigures(
            periodEnd: quarter,
            fiscalYear: 2026,
            quarter: 3,
            revenue: 5000 * _million,
          ),
        ),
        1e10,
      )!;
      expect(expectation.revenue, closeTo(5000 * _million, 1));
      expect(expectation.revenueThrough, quarter);
    });

    test('but not where the quarter carried only its balance sheet', () {
      final expectation = GrowthExpectation.of(
        _snapshot(
          trailing: TrailingFigures(
            periodEnd: DateTime(2026, 9, 30),
            fiscalYear: 2026,
            quarter: 3,
            totalDebt: 10 * _million,
            cash: 5 * _million,
          ),
        ),
        1e10,
      )!;
      expect(expectation.revenueThrough, isNull);
    });
  });
}
