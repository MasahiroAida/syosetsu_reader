// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReadingHistoryAdapter extends TypeAdapter<ReadingHistory> {
  @override
  final int typeId = 2;

  @override
  ReadingHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReadingHistory(
      id: fields[0] as String,
      novelId: fields[1] as String,
      novelTitle: fields[2] as String,
      author: fields[3] as String,
      currentChapter: fields[4] as int,
      totalChapters: fields[5] as int,
      lastViewed: fields[6] as DateTime,
      url: fields[7] as String,
      scrollPosition: fields[8] as double?,
      isSerialNovel: fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ReadingHistory obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.novelId)
      ..writeByte(2)
      ..write(obj.novelTitle)
      ..writeByte(3)
      ..write(obj.author)
      ..writeByte(4)
      ..write(obj.currentChapter)
      ..writeByte(5)
      ..write(obj.totalChapters)
      ..writeByte(6)
      ..write(obj.lastViewed)
      ..writeByte(7)
      ..write(obj.url)
      ..writeByte(8)
      ..write(obj.scrollPosition)
      ..writeByte(9)
      ..write(obj.isSerialNovel);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
