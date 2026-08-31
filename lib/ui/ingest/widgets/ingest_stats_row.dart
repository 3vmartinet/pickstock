import 'package:get_it/get_it.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/sec/bulk_ingest_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/ingest_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();

/// Below a minute, seconds alone read better than `0m 42s`.
const int _secondsPerMinute = 60;

/// What the current stage has got through, how fast, and how much longer.
///
/// The three read together: without the rate a long wait looks stalled, and
/// without the estimate there is no way to judge whether to keep waiting.
class IngestStatsRow extends StatelessWidget {
  const IngestStatsRow({super.key, required this.progress});

  final IngestProgress progress;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<IngestViewModel>();
    final parts = [
      ?_amount(context),
      ?_rate(context, viewModel.ratePerSecond),
      ?_remaining(context, viewModel.estimatedRemaining),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: ThemeRepo.spaceSmall,
      runSpacing: ThemeRepo.spaceXSmall,
      children: [for (final part in parts) Text(part).muted().xSmall().mono()],
    );
  }

  /// How much of this stage is done, in whatever unit the stage counts in.
  String? _amount(BuildContext context) => switch (progress) {
    IngestDownloading(:final receivedBytes, :final totalBytes) =>
      totalBytes == null
          ? _formatRepo.bytes(receivedBytes)
          : context.strings.ingestBytesOfTotal(
              _formatRepo.bytes(receivedBytes),
              _formatRepo.bytes(totalBytes),
            ),
    IngestLoading(:final companiesLoaded, :final totalCompanies) =>
      context.strings.ingestCompaniesOfTotal(companiesLoaded, totalCompanies),
    IngestFetchingSectors(:final quartersRead) =>
      context.strings.ingestDataSets(quartersRead, sectorQuarters),
    _ => null,
  };

  /// Bytes per second while downloading; companies per second while loading.
  String? _rate(BuildContext context, double? rate) {
    if (rate == null) return null;
    return switch (progress) {
      IngestDownloading() => context.strings.ingestRate(
        _formatRepo.bytes(rate),
      ),
      IngestLoading() => context.strings.ingestRateCompanies(rate.round()),
      _ => null,
    };
  }

  String? _remaining(BuildContext context, Duration? remaining) {
    if (remaining == null ||
        progress is IngestFetchingDirectory ||
        progress is IngestFetchingSectors) {
      return null;
    }
    return context.strings.ingestRemaining(_readable(context, remaining));
  }

  String _readable(BuildContext context, Duration duration) {
    final seconds = duration.inSeconds;
    if (seconds < _secondsPerMinute) {
      return context.strings.durationSeconds(seconds);
    }
    return context.strings.durationMinutesSeconds(
      duration.inMinutes,
      seconds % _secondsPerMinute,
    );
  }
}
