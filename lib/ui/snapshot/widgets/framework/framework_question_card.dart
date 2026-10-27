import 'package:get_it/get_it.dart';
import 'package:pickstock/data/research/company_insight.dart';
import 'package:pickstock/data/research/framework_evidence.dart';
import 'package:pickstock/data/research/framework_question.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/research/web_search_repo.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/research/ollama_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/snapshot/widgets/framework/evidence_panel.dart';
import 'package:pickstock/ui/widgets/edge_progress.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:pickstock/ui/widgets/just_fetched.dart';
import 'package:pickstock/ui/widgets/note_age.dart';
import 'package:pickstock/ui/widgets/source_link.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();
FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();

/// The colour a verdict is shown in: the theme's good and bad, and caution
/// for a question the model could not settle — it is neither, and it still
/// keeps the company off a watchlist.
Color verdictColour(ThemeData theme, FrameworkVerdict verdict) =>
    switch (verdict) {
      FrameworkVerdict.yes => _themeRepo.positive(theme),
      FrameworkVerdict.no => _themeRepo.negative(theme),
      FrameworkVerdict.unclear => _themeRepo.caution(theme),
    };

/// One of the seven: the question, the verdict, why, and what it rests on.
///
/// Read top to bottom in the order a sceptic asks: what is the answer (the
/// pill and the headline, both in the first line a glance takes in), why (the
/// explanation), on what evidence (the points, each with where it was read),
/// and how does that square with the figures (the panel beside it, which is
/// the filings rather than the model and is there before the model is asked).
class FrameworkQuestionCard extends StatelessWidget {
  const FrameworkQuestionCard({super.key, required this.question});

  final FrameworkQuestion question;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SnapshotViewModel>();
    final snapshot = viewModel.snapshot;
    if (snapshot == null) return const SizedBox.shrink();

    final state = viewModel.frameworkState(question);
    final answer = viewModel.frameworkAnswer(question);
    final evidence = FrameworkEvidence.forQuestion(
      question,
      snapshot,
      valuation: viewModel.valuation,
    );
    // A single question asked again marks its own card; a full run marks the
    // scorecard instead, which says it once rather than seven times.
    final isFresh = viewModel.highlightedKind == question.noteKind;

    final body = LayoutBuilder(
      builder: (context, constraints) {
        final reading = _Reading(question: question, state: state);
        final panel = EvidencePanel(evidence: evidence);
        if (constraints.maxWidth < ThemeRepo.frameworkSideBySideMinWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: ThemeRepo.spaceMedium,
            children: [reading, panel],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: ThemeRepo.spaceLarge,
          children: [
            Expanded(flex: ThemeRepo.frameworkAnswerFlex, child: reading),
            Expanded(flex: ThemeRepo.frameworkEvidenceFlex, child: panel),
          ],
        );
      },
    );

    Widget card = Card(
      padding: context.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: ThemeRepo.spaceMedium,
        children: [
          _Heading(
            question: question,
            state: state,
            answer: answer,
            isFresh: isFresh,
          ),
          body,
        ],
      ),
    );

    // The bar along the card's foot while this is the question being read:
    // with seven cards on the tab, it is the one sign of which.
    if (state == InsightState.loading) {
      card = EdgeProgress(
        fraction: null,
        colour: context.theme.colorScheme.primary,
        child: card,
      );
    }
    return isFresh ? JustFetched(child: card) : card;
  }
}

/// The number, the question and the verdict, on one line.
class _Heading extends StatelessWidget {
  const _Heading({
    required this.question,
    required this.state,
    required this.answer,
    required this.isFresh,
  });

  final FrameworkQuestion question;
  final InsightState state;
  final FrameworkAnswer? answer;

  /// Whether this one question has just been answered again.
  final bool isFresh;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = context.theme;
    final verdict = answer?.verdict;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: ThemeRepo.spaceMedium,
      children: [
        Text(
          question.number.toString().padLeft(2, '0'),
          style: TextStyle(
            fontSize: ThemeRepo.frameworkNumberSize,
            fontWeight: ThemeRepo.frameworkStepWeight,
            height: ThemeRepo.headlineFigureHeight,
            color: verdict == null
                ? theme.colorScheme.mutedForeground
                : verdictColour(theme, verdict),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: ThemeRepo.spaceXSmall,
            children: [
              Row(
                spacing: ThemeRepo.spaceXSmall,
                children: [
                  Icon(question.icon).iconXSmall().iconMutedForeground(),
                  Text(question.getLabel(strings)).muted().xSmall(),
                ],
              ),
              Row(
                spacing: ThemeRepo.spaceSmall,
                children: [
                  Flexible(
                    child: Text(question.getTitle(strings)).large().semiBold(),
                  ),
                  if (isFresh) const JustFetchedBadge(),
                ],
              ),
            ],
          ),
        ),
        switch (state) {
          InsightState.queued => _StatePill(
            icon: LucideIcons.clock,
            label: strings.researchQueued,
            hint: strings.frameworkWaiting,
          ),
          InsightState.loading => _StatePill(
            icon: LucideIcons.loaderCircle,
            label: strings.insightReading,
            hint: strings.insightReadingHint,
          ),
          _ when verdict != null => VerdictPill(verdict: verdict),
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }
}

/// The verdict as a status: its colour, its icon and its word, so it never
/// rests on colour alone.
class VerdictPill extends StatelessWidget {
  const VerdictPill({super.key, required this.verdict});

  final FrameworkVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final accent = verdictColour(context.theme, verdict);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ThemeRepo.spaceSmall + ThemeRepo.spaceXSmall,
        vertical: ThemeRepo.spaceXSmall,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: ThemeRepo.frameworkTint),
        borderRadius: BorderRadius.circular(ThemeRepo.frameworkStepSize),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: ThemeRepo.spaceXSmall,
        children: [
          Icon(verdict.icon, color: accent).iconSmall(),
          Text(verdict.getLabel(context.strings))
              .small()
              .semiBold(color: accent),
        ],
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({
    required this.icon,
    required this.label,
    required this.hint,
  });

  final IconData icon;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      tooltip: HintTooltip(hint).call,
      child: OutlineBadge(leading: Icon(icon).iconXSmall(), child: Text(label)),
    );
  }
}

/// The model's side of the card: its answer, or what it will look for.
class _Reading extends StatelessWidget {
  const _Reading({required this.question, required this.state});

  final FrameworkQuestion question;
  final InsightState state;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SnapshotViewModel>();
    final strings = context.strings;
    final answer = viewModel.frameworkAnswer(question);
    final failure = viewModel.frameworkFailure(question);
    final cik = viewModel.snapshot?.company.cik ?? '';
    final isBusy =
        state == InsightState.queued || state == InsightState.loading;

    final until = viewModel.searchAvailableAt;
    final reason = switch (failure) {
      // The wait the service gave, where it gave one: two hours is not "a few
      // minutes", and a reader told the latter tries again and fails again.
      ResearchFailure.searchRefused when until != null =>
        strings.researchFailedSearchRefusedUntil(_formatRepo.timeOrDate(until)),
      _ => failure?.describe(strings),
    };
    final failureLine = state == InsightState.failed && reason != null
        ? Text(strings.frameworkFailed(reason))
              .xSmall(color: _themeRepo.negative(context.theme))
        : null;

    if (answer == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: ThemeRepo.spaceSmall,
        children: [
          Text(strings.frameworkLookFor).muted().xSmall().semiBold(),
          Text(question.getLookFor(strings)).muted().small(),
          ?failureLine,
          if (viewModel.canResearch && !isBusy)
            Tooltip(
              tooltip: HintTooltip(strings.frameworkAskOneHint).call,
              child: OutlineButton(
                size: ButtonSize.small,
                leading: const Icon(LucideIcons.sparkles).iconXSmall(),
                onPressed: () => context.read<SnapshotViewModel>().runFramework(
                  only: question,
                ),
                child: Text(strings.frameworkAskOne),
              ),
            ),
        ],
      );
    }

    final sources = {
      for (final source in viewModel.frameworkSources(question))
        source.url: source,
    };
    final generatedAt = viewModel.frameworkGeneratedAt(question);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: ThemeRepo.spaceSmall,
      children: [
        // The answer, in the largest type on the card after the question: it
        // is what the card exists to say.
        Text(answer.headline).large().semiBold(),
        if (answer.explanation.isNotEmpty) Text(answer.explanation).small(),
        if (answer.points.isNotEmpty) ...[
          const SizedBox(height: ThemeRepo.spaceXSmall),
          Text(strings.frameworkEvidence).muted().xSmall().semiBold(),
          for (final point in answer.points)
            _PointRow(point: point, question: question, cik: cik),
        ],
        ?failureLine,
        if (sources.isNotEmpty) _Sources(sources: sources.values, cik: cik),
        if (generatedAt != null && viewModel.canResearch && !isBusy)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: NoteAge(
              generatedAt: generatedAt,
              onRefresh: () => context.read<SnapshotViewModel>().runFramework(
                only: question,
              ),
            ),
          ),
      ],
    );
  }
}

/// One piece of evidence, with where it was read.
///
/// The risk question's points are the three things that could kill the
/// investment, so they are numbered and marked as warnings rather than
/// bulleted — the framework asks for three, and a reader should be able to
/// count them.
class _PointRow extends StatelessWidget {
  const _PointRow({
    required this.point,
    required this.question,
    required this.cik,
  });

  final FrameworkPoint point;
  final FrameworkQuestion question;
  final String cik;

  @override
  Widget build(BuildContext context) {
    final url = point.url;
    final isRisk = question == FrameworkQuestion.risk;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: ThemeRepo.spaceSmall,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            isRisk ? LucideIcons.triangleAlert : LucideIcons.chevronRight,
          ).iconXSmall().iconMutedForeground(),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: ThemeRepo.spaceXSmall,
            children: [
              Text(point.text).small(),
              if (url != null)
                SourceLink(label: _host(url), url: url, cik: cik)
              else if (point.isFromFilings)
                _OriginMark(
                  icon: LucideIcons.fileText,
                  label: context.strings.frameworkFilingsMark,
                  hint: context.strings.frameworkFilingsMarkHint,
                )
              else
                // Neither a page nor a figure on file: the model's own
                // reading, which is worth having and worth knowing it is.
                _OriginMark(
                  icon: LucideIcons.messageCircleQuestion,
                  label: context.strings.frameworkUnsourcedMark,
                  hint: context.strings.frameworkUnsourcedMarkHint,
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// The site a point was read on, which says more at a glance than a path.
  static String _host(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    if (host.isEmpty) return url;
    return host.startsWith('www.') ? host.substring(4) : host;
  }
}

/// Where a point without a page came from, as a small outlined tag.
class _OriginMark extends StatelessWidget {
  const _OriginMark({
    required this.icon,
    required this.label,
    required this.hint,
  });

  final IconData icon;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      tooltip: HintTooltip(hint).call,
      child: OutlineBadge(leading: Icon(icon).iconXSmall(), child: Text(label)),
    );
  }
}

/// Every page read for the answer, folded away: the points above cite the
/// ones that mattered, and five more links under every card is a wall.
class _Sources extends StatelessWidget {
  const _Sources({required this.sources, required this.cik});

  final Iterable<SearchResult> sources;
  final String cik;

  @override
  Widget build(BuildContext context) {
    return Collapsible(
      children: [
        CollapsibleTrigger(
          child: Text('${context.strings.insightSources} (${sources.length})')
              .muted()
              .xSmall()
              .semiBold(),
        ),
        CollapsibleContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: ThemeRepo.spaceXSmall,
            children: [
              for (final source in sources)
                SourceLink(
                  label: source.title.isEmpty ? source.url : source.title,
                  url: source.url,
                  cik: cik,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
