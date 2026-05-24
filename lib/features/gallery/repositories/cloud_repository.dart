import 'package:mongo_dart/mongo_dart.dart';
import '../../../config/env_config.dart';
import '../models/palette_entry.dart';

class CloudRepository {
  Db? _db;
  DbCollection? _collection;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    try {
      _db = await Db.create(EnvConfig.mongoUri);
      await _db!.open();
      _collection = _db!.collection(EnvConfig.mongoCollection);
      _isConnected = true;
      print('MongoDB connected');
    } catch (e) {
      _isConnected = false;
      print('MongoDB connection error: $e');
    }
  }

  Future<void> save(PaletteEntry entry) async {
    if (!_isConnected || _collection == null) return;
    try {
      await _collection!.insertOne(entry.toMongoMap());
      print('Saved to MongoDB: ${entry.id}');
    } catch (e) {
      print('MongoDB save error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    if (!_isConnected || _collection == null) return [];
    try {
      return await _collection!.find().toList();
    } catch (e) {
      print('MongoDB fetch error: $e');
      return [];
    }
  }

  Future<void> delete(String id) async {
    if (!_isConnected || _collection == null) return;
    try {
      await _collection!.deleteOne({'_id': id});
      print('Deleted from MongoDB: $id');
    } catch (e) {
      print('MongoDB delete error: $e');
    }
  }

  Future<void> disconnect() async {
    await _db?.close();
    _isConnected = false;
    print('MongoDB disconnected');
  }
}