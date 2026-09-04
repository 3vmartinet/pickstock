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
  String get statLoaded => 'Filers read';

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
  String get stageLoadDetail =>
      'Every filer in the archive — most have no ticker';

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
  String get dataAsOfLabel => 'SEC data';

  @override
  String dataAsOfDate(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String dataAsOfHint(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Your figures come from the archive SEC published on $dateString. PickStock looks for a newer one every time it starts.';
  }

  @override
  String get updateDownloading => 'Downloading update…';

  @override
  String get updateDownloadingHint =>
      'SEC\'s archive is downloading in the background. Carry on using the app — refreshing the database is a separate step, and you will be asked before it starts.';

  @override
  String updateDownloadedPercent(int percent) {
    return '$percent% downloaded.';
  }

  @override
  String get updateCancel => 'Cancel the download';

  @override
  String get updateCancelHint =>
      'Stop the download and throw away what has come down. An archive is only usable whole, so there is nothing to resume — starting again starts from the beginning.';

  @override
  String get updateReady => 'Finish update';

  @override
  String get updateConfirmTitle => 'Refresh the database now?';

  @override
  String get updateConfirmBody =>
      'Every figure is replaced from the archive that has been downloaded, so PickStock cannot be used until it finishes. Leave the app open while it runs.';

  @override
  String updateConfirmLast(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'about $minutes minutes',
      one: 'about a minute',
    );
    return 'Last time this took $_temp0.';
  }

  @override
  String get updateConfirmUntimed =>
      'It usually takes a few minutes. Nothing has been timed on this machine yet, so that is a guess rather than a measurement.';

  @override
  String get updateConfirmStart => 'Refresh now';

  @override
  String get updateConfirmCancel => 'Not now';

  @override
  String get updateReadyHint =>
      'The download is complete. Refreshing the database takes a few minutes and the app cannot be used while it runs, so nothing starts until you say so.';

  @override
  String get updateFailed => 'Update failed';

  @override
  String get updateFailedHint =>
      'The download did not finish and nothing was changed — your figures are as they were. Press to try again.';

  @override
  String get ingestWarnLeave => 'This takes a few minutes. Leave the app open.';

  @override
  String get insightBusinessTitle => 'What the filings do not say';

  @override
  String get insightBusinessInvitation =>
      'EDGAR publishes no description of a business anywhere — the industry title above is the closest thing on file. A model on this machine can read around and say what this company actually sells, and what has been moving its revenue.';

  @override
  String get insightBusinessAction => 'Describe the business';

  @override
  String get insightInputsTitle => 'Do these figures mean what they appear to?';

  @override
  String get insightInputsInvitation =>
      'The band above is struck from the filing as tagged. A figure can be read correctly and still not mean what it looks like: cash that belongs to outside owners, a profit that is a tax release, a share count from before a split. A model can read the filing and say whether any of that applies here.';

  @override
  String get insightInputsAction => 'Check against the filing';

  @override
  String get insightExpectationsTitle => 'What anyone else expects';

  @override
  String get insightExpectationsInvitation =>
      'The rate above is what this price asks of the company. Whether the company itself expects it is not in the filings — that is guidance, an earnings call, a broker\'s note. A model can find what has been said and set it against the arithmetic.';

  @override
  String get insightExpectationsAction => 'Find what is expected';

  @override
  String get agoJustNow => 'just now';

  @override
  String agoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min ago',
      one: '1 min ago',
    );
    return '$_temp0';
  }

  @override
  String agoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: 'an hour ago',
    );
    return '$_temp0';
  }

  @override
  String agoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: 'yesterday',
    );
    return '$_temp0';
  }

  @override
  String agoMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months ago',
      one: 'last month',
    );
    return '$_temp0';
  }

  @override
  String agoYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years ago',
      one: 'last year',
    );
    return '$_temp0';
  }

  @override
  String noteGeneratedOn(DateTime when) {
    final intl.DateFormat whenDateFormat = intl.DateFormat.yMMMd(localeName);
    final String whenString = whenDateFormat.format(when);

    return 'Read on $whenString. Press to read it again — the web moves, and this did not.';
  }

  @override
  String get noteRegenerate => 'Read it again';

  @override
  String get insightReading => 'Reading…';

  @override
  String get insightReadingHint =>
      'Searching the web and reading what it finds. This takes about a minute.';

  @override
  String get insightSources => 'Read from';

  @override
  String get insightCaveat =>
      'Written by a model from pages it found, not from the filings. Check anything you would act on.';

  @override
  String get eventsTitle => 'Recent developments';

  @override
  String get sourceOpenExternally =>
      'Open in your browser. This pane closes, so the page is not open twice.';

  @override
  String get sourceClose => 'Close this pane';

  @override
  String get sourceUnavailable =>
      'This page cannot be shown here. Use the button above to open it in your browser.';

  @override
  String get eventsFetch => 'Fetch latest news';

  @override
  String get eventsFetchHint =>
      'A model on this machine searches the web and lists the three most recent developments worth an investor\'s attention. It takes about a minute.';

  @override
  String get eventsLoading => 'Reading…';

  @override
  String get eventsLoadingHint =>
      'Searching the web and reading what it finds. This takes about a minute.';

  @override
  String get eventsDoneHint =>
      'Read already. Open the company again to look afresh.';

  @override
  String get eventsEmpty => 'Nothing recent turned up.';

  @override
  String eventsOpenHint(String caption, String url) {
    return '$caption Opens $url in your browser.';
  }

  @override
  String get eventsFailedNoKey =>
      'No Ollama key is built in, so there is nothing to search with. Copy env.example.json to env.json and paste one.';

  @override
  String get eventsFailedNoServer =>
      'Nothing is answering on this machine. Start Ollama and try again.';

  @override
  String get eventsFailedNoModel =>
      'Ollama is running but has not pulled the model this build asks for.';

  @override
  String get eventsFailedOther => 'The search did not finish. Try again.';

  @override
  String get jobsTooltip => 'Reports and running jobs';

  @override
  String get jobsTitle => 'Reports';

  @override
  String get jobsEmpty => 'No reports yet.';

  @override
  String get jobsEmptyBody =>
      'Scan the companies you have filtered to find the ones priced below what their filings support.';

  @override
  String jobsStart(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Scan $countString companies';
  }

  @override
  String get jobsRunningOne => 'A scan is already running.';

  @override
  String jobsProgress(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString of $totalString';
  }

  @override
  String jobsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count undervalued',
      one: '1 undervalued',
      zero: 'nothing yet',
    );
    return '$_temp0';
  }

  @override
  String jobsRemaining(String duration) {
    return '$duration left';
  }

  @override
  String get jobsCancel => 'Stop';

  @override
  String get jobsCancelled => 'Stopped early';

  @override
  String jobsDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count undervalued',
      one: '1 undervalued',
      zero: 'Nothing undervalued',
    );
    return '$_temp0';
  }

  @override
  String get jobsOpen => 'Open';

  @override
  String get reportRename => 'Rename';

  @override
  String get reportDelete => 'Delete';

  @override
  String reportDeleteConfirm(String name) {
    return 'Delete “$name”? The companies in it are not affected.';
  }

  @override
  String get reportNameLabel => 'Name';

  @override
  String reportSubtitle(int found, int valued, int considered) {
    final intl.NumberFormat valuedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String valuedString = valuedNumberFormat.format(valued);
    final intl.NumberFormat consideredNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String consideredString = consideredNumberFormat.format(considered);

    String _temp0 = intl.Intl.pluralLogic(
      found,
      locale: localeName,
      other: '$found of',
      one: '1 of',
    );
    return '$_temp0 $valuedString valued, from $consideredString filtered';
  }

  @override
  String get reportEmptyTitle => 'Nothing was undervalued';

  @override
  String get reportEmptyBody =>
      'Every company that could be valued was priced at or above the bottom of its range.';

  @override
  String get reportColumnUpside => 'Upside to low';

  @override
  String get reportColumnPrice => 'Price';

  @override
  String get reportColumnRange => 'Fair range';

  @override
  String reportSkippedNote(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString companies could not be valued and were skipped',
      one: 'One company could not be valued and was skipped',
      zero: '',
    );
    return '$_temp0 — no share count, no revenue, or no positive cash stream.';
  }

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
      other: '$countString tickers',
      one: '1 ticker',
    );
    return '$_temp0 in SEC\'s directory';
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
  String sortRevenueRising(int years) {
    return 'Revenue up $years years running';
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
  String sectorNarrow(String sector) {
    return 'Narrow $sector to SEC industries';
  }

  @override
  String sectorNarrowedCount(int selected, int total) {
    return '$selected/$total';
  }

  @override
  String get sectorIndustriesHeader => 'SEC industries';

  @override
  String get sectorIndustriesHint => 'Hold ⇧ to pick several';

  @override
  String get sectorApplySelection => 'Apply selection';

  @override
  String get sectorAllIndustries => 'All industries';

  @override
  String sectorIndustryCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString companies',
      one: '1 company',
    );
    return '$_temp0';
  }

  @override
  String browseIndustriesFilter(String sector, int count) {
    return '$sector, $count industries';
  }

  @override
  String get browseDebtFree => 'Debt-free';

  @override
  String get browseDebtFreeHint =>
      'Only companies whose latest filed year reports no borrowings and no interest expense.';

  @override
  String get browsePositiveCashFlow => 'Cash generative';

  @override
  String get browsePositiveCashFlowHint =>
      'Only companies whose latest filed year turned more cash from operations than it spent on capital equipment.';

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
  String labelIndustryAndCik(String industry, String cik) {
    return '$industry · CIK $cik';
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
  String priorNetCashUp(String amount) {
    return 'up from net cash of $amount';
  }

  @override
  String priorNetCashDown(String amount) {
    return 'down from net cash of $amount';
  }

  @override
  String priorNetDebtUp(String amount) {
    return 'up from net debt of $amount';
  }

  @override
  String priorNetDebtDown(String amount) {
    return 'down from net debt of $amount';
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
      'The gap between what the company owes and what it holds. The heading says which way round it is — Net cash when it holds more than it owes, Net debt when it owes more — so the amount itself carries no sign. What it holds counts treasuries and commercial paper, which settle a debt as readily as cash does.';

  @override
  String deltaVersusPriorYear(String year) {
    return 'vs FY$year';
  }

  @override
  String get tabOverview => 'Overview';

  @override
  String get tabValuation => 'Valuation';

  @override
  String get tabExpectations => 'Expectations';

  @override
  String get sectionValuation => 'Fair value';

  @override
  String get labelSharePrice => 'Share price';

  @override
  String get hintSharePrice =>
      'The price one share trades at. Quoted from Finnhub where a key is configured. Click the price to type your own.';

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
  String get quoteJobRunning =>
      'A report is using the quote allowance. This price will refresh when it finishes.';

  @override
  String get quoteTimedOut => 'The quote service did not answer in time.';

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
  String get labelRangeLow => 'Range low';

  @override
  String get labelRangeHigh => 'Range high';

  @override
  String get labelPriceToday => 'Price today';

  @override
  String get priceEditorTitle => 'Set the share price';

  @override
  String get priceEditorHint =>
      'Replaces the quoted price until the next refresh.';

  @override
  String get priceEnter => 'Set a price';

  @override
  String get labelMarketCap => 'Market value';

  @override
  String get labelEnterpriseValue => 'Enterprise value';

  @override
  String get labelEarningsPerShare => 'Earnings per share';

  @override
  String valuationBasisLine(
    String low,
    String high,
    String basis,
    String amount,
    String shares,
  ) {
    return '$low× to $high× $basis of $amount, over $shares shares';
  }

  @override
  String valuationGrowthPremium(
    String flat,
    String discount,
    String premium,
    String growth,
  ) {
    return '$flat years at $discount, $premium more for growing $growth a year';
  }

  @override
  String valuationNoGrowthPremium(String flat, String discount) {
    return '$flat years at $discount, with nothing added for growth';
  }

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
    return 'In one year the company took in $revenue and, after every bill including new equipment, had $freeCashFlow left over. That is one year\'s spare cash — what it earns annually, not a pile it has saved up.';
  }

  @override
  String get napkinStep3TitleDebt =>
      'It owes money, and that is already counted';

  @override
  String get napkinStep3TitleCash => 'It holds spare cash';

  @override
  String napkinStep3BodyDebt(String netDebt, String freeCashFlow) {
    return 'The company owes $netDebt more than it holds. Its lenders are paid before the owners are, and that interest already came out of the $freeCashFlow above — so the cash figure is what is left for you after the debt has taken its cut.';
  }

  @override
  String napkinStep3BodyCash(String netCash, String freeCashFlow) {
    return 'The company holds $netCash more than it owes, so nothing is being siphoned off to lenders. The whole $freeCashFlow above belongs to the owners.';
  }

  @override
  String get napkinStep4Title => 'How many years of cash is that?';

  @override
  String napkinStep4Body(String marketCap, String freeCashFlow, String years) {
    return '$marketCap to buy every share, ÷ $freeCashFlow earned each year = $years years to get your money back, if the company never grows. The same question as asking how many years\' rent a flat costs.';
  }

  @override
  String get napkinStep5Title => 'How many years is fair?';

  @override
  String napkinStep5BodyFlat(String discount, String flat) {
    return 'Wanting $discount a year back, a business going nowhere is worth about $flat years of its cash — that is simply what those years add up to once each one is discounted. This one is not growing, so it gets no more than that.';
  }

  @override
  String napkinStep5BodyGrowing(
    String discount,
    String flat,
    String growth,
    String years,
    String low,
    String high,
  ) {
    return 'Wanting $discount a year back, a business going nowhere is worth about $flat years of its cash. This one grew $growth in its middle year of the last $years — the median, so one exceptional year cannot set the price. Next year\'s cash should be bigger than this year\'s, so it is worth more: $low to $high years, the range being what a point either side of $discount does to the answer.';
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
    return '$low to $high years of $basis is $valueLow to $valueHigh for the whole company. Divide by $shares shares, and one share is worth $rangeLow to $rangeHigh.';
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
  String get targetsTitle => 'What a share is worth if the record repeats';

  @override
  String get targetsBear => 'Bear';

  @override
  String get targetsNeutral => 'Neutral';

  @override
  String get targetsBull => 'Bull';

  @override
  String targetsGrowthAssumed(String growth) {
    return '$growth a year assumed';
  }

  @override
  String targetsAgainstPrice(String price) {
    return 'vs $price today';
  }

  @override
  String get targetsHowTitle => 'How these are worked out';

  @override
  String get targetsHowStep1Title => 'A year of cash to start from';

  @override
  String targetsHowStep1Body(String revenue, String margin, String flow) {
    return 'Its last year sold $revenue. Over the years on file it has turned $margin of what it sells into spare cash, so the sum starts from $flow — its own typical conversion, not one unusual year.';
  }

  @override
  String get targetsHowStep2Title => 'Three rates it has actually managed';

  @override
  String targetsHowStep2Body(
    String rates,
    String years,
    String bear,
    String neutral,
    String bull,
  ) {
    return 'Its revenue grew $rates in the $years years on file. Its worst year gives the bear case at $bear, its middle year the neutral at $neutral, and its best year the bull at $bull. Nothing here is forecast — these are years it has already had.';
  }

  @override
  String get targetsHowStep3Title => 'Ten years of it, then the long run';

  @override
  String targetsHowStep3Body(String terminal, String discount, String tenYear) {
    return 'Each rate is grown out for ten years, fading to $terminal a year by the end — nothing outgrows the economy for ever. Every year\'s cash is then discounted at $discount, because money you get later is worth less than money you have now: a dollar arriving in ten years counts as $tenYear today. The years after that are valued as one lump on the same terms.';
  }

  @override
  String get targetsHowStep4Title => 'Split across the shares';

  @override
  String targetsHowStep4Body(
    String shares,
    String bear,
    String neutral,
    String bull,
  ) {
    return 'That total, divided by $shares shares, is what one share is worth under each reading: $bear bear, $neutral neutral, $bull bull.';
  }

  @override
  String targetsRateComputed(String rate) {
    return 'Discounted at $rate, this company\'s own required return';
  }

  @override
  String targetsRateAssumed(String rate) {
    return 'Discounted at $rate, assumed';
  }

  @override
  String get targetsRateWhat =>
      'What a buyer should want back each year for holding this share rather than a government bond.';

  @override
  String get targetsRateRiskFree => 'Risk-free';

  @override
  String targetsRateRiskFreeNote(String date) {
    return '10-year US Treasury, $date';
  }

  @override
  String get targetsRateBeta => 'Beta';

  @override
  String get targetsRateBetaNote =>
      'How much the share swings against the market. 1.0 is the market itself.';

  @override
  String get targetsRatePremium => 'Equity premium';

  @override
  String get targetsRatePremiumNote =>
      'The extra wanted for holding shares at all. An estimate, the same for every company.';

  @override
  String get targetsRateTotal => 'Required return';

  @override
  String targetsRateCapped(String rate) {
    return 'Held to $rate — beyond the band a borrowed beta says more than the company does.';
  }

  @override
  String get targetsRateAssumedWhy =>
      'A reasonable return to want, not this company\'s own. Its cost of equity needs a Treasury yield and a beta, neither of which is in SEC filings — and neither could be reached.';

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
  String napkinCaveatOutsideOwners(String share) {
    return 'Only $share of this business belongs to the listed shares; the rest is held by owners outside the company. The cash above is the whole group\'s brought down to that share, because the share count beside it counts the listed shares alone.';
  }

  @override
  String get napkinCaveatShareCount =>
      'It files no current share count, so the number above is the average across the fiscal year that its earnings are reported against. Every figure here is struck against it, so read them as approximate.';

  @override
  String napkinCaveatShareCountStale(String year) {
    return 'It last filed a share count in $year, so the number above is the average across the fiscal year that its earnings are reported against. Every figure here is struck against it, so read them as approximate.';
  }

  @override
  String get labelPriceEarnings => 'P/E';

  @override
  String get labelPriceToFreeCashFlow => 'P/FCF';

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
  String get hintPriceToFreeCashFlow =>
      'Years of spare cash the shares cost. Market value, not enterprise value, because this cash flow is already after interest.';

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
    return 'The fair range is a heuristic: $low–$high times the latest year\'s $basis, widened for revenue growth. That cash flow is already after interest, so the debt is not subtracted a second time. It is a frame for the price, not a target.';
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
