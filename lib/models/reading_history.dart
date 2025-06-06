import 'package:hive/hive.dart';

part 'reading_history.g.dart';

@HiveType(typeId: 2)
class ReadingHistory extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String novelId;

  @HiveField(2)
  String novelTitle;

  @HiveField(3)
  String author;

  @HiveField(4)
  int currentChapter;

  @HiveField(5)
  int totalChapters;

  @HiveField(6)
  DateTime lastViewed;

  @HiveField(7)
  String url;

  @HiveField(8)
  double? scrollPosition;

  @HiveField(9)
  bool isSerialNovel;

  ReadingHistory({
    required this.id,
    required this.novelId,
    required this.novelTitle,
    required this.author,
    this.currentChapter = 0,
    this.totalChapters = 0,
    required this.lastViewed,
    required this.url,
    this.scrollPosition,
    this.isSerialNovel = false,
  });

  int get unreadChapters =>
      totalChapters > currentChapter ? totalChapters - currentChapter : 0;

  double get readingProgress {
    if (totalChapters == 0) return 0.0;
    return currentChapter / totalChapters;
  }

  String get chapterDisplay =>
      isSerialNovel && currentChapter > 0 ? '第${currentChapter}章' : '目次/短編';

  String get timeAgo {
    final difference = DateTime.now().difference(lastViewed);
    if (difference.inDays > 0) {
      return '${difference.inDays}日前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}時間前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分前';
    } else {
      return 'たった今';
    }
  }
}
