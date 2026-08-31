import 'package:get_it/get_it.dart';
import 'package:pickstock/data/valuation/expectation_verdict_extensions.dart';
import 'package:pickstock/data/valuation/growth_expectation.dart';
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

const double _accentOpacity = 0.12;

/// The growth the current price requires, against the growth the company has
/// produced.
///
/// This is the part that answers whether the market may be missing something:
/// a price asking less than a company has repeatedly delivered leaves room,
/// and one asking more than it ever has needs a reason that is not in the
/// filings.
class ExpectationCard extends StatelessWidget {
  const ExpectationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final expectation = context.select<SnapshotViewModel, GrowthExpectation?>(
      (viewModel) => viewModel.growthExpectation,
    );
    if (expectation == null) return const SizedBox.shrink();

    final verdict = expectation.verdict;
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
              Container(
                padding: const EdgeInsets.all(ThemeRepo.spaceSmall),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: _accentOpacity),
                  borderRadius: context.theme.borderRadiusMd,
                ),
                child: Icon(verdict.icon, color: accent).iconSmall(),
              ),
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
          const Divider(),
          const _HeadlineRates(),
          const _SensitivityRow(),
          const _WorthRow(),
          const _BasisLines(),
        ],
      ),
    );
  }
}

/// The two rates the verdict turns on, side by side.
class _HeadlineRates extends StatelessWidget {
  const _HeadlineRates();

  @override
  Widget build(BuildContext context) {
    final expectation = context.select<SnapshotViewModel, GrowthExpectation?>(
      (viewModel) => viewModel.growthExpectation,
    );
    if (expectation == null) return const SizedBox.shrink();

    final required = expectation.requiredGrowthPercent;
    final delivered = expectation.deliveredGrowthPercent;
    final years = expectation.deliveredOverYears;
    final unknown = context.strings.verdictUnknown;

    return Wrap(
      spacing: ThemeRepo.spaceXLarge,
      runSpacing: ThemeRepo.spaceSmall,
      children: [
        _Stat(
          label: context.strings.expectationRequired,
          value: required == null
              ? unknown
              : context.strings.expectationPerYear(
                  _formatRepo.percent(required),
                ),
          isEmphasised: true,
        ),
        if (delivered != null && years != null)
          _Stat(
            label: context.strings.expectationDelivered(years),
            value: context.strings.expectationPerYear(
              _formatRepo.signedPercent(delivered),
            ),
            isEmphasised: true,
          ),
      ],
    );
  }
}

/// The required rate across the discount band.
///
/// The single figure above moves by more than fifteen points across this row,
/// so hiding the row would make it look far more precise than it is.
class _SensitivityRow extends StatelessWidget {
  const _SensitivityRow();

  @override
  Widget build(BuildContext context) {
    final expectation = context.select<SnapshotViewModel, GrowthExpectation?>(
      (viewModel) => viewModel.growthExpectation,
    );
    if (expectation == null) return const SizedBox.shrink();

    final delivered = expectation.deliveredGrowthPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: ThemeRepo.spaceSmall,
      children: [
        Text(context.strings.expectationSensitivity).muted().xSmall(),
        Wrap(
          spacing: ThemeRepo.spaceLarge,
          runSpacing: ThemeRepo.spaceSmall,
          children: [
            for (final point in expectation.sensitivity)
              _Stat(
                label: context.strings.expectationRate(
                  _formatRepo.percent(point.rate * 100),
                ),
                value: point.growthPercent == null
                    ? context.strings.verdictUnknown
                    : _formatRepo.percent(point.growthPercent!),
                // Coloured against the record, so the row reads at a glance as
                // where the price stops being supported by history.
                colour: delivered == null || point.growthPercent == null
                    ? null
                    : _themeRepo.forOutcome(
                        context.theme,
                        isGood: point.growthPercent! <= delivered,
                      ),
              ),
          ],
        ),
      ],
    );
  }
}

/// What a share is worth if the company simply repeats its record.
class _WorthRow extends StatelessWidget {
  const _WorthRow();

  @override
  Widget build(BuildContext context) {
    final expectation = context.select<SnapshotViewModel, GrowthExpectation?>(
      (viewModel) => viewModel.growthExpectation,
    );
    final shares = context.select<SnapshotViewModel, double?>(
      (viewModel) => viewModel.valuation?.sharesOutstanding,
    );
    if (expectation == null || shares == null) return const SizedBox.shrink();

    final values = expectation.equityValues(shares);
    if (values.isEmpty) return const SizedBox.shrink();

    final price = context.select<SnapshotViewModel, double?>(
      (viewModel) => viewModel.pricePerShare,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: ThemeRepo.spaceSmall,
      children: [
        Text(context.strings.expectationWorth).muted().xSmall(),
        Wrap(
          spacing: ThemeRepo.spaceLarge,
          runSpacing: ThemeRepo.spaceSmall,
          children: [
            for (final point in values)
              _Stat(
                label: context.strings.expectationRate(
                  _formatRepo.percent(point.rate * 100),
                ),
                value: _formatRepo.price(point.value),
                colour: price == null
                    ? null
                    : _themeRepo.forOutcome(
                        context.theme,
                        isGood: point.value >= price,
                      ),
              ),
          ],
        ),
      ],
    );
  }
}

/// What was discounted, and what was normalised away to get it.
class _BasisLines extends StatelessWidget {
  const _BasisLines();

  @override
  Widget build(BuildContext context) {
    final expectation = context.select<SnapshotViewModel, GrowthExpectation?>(
      (viewModel) => viewModel.growthExpectation,
    );
    if (expectation == null) return const SizedBox.shrink();

    final reported = expectation.reportedCashFlow;
    final gap = expectation.normalisationEffectPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: ThemeRepo.spaceXSmall,
      children: [
        Text(
          context.strings.expectationBasis(
            _formatRepo.compactCurrency(expectation.normalisedCashFlow),
            _formatRepo.percent(expectation.medianCashFlowMargin),
          ),
        ).muted().xSmall(),
        if (reported != null && gap != null)
          Text(
            context.strings.expectationNormalised(
              _formatRepo.compactCurrency(reported),
              _formatRepo.signedPercent(gap),
            ),
          ).muted().xSmall(),
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
