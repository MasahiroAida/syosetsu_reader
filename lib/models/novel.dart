import 'package:hive/hive.dart';

part 'novel.g.dart';

@HiveType(typeId: 0)
class Novel extends HiveObject {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String title;
  
  @HiveField(2)
  String author;
  
  @HiveField(3)
  String? coverUrl;
  
  @HiveField(4)
  int lastReadChapter;
  
  @HiveField(5)
  int unreadChapterCount;
  
  @HiveField(6)
  DateTime addedAt;
  
  @HiveField(7)
  String? summary;
  
  @HiveField(8)
  String? keyword;
  
  @HiveField(9)
  int? totalChapters;

  Novel({
    required this.id,
    required this.title,
    required this.author,
    this.coverUrl,
    this.lastReadChapter = 0,
    this.unreadChapterCount = 0,
    required this.addedAt,
    this.summary,
    this.keyword,
    this.totalChapters,
  });

  String get displayTitle =>
      title.length > 30 ? '${title.substring(0, 30)}...' : title;

  double get readingProgress {
    if (totalChapters == null || totalChapters == 0) return 0.0;
    return lastReadChapter / totalChapters!;
  }
}
