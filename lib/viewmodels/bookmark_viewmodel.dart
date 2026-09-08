import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:hive/hive.dart';
import '../models/bookmark.dart';
import '../models/reading_history.dart';
import '../services/database_helper.dart';
import '../utils/novel_url.dart';

class BookmarkViewModel extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final http.Client _client;
  final bool _ownsClient;

  List<Bookmark> _bookmarks = [];
  final Map<String, int> _unreadCounts = {}; // novelId -> unread count
  final Map<String, int> _totalChapters = {};
  final Map<String, ReadingHistory> _historyByNovelId = {};
  bool _isLoading = false;
  bool _isUpdatingFromApi = false;
  bool _isDisposed = false;
  DateTime? _lastApiUpdateTime; // 最後のAPI更新時刻
  StreamSubscription? _bookmarkSubscription;
  StreamSubscription? _historySubscription;

  static const Duration _apiCooldownDuration = Duration(seconds: 30); // クールタイム

  BookmarkViewModel({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null {
    _bookmarkSubscription = Hive.box<Bookmark>(DatabaseHelper.bookmarkBoxName)
        .watch()
        .listen((_) async {
      if (_isDisposed) return;
      await _loadBookmarksInternal();
      _safeNotifyListeners();
    });
    _historySubscription =
        Hive.box<ReadingHistory>(DatabaseHelper.historyBoxName)
            .watch()
            .listen((_) async {
      if (_isDisposed) return;
      await _updateUnreadCounts();
      _safeNotifyListeners();
    });
  }

  List<Bookmark> get bookmarks => _bookmarks;
  bool get isLoading => _isLoading;
  bool get isUpdatingFromApi => _isUpdatingFromApi;
  int getUnreadCount(String novelId) => _unreadCounts[novelId] ?? 0;

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
    _bookmarkSubscription?.cancel();
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

  /// 内部的なブックマーク読み込み処理
  Future<void> _loadBookmarksInternal() async {
    try {
      _bookmarks = await _dbHelper.getBookmarks();
      await _updateUnreadCounts();
    } catch (e) {
      debugPrint('ブックマーク内部読み込みエラー: $e');
    }
  }

  /// ローカル一覧の更新では通信せず、履歴を一度だけ走査する。
  Future<void> _updateUnreadCounts() async {
    final history = await _dbHelper.getAllReadingHistory();
    if (_isDisposed) return;
    _historyByNovelId
      ..clear()
      ..addEntries(
          history.map((item) => MapEntry(item.novelId.toLowerCase(), item)));
    _unreadCounts.clear();
    for (final bookmark in _bookmarks) {
      final novelId = bookmark.novelId.toLowerCase();
      final item = _historyByNovelId[novelId];
      final total = item?.totalChapters ?? _totalChapters[novelId] ?? 0;
      final chapter = item?.currentChapter ?? bookmark.currentChapter;
      _unreadCounts[bookmark.novelId] = total > chapter ? total - chapter : 0;
    }
    final novelIds =
        _bookmarks.map((item) => item.novelId.toLowerCase()).toSet();
    _totalChapters.removeWhere((novelId, _) => !novelIds.contains(novelId));
  }

  bool isR18Bookmark(String novelId) {
    final history = _historyByNovelId[novelId.toLowerCase()];
    return history != null &&
        Uri.tryParse(history.url)?.host == 'novel18.syosetu.com';
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

  /// 小説が連載かどうかを判定（修正版）
  bool isSerialNovel(Map<String, dynamic>? novelData) {
    if (novelData == null) return false;
    // novel_type: 1=連載, 2=短編
    final novelType = novelData['novel_type'];
    return novelType?.toString() == '1'; // 1が連載
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

  /// ブックマークを読み込み（初回のみAPI更新）
  Future<void> loadBookmarks({bool forceApiUpdate = false}) async {
    if (_isDisposed) return;

    _isLoading = true;
    _safeNotifyListeners();

    try {
      if (!_isDisposed) {
        await _loadBookmarksInternal();

        if (forceApiUpdate) {
          await _updateBookmarksFromApiInternal();
        }
      }
    } catch (e) {
      debugPrint('ブックマーク読み込みエラー: $e');
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        _safeNotifyListeners();
      }
    }
  }

  /// Hive通知で一覧が変わっても、更新対象のスナップショットを維持する。
  Future<bool> _updateBookmarksFromApiInternal() async {
    if (_bookmarks.isEmpty ||
        _isDisposed ||
        _isUpdatingFromApi ||
        isApiUpdateOnCooldown) {
      return false;
    }

    _isUpdatingFromApi = true;
    _safeNotifyListeners();
    final novelIds = _bookmarks.map((item) => item.novelId).toList();
    var succeeded = true;
    try {
      for (final novelId in novelIds) {
        if (_isDisposed) return false;
        if (!await _refreshBookmarkItem(novelId)) succeeded = false;
        if (!_isDisposed && novelId != novelIds.last) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
      if (succeeded) _lastApiUpdateTime = DateTime.now();
      if (!_isDisposed) await _updateUnreadCounts();
      return succeeded;
    } catch (e) {
      debugPrint('API更新エラー: $e');
      return false;
    } finally {
      _isUpdatingFromApi = false;
      _safeNotifyListeners();
    }
  }

  Future<bool> _refreshBookmarkItem(String novelId) async {
    final novelDetails = await fetchNovelDetails(
      novelId,
      r18: isR18Bookmark(novelId),
    );
    if (novelDetails == null || _isDisposed) return false;
    final bookmark = await _dbHelper.getBookmarkByNovelId(novelId);
    if (bookmark == null || _isDisposed) return false;

    final title =
        getNovelTitle(novelDetails, fallbackTitle: bookmark.novelTitle);
    final author = novelDetails['writer'] == null
        ? bookmark.author
        : getNovelAuthor(novelDetails);
    final serial = isSerialNovel(novelDetails);
    final lastUpdate = getLastUpdate(novelDetails) ?? bookmark.lastUpdate;
    final totalChapters = getTotalChapters(novelDetails);
    _totalChapters[novelId.toLowerCase()] = totalChapters;
    if (title != bookmark.novelTitle ||
        author != bookmark.author ||
        serial != bookmark.isSerialNovel ||
        lastUpdate != bookmark.lastUpdate) {
      bookmark
        ..novelTitle = title
        ..author = author
        ..isSerialNovel = serial
        ..lastUpdate = lastUpdate;
      await bookmark.save();
    }
    // 総話数だけ増えた場合も未読数を更新する。閲覧時刻・読書位置は保持する。
    await _dbHelper.updateReadingHistoryInfo(
      novelId,
      title,
      author,
      totalChapters,
      isSerialNovel: serial,
      lastUpdate: lastUpdate,
    );
    return true;
  }

  /// 手動でAPIから更新（クールタイムと同時実行をチェック）
  Future<bool> refreshFromApi() => _updateBookmarksFromApiInternal();

  Future<bool> refreshSingleBookmark(String novelId) async {
    if (_isDisposed || _isUpdatingFromApi || isApiUpdateOnCooldown) {
      return false;
    }
    if (!_bookmarks.any((item) => item.novelId == novelId)) return false;
    _isUpdatingFromApi = true;
    _safeNotifyListeners();
    try {
      final succeeded = await _refreshBookmarkItem(novelId);
      if (succeeded) {
        _lastApiUpdateTime = DateTime.now();
        await _updateUnreadCounts();
      }
      return succeeded;
    } catch (e) {
      debugPrint('単一ブックマーク更新エラー: $e');
      return false;
    } finally {
      _isUpdatingFromApi = false;
      _safeNotifyListeners();
    }
  }

  Future<void> deleteBookmark(String novelId) async {
    if (_isDisposed) return;

    try {
      await _dbHelper.deleteBookmark(novelId);
      await loadBookmarks(); // リロード（API更新はしない）
    } catch (e) {
      debugPrint('ブックマーク削除エラー: $e');
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
