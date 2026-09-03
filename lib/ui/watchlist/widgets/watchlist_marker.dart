import 'package:get_it/get_it.dart';
import 'package:pickstock/data/watchlist/watchlist.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/watchlist/widgets/watchlist_dot.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// The mark that stands for one list beside a company.
///
/// A star for the starred list and a dot for every other, both in the list's
/// own colour. The starred list is the one the star on a report writes into,
/// so it is the list a tile is most often marked for — and among a row of
/// identical dots there is nothing to say which one it was. The same glyph
/// the report's own star uses, so the mark on the tile and the control that
/// put it there are recognisably the same thing.
class WatchlistMarker extends StatelessWidget {
  const WatchlistMarker({super.key, required this.list});

  final Watchlist list;

  @override
  Widget build(BuildContext context) {
    if (!list.isDefault) {
      return WatchlistDot(colourIndex: list.colourIndex);
    }
    return Icon(
      BootstrapIcons.starFill,
      size: ThemeRepo.watchlistStarSize,
      color: _themeRepo.watchlistColour(context.theme, list.colourIndex),
    );
  }
}
