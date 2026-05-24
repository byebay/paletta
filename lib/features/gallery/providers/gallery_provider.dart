import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/palette_entry.dart';
import '../repositories/local_repository.dart';
import '../repositories/cloud_repository.dart';
import '../../pcd/kmeans_extractor.dart';
import '../../../config/env_config.dart';
import 'package:image/image.dart' as img;
import '../../../core/utils/image_storage_service.dart';

class GalleryProvider extends ChangeNotifier {
  final LocalRepository _local = LocalRepository();
  final CloudRepository _cloud = CloudRepository();

  List<PaletteEntry> _entries = [];
  bool _isLoading = false;

  List<PaletteEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  bool get isCloudConnected => _cloud.isConnected;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    await _local.init();
    await _cloud.connect();

    _entries = _local.getAll();
    _isLoading = false;
    notifyListeners();

    print('GalleryProvider initialized: ${_entries.length} entries');
  }

  // Simpan palet baru
  Future<void> savePalette({
    required List<PaletteColor> palette,
    required String objectLabel,
    String? imagePath,
    String? thumbnailPath,
  }) async {
    if (_local.count >= EnvConfig.maxSavedPalettes) return;

    final entry = PaletteEntry(
      id: const Uuid().v4(),
      objectLabel: objectLabel,
      colors: PaletteEntry.colorsFromPalette(palette),
      createdAt: DateTime.now(),
      imagePath: imagePath,
      thumbnailPath: thumbnailPath,
    );

    await _local.save(entry);
    await _cloud.save(entry);

    _entries = _local.getAll();
    notifyListeners();
  }

  Future<void> delete(PaletteEntry entry) async {
    // Hapus file foto dari storage
    await ImageStorageService.deleteImage(
      entry.imagePath,
      entry.thumbnailPath,
    );

    await _local.delete(entry.id);
    await _cloud.delete(entry.id);
    _entries = _local.getAll();
    notifyListeners();
  }

  Future<void> dispose() async {
    await _cloud.disconnect();
  }
}