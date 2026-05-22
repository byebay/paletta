import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../features/camera/camera_controller_wrapper.dart';
import '../features/inference/isolate_runner.dart';
import '../features/inference/model_loader.dart';
import '../features/inference/yolo_inference_engine.dart';
import '../features/overlay/bounding_box_painter.dart';
import '../features/pcd/kmeans_extractor.dart';
import '../config/env_config.dart';
import 'dart:typed_data';

enum FlashToggleMode { off, alwaysOn, onCapture }

class ScannerScreen extends StatefulWidget {
  final ModelLoader modelLoader;
  const ScannerScreen({super.key, required this.modelLoader});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class CameraFrameData {
  final int width;
  final int height;
  final List<PlaneData> planes;

  CameraFrameData({required this.width, required this.height, required this.planes});

  static CameraFrameData fromCameraImage(CameraImage image) {
    return CameraFrameData(
      width: image.width,
      height: image.height,
      planes: image.planes.map((p) => PlaneData(
        bytes: Uint8List.fromList(p.bytes), // Copy bytes segera
        bytesPerRow: p.bytesPerRow,
        bytesPerPixel: p.bytesPerPixel,
      )).toList(),
    );
  }
}

class PlaneData {
  final Uint8List bytes;
  final int bytesPerRow;
  final int? bytesPerPixel;

  PlaneData({required this.bytes, required this.bytesPerRow, this.bytesPerPixel});
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  final CameraControllerWrapper _cameraWrapper = CameraControllerWrapper();
  late final YoloInferenceEngine _engine;
  late final IsolateRunner _isolateRunner;

  bool _captureNextFrame = false;
  Completer<CameraFrameData>? _frameCompleter;

  // Bounding box
  List<DetectionResult> _detections = [];

  // Palet warna
  List<PaletteColor> _palette = [];
  bool _isCapturing = false;
  bool _showShutterEffect = false;

  // Toggle
  bool _showBoundingBox = true;
  FlashToggleMode _flashMode = FlashToggleMode.off;

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

    // Stream HANYA memproses frame saat diminta untuk capture
    await _cameraWrapper.controller?.startImageStream((image) {
      if (_captureNextFrame && _frameCompleter != null && !_frameCompleter!.isCompleted) {
        _captureNextFrame = false;
        _frameCompleter!.complete(CameraFrameData.fromCameraImage(image));
      }
    });

    setState(() {});
  }

  // Tombol capture — proses frame saat ini
  Future<void> _captureAndExtract() async {
    if (_isCapturing) return;
    _isCapturing = true;
    setState(() {
      _detections = []; // Sembunyikan bounding box lama saat mulai capture
    });

    // Nyalakan flash jika mode onCapture
    if (_flashMode == FlashToggleMode.onCapture) {
      await _cameraWrapper.controller?.setFlashMode(FlashMode.torch);
      await Future.delayed(const Duration(milliseconds: 500)); // Beri waktu AE menyesuaikan
    }

    try {
      _frameCompleter = Completer<CameraFrameData>();
      _captureNextFrame = true;

      // Efek shutter kamera
      setState(() => _showShutterEffect = true);
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) setState(() => _showShutterEffect = false);
      });

      final frame = await _frameCompleter!.future;

      // Dapatkan bounding box (inference hanya dilakukan saat capture)
      final results = await _isolateRunner.run(frame);

      final converted = await _isolateRunner.convertFrame(frame);
      if (converted == null) return;

      final extractor = KMeansExtractor(k: EnvConfig.kValue);
      List<PaletteColor> palette;

      // Ekstrak dari bounding box hanya jika toggle ON dan ada deteksi
      if (_showBoundingBox && results.isNotEmpty) {
        palette = extractor.extract(
          image: converted,
          x1: results.first.x1,
          y1: results.first.y1,
          x2: results.first.x2,
          y2: results.first.y2,
        );
      } else {
        // Fallback: ekstrak dari seluruh frame
        palette = extractor.extract(
          image: converted,
          x1: 0.0,
          y1: 0.0,
          x2: 1.0,
          y2: 1.0,
        );
      }

      if (mounted) {
        setState(() {
          _detections = results; // Tampilkan bounding box untuk frame yang dicapture
          _palette = palette;
        });
      }
    } catch (e) {
      print('Capture error: $e');
    } finally {
      // Matikan flash setelah capture jika mode onCapture
      if (_flashMode == FlashToggleMode.onCapture) {
        await _cameraWrapper.controller?.setFlashMode(FlashMode.off);
      }
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _toggleFlash() async {
    // Rotasi: off → alwaysOn → onCapture → off
    _flashMode = FlashToggleMode
        .values[(_flashMode.index + 1) % FlashToggleMode.values.length];

    await _cameraWrapper.controller?.setFlashMode(
      _flashMode == FlashToggleMode.alwaysOn
          ? FlashMode.torch
          : FlashMode.off,
    );

    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _cameraWrapper.controller?.setFlashMode(FlashMode.off);
      _cameraWrapper.controller?.stopImageStream();
      _cameraWrapper.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    _cameraWrapper.controller?.setFlashMode(FlashMode.off);
    WidgetsBinding.instance.removeObserver(this);
    _cameraWrapper.controller?.stopImageStream();
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
        title: const Text(
          'Scanner',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          // Toggle bounding box
          IconButton(
            onPressed: () =>
                setState(() => _showBoundingBox = !_showBoundingBox),
            icon: Icon(
              _showBoundingBox ? Icons.grid_on : Icons.grid_off,
              color: _showBoundingBox ? Colors.white : Colors.grey,
            ),
            tooltip: _showBoundingBox ? 'Sembunyikan Box' : 'Tampilkan Box',
          ),

          // Toggle senter 3 mode
          IconButton(
            onPressed: _toggleFlash,
            icon: Icon(
              _flashMode == FlashToggleMode.alwaysOn
                  ? Icons.flash_on
                  : _flashMode == FlashToggleMode.onCapture
                      ? Icons.flash_auto
                      : Icons.flash_off,
              color: _flashMode == FlashToggleMode.off
                  ? Colors.white
                  : Colors.yellow,
            ),
            tooltip: _flashMode == FlashToggleMode.off
                ? 'Senter: Off'
                : _flashMode == FlashToggleMode.alwaysOn
                    ? 'Senter: Selalu On'
                    : 'Senter: Saat Capture',
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera preview + overlay
          Expanded(
            child: Stack(
              children: [
                // Camera preview
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _cameraWrapper
                        .controller!.value.previewSize!.height,
                    height: _cameraWrapper
                        .controller!.value.previewSize!.width,
                    child: CameraPreview(_cameraWrapper.controller!),
                  ),
                ),

                // Bounding box overlay
                if (_detections.isNotEmpty && _showBoundingBox)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: BoundingBoxPainter(
                        detections: _detections,
                        imageSize: Size(
                          _cameraWrapper
                              .controller!.value.previewSize!.height,
                          _cameraWrapper
                              .controller!.value.previewSize!.width,
                        ),
                      ),
                    ),
                  ),

                // Shutter effect overlay
                if (_showShutterEffect)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black,
                    ),
                  ),
              ],
            ),
          ),

          // Area bawah — palet + tombol
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
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color.fromRGBO(
                                    color.r, color.g, color.b, 1.0),
                                border:
                                    Border.all(color: Colors.white, width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 4,
                                  )
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
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

                // Tombol capture
                GestureDetector(
                  onTap: _isCapturing ? null : _captureAndExtract,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: _isCapturing
                          ? Colors.grey
                          : Colors.white.withOpacity(0.2),
                    ),
                    child: _isCapturing
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 32,
                          ),
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