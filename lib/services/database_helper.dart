import 'package:hive/hive.dart';
import '../models/novel.dart';
import '../models/bookmark.dart';
import '../models/reading_history.dart';

class DatabaseHelper {
  static const String novelBoxName = 'novels';
  static const String bookmarkBoxName = 'bookmarks';
  static const String historyBoxName = 'reading_history';

  Box<Novel> get _novelBox => Hive.box<Novel>(novelBoxName);
  Box<Bookmark> get _bookmarkBox => Hive.box<Bookmark>(bookmarkBoxName);
  Box<ReadingHistory> get _historyBox => Hive.box<ReadingHistory>(historyBoxName);

  // Novel operations
  Future<int> insertNovel(Novel novel) async {
    await _novelBox.put(novel.id, novel);
    return 0;
  }

  Future<List<Novel>> getNovels() async {
    return _novelBox.values.toList();
  }

  Future<int> updateNovel(Novel novel) async {
    await _novelBox.put(novel.id, novel);
    return 0;
  }

  Future<int> deleteNovel(String id) async {
    await _novelBox.delete(id);
    return 0;
  }

  // Bookmark operations
  Future<int> insertBookmark(Bookmark bookmark) async {
    await _bookmarkBox.put(bookmark.id, bookmark);
    return 0;
  }

  Future<List<Bookmark>> getBookmarks() async {
    final list = _bookmarkBox.values.toList();
    list.sort((a, b) => b.lastViewed.compareTo(a.lastViewed));
    return list;
  }

  Future<Bookmark?> getBookmarkByNovelId(String novelId) async {
    try {
      return _bookmarkBox.values.firstWhere((b) => b.novelId == novelId);
    } catch (_) {
      return null;
    }
  }

  Future<int> updateBookmark(Bookmark bookmark) async {
    await _bookmarkBox.put(bookmark.id, bookmark);
    return 0;
  }

  Future<int> deleteBookmark(String novelId) async {
    final item = await getBookmarkByNovelId(novelId);
    if (item != null) {
      await item.delete();
    }
    return 0;
  }

  Future<bool> isBookmarked(String novelId) async {
    return await getBookmarkByNovelId(novelId) != null;
  }

  // Reading history operations
  Future<int> insertReadingHistory(ReadingHistory history) async {
    await _historyBox.put(history.id, history);
    return 0;
  }

  Future<List<ReadingHistory>> getReadingHistory() async {
    final list = _historyBox.values.toList();
    list.sort((a, b) => b.lastViewed.compareTo(a.lastViewed));
    if (list.length > 100) {
      return list.sublist(0, 100);
    }
    return list;
  }

  Future<List<ReadingHistory>> getAllReadingHistory() async {
    final list = _historyBox.values.toList();
    list.sort((a, b) => b.lastViewed.compareTo(a.lastViewed));
    return list;
  }

  Future<ReadingHistory?> getReadingHistoryByNovelId(String novelId) async {
    try {
      return _historyBox.values.firstWhere((h) => h.novelId == novelId);
    } catch (_) {
      return null;
    }
  }

  Future<int> updateReadingHistory(String novelId, int currentChapter) async {
    final history = await getReadingHistoryByNovelId(novelId);
    if (history != null) {
      history.currentChapter = currentChapter;
      history.lastViewed = DateTime.now();
      await history.save();
    }
    return 0;
  }

  Future<int> updateReadingHistoryFull(ReadingHistory history) async {
    await _historyBox.put(history.id, history);
    return 0;
  }

  Future<int> deleteReadingHistory(String novelId) async {
    final history = await getReadingHistoryByNovelId(novelId);
    if (history != null) {
      await history.delete();
    }
    return 0;
  }

  Future<int> updateReadingPosition(
      String novelId, int currentChapter, double scrollPosition) async {
    final history = await getReadingHistoryByNovelId(novelId);
    if (history != null) {
      history.currentChapter = currentChapter;
      history.scrollPosition = scrollPosition;
      history.lastViewed = DateTime.now();
      await history.save();
    }
    return 0;
  }

  Future<int> updateBookmarkPosition(
      String novelId, int currentChapter, double scrollPosition) async {
    final bookmark = await getBookmarkByNovelId(novelId);
    if (bookmark != null) {
      bookmark.currentChapter = currentChapter;
      bookmark.scrollPosition = scrollPosition;
      bookmark.lastViewed = DateTime.now();
      await bookmark.save();
    }
    return 0;
  }

  bool isSerialNovelFromUrl(String url) {
    final serialRegex =
        RegExp(r'https://ncode\.syosetu\.com/([^/]+)/([0-9]+)/?.*');
    return serialRegex.hasMatch(url);
  }

  int extractChapterFromUrl(String url) {
    if (!isSerialNovelFromUrl(url)) return 0;

    final regex =
        RegExp(r'https://ncode\.syosetu\.com/([^/]+)/([0-9]+)/?.*');
    final match = regex.firstMatch(url);

    if (match != null) {
      return int.tryParse(match.group(2)!) ?? 0;
    }
    return 0;
  }

  String buildNovelUrl(String novelId, int chapter) {
    final baseUrl = 'https://ncode.syosetu.com/${novelId.toLowerCase()}/';
    if (chapter > 0) {
      return '$baseUrl$chapter/';
    } else {
      return baseUrl;
    }
  }

  Future<void> updateBookmarkInfo(
      String novelId, String title, String author) async {
    final bookmark = await getBookmarkByNovelId(novelId);
    if (bookmark != null) {
      bookmark
        ..novelTitle = title
        ..author = author
        ..lastViewed = DateTime.now();
      await bookmark.save();
    }
  }

  Future<void> updateReadingHistoryInfo(
      String novelId, String title, String author, int totalChapters,
      {bool? isSerialNovel}) async {
    final history = await getReadingHistoryByNovelId(novelId);
    if (history != null) {
      history
        ..novelTitle = title
        ..author = author
        ..totalChapters = totalChapters
        ..isSerialNovel = isSerialNovel ?? history.isSerialNovel
        ..lastViewed = DateTime.now();
      await history.save();
    }
  }

  Future<void> updateBookmarkSerialType(
      String novelId, bool isSerialNovel) async {
    final bookmark = await getBookmarkByNovelId(novelId);
    if (bookmark != null) {
      bookmark.isSerialNovel = isSerialNovel;
      await bookmark.save();
    }
  }

  Future<void> cleanOldHistory({int keepCount = 20}) async {
    final list = await getAllReadingHistory();
    for (int i = keepCount; i < list.length; i++) {
      await list[i].delete();
    }
  }

  Future<Map<String, int>> getDatabaseStats() async {
    return {
      'novels': _novelBox.length,
      'bookmarks': _bookmarkBox.length,
      'history': _historyBox.length,
    };
  }

  Future<void> closeDatabase() async {
    await Hive.close();
  }
}
