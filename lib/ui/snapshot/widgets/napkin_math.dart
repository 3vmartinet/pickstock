import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/valuation/cash_flow_model.dart';
import 'package:pickstock/data/valuation/quarter_figure.dart';
import 'package:pickstock/data/valuation/valuation_basis.dart';
import 'package:pickstock/data/valuation/valuation.dart';
import 'package:pickstock/data/valuation/valuation_verdict.dart';
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

/// One line of the derivation.
typedef _Step = ({String title, String body});

/// The whole valuation worked out in plain words, with this company's own
/// numbers in it.
///
/// The cards beside this one give ratios and a verdict, which are only worth
/// anything to a reader who already knows what a multiple is. This says the
/// same thing as arithmetic anyone can check: what you pay, what you get, how
/// many years that is, and how many years is fair.
class NapkinMath extends StatelessWidget {
  const NapkinMath({super.key});

  @override
  Widget build(BuildContext context) {
    final valuation = context.select<SnapshotViewModel, Valuation?>(
      (viewModel) => viewModel.valuation,
    );
    final figures = context.select<SnapshotViewModel, FiscalYearFigures?>(
      (viewModel) => viewModel.latestFigures,
    );
    if (valuation == null || figures == null) return const SizedBox.shrink();

    final steps = napkinStepsFor(context.strings, valuation);
    if (steps.isEmpty) return const SizedBox.shrink();

    final caveats = napkinCaveatsFor(context.strings, valuation, figures);

    return Card(
      padding: context.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: ThemeRepo.spaceMedium,
        children: [
          Row(
            spacing: ThemeRepo.spaceSmall,
            children: [
              const Icon(LucideIcons.pencilLine)
                  .iconSmall()
                  .iconMutedForeground(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.strings.napkinTitle).semiBold(),
                    Text(context.strings.napkinSubtitle).muted().xSmall(),
                  ],
                ),
              ),
            ],
          ),
          const Divider(),
          for (var index = 0; index < steps.length; index++)
            _NumberedStep(number: index + 1, step: steps[index]),
          if (caveats.isNotEmpty) ...[const Divider(), _Caveats(caveats)],
        ],
      ),
    );
  }
}

/// The derivation, in the order the arithmetic happens.
///
/// Returns empty where a step cannot be stated: half a derivation with gaps in
/// it teaches nothing, so the panel simply does not appear.
@visibleForTesting
List<({String title, String body})> napkinStepsFor(
  AppLocalizations strings,
  Valuation valuation,
) {
  final shares = valuation.sharesOutstanding;
  final marketCap = valuation.marketCap;
  final basis = valuation.basisAmount;
  final low = valuation.fairValueLow;
  final lowBefore = valuation.fairValueLowBeforeMargin;
  final high = valuation.fairValueHigh;
  final equityLow = valuation.equityValueAt(valuation.lowMultiple);
  final equityHigh = valuation.equityValueAt(valuation.highMultiple);
  if (shares == null ||
      marketCap == null ||
      basis == null ||
      basis <= 0 ||
      low == null ||
      lowBefore == null ||
      high == null ||
      equityLow == null ||
      equityHigh == null) {
    return const [];
  }

  final netDebt = valuation.netDebt;
  final excess = valuation.excessDebtDeducted;
  final netCash = valuation.netCashAdded;
  final money = _formatRepo.compactCurrency;
  final count = _formatRepo.compactCount;
  final price = _formatRepo.price;
  final years = _formatRepo.ratio;
  final percent = _formatRepo.percent;
  final discount = percent(valuation.discountRatePercent);
  final growth = valuation.creditedGrowthPercent;
  final streamLow = basis * valuation.lowMultiple;
  final streamHigh = basis * valuation.highMultiple;

  return [
    (
      title: strings.napkinStep1Title,
      body: strings.napkinStep1Body(
        price(valuation.pricePerShare),
        count(shares),
        money(marketCap),
      ),
    ),
    (
      title: strings.napkinStep2Title,
      body: valuation.basisYears > 1
          ? strings.napkinStep2BodyTypical(
              valuation.revenue == null ? '—' : money(valuation.revenue!),
              money(basis),
              valuation.basisYears,
            )
          : strings.napkinStep2Body(
              valuation.revenue == null ? '—' : money(valuation.revenue!),
              money(basis),
            ),
    ),
    // A debt that is not on file is said to be missing rather than written
    // as $0, which would read as a company owing nothing.
    switch (netDebt) {
      null => (
        title: strings.napkinStep3TitleUnknown,
        body: strings.napkinStep3BodyUnknown(money(basis)),
      ),
      < 0 => (
        title: strings.napkinStep3TitleCash,
        body: strings.napkinStep3BodyCash(money(netCash), money(basis)),
      ),
      final owed when excess > 0 => (
        title: strings.napkinStep3TitleExcess,
        body: strings.napkinStep3BodyExcess(
          money(owed),
          years(owed / basis),
          money(basis),
          years(CashFlowModel.carriedDebtYears),
          money(excess),
        ),
      ),
      final owed => (
        title: strings.napkinStep3TitleDebt,
        body: strings.napkinStep3BodyDebt(money(owed), money(basis)),
      ),
    },
    (
      title: strings.napkinStep4Title,
      body: strings.napkinStep4Body(
        money(marketCap),
        money(basis),
        years(marketCap / basis),
      ),
    ),
    (
      title: strings.napkinStep5Title,
      body: growth > 0
          ? strings.napkinStep5BodyGrowing(
              discount,
              years(valuation.flatMultiple),
              percent(growth),
              '${valuation.growthWindowYears}',
              years(valuation.lowMultiple),
              years(valuation.highMultiple),
            )
          : growth < 0
          ? strings.napkinStep5BodyShrinking(
              discount,
              years(valuation.flatMultiple),
              percent(-growth),
              '${valuation.growthWindowYears}',
              years(valuation.lowMultiple),
              years(valuation.highMultiple),
            )
          : strings.napkinStep5BodyFlat(
              discount,
              years(valuation.flatMultiple),
            ),
    ),
    (
      title: strings.napkinStep6Title,
      body: [
        strings.napkinStep6Body(
          years(valuation.lowMultiple),
          years(valuation.highMultiple),
          money(basis),
          money(streamLow),
          money(streamHigh),
        ),
        if (netCash > 0)
          strings.napkinStep6PlusCash(
            money(netCash),
            money(equityLow),
            money(equityHigh),
          )
        else if (excess > 0)
          strings.napkinStep6LessDebt(
            money(excess),
            money(equityLow),
            money(equityHigh),
          )
        else
          strings.napkinStep6AsIs,
      ].join(' '),
    ),
    (
      title: strings.napkinStep7Title,
      body: strings.napkinStep7Body(
        count(shares),
        price(lowBefore),
        price(high),
        percent(CashFlowModel.marginOfSafety * 100),
        price(low),
      ),
    ),
    (
      title: strings.napkinStep8Title,
      body: switch (valuation.verdict) {
        ValuationVerdict.undervalued => strings.napkinStep8BodyUnder(
          price(valuation.pricePerShare),
          price(low),
          price(high),
        ),
        ValuationVerdict.overvalued => strings.napkinStep8BodyOver(
          price(valuation.pricePerShare),
          price(low),
          price(high),
        ),
        _ => strings.napkinStep8BodyFair(
          price(valuation.pricePerShare),
          price(low),
          price(high),
        ),
      },
    ),
  ];
}

/// The things that would mislead a reader who took the steps at face value.
@visibleForTesting
List<String> napkinCaveatsFor(
  AppLocalizations strings,
  Valuation valuation,
  FiscalYearFigures figures,
) {
  final actualGrowth = valuation.growthPercent;
  final fromQuarter = valuation.fromQuarter;
  // The share count only reaches the arithmetic from the quarter where there
  // is no cover count; otherwise the quarter's average is only the earnings
  // divisor, which the steps never use.
  final sharesFromQuarter =
      !valuation.countIsCurrent &&
      fromQuarter.contains(QuarterFigure.dilutedShares);
  return [
    // First, because every figure in the derivation is struck against the
    // share count: a market value built on the wrong one is wrong throughout,
    // and the steps read as arithmetic whose authority their input does not
    // have.
    //
    // Two ways to have no current count, and they are worth telling apart. A
    // filer that never states one is filing the way it always has; one that
    // stopped in 2010 has a count on record that a reader might otherwise go
    // looking for, and naming the year says how far out of date it is.
    if (!valuation.countIsCurrent)
      switch ((valuation.sharesLastFiled, sharesFromQuarter)) {
        (final filed?, true) => strings.napkinCaveatShareCountQuarterStale(
          '${filed.year}',
        ),
        (final filed?, false) => strings.napkinCaveatShareCountStale(
          '${filed.year}',
        ),
        (null, true) => strings.napkinCaveatShareCountQuarter,
        (null, false) => strings.napkinCaveatShareCount,
      },
    // Said because the figures above will not match the annual report a
    // reader checks them against — naming only the ones that came from the
    // quarter, since any of them can have stayed the year's.
    if (valuation.currentThrough case final through?)
      if (_quarterFigures(
            strings,
            sales: fromQuarter.contains(QuarterFigure.revenue),
            cashAndDebt: fromQuarter.contains(QuarterFigure.netDebt),
            shares: sharesFromQuarter,
          )
          case final figures?)
        strings.napkinCaveatQuarter(_formatRepo.shortDate(through), figures),
    if (valuation.basis == ValuationBasis.earnings)
      strings.napkinCaveatEarnings,
    if (actualGrowth != null &&
        actualGrowth > CashFlowModel.maximumCreditedGrowth * 100)
      strings.napkinCaveatGrowthCapped(
        _formatRepo.percent(actualGrowth),
        _formatRepo.percent(valuation.creditedGrowthPercent),
      ),
    // Said where the arithmetic happens, because the figure above is not the
    // one the cash flow statement prints and a reader checking would find
    // them differ.
    if (valuation.stockPayShareOfCashPercent case final share?)
      strings.napkinCaveatStockPay(_formatRepo.percent(share)),
    if (figures.leaseShareOfDebtPercent case final share?)
      strings.napkinCaveatLeases(_formatRepo.percent(share)),
    if (valuation.hasOutsideOwners)
      strings.napkinCaveatOutsideOwners(
        _formatRepo.percent(valuation.parentStake * 100),
      ),
    // Worded for the stream the band is struck on: a typical year of cash
    // already allows for a building spree, a year's profit only charges what
    // wore out.
    if (valuation.isBuildingCapacity)
      valuation.basis == ValuationBasis.earnings
          ? strings.napkinCaveatBuildingEarnings(
              _formatRepo.ratio(valuation.capexToDepreciation!),
            )
          : strings.napkinCaveatBuilding(
              _formatRepo.ratio(valuation.capexToDepreciation!),
            ),
    if (valuation.isMarginEroding)
      strings.napkinCaveatMargin(
        _formatRepo.ratio(valuation.marginChangePoints!.abs()),
      ),
  ];
}

/// The figures that came from the quarter, as a phrase, or `null` where none
/// of those the steps use did.
String? _quarterFigures(
  AppLocalizations strings, {
  required bool sales,
  required bool cashAndDebt,
  required bool shares,
}) {
  final named = [
    if (sales) strings.napkinQuarterSales,
    if (cashAndDebt) strings.napkinQuarterCashAndDebt,
    if (shares) strings.napkinQuarterShareCount,
  ];
  return switch (named) {
    [] => null,
    [final only] => only,
    [final first, final second] => strings.napkinListOfTwo(first, second),
    [final first, final second, final third, ...] => strings.napkinListOfThree(
      first,
      second,
      third,
    ),
  };
}

class _NumberedStep extends StatelessWidget {
  const _NumberedStep({required this.number, required this.step});

  final int number;
  final _Step step;

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
              Text(step.title).small().semiBold(),
              _Sentence(step.body),
            ],
          ),
        ),
      ],
    );
  }
}

/// A line of the explanation, with its figures picked out.
///
/// The prose is scaffolding; the numbers are the point. Left uniformly muted,
/// a reader has to parse the sentence to find them, which is the opposite of
/// what a worked example is for.
class _Sentence extends StatelessWidget {
  const _Sentence(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    // Weight only, no colour: the figures inherit the muted colour of the
    // prose around them. Darkening them as well made every step read as half
    // heading, half sentence.
    const emphasis = TextStyle(fontWeight: ThemeRepo.napkinFigureWeight);

    final spans = <TextSpan>[];
    var at = 0;
    for (final match in _figure.allMatches(text)) {
      if (match.start > at) {
        spans.add(TextSpan(text: text.substring(at, match.start)));
      }
      spans.add(TextSpan(text: match[0], style: emphasis));
      at = match.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));

    return Text.rich(TextSpan(children: spans)).muted().small();
  }
}

/// A figure in the prose: an amount, a count, a rate or a multiple. The
/// optional tail covers `$3.71T`, `24.5%` and `18×` alike.
final RegExp _figure = RegExp(r'\$?\d[\d,]*(?:\.\d+)?(?:[KMBT]\b|%|×)?');

class _Caveats extends StatelessWidget {
  const _Caveats(this.caveats);

  final List<String> caveats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: ThemeRepo.spaceSmall,
      children: [
        Row(
          spacing: ThemeRepo.spaceSmall,
          children: [
            Icon(
              LucideIcons.triangleAlert,
              color: _themeRepo.unknown(context.theme),
            ).iconXSmall(),
            Text(context.strings.napkinCaveatTitle).small().semiBold(),
          ],
        ),
        for (final caveat in caveats) Text(caveat).muted().xSmall(),
      ],
    );
  }
}
