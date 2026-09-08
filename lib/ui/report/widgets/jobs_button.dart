import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:pickstock/data/report/valuation_job.dart';
import 'package:pickstock/data/report/valuation_report.dart';
import 'package:pickstock/data/research/research_task.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/app_route.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/report/jobs_view_model.dart';
import 'package:pickstock/ui/report/research_queue.dart';
import 'package:pickstock/ui/report/widgets/report_actions.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();
ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();
ResearchQueue get _researchQueue => GetIt.I.get<ResearchQueue>();

/// The app bar's way into work that outlives the screen that started it:
/// scans over the directory, and questions put to the local model.
///
/// A popover rather than a screen, because a run is something you glance at
/// while doing something else — and a screen you have to leave to keep working
/// is a screen you stop checking.
class JobsButton extends StatefulWidget {
  const JobsButton({super.key});

  @override
  State<JobsButton> createState() => _JobsButtonState();
}

class _JobsButtonState extends State<JobsButton> {
  final OverlayController _menu = OverlayController();

  @override
  void dispose() {
    _menu.dispose();
    super.dispose();
  }

  /// Opens the panel, built by hand rather than through `showDropdown`.
  ///
  /// `showDropdown` passes `consumeOutsideTaps: false`, which means the press
  /// that dismisses the panel carries on to whatever is under it — and what is
  /// under it is this button, which opened it again. Pressing the button a
  /// second time looked like a panel that refused to close.
  void _open() {
    final theme = Theme.of(context);
    // The providers sit above the router and so above this overlay. Handed
    // down explicitly, the panel is buildable wherever the overlay lands.
    final jobs = context.read<JobsViewModel>();
    final browse = context.read<BrowseViewModel>();
    final snapshot = context.read<SnapshotViewModel>();

    _menu.show<void>(
      context,
      MenuConfiguration(
        alignment: Alignment.topRight,
        anchorAlignment: Alignment.bottomRight,
        offset: const Offset(0, ThemeRepo.spaceXSmall),
        consumeOutsideTaps: true,
        overlayBarrier: OverlayBarrier(
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
      ),
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider<JobsViewModel>.value(value: jobs),
          ChangeNotifierProvider<BrowseViewModel>.value(value: browse),
          ChangeNotifierProvider<SnapshotViewModel>.value(value: snapshot),
          ChangeNotifierProvider<ResearchQueue>.value(value: _researchQueue),
        ],
        child: const _JobsPanel(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final running = context.select<JobsViewModel, int>(
      (viewModel) => viewModel.runningCount,
    );
    final asked = context.select<ResearchQueue, int>(
      (queue) => queue.activeCount,
    );
    final outstanding = running + asked;

    // The controller notifies on opening and on closing, however the close
    // came about, so the press follows the panel rather than having to be kept
    // in step with it by hand.
    return ListenableBuilder(
      listenable: _menu,
      builder: (context, _) {
        final button = Tooltip(
          tooltip: HintTooltip(context.strings.jobsTooltip).call,
          child: GhostButton(
            density: ButtonDensity.icon,
            onPressed: _menu.hasOpenOverlay ? _menu.close : _open,
            child: outstanding > 0
                // The spinner is the badge: that something is running at all
                // is most of what the app bar has to say.
                ? const SizedBox.square(
                    dimension: ThemeRepo.inlineSpinnerSize,
                    child: CircularProgressIndicator(),
                  )
                : const Icon(LucideIcons.listChecks),
          ),
        );

        // The count only once there is a queue worth calling one. One or two
        // things running is what the spinner already says, and a badge reading
        // "2" beside it would be a second way of saying the same thing; a
        // badge reading "7" says something the spinner cannot.
        if (outstanding <= jobsBadgeThreshold) return button;
        return _CountBadge(count: outstanding, child: button);
      },
    );
  }
}

/// Past this the spinner has stopped being the whole story.
const int jobsBadgeThreshold = 2;

/// How many things are outstanding, on the corner of the button they are
/// outstanding on.
///
/// Filled in the accent colour rather than outlined: it sits on a ghost button
/// with nothing else around it, and an outlined count at this size reads as a
/// smudge on the glyph.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;

    return Stack(
      // The badge sits outside the button's bounds, so it must not be trimmed
      // back to them.
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: ThemeRepo.countBadgeOffset,
          right: ThemeRepo.countBadgeOffset,
          child: Container(
            key: jobsCountBadgeKey,
            height: ThemeRepo.countBadgeHeight,
            padding: ThemeRepo.countBadgePadding,
            alignment: Alignment.center,
            constraints: const BoxConstraints(
              minWidth: ThemeRepo.countBadgeMinWidth,
            ),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(
                ThemeRepo.countBadgeHeight / 2,
              ),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: scheme.primaryForeground,
                fontSize: ThemeRepo.countBadgeFontSize,
                fontWeight: FontWeight.w600,
                // Flat, so the digits sit on the badge's own centre line
                // rather than on a line height built for a paragraph.
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The count on the job button's corner.
const Key jobsCountBadgeKey = Key('jobsCountBadge');

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
    final asked = context.select<ResearchQueue, List<ResearchTask>>(
      (queue) => queue.tasks,
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
            // Above the reports and below the scan: a question already asked
            // is the thing most likely to be what the panel was opened for.
            //
            // Spread rather than a widget that shrinks to nothing, because the
            // column spaces its children and an empty one still takes a gap.
            if (asked.isNotEmpty) _ResearchSection(tasks: asked),
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
    final started = context.read<JobsViewModel>().start(
      name: context.read<BrowseViewModel>().describeFilter(context.strings),
      companies: companies,
    );
    // Only out of the way once something is actually under way. A panel that
    // closed on a refused start looked exactly like one that had worked.
    if (started) closeOverlay(context);
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

/// The line of questions put to the local model, and the way back to each
/// answer.
///
/// Here rather than on the report that asked, because by the time an answer
/// lands the reader is three companies away. A row that says which company
/// and which question, and takes you to it — which is the only useful thing a
/// finished background job can do.
class _ResearchSection extends StatelessWidget {
  const _ResearchSection({required this.tasks});

  final List<ResearchTask> tasks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: ThemeRepo.spaceSmall,
      children: [
        const Divider(),
        Text(context.strings.researchTitle).small().semiBold(),
        // Said once, under the heading, because it explains every row under
        // it: they are not slow, they are waiting.
        Text(context.strings.researchNote).muted().xSmall(),
        // Bounded like the reports below it: three questions a company adds
        // up quickly, and a panel taller than the window has nowhere to go.
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: ThemeRepo.jobsPanelMaxListHeight,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: ThemeRepo.spaceXSmall,
              children: [
                for (final task in tasks) _ResearchRow(task: task),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One question: what was asked, where it has got to, and the one thing that
/// can be done about it.
///
/// Two bounded halves rather than a row with a button inside it. While the
/// model still owes an answer the label is inert and only the cross is live;
/// once it has answered the label is the way to it and the cross is gone,
/// because there is nothing left to call off.
class _ResearchRow extends StatelessWidget {
  const _ResearchRow({required this.task});

  final ResearchTask task;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Row(
      spacing: ThemeRepo.spaceXSmall,
      children: [
        Expanded(
          child: Tooltip(
            tooltip: HintTooltip(
              task.isActive
                  ? strings.researchQueuedHint
                  : strings.researchOpenHint(task.companyName),
            ).call,
            child: GhostButton(
              alignment: AlignmentDirectional.centerStart,
              enabled: !task.isActive,
              onPressed: task.isActive ? null : () => _open(context),
              leading: _StateMark(task: task),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: ThemeRepo.spaceXSmall,
                children: [
                  Text(
                    '${task.ticker} · ${_asked(task, strings)}',
                  ).small().singleLine(),
                  Text(_status(task, strings)).muted().xSmall().singleLine(),
                ],
              ),
            ),
          ),
        ),
        if (task.isActive)
          Tooltip(
            tooltip: HintTooltip(strings.researchCancelHint).call,
            child: GhostButton(
              key: researchCancelKey(task.id),
              density: ButtonDensity.icon,
              onPressed: () => context.read<ResearchQueue>().remove(task.id),
              child: const Icon(LucideIcons.x).iconXSmall(),
            ),
          ),
      ],
    );
  }

  /// Goes to where the answer landed, and takes the row away on the way out.
  ///
  /// Removed rather than left ticked: the row exists to say something is owed,
  /// and once it has been collected it is owed no longer. A list that kept
  /// every answer ever fetched would be a list nobody reads.
  void _open(BuildContext context) {
    final snapshot = context.read<SnapshotViewModel>();
    final queue = context.read<ResearchQueue>();
    final navigator = Navigator.of(context);
    // Read before the overlay goes: closing it takes this context's ancestors
    // with it.
    final needsItsOwnScreen = !context.showsMasterDetail;

    closeOverlay(context);
    queue.remove(task.id);
    unawaited(
      snapshot.revealNote(
        ticker: task.ticker,
        tab: task.tab,
        kind: task.kind,
      ),
    );
    // Beside the list the report is already on screen; on a narrow window it
    // gets a screen of its own.
    if (needsItsOwnScreen) navigator.pushNamed(AppRoute.company.path);
  }

  /// What was asked, in the words the card asked it with.
  static String _asked(ResearchTask task, AppLocalizations strings) =>
      task.insight?.getAction(strings) ?? strings.researchNewsAction;

  static String _status(ResearchTask task, AppLocalizations strings) =>
      switch (task.state) {
        ResearchTaskState.pending => strings.researchStatusQueued,
        ResearchTaskState.running => strings.researchStatusRunning,
        ResearchTaskState.done => strings.researchStatusReady,
        ResearchTaskState.failed => strings.researchStatusFailed,
      };
}

/// Where the question has got to, as one glyph.
class _StateMark extends StatelessWidget {
  const _StateMark({required this.task});

  final ResearchTask task;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return switch (task.state) {
      // Waiting: a clock rather than a spinner, which would claim work that
      // has not started.
      ResearchTaskState.pending => const Icon(
        LucideIcons.clock,
      ).iconXSmall().iconMutedForeground(),
      // Centred, not merely sized: a button's leading slot hands its child
      // the row's full height, and a two-line row drew the spinner as an
      // ellipse.
      ResearchTaskState.running => const Center(
        child: SizedBox.square(
          dimension: ThemeRepo.inlineSpinnerSize,
          child: CircularProgressIndicator(),
        ),
      ),
      ResearchTaskState.done => Icon(
        LucideIcons.check,
        color: _themeRepo.forOutcome(theme, isGood: true),
      ).iconXSmall(),
      ResearchTaskState.failed => Icon(
        LucideIcons.triangleAlert,
        color: theme.colorScheme.destructive,
      ).iconXSmall(),
    };
  }
}

/// The cross that drops one question from the line.
Key researchCancelKey(int id) => ValueKey('researchCancel-$id');
