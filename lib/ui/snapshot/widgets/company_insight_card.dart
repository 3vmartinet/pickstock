import 'package:get_it/get_it.dart';
import 'package:pickstock/ui/widgets/model_caveat.dart';
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
import 'package:pickstock/ui/widgets/column_text.dart';
import 'package:pickstock/ui/widgets/column_text_placeholder.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:pickstock/ui/settings/widgets/search_setup_dialog.dart';

ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// One question the filings cannot settle, asked where it arises.
///
/// An [Alert] rather than a button somewhere: shadcn's alert is the component
/// for a note *about the thing beside it*, and that is exactly what each of
/// these is — the glyph and the title frame the question, the body says why
/// the report cannot answer it, and the action sits at the end of the title's
/// line. Answered, the same block holds the answer, so the question and its
/// answer are never in two places.
///
/// Everything but the body on the one top line: the alert's own leading and
/// trailing slots each run the full height of the block, and beside a page of
/// answer that left two empty columns down either side of it.
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
      title: Row(
        spacing: ThemeRepo.spaceSmall,
        children: [
          Icon(insight.icon).iconSmall().iconMutedForeground(),
          // The title takes the free width, which pushes the age or the
          // offer to the far end of the line.
          Expanded(
            child: Row(
              spacing: ThemeRepo.spaceSmall,
              children: [
                Flexible(child: Text(insight.getTitle(context.strings))),
                if (isFresh) const JustFetchedBadge(),
              ],
            ),
          ),
          // Once answered the offer gives way to the answer's age and the
          // offer to read it again: the block has become the answer, and a
          // button that still said "describe the business" would be offering
          // work already done.
          if (state == InsightState.ready)
            _Age(insight: insight)
          else
            _Ask(insight: insight, state: state),
        ],
      ),
      content: switch (state) {
        // The article being written, in the shape it will take: the columns
        // stand where the prose will land, so nothing jumps when it does.
        // Only while the model is at it — a queued question has nothing
        // under way to show.
        InsightState.loading when insight == CompanyInsight.business =>
          const ColumnTextPlaceholder(
            key: insightPlaceholderKey,
            isSerif: true,
          ),
        InsightState.idle || InsightState.queued || InsightState.loading =>
          Text(insight.getInvitation(context.strings)).muted().xSmall(),
        InsightState.failed => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              viewModel.insightFailure(insight)?.describe(context.strings) ??
                  context.strings.eventsFailedOther,
            ).xSmall(color: _themeRepo.negative(context.theme)),
            if (SearchSetupLink.cures(viewModel.insightFailure(insight)))
              const SearchSetupLink(),
          ],
        ),
        InsightState.ready => _Answer(
          answer: viewModel.insightAnswer(insight),
          // The business described reads as an article about the company,
          // and is set as one; the tabs' insights are notes on figures.
          isArticle: insight == CompanyInsight.business,
          cik: viewModel.snapshot?.company.cik ?? '',
        ),
      },
    );

    return isFresh ? JustFetched(child: alert) : alert;
  }
}

/// The placeholder standing in for the business described while it is read.
const Key insightPlaceholderKey = ValueKey('insightPlaceholder');

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
  const _Answer({
    required this.answer,
    required this.cik,
    this.isArticle = false,
  });

  /// Whether the prose is set in the serif, as an article.
  final bool isArticle;

  final ResearchAnswer? answer;
  final String cik;

  @override
  Widget build(BuildContext context) {
    final current = answer;
    if (current == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: ThemeRepo.spaceSmall,
      children: [
        ColumnText(current.text, isSerif: isArticle),
        // Straight under the text it is about, before the sources, so it is
        // read as a note on the answer rather than on the links.
        const ModelCaveat(),
        // Each page listed rather than a citation count: a claim a reader
        // cannot check is a claim they have to take on trust, and this app's
        // whole argument is that its own arithmetic is inspectable.
        if (current.sources.isNotEmpty) ...[
          const Divider(),
          SourcesList(sources: current.sources, cik: cik),
        ],
      ],
    );
  }
}
