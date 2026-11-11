/// A figure the valuation can read from the newest 10-Q rather than the
/// annual report, where the quarter is the newer of the two.
enum QuarterFigure {
  /// The twelve months' revenue the typical margin is applied to.
  revenue,

  /// The cash and debt at the quarter end.
  netDebt,

  /// The diluted average share count over the year to date.
  dilutedShares,
}
