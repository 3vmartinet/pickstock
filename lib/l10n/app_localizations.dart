import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'PickStock'**
  String get appTitle;

  /// No description provided for @stageDirectoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Ticker directory'**
  String get stageDirectoryLabel;

  /// No description provided for @stageDirectoryDetail.
  ///
  /// In en, this message translates to:
  /// **'Symbols and company names'**
  String get stageDirectoryDetail;

  /// No description provided for @statDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get statDownloaded;

  /// No description provided for @statLoaded.
  ///
  /// In en, this message translates to:
  /// **'Companies read'**
  String get statLoaded;

  /// No description provided for @statDataSets.
  ///
  /// In en, this message translates to:
  /// **'Data sets'**
  String get statDataSets;

  /// No description provided for @statSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get statSpeed;

  /// No description provided for @statRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get statRemaining;

  /// No description provided for @statPending.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get statPending;

  /// No description provided for @stageSectorsLabel.
  ///
  /// In en, this message translates to:
  /// **'Industry codes'**
  String get stageSectorsLabel;

  /// No description provided for @stageSectorsDetail.
  ///
  /// In en, this message translates to:
  /// **'A sector for each filer, about 60 MB a quarter'**
  String get stageSectorsDetail;

  /// No description provided for @ingestDataSets.
  ///
  /// In en, this message translates to:
  /// **'{read} / {total}'**
  String ingestDataSets(int read, int total);

  /// No description provided for @stageDownloadLabel.
  ///
  /// In en, this message translates to:
  /// **'SEC bulk archive'**
  String get stageDownloadLabel;

  /// No description provided for @stageDownloadDetail.
  ///
  /// In en, this message translates to:
  /// **'About 1.4 GB, downloaded once'**
  String get stageDownloadDetail;

  /// No description provided for @stageLoadLabel.
  ///
  /// In en, this message translates to:
  /// **'Local database'**
  String get stageLoadLabel;

  /// No description provided for @stageLoadDetail.
  ///
  /// In en, this message translates to:
  /// **'Reading filings for every company'**
  String get stageLoadDetail;

  /// No description provided for @ingestPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing your data'**
  String get ingestPreparing;

  /// No description provided for @ingestBytesOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{received} / {total}'**
  String ingestBytesOfTotal(String received, String total);

  /// No description provided for @ingestRate.
  ///
  /// In en, this message translates to:
  /// **'{rate}/s'**
  String ingestRate(String rate);

  /// No description provided for @ingestRateCompanies.
  ///
  /// In en, this message translates to:
  /// **'{rate}/s'**
  String ingestRateCompanies(int rate);

  /// No description provided for @ingestRemaining.
  ///
  /// In en, this message translates to:
  /// **'{duration}'**
  String ingestRemaining(String duration);

  /// No description provided for @ingestCompaniesOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{loaded} / {total}'**
  String ingestCompaniesOfTotal(int loaded, int total);

  /// No description provided for @durationMinutesSeconds.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s'**
  String durationMinutesSeconds(int minutes, int seconds);

  /// No description provided for @durationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String durationSeconds(int seconds);

  /// No description provided for @gateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking local data…'**
  String get gateChecking;

  /// No description provided for @gateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Financial data required'**
  String get gateRequiredTitle;

  /// No description provided for @gateRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'PickStock reads ten years of filings from a database on this machine. Download SEC\'s bulk archive once — about 1.4 GB — and everything after that works offline.'**
  String get gateRequiredBody;

  /// No description provided for @gateStart.
  ///
  /// In en, this message translates to:
  /// **'Download SEC data'**
  String get gateStart;

  /// No description provided for @gateFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get gateFailedTitle;

  /// No description provided for @gateFailedBody.
  ///
  /// In en, this message translates to:
  /// **'The archive could not be fetched. Check your connection and try again.'**
  String get gateFailedBody;

  /// No description provided for @gateRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get gateRetry;

  /// No description provided for @gateRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh data'**
  String get gateRefresh;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailable;

  /// No description provided for @updateAvailableOn.
  ///
  /// In en, this message translates to:
  /// **'SEC rebuilt the archive on {date}. Download it to refresh your figures.'**
  String updateAvailableOn(DateTime date);

  /// No description provided for @ingestWarnLeave.
  ///
  /// In en, this message translates to:
  /// **'This takes a few minutes. Leave the app open.'**
  String get ingestWarnLeave;

  /// No description provided for @toggleTheme.
  ///
  /// In en, this message translates to:
  /// **'Toggle light / dark theme'**
  String get toggleTheme;

  /// No description provided for @browseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 symbol} other{{count} symbols}} filed with SEC EDGAR'**
  String browseSubtitle(int count);

  /// No description provided for @sortByName.
  ///
  /// In en, this message translates to:
  /// **'Name (A–Z)'**
  String get sortByName;

  /// No description provided for @sortRevenueOneYear.
  ///
  /// In en, this message translates to:
  /// **'Revenue growth, 1 year'**
  String get sortRevenueOneYear;

  /// No description provided for @sortRevenueYears.
  ///
  /// In en, this message translates to:
  /// **'Revenue growth, {years}-year annualised'**
  String sortRevenueYears(int years);

  /// No description provided for @sortFreeCashFlowOneYear.
  ///
  /// In en, this message translates to:
  /// **'Free cash flow growth, 1 year'**
  String get sortFreeCashFlowOneYear;

  /// No description provided for @sectorTechnology.
  ///
  /// In en, this message translates to:
  /// **'Tech'**
  String get sectorTechnology;

  /// No description provided for @sectorHealthcare.
  ///
  /// In en, this message translates to:
  /// **'Pharma & health'**
  String get sectorHealthcare;

  /// No description provided for @sectorFinancials.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get sectorFinancials;

  /// No description provided for @sectorRealEstate.
  ///
  /// In en, this message translates to:
  /// **'Real estate'**
  String get sectorRealEstate;

  /// No description provided for @sectorEnergy.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get sectorEnergy;

  /// No description provided for @sectorUtilities.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get sectorUtilities;

  /// No description provided for @sectorIndustrials.
  ///
  /// In en, this message translates to:
  /// **'Industrials'**
  String get sectorIndustrials;

  /// No description provided for @sectorAutomotive.
  ///
  /// In en, this message translates to:
  /// **'Automotive'**
  String get sectorAutomotive;

  /// No description provided for @sectorMaterials.
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get sectorMaterials;

  /// No description provided for @sectorConsumer.
  ///
  /// In en, this message translates to:
  /// **'Consumer'**
  String get sectorConsumer;

  /// No description provided for @sectorCommunications.
  ///
  /// In en, this message translates to:
  /// **'Media & telecom'**
  String get sectorCommunications;

  /// No description provided for @sectorTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get sectorTransport;

  /// No description provided for @sectorAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get sectorAll;

  /// No description provided for @browseNoFigure.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get browseNoFigure;

  /// No description provided for @browseFilterPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Filter by symbol or company name'**
  String get browseFilterPlaceholder;

  /// No description provided for @browseMatchCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No matches} =1{1 match} other{{count} matches}}'**
  String browseMatchCount(int count);

  /// No description provided for @browseEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching symbols'**
  String get browseEmptyTitle;

  /// No description provided for @browseEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing in EDGAR\'s directory matches \"{query}\".'**
  String browseEmptyBody(String query);

  /// No description provided for @backToList.
  ///
  /// In en, this message translates to:
  /// **'Back to the list'**
  String get backToList;

  /// No description provided for @idleShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Or start with one of these'**
  String get idleShortcuts;

  /// No description provided for @idleTitle.
  ///
  /// In en, this message translates to:
  /// **'Check a company before you invest'**
  String get idleTitle;

  /// No description provided for @idleBody.
  ///
  /// In en, this message translates to:
  /// **'Pick a company from the list to pull ten fiscal years of revenue, profitability, free cash flow and balance-sheet strength — straight from its own 10-K filings.'**
  String get idleBody;

  /// No description provided for @loadingFetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching XBRL company facts for {ticker}…'**
  String loadingFetching(String ticker);

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not build a snapshot'**
  String get errorTitle;

  /// No description provided for @errorUnknownTicker.
  ///
  /// In en, this message translates to:
  /// **'No SEC filer matches the ticker \"{ticker}\".'**
  String errorUnknownTicker(String ticker);

  /// No description provided for @errorNoAnnualData.
  ///
  /// In en, this message translates to:
  /// **'SEC EDGAR holds no annual (10-K) cash-flow figures for {ticker}.'**
  String errorNoAnnualData(String ticker);

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not reach SEC EDGAR. Check your connection and try again.'**
  String get errorNetwork;

  /// No description provided for @errorDatabaseEmpty.
  ///
  /// In en, this message translates to:
  /// **'No data loaded yet. Download the SEC bulk archive to populate the local database.'**
  String get errorDatabaseEmpty;

  /// No description provided for @errorService.
  ///
  /// In en, this message translates to:
  /// **'SEC EDGAR returned an unexpected response. Try again in a moment.'**
  String get errorService;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @sectionSanityCheck.
  ///
  /// In en, this message translates to:
  /// **'Sanity check'**
  String get sectionSanityCheck;

  /// No description provided for @sectionHighlights.
  ///
  /// In en, this message translates to:
  /// **'FY{year} highlights'**
  String sectionHighlights(String year);

  /// No description provided for @sectionQuarterHistory.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One quarter} other{Last {count} quarters}}'**
  String sectionQuarterHistory(int count);

  /// No description provided for @sectionHistory.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One year} other{{count}-year}} history'**
  String sectionHistory(int count);

  /// No description provided for @checkRevenueGrowth.
  ///
  /// In en, this message translates to:
  /// **'Revenue growing?'**
  String get checkRevenueGrowth;

  /// No description provided for @checkProfitable.
  ///
  /// In en, this message translates to:
  /// **'Profitable?'**
  String get checkProfitable;

  /// No description provided for @checkNetCash.
  ///
  /// In en, this message translates to:
  /// **'More cash than debt?'**
  String get checkNetCash;

  /// No description provided for @verdictYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get verdictYes;

  /// No description provided for @verdictNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get verdictNo;

  /// No description provided for @verdictUnknown.
  ///
  /// In en, this message translates to:
  /// **'n/a'**
  String get verdictUnknown;

  /// No description provided for @detailRevenueGrowing.
  ///
  /// In en, this message translates to:
  /// **'Growing {percent} year over year'**
  String detailRevenueGrowing(String percent);

  /// No description provided for @detailRevenueShrinking.
  ///
  /// In en, this message translates to:
  /// **'Shrinking {percent} year over year'**
  String detailRevenueShrinking(String percent);

  /// No description provided for @detailProfitable.
  ///
  /// In en, this message translates to:
  /// **'Net income of {amount}'**
  String detailProfitable(String amount);

  /// No description provided for @detailUnprofitable.
  ///
  /// In en, this message translates to:
  /// **'Net loss of {amount}'**
  String detailUnprofitable(String amount);

  /// No description provided for @detailNetCash.
  ///
  /// In en, this message translates to:
  /// **'Net cash of {amount}'**
  String detailNetCash(String amount);

  /// No description provided for @detailNetDebt.
  ///
  /// In en, this message translates to:
  /// **'Net debt of {amount}'**
  String detailNetDebt(String amount);

  /// No description provided for @detailNotEnoughHistory.
  ///
  /// In en, this message translates to:
  /// **'Not enough filing history'**
  String get detailNotEnoughHistory;

  /// No description provided for @detailUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not reported in these filings'**
  String get detailUnavailable;

  /// No description provided for @labelFiscalYear.
  ///
  /// In en, this message translates to:
  /// **'FY'**
  String get labelFiscalYear;

  /// No description provided for @labelPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get labelPeriod;

  /// No description provided for @labelQuarterOfYear.
  ///
  /// In en, this message translates to:
  /// **'Q{quarter} FY{year}'**
  String labelQuarterOfYear(int quarter, int year);

  /// No description provided for @periodAnnual.
  ///
  /// In en, this message translates to:
  /// **'Annual'**
  String get periodAnnual;

  /// No description provided for @periodQuarterly.
  ///
  /// In en, this message translates to:
  /// **'Quarterly'**
  String get periodQuarterly;

  /// No description provided for @sortByYear.
  ///
  /// In en, this message translates to:
  /// **'Sort by fiscal year'**
  String get sortByYear;

  /// No description provided for @sortNewestFirst.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get sortNewestFirst;

  /// No description provided for @sortOldestFirst.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get sortOldestFirst;

  /// No description provided for @labelRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get labelRevenue;

  /// No description provided for @labelRevenueGrowth.
  ///
  /// In en, this message translates to:
  /// **'Rev YoY'**
  String get labelRevenueGrowth;

  /// No description provided for @labelNetIncome.
  ///
  /// In en, this message translates to:
  /// **'Net income'**
  String get labelNetIncome;

  /// No description provided for @labelFreeCashFlow.
  ///
  /// In en, this message translates to:
  /// **'Free cash flow'**
  String get labelFreeCashFlow;

  /// No description provided for @labelTotalDebt.
  ///
  /// In en, this message translates to:
  /// **'Total debt'**
  String get labelTotalDebt;

  /// No description provided for @labelCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get labelCash;

  /// No description provided for @labelNetDebt.
  ///
  /// In en, this message translates to:
  /// **'Net debt'**
  String get labelNetDebt;

  /// No description provided for @labelCik.
  ///
  /// In en, this message translates to:
  /// **'CIK {cik}'**
  String labelCik(String cik);

  /// No description provided for @labelNetDebtPosition.
  ///
  /// In en, this message translates to:
  /// **'Net debt'**
  String get labelNetDebtPosition;

  /// No description provided for @priorNetDebt.
  ///
  /// In en, this message translates to:
  /// **'was net debt of {amount}'**
  String priorNetDebt(String amount);

  /// No description provided for @priorNetCash.
  ///
  /// In en, this message translates to:
  /// **'was net cash of {amount}'**
  String priorNetCash(String amount);

  /// No description provided for @labelNetCashPosition.
  ///
  /// In en, this message translates to:
  /// **'Net cash'**
  String get labelNetCashPosition;

  /// No description provided for @hintRevenue.
  ///
  /// In en, this message translates to:
  /// **'Top-line sales reported on the income statement.'**
  String get hintRevenue;

  /// No description provided for @hintNetIncome.
  ///
  /// In en, this message translates to:
  /// **'Bottom-line profit after every cost, tax and one-off.'**
  String get hintNetIncome;

  /// No description provided for @hintFreeCashFlow.
  ///
  /// In en, this message translates to:
  /// **'Operating cash flow minus capital expenditure — the cash the business actually keeps.'**
  String get hintFreeCashFlow;

  /// No description provided for @hintNetDebt.
  ///
  /// In en, this message translates to:
  /// **'Total borrowings minus cash, equivalents and short-term investments. A negative figure is a net cash position: the company holds more than it owes. Short-term investments count because treasuries and commercial paper settle a debt as readily as cash — Microsoft keeps three quarters of its money there.'**
  String get hintNetDebt;

  /// No description provided for @deltaVersusPriorYear.
  ///
  /// In en, this message translates to:
  /// **'vs FY{year}'**
  String deltaVersusPriorYear(String year);

  /// No description provided for @tabOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get tabOverview;

  /// No description provided for @tabValuation.
  ///
  /// In en, this message translates to:
  /// **'Valuation'**
  String get tabValuation;

  /// No description provided for @sectionValuation.
  ///
  /// In en, this message translates to:
  /// **'Fair value'**
  String get sectionValuation;

  /// No description provided for @labelSharePrice.
  ///
  /// In en, this message translates to:
  /// **'Share price'**
  String get labelSharePrice;

  /// No description provided for @hintSharePrice.
  ///
  /// In en, this message translates to:
  /// **'The price one share trades at. Quoted from Finnhub where a key is configured; click the price to type your own. Everything else in this report comes from the filings.'**
  String get hintSharePrice;

  /// No description provided for @placeholderSharePrice.
  ///
  /// In en, this message translates to:
  /// **'0.00'**
  String get placeholderSharePrice;

  /// No description provided for @valuationIdle.
  ///
  /// In en, this message translates to:
  /// **'Enter the current share price to see how it compares with what the filings say the business earns.'**
  String get valuationIdle;

  /// No description provided for @footnotePriceSource.
  ///
  /// In en, this message translates to:
  /// **'Prices come from Finnhub and are cached until they go stale; typing over one replaces it. Everything else is from the filings.'**
  String get footnotePriceSource;

  /// No description provided for @valuationNoShareCount.
  ///
  /// In en, this message translates to:
  /// **'No share count is on file for this company, so its value cannot be split per share.'**
  String get valuationNoShareCount;

  /// No description provided for @quoteLive.
  ///
  /// In en, this message translates to:
  /// **'Live · {time}'**
  String quoteLive(String time);

  /// No description provided for @quoteStale.
  ///
  /// In en, this message translates to:
  /// **'Last quote · {time}'**
  String quoteStale(String time);

  /// No description provided for @quoteEntered.
  ///
  /// In en, this message translates to:
  /// **'Your price'**
  String get quoteEntered;

  /// No description provided for @quoteFetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching the price…'**
  String get quoteFetching;

  /// No description provided for @quoteRefresh.
  ///
  /// In en, this message translates to:
  /// **'Fetch the current price'**
  String get quoteRefresh;

  /// No description provided for @quoteNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'No quote service is configured, so the price is yours to enter.'**
  String get quoteNotConfigured;

  /// No description provided for @quoteNoCoverage.
  ///
  /// In en, this message translates to:
  /// **'No quote for this symbol — enter a price to value it.'**
  String get quoteNoCoverage;

  /// No description provided for @quoteRateLimited.
  ///
  /// In en, this message translates to:
  /// **'The minute\'s quote allowance is spent. Try again shortly.'**
  String get quoteRateLimited;

  /// No description provided for @quoteNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the quote service.'**
  String get quoteNetwork;

  /// No description provided for @quoteTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The quote service did not answer in time.'**
  String get quoteTimedOut;

  /// No description provided for @quoteService.
  ///
  /// In en, this message translates to:
  /// **'The quote service refused the request.'**
  String get quoteService;

  /// No description provided for @verdictUndervalued.
  ///
  /// In en, this message translates to:
  /// **'Undervalued'**
  String get verdictUndervalued;

  /// No description provided for @verdictFairlyValued.
  ///
  /// In en, this message translates to:
  /// **'Fairly valued'**
  String get verdictFairlyValued;

  /// No description provided for @verdictOvervalued.
  ///
  /// In en, this message translates to:
  /// **'Overvalued'**
  String get verdictOvervalued;

  /// No description provided for @verdictNotValuable.
  ///
  /// In en, this message translates to:
  /// **'Cannot be valued'**
  String get verdictNotValuable;

  /// No description provided for @detailUndervalued.
  ///
  /// In en, this message translates to:
  /// **'The price is below the range these earnings support.'**
  String get detailUndervalued;

  /// No description provided for @detailFairlyValued.
  ///
  /// In en, this message translates to:
  /// **'The price sits inside the range these earnings support.'**
  String get detailFairlyValued;

  /// No description provided for @detailOvervalued.
  ///
  /// In en, this message translates to:
  /// **'The price is above the range these earnings support.'**
  String get detailOvervalued;

  /// No description provided for @detailNotValuable.
  ///
  /// In en, this message translates to:
  /// **'The company reports neither a profit nor free cash flow, so there is nothing to strike a multiple against.'**
  String get detailNotValuable;

  /// No description provided for @labelRangeLow.
  ///
  /// In en, this message translates to:
  /// **'Range low'**
  String get labelRangeLow;

  /// No description provided for @labelRangeHigh.
  ///
  /// In en, this message translates to:
  /// **'Range high'**
  String get labelRangeHigh;

  /// No description provided for @labelPriceToday.
  ///
  /// In en, this message translates to:
  /// **'Price today'**
  String get labelPriceToday;

  /// No description provided for @priceEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Set the share price'**
  String get priceEditorTitle;

  /// No description provided for @priceEditorHint.
  ///
  /// In en, this message translates to:
  /// **'Replaces the quoted price until the next refresh.'**
  String get priceEditorHint;

  /// No description provided for @priceEnter.
  ///
  /// In en, this message translates to:
  /// **'Set a price'**
  String get priceEnter;

  /// No description provided for @labelMarketCap.
  ///
  /// In en, this message translates to:
  /// **'Market value'**
  String get labelMarketCap;

  /// No description provided for @labelEnterpriseValue.
  ///
  /// In en, this message translates to:
  /// **'Enterprise value'**
  String get labelEnterpriseValue;

  /// No description provided for @labelEarningsPerShare.
  ///
  /// In en, this message translates to:
  /// **'Earnings per share'**
  String get labelEarningsPerShare;

  /// No description provided for @valuationBasisLine.
  ///
  /// In en, this message translates to:
  /// **'{low}× to {high}× {basis} of {amount}, less net debt, over {shares} shares'**
  String valuationBasisLine(
    String low,
    String high,
    String basis,
    String amount,
    String shares,
  );

  /// No description provided for @valuationGrowthPremium.
  ///
  /// In en, this message translates to:
  /// **'Includes {points} points of multiple for {growth} annual revenue growth.'**
  String valuationGrowthPremium(String points, String growth);

  /// No description provided for @valuationNoGrowthPremium.
  ///
  /// In en, this message translates to:
  /// **'No growth premium: revenue is not growing on these filings.'**
  String get valuationNoGrowthPremium;

  /// No description provided for @basisFreeCashFlow.
  ///
  /// In en, this message translates to:
  /// **'free cash flow'**
  String get basisFreeCashFlow;

  /// No description provided for @basisEarnings.
  ///
  /// In en, this message translates to:
  /// **'net income'**
  String get basisEarnings;

  /// No description provided for @sectionExpectations.
  ///
  /// In en, this message translates to:
  /// **'What the price is asking'**
  String get sectionExpectations;

  /// No description provided for @expectationRequired.
  ///
  /// In en, this message translates to:
  /// **'Growth the price requires'**
  String get expectationRequired;

  /// No description provided for @expectationDelivered.
  ///
  /// In en, this message translates to:
  /// **'Growth delivered over {years} years'**
  String expectationDelivered(int years);

  /// No description provided for @expectationPerYear.
  ///
  /// In en, this message translates to:
  /// **'{percent} a year'**
  String expectationPerYear(String percent);

  /// No description provided for @expectationBasis.
  ///
  /// In en, this message translates to:
  /// **'Discounting {amount} a year — this company\'s median free cash flow margin of {margin} on its latest revenue — over ten years, fading to 2.5%.'**
  String expectationBasis(String amount, String margin);

  /// No description provided for @expectationNormalised.
  ///
  /// In en, this message translates to:
  /// **'Its latest reported free cash flow was {reported}, {gap} against that, so the year as filed is not used on its own.'**
  String expectationNormalised(String reported, String gap);

  /// No description provided for @expectationSensitivity.
  ///
  /// In en, this message translates to:
  /// **'Required growth by the return a buyer wants'**
  String get expectationSensitivity;

  /// No description provided for @expectationWorth.
  ///
  /// In en, this message translates to:
  /// **'Worth a share if it repeats its record'**
  String get expectationWorth;

  /// No description provided for @expectationRate.
  ///
  /// In en, this message translates to:
  /// **'{percent} return'**
  String expectationRate(String percent);

  /// No description provided for @verdictBelowRecord.
  ///
  /// In en, this message translates to:
  /// **'Asking less than it has delivered'**
  String get verdictBelowRecord;

  /// No description provided for @verdictInLineWithRecord.
  ///
  /// In en, this message translates to:
  /// **'Asking about what it has delivered'**
  String get verdictInLineWithRecord;

  /// No description provided for @verdictBeyondRecord.
  ///
  /// In en, this message translates to:
  /// **'Asking more than it has ever delivered'**
  String get verdictBeyondRecord;

  /// No description provided for @verdictExpectationUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not enough history to judge the price'**
  String get verdictExpectationUnknown;

  /// No description provided for @detailBelowRecord.
  ///
  /// In en, this message translates to:
  /// **'Even a buyer wanting an 11% return needs less growth than this company has managed. Either the market doubts the record repeats, or it has not noticed it.'**
  String get detailBelowRecord;

  /// No description provided for @detailInLineWithRecord.
  ///
  /// In en, this message translates to:
  /// **'The growth the price requires sits inside what the company has actually produced, so the price is a reasonable reading of the record rather than a bet against it.'**
  String get detailInLineWithRecord;

  /// No description provided for @detailBeyondRecord.
  ///
  /// In en, this message translates to:
  /// **'Even a buyer content with a 7% return needs more growth than this company has ever produced. That does not make the price wrong, but it does mean the case for it is not in the filings.'**
  String get detailBeyondRecord;

  /// No description provided for @detailExpectationUnknown.
  ///
  /// In en, this message translates to:
  /// **'Too few years on file, or no positive cash flow to discount.'**
  String get detailExpectationUnknown;

  /// No description provided for @footnoteExpectations.
  ///
  /// In en, this message translates to:
  /// **'A discounted cash flow run backwards: the price is taken as given and the growth it implies is solved for, so the guess belongs to the market rather than to PickStock. The figure moves a long way with the return a buyer wants, which is why the whole band is shown.'**
  String get footnoteExpectations;

  /// No description provided for @watchlistAll.
  ///
  /// In en, this message translates to:
  /// **'All companies'**
  String get watchlistAll;

  /// No description provided for @watchlistFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get watchlistFilterLabel;

  /// No description provided for @watchlistCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{empty} =1{1 company} other{{count} companies}}'**
  String watchlistCount(int count);

  /// No description provided for @watchlistManage.
  ///
  /// In en, this message translates to:
  /// **'Manage lists'**
  String get watchlistManage;

  /// No description provided for @watchlistNew.
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get watchlistNew;

  /// No description provided for @watchlistEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit list'**
  String get watchlistEdit;

  /// No description provided for @watchlistDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete list'**
  String get watchlistDelete;

  /// No description provided for @watchlistDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”? The companies in it are not affected.'**
  String watchlistDeleteConfirm(String name);

  /// No description provided for @watchlistNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Semiconductors, Dividend payers…'**
  String get watchlistNamePlaceholder;

  /// No description provided for @watchlistNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get watchlistNameLabel;

  /// No description provided for @watchlistColourLabel.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get watchlistColourLabel;

  /// No description provided for @watchlistSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get watchlistSave;

  /// No description provided for @watchlistCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get watchlistCancel;

  /// No description provided for @watchlistCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get watchlistCreate;

  /// No description provided for @watchlistDefaultLocked.
  ///
  /// In en, this message translates to:
  /// **'The starred list cannot be deleted.'**
  String get watchlistDefaultLocked;

  /// No description provided for @watchlistEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No lists yet'**
  String get watchlistEmptyTitle;

  /// No description provided for @watchlistEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Star a company, or make a list to group the ones you are watching.'**
  String get watchlistEmptyBody;

  /// No description provided for @watchlistNoMatchesTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this list'**
  String get watchlistNoMatchesTitle;

  /// No description provided for @watchlistNoMatchesBody.
  ///
  /// In en, this message translates to:
  /// **'Open a company and add it to “{name}”.'**
  String watchlistNoMatchesBody(String name);

  /// No description provided for @watchlistStarAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to favourites'**
  String get watchlistStarAdd;

  /// No description provided for @watchlistStarRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get watchlistStarRemove;

  /// No description provided for @watchlistAddTo.
  ///
  /// In en, this message translates to:
  /// **'Add to a list'**
  String get watchlistAddTo;

  /// No description provided for @watchlistInLists.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{In 1 list} other{In {count} lists}}'**
  String watchlistInLists(int count);

  /// No description provided for @watchlistNotInAny.
  ///
  /// In en, this message translates to:
  /// **'Not in any list'**
  String get watchlistNotInAny;

  /// No description provided for @napkinTitle.
  ///
  /// In en, this message translates to:
  /// **'How this was worked out'**
  String get napkinTitle;

  /// No description provided for @napkinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The whole calculation, in the order it happens.'**
  String get napkinSubtitle;

  /// No description provided for @napkinStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Buying the whole company'**
  String get napkinStep1Title;

  /// No description provided for @napkinStep1Body.
  ///
  /// In en, this message translates to:
  /// **'A share costs {price}. There are {shares} of them, so buying every share costs {marketCap}. That is what the market says the company is worth.'**
  String napkinStep1Body(String price, String shares, String marketCap);

  /// No description provided for @napkinStep2Title.
  ///
  /// In en, this message translates to:
  /// **'What you get for it'**
  String get napkinStep2Title;

  /// No description provided for @napkinStep2Body.
  ///
  /// In en, this message translates to:
  /// **'Last year the company collected {revenue} and, after every bill including new equipment, kept {freeCashFlow}. That leftover is the money the owners could actually take out.'**
  String napkinStep2Body(String revenue, String freeCashFlow);

  /// No description provided for @napkinStep3TitleDebt.
  ///
  /// In en, this message translates to:
  /// **'You also inherit the debts'**
  String get napkinStep3TitleDebt;

  /// No description provided for @napkinStep3TitleCash.
  ///
  /// In en, this message translates to:
  /// **'You also get the cash pile'**
  String get napkinStep3TitleCash;

  /// No description provided for @napkinStep3BodyDebt.
  ///
  /// In en, this message translates to:
  /// **'It owes {netDebt} more than it holds. Buy the company and you owe that too, so the real cost is {enterpriseValue}.'**
  String napkinStep3BodyDebt(String netDebt, String enterpriseValue);

  /// No description provided for @napkinStep3BodyCash.
  ///
  /// In en, this message translates to:
  /// **'It holds {netCash} more than it owes. That cash comes with the company, so the real cost is only {enterpriseValue}.'**
  String napkinStep3BodyCash(String netCash, String enterpriseValue);

  /// No description provided for @napkinStep4Title.
  ///
  /// In en, this message translates to:
  /// **'How many years of cash is that?'**
  String get napkinStep4Title;

  /// No description provided for @napkinStep4Body.
  ///
  /// In en, this message translates to:
  /// **'{enterpriseValue} ÷ {freeCashFlow} a year = {years} years to earn the purchase price back, if nothing ever grows.'**
  String napkinStep4Body(
    String enterpriseValue,
    String freeCashFlow,
    String years,
  );

  /// No description provided for @napkinStep5Title.
  ///
  /// In en, this message translates to:
  /// **'How many years is fair?'**
  String get napkinStep5Title;

  /// No description provided for @napkinStep5BodyFlat.
  ///
  /// In en, this message translates to:
  /// **'A business going nowhere is worth roughly 12 to 18 years of its cash. This one is not growing, so it gets no more than that.'**
  String get napkinStep5BodyFlat;

  /// No description provided for @napkinStep5BodyGrowing.
  ///
  /// In en, this message translates to:
  /// **'A business going nowhere is worth roughly 12 to 18 years of its cash. This one grows {growth} a year, which buys it another {premium} years: {low} to {high}.'**
  String napkinStep5BodyGrowing(
    String growth,
    String premium,
    String low,
    String high,
  );

  /// No description provided for @napkinStep6Title.
  ///
  /// In en, this message translates to:
  /// **'So what is a share worth?'**
  String get napkinStep6Title;

  /// No description provided for @napkinStep6Body.
  ///
  /// In en, this message translates to:
  /// **'{low} to {high} years of {basis} is {valueLow} to {valueHigh}. Settle the debts, divide by {shares} shares, and one share is worth {rangeLow} to {rangeHigh}.'**
  String napkinStep6Body(
    String low,
    String high,
    String basis,
    String valueLow,
    String valueHigh,
    String shares,
    String rangeLow,
    String rangeHigh,
  );

  /// No description provided for @napkinStep7Title.
  ///
  /// In en, this message translates to:
  /// **'And the answer'**
  String get napkinStep7Title;

  /// No description provided for @napkinStep7BodyUnder.
  ///
  /// In en, this message translates to:
  /// **'You are paying {price}, below the {rangeLow}–{rangeHigh} the earnings support. That is the cheap side.'**
  String napkinStep7BodyUnder(String price, String rangeLow, String rangeHigh);

  /// No description provided for @napkinStep7BodyFair.
  ///
  /// In en, this message translates to:
  /// **'You are paying {price}, inside the {rangeLow}–{rangeHigh} the earnings support. That is a normal price.'**
  String napkinStep7BodyFair(String price, String rangeLow, String rangeHigh);

  /// No description provided for @napkinStep7BodyOver.
  ///
  /// In en, this message translates to:
  /// **'You are paying {price}, above the {rangeLow}–{rangeHigh} the earnings support. You are paying for growth that has not happened yet.'**
  String napkinStep7BodyOver(String price, String rangeLow, String rangeHigh);

  /// No description provided for @napkinCaveatTitle.
  ///
  /// In en, this message translates to:
  /// **'Worth knowing'**
  String get napkinCaveatTitle;

  /// No description provided for @napkinCaveatBuilding.
  ///
  /// In en, this message translates to:
  /// **'It spent {ratio}× more on equipment than wore out, so last year\'s leftover cash understates what the business normally makes. The section below uses a smoothed figure instead.'**
  String napkinCaveatBuilding(String ratio);

  /// No description provided for @napkinCaveatMargin.
  ///
  /// In en, this message translates to:
  /// **'Its profit margin is {points} points below its own ten-year normal, so the sales growth above is being won at a lower profit.'**
  String napkinCaveatMargin(String points);

  /// No description provided for @napkinCaveatEarnings.
  ///
  /// In en, this message translates to:
  /// **'It generates no spare cash, so this uses accounting profit instead — a weaker measure, because profit is an opinion and cash is a fact.'**
  String get napkinCaveatEarnings;

  /// No description provided for @labelPriceEarnings.
  ///
  /// In en, this message translates to:
  /// **'P/E'**
  String get labelPriceEarnings;

  /// No description provided for @labelEnterpriseValueToFreeCashFlow.
  ///
  /// In en, this message translates to:
  /// **'EV/FCF'**
  String get labelEnterpriseValueToFreeCashFlow;

  /// No description provided for @labelFreeCashFlowYield.
  ///
  /// In en, this message translates to:
  /// **'FCF yield'**
  String get labelFreeCashFlowYield;

  /// No description provided for @labelGrowthAdjusted.
  ///
  /// In en, this message translates to:
  /// **'PEG'**
  String get labelGrowthAdjusted;

  /// No description provided for @labelPriceToSales.
  ///
  /// In en, this message translates to:
  /// **'P/S'**
  String get labelPriceToSales;

  /// No description provided for @hintPriceEarnings.
  ///
  /// In en, this message translates to:
  /// **'Price divided by earnings per share: years of current profit the price costs. Blank at a loss, where the ratio means nothing.'**
  String get hintPriceEarnings;

  /// No description provided for @hintEnterpriseValueToFreeCashFlow.
  ///
  /// In en, this message translates to:
  /// **'Enterprise value over free cash flow. Unlike P/E it counts debt, so a company that borrowed to buy its earnings looks dearer.'**
  String get hintEnterpriseValueToFreeCashFlow;

  /// No description provided for @hintFreeCashFlowYield.
  ///
  /// In en, this message translates to:
  /// **'Free cash flow as a percentage of market value — what an owner earns at this price before any growth. Higher is cheaper.'**
  String get hintFreeCashFlowYield;

  /// No description provided for @hintGrowthAdjusted.
  ///
  /// In en, this message translates to:
  /// **'The earnings multiple divided by the annual revenue growth rate. Under 1 means the growth more than covers the multiple.'**
  String get hintGrowthAdjusted;

  /// No description provided for @hintPriceToSales.
  ///
  /// In en, this message translates to:
  /// **'Market value over revenue. The fallback when a company has no profit to divide by, and worth little on its own.'**
  String get hintPriceToSales;

  /// No description provided for @footnoteValuation.
  ///
  /// In en, this message translates to:
  /// **'The fair range is a heuristic: {low}–{high} times the latest year\'s {basis}, widened for revenue growth, less net debt. It is a frame for the price, not a target.'**
  String footnoteValuation(String low, String high, String basis);

  /// No description provided for @footnoteNegatives.
  ///
  /// In en, this message translates to:
  /// **'Cash includes short-term investments. Net debt is negative when a company holds more of it than it owes.'**
  String get footnoteNegatives;

  /// No description provided for @footnoteSource.
  ///
  /// In en, this message translates to:
  /// **'Source: SEC EDGAR XBRL company facts. Figures in USD millions. A sanity check on the shape of the numbers — not investment advice.'**
  String get footnoteSource;

  /// No description provided for @footnoteQuarters.
  ///
  /// In en, this message translates to:
  /// **'Fourth-quarter income and cash-flow figures are derived by subtracting the first three quarters from the full year; balance-sheet figures are as filed.'**
  String get footnoteQuarters;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
