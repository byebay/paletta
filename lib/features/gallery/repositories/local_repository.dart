import 'package:hive_flutter/hive_flutter.dart';
import '../models/palette_entry.dart';

class LocalRepository {
  static const String _boxName = 'palettes';
  late Box<PaletteEntry> _box;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(PaletteEntryAdapter());
    _box = await Hive.openBox<PaletteEntry>(_boxName);
    print('Hive initialized: ${_box.length} entries found');
  }

  // Simpan entri baru
  Future<void> save(PaletteEntry entry) async {
    await _box.put(entry.id, entry);
    print('Saved to Hive: ${entry.id}');
  }

  // Ambil semua entri, diurutkan terbaru dulu
  List<PaletteEntry> getAll() {
    final entries = _box.values.toList();
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  // Hapus entri berdasarkan ID
  Future<void> delete(String id) async {
    await _box.delete(id);
    print('Deleted from Hive: $id');
  }

  // Hapus semua entri
  Future<void> clearAll() async {
    await _box.clear();
    print('Hive cleared');
  }

  int get count => _box.length;
}