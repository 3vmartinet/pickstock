import 'dart:math' as math;

import 'package:get_it/get_it.dart';
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/data/valuation/valuation.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:pickstock/ui/snapshot/widgets/price_editor.dart';
import 'package:provider/provider.dart';
import 'package:pickstock/ui/widgets/hint_tooltip.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();
ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// Where the price sits against the range the filings support, drawn to scale.
///
/// A range and a percentage to its midpoint asked the reader to do the join
/// themselves, against a midpoint the arithmetic never produced. A track with
/// the band on it and the price marked answers "how far, which side" at a
/// glance, and the figures underneath give each bound its own distance.
class FairValueGauge extends StatelessWidget {
  const FairValueGauge({super.key});

  @override
  Widget build(BuildContext context) {
    final valuation = context.select<SnapshotViewModel, Valuation?>(
      (viewModel) => viewModel.valuation,
    );
    final low = valuation?.fairValueLow;
    final high = valuation?.fairValueHigh;
    // A band of zero width is a company whose debts swallow it; there is no
    // range to draw, and the verdict above already says so.
    if (valuation == null || low == null || high == null || high <= low) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: ThemeRepo.spaceMedium,
      children: [
        _Track(valuation: valuation, low: low, high: high),
        _Bounds(valuation: valuation, low: low, high: high),
      ],
    );
  }
}

/// The bar: a muted axis, the fair range as a band on it, and the price as a
/// marker.
class _Track extends StatelessWidget {
  const _Track({
    required this.valuation,
    required this.low,
    required this.high,
  });

  final Valuation valuation;
  final double low;
  final double high;

  @override
  Widget build(BuildContext context) {
    final price = valuation.pricePerShare;
    final accent = _themeRepo.forOutcome(
      context.theme,
      isGood: valuation.verdict.isGood,
    );

    // The axis has to hold the band and the price, whichever is further out,
    // with a margin so a marker at an extreme is not clipped in half.
    final axisLow = math.min(price, low);
    final axisHigh = math.max(price, high);
    final margin = (axisHigh - axisLow) * _axisMargin;
    final start = axisLow - margin;
    final span = axisHigh + margin - start;

    double fractionOf(double value) => ((value - start) / span).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bandStart = fractionOf(low) * width;
        final bandEnd = fractionOf(high) * width;
        final markerAt = fractionOf(price) * width;

        return SizedBox(
          height: ThemeRepo.gaugeHeight,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: width,
                  height: ThemeRepo.gaugeTrackHeight,
                  decoration: BoxDecoration(
                    color: context.theme.colorScheme.muted,
                    borderRadius: context.theme.borderRadiusSm,
                  ),
                ),
              ),
              Positioned(
                left: bandStart,
                width: math.max(bandEnd - bandStart, ThemeRepo.gaugeMinBand),
                top: (ThemeRepo.gaugeHeight - ThemeRepo.gaugeTrackHeight) / 2,
                height: ThemeRepo.gaugeTrackHeight,
                child: DecoratedBox(
                  key: fairValueBandKey,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: _bandOpacity),
                    borderRadius: context.theme.borderRadiusSm,
                  ),
                ),
              ),
              Positioned(
                // Centred on the price, and kept inside the track at either
                // extreme rather than hanging off it.
                left: (markerAt - ThemeRepo.gaugeMarkerWidth / 2).clamp(
                  0.0,
                  width - ThemeRepo.gaugeMarkerWidth,
                ),
                width: ThemeRepo.gaugeMarkerWidth,
                height: ThemeRepo.gaugeHeight,
                child: DecoratedBox(
                  key: fairValuePriceMarkerKey,
                  decoration: BoxDecoration(
                    color: context.theme.colorScheme.foreground,
                    borderRadius: context.theme.borderRadiusSm,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The three numbers the bar is drawn from, in the order they appear on it.
class _Bounds extends StatelessWidget {
  const _Bounds({
    required this.valuation,
    required this.low,
    required this.high,
  });

  final Valuation valuation;
  final double low;
  final double high;

  @override
  Widget build(BuildContext context) {
    final price = valuation.pricePerShare;
    final marks = <_Mark>[
      _Mark(
        at: low,
        label: context.strings.labelRangeLow,
        percent: valuation.percentToLow,
      ),
      _Mark(
        at: high,
        label: context.strings.labelRangeHigh,
        percent: valuation.percentToHigh,
      ),
      _Mark(at: price, label: context.strings.labelPriceToday, isPrice: true),
    ]..sort((a, b) => a.at.compareTo(b.at));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < marks.length; index++)
          Expanded(
            child: _MarkColumn(
              mark: marks[index],
              // Read left to right like the bar above: the first sits under
              // its left end, the last under its right.
              alignment: switch (index) {
                0 => CrossAxisAlignment.start,
                1 => CrossAxisAlignment.center,
                _ => CrossAxisAlignment.end,
              },
            ),
          ),
      ],
    );
  }
}

class _Mark {
  const _Mark({
    required this.at,
    required this.label,
    this.percent,
    this.isPrice = false,
  });

  final double at;
  final String label;

  /// How far the price has to move to reach this mark. Absent on the price
  /// itself, which is where the moving starts.
  final double? percent;
  final bool isPrice;
}

class _MarkColumn extends StatelessWidget {
  const _MarkColumn({required this.mark, required this.alignment});

  final _Mark mark;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final percent = mark.percent;

    final value = Text(_formatRepo.price(mark.at))
        .small()
        .semiBold(
          // The price is stated, not judged: the colour on this row means
          // "which way would it have to move", and it moves nowhere.
          color: mark.isPrice
              ? context.theme.colorScheme.foreground
              : _themeRepo.forOutcome(
                  context.theme,
                  isGood: (percent ?? 0) >= 0,
                ),
        )
        .singleLine();

    return Column(
      crossAxisAlignment: alignment,
      spacing: ThemeRepo.spaceXSmall,
      children: [
        if (mark.isPrice)
          const _PriceLabel()
        else
          Text(mark.label).muted().xSmall().singleLine(),
        // Clicking the price is how one is typed by hand. The bounds are
        // derived, so there is nothing to type there.
        if (mark.isPrice)
          _Editable(key: priceValueKey, child: value)
        else
          value,
        if (percent != null)
          Text(_formatRepo.signedPercent(percent)).muted().xSmall().singleLine()
        else
          const _PriceProvenance(),
      ],
    );
  }
}

/// Makes its child open the price editor, without touching how it looks.
class _Editable extends StatelessWidget {
  const _Editable({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      tooltip: HintTooltip(context.strings.hintSharePrice).call,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => showPriceEditor(context),
          child: child,
        ),
      ),
    );
  }
}

/// The price's own heading, with the two things you can do to it.
///
/// Sized and coloured exactly like the bounds' headings beside it, so the row
/// still reads as three of the same thing rather than one with a toolbar.
class _PriceLabel extends StatelessWidget {
  const _PriceLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: ThemeRepo.spaceXSmall,
      children: [
        Flexible(
          child: Text(context.strings.labelPriceToday)
              .muted()
              .xSmall()
              .singleLine(),
        ),
        const _RefreshQuoteButton(),
        Tooltip(
          tooltip: HintTooltip(context.strings.hintSharePrice).call,
          child: const Icon(LucideIcons.info)
              .iconXSmall()
              .iconMutedForeground(),
        ),
      ],
    );
  }
}

/// Only shown where quotes are available; without a key there is nothing to
/// refresh from.
class _RefreshQuoteButton extends StatelessWidget {
  const _RefreshQuoteButton();

  @override
  Widget build(BuildContext context) {
    final canFetch = context.select<SnapshotViewModel, bool>(
      (viewModel) => viewModel.canFetchQuotes,
    );
    if (!canFetch) return const SizedBox.shrink();

    final isQuoting = context.select<SnapshotViewModel, bool>(
      (viewModel) => viewModel.isQuoting,
    );

    return Tooltip(
      tooltip: HintTooltip(context.strings.quoteRefresh).call,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: isQuoting
              ? null
              : context.read<SnapshotViewModel>().refreshQuote,
          child: isQuoting
              ? const SizedBox.square(
                  dimension: ThemeRepo.inlineSpinnerSize,
                  child: CircularProgressIndicator(),
                )
              : const Icon(LucideIcons.refreshCw)
                    .iconXSmall()
                    .iconMutedForeground(),
        ),
      ),
    );
  }
}

/// One line saying where the price came from, and when it was true.
///
/// Sits in the slot the bounds use for their percentage, so the three columns
/// stay the same shape and the provenance reads as the price's own footnote.
class _PriceProvenance extends StatelessWidget {
  const _PriceProvenance();

  @override
  Widget build(BuildContext context) {
    final isQuoting = context.select<SnapshotViewModel, bool>(
      (viewModel) => viewModel.isQuoting,
    );
    if (isQuoting) {
      return Text(context.strings.quoteFetching).muted().xSmall().singleLine();
    }

    // A failure is the more useful thing to say: it explains why the price on
    // screen is old.
    final failure = context.select<SnapshotViewModel, QuoteFailure?>(
      (viewModel) => viewModel.quoteFailure,
    );
    if (failure != null) {
      return Text(failure.describe(context.strings)).muted().xSmall();
    }

    final quote = context.select<SnapshotViewModel, Quote?>(
      (viewModel) => viewModel.quote,
    );
    if (quote == null) return const SizedBox.shrink();

    return Text(_describe(context, quote)).muted().xSmall().singleLine();
  }

  String _describe(BuildContext context, Quote quote) {
    if (!quote.isQuoted) return context.strings.quoteEntered;
    final age = DateTime.now().difference(quote.asOf);
    final time = _formatRepo.timeOrDate(quote.asOf);
    // Past the refresh window the price is history, not a live quote, and is
    // labelled as such — the market has moved since.
    return age > quoteFreshness
        ? context.strings.quoteStale(time)
        : context.strings.quoteLive(time);
  }
}

/// The band and the marker are keyed so a test can measure each one directly.
/// Both are plain decorated boxes, and so is the track they sit on, which
/// makes finding them by type a question of paint order — and paint order is
/// exactly the sort of thing that changes without anyone noticing.
const Key fairValueBandKey = Key('fairValueBand');
const Key fairValuePriceMarkerKey = Key('fairValuePriceMarker');

/// The price itself, which opens the editor when clicked.
const Key priceValueKey = Key('priceValue');

/// Breathing room at each end of the axis, as a share of the span.
const double _axisMargin = 0.08;

/// How strongly the band tints the track.
const double _bandOpacity = 0.35;
