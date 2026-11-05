import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// A miniature sparkline chart rendering an institutional holder's position trajectory.
class HolderSparkline extends StatelessWidget {
  const HolderSparkline({
    super.key,
    required this.values,
    required this.colour,
    this.width = 56,
    this.height = 18,
  });

  final List<double> values;
  final Color colour;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(width: width, height: height);
    }

    return CustomPaint(
      size: Size(width, height),
      painter: _SparklinePainter(values: values, colour: colour),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.colour});

  final List<double> values;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
    final range = maxVal - minVal;
    final span = range == 0 ? 1.0 : range;

    const padY = 2.0;
    const padX = 2.0;
    final plotW = size.width - padX * 2;
    final plotH = size.height - padY * 2;

    double xOf(int index) => padX + (index / (values.length - 1)) * plotW;
    double yOf(double val) => padY + plotH - ((val - minVal) / span) * plotH;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = xOf(i);
      final y = yOf(values[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // Draw a small dot on the latest point.
    final lastX = xOf(values.length - 1);
    final lastY = yOf(values.last);
    canvas.drawCircle(
      Offset(lastX, lastY),
      2.0,
      Paint()..color = colour,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.colour != colour;
}

