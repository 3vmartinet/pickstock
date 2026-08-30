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
  String get ingestStart => 'Download SEC data';

  @override
  String ingestDownloading(String percent) {
    return 'Downloading… $percent';
  }

  @override
  String ingestParsing(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Loading $countString companies…';
  }

  @override
  String ingestDone(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString companies loaded';
  }

  @override
  String get ingestFailed => 'Download failed — try again';

  @override
  String get ingestSize =>
      'One 1.4 GB download from SEC, then everything is local.';

  @override
  String get toggleTheme => 'Toggle light / dark theme';

  @override
  String get searchPlaceholder => 'Search by symbol or company name';

  @override
  String get searchAction => 'Analyze';

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
  String get labelYear => 'Year';

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
  String get labelNetDebt => 'Net debt / (cash)';

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
      'Total borrowings minus cash. Negative means the company holds more cash than debt.';

  @override
  String deltaVersusPriorYear(String year) {
    return 'vs FY$year';
  }

  @override
  String get footnoteNegatives =>
      'Values in parentheses are negative — a net cash position.';

  @override
  String get footnoteSource =>
      'Source: SEC EDGAR XBRL company facts, 10-K filings only. Figures in USD millions. A sanity check on the shape of the numbers — not investment advice.';

  @override
  String get unitMillionsSuffix => 'M';
}
