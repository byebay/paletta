import 'package:flutter/material.dart';
import '../pcd/kmeans_extractor.dart';

class PaletteSwatchPainter extends CustomPainter {
  final List<PaletteColor> palette;
  final double x1, y2; // Posisi bawah-kiri bounding box

  PaletteSwatchPainter({
    required this.palette,
    required this.x1,
    required this.y2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (palette.isEmpty) return;

    const swatchSize = 28.0;
    const spacing = 4.0;
    const padding = 4.0;

    final startX = x1 * size.width;
    final startY = y2 * size.height + 8;

    for (int i = 0; i < palette.length; i++) {
      final color = palette[i];
      final offsetX = startX + i * (swatchSize + spacing);

      // Lingkaran warna
      final paint = Paint()
        ..color = Color.fromRGBO(color.r, color.g, color.b, 1.0)
        ..style = PaintingStyle.fill;

      final center = Offset(offsetX + swatchSize / 2, startY + swatchSize / 2);

      // Shadow
      canvas.drawCircle(
        center.translate(1, 1),
        swatchSize / 2,
        Paint()..color = Colors.black38,
      );

      // Warna
      canvas.drawCircle(center, swatchSize / 2, paint);

      // Border putih
      canvas.drawCircle(
        center,
        swatchSize / 2,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Label HEX di bawah lingkaran
      final hex = color.toHex().substring(1); // Hapus '#'
      final textPainter = TextPainter(
        text: TextSpan(
          text: hex,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 2)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
          offsetX + (swatchSize - textPainter.width) / 2,
          startY + swatchSize + padding,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(PaletteSwatchPainter oldDelegate) =>
      oldDelegate.palette != palette;
}