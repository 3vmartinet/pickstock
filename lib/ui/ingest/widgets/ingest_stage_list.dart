import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/ingest_stage.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// How faint a stage that has not started yet appears.
const double _pendingOpacity = 0.45;

/// Tint behind a completed or running stage's marker.
const double _markerTint = 0.14;

/// The three stages, with the finished ones ticked and the running one lit.
///
/// A single bar says how far along one stage is; this says where that stage
/// sits in the whole job, which is what makes a long wait feel bounded.
class IngestStageList extends StatelessWidget {
  const IngestStageList({super.key, this.current});

  /// The stage running now, or `null` before the job has started — where a
  /// pulsing marker would claim work that is not happening.
  final IngestStage? current;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: ThemeRepo.spaceMedium,
      children: [
        for (final stage in IngestStage.values)
          _StageRow(stage: stage, current: current),
      ],
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.stage, required this.current});

  final IngestStage stage;
  final IngestStage? current;

  @override
  Widget build(BuildContext context) {
    final isDone = stage.isDoneWhen(current);
    final isActive = stage.isActiveWhen(current);

    final row = Row(
      spacing: ThemeRepo.spaceMedium,
      children: [
        _StageMarker(stage: stage, isDone: isDone, isActive: isActive),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stage.getLabel(context.strings)).small().semiBold(),
              Text(stage.getDetail(context.strings)).muted().xSmall(),
            ],
          ),
        ),
      ],
    );

    if (isActive) return row;
    return Opacity(opacity: isDone ? 1 : _pendingOpacity, child: row);
  }
}

class _StageMarker extends StatelessWidget {
  const _StageMarker({
    required this.stage,
    required this.isDone,
    required this.isActive,
  });

  final IngestStage stage;
  final bool isDone;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final accent = isDone
        ? _themeRepo.positive(context.theme)
        : context.theme.colorScheme.foreground;

    final marker = Container(
      width: ThemeRepo.stageMarkerSize,
      height: ThemeRepo.stageMarkerSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone || isActive
            ? accent.withValues(alpha: _markerTint)
            : context.theme.colorScheme.muted,
      ),
      child: Icon(
        isDone ? LucideIcons.check : stage.icon,
        color: isDone || isActive ? accent : null,
      ).iconXSmall(),
    );

    // Only the running stage breathes, so the eye goes straight to it.
    if (!isActive) return marker;
    return marker
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scaleXY(
          begin: 1,
          end: ThemeRepo.stagePulseScale,
          duration: ThemeRepo.stagePulseDuration,
          curve: Curves.easeInOut,
        );
  }
}
