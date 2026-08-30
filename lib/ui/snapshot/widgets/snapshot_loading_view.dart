import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/snapshot/snapshot_state.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/widgets/responsive_grid.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Placeholder block sizes, chosen to match the report they stand in for so
/// little jumps when the real figures arrive.
const double _headingWidth = 220;
const double _lineWidth = 140;
const double _figureWidth = 110;
const double _rowHeight = 44;
const int _cardCount = 4;
const int _rowCount = 4;

/// Text under the shimmer. Never legible, but it gives the skeleton its
/// line heights.
const String _placeholderText = 'placeholder';

/// What the screen shows while EDGAR is being queried: the shape of the
/// report, greyed out, plus which ticker is being fetched.
class SnapshotLoadingView extends StatelessWidget {
  const SnapshotLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: ThemeRepo.spaceLarge,
      children: [_LoadingStatus(), _PlaceholderReport()],
    );
  }
}

class _LoadingStatus extends StatelessWidget {
  const _LoadingStatus();

  @override
  Widget build(BuildContext context) {
    final ticker = context.select<SnapshotViewModel, String>(
      (viewModel) => switch (viewModel.state) {
        SnapshotLoading(:final ticker) => ticker,
        _ => '',
      },
    );

    return Row(
      spacing: ThemeRepo.spaceSmall,
      children: [
        const CircularProgressIndicator(size: ThemeRepo.spaceMedium),
        Text(context.strings.loadingFetching(ticker)).muted().small(),
      ],
    );
  }
}

class _PlaceholderReport extends StatelessWidget {
  const _PlaceholderReport();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: ThemeRepo.spaceLarge,
      children: [
        const _PlaceholderHeaderCard(),
        ResponsiveGrid(
          minItemWidth: ThemeRepo.metricCardMinWidth,
          children: List<Widget>.filled(_cardCount, const _PlaceholderCard()),
        ),
        const _PlaceholderTable(),
      ],
    ).asSkeleton();
  }
}

class _PlaceholderHeaderCard extends StatelessWidget {
  const _PlaceholderHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      padding: ThemeRepo.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: ThemeRepo.spaceSmall,
        children: [
          SizedBox(
            width: _headingWidth,
            child: const Text(_placeholderText).h3(),
          ),
          const SizedBox(width: _lineWidth, child: Text(_placeholderText)),
        ],
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      padding: ThemeRepo.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: ThemeRepo.spaceSmall,
        children: [
          const SizedBox(width: _lineWidth, child: Text(_placeholderText)),
          SizedBox(
            width: _figureWidth,
            child: const Text(_placeholderText).x3Large(),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderTable extends StatelessWidget {
  const _PlaceholderTable();

  @override
  Widget build(BuildContext context) {
    return Card(
      padding: ThemeRepo.cardPadding,
      child: Column(
        children: List<Widget>.filled(
          _rowCount,
          const SizedBox(
            height: _rowHeight,
            child: Row(children: [Expanded(child: Text(_placeholderText))]),
          ),
        ),
      ),
    );
  }
}
