import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../features/camera/camera_controller_wrapper.dart';
import '../features/inference/isolate_runner.dart';
import '../features/inference/model_loader.dart';
import '../features/inference/yolo_inference_engine.dart';
import '../features/overlay/bounding_box_painter.dart';
import '../features/pcd/kmeans_extractor.dart';
import '../config/env_config.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import '../features/gallery/providers/gallery_provider.dart';
import '../core/utils/image_storage_service.dart';
import 'edit_screen.dart';

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

class _CameraControlButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final Color activeColor;

  const _CameraControlButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? activeColor.withOpacity(0.2)
              : Colors.black54,
          border: Border.all(
            color: isActive ? activeColor : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? activeColor : Colors.white,
          size: 18,
        ),
      ),
    );
  }
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
  bool _showBoundingBox = false;
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
          _detections = results;
          _palette = palette;
        });

        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();

        final label = (_showBoundingBox && results.isNotEmpty) ? results.first.label : 'unknown';
        final passedDetections = _showBoundingBox ? results : <DetectionResult>[];

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditScreen(
              capturedImage: converted,
              detections: passedDetections,
              label: label,
            ),
          ),
        );
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

  void _toggleBoundingBox() {
    setState(() {
      _showBoundingBox = !_showBoundingBox;
      if (!_showBoundingBox) {
        _detections = [];
      }
    });
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF2196F3)),
              SizedBox(height: 16),
              Text('Menyiapkan kamera...',
                  style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // === CAMERA AREA ===
          Expanded(
            child: Stack(
              children: [
                // Camera preview
                Positioned.fill(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _cameraWrapper.controller!.value.previewSize!.height,
                      height: _cameraWrapper.controller!.value.previewSize!.width,
                      child: CameraPreview(_cameraWrapper.controller!),
                    ),
                  ),
                ),

                // Bounding box overlay
                if (_detections.isNotEmpty && _showBoundingBox)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: BoundingBoxPainter(
                        detections: _detections,
                        imageSize: Size(
                          _cameraWrapper.controller!.value.previewSize!.height,
                          _cameraWrapper.controller!.value.previewSize!.width,
                        ),
                      ),
                    ),
                  ),

                // Shutter effect
                if (_showShutterEffect)
                  Positioned.fill(
                    child: Container(color: Colors.white),
                  ),

                // Top controls overlay
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // App title
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Paletta',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),

                      // Control buttons
                      Row(
                        children: [
                          // Toggle bounding box
                          _CameraControlButton(
                            icon: _showBoundingBox
                                ? Icons.grid_on
                                : Icons.grid_off,
                            isActive: _showBoundingBox,
                            onTap: _toggleBoundingBox,
                            activeColor: const Color(0xFF2196F3),
                          ),
                          const SizedBox(width: 8),

                          // Toggle flash
                          _CameraControlButton(
                            icon: _flashMode == FlashToggleMode.alwaysOn
                                ? Icons.flash_on
                                : _flashMode == FlashToggleMode.onCapture
                                    ? Icons.flash_auto
                                    : Icons.flash_off,
                            isActive: _flashMode != FlashToggleMode.off,
                            onTap: _toggleFlash,
                            activeColor: Colors.yellow,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Detection label overlay
                if (_detections.isNotEmpty && _showBoundingBox)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_detections.first.label} '
                        '${(_detections.first.confidence * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // === BOTTOM AREA ===
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              top: 20,
              left: 24,
              right: 24,
              bottom: 20,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(child: SizedBox()),
                GestureDetector(
                  onTap: _isCapturing ? null : _captureAndExtract,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isCapturing
                          ? Colors.grey.shade300
                          : const Color(0xFF2196F3),
                      boxShadow: _isCapturing
                          ? []
                          : [
                              BoxShadow(
                                color: const Color(0xFF2196F3).withOpacity(0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                    ),
                    child: _isCapturing
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.camera_alt, color: Colors.white, size: 28),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
