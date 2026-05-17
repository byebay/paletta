import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../config/env_config.dart';
import 'dart:typed_data';

class ModelLoader {
  Interpreter? _interpreter;
  List<String> _labels = [];

  Interpreter? get interpreter => _interpreter;
  List<String> get labels => _labels;
  bool get isLoaded => _interpreter != null;

  Future<void> load() async {
    await _loadModel();
    await _loadLabels();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        EnvConfig.modelPath,
        options: InterpreterOptions()..threads = 2,
      );
      print('Model loaded: ${EnvConfig.modelPath}');
      print('Input shape: ${_interpreter!.getInputTensor(0).shape}');
      print('Output shape: ${_interpreter!.getOutputTensor(0).shape}');

      // Test inference dengan dummy data
      await _testInference();
    } catch (e) {
      print('Failed to load model: $e');
    }
  }
  
  Future<void> _testInference() async {
    try {
      print('Test inference: start');
      final inputSize = EnvConfig.inputSize;
      final dummyInput = Float32List(1 * inputSize * inputSize * 3);
      final dummyOutput = List.generate(
        1, (_) => List.generate(84, (_) => List.filled(8400, 0.0)),
      );
      _interpreter!.run(
        dummyInput.reshape([1, inputSize, inputSize, 3]),
        dummyOutput,
      );
      print('Test inference: done');
    } catch (e) {
      print('Test inference error: $e');
    }
  }

  Future<void> _loadLabels() async {
    try {
      final raw = await rootBundle.loadString(EnvConfig.labelsPath);
      _labels = raw
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      print('Labels loaded: ${_labels.length} classes');
    } catch (e) {
      print('Failed to load labels: $e');
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    print('Model disposed');
  }
}