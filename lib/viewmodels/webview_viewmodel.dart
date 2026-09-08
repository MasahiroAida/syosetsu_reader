import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/bookmark.dart';
import '../models/reading_history.dart';
import '../services/database_helper.dart';
import '../utils/novel_url.dart';

class WebViewViewModel extends ChangeNotifier {
  WebViewViewModel({http.Client? client, DatabaseHelper? database})
      : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _dbHelper = database ?? DatabaseHelper();

  final DatabaseHelper _dbHelper;
  final http.Client _client;
  final bool _ownsClient;
  bool _disposed = false;
  int _detailsRequest = 0;
  int _bookmarkRequest = 0;
  final Map<String, Future<Map<String, dynamic>?>> _pendingDetails = {};

  void _notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _detailsRequest++;
    _bookmarkRequest++;
    if (_ownsClient) _client.close();
    super.dispose();
  }

  /// APIから取得した小説データをキャッシュする
  final Map<String, Map<String, dynamic>> _novelDetailsCache = {};

  bool _isLoading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isBookmarked = false;

  // 小説詳細情報を保持するフィールドを追加
  Map<String, dynamic>? _novelDetails;
  bool _isLoadingNovelDetails = false;

  bool get isLoading => _isLoading;
  bool get canGoBack => _canGoBack;
  bool get canGoForward => _canGoForward;
  bool get isBookmarked => _isBookmarked;
  Map<String, dynamic>? get novelDetails => _novelDetails;
  bool get isLoadingNovelDetails => _isLoadingNovelDetails;

  void updateLoadingState(bool loading) {
    if (_disposed || _isLoading == loading) return;
    _isLoading = loading;
    _notifyListeners();
  }

  void updateNavigationState(bool canGoBack, bool canGoForward) {
    if (_disposed ||
        (_canGoBack == canGoBack && _canGoForward == canGoForward)) {
      return;
    }
    _canGoBack = canGoBack;
    _canGoForward = canGoForward;
    _notifyListeners();
  }

  /// URLからncodeを抽出
  String? extractNcodeFromUrl(String url) => NovelUrl.parse(url)?.ncode;

  /// Keep concurrent page requests separate; only the latest may update the UI.
  Future<Map<String, dynamic>?> fetchNovelDetails(String ncode,
      {bool r18 = false}) async {
    if (_disposed || ncode.isEmpty) return null;
    final request = ++_detailsRequest;
    final normalizedNcode = ncode.toLowerCase();
    final cacheKey = '${r18 ? 'r18' : 'general'}:$normalizedNcode';
    final cached = _novelDetailsCache[cacheKey];
    _novelDetails = cached;
    _isLoadingNovelDetails = cached == null;
    _notifyListeners();
    if (cached != null) return cached;

    final pending = _pendingDetails.putIfAbsent(
        cacheKey, () => _requestNovelDetails(normalizedNcode, r18: r18));
    try {
      final details = await pending;
      if (details != null) _novelDetailsCache[cacheKey] = details;
      if (!_disposed && request == _detailsRequest) _novelDetails = details;
      return details;
    } finally {
      if (identical(_pendingDetails[cacheKey], pending)) {
        _pendingDetails.remove(cacheKey);
      }
      if (!_disposed && request == _detailsRequest) {
        _isLoadingNovelDetails = false;
        _notifyListeners();
      }
    }
  }

  Future<Map<String, dynamic>?> _requestNovelDetails(String ncode,
      {required bool r18}) async {
    try {
      final uri = Uri.https(
          'api.syosetu.com',
          r18 ? '/novel18api/api/' : '/novelapi/api/',
          {'out': 'json', 'ncode': ncode});
      final response = await _client.get(uri, headers: {
        'User-Agent': 'SyosetsuReader/1.0',
      }).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final data = json.decode(utf8.decode(response.bodyBytes));
      if (data is! List || data.length < 2 || data[1] is! Map) return null;
      return Map<String, dynamic>.from(data[1] as Map);
    } catch (e) {
      debugPrint('小説詳細取得エラー: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchNovelDetailsFromUrl(String url) async {
    final page = NovelUrl.parse(url);
    if (page == null) {
      _detailsRequest++;
      _novelDetails = null;
      _isLoadingNovelDetails = false;
      _notifyListeners();
      return null;
    }
    return fetchNovelDetails(page.ncode, r18: page.isR18);
  }

  /// 小説が連載かどうかを判定
  bool isSerialNovel(Map<String, dynamic>? novelData) {
    if (novelData == null) return false;

    // novel_type: 2=短編, 1=連載
    final novelType = novelData['novel_type'];
    return novelType.toString() == '1';
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

  /// 小説のジャンルを取得
  String getNovelGenre(Map<String, dynamic>? novelData) {
    if (novelData == null) return 'その他';

    final genreMap = {
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

    final genre = novelData['genre'];
    if (genre != null) {
      return genreMap[int.tryParse(genre.toString())] ?? 'その他';
    }

    return 'その他';
  }

  Future<void> checkBookmarkStatus(String novelId) async {
    final request = ++_bookmarkRequest;
    _isBookmarked = false;
    _notifyListeners();
    try {
      final bookmarked = await _dbHelper.isBookmarked(novelId);
      if (_disposed || request != _bookmarkRequest) return;
      _isBookmarked = bookmarked;
      _notifyListeners();
    } catch (e) {
      debugPrint('ブックマーク状態確認エラー: $e');
    }
  }

  /// 特定の小説IDの履歴を取得
  Future<ReadingHistory?> getHistoryItem(String novelId) async {
    try {
      return await _dbHelper.getReadingHistoryByNovelId(novelId);
    } catch (e) {
      debugPrint('履歴取得エラー: $e');
      return null;
    }
  }

  /// 履歴を追加または更新（API情報を使用）+ ブックマークの最終閲覧時刻も更新
  Future<void> addToHistory(ReadingHistory history,
      {Map<String, dynamic>? novelData}) async {
    try {
      // 既存の履歴があるかチェック
      final existingHistory =
          await _dbHelper.getReadingHistoryByNovelId(history.novelId);

      final now = DateTime.now();

      // API情報がある場合は、より正確な情報で履歴を更新
      ReadingHistory updatedHistory = history;
      if (novelData != null) {
        updatedHistory = ReadingHistory(
          id: history.id,
          novelId: history.novelId,
          novelTitle:
              getNovelTitle(novelData, fallbackTitle: history.novelTitle),
          author: getNovelAuthor(novelData),
          currentChapter: history.currentChapter,
          totalChapters: getTotalChapters(novelData),
          lastViewed: now, // 現在時刻で更新
          url: history.url,
          scrollPosition: history.scrollPosition,
          isSerialNovel: isSerialNovel(novelData),
          lastUpdate: getLastUpdate(novelData),
        );
      } else {
        // API情報がない場合も最終閲覧時刻は更新
        updatedHistory = ReadingHistory(
          id: history.id,
          novelId: history.novelId,
          novelTitle: history.novelTitle,
          author: history.author,
          currentChapter: history.currentChapter,
          totalChapters: history.totalChapters,
          lastViewed: now, // 現在時刻で更新
          url: history.url,
          scrollPosition: history.scrollPosition,
          isSerialNovel: history.isSerialNovel,
          lastUpdate: history.lastUpdate,
        );
      }

      if (existingHistory != null) {
        // 既存の履歴がある場合は全体を更新
        await _dbHelper.updateReadingHistoryFull(updatedHistory);
        debugPrint(
            '閲覧履歴を更新: ${updatedHistory.novelId} (第${updatedHistory.currentChapter}章) at ${updatedHistory.lastViewed}');
      } else {
        // 新規の場合は挿入
        await _dbHelper.insertReadingHistory(updatedHistory);
        debugPrint(
            '閲覧履歴を新規追加: ${updatedHistory.novelId} (第${updatedHistory.currentChapter}章) at ${updatedHistory.lastViewed}');
      }

      // ★ ブックマークの最終閲覧時刻も同時に更新
      await updateBookmarkLastViewed(history.novelId, now, novelData);
    } catch (e) {
      debugPrint('履歴追加エラー: $e');
    }
  }

  /// ブックマークの最終閲覧時刻を更新（新規メソッド）
  Future<void> updateBookmarkLastViewed(String novelId, DateTime lastViewed,
      Map<String, dynamic>? novelData) async {
    try {
      final bookmark = await _dbHelper.getBookmarkByNovelId(novelId);
      if (bookmark != null) {
        // ブックマークが存在する場合は最終閲覧時刻を更新
        bookmark.lastViewed = lastViewed;

        // API情報がある場合は、より正確な情報で更新
        if (novelData != null) {
          bookmark.novelTitle =
              getNovelTitle(novelData, fallbackTitle: bookmark.novelTitle);
          bookmark.author = getNovelAuthor(novelData);
          bookmark.isSerialNovel = isSerialNovel(novelData);
          bookmark.lastUpdate = getLastUpdate(novelData);
        }

        await bookmark.save();
        debugPrint('ブックマークの最終閲覧時刻を更新: $novelId at $lastViewed');
      }
    } catch (e) {
      debugPrint('ブックマーク最終閲覧時刻更新エラー: $e');
    }
  }

  /// URLが小説コンテンツかどうかを判定
  bool isNovelContentUrl(String url) => NovelUrl.parse(url) != null;

  /// URLから基本的な小説情報を推測
  Map<String, dynamic> inferNovelInfoFromUrl(String url, String fallbackTitle) {
    final ncode = extractNcodeFromUrl(url);
    final isSerial = isSerialNovelFromUrl(url);

    return {
      'ncode': ncode ?? 'unknown',
      'title': fallbackTitle,
      'author': 'Unknown',
      'isSerial': isSerial,
      'chapter': isSerial ? _extractChapterFromUrl(url) : 0,
    };
  }

  /// URLから章番号を抽出（プライベートメソッドの代替）
  int _extractChapterFromUrl(String url) => NovelUrl.parse(url)?.chapter ?? 0;

  /// 読書履歴のチャプターを更新（最終閲覧時刻も更新）
  Future<void> updateReadingChapter(String novelId, int currentChapter) async {
    try {
      final now = DateTime.now();
      await _dbHelper.updateReadingHistory(novelId, currentChapter);

      // ★ ブックマークの最終閲覧時刻も同時に更新
      await updateBookmarkLastViewed(novelId, now, null);

      if (currentChapter == 0) {
        debugPrint('読書履歴を目次/短編として更新: $novelId');
      } else {
        debugPrint('読書履歴のチャプターを更新: $novelId -> 第$currentChapter章');
      }
    } catch (e) {
      debugPrint('読書履歴チャプター更新エラー: $e');
    }
  }

  /// 読書履歴の位置（チャプター + スクロール）を更新（最終閲覧時刻も更新）
  Future<void> updateReadingPosition(
      String novelId, int currentChapter, double scrollPosition) async {
    try {
      final now = DateTime.now();
      await _dbHelper.updateReadingPosition(
          novelId, currentChapter, scrollPosition);

      // ★ ブックマークの最終閲覧時刻も同時に更新
      await updateBookmarkLastViewed(novelId, now, null);

      if (currentChapter == 0) {
        debugPrint('目次/短編の読書位置を更新: $novelId -> scroll: $scrollPosition');
      } else {
        debugPrint(
            '連載の読書位置を更新: $novelId -> 第$currentChapter章, scroll: $scrollPosition');
      }
    } catch (e) {
      debugPrint('読書位置更新エラー: $e');
    }
  }

  /// ブックマークのチャプターを更新
  Future<void> updateBookmarkChapter(String novelId, int currentChapter) async {
    try {
      final bookmark = await _dbHelper.getBookmarkByNovelId(novelId);
      if (bookmark != null) {
        await _dbHelper.updateBookmarkPosition(
            novelId, currentChapter, bookmark.scrollPosition ?? 0.0);

        if (currentChapter == 0) {
          debugPrint('ブックマークを目次/短編として更新: $novelId');
        } else {
          debugPrint('ブックマークのチャプターを更新: $novelId -> 第$currentChapter章');
        }
      }
    } catch (e) {
      debugPrint('ブックマークチャプター更新エラー: $e');
    }
  }

  /// ブックマークの位置（チャプター + スクロール）を更新
  Future<void> updateBookmarkPosition(
      String novelId, int currentChapter, double scrollPosition) async {
    try {
      await _dbHelper.updateBookmarkPosition(
          novelId, currentChapter, scrollPosition);

      if (currentChapter == 0) {
        debugPrint('目次/短編ブックマーク位置を更新: $novelId -> scroll: $scrollPosition');
      } else {
        debugPrint(
            '連載ブックマーク位置を更新: $novelId -> 第$currentChapter章, scroll: $scrollPosition');
      }
    } catch (e) {
      debugPrint('ブックマーク位置更新エラー: $e');
    }
  }

  /// ブックマークを追加（API情報を使用）
  Future<bool> addBookmark(
    String novelId,
    String title, {
    int currentChapter = 1,
    double scrollPosition = 0.0,
    bool isSerialNovel = false,
    Map<String, dynamic>? novelData,
  }) async {
    final request = ++_bookmarkRequest;
    try {
      final now = DateTime.now();
      final bookmark = Bookmark(
        id: novelId,
        novelId: novelId,
        novelTitle: novelData != null
            ? getNovelTitle(novelData, fallbackTitle: title)
            : title,
        author: novelData != null ? getNovelAuthor(novelData) : 'Unknown',
        currentChapter: currentChapter,
        addedAt: now,
        lastViewed: now,
        scrollPosition: scrollPosition,
        isSerialNovel: isSerialNovel,
        lastUpdate: getLastUpdate(novelData),
      );

      await _dbHelper.insertBookmark(bookmark);
      if (!_disposed && request == _bookmarkRequest) {
        _isBookmarked = true;
        _notifyListeners();
      }
      debugPrint('ブックマークを追加: $novelId');
      return true;
    } catch (e) {
      debugPrint('ブックマーク追加エラー: $e');
      return false;
    }
  }

  /// ブックマークを削除
  Future<bool> removeBookmark(String novelId) async {
    final request = ++_bookmarkRequest;
    try {
      await _dbHelper.deleteBookmark(novelId);
      if (!_disposed && request == _bookmarkRequest) {
        _isBookmarked = false;
        _notifyListeners();
      }
      debugPrint('ブックマークを削除: $novelId');
      return true;
    } catch (e) {
      debugPrint('ブックマーク削除エラー: $e');
      return false;
    }
  }

  /// ブックマークを切り替え（章情報とスクロール位置、API情報も保存）
  Future<bool> toggleBookmark(
    String novelId,
    String title, {
    int currentChapter = 0,
    double scrollPosition = 0.0,
    bool isSerialNovel = false,
    Map<String, dynamic>? novelData,
  }) async {
    try {
      if (_isBookmarked) {
        return await removeBookmark(novelId) ? false : true;
      } else {
        return await addBookmark(novelId, title,
            currentChapter: currentChapter,
            scrollPosition: scrollPosition,
            isSerialNovel: isSerialNovel,
            novelData: novelData);
      }
    } catch (e) {
      debugPrint('ブックマーク切り替えエラー: $e');
      return _isBookmarked;
    }
  }

  /// URLから小説種別を判定するヘルパーメソッド
  bool isSerialNovelFromUrl(String url) =>
      (NovelUrl.parse(url)?.chapter ?? 0) > 0;

  /// すべての読書履歴を取得
  Future<List<ReadingHistory>> getAllHistory() async {
    try {
      return await _dbHelper.getAllReadingHistory();
    } catch (e) {
      debugPrint('履歴一覧取得エラー: $e');
      return [];
    }
  }

  /// 章番号の表示用テキストを取得
  String getChapterDisplayText(int chapter, bool isSerialNovel) {
    if (!isSerialNovel || chapter == 0) {
      return '目次/短編';
    }
    return '第$chapter章';
  }

  /// 履歴を削除
  Future<void> deleteHistory(String novelId) async {
    try {
      await _dbHelper.deleteReadingHistory(novelId);
    } catch (e) {
      debugPrint('履歴削除エラー: $e');
    }
  }

  // WebView用のJavaScript実行メソッド
  void adjustFontSize(WebViewController controller) {
    controller.runJavaScript('''
      // 小説本文の要素を特定してフォントサイズを調整
      var novelTextElements = document.querySelectorAll('.js-novel-text, .p-novel__text, .novel_view');
      novelTextElements.forEach(function(element) {
        var currentSize = window.getComputedStyle(element).fontSize;
        var newSize = parseFloat(currentSize) * 1.1;
        element.style.fontSize = newSize + 'px';
      });
      
      // 一般的なテキスト要素も調整
      var textElements = document.querySelectorAll('p, div');
      textElements.forEach(function(element) {
        if (element.innerText && element.innerText.length > 10) {
          var currentSize = window.getComputedStyle(element).fontSize;
          var newSize = parseFloat(currentSize) * 1.05;
          element.style.fontSize = newSize + 'px';
        }
      });
    ''');
  }

  void changeColorScheme(WebViewController controller) {
    controller.runJavaScript('''
      // ダークモード切り替え
      var isDarkMode = document.body.getAttribute('data-dark-mode') === 'true';
      
      if (!isDarkMode) {
        // ダークモード適用
        document.body.style.backgroundColor = '#1a1a1a';
        document.body.style.color = '#e0e0e0';
        document.body.setAttribute('data-dark-mode', 'true');
        
        // 小説本文エリアの背景も変更
        var novelElements = document.querySelectorAll('.js-novel-text, .p-novel__text');
        novelElements.forEach(function(element) {
          element.style.backgroundColor = '#2d2d2d';
          element.style.color = '#f0f0f0';
          element.style.padding = '15px';
          element.style.borderRadius = '5px';
        });
        
        // リンクの色も調整
        var links = document.querySelectorAll('a');
        links.forEach(function(link) {
          link.style.color = '#64b5f6';
        });
      } else {
        // ライトモード適用
        document.body.style.backgroundColor = 'white';
        document.body.style.color = 'black';
        document.body.setAttribute('data-dark-mode', 'false');
        
        // 小説本文エリアの背景をリセット
        var novelElements = document.querySelectorAll('.js-novel-text, .p-novel__text');
        novelElements.forEach(function(element) {
          element.style.backgroundColor = '';
          element.style.color = '';
          element.style.padding = '';
          element.style.borderRadius = '';
        });
        
        // リンクの色をリセット
        var links = document.querySelectorAll('a');
        links.forEach(function(link) {
          link.style.color = '';
        });
      }
    ''');
  }

  void adjustLineHeight(WebViewController controller) {
    controller.runJavaScript('''
      // 小説本文の行間を調整
      var novelTextElements = document.querySelectorAll('.js-novel-text, .p-novel__text, .novel_view');
      novelTextElements.forEach(function(element) {
        element.style.lineHeight = '1.8';
        element.style.letterSpacing = '0.5px';
      });
      
      // パラグラフの行間も調整
      var paragraphs = document.querySelectorAll('p');
      paragraphs.forEach(function(p) {
        if (p.innerText && p.innerText.length > 10) {
          p.style.lineHeight = '1.7';
          p.style.marginBottom = '1em';
        }
      });
    ''');
  }

  /// フォントサイズをリセット
  void resetFontSize(WebViewController controller) {
    controller.runJavaScript('''
      var allElements = document.querySelectorAll('*');
      allElements.forEach(function(element) {
        element.style.fontSize = '';
      });
    ''');
  }

  /// スタイルを全てリセット
  void resetAllStyles(WebViewController controller) {
    controller.runJavaScript('''
      // 全ての要素のスタイルをリセット
      var allElements = document.querySelectorAll('*');
      allElements.forEach(function(element) {
        element.style.fontSize = '';
        element.style.lineHeight = '';
        element.style.backgroundColor = '';
        element.style.color = '';
        element.style.padding = '';
        element.style.borderRadius = '';
        element.style.letterSpacing = '';
        element.style.marginBottom = '';
      });
      
      // body の特別な属性も削除
      document.body.removeAttribute('data-dark-mode');
    ''');
  }

  /// 現在のページのタイトルを取得
  Future<String?> getCurrentPageTitle(WebViewController controller) async {
    try {
      final title = await controller.runJavaScriptReturningResult('''
        document.querySelector('.p-novel__title')?.innerText || document.title;
      ''');
      return title.toString();
    } catch (e) {
      debugPrint('タイトル取得エラー: $e');
      return null;
    }
  }

  /// 現在のページの章番号を取得
  Future<int?> getCurrentChapter(
      WebViewController controller, String currentUrl) async {
    try {
      // URLから章番号を抽出を試行
      if (isSerialNovelFromUrl(currentUrl)) {
        final regex = RegExp(
            r'https://(?:ncode|novel18)\.syosetu\.com/([^/]+)/([0-9]+)/?.*');
        final match = regex.firstMatch(currentUrl);
        if (match != null) {
          return int.tryParse(match.group(2)!) ?? 1;
        }
      }

      // JavaScriptで章番号を取得を試行
      final chapterText = await controller.runJavaScriptReturningResult(r'''
        (function() {
          // 複数のセレクタで章番号を探す
          var chapterElement = document.querySelector('.p-novel__number') ||
                              document.querySelector('.chapter-number') ||
                              document.querySelector('.novel_subno');
          
          if (chapterElement) {
            var text = chapterElement.innerText || chapterElement.textContent;
            var match = text.match(/([0-9]+)/);
            return match ? match[1] : '0';
          }
          
          // URLから章番号を抽出
          var urlMatch = window.location.pathname.match(/\/([0-9]+)\/?$/);
          return urlMatch ? urlMatch[1] : '0';
        })();
      ''');

      final chapterString = chapterText.toString();
      return int.tryParse(chapterString) ?? 0;
    } catch (e) {
      debugPrint('章番号取得エラー: $e');
      return 0;
    }
  }

  /// ブックマーク存在確認（外部からアクセス用）
  Future<Bookmark?> getBookmarkByNovelId(String novelId) async {
    return await _dbHelper.getBookmarkByNovelId(novelId);
  }

  /// ブックマーク直接挿入（外部からアクセス用）
  Future<void> insertBookmark(Bookmark bookmark) async {
    await _dbHelper.insertBookmark(bookmark);
    await checkBookmarkStatus(bookmark.novelId);
  }
}
