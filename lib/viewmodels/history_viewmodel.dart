import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:hive/hive.dart';
import '../models/reading_history.dart';
import '../services/database_helper.dart';

class HistoryViewModel extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  List<ReadingHistory> _history = [];
  bool _isLoading = false;
  bool _isUpdatingFromApi = false;
  bool _isDisposed = false;
  DateTime? _lastApiUpdateTime; // 最後のAPI更新時刻
  StreamSubscription? _historySubscription;

  static const Duration _apiCooldownDuration = Duration(seconds: 30); // クールタイム

  HistoryViewModel() {
    _historySubscription =
        Hive.box<ReadingHistory>(DatabaseHelper.historyBoxName).watch().listen((_) async {
      if (_isDisposed) return;
      _history = await _dbHelper.getAllReadingHistory();
      _safeNotifyListeners();
    });
  }

  List<ReadingHistory> get history => _history;
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
    _historySubscription?.cancel();
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
      final regex =
          RegExp(r'https://(?:ncode|novel18)\.syosetu\.com/([a-zA-Z0-9]+)/?');
      final match = regex.firstMatch(url);
      return match?.group(1)?.toLowerCase();
    } catch (e) {
      print('ncode抽出エラー: $e');
      return null;
    }
  }

  /// APIから小説詳細情報を取得
  Future<Map<String, dynamic>?> fetchNovelDetails(String ncode,
      {bool r18 = false}) async {
    if (ncode.isEmpty || _isDisposed) return null;
    
    try {
      final baseUrl = r18
          ? 'https://api.syosetu.com/novel18api/api'
          : 'https://api.syosetu.com/novelapi/api';
      final apiUrl = '$baseUrl?out=json&ncode=$ncode';
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

  /// 履歴を読み込み（初回のみAPI更新）
  Future<void> loadHistory({bool forceApiUpdate = false}) async {
    if (_isDisposed) return;
    
    _isLoading = true;
    _safeNotifyListeners();

    try {
      if (!_isDisposed) {
        _history = await _dbHelper.getAllReadingHistory();

        if (forceApiUpdate) {
          await _updateHistoryFromApiInternal();
        }
      }
    } catch (e) {
      print('履歴読み込みエラー: $e');
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        _safeNotifyListeners();
      }
    }
  }

  /// APIから最新情報を取得して履歴を更新（内部用）
  Future<void> _updateHistoryFromApiInternal() async {
    if (_history.isEmpty || _isDisposed) return;

    _isUpdatingFromApi = true;
    _safeNotifyListeners();

    try {
      bool hasUpdates = false;
      
      for (int i = 0; i < _history.length && !_isDisposed; i++) {
        final historyItem = _history[i];
        
        // ncodeを抽出（ReadingHistoryのnovelIdがncodeと仮定）
        final ncode = historyItem.novelId.toLowerCase();
        
        // APIから最新情報を取得
        final isR18 = historyItem.url.contains('novel18.syosetu.com');
        final novelDetails = await fetchNovelDetails(ncode, r18: isR18);
        
        if (novelDetails != null && !_isDisposed) {
          final updatedTitle = getNovelTitle(novelDetails, fallbackTitle: historyItem.novelTitle);
          final updatedAuthor = getNovelAuthor(novelDetails);
          final updatedTotalChapters = getTotalChapters(novelDetails);
          
          // 情報が変更されている場合のみ更新
          if (updatedTitle != historyItem.novelTitle || 
              updatedAuthor != historyItem.author ||
              updatedTotalChapters != historyItem.totalChapters) {
            
            final updatedHistory = ReadingHistory(
              id: historyItem.id,
              novelId: historyItem.novelId,
              novelTitle: updatedTitle,
              author: updatedAuthor,
              currentChapter: historyItem.currentChapter,
              totalChapters: updatedTotalChapters,
              lastViewed: historyItem.lastViewed,
              url: historyItem.url,
              scrollPosition: historyItem.scrollPosition,
            );
            
            // データベースを更新
            await _dbHelper.updateReadingHistoryInfo(
              historyItem.novelId, 
              updatedTitle, 
              updatedAuthor, 
              updatedTotalChapters
            );
            
            // リスト内の履歴を更新
            if (!_isDisposed) {
              _history[i] = updatedHistory;
              hasUpdates = true;
            }
            
            print('履歴情報を更新: ${historyItem.novelTitle} -> $updatedTitle');
          }
        }
        
        // APIの負荷を軽減するため少し待機（途中で破棄された場合は停止）
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
      print('API更新がクールタイム中です。残り$cooldownRemainingSeconds秒');
      return false;
    }
    
    await _updateHistoryFromApiInternal();
    return true;
  }

  /// 単一の履歴項目を更新（クールタイムチェック付き）
  Future<bool> refreshSingleHistory(String novelId) async {
    if (_isDisposed) return false;
    
    // クールタイムチェック
    if (isApiUpdateOnCooldown) {
      print('API更新がクールタイム中です。残り$cooldownRemainingSeconds秒');
      return false;
    }
    
    try {
      _isUpdatingFromApi = true;
      _safeNotifyListeners();
      
      final historyIndex = _history.indexWhere((item) => item.novelId == novelId);
      if (historyIndex == -1) return false;
      
      final historyItem = _history[historyIndex];
      final ncode = historyItem.novelId.toLowerCase();
      
      // APIから最新情報を取得
      final isR18 = historyItem.url.contains('novel18.syosetu.com');
      final novelDetails = await fetchNovelDetails(ncode, r18: isR18);
      
      if (novelDetails != null && !_isDisposed) {
        final updatedTitle = getNovelTitle(novelDetails, fallbackTitle: historyItem.novelTitle);
        final updatedAuthor = getNovelAuthor(novelDetails);
        final updatedTotalChapters = getTotalChapters(novelDetails);
        
        // 情報が変更されている場合のみ更新
        if (updatedTitle != historyItem.novelTitle || 
            updatedAuthor != historyItem.author ||
            updatedTotalChapters != historyItem.totalChapters) {
          
          final updatedHistory = ReadingHistory(
            id: historyItem.id,
            novelId: historyItem.novelId,
            novelTitle: updatedTitle,
            author: updatedAuthor,
            currentChapter: historyItem.currentChapter,
            totalChapters: updatedTotalChapters,
            lastViewed: historyItem.lastViewed,
            url: historyItem.url,
            scrollPosition: historyItem.scrollPosition,
          );
          
          // データベースを更新
          await _dbHelper.updateReadingHistoryInfo(
            historyItem.novelId, 
            updatedTitle, 
            updatedAuthor, 
            updatedTotalChapters
          );
          
          // リスト内の履歴を更新
          if (!_isDisposed) {
            _history[historyIndex] = updatedHistory;
          }
          
          print('履歴情報を更新: ${historyItem.novelTitle} -> $updatedTitle');
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
      print('単一履歴更新エラー: $e');
      return false;
    } finally {
      if (!_isDisposed) {
        _isUpdatingFromApi = false;
        _safeNotifyListeners();
      }
    }
  }

  Future<void> deleteHistory(String novelId) async {
    if (_isDisposed) return;
    
    try {
      await _dbHelper.deleteReadingHistory(novelId);
      await loadHistory(); // リロード（API更新はしない）
    } catch (e) {
      print('履歴削除エラー: $e');
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

  String buildChapterUrl(String novelId, int currentChapter, {bool r18 = false}) {
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