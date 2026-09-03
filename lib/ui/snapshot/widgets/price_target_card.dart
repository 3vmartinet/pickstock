import 'dart:math' as math;

import 'package:get_it/get_it.dart';
import 'package:pickstock/data/valuation/cash_flow_model.dart';
import 'package:pickstock/data/valuation/discount_rate.dart';
import 'package:pickstock/data/valuation/growth_expectation.dart';
import 'package:pickstock/data/valuation/price_case_extensions.dart';
import 'package:pickstock/data/valuation/price_target.dart';
import 'package:pickstock/l10n/app_localizations.dart';
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

/// Three readings of what a share is worth, and the arithmetic behind them.
///
/// The same discounted cash flow the rest of the tab runs, at three growth
/// rates read off the company's own years rather than guessed. Shown with the
/// working, because a target price is worth nothing without the assumption
/// underneath it — a reader has to be able to disagree with the growth rather
/// than take the number on trust.
class PriceTargetCard extends StatelessWidget {
  const PriceTargetCard({super.key});

  @override
  Widget build(BuildContext context) {
    final expectation = context.select<SnapshotViewModel, GrowthExpectation?>(
      (viewModel) => viewModel.growthExpectation,
    );
    final shares = context.select<SnapshotViewModel, double?>(
      (viewModel) => viewModel.valuation?.sharesOutstanding,
    );
    if (expectation == null || shares == null) return const SizedBox.shrink();

    final rate = context.select<SnapshotViewModel, DiscountRate?>(
      (viewModel) => viewModel.discountRate,
    );
    final targets = expectation.priceTargets(
      shares,
      discountRate:
          (rate?.percent ?? CashFlowModel.defaultDiscountRate * 100) / 100,
    );
    if (targets.isEmpty) return const SizedBox.shrink();

    final price = context.select<SnapshotViewModel, double?>(
      (viewModel) => viewModel.pricePerShare,
    );

    return Card(
      padding: context.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: ThemeRepo.spaceMedium,
        children: [
          Text(context.strings.targetsTitle).h4(),
          Wrap(
            spacing: ThemeRepo.spaceXLarge,
            runSpacing: ThemeRepo.spaceMedium,
            children: [
              for (final target in targets)
                _Target(target: target, price: price),
            ],
          ),
          _RateLine(rate: rate),
          const Divider(),
          _Working(
            expectation: expectation,
            shares: shares,
            targets: targets,
            rate: rate,
          ),
        ],
      ),
    );
  }
}

/// One reading: what it assumes, what it makes a share worth, and how far
/// that sits from what a share costs.
class _Target extends StatelessWidget {
  const _Target({required this.target, required this.price});

  final PriceTarget target;
  final double? price;

  @override
  Widget build(BuildContext context) {
    final upside = price == null ? null : target.upsidePercentFrom(price!);
    final colour = upside == null
        ? null
        : _themeRepo.forOutcome(context.theme, isGood: upside >= 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: ThemeRepo.spaceXSmall,
      children: [
        Text(target.scenario.getLabel(context.strings)).muted().xSmall(),
        Text(_formatRepo.price(target.valuePerShare)).h3(color: colour),
        Text(
          context.strings.targetsGrowthAssumed(
            _formatRepo.signedPercent(target.growthPercent),
          ),
        ).muted().xSmall(),
        if (upside != null)
          Text(_formatRepo.signedPercent(upside)).xSmall(color: colour),
      ],
    );
  }
}

/// The worked example: where the cash came from, where the rates came from,
/// what was done to them, and what came out.
class _Working extends StatelessWidget {
  const _Working({
    required this.expectation,
    required this.shares,
    required this.targets,
    required this.rate,
  });

  final GrowthExpectation expectation;
  final double shares;
  final List<PriceTarget> targets;
  final DiscountRate? rate;

  double get _discountPercent =>
      rate?.percent ?? CashFlowModel.defaultDiscountRate * 100;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final steps = _steps(strings);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: ThemeRepo.spaceMedium,
      children: [
        Text(strings.targetsHowTitle).small().semiBold(),
        for (final (index, step) in steps.indexed)
          _Step(number: index + 1, title: step.title, body: step.body),
      ],
    );
  }

  List<({String title, String body})> _steps(AppLocalizations strings) {
    final money = _formatRepo.compactCurrency;
    final percent = _formatRepo.percent;
    final signed = _formatRepo.signedPercent;
    final revenue = expectation.marketCap <= 0
        ? null
        : expectation.normalisedCashFlow / expectation.medianCashFlowMargin;

    return [
      (
        title: strings.targetsHowStep1Title,
        body: strings.targetsHowStep1Body(
          revenue == null ? '—' : money(revenue * 100),
          percent(expectation.medianCashFlowMargin),
          money(expectation.normalisedCashFlow),
        ),
      ),
      (
        title: strings.targetsHowStep2Title,
        body: strings.targetsHowStep2Body(
          expectation.growthRatesOnFile.map(signed).join(', '),
          '${expectation.growthRatesOnFile.length}',
          signed(targets.first.growthPercent),
          signed(targets[1].growthPercent),
          signed(targets.last.growthPercent),
        ),
      ),
      (
        title: strings.targetsHowStep3Title,
        body: strings.targetsHowStep3Body(
          percent(CashFlowModel.terminalGrowth * 100),
          percent(_discountPercent),
          // Worked out rather than written into the copy, so the example
          // still holds at whatever rate this company is discounted at.
          _formatRepo.price(
            1 / math.pow(1 + _discountPercent / 100, CashFlowModel.horizon),
          ),
        ),
      ),
      (
        title: strings.targetsHowStep4Title,
        body: strings.targetsHowStep4Body(
          _formatRepo.compactCount(shares),
          _formatRepo.price(targets.first.valuePerShare),
          _formatRepo.price(targets[1].valuePerShare),
          _formatRepo.price(targets.last.valuePerShare),
        ),
      ),
    ];
  }
}

/// A numbered line of the working, matching the valuation tab's own.
class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.body});

  final int number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: ThemeRepo.spaceMedium,
      children: [
        Container(
          width: ThemeRepo.napkinStepSize,
          height: ThemeRepo.napkinStepSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.theme.colorScheme.muted,
            shape: BoxShape.circle,
          ),
          child: Text('$number').xSmall().semiBold(),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: ThemeRepo.spaceXSmall,
            children: [
              Text(title).small().semiBold(),
              Text(body).muted().small(),
            ],
          ),
        ),
      ],
    );
  }
}

/// The rate the targets were discounted at, and where it came from.
///
/// A line, not a paragraph: the rate itself with an information mark beside
/// it, and the arithmetic behind it only for a reader who asks. The rate is
/// the most consequential number on the card and the one nobody wants a
/// lecture about.
class _RateLine extends StatelessWidget {
  const _RateLine({required this.rate});

  final DiscountRate? rate;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final percent = _formatRepo.percent(
      rate?.percent ?? CashFlowModel.defaultDiscountRate * 100,
    );

    return Tooltip(
      tooltip: (_) => _RateBreakdown(rate: rate),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: ThemeRepo.spaceXSmall,
        children: [
          Text(
            rate == null
                ? strings.targetsRateAssumed(percent)
                : strings.targetsRateComputed(percent),
          ).muted().xSmall(),
          const Icon(LucideIcons.info).iconXSmall().iconMutedForeground(),
        ],
      ),
    );
  }
}

/// The rate broken into its parts, as a small table rather than prose.
class _RateBreakdown extends StatelessWidget {
  const _RateBreakdown({required this.rate});

  final DiscountRate? rate;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final percent = _formatRepo.percent;
    final held = rate;

    return TooltipContainer(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: ThemeRepo.tooltipMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: ThemeRepo.spaceSmall,
          children: [
            Text(strings.targetsRateWhat).xSmall(),
            if (held == null)
              Text(strings.targetsRateAssumedWhy).muted().xSmall()
            else ...[
              const Divider(),
              _RatePart(
                label: strings.targetsRateRiskFree,
                value: percent(held.riskFreePercent),
                note: strings.targetsRateRiskFreeNote(
                  _formatRepo.shortDate(held.asOf),
                ),
              ),
              _RatePart(
                label: strings.targetsRateBeta,
                value: _formatRepo.ratio(held.beta),
                note: strings.targetsRateBetaNote,
              ),
              _RatePart(
                label: strings.targetsRatePremium,
                value: percent(equityRiskPremium),
                note: strings.targetsRatePremiumNote,
              ),
              const Divider(),
              _RatePart(
                label: strings.targetsRateTotal,
                value: percent(held.percent),
                emphasised: true,
              ),
              if (held.isCapped)
                Text(strings.targetsRateCapped(percent(held.uncappedPercent)))
                    .muted()
                    .xSmall(),
            ],
          ],
        ),
      ),
    );
  }
}

/// One line of the breakdown: what it is, what it is worth, and — small and
/// muted under it — what it means.
class _RatePart extends StatelessWidget {
  const _RatePart({
    required this.label,
    required this.value,
    this.note,
    this.emphasised = false,
  });

  final String label;
  final String value;
  final String? note;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          spacing: ThemeRepo.spaceMedium,
          children: [
            Expanded(
              child: emphasised
                  ? Text(label).xSmall().semiBold()
                  : Text(label).xSmall(),
            ),
            emphasised
                ? Text(value).xSmall().semiBold()
                : Text(value).mono().xSmall(),
          ],
        ),
        if (note case final text?) Text(text).muted().xSmall(),
      ],
    );
  }
}
