import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImageStorageService {
  static const int _thumbnailSize = 200;
  static const String _folderName = 'paletta_images';

  /// Simpan foto asli + generate thumbnail
  /// Return: map berisi path foto asli dan thumbnail
  static Future<Map<String, String>> saveImage(img.Image image) async {
    final dir = await _getImageDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Simpan foto asli
    final originalPath = '${dir.path}/original_$timestamp.jpg';
    final originalBytes = img.encodeJpg(image, quality: 75);
    await File(originalPath).writeAsBytes(originalBytes);

    // Generate thumbnail — pertahankan aspect ratio portrait
    final aspectRatio = image.width / image.height;
    final thumbWidth = (150 * aspectRatio).round();
    const thumbHeight = 200;

    final thumbnail = img.copyResize(
      image,
      width: thumbWidth,
      height: thumbHeight,
      interpolation: img.Interpolation.cubic, // Kualitas lebih baik dari linear
    );

    final thumbnailPath = '${dir.path}/thumb_$timestamp.jpg';
    final thumbnailBytes = img.encodeJpg(thumbnail, quality: 90);
    await File(thumbnailPath).writeAsBytes(thumbnailBytes);

    return {
      'originalPath': originalPath,
      'thumbnailPath': thumbnailPath,
    };
  }

  static Future<Map<String, String>> saveImageFromBytes(
      List<int> jpegBytes) async {
    final dir = await _getImageDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Simpan foto asli
    final originalPath = '${dir.path}/original_$timestamp.jpg';
    await File(originalPath).writeAsBytes(jpegBytes);

    // Decode hanya untuk thumbnail
    final decoded = img.decodeJpg(Uint8List.fromList(jpegBytes));
    if (decoded == null) return {'originalPath': originalPath, 'thumbnailPath': ''};

    const thumbHeight = 200;
    final aspectRatio = decoded.width / decoded.height;
    final thumbWidth = (150 * aspectRatio).round();

    final thumbnail = img.copyResize(
      decoded,
      width: thumbWidth,
      height: thumbHeight,
      interpolation: img.Interpolation.linear,
    );

    final thumbnailPath = '${dir.path}/thumb_$timestamp.jpg';
    await File(thumbnailPath)
        .writeAsBytes(img.encodeJpg(thumbnail, quality: 90));

    return {
      'originalPath': originalPath,
      'thumbnailPath': thumbnailPath,
    };
  }

  /// Memproses encode image di background thread agar tidak block UI dan menghindari OOM
  static Future<Map<String, String>> saveImageInBackground(img.Image image) async {
    final dir = await _getImageDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Jalankan komputasi berat di background isolate
    final result = await compute(_encodeAndGenerateThumbnail, image);

    final originalPath = '${dir.path}/original_$timestamp.jpg';
    await File(originalPath).writeAsBytes(result['original']!);

    final thumbnailPath = '${dir.path}/thumb_$timestamp.jpg';
    await File(thumbnailPath).writeAsBytes(result['thumbnail']!);

    return {
      'originalPath': originalPath,
      'thumbnailPath': thumbnailPath,
    };
  }

  /// Hapus foto dan thumbnail berdasarkan path
  static Future<void> deleteImage(
      String? originalPath, String? thumbnailPath) async {
    if (originalPath != null) {
      final file = File(originalPath);
      if (await file.exists()) await file.delete();
    }
    if (thumbnailPath != null) {
      final file = File(thumbnailPath);
      if (await file.exists()) await file.delete();
    }
  }

  static Future<Directory> _getImageDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${appDir.path}/$_folderName');
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    return imageDir;
  }
}

// Top-level function for background isolate
Map<String, Uint8List> _encodeAndGenerateThumbnail(img.Image image) {
  // Perbaiki orientasi: gambar mentah dari stream tidak memiliki EXIF.
  // Karena sensor kamera biasanya landscape, jika width > height kita putar 90 derajat searah jarum jam.
  final oriented = image.width > image.height ? img.copyRotate(image, angle: 90) : image;

  // Simpan foto asli
  final originalBytes = img.encodeJpg(oriented, quality: 90);

  // Generate thumbnail
  final aspectRatio = oriented.width / oriented.height;
  final thumbWidth = (200 * aspectRatio).round();
  const thumbHeight = 300;

  final thumbnail = img.copyResize(
    oriented,
    width: thumbWidth,
    height: thumbHeight,
    interpolation: img.Interpolation.linear,
  );

  final thumbnailBytes = img.encodeJpg(thumbnail, quality: 90);

  return {
    'original': Uint8List.fromList(originalBytes),
    'thumbnail': Uint8List.fromList(thumbnailBytes),
  };
}