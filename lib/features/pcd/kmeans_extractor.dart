import 'dart:math';
import 'package:image/image.dart' as img;

class PaletteColor {
  final int r, g, b;

  PaletteColor(this.r, this.g, this.b);

  String toHex() =>
      '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'.toUpperCase();

  Map<String, int> toCMYK() {
    final rN = r / 255.0;
    final gN = g / 255.0;
    final bN = b / 255.0;

    final k = 1.0 - [rN, gN, bN].reduce(max);
    if (k == 1.0) return {'c': 0, 'm': 0, 'y': 0, 'k': 100};

    final c = ((1.0 - rN - k) / (1.0 - k) * 100).round();
    final m = ((1.0 - gN - k) / (1.0 - k) * 100).round();
    final y = ((1.0 - bN - k) / (1.0 - k) * 100).round();
    final kInt = (k * 100).round();

    return {'c': c, 'm': m, 'y': y, 'k': kInt};
  }

  @override
  String toString() => 'PaletteColor(${toHex()})';
}

class KMeansExtractor {
  final int k;
  final int maxIterations;
  final int maxSamples;

  KMeansExtractor({
    this.k = 5,
    this.maxIterations = 20,
    this.maxSamples = 500,
  });

  /// Ekstraksi palet warna dari area bounding box dalam gambar
  List<PaletteColor> extract({
    required img.Image image,
    required double x1,
    required double y1,
    required double x2,
    required double y2,
  }) {
    // Konversi koordinat ternormalisasi [0,1] ke koordinat piksel
    final imgWidth = image.width;
    final imgHeight = image.height;

    final left   = (x1 * imgWidth).round().clamp(0, imgWidth - 1);
    final top    = (y1 * imgHeight).round().clamp(0, imgHeight - 1);
    final right  = (x2 * imgWidth).round().clamp(0, imgWidth - 1);
    final bottom = (y2 * imgHeight).round().clamp(0, imgHeight - 1);

    // Crop area bounding box
    final cropped = img.copyCrop(
      image,
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    );

    // Ambil sampel piksel (hindari proses semua piksel)
    final pixels = _samplePixels(cropped);
    if (pixels.isEmpty) return [];

    // Jalankan K-Means
    return _kMeans(pixels);
  }

  /// Ambil sampel acak dari piksel gambar
  List<List<int>> _samplePixels(img.Image image) {
    final pixels = <List<int>>[];
    final random = Random(42); // Seed tetap agar hasil konsisten

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        pixels.add([pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()]);
      }
    }

    // Acak dan ambil maksimal maxSamples piksel
    pixels.shuffle(random);
    return pixels.take(maxSamples).toList();
  }

  /// Algoritma K-Means Clustering
  List<PaletteColor> _kMeans(List<List<int>> pixels) {
    final random = Random(42);

    // Inisialisasi centroid secara acak dari piksel yang ada
    List<List<double>> centroids = List.generate(k, (_) {
      final p = pixels[random.nextInt(pixels.length)];
      return [p[0].toDouble(), p[1].toDouble(), p[2].toDouble()];
    });

    List<int> assignments = List.filled(pixels.length, 0);

    for (int iter = 0; iter < maxIterations; iter++) {
      bool changed = false;

      // Assignment step: setiap piksel ke centroid terdekat
      for (int i = 0; i < pixels.length; i++) {
        final nearest = _nearestCentroid(pixels[i], centroids);
        if (nearest != assignments[i]) {
          assignments[i] = nearest;
          changed = true;
        }
      }

      // Jika tidak ada perubahan, konvergen
      if (!changed) {
        print('K-Means converged at iteration $iter');
        break;
      }

      // Update step: hitung ulang centroid
      final sums = List.generate(k, (_) => [0.0, 0.0, 0.0]);
      final counts = List.filled(k, 0);

      for (int i = 0; i < pixels.length; i++) {
        final c = assignments[i];
        sums[c][0] += pixels[i][0];
        sums[c][1] += pixels[i][1];
        sums[c][2] += pixels[i][2];
        counts[c]++;
      }

      for (int c = 0; c < k; c++) {
        if (counts[c] > 0) {
          centroids[c] = [
            sums[c][0] / counts[c],
            sums[c][1] / counts[c],
            sums[c][2] / counts[c],
          ];
        }
      }
    }

    // Konversi centroid ke PaletteColor, urutkan dari gelap ke terang
    final colors = centroids.map((c) => PaletteColor(
      c[0].round().clamp(0, 255),
      c[1].round().clamp(0, 255),
      c[2].round().clamp(0, 255),
    )).toList();

    colors.sort((a, b) {
      final brightnessA = 0.299 * a.r + 0.587 * a.g + 0.114 * a.b;
      final brightnessB = 0.299 * b.r + 0.587 * b.g + 0.114 * b.b;
      return brightnessA.compareTo(brightnessB);
    });

    return colors;
  }

  /// Hitung jarak Euclidean antara piksel dan centroid
  int _nearestCentroid(List<int> pixel, List<List<double>> centroids) {
    int nearest = 0;
    double minDist = double.infinity;

    for (int c = 0; c < centroids.length; c++) {
      final dr = pixel[0] - centroids[c][0];
      final dg = pixel[1] - centroids[c][1];
      final db = pixel[2] - centroids[c][2];
      final dist = dr * dr + dg * dg + db * db;
      if (dist < minDist) {
        minDist = dist;
        nearest = c;
      }
    }

    return nearest;
  }
}