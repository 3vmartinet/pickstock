/// The unit a concept is reported in. Money and share counts sit in separate
/// buckets under the same tag.
enum XbrlUnit {
  usd('USD'),
  shares('shares');

  const XbrlUnit(this.key);

  /// The key this unit appears under in a fact's `units` map.
  final String key;
}

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

  /// Profit from the business itself, before interest, tax and one-offs.
  ///
  /// The margin to watch: a company can grow revenue for years while operating
  /// margin quietly collapses, and revenue growth alone would call that a
  /// success. `GrossProfit` would be the purer signal but is not dependable —
  /// Alphabet and Ford do not tag it and Amazon tags a figure that is plainly
  /// not its gross profit.
  operatingIncome(tags: ['OperatingIncomeLoss']),

  /// Depreciation and amortisation, which says whether heavy capital spending
  /// is building something new or merely replacing what wore out.
  depreciationAmortisation(
    tags: [
      'DepreciationDepletionAndAmortization',
      'DepreciationAmortizationAndAccretionNet',
      'DepreciationAndAmortization',
      'Depreciation',
    ],
  ),

  /// Everything the company owns, for how much capital the returns are earned
  /// on.
  totalAssets(tags: ['Assets'], isInstant: true),

  /// The owners' share of it.
  shareholdersEquity(
    tags: [
      'StockholdersEquity',
      'StockholdersEquityIncludingPortionAttributableToNoncontrollingInterest',
    ],
    isInstant: true,
  ),
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

  /// `...AndCapitalLeaseObligations` is what filers who fold leases into
  /// borrowings use instead of the plain concept — Coca-Cola reports $42.1B
  /// there and nothing under either tag above it, so without it the company
  /// read as holding $1.5B of debt against $13.9B of cash.
  longTermDebt(
    tags: [
      'LongTermDebtNoncurrent',
      'LongTermDebtAndCapitalLeaseObligations',
      'LongTermDebt',
    ],
    isInstant: true,
  ),
  currentDebt(
    tags: [
      'LongTermDebtCurrent',
      'LongTermDebtAndCapitalLeaseObligationsCurrent',
      'DebtCurrent',
    ],
    isInstant: true,
  ),
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
  ),

  /// Treasury bills, commercial paper and the like: liquid holdings a company
  /// keeps beside its cash and could settle a debt with tomorrow.
  ///
  /// Reading cash without these badly understates the cash-rich. Microsoft
  /// keeps $55.9B of its $76.8B here and only $20.9B as cash proper, so
  /// against $40.3B of debt it looked like a net borrower when it holds
  /// $36.5B more than it owes.
  ///
  /// These tags are alternate names for one line, not components of it, so the
  /// first with data wins. Verified against filers that also report the
  /// combined `CashCashEquivalentsAndShortTermInvestments`: cash plus the tag
  /// chosen here reproduces it exactly for Microsoft, Alphabet and Coca-Cola.
  shortTermInvestments(
    tags: [
      'ShortTermInvestments',
      'OtherShortTermInvestments',
      'MarketableSecuritiesCurrent',
      'AvailableForSaleSecuritiesDebtSecuritiesCurrent',
      'AvailableForSaleSecuritiesCurrent',
    ],
    isInstant: true,
  ),

  /// Diluted share count for the year, which is what earnings per share is
  /// struck against — so it is the right divisor for a per-share figure.
  dilutedShares(
    tags: [
      'WeightedAverageNumberOfDilutedSharesOutstanding',
      'WeightedAverageNumberOfSharesOutstandingBasic',
      'WeightedAverageNumberOfDilutedSharesOutstandingAdjustment',
    ],
    unit: XbrlUnit.shares,
  );

  const XbrlMetric({
    required this.tags,
    this.isInstant = false,
    this.unit = XbrlUnit.usd,
  });

  /// Candidate us-gaap concept names, most preferred first.
  final List<String> tags;

  /// Whether the concept is reported as a point in time (balance sheet)
  /// rather than over a period (income statement, cash flow).
  final bool isInstant;

  /// Which units bucket the values live in.
  final XbrlUnit unit;

  /// The components that add up to total borrowings.
  static const List<XbrlMetric> debtComponents = [
    longTermDebt,
    currentDebt,
    commercialPaper,
    shortTermBorrowings,
  ];

  /// The components that add up to liquid holdings, which is what net debt is
  /// measured against.
  static const List<XbrlMetric> cashComponents = [cash, shortTermInvestments];
}
