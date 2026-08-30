import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/browse/browse_view_model.dart';
import 'package:pickstock/ui/responsive_extensions.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Narrows the directory by symbol or company name.
class TickerFilterBar extends StatelessWidget {
  const TickerFilterBar({super.key});

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
        child: const Row(
          spacing: ThemeRepo.spaceMedium,
          children: [
            Flexible(child: _FilterField()),
            _MatchCount(),
          ],
        ),
      ),
    );
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<BrowseViewModel>();
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: ThemeRepo.filterFieldMaxWidth,
      ),
      child: TextField(
        controller: viewModel.filterController,
        placeholder: Text(context.strings.browseFilterPlaceholder),
        onChanged: viewModel.setQuery,
        features: const [
          InputFeature.leading(Icon(LucideIcons.search)),
          InputFeature.clear(),
        ],
      ),
    );
  }
}

class _MatchCount extends StatelessWidget {
  const _MatchCount();

  @override
  Widget build(BuildContext context) {
    final count = context.select<BrowseViewModel, int>(
      (viewModel) => viewModel.resultCount,
    );
    return Text(context.strings.browseMatchCount(count)).muted().small();
  }
}
