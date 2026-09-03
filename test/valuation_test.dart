import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/valuation/cash_flow_model.dart';
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
  group('what counts as profit', () {
    /// Lyft's FY2025: an operating loss, a pre-tax loss, and $2.844B of net
    /// income from releasing a deferred tax allowance.
    FinancialSnapshot lyft({double? operatingIncome = -188.4 * _million}) =>
        FinancialSnapshot(
          company: const Company(
            ticker: 'LYFT',
            cik: '0001759509',
            name: 'Lyft, Inc.',
            sharesOutstanding: 378.5 * _million,
          ),
          years: [
            const FiscalYearFigures(fiscalYear: 2024, revenue: 5366 * _million),
            FiscalYearFigures(
              fiscalYear: 2025,
              revenue: 5895 * _million,
              priorRevenue: 5366 * _million,
              netIncome: 2844 * _million,
              operatingIncome: operatingIncome,
              // Lyft tags no capital spending concept at all, so there is no
              // free cash flow to prefer and the basis falls to profit.
              operatingCashFlow: 1168 * _million,
              cash: 2000 * _million,
              totalDebt: 0,
              dilutedShares: 378.5 * _million,
            ),
          ],
        );

    test('is no more than the business itself made', () {
      final valuation = Valuation(snapshot: lyft(), pricePerShare: 17.28);

      // Valued on the $2.844B, a share came out at $203 to $248 against a
      // price of $17 — a thirteen-fold upside, in a year the business lost
      // money. Held to the operating loss there is nothing to value.
      expect(valuation.basis, isNull);
      expect(valuation.basisAmount, isNull);
      expect(valuation.fairValueLow, isNull);
      expect(valuation.fairValueHigh, isNull);
    });

    test('and is left alone where the business earned it', () {
      // Operating income is struck before tax and financing, so a company
      // earning its way reports less profit than operating income, and the
      // ceiling never binds.
      final snapshot = _snapshot(netIncome: 100 * _million);
      final valuation = Valuation(snapshot: snapshot, pricePerShare: 100);
      expect(valuation.basis, ValuationBasis.freeCashFlow);

      final noCash = Valuation(
        snapshot: lyft(operatingIncome: 3000 * _million),
        pricePerShare: 17.28,
      );
      expect(noCash.basis, ValuationBasis.earnings);
      expect(noCash.basisAmount, 2844 * _million);
    });

    test('a filer that states no operating income is taken at its word', () {
      // Nothing to check the profit against, so nothing is done to it: the
      // ceiling is a guard against a figure the filings contradict, not a
      // requirement that they carry one.
      final valuation = Valuation(
        snapshot: lyft(operatingIncome: null),
        pricePerShare: 17.28,
      );
      expect(valuation.basis, ValuationBasis.earnings);
      expect(valuation.basisAmount, 2844 * _million);
    });
  });

  group('the growth the multiple pays for', () {
    /// Zoom's own filings, in billions: a pandemic year and then five years
    /// of very little.
    FinancialSnapshot zoom() => FinancialSnapshot(
      company: const Company(
        ticker: 'ZM',
        cik: '0001585521',
        name: 'Zoom Communications, Inc.',
        sharesOutstanding: 300 * _million,
      ),
      years: [
        for (final (year, revenue) in const [
          (2021, 2.651),
          (2022, 4.100),
          (2023, 4.393),
          (2024, 4.527),
          (2025, 4.665),
          (2026, 4.869),
        ])
          FiscalYearFigures(
            fiscalYear: year,
            revenue: revenue * 1000 * _million,
            priorRevenue: switch (year) {
              2021 => null,
              2022 => 2.651 * 1000 * _million,
              2023 => 4.100 * 1000 * _million,
              2024 => 4.393 * 1000 * _million,
              2025 => 4.527 * 1000 * _million,
              _ => 4.665 * 1000 * _million,
            },
            netIncome: 1000 * _million,
            operatingCashFlow: 1900 * _million,
            capitalExpenditure: 100 * _million,
            cash: 7000 * _million,
            totalDebt: 0,
            dilutedShares: 300 * _million,
          ),
      ],
    );

    test('is not a spike at the far end of the window', () {
      final valuation = Valuation(snapshot: zoom(), pricePerShare: 80);

      // $2.65B to $4.87B over five years annualises to 12.9%, and all of it
      // is the tail of one pandemic year. The report's own overview says
      // 4.4% at the top of the page, and the worked example below it used to
      // say 12.9% — the same company, growing at two different rates.
      expect(valuation.revenueGrowthPercent, closeTo(4.4, 0.1));
      expect(valuation.creditedGrowthPercent, closeTo(4.4, 0.1));
      expect(valuation.growthWindowYears, 5);

      // Which the model pays about two and a half more years of cash for,
      // where the annualised rate would have bought nearly ten.
      expect(
        valuation.centralMultiple - valuation.flatMultiple,
        closeTo(3.1, 0.2),
      );
    });

    test('nor is a climb undone by one flat year at the end of it', () {
      // The mirror image of Zoom, and why this is a median rather than
      // simply the latest year: four years of steady growth and then a pause.
      // The pause is one year of five, so it moves the middle year not at
      // all — where reading the latest year alone would price the climb away.
      final steady = FinancialSnapshot(
        company: const Company(
          ticker: 'STDY',
          cik: '0000000002',
          name: 'Steady Corp',
          sharesOutstanding: 10 * _million,
        ),
        years: [
          for (final (year, revenue, prior) in const [
            (2021, 1000.0, null),
            (2022, 1100.0, 1000.0),
            (2023, 1210.0, 1100.0),
            (2024, 1331.0, 1210.0),
            (2025, 1464.0, 1331.0),
            (2026, 1464.0, 1464.0),
          ])
            FiscalYearFigures(
              fiscalYear: year,
              revenue: revenue * _million,
              priorRevenue: prior == null ? null : prior * _million,
              netIncome: 100 * _million,
              operatingCashFlow: 120 * _million,
              capitalExpenditure: 20 * _million,
              cash: 10 * _million,
              totalDebt: 0,
              dilutedShares: 10 * _million,
            ),
        ],
      );

      final valuation = Valuation(snapshot: steady, pricePerShare: 100);
      // Rates of 10, 10, 10, 10 and 0: the middle one is 10.
      expect(valuation.creditedGrowthPercent, closeTo(10, 0.1));
      expect(valuation.growthWindowYears, 5);
    });

    test('a filer with two years on file has one year to be typical', () {
      final snapshot = _snapshot(
        startRevenue: 1000 * _million,
        endRevenue: 1300 * _million,
      );
      final valuation = Valuation(snapshot: snapshot, pricePerShare: 100);
      // One rate, so it is its own median — and 30% is exactly the cap.
      expect(valuation.growthWindowYears, 1);
      expect(
        valuation.creditedGrowthPercent,
        closeTo(CashFlowModel.maximumCreditedGrowth * 100, 0.1),
      );
    });
  });

  group('valuation arithmetic', () {
    test('values the shares on the cash that reaches them', () {
      final valuation = Valuation(snapshot: _snapshot(), pricePerShare: 100);

      expect(valuation.basis, ValuationBasis.freeCashFlow);
      expect(valuation.basisAmount, 100 * _million);
      // Flat revenue earns nothing for growth, so the band is what a buyer
      // wanting 9% pays for a stream that never grows — 14.1 years of it,
      // widened by a point either side of that return.
      expect(valuation.flatMultiple, closeTo(14.08, 0.01));
      expect(valuation.lowMultiple, closeTo(12.24, 0.01));
      expect(valuation.highMultiple, closeTo(16.59, 0.01));
      // 100m x 12.24 over 10m shares. No net-debt adjustment: the cash flow
      // is already after the interest the lenders take.
      expect(valuation.fairValueLow, closeTo(122.37, 0.01));
      expect(valuation.fairValueHigh, closeTo(165.94, 0.01));
      // How far a $100 price sits below each bound.
      expect(valuation.percentToLow, closeTo(22.37, 0.01));
      expect(valuation.percentToHigh, closeTo(65.94, 0.01));
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

      // The band is 122 to 166 against a price of 100.
      expect(valuation.percentToLow, closeTo(22.37, 0.01));
      expect(valuation.percentToHigh, closeTo(65.94, 0.01));

      // Above the band both readings turn negative: the price has to fall.
      final dear = Valuation(snapshot: _snapshot(), pricePerShare: 200);
      expect(dear.percentToLow, closeTo(-38.81, 0.01));
      expect(dear.percentToHigh, closeTo(-17.03, 0.01));
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
      // Growth is paid for by the model rather than by a premium per point:
      // ten per cent fading to 2.5 is worth six more years than flat.
      expect(growing.centralMultiple, greaterThan(growing.flatMultiple));
      expect(growing.centralMultiple - growing.flatMultiple, closeTo(7.9, 0.3));

      // Quadrupling is not credited past the ceiling.
      final soaring = Valuation(
        snapshot: _snapshot(
          startRevenue: 1000 * _million,
          endRevenue: 4000 * _million,
        ),
        pricePerShare: 100,
      );
      expect(
        soaring.creditedGrowthPercent,
        CashFlowModel.maximumCreditedGrowth * 100,
      );
      expect(soaring.highMultiple, closeTo(62.41, 0.1));

      // A shrinking business gets no discount either — the flat band stands.
      final shrinking = Valuation(
        snapshot: _snapshot(
          startRevenue: 1000 * _million,
          endRevenue: 500 * _million,
        ),
        pricePerShare: 100,
      );
      expect(shrinking.creditedGrowthPercent, 0);
      // The no-growth multiple, not something below it.
      expect(shrinking.lowMultiple, closeTo(12.24, 0.01));
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

    test('does not charge for the same debt twice', () {
      // Free cash flow is operating cash flow less capital spending, and US
      // filers put interest paid in the operating section — so the lenders
      // have already been paid out of it. Subtracting their principal from a
      // multiple of it as well would penalise the debt a second time, and the
      // band would move with debt the cash flow has already accounted for.
      final borrowed = Valuation(
        snapshot: _snapshot(totalDebt: 5000 * _million),
        pricePerShare: 100,
      );
      final debtFree = Valuation(
        snapshot: _snapshot(totalDebt: 0, cash: 0),
        pricePerShare: 100,
      );

      expect(borrowed.fairValueLow, debtFree.fairValueLow);
      expect(borrowed.fairValueHigh, debtFree.fairValueHigh);
      // The debt is still reported; it just is not double counted. Net of the
      // fixture's 10m of cash.
      expect(borrowed.netDebt, 4990 * _million);
      expect(borrowed.enterpriseValue, greaterThan(borrowed.marketCap!));
    });

    test('derives the market and enterprise figures from the share count', () {
      final valuation = Valuation(snapshot: _snapshot(), pricePerShare: 100);

      expect(valuation.marketCap, 1000 * _million);
      // Net debt of 40m is added: an acquirer takes it on.
      expect(valuation.enterpriseValue, 1040 * _million);
      expect(valuation.earningsPerShare, closeTo(10, 0.001));
      expect(valuation.priceEarningsRatio, closeTo(10, 0.001));
      expect(valuation.priceToFreeCashFlow, closeTo(10, 0.001));
      expect(valuation.freeCashFlowYieldPercent, closeTo(10, 0.001));
      expect(valuation.priceToSalesRatio, closeTo(1, 0.001));
    });

    test('a net cash pile lowers what an acquirer would pay', () {
      final netCash = Valuation(
        snapshot: _snapshot(totalDebt: 10 * _million, cash: 50 * _million),
        pricePerShare: 100,
      );

      // The enterprise value nets the surplus cash off the market value; the
      // band itself is struck on the cash flow alone.
      expect(netCash.enterpriseValue, 960 * _million);
      expect(netCash.fairValueLow, closeTo(122.37, 0.01));
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
