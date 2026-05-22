import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../../config/env_config.dart';
import '../pcd/preprocessor.dart';
import 'yolo_inference_engine.dart';
import '../../screens/scanner_screen.dart';

class _PreprocessPayload {
  final CameraFrameData frameData;
  final int inputSize;
  _PreprocessPayload(this.frameData, this.inputSize);
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
  Future<List<DetectionResult>> run(CameraFrameData frameData) async {
    final payload = _PreprocessPayload(frameData, EnvConfig.inputSize);
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

  // Konversi CameraImage ke img.Image untuk ekstraksi palet
  Future<img.Image?> convertFrame(CameraFrameData frameData) async {
    final payload = _PreprocessPayload(frameData, EnvConfig.inputSize);
    return await compute(_convertFrameInBackground, payload);
  }
}

Future<Float32List?> _preprocessImageInBackground(_ImagePayload payload) async {
  return Preprocessor.processImage(payload.image, payload.inputSize);
}

Future<Float32List?> _preprocessInBackground(_PreprocessPayload payload) async {
  return Preprocessor.processFrameData(payload.frameData, payload.inputSize);
}

Future<img.Image?> _convertFrameInBackground(_PreprocessPayload payload) async {
  return Preprocessor.convertFrameData(payload.frameData);
}