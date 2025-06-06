class RankingNovel {
  final String ncode;
  final String title;
  final String author;
  final int point;
  final String genre;
  final int novelType; // 1: 連載, 2: 短編
  final int end; // 0: 連載中, 1: 完結済み/短編
  final int length; // 文字数
  final int general_all_no;

  RankingNovel({
    required this.ncode,
    required this.title,
    required this.author,
    required this.point,
    required this.genre,
    required this.novelType,
    required this.end,
    required this.length,
    required this.general_all_no,
  });

  factory RankingNovel.fromMap(Map<String, dynamic> map) {
    return RankingNovel(
      ncode: map['ncode'] ?? '',
      title: map['title'] ?? '',
      author: map['writer'] ?? '',
      point: map['pt'] ?? 0,
      genre: map['genre'] ?? '',
      novelType: map['novel_type'] ?? 1,
      end: map['end'] ?? 0,
      length: map['length'] ?? 0,
      general_all_no: map['general_all_no'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ncode': ncode,
      'title': title,
      'writer': author,
      'pt': point,
      'genre': genre,
      'novel_type': novelType,
      'end': end,
      'length': length,
      'general_all_no': general_all_no,
    };
  }
}