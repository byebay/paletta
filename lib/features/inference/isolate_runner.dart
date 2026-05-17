import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../../config/env_config.dart';
import '../pcd/preprocessor.dart';
import 'yolo_inference_engine.dart';

class _PreprocessPayload {
  final CameraImage cameraImage;
  final int inputSize;
  _PreprocessPayload(this.cameraImage, this.inputSize);
}

class _ImagePayload {
  final img.Image image;
  final int inputSize;
  _ImagePayload(this.image, this.inputSize);
}

class IsolateRunner {
  final YoloInferenceEngine _engine;

  IsolateRunner(this._engine);

  // Dari CameraImage (stream)
  Future<List<DetectionResult>> run(CameraImage cameraImage) async {
    final payload = _PreprocessPayload(cameraImage, EnvConfig.inputSize);
    final inputTensor = await compute(_preprocessInBackground, payload);
    if (inputTensor == null) return [];
    return _engine.run(inputTensor);
  }

  // Dari img.Image (takePicture)
  Future<List<DetectionResult>> runFromImage(img.Image image) async {
    final payload = _ImagePayload(image, EnvConfig.inputSize);
    final inputTensor = await compute(_preprocessImageInBackground, payload);
    if (inputTensor == null) return [];
    return _engine.run(inputTensor);
  }
}

Future<Float32List?> _preprocessInBackground(_PreprocessPayload payload) async {
  return await Preprocessor.process(payload.cameraImage, payload.inputSize);
}

Future<Float32List?> _preprocessImageInBackground(_ImagePayload payload) async {
  return Preprocessor.processImage(payload.image, payload.inputSize);
}