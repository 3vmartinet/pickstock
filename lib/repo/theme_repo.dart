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

  /// The star standing in for that dot on the starred list. Larger than the
  /// dot because a star is mostly the gaps between its points: at the dot's
  /// own size it reads as a smudge rather than as a star.
  static const double watchlistStarSize = 12;

  /// A swatch in the colour picker, big enough to tap.
  static const double watchlistSwatchSize = 28;
  static const double watchlistSwatchRing = 2;

  /// Columns of a report row.
  static const double reportRankWidth = 28;
  static const double reportTickerWidth = 72;
  static const double reportFigureWidth = 128;

  /// The jobs panel: wide enough for a report's name and its date on one
  /// line, and capped so a long history scrolls rather than filling the app.
  static const double jobsPanelWidth = 360;
  static const double jobsPanelMaxListHeight = 260;

  /// A tooltip wraps at about a comfortable line length rather than running
  /// the width of the window.
  static const double tooltipMaxWidth = 380;

  /// A form dialog wide enough for a name field without stretching to the
  /// window.
  static const double dialogWidth = 340;

  /// The list popover, sized so a dozen lists scroll rather than fill the
  /// screen.
  static const double watchlistPopupWidth = 280;
  static const double watchlistPopupMaxHeight = 360;

  /// The industry menu behind a sector chip. Height only: the menu takes the
  /// width its longest title needs so every one of them sits on a single
  /// line, and a sector can hold forty of them.
  static const double industryPopupMaxHeight = 360;

  /// How many list dots a tile shows before it stops.
  static const int watchlistDotsPerTile = 3;

  /// Between the company card and the tabs under it. Half a section's spacing:
  /// the two are one block of chrome, not two sections.
  static const double reportTabsGap = spaceSmall + spaceXSmall;

  /// Figures in the worked example are set apart from the prose around them.
  static const FontWeight napkinFigureWeight = FontWeight.w600;

  /// The numbered bullet beside each step of the worked example.
  static const double napkinStepSize = 22;

  /// The verdict and ratios take a little more room than the explanation
  /// beside them, which is mostly text and reads better narrow.
  static const int valuationCardsFlex = 3;
  static const int napkinFlex = 2;

  /// Below this the valuation cards and the worked example stack instead of
  /// sitting side by side; two narrow columns are worse than one wide one.
  static const double napkinSideBySideMinWidth = 900;

  /// Below this the expectations tab's two cards stack: level, each would be
  /// too narrow for the three price cases one of them lays out in a row.
  static const double expectationsSideBySideMinWidth = 820;

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

  /// The pane a source opens in, beside the report. Wide enough for a news
  /// page to lay out as its publisher intended rather than as a phone.
  static const double sourcePaneWidth = 520;
  static const double sourcePaneMinWidth = 320;

  /// The most the developments panel may take of the header's row.
  ///
  /// Capped rather than given the slack: the panel would happily swallow a
  /// wide window and leave the company's own name in an ellipsis, and past
  /// this width the captions are whole anyway so the room does nothing for
  /// them. Flexible under the cap, so on a narrow pane the two share the row
  /// instead of the panel taking a fixed bite out of it.
  static const double eventsPanelMaxWidth = 380;

  /// How faint the developments panel's fill is against the card it sits in,
  /// and how tightly it is packed. Tighter than a card: it shares a row with
  /// the company's name, and every pixel of padding is a pixel a caption does
  /// not get.
  static const double eventsPanelTint = 0.5;
  static const EdgeInsets eventsPanelPadding = EdgeInsets.symmetric(
    horizontal: spaceSmall + spaceXSmall,
    vertical: spaceSmall,
  );

  /// How old an answer is, said beside it. Small: it is a footnote on the
  /// answer, not part of it.
  static const double noteAgeFontSize = 11;

  /// One development in the header's panel. Under the body text and under the
  /// industry line beside it: three of these share the row with the company's
  /// name, and they are supporting detail rather than part of the reading.
  static const double eventFontSize = 11;

  /// The stamp in the app bar saying which day's data is loaded: its type,
  /// set below the scale's smallest step because it is a footnote on the
  /// window rather than part of the reading, and the box it sits in.
  static const double dataStampFontSize = 10;
  static const double dataStampLineHeight = 1.25;
  static const EdgeInsets dataStampPadding = EdgeInsets.symmetric(
    horizontal: spaceSmall,
    vertical: spaceXSmall,
  );

  /// The dot that marks an update as new, and how far it sits outside the
  /// button's top-left corner. Small and unadorned: it is a mark, not a
  /// second thing to read.
  static const double updateBadgeSize = 8;
  static const double updateBadgeOffset = -2;

  /// The sliver of progress along the bottom edge of the download button, and
  /// how faint its unfilled track is. Thin enough to read as part of the
  /// button's border rather than as a bar laid across it.
  static const double updateProgressHeight = 3;
  static const double updateProgressTrack = 0.3;

  /// One turn of the app bar's refresh arrows while an update downloads
  /// behind the app. Slow enough to read as "still going" rather than as
  /// something urgently spinning.
  static const Duration updateSpinDuration = Duration(milliseconds: 1600);

  static const double filterFieldMaxWidth = 320;
  static const double sortPopupMaxHeight = 320;

  /// The most the sort control may take, however long its longest label
  /// measures.
  static const double sortSelectMaxWidth = 400;

  /// What a `Select` costs around its label: the padding either side, the gap
  /// before the chevron, and the chevron. Added to the measured width of the
  /// longest option to size the control.
  static const double selectChromeWidth = 56;

  /// Tiles are twice as wide as tall: the symbol and name stack on the left
  /// with the ranked figure on the right, which packs far more of them into a
  /// pane than a square does.
  static const double tickerTileMaxWidth = 240;

  /// The ring on the tile whose report is open beside the list. Two pixels
  /// rather than the one every other tile carries: at a glance down a pane of
  /// a hundred tiles, a ring the same weight as all the others is not a mark
  /// at all. Painted inside the tile's bounds, so a selection moving from one
  /// tile to another shifts nothing in the grid.
  static const double tickerTileSelectedRing = 2;
  static const double tickerTileAspectRatio = 2;

  /// Flatter where only one tile fits across. A single column takes the whole
  /// pane, and at the ratio above that makes each tile nearly as tall as the
  /// pane is wide — a column of near-empty boxes with a handful of companies
  /// on screen.
  ///
  /// Three rather than four: four left a long registrant name with nowhere to
  /// go, and it ran out of the bottom of the tile mid-letter. Three still
  /// puts half as much again on screen and leaves the second line room to
  /// finish.
  static const double tickerTileWideAspectRatio = 3;

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

  /// Colour for something finished and waiting on the user, which is neither
  /// good news nor bad: an update downloaded but not yet loaded.
  Color caution(ThemeData theme) => theme.brightness == Brightness.dark
      ? Colors.orange.shade400
      : Colors.orange.shade600;

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
