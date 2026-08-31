import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/history_period.dart';
import 'package:pickstock/data/valuation/valuation.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/snapshot/widgets/company_header.dart';
import 'package:pickstock/ui/snapshot/widgets/expectation_card.dart';
import 'package:pickstock/ui/snapshot/widgets/history_order_toggle.dart';
import 'package:pickstock/ui/snapshot/widgets/history_period_tabs.dart';
import 'package:pickstock/ui/snapshot/widgets/history_table.dart';
import 'package:pickstock/ui/snapshot/widgets/metric_grid.dart';
import 'package:pickstock/ui/snapshot/widgets/napkin_math.dart';
import 'package:pickstock/ui/snapshot/widgets/sanity_check_grid.dart';
import 'package:pickstock/ui/snapshot/widgets/share_price_field.dart';
import 'package:pickstock/ui/snapshot/widgets/valuation_grid.dart';
import 'package:pickstock/ui/snapshot/widgets/valuation_verdict_card.dart';
import 'package:pickstock/ui/widgets/section_header.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();

/// The whole report for a loaded snapshot, top to bottom.
class SnapshotReport extends StatelessWidget {
  const SnapshotReport({super.key});

  @override
  Widget build(BuildContext context) {
    // Sections rise into place one after the other so the eye is led down the
    // page in reading order rather than everything landing at once.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children:
          const <Widget>[
                CompanyHeader(),
                _SanityCheckSection(),
                _HighlightsSection(),
                _ValuationSection(),
                _ExpectationsSection(),
                _HistorySection(),
                _Footnotes(),
              ]
              .animate(interval: ThemeRepo.entranceStagger)
              .fadeIn(duration: ThemeRepo.entranceDuration)
              .slideY(
                begin: ThemeRepo.entranceSlide,
                end: 0,
                duration: ThemeRepo.entranceDuration,
                curve: Curves.easeOutCubic,
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
      trailing: const SharePriceField(),
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
    if (!hasPrice) {
      return Text(context.strings.valuationIdle).muted().small();
    }

    // The verdict and its ratios on the left, the worked example on the right,
    // so a reader can follow the arithmetic beside the answer it produced —
    // and below it instead where the pane is too narrow to split.
    return LayoutBuilder(
      builder: (context, constraints) {
        const cards = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: ThemeRepo.spaceMedium,
          children: [ValuationVerdictCard(), ValuationGrid()],
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
    if (!hasExpectation) return const SizedBox.shrink();

    return _Section(
      icon: LucideIcons.target,
      title: context.strings.sectionExpectations,
      child: const ExpectationCard(),
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
    // The quarterly caveat is only shown where it applies.
    final isQuarterly = context.select<SnapshotViewModel, bool>(
      (viewModel) => viewModel.historyPeriod == HistoryPeriod.quarterly,
    );
    final valuation = context.select<SnapshotViewModel, Valuation?>(
      (viewModel) => viewModel.valuation,
    );

    return Padding(
      padding: const EdgeInsets.only(top: ThemeRepo.spaceLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: ThemeRepo.spaceXSmall,
        children: [
          Text(context.strings.footnoteNegatives).muted().xSmall(),
          if (valuation != null) ...[
            Text(context.strings.footnotePriceSource).muted().xSmall(),
            Text(context.strings.footnoteExpectations).muted().xSmall(),
          ],
          if (valuation?.basis case final basis?)
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
