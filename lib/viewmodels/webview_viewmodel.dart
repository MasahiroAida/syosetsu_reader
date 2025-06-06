import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/bookmark.dart';
import '../models/reading_history.dart';
import '../services/database_helper.dart';

class WebViewViewModel extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();

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
    _isLoading = loading;
    notifyListeners();
  }

  void updateNavigationState(bool canGoBack, bool canGoForward) {
    _canGoBack = canGoBack;
    _canGoForward = canGoForward;
    notifyListeners();
  }

  /// URLからncodeを抽出
  String? extractNcodeFromUrl(String url) {
    try {
      // なろうのURL形式に対応
      // https://ncode.syosetu.com/n9893km/ または
      // https://ncode.syosetu.com/n9893km/1/ など
      final regex =
          RegExp(r'https://ncode\.syosetu\.com/([a-zA-Z0-9]+)/?.*');
      final match = regex.firstMatch(url);
      
      if (match != null) {
        return match.group(1)?.toLowerCase(); // ncodeを小文字で返す
      }
      
      return null;
    } catch (e) {
      print('ncode抽出エラー: $e');
      return null;
    }
  }

  /// APIから小説詳細情報を取得
  Future<Map<String, dynamic>?> fetchNovelDetails(String ncode) async {
    if (ncode.isEmpty) return null;

    // キャッシュがあればそれを返す
    if (_novelDetailsCache.containsKey(ncode)) {
      _novelDetails = _novelDetailsCache[ncode];
      return _novelDetails;
    }

    try {
      _isLoadingNovelDetails = true;
      notifyListeners();

      final apiUrl = 'https://api.syosetu.com/novelapi/api?out=json&ncode=$ncode';
      print('小説詳細API呼び出し: $apiUrl');

      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is List && data.length > 1) {
          // 最初の要素はallcountなので、2番目の要素が小説データ
          final novelData = data[1] as Map<String, dynamic>;

          _novelDetails = novelData;
          _novelDetailsCache[ncode] = novelData; // キャッシュに保存
          print('小説詳細取得成功: ${novelData['title']}');

          return novelData;
        } else {
          print('小説データが見つかりません: $ncode');
          return null;
        }
      } else {
        print('API呼び出し失敗: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('小説詳細取得エラー: $e');
      return null;
    } finally {
      _isLoadingNovelDetails = false;
      notifyListeners();
    }
  }

  /// URLから小説詳細情報を取得
  Future<Map<String, dynamic>?> fetchNovelDetailsFromUrl(String url) async {
    final ncode = extractNcodeFromUrl(url);
    if (ncode == null) {
      print('URLからncodeを抽出できませんでした: $url');
      return null;
    }
    
    return await fetchNovelDetails(ncode);
  }

  /// 小説が連載かどうかを判定
  bool isSerialNovel(Map<String, dynamic>? novelData) {
    if (novelData == null) return false;
    
    // novel_type: 1=短編, 2=連載
    final novelType = novelData['novel_type'];
    return novelType == 2;
  }

  /// 小説のタイトルを取得
  String getNovelTitle(Map<String, dynamic>? novelData, {String? fallbackTitle}) {
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
    try {
      _isBookmarked = await _dbHelper.isBookmarked(novelId);
      notifyListeners();
    } catch (e) {
      print('ブックマーク状態確認エラー: $e');
    }
  }

  /// 特定の小説IDの履歴を取得
  Future<ReadingHistory?> getHistoryItem(String novelId) async {
    try {
      return await _dbHelper.getReadingHistoryByNovelId(novelId);
    } catch (e) {
      print('履歴取得エラー: $e');
      return null;
    }
  }

  /// 履歴を追加または更新（API情報を使用）
  Future<void> addToHistory(ReadingHistory history, {Map<String, dynamic>? novelData}) async {
    try {
      // 既存の履歴があるかチェック
      final existingHistory = await _dbHelper.getReadingHistoryByNovelId(history.novelId);
      
      // API情報がある場合は、より正確な情報で履歴を更新
      ReadingHistory updatedHistory = history;
      if (novelData != null) {
        updatedHistory = ReadingHistory(
          id: history.id,
          novelId: history.novelId,
          novelTitle: getNovelTitle(novelData, fallbackTitle: history.novelTitle),
          author: getNovelAuthor(novelData),
          currentChapter: history.currentChapter,
          totalChapters: getTotalChapters(novelData),
          lastViewed: DateTime.now(), // 常に現在時刻で更新
          url: history.url,
          scrollPosition: history.scrollPosition,
          isSerialNovel: isSerialNovel(novelData),
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
          lastViewed: DateTime.now(),
          url: history.url,
          scrollPosition: history.scrollPosition,
          isSerialNovel: history.isSerialNovel,
        );
      }
      
      if (existingHistory != null) {
        // 既存の履歴がある場合は全体を更新
        await _dbHelper.updateReadingHistoryFull(updatedHistory);
        print('閲覧履歴を更新: ${updatedHistory.novelId} (第${updatedHistory.currentChapter}章) at ${updatedHistory.lastViewed}');
      } else {
        // 新規の場合は挿入
        await _dbHelper.insertReadingHistory(updatedHistory);
        print('閲覧履歴を新規追加: ${updatedHistory.novelId} (第${updatedHistory.currentChapter}章) at ${updatedHistory.lastViewed}');
      }
    } catch (e) {
      print('履歴追加エラー: $e');
    }
  }

  /// URLが小説コンテンツかどうかを判定
  bool isNovelContentUrl(String url) {
    try {
      // なろうの小説ページかどうかチェック
      final novelRegex =
          RegExp(r'https://ncode\.syosetu\.com/([a-zA-Z0-9]+)(/[0-9]+)?/?.*');
      return novelRegex.hasMatch(url);
    } catch (e) {
      print('小説URL判定エラー: $e');
      return false;
    }
  }
  
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
  int _extractChapterFromUrl(String url) {
    try {
      final regex =
          RegExp(r'https://ncode\.syosetu\.com/([^/]+)/([0-9]+)/?.*');
      final match = regex.firstMatch(url);
      
      if (match != null) {
        return int.tryParse(match.group(2)!) ?? 0;
      }
      return 0;
    } catch (e) {
      print('章番号抽出エラー: $e');
      return 0;
    }
  }

  /// 読書履歴のチャプターを更新
  Future<void> updateReadingChapter(String novelId, int currentChapter) async {
    try {
      await _dbHelper.updateReadingHistory(novelId, currentChapter);
      
      if (currentChapter == 0) {
        print('読書履歴を目次/短編として更新: $novelId');
      } else {
        print('読書履歴のチャプターを更新: $novelId -> 第${currentChapter}章');
      }
    } catch (e) {
      print('読書履歴チャプター更新エラー: $e');
    }
  }

  /// 読書履歴の位置（チャプター + スクロール）を更新
  Future<void> updateReadingPosition(String novelId, int currentChapter, double scrollPosition) async {
    try {
      await _dbHelper.updateReadingPosition(novelId, currentChapter, scrollPosition);
      
      if (currentChapter == 0) {
        print('目次/短編の読書位置を更新: $novelId -> scroll: $scrollPosition');
      } else {
        print('連載の読書位置を更新: $novelId -> 第${currentChapter}章, scroll: $scrollPosition');
      }
    } catch (e) {
      print('読書位置更新エラー: $e');
    }
  }

  /// ブックマークのチャプターを更新
  Future<void> updateBookmarkChapter(String novelId, int currentChapter) async {
    try {
      final bookmark = await _dbHelper.getBookmarkByNovelId(novelId);
      if (bookmark != null) {
        await _dbHelper.updateBookmarkPosition(novelId, currentChapter, bookmark.scrollPosition ?? 0.0);
        
        if (currentChapter == 0) {
          print('ブックマークを目次/短編として更新: $novelId');
        } else {
          print('ブックマークのチャプターを更新: $novelId -> 第${currentChapter}章');
        }
      }
    } catch (e) {
      print('ブックマークチャプター更新エラー: $e');
    }
  }

  /// ブックマークの位置（チャプター + スクロール）を更新
  Future<void> updateBookmarkPosition(String novelId, int currentChapter, double scrollPosition) async {
    try {
      await _dbHelper.updateBookmarkPosition(novelId, currentChapter, scrollPosition);
      
      if (currentChapter == 0) {
        print('目次/短編ブックマーク位置を更新: $novelId -> scroll: $scrollPosition');
      } else {
        print('連載ブックマーク位置を更新: $novelId -> 第${currentChapter}章, scroll: $scrollPosition');
      }
    } catch (e) {
      print('ブックマーク位置更新エラー: $e');
    }
  }

  /// ブックマークを追加（API情報を使用）
  Future<bool> addBookmark(String novelId, String title, {
    int currentChapter = 1,
    double scrollPosition = 0.0,
    bool isSerialNovel = false,
    Map<String, dynamic>? novelData,
  }) async {
    try {
      final bookmark = Bookmark(
        id: novelId,
        novelId: novelId,
        novelTitle: novelData != null ? getNovelTitle(novelData, fallbackTitle: title) : title,
        author: novelData != null ? getNovelAuthor(novelData) : 'Unknown',
        currentChapter: currentChapter,
        addedAt: DateTime.now(),
        lastViewed: DateTime.now(),
        scrollPosition: scrollPosition,
        isSerialNovel: isSerialNovel,
      );
      
      await _dbHelper.insertBookmark(bookmark);
      _isBookmarked = true;
      notifyListeners();
      print('ブックマークを追加: $novelId');
      return true;
    } catch (e) {
      print('ブックマーク追加エラー: $e');
      return false;
    }
  }

  /// ブックマークを削除
  Future<bool> removeBookmark(String novelId) async {
    try {
      await _dbHelper.deleteBookmark(novelId);
      _isBookmarked = false;
      notifyListeners();
      print('ブックマークを削除: $novelId');
      return true;
    } catch (e) {
      print('ブックマーク削除エラー: $e');
      return false;
    }
  }

  /// ブックマークを切り替え（章情報とスクロール位置、API情報も保存）
  Future<bool> toggleBookmark(String novelId, String title, {
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
      print('ブックマーク切り替えエラー: $e');
      return _isBookmarked;
    }
  }

  /// URLから小説種別を判定するヘルパーメソッド
  bool isSerialNovelFromUrl(String url) {
    final serialRegex =
        RegExp(r'https://ncode\.syosetu\.com/([^/]+)/([0-9]+)/?.*');
    return serialRegex.hasMatch(url);
  }

  /// すべての読書履歴を取得
  Future<List<ReadingHistory>> getAllHistory() async {
    try {
      return await _dbHelper.getAllReadingHistory();
    } catch (e) {
      print('履歴一覧取得エラー: $e');
      return [];
    }
  }

  /// 章番号の表示用テキストを取得
  String getChapterDisplayText(int chapter, bool isSerialNovel) {
    if (!isSerialNovel || chapter == 0) {
      return '目次/短編';
    }
    return '第${chapter}章';
  }

  /// 履歴を削除
  Future<void> deleteHistory(String novelId) async {
    try {
      await _dbHelper.deleteReadingHistory(novelId);
    } catch (e) {
      print('履歴削除エラー: $e');
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
      return title?.toString();
    } catch (e) {
      print('タイトル取得エラー: $e');
      return null;
    }
  }

  /// 現在のページの章番号を取得
  Future<int?> getCurrentChapter(WebViewController controller, String currentUrl) async {
    try {
      // URLから章番号を抽出を試行
      if (isSerialNovelFromUrl(currentUrl)) {
        final regex =
            RegExp(r'https://ncode\.syosetu\.com/([^/]+)/([0-9]+)/?.*');
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
  
      final chapterString = chapterText?.toString() ?? '0';
      return int.tryParse(chapterString) ?? 0;
    } catch (e) {
      print('章番号取得エラー: $e');
      return 0;
    }
  }
}