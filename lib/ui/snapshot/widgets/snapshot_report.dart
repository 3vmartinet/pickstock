import 'package:flutter_animate/flutter_animate.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/snapshot/widgets/company_header.dart';
import 'package:pickstock/ui/snapshot/widgets/history_order_toggle.dart';
import 'package:pickstock/ui/snapshot/widgets/history_table.dart';
import 'package:pickstock/ui/snapshot/widgets/metric_grid.dart';
import 'package:pickstock/ui/snapshot/widgets/sanity_check_grid.dart';
import 'package:pickstock/ui/widgets/section_header.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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
  });

  final IconData icon;
  final String title;
  final Widget child;

  /// Optional control aligned to the far end of the section heading.
  final Widget? trailing;

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

class _HistorySection extends StatelessWidget {
  const _HistorySection();

  @override
  Widget build(BuildContext context) {
    // Titled from the data: how many years EDGAR holds varies by company.
    final yearCount = context.select<SnapshotViewModel, int>(
      (viewModel) => viewModel.reportedYearCount,
    );

    return _Section(
      icon: LucideIcons.chartNoAxesColumn,
      title: context.strings.sectionHistory(yearCount),
      trailing: const HistoryOrderToggle(),
      child: const HistoryTable(),
    );
  }
}

class _Footnotes extends StatelessWidget {
  const _Footnotes();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: ThemeRepo.spaceLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: ThemeRepo.spaceXSmall,
        children: [
          Text(context.strings.footnoteNegatives).muted().xSmall(),
          Text(context.strings.footnoteSource).muted().xSmall(),
        ],
      ),
    );
  }
}
