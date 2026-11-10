import 'dart:math' as math;

import 'package:pickstock/data/research/framework_question.dart';
import 'package:pickstock/data/snapshot/financial_snapshot.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/valuation/normalised_cash_flow.dart';
import 'package:pickstock/data/valuation/valuation.dart';
import 'package:pickstock/data/valuation/valuation_verdict.dart';
import 'package:pickstock/l10n/app_localizations.dart';

/// The window growth, margins and cash are judged over: the framework's own
/// "three or more years".
const int _window = 3;

/// Revenue growing slower than this a year, compounded, is flat: below
/// inflation it is a business shrinking in real terms.
const double _flatGrowthPercent = 2;

/// A latest year this far down reverses the trend, unless the trend before it
/// was strong enough for one bad year to be a dip.
const double _reversalPercent = -5;
const double _clearRisePercent = 5;

/// A fall in revenue this large in one year is as often a business sold, with
/// the years after restated, as a decline — see `FrameworkPrompts`. The
/// filings cannot tell which, so the question is left to the reading.
const double _restatementDropPercent = -25;

/// How far margins may move over the window, in points, and still be
/// holding; and how far down they must go to be falling.
const double _marginHoldingPoints = -1;
const double _marginFallingPoints = -3;

/// Operating cash flow under this share of profit, summed over the window, is
/// profit not turning into cash; at or above the second it is backed by it.
const double _poorConversion = 0.5;
const double _goodConversion = 0.8;

/// Debt that would take more years than this of the business's typical spare
/// cash to clear is more than the cash flow can carry. Three years' worth is
/// already taken off the fair value; past eight it is the risk itself.
const double _maxPaybackYears = 8;

/// Operating profit under this many times the interest bill leaves the
/// lenders one bad year from not being paid.
const double _minInterestCover = 1.5;

/// Net debt above this many times operating profit before depreciation is
/// past what lenders treat as investment grade, with room to spare.
const double _maxDebtToEarnings = 5;

/// Industries whose makers lend to their own customers through a finance arm
/// the filings consolidate: motor vehicles, farm machinery, construction
/// machinery. Ford, General Motors, PACCAR, Deere, CNH and Caterpillar carry
/// their lending arms' borrowings, which are backed by the loans they made,
/// beside the factories' — General Motors reads as six times its operating
/// profit in debt when its car business holds net cash. No debt measure the
/// filings support tells the two apart, so these are left to the reading.
const Set<int> _captiveFinanceSics = {3711, 3523, 3531};

/// Why the filings settled a question the way they did.
enum FilingsReason {
  growing,
  notGrowing,
  reversing,
  dipInRise,
  marginsHolding,
  marginsFalling,
  marginsSlipping,
  cashBacked,
  cashPositive,
  cashBurning,
  profitNotCash,
  cashUneven,
  debtBeyondCash,
  debtWithoutEarnings,
  interestUncovered,
  belowRange,
  aboveRange,
  inRange,
  cannotValue,
  noPrice,
}

/// What the filings alone say about one question, and the figures that
/// decided it.
///
/// For the questions a filing can settle, this is the verdict, and the
/// model's reading is notes beside it. A 12B model asked whether revenue that
/// grew 7% a year is growing will say yes nearly always and no now and then,
/// and a verdict that changes with the run is not a screen.
class FilingsReading {
  const FilingsReading(this.verdict, this.reason, [this.figures = const []]);

  final FrameworkVerdict verdict;
  final FilingsReason reason;

  /// The figures the reason quotes, in the order its sentence uses them.
  final List<double> figures;

  /// The reason in a sentence, with its figures.
  String describe(
    AppLocalizations strings,
    String Function(double) percent,
    String Function(double) ratio,
    String Function(double) price,
  ) {
    double at(int index) => figures[index];
    return switch (reason) {
      FilingsReason.growing => strings.filingsGrowing(percent(at(0))),
      FilingsReason.notGrowing => strings.filingsNotGrowing(percent(at(0))),
      FilingsReason.reversing => strings.filingsReversing(
        percent(at(0)),
        percent(at(1)),
      ),
      FilingsReason.dipInRise => strings.filingsDipInRise(
        percent(at(0)),
        percent(at(1)),
      ),
      FilingsReason.marginsHolding => strings.filingsMarginsHolding(
        ratio(at(0)),
      ),
      FilingsReason.marginsFalling => strings.filingsMarginsFalling(
        ratio(-at(0)),
      ),
      FilingsReason.marginsSlipping => strings.filingsMarginsSlipping(
        ratio(-at(0)),
      ),
      FilingsReason.cashBacked => strings.filingsCashBacked(ratio(at(0))),
      FilingsReason.cashPositive => strings.filingsCashPositive,
      FilingsReason.cashBurning => strings.filingsCashBurning,
      FilingsReason.profitNotCash => strings.filingsProfitNotCash(ratio(at(0))),
      FilingsReason.cashUneven => strings.filingsCashUneven,
      FilingsReason.debtBeyondCash => strings.filingsDebtBeyondCash(
        ratio(at(0)),
        ratio(at(1)),
      ),
      FilingsReason.debtWithoutEarnings => strings.filingsDebtWithoutEarnings,
      FilingsReason.interestUncovered => strings.filingsInterestUncovered(
        ratio(at(0)),
      ),
      FilingsReason.belowRange => strings.filingsBelowRange(
        price(at(0)),
        price(at(1)),
        price(at(2)),
      ),
      FilingsReason.aboveRange => strings.filingsAboveRange(
        price(at(0)),
        price(at(1)),
        price(at(2)),
      ),
      FilingsReason.inRange => strings.filingsInRange(
        price(at(0)),
        price(at(1)),
        price(at(2)),
      ),
      FilingsReason.cannotValue => strings.filingsCannotValue,
      FilingsReason.noPrice => strings.filingsNoPrice,
    };
  }
}

/// Settles what the filings can settle of the seven questions.
///
/// Growth, margins and cash are questions about figures the app holds, and
/// the framework states each as a rule over them; timing is the price against
/// the range the filings support. Moat and management are not in a filing at
/// all, and are left to the reading. Risk is both: the filings can say the
/// debt is more than the cash flow carries, which is a no whatever else is
/// true, but not that nothing else threatens the business — so they only
/// ever answer it no, and otherwise leave it to the reading.
///
/// Banks, insurers and REITs are left to the reading on everything but
/// growth: their margins and cash flow do not mean what these rules assume.
abstract final class FilingsCheck {
  /// What the filings say about [question], or `null` where they do not
  /// settle it.
  static FilingsReading? of(
    FrameworkQuestion question,
    FinancialSnapshot snapshot, {
    Valuation? valuation,
  }) {
    final covered = Valuation.covers(snapshot.company.sic);
    return switch (question) {
      FrameworkQuestion.growth => _growth(snapshot.years),
      FrameworkQuestion.margins => covered ? _margins(snapshot.years) : null,
      FrameworkQuestion.cash => covered ? _cash(snapshot.years) : null,
      FrameworkQuestion.risk => covered ? _risk(snapshot) : null,
      FrameworkQuestion.timing => _timing(valuation),
      FrameworkQuestion.moat || FrameworkQuestion.management => null,
    };
  }

  /// Whether the filings answer [question] whatever the figures, so the
  /// model need not be asked it at all.
  static bool settlesAlone(FrameworkQuestion question) =>
      question == FrameworkQuestion.timing;

  static FilingsReading? _growth(List<FiscalYearFigures> years) {
    if (years.length <= _window) return null;
    final recent = years.sublist(years.length - _window - 1);
    if (recent.any((year) => year.revenue == null || year.revenue! <= 0)) {
      return null;
    }
    // A restatement makes every rate across it wrong.
    for (final year in recent.skip(1)) {
      final change = year.revenueGrowthPercent;
      if (change != null && change <= _restatementDropPercent) return null;
    }
    final rate =
        (math
                .pow(recent.last.revenue! / recent.first.revenue!, 1 / _window)
                .toDouble() -
            1) *
        100;
    final latest =
        (recent.last.revenue! / recent[recent.length - 2].revenue! - 1) * 100;

    if (rate <= _flatGrowthPercent) {
      return FilingsReading(FrameworkVerdict.no, FilingsReason.notGrowing, [
        rate,
      ]);
    }
    if (latest <= _reversalPercent) {
      return rate >= _clearRisePercent
          ? FilingsReading(FrameworkVerdict.unclear, FilingsReason.dipInRise, [
              rate,
              latest,
            ])
          : FilingsReading(FrameworkVerdict.no, FilingsReason.reversing, [
              rate,
              latest,
            ]);
    }
    return FilingsReading(FrameworkVerdict.yes, FilingsReason.growing, [rate]);
  }

  /// Operating margin as the business earned it: before a write-down, which
  /// is history rather than the trend.
  static double? _underlyingMargin(FiscalYearFigures year) =>
      year.operatingMarginBeforeImpairmentPercent ??
      year.operatingMarginPercent;

  static FilingsReading? _margins(List<FiscalYearFigures> years) {
    if (years.length <= _window) return null;
    final start = years[years.length - 1 - _window];
    final end = years.last;
    final startOperating = _underlyingMargin(start);
    final endOperating = _underlyingMargin(end);
    if (startOperating == null || endOperating == null) return null;

    // The worse of the two: gross margin falling under a steady operating
    // margin is pricing power going, hidden for a while by cutting overheads.
    var change = endOperating - startOperating;
    final startGross = start.grossMarginPercent;
    final endGross = end.grossMarginPercent;
    if (startGross != null && endGross != null) {
      change = math.min(change, endGross - startGross);
    }

    if (change >= _marginHoldingPoints) {
      return FilingsReading(
        FrameworkVerdict.yes,
        FilingsReason.marginsHolding,
        [change],
      );
    }
    return change <= _marginFallingPoints
        ? FilingsReading(FrameworkVerdict.no, FilingsReason.marginsFalling, [
            change,
          ])
        : FilingsReading(
            FrameworkVerdict.unclear,
            FilingsReason.marginsSlipping,
            [change],
          );
  }

  static FilingsReading? _cash(List<FiscalYearFigures> years) {
    if (years.length < _window) return null;
    final recent = years.sublist(years.length - _window);
    if (recent.any(
      (year) => year.operatingCashFlow == null || year.freeCashFlow == null,
    )) {
      return null;
    }

    final operating = recent.fold<double>(
      0,
      (sum, year) => sum + year.operatingCashFlow!,
    );
    final free = recent.fold<double>(
      0,
      (sum, year) => sum + year.freeCashFlow!,
    );
    final negativeYears = recent
        .where((year) => year.operatingCashFlow! <= 0)
        .length;
    if (negativeYears >= 2 || free <= 0) {
      return const FilingsReading(
        FrameworkVerdict.no,
        FilingsReason.cashBurning,
      );
    }

    // Profit before write-downs, which are charges with no cash behind them.
    final profits = [
      for (final year in recent)
        if (year.netIncome case final income?) income + (year.impairment ?? 0),
    ];
    final profit = profits.length == recent.length
        ? profits.fold<double>(0, (sum, value) => sum + value)
        : null;
    final conversion = profit == null || profit <= 0
        ? null
        : operating / profit;

    if (conversion != null && conversion < _poorConversion) {
      return FilingsReading(FrameworkVerdict.no, FilingsReason.profitNotCash, [
        conversion,
      ]);
    }
    if (negativeYears == 0 &&
        (conversion == null || conversion >= _goodConversion)) {
      // A loss-maker throwing off cash is generating it, with no profit to
      // measure the cash against.
      return conversion == null
          ? const FilingsReading(
              FrameworkVerdict.yes,
              FilingsReason.cashPositive,
            )
          : FilingsReading(FrameworkVerdict.yes, FilingsReason.cashBacked, [
              conversion,
            ]);
    }
    return const FilingsReading(
      FrameworkVerdict.unclear,
      FilingsReason.cashUneven,
    );
  }

  /// The debt a filing shows the business cannot carry, or `null`.
  ///
  /// Only for a company that owes more than it holds, and only where its
  /// operating profit is tagged: without it, every multiple of earnings is a
  /// multiple of nothing. Each test needs two measures to agree, because each
  /// alone misreads a kind of company the directory has plenty of.
  ///
  /// Interest cover alone fails Ford and General Motors, whose interest bill
  /// is mostly their lending arms', paid out of car loans the filings cannot
  /// separate from the factories — so a thin cover only counts where there is
  /// no spare cash to pay it from either. Debt over spare cash alone fails
  /// Amazon, whose cash goes on building rather than repaying, at twelve
  /// years against 1.1 times its operating profit before depreciation — so a
  /// long payback only counts where that multiple is high as well.
  static FilingsReading? _risk(FinancialSnapshot snapshot) {
    if (_captiveFinanceSics.contains(snapshot.company.sic)) return null;
    final latest = snapshot.latest;
    final netDebt = snapshot.trailing?.netDebt ?? latest.netDebt;
    if (netDebt == null || netDebt <= 0) return null;
    final operating =
        latest.operatingIncomeBeforeImpairment ?? latest.operatingIncome;
    if (operating == null) return null;

    final flow = NormalisedCashFlow.of(snapshot)?.flow;
    final hasSpareCash = flow != null && flow > 0;
    final earnings = operating + (latest.depreciationAmortisation ?? 0);

    if (earnings <= 0 && !hasSpareCash) {
      return FilingsReading(
        FrameworkVerdict.no,
        FilingsReason.debtWithoutEarnings,
        [netDebt],
      );
    }

    final interest = latest.interestExpense;
    if (interest != null && interest > 0 && !hasSpareCash) {
      final cover = operating / interest;
      if (cover < _minInterestCover) {
        return FilingsReading(
          FrameworkVerdict.no,
          FilingsReason.interestUncovered,
          [cover],
        );
      }
    }

    if (hasSpareCash && earnings > 0) {
      final payback = netDebt / flow;
      if (payback > _maxPaybackYears &&
          netDebt / earnings > _maxDebtToEarnings) {
        return FilingsReading(
          FrameworkVerdict.no,
          FilingsReason.debtBeyondCash,
          [payback, netDebt / earnings],
        );
      }
    }
    return null;
  }

  static FilingsReading _timing(Valuation? valuation) {
    if (valuation == null) {
      return const FilingsReading(
        FrameworkVerdict.unclear,
        FilingsReason.noPrice,
      );
    }
    final low = valuation.fairValueLow;
    final high = valuation.fairValueHigh;
    if (low == null || high == null) {
      return const FilingsReading(
        FrameworkVerdict.unclear,
        FilingsReason.cannotValue,
      );
    }
    final figures = [valuation.pricePerShare, low, high];
    return switch (valuation.verdict) {
      ValuationVerdict.undervalued => FilingsReading(
        FrameworkVerdict.yes,
        FilingsReason.belowRange,
        figures,
      ),
      ValuationVerdict.overvalued => FilingsReading(
        FrameworkVerdict.no,
        FilingsReason.aboveRange,
        figures,
      ),
      ValuationVerdict.fairlyValued => FilingsReading(
        FrameworkVerdict.unclear,
        FilingsReason.inRange,
        figures,
      ),
      ValuationVerdict.unknown ||
      ValuationVerdict.notCovered => const FilingsReading(
        FrameworkVerdict.unclear,
        FilingsReason.cannotValue,
      ),
    };
  }
}
