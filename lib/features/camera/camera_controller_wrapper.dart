import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraControllerWrapper {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        debugPrint('No cameras found on this device');
        return;
      }

      // Pakai kamera belakang (index 0)
      _controller = CameraController(
        _cameras[0],
        ResolutionPreset.high,
        enableAudio: false,         // Tidak butuh audio
        imageFormatGroup: ImageFormatGroup.yuv420, // Format optimal untuk TFLite
      );

      await _controller!.initialize();
      debugPrint('Camera initialized successfully');
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  // Wajib dipanggil saat widget dispose — Resource Safety (FR requirement)
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
    debugPrint('Camera disposed');
  }
}