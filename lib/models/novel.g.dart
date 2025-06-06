// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'novel.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NovelAdapter extends TypeAdapter<Novel> {
  @override
  final int typeId = 0;

  @override
  Novel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Novel(
      id: fields[0] as String,
      title: fields[1] as String,
      author: fields[2] as String,
      coverUrl: fields[3] as String?,
      lastReadChapter: fields[4] as int,
      unreadChapterCount: fields[5] as int,
      addedAt: fields[6] as DateTime,
      summary: fields[7] as String?,
      keyword: fields[8] as String?,
      totalChapters: fields[9] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Novel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.author)
      ..writeByte(3)
      ..write(obj.coverUrl)
      ..writeByte(4)
      ..write(obj.lastReadChapter)
      ..writeByte(5)
      ..write(obj.unreadChapterCount)
      ..writeByte(6)
      ..write(obj.addedAt)
      ..writeByte(7)
      ..write(obj.summary)
      ..writeByte(8)
      ..write(obj.keyword)
      ..writeByte(9)
      ..write(obj.totalChapters);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NovelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
