import 'package:hive/hive.dart';
import '../../pcd/kmeans_extractor.dart';

part 'palette_entry.g.dart';

@HiveType(typeId: 0)
class PaletteEntry extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String objectLabel; // Label objek dari YOLO (misal: "person", "chair")

  @HiveField(2)
  final List<Map<String, dynamic>> colors; // List 5 warna

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final String? imagePath; // Path foto yang dijepret

  @HiveField(5)
  final String? thumbnailPath; // Tambahan baru

  PaletteEntry({
    required this.id,
    required this.objectLabel,
    required this.colors,
    required this.createdAt,
    this.imagePath,
    this.thumbnailPath,
  });

  // Konversi dari List<PaletteColor> ke format yang bisa disimpan
  static List<Map<String, dynamic>> colorsFromPalette(
      List<PaletteColor> palette) {
    return palette.map((c) => {
      'r': c.r,
      'g': c.g,
      'b': c.b,
      'hex': c.toHex(),
      'cmyk': c.toCMYK(),
    }).toList();
  }

  // Konversi ke Map untuk MongoDB
  Map<String, dynamic> toMongoMap() {
    return {
      '_id': id,
      'objectLabel': objectLabel,
      'colors': colors,
      'createdAt': createdAt.toIso8601String(),
      'imagePath': imagePath,
      'thumbnailPath': thumbnailPath,
    };
  }

  @override
  String toString() => 'PaletteEntry($objectLabel, ${colors.length} colors)';
}