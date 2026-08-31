import 'package:flutter_animate/flutter_animate.dart';
import 'package:pickstock/data/snapshot/ingest_stage.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/sec/bulk_ingest_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/ingest/widgets/ingest_progress_ring.dart';
import 'package:pickstock/ui/ingest/widgets/ingest_stage_list.dart';
import 'package:pickstock/ui/ingest/widgets/ingest_stats_row.dart';
import 'package:pickstock/ui/ingest_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

/// The full-screen setup step: explains what is needed, downloads it, and
/// reports progress. Nothing else is reachable while it is on screen.
class IngestScreen extends StatelessWidget {
  const IngestScreen({super.key, this.isChecking = false});

  /// While the database is being inspected there is nothing to decide yet, so
  /// only a spinner is shown rather than a button the user might press twice.
  final bool isChecking;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ThemeRepo.spaceXLarge),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ThemeRepo.ingestPanelMaxWidth,
            ),
            child: isChecking ? const _Checking() : const _Panel(),
          ),
        ),
      ),
    );
  }
}

class _Checking extends StatelessWidget {
  const _Checking();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: ThemeRepo.spaceMedium,
      children: [
        const CircularProgressIndicator(),
        Text(context.strings.gateChecking).muted().small(),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel();

  @override
  Widget build(BuildContext context) {
    final state = context.select<IngestViewModel, IngestState>(
      (viewModel) => viewModel.state,
    );

    return Card(
      padding: const EdgeInsets.all(ThemeRepo.spaceXLarge),
      child:
          Column(
                mainAxisSize: MainAxisSize.min,
                spacing: ThemeRepo.spaceLarge,
                children: switch (state) {
                  IngestActive(:final progress) => [
                    _Heading(stage: IngestStage.of(progress)),
                    _ActiveRing(progress: progress),
                    IngestStatsRow(progress: progress),
                    const Divider(),
                    IngestStageList(current: IngestStage.of(progress)),
                    Text(context.strings.ingestWarnLeave)
                        .muted()
                        .xSmall()
                        .textCenter(),
                  ],
                  IngestFailed() => const [_Invitation(hasFailed: true)],
                  _ => const [_Invitation(hasFailed: false)],
                },
              )
              .animate()
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

/// The title while a stage is running: the stage's own name, so the heading
/// changes as the job moves rather than sitting static for minutes.
class _Heading extends StatelessWidget {
  const _Heading({required this.stage});

  final IngestStage stage;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: ThemeRepo.spaceXSmall,
      children: [
        Text(context.strings.ingestPreparing).muted().xSmall().textCenter(),
        // Keyed so a stage change fades the new title in rather than swapping
        // the glyphs in place.
        KeyedSubtree(
          key: ValueKey(stage),
          child: Text(stage.getLabel(context.strings))
              .h3()
              .textCenter()
              .animate()
              .fadeIn(duration: ThemeRepo.entranceDuration),
        ),
      ],
    );
  }
}

class _ActiveRing extends StatelessWidget {
  const _ActiveRing({required this.progress});

  final IngestProgress progress;

  @override
  Widget build(BuildContext context) {
    // Both long stages know their size; fetching the directory does not, and
    // shows its icon instead of a percentage that would sit at zero.
    final fraction = switch (progress) {
      IngestDownloading(:final fraction) => fraction,
      IngestLoading(:final fraction) => fraction,
      IngestDone() => 1.0,
      IngestFetchingDirectory() => null,
      IngestFetchingSectors(:final quartersRead) =>
        quartersRead / sectorQuarters,
    };

    return IngestProgressRing(
      fraction: fraction,
      icon: IngestStage.of(progress).icon,
    );
  }
}

/// What is shown before the download starts, and after one fails.
class _Invitation extends StatelessWidget {
  const _Invitation({required this.hasFailed});

  final bool hasFailed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: ThemeRepo.spaceLarge,
      children: [
        _Glyph(isError: hasFailed),
        Column(
          spacing: ThemeRepo.spaceSmall,
          children: [
            Text(
              hasFailed
                  ? context.strings.gateFailedTitle
                  : context.strings.gateRequiredTitle,
            ).h3().textCenter(),
            Text(
              hasFailed
                  ? context.strings.gateFailedBody
                  : context.strings.gateRequiredBody,
            ).muted().textCenter(),
          ],
        ),
        const Divider(),
        // Listed before starting too, so the size and shape of the job is
        // clear before committing to a 1.4 GB download. No stage is marked
        // active: nothing is running yet.
        const IngestStageList(),
        PrimaryButton(
          onPressed: context.read<IngestViewModel>().start,
          leading: const Icon(LucideIcons.download),
          child: Text(
            hasFailed ? context.strings.gateRetry : context.strings.gateStart,
          ),
        ),
      ],
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.isError});

  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ThemeRepo.spaceMedium),
      decoration: BoxDecoration(
        color: isError
            ? context.theme.colorScheme.destructive.withValues(
                alpha: ThemeRepo.glyphTint,
              )
            : context.theme.colorScheme.muted,
        borderRadius: context.theme.borderRadiusLg,
      ),
      child: Icon(
        isError ? LucideIcons.triangleAlert : LucideIcons.databaseZap,
        color: isError ? context.theme.colorScheme.destructive : null,
      ).iconXLarge(),
    );
  }
}
