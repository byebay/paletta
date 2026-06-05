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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF212121)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Foto',
          style: TextStyle(
            color: Color(0xFF212121),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: Colors.grey.shade200, height: 1),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_alt, size: 16),
              label: Text(_isSaving ? 'Menyimpan...' : 'Simpan',
                  style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // === PHOTO PREVIEW ===
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: const Color(0xFFF5F5F5)),
                if (_previewBytes != null)
                  Image.memory(
                    _previewBytes!,
                    fit: BoxFit.contain,
                  )
                else
                  const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF2196F3)),
                  ),

                // Loading overlay
                if (_isProcessing)
                  Container(
                    color: Colors.white54,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                              color: Color(0xFF2196F3)),
                          SizedBox(height: 12),
                          Text('Memproses...',
                              style: TextStyle(
                                  color: Color(0xFF2196F3),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // === PALETTE + LABEL ===
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label field
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.label_outline,
                          color: Color(0xFF2196F3), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _labelController,
                          style: const TextStyle(
                              color: Color(0xFF212121),
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                          decoration: const InputDecoration(
                            hintText: 'Nama objek...',
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _labelController.clear(),
                        child: Icon(Icons.close,
                            color: Colors.grey.shade400, size: 16),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Palette swatches
                if (_palette.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _palette.map((color) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Column(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color.fromRGBO(
                                    color.r, color.g, color.b, 1.0),
                                border: Border.all(
                                    color: Colors.grey.shade200, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color.fromRGBO(
                                        color.r, color.g, color.b, 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              color.toHex(),
                              style: const TextStyle(
                                color: Color(0xFF212121),
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),

          Divider(color: Colors.grey.shade100, height: 1),

          // === PCD CONTROLS ===
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  // Section header
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 4),
                    child: Text(
                      'PENGOLAHAN CITRA',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

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
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.equalizer,
                                color: _histogramEq
                                    ? const Color(0xFF2196F3)
                                    : Colors.grey,
                                size: 16),
                            const SizedBox(width: 8),
                            const Text(
                              'Histogram Equalization',
                              style: TextStyle(
                                  color: Color(0xFF212121), fontSize: 13),
                            ),
                          ],
                        ),
                        Switch(
                          value: _histogramEq,
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
    final isModified = value != defaultValue;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                      color: Color(0xFF212121),
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
                if (isModified)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF2196F3),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              valueLabel,
              style: TextStyle(
                color: isModified
                    ? const Color(0xFF2196F3)
                    : Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(defaultValue),
            child: Icon(
              Icons.refresh,
              color: isModified ? const Color(0xFF2196F3) : Colors.grey.shade300,
              size: 16,
            ),
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