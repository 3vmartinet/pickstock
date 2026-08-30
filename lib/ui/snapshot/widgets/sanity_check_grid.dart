import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/snapshot/sanity_check.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/widgets/responsive_grid.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// How much of the verdict colour tints the card's accent chip.
const double _accentOpacity = 0.12;

/// The three yes/no questions, answered for the most recent fiscal year.
class SanityCheckGrid extends StatelessWidget {
  const SanityCheckGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      minItemWidth: ThemeRepo.checkCardMinWidth,
      children: [
        for (final check in SanityCheck.values) _SanityCheckCard(check),
      ],
    );
  }
}

class _SanityCheckCard extends StatelessWidget {
  const _SanityCheckCard(this.check);

  final SanityCheck check;

  @override
  Widget build(BuildContext context) {
    final figures = context.select<SnapshotViewModel, FiscalYearFigures?>(
      (viewModel) => viewModel.latestFigures,
    );
    if (figures == null) return const SizedBox.shrink();

    final verdict = check.getVerdict(figures);
    final accent = _themeRepo.forOutcome(context.theme, isGood: verdict.isGood);

    return Card(
      padding: context.cardPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: ThemeRepo.spaceMedium,
        children: [
          _VerdictGlyph(icon: verdict.icon, accent: accent),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: ThemeRepo.spaceXSmall,
              children: [
                Text(check.getQuestion(context.strings)).muted().small(),
                Text(verdict.getLabel(context.strings)).h4(color: accent),
                Text(check.getDetail(context.strings, figures))
                    .muted()
                    .xSmall(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerdictGlyph extends StatelessWidget {
  const _VerdictGlyph({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ThemeRepo.spaceSmall),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: _accentOpacity),
        borderRadius: context.theme.borderRadiusMd,
      ),
      child: Icon(icon, color: accent).iconSmall(),
    );
  }
}
