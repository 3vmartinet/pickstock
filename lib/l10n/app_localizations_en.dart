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
  String get appSubtitle => 'Financial health snapshots from SEC EDGAR';

  @override
  String get stageDirectoryLabel => 'Ticker directory';

  @override
  String get stageDirectoryDetail => 'Symbols and company names';

  @override
  String get stageSectorsLabel => 'Industry codes';

  @override
  String get stageSectorsDetail =>
      'A sector for each filer, about 60 MB a quarter';

  @override
  String ingestDataSets(int read, int total) {
    return '$read of $total data sets';
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
    return '$received of $total';
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

    return '$rateString companies/s';
  }

  @override
  String ingestRemaining(String duration) {
    return '$duration left';
  }

  @override
  String ingestCompaniesOfTotal(int loaded, int total) {
    final intl.NumberFormat loadedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String loadedString = loadedNumberFormat.format(loaded);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$loadedString of $totalString companies';
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
  String get ingestStageDirectory => 'Fetching the ticker directory…';

  @override
  String ingestStageDownload(String percent) {
    return 'Downloading the archive… $percent';
  }

  @override
  String ingestStageDownloadSized(String received, String total) {
    return 'Downloading the archive… $received of $total';
  }

  @override
  String ingestStageLoad(int count, int total) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Loading filings into the database… $countString of $totalString companies';
  }

  @override
  String get ingestStageFinishing => 'Finishing up…';

  @override
  String get ingestStageLoadHint =>
      'Reading 20,000 filings takes a few minutes.';

  @override
  String get ingestWarnLeave => 'This takes a few minutes. Leave the app open.';

  @override
  String get toggleTheme => 'Toggle light / dark theme';

  @override
  String get searchPlaceholder => 'Search by symbol or company name';

  @override
  String get searchExamples => 'Try one of these';

  @override
  String get browseTitle => 'All tickers';

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
  String get browseOpen => 'Browse all tickers';

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
  String get browseSortLabel => 'Sort';

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
  String get browseBack => 'Back to the report';

  @override
  String get idleTitle => 'Check a company before you invest';

  @override
  String get idleBody =>
      'Type a ticker symbol or a company name to pull the last three fiscal years of revenue, profitability, free cash flow and balance-sheet strength — straight from the company\'s own 10-K filings.';

  @override
  String loadingResolving(String ticker) {
    return 'Looking up $ticker in the SEC ticker registry…';
  }

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
  String get labelOperatingCashFlow => 'Operating cash flow';

  @override
  String get labelCapitalExpenditure => 'Capital expenditure';

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
      'Total borrowings minus cash. A negative figure is a net cash position: the company holds more cash than debt.';

  @override
  String deltaVersusPriorYear(String year) {
    return 'vs FY$year';
  }

  @override
  String get footnoteNegatives =>
      'Net debt is negative when a company holds more cash than it owes.';

  @override
  String get footnoteSource =>
      'Source: SEC EDGAR XBRL company facts. Figures in USD millions. A sanity check on the shape of the numbers — not investment advice.';

  @override
  String get footnoteQuarters =>
      'Fourth-quarter income and cash-flow figures are derived by subtracting the first three quarters from the full year; balance-sheet figures are as filed.';

  @override
  String get unitMillionsSuffix => 'M';
}
