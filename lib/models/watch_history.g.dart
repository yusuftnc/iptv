// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watch_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WatchHistoryAdapter extends TypeAdapter<WatchHistory> {
  @override
  final int typeId = 1;

  @override
  WatchHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WatchHistory(
      contentId: fields[0] as String,
      name: fields[1] as String,
      streamType: fields[2] as String,
      streamIcon: fields[3] as String?,
      position: fields[5] as int?,
      duration: fields[6] as int?,
      streamUrl: fields[7] as String?,
      category: fields[8] as String?,
    )..watchDate = fields[4] as DateTime;
  }

  @override
  void write(BinaryWriter writer, WatchHistory obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.contentId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.streamType)
      ..writeByte(3)
      ..write(obj.streamIcon)
      ..writeByte(4)
      ..write(obj.watchDate)
      ..writeByte(5)
      ..write(obj.position)
      ..writeByte(6)
      ..write(obj.duration)
      ..writeByte(7)
      ..write(obj.streamUrl)
      ..writeByte(8)
      ..write(obj.category);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
