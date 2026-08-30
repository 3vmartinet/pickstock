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

  /// No description provided for @ingestStart.
  ///
  /// In en, this message translates to:
  /// **'Download SEC data'**
  String get ingestStart;

  /// No description provided for @ingestDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}'**
  String ingestDownloading(String percent);

  /// No description provided for @ingestParsing.
  ///
  /// In en, this message translates to:
  /// **'Loading {count} companies…'**
  String ingestParsing(int count);

  /// No description provided for @ingestDone.
  ///
  /// In en, this message translates to:
  /// **'{count} companies loaded'**
  String ingestDone(int count);

  /// No description provided for @ingestFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed — try again'**
  String get ingestFailed;

  /// No description provided for @ingestSize.
  ///
  /// In en, this message translates to:
  /// **'One 1.4 GB download from SEC, then everything is local.'**
  String get ingestSize;

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

  /// No description provided for @searchAction.
  ///
  /// In en, this message translates to:
  /// **'Analyze'**
  String get searchAction;

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

  /// No description provided for @labelYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get labelYear;

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
  /// **'Net debt / (cash)'**
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
  /// **'Total borrowings minus cash. Negative means the company holds more cash than debt.'**
  String get hintNetDebt;

  /// No description provided for @deltaVersusPriorYear.
  ///
  /// In en, this message translates to:
  /// **'vs FY{year}'**
  String deltaVersusPriorYear(String year);

  /// No description provided for @footnoteNegatives.
  ///
  /// In en, this message translates to:
  /// **'Values in parentheses are negative — a net cash position.'**
  String get footnoteNegatives;

  /// No description provided for @footnoteSource.
  ///
  /// In en, this message translates to:
  /// **'Source: SEC EDGAR XBRL company facts, 10-K filings only. Figures in USD millions. A sanity check on the shape of the numbers — not investment advice.'**
  String get footnoteSource;

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
