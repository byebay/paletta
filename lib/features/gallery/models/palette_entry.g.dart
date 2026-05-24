// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'palette_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PaletteEntryAdapter extends TypeAdapter<PaletteEntry> {
  @override
  final int typeId = 0;

  @override
  PaletteEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PaletteEntry(
      id: fields[0] as String,
      objectLabel: fields[1] as String,
      colors: (fields[2] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
      createdAt: fields[3] as DateTime,
      imagePath: fields[4] as String?,
      thumbnailPath: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PaletteEntry obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.objectLabel)
      ..writeByte(2)
      ..write(obj.colors)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.imagePath)
      ..writeByte(5)
      ..write(obj.thumbnailPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaletteEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
