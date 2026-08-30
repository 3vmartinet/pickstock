/// The us-gaap XBRL concepts PickStock reads out of a company facts payload.
///
/// Companies do not all tag the same line item with the same concept, so every
/// metric carries an ordered list of candidate tags: the first tag with data
/// for a fiscal year wins. [isInstant] separates balance-sheet concepts
/// (a point in time) from income-statement and cash-flow ones (a duration),
/// which is how a full-year fact is told apart from a quarterly one.
enum XbrlMetric {
  revenue(
    tags: [
      'RevenueFromContractWithCustomerExcludingAssessedTax',
      'RevenueFromContractWithCustomerIncludingAssessedTax',
      'Revenues',
      'SalesRevenueNet',
    ],
  ),
  netIncome(tags: ['NetIncomeLoss']),
  operatingCashFlow(
    tags: [
      'NetCashProvidedByUsedInOperatingActivities',
      'NetCashProvidedByUsedInOperatingActivitiesContinuingOperations',
    ],
  ),
  capitalExpenditure(
    tags: [
      'PaymentsToAcquirePropertyPlantAndEquipment',
      'PaymentsForCapitalImprovements',
      'PaymentsToAcquireProductiveAssets',
    ],
  ),
  longTermDebt(
    tags: ['LongTermDebtNoncurrent', 'LongTermDebt'],
    isInstant: true,
  ),
  currentDebt(tags: ['LongTermDebtCurrent', 'DebtCurrent'], isInstant: true),
  // Commercial paper and short-term borrowings sit under distinct concepts and
  // a company can carry both at once, so they are summed as separate debt
  // components rather than treated as fallbacks for one another (unlike the
  // long-term/current tags above, which are alternate names for one concept).
  commercialPaper(tags: ['CommercialPaper'], isInstant: true),
  shortTermBorrowings(tags: ['ShortTermBorrowings'], isInstant: true),
  cash(
    tags: [
      'CashAndCashEquivalentsAtCarryingValue',
      'CashCashEquivalentsRestrictedCashAndRestrictedCashEquivalents',
    ],
    isInstant: true,
  );

  const XbrlMetric({required this.tags, this.isInstant = false});

  /// Candidate us-gaap concept names, most preferred first.
  final List<String> tags;

  /// Whether the concept is reported as a point in time (balance sheet)
  /// rather than over a period (income statement, cash flow).
  final bool isInstant;

  /// The components that add up to total borrowings.
  static const List<XbrlMetric> debtComponents = [
    longTermDebt,
    currentDebt,
    commercialPaper,
    shortTermBorrowings,
  ];
}
