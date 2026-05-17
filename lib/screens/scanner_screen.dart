import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../features/camera/camera_controller_wrapper.dart';
import '../features/inference/isolate_runner.dart';
import '../features/inference/model_loader.dart';
import '../features/inference/yolo_inference_engine.dart';

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

    // Timer inference — setiap 2 detik ambil foto lalu proses
    _inferenceTimer = Timer.periodic(
      const Duration(milliseconds: 2000),
      (_) => _runInference(),
    );

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
    _inferenceTimer?.cancel();
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
      body: SizedBox.expand(
        child: CameraPreview(_cameraWrapper.controller!),
      ),
    );
  }
}