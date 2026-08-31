import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The single source of truth for spacing, radii, colours and motion.
///
/// Widgets read from here rather than constructing `Color`, `TextStyle` or
/// `EdgeInsets` values inline, so a change to the look of the app is a change
/// to this file alone.
class ThemeRepo {
  static const double _radius = 0.65;

  // Spacing scale. Every gap in the app is one of these.
  static const double spaceXSmall = 4;
  static const double spaceSmall = 8;
  static const double spaceMedium = 16;
  static const double spaceLarge = 24;
  static const double spaceXLarge = 32;
  static const double spaceXXLarge = 48;

  // Layout.
  static const double contentMaxWidth = 1180;
  static const double searchFieldMaxWidth = 420;
  static const double metricCardMinWidth = 240;
  static const double checkCardMinWidth = 260;

  /// The narrowest the eight-column history table can be before its figures
  /// start wrapping mid-number. Below this the report shows one card per
  /// fiscal year instead.
  static const double historyTableMinWidth = 960;

  // The browsable ticker directory.
  static const double masterDetailMinWidth = 1000;
  static const double masterListWidth = 400;
  // The ingest gate.
  static const double progressRingSize = 148;
  static const double progressRingStroke = 8;
  static const double progressRingFigureSize = 44;
  static const double ingestPanelMaxWidth = 520;
  static const double stageMarkerSize = 28;
  static const double glyphTint = 0.12;
  static const double stagePulseScale = 1.12;
  static const Duration stagePulseDuration = Duration(milliseconds: 900);

  static const double filterFieldMaxWidth = 320;
  static const double sortSelectMaxWidth = 280;
  static const double sortPopupMaxHeight = 320;

  /// Square tiles, sized so a company name gets a few readable lines and a
  /// wide window still fits several columns.
  static const double tickerTileMaxWidth = 190;
  static const int tickerNameMaxLines = 3;

  static const EdgeInsets cardPadding = EdgeInsets.all(spaceLarge);
  static const EdgeInsets compactCardPadding = EdgeInsets.all(spaceMedium);
  static const EdgeInsets tableCellPadding = EdgeInsets.symmetric(
    horizontal: spaceMedium,
    vertical: spaceSmall + spaceXSmall,
  );

  // Motion.
  static const Duration entranceDuration = Duration(milliseconds: 320);
  static const Duration entranceStagger = Duration(milliseconds: 55);
  static const double entranceSlide = 0.12;

  /// A headline figure is set tight and heavy so it reads at a glance.
  static const double headlineFigureHeight = 1.1;
  static const FontWeight headlineFigureWeight = FontWeight.w700;

  ThemeData get lightTheme =>
      const ThemeData(colorScheme: ColorSchemes.lightSlate, radius: _radius);

  ThemeData get darkTheme => const ThemeData.dark(
    colorScheme: ColorSchemes.darkSlate,
    radius: _radius,
  );

  /// Colour for a figure that is good news: growth, profit, net cash.
  Color positive(ThemeData theme) => theme.brightness == Brightness.dark
      ? Colors.emerald.shade400
      : Colors.emerald.shade600;

  /// Colour for a figure that is bad news: contraction, a loss, net debt.
  Color negative(ThemeData theme) => theme.brightness == Brightness.dark
      ? Colors.rose.shade400
      : Colors.rose.shade600;

  /// Colour for a figure the filings do not report.
  Color unknown(ThemeData theme) => theme.colorScheme.mutedForeground;

  /// Picks between [positive], [negative] and [unknown] for a tri-state value.
  Color forOutcome(ThemeData theme, {required bool? isGood}) =>
      switch (isGood) {
        true => positive(theme),
        false => negative(theme),
        null => unknown(theme),
      };
}
