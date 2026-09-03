import 'package:pickstock/data/snapshot/fiscal_quarter_figures.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/xbrl/xbrl_metric.dart';

const String _factsKey = 'facts';
const String _usGaapKey = 'us-gaap';
const String _unitsKey = 'units';
const String _formKey = 'form';
const String _fiscalYearKey = 'fy';
const String _startKey = 'start';
const String _endKey = 'end';
const String _valueKey = 'val';

/// Where the price of real borrowings starts, as a share of the assets they
/// are carried against. The evidence for the number is in
/// `CompanyFactsParser._borrowingInterest`.
const double _borrowingInterestToAssets = 0.002;
const String _accessionKey = 'accn';
const String _entityNameKey = 'entityName';
const String _deiKey = 'dei';

/// The cover-page share count, filed as of the filing date rather than the
/// period end — which makes it the right multiplier for a market value today.
const String _sharesOutstandingTag = 'EntityCommonStockSharesOutstanding';
const String _sharesOutstandingFallbackTag = 'CommonStockSharesOutstanding';
const String _annualForm = '10-K';
const String _quarterlyForm = '10-Q';
const String _fiscalPeriodKey = 'fp';
const String _fullYearPeriod = 'FY';

/// A quarter's duration, give or take a company's 13-week calendar.
const int _minQuarterDays = 80;
const int _maxQuarterDays = 100;

/// The quarter a 10-K's own three-month figures belong to: a 10-K reports the
/// fourth, and labels it `FY` because that is the filing's period.
const int _fourthQuarter = 4;
const int _quartersPerYear = 4;

/// A 10-K carries quarterly facts alongside the annual ones, so a duration is
/// only treated as a full year if it actually spans one.
const int _minAnnualDays = 330;
const int _maxAnnualDays = 400;

/// Turns one SEC "company facts" payload into fiscal years of figures.
///
/// Shared by the bulk ingest and anything else reading the same JSON, so the
/// two can never disagree about what a number means.
abstract final class CompanyFactsParser {
  /// The registrant name carried in the payload, if present.
  static String? entityName(Map<String, dynamic> facts) =>
      facts[_entityNameKey] as String?;

  /// The newest share count on the cover of a filing, or `null` where none
  /// current enough to use is filed.
  ///
  /// Taken from the `dei` namespace, which is where the cover-page figure
  /// lives; the us-gaap balance-sheet count stands in when it is absent.
  ///
  /// A count is only used if it is at least as recent as the newest *annual*
  /// balance sheet. A filer that stops tagging the concept leaves its
  /// last one behind for ever, and "newest on file" then means whatever it
  /// said the day it stopped: Mastercard's series ends in 2010 at 122.5M
  /// shares, before a ten-for-one split and fifteen years of buybacks, and
  /// against a real price that stated a company a seventh of its size — which
  /// every ratio on the valuation tab is then struck against. Rejected here,
  /// the count falls through to the diluted average earnings are reported
  /// against, which every filer restates every quarter.
  ///
  /// Measured against the annual report rather than the newest balance sheet
  /// of any kind, which was too strict: a count filed with the 10-K is a
  /// quarter old by the time the next 10-Q lands, and a quarter-old count of
  /// the shares that exist beats a twelve-month average of them. Only a count
  /// that has gone a year or more without being restated is worth refusing.
  static double? latestSharesOutstanding(Map<String, dynamic> facts) {
    final asOf = _newestBalanceSheetDate(facts);
    final candidates = [
      facts[_factsKey]?[_deiKey]?[_sharesOutstandingTag],
      facts[_factsKey]?[_usGaapKey]?[_sharesOutstandingFallbackTag],
    ];

    for (final candidate in candidates) {
      final units =
          (candidate as Map<String, dynamic>?)?[_unitsKey]?[XbrlUnit.shares.key]
              as List<dynamic>?;
      if (units == null) continue;

      double? newest;
      String? newestEnd;
      for (final raw in units) {
        final fact = raw as Map<String, dynamic>;
        final end = fact[_endKey] as String?;
        final value = fact[_valueKey] as num?;
        if (end == null || value == null) continue;
        if (newestEnd == null || end.compareTo(newestEnd) > 0) {
          newestEnd = end;
          newest = value.toDouble();
        }
      }
      if (newest == null || newestEnd == null) continue;
      // The cover is dated the day the filing went in, so a live count is
      // always on or after the balance sheet it accompanies.
      if (asOf != null && newestEnd.compareTo(asOf) < 0) continue;
      return newest;
    }
    return null;
  }

  /// When the filer last put a share count on a cover, whether or not it is
  /// recent enough to use, or `null` if it never did.
  ///
  /// Read separately from [latestSharesOutstanding] so that a filer which
  /// stopped tagging the concept can be told from one that never tagged it.
  /// Both fall back to the diluted average, and only the first has a year to
  /// name for it.
  static DateTime? lastFiledShareCount(Map<String, dynamic> facts) {
    String? newest;
    for (final candidate in [
      facts[_factsKey]?[_deiKey]?[_sharesOutstandingTag],
      facts[_factsKey]?[_usGaapKey]?[_sharesOutstandingFallbackTag],
    ]) {
      final units =
          (candidate as Map<String, dynamic>?)?[_unitsKey]?[XbrlUnit.shares.key]
              as List<dynamic>?;
      if (units == null) continue;
      for (final raw in units) {
        final fact = raw as Map<String, dynamic>;
        final end = fact[_endKey] as String?;
        if (end == null || fact[_valueKey] == null) continue;
        if (newest == null || end.compareTo(newest) > 0) newest = end;
      }
    }
    return newest == null ? null : DateTime.tryParse(newest);
  }

  /// The newest date the payload states an annual balance sheet for.
  ///
  /// Read off `Assets` in the annual report, which every operating filer
  /// restates every year, so it dates the payload without depending on a
  /// concept a filer might have stopped tagging. `null` where the concept is absent, in which case there
  /// is nothing to date a share count against and it is taken as filed.
  static String? _newestBalanceSheetDate(Map<String, dynamic> facts) {
    final units =
        facts[_factsKey]?[_usGaapKey]?[XbrlMetric
                .totalAssets
                .tags
                .first]?[_unitsKey]?[XbrlUnit.usd.key]
            as List<dynamic>?;
    if (units == null) return null;

    String? newest;
    for (final raw in units) {
      final fact = raw as Map<String, dynamic>;
      if (fact[_formKey] != _annualForm) continue;
      final end = fact[_endKey] as String?;
      if (end == null) continue;
      if (newest == null || end.compareTo(newest) > 0) newest = end;
    }
    return newest;
  }

  /// Every fiscal quarter the payload covers, oldest first.
  ///
  /// Quarters come from 10-Qs and, for the fourth, from the 10-K. Cash-flow
  /// lines are often filed year-to-date rather than per quarter, so those
  /// come back null more often than in the annual view.
  static List<FiscalQuarterFigures> parseQuarters(Map<String, dynamic> facts) {
    final seriesByMetric = {
      for (final metric in XbrlMetric.values)
        metric: _quarterSeries(facts, metric),
    };
    _fillFourthQuarters(facts, seriesByMetric);

    // Revenue defines which quarters exist: without it a row says nothing.
    final keys = seriesByMetric[XbrlMetric.revenue]!.keys.toList()..sort();

    return [
      for (final key in keys)
        FiscalQuarterFigures(
          fiscalYear: key.year,
          quarter: key.quarter,
          revenue: seriesByMetric[XbrlMetric.revenue]![key],
          // The same quarter a year earlier, for a like-for-like comparison.
          priorRevenue: seriesByMetric[XbrlMetric.revenue]![key.yearEarlier],
          netIncome: seriesByMetric[XbrlMetric.netIncome]![key],
          operatingCashFlow: seriesByMetric[XbrlMetric.operatingCashFlow]![key],
          capitalExpenditure:
              seriesByMetric[XbrlMetric.capitalExpenditure]![key],
          totalDebt: _sumFor(XbrlMetric.debtComponents, key, seriesByMetric),
          cash: _sumFor(XbrlMetric.cashComponents, key, seriesByMetric),
        ),
    ];
  }

  /// Supplies the fourth quarter, which most companies never file.
  ///
  /// A 10-K reports the full year and the 10-Qs cover the first three
  /// quarters, so a flow line's fourth quarter is the year less those three.
  /// Balance-sheet lines need no arithmetic: the year-end instant *is* the
  /// fourth quarter's closing position, and is taken as filed.
  static void _fillFourthQuarters(
    Map<String, dynamic> facts,
    Map<XbrlMetric, Map<QuarterKey, double>> seriesByMetric,
  ) {
    for (final metric in XbrlMetric.values) {
      final quarters = seriesByMetric[metric]!;
      final annual = _annualSeries(facts, metric);

      for (final entry in annual.entries) {
        final fourth = QuarterKey(entry.key, _fourthQuarter);
        if (quarters.containsKey(fourth)) continue;

        if (metric.isInstant) {
          quarters[fourth] = entry.value;
          continue;
        }

        final first = quarters[QuarterKey(entry.key, 1)];
        final second = quarters[QuarterKey(entry.key, 2)];
        final third = quarters[QuarterKey(entry.key, 3)];
        if (first == null || second == null || third == null) continue;
        quarters[fourth] = entry.value - (first + second + third);
      }
    }
  }

  /// Adds up [components] for one quarter, or `null` where the filer reported
  /// none of them — which is not the same as reporting zero.
  static double? _sumFor(
    List<XbrlMetric> components,
    QuarterKey key,
    Map<XbrlMetric, Map<QuarterKey, double>> seriesByMetric,
  ) {
    final hasAny = components.any(
      (metric) => seriesByMetric[metric]!.containsKey(key),
    );
    if (!hasAny) return null;
    return components.fold<double>(
      0,
      (sum, metric) => sum + (seriesByMetric[metric]![key] ?? 0),
    );
  }

  /// Merges a metric's candidate tags into one quarterly series.
  static Map<QuarterKey, double> _quarterSeries(
    Map<String, dynamic> facts,
    XbrlMetric metric,
  ) {
    final combined = <QuarterKey, double>{};
    for (final tag in metric.tags.reversed) {
      combined.addAll(
        _quarterSeriesForTag(
          facts,
          tag,
          isInstant: metric.isInstant,
          unit: metric.unit,
        ),
      );
    }
    return combined;
  }

  /// One value per quarter for a single tag.
  ///
  /// A filing restates earlier periods as comparatives, so within each filing
  /// only the newest period is taken — that is the filing's own quarter, and
  /// the one its `fy`/`fp` describe. Everything else arrives from the filing
  /// that reported it first-hand.
  static Map<QuarterKey, double> _quarterSeriesForTag(
    Map<String, dynamic> facts,
    String tag, {
    required bool isInstant,
    XbrlUnit unit = XbrlUnit.usd,
  }) {
    final usGaap = facts[_factsKey]?[_usGaapKey] as Map<String, dynamic>?;
    final units = usGaap?[tag]?[_unitsKey]?[unit.key] as List<dynamic>?;
    if (units == null) return const {};

    final factsByFiling = <String, List<Map<String, dynamic>>>{};
    for (final raw in units) {
      final fact = raw as Map<String, dynamic>;
      final form = fact[_formKey];
      if (form != _quarterlyForm && form != _annualForm) continue;
      if (fact[_fiscalYearKey] is! int) continue;
      if (fact[_valueKey] is! num) continue;
      if (_quarterOf(fact) == null) continue;

      final start = fact[_startKey] as String?;
      if (isInstant == (start != null)) continue;
      if (start != null && !_spansAQuarter(start, fact[_endKey] as String)) {
        continue;
      }

      final accession = fact[_accessionKey] as String?;
      if (accession == null) continue;
      (factsByFiling[accession] ??= []).add(fact);
    }

    final series = <QuarterKey, double>{};
    final filings = factsByFiling.keys.toList()
      ..sort((a, b) {
        final byYear = (factsByFiling[a]!.first[_fiscalYearKey] as int)
            .compareTo(factsByFiling[b]!.first[_fiscalYearKey] as int);
        return byYear != 0 ? byYear : a.compareTo(b);
      });

    for (final accession in filings) {
      final periods = factsByFiling[accession]!
        ..sort(
          (a, b) => (a[_endKey] as String).compareTo(b[_endKey] as String),
        );
      final own = periods.last;
      final quarter = _quarterOf(own);
      if (quarter == null) continue;
      series[QuarterKey(own[_fiscalYearKey] as int, quarter)] =
          (own[_valueKey] as num).toDouble();
    }
    return series;
  }

  /// `Q1`–`Q3` as filed; `FY` on a 10-K means the fourth quarter.
  static int? _quarterOf(Map<String, dynamic> fact) {
    final period = fact[_fiscalPeriodKey];
    if (period == _fullYearPeriod) {
      return fact[_formKey] == _annualForm ? _fourthQuarter : null;
    }
    if (period is! String || !period.startsWith('Q')) return null;
    return int.tryParse(period.substring(1));
  }

  static bool _spansAQuarter(String start, String end) {
    final days = DateTime.parse(end).difference(DateTime.parse(start)).inDays;
    return days >= _minQuarterDays && days <= _maxQuarterDays;
  }

  /// Every fiscal year the payload covers, oldest first.
  ///
  /// Years are those for which operating cash flow is known: without it there
  /// is no free cash flow and little worth reporting.
  static List<FiscalYearFigures> parse(Map<String, dynamic> facts) {
    final seriesByMetric = {
      for (final metric in XbrlMetric.values)
        metric: _annualSeries(facts, metric),
    };

    final years = seriesByMetric[XbrlMetric.operatingCashFlow]!.keys.toList()
      ..sort();

    return [for (final year in years) _figuresFor(year, seriesByMetric)];
  }

  static FiscalYearFigures _figuresFor(
    int year,
    Map<XbrlMetric, Map<int, double>> seriesByMetric,
  ) {
    double? valueOf(XbrlMetric metric) => seriesByMetric[metric]![year];

    // Total debt is only meaningful when the company reports at least one
    // balance-sheet component for the year; without any, a `0` total would
    // read as "no debt" when the truth is "not reported".
    /// Adds up a group of balance-sheet lines, or `null` where the filer
    /// reported none of them.
    double? sumOf(List<XbrlMetric> components) {
      final hasAny = components.any(
        (metric) => seriesByMetric[metric]!.containsKey(year),
      );
      if (!hasAny) return null;
      return components.fold<double>(
        0,
        (sum, metric) => sum + (valueOf(metric) ?? 0),
      );
    }

    return FiscalYearFigures(
      fiscalYear: year,
      revenue: valueOf(XbrlMetric.revenue),
      priorRevenue: seriesByMetric[XbrlMetric.revenue]![year - 1],
      netIncome: valueOf(XbrlMetric.netIncome),
      operatingCashFlow: valueOf(XbrlMetric.operatingCashFlow),
      capitalExpenditure: valueOf(XbrlMetric.capitalExpenditure),
      totalDebt: sumOf(XbrlMetric.debtComponents),
      cash: sumOf(XbrlMetric.cashComponents),
      dilutedShares: valueOf(XbrlMetric.dilutedShares),
      operatingIncome: valueOf(XbrlMetric.operatingIncome),
      depreciationAmortisation: valueOf(XbrlMetric.depreciationAmortisation),
      totalAssets: valueOf(XbrlMetric.totalAssets),
      shareholdersEquity: valueOf(XbrlMetric.shareholdersEquity),
      interestExpense:
          valueOf(XbrlMetric.interestExpense) ??
          _borrowingInterest(
            paid: valueOf(XbrlMetric.interestPaid),
            assets: valueOf(XbrlMetric.totalAssets),
          ),
    );
  }

  /// Cash interest large enough to be the price of borrowings, or `null`.
  ///
  /// Read only for filers that report no accrual interest concept at all,
  /// which is the shape that used to slip past the debt-free test: PACCAR,
  /// Textron and Ares Management each fund themselves through an arm that
  /// tags neither its borrowings nor their cost under any concept this parser
  /// can see, and all three read as owing nothing.
  ///
  /// Size is the test because a company that owes nothing still pays a little
  /// interest — commitment fees on a revolver it has never drawn, finance
  /// charges on leases — and any amount at all would call Lululemon a
  /// borrower over $1.0M. Measured against the balance sheet it is carried
  /// on, the two separate cleanly: across the directory's largest filers
  /// reading as debt-free, the fees stop at 0.18% of assets (American Eagle)
  /// and the smallest genuine borrower starts at 0.21% (Green Dot). Everything
  /// above is a real lender being paid — Green Dot, NVR, First Industrial,
  /// CubeSmart, Global Partners, PACCAR, Ares, ARMOUR — and everything below
  /// is a retailer's facility fees.
  static double? _borrowingInterest({
    required double? paid,
    required double? assets,
  }) {
    if (paid == null || paid <= 0) return null;
    if (assets == null || assets <= 0) return null;
    return paid / assets > _borrowingInterestToAssets ? paid : null;
  }

  /// Merges a metric's candidate tags into one series, earlier tags winning.
  static Map<int, double> _annualSeries(
    Map<String, dynamic> facts,
    XbrlMetric metric,
  ) {
    final combined = <int, double>{};
    for (final tag in metric.tags.reversed) {
      combined.addAll(
        _annualSeriesForTag(
          facts,
          tag,
          isInstant: metric.isInstant,
          unit: metric.unit,
        ),
      );
    }
    return combined;
  }

  /// One value per fiscal year for a single tag, labelled the way the company
  /// labels its own years.
  ///
  /// `fy` on a fact is the fiscal year of the *filing*, not of the value: a
  /// 10-K restates the two years before it, and all three arrive tagged with
  /// the same `fy`. So facts are grouped by filing, ordered by period, and the
  /// newest one in each filing takes that filing's `fy` while the comparatives
  /// beneath it take `fy - 1`, `fy - 2`. Reading `fy` directly would report a
  /// prior year's figure — or a quarterly one — under the wrong heading.
  static Map<int, double> _annualSeriesForTag(
    Map<String, dynamic> facts,
    String tag, {
    required bool isInstant,
    XbrlUnit unit = XbrlUnit.usd,
  }) {
    final usGaap = facts[_factsKey]?[_usGaapKey] as Map<String, dynamic>?;
    final units = usGaap?[tag]?[_unitsKey]?[unit.key] as List<dynamic>?;
    if (units == null) return const {};

    final factsByFiling = <String, List<Map<String, dynamic>>>{};
    for (final raw in units) {
      final fact = raw as Map<String, dynamic>;
      if (fact[_formKey] != _annualForm) continue;
      if (fact[_fiscalYearKey] is! int) continue;
      if (fact[_valueKey] is! num) continue;

      // A duration fact carries a start date; a point-in-time one does not.
      final start = fact[_startKey] as String?;
      if (isInstant == (start != null)) continue;
      if (start != null && !_spansAFullYear(start, fact[_endKey] as String)) {
        continue;
      }

      final accession = fact[_accessionKey] as String?;
      if (accession == null) continue;
      (factsByFiling[accession] ??= []).add(fact);
    }

    final series = <int, double>{};
    // Oldest filing first, so a later restatement of a year wins.
    final filings = factsByFiling.keys.toList()
      ..sort((a, b) {
        final byYear = (factsByFiling[a]!.first[_fiscalYearKey] as int)
            .compareTo(factsByFiling[b]!.first[_fiscalYearKey] as int);
        return byYear != 0 ? byYear : a.compareTo(b);
      });

    for (final accession in filings) {
      final periods = factsByFiling[accession]!
        ..sort(
          (a, b) => (a[_endKey] as String).compareTo(b[_endKey] as String),
        );
      final filingYear = periods.last[_fiscalYearKey] as int;
      for (var i = 0; i < periods.length; i++) {
        final year = filingYear - (periods.length - 1 - i);
        series[year] = (periods[i][_valueKey] as num).toDouble();
      }
    }
    return series;
  }

  static bool _spansAFullYear(String start, String end) {
    final days = DateTime.parse(end).difference(DateTime.parse(start)).inDays;
    return days >= _minAnnualDays && days <= _maxAnnualDays;
  }
}

/// Identifies one fiscal quarter, so quarters sort and compare like numbers.
class QuarterKey implements Comparable<QuarterKey> {
  const QuarterKey(this.year, this.quarter);

  final int year;
  final int quarter;

  /// The same quarter a year earlier, which is what growth is measured against.
  QuarterKey get yearEarlier => QuarterKey(year - 1, quarter);

  @override
  int compareTo(QuarterKey other) => year != other.year
      ? year.compareTo(other.year)
      : quarter.compareTo(other.quarter);

  @override
  bool operator ==(Object other) =>
      other is QuarterKey && other.year == year && other.quarter == quarter;

  @override
  int get hashCode => year * _quartersPerYear + quarter;

  @override
  String toString() => 'Q$quarter FY$year';
}
