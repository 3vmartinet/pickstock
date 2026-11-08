import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/widgets/column_text_placeholder.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

/// Prose set in newspaper columns: justified, as many columns as the width
/// holds at a comfortable measure, filled one after the other and balanced so
/// they end level.
///
/// A line running the full width of a report pane is a hundred and fifty
/// characters, twice what reads easily: the eye loses its place on the way
/// back to the start of the next. Columns bring the line back to a length the
/// eye can follow without making the text any taller than it needs to be.
///
/// The text is laid out once, justified, at the column's width, as one long
/// column; each column on screen is a slice of it. So the text flows from one
/// column to the next as it would on a page, and a line that ends a column
/// mid-paragraph is justified like any other rather than left ragged, as it
/// would be if each column were set as text of its own.
///
/// One column where there is not the width for two or the text is too short
/// to be worth dividing.
///
/// Laid out and painted directly rather than as a row of text widgets under
/// a layout builder: the cards it sits in are measured for their natural size
/// before they are laid out, which a layout builder cannot answer and this
/// can.
class ColumnText extends LeafRenderObjectWidget {
  const ColumnText(this.text, {super.key, this.isSerif = false});

  final String text;

  /// Set in a serif, as a newspaper's body text is, rather than the app's
  /// own sans: for prose meant to be read as an article.
  final bool isSerif;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderColumnText(
    text: text,
    style: styleOf(context, isSerif: isSerif),
    scaler: MediaQuery.textScalerOf(context),
    direction: Directionality.of(context),
  );

  @override
  void updateRenderObject(BuildContext context, RenderColumnText renderObject) {
    renderObject
      ..text = text
      ..style = styleOf(context, isSerif: isSerif)
      ..scaler = MediaQuery.textScalerOf(context)
      ..direction = Directionality.of(context);
  }

  /// The style the small text extension gives, spelt out, in the serif where
  /// asked. Shared with [ColumnTextPlaceholder], whose lines stand where
  /// these will.
  static TextStyle styleOf(BuildContext context, {required bool isSerif}) {
    final style = DefaultTextStyle.of(context).style
        .merge(context.theme.typography.small);
    if (!isSerif) return style;
    // Built fresh rather than copied: the inherited style carries the app
    // font's package, and a copy would look for the serif inside it.
    return TextStyle(
      color: style.color,
      fontWeight: style.fontWeight,
      // The system's own: Charter on a Mac, a book face drawn for reading on
      // screen, and Georgia wherever it is missing. Nothing to bundle.
      fontFamily: ThemeRepo.serifFamily,
      fontFamilyFallback: ThemeRepo.serifFallback,
      // Charter's lowercase is tall enough to match the sans at its size;
      // only the lines want a little more room, as a book's do.
      fontSize:
          (style.fontSize ?? ThemeRepo.serifFallbackSize) +
          ThemeRepo.serifSizeIncrease,
      height: ThemeRepo.serifLineHeight,
    );
  }
}

/// Lays out and paints a [ColumnText].
class RenderColumnText extends RenderBox {
  RenderColumnText({
    required this._text,
    required this._style,
    required this._scaler,
    required this._direction,
  });

  String _text;
  set text(String value) {
    if (value == _text) return;
    _text = value;
    _forget();
  }

  TextStyle _style;

  /// The style the text is set in.
  @visibleForTesting
  TextStyle get style => _style;
  set style(TextStyle value) {
    if (value == _style) return;
    _style = value;
    _forget();
  }

  TextScaler _scaler;
  set scaler(TextScaler value) {
    if (value == _scaler) return;
    _scaler = value;
    _forget();
  }

  TextDirection _direction;
  set direction(TextDirection value) {
    if (value == _direction) return;
    _direction = value;
    _forget();
  }

  /// The columns last set, and the width they were set for: layout and the
  /// measuring before it ask about the same width, often more than once.
  _Setting? _setting;

  void _forget() {
    _setting?.dispose();
    _setting = null;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  TextPainter _painter() => TextPainter(
    text: TextSpan(text: _text, style: _style),
    textDirection: _direction,
    textScaler: _scaler,
    textAlign: TextAlign.justify,
  );

  _Setting _settingFor(double width) {
    final cached = _setting;
    if (cached != null && cached.width == width) return cached;
    cached?.dispose();
    return _setting = _set(width);
  }

  /// The most columns [width] holds that the text fills, each a slice of
  /// one layout at the column's width.
  _Setting _set(double width) {
    if (width.isFinite) {
      const gutter = ThemeRepo.columnTextGutter;
      final most = columnCountFor(width);
      for (var count = most; count >= 2; count--) {
        final columnWidth = (width - gutter * (count - 1)) / count;
        final painter = _painter()..layout(maxWidth: columnWidth);
        final lines = painter.computeLineMetrics();
        // Fewer columns rather than columns of a line or two each, which
        // read as fragments rather than as a page.
        if (lines.length >= count * ThemeRepo.columnTextMinLines) {
          return _Setting(
            width: width,
            columnWidth: columnWidth,
            painter: painter,
            slices: _slices(lines, _balance(lines, count), painter.height),
          );
        }
        painter.dispose();
      }
    }
    final painter = _painter()
      ..layout(maxWidth: width.isFinite ? width : double.infinity);
    return _Setting(
      width: width,
      columnWidth: painter.width,
      painter: painter,
      slices: [(top: 0, bottom: painter.height)],
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final painter = _painter()..layout();
    final width = painter.minIntrinsicWidth;
    painter.dispose();
    return width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final painter = _painter()..layout();
    final width = painter.maxIntrinsicWidth;
    painter.dispose();
    return width;
  }

  @override
  double computeMinIntrinsicHeight(double width) => _settingFor(width).height;

  @override
  double computeMaxIntrinsicHeight(double width) => _settingFor(width).height;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final setting = _settingFor(constraints.maxWidth);
    return constraints.constrain(Size(setting.extent, setting.height));
  }

  @override
  void performLayout() {
    final setting = _settingFor(constraints.maxWidth);
    size = constraints.constrain(Size(setting.extent, setting.height));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final setting = _setting;
    if (setting == null) return;
    final canvas = context.canvas;
    for (final (index, slice) in setting.slices.indexed) {
      // Each column shows its own run of lines of the one layout, lifted to
      // the top and cut off where the next column's run begins.
      final origin =
          offset +
          Offset(index * (setting.columnWidth + ThemeRepo.columnTextGutter), 0);
      canvas
        ..save()
        ..clipRect(
          origin & Size(setting.columnWidth, slice.bottom - slice.top),
        );
      setting.painter.paint(canvas, origin - Offset(0, slice.top));
      canvas.restore();
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..label = _text
      ..textDirection = _direction;
  }

  @override
  void dispose() {
    _setting?.dispose();
    super.dispose();
  }
}

/// The most columns [width] holds at a comfortable measure, before the text
/// has its say on whether it fills them. One at the least.
int columnCountFor(double width) {
  if (!width.isFinite) return 1;
  const gutter = ThemeRepo.columnTextGutter;
  return math.max(
    1,
    math.min(
      ThemeRepo.columnTextMaxColumns,
      ((width + gutter) / (ThemeRepo.columnTextMinWidth + gutter)).floor(),
    ),
  );
}

/// The run of one layout a column shows, from the top of its first line to
/// the top of the line after its last.
typedef _Slice = ({double top, double bottom});

/// The columns [RenderColumnText] set for one width.
class _Setting {
  _Setting({
    required this.width,
    required this.columnWidth,
    required this.painter,
    required this.slices,
  });

  final double width;
  final double columnWidth;
  final TextPainter painter;
  final List<_Slice> slices;

  double get height =>
      slices.map((slice) => slice.bottom - slice.top).reduce(math.max);

  /// How wide the setting stands: the whole width where there is more than
  /// one column, and the text's own width where it is a single one.
  double get extent =>
      slices.length * columnWidth +
      ThemeRepo.columnTextGutter * (slices.length - 1);

  void dispose() => painter.dispose();
}

bool _isBlank(LineMetrics line) => line.width < 1;

/// Where line [index] of [lines] starts, or [end] past the last.
double _topOf(List<LineMetrics> lines, int index, double end) =>
    index < lines.length ? lines[index].baseline - lines[index].ascent : end;

/// The slice of the layout each column shows, given the first line of each
/// column after the first: blank lines at a column's top or foot left out, so
/// no column opens or closes on the gap between two paragraphs.
List<_Slice> _slices(List<LineMetrics> lines, List<int> breaks, double end) {
  final slices = <_Slice>[];
  var from = 0;
  for (final to in [...breaks, lines.length]) {
    var first = from;
    var last = to - 1;
    while (first < last && _isBlank(lines[first])) {
      first++;
    }
    while (last > first && _isBlank(lines[last])) {
      last--;
    }
    slices.add((
      top: _topOf(lines, first, end),
      bottom: _topOf(lines, last + 1, end),
    ));
    from = to;
  }
  return slices;
}

/// The first line of each column after the first, for [count] columns of
/// [lines] whose tallest is as short as it can be. On a tie the earlier
/// columns take the extra line, as a page fills.
List<int> _balance(List<LineMetrics> lines, int count) {
  // Heights within half a pixel are the same height: lines are placed at
  // fractional positions, and an exact comparison let rounding decide.
  const tie = 0.5;

  /// How tall lines [from] to [to] stand as a column, blank ends trimmed.
  double heightOf(int from, int to) {
    var first = from;
    var last = to - 1;
    while (first <= last && _isBlank(lines[first])) {
      first++;
    }
    while (last >= first && _isBlank(lines[last])) {
      last--;
    }
    if (first > last) return 0;
    final top = lines[first].baseline - lines[first].ascent;
    final bottom = lines[last].baseline + lines[last].descent;
    return bottom - top;
  }

  var best = <int>[];
  var bestHeight = double.infinity;

  void tryFrom(int from, List<int> chosen, double tallest) {
    if (chosen.length == count - 1) {
      final height = math.max(tallest, heightOf(from, lines.length));
      // On a tie the later break wins, which leaves the earlier column the
      // longer one.
      if (height <= bestHeight + tie) {
        bestHeight = height;
        best = [...chosen];
      }
      return;
    }
    final remaining = count - 1 - chosen.length;
    for (var at = from + 1; at <= lines.length - remaining; at++) {
      final height = math.max(tallest, heightOf(from, at));
      if (height > bestHeight + tie) continue;
      tryFrom(at, [...chosen, at], height);
    }
  }

  tryFrom(0, const [], 0);
  return best;
}
