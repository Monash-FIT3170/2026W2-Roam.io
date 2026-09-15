import 'package:flutter/material.dart';

import '../domain/hazard_category.dart';

/// A single, original icon vocabulary for hazard sheets and map markers.
class HazardCategoryIcon extends StatelessWidget {
  const HazardCategoryIcon({
    super.key,
    required this.category,
    required this.color,
    this.size = 24,
  });

  final HazardCategory category;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${category.displayLabel} hazard icon',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: HazardCategoryIconPainter(category: category, color: color),
        ),
      ),
    );
  }
}

/// Draws bold silhouettes in a 24×24 coordinate space, including on bitmaps.
class HazardCategoryIconPainter extends CustomPainter {
  const HazardCategoryIconPainter({
    required this.category,
    required this.color,
  });

  final HazardCategory category;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    switch (category) {
      case HazardCategory.crash:
        _car(canvas, stroke, fill, left: 2, top: 10, width: 14);
        _line(canvas, stroke, 18, 3, 18, 5);
        _line(canvas, stroke, 18, 10, 18, 12);
        _line(canvas, stroke, 14, 7, 16, 7);
        _line(canvas, stroke, 20, 7, 22, 7);
        _line(canvas, stroke, 15, 4, 16, 5);
        _line(canvas, stroke, 20, 9, 21, 10);
      case HazardCategory.pothole:
        _line(canvas, stroke, 2, 9, 7, 9);
        _line(canvas, stroke, 17, 9, 22, 9);
        _line(canvas, stroke, 2, 18, 22, 18);
        final hole = Path()
          ..moveTo(7, 9)
          ..lineTo(9, 13)
          ..lineTo(15, 13)
          ..lineTo(17, 9);
        canvas.drawPath(hole, stroke);
        canvas.drawOval(const Rect.fromLTRB(8, 14, 16, 16.5), fill);
      case HazardCategory.roadworks:
        _line(canvas, stroke, 3, 8, 21, 8);
        _line(canvas, stroke, 3, 16, 21, 16);
        _line(canvas, stroke, 4, 8, 4, 19);
        _line(canvas, stroke, 20, 8, 20, 19);
        _line(canvas, stroke, 7, 8, 10, 16);
        _line(canvas, stroke, 14, 8, 17, 16);
        _line(canvas, stroke, 3, 20, 6, 20);
        _line(canvas, stroke, 18, 20, 21, 20);
      case HazardCategory.obstruction:
        _line(canvas, stroke, 3, 5, 3, 21);
        _line(canvas, stroke, 21, 5, 21, 21);
        _line(canvas, stroke, 5, 8, 19, 18);
        _line(canvas, stroke, 10, 11.5, 9, 7);
        _line(canvas, stroke, 14, 14.5, 18, 11);
        canvas.drawCircle(const Offset(7, 18), 2, fill);
        canvas.drawCircle(const Offset(15, 20), 1.5, fill);
      case HazardCategory.flooding:
        _line(canvas, stroke, 3, 3, 3, 11);
        _line(canvas, stroke, 21, 3, 21, 11);
        _line(canvas, stroke, 7, 6, 17, 6);
        for (final y in [13.0, 18.0]) {
          final wave = Path()
            ..moveTo(2, y)
            ..quadraticBezierTo(5, y - 3, 8, y)
            ..quadraticBezierTo(11, y + 3, 14, y)
            ..quadraticBezierTo(17, y - 3, 22, y);
          canvas.drawPath(wave, stroke);
        }
      case HazardCategory.slipperySurface:
        _car(canvas, stroke, fill, left: 2, top: 5, width: 15);
        final firstSkid = Path()
          ..moveTo(8, 17)
          ..quadraticBezierTo(13, 15, 17, 20);
        final secondSkid = Path()
          ..moveTo(15, 15)
          ..quadraticBezierTo(19, 14, 22, 19);
        canvas.drawPath(firstSkid, stroke);
        canvas.drawPath(secondSkid, stroke);
    }
    canvas.restore();
  }

  static void _line(
    Canvas canvas,
    Paint paint,
    double x1,
    double y1,
    double x2,
    double y2,
  ) => canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);

  static void _car(
    Canvas canvas,
    Paint stroke,
    Paint fill, {
    required double left,
    required double top,
    required double width,
  }) {
    final body = Path()
      ..moveTo(left, top + 5)
      ..lineTo(left + 2, top + 5)
      ..lineTo(left + 4, top)
      ..lineTo(left + width - 3, top)
      ..lineTo(left + width - 1, top + 5)
      ..lineTo(left + width, top + 5)
      ..lineTo(left + width, top + 9)
      ..lineTo(left, top + 9)
      ..close();
    canvas.drawPath(body, stroke);
    canvas.drawCircle(Offset(left + 3, top + 10), 1.5, fill);
    canvas.drawCircle(Offset(left + width - 3, top + 10), 1.5, fill);
  }

  @override
  bool shouldRepaint(HazardCategoryIconPainter oldDelegate) =>
      category != oldDelegate.category || color != oldDelegate.color;
}
