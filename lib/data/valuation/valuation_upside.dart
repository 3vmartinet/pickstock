import 'package:equatable/equatable.dart';
import 'package:pickstock/data/valuation/valuation.dart';

/// How far a company's price would have to move to reach each end of its
/// fair-value band, as percentages. Positive means the bound is above the
/// price.
///
/// Kept per company by the list valuation, beside the verdict, so the list
/// can be ranked by either bound. Either figure is `null` where the band
/// could not be built.
class ValuationUpside extends Equatable {
  const ValuationUpside({required this.toLow, required this.toHigh});

  ValuationUpside.of(Valuation valuation)
    : toLow = valuation.percentToLow,
      toHigh = valuation.percentToHigh;

  /// How far the price is from the bottom of the band.
  final double? toLow;

  /// How far the price is from the top of the band.
  final double? toHigh;

  @override
  List<Object?> get props => [toLow, toHigh];
}
