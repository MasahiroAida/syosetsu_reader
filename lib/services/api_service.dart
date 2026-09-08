import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/search_novel.dart';
import '../models/ranking_novel.dart';
import '../models/review.dart';

class ApiService {
  static const String naroApiBase = 'https://api.syosetu.com/novelapi/api/';
  static const String naroR18ApiBase =
      'https://api.syosetu.com/novel18api/api/';
  static const String rankingApiBase = 'https://api.syosetu.com/rank/rankget/';
  static const Duration cacheExpiry = Duration(minutes: 30);
  static const _headers = {
    'User-Agent': 'Syosetsu Reader App/1.0',
    'Accept': 'application/json',
    'Accept-Encoding': 'identity',
  };

  final http.Client? _client;
  final DateTime Function() _now;
  static final Map<String, _RankingCacheEntry> _sharedRankingCache = {};
  static final Map<String, Future<List<Map<String, dynamic>>>>
      _sharedRankingRequests = {};
  final Map<String, _RankingCacheEntry> _rankingCache;
  final Map<String, Future<List<Map<String, dynamic>>>> _rankingRequests;

  ApiService({http.Client? client, DateTime Function()? now})
      : _client = client,
        _now = now ?? DateTime.now,
        _rankingCache =
            client == null && now == null ? _sharedRankingCache : {},
        _rankingRequests =
            client == null && now == null ? _sharedRankingRequests : {};

  static void clearCache() {
    _sharedRankingCache.clear();
    // Pending requests may finish, but must not repopulate the cleared cache.
    _sharedRankingRequests.clear();
  }

  static const Map<int, String> r18Genres = {
    1: 'ノクターンノベルズ',
    2: 'ムーンライトノベルズ（女性向け）',
    3: 'ムーンライトノベルズ（BL）',
    4: 'ミッドナイトノベルズ',
  };

  // ジャンル定義
  static const Map<int, String> genres = {
    101: '異世界〔恋愛〕',
    102: '現実世界〔恋愛〕',
    201: 'ハイファンタジー〔ファンタジー〕',
    202: 'ローファンタジー〔ファンタジー〕',
    301: '純文学〔文芸〕',
    302: 'ヒューマンドラマ〔文芸〕',
    303: '歴史〔文芸〕',
    304: '推理〔文芸〕',
    305: 'ホラー〔文芸〕',
    306: 'アクション〔文芸〕',
    307: 'コメディー〔文芸〕',
    401: 'VRゲーム〔SF〕',
    402: '宇宙〔SF〕',
    403: '空想科学〔SF〕',
    404: 'パニック〔SF〕',
    9901: '童話〔その他〕',
    9902: '詩〔その他〕',
    9903: 'エッセイ〔その他〕',
    9904: 'リプレイ〔その他〕',
    9999: 'その他〔その他〕',
  };

  String _getFormattedDateForRtype(String rtype) {
    // Daily snapshots are generated between 04:00 and 07:00 JST.
    // Use the previous snapshot until that window has finished (UTC + 9 - 7).
    final calcTime = _now().toUtc().add(const Duration(hours: 2));
    final formatter = DateFormat('yyyyMMdd');
    switch (rtype) {
      case 'q':
      case 'm':
        // Quarterly rankings also have a snapshot on the first of EVERY month.
        return formatter.format(DateTime.utc(calcTime.year, calcTime.month, 1));
      case 'w':
        final daysAfterTuesday = (calcTime.weekday - DateTime.tuesday + 7) % 7;
        return formatter.format(
          calcTime.subtract(Duration(days: daysAfterTuesday)),
        );
      default:
        return formatter.format(calcTime);
    }
  }

  Future<List<Map<String, dynamic>>> _getJsonList(Uri uri) async {
    final response = await (_client?.get(uri, headers: _headers) ??
            http.get(uri, headers: _headers))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', uri);
    }
    // The API always sends UTF-8, including responses without a charset header.
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! List || data.any((item) => item is! Map<String, dynamic>)) {
      throw const FormatException('APIから無効なデータが返されました');
    }
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> _getNovelDetails(
      List<String> ncodes) async {
    if (ncodes.isEmpty) return [];
    final uri = Uri.parse(naroApiBase).replace(queryParameters: {
      'out': 'json',
      'lim': '300',
      'ncode': ncodes.toSet().join('-'),
      'of': 'n-t-w-g-nt-e-l-ga',
    });
    final data = await _getJsonList(uri);
    return data.where((item) => !item.containsKey('allcount')).toList();
  }

  Future<List<SearchNovel>> searchNovels({
    String? word,
    String? notword,
    List<int>? genres,
    List<String>? keywords,
    String? type,
    String? lastup,
    String order = 'new',
    int limit = 20,
    bool r18 = false,
  }) async {
    final params = <String, String>{
      'out': 'json',
      'lim': limit.clamp(1, 500).toString(),
      'order': order,
      'of': r18 ? 'n-t-w-s-k-ng-ga-gl-l' : 'n-t-w-s-k-g-ga-gl-l',
    };
    // `keyword` is a boolean search-field switch, not a list of words.
    final terms = <String>{
      if (word != null && word.trim().isNotEmpty) word.trim()
    };
    final featureParams = {
      if (!r18) 'R15': 'isr15',
      'ボーイズラブ': 'isbl',
      'ガールズラブ': 'isgl',
      '残酷な描写あり': 'iszankoku',
      '異世界転生': 'istensei',
      '異世界転移': 'istenni',
    };
    for (final keyword in keywords ?? <String>[]) {
      final term = keyword.trim();
      final feature = featureParams[term];
      if (feature != null) {
        params[feature] = '1';
      } else if (term.isNotEmpty) {
        terms.add(term);
      }
    }
    if (terms.isNotEmpty) params['word'] = terms.join(' ');
    if (notword != null && notword.trim().isNotEmpty) {
      params['notword'] = notword.trim();
    }
    if (genres != null && genres.isNotEmpty) {
      params[r18 ? 'nocgenre' : 'genre'] = genres.join('-');
    }
    if (type != null && type.isNotEmpty) params['type'] = type;
    if (lastup != null && lastup.isNotEmpty) params['lastup'] = lastup;
    final base = r18 ? naroR18ApiBase : naroApiBase;
    final data = await _getJsonList(
      Uri.parse(base).replace(queryParameters: params),
    );
    return data
        .where((item) => !item.containsKey('allcount'))
        .map(SearchNovel.fromMap)
        .toList();
  }

  Future<List<RankingNovel>> getRanking({
    String rtype = 'd',
    int? genre,
    bool forceRefresh = false,
  }) async {
    final date = _getFormattedDateForRtype(rtype);
    final key = '$date-$rtype';
    final now = _now();
    _rankingCache.removeWhere(
      (_, entry) => now.difference(entry.createdAt) >= cacheExpiry,
    );
    var rows = forceRefresh ? null : _rankingCache[key]?.rows;
    if (rows == null) {
      // Genre changes can reuse both completed and in-flight period requests.
      var request = _rankingRequests[key];
      if (request == null) {
        request = _fetchRanking(key);
        _rankingRequests[key] = request;
      }
      try {
        rows = await request;
        if (identical(_rankingRequests[key], request)) {
          _rankingCache[key] = _RankingCacheEntry(rows, _now());
        }
      } finally {
        if (identical(_rankingRequests[key], request)) {
          _rankingRequests.remove(key);
        }
      }
    }
    return rows
        .where((item) => genre == null || genre <= 0 || item['genre'] == genre)
        .map((item) => RankingNovel.fromMap({
              ...item,
              'genre': genres[item['genre']] ?? 'その他',
            }))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchRanking(String key) async {
    final data = await _getJsonList(
      Uri.parse(rankingApiBase).replace(queryParameters: {
        'out': 'json',
        'rtype': key,
      }),
    );
    // Ranking responses have no allcount header: the first row is rank 1.
    final rankingData = data
        .where((item) => (item['ncode']?.toString() ?? '').isNotEmpty)
        .toList();
    if (rankingData.isEmpty) return [];
    final ncodes = rankingData
        .map((item) => item['ncode'].toString().toLowerCase())
        .toList();
    final details = await _getNovelDetails(ncodes);
    // Index once instead of scanning all details for every ranked novel.
    final detailsByCode = {
      for (final detail in details)
        detail['ncode']?.toString().toLowerCase(): detail,
    };
    final mergedData = <Map<String, dynamic>>[];
    for (final item in rankingData) {
      final ncode = item['ncode'].toString();
      final detail = detailsByCode[ncode.toLowerCase()];
      // Deleted or search-excluded works cannot provide readable metadata.
      if (detail == null) continue;
      mergedData.add({
        ...detail,
        'ncode': ncode,
        'pt': item['pt'],
        'rank': item['rank'],
        'genre': int.tryParse(detail['genre'].toString()) ?? 0,
      });
    }
    return mergedData;
  }

  // レビュー取得（仮実装）
  Future<List<Review>> getReviews() async {
    // 実際のAPIがない場合のサンプルデータ
    return [
      Review(
        id: '1',
        novelTitle: 'サンプル小説1',
        summary: 'とても面白い作品です。キャラクターが魅力的で展開も素晴らしい。',
        rating: 4.5,
        reviewUrl: 'https://example.com/review/1',
      ),
      Review(
        id: '2',
        novelTitle: 'サンプル小説2',
        summary: '世界観が詳細に作り込まれており、読み応えがある。',
        rating: 4.2,
        reviewUrl: 'https://example.com/review/2',
      ),
    ];
  }
}

class _RankingCacheEntry {
  final List<Map<String, dynamic>> rows;
  final DateTime createdAt;

  _RankingCacheEntry(this.rows, this.createdAt);
}
