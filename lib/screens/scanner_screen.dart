import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../config/env_config.dart';
import '../features/camera/camera_controller_wrapper.dart';
import '../features/inference/isolate_runner.dart';
import '../features/inference/model_loader.dart';
import '../features/inference/yolo_inference_engine.dart';
import '../features/pcd/kmeans_extractor.dart';

class ScannerScreen extends StatefulWidget {
  final ModelLoader modelLoader;
  const ScannerScreen({super.key, required this.modelLoader});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  final CameraControllerWrapper _cameraWrapper = CameraControllerWrapper();
  late final YoloInferenceEngine _engine;
  late final IsolateRunner _isolateRunner;

  bool _isProcessing = false;
  Timer? _inferenceTimer;
  List<DetectionResult> _detections = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine = YoloInferenceEngine(widget.modelLoader);
    _isolateRunner = IsolateRunner(_engine);
    _initCamera();
  }

  Future<void> _initCamera() async {
    await _cameraWrapper.initialize();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _runInference() async {
    if (_isProcessing || !_cameraWrapper.isInitialized) return;
    _isProcessing = true;

    try {
      // Ambil foto dari kamera
      final xFile = await _cameraWrapper.controller!.takePicture();
      final bytes = await File(xFile.path).readAsBytes();

      // Decode foto → img.Image
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return;

      // Jalankan inference
      final results = await _isolateRunner.runFromImage(decoded);

      if (mounted) {
        setState(() => _detections = results);
        if (results.isNotEmpty) {
          print('Detected: ${results.first}');
          
          final extractor = KMeansExtractor(k: EnvConfig.kValue);
          final palette = extractor.extract(
            image: decoded,
            x1: results.first.x1,
            y1: results.first.y1,
            x2: results.first.x2,
            y2: results.first.y2,
          );

          for (final color in palette) {
            print('Color: ${color.toHex()} | CMYK: ${color.toCMYK()}');
          }
        }
      }
    } catch (e) {
      print('Inference error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _inferenceTimer?.cancel();
      _cameraWrapper.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraWrapper.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraWrapper.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Scanner 🎨',
            style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // Preview kamera dengan aspect ratio yang benar
          Expanded(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _cameraWrapper.controller!.value.previewSize!.height,
                height: _cameraWrapper.controller!.value.previewSize!.width,
                child: CameraPreview(_cameraWrapper.controller!),
              ),
            ),
          ),

          // Area tombol di bagian bawah
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Placeholder kiri
                const SizedBox(width: 64),

                // Tombol foto
                GestureDetector(
                  onTap: _isProcessing ? null : _runInference,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: _isProcessing
                          ? Colors.grey
                          : Colors.white.withOpacity(0.2),
                    ),
                    child: _isProcessing
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.camera_alt,
                            color: Colors.white, size: 32),
                  ),
                ),

                // Placeholder kanan
                const SizedBox(width: 64),
              ],
            ),
          ),
        ],
      ),
    );
  }
}