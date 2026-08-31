import 'package:flutter/services.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:pickstock/ui/snapshot/snapshot_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The field takes company names as well as symbols, so it is long enough for
/// the longest registrant name rather than the seven characters a symbol needs.
const int _maxQueryLength = 80;

/// The always-visible ticker entry, pinned under the app bar.
class TickerSearchBar extends StatelessWidget {
  const TickerSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.isCompact
            ? ThemeRepo.spaceMedium
            : ThemeRepo.spaceXLarge,
        vertical: ThemeRepo.spaceMedium,
      ),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: ThemeRepo.contentMaxWidth),
        // Aligned left rather than stretched: the field stops at its own
        // maximum on a wide window. There is no submit button — enter, or a
        // suggestion, runs the lookup.
        child: const Row(children: [Flexible(child: _TickerField())]),
      ),
    );
  }
}

class _TickerField extends StatelessWidget {
  const _TickerField();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<SnapshotViewModel>();
    final suggestions = context.select<SnapshotViewModel, List<String>>(
      (model) => model.suggestionLabels,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: ThemeRepo.searchFieldMaxWidth,
      ),
      child: AutoComplete(
        suggestions: suggestions,
        // The row holds `SYMBOL · Company Name`; only the symbol belongs in
        // the field, and picking a row runs that lookup straight away.
        mode: AutoCompleteMode.replaceAll,
        completer: viewModel.acceptSuggestion,
        child: TextField(
          controller: viewModel.tickerController,
          placeholder: Text(context.strings.searchPlaceholder),
          textInputAction: TextInputAction.search,
          maxLength: _maxQueryLength,
          onChanged: viewModel.onQueryChanged,
          onSubmitted: (_) => viewModel.submitTypedTicker(),
          features: const [
            InputFeature.leading(Icon(LucideIcons.search)),
            InputFeature.clear(),
          ],
        ),
      ),
    );
  }
}
