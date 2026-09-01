import 'package:get_it/get_it.dart';
import 'package:pickstock/data/report/valuation_job.dart';
import 'package:pickstock/data/report/valuation_report.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/app_route.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/report/jobs_view_model.dart';
import 'package:pickstock/ui/report/widgets/report_actions.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();

/// The app bar's way into scans: start one, watch it, open what it found.
///
/// A popover rather than a screen, because a run is something you glance at
/// while doing something else — and a screen you have to leave to keep working
/// is a screen you stop checking.
class JobsButton extends StatelessWidget {
  const JobsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final running = context.select<JobsViewModel, int>(
      (viewModel) => viewModel.runningCount,
    );

    return Tooltip(
      tooltip: HintTooltip(context.strings.jobsTooltip).call,
      child: GhostButton(
        density: ButtonDensity.icon,
        onPressed: () =>
            showDropdown(context: context, builder: (_) => const _JobsPanel()),
        child: running > 0
            // The spinner is the badge: a count of one running job says less
            // than the fact that something is running at all.
            ? const SizedBox.square(
                dimension: ThemeRepo.inlineSpinnerSize,
                child: CircularProgressIndicator(),
              )
            : const Icon(LucideIcons.listChecks),
      ),
    );
  }
}

class _JobsPanel extends StatelessWidget {
  const _JobsPanel();

  @override
  Widget build(BuildContext context) {
    final jobs = context.select<JobsViewModel, List<ValuationJob>>(
      (viewModel) => viewModel.jobs,
    );
    final reports = context.select<JobsViewModel, List<ValuationReport>>(
      (viewModel) => viewModel.reports,
    );
    // A finished job and its saved report are the same thing; the report is
    // the one that survives, so the job row gives way once it exists.
    final live = jobs.where((job) => job.isRunning).toList();

    return ModalContainer(
      child: SizedBox(
        width: ThemeRepo.jobsPanelWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: ThemeRepo.spaceMedium,
          children: [
            Text(context.strings.jobsTitle).semiBold(),
            const _StartButton(),
            if (live.isNotEmpty) ...[
              const Divider(),
              for (final job in live) _RunningJob(job: job),
            ],
            if (reports.isEmpty && live.isEmpty)
              Text(context.strings.jobsEmptyBody).muted().xSmall()
            else if (reports.isNotEmpty) ...[
              const Divider(),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: ThemeRepo.jobsPanelMaxListHeight,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: ThemeRepo.spaceSmall,
                    children: [
                      for (final report in reports) _ReportRow(report: report),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Starts a scan over whatever the directory is filtered to.
class _StartButton extends StatelessWidget {
  const _StartButton();

  @override
  Widget build(BuildContext context) {
    final companies = context.select<BrowseViewModel, List<Company>>(
      (viewModel) => viewModel.results,
    );
    final running = context.select<JobsViewModel, bool>(
      (viewModel) => viewModel.hasRunning,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: ThemeRepo.spaceXSmall,
      children: [
        PrimaryButton(
          enabled: !running && companies.isNotEmpty,
          leading: const Icon(LucideIcons.play).iconXSmall(),
          onPressed: () => _start(context, companies),
          child: Text(context.strings.jobsStart(companies.length)),
        ),
        if (running)
          Text(context.strings.jobsRunningOne).muted().xSmall()
        else
          Text(context.strings.jobsEmptyBody).muted().xSmall(),
      ],
    );
  }

  void _start(BuildContext context, List<Company> companies) {
    context.read<JobsViewModel>().start(
      name: context.read<BrowseViewModel>().describeFilter(context.strings),
      companies: companies,
    );
    closeOverlay(context);
  }
}

class _RunningJob extends StatelessWidget {
  const _RunningJob({required this.job});

  final ValuationJob job;

  @override
  Widget build(BuildContext context) {
    final remaining = job.remaining;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: ThemeRepo.spaceXSmall,
      children: [
        Row(
          spacing: ThemeRepo.spaceSmall,
          children: [
            Expanded(child: Text(job.name).small().semiBold().singleLine()),
            GhostButton(
              density: ButtonDensity.compact,
              onPressed: () => context.read<JobsViewModel>().cancel(job.id),
              child: Text(context.strings.jobsCancel).xSmall(),
            ),
          ],
        ),
        Progress(progress: job.progress),
        Row(
          spacing: ThemeRepo.spaceSmall,
          children: [
            Expanded(
              child: Text(
                context.strings.jobsProgress(job.processed, job.total),
              ).muted().xSmall(),
            ),
            Text(context.strings.jobsFound(job.found)).muted().xSmall(),
            if (remaining != null)
              Text(
                context.strings.jobsRemaining(_formatRepo.duration(remaining)),
              ).muted().xSmall(),
          ],
        ),
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.report});

  final ValuationReport report;

  @override
  Widget build(BuildContext context) {
    return GhostButton(
      alignment: AlignmentDirectional.centerStart,
      onPressed: () {
        closeOverlay(context);
        Navigator.of(context)
            .pushNamed(AppRoute.report.path, arguments: report.id);
      },
      child: Row(
        spacing: ThemeRepo.spaceSmall,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: ThemeRepo.spaceXSmall,
              children: [
                Text(report.name).small().singleLine(),
                Text(
                  '${_formatRepo.timeOrDate(report.createdAt)} · '
                  '${context.strings.jobsDone(report.entries.length)}',
                ).muted().xSmall().singleLine(),
              ],
            ),
          ),
          ReportActions(report: report),
        ],
      ),
    );
  }
}
