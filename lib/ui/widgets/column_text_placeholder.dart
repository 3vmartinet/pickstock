import 'dart:math' as math;

import 'package:pickstock/repo/theme_repo.dart';
import 'package:pickstock/ui/widgets/column_text.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

/// The lines of a paragraph-to-be: each one runs the full measure, as a
/// justified line does, except the last, which stops where its sentence does.
/// Three paragraphs of unequal length, as an article has.
const List<({int lines, double lastLine})> _paragraphs = [
  (lines: 6, lastLine: 0.62),
  (lines: 5, lastLine: 0.38),
  (lines: 4, lastLine: 0.71),
];

/// How much of a line's height its bar takes: about the height of the
/// lowercase with the ascenders, so the bars read as lines of type rather than
/// as stripes.
const double _barHeightFraction = 0.55;

/// One pass of the highlight across a line.
const Duration _sweep = Duration(milliseconds: 520);

/// How far behind the line above each line's sweep starts, as a share of one
/// sweep: enough that the light runs down the column as a slanting band
/// rather than lighting the whole column at once.
const double _stagger = 0.28;

/// How wide the highlight is, as a share of the column.
const double _highlightWidth = 0.45;

/// An article not yet written, set the way [ColumnText] will set it: justified
/// lines in as many columns as the width holds, filled one after the other and
/// balanced, with the paragraphs' short last lines and the gaps between them.
///
/// The highlight reads it the way a reader would: across each line, down the
/// column, and on to the top of the next, so the shimmer says "this is being
/// written" in the shape of the page it will become rather than as a light
/// passing over the whole block at once.
///
/// Held still where the system asks for less motion.
class ColumnTextPlaceholder extends StatefulWidget {
  const ColumnTextPlaceholder({super.key, this.isSerif = false});

  /// Whether the text it stands in for is set in the serif, which sets taller
  /// lines.
  final bool isSerif;

  @override
  State<ColumnTextPlaceholder> createState() => _ColumnTextPlaceholderState();
}

class _ColumnTextPlaceholderState extends State<ColumnTextPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _cycle,
  );

  /// One reading of the whole placeholder: a sweep for every line's start,
  /// staggered, plus the last line's own sweep and the same again as a pause,
  /// so the light is seen to finish before it begins again.
  static final Duration _cycle = _sweep * (_lineCount * _stagger + 2);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    final style = ColumnText.styleOf(context, isSerif: widget.isSerif);
    final scaler = MediaQuery.textScalerOf(context);
    final fontSize = scaler.scale(
      style.fontSize ?? ThemeRepo.serifFallbackSize,
    );
    final lineHeight = fontSize * (style.height ?? ThemeRepo.serifLineHeight);
    final isStill = MediaQuery.disableAnimationsOf(context);

    // No words for a screen reader: the button beside it already says the
    // answer is being read.
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => _Placeholder(
        lineHeight: lineHeight,
        bar: scheme.muted,
        highlight: scheme.mutedForeground.withValues(alpha: 0.35),
        progress: isStill ? null : _controller.value,
      ),
    );
  }
}

/// How many lines of type the placeholder sets, gaps left out.
final int _lineCount = _paragraphs.fold(0, (sum, p) => sum + p.lines);

/// A line of the placeholder, in reading order: how much of the measure it
/// runs, or null for the gap between two paragraphs.
final List<double?> _slots = [
  for (final (index, paragraph) in _paragraphs.indexed) ...[
    if (index > 0) null,
    for (var line = 1; line < paragraph.lines; line++) 1.0,
    paragraph.lastLine,
  ],
];

/// The slots each column shows, balanced as [ColumnText] balances: as level
/// as they can be, the earlier columns taking the extra line, and no column
/// opening or closing on a gap.
List<List<double?>> _columnsOf(int count) {
  final perColumn = (_slots.length / count).ceil();
  final columns = <List<double?>>[];
  for (var from = 0; from < _slots.length; from += perColumn) {
    final column = _slots
        .sublist(from, math.min(from + perColumn, _slots.length))
        .toList();
    while (column.isNotEmpty && column.first == null) {
      column.removeAt(0);
    }
    while (column.isNotEmpty && column.last == null) {
      column.removeLast();
    }
    if (column.isNotEmpty) columns.add(column);
  }
  return columns;
}

class _Placeholder extends LeafRenderObjectWidget {
  const _Placeholder({
    required this.lineHeight,
    required this.bar,
    required this.highlight,
    required this.progress,
  });

  final double lineHeight;
  final Color bar;
  final Color highlight;
  final double? progress;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderColumnTextPlaceholder(
        lineHeight: lineHeight,
        bar: bar,
        highlight: highlight,
        progress: progress,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderColumnTextPlaceholder renderObject,
  ) {
    renderObject
      ..lineHeight = lineHeight
      ..bar = bar
      ..highlight = highlight
      ..progress = progress;
  }
}

/// Lays out and paints a [ColumnTextPlaceholder]: a leaf, as [ColumnText] is,
/// so the cards it sits in can measure it before laying it out.
class RenderColumnTextPlaceholder extends RenderBox {
  RenderColumnTextPlaceholder({
    required this._lineHeight,
    required this._bar,
    required this._highlight,
    required this._progress,
  });

  double _lineHeight;
  set lineHeight(double value) {
    if (value == _lineHeight) return;
    _lineHeight = value;
    markNeedsLayout();
  }

  Color _bar;
  set bar(Color value) {
    if (value == _bar) return;
    _bar = value;
    markNeedsPaint();
  }

  Color _highlight;
  set highlight(Color value) {
    if (value == _highlight) return;
    _highlight = value;
    markNeedsPaint();
  }

  double? _progress;
  set progress(double? value) {
    if (value == _progress) return;
    _progress = value;
    markNeedsPaint();
  }

  /// How many columns the placeholder is set in at its current width.
  @visibleForTesting
  int get columnCount => _columnsOf(columnCountFor(size.width)).length;

  double _heightFor(double width) {
    final columns = _columnsOf(columnCountFor(width));
    return columns.map((column) => column.length).reduce(math.max) *
        _lineHeight;
  }

  /// As wide as the most columns it would ever set: it has no words of its
  /// own to ask for more.
  static const double _widest =
      ThemeRepo.columnTextMinWidth * ThemeRepo.columnTextMaxColumns +
      ThemeRepo.columnTextGutter * (ThemeRepo.columnTextMaxColumns - 1);

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => _widest;

  @override
  double computeMinIntrinsicHeight(double width) => _heightFor(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _heightFor(width);

  Size _sizeFor(BoxConstraints constraints) {
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : _widest;
    return constraints.constrain(Size(width, _heightFor(width)));
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _sizeFor(constraints);

  @override
  void performLayout() => size = _sizeFor(constraints);

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final columns = _columnsOf(columnCountFor(size.width));
    const gutter = ThemeRepo.columnTextGutter;
    final columnWidth =
        (size.width - gutter * (columns.length - 1)) / columns.length;
    final barHeight = _lineHeight * _barHeightFraction;
    final radius = Radius.circular(barHeight / 2);
    final base = Paint()..color = _bar;

    // Where the reading has got to, in sweeps: line n starts its sweep n
    // staggers in, and a sweep's position runs from just before the line's
    // start to just past its end so the light enters and leaves it whole.
    final reading = _progress == null
        ? null
        : _progress! * (_lineCount * _stagger + 2);
    var lineIndex = 0;

    for (final (index, column) in columns.indexed) {
      final left = offset.dx + index * (columnWidth + gutter);
      for (final (row, slot) in column.indexed) {
        if (slot == null) continue;
        final top =
            offset.dy + row * _lineHeight + (_lineHeight - barHeight) / 2;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, columnWidth * slot, barHeight),
          radius,
        );
        canvas.drawRRect(rect, base);

        final sweep = reading == null ? null : reading - lineIndex * _stagger;
        lineIndex++;
        if (sweep == null || sweep <= 0 || sweep >= 1) continue;

        final band = columnWidth * _highlightWidth;
        final centre = left - band / 2 + sweep * (columnWidth + band);
        canvas.drawRRect(
          rect,
          Paint()
            ..shader =
                LinearGradient(
                  colors: [
                    _highlight.withValues(alpha: 0),
                    _highlight,
                    _highlight.withValues(alpha: 0),
                  ],
                ).createShader(
                  Rect.fromLTWH(centre - band / 2, top, band, barHeight),
                ),
        );
      }
    }
  }
}
