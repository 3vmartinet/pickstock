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

/// One labelled figure: a heading that never moves over a value that does.
class _Stat {
  const _Stat({required this.label, required this.value});

  final String label;

  /// `null` renders a placeholder, so a value that only appears once there is
  /// enough to measure does not shift the row when it arrives.
  final String? value;
}

/// What the current stage has got through, how fast, and how much longer.
///
/// One line of three changing numbers separated by dots was unreadable — with
/// nothing static to anchor on, every value moved sideways whenever any of
/// them changed. Each figure now has its own column with a fixed heading, so
/// the labels hold still and only the digits underneath them move.
class IngestStatsRow extends StatelessWidget {
  const IngestStatsRow({super.key, required this.progress});

  final IngestProgress progress;

  @override
  Widget build(BuildContext context) {
    final stats = _statsFor(context, context.watch<IngestViewModel>());
    if (stats.isEmpty) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Equal columns, so a widening value cannot push its neighbours along.
        for (final stat in stats) Expanded(child: _StatColumn(stat: stat)),
      ],
    );
  }

  /// The figures worth showing for the running stage.
  ///
  /// A stage keeps the same set throughout, so the row's shape is settled the
  /// moment it appears.
  List<_Stat> _statsFor(BuildContext context, IngestViewModel viewModel) {
    final strings = context.strings;

    return switch (progress) {
      IngestFetchingDirectory() => const [],
      IngestFetchingSectors(:final quartersRead) => [
        _Stat(
          label: strings.statDataSets,
          value: strings.ingestDataSets(quartersRead, sectorQuarters),
        ),
      ],
      IngestDownloading(:final receivedBytes, :final totalBytes) => [
        _Stat(
          label: strings.statDownloaded,
          value: totalBytes == null
              ? _formatRepo.bytes(receivedBytes)
              : strings.ingestBytesOfTotal(
                  _formatRepo.bytes(receivedBytes),
                  _formatRepo.bytes(totalBytes),
                ),
        ),
        _Stat(label: strings.statSpeed, value: _bytesRate(context, viewModel)),
        _Stat(
          label: strings.statRemaining,
          value: _remaining(context, viewModel),
        ),
      ],
      IngestLoading(:final companiesLoaded, :final totalCompanies) => [
        _Stat(
          label: strings.statLoaded,
          value: strings.ingestCompaniesOfTotal(
            companiesLoaded,
            totalCompanies,
          ),
        ),
        _Stat(label: strings.statSpeed, value: _countRate(context, viewModel)),
        _Stat(
          label: strings.statRemaining,
          value: _remaining(context, viewModel),
        ),
      ],
      IngestDone() => const [],
    };
  }

  String? _bytesRate(BuildContext context, IngestViewModel viewModel) {
    final rate = viewModel.ratePerSecond;
    return rate == null
        ? null
        : context.strings.ingestRate(_formatRepo.bytes(rate));
  }

  String? _countRate(BuildContext context, IngestViewModel viewModel) {
    final rate = viewModel.ratePerSecond;
    return rate == null
        ? null
        : context.strings.ingestRateCompanies(rate.round());
  }

  String? _remaining(BuildContext context, IngestViewModel viewModel) {
    final remaining = viewModel.estimatedRemaining;
    if (remaining == null) return null;

    final seconds = remaining.inSeconds;
    return context.strings.ingestRemaining(
      seconds < _secondsPerMinute
          ? context.strings.durationSeconds(seconds)
          : context.strings.durationMinutesSeconds(
              remaining.inMinutes,
              seconds % _secondsPerMinute,
            ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.stat});

  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: ThemeRepo.spaceXSmall,
      children: [
        Text(stat.label).muted().xSmall().singleLine().textCenter(),
        // Monospaced so the digits keep their columns as they tick over.
        Text(stat.value ?? context.strings.statPending)
            .mono()
            .small()
            .singleLine()
            .textCenter(),
      ],
    );
  }
}
