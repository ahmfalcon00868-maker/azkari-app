import 'package:flutter/material.dart';

class GooglePlayIcon extends StatelessWidget {
  final double size;
  const GooglePlayIcon({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GooglePlayPainter(),
    );
  }
}

class _GooglePlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final left = Offset(w * 0.12, h * 0.08);
    final bottomLeft = Offset(w * 0.12, h * 0.92);
    final rightTip = Offset(w * 0.90, h * 0.50);
    final center = Offset(w * 0.56, h * 0.50);
    final topMid = Offset(w * 0.66, h * 0.37);
    final bottomMid = Offset(w * 0.66, h * 0.63);

    final bluePath = Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(center.dx, center.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..close();
    canvas.drawPath(bluePath, Paint()..color = const Color(0xFF00D2FF));

    final greenPath = Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(topMid.dx, topMid.dy)
      ..lineTo(center.dx, center.dy)
      ..close();
    canvas.drawPath(greenPath, Paint()..color = const Color(0xFF00F076));

    final redPath = Path()
      ..moveTo(bottomLeft.dx, bottomLeft.dy)
      ..lineTo(center.dx, center.dy)
      ..lineTo(bottomMid.dx, bottomMid.dy)
      ..close();
    canvas.drawPath(redPath, Paint()..color = const Color(0xFFFF3A44));

    final yellowPath = Path()
      ..moveTo(topMid.dx, topMid.dy)
      ..lineTo(rightTip.dx, rightTip.dy)
      ..lineTo(bottomMid.dx, bottomMid.dy)
      ..lineTo(center.dx, center.dy)
      ..close();
    canvas.drawPath(yellowPath, Paint()..color = const Color(0xFFFFC900));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
