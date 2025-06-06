class SearchNovel {
  final String ncode;
  final String title;
  final String author;
  final String story;
  final String keyword;
  final int genre;
  final int totalChapters;
  final DateTime lastUpdate;
  final int length;

  SearchNovel({
    required this.ncode,
    required this.title,
    required this.author,
    required this.story,
    required this.keyword,
    required this.genre,
    required this.totalChapters,
    required this.lastUpdate,
    required this.length,
  });

  factory SearchNovel.fromMap(Map<String, dynamic> map) {
    return SearchNovel(
      ncode: map['ncode'] ?? '',
      title: map['title'] ?? '',
      author: map['writer'] ?? '',
      story: map['story'] ?? '',
      keyword: map['keyword'] ?? '',
      genre: map['genre'] ?? 0,
      totalChapters: map['general_all_no'] ?? 0,
      lastUpdate: DateTime.tryParse(map['general_lastup'] ?? '') ?? DateTime.now(),
      length: map['length'] ?? 0,
    );
  }
}