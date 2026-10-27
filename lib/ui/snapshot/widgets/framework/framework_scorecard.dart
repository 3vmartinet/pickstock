import 'package:get_it/get_it.dart';
import 'package:pickstock/data/research/company_insight.dart';
import 'package:pickstock/data/research/framework_question.dart';
import 'package:pickstock/data/research/research_task.dart';
import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/snapshot/widgets/framework/framework_question_card.dart';
import 'package:pickstock/ui/watchlist/widgets/add_to_watchlist_button.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:pickstock/ui/widgets/just_fetched.dart';
import 'package:pickstock/ui/widgets/note_age.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// The framework's answer in one card: where the company stands, and all
/// seven verdicts in a row.
///
/// The framework's whole argument is that one No ends it, so the outcome is
/// the first thing on the tab and the row of steps under it shows *which*
/// question did it without reading a word. Each step jumps to its card.
class FrameworkScorecard extends StatelessWidget {
  const FrameworkScorecard({super.key, required this.onJump});

  /// Scrolls to a question's card.
  final ValueChanged<FrameworkQuestion> onJump;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SnapshotViewModel>();
    final strings = context.strings;
    final outcome = viewModel.frameworkOutcome;
    final run = viewModel.frameworkRun;
    final isFresh = viewModel.highlightedKind == frameworkNoteKind;

    final card = Card(
      padding: context.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: ThemeRepo.spaceLarge,
        children: [
          _Outcome(outcome: outcome),
          _Steps(onJump: onJump),
          if (run != null)
            _RunProgress(run: run)
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

/// Where the company stands, said as the framework would say it, with what
/// to do about it.
class _Outcome extends StatelessWidget {
  const _Outcome({required this.outcome});

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

    final summary = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: ThemeRepo.spaceMedium,
      children: [
        Container(
          padding: const EdgeInsets.all(ThemeRepo.spaceSmall),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: ThemeRepo.frameworkTint),
            borderRadius: theme.borderRadiusMd,
          ),
          child: Icon(icon, color: accent).iconMedium(),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: ThemeRepo.spaceXSmall,
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
              }).h4(color: accent),
              Text(detail).muted().small(),
            ],
          ),
        ),
      ],
    );

    final actions = _Actions(outcome: outcome);
    // Beside the outcome where there is room, under it where there is not:
    // the run button is the one thing on the tab before anything is answered.
    return context.isCompact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: ThemeRepo.spaceMedium,
            children: [summary, actions],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: ThemeRepo.spaceMedium,
            children: [
              Expanded(child: summary),
              actions,
            ],
          );
  }

  /// "Growth and Margins", "Growth, Moat and Margins": the questions that
  /// failed, by their short names.
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

/// Run, run again, or — for seven yeses — put it on a list.
class _Actions extends StatelessWidget {
  const _Actions({required this.outcome});

  final FrameworkOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SnapshotViewModel>();
    final strings = context.strings;
    final cik = viewModel.snapshot?.company.cik;
    final oldest = viewModel.frameworkOldestAnswerAt;
    if (cik == null) return const SizedBox.shrink();

    return Wrap(
      spacing: ThemeRepo.spaceSmall,
      runSpacing: ThemeRepo.spaceSmall,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // What the framework is for: seven yeses go on a watchlist. Offered
        // right here, so acting on the verdict is one press from reading it.
        if (outcome == FrameworkOutcome.watchlist)
          AddToWatchlistButton(cik: cik),
        if (viewModel.canResearch && !viewModel.isFrameworkBusy)
          if (outcome == FrameworkOutcome.notStarted)
            Tooltip(
              tooltip: HintTooltip(strings.frameworkRunHint).call,
              child: PrimaryButton(
                leading: const Icon(LucideIcons.sparkles).iconXSmall(),
                onPressed: () =>
                    context.read<SnapshotViewModel>().runFramework(),
                child: Text(strings.frameworkRun),
              ),
            )
          else ...[
            if (oldest != null)
              // The age of the stalest answer, and its refresh runs all seven:
              // the scorecard is only as current as the oldest thing on it.
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
      ],
    );
  }
}

/// The seven, as numbered steps joined by a rule.
class _Steps extends StatelessWidget {
  const _Steps({required this.onJump});

  final ValueChanged<FrameworkQuestion> onJump;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final question in FrameworkQuestion.values)
          Expanded(
            child: _Step(question: question, onJump: onJump),
          ),
      ],
    );
  }
}

/// One question on the scorecard: its number in a ring the colour of its
/// verdict, the verdict's word under it, and a press that goes to its card.
class _Step extends StatelessWidget {
  const _Step({required this.question, required this.onJump});

  final FrameworkQuestion question;
  final ValueChanged<FrameworkQuestion> onJump;

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
    final rule = Expanded(
      child: Container(height: 1, color: theme.colorScheme.border),
    );

    final marker = Container(
      width: ThemeRepo.frameworkStepSize,
      height: ThemeRepo.frameworkStepSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: verdict == null
            ? theme.colorScheme.background
            : accent.withValues(alpha: ThemeRepo.frameworkTint),
        border: Border.all(
          color: verdict == null ? theme.colorScheme.border : accent,
          width: ThemeRepo.frameworkStepRing,
        ),
      ),
      child: switch (state) {
        InsightState.loading => const CircularProgressIndicator(
          size: ThemeRepo.inlineSpinnerSize,
        ),
        _ when verdict != null => Icon(verdict.icon, color: accent).iconSmall(),
        _ => Text(
          question.number.toString(),
          style: TextStyle(
            fontWeight: ThemeRepo.frameworkStepWeight,
            color: accent,
          ),
        ).small(),
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
        child: Column(
          spacing: ThemeRepo.spaceXSmall,
          children: [
            Row(
              children: [
                if (isFirst) const Spacer() else rule,
                marker,
                if (isLast) const Spacer() else rule,
              ],
            ),
            // Shrunk rather than cut: seven labels across a phone-width pane
            // left "Management" reading "Manag".
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(question.getLabel(strings)).xSmall(),
            ),
            // The word under the marker repeats what its icon and colour say,
            // so it is the first thing to go where there is no room.
            if (!context.isCompact)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(verdict?.getLabel(strings) ?? '—')
                    .xSmall(color: accent)
                    .semiBold(),
              ),
          ],
        ),
      ),
    );
  }
}

/// How far through the run the queue has got, and which question it is on.
class _RunProgress extends StatelessWidget {
  const _RunProgress({required this.run});

  final ResearchTask run;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final total = run.frameworkQuestions.length;
    final current = run.currentFrameworkQuestion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: ThemeRepo.spaceSmall,
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
