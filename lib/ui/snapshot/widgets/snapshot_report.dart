import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/data/snapshot/history_period.dart';
import 'package:pickstock/data/research/company_insight.dart';
import 'package:pickstock/data/snapshot/report_tab.dart';
import 'package:pickstock/data/valuation/valuation.dart';
import 'package:pickstock/data/valuation/valuation_verdict.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/snapshot/widgets/company_insight_card.dart';
import 'package:pickstock/ui/snapshot/widgets/company_header.dart';
import 'package:pickstock/ui/snapshot/widgets/expectation_card.dart';
import 'package:pickstock/ui/snapshot/widgets/price_target_card.dart';
import 'package:pickstock/ui/snapshot/widgets/history_order_toggle.dart';
import 'package:pickstock/ui/snapshot/widgets/history_period_tabs.dart';
import 'package:pickstock/ui/snapshot/widgets/history_table.dart';
import 'package:pickstock/ui/snapshot/widgets/metric_grid.dart';
import 'package:pickstock/ui/snapshot/widgets/napkin_math.dart';
import 'package:pickstock/ui/snapshot/widgets/price_editor.dart';
import 'package:pickstock/ui/snapshot/widgets/sanity_check_grid.dart';
import 'package:pickstock/ui/snapshot/widgets/valuation_grid.dart';
import 'package:pickstock/ui/snapshot/widgets/valuation_verdict_card.dart';
import 'package:pickstock/ui/widgets/section_header.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();
ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// The whole report for a loaded snapshot: who the company is, then one tab
/// per question asked of it.
class SnapshotReport extends StatelessWidget {
  const SnapshotReport({super.key});

  @override
  Widget build(BuildContext context) {
    // The company and its tabs stay put while the report scrolls under them:
    // on a long tab you would otherwise lose both the name of what you are
    // reading and the way to the other tab.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.pageGutter,
            context.pageGutter,
            context.pageGutter,
            0,
          ),
          child: const _Pinned(),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              context.pageGutter,
              0,
              context.pageGutter,
              context.pageGutter,
            ),
            child: const ReportTabBody(),
          ),
        ),
      ],
    );
  }
}

/// What stays on screen however far the report scrolls.
class _Pinned extends StatelessWidget {
  const _Pinned();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [CompanyHeader(), ReportTabs()],
  );
}

/// Everything that scrolls: the open tab, and the notes belonging to it.
class ReportTabBody extends StatelessWidget {
  const ReportTabBody({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [_TabBody(), _Footnotes()],
  );
}

/// The tab bar, under the company and above everything it applies to.
///
/// `Tabs` with `expand`, so the two share whatever width there is. The
/// underlined `TabList` sizes each tab to its own content instead, which ran
/// past the right edge of a narrow window — unreachable, with nothing to say
/// there was more. Filling the width also tells this control apart from the
/// small pill that switches the history between annual and quarterly.
class ReportTabs extends StatelessWidget {
  const ReportTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final current = context.select<SnapshotViewModel, ReportTab>(
      (viewModel) => viewModel.reportTab,
    );
    // The answer, on the tab that holds it. Once a price is in, the verdict
    // is the one thing a reader opens a company for, and it was two clicks
    // away behind a tab labelled with a pair of scales.
    final verdict = context.select<SnapshotViewModel, ValuationVerdict?>(
      (viewModel) => viewModel.valuation?.verdict,
    );

    return Padding(
      padding: const EdgeInsets.only(top: ThemeRepo.reportTabsGap),
      child: Tabs(
        index: current.index,
        expand: true,
        onChanged: (index) => context.read<SnapshotViewModel>().selectReportTab(
          ReportTab.values[index],
        ),
        children: [
          for (final tab in ReportTab.values)
            TabItem(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: ThemeRepo.spaceSmall,
                children: [
                  // Dropped on a narrow window: three labels and three icons
                  // leave the labels no room to be read.
                  if (!context.isCompact) Icon(tab.icon).iconXSmall(),
                  Flexible(
                    child: Text(tab.getLabel(context.strings)).singleLine(),
                  ),
                  if (tab == ReportTab.valuation)
                    _VerdictMark(verdict: verdict),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The verdict, after the valuation tab's own label.
///
/// Trailing rather than in place of the tab's glyph: the scales say what the
/// tab is for and the arrow says what it found, and a tab that swapped one
/// for the other lost the first to gain the second.
///
/// Subtle by design — the same size as the glyph opposite it, in the colour
/// the verdict already uses on the card inside. It says nothing at all until
/// there is a price, where a question mark would only be noise beside two
/// tabs that are quietly getting on with it.
///
/// Kept on a narrow window, where the leading glyphs are dropped for room:
/// one mark on one tab is what those three were making way for, and it is the
/// thing a reader opened the company to see.
class _VerdictMark extends StatelessWidget {
  const _VerdictMark({required this.verdict});

  final ValuationVerdict? verdict;

  @override
  Widget build(BuildContext context) {
    final shown = verdict;
    if (shown == null || shown == ValuationVerdict.unknown) {
      return const SizedBox.shrink();
    }
    return Icon(
      shown.icon,
      color: _themeRepo.forOutcome(context.theme, isGood: shown.isGood),
    ).iconXSmall();
  }
}

/// Whichever tab is open.
class _TabBody extends StatelessWidget {
  const _TabBody();

  @override
  Widget build(BuildContext context) {
    final tab = context.select<SnapshotViewModel, ReportTab>(
      (viewModel) => viewModel.reportTab,
    );

    final sections = switch (tab) {
      ReportTab.overview => const <Widget>[
        // Before the checks: what the company does is the question a reader
        // asks before whether its revenue grew.
        _InsightSection(insight: CompanyInsight.business),
        _SanityCheckSection(),
        _HighlightsSection(),
        _HistorySection(),
      ],
      // Both of these carry their insight inside their own layout rather than
      // as a section after it: appended, it sat below a screen of arithmetic
      // and was read by nobody.
      ReportTab.valuation => const <Widget>[_ValuationSection()],
      ReportTab.expectations => const <Widget>[_ExpectationsSection()],
    };

    // Keyed on the tab so switching replays the entrance instead of morphing
    // one layout into the next; the sections inside still stagger.
    return KeyedSubtree(
      key: ValueKey(tab),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: sections
            .animate(interval: ThemeRepo.entranceStagger)
            .fadeIn(duration: ThemeRepo.entranceDuration)
            .slideY(
              begin: ThemeRepo.entranceSlide,
              end: 0,
              duration: ThemeRepo.entranceDuration,
              curve: Curves.easeOutCubic,
            ),
      ),
    );
  }
}

/// A titled block of the report, spaced away from the one above it.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    this.belowHeading,
  });

  final IconData icon;
  final String title;
  final Widget child;

  /// Optional control aligned to the far end of the section heading.
  final Widget? trailing;

  /// Optional control on its own row under the heading, for anything too wide
  /// to sit beside the title.
  final Widget? belowHeading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: ThemeRepo.spaceLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: ThemeRepo.spaceSmall,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionHeader(icon: icon, title: title),
              ),
              ?trailing,
            ],
          ),
          ?belowHeading,
          child,
        ],
      ),
    );
  }
}

/// One insight, spaced like the sections it sits between.
///
/// No heading of its own: the alert inside carries its own title, and a
/// section header above it would state the question twice.
/// The targets beside the verdict, and the reading-around under both.
///
/// Side by side because they answer halves of one question — what a share is
/// worth if the company keeps going as it has, and what the price is already
/// asking of it — and a reader compares them rather than reading them in
/// turn. Stacked where the pane is too narrow to put them level.
class _ExpectationsContent extends StatelessWidget {
  const _ExpectationsContent();

  @override
  Widget build(BuildContext context) {
    // Level only where there are two cards to put level: without price cases
    // the targets card collapses to nothing, and an `Expanded` around it
    // would hold half the row open for a void.
    final hasTargets = context.select<SnapshotViewModel, bool>(
      (viewModel) => viewModel.hasPriceTargets,
    );

    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: ThemeRepo.spaceMedium,
        children: [
          if (!hasTargets)
            const ExpectationCard()
          else if (constraints.maxWidth <
              ThemeRepo.expectationsSideBySideMinWidth)
            const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: ThemeRepo.spaceMedium,
              children: [PriceTargetCard(), ExpectationCard()],
            )
          else
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: ThemeRepo.spaceMedium,
              children: [
                Expanded(child: PriceTargetCard()),
                Expanded(child: ExpectationCard()),
              ],
            ),
          // Under both: it sets what anyone else expects against the pair,
          // which cannot be read before them.
          const CompanyInsightCard(insight: CompanyInsight.expectations),
        ],
      ),
    );
  }
}

class _InsightSection extends StatelessWidget {
  const _InsightSection({required this.insight});

  final CompanyInsight insight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: ThemeRepo.spaceLarge),
      child: CompanyInsightCard(insight: insight),
    );
  }
}

class _SanityCheckSection extends StatelessWidget {
  const _SanityCheckSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: LucideIcons.shieldCheck,
      title: context.strings.sectionSanityCheck,
      child: const SanityCheckGrid(),
    );
  }
}

class _HighlightsSection extends StatelessWidget {
  const _HighlightsSection();

  @override
  Widget build(BuildContext context) {
    final latestYear = context.select<SnapshotViewModel, String?>(
      (viewModel) => viewModel.latestFigures?.fiscalYear.toString(),
    );
    if (latestYear == null) return const SizedBox.shrink();

    return _Section(
      icon: LucideIcons.sparkles,
      title: context.strings.sectionHighlights(latestYear),
      child: const MetricGrid(),
    );
  }
}

/// Judges the entered price against the filings.
///
/// It sits under the highlights because it only makes sense once the figures it
/// divides are on screen, and above the history because it is a verdict on the
/// present rather than a record of the past.
class _ValuationSection extends StatelessWidget {
  const _ValuationSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: LucideIcons.scale,
      title: context.strings.sectionValuation,
      child: const _ValuationContent(),
    );
  }
}

class _ValuationContent extends StatelessWidget {
  const _ValuationContent();

  @override
  Widget build(BuildContext context) {
    final canBeValued = context.select<SnapshotViewModel, bool>(
      (viewModel) => viewModel.canBeValued,
    );
    if (!canBeValued) {
      return Text(context.strings.valuationNoShareCount).muted().small();
    }

    final hasPrice = context.select<SnapshotViewModel, bool>(
      (viewModel) => viewModel.pricePerShare != null,
    );
    if (!hasPrice) return const _NoPriceYet();

    // The verdict and its ratios on the left, the worked example on the right,
    // so a reader can follow the arithmetic beside the answer it produced —
    // and below it instead where the pane is too narrow to split.
    return LayoutBuilder(
      builder: (context, constraints) {
        const cards = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: ThemeRepo.spaceMedium,
          children: [
            ValuationVerdictCard(),
            ValuationGrid(),
            // Under the ratios and beside the worked example, so the check on
            // the figures is read at the same height as the figures rather
            // than a screen below them.
            //
            // Inside the priced branch on purpose: the question quotes the
            // cash flow and share count the band was struck from, and there
            // is no band to check until there is a price.
            CompanyInsightCard(insight: CompanyInsight.inputs),
          ],
        );

        if (constraints.maxWidth < ThemeRepo.napkinSideBySideMinWidth) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: ThemeRepo.spaceMedium,
            children: [cards, NapkinMath()],
          );
        }

        return const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: ThemeRepo.spaceMedium,
          children: [
            Expanded(flex: ThemeRepo.valuationCardsFlex, child: cards),
            Expanded(flex: ThemeRepo.napkinFlex, child: NapkinMath()),
          ],
        );
      },
    );
  }
}

/// What the price is asking of the company, and whether the company has ever
/// done it.
///
/// Separate from the valuation above because it answers a different question:
/// not "is this multiple high" but "what would have to be true for this price
/// to be right, and has it been true before".
class _ExpectationsSection extends StatelessWidget {
  const _ExpectationsSection();

  @override
  Widget build(BuildContext context) {
    final hasExpectation = context.select<SnapshotViewModel, bool>(
      (viewModel) => viewModel.growthExpectation != null,
    );
    // On its own tab now, so an absent price leaves an empty screen rather
    // than a gap under the valuation. Same way in as the valuation offers.
    if (!hasExpectation) {
      return _Section(
        icon: LucideIcons.target,
        title: context.strings.sectionExpectations,
        child: const _NoPriceYet(),
      );
    }

    return _Section(
      icon: LucideIcons.target,
      title: context.strings.sectionExpectations,
      // The targets first: what a share is worth is the question a reader
      // came with. The verdict below sets it against what the price already
      // asks, which is the check on taking any single target seriously.
      child: const _ExpectationsContent(),
    );
  }
}

/// The valuation with nothing to value: why there is no price, and the way to
/// supply one.
///
/// The gauge carries both of those once a price exists, but it does not exist
/// yet — so a failed quote would otherwise leave the reader looking at an
/// invitation to type with no hint that anything had been tried.
class _NoPriceYet extends StatelessWidget {
  const _NoPriceYet();

  @override
  Widget build(BuildContext context) {
    final isQuoting = context.select<SnapshotViewModel, bool>(
      (viewModel) => viewModel.isQuoting,
    );
    final failure = context.select<SnapshotViewModel, QuoteFailure?>(
      (viewModel) => viewModel.quoteFailure,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: ThemeRepo.spaceMedium,
      children: [
        Text(switch ((isQuoting, failure)) {
          (true, _) => context.strings.quoteFetching,
          (_, final QuoteFailure reason?) => reason.describe(context.strings),
          _ => context.strings.valuationIdle,
        }).muted().small(),
        OutlineButton(
          density: ButtonDensity.compact,
          leading: const Icon(LucideIcons.dollarSign).iconXSmall(),
          onPressed: () => showPriceEditor(context),
          child: Text(context.strings.priceEnter),
        ),
      ],
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection();

  @override
  Widget build(BuildContext context) {
    // Titled from the data: how many periods EDGAR holds varies by company.
    final rowCount = context.select<SnapshotViewModel, int>(
      (viewModel) => viewModel.historyRowCount,
    );
    final period = context.select<SnapshotViewModel, HistoryPeriod>(
      (viewModel) => viewModel.historyPeriod,
    );

    return _Section(
      icon: LucideIcons.chartNoAxesColumn,
      title: switch (period) {
        HistoryPeriod.annual => context.strings.sectionHistory(rowCount),
        HistoryPeriod.quarterly => context.strings.sectionQuarterHistory(
          rowCount,
        ),
      },
      trailing: const HistoryOrderToggle(),
      belowHeading: const HistoryPeriodTabs(),
      child: const HistoryTable(),
    );
  }
}

class _Footnotes extends StatelessWidget {
  const _Footnotes();

  @override
  Widget build(BuildContext context) {
    // Each caveat is shown on the tab it applies to and nowhere else: a
    // footnote about quarters under a valuation is noise.
    final tab = context.select<SnapshotViewModel, ReportTab>(
      (viewModel) => viewModel.reportTab,
    );
    final isQuarterly =
        tab == ReportTab.overview &&
        context.select<SnapshotViewModel, bool>(
          (viewModel) => viewModel.historyPeriod == HistoryPeriod.quarterly,
        );
    final valuation = tab == ReportTab.overview
        ? null
        : context.select<SnapshotViewModel, Valuation?>(
            (viewModel) => viewModel.valuation,
          );
    // How the band was struck belongs under the band, not under the growth it
    // is being compared with.
    final valuationBasis = tab == ReportTab.valuation ? valuation?.basis : null;

    return Padding(
      padding: const EdgeInsets.only(top: ThemeRepo.spaceLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: ThemeRepo.spaceXSmall,
        children: [
          Text(context.strings.footnoteNegatives).muted().xSmall(),
          if (valuation != null)
            Text(context.strings.footnotePriceSource).muted().xSmall(),
          if (tab == ReportTab.expectations && valuation != null)
            Text(context.strings.footnoteExpectations).muted().xSmall(),
          if (valuationBasis case final basis?)
            Text(
              context.strings.footnoteValuation(
                _formatRepo.ratio(valuation!.lowMultiple),
                _formatRepo.ratio(valuation.highMultiple),
                basis.getLabel(context.strings),
              ),
            ).muted().xSmall(),
          if (isQuarterly)
            Text(context.strings.footnoteQuarters).muted().xSmall(),
          Text(context.strings.footnoteSource).muted().xSmall(),
        ],
      ),
    );
  }
}
