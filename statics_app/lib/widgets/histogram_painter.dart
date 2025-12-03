// lib/widgets/histogram_painter.dart
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class HistogramPainter extends CustomPainter {
  final List<double> edges; // length k+1
  final List<int> counts; // length k
  final List<double>? curveX;
  final List<double>? curveY; // frequencies in same units as counts
  HistogramPainter({required this.edges, required this.counts, this.curveX, this.curveY});

  @override
  void paint(Canvas canvas, Size size) {
    final paintAxis = Paint()..color = Colors.black..strokeWidth = 1.2;
    final paintGrid = Paint()..color = Colors.grey.withOpacity(0.25)..strokeWidth = 0.7;
    final paintBar = Paint()..color = Colors.lightBlue..style = PaintingStyle.fill;
    final paintEdge = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.0;
    final paintCurve = Paint()..color = Colors.red..style = PaintingStyle.stroke..strokeWidth = 2.0;

    // Padding for labels
    const double leftPad = 40.0;
    const double bottomPad = 28.0;
    const double topPad = 12.0;
    const double rightPad = 12.0;

    final double w = size.width - leftPad - rightPad;
    final double h = size.height - topPad - bottomPad;
    final double originX = leftPad;
    final double originY = topPad + h;

    // domain range
    final double minX = edges.first;
    final double maxX = edges.last;
    final double domain = (maxX - minX) == 0 ? 1.0 : (maxX - minX);

    // range (counts) //--cambios
    double maxBarHeight = counts.isEmpty ? 0.0 : counts.reduce((a,b) => a > b ? a : b).toDouble();
    double maxCurveHeight = 0.0;

    if (curveY != null && curveY!.isNotEmpty) {
      maxCurveHeight = curveY!.reduce((a, b) => a > b ? a : b);
    }
    // El tope del gráfico será el mayor de los dos
    final double maxY = (maxBarHeight > maxCurveHeight) ? maxBarHeight : maxCurveHeight;
    final double rangeY = maxY == 0 ? 1.0 : maxY;
    //-- fin de los cambios
    
    // draw grid horizontal lines and ticks
    final int ny = 5;
    for (int i = 0; i <= ny; i++) {
      final double yy = originY - (i / ny) * h;
      canvas.drawLine(Offset(originX, yy), Offset(originX + w, yy), paintGrid);
      // y-label
      final tp = _textPainter((rangeY * i / ny).toStringAsFixed(0), 10.0);
      tp.paint(canvas, Offset(6, yy - tp.height/2));
    }

    // draw x axis
    canvas.drawLine(Offset(originX, originY), Offset(originX + w, originY), paintAxis);

    // draw bars
    for (int i = 0; i < counts.length; i++) {
      final left = originX + ((edges[i] - minX) / domain) * w;
      final right = originX + ((edges[i+1] - minX) / domain) * w;
      final top = originY - (counts[i] / rangeY) * h;
      final rect = Rect.fromLTRB(left, top, right, originY);
      canvas.drawRect(rect, paintBar);
      canvas.drawRect(rect, paintEdge);

      // x label (midpoint)
      final mid = 0.5*(edges[i]+edges[i+1]);
      final tp = _textPainter(mid.toStringAsFixed(2), 9.0);
      final px = (left + right)/2 - tp.width/2;
      tp.paint(canvas, Offset(px.clamp(originX, originX + w - tp.width), originY + 4));
    }

    // Draw curve if provided
    if (curveX != null && curveY != null && curveX!.length == curveY!.length) {
      final path = Path();
      for (int i = 0; i < curveX!.length; i++) {
        final x = originX + ((curveX![i] - minX) / domain) * w;
        final y = originY - (curveY![i] / rangeY) * h;
        if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
      }
      canvas.drawPath(path, paintCurve);
    }
  }

  TextPainter _textPainter(String text, double size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: Colors.black, fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp;
  }

  @override
  bool shouldRepaint(covariant HistogramPainter old) {
    return old.edges != edges || old.counts != counts || old.curveX != curveX;
  }
}
