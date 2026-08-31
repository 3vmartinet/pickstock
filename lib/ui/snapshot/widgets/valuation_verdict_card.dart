import 'package:get_it/get_it.dart';
import 'package:pickstock/data/valuation/valuation.dart';
import 'package:pickstock/data/valuation/valuation_verdict.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();
ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// How much of the verdict colour tints the card's glyph.
const double _accentOpacity = 0.12;

/// The verdict on the entered price, and the arithmetic that produced it.
///
/// The workings are on the card on purpose: a one-word verdict from a hidden
/// formula is worth nothing, so the multiples, the stream they are struck
/// against and the growth premium are all stated.
class ValuationVerdictCard extends StatelessWidget {
  const ValuationVerdictCard({super.key});

  @override
  Widget build(BuildContext context) {
    final valuation = context.select<SnapshotViewModel, Valuation?>(
      (viewModel) => viewModel.valuation,
    );
    if (valuation == null) return const SizedBox.shrink();

    final verdict = valuation.verdict;
    final accent = _themeRepo.forOutcome(context.theme, isGood: verdict.isGood);

    return Card(
      padding: context.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: ThemeRepo.spaceMedium,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: ThemeRepo.spaceMedium,
            children: [
              _VerdictGlyph(icon: verdict.icon, accent: accent),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: ThemeRepo.spaceXSmall,
                  children: [
                    Text(verdict.getLabel(context.strings)).h4(color: accent),
                    Text(verdict.getDetail(context.strings)).muted().small(),
                  ],
                ),
              ),
            ],
          ),
          if (verdict != ValuationVerdict.unknown) ...[
            const Divider(),
            const _FairValueRow(),
            const _WorkingsLines(),
          ],
          const Divider(),
          const _SizeRow(),
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

/// The band itself, and how far the price is from the middle of it.
class _FairValueRow extends StatelessWidget {
  const _FairValueRow();

  @override
  Widget build(BuildContext context) {
    final valuation = context.select<SnapshotViewModel, Valuation?>(
      (viewModel) => viewModel.valuation,
    );
    final low = valuation?.fairValueLow;
    final high = valuation?.fairValueHigh;
    if (valuation == null || low == null || high == null) {
      return const SizedBox.shrink();
    }

    final upside = valuation.upsidePercent;

    return Wrap(
      spacing: ThemeRepo.spaceXLarge,
      runSpacing: ThemeRepo.spaceSmall,
      children: [
        _Stat(
          label: context.strings.labelFairValueRange,
          value: context.strings.fairValueRange(
            _formatRepo.price(low),
            _formatRepo.price(high),
          ),
          isEmphasised: true,
        ),
        if (upside != null)
          _Stat(
            label: context.strings.labelUpside,
            value: _formatRepo.signedPercent(upside),
            colour: _themeRepo.forOutcome(context.theme, isGood: upside >= 0),
            isEmphasised: true,
          ),
      ],
    );
  }
}

/// The two sentences that show the working: what multiple, on what, and what
/// the growth premium added.
class _WorkingsLines extends StatelessWidget {
  const _WorkingsLines();

  @override
  Widget build(BuildContext context) {
    final valuation = context.select<SnapshotViewModel, Valuation?>(
      (viewModel) => viewModel.valuation,
    );
    final basis = valuation?.basis;
    final shares = valuation?.sharesOutstanding;
    final stream = valuation?.basisAmount;
    if (valuation == null ||
        basis == null ||
        shares == null ||
        stream == null) {
      return const SizedBox.shrink();
    }

    final growth = valuation.creditedGrowthPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: ThemeRepo.spaceXSmall,
      children: [
        Text(
          context.strings.valuationBasisLine(
            _formatRepo.ratio(valuation.lowMultiple),
            _formatRepo.ratio(valuation.highMultiple),
            basis.getLabel(context.strings),
            _formatRepo.compactCurrency(stream),
            _formatRepo.compactCount(shares),
          ),
        ).muted().xSmall(),
        Text(
          growth > 0
              ? context.strings.valuationGrowthPremium(
                  _formatRepo.ratio(valuation.growthPremiumMultiple),
                  _formatRepo.percent(growth),
                )
              : context.strings.valuationNoGrowthPremium,
        ).muted().xSmall(),
      ],
    );
  }
}

/// What the market is paying for, in absolute terms.
class _SizeRow extends StatelessWidget {
  const _SizeRow();

  @override
  Widget build(BuildContext context) {
    final valuation = context.select<SnapshotViewModel, Valuation?>(
      (viewModel) => viewModel.valuation,
    );
    if (valuation == null) return const SizedBox.shrink();

    final marketCap = valuation.marketCap;
    final enterpriseValue = valuation.enterpriseValue;
    final earningsPerShare = valuation.earningsPerShare;
    final unknown = context.strings.verdictUnknown;

    return Wrap(
      spacing: ThemeRepo.spaceXLarge,
      runSpacing: ThemeRepo.spaceSmall,
      children: [
        _Stat(
          label: context.strings.labelMarketCap,
          value: marketCap == null
              ? unknown
              : _formatRepo.compactCurrency(marketCap),
        ),
        _Stat(
          label: context.strings.labelEnterpriseValue,
          value: enterpriseValue == null
              ? unknown
              : _formatRepo.compactCurrency(enterpriseValue),
        ),
        _Stat(
          label: context.strings.labelEarningsPerShare,
          value: earningsPerShare == null
              ? unknown
              : _formatRepo.price(earningsPerShare),
        ),
      ],
    );
  }
}

/// A labelled figure, stacked so a row of them reads as columns.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.colour,
    this.isEmphasised = false,
  });

  final String label;
  final String value;
  final Color? colour;
  final bool isEmphasised;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: ThemeRepo.spaceXSmall,
      children: [
        Text(label).muted().xSmall(),
        isEmphasised
            ? Text(value).large().semiBold(color: colour)
            : Text(value).small().semiBold(color: colour),
      ],
    );
  }
}
