import 'package:get_it/get_it.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

ThemeRepo get _themeRepo => GetIt.I.get<ThemeRepo>();

/// A large ring with the percentage counting up inside it.
///
/// The ring carries the run's weight visually, so it is deliberately the
/// biggest thing on screen; the stage list underneath says what it measures.
class IngestProgressRing extends StatelessWidget {
  const IngestProgressRing({super.key, required this.fraction, this.icon});

  /// `null` where the stage cannot be measured, which shows an indeterminate
  /// ring rather than a misleading zero.
  final double? fraction;

  /// Shown in place of a percentage when there is no fraction.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final percent = fraction == null ? null : (fraction! * 100).round();

    return SizedBox.square(
      dimension: ThemeRepo.progressRingSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // A full, faint ring behind the value gives the arc something to
          // travel along rather than appearing out of nowhere.
          CircularProgressIndicator(
            value: 1,
            size: ThemeRepo.progressRingSize,
            strokeWidth: ThemeRepo.progressRingStroke,
            color: context.theme.colorScheme.muted,
          ),
          CircularProgressIndicator(
            value: fraction,
            size: ThemeRepo.progressRingSize,
            strokeWidth: ThemeRepo.progressRingStroke,
            color: _themeRepo.positive(context.theme),
          ),
          if (percent == null)
            Icon(icon).iconXLarge().iconMutedForeground()
          else
            _Percentage(percent: percent),
        ],
      ),
    );
  }
}

class _Percentage extends StatelessWidget {
  const _Percentage({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Ticking rather than snapping: the digits settle into place, which
        // reads as motion even between updates.
        NumberTicker(
          number: percent,
          initialNumber: 0,
          formatter: (value) => value.round().toString(),
          style: TextStyle(
            fontSize: ThemeRepo.progressRingFigureSize,
            fontWeight: ThemeRepo.headlineFigureWeight,
            height: ThemeRepo.headlineFigureHeight,
            color: context.theme.colorScheme.foreground,
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: ThemeRepo.spaceSmall),
          child: Text('%'),
        ).muted().small(),
      ],
    );
  }
}
