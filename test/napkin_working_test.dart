import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/snapshot/trailing_figures.dart';
import 'package:pickstock/data/valuation/valuation.dart';
import 'package:pickstock/data/valuation/valuation_basis.dart';
import 'package:pickstock/l10n/app_localizations_en.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/ui/snapshot/widgets/napkin_math.dart';

const double _million = 1000000;

final _strings = AppLocalizationsEn();

/// A steady filer with three years on file, so its cash flow is a typical
/// year and its margin has a median to be set against.
FinancialSnapshot _snapshot({
  double? sharesOutstanding = 10 * _million,
  double? totalDebt = 50 * _million,
  double? operatingCashFlow = 500 * _million,
  List<double> margins = const [0.20, 0.20, 0.20],
  TrailingFigures? trailing,
}) => FinancialSnapshot(
  company: Company(
    ticker: 'TEST',
    cik: '0000000001',
    name: 'Test Corp',
    sharesOutstanding: sharesOutstanding,
  ),
  years: [
    for (final (index, margin) in margins.indexed)
      FiscalYearFigures(
        fiscalYear: 2023 + index,
        revenue: 1000 * _million,
        operatingIncome: 1000 * _million * margin,
        netIncome: 100 * _million,
        operatingCashFlow: operatingCashFlow,
        capitalExpenditure: 300 * _million,
        depreciationAmortisation: 100 * _million,
        totalDebt: totalDebt,
        cash: 10 * _million,
        dilutedShares: 10 * _million,
      ),
  ],
  trailing: trailing,
);

TrailingFigures _quarter({
  double? revenue,
  double? totalDebt,
  double? cash,
  double? dilutedShares,
}) => TrailingFigures(
  periodEnd: DateTime(2026, 9, 30),
  fiscalYear: 2026,
  quarter: 3,
  revenue: revenue,
  totalDebt: totalDebt,
  cash: cash,
  dilutedShares: dilutedShares,
);

List<String> _caveats(FinancialSnapshot snapshot) {
  final valuation = Valuation(snapshot: snapshot, pricePerShare: 100);
  return napkinCaveatsFor(_strings, valuation, snapshot.latest);
}

String? _quarterCaveat(FinancialSnapshot snapshot) =>
    _caveats(snapshot)
        .where((caveat) => caveat.contains('latest quarterly report, to'))
        .firstOrNull;

void main() {
  setUp(() => GetIt.I.registerLazySingleton<FormatRepo>(FormatRepo.new));
  tearDown(GetIt.I.reset);

  group('step three', () {
    test('says the debt is not on file rather than writing it as \$0', () {
      final valuation = Valuation(
        snapshot: _snapshot(totalDebt: null),
        pricePerShare: 100,
      );
      final steps = napkinStepsFor(_strings, valuation);

      expect(steps[2].title, _strings.napkinStep3TitleUnknown);
      expect(steps[2].body, contains('no usable figure for its cash and debt'));
      expect(steps.any((step) => step.body.contains(r'owes $0')), isFalse);
    });

    test('still states a debt that is on file', () {
      final valuation = Valuation(snapshot: _snapshot(), pricePerShare: 100);
      final steps = napkinStepsFor(_strings, valuation);
      expect(steps[2].title, _strings.napkinStep3TitleDebt);
      expect(steps[2].body, contains(r'owes $40M more than it holds'));
    });
  });

  group('the quarter caveat', () {
    test('is absent where every figure is the annual report\'s', () {
      expect(_quarterCaveat(_snapshot()), isNull);
    });

    test('names the sales alone where only they came from the quarter', () {
      final caveat = _quarterCaveat(
        _snapshot(trailing: _quarter(revenue: 1200 * _million)),
      );
      expect(
        caveat,
        contains(GetIt.I.get<FormatRepo>().shortDate(DateTime(2026, 9, 30))),
      );
      expect(caveat, contains('the sales'));
      expect(caveat, isNot(contains('cash and debt')));
      expect(caveat, isNot(contains('share count')));
    });

    test('names the cash and debt alone where only they did', () {
      final caveat = _quarterCaveat(
        _snapshot(
          trailing: _quarter(totalDebt: 80 * _million, cash: 20 * _million),
        ),
      );
      expect(caveat, contains('the cash and debt'));
      expect(caveat, isNot(contains('the sales')));
    });

    test('names the share count where it is the one divided by', () {
      final caveat = _quarterCaveat(
        _snapshot(
          sharesOutstanding: null,
          trailing: _quarter(
            revenue: 1200 * _million,
            totalDebt: 80 * _million,
            cash: 20 * _million,
            dilutedShares: 12 * _million,
          ),
        ),
      );
      expect(
        caveat,
        contains(
          'the sales, for the twelve months to that date, the cash and debt '
          'and the share count',
        ),
      );
    });

    test('but not where a cover count is divided by instead', () {
      // The quarter's average is then only the earnings divisor, which the
      // worked example never uses.
      expect(
        _quarterCaveat(_snapshot(trailing: _quarter(dilutedShares: 12e6))),
        isNull,
      );
    });

    test('and the share count caveat says the average is the quarter\'s', () {
      final caveats = _caveats(
        _snapshot(
          sharesOutstanding: null,
          trailing: _quarter(dilutedShares: 12 * _million),
        ),
      );
      expect(caveats, contains(_strings.napkinCaveatShareCountQuarter));
      expect(caveats, isNot(contains(_strings.napkinCaveatShareCount)));
    });
  });

  group('the building and margin caveats', () {
    test('show on the cash flow basis', () {
      final snapshot = _snapshot(margins: const [0.20, 0.20, 0.12]);
      final valuation = Valuation(snapshot: snapshot, pricePerShare: 100);
      expect(valuation.basis, ValuationBasis.freeCashFlow);

      final caveats = _caveats(snapshot);
      expect(caveats, contains(_strings.napkinCaveatBuilding('3.0')));
      expect(caveats, contains(_strings.napkinCaveatMargin('8.0')));
    });

    test('and on the earnings basis, worded for profit', () {
      final snapshot = _snapshot(
        operatingCashFlow: null,
        margins: const [0.20, 0.20, 0.12],
      );
      final valuation = Valuation(snapshot: snapshot, pricePerShare: 100);
      expect(valuation.basis, ValuationBasis.earnings);

      final caveats = _caveats(snapshot);
      expect(caveats, contains(_strings.napkinCaveatBuildingEarnings('3.0')));
      expect(caveats, isNot(contains(_strings.napkinCaveatBuilding('3.0'))));
      expect(caveats, contains(_strings.napkinCaveatMargin('8.0')));
    });
  });
}
