import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/bookmark.dart';
import '../services/database_helper.dart';

class BookmarkViewModel extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  List<Bookmark> _bookmarks = [];
  bool _isLoading = false;
  bool _isUpdatingFromApi = false;
  bool _isDisposed = false;
  DateTime? _lastApiUpdateTime; // 最後のAPI更新時刻
  
  static const Duration _apiCooldownDuration = Duration(seconds: 30); // クールタイム

  List<Bookmark> get bookmarks => _bookmarks;
  bool get isLoading => _isLoading;
  bool get isUpdatingFromApi => _isUpdatingFromApi;
  
  /// API更新のクールタイムが有効かどうか
  bool get isApiUpdateOnCooldown {
    if (_lastApiUpdateTime == null) return false;
    return DateTime.now().difference(_lastApiUpdateTime!) < _apiCooldownDuration;
  }
  
  /// クールタイム残り時間（秒）
  int get cooldownRemainingSeconds {
    if (_lastApiUpdateTime == null) return 0;
    final elapsed = DateTime.now().difference(_lastApiUpdateTime!);
    final remaining = _apiCooldownDuration - elapsed;
    return remaining.inSeconds > 0 ? remaining.inSeconds : 0;
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// URLからncodeを抽出
  String? extractNcodeFromUrl(String url) {
    try {
      final regex = RegExp(r'https://ncode\.syosetu\.com/([a-zA-Z0-9]+)/?');
      final match = regex.firstMatch(url);
      return match?.group(1)?.toLowerCase();
    } catch (e) {
      print('ncode抽出エラー: $e');
      return null;
    }
  }

  /// APIから小説詳細情報を取得
  Future<Map<String, dynamic>?> fetchNovelDetails(String ncode) async {
    if (ncode.isEmpty || _isDisposed) return null;
    
    try {
      final apiUrl = 'https://api.syosetu.com/novelapi/api?out=json&ncode=$ncode';
      final response = await http.get(Uri.parse(apiUrl));
      
      if (response.statusCode == 200 && !_isDisposed) {
        final data = json.decode(response.body);
        if (data is List && data.length > 1) {
          return data[1] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('小説詳細取得エラー: $e');
      return null;
    }
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

  /// 小説が連載かどうかを判定
  bool isSerialNovel(Map<String, dynamic>? novelData) {
    if (novelData == null) return false;
    final novelType = novelData['novel_type'];
    return novelType == 2;
  }

  /// 小説の総話数を取得
  int getTotalChapters(Map<String, dynamic>? novelData) {
    if (novelData != null && novelData['general_all_no'] != null) {
      return int.tryParse(novelData['general_all_no'].toString()) ?? 1;
    }
    return 1;
  }

  /// ブックマークを読み込み（初回のみAPI更新）
  Future<void> loadBookmarks({bool forceApiUpdate = false}) async {
    if (_isDisposed) return;
    
    _isLoading = true;
    _safeNotifyListeners();

    try {
      if (!_isDisposed) {
        _bookmarks = await _dbHelper.getBookmarks();

        if (forceApiUpdate) {
          await _updateBookmarksFromApiInternal();
        }
      }
    } catch (e) {
      print('ブックマーク読み込みエラー: $e');
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        _safeNotifyListeners();
      }
    }
  }

  /// APIから最新情報を取得してブックマークを更新（内部用）
  Future<void> _updateBookmarksFromApiInternal() async {
    if (_bookmarks.isEmpty || _isDisposed) return;

    _isUpdatingFromApi = true;
    _safeNotifyListeners();

    try {
      bool hasUpdates = false;
      
      for (int i = 0; i < _bookmarks.length && !_isDisposed; i++) {
        final bookmark = _bookmarks[i];
        
        // ncodeを抽出
        final ncode = bookmark.novelId.toLowerCase();
        
        // APIから最新情報を取得
        final novelDetails = await fetchNovelDetails(ncode);
        
        if (novelDetails != null && !_isDisposed) {
          final updatedTitle = getNovelTitle(novelDetails, fallbackTitle: bookmark.novelTitle);
          final updatedAuthor = getNovelAuthor(novelDetails);
          //final updatedIsSerial = isSerialNovel(novelDetails);
          
          // 情報が変更されている場合のみ更新
          if (updatedTitle != bookmark.novelTitle || 
              updatedAuthor != bookmark.author) {

            final updatedBookmark = Bookmark(
              id: bookmark.id,
              novelId: bookmark.novelId,
              novelTitle: updatedTitle,
              author: updatedAuthor,
              currentChapter: bookmark.currentChapter,
              //isSerialNovel: updatedIsSerial,
              addedAt: bookmark.addedAt,
              lastViewed: bookmark.lastViewed,
              scrollPosition: bookmark.scrollPosition,
            );
            
            // データベースを更新
            await _dbHelper.updateBookmarkInfo(
              bookmark.novelId, 
              updatedTitle, 
              updatedAuthor, 
              //updatedIsSerial
            );
            
            // リスト内のブックマークを更新
            if (!_isDisposed) {
              _bookmarks[i] = updatedBookmark;
              hasUpdates = true;
            }
            
            print('ブックマーク情報を更新: ${bookmark.novelTitle} -> $updatedTitle');
          }
        }
        
        // APIの負荷を軽減するため少し待機
        if (!_isDisposed) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
      
      // API更新時刻を記録
      _lastApiUpdateTime = DateTime.now();
      
      if (hasUpdates && !_isDisposed) {
        _safeNotifyListeners();
      }
    } catch (e) {
      print('API更新エラー: $e');
    } finally {
      if (!_isDisposed) {
        _isUpdatingFromApi = false;
        _safeNotifyListeners();
      }
    }
  }

  /// 手動でAPIから更新（クールタイムチェック付き）
  Future<bool> refreshFromApi() async {
    if (_isDisposed) return false;
    
    // クールタイムチェック
    if (isApiUpdateOnCooldown) {
      print('API更新がクールタイム中です。残り${cooldownRemainingSeconds}秒');
      return false;
    }
    
    await _updateBookmarksFromApiInternal();
    return true;
  }

  /// 単一のブックマーク項目を更新（クールタイムチェック付き）
  Future<bool> refreshSingleBookmark(String novelId) async {
    if (_isDisposed) return false;
    
    // クールタイムチェック
    if (isApiUpdateOnCooldown) {
      print('API更新がクールタイム中です。残り${cooldownRemainingSeconds}秒');
      return false;
    }
    
    try {
      _isUpdatingFromApi = true;
      _safeNotifyListeners();
      
      final bookmarkIndex = _bookmarks.indexWhere((item) => item.novelId == novelId);
      if (bookmarkIndex == -1) return false;
      
      final bookmark = _bookmarks[bookmarkIndex];
      final ncode = bookmark.novelId.toLowerCase();
      
      // APIから最新情報を取得
      final novelDetails = await fetchNovelDetails(ncode);
      
      if (novelDetails != null && !_isDisposed) {
        final updatedTitle = getNovelTitle(novelDetails, fallbackTitle: bookmark.novelTitle);
        final updatedAuthor = getNovelAuthor(novelDetails);
        //final updatedIsSerial = isSerialNovel(novelDetails);
        
        // 情報が変更されている場合のみ更新
        if (updatedTitle != bookmark.novelTitle || 
            updatedAuthor != bookmark.author) {
          
          final updatedBookmark = Bookmark(
            id: bookmark.id,
            novelId: bookmark.novelId,
            novelTitle: updatedTitle,
            author: updatedAuthor,
            currentChapter: bookmark.currentChapter,
            //isSerialNovel: updatedIsSerial,
            addedAt: bookmark.addedAt,
            lastViewed: bookmark.lastViewed,
            scrollPosition: bookmark.scrollPosition,
          );
          
          // データベースを更新
          await _dbHelper.updateBookmarkInfo(
            bookmark.novelId, 
            updatedTitle, 
            updatedAuthor
          );
          
          // リスト内のブックマークを更新
          if (!_isDisposed) {
            _bookmarks[bookmarkIndex] = updatedBookmark;
          }
          
          print('ブックマーク情報を更新: ${bookmark.novelTitle} -> $updatedTitle');
        }
        
        // API更新時刻を記録
        _lastApiUpdateTime = DateTime.now();
        
        if (!_isDisposed) {
          _safeNotifyListeners();
        }
        
        return true;
      }
      
      return false;
    } catch (e) {
      print('単一ブックマーク更新エラー: $e');
      return false;
    } finally {
      if (!_isDisposed) {
        _isUpdatingFromApi = false;
        _safeNotifyListeners();
      }
    }
  }

  Future<void> deleteBookmark(String novelId) async {
    if (_isDisposed) return;
    
    try {
      await _dbHelper.deleteBookmark(novelId);
      await loadBookmarks(); // リロード（API更新はしない）
    } catch (e) {
      print('ブックマーク削除エラー: $e');
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

  String buildChapterUrl(String novelId, int currentChapter) {
    if (currentChapter > 0) {
      return 'https://ncode.syosetu.com/${novelId.toLowerCase()}/$currentChapter/';
    } else {
      return 'https://ncode.syosetu.com/${novelId.toLowerCase()}/';
    }
  }

  String buildHomeUrl(String novelId) {
    return 'https://ncode.syosetu.com/${novelId.toLowerCase()}/';
  }
}