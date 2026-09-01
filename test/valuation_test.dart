import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/valuation/valuation.dart';
import 'package:pickstock/data/valuation/valuation_basis.dart';
import 'package:pickstock/data/valuation/valuation_metric.dart';
import 'package:pickstock/data/valuation/valuation_verdict.dart';
import 'package:pickstock/repo/format_repo.dart';

const double _million = 1000000;

/// A profitable, slowly growing filer: two years apart so the growth window is
/// unambiguous, and figures round enough to check by hand.
FinancialSnapshot _snapshot({
  double? netIncome = 100 * _million,
  double? operatingCashFlow = 120 * _million,
  double? capitalExpenditure = 20 * _million,
  double? totalDebt = 50 * _million,
  double? cash = 10 * _million,
  double? sharesOutstanding = 10 * _million,
  double? dilutedShares = 10 * _million,
  double startRevenue = 1000 * _million,
  double endRevenue = 1000 * _million,
}) {
  return FinancialSnapshot(
    company: Company(
      ticker: 'TEST',
      cik: '0000000001',
      name: 'Test Corp',
      sharesOutstanding: sharesOutstanding,
    ),
    years: [
      FiscalYearFigures(fiscalYear: 2024, revenue: startRevenue),
      FiscalYearFigures(
        fiscalYear: 2025,
        revenue: endRevenue,
        priorRevenue: startRevenue,
        netIncome: netIncome,
        operatingCashFlow: operatingCashFlow,
        capitalExpenditure: capitalExpenditure,
        totalDebt: totalDebt,
        cash: cash,
        dilutedShares: dilutedShares,
      ),
    ],
  );
}

void main() {
  group('valuation arithmetic', () {
    test('values the business on free cash flow, less what lenders own', () {
      final valuation = Valuation(snapshot: _snapshot(), pricePerShare: 100);

      expect(valuation.basis, ValuationBasis.freeCashFlow);
      expect(valuation.basisAmount, 100 * _million);
      // Flat revenue earns no premium, so the band is the base 12x to 18x.
      expect(valuation.growthPremiumMultiple, 0);
      expect(valuation.lowMultiple, 12);
      expect(valuation.highMultiple, 18);
      // 100m x 12 = 1.2bn of business, less 40m net debt, over 10m shares.
      expect(valuation.fairValueLow, closeTo(116, 0.01));
      expect(valuation.fairValueHigh, closeTo(176, 0.01));
      expect(valuation.percentToLow, closeTo(16, 0.01));
      expect(valuation.percentToHigh, closeTo(76, 0.01));
    });

    test('places the price against the band', () {
      expect(
        Valuation(snapshot: _snapshot(), pricePerShare: 100).verdict,
        ValuationVerdict.undervalued,
      );
      expect(
        Valuation(snapshot: _snapshot(), pricePerShare: 146).verdict,
        ValuationVerdict.fairlyValued,
      );
      expect(
        Valuation(snapshot: _snapshot(), pricePerShare: 200).verdict,
        ValuationVerdict.overvalued,
      );
    });

    test('measures the distance to each end of the band', () {
      final valuation = Valuation(snapshot: _snapshot(), pricePerShare: 100);

      // The band is 116 to 176 against a price of 100.
      expect(valuation.percentToLow, closeTo(16, 0.01));
      expect(valuation.percentToHigh, closeTo(76, 0.01));

      // Above the band both readings turn negative: the price has to fall.
      final dear = Valuation(snapshot: _snapshot(), pricePerShare: 200);
      expect(dear.percentToLow, closeTo(-42, 0.01));
      expect(dear.percentToHigh, closeTo(-12, 0.01));
    });

    test('pays for growth, but only up to the credited ceiling', () {
      // Ten percent over the one year the fixture spans.
      final growing = Valuation(
        snapshot: _snapshot(
          startRevenue: 1000 * _million,
          endRevenue: 1100 * _million,
        ),
        pricePerShare: 100,
      );
      expect(growing.revenueGrowthPercent, closeTo(10, 0.01));
      expect(growing.growthPremiumMultiple, closeTo(6, 0.01));
      expect(growing.lowMultiple, closeTo(18, 0.01));

      // Quadrupling is not credited past the ceiling.
      final soaring = Valuation(
        snapshot: _snapshot(
          startRevenue: 1000 * _million,
          endRevenue: 4000 * _million,
        ),
        pricePerShare: 100,
      );
      expect(soaring.creditedGrowthPercent, 25);
      expect(soaring.highMultiple, closeTo(33, 0.01));

      // A shrinking business gets no discount either — the base band stands.
      final shrinking = Valuation(
        snapshot: _snapshot(
          startRevenue: 1000 * _million,
          endRevenue: 500 * _million,
        ),
        pricePerShare: 100,
      );
      expect(shrinking.creditedGrowthPercent, 0);
      expect(shrinking.lowMultiple, 12);
    });

    test('falls back to net income where there is no free cash flow', () {
      final valuation = Valuation(
        snapshot: _snapshot(operatingCashFlow: null),
        pricePerShare: 100,
      );

      expect(valuation.basis, ValuationBasis.earnings);
      expect(valuation.basisAmount, 100 * _million);
      expect(valuation.freeCashFlowYieldPercent, isNull);
      expect(valuation.verdict, ValuationVerdict.undervalued);
    });

    test('refuses to value a business that earns nothing', () {
      final valuation = Valuation(
        snapshot: _snapshot(
          netIncome: -30 * _million,
          operatingCashFlow: 5 * _million,
          capitalExpenditure: 40 * _million,
        ),
        pricePerShare: 100,
      );

      expect(valuation.basis, isNull);
      expect(valuation.fairValueLow, isNull);
      expect(valuation.verdict, ValuationVerdict.unknown);
    });

    test('a business worth less than its debts bottoms out at nothing', () {
      final valuation = Valuation(
        snapshot: _snapshot(totalDebt: 5000 * _million),
        pricePerShare: 100,
      );

      expect(valuation.fairValueLow, 0);
      expect(valuation.fairValueHigh, 0);
      expect(valuation.verdict, ValuationVerdict.overvalued);
    });

    test('derives the market and enterprise figures from the share count', () {
      final valuation = Valuation(snapshot: _snapshot(), pricePerShare: 100);

      expect(valuation.marketCap, 1000 * _million);
      // Net debt of 40m is added: an acquirer takes it on.
      expect(valuation.enterpriseValue, 1040 * _million);
      expect(valuation.earningsPerShare, closeTo(10, 0.001));
      expect(valuation.priceEarningsRatio, closeTo(10, 0.001));
      expect(valuation.enterpriseValueToFreeCashFlow, closeTo(10.4, 0.001));
      expect(valuation.freeCashFlowYieldPercent, closeTo(10, 0.001));
      expect(valuation.priceToSalesRatio, closeTo(1, 0.001));
    });

    test('a net cash pile is handed back, raising the per-share value', () {
      final netCash = Valuation(
        snapshot: _snapshot(totalDebt: 10 * _million, cash: 50 * _million),
        pricePerShare: 100,
      );

      // 1.2bn plus 40m of surplus cash, over 10m shares.
      expect(netCash.fairValueLow, closeTo(124, 0.01));
      expect(netCash.enterpriseValue, 960 * _million);
    });

    test('leaves ratios unstated rather than meaningless at a loss', () {
      final valuation = Valuation(
        snapshot: _snapshot(netIncome: -50 * _million),
        pricePerShare: 100,
      );

      expect(valuation.earningsPerShare, closeTo(-5, 0.001));
      expect(valuation.priceEarningsRatio, isNull);
      expect(valuation.growthAdjustedRatio, isNull);
      // Cash flow is unaffected by the accounting loss.
      expect(valuation.freeCashFlowYieldPercent, closeTo(10, 0.001));
    });

    test('cannot value a filer that reports no share count', () {
      final valuation = Valuation(
        snapshot: _snapshot(sharesOutstanding: null, dilutedShares: null),
        pricePerShare: 100,
      );

      expect(valuation.marketCap, isNull);
      expect(valuation.fairValueLow, isNull);
      expect(valuation.verdict, ValuationVerdict.unknown);
    });

    test('stands in one share count for the other', () {
      final coverOnly = Valuation(
        snapshot: _snapshot(dilutedShares: null),
        pricePerShare: 100,
      );
      expect(coverOnly.earningsPerShare, closeTo(10, 0.001));

      final dilutedOnly = Valuation(
        snapshot: _snapshot(sharesOutstanding: null),
        pricePerShare: 100,
      );
      expect(dilutedOnly.marketCap, 1000 * _million);
    });
  });

  group('supporting ratios', () {
    // Only the formatter is needed here: the ratios are arithmetic, not a
    // trip through the database.
    setUp(() => GetIt.I.registerLazySingleton<FormatRepo>(FormatRepo.new));

    tearDown(GetIt.I.reset);

    test('reads a low multiple as cheap and a high one as dear', () {
      final cheap = Valuation(snapshot: _snapshot(), pricePerShare: 100);
      expect(ValuationMetric.priceEarnings.getSentiment(cheap), isTrue);
      expect(ValuationMetric.priceEarnings.getFormattedValue(cheap), '10.0');

      final dear = Valuation(snapshot: _snapshot(), pricePerShare: 400);
      expect(ValuationMetric.priceEarnings.getSentiment(dear), isFalse);
      expect(ValuationMetric.priceEarnings.getFormattedValue(dear), '40.0');

      final fair = Valuation(snapshot: _snapshot(), pricePerShare: 200);
      expect(ValuationMetric.priceEarnings.getSentiment(fair), isNull);
    });

    test('reads a yield the other way round: more is cheaper', () {
      final highYield = Valuation(snapshot: _snapshot(), pricePerShare: 100);
      expect(ValuationMetric.freeCashFlowYield.getSentiment(highYield), isTrue);
      expect(
        ValuationMetric.freeCashFlowYield.getFormattedValue(highYield),
        '10.0%',
      );

      final lowYield = Valuation(snapshot: _snapshot(), pricePerShare: 500);
      expect(ValuationMetric.freeCashFlowYield.getSentiment(lowYield), isFalse);
    });

    test('states nothing where a ratio cannot be struck', () {
      final loss = Valuation(
        snapshot: _snapshot(netIncome: -50 * _million),
        pricePerShare: 100,
      );
      expect(ValuationMetric.priceEarnings.getFormattedValue(loss), isNull);
      expect(ValuationMetric.priceEarnings.getSentiment(loss), isNull);
    });

    test('rounds an absurd multiple whole rather than to a decimal', () {
      expect(GetIt.I.get<FormatRepo>().ratio(412.34), '412');
      expect(GetIt.I.get<FormatRepo>().ratio(41.234), '41.2');
    });
  });
}
