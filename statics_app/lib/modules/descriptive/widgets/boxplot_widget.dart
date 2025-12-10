// lib/widgets/boxplot_widget.dart
import 'package:flutter/material.dart';
import '../models/descriptive_models.dart';

class BoxplotWidget extends StatelessWidget {
  final Boxplot box;
  const BoxplotWidget({super.key, required this.box});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: CustomPaint(
        painter: _BoxplotPainter(box),
        child: Container(),
      ),
    );
  }
}

class _BoxplotPainter extends CustomPainter {
  final Boxplot box;
  _BoxplotPainter(this.box);

  @override
  void paint(Canvas canvas, Size size) {
    final paintBox = Paint()..color = Colors.lightGreen..style = PaintingStyle.fill;
    final paintEdge = Paint()..color = Colors.black..strokeWidth = 1.2;
    final paintWhisker = Paint()..color = Colors.black..strokeWidth = 2.0;
    final paintOutlier = Paint()..color = Colors.red..style = PaintingStyle.fill;

    final double leftPad = 20, rightPad = 20;
    final double minX = box.min;
    final double maxX = box.max;
    final double domain = (maxX - minX) == 0 ? 1.0 : (maxX - minX);

    final double yCenter = size.height / 2;
    final double boxHeight = size.height * 0.25;

    double mapX(double x) => leftPad + ((x - minX)/domain) * (size.width - leftPad - rightPad);

    final double xQ1 = mapX(box.q1);
    final double xQ3 = mapX(box.q3);
    final double xMed = mapX(box.median);
    final double xMin = mapX(box.min);
    final double xMax = mapX(box.max);
    final double xLowerFence = mapX(box.lowerFence);
    final double xUpperFence = mapX(box.upperFence);

    // box
    final r = Rect.fromLTRB(xQ1, yCenter - boxHeight/2, xQ3, yCenter + boxHeight/2);
    canvas.drawRect(r, paintBox);
    canvas.drawRect(r, paintEdge);

    // median line
    canvas.drawLine(Offset(xMed, yCenter - boxHeight/2), Offset(xMed, yCenter + boxHeight/2), paintEdge);

    // whiskers (to min and max within fences)
    canvas.drawLine(Offset(xMin, yCenter), Offset(xQ1, yCenter), paintWhisker);
    canvas.drawLine(Offset(xQ3, yCenter), Offset(xMax, yCenter), paintWhisker);
    // caps
    canvas.drawLine(Offset(xMin, yCenter - boxHeight/4), Offset(xMin, yCenter + boxHeight/4), paintEdge);
    canvas.drawLine(Offset(xMax, yCenter - boxHeight/4), Offset(xMax, yCenter + boxHeight/4), paintEdge);

    // outliers as points
    final out = box.outliers;
    for (var v in out) {
      final x = mapX(v);
      canvas.drawCircle(Offset(x, yCenter), 3.0, paintOutlier);
    }

    // labels: show q1,q2,q3 values below
    final tp = TextPainter(textDirection: TextDirection.ltr);
    void drawLabel(String t, double atX) {
      tp.text = TextSpan(text: t, style: TextStyle(color: Colors.black, fontSize: 10));
      tp.layout();
      tp.paint(canvas, Offset(atX - tp.width/2, yCenter + boxHeight/2 + 6));
    }
    drawLabel(box.q1.toStringAsFixed(2), xQ1);
    drawLabel(box.median.toStringAsFixed(2), xMed);
    drawLabel(box.q3.toStringAsFixed(2), xQ3);
  }

  @override
  bool shouldRepaint(covariant _BoxplotPainter old) => old.box != box;
}
