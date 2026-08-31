import 'package:get_it/get_it.dart';
import 'package:pickstock/l10n/localization_extensions.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/watchlist/watchlist_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// One tap to follow a company.
///
/// The star is the starred list's membership and nothing else: there is no
/// separate favourites mechanism to keep in step with the lists.
class WatchlistStar extends StatelessWidget {
  const WatchlistStar({super.key, required this.cik});

  final String cik;

  @override
  Widget build(BuildContext context) {
    final isStarred = context.select<WatchlistViewModel, bool>(
      (viewModel) => viewModel.isStarred(cik),
    );

    return Tooltip(
      tooltip: TooltipContainer(
        child: Text(
          isStarred
              ? context.strings.watchlistStarRemove
              : context.strings.watchlistStarAdd,
        ),
      ).call,
      child: GhostButton(
        density: ButtonDensity.icon,
        onPressed: () => context.read<WatchlistViewModel>().toggleStar(cik),
        // Filled and coloured when on, outlined when off: the state has to be
        // readable without the tooltip.
        child: Icon(
          isStarred ? BootstrapIcons.starFill : LucideIcons.star,
          color: isStarred
              ? _themeRepo.watchlistColour(context.theme, 0)
              : null,
        ),
      ),
    );
  }
}
