class Novel {
  final String id;
  final String title;
  final String author;
  final String? coverUrl;
  final int lastReadChapter;
  final int unreadChapterCount;
  final DateTime addedAt;
  final String? summary;
  final String? keyword;
  final int? totalChapters;

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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'cover_url': coverUrl,
      'last_read_chapter': lastReadChapter,
      'unread_chapter_count': unreadChapterCount,
      'added_at': addedAt.millisecondsSinceEpoch,
      'summary': summary,
      'keyword': keyword,
      'total_chapters': totalChapters,
    };
  }

  factory Novel.fromMap(Map<String, dynamic> map) {
    return Novel(
      id: map['id'],
      title: map['title'],
      author: map['author'],
      coverUrl: map['cover_url'],
      lastReadChapter: map['last_read_chapter'] ?? 0,
      unreadChapterCount: map['unread_chapter_count'] ?? 0,
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at']),
      summary: map['summary'],
      keyword: map['keyword'],
      totalChapters: map['total_chapters'],
    );
  }
}