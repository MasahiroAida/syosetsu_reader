import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:hive/hive.dart';
import '../models/reading_history.dart';
import '../services/database_helper.dart';
import '../utils/novel_url.dart';

class HistoryViewModel extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final http.Client _client;
  final bool _ownsClient;

  List<ReadingHistory> _history = [];
  bool _isLoading = false;
  bool _isUpdatingFromApi = false;
  bool _isDisposed = false;
  DateTime? _lastApiUpdateTime; // 最後のAPI更新時刻
  StreamSubscription? _historySubscription;

  static const Duration _apiCooldownDuration = Duration(seconds: 30); // クールタイム

  HistoryViewModel({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null {
    _historySubscription =
        Hive.box<ReadingHistory>(DatabaseHelper.historyBoxName)
            .watch()
            .listen((_) async {
      if (_isDisposed) return;
      _history = await _dbHelper.getReadingHistory();
      _safeNotifyListeners();
    });
  }

  List<ReadingHistory> get history => _history;
  bool get isLoading => _isLoading;
  bool get isUpdatingFromApi => _isUpdatingFromApi;

  /// API更新のクールタイムが有効かどうか
  bool get isApiUpdateOnCooldown {
    if (_lastApiUpdateTime == null) return false;
    return DateTime.now().difference(_lastApiUpdateTime!) <
        _apiCooldownDuration;
  }

  /// クールタイム残り時間（秒）
  int get cooldownRemainingSeconds {
    if (_lastApiUpdateTime == null) return 0;
    final elapsed = DateTime.now().difference(_lastApiUpdateTime!);
    final remaining = _apiCooldownDuration - elapsed;
    return remaining.inMilliseconds > 0
        ? (remaining.inMilliseconds / 1000).ceil()
        : 0;
  }

  String get refreshUnavailableMessage {
    if (_isUpdatingFromApi) return '更新中です。しばらくお待ちください';
    if (isApiUpdateOnCooldown) {
      return '更新クールタイム中です ($cooldownRemainingSeconds秒)';
    }
    return '最新情報を取得できませんでした。通信状態を確認してください';
  }

  @override
  void dispose() {
    _historySubscription?.cancel();
    _isDisposed = true;
    if (_ownsClient) _client.close();
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// URLからncodeを抽出
  String? extractNcodeFromUrl(String url) => NovelUrl.parse(url)?.ncode;

  /// APIから小説詳細情報を取得
  Future<Map<String, dynamic>?> fetchNovelDetails(String ncode,
      {bool r18 = false}) async {
    if (ncode.isEmpty || _isDisposed) return null;

    try {
      final baseUrl = r18
          ? 'https://api.syosetu.com/novel18api/api'
          : 'https://api.syosetu.com/novelapi/api';
      final apiUrl = Uri.parse(baseUrl).replace(queryParameters: {
        'out': 'json',
        'ncode': ncode.toLowerCase(),
      });
      final response = await _client.get(apiUrl, headers: {
        'User-Agent': 'Syosetsu Reader App/1.0',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && !_isDisposed) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data is List && data.length > 1) {
          return data[1] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      debugPrint('小説詳細取得エラー: $e');
      return null;
    }
  }

  /// 小説のタイトルを取得
  String getNovelTitle(Map<String, dynamic>? novelData,
      {String? fallbackTitle}) {
    if (novelData != null && novelData['title'] != null) {
      return novelData['title'].toString();
    }
    return fallbackTitle ?? 'タイトル不明';
  }

  /// 小説の作者名を取得
  String getNovelAuthor(Map<String, dynamic>? novelData) {
    if (novelData != null && novelData['writer'] != null) {
      return novelData['writer'].toString();
    }
    return 'Unknown';
  }

  /// 小説が連載かどうかを判定
  bool isSerialNovel(Map<String, dynamic>? novelData) {
    if (novelData == null) return false;
    final novelType = novelData['novel_type'];
    return novelType?.toString() == '1';
  }

  /// 小説の総話数を取得
  int getTotalChapters(Map<String, dynamic>? novelData) {
    if (novelData != null && novelData['general_all_no'] != null) {
      return int.tryParse(novelData['general_all_no'].toString()) ?? 1;
    }
    return 1;
  }

  DateTime? getLastUpdate(Map<String, dynamic>? novelData) {
    if (novelData == null) return null;
    final raw = novelData['general_lastup']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String getLastUpdateDisplay(DateTime? dateTime) {
    if (dateTime == null) return '';
    final difference = DateTime.now().difference(dateTime);
    if (difference.isNegative) {
      return _formatDate(dateTime);
    }
    if (difference.inDays >= 2) {
      return _formatDate(dateTime);
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}日前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}時間前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分前';
    } else {
      return 'たった今';
    }
  }

  String _formatDate(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '$year/$month/$day';
  }

  /// 履歴を読み込み（初回のみAPI更新）
  Future<void> loadHistory({bool forceApiUpdate = false}) async {
    if (_isDisposed) return;

    _isLoading = true;
    _safeNotifyListeners();

    try {
      if (!_isDisposed) {
        _history = await _dbHelper.getReadingHistory();

        if (forceApiUpdate) {
          await _updateHistoryFromApiInternal();
        }
      }
    } catch (e) {
      debugPrint('履歴読み込みエラー: $e');
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        _safeNotifyListeners();
      }
    }
  }

  /// 一覧のスナップショットを使い、Hive通知による並べ替えの影響を受けずに更新する。
  Future<bool> _updateHistoryFromApiInternal() async {
    if (_history.isEmpty ||
        _isDisposed ||
        _isUpdatingFromApi ||
        isApiUpdateOnCooldown) {
      return false;
    }

    _isUpdatingFromApi = true;
    _safeNotifyListeners();
    final novelIds = _history.map((item) => item.novelId).toList();
    var succeeded = true;
    try {
      for (final novelId in novelIds) {
        if (_isDisposed) return false;
        if (!await _refreshHistoryItem(novelId)) succeeded = false;
        if (!_isDisposed && novelId != novelIds.last) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
      if (succeeded) _lastApiUpdateTime = DateTime.now();
      return succeeded;
    } catch (e) {
      debugPrint('API更新エラー: $e');
      return false;
    } finally {
      _isUpdatingFromApi = false;
      _safeNotifyListeners();
    }
  }

  Future<bool> _refreshHistoryItem(String novelId) async {
    final original = await _dbHelper.getReadingHistoryByNovelId(novelId);
    if (original == null || _isDisposed) return false;
    final novelDetails = await fetchNovelDetails(
      novelId,
      r18: Uri.tryParse(original.url)?.host == 'novel18.syosetu.com',
    );
    if (novelDetails == null || _isDisposed) return false;

    // 通信中に削除・読書位置更新された項目を古いオブジェクトで上書きしない。
    final current = await _dbHelper.getReadingHistoryByNovelId(novelId);
    if (current == null || _isDisposed) return false;
    final title =
        getNovelTitle(novelDetails, fallbackTitle: current.novelTitle);
    final author = novelDetails['writer'] == null
        ? current.author
        : getNovelAuthor(novelDetails);
    final totalChapters = getTotalChapters(novelDetails);
    final serial = isSerialNovel(novelDetails);
    final lastUpdate = getLastUpdate(novelDetails) ?? current.lastUpdate;
    if (title != current.novelTitle ||
        author != current.author ||
        totalChapters != current.totalChapters ||
        serial != current.isSerialNovel ||
        lastUpdate != current.lastUpdate) {
      await _dbHelper.updateReadingHistoryInfo(
        novelId,
        title,
        author,
        totalChapters,
        isSerialNovel: serial,
        lastUpdate: lastUpdate,
      );
    }
    return true;
  }

  /// 手動でAPIから更新（クールタイムと同時実行をチェック）
  Future<bool> refreshFromApi() => _updateHistoryFromApiInternal();

  Future<bool> refreshSingleHistory(String novelId) async {
    if (_isDisposed || _isUpdatingFromApi || isApiUpdateOnCooldown) {
      return false;
    }
    _isUpdatingFromApi = true;
    _safeNotifyListeners();
    try {
      final succeeded = await _refreshHistoryItem(novelId);
      if (succeeded) _lastApiUpdateTime = DateTime.now();
      return succeeded;
    } catch (e) {
      debugPrint('単一履歴更新エラー: $e');
      return false;
    } finally {
      _isUpdatingFromApi = false;
      _safeNotifyListeners();
    }
  }

  Future<void> deleteHistory(String novelId) async {
    if (_isDisposed) return;

    try {
      await _dbHelper.deleteReadingHistory(novelId);
      await loadHistory(); // リロード（API更新はしない）
    } catch (e) {
      debugPrint('履歴削除エラー: $e');
    }
  }

  String getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
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

  String buildChapterUrl(String novelId, int currentChapter,
      {bool r18 = false}) {
    final domain = r18 ? 'novel18' : 'ncode';
    if (currentChapter > 0) {
      return 'https://$domain.syosetu.com/${novelId.toLowerCase()}/$currentChapter/';
    } else {
      return 'https://$domain.syosetu.com/${novelId.toLowerCase()}/';
    }
  }

  String buildHomeUrl(String novelId, {bool r18 = false}) {
    final domain = r18 ? 'novel18' : 'ncode';
    return 'https://$domain.syosetu.com/${novelId.toLowerCase()}/';
  }
}
