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

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Financial health snapshots from SEC EDGAR'**
  String get appSubtitle;

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
  /// **'{read} of {total} data sets'**
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
  /// **'{received} of {total}'**
  String ingestBytesOfTotal(String received, String total);

  /// No description provided for @ingestRate.
  ///
  /// In en, this message translates to:
  /// **'{rate}/s'**
  String ingestRate(String rate);

  /// No description provided for @ingestRateCompanies.
  ///
  /// In en, this message translates to:
  /// **'{rate} companies/s'**
  String ingestRateCompanies(int rate);

  /// No description provided for @ingestRemaining.
  ///
  /// In en, this message translates to:
  /// **'{duration} left'**
  String ingestRemaining(String duration);

  /// No description provided for @ingestCompaniesOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{loaded} of {total} companies'**
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

  /// No description provided for @ingestStageDirectory.
  ///
  /// In en, this message translates to:
  /// **'Fetching the ticker directory…'**
  String get ingestStageDirectory;

  /// No description provided for @ingestStageDownload.
  ///
  /// In en, this message translates to:
  /// **'Downloading the archive… {percent}'**
  String ingestStageDownload(String percent);

  /// No description provided for @ingestStageDownloadSized.
  ///
  /// In en, this message translates to:
  /// **'Downloading the archive… {received} of {total}'**
  String ingestStageDownloadSized(String received, String total);

  /// No description provided for @ingestStageLoad.
  ///
  /// In en, this message translates to:
  /// **'Loading filings into the database… {count} of {total} companies'**
  String ingestStageLoad(int count, int total);

  /// No description provided for @ingestStageFinishing.
  ///
  /// In en, this message translates to:
  /// **'Finishing up…'**
  String get ingestStageFinishing;

  /// No description provided for @ingestStageLoadHint.
  ///
  /// In en, this message translates to:
  /// **'Reading 20,000 filings takes a few minutes.'**
  String get ingestStageLoadHint;

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

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search by symbol or company name'**
  String get searchPlaceholder;

  /// No description provided for @searchExamples.
  ///
  /// In en, this message translates to:
  /// **'Try one of these'**
  String get searchExamples;

  /// No description provided for @browseTitle.
  ///
  /// In en, this message translates to:
  /// **'All tickers'**
  String get browseTitle;

  /// No description provided for @browseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 symbol} other{{count} symbols}} filed with SEC EDGAR'**
  String browseSubtitle(int count);

  /// No description provided for @browseOpen.
  ///
  /// In en, this message translates to:
  /// **'Browse all tickers'**
  String get browseOpen;

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

  /// No description provided for @browseSortLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get browseSortLabel;

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

  /// No description provided for @browseBack.
  ///
  /// In en, this message translates to:
  /// **'Back to the report'**
  String get browseBack;

  /// No description provided for @idleTitle.
  ///
  /// In en, this message translates to:
  /// **'Check a company before you invest'**
  String get idleTitle;

  /// No description provided for @idleBody.
  ///
  /// In en, this message translates to:
  /// **'Type a ticker symbol or a company name to pull the last three fiscal years of revenue, profitability, free cash flow and balance-sheet strength — straight from the company\'s own 10-K filings.'**
  String get idleBody;

  /// No description provided for @loadingResolving.
  ///
  /// In en, this message translates to:
  /// **'Looking up {ticker} in the SEC ticker registry…'**
  String loadingResolving(String ticker);

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

  /// No description provided for @labelOperatingCashFlow.
  ///
  /// In en, this message translates to:
  /// **'Operating cash flow'**
  String get labelOperatingCashFlow;

  /// No description provided for @labelCapitalExpenditure.
  ///
  /// In en, this message translates to:
  /// **'Capital expenditure'**
  String get labelCapitalExpenditure;

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

  /// No description provided for @labelFiscalYearsCovered.
  ///
  /// In en, this message translates to:
  /// **'FY{first} – FY{last}'**
  String labelFiscalYearsCovered(String first, String last);

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
  /// **'Total borrowings minus cash. A negative figure is a net cash position: the company holds more cash than debt.'**
  String get hintNetDebt;

  /// No description provided for @deltaVersusPriorYear.
  ///
  /// In en, this message translates to:
  /// **'vs FY{year}'**
  String deltaVersusPriorYear(String year);

  /// No description provided for @footnoteNegatives.
  ///
  /// In en, this message translates to:
  /// **'Net debt is negative when a company holds more cash than it owes.'**
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

  /// No description provided for @unitMillionsSuffix.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get unitMillionsSuffix;
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
