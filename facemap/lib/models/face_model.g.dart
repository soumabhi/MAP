// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'face_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FaceAdapter extends TypeAdapter<Face> {
  @override
  final int typeId = 0;

  @override
  Face read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Face(
      id: fields[0] as String,
      employeeId: fields[1] as String,
      embedding: (fields[2] as List).cast<double>(),
    );
  }

  @override
  void write(BinaryWriter writer, Face obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.employeeId)
      ..writeByte(2)
      ..write(obj.embedding);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
