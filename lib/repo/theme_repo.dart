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

  /// The inset every page-level row starts at, horizontally and vertically.
  /// Read through `context.pageGutter`, which is where the reasoning lives.
  static const double pageGutter = spaceMedium;

  // Layout.
  static const double contentMaxWidth = 1180;
  static const double searchFieldMaxWidth = 420;
  static const double metricCardMinWidth = 240;
  static const double checkCardMinWidth = 260;

  /// Narrow enough that the five valuation ratios fit one row on a wide
  /// window and two on a split pane.
  static const double ratioCardMinWidth = 132;

  /// A price field only ever holds a handful of digits.
  static const double priceFieldWidth = 168;

  /// The fair-value bar: the marker stands proud of the track it sits on.
  static const double gaugeHeight = 22;
  static const double gaugeTrackHeight = 10;
  static const double gaugeMarkerWidth = 3;

  /// A band narrower than this would vanish; a company priced far outside its
  /// range still deserves to see where the range is.
  static const double gaugeMinBand = 4;

  /// The coloured dot marking a list, on a chip or a tile.
  static const double watchlistDotSize = 8;

  /// A swatch in the colour picker, big enough to tap.
  static const double watchlistSwatchSize = 28;
  static const double watchlistSwatchRing = 2;

  /// A form dialog wide enough for a name field without stretching to the
  /// window.
  static const double dialogWidth = 340;

  /// The list popover, sized so a dozen lists scroll rather than fill the
  /// screen.
  static const double watchlistPopupWidth = 280;
  static const double watchlistPopupMaxHeight = 360;

  /// How many list dots a tile shows before it stops.
  static const int watchlistDotsPerTile = 3;

  /// The numbered bullet beside each step of the worked example.
  static const double napkinStepSize = 22;

  /// The verdict and ratios take a little more room than the explanation
  /// beside them, which is mostly text and reads better narrow.
  static const int valuationCardsFlex = 3;
  static const int napkinFlex = 2;

  /// Below this the valuation cards and the worked example stack instead of
  /// sitting side by side; two narrow columns are worse than one wide one.
  static const double napkinSideBySideMinWidth = 900;

  /// A spinner sized to sit inside a button without changing its height.
  static const double inlineSpinnerSize = 14;

  /// The narrowest the eight-column history table can be before its figures
  /// start wrapping mid-number. Below this the report shows one card per
  /// fiscal year instead.
  static const double historyTableMinWidth = 960;

  // The browsable ticker directory.
  static const double masterDetailMinWidth = 1000;

  /// The list pane starts here and can be dragged wider to fit more columns.
  /// The maximum leaves the report enough width to stay readable.
  static const double masterListWidth = 420;
  static const double masterListMinWidth = 260;
  static const double masterListMaxWidth = 900;
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

  /// The sort popup is sized to its longest option — "Revenue growth, 10-year
  /// annualised" — rather than to the button, which wrapped every option over
  /// three lines.
  static const double sortPopupMinWidth = 300;

  /// Tiles are twice as wide as tall: the symbol and name stack on the left
  /// with the ranked figure on the right, which packs far more of them into a
  /// pane than a square does.
  static const double tickerTileMaxWidth = 240;
  static const double tickerTileAspectRatio = 2;
  static const int tickerNameMaxLines = 2;

  /// The app bar's vertical padding. Setting the gutter means setting both
  /// sides — `padding` takes one value — so this replaces shadcn's off-scale
  /// 19.5 with the nearest step on ours.
  static const double appBarVerticalPadding = spaceMedium;

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

  /// The palette a watchlist's indicator is picked from.
  ///
  /// Stored by index rather than by value, so a list keeps its identity when
  /// the theme changes and the dark variant can differ from the light one.
  /// Eight is enough to tell lists apart at a glance and few enough to fit one
  /// row of swatches.
  List<Color> watchlistPalette(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return [
      isDark ? Colors.amber.shade400 : Colors.amber.shade600,
      isDark ? Colors.sky.shade400 : Colors.sky.shade600,
      isDark ? Colors.emerald.shade400 : Colors.emerald.shade600,
      isDark ? Colors.rose.shade400 : Colors.rose.shade600,
      isDark ? Colors.violet.shade400 : Colors.violet.shade600,
      isDark ? Colors.orange.shade400 : Colors.orange.shade600,
      isDark ? Colors.teal.shade400 : Colors.teal.shade600,
      isDark ? Colors.fuchsia.shade400 : Colors.fuchsia.shade600,
    ];
  }

  /// The colour for [index], wrapping rather than throwing: a palette that
  /// shrinks should not strand a list the user already made.
  Color watchlistColour(ThemeData theme, int index) {
    final palette = watchlistPalette(theme);
    return palette[index % palette.length];
  }

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
