import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/institutional_shareholding.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/widgets/section_header.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();
ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// Visual breakdown of the company's equity float across passive indexers,
/// active managers, corporate insiders, and retail float.
class OwnershipCompositionCard extends StatelessWidget {
  const OwnershipCompositionCard({super.key, required this.holdings});

  final InstitutionalShareholding holdings;

  @override
  Widget build(BuildContext context) {
    return Card(
      padding: context.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: ThemeRepo.spaceMedium,
        children: [
          SectionHeader(
            icon: LucideIcons.chartPie,
            title: context.strings.sectionOwnershipComposition,
          ),
          _CompositionBar(holdings: holdings),
          _CompositionLegend(holdings: holdings),
        ],
      ),
    );
  }
}

class _CompositionBar extends StatelessWidget {
  const _CompositionBar({required this.holdings});

  final InstitutionalShareholding holdings;

  @override
  Widget build(BuildContext context) {
    final passiveColor = context.theme.colorScheme.primary;
    final activeColor = context.theme.colorScheme.primary.withValues(alpha: 0.55);
    final insiderColor = _themeRepo.caution(context.theme);
    final floatColor = context.theme.colorScheme.muted;

    final passiveWeight = holdings.passiveIndexPercent.clamp(0.0, 100.0);
    final activeWeight = holdings.activeFundsPercent.clamp(0.0, 100.0);
    final insiderWeight = holdings.insiderPercent.clamp(0.0, 100.0);
    final floatWeight = (100.0 - (passiveWeight + activeWeight + insiderWeight))
        .clamp(0.0, 100.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final passiveWidth = (passiveWeight / 100.0) * totalWidth;
        final activeWidth = (activeWeight / 100.0) * totalWidth;
        final insiderWidth = (insiderWeight / 100.0) * totalWidth;
        final floatWidth = (floatWeight / 100.0) * totalWidth;

        return ClipRRect(
          borderRadius: context.theme.borderRadiusMd,
          child: SizedBox(
            height: ThemeRepo.gaugeHeight,
            child: Row(
              children: [
                if (passiveWidth > 0)
                  Container(width: passiveWidth, color: passiveColor),
                if (activeWidth > 0)
                  Container(width: activeWidth, color: activeColor),
                if (insiderWidth > 0)
                  Container(width: insiderWidth, color: insiderColor),
                if (floatWidth > 0)
                  Container(width: floatWidth, color: floatColor),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CompositionLegend extends StatelessWidget {
  const _CompositionLegend({required this.holdings});

  final InstitutionalShareholding holdings;

  @override
  Widget build(BuildContext context) {
    final passiveColor = context.theme.colorScheme.primary;
    final activeColor = context.theme.colorScheme.primary.withValues(alpha: 0.55);
    final insiderColor = _themeRepo.caution(context.theme);
    final floatColor = context.theme.colorScheme.muted;

    return Wrap(
      spacing: ThemeRepo.spaceMedium,
      runSpacing: ThemeRepo.spaceSmall,
      children: [
        _LegendItem(
          color: passiveColor,
          label: context.strings.ownershipPassive,
          percent: holdings.passiveIndexPercent,
        ),
        _LegendItem(
          color: activeColor,
          label: context.strings.ownershipActive,
          percent: holdings.activeFundsPercent,
        ),
        _LegendItem(
          color: insiderColor,
          label: context.strings.ownershipInsiders,
          percent: holdings.insiderPercent,
        ),
        _LegendItem(
          color: floatColor,
          label: context.strings.ownershipFloat,
          percent: holdings.publicFloatPercent,
          border: true,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.percent,
    this.border = false,
  });

  final Color color;
  final String label;
  final double percent;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: ThemeRepo.spaceXSmall,
      children: [
        Container(
          width: ThemeRepo.watchlistDotSize,
          height: ThemeRepo.watchlistDotSize,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: border ? Border.all(color: context.theme.colorScheme.border) : null,
          ),
        ),
        Text(label).muted().xSmall(),
        Text(_formatRepo.percent(percent)).semiBold().xSmall(),
      ],
    );
  }
}

