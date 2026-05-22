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
import '../features/overlay/bounding_box_painter.dart';
import '../features/overlay/palette_swatch_painter.dart';
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
  List<PaletteColor> _palette = [];
  img.Image? _capturedImage;
  Size _imageSize = Size.zero;

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
      final xFile = await _cameraWrapper.controller!.takePicture();
      final bytes = await File(xFile.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return;

      _capturedImage = decoded;
      _imageSize = Size(decoded.width.toDouble(), decoded.height.toDouble());

      final results = await _isolateRunner.runFromImage(decoded);

      final extractor = KMeansExtractor(k: EnvConfig.kValue);
      List<PaletteColor> palette = [];

      if (results.isNotEmpty) {
        // Ada deteksi → ekstrak dari area bounding box
        palette = extractor.extract(
          image: decoded,
          x1: results.first.x1,
          y1: results.first.y1,
          x2: results.first.x2,
          y2: results.first.y2,
        );
      } else {
        // Tidak ada deteksi → ekstrak dari seluruh frame
        palette = extractor.extract(
          image: decoded,
          x1: 0.0,
          y1: 0.0,
          x2: 1.0,
          y2: 1.0,
        );
      }

      if (mounted) {
        setState(() {
          _detections = results;
          _palette = palette;
        });
      }
    } catch (e) {
      print('Inference error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
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
        title: const Text('Scanner',
            style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Camera preview
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isLandscape =
                        MediaQuery.of(context).orientation == Orientation.landscape;
                    final previewSize =
                        _cameraWrapper.controller!.value.previewSize!;

                    // Swap width/height sesuai orientasi
                    final previewWidth =
                        isLandscape ? previewSize.width : previewSize.height;
                    final previewHeight =
                        isLandscape ? previewSize.height : previewSize.width;

                    return FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: previewWidth,
                        height: previewHeight,
                        child: CameraPreview(_cameraWrapper.controller!),
                      ),
                    );
                  },
                ),

                // Bounding box overlay
                if (_detections.isNotEmpty)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: BoundingBoxPainter(
                        detections: _detections,
                        imageSize: _imageSize,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Tombol foto
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Palet warna
                if (_palette.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _palette.map((color) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          children: [
                            // Lingkaran warna
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color.fromRGBO(color.r, color.g, color.b, 1.0),
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black45, blurRadius: 4)
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Label HEX
                            Text(
                              color.toHex(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

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
              ],
            ),
          ),
        ],
      ),
    );
  }
}