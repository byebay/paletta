import 'package:flutter/material.dart';
import '../inference/yolo_inference_engine.dart';

class BoundingBoxPainter extends CustomPainter {
  final List<DetectionResult> detections;
  final Size imageSize;

  BoundingBoxPainter({
    required this.detections,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final detection in detections) {
      _drawBox(canvas, size, detection);
      _drawLabel(canvas, size, detection);
    }
  }

  void _drawBox(Canvas canvas, Size size, DetectionResult detection) {
    final paint = Paint()
      ..color = _colorByConfidence(detection.confidence)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // Konversi koordinat ternormalisasi [0,1] ke koordinat layar
    final rect = Rect.fromLTRB(
      detection.x1 * size.width,
      detection.y1 * size.height,
      detection.x2 * size.width,
      detection.y2 * size.height,
    );

    canvas.drawRect(rect, paint);
  }

  void _drawLabel(Canvas canvas, Size size, DetectionResult detection) {
    final label =
        '${detection.label} ${(detection.confidence * 100).toStringAsFixed(1)}%';

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black54,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        detection.x1 * size.width + 4,
        detection.y1 * size.height + 4,
      ),
    );
  }

  // Warna box berdasarkan confidence
  Color _colorByConfidence(double confidence) {
    if (confidence >= 0.7) return Colors.green;
    if (confidence >= 0.4) return Colors.orange;
    return Colors.red;
  }

  @override
  bool shouldRepaint(BoundingBoxPainter oldDelegate) =>
      oldDelegate.detections != detections;
}