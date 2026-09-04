import 'package:pickstock/data/snapshot/company.dart';
import 'package:pickstock/data/snapshot/sic_industry.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/snapshot/widgets/company_events.dart';
import 'package:pickstock/ui/watchlist/widgets/add_to_watchlist_button.dart';
import 'package:pickstock/ui/watchlist/widgets/watchlist_star.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Who the report is about, and whether you are following them.
class CompanyHeader extends StatelessWidget {
  const CompanyHeader({super.key});

  @override
  Widget build(BuildContext context) {
    // Watched rather than read: whether the panel is on the row decides how
    // the row is divided.
    final hasEvents = context.select<SnapshotViewModel, bool>(
      (viewModel) => viewModel.hasEventsToShow,
    );

    return Card(
      padding: context.cardPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: ThemeRepo.spaceMedium,
        children: [
          // Two layouts, because the row has two jobs. With no news the name
          // and its industry line get the lot; with news the identity is
          // pinned narrow and the rest goes to the panel.
          // The name takes the slack either way; only the panel is capped.
          const Expanded(child: _CompanyIdentity()),
          // The middle of the row, which the header has always reserved and
          // never used. `Flexible` rather than `Expanded` so it gives back
          // what it does not need, and capped so a wide window does not hand
          // it width the captions have no use for.
          if (hasEvents)
            Flexible(
              // `ConstrainedBox` asserts on its constraints, so it is not
              // const.
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: ThemeRepo.eventsPanelMaxWidth,
                ),
                child: const CompanyEvents(),
              ),
            ),
          const _FollowRow(),
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
        Text(_subtitleOf(context, company)).muted().xSmall().ellipsis(),
      ],
    );
  }
}

/// What the company does, and the number it is filed under.
///
/// SEC states no prose description of a business anywhere in EDGAR, so the
/// industry title behind the filer's SIC code stands in — it is what EDGAR's
/// own `sicDescription` reports, and it is already on hand from the ingest.
/// Filers the industry data sets never covered fall back to the CIK alone.
String _subtitleOf(BuildContext context, Company company) {
  final industry = SicIndustry.of(company.sic);
  // One line, not two: the header is pinned above the report and every row it
  // takes is a row the figures do not get.
  return industry == null
      ? context.strings.labelCik(company.cik)
      : context.strings.labelIndustryAndCik(industry, company.cik);
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

    // A column, so reading around sits under the lists rather than in the
    // middle of the title row: all three are things you do to the company.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      spacing: ThemeRepo.spaceSmall,
      children: [
        Row(
          spacing: ThemeRepo.spaceSmall,
          children: [
            WatchlistStar(cik: cik),
            AddToWatchlistButton(cik: cik),
          ],
        ),
        const CompanyEventsButton(),
      ],
    );
  }
}
