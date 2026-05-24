import 'package:image/image.dart' as img;

class ImageEnhancer {
  /// Unsharp Masking — teknik penajaman citra klasik
  /// Formula: sharpened = original + amount * (original - blurred)
  static img.Image sharpen(img.Image image, {double amount = 1.5}) {
    // Langkah 1: Blur gambar (Gaussian Blur sebagai low-pass filter)
    final blurred = img.gaussianBlur(image, radius: 2);

    // Langkah 2: Hitung unsharp mask dan tambahkan ke original
    final output = img.Image(width: image.width, height: image.height);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final orig = image.getPixel(x, y);
        final blur = blurred.getPixel(x, y);

        // Unsharp mask: original + amount * (original - blurred)
        int r = (orig.r + amount * (orig.r - blur.r)).round().clamp(0, 255);
        int g = (orig.g + amount * (orig.g - blur.g)).round().clamp(0, 255);
        int b = (orig.b + amount * (orig.b - blur.b)).round().clamp(0, 255);

        output.setPixelRgb(x, y, r, g, b);
      }
    }

    return output;
  }
}