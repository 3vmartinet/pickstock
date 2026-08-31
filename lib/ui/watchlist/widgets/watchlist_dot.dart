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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _themeRepo.watchlistColour(context.theme, colourIndex),
        shape: BoxShape.circle,
      ),
    );
  }
}
