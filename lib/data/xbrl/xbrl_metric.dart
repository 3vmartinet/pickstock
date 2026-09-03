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

  /// What the company spent on the assets it operates with.
  ///
  /// The last four are the names a filer reaches for when it reports none of
  /// the concepts above, and are read only in that case. Without them a third
  /// of the directory reported operating cash flow and no capital spending at
  /// all, which left the most capital-hungry companies in it unanswerable:
  /// Verizon tags its $17.0B under `...OtherProductiveAssets`, Eli Lilly its
  /// $7.8B under `...OtherPropertyPlantAndEquipment`, and the oil and gas
  /// producers under concepts of their own — EOG $6.1B, Diamondback $3.5B.
  ///
  /// `PaymentsToAcquireOilAndGasProperty` is deliberately not among them: it
  /// is what a producer pays to buy acreage from someone else, which is an
  /// acquisition rather than the cost of running what it already has.
  /// Diamondback reports $5.9B of it beside the $3.5B it spent drilling, and
  /// reading both would show a company that funds itself as one that cannot.
  /// `CapitalExpendituresIncurredButNotYetPaid` is excluded for the plainer
  /// reason that it is not a payment.
  capitalExpenditure(
    tags: [
      'PaymentsToAcquirePropertyPlantAndEquipment',
      'PaymentsForCapitalImprovements',
      'PaymentsToAcquireProductiveAssets',
      'PaymentsToAcquireOilAndGasPropertyAndEquipment',
      'PaymentsToExploreAndDevelopOilAndGasProperties',
      'PaymentsToAcquireOtherProductiveAssets',
      'PaymentsToAcquireOtherPropertyPlantAndEquipment',
    ],
  ),

  /// `...AndCapitalLeaseObligations` is what filers who fold leases into
  /// borrowings use instead of the plain concept — Coca-Cola reports $42.1B
  /// there and nothing under either tag above it, so without it the company
  /// read as holding $1.5B of debt against $13.9B of cash.
  ///
  /// Convertible notes come last, so they are only read where a filer reports
  /// no plain long-term debt concept at all. Super Micro is one: its
  /// borrowings are entirely convertible notes, and it read as debt-free while
  /// owing $4.6B. Where a filer reports both, the plain concept already
  /// includes the notes and reading them again would double the debt.
  ///
  /// The last six are the names a filer reaches for when it reports none of
  /// the concepts above, and are read only in that case — General Motors
  /// carries $131.6B under the combined tag and nothing under any other, so
  /// without it the most leveraged carmaker in the directory read as holding
  /// no debt at all. State Street ($25.1B), CNH ($26.8B), D.R. Horton
  /// ($6.0B), Everest ($2.4B) and Raymond James ($4.2B) were the same.
  ///
  /// Two of them state a total including current maturities, which the
  /// current-debt component below would count again — but only for a filer
  /// that reports both, and none of the six above. That is a narrower error
  /// than reporting a borrower as debt-free, which is what these fix.
  longTermDebt(
    tags: [
      'LongTermDebtNoncurrent',
      'LongTermDebtAndCapitalLeaseObligations',
      'LongTermDebt',
      'ConvertibleDebtNoncurrent',
      'ConvertibleLongTermNotesPayable',
      'ConvertibleNotesPayableNoncurrent',
      'DebtAndCapitalLeaseObligations',
      'LongTermDebtAndCapitalLeaseObligationsIncludingCurrentMaturities',
      'DebtLongtermAndShorttermCombinedAmount',
      'SeniorNotes',
      'NotesPayable',
      'LoansPayable',
    ],
    isInstant: true,
  ),
  currentDebt(
    tags: [
      'LongTermDebtCurrent',
      'LongTermDebtAndCapitalLeaseObligationsCurrent',
      'DebtCurrent',
      'ConvertibleDebtCurrent',
      'ConvertibleNotesPayableCurrent',
    ],
    isInstant: true,
  ),
  // Commercial paper and short-term borrowings sit under distinct concepts and
  // a company can carry both at once, so they are summed as separate debt
  // components rather than treated as fallbacks for one another (unlike the
  // long-term/current tags above, which are alternate names for one concept).
  commercialPaper(tags: ['CommercialPaper'], isInstant: true),
  shortTermBorrowings(
    tags: ['ShortTermBorrowings', 'OtherBorrowings'],
    isInstant: true,
  ),

  /// What the borrowings cost for the year.
  ///
  /// Read for what its absence says: interest is the price of debt, so a
  /// company with none of it has nothing to service. That is the only
  /// dependable way to tell "no borrowings" from "borrowings filed under a
  /// concept nobody reads" — Ford, Berkshire and KKR all report no debt this
  /// parser can find and between them $9.1B of interest.
  ///
  /// Cash interest paid is not among these tags: it is a supplemental
  /// cash-flow line that debt-free filers report anyway for lease and
  /// facility fees, and reading it here would call Lululemon a borrower over
  /// $1.0M of them. It is read separately, and only on its size — see
  /// [interestPaid].
  interestExpense(
    tags: [
      'InterestExpense',
      'InterestExpenseNonoperating',
      'InterestAndDebtExpense',
      'InterestExpenseOperating',
      'InterestExpenseBorrowings',
      'InterestExpenseDebt',
      // What a mortgage REIT's borrowings are called: it funds itself through
      // repurchase agreements and reports no debt concept at all. ARMOUR
      // Residential pays $642M of this against $21.0B of assets and read as
      // owing nothing.
      'InterestExpenseSecuritiesSoldUnderAgreementsToRepurchase',
    ],
  ),

  /// Cash interest actually handed over during the year.
  ///
  /// A last resort, read only where a filer reports no accrual interest
  /// concept at all, and then only when it is large enough to be the price of
  /// borrowings — see `CompanyFactsParser` for the test and why it is needed.
  /// Filers that report neither debt nor interest under any concept this
  /// parser can see are otherwise read as owing nothing: PACCAR funds its
  /// truck loans through a captive finance arm and paid $693M, Textron and
  /// Ares Management the same shape.
  interestPaid(tags: ['InterestPaidNet', 'InterestPaid']),
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
