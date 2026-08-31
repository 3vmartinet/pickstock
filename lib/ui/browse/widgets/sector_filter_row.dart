import 'package:pickstock/data/snapshot/sic_sector.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// One tap per sector, scrolling sideways rather than wrapping.
///
/// A row keeps the list itself as tall as possible; twelve chips would take
/// three lines if they wrapped.
class SectorFilterRow extends StatelessWidget {
  const SectorFilterRow({super.key});

  @override
  Widget build(BuildContext context) {
    final hasSectors = context.select<BrowseViewModel, bool>(
      (viewModel) => viewModel.hasSectors,
    );
    // Nothing classified: an ingest before sectors were collected, or a
    // company set the data sets do not cover.
    if (!hasSectors) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // The filter above already ends on a full gutter, so the chips take
      // none at the top and the same gutter below: even space either side of
      // the row, and the divider is no longer sitting on them.
      padding: EdgeInsets.fromLTRB(
        context.pageGutter,
        0,
        context.pageGutter,
        ThemeRepo.spaceMedium,
      ),
      child: Row(
        spacing: ThemeRepo.spaceSmall,
        children: [
          const _SectorChip(),
          for (final sector in SicSector.values) _SectorChip(sector: sector),
        ],
      ),
    );
  }
}

class _SectorChip extends StatelessWidget {
  const _SectorChip({this.sector});

  /// `null` is the chip that clears the filter.
  final SicSector? sector;

  @override
  Widget build(BuildContext context) {
    final selected = context.select<BrowseViewModel, SicSector?>(
      (viewModel) => viewModel.sector,
    );
    final isSelected = selected == sector;

    return Button(
      style: isSelected
          ? const ButtonStyle.primary(size: ButtonSize.small)
          : const ButtonStyle.outline(size: ButtonSize.small),
      onPressed: () => context.read<BrowseViewModel>().selectSector(
        isSelected ? null : sector,
      ),
      leading: sector == null ? null : Icon(sector!.icon).iconXSmall(),
      child: Text(
        sector?.getLabel(context.strings) ?? context.strings.sectorAll,
      ),
    );
  }
}
