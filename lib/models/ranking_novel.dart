class RankingNovel {
  final String ncode;
  final String title;
  final String author;
  final int point;
  final int rank;
  final String genre;
  final int novelType; // 1: 連載, 2: 短編
  final int end; // 0: 完結済み/短編, 1: 連載中
  final int length; // 文字数
  final int totalChapters;

  RankingNovel({
    required this.ncode,
    required this.title,
    required this.author,
    required this.point,
    this.rank = 0,
    required this.genre,
    required this.novelType,
    required this.end,
    required this.length,
    required this.totalChapters,
  });

  factory RankingNovel.fromMap(Map<String, dynamic> map) {
    return RankingNovel(
      ncode: map['ncode']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      author: map['writer']?.toString() ?? '',
      point: _asInt(map['pt']),
      rank: _asInt(map['rank']),
      genre: map['genre']?.toString() ?? '',
      novelType: _asInt(map['novel_type'] ?? map['noveltype'], fallback: 1),
      end: _asInt(map['end']),
      length: _asInt(map['length']),
      totalChapters: _asInt(map['general_all_no']),
    );
  }

  static int _asInt(dynamic value, {int fallback = 0}) => value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? fallback;

  Map<String, dynamic> toMap() {
    return {
      'ncode': ncode,
      'title': title,
      'writer': author,
      'pt': point,
      'rank': rank,
      'genre': genre,
      'novel_type': novelType,
      'end': end,
      'length': length,
      'general_all_no': totalChapters,
    };
  }
}
