// 作品タイプ
class WorkTypes {
  static const Map<String, String> types = {
    '': '指定なし',
    't': '短編',
    'r': '連載中',
    'e': '完結済み',
  };
}

// 並び順
class OrderTypes {
  static const Map<String, String> types = {
    'new': '新着順',
    'favnovelcnt': 'ブックマーク数順',
    'reviewcnt': 'レビュー数順',
    'hyoka': '総合評価順',
    'hyokaasc': '評価順（低い順）',
    'impressioncnt': '感想数順',
    'hyokacnt': '評価数順',
    'weekly': '週間ユニークユーザー順',
    'lengthdesc': '文字数順（多い順）',
    'lengthasc': '文字数順（少ない順）',
  };
}

// 作品に含まれる要素
class NovelKeywords {
  static const List<String> keywords = [
    'R15', 'ボーイズラブ', 'ガールズラブ', '残酷な描写あり',
    '異世界転生', '異世界転移', '逆行転生', '人外転生',
    '悪役令嬢', '婚約破棄', '恋愛', 'ラブコメ',
    'バトル', 'アクション', 'ダーク', 'シリアス',
    'ほのぼの', 'コメディ', 'ギャグ', '日常',
    'チート', '魔法', '学園', '現代',
    'ハーレム', '主人公最強', '成り上がり', '復讐',
  ];
}