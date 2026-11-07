import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/snapshot/widgets/holdings/activism_alert.dart';
import 'package:pickstock/ui/snapshot/widgets/holdings/holders_table.dart';
import 'package:pickstock/ui/snapshot/widgets/holdings/institutional_ownership_chart.dart';
import 'package:pickstock/ui/snapshot/widgets/holdings/ownership_composition_card.dart';
import 'package:pickstock/ui/snapshot/widgets/holdings/ownership_metric_grid.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The complete institutional shareholding and beneficial ownership view
/// for the open company, sourced from SEC EDGAR Form 13F and Schedule 13D/13G.
class HoldingsSection extends StatelessWidget {
  const HoldingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SnapshotViewModel>();
    final holdings = viewModel.institutionalShareholding;
    final isLoading = viewModel.isHoldingsLoading;

    if (isLoading && holdings == null) {
      return Padding(
        padding: const EdgeInsets.only(top: ThemeRepo.spaceXLarge),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: ThemeRepo.spaceMedium,
            children: [
              const CircularProgressIndicator(),
              Text('Reading Form 13F and Schedule 13D filings…')
                  .muted()
                  .small(),
            ],
          ),
        ),
      );
    }

    if (holdings == null) {
      return Padding(
        padding: const EdgeInsets.only(top: ThemeRepo.spaceLarge),
        child: Card(
          padding: context.cardPadding,
          child: Row(
            spacing: ThemeRepo.spaceMedium,
            children: [
              const Icon(LucideIcons.info).iconSmall().iconMutedForeground(),
              Expanded(
                child: Text(context.strings.holdingsNoData).muted().small(),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: ThemeRepo.spaceLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: ThemeRepo.spaceLarge,
        children: [
          OwnershipMetricGrid(holdings: holdings),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 680) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: ThemeRepo.spaceLarge,
                  children: [
                    Expanded(
                      child: InstitutionalOwnershipChart(holdings: holdings),
                    ),
                    Expanded(
                      child: OwnershipCompositionCard(holdings: holdings),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: ThemeRepo.spaceLarge,
                children: [
                  InstitutionalOwnershipChart(holdings: holdings),
                  OwnershipCompositionCard(holdings: holdings),
                ],
              );
            },
          ),
          ActivismAlert(holdings: holdings),
          HoldingsTable(holdings: holdings),
        ],
      ),
    );
  }
}
