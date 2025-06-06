class Bookmark {
  final String id;
  final String novelId;
  final String novelTitle;
  final String author;
  final int currentChapter;
  final DateTime addedAt;
  final DateTime lastViewed;
  final double? scrollPosition;
  final bool? isSerialNovel;

  Bookmark({
    required this.id,
    required this.novelId,
    required this.novelTitle,
    required this.author,
    required this.currentChapter,
    required this.addedAt,
    required this.lastViewed,
    this.scrollPosition,
    this.isSerialNovel,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'novel_id': novelId,
      'novel_title': novelTitle,
      'author': author,
      'current_chapter': currentChapter,
      'added_at': addedAt.millisecondsSinceEpoch,
      'last_viewed': lastViewed.millisecondsSinceEpoch,
      'scroll_position': scrollPosition,
      'is_serial_novel': isSerialNovel,
    };
  }

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      id: map['id'],
      novelId: map['novel_id'],
      novelTitle: map['novel_title'],
      author: map['author'],
      currentChapter: map['current_chapter'] ?? 0,
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at']),
      lastViewed: DateTime.fromMillisecondsSinceEpoch(map['last_viewed']),
      scrollPosition: map['scroll_position']?.toDouble(),
      isSerialNovel: map['is_serial_novel'] == true,
    );
  }
}