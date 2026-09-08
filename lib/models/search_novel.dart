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

  static int _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  factory SearchNovel.fromMap(Map<String, dynamic> map) {
    return SearchNovel(
      ncode: map['ncode']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      author: map['writer']?.toString() ?? '',
      story: map['story']?.toString() ?? '',
      keyword: map['keyword']?.toString() ?? '',
      genre: _asInt(map['genre'] ?? map['nocgenre']),
      totalChapters: _asInt(map['general_all_no']),
      lastUpdate: DateTime.tryParse(map['general_lastup']?.toString() ?? '') ??
          DateTime.now(),
      length: _asInt(map['length']),
    );
  }
}
