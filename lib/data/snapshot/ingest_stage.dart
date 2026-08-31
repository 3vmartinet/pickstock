import 'package:pickstock/l10n/app_localizations.dart';
import 'package:pickstock/repo/sec/bulk_ingest_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The three stages of a bulk ingest, in the order they run.
///
/// Declared in order so a stage can tell whether it is behind, at, or ahead of
/// whichever one is running.
enum IngestStage {
  directory(icon: LucideIcons.listOrdered),
  sectors(icon: LucideIcons.tags),
  download(icon: LucideIcons.cloudDownload),
  load(icon: LucideIcons.database);

  const IngestStage({required this.icon});

  final IconData icon;

  /// Which stage a progress report belongs to.
  static IngestStage of(IngestProgress progress) => switch (progress) {
    IngestFetchingDirectory() => IngestStage.directory,
    IngestFetchingSectors() => IngestStage.sectors,
    IngestDownloading() => IngestStage.download,
    IngestLoading() || IngestDone() => IngestStage.load,
  };

  String getLabel(AppLocalizations strings) => switch (this) {
    IngestStage.directory => strings.stageDirectoryLabel,
    IngestStage.sectors => strings.stageSectorsLabel,
    IngestStage.download => strings.stageDownloadLabel,
    IngestStage.load => strings.stageLoadLabel,
  };

  String getDetail(AppLocalizations strings) => switch (this) {
    IngestStage.directory => strings.stageDirectoryDetail,
    IngestStage.sectors => strings.stageSectorsDetail,
    IngestStage.download => strings.stageDownloadDetail,
    IngestStage.load => strings.stageLoadDetail,
  };

  /// A `null` current stage means nothing is running yet, so no stage is
  /// either finished or active.
  bool isDoneWhen(IngestStage? current) =>
      current != null && index < current.index;

  bool isActiveWhen(IngestStage? current) => index == current?.index;
}
