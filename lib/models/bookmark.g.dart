// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookmark.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BookmarkAdapter extends TypeAdapter<Bookmark> {
  @override
  final int typeId = 1;

  @override
  Bookmark read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Bookmark(
      id: fields[0] as String,
      novelId: fields[1] as String,
      novelTitle: fields[2] as String,
      author: fields[3] as String,
      currentChapter: fields[4] as int,
      addedAt: fields[5] as DateTime,
      lastViewed: fields[6] as DateTime,
      scrollPosition: fields[7] as double?,
      isSerialNovel: fields[8] as bool,
      lastUpdate: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Bookmark obj) {
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
      ..write(obj.addedAt)
      ..writeByte(6)
      ..write(obj.lastViewed)
      ..writeByte(7)
      ..write(obj.scrollPosition)
      ..writeByte(8)
      ..write(obj.isSerialNovel)
      ..writeByte(9)
      ..write(obj.lastUpdate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookmarkAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
