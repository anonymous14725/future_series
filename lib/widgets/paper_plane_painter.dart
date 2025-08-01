import 'package:flutter/material.dart';

// This painter now uses your exact coordinates for a much better shape.
class PaperPlanePainter extends CustomPainter {
  final Color color;

  PaperPlanePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill; // Using fill as your coordinates create a closed shape

    // Your provided path for the new paper plane shape
    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.1);
    path.lineTo(size.width, size.height * 0.5);
    path.lineTo(size.width * 0.1, size.height * 1); // Note: height * 1 is same as height
    path.lineTo(size.width * 0.4, size.height * 0.5);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant PaperPlanePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}