import 'package:get_it/get_it.dart';
import 'package:pickstock/data/valuation/valuation.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/repo/format_repo.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();

/// The supporting ratios shown under a valuation verdict.
///
/// Each case pulls its own figure out of a [Valuation], knows the range it is
/// cheap or expensive in, and formats itself — the ratio being a multiple, a
/// yield or a plain number is the enum's business, not the widget's.
enum ValuationMetric {
  priceEarnings(cheapBelow: 15, expensiveAbove: 25),
  enterpriseValueToFreeCashFlow(cheapBelow: 15, expensiveAbove: 25),

  /// A yield, so the thresholds run the other way: more is cheaper.
  freeCashFlowYield(cheapBelow: 3, expensiveAbove: 6, isHigherCheaper: true),
  growthAdjusted(cheapBelow: 1, expensiveAbove: 2),
  priceToSales(cheapBelow: 2, expensiveAbove: 6);

  const ValuationMetric({
    required this.cheapBelow,
    required this.expensiveAbove,
    this.isHigherCheaper = false,
  });

  /// Under this value the ratio reads cheap, over [expensiveAbove] expensive,
  /// and between them fair. Reversed when [isHigherCheaper].
  final double cheapBelow;
  final double expensiveAbove;
  final bool isHigherCheaper;

  String getLabel(AppLocalizations strings) => switch (this) {
    ValuationMetric.priceEarnings => strings.labelPriceEarnings,
    ValuationMetric.enterpriseValueToFreeCashFlow =>
      strings.labelEnterpriseValueToFreeCashFlow,
    ValuationMetric.freeCashFlowYield => strings.labelFreeCashFlowYield,
    ValuationMetric.growthAdjusted => strings.labelGrowthAdjusted,
    ValuationMetric.priceToSales => strings.labelPriceToSales,
  };

  String getHint(AppLocalizations strings) => switch (this) {
    ValuationMetric.priceEarnings => strings.hintPriceEarnings,
    ValuationMetric.enterpriseValueToFreeCashFlow =>
      strings.hintEnterpriseValueToFreeCashFlow,
    ValuationMetric.freeCashFlowYield => strings.hintFreeCashFlowYield,
    ValuationMetric.growthAdjusted => strings.hintGrowthAdjusted,
    ValuationMetric.priceToSales => strings.hintPriceToSales,
  };

  double? getValue(Valuation valuation) => switch (this) {
    ValuationMetric.priceEarnings => valuation.priceEarningsRatio,
    ValuationMetric.enterpriseValueToFreeCashFlow =>
      valuation.enterpriseValueToFreeCashFlow,
    ValuationMetric.freeCashFlowYield => valuation.freeCashFlowYieldPercent,
    ValuationMetric.growthAdjusted => valuation.growthAdjustedRatio,
    ValuationMetric.priceToSales => valuation.priceToSalesRatio,
  };

  /// The figure as it should read: a yield carries its percent sign, every
  /// other ratio is a bare multiple to one decimal.
  String? getFormattedValue(Valuation valuation) {
    final value = getValue(valuation);
    if (value == null) return null;
    return this == ValuationMetric.freeCashFlowYield
        ? _formatRepo.percent(value)
        : _formatRepo.ratio(value);
  }

  /// Whether the ratio is cheap, expensive, or neither. `null` covers both the
  /// fair middle and a ratio that cannot be stated, and the caller separates
  /// the two by whether [getValue] returned anything.
  bool? getSentiment(Valuation valuation) {
    final value = getValue(valuation);
    if (value == null) return null;
    final cheap = isHigherCheaper ? value > expensiveAbove : value < cheapBelow;
    if (cheap) return true;
    final expensive = isHigherCheaper
        ? value < cheapBelow
        : value > expensiveAbove;
    return expensive ? false : null;
  }
}
