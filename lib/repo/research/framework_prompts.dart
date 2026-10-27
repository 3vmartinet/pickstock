import 'dart:math' as math;

import 'package:pickstock/data/research/framework_question.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/valuation/valuation.dart';
import 'package:pickstock/data/valuation/valuation_basis.dart';
import 'package:pickstock/data/valuation/valuation_verdict.dart';

/// A one-year fall in revenue, in percent, past which the brief warns that it
/// may be a restatement rather than a decline.
///
/// AppLovin is why. It sold its apps business in 2025 and restated FY2023
/// onwards without it, so FY2023 reads 34.6% below FY2022 — the fastest
/// grower in the directory shown shrinking by a third, and its three-year
/// rate struck from the unrestated base. A quarter is past what an ongoing
/// business loses in a bad year, and well short of what a divestiture
/// removes.
const double _restatementDrop = 25;

/// How many fiscal years the model is shown. Five is the window the framework
/// itself names for growth and the "three or more" it wants for margins, with
/// a sixth so the first of them has a year-over-year change.
const int _yearsShown = 6;

/// Everything one question needs said to the model, built up front.
///
/// Held by the queued work rather than built when its turn comes: the brief
/// quotes the figures on screen, and by then the reader may be three companies
/// away.
class FrameworkPrompt {
  const FrameworkPrompt({
    required this.question,
    required this.title,
    required this.research,
    required this.rule,
    required this.points,
    this.needsReading = true,
  });

  final FrameworkQuestion question;

  /// The question in the framework's own words, quoted back when distilling.
  final String title;

  /// What the model is asked to go and find out.
  final String research;

  /// How the answer turns into a yes, a no or neither.
  final String rule;

  /// What the evidence list should hold. The risk question wants its three
  /// killers there; the others want whatever settled the verdict.
  final String points;

  /// Whether the question cannot be answered without reading the web. All
  /// but the cash question, which the filings mostly settle and which is told
  /// to search only for what they cannot say.
  final bool needsReading;
}

/// Writes the seven questions for one company.
///
/// Each one is written out rather than templated, for the reason the insights
/// are: what makes a question worth a minute of the model is that it names the
/// thing the filings cannot settle, and that differs every time. What they
/// share is [brief] — the filings, set out once, so the model argues from the
/// company's own numbers and searches for what those cannot say.
///
/// Tested against `gemma4:12b-mlx` with Crocs, which fails growth and risk on
/// its FY2025 and passes the moat: a 12B model answers each in one to three
/// searches and twenty to seventy seconds, and distils the result into the
/// JSON shape in under ten.
class FrameworkPrompts {
  FrameworkPrompts({required this.snapshot, this.valuation, DateTime? today})
    : today = today ?? DateTime.now();

  final FinancialSnapshot snapshot;

  /// Absent until there is a price, which only the timing question misses.
  final Valuation? valuation;

  final DateTime today;

  String get subject => '${snapshot.company.name} (${snapshot.company.ticker})';

  List<FiscalYearFigures> get _years {
    final years = snapshot.years;
    return years.sublist(math.max(0, years.length - _yearsShown));
  }

  /// The system message: who is asking, and what is already known for
  /// certain.
  String get brief => [
    'You are an equity analyst screening $subject for a long-term investor, '
        'one question at a time. Today is ${_day(today)}. The figures below '
        'come from the company\'s own SEC filings and are reliable: prefer '
        'them to any figure you read on the web, and use the web for what '
        'the filings cannot say. The share price given is today\'s; prefer it '
        'to any price you read. Where a year carries a write-down, judge the '
        'business on its figures before the write-down and say that you have: '
        'a non-cash charge already booked is history, not the trend.',
    figures,
  ].join('\n\n');

  /// The filings, one line a year, then what can be worked out from them.
  ///
  /// Every figure is labelled and every gap is said in words: a prompt with
  /// a blank in it invites the model to fill the blank itself.
  String get figures {
    final lines = <String>[
      'Fiscal years from the filings, oldest first (USD millions):',
      for (final year in _years) _yearLine(year),
    ];

    // Said in a sentence as well as on the year's line: it is the fact every
    // question has to agree on, and a figure buried mid-line was the one a
    // question asked on its own missed.
    for (final year in _years) {
      final before = year.operatingIncomeBeforeImpairment;
      if (before == null) continue;
      lines.add(
        'FY${year.fiscalYear} includes a non-cash write-down (impairment) of '
        '${_m(year.impairment)}. Before it, operating income was ${_m(before)}'
        '${_marginNote(year.operatingMarginBeforeImpairmentPercent)}.',
      );
    }

    if (_years.every((year) => year.grossProfit == null)) {
      lines.add('Gross profit is not tagged in these filings.');
    }

    // Before the growth rates, which a restatement makes wrong: said first,
    // it is the reading of them.
    for (final year in _years) {
      final change = year.revenueGrowthPercent;
      if (change == null || change > -_restatementDrop) continue;
      lines.add(
        'FY${year.fiscalYear} revenue is ${_pct(-change)} below '
        'FY${year.fiscalYear - 1}. A fall that size is as often a business sold '
        'or discontinued, with later years restated to exclude it, as a real '
        'decline: years either side of a restatement are not comparable, and '
        'growth rates spanning it are not either. Check which before judging '
        'growth on it.',
      );
    }

    final growth = [
      for (final span in const [3, 5])
        if (_cagr(span) case final rate?) '$span years ${_pct(rate)}',
    ];
    if (growth.isNotEmpty) {
      lines.add('Revenue compound annual growth: ${growth.join(', ')}.');
    }

    final shares = _shareChange();
    if (shares != null) {
      lines.add(
        'Diluted share count changed ${_pct(shares)} over the years shown.',
      );
    }

    final current = valuation;
    if (current == null) {
      lines.add('No share price is available today.');
    } else {
      final low = current.fairValueLow;
      final high = current.fairValueHigh;
      final stream = current.basis == ValuationBasis.earnings
          ? 'earnings'
          : 'free cash flow';
      final range = low == null || high == null
          ? 'PickStock cannot value it from the filings.'
          : 'PickStock values it from the filings at '
                '\$${low.toStringAsFixed(0)}-\$${high.toStringAsFixed(0)} a '
                'share (${current.lowMultiple.toStringAsFixed(0)}-'
                '${current.highMultiple.toStringAsFixed(0)}x $stream), and '
                'reads it as ${_verdict(current.verdict)}.';
      lines.add(
        'Share price today: \$${current.pricePerShare.toStringAsFixed(2)}. '
        '$range',
      );
    }
    return lines.join('\n');
  }

  /// Operating income as a year's line states it.
  ///
  /// In a year with a write-down the margin quoted is the one before it, and
  /// the margin after it is not written at all. Told in words that the 3.7%
  /// Crocs' FY2025 shows as filed was a write-down, the 12B model went on
  /// calling it a collapse — on the risk question, then on timing, each in
  /// turn as the other was told. Shown the figure, it anchors on it; not
  /// shown it, it cannot. The figure as filed is still there in money.
  String _operatingPart(FiscalYearFigures year) {
    final before = year.operatingIncomeBeforeImpairment;
    if (before == null) {
      return 'operating income ${_m(year.operatingIncome)}'
          '${_marginNote(year.operatingMarginPercent)}';
    }
    return 'operating income ${_m(before)} before a '
        '${_m(year.impairment)} write-down'
        '${_marginNote(year.operatingMarginBeforeImpairmentPercent)}, '
        '${_m(year.operatingIncome)} as filed after it';
  }

  String _yearLine(FiscalYearFigures year) {
    final parts = <String>[
      'revenue ${_m(year.revenue)}'
          '${year.revenueGrowthPercent == null ? '' : ' (${_signed(year.revenueGrowthPercent!)} y/y)'}',
      'gross profit ${_m(year.grossProfit)}'
          '${_marginNote(year.grossMarginPercent)}',
      _operatingPart(year),
      'net income ${_m(year.netIncome)}',
      'operating cash flow ${_m(year.operatingCashFlow)}',
      'capex ${_m(year.capitalExpenditure)}',
      'free cash flow ${_m(year.freeCashFlow)}',
      'debt ${_m(year.totalDebt)}',
      'cash ${_m(year.cash)}',
      'dividends ${_m(year.dividendsPaid)}',
      'buybacks ${_m(year.buybacks)}',
      'stock pay ${_m(year.shareBasedCompensation)}',
      'diluted shares ${_count(year.dilutedShares)}',
    ];
    return 'FY${year.fiscalYear}: ${parts.join('; ')}';
  }

  /// All seven, in the framework's order.
  List<FrameworkPrompt> get all => [
    for (final question in FrameworkQuestion.values) promptFor(question),
  ];

  FrameworkPrompt promptFor(FrameworkQuestion question) => switch (question) {
    FrameworkQuestion.growth => FrameworkPrompt(
      question: question,
      title: 'Is the business growing?',
      research:
          'Question 1 of a stock-screening framework: is $subject still '
          'growing? The filings above give its revenue for each year. Search '
          'the web for the company\'s latest quarterly results and its revenue '
          'guidance for the current year, to tell whether the trend in the '
          'filings is continuing, accelerating or reversing. Then say in three '
          'or four sentences whether the business is growing, naming the '
          'figures that decide it and what has been driving the trend.',
      rule:
          'yes if revenue has risen over the last three to five years and the '
          'most recent trend is still up; no if it is flat or declining. A '
          'single down year inside a clear rise is not a no on its own, but a '
          'latest year that reverses the trend, with no guidance that it '
          'recovers, is. Where a fall turns out to be a business sold or '
          'discontinued, judge growth on the business that remains, from the '
          'years after the restatement and from its latest quarters.',
      points: 'two to four pieces of evidence for the verdict.',
    ),
    FrameworkQuestion.moat => FrameworkPrompt(
      question: question,
      title: 'Can they defend their position?',
      research:
          'Question 2 of a stock-screening framework: can $subject defend its '
          'position? Search the web for who its main competitors are, how its '
          'market share has moved, and what advantage it has — network '
          'effects, brand power, switching costs, scale or cost advantage, '
          'patents or regulation. Then answer in three or four sentences: '
          'could a competitor with unlimited capital take its customers within '
          'two years, and why or why not?',
      rule:
          'yes if the business has a durable advantage — network effects, '
          'brand power, high switching costs, scale or cost advantage, patents '
          'or regulation — that a competitor with unlimited capital could not '
          'overcome within two years; no if what it sells is easily copied or '
          'it is steadily losing share; unclear if the evidence points both '
          'ways. Gross margins held high for years are evidence of a moat; '
          'margins falling while rivals gain are evidence against.',
      points:
          'two to four pieces of evidence: the advantage itself, and what '
          'proves or undermines it.',
    ),
    FrameworkQuestion.management => FrameworkPrompt(
      question: question,
      title: 'Is management competent?',
      research:
          'Question 3 of a stock-screening framework: is $subject run by '
          'competent management? The filings above show what it did with its '
          'cash — buybacks, dividends, debt — and how the share count moved. '
          'Search the web for its chief executive and how long they have led '
          'it, recent insider buying or selling, the acquisitions it has made '
          'and how they turned out, and whether it has met the targets and '
          'guidance it set in the last few years. Then say in three or four '
          'sentences whether management allocates capital well and delivers '
          'on its promises.',
      rule:
          'yes if capital has been allocated sensibly — acquisitions that '
          'paid off, buybacks at reasonable prices, debt kept in hand — and '
          'management has broadly delivered on what it promised; no if it '
          'has repeatedly missed its own guidance, destroyed value with '
          'acquisitions or write-downs, diluted shareholders heavily, or '
          'insiders are selling heavily while promising growth; unclear if the '
          'record cannot be found.',
      points:
          'two to four pieces of evidence: capital allocation decisions, '
          'insider activity, and promises kept or missed.',
    ),
    FrameworkQuestion.margins => FrameworkPrompt(
      question: question,
      title: 'Are margins improving or declining?',
      research:
          'Question 4 of a stock-screening framework: are the margins of '
          '$subject improving or declining? The filings above give gross and '
          'operating margins by year where they are tagged. Search the web for '
          'its latest quarterly gross and operating margins'
          '${_years.every((year) => year.grossProfit == null) ? ' — and its gross margin by year, which the filings do not tag —' : ''}'
          ' and for what management says is moving them: pricing, input costs, '
          'mix, competition, one-off charges. Then say in three or four '
          'sentences which way margins are heading over three or more years, '
          'and whether any fall is a one-off or the business weakening.',
      rule:
          'yes if gross and operating margins are stable or rising over three '
          'or more years; no if they are compressing, unless the fall is '
          'plainly one non-cash charge such as an impairment with the '
          'underlying margin intact, in which case judge the underlying '
          'margin; unclear if the figures conflict.',
      points:
          'two to four pieces of evidence: the margin figures by year, and '
          'what is driving them.',
    ),
    FrameworkQuestion.cash => FrameworkPrompt(
      question: question,
      title: "What's the cash situation?",
      research:
          'Question 5 of a stock-screening framework: is $subject generating '
          'cash or burning it? The filings above give operating cash flow, '
          'capital spending and free cash flow by year, against net income, '
          'and the debt and cash held. Search the web only for what they '
          'cannot say: its latest quarter\'s cash flow, and anything unusual '
          'in it — working capital swings, cash tied up in inventory, '
          'factoring, or stock pay inflating the figure. Then say in three or '
          'four sentences whether the business produces real cash, and '
          'whether its cash flow backs up its reported profit.',
      rule:
          'yes if operating cash flow has been positive and broadly at or '
          'above net income for the last three years, and free cash flow '
          'covers what it owes; no if it is burning cash, or reported profit '
          'is persistently not turning into cash; unclear if the record is '
          'too short or too uneven to tell. A loss made by a write-down is '
          'not profit failing to become cash: compare cash flow with profit '
          'before the write-down.',
      points:
          'two to four pieces of evidence: operating and free cash flow by '
          'year, against profit and debt.',
      needsReading: false,
    ),
    FrameworkQuestion.risk => FrameworkPrompt(
      question: question,
      title: "What's the risk?",
      research:
          'Question 6 of a stock-screening framework: what could go wrong '
          'with $subject? Search the web for the risk factors in its latest '
          '10-K or 20-F and for current concerns — regulation, new '
          'competition, sensitivity to the economy, customer or supplier '
          'concentration, litigation. Weigh its debt against the cash flow in '
          'the filings. Then name the three specific things most likely to '
          'break an investment in it, each in one sentence, and say how '
          'serious each looks today.',
      rule:
          'yes if you can name three specific things that could break the '
          'investment and none of them is already happening at a scale that '
          'threatens the business; no if any of them is, or debt is beyond '
          'what the cash flow can carry; unclear if a material risk cannot be '
          'sized. A write-down already booked is not itself one of the three: '
          'it is history. Judge from the margin before it, and name instead '
          'what could cause the next one — the brand or acquisition it wrote '
          'down continuing to shrink, say.',
      points:
          'exactly three: the three specific things most likely to break this '
          'investment, the most serious first, each saying how likely it '
          'looks today.',
    ),
    FrameworkQuestion.timing => FrameworkPrompt(
      question: question,
      title: 'Is the timing right?',
      research:
          'Question 7 of a stock-screening framework: is now a sensible '
          'moment to buy $subject? '
          '${valuation == null ? 'No share price is available in the app, so search for today\'s price too. ' : 'Today\'s price and PickStock\'s valuation are given above. '}'
          'Search the web for how the share price has moved over the last '
          'three to twelve months against its 52-week range, the next earnings '
          'date or other upcoming catalysts, and whether money is moving into '
          'or out of its sector. Then say in three or four sentences whether '
          'the timing looks right, and why.',
      rule:
          'yes if the price has pulled back or sits below the range the '
          'filings support, and there is a catalyst ahead; no if the price is '
          'stretched after a run-up, sits above the range the filings '
          'support, or a known negative event is ahead; unclear if neither. A '
          'write-down already reported is not by itself a reason the timing is '
          'wrong.',
      points:
          'two to four pieces of evidence: where the price sits, recent '
          'moves, and what is coming.',
    ),
  };

  /// What turns research into an answer, with the pages it may cite numbered.
  ///
  /// Numbers rather than URLs: a 12B model asked to copy a link exactly will
  /// now and then improve it, and a link that has been improved opens nothing.
  /// A number it cannot get subtly wrong — only wrong outright, which is
  /// caught.
  String distil(FrameworkPrompt prompt, String research, List<String> pages) =>
      'Question about $subject: "${prompt.title}"\n\n'
      'How to decide the verdict: ${prompt.rule}\n\n'
      'The company\'s own filings:\n$figures\n\n'
      'Research gathered from the web:\n'
      '${research.isEmpty ? '(none)' : research}\n\n'
      'The pages that were read, numbered:\n'
      '${pages.isEmpty ? '(none)' : [for (var i = 0; i < pages.length; i++) '[${i + 1}] ${pages[i]}'].join('\n')}\n\n'
      'Reply with one JSON object and nothing else, in this shape:\n'
      '{"verdict":"yes","headline":"...","explanation":"...",'
      '"points":[{"text":"...","source":0}]}\n\n'
      '- "verdict": "yes", "no" or "unclear". Use "unclear" only when the '
      'evidence genuinely does not settle it, not to avoid committing.\n'
      '- "headline": the answer in under twelve words, as a plain statement, '
      'with the key figure in it where there is one.\n'
      '- Where the filings note a write-down, quote the margin before it. A '
      'write-down already booked is not a margin collapse and not, by itself, '
      'a reason for the verdict.\n'
      '- "explanation": two or three sentences saying why, citing figures. Do '
      'not open with "Yes" or "No".\n'
      '- Never put a double quote inside a text value; use single quotes.\n'
      '- "points": ${prompt.points} Each is one short sentence under twenty '
      'words. "source" is the number of the page the point was read on, or 0 '
      'when it comes from the filings.';

  double? _cagr(int span) {
    final years = snapshot.years;
    if (years.length <= span) return null;
    final end = years.last.revenue;
    final start = years[years.length - 1 - span].revenue;
    if (end == null || start == null || start <= 0 || end <= 0) return null;
    return (math.pow(end / start, 1 / span) - 1) * 100;
  }

  double? _shareChange() {
    final first = _years.first.dilutedShares;
    final last = _years.last.dilutedShares;
    if (first == null || last == null || first <= 0) return null;
    return (last - first) / first * 100;
  }

  static String _verdict(ValuationVerdict verdict) => switch (verdict) {
    ValuationVerdict.undervalued => 'undervalued',
    ValuationVerdict.fairlyValued => 'fairly valued',
    ValuationVerdict.overvalued => 'overvalued',
    ValuationVerdict.unknown => 'impossible to value',
  };

  static String _day(DateTime day) =>
      '${day.year}-${_two(day.month)}-${_two(day.day)}';

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _m(double? value) =>
      value == null ? 'not reported' : (value / 1000000).toStringAsFixed(1);

  static String _count(double? value) => value == null
      ? 'not reported'
      : '${(value / 1000000).toStringAsFixed(1)}M';

  static String _marginNote(double? percent) =>
      percent == null ? '' : ' (${percent.toStringAsFixed(1)}% margin)';

  static String _pct(double value) => '${value.toStringAsFixed(1)}%';

  static String _signed(double value) =>
      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}%';
}
