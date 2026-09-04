import 'package:get_it/get_it.dart';
import 'package:pickstock/data/research/company_event.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/widgets/edge_progress.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:pickstock/ui/widgets/note_age.dart';
import 'package:pickstock/ui/widgets/section_header.dart';
import 'package:pickstock/ui/widgets/source_link.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();

/// The press that sends the local model off to read about the company.
///
/// Under the lists rather than beside the name: it belongs with the other two
/// things you can do to a company, and a labelled button in the middle of the
/// title row left neither the name nor the captions enough width.
///
/// Reports itself the way the archive download does — a bar along its own
/// bottom edge — because the wait is the same order of magnitude and a header
/// that grew a progress row would push the report down while it worked.
class CompanyEventsButton extends StatelessWidget {
  const CompanyEventsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SnapshotViewModel>();
    // No key built in, no offer: a button that only ever explains why it
    // cannot work is worse than no button.
    if (!viewModel.canResearchEvents) return const SizedBox.shrink();

    final state = viewModel.eventsState;
    final isLoading = state == EventsState.loading;
    // Once read, it is done: the answer is on screen and asking the same
    // question of the same company again would spend another minute to say
    // the same thing. Opening the company afresh is what starts over.
    final hasRun = state != EventsState.idle && !isLoading;

    final button = Tooltip(
      tooltip: HintTooltip(switch (state) {
        EventsState.loading => context.strings.eventsLoadingHint,
        EventsState.idle => context.strings.eventsFetchHint,
        _ => context.strings.eventsDoneHint,
      }).call,
      child: OutlineButton(
        // The same weight and density as the list button above it, so the two
        // read as a pair rather than as a control that wandered in.
        density: context.isCompact ? ButtonDensity.icon : ButtonDensity.normal,
        enabled: !isLoading && !hasRun,
        onPressed: isLoading || hasRun ? null : viewModel.loadEvents,
        leading: const Icon(LucideIcons.newspaper).iconSmall(),
        child: context.isCompact
            ? const SizedBox.shrink()
            : Text(
                isLoading
                    ? context.strings.eventsLoading
                    : context.strings.eventsFetch,
              ),
      ),
    );

    if (!isLoading) return button;
    return EdgeProgress(
      // Indeterminate: a model reading the web reports no fraction of
      // anything, and a bar pretending otherwise would be inventing one.
      fraction: null,
      // On an outlined button, so the accent colour rather than a fill's own
      // foreground.
      colour: context.theme.colorScheme.primary,
      child: button,
    );
  }
}

/// What the model found, in a block of its own under the company.
///
/// A bordered panel rather than lines loose in the header: they come from the
/// web and not from the filings, and the reader is entitled to see at a glance
/// where the app's own figures stop and somebody else's reporting starts.
///
/// In the middle of the header's row, between the company and the controls
/// that follow it. The row is the narrower of the two places it could go, so a
/// caption is often cut short — the tooltip carries it whole, and the line
/// opens the page it came from.
class CompanyEvents extends StatelessWidget {
  const CompanyEvents({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SnapshotViewModel>();
    if (!viewModel.hasEventsToShow) return const SizedBox.shrink();

    return Container(
      key: eventsPanelKey,
      padding: ThemeRepo.eventsPanelPadding,
      decoration: BoxDecoration(
        // Faint fill inside a border, which is how the rest of shadcn insets
        // a block within a card: enough to separate it, not enough to compete
        // with the figures underneath.
        color: context.theme.colorScheme.muted.withValues(
          alpha: ThemeRepo.eventsPanelTint,
        ),
        border: Border.all(color: context.theme.colorScheme.border),
        borderRadius: context.theme.borderRadiusMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: ThemeRepo.spaceSmall,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionHeader(
                  icon: LucideIcons.newspaper,
                  title: context.strings.eventsTitle,
                ),
              ),
            ],
          ),
          switch (viewModel.eventsState) {
            EventsState.empty => Text(
              context.strings.eventsEmpty,
            ).muted().xSmall(),
            EventsState.failed => Text(
              viewModel.eventsFailure?.describe(context.strings) ??
                  context.strings.eventsFailedOther,
            ).muted().xSmall(),
            _ => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: ThemeRepo.spaceXSmall,
              children: [
                for (final event in viewModel.events)
                  SourceLink(
                    label: _lineFor(event),
                    url: event.url,
                    cik: viewModel.snapshot?.company.cik ?? '',
                  ),
              ],
            ),
          },
          // Under the lines rather than beside the title: squeezed into the
          // company header's row there is not width for both, and the title
          // is the half that has to stay readable.
          if (viewModel.eventsGeneratedAt case final generatedAt?)
            Align(
              alignment: Alignment.centerRight,
              child: NoteAge(
                generatedAt: generatedAt,
                onRefresh: () =>
                    context.read<SnapshotViewModel>().loadEvents(afresh: true),
              ),
            ),
        ],
      ),
    );
  }
}

/// The date and the caption on one line, or the caption alone where the page
/// did not say when it happened.
String _lineFor(CompanyEvent event) {
  final date = event.date;
  return date == null
      ? event.caption
      : '${_formatRepo.shortDate(date)} · ${event.caption}';
}

/// The panel the developments sit in.
const Key eventsPanelKey = Key('eventsPanel');
