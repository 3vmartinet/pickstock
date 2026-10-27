import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/data/research/framework_evidence.dart';
import 'package:pickstock/data/research/framework_question.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/repo/research/framework_prompts.dart';
import 'package:pickstock/repo/sec/company_facts_parser.dart';

const double _million = 1000000;

Map<String, dynamic> _usd(num value) => {
  'units': {
    'USD': [
      {
        'accn': 'a-2025',
        'fy': 2025,
        'fp': 'FY',
        'form': '10-K',
        'start': '2025-01-01',
        'end': '2025-12-31',
        'val': value,
      },
    ],
  },
};

/// One year of a filing with whichever write-down concepts the caller passes,
/// shaped on Crocs' FY2025.
Map<String, dynamic> _facts({num? total, num? goodwill, num? intangibles}) => {
  'facts': {
    'us-gaap': {
      'Revenues': _usd(4040.6 * _million),
      'OperatingIncomeLoss': _usd(149.5 * _million),
      'NetCashProvidedByUsedInOperatingActivities': _usd(710.4 * _million),
      'AssetImpairmentCharges': ?(total == null ? null : _usd(total)),
      'GoodwillImpairmentLoss': ?(goodwill == null ? null : _usd(goodwill)),
      'ImpairmentOfIntangibleAssetsIndefinitelivedExcludingGoodwill':
          ?(intangibles == null ? null : _usd(intangibles)),
    },
  },
};

FiscalYearFigures _parsed(Map<String, dynamic> facts) =>
    CompanyFactsParser.parse(facts).single;

/// Crocs' FY2025 as the app holds it after the ingest.
const FiscalYearFigures _crocs2025 = FiscalYearFigures(
  fiscalYear: 2025,
  revenue: 4040.6 * _million,
  operatingIncome: 149.5 * _million,
  impairment: 738.1 * _million,
);

void main() {
  group('reading write-downs', () {
    test('takes the total where only the total is tagged', () {
      expect(
        _parsed(_facts(total: 738.1 * _million)).impairment,
        738.1 * _million,
      );
    });

    test('adds up the parts where only they are tagged', () {
      final year = _parsed(
        _facts(goodwill: 307 * _million, intangibles: 430 * _million),
      );
      expect(year.impairment, 737 * _million);
    });

    test('never counts a filer that tags both twice', () {
      // Crocs tags all three: the total already holds the goodwill and the
      // HEYDUDE intangibles, so adding them would double the charge.
      final year = _parsed(
        _facts(
          total: 738.1 * _million,
          goodwill: 307 * _million,
          intangibles: 430 * _million,
        ),
      );
      expect(year.impairment, 738.1 * _million);
    });

    test('says nothing for a year with no write-down', () {
      final year = _parsed(_facts());
      expect(year.impairment, isNull);
      expect(year.operatingIncomeBeforeImpairment, isNull);
    });
  });

  test('adds the write-down back to find the margin the business earned', () {
    expect(_crocs2025.operatingMarginPercent, closeTo(3.7, 0.05));
    expect(_crocs2025.operatingIncomeBeforeImpairment, 887.6 * _million);
    expect(
      _crocs2025.operatingMarginBeforeImpairmentPercent,
      closeTo(22.0, 0.05),
    );
  });

  group('every question is told about it', () {
    final prompts = FrameworkPrompts(
      snapshot: const FinancialSnapshot(
        company: Company(
          ticker: 'CROX',
          cik: '0001334036',
          name: 'Crocs, Inc.',
        ),
        years: [_crocs2025],
      ),
      today: DateTime(2026, 10, 27),
    );

    test('as a fact in the brief all seven share', () {
      expect(
        prompts.brief,
        contains(
          'operating income 887.6 before a 738.1 write-down (22.0% margin), '
          '149.5 as filed after it',
        ),
      );
      // The margin after the write-down is not written anywhere: shown it,
      // the model anchors on it.
      expect(prompts.brief, isNot(contains('3.7%')));
      expect(
        prompts.brief,
        contains(
          'FY2025 includes a non-cash write-down (impairment) of 738.1. '
          'Before it, operating income was 887.6 (22.0% margin).',
        ),
      );
      expect(
        prompts.brief,
        contains(
          'a non-cash charge already booked is '
          'history',
        ),
      );
    });

    test('and in the rules of the questions it misled', () {
      for (final question in [
        FrameworkQuestion.cash,
        FrameworkQuestion.risk,
        FrameworkQuestion.timing,
      ]) {
        expect(
          prompts.promptFor(question).rule,
          contains('write-down'),
          reason: question.name,
        );
      }
      expect(
        prompts.promptFor(FrameworkQuestion.risk).rule,
        contains('not itself one of the three'),
      );
    });
  });

  test('the margin and risk panels show the charge beside the drop', () {
    const snapshot = FinancialSnapshot(
      company: Company(ticker: 'CROX', cik: '0001334036', name: 'Crocs, Inc.'),
      years: [_crocs2025],
    );
    for (final question in [
      FrameworkQuestion.margins,
      FrameworkQuestion.risk,
    ]) {
      final measures = [
        for (final stat in FrameworkEvidence.forQuestion(
          question,
          snapshot,
        ).stats)
          stat.measure,
      ];
      expect(measures, contains(EvidenceMeasure.impairment));
      expect(
        measures,
        contains(EvidenceMeasure.operatingMarginBeforeImpairment),
      );
    }
  });
}
