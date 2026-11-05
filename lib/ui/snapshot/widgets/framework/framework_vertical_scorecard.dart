import 'package:get_it/get_it.dart';
import 'package:pickstock/data/research/company_insight.dart';
import 'package:pickstock/data/research/framework_question.dart';
import 'package:pickstock/data/research/research_task.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/snapshot/widgets/framework/framework_layout_toggle.dart';
import 'package:pickstock/ui/snapshot/widgets/framework/framework_question_card.dart';
import 'package:pickstock/ui/watchlist/widgets/add_to_watchlist_button.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:pickstock/ui/widgets/just_fetched.dart';
import 'package:pickstock/ui/widgets/note_age.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// The seven questions scorecard laid out vertically on a dedicated side pane.
class FrameworkVerticalScorecard extends StatelessWidget {
  const FrameworkVerticalScorecard({
    super.key,
    required this.onJump,
    this.activeQuestion,
  });

  final ValueChanged<FrameworkQuestion> onJump;
  final FrameworkQuestion? activeQuestion;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SnapshotViewModel>();
    final strings = context.strings;
    final outcome = viewModel.frameworkOutcome;
    final run = viewModel.frameworkRun;
    final isFresh = viewModel.highlightedKind == frameworkNoteKind;

    final card = Card(
      padding: ThemeRepo.compactCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: ThemeRepo.spaceMedium,
        children: [
          _VerticalOutcome(outcome: outcome),
          const Divider(),
          _VerticalSteps(onJump: onJump, activeQuestion: activeQuestion),
          if (run != null)
            _VerticalRunProgress(run: run)
          else if (!viewModel.canResearch)
            Text(strings.frameworkUnavailable).muted().xSmall()
          else if (outcome == FrameworkOutcome.notStarted)
            Text(strings.frameworkIntro).muted().xSmall(),
        ],
      ),
    );

    return isFresh ? JustFetched(child: card) : card;
  }
}

class _VerticalOutcome extends StatelessWidget {
  const _VerticalOutcome({required this.outcome});

  final FrameworkOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SnapshotViewModel>();
    final strings = context.strings;
    final theme = context.theme;
    final accent = switch (outcome) {
      FrameworkOutcome.notStarted => _themeRepo.unknown(theme),
      FrameworkOutcome.incomplete => _themeRepo.caution(theme),
      FrameworkOutcome.moveOn => _themeRepo.negative(theme),
      FrameworkOutcome.watchlist => _themeRepo.positive(theme),
    };
    final icon = switch (outcome) {
      FrameworkOutcome.notStarted => LucideIcons.clipboardList,
      FrameworkOutcome.incomplete => LucideIcons.circleDashed,
      FrameworkOutcome.moveOn => LucideIcons.circleX,
      FrameworkOutcome.watchlist => LucideIcons.circleCheck,
    };
    final answered = FrameworkQuestion.values.where(
      (question) => viewModel.frameworkAnswer(question) != null,
    );
    final detail = switch (outcome) {
      FrameworkOutcome.notStarted => strings.frameworkOutcomeNotStartedDetail,
      FrameworkOutcome.incomplete => strings.frameworkOutcomeIncompleteDetail(
        viewModel.frameworkCount(FrameworkVerdict.yes),
        viewModel.frameworkCount(FrameworkVerdict.unclear),
        FrameworkQuestion.values.length - answered.length,
      ),
      FrameworkOutcome.moveOn => strings.frameworkOutcomeMoveOnDetail(
        _listed(strings, viewModel.frameworkNoes),
      ),
      FrameworkOutcome.watchlist => strings.frameworkOutcomeWatchlistDetail,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: ThemeRepo.spaceSmall,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(ThemeRepo.spaceSmall),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: ThemeRepo.frameworkTint),
                borderRadius: theme.borderRadiusMd,
              ),
              child: Icon(icon, color: accent).iconSmall(),
            ),
            const SizedBox(width: ThemeRepo.spaceSmall),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    spacing: ThemeRepo.spaceSmall,
                    children: [
                      Text(strings.frameworkTitle).muted().xSmall().semiBold(),
                      if (viewModel.highlightedKind == frameworkNoteKind)
                        const JustFetchedBadge(),
                    ],
                  ),
                  Text(switch (outcome) {
                    FrameworkOutcome.notStarted =>
                      strings.frameworkOutcomeNotStarted,
                    FrameworkOutcome.incomplete =>
                      strings.frameworkOutcomeIncomplete,
                    FrameworkOutcome.moveOn => strings.frameworkOutcomeMoveOn,
                    FrameworkOutcome.watchlist => strings.frameworkOutcomeWatchlist,
                  }).semiBold().small(color: accent),
                ],
              ),
            ),
            const FrameworkLayoutToggle(),
          ],
        ),
        Text(detail).muted().xSmall(),
        _VerticalActions(outcome: outcome),
      ],
    );
  }

  static String _listed(
    AppLocalizations strings,
    List<FrameworkQuestion> questions,
  ) {
    final names = [
      for (final question in questions) question.getLabel(strings),
    ];
    if (names.length < 2) return names.join();
    return '${names.sublist(0, names.length - 1).join(', ')} '
        '${strings.listAnd} ${names.last}';
  }
}

class _VerticalActions extends StatelessWidget {
  const _VerticalActions({required this.outcome});

  final FrameworkOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SnapshotViewModel>();
    final strings = context.strings;
    final cik = viewModel.snapshot?.company.cik;
    final oldest = viewModel.frameworkOldestAnswerAt;
    final isCollapsed = viewModel.isFrameworkVerticalCollapsed;
    if (cik == null) return const SizedBox.shrink();

    return Wrap(
      spacing: ThemeRepo.spaceSmall,
      runSpacing: ThemeRepo.spaceSmall,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (outcome == FrameworkOutcome.watchlist)
          AddToWatchlistButton(cik: cik),
        if (viewModel.canResearch && !viewModel.isFrameworkBusy)
          if (outcome == FrameworkOutcome.notStarted)
            Tooltip(
              tooltip: HintTooltip(strings.frameworkRunHint).call,
              child: PrimaryButton(
                size: ButtonSize.small,
                leading: const Icon(LucideIcons.sparkles).iconXSmall(),
                onPressed: () =>
                    context.read<SnapshotViewModel>().runFramework(),
                child: Text(strings.frameworkRun),
              ),
            )
          else ...[
            if (oldest != null)
              NoteAge(
                generatedAt: oldest,
                onRefresh: () =>
                    context.read<SnapshotViewModel>().runFramework(),
              ),
            Tooltip(
              tooltip: HintTooltip(strings.frameworkRunAgainHint).call,
              child: OutlineButton(
                size: ButtonSize.small,
                onPressed: () =>
                    context.read<SnapshotViewModel>().runFramework(),
                child: Text(strings.frameworkRunAgain),
              ),
            ),
          ],
        // Toggle between expanded (full list) and collapsed (focused answer only)
        ButtonGroup(
          children: [
            Tooltip(
              tooltip: HintTooltip(strings.frameworkVerticalExpandedHint).call,
              child: !isCollapsed
                  ? IconButton.secondary(
                      size: ButtonSize.small,
                      density: ButtonDensity.icon,
                      icon: const Icon(LucideIcons.rows3).iconSmall(),
                      onPressed: () {},
                    )
                  : IconButton.ghost(
                      size: ButtonSize.small,
                      density: ButtonDensity.icon,
                      icon: const Icon(LucideIcons.rows3).iconSmall(),
                      onPressed: () =>
                          viewModel.setFrameworkVerticalCollapsed(false),
                    ),
            ),
            Tooltip(
              tooltip: HintTooltip(strings.frameworkVerticalCollapsedHint).call,
              child: isCollapsed
                  ? IconButton.secondary(
                      size: ButtonSize.small,
                      density: ButtonDensity.icon,
                      icon: const Icon(LucideIcons.listCollapse).iconSmall(),
                      onPressed: () {},
                    )
                  : IconButton.ghost(
                      size: ButtonSize.small,
                      density: ButtonDensity.icon,
                      icon: const Icon(LucideIcons.listCollapse).iconSmall(),
                      onPressed: () =>
                          viewModel.setFrameworkVerticalCollapsed(true),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VerticalSteps extends StatelessWidget {
  const _VerticalSteps({required this.onJump, this.activeQuestion});

  final ValueChanged<FrameworkQuestion> onJump;
  final FrameworkQuestion? activeQuestion;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final question in FrameworkQuestion.values)
          _VerticalStep(
            question: question,
            onJump: onJump,
            isActive: question == activeQuestion,
          ),
      ],
    );
  }
}

class _VerticalStep extends StatelessWidget {
  const _VerticalStep({
    required this.question,
    required this.onJump,
    this.isActive = false,
  });

  final FrameworkQuestion question;
  final ValueChanged<FrameworkQuestion> onJump;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SnapshotViewModel>();
    final strings = context.strings;
    final theme = context.theme;
    final answer = viewModel.frameworkAnswer(question);
    final state = viewModel.frameworkState(question);
    final verdict = answer?.verdict;
    final accent = verdict == null
        ? theme.colorScheme.mutedForeground
        : verdictColour(theme, verdict);

    final isFirst = question.index == 0;
    final isLast = question.index == FrameworkQuestion.values.length - 1;

    final marker = Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: verdict == null
            ? theme.colorScheme.background
            : accent.withValues(alpha: ThemeRepo.frameworkTint),
        border: Border.all(
          color: isActive
              ? (verdict == null ? theme.colorScheme.primary : accent)
              : (verdict == null ? theme.colorScheme.border : accent),
          width: isActive
              ? ThemeRepo.frameworkStepRing + 1.5
              : ThemeRepo.frameworkStepRing,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: (verdict == null ? theme.colorScheme.primary : accent)
                      .withValues(alpha: 0.35),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: switch (state) {
        InsightState.loading => const CircularProgressIndicator(
          size: 10,
          strokeWidth: ThemeRepo.inlineSpinnerStroke,
        ),
        _ when verdict != null => Icon(verdict.icon, color: accent).iconXSmall(),
        _ => Text(
          question.number.toString(),
          style: TextStyle(
            fontWeight: ThemeRepo.frameworkStepWeight,
            color: accent,
            fontSize: 11,
          ),
        ),
      },
    );

    final hint = [
      strings.frameworkJumpHint(question.number, question.getTitle(strings)),
      answer?.headline ?? strings.frameworkNotAsked,
    ].join('\n');

    return Tooltip(
      tooltip: HintTooltip(hint).call,
      child: GhostButton(
        density: ButtonDensity.compact,
        onPressed: () => onJump(question),
        child: Container(
          decoration: isActive
              ? BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.7),
                  borderRadius: theme.borderRadiusMd,
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.25),
                  ),
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                height: 36,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!isFirst)
                      Positioned(
                        top: 0,
                        bottom: 18,
                        child: Container(
                          width: 1,
                          color: theme.colorScheme.border,
                        ),
                      ),
                    if (!isLast)
                      Positioned(
                        top: 18,
                        bottom: 0,
                        child: Container(
                          width: 1,
                          color: theme.colorScheme.border,
                        ),
                      ),
                    marker,
                  ],
                ),
              ),
              const SizedBox(width: ThemeRepo.spaceSmall),
              Expanded(
                child: Text(
                  '${question.number}. ${question.getLabel(strings)}',
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ).small(),
              ),
              if (verdict != null)
                Text(
                  verdict.getLabel(strings),
                ).xSmall(color: accent).semiBold()
              else
                Text('—').xSmall().muted(),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerticalRunProgress extends StatelessWidget {
  const _VerticalRunProgress({required this.run});

  final ResearchTask run;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final total = run.frameworkQuestions.length;
    final current = run.currentFrameworkQuestion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: ThemeRepo.spaceXSmall,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                current == null
                    ? strings.frameworkWaiting
                    : strings.frameworkAnswering(current.getTitle(strings)),
              ).small().singleLine(),
            ),
            Text(strings.frameworkProgress(run.stepsDone, total))
                .muted()
                .xSmall(),
          ],
        ),
        Progress(progress: run.stepsDone / total),
      ],
    );
  }
}
