import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:pickstock/data/quote/quote.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/format_repo.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

FormatRepo get _formatRepo => GetIt.I.get<FormatRepo>();

/// Where the share price comes from: quoted if a key is configured, typed
/// otherwise, and typed over whenever the user wants to.
///
/// EDGAR files statements, not quotes, so this is the only figure in the report
/// that does not come out of the filings — which is why it says where it came
/// from and when.
class SharePriceField extends StatelessWidget {
  const SharePriceField({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: ThemeRepo.spaceXSmall,
      children: [_PriceRow(), _PriceProvenance()],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<SnapshotViewModel>();

    return Row(
      spacing: ThemeRepo.spaceSmall,
      children: [
        SizedBox(
          width: ThemeRepo.priceFieldWidth,
          child: TextField(
            controller: viewModel.priceController,
            placeholder: Text(context.strings.placeholderSharePrice),
            onChanged: viewModel.enterPrice,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // A comma passes: it is the decimal point in half the world, and
            // the view model reads it as one.
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            features: const [
              InputFeature.leading(Icon(LucideIcons.dollarSign)),
              InputFeature.clear(),
            ],
          ),
        ),
        const _RefreshQuoteButton(),
        Tooltip(
          tooltip: TooltipContainer(child: Text(context.strings.hintSharePrice))
              .call,
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
      tooltip: TooltipContainer(child: Text(context.strings.quoteRefresh)).call,
      child: GhostButton(
        enabled: !isQuoting,
        onPressed: context.read<SnapshotViewModel>().refreshQuote,
        child: isQuoting
            ? const SizedBox.square(
                dimension: ThemeRepo.inlineSpinnerSize,
                child: CircularProgressIndicator(),
              )
            : const Icon(LucideIcons.refreshCw).iconXSmall(),
      ),
    );
  }
}

/// One line saying where the price came from, and when it was true.
class _PriceProvenance extends StatelessWidget {
  const _PriceProvenance();

  @override
  Widget build(BuildContext context) {
    final isQuoting = context.select<SnapshotViewModel, bool>(
      (viewModel) => viewModel.isQuoting,
    );
    if (isQuoting) {
      return Text(context.strings.quoteFetching).muted().xSmall();
    }

    // A failure is the more useful thing to say: it explains why the price on
    // screen is old, or why there is none.
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

    return Text(_describe(context, quote)).muted().xSmall();
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
