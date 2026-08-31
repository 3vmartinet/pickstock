import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/watchlist/widgets/add_to_watchlist_button.dart';
import 'package:pickstock/ui/watchlist/widgets/watchlist_star.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Who the report is about: registrant name, symbol, CIK and years covered.
class CompanyHeader extends StatelessWidget {
  const CompanyHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      padding: context.cardPadding,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: ThemeRepo.spaceMedium,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: ThemeRepo.spaceMedium,
            children: [
              Expanded(child: _CompanyIdentity()),
              _CoverageBadge(),
            ],
          ),
          _FollowRow(),
        ],
      ),
    );
  }
}

class _CompanyIdentity extends StatelessWidget {
  const _CompanyIdentity();

  @override
  Widget build(BuildContext context) {
    final company = context.select<SnapshotViewModel, Company?>(
      (viewModel) => viewModel.snapshot?.company,
    );
    if (company == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: ThemeRepo.spaceXSmall,
      children: [
        Row(
          spacing: ThemeRepo.spaceSmall,
          children: [
            PrimaryBadge(child: Text(company.ticker)),
            Flexible(child: Text(company.name).h3().singleLine().ellipsis()),
          ],
        ),
        Text(context.strings.labelCik(company.cik)).muted().xSmall(),
      ],
    );
  }
}

/// Following the company: one tap for the starred list, a menu for the rest.
class _FollowRow extends StatelessWidget {
  const _FollowRow();

  @override
  Widget build(BuildContext context) {
    final cik = context.select<SnapshotViewModel, String?>(
      (viewModel) => viewModel.snapshot?.company.cik,
    );
    if (cik == null) return const SizedBox.shrink();

    return Row(
      spacing: ThemeRepo.spaceSmall,
      children: [
        WatchlistStar(cik: cik),
        AddToWatchlistButton(cik: cik),
      ],
    );
  }
}

class _CoverageBadge extends StatelessWidget {
  const _CoverageBadge();

  @override
  Widget build(BuildContext context) {
    final years = context.select<SnapshotViewModel, (String, String)?>((
      viewModel,
    ) {
      final reported = viewModel.snapshot?.years;
      if (reported == null || reported.isEmpty) return null;
      return (
        reported.first.fiscalYear.toString(),
        reported.last.fiscalYear.toString(),
      );
    });
    if (years == null) return const SizedBox.shrink();

    return OutlineBadge(
      child: Text(context.strings.labelFiscalYearsCovered(years.$1, years.$2)),
    );
  }
}
