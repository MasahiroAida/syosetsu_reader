import 'package:hive/hive.dart';

part 'bookmark.g.dart';

@HiveType(typeId: 1)
class Bookmark extends HiveObject {
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
  DateTime addedAt;

  @HiveField(6)
  DateTime lastViewed;

  @HiveField(7)
  double? scrollPosition;

  @HiveField(8)
  bool isSerialNovel;

  Bookmark({
    required this.id,
    required this.novelId,
    required this.novelTitle,
    required this.author,
    this.currentChapter = 0,
    required this.addedAt,
    required this.lastViewed,
    this.scrollPosition,
    this.isSerialNovel = false,
  });

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
