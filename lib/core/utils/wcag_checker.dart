class WcagResult {
  final double contrastRatio;
  final bool passAA;      // Minimum 4.5:1 untuk teks normal
  final bool passAAA;     // Minimum 7.0:1 untuk teks enhanced
  final String rating;

  WcagResult({
    required this.contrastRatio,
    required this.passAA,
    required this.passAAA,
    required this.rating,
  });

  @override
  String toString() =>
      'Contrast: ${contrastRatio.toStringAsFixed(2)}:1 | $rating';
}

class WcagChecker {
  /// Hitung contrast ratio antara dua warna (foreground vs background)
  /// Formula: (L1 + 0.05) / (L2 + 0.05) dimana L1 > L2
  static WcagResult check(
    int r1, int g1, int b1, // Warna 1
    int r2, int g2, int b2, // Warna 2
  ) {
    final l1 = _relativeLuminance(r1, g1, b1);
    final l2 = _relativeLuminance(r2, g2, b2);

    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;

    final ratio = (lighter + 0.05) / (darker + 0.05);

    final passAA = ratio >= 4.5;
    final passAAA = ratio >= 7.0;

    String rating;
    if (passAAA) {
      rating = 'AAA ✓';
    } else if (passAA) {
      rating = 'AA ✓';
    } else if (ratio >= 3.0) {
      rating = 'AA Large ✓'; // Lulus untuk teks besar (18pt+)
    } else {
      rating = 'Fail ✗';
    }

    return WcagResult(
      contrastRatio: ratio,
      passAA: passAA,
      passAAA: passAAA,
      rating: rating,
    );
  }

  /// Hitung relative luminance dari satu warna
  /// Formula standar WCAG 2.1
  static double _relativeLuminance(int r, int g, int b) {
    final rLin = _linearize(r / 255.0);
    final gLin = _linearize(g / 255.0);
    final bLin = _linearize(b / 255.0);
    return 0.2126 * rLin + 0.7152 * gLin + 0.0722 * bLin;
  }

  /// Konversi nilai sRGB ke linear
  static double _linearize(double value) {
    if (value <= 0.04045) {
      return value / 12.92;
    } else {
      return ((value + 0.055) / 1.055) * ((value + 0.055) / 1.055);
    }
  }

  /// Cek apakah warna teks yang cocok adalah hitam atau putih
  /// berdasarkan luminance background
  static bool shouldUseWhiteText(int r, int g, int b) {
    final luminance = _relativeLuminance(r, g, b);
    return luminance < 0.179;
  }

  /// Cek semua kombinasi pasangan warna dari sebuah palet
  static List<WcagPairResult> checkPalette(
      List<Map<String, dynamic>> colors) {
    final results = <WcagPairResult>[];

    for (int i = 0; i < colors.length; i++) {
      for (int j = i + 1; j < colors.length; j++) {
        final c1 = colors[i];
        final c2 = colors[j];

        final result = check(
          c1['r'] as int, c1['g'] as int, c1['b'] as int,
          c2['r'] as int, c2['g'] as int, c2['b'] as int,
        );

        results.add(WcagPairResult(
          color1: c1,
          color2: c2,
          result: result,
        ));
      }
    }

    // Urutkan dari kontras tertinggi
    results.sort((a, b) =>
        b.result.contrastRatio.compareTo(a.result.contrastRatio));

    return results;
  }
}

class WcagPairResult {
  final Map<String, dynamic> color1;
  final Map<String, dynamic> color2;
  final WcagResult result;

  WcagPairResult({
    required this.color1,
    required this.color2,
    required this.result,
  });
}