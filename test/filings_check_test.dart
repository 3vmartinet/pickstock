import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/data/research/filings_check.dart';
import 'package:pickstock/data/research/framework_question.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/snapshot/trailing_figures.dart';

const Company _company = Company(
  ticker: 'T',
  cik: '1',
  name: 'Test',
  sic: 3571,
);
const Company _bank = Company(ticker: 'B', cik: '2', name: 'Bank', sic: 6021);

/// Four years from [revenues], with whatever else each year is given.
FinancialSnapshot _years(
  List<double> revenues, {
  Company company = _company,
  List<double?>? operating,
  List<double?>? gross,
  List<double?>? cash,
  List<double?>? capex,
  List<double?>? income,
  List<double?>? impairment,
  double? interest,
  double? debt,
  double? held,
  TrailingFigures? trailing,
}) {
  final last = revenues.length - 1;
  return FinancialSnapshot(
    company: company,
    trailing: trailing,
    years: [
      for (var i = 0; i <= last; i++)
        FiscalYearFigures(
          fiscalYear: 2022 + i,
          revenue: revenues[i],
          priorRevenue: i == 0 ? null : revenues[i - 1],
          operatingIncome: operating?[i],
          grossProfit: gross?[i],
          operatingCashFlow: cash?[i],
          capitalExpenditure: capex?[i] ?? (cash == null ? null : 0),
          netIncome: income?[i],
          impairment: impairment?[i],
          interestExpense: i == last ? interest : null,
          totalDebt: i == last ? debt : null,
          cash: i == last ? held : null,
        ),
    ],
  );
}

FilingsReading? _check(FrameworkQuestion question, FinancialSnapshot s) =>
    FilingsCheck.of(question, s);

void main() {
  group('growth', () {
    test('is a yes for revenue rising over three years and still rising', () {
      final reading = _check(
        FrameworkQuestion.growth,
        _years([100, 110, 121, 133]),
      )!;
      expect(reading.verdict, FrameworkVerdict.yes);
      expect(reading.figures.single, closeTo(10, 0.1));
    });

    test('is a no for growth below inflation', () {
      expect(
        _check(FrameworkQuestion.growth, _years([100, 101, 102, 103]))!.reason,
        FilingsReason.notGrowing,
      );
    });

    test('is a no for a weak trend the latest year reverses', () {
      final reading = _check(
        FrameworkQuestion.growth,
        _years([100, 108, 118, 111]),
      )!;
      expect(reading.verdict, FrameworkVerdict.no);
      expect(reading.reason, FilingsReason.reversing);
    });

    test('leaves a dip in a strong rise unsettled', () {
      expect(
        _check(FrameworkQuestion.growth, _years([100, 130, 160, 150]))!.verdict,
        FrameworkVerdict.unclear,
      );
    });

    test('leaves a fall that may be a business sold to the reading', () {
      expect(
        _check(FrameworkQuestion.growth, _years([100, 120, 80, 90])),
        isNull,
      );
    });

    test('needs four years', () {
      expect(_check(FrameworkQuestion.growth, _years([100, 110, 120])), isNull);
    });
  });

  group('margins', () {
    test('holding is a yes', () {
      expect(
        _check(
          FrameworkQuestion.margins,
          _years([100, 100, 100, 100], operating: [20, 20, 20, 19.5]),
        )!.verdict,
        FrameworkVerdict.yes,
      );
    });

    test('falling three points is a no', () {
      expect(
        _check(
          FrameworkQuestion.margins,
          _years([100, 100, 100, 100], operating: [30, 28, 26, 24]),
        )!.reason,
        FilingsReason.marginsFalling,
      );
    });

    test('gross margin falling under a steady operating margin is a no', () {
      expect(
        _check(
          FrameworkQuestion.margins,
          _years(
            [100, 100, 100, 100],
            operating: [20, 20, 20, 20],
            gross: [50, 48, 46, 44],
          ),
        )!.verdict,
        FrameworkVerdict.no,
      );
    });

    test('judges a year with a write-down on the margin before it', () {
      // Crocs' shape: the charge takes the margin from 22% to 4% as filed.
      expect(
        _check(
          FrameworkQuestion.margins,
          _years(
            [100, 100, 100, 100],
            operating: [22, 22, 22, 4],
            impairment: [null, null, null, 18],
          ),
        )!.verdict,
        FrameworkVerdict.yes,
      );
    });

    test('says nothing about a bank', () {
      expect(
        _check(
          FrameworkQuestion.margins,
          _years(
            [100, 100, 100, 100],
            operating: [30, 20, 10, 5],
            company: _bank,
          ),
        ),
        isNull,
      );
    });
  });

  group('cash', () {
    test('profit arriving as cash is a yes', () {
      final reading = _check(
        FrameworkQuestion.cash,
        _years(
          [100, 100, 100, 100],
          cash: [20, 20, 20, 20],
          capex: [5, 5, 5, 5],
          income: [15, 15, 15, 15],
        ),
      )!;
      expect(reading.verdict, FrameworkVerdict.yes);
      expect(reading.figures.single, closeTo(20 / 15, 1e-9));
    });

    test('burning cash is a no', () {
      expect(
        _check(
          FrameworkQuestion.cash,
          _years(
            [100, 100, 100, 100],
            cash: [5, -5, -10, -2],
            income: [1, 1, 1, 1],
          ),
        )!.reason,
        FilingsReason.cashBurning,
      );
    });

    test('profit that never becomes cash is a no', () {
      expect(
        _check(
          FrameworkQuestion.cash,
          _years(
            [100, 100, 100, 100],
            cash: [4, 4, 4, 4],
            income: [20, 20, 20, 20],
          ),
        )!.reason,
        FilingsReason.profitNotCash,
      );
    });

    test('a loss made by a write-down is not profit failing to be cash', () {
      expect(
        _check(
          FrameworkQuestion.cash,
          _years(
            [100, 100, 100, 100],
            cash: [20, 20, 20, 20],
            income: [15, 15, 15, -60],
            impairment: [null, null, null, 75],
          ),
        )!.verdict,
        FrameworkVerdict.yes,
      );
    });
  });

  group('risk', () {
    test('thin interest cover with no spare cash is a no', () {
      expect(
        _check(
          FrameworkQuestion.risk,
          _years(
            [100, 100, 100, 100],
            operating: [10, 10, 10, 10],
            cash: [-1, -1, -1, -1],
            interest: 8,
            debt: 50,
            held: 0,
          ),
        )!.reason,
        FilingsReason.interestUncovered,
      );
    });

    test('thin interest cover paid from spare cash is left to the reading', () {
      // Ford's shape: the interest is mostly its lending arm's.
      expect(
        _check(
          FrameworkQuestion.risk,
          _years(
            [100, 100, 100, 100],
            operating: [2, 2, 2, 2],
            cash: [15, 15, 15, 15],
            interest: 8,
            debt: 50,
            held: 0,
          ),
        ),
        isNull,
      );
    });

    test(
      'debt beyond both eight years of cash and five of earnings is a no',
      () {
        final reading = _check(
          FrameworkQuestion.risk,
          _years(
            [100, 100, 100, 100],
            operating: [3, 3, 3, 3],
            cash: [10, 10, 10, 10],
            debt: 100,
            held: 0,
          ),
        )!;
        expect(reading.reason, FilingsReason.debtBeyondCash);
        expect(reading.figures, [closeTo(10, 1e-9), closeTo(100 / 3, 1e-9)]);
      },
    );

    test('a long payback against modest earnings is left to the reading', () {
      // Amazon's shape: its cash goes on building, not on repaying.
      expect(
        _check(
          FrameworkQuestion.risk,
          _years(
            [100, 100, 100, 100],
            operating: [100, 100, 100, 100],
            cash: [10, 10, 10, 10],
            debt: 110,
            held: 0,
          ),
        ),
        isNull,
      );
    });

    test('debt with neither profit nor spare cash is a no', () {
      expect(
        _check(
          FrameworkQuestion.risk,
          _years(
            [100, 100, 100, 100],
            operating: [-20, -20, -20, -20],
            cash: [-10, -10, -10, -10],
            debt: 40,
            held: 10,
          ),
        )!.reason,
        FilingsReason.debtWithoutEarnings,
      );
    });

    test('reads the debt at the newest quarter', () {
      final snapshot = _years(
        [100, 100, 100, 100],
        operating: [3, 3, 3, 3],
        cash: [10, 10, 10, 10],
        debt: 10,
        held: 0,
        trailing: TrailingFigures(
          periodEnd: DateTime(2026, 9, 30),
          fiscalYear: 2026,
          quarter: 3,
          totalDebt: 100,
          cash: 0,
        ),
      );
      expect(
        _check(FrameworkQuestion.risk, snapshot)!.verdict,
        FrameworkVerdict.no,
      );
    });

    test('a carmaker\'s debt is left to the reading', () {
      expect(
        _check(
          FrameworkQuestion.risk,
          _years(
            [100, 100, 100, 100],
            company: const Company(
              ticker: 'GM',
              cik: '3',
              name: 'GM',
              sic: 3711,
            ),
            operating: [3, 3, 3, 3],
            cash: [10, 10, 10, 10],
            debt: 100,
            held: 0,
          ),
        ),
        isNull,
      );
    });

    test('a company holding net cash is never failed on debt', () {
      expect(
        _check(
          FrameworkQuestion.risk,
          _years(
            [100, 100, 100, 100],
            operating: [-50, -50, -50, -50],
            cash: [-40, -40, -40, -40],
            interest: 1,
            debt: 5,
            held: 300,
          ),
        ),
        isNull,
      );
    });
  });

  group('timing', () {
    test('without a price is unsettled, and the model is not asked', () {
      expect(
        _check(FrameworkQuestion.timing, _years([100, 100, 100, 100]))!.reason,
        FilingsReason.noPrice,
      );
      expect(FilingsCheck.settlesAlone(FrameworkQuestion.timing), isTrue);
    });
  });

  test('moat and management are never the filings\' to settle', () {
    final snapshot = _years([100, 110, 121, 133]);
    expect(_check(FrameworkQuestion.moat, snapshot), isNull);
    expect(_check(FrameworkQuestion.management, snapshot), isNull);
  });

  test(
    'an answer keeps the model\'s verdict where the filings overrule it',
    () {
      const answer = FrameworkAnswer(
        verdict: FrameworkVerdict.no,
        headline: 'Cash flow is weak',
        explanation: '',
      );
      final settled = answer.settledAs(FrameworkVerdict.yes);
      expect(settled.verdict, FrameworkVerdict.yes);
      expect(settled.modelVerdict, FrameworkVerdict.no);
      expect(FrameworkAnswer.fromJson(settled.toJson()), settled);
      expect(answer.settledAs(FrameworkVerdict.no).modelVerdict, isNull);
    },
  );
}
