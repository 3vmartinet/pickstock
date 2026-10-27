import 'package:flutter_test/flutter_test.dart';
import 'package:pickstock/data/research/framework_question.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/repo/research/framework_prompts.dart';
import 'package:pickstock/repo/research/ollama_repo.dart';
import 'package:pickstock/repo/research/web_search_repo.dart';

/// Puts all seven framework questions to the model on this machine, for real,
/// to prove the prompts come back as verdicts the app can read.
///
/// Skipped unless a key is built in, like the other live tests:
///
/// ```sh
/// flutter test --dart-define-from-file=env.json test/live_framework_test.dart
/// ```
///
/// Crocs, because its FY2025 is a real test of judgement: revenue flat after
/// years of growth, operating margin from 25% to 4% on an impairment, and free
/// cash flow still strong. A prompt that cannot tell those apart is no use.
///
/// Before write-downs were read, the margins question called the drop an
/// impairment while the risk question called it a collapse — each asked on
/// its own, from the same figures, reaching opposite conclusions.
final Object? _skip = ollamaApiKey.isEmpty
    ? 'no OLLAMA_API_KEY built in; pass --dart-define-from-file=env.json'
    : null;

/// Seven questions of one to three searches each, on a laptop.
const Timeout _runTimeout = Timeout(Duration(minutes: 20));

const double _million = 1000000;

FiscalYearFigures _year(
  int year, {
  required double revenue,
  double? priorRevenue,
  required double operating,
  required double net,
  required double ocf,
  required double capex,
  required double debt,
  required double cash,
  required double buybacks,
  required double shares,
  double? impairment,
}) => FiscalYearFigures(
  fiscalYear: year,
  revenue: revenue * _million,
  priorRevenue: priorRevenue == null ? null : priorRevenue * _million,
  operatingIncome: operating * _million,
  netIncome: net * _million,
  operatingCashFlow: ocf * _million,
  capitalExpenditure: capex * _million,
  totalDebt: debt * _million,
  cash: cash * _million,
  buybacks: buybacks * _million,
  dilutedShares: shares * _million,
  impairment: impairment == null ? null : impairment * _million,
);

/// Crocs' filings as the app holds them.
final FinancialSnapshot _crocs = FinancialSnapshot(
  company: const Company(
    ticker: 'CROX',
    cik: '0001334036',
    name: 'Crocs, Inc.',
  ),
  years: [
    _year(
      2021,
      revenue: 2313.4,
      priorRevenue: 1386.0,
      operating: 683.1,
      net: 725.7,
      ocf: 567.2,
      capex: 55.9,
      debt: 963.6,
      cash: 213.2,
      buybacks: 1000.0,
      shares: 63.7,
    ),
    _year(
      2022,
      revenue: 3555.0,
      priorRevenue: 2313.4,
      operating: 850.8,
      net: 540.2,
      ocf: 603.1,
      capex: 104.2,
      debt: 2595.0,
      cash: 191.6,
      buybacks: 0,
      shares: 62.0,
    ),
    _year(
      2023,
      revenue: 3962.3,
      priorRevenue: 3555.0,
      operating: 1036.8,
      net: 792.6,
      ocf: 930.4,
      capex: 115.6,
      debt: 1996.4,
      cash: 149.3,
      buybacks: 175.0,
      shares: 62.0,
    ),
    _year(
      2024,
      revenue: 4102.1,
      priorRevenue: 3962.3,
      operating: 1021.9,
      net: 950.1,
      ocf: 992.5,
      capex: 69.3,
      debt: 1701.3,
      cash: 180.5,
      buybacks: 552.5,
      shares: 59.8,
      impairment: 24.1,
    ),
    _year(
      2025,
      revenue: 4040.6,
      priorRevenue: 4102.1,
      operating: 149.5,
      net: -81.2,
      ocf: 710.4,
      capex: 51.2,
      debt: 1613.8,
      cash: 130.4,
      buybacks: 582.3,
      shares: 54.2,
      // HEYDUDE: $307M of goodwill and $430M of brand, as filed under
      // `AssetImpairmentCharges`.
      impairment: 738.1,
    ),
  ],
);

void main() {
  test(
    'every question comes back as a verdict the app can read',
    () async {
      final repo = OllamaRepo(search: OllamaWebSearchRepo());
      if (!await repo.isAvailable) {
        markTestSkipped('no local ${repo.model}; start ollama and pull it');
        return;
      }

      final prompts = FrameworkPrompts(snapshot: _crocs);
      for (final question in FrameworkQuestion.values) {
        final started = DateTime.now();
        final reading = await repo.screen(prompts, question);
        final answer = reading!.answer;
        final pages = {for (final source in reading.sources) source.url};

        // Read on purpose rather than asserted on: the verdicts are the
        // model's judgement, and the point of running this is to look at them.
        // ignore: avoid_print
        print(
          '${question.number}. ${question.name} '
          '[${DateTime.now().difference(started).inSeconds}s, '
          '${pages.length} pages] ${answer.verdict.name}: ${answer.headline}\n'
          '   ${answer.explanation}\n'
          '${[for (final point in answer.points) '   - ${point.text} <${point.url ?? (point.isFromFilings ? 'filings' : 'unsourced')}>'].join('\n')}',
        );

        expect(answer.headline, isNotEmpty);
        expect(answer.explanation, isNotEmpty);
        expect(answer.points, isNotEmpty);
        // Every link it kept is one the search actually returned.
        for (final point in answer.points) {
          if (point.url case final url?) expect(pages, contains(url));
        }
        // Every question but cash is a question of reading, and a 12B model
        // given the filings would sometimes answer those from them alone.
        if (prompts.promptFor(question).needsReading) {
          expect(pages, isNotEmpty, reason: '${question.name} read nothing');
        }
        if (question == FrameworkQuestion.risk) {
          expect(answer.points, hasLength(3));
        }
        // The case this test exists for: FY2025's 3.7% margin is a write-down,
        // not the business, and the margins question already says so. Risk
        // and timing quoting it as a collapse contradict it — first one did,
        // then, once risk was told, the other.
        if (question == FrameworkQuestion.risk ||
            question == FrameworkQuestion.timing) {
          final said = '${answer.headline} ${answer.explanation}'.toLowerCase();
          expect(said, isNot(contains('3.7%')), reason: said);
          // The margin, not any use of the word: "a collapse in demand" is
          // a risk worth naming.
          expect(said, isNot(contains('margin collapse')), reason: said);
          expect(said, isNot(contains('margin collapsed')), reason: said);
        }
      }
    },
    timeout: _runTimeout,
    skip: _skip,
  );
}
