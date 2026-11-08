import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart'
    show BoxHitTestEntry, BoxHitTestResult, RenderProxyBox;

import 'package:get_it/get_it.dart';
import 'package:pickstock/data/report/valuation_job.dart';
import 'package:pickstock/data/report/valuation_report.dart';
import 'package:pickstock/data/research/research_task.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/research/ollama_repo.dart';
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
import 'package:pickstock/ui/settings/settings_view_model.dart';
import 'package:pickstock/ui/settings/widgets/search_setup_dialog.dart';

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
    final settings = context.read<SettingsViewModel>();

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
          ChangeNotifierProvider<SettingsViewModel>.value(value: settings),
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
    final unseen = context.select<ResearchQueue, int>(
      (queue) => queue.unseenCount,
    );

    // The controller notifies on opening and on closing, however the close
    // came about, so the press follows the panel rather than having to be kept
    // in step with it by hand.
    return ListenableBuilder(
      listenable: _menu,
      builder: (context, _) {
        final onPressed = _menu.hasOpenOverlay ? _menu.close : _open;
        final scheme = context.theme.colorScheme;
        // The spinner's own pair, set on it explicitly so the counts can wear
        // the same: its ring for their digits and marks, its track for their
        // fill. Quieter than a green and an orange of their own, and of a
        // piece with the spinner they sit against.
        // The counts take the SEC data stamp's pair, so the app bar's two
        // small labels read as one family; the spinner keeps its own.
        final ink = scheme.primary;
        final track = ink.withValues(
          alpha: ink.a * ThemeRepo.spinnerTrackShare,
        );

        final segments = [
          // Answers that have landed and not been opened — only once nothing
          // is running. While work is under way the pill is about that, and a
          // second figure beside it was one more thing to read for no gain:
          // the answers are in the list, and the count comes back the moment
          // the last of the work is done.
          if (unseen > 0 && outstanding == 0)
            _Segment(
              key: jobsUnseenBadgeKey,
              count: unseen,
              colour: scheme.muted,
              textColour: scheme.mutedForeground,
              isPending: false,
            ),
          // The count only once there is a queue worth calling one. One or
          // two things running is what the spinner already says, and a badge
          // reading "2" beside it would be a second way of saying the same
          // thing; a badge reading "7" says something the spinner cannot.
          if (outstanding > jobsBadgeThreshold)
            _Segment(
              key: jobsCountBadgeKey,
              count: outstanding,
              colour: scheme.muted,
              textColour: scheme.mutedForeground,
              isPending: true,
            ),
        ];

        return Tooltip(
          tooltip: HintTooltip(context.strings.jobsTooltip).call,
          // The counts inside the button, before its glyph: one control, so
          // its hover lights them and the glyph together and a press on
          // either is the same press, rather than a count sitting outside a
          // highlight that stopped short of it.
          child: GhostButton(
            density: ButtonDensity.icon,
            onPressed: onPressed,
            child: Builder(
              builder: (inside) {
                final box =
                    IconTheme.of(inside).size ??
                    ThemeRepo.jobsSpinnerFallbackSize;
                final ringDiameter = box * ThemeRepo.lucideDrawnShare;
                final glyph = outstanding > 0
                    // The spinner is the badge: that something is running at
                    // all is most of what the app bar has to say.
                    //
                    // As large as the glyph it stands in for, read from the
                    // button's own icon size: a Lucide glyph is drawn inside
                    // a margin of its box, so the ring is sized to the
                    // drawing, not to the box. In the glyph's own box, so the
                    // button keeps its size as work starts and stops.
                    ? SizedBox.square(
                        dimension: box,
                        child: Center(
                          child: SizedBox.square(
                            dimension: ringDiameter,
                            child: CircularProgressIndicator(
                              strokeWidth: ThemeRepo.jobsSpinnerStroke,
                              color: ink,
                              backgroundColor: track,
                            ),
                          ),
                        ),
                      )
                    : const Icon(LucideIcons.listChecks);
                if (segments.isEmpty) return glyph;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CountBadges(
                      segments: segments,
                      // Marked while anything is still under way: then
                      // "done" and "running" both mean something, and the
                      // marks say which count is which. With everything
                      // finished, the count left is plain.
                      isMarked: outstanding > 0,
                      // Its end hollowed to the spinner's curve while the
                      // spinner shows, and slid in against it: two pieces
                      // made to fit. The ring is centred in the glyph's box,
                      // which follows straight after.
                      ring: outstanding > 0
                          ? _Ring(
                              centreFromLeft: box / 2,
                              // The track is stroked on the box's own edge,
                              // so it reaches half a stroke beyond it.
                              radius:
                                  ringDiameter / 2 +
                                  ThemeRepo.jobsSpinnerStroke / 2,
                            )
                          : null,
                    ),
                    glyph,
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Past this the spinner has stopped being the whole story.
const int jobsBadgeThreshold = 2;

/// The counts before the jobs button's glyph, as one pill: how many answers
/// are waiting to be opened and how many things are outstanding, either or
/// both, with a solid line between the two.
///
/// Filled rather than outlined: an outlined count at this size reads as a
/// smudge beside the glyph. Rounded at its start, and at its end too unless
/// that end is hollowed to fit the spinner.
class _CountBadges extends StatelessWidget {
  const _CountBadges({
    required this.segments,
    required this.isMarked,
    required this.ring,
  });

  final List<_Segment> segments;

  /// Whether each count carries its mark: a check for done, running dots for
  /// under way.
  final bool isMarked;

  /// The spinner's ring after the counts, which their end follows, or `null`
  /// for a plain rounded end.
  final _Ring? ring;

  @override
  Widget build(BuildContext context) {
    const end = Radius.circular(ThemeRepo.countBadgeHeight / 2);
    final ring = this.ring;
    // The hollow: a circle round the ring's centre, a little wider than the
    // ring, so the end runs parallel to it at an even gap.
    final hollow = ring == null ? null : ring.radius + ThemeRepo.countRingGap;
    const half = ThemeRepo.countBadgeHeight / 2;
    // How far in from its corners the hollow's deepest point is.
    final sag = hollow == null
        ? 0.0
        : hollow - math.sqrt(hollow * hollow - half * half);
    final last = segments.length - 1;

    final pill = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, segment) in segments.indexed) ...[
          // A solid line between two counts, in their ink, so they read as
          // two figures rather than one run of digits and marks.
          if (index > 0)
            Container(
              width: ThemeRepo.countSeparatorWidth,
              height: ThemeRepo.countBadgeHeight,
              color: segment.colour,
              alignment: Alignment.center,
              child: Container(
                width: ThemeRepo.countSeparatorWidth,
                height:
                    ThemeRepo.countBadgeHeight -
                    2 * ThemeRepo.countSeparatorInset,
                color: segment.textColour,
              ),
            ),
          segment.build(
            BorderRadius.horizontal(
              left: index == 0 ? end : Radius.zero,
              right: index == last ? end : Radius.zero,
            ),
            // Roomier where two counts share the pill, so each half reads as
            // a count of its own.
            padding:
                (segments.length > 1
                    ? ThemeRepo.countPillPadding
                    : ThemeRepo.countBadgePadding) +
                // Room for the hollow, so the count stays centred in what is
                // left of its half.
                EdgeInsets.only(right: index == last ? sag : 0),
            isMarked: isMarked,
            hollow: index == last ? hollow : null,
          ),
        ],
      ],
    );

    if (ring == null || hollow == null) {
      // A plain gap before the glyph.
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: ThemeRepo.spaceXSmall),
        child: pill,
      );
    }
    // Slid in until the hollow's corners sit on the circle round the ring:
    // the count's end then lies an even gap from the spinner all along it.
    return _Overhang(
      by: ring.centreFromLeft - math.sqrt(hollow * hollow - half * half),
      child: pill,
    );
  }
}

/// One count in [_CountBadges].
class _Segment {
  const _Segment({
    required this.key,
    required this.count,
    required this.colour,
    required this.textColour,
    required this.isPending,
  });

  final Key key;
  final int count;
  final Color colour;
  final Color textColour;

  /// Whether the count is of work still under way, rather than done.
  final bool isPending;

  Widget build(
    BorderRadius radius, {
    required EdgeInsets padding,
    required bool isMarked,
    double? hollow,
  }) {
    final digits = Text(
      '$count',
      style: TextStyle(
        color: textColour,
        fontSize: ThemeRepo.countBadgeFontSize,
        fontWeight: FontWeight.w600,
        // Flat, so the digits sit on the badge's own centre line rather than
        // on a line height built for a paragraph.
        height: 1,
      ),
    );
    return Container(
      key: key,
      height: ThemeRepo.countBadgeHeight,
      padding: padding,
      alignment: Alignment.center,
      constraints: const BoxConstraints(minWidth: ThemeRepo.countBadgeMinWidth),
      decoration: hollow == null
          ? BoxDecoration(color: colour, borderRadius: radius)
          : ShapeDecoration(
              color: colour,
              shape: _HollowEndBorder(left: radius.topLeft.x, hollow: hollow),
            ),
      child: !isMarked
          ? digits
          : Row(
              mainAxisSize: MainAxisSize.min,
              spacing: ThemeRepo.countMarkGap,
              children: [
                // A check before what is done, dots running before what is
                // still under way.
                if (isPending)
                  _RunningDots(colour: textColour)
                else
                  Icon(
                    LucideIcons.check,
                    key: jobsDoneMarkKey,
                    size: ThemeRepo.countMarkSize,
                    color: textColour,
                  ),
                digits,
              ],
            ),
    );
  }
}

/// Three dots lighting one after another, for work under way: the
/// "still typing" of a count. Held still where the system asks for less
/// motion.
class _RunningDots extends StatefulWidget {
  const _RunningDots({required this.colour});

  final Color colour;

  @override
  State<_RunningDots> createState() => _RunningDotsState();
}

class _RunningDotsState extends State<_RunningDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: ThemeRepo.countDotsCycle,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _cycle.stop();
    } else if (!_cycle.isAnimating) {
      _cycle.repeat();
    }
  }

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const count = 3;
    return AnimatedBuilder(
      key: jobsRunningMarkKey,
      animation: _cycle,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        spacing: ThemeRepo.countDotGap,
        children: [
          for (var dot = 0; dot < count; dot++)
            // Lifted in turn and set back down, a wave running across the
            // three; a little brighter at the top of its rise.
            Transform.translate(
              offset: Offset(
                0,
                -ThemeRepo.countDotLift * _rise(_cycle.value, dot / count),
              ),
              child: Container(
                width: ThemeRepo.countDotSize,
                height: ThemeRepo.countDotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.colour.withValues(
                    alpha:
                        ThemeRepo.countDotDim +
                        (1 - ThemeRepo.countDotDim) *
                            _rise(_cycle.value, dot / count),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// How far up its rise a dot is at [time] through the cycle, from nought
  /// at rest to one at the top, peaking at its [offset]: a soft rise and fall
  /// over half the cycle, and at rest for the other half, so each dot has
  /// landed before the one after it is at its highest.
  static double _rise(double time, double offset) {
    final phase = (time - offset) % 1;
    return math.max(0, math.cos(phase * 2 * math.pi)).toDouble();
  }
}

/// Where the spinner's ring sits after the counts.
@immutable
class _Ring {
  const _Ring({required this.centreFromLeft, required this.radius});

  /// From the start of the glyph's box to the ring's centre.
  final double centreFromLeft;

  /// To the outside of the ring's stroke.
  final double radius;

  @override
  bool operator ==(Object other) =>
      other is _Ring &&
      (other.centreFromLeft - centreFromLeft).abs() < 0.5 &&
      (other.radius - radius).abs() < 0.5;

  @override
  int get hashCode => Object.hash(centreFromLeft.round(), radius.round());
}

/// A badge's outline with its right end hollowed into a circle's arc, and its
/// left end rounded by [left] — a full half circle for a badge of its own, or
/// square where it is the second half of a pill.
class _HollowEndBorder extends ShapeBorder {
  const _HollowEndBorder({required this.left, required this.hollow});

  final double left;

  /// The radius of the circle the right end is hollowed to.
  final double hollow;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final round = math.min(left, rect.height / 2);
    final path = Path()
      ..moveTo(rect.left + round, rect.top)
      ..lineTo(rect.right, rect.top)
      // Down the hollow, bowing in towards the badge: counter-clockwise, as
      // the left side of a circle centred out to the right is drawn.
      ..arcToPoint(
        Offset(rect.right, rect.bottom),
        radius: Radius.circular(hollow),
        clockwise: false,
      )
      ..lineTo(rect.left + round, rect.bottom);
    if (round > 0) {
      path.arcToPoint(
        Offset(rect.left + round, rect.top),
        radius: Radius.circular(round),
      );
    } else {
      path.lineTo(rect.left, rect.top);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) =>
      _HollowEndBorder(left: left * t, hollow: hollow * t);
}

/// Lays its child out at its own size but takes [by] less width in the row,
/// so the child's end reaches over whatever comes next.
class _Overhang extends SingleChildRenderObjectWidget {
  const _Overhang({required this.by, super.child});

  final double by;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderOverhang(by);

  @override
  void updateRenderObject(BuildContext context, _RenderOverhang renderObject) {
    renderObject.by = by;
  }
}

class _RenderOverhang extends RenderProxyBox {
  _RenderOverhang(this._by);

  double _by;
  set by(double value) {
    if (value == _by) return;
    _by = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child!;
    child.layout(constraints.loosen(), parentUsesSize: true);
    size = constraints.constrain(
      Size(math.max(0, child.size.width - _by), child.size.height),
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!child!.hitTest(result, position: position)) return false;
    result.add(BoxHitTestEntry(this, position));
    return true;
  }
}

/// The check before the count of answers done, in the pill.
const Key jobsDoneMarkKey = Key('jobsDoneMark');

/// The running dots before the count of work under way, in the pill.
const Key jobsRunningMarkKey = Key('jobsRunningMark');

/// The count of outstanding work on the job button's corner.
const Key jobsCountBadgeKey = Key('jobsCountBadge');

/// The count of answers not yet opened, on the job button's corner.
const Key jobsUnseenBadgeKey = Key('jobsUnseenBadge');

/// The dot on a finished question's row until its answer is opened.
Key researchUnseenDotKey(int id) => ValueKey('researchUnseen-$id');

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
            const _ReportingActions(),
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
            if (reports.isEmpty && live.isEmpty && asked.isEmpty)
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

/// The reporting actions available for whatever the directory is filtered to:
/// a valuation scan and a batch framework question evaluation.
class _ReportingActions extends StatelessWidget {
  const _ReportingActions();

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
      spacing: ThemeRepo.spaceSmall,
      children: [
        Column(
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
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: ThemeRepo.spaceXSmall,
          children: [
            OutlineButton(
              enabled: companies.isNotEmpty,
              leading: const Icon(LucideIcons.sparkles).iconXSmall(),
              onPressed: () => _startFramework(context, companies),
              child: Text(context.strings.jobsStartFramework(companies.length)),
            ),
            Text(context.strings.jobsFrameworkBody).muted().xSmall(),
          ],
        ),
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

  void _startFramework(BuildContext context, List<Company> companies) {
    final count = context.read<SnapshotViewModel>().runFrameworkBatch(
      companies,
    );
    if (count > 0 || companies.isNotEmpty) closeOverlay(context);
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
class _ResearchSection extends StatefulWidget {
  const _ResearchSection({required this.tasks});

  final List<ResearchTask> tasks;

  @override
  State<_ResearchSection> createState() => _ResearchSectionState();
}

class _ResearchSectionState extends State<_ResearchSection> {
  /// The row of the question being answered now.
  final GlobalKey _running = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Opened on the question being answered: with the newest first, it is
    // somewhere down a list of waiting and finished ones, and it is the one
    // the list was most likely opened to check on. Once, as the list opens,
    // so it does not pull the list back while it is being read.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = _running.currentContext;
      if (row == null || !row.mounted) return;
      unawaited(
        Scrollable.ensureVisible(
          row,
          alignment: ThemeRepo.jobsRunningRowAlignment,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: ThemeRepo.spaceSmall,
      children: [
        const Divider(),
        const _ResearchHeader(),
        // Once, for the section rather than on each row it would cure: a
        // spent allowance fails every question after it the same way.
        if (tasks.any((task) => SearchSetupLink.cures(task.failure)))
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SearchSetupLink(
              onPressed: () {
                // The guide is a dialog, and opens over the app, not over a
                // popover about to close under it.
                final host = Navigator.of(context, rootNavigator: true).context;
                closeOverlay(context);
                unawaited(showSearchSetup(host));
              },
            ),
          ),
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
                for (final task in tasks)
                  task.isRunning || task.isWaiting
                      ? KeyedSubtree(
                          key: _running,
                          child: _ResearchRow(task: task),
                        )
                      : _ResearchRow(task: task),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The section's title, with its two list-wide actions at the row's end.
class _ResearchHeader extends StatelessWidget {
  const _ResearchHeader();

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final queue = context.watch<ResearchQueue>();

    return Row(
      spacing: ThemeRepo.spaceXSmall,
      children: [
        Expanded(child: Text(strings.researchTitle).small().semiBold()),
        Tooltip(
          tooltip: HintTooltip(strings.researchMarkAllReadHint).call,
          child: GhostButton(
            key: researchMarkAllReadKey,
            density: ButtonDensity.icon,
            enabled: queue.unseenCount > 0,
            onPressed: queue.unseenCount > 0 ? queue.markAllSeen : null,
            child: const Icon(LucideIcons.checkCheck).iconXSmall(),
          ),
        ),
        Tooltip(
          tooltip: HintTooltip(strings.researchClearFinishedHint).call,
          child: GhostButton(
            key: researchClearFinishedKey,
            density: ButtonDensity.icon,
            enabled: queue.hasFinished,
            onPressed: queue.hasFinished ? queue.clearFinished : null,
            child: const Icon(LucideIcons.listX).iconXSmall(),
          ),
        ),
      ],
    );
  }
}

/// Marks every finished question in the panel as opened.
const Key researchMarkAllReadKey = Key('researchMarkAllRead');

/// Clears every finished or failed question off the panel.
const Key researchClearFinishedKey = Key('researchClearFinished');

/// One question: what was asked, where it has got to, and the one thing that
/// can be done about it.
///
/// Two bounded halves rather than a row with a button inside it. While the
/// model still owes an answer the label is inert and the cross calls the
/// question off; once it has answered the label is the way to it, and the
/// cross takes the row off the list. A dot at the row's end marks an answer
/// not opened yet.
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
              // At the end of the row, where an unread mark sits in a mail
              // list: the state glyph at the start says what happened, this
              // says whether the reader has been to look.
              // Not on a failure: the red cross at the start already says it,
              // and a dot beside it would read as a second error.
              trailing: task.isUnseen && !task.isFailed
                  ? Container(
                      key: researchUnseenDotKey(task.id),
                      width: ThemeRepo.updateBadgeSize,
                      height: ThemeRepo.updateBadgeSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // The green of the count it adds to on the button: an
                        // unread answer is news, not an error.
                        color: _themeRepo.positive(context.theme),
                      ),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: ThemeRepo.spaceXSmall,
                children: [
                  Text('${task.ticker} · ${_asked(task, strings)}')
                      .small()
                      .singleLine(),
                  if (task.isWaiting)
                    // Why it stopped, and that it will try again by itself:
                    // in the caution colour, as work held up rather than
                    // failed.
                    Text(_retrying(task, strings))
                        .xSmall(color: _themeRepo.caution(context.theme))
                        .singleLine()
                  else if (task.isFailed)
                    Text(
                          (task.failure ?? ResearchFailure.failed).describe(
                            strings,
                          ),
                        )
                        .xSmall(color: _themeRepo.negative(context.theme))
                        .singleLine()
                  else
                    Text(_status(task, strings)).muted().xSmall().singleLine(),
                ],
              ),
            ),
          ),
        ),
        Tooltip(
          tooltip: HintTooltip(
            task.isActive
                ? strings.researchCancelHint
                : strings.researchDismissHint,
          ).call,
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

  /// Goes to where the answer landed, and marks it as opened on the way out.
  ///
  /// Kept rather than removed, so the list is also the way back to an answer
  /// read a moment ago; the dot and the app bar's count are what set apart the
  /// answers not looked at yet. The cross is the way to clear a row.
  void _open(BuildContext context) {
    final snapshot = context.read<SnapshotViewModel>();
    final queue = context.read<ResearchQueue>();
    final navigator = Navigator.of(context);
    // Read before the overlay goes: closing it takes this context's ancestors
    // with it.
    final needsItsOwnScreen = !context.showsMasterDetail;

    closeOverlay(context);
    queue.markSeen(task.id);
    unawaited(
      snapshot.revealNote(ticker: task.ticker, tab: task.tab, kind: task.kind),
    );
    // Beside the list the report is already on screen; on a narrow window it
    // gets a screen of its own.
    if (needsItsOwnScreen) navigator.pushNamed(AppRoute.company.path);
  }

  /// What was asked, in the words the card asked it with.
  static String _asked(ResearchTask task, AppLocalizations strings) =>
      switch (task.frameworkQuestions) {
        [] => task.insight?.getAction(strings) ?? strings.researchNewsAction,
        [final only] => strings.researchFrameworkOneAction(
          only.getLabel(strings),
        ),
        _ => strings.researchFrameworkAction,
      };

  /// What a question waiting to be tried again is waiting out, and until
  /// when.
  static String _retrying(ResearchTask task, AppLocalizations strings) {
    final reason = (task.failure ?? ResearchFailure.failed).describe(strings);
    final at = task.retryAt;
    return at == null
        ? strings.researchRetryWhenModelAnswers(reason)
        : strings.researchRetryAt(reason, _formatRepo.timeOrDate(at));
  }

  static String _status(ResearchTask task, AppLocalizations strings) =>
      switch (task.state) {
        ResearchTaskState.pending => strings.researchStatusQueued,
        // A run of seven says how far through it is: several minutes of
        // "searching and reading" with nothing moving looks stuck.
        ResearchTaskState.running when task.frameworkQuestions.length > 1 =>
          strings.researchStatusStep(
            task.stepsDone + 1,
            task.frameworkQuestions.length,
          ),
        ResearchTaskState.running => strings.researchStatusRunning,
        // Shown with its reason instead; see the row.
        ResearchTaskState.waiting => '',
        ResearchTaskState.done when task.isSeen => strings.researchStatusOpened,
        ResearchTaskState.done => strings.researchStatusReady,
        // Shown in the failure's own words instead; see the row.
        ResearchTaskState.failed => '',
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
          child: CircularProgressIndicator(
            strokeWidth: ThemeRepo.inlineSpinnerStroke,
          ),
        ),
      ),
      // Held up, not failed: a retry glyph in the caution colour.
      ResearchTaskState.waiting => Icon(
        LucideIcons.rotateCw,
        color: _themeRepo.caution(theme),
      ).iconXSmall(),
      ResearchTaskState.done => Icon(
        LucideIcons.check,
        color: _themeRepo.forOutcome(theme, isGood: true),
      ).iconXSmall(),
      ResearchTaskState.failed => Icon(
        LucideIcons.x,
        color: _themeRepo.negative(theme),
      ).iconXSmall(),
    };
  }
}

/// The cross that drops one question from the line.
Key researchCancelKey(int id) => ValueKey('researchCancel-$id');
