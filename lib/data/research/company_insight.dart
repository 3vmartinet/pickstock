import 'package:pickstock/l10n/app_localizations.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The three questions a model can answer that EDGAR cannot.
///
/// Each belongs to one tab, and each exists because of something the filings
/// structurally do not carry — not because a tab looked like it wanted a
/// button. The valuation one is the reason the rest are worth having: every
/// wrong band this app has produced came from a figure that was read correctly
/// and did not mean what it appeared to.
enum CompanyInsight {
  /// What the business is, and what has been moving its revenue.
  ///
  /// EDGAR publishes no prose description of a registrant anywhere: the
  /// industry title behind a SIC code is the closest thing on file, which is
  /// how a report can show ten years of a blank-cheque company's figures
  /// without ever saying it is one.
  business(icon: LucideIcons.building2),

  /// Whether the figures the band was struck from mean what they appear to.
  ///
  /// MarketWise's cash was 91% somebody else's, Lyft's profit was a deferred
  /// tax release, and Mastercard's share count was last restated before a
  /// ten-for-one split. Each was read correctly out of the filing and each
  /// produced a band out by more than a factor of ten. The narrative around
  /// the numbers is where all three were visible.
  inputs(icon: LucideIcons.scanSearch),

  /// What the company and the market expect, against what the price asks.
  ///
  /// The tab works out the growth a price implies and reads the company's own
  /// history three ways. What it cannot know is whether anyone — management
  /// included — expects that growth, which is the only thing that makes the
  /// implied rate a claim rather than a calculation.
  expectations(icon: LucideIcons.messageSquareQuote);

  const CompanyInsight({required this.icon});

  final IconData icon;

  /// The heading over the block, which frames the question rather than
  /// advertising the machinery answering it.
  String getTitle(AppLocalizations strings) => switch (this) {
    CompanyInsight.business => strings.insightBusinessTitle,
    CompanyInsight.inputs => strings.insightInputsTitle,
    CompanyInsight.expectations => strings.insightExpectationsTitle,
  };

  /// Why the app cannot answer it from the filings alone. Shown until it has
  /// been asked, so the offer explains itself.
  String getInvitation(AppLocalizations strings) => switch (this) {
    CompanyInsight.business => strings.insightBusinessInvitation,
    CompanyInsight.inputs => strings.insightInputsInvitation,
    CompanyInsight.expectations => strings.insightExpectationsInvitation,
  };

  /// What the button says.
  String getAction(AppLocalizations strings) => switch (this) {
    CompanyInsight.business => strings.insightBusinessAction,
    CompanyInsight.inputs => strings.insightInputsAction,
    CompanyInsight.expectations => strings.insightExpectationsAction,
  };
}

/// How the news is filed alongside the three insights.
///
/// Not a [CompanyInsight] itself: it is structured differently — developments
/// rather than prose — and it lives in the header rather than on a tab.
const String eventsNoteKind = 'events';

/// Where an insight has got to. One per insight per company: reading around
/// costs a minute of a local model, so each is asked for on its own.
enum InsightState { idle, loading, ready, failed }
