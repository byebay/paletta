import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../config/env_config.dart';
import 'model_loader.dart';

class DetectionResult {
  final String label;
  final double confidence;
  final double x1, y1, x2, y2; // Koordinat dalam ruang model (0.0 - 1.0)

  DetectionResult({
    required this.label,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  @override
  String toString() =>
      '$label (${(confidence * 100).toStringAsFixed(1)}%) [$x1, $y1, $x2, $y2]';
}

class YoloInferenceEngine {
  final ModelLoader _modelLoader;
  int _numDetections = 2100; // default, akan di-update saat model load

  YoloInferenceEngine(this._modelLoader) {
    _initOutputSize();
  }

  void _initOutputSize() {
    if (!_modelLoader.isLoaded) return;
    final outputShape = _modelLoader.interpreter!.getOutputTensor(0).shape;
    _numDetections = outputShape[2]; // [1, 84, N] → ambil N
    print('Output detections: $_numDetections');
  }

  List<DetectionResult> run(Float32List inputTensor) {
    if (!_modelLoader.isLoaded) return [];

    try {
      final interpreter = _modelLoader.interpreter!;
      final inputSize = EnvConfig.inputSize;

      final inputBuffer = [inputTensor.reshape([1, inputSize, inputSize, 3])];

      final outputBuffer = {
        0: List.generate(1, (_) =>
            List.generate(84, (_) =>
                List.filled(_numDetections, 0.0)))
      };

      interpreter.runForMultipleInputs(inputBuffer, outputBuffer);

      final output = outputBuffer[0] as List<List<List<double>>>;
      return _parseOutput(output[0]);
    } catch (e, stack) {
      print('Engine error: $e');
      print('Stack: $stack');
      return [];
    }
  }

  List<DetectionResult> _parseOutput(List<List<double>> output) {
    final results = <DetectionResult>[];
    final threshold = EnvConfig.confidenceThreshold;
    final labels = _modelLoader.labels;

    double globalMaxScore = 0.0;

    for (int i = 0; i < _numDetections; i++) {
      double maxScore = 0.0;
      int maxClassIndex = 0;

      for (int c = 4; c < 84; c++) {
        if (output[c][i] > maxScore) {
          maxScore = output[c][i];
          maxClassIndex = c - 4;
        }
      }

      if (maxScore > globalMaxScore) globalMaxScore = maxScore;
      if (maxScore < threshold) continue;

      final cx = output[0][i];
      final cy = output[1][i];
      final w  = output[2][i];
      final h  = output[3][i];

      final x1 = (cx - w / 2).clamp(0.0, 1.0);
      final y1 = (cy - h / 2).clamp(0.0, 1.0);
      final x2 = (cx + w / 2).clamp(0.0, 1.0);
      final y2 = (cy + h / 2).clamp(0.0, 1.0);

      final label = (maxClassIndex < labels.length)
          ? labels[maxClassIndex]
          : 'unknown';

      results.add(DetectionResult(
        label: label,
        confidence: maxScore,
        x1: x1, y1: y1,
        x2: x2, y2: y2,
      ));
    }

    print('Max score: $globalMaxScore (threshold: $threshold)');
    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results.take(10).toList();
  }
}