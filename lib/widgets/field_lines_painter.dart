import 'package:flutter/material.dart';

class FieldLinesPainter extends CustomPainter {
  final double opacity;

  FieldLinesPainter({this.opacity = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    // Arka planı koyu yeşil doldur
    final bgPaint = Paint()
      ..color = const Color(0xFF145A32).withOpacity(opacity)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(12),
      ),
      bgPaint,
    );
    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Dış dikdörtgen (kenar çizgileri)
    canvas.drawRect(
      Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
      paint,
    );

    // Orta çizgi
    canvas.drawLine(
      Offset(size.width / 2, 2),
      Offset(size.width / 2, size.height - 2),
      paint,
    );

    // Orta yuvarlak
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      12,
      paint,
    );

    // Ceza sahası çizgileri (her iki uçta)
    double penaltyWidth = 18;
    double penaltyHeight = size.height - 20;
    // Sol ceza sahası
    canvas.drawRect(
      Rect.fromLTWH(2, (size.height - penaltyHeight) / 2, penaltyWidth, penaltyHeight),
      paint,
    );
    // Sağ ceza sahası
    canvas.drawRect(
      Rect.fromLTWH(size.width - penaltyWidth - 2, (size.height - penaltyHeight) / 2, penaltyWidth, penaltyHeight),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant FieldLinesPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
