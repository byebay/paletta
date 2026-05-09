import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  EnvConfig._(); // Prevent instantiation

  // --- Model ---
  static String get modelPath =>
      dotenv.env['MODEL_PATH'] ?? 'assets/models/yolov8n.tflite';

  static String get labelsPath =>
      dotenv.env['LABELS_PATH'] ?? 'assets/labels/coco_labels.txt';

  static int get inputSize =>
      int.tryParse(dotenv.env['INPUT_SIZE'] ?? '640') ?? 640;

  static double get confidenceThreshold =>
      double.tryParse(dotenv.env['CONFIDENCE_THRESHOLD'] ?? '0.5') ?? 0.5;

  static double get iouThreshold =>
      double.tryParse(dotenv.env['IOU_THRESHOLD'] ?? '0.45') ?? 0.45;

  // --- PCD ---
  static int get kValue =>
      int.tryParse(dotenv.env['K_VALUE'] ?? '5') ?? 5;

  // --- App ---
  static int get maxSavedPalettes =>
      int.tryParse(dotenv.env['MAX_SAVED_PALETTES'] ?? '100') ?? 100;
}