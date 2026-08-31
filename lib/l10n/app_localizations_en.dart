// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PickStock';

  @override
  String get stageDirectoryLabel => 'Ticker directory';

  @override
  String get stageDirectoryDetail => 'Symbols and company names';

  @override
  String get statDownloaded => 'Downloaded';

  @override
  String get statLoaded => 'Companies read';

  @override
  String get statDataSets => 'Data sets';

  @override
  String get statSpeed => 'Speed';

  @override
  String get statRemaining => 'Remaining';

  @override
  String get statPending => '—';

  @override
  String get stageSectorsLabel => 'Industry codes';

  @override
  String get stageSectorsDetail =>
      'A sector for each filer, about 60 MB a quarter';

  @override
  String ingestDataSets(int read, int total) {
    return '$read / $total';
  }

  @override
  String get stageDownloadLabel => 'SEC bulk archive';

  @override
  String get stageDownloadDetail => 'About 1.4 GB, downloaded once';

  @override
  String get stageLoadLabel => 'Local database';

  @override
  String get stageLoadDetail => 'Reading filings for every company';

  @override
  String get ingestPreparing => 'Preparing your data';

  @override
  String ingestBytesOfTotal(String received, String total) {
    return '$received / $total';
  }

  @override
  String ingestRate(String rate) {
    return '$rate/s';
  }

  @override
  String ingestRateCompanies(int rate) {
    final intl.NumberFormat rateNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String rateString = rateNumberFormat.format(rate);

    return '$rateString/s';
  }

  @override
  String ingestRemaining(String duration) {
    return '$duration';
  }

  @override
  String ingestCompaniesOfTotal(int loaded, int total) {
    final intl.NumberFormat loadedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String loadedString = loadedNumberFormat.format(loaded);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$loadedString / $totalString';
  }

  @override
  String durationMinutesSeconds(int minutes, int seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String durationSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String get gateChecking => 'Checking local data…';

  @override
  String get gateRequiredTitle => 'Financial data required';

  @override
  String get gateRequiredBody =>
      'PickStock reads ten years of filings from a database on this machine. Download SEC\'s bulk archive once — about 1.4 GB — and everything after that works offline.';

  @override
  String get gateStart => 'Download SEC data';

  @override
  String get gateFailedTitle => 'Download failed';

  @override
  String get gateFailedBody =>
      'The archive could not be fetched. Check your connection and try again.';

  @override
  String get gateRetry => 'Try again';

  @override
  String get gateRefresh => 'Refresh data';

  @override
  String get updateAvailable => 'Update available';

  @override
  String updateAvailableOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'SEC rebuilt the archive on $dateString. Download it to refresh your figures.';
  }

  @override
  String get ingestWarnLeave => 'This takes a few minutes. Leave the app open.';

  @override
  String get toggleTheme => 'Toggle light / dark theme';

  @override
  String browseSubtitle(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString symbols',
      one: '1 symbol',
    );
    return '$_temp0 filed with SEC EDGAR';
  }

  @override
  String get sortByName => 'Name (A–Z)';

  @override
  String get sortRevenueOneYear => 'Revenue growth, 1 year';

  @override
  String sortRevenueYears(int years) {
    return 'Revenue growth, $years-year annualised';
  }

  @override
  String get sortFreeCashFlowOneYear => 'Free cash flow growth, 1 year';

  @override
  String get sectorTechnology => 'Tech';

  @override
  String get sectorHealthcare => 'Pharma & health';

  @override
  String get sectorFinancials => 'Finance';

  @override
  String get sectorRealEstate => 'Real estate';

  @override
  String get sectorEnergy => 'Energy';

  @override
  String get sectorUtilities => 'Utilities';

  @override
  String get sectorIndustrials => 'Industrials';

  @override
  String get sectorAutomotive => 'Automotive';

  @override
  String get sectorMaterials => 'Materials';

  @override
  String get sectorConsumer => 'Consumer';

  @override
  String get sectorCommunications => 'Media & telecom';

  @override
  String get sectorTransport => 'Transport';

  @override
  String get sectorAll => 'All';

  @override
  String get browseNoFigure => '—';

  @override
  String get browseFilterPlaceholder => 'Filter by symbol or company name';

  @override
  String browseMatchCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString matches',
      one: '1 match',
      zero: 'No matches',
    );
    return '$_temp0';
  }

  @override
  String get browseEmptyTitle => 'No matching symbols';

  @override
  String browseEmptyBody(String query) {
    return 'Nothing in EDGAR\'s directory matches \"$query\".';
  }

  @override
  String get backToList => 'Back to the list';

  @override
  String get idleShortcuts => 'Or start with one of these';

  @override
  String get idleTitle => 'Check a company before you invest';

  @override
  String get idleBody =>
      'Pick a company from the list to pull ten fiscal years of revenue, profitability, free cash flow and balance-sheet strength — straight from its own 10-K filings.';

  @override
  String loadingFetching(String ticker) {
    return 'Fetching XBRL company facts for $ticker…';
  }

  @override
  String get errorTitle => 'Could not build a snapshot';

  @override
  String errorUnknownTicker(String ticker) {
    return 'No SEC filer matches the ticker \"$ticker\".';
  }

  @override
  String errorNoAnnualData(String ticker) {
    return 'SEC EDGAR holds no annual (10-K) cash-flow figures for $ticker.';
  }

  @override
  String get errorNetwork =>
      'Could not reach SEC EDGAR. Check your connection and try again.';

  @override
  String get errorDatabaseEmpty =>
      'No data loaded yet. Download the SEC bulk archive to populate the local database.';

  @override
  String get errorService =>
      'SEC EDGAR returned an unexpected response. Try again in a moment.';

  @override
  String get retry => 'Try again';

  @override
  String get sectionSanityCheck => 'Sanity check';

  @override
  String sectionHighlights(String year) {
    return 'FY$year highlights';
  }

  @override
  String sectionQuarterHistory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Last $count quarters',
      one: 'One quarter',
    );
    return '$_temp0';
  }

  @override
  String sectionHistory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-year',
      one: 'One year',
    );
    return '$_temp0 history';
  }

  @override
  String get checkRevenueGrowth => 'Revenue growing?';

  @override
  String get checkProfitable => 'Profitable?';

  @override
  String get checkNetCash => 'More cash than debt?';

  @override
  String get verdictYes => 'Yes';

  @override
  String get verdictNo => 'No';

  @override
  String get verdictUnknown => 'n/a';

  @override
  String detailRevenueGrowing(String percent) {
    return 'Growing $percent year over year';
  }

  @override
  String detailRevenueShrinking(String percent) {
    return 'Shrinking $percent year over year';
  }

  @override
  String detailProfitable(String amount) {
    return 'Net income of $amount';
  }

  @override
  String detailUnprofitable(String amount) {
    return 'Net loss of $amount';
  }

  @override
  String detailNetCash(String amount) {
    return 'Net cash of $amount';
  }

  @override
  String detailNetDebt(String amount) {
    return 'Net debt of $amount';
  }

  @override
  String get detailNotEnoughHistory => 'Not enough filing history';

  @override
  String get detailUnavailable => 'Not reported in these filings';

  @override
  String get labelFiscalYear => 'FY';

  @override
  String get labelPeriod => 'Period';

  @override
  String labelQuarterOfYear(int quarter, int year) {
    return 'Q$quarter FY$year';
  }

  @override
  String get periodAnnual => 'Annual';

  @override
  String get periodQuarterly => 'Quarterly';

  @override
  String get sortByYear => 'Sort by fiscal year';

  @override
  String get sortNewestFirst => 'Newest first';

  @override
  String get sortOldestFirst => 'Oldest first';

  @override
  String get labelRevenue => 'Revenue';

  @override
  String get labelRevenueGrowth => 'Rev YoY';

  @override
  String get labelNetIncome => 'Net income';

  @override
  String get labelFreeCashFlow => 'Free cash flow';

  @override
  String get labelTotalDebt => 'Total debt';

  @override
  String get labelCash => 'Cash';

  @override
  String get labelNetDebt => 'Net debt';

  @override
  String labelCik(String cik) {
    return 'CIK $cik';
  }

  @override
  String labelFiscalYearsCovered(String first, String last) {
    return 'FY$first – FY$last';
  }

  @override
  String get labelNetDebtPosition => 'Net debt';

  @override
  String priorNetDebt(String amount) {
    return 'was net debt of $amount';
  }

  @override
  String priorNetCash(String amount) {
    return 'was net cash of $amount';
  }

  @override
  String get labelNetCashPosition => 'Net cash';

  @override
  String get hintRevenue => 'Top-line sales reported on the income statement.';

  @override
  String get hintNetIncome =>
      'Bottom-line profit after every cost, tax and one-off.';

  @override
  String get hintFreeCashFlow =>
      'Operating cash flow minus capital expenditure — the cash the business actually keeps.';

  @override
  String get hintNetDebt =>
      'Total borrowings minus cash, equivalents and short-term investments. A negative figure is a net cash position: the company holds more than it owes. Short-term investments count because treasuries and commercial paper settle a debt as readily as cash — Microsoft keeps three quarters of its money there.';

  @override
  String deltaVersusPriorYear(String year) {
    return 'vs FY$year';
  }

  @override
  String get sectionValuation => 'Valuation';

  @override
  String get labelSharePrice => 'Share price';

  @override
  String get hintSharePrice =>
      'The price one share trades at. Quoted from Finnhub where a key is configured, and yours to type over either way — everything else in this report comes from the filings.';

  @override
  String get placeholderSharePrice => '0.00';

  @override
  String get valuationIdle =>
      'Enter the current share price to see how it compares with what the filings say the business earns.';

  @override
  String get footnotePriceSource =>
      'Prices come from Finnhub and are cached until they go stale; typing over one replaces it. Everything else is from the filings.';

  @override
  String get valuationNoShareCount =>
      'No share count is on file for this company, so its value cannot be split per share.';

  @override
  String quoteLive(String time) {
    return 'Live · $time';
  }

  @override
  String quoteStale(String time) {
    return 'Last quote · $time';
  }

  @override
  String get quoteEntered => 'Your price';

  @override
  String get quoteFetching => 'Fetching the price…';

  @override
  String get quoteRefresh => 'Fetch the current price';

  @override
  String get quoteNotConfigured =>
      'No quote service is configured, so the price is yours to enter.';

  @override
  String get quoteNoCoverage =>
      'No quote for this symbol — enter a price to value it.';

  @override
  String get quoteRateLimited =>
      'The minute\'s quote allowance is spent. Try again shortly.';

  @override
  String get quoteNetwork => 'Could not reach the quote service.';

  @override
  String get quoteService => 'The quote service refused the request.';

  @override
  String get verdictUndervalued => 'Undervalued';

  @override
  String get verdictFairlyValued => 'Fairly valued';

  @override
  String get verdictOvervalued => 'Overvalued';

  @override
  String get verdictNotValuable => 'Cannot be valued';

  @override
  String get detailUndervalued =>
      'The price is below the range these earnings support.';

  @override
  String get detailFairlyValued =>
      'The price sits inside the range these earnings support.';

  @override
  String get detailOvervalued =>
      'The price is above the range these earnings support.';

  @override
  String get detailNotValuable =>
      'The company reports neither a profit nor free cash flow, so there is nothing to strike a multiple against.';

  @override
  String get labelFairValueRange => 'Fair range';

  @override
  String get labelUpside => 'To mid-range';

  @override
  String get labelMarketCap => 'Market value';

  @override
  String get labelEnterpriseValue => 'Enterprise value';

  @override
  String get labelEarningsPerShare => 'Earnings per share';

  @override
  String fairValueRange(String low, String high) {
    return '$low – $high';
  }

  @override
  String valuationBasisLine(
    String low,
    String high,
    String basis,
    String amount,
    String shares,
  ) {
    return '$low× to $high× $basis of $amount, less net debt, over $shares shares';
  }

  @override
  String valuationGrowthPremium(String points, String growth) {
    return 'Includes $points points of multiple for $growth annual revenue growth.';
  }

  @override
  String get valuationNoGrowthPremium =>
      'No growth premium: revenue is not growing on these filings.';

  @override
  String get basisFreeCashFlow => 'free cash flow';

  @override
  String get basisEarnings => 'net income';

  @override
  String get sectionExpectations => 'What the price is asking';

  @override
  String get expectationRequired => 'Growth the price requires';

  @override
  String expectationDelivered(int years) {
    return 'Growth delivered over $years years';
  }

  @override
  String expectationPerYear(String percent) {
    return '$percent a year';
  }

  @override
  String expectationBasis(String amount, String margin) {
    return 'Discounting $amount a year — this company\'s median free cash flow margin of $margin on its latest revenue — over ten years, fading to 2.5%.';
  }

  @override
  String expectationNormalised(String reported, String gap) {
    return 'Its latest reported free cash flow was $reported, $gap against that, so the year as filed is not used on its own.';
  }

  @override
  String get expectationSensitivity =>
      'Required growth by the return a buyer wants';

  @override
  String get expectationWorth => 'Worth a share if it repeats its record';

  @override
  String expectationRate(String percent) {
    return '$percent return';
  }

  @override
  String get verdictBelowRecord => 'Asking less than it has delivered';

  @override
  String get verdictInLineWithRecord => 'Asking about what it has delivered';

  @override
  String get verdictBeyondRecord => 'Asking more than it has ever delivered';

  @override
  String get verdictExpectationUnknown =>
      'Not enough history to judge the price';

  @override
  String get detailBelowRecord =>
      'Even a buyer wanting an 11% return needs less growth than this company has managed. Either the market doubts the record repeats, or it has not noticed it.';

  @override
  String get detailInLineWithRecord =>
      'The growth the price requires sits inside what the company has actually produced, so the price is a reasonable reading of the record rather than a bet against it.';

  @override
  String get detailBeyondRecord =>
      'Even a buyer content with a 7% return needs more growth than this company has ever produced. That does not make the price wrong, but it does mean the case for it is not in the filings.';

  @override
  String get detailExpectationUnknown =>
      'Too few years on file, or no positive cash flow to discount.';

  @override
  String get footnoteExpectations =>
      'A discounted cash flow run backwards: the price is taken as given and the growth it implies is solved for, so the guess belongs to the market rather than to PickStock. The figure moves a long way with the return a buyer wants, which is why the whole band is shown.';

  @override
  String get watchlistAll => 'All companies';

  @override
  String get watchlistFilterLabel => 'List';

  @override
  String watchlistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count companies',
      one: '1 company',
      zero: 'empty',
    );
    return '$_temp0';
  }

  @override
  String get watchlistManage => 'Manage lists';

  @override
  String get watchlistNew => 'New list';

  @override
  String get watchlistEdit => 'Edit list';

  @override
  String get watchlistDelete => 'Delete list';

  @override
  String watchlistDeleteConfirm(String name) {
    return 'Delete “$name”? The companies in it are not affected.';
  }

  @override
  String get watchlistNamePlaceholder => 'Semiconductors, Dividend payers…';

  @override
  String get watchlistNameLabel => 'Name';

  @override
  String get watchlistColourLabel => 'Colour';

  @override
  String get watchlistSave => 'Save';

  @override
  String get watchlistCancel => 'Cancel';

  @override
  String get watchlistCreate => 'Create';

  @override
  String get watchlistDefaultLocked => 'The starred list cannot be deleted.';

  @override
  String get watchlistEmptyTitle => 'No lists yet';

  @override
  String get watchlistEmptyBody =>
      'Star a company, or make a list to group the ones you are watching.';

  @override
  String get watchlistNoMatchesTitle => 'Nothing in this list';

  @override
  String watchlistNoMatchesBody(String name) {
    return 'Open a company and add it to “$name”.';
  }

  @override
  String get watchlistStarAdd => 'Add to favourites';

  @override
  String get watchlistStarRemove => 'Remove from favourites';

  @override
  String get watchlistAddTo => 'Add to a list';

  @override
  String watchlistInLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $count lists',
      one: 'In 1 list',
    );
    return '$_temp0';
  }

  @override
  String get watchlistNotInAny => 'Not in any list';

  @override
  String get napkinTitle => 'How this was worked out';

  @override
  String get napkinSubtitle =>
      'The whole calculation, in the order it happens.';

  @override
  String get napkinStep1Title => 'Buying the whole company';

  @override
  String napkinStep1Body(String price, String shares, String marketCap) {
    return 'A share costs $price. There are $shares of them, so buying every share costs $marketCap. That is what the market says the company is worth.';
  }

  @override
  String get napkinStep2Title => 'What you get for it';

  @override
  String napkinStep2Body(String revenue, String freeCashFlow) {
    return 'Last year the company collected $revenue and, after every bill including new equipment, kept $freeCashFlow. That leftover is the money the owners could actually take out.';
  }

  @override
  String get napkinStep3TitleDebt => 'You also inherit the debts';

  @override
  String get napkinStep3TitleCash => 'You also get the cash pile';

  @override
  String napkinStep3BodyDebt(String netDebt, String enterpriseValue) {
    return 'It owes $netDebt more than it holds. Buy the company and you owe that too, so the real cost is $enterpriseValue.';
  }

  @override
  String napkinStep3BodyCash(String netCash, String enterpriseValue) {
    return 'It holds $netCash more than it owes. That cash comes with the company, so the real cost is only $enterpriseValue.';
  }

  @override
  String get napkinStep4Title => 'How many years of cash is that?';

  @override
  String napkinStep4Body(
    String enterpriseValue,
    String freeCashFlow,
    String years,
  ) {
    return '$enterpriseValue ÷ $freeCashFlow a year = $years years to earn the purchase price back, if nothing ever grows.';
  }

  @override
  String get napkinStep5Title => 'How many years is fair?';

  @override
  String get napkinStep5BodyFlat =>
      'A business going nowhere is worth roughly 12 to 18 years of its cash. This one is not growing, so it gets no more than that.';

  @override
  String napkinStep5BodyGrowing(
    String growth,
    String premium,
    String low,
    String high,
  ) {
    return 'A business going nowhere is worth roughly 12 to 18 years of its cash. This one grows $growth a year, which buys it another $premium years: $low to $high.';
  }

  @override
  String get napkinStep6Title => 'So what is a share worth?';

  @override
  String napkinStep6Body(
    String low,
    String high,
    String basis,
    String valueLow,
    String valueHigh,
    String shares,
    String rangeLow,
    String rangeHigh,
  ) {
    return '$low to $high years of $basis is $valueLow to $valueHigh. Settle the debts, divide by $shares shares, and one share is worth $rangeLow to $rangeHigh.';
  }

  @override
  String get napkinStep7Title => 'And the answer';

  @override
  String napkinStep7BodyUnder(String price, String rangeLow, String rangeHigh) {
    return 'You are paying $price, below the $rangeLow–$rangeHigh the earnings support. That is the cheap side.';
  }

  @override
  String napkinStep7BodyFair(String price, String rangeLow, String rangeHigh) {
    return 'You are paying $price, inside the $rangeLow–$rangeHigh the earnings support. That is a normal price.';
  }

  @override
  String napkinStep7BodyOver(String price, String rangeLow, String rangeHigh) {
    return 'You are paying $price, above the $rangeLow–$rangeHigh the earnings support. You are paying for growth that has not happened yet.';
  }

  @override
  String get napkinCaveatTitle => 'Worth knowing';

  @override
  String napkinCaveatBuilding(String ratio) {
    return 'It spent $ratio× more on equipment than wore out, so last year\'s leftover cash understates what the business normally makes. The section below uses a smoothed figure instead.';
  }

  @override
  String napkinCaveatMargin(String points) {
    return 'Its profit margin is $points points below its own ten-year normal, so the sales growth above is being won at a lower profit.';
  }

  @override
  String get napkinCaveatEarnings =>
      'It generates no spare cash, so this uses accounting profit instead — a weaker measure, because profit is an opinion and cash is a fact.';

  @override
  String get labelPriceEarnings => 'P/E';

  @override
  String get labelEnterpriseValueToFreeCashFlow => 'EV/FCF';

  @override
  String get labelFreeCashFlowYield => 'FCF yield';

  @override
  String get labelGrowthAdjusted => 'PEG';

  @override
  String get labelPriceToSales => 'P/S';

  @override
  String get hintPriceEarnings =>
      'Price divided by earnings per share: years of current profit the price costs. Blank at a loss, where the ratio means nothing.';

  @override
  String get hintEnterpriseValueToFreeCashFlow =>
      'Enterprise value over free cash flow. Unlike P/E it counts debt, so a company that borrowed to buy its earnings looks dearer.';

  @override
  String get hintFreeCashFlowYield =>
      'Free cash flow as a percentage of market value — what an owner earns at this price before any growth. Higher is cheaper.';

  @override
  String get hintGrowthAdjusted =>
      'The earnings multiple divided by the annual revenue growth rate. Under 1 means the growth more than covers the multiple.';

  @override
  String get hintPriceToSales =>
      'Market value over revenue. The fallback when a company has no profit to divide by, and worth little on its own.';

  @override
  String footnoteValuation(String low, String high, String basis) {
    return 'The fair range is a heuristic: $low–$high times the latest year\'s $basis, widened for revenue growth, less net debt. It is a frame for the price, not a target.';
  }

  @override
  String get footnoteNegatives =>
      'Cash includes short-term investments. Net debt is negative when a company holds more of it than it owes.';

  @override
  String get footnoteSource =>
      'Source: SEC EDGAR XBRL company facts. Figures in USD millions. A sanity check on the shape of the numbers — not investment advice.';

  @override
  String get footnoteQuarters =>
      'Fourth-quarter income and cash-flow figures are derived by subtracting the first three quarters from the full year; balance-sheet figures are as filed.';
}
