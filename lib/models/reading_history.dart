class ReadingHistory {
  final String id;
  final String novelId;
  final String novelTitle;
  final String author;
  final int currentChapter;
  final int totalChapters;
  final DateTime lastViewed;
  final String url;
  final double? scrollPosition;

  ReadingHistory({
    required this.id,
    required this.novelId,
    required this.novelTitle,
    required this.author,
    required this.currentChapter,
    required this.totalChapters,
    required this.lastViewed,
    required this.url,
    this.scrollPosition,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'novel_id': novelId,
      'novel_title': novelTitle,
      'author': author,
      'current_chapter': currentChapter,
      'total_chapters': totalChapters,
      'last_viewed': lastViewed.millisecondsSinceEpoch,
      'url': url,
      'scroll_position': scrollPosition ?? 0.0,
    };
  }

  factory ReadingHistory.fromMap(Map<String, dynamic> map) {
    return ReadingHistory(
      id: map['id'],
      novelId: map['novel_id'],
      novelTitle: map['novel_title'],
      author: map['author'],
      currentChapter: map['current_chapter'] ?? 0,
      totalChapters: map['total_chapters'] ?? 0,
      lastViewed: DateTime.fromMillisecondsSinceEpoch(map['last_viewed']),
      url: map['url'] ?? '',
      scrollPosition: map['scroll_position']?.toDouble(),
    );
  }

  int get unreadChapters => totalChapters - currentChapter;

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