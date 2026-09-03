import 'package:equatable/equatable.dart';

/// The three readings a price target is quoted under.
enum PriceCase {
  /// The company's weaker years repeated.
  bear,

  /// Its typical year repeated.
  neutral,

  /// Its stronger years repeated.
  bull,
}

/// What a share is worth if a company keeps growing the way it has.
///
/// Not a forecast. Every one of these is the same discounted cash flow run at
/// a different growth rate, and the three rates are read off the company's own
/// record rather than guessed: the quarter of its years that went worst, its
/// middle year, and the quarter that went best. A price target is only as good
/// as the growth behind it, so the growth here is the one thing that is not
/// invented — and the report prints it beside the target so a reader can
/// disagree with the assumption rather than with the arithmetic.
class PriceTarget extends Equatable {
  const PriceTarget({
    required this.scenario,
    required this.growthPercent,
    required this.valuePerShare,
  });

  final PriceCase scenario;

  /// The annual revenue growth this target assumes, in percentage points.
  final double growthPercent;

  final double valuePerShare;

  /// How far [valuePerShare] sits from [price], as a percentage. Positive
  /// means the target is above the price.
  double upsidePercentFrom(double price) =>
      price <= 0 ? 0 : (valuePerShare - price) / price * 100;

  @override
  List<Object?> get props => [scenario, growthPercent, valuePerShare];
}
