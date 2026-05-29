import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import '../features/gallery/providers/gallery_provider.dart';
import '../features/gallery/models/palette_entry.dart';
import '../features/inference/yolo_inference_engine.dart';
import '../features/pcd/kmeans_extractor.dart';
import '../config/env_config.dart';
import '../core/utils/image_storage_service.dart';
import 'dart:math' as math;
import 'dart:async';

class EditScreen extends StatefulWidget {
  final img.Image capturedImage;
  final List<DetectionResult> detections;
  final String label;

  const EditScreen({
    super.key,
    required this.capturedImage,
    required this.detections,
    required this.label,
  });

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  // Parameter PCD
  double _contrast = 1.0;   // 0.5 - 2.0
  double _gamma = 1.0;      // 0.5 - 2.5
  double _sharpness = 0.0;  // 0.0 - 3.0
  bool _histogramEq = false;

  // State
  img.Image? _processedImage;
  Uint8List? _previewBytes;
  List<PaletteColor> _palette = [];
  bool _isProcessing = false;
  bool _isSaving = false;
  Timer? _debounceTimer;
  late TextEditingController _labelController;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.label);
    _applyEffects();
  }

  Future<void> _applyEffects() async {
    if (_isProcessing) return;
    _isProcessing = true;

    // Jalankan semua efek PCD di background
    final result = await Future.microtask(() => _processImage(
      image: widget.capturedImage,
      contrast: _contrast,
      gamma: _gamma,
      sharpness: _sharpness,
      histogramEq: _histogramEq,
    ));

    // Ekstrak palet dari gambar hasil edit
    final extractor = KMeansExtractor(k: EnvConfig.kValue);
    List<PaletteColor> palette;

    if (widget.detections.isNotEmpty) {
      palette = extractor.extract(
        image: result,
        x1: widget.detections.first.x1,
        y1: widget.detections.first.y1,
        x2: widget.detections.first.x2,
        y2: widget.detections.first.y2,
      );
    } else {
      palette = extractor.extract(
        image: result,
        x1: 0.0, y1: 0.0,
        x2: 1.0, y2: 1.0,
      );
    }

    // Encode ke JPEG untuk preview
    final bytes = Uint8List.fromList(img.encodeJpg(result, quality: 85));

    if (mounted) {
      setState(() {
        _processedImage = result;
        _previewBytes = bytes;
        _palette = palette;
        _isProcessing = false;
      });
    }
  }

  // Pipeline PCD lengkap
  static img.Image _processImage({
    required img.Image image,
    required double contrast,
    required double gamma,
    required double sharpness,
    required bool histogramEq,
  }) {
    img.Image result = image.clone();

    // 1. Contrast Stretching
    if (contrast != 1.0) {
      result = _applyContrast(result, contrast);
    }

    // 2. Histogram Equalization
    if (histogramEq) {
      result = _applyHistogramEqualization(result);
    }

    // 3. Gamma Correction
    if (gamma != 1.0) {
      result = _applyGamma(result, gamma);
    }

    // 4. Unsharp Masking (Sharpening)
    if (sharpness > 0) {
      result = _applySharpen(result, sharpness);
    }

    return result;
  }

  // --- Operasi PCD ---

  static img.Image _applyContrast(img.Image image, double factor) {
    final output = img.Image(width: image.width, height: image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        int r = ((factor * (pixel.r - 128)) + 128).round().clamp(0, 255);
        int g = ((factor * (pixel.g - 128)) + 128).round().clamp(0, 255);
        int b = ((factor * (pixel.b - 128)) + 128).round().clamp(0, 255);
        output.setPixelRgb(x, y, r, g, b);
      }
    }
    return output;
  }

  static img.Image _applyHistogramEqualization(img.Image image) {
    // Hitung histogram untuk setiap channel
    final histR = List.filled(256, 0);
    final histG = List.filled(256, 0);
    final histB = List.filled(256, 0);
    final total = image.width * image.height;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        histR[pixel.r.toInt()]++;
        histG[pixel.g.toInt()]++;
        histB[pixel.b.toInt()]++;
      }
    }

    // Hitung CDF (Cumulative Distribution Function)
    final cdfR = List.filled(256, 0);
    final cdfG = List.filled(256, 0);
    final cdfB = List.filled(256, 0);

    cdfR[0] = histR[0];
    cdfG[0] = histG[0];
    cdfB[0] = histB[0];

    for (int i = 1; i < 256; i++) {
      cdfR[i] = cdfR[i - 1] + histR[i];
      cdfG[i] = cdfG[i - 1] + histG[i];
      cdfB[i] = cdfB[i - 1] + histB[i];
    }

    // Normalisasi CDF ke [0, 255]
    final output = img.Image(width: image.width, height: image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = ((cdfR[pixel.r.toInt()] / total) * 255).round().clamp(0, 255);
        final g = ((cdfG[pixel.g.toInt()] / total) * 255).round().clamp(0, 255);
        final b = ((cdfB[pixel.b.toInt()] / total) * 255).round().clamp(0, 255);
        output.setPixelRgb(x, y, r, g, b);
      }
    }

    return output;
  }

  static img.Image _applyGamma(img.Image image, double gamma) {
    // Buat lookup table untuk efisiensi
    final lut = List.generate(256, (i) {
      return (255.0 * math.pow(i / 255.0, 1.0 / gamma)).round().clamp(0, 255);
    });

    final output = img.Image(width: image.width, height: image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        output.setPixelRgb(
          x, y,
          lut[pixel.r.toInt()],
          lut[pixel.g.toInt()],
          lut[pixel.b.toInt()],
        );
      }
    }
    return output;
  }

  static img.Image _applySharpen(img.Image image, double amount) {
    final blurred = img.gaussianBlur(image, radius: 1);
    final output = img.Image(width: image.width, height: image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final orig = image.getPixel(x, y);
        final blur = blurred.getPixel(x, y);
        int r = (orig.r + amount * (orig.r - blur.r)).round().clamp(0, 255);
        int g = (orig.g + amount * (orig.g - blur.g)).round().clamp(0, 255);
        int b = (orig.b + amount * (orig.b - blur.b)).round().clamp(0, 255);
        output.setPixelRgb(x, y, r, g, b);
      }
    }
    return output;
  }

  Future<void> _save() async {
    if (_processedImage == null || _isSaving) return;
    _isSaving = true;
    setState(() {});

    try {
      final paths = await ImageStorageService.saveImageInBackground(
          _processedImage!);

      final label = _labelController.text.trim().isEmpty
          ? 'unknown'
          : _labelController.text.trim();

      await context.read<GalleryProvider>().savePalette(
        palette: _palette,
        objectLabel: label, // Pakai dari controller
        imagePath: paths['originalPath'],
        thumbnailPath: paths['thumbnailPath'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Palet berhasil disimpan!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context); // Kembali ke scanner
      }
    } catch (e) {
      print('Save error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetToDefault() {
    setState(() {
      _contrast = 1.0;
      _gamma = 1.0;
      _sharpness = 0.0;
      _histogramEq = false;
    });
    _applyEffects();
  }

  void _debouncedApply() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _applyEffects();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Edit Foto',
            style: TextStyle(color: Colors.white)),
        actions: [
          // Tombol simpan
          TextButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save, color: Colors.white),
            label: const Text('Simpan',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Preview foto
          Expanded(
            flex: 3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_previewBytes != null)
                  Image.memory(
                    _previewBytes!,
                    fit: BoxFit.contain,
                  )
                else
                  const CircularProgressIndicator(),

                // Loading overlay saat processing
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),

          // Palette preview
          if (_palette.isNotEmpty)
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _palette.map((color) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color.fromRGBO(color.r, color.g, color.b, 1.0),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          color.toHex(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 8),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          Container(
            color: Colors.black,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.label_outline, color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _labelController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Nama objek...',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                // Tombol clear
                GestureDetector(
                  onTap: () => _labelController.clear(),
                  child: const Icon(Icons.close, color: Colors.white38, size: 16),
                ),
              ],
            ),
          ),
          // Panel kontrol PCD
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.grey[900],
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Contrast
                  _buildSlider(
                    label: 'Kontras',
                    value: _contrast,
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    defaultValue: 1.0,
                    onChanged: (v) {
                      setState(() => _contrast = v);
                      _debouncedApply();
                    },
                    valueLabel: _contrast.toStringAsFixed(1),
                  ),

                  // Gamma
                  _buildSlider(
                    label: 'Gamma',
                    value: _gamma,
                    min: 0.5,
                    max: 2.5,
                    divisions: 40,
                    defaultValue: 1.0,
                    onChanged: (v) {
                      setState(() => _gamma = v);
                      _debouncedApply();
                    },
                    valueLabel: _gamma.toStringAsFixed(1),
                  ),

                  // Sharpness
                  _buildSlider(
                    label: 'Penajaman',
                    value: _sharpness,
                    min: 0.0,
                    max: 3.0,
                    divisions: 30,
                    defaultValue: 0.0,
                    onChanged: (v) {
                      setState(() => _sharpness = v);
                      _debouncedApply();
                    },
                    valueLabel: _sharpness.toStringAsFixed(1),
                  ),

                  // Histogram Equalization Toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Histogram Equalization',
                            style: TextStyle(
                                color: Colors.white, fontSize: 13)),
                        Switch(
                          value: _histogramEq,
                          activeColor: Colors.blue,
                          onChanged: (v) {
                            setState(() => _histogramEq = v);
                            _debouncedApply();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String valueLabel,
    required double defaultValue,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              activeColor: Colors.blue,
              inactiveColor: Colors.white24,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(valueLabel,
                style:
                    const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          // Tombol reset per slider
          GestureDetector(
            onTap: () => onChanged(defaultValue),
            child: const Icon(Icons.refresh,
                color: Colors.white38, size: 18),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }
}