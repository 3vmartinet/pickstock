import 'package:get_it/get_it.dart';
import 'package:pickstock/data/snapshot/fiscal_year_figures.dart';
import 'package:pickstock/data/valuation/growth_expectation.dart';
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
    final expectation = context.select<SnapshotViewModel, GrowthExpectation?>(
      (viewModel) => viewModel.growthExpectation,
    );
    if (valuation == null || figures == null) return const SizedBox.shrink();

    final steps = _stepsFor(context.strings, valuation, figures);
    if (steps.isEmpty) return const SizedBox.shrink();

    final caveats = _caveatsFor(
      context.strings,
      valuation,
      figures,
      expectation,
    );

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
List<_Step> _stepsFor(
  AppLocalizations strings,
  Valuation valuation,
  FiscalYearFigures figures,
) {
  final shares = valuation.sharesOutstanding;
  final marketCap = valuation.marketCap;
  final enterpriseValue = valuation.enterpriseValue;
  final basis = valuation.basisAmount;
  final low = valuation.fairValueLow;
  final high = valuation.fairValueHigh;
  if (shares == null ||
      marketCap == null ||
      enterpriseValue == null ||
      basis == null ||
      basis <= 0 ||
      low == null ||
      high == null) {
    return const [];
  }

  final netDebt = figures.netDebt ?? 0;
  final money = _formatRepo.compactCurrency;
  final count = _formatRepo.compactCount;
  final price = _formatRepo.price;
  final years = _formatRepo.ratio;

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
      body: strings.napkinStep2Body(
        figures.revenue == null ? '—' : money(figures.revenue!),
        money(basis),
      ),
    ),
    (
      title: netDebt >= 0
          ? strings.napkinStep3TitleDebt
          : strings.napkinStep3TitleCash,
      body: netDebt >= 0
          ? strings.napkinStep3BodyDebt(money(netDebt), money(basis))
          : strings.napkinStep3BodyCash(money(netDebt.abs()), money(basis)),
    ),
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
      body: valuation.creditedGrowthPercent <= 0
          ? strings.napkinStep5BodyFlat
          : strings.napkinStep5BodyGrowing(
              _formatRepo.percent(valuation.creditedGrowthPercent),
              years(valuation.growthPremiumMultiple),
              years(valuation.lowMultiple),
              years(valuation.highMultiple),
            ),
    ),
    (
      title: strings.napkinStep6Title,
      body: strings.napkinStep6Body(
        years(valuation.lowMultiple),
        years(valuation.highMultiple),
        money(basis),
        money(basis * valuation.lowMultiple),
        money(basis * valuation.highMultiple),
        count(shares),
        price(low),
        price(high),
      ),
    ),
    (
      title: strings.napkinStep7Title,
      body: switch (valuation.verdict) {
        ValuationVerdict.undervalued => strings.napkinStep7BodyUnder(
          price(valuation.pricePerShare),
          price(low),
          price(high),
        ),
        ValuationVerdict.overvalued => strings.napkinStep7BodyOver(
          price(valuation.pricePerShare),
          price(low),
          price(high),
        ),
        _ => strings.napkinStep7BodyFair(
          price(valuation.pricePerShare),
          price(low),
          price(high),
        ),
      },
    ),
  ];
}

/// The things that would mislead a reader who took the steps at face value.
List<String> _caveatsFor(
  AppLocalizations strings,
  Valuation valuation,
  FiscalYearFigures figures,
  GrowthExpectation? expectation,
) {
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
      if (valuation.sharesLastFiled case final filed?)
        strings.napkinCaveatShareCountStale('${filed.year}')
      else
        strings.napkinCaveatShareCount,
    if (valuation.basis == ValuationBasis.earnings)
      strings.napkinCaveatEarnings,
    if (expectation != null && expectation.isBuildingCapacity(figures))
      strings.napkinCaveatBuilding(
        _formatRepo.ratio(figures.capexToDepreciation!),
      ),
    if (expectation != null && expectation.isMarginEroding)
      strings.napkinCaveatMargin(
        _formatRepo.ratio(expectation.marginChangePoints!.abs()),
      ),
  ];
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
