import 'package:pickstock/data/research/company_insight.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/research/ollama_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/widgets/edge_progress.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:pickstock/ui/widgets/just_fetched.dart';
import 'package:pickstock/ui/widgets/note_age.dart';
import 'package:pickstock/ui/widgets/source_link.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

/// One question the filings cannot settle, asked where it arises.
///
/// An [Alert] rather than a button somewhere: shadcn's alert is the component
/// for a note *about the thing beside it*, and that is exactly what each of
/// these is — the leading glyph and the title frame the question, the body
/// says why the report cannot answer it, and the action sits in the trailing
/// slot where an alert's action belongs. Answered, the same block holds the
/// answer, so the question and its answer are never in two places.
///
/// Never automatic. A minute of a local model is a minute the reader did not
/// ask for, and two of the three questions only matter to somebody already
/// suspicious of the figures.
class CompanyInsightCard extends StatelessWidget {
  const CompanyInsightCard({super.key, required this.insight});

  final CompanyInsight insight;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SnapshotViewModel>();
    // No key built in, no offer: a block that only ever explains why it cannot
    // work is worse than no block.
    if (!viewModel.canResearch) return const SizedBox.shrink();

    final state = viewModel.insightState(insight);
    // The one card an answer has just landed in, on a report of a dozen.
    final isFresh = viewModel.highlightedKind == insight.name;

    final alert = Alert(
      leading: Icon(insight.icon).iconSmall().iconMutedForeground(),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: ThemeRepo.spaceSmall,
        children: [
          Flexible(child: Text(insight.getTitle(context.strings))),
          if (isFresh) const JustFetchedBadge(),
        ],
      ),
      content: switch (state) {
        InsightState.idle ||
        InsightState.queued ||
        InsightState.loading => Text(
          insight.getInvitation(context.strings),
        ).muted().xSmall(),
        InsightState.failed => Text(
          viewModel.insightFailure(insight)?.describe(context.strings) ??
              context.strings.eventsFailedOther,
        ).muted().xSmall(),
        InsightState.ready => _Answer(
          answer: viewModel.insightAnswer(insight),
          cik: viewModel.snapshot?.company.cik ?? '',
        ),
      },
      // Once answered the offer gives way to the answer's age and the offer
      // to read it again: the block has become the answer, and a button that
      // still said "describe the business" would be offering work already
      // done.
      trailing: state == InsightState.ready
          ? _Age(insight: insight)
          : _Ask(insight: insight, state: state),
    );

    return isFresh ? JustFetched(child: alert) : alert;
  }
}

/// The press, sized to sit in an alert's trailing slot.
class _Ask extends StatelessWidget {
  const _Ask({required this.insight, required this.state});

  final CompanyInsight insight;
  final InsightState state;

  @override
  Widget build(BuildContext context) {
    final isLoading = state == InsightState.loading;
    // Waiting behind another question, which is where most of them start: the
    // model takes one at a time. Said plainly rather than shown as "Reading…"
    // — a button claiming work that has not begun is the reason a minute felt
    // like three.
    final isQueued = state == InsightState.queued;
    final isBusy = isLoading || isQueued;

    final button = Tooltip(
      tooltip: HintTooltip(switch (state) {
        InsightState.loading => context.strings.insightReadingHint,
        InsightState.queued => context.strings.researchQueuedHint,
        _ => insight.getInvitation(context.strings),
      }).call,
      child: OutlineButton(
        size: ButtonSize.small,
        enabled: !isBusy,
        onPressed: isBusy
            ? null
            : () => context.read<SnapshotViewModel>().loadInsight(insight),
        child: Text(switch (state) {
          InsightState.loading => context.strings.insightReading,
          InsightState.queued => context.strings.researchQueued,
          _ => insight.getAction(context.strings),
        }),
      ),
    );

    // Only the one actually being answered gets the bar; a queued question has
    // nothing under way to report.
    if (!isLoading) return button;
    return EdgeProgress(
      // Indeterminate: a model reading the web reports no fraction of
      // anything, and a bar pretending otherwise would be inventing one.
      fraction: null,
      colour: context.theme.colorScheme.primary,
      child: button,
    );
  }
}

/// How old the answer is, and the way to a fresh one.
class _Age extends StatelessWidget {
  const _Age({required this.insight});

  final CompanyInsight insight;

  @override
  Widget build(BuildContext context) {
    final generatedAt = context.select<SnapshotViewModel, DateTime?>(
      (viewModel) => viewModel.insightGeneratedAt(insight),
    );
    if (generatedAt == null) return const SizedBox.shrink();

    return NoteAge(
      generatedAt: generatedAt,
      onRefresh: () =>
          context.read<SnapshotViewModel>().loadInsight(insight, afresh: true),
    );
  }
}

/// What came back, and what it was read from.
class _Answer extends StatelessWidget {
  const _Answer({required this.answer, required this.cik});

  final ResearchAnswer? answer;
  final String cik;

  @override
  Widget build(BuildContext context) {
    final current = answer;
    if (current == null) return const SizedBox.shrink();

    // One page per line rather than a citation count: a claim a reader cannot
    // check is a claim they have to take on trust, and this app's whole
    // argument is that its own arithmetic is inspectable.
    final sources = {for (final source in current.sources) source.url: source};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: ThemeRepo.spaceSmall,
      children: [
        Text(current.text).small(),
        if (sources.isNotEmpty) ...[
          const Divider(),
          Text(context.strings.insightSources).muted().xSmall().semiBold(),
          for (final source in sources.values)
            SourceLink(
              label: source.title.isEmpty ? source.url : source.title,
              url: source.url,
              cik: cik,
            ),
        ],
        // Said every time, not once in a settings screen: the paragraph above
        // reads exactly like the app's own text and did not come from the
        // filings.
        //
        // Italic, because at the same weight as the links above it read as
        // one more of them — and it is a note about them, not another.
        Text(context.strings.insightCaveat).muted().xSmall().italic(),
      ],
    );
  }
}
