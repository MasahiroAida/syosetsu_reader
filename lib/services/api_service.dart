import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/search_novel.dart';
import '../models/ranking_novel.dart';
import '../models/review.dart';

class ApiService {
  static const String naroApiBase = 'https://api.syosetu.com/novelapi/api/';
  static const String rankingApiBase = 'https://api.syosetu.com/rank/rankget/';
  
  // キャッシュ管理
  static Map<String, dynamic> _cache = {};
  static Map<String, DateTime> _cacheTimestamps = {};
  static const Duration cacheExpiry = Duration(minutes: 30);

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

  // 日本時間の現在日時を取得
  static DateTime _getJapanTime() {
    final now = DateTime.now().toUtc();
    return now.add(const Duration(hours: 9)); // JST = UTC+9
  }

  // rtypeに応じた適切な日付を計算
  static String _getFormattedDateForRtype(String rtype) {
    final japanTime = _getJapanTime();
    final calcTime = japanTime.add(const Duration(hours: -6)); // 日本時間-6で計算
    final formatter = DateFormat('yyyyMMdd');
    
    switch (rtype) {
      case 'q':
        // 四半期ランキング：当四半期の初日
        final quarter = ((calcTime.month - 1) ~/ 3) * 3 + 1;
        final firstDayOfQuarter = DateTime(calcTime.year, quarter, 1);
        return formatter.format(firstDayOfQuarter);
      case 'm':
        // 月別ランキング：今月の1日
        final firstDayOfMonth = DateTime(calcTime.year, calcTime.month, 1);
        return formatter.format(firstDayOfMonth);
        
      case 'w':
        // 週別ランキング：直近の火曜日
        // 火曜日 = weekday 2
        final currentWeekday = calcTime.weekday;
        late DateTime targetTuesday;
        
        if (currentWeekday == DateTime.tuesday) {
          // 今日が火曜日の場合
          targetTuesday = calcTime;
        } else if (currentWeekday > DateTime.tuesday) {
          // 今週の火曜日が過ぎている場合（水〜月）
          final daysAfterTuesday = currentWeekday - DateTime.tuesday;
          targetTuesday = calcTime.subtract(Duration(days: daysAfterTuesday));
        } else {
          // 今週の火曜日がまだ来ていない場合（月）
          final daysBeforeTuesday = DateTime.tuesday - currentWeekday;
          targetTuesday = calcTime.subtract(Duration(days: 7 - daysBeforeTuesday));
        }
        
        return formatter.format(targetTuesday);
        
      case 'd':
      default:
        // 日別ランキング：今日
        return formatter.format(calcTime);
    }
  }

  // 小説詳細情報を取得
  Future<List<dynamic>> _getNovelDetails(List<String> ncodes) async {
    if (ncodes.isEmpty) return [];
    
    try {
      // ncodeをハイフンで繋げる
      final ncodeParam = ncodes.map((ncode) => ncode.toLowerCase()).join('-');
      
      // HTTPヘッダーを設定
      final headers = {
        'User-Agent': 'Syosetsu Reader App/1.0',
        'Accept': 'application/json',
        'Accept-Encoding': 'identity',
      };
      
      final response = await http.get(
        Uri.parse('${naroApiBase}?out=json&lim=300&ncode=${ncodeParam}'),
        headers: headers,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('小説詳細リクエストタイムアウト');
        },
      );

      if (response.statusCode == 200) {
        // レスポンスの内容をチェック
        final responseBody = response.body.trim();
        if (responseBody.isEmpty) {
          print('小説詳細取得エラー: 空のレスポンス');
          return [];
        }
        
        // JSONとして有効かチェック
        if (!responseBody.startsWith('{') && !responseBody.startsWith('[')) {
          print('小説詳細取得エラー: JSONではないレスポンス: ${responseBody.substring(0, 100)}');
          return [];
        }
        
        final data = json.decode(responseBody);
        return data is List ? data.skip(1).toList() : [];
      } else {
        print('小説詳細取得エラー: HTTP ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('小説詳細取得エラー: $e');
    }
    return [];
  }

  // 小説検索
  Future<List<SearchNovel>> searchNovels({
    String? word,
    String? notword,
    List<int>? genres,
    List<String>? keywords,
    String? type,
    String? lastup,
    String order = 'new',
    int limit = 20,
  }) async {
    try {
      final params = <String, String>{
        'out': 'json',
        'lim': limit.toString(),
        'order': order,
      };

      if (word != null && word.isNotEmpty) {
        params['word'] = word;
      }
      
      if (notword != null && notword.isNotEmpty) {
        params['notword'] = notword;
      }

      if (genres != null && genres.isNotEmpty) {
        params['genre'] = genres.join('-');
      }

      if (keywords != null && keywords.isNotEmpty) {
        params['keyword'] = keywords.join(' ');
      }

      if (type != null && type.isNotEmpty) {
        params['type'] = type;
      }

      if (lastup != null && lastup.isNotEmpty) {
        params['lastup'] = lastup;
      }

      final uri = Uri.parse(naroApiBase).replace(queryParameters: params);
      print('リクエストURL: $uri');
      
      // HTTPヘッダーを設定
      final headers = {
        'User-Agent': 'Syosetsu Reader App/1.0',
        'Accept': 'application/json',
        'Accept-Encoding': 'identity', // gzipを無効化
      };
      
      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('リクエストタイムアウト');
        },
      );
      print('HTTPステータス: ${response.statusCode}');
      print('レスポンスヘッダー: ${response.headers}');

      if (response.statusCode == 200) {
        // レスポンスの内容をチェック
        final responseBody = response.body.trim();
        print('レスポンス長: ${responseBody.length}');
        print('レスポンス内容（最初の200文字）: ${responseBody.length > 200 ? responseBody.substring(0, 200) : responseBody}');
        
        if (responseBody.isEmpty) {
          print('小説検索エラー: 空のレスポンス');
          return [];
        }
        
        // JSONとして有効かチェック
        if (!responseBody.startsWith('{') && !responseBody.startsWith('[')) {
          print('小説検索エラー: JSONではないレスポンス: ${responseBody.length > 100 ? responseBody.substring(0, 100) : responseBody}');
          return [];
        }
        
        final data = json.decode(responseBody);
        final List<dynamic> novelData = data is List ? data.skip(1).toList() : [];
        
        return novelData.map((e) => SearchNovel.fromMap(e)).toList();
      } else {
        print('小説検索エラー: HTTP ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('小説検索エラー: $e');
    }
    return [];
  }

  // ランキング取得
  Future<List<RankingNovel>> getRanking({String rtype = 'd', int? genre}) async {
    final genreKey = genre != null ? genre.toString() : 'all';
    final cacheKey = 'ranking_${rtype}_$genreKey';
    
    // キャッシュチェック
    if (_cache.containsKey(cacheKey) && _cacheTimestamps.containsKey(cacheKey)) {
      final cacheTime = _cacheTimestamps[cacheKey]!;
      if (DateTime.now().difference(cacheTime) < cacheExpiry) {
        return (_cache[cacheKey] as List).map((e) => RankingNovel.fromMap(e)).toList();
      }
    }

    // rtypeに応じた適切な日付を取得
    final formattedDate = _getFormattedDateForRtype(rtype);

    try {
      final queryParams = <String, String>{
        'out': 'json',
        'rtype': '${formattedDate}-$rtype',
      };
      if (genre != null && genre > 0) {
        queryParams['genre'] = genre.toString();
      }
      final uri = Uri.parse(rankingApiBase).replace(queryParameters: queryParams);
      print('ランキングリクエストURL: $uri');
      
      // HTTPヘッダーを設定
      final headers = {
        'User-Agent': 'Syosetsu Reader App/1.0',
        'Accept': 'application/json',
        'Accept-Encoding': 'identity',
      };
      
      final response = await http.get(
        uri,
        headers: headers,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('ランキングリクエストタイムアウト');
        },
      );

      if (response.statusCode == 200) {
        // レスポンスの内容をチェック
        final responseBody = response.body.trim();
        if (responseBody.isEmpty) {
          print('ランキング取得エラー: 空のレスポンス');
          return [];
        }
        
        // JSONとして有効かチェック
        if (!responseBody.startsWith('{') && !responseBody.startsWith('[')) {
          print('ランキング取得エラー: JSONではないレスポンス: ${responseBody.substring(0, 100)}');
          return [];
        }
        
        final data = json.decode(responseBody);
        final List<dynamic> rankingData = data is List ? data.skip(1).toList() : [];
        
        if (rankingData.isEmpty) return [];
        
        // ランキングからncodeを抽出（int型の場合もあるのでtoString()で変換）
        final ncodes = rankingData
            .map((e) => e['ncode']?.toString())
            .where((ncode) => ncode != null && ncode.isNotEmpty)
            .cast<String>()
            .toList();
        
        // 小説詳細情報を取得
        final novelDetails = await _getNovelDetails(ncodes);
        
        // ランキング情報と詳細情報をマージ
        final List<Map<String, dynamic>> mergedData = [];
        for (int i = 0; i < rankingData.length; i++) {
          final rankingItem = rankingData[i];
          final ncode = rankingItem['ncode']?.toString();
          
          if (ncode == null || ncode.isEmpty) continue;
          
          // 対応する詳細情報を検索
          final detailItem = novelDetails.firstWhere(
            (detail) => detail['ncode'] == ncode,
            orElse: () => {},
          );
          
          // ランキング情報と詳細情報をマージ
          final merged = Map<String, dynamic>.from(detailItem);
          merged['pt'] = rankingItem['pt'];
          merged['rank'] = rankingItem['rank'];
          merged['ncode'] = ncode; // 確実にString型として保存
          merged['genre'] = genres[detailItem['genre']] ?? 'その他';
          
          mergedData.add(merged);
        }
        
        // キャッシュに保存
        _cache[cacheKey] = mergedData;
        _cacheTimestamps[cacheKey] = DateTime.now();
        
        return mergedData.map((e) => RankingNovel.fromMap(e)).toList();
      } else {
        print('ランキング取得エラー: HTTP ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('ランキング取得エラー: $e');
      print('リクエストURL: $uri');
    }
    return [];
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