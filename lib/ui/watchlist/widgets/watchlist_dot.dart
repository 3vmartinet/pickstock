import 'package:get_it/get_it.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// The coloured mark that identifies one list.
class WatchlistDot extends StatelessWidget {
  const WatchlistDot({
    super.key,
    required this.colourIndex,
    this.size = ThemeRepo.watchlistDotSize,
  });

  final int colourIndex;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Centred so a tight box around it — a menu's leading slot is one —
    // cannot stretch the dot to fill it. Left to itself it came out half as
    // wide again as the star beside it in the same menu.
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _themeRepo.watchlistColour(context.theme, colourIndex),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
