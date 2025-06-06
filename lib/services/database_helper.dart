import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/novel.dart';
import '../models/bookmark.dart';
import '../models/reading_history.dart';

class DatabaseHelper {
  static Database? _database;
  static const String dbName = 'novel_reader.db';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), dbName);
    return await openDatabase(
      path,
      version: 4, // Increment version number
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE novels(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        cover_url TEXT,
        last_read_chapter INTEGER DEFAULT 0,
        unread_chapter_count INTEGER DEFAULT 0,
        added_at INTEGER NOT NULL,
        summary TEXT,
        keyword TEXT,
        total_chapters INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE bookmarks(
        id TEXT PRIMARY KEY,
        novel_id TEXT NOT NULL,
        novel_title TEXT NOT NULL,
        author TEXT NOT NULL,
        current_chapter INTEGER DEFAULT 0,
        added_at INTEGER NOT NULL,
        last_viewed INTEGER NOT NULL,
        scroll_position REAL DEFAULT 0.0,
        is_serial_novel INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE reading_history(
        id TEXT PRIMARY KEY,
        novel_id TEXT NOT NULL,
        novel_title TEXT NOT NULL,
        author TEXT NOT NULL,
        current_chapter INTEGER DEFAULT 0,
        total_chapters INTEGER DEFAULT 0,
        last_viewed INTEGER NOT NULL,
        url TEXT NOT NULL,
        scroll_position REAL DEFAULT 0.0,
        is_serial_novel INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE novels ADD COLUMN summary TEXT');
      await db.execute('ALTER TABLE novels ADD COLUMN keyword TEXT');
      await db.execute('ALTER TABLE novels ADD COLUMN total_chapters INTEGER');
      
      await db.execute('''
        CREATE TABLE IF NOT EXISTS bookmarks(
          id TEXT PRIMARY KEY,
          novel_id TEXT NOT NULL,
          novel_title TEXT NOT NULL,
          author TEXT NOT NULL,
          current_chapter INTEGER DEFAULT 0,
          added_at INTEGER NOT NULL,
          last_viewed INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS reading_history(
          id TEXT PRIMARY KEY,
          novel_id TEXT NOT NULL,
          novel_title TEXT NOT NULL,
          author TEXT NOT NULL,
          current_chapter INTEGER DEFAULT 0,
          total_chapters INTEGER DEFAULT 0,
          last_viewed INTEGER NOT NULL,
          url TEXT NOT NULL
        )
      ''');
    }
    
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE bookmarks ADD COLUMN scroll_position REAL DEFAULT 0.0');
      } catch (e) {
        print('bookmarks テーブルにscroll_positionカラム追加失敗: $e');
      }
      
      try {
        await db.execute('ALTER TABLE reading_history ADD COLUMN scroll_position REAL DEFAULT 0.0');
      } catch (e) {
        print('reading_history テーブルにscroll_positionカラム追加失敗: $e');
      }
    }

    // Add is_serial_novel column in version 4
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE bookmarks ADD COLUMN is_serial_novel INTEGER DEFAULT 0');
      } catch (e) {
        print('bookmarks テーブルにis_serial_novelカラム追加失敗: $e');
      }
      
      try {
        await db.execute('ALTER TABLE reading_history ADD COLUMN is_serial_novel INTEGER DEFAULT 0');
      } catch (e) {
        print('reading_history テーブルにis_serial_novelカラム追加失敗: $e');
      }
    }
  }

  // Novel operations
  Future<int> insertNovel(Novel novel) async {
    final db = await database;
    return await db.insert('novels', novel.toMap());
  }

  Future<List<Novel>> getNovels() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('novels');
    return List.generate(maps.length, (i) => Novel.fromMap(maps[i]));
  }

  Future<int> updateNovel(Novel novel) async {
    final db = await database;
    return await db.update(
      'novels',
      novel.toMap(),
      where: 'id = ?',
      whereArgs: [novel.id],
    );
  }

  Future<int> deleteNovel(String id) async {
    final db = await database;
    return await db.delete('novels', where: 'id = ?', whereArgs: [id]);
  }

  // Bookmark operations
  Future<int> insertBookmark(Bookmark bookmark) async {
    final db = await database;
    return await db.insert('bookmarks', bookmark.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Bookmark>> getBookmarks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bookmarks',
      orderBy: 'last_viewed DESC',
    );
    return List.generate(maps.length, (i) => Bookmark.fromMap(maps[i]));
  }

  Future<Bookmark?> getBookmarkByNovelId(String novelId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bookmarks',
      where: 'novel_id = ?',
      whereArgs: [novelId],
    );
    
    if (maps.isNotEmpty) {
      return Bookmark.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateBookmark(Bookmark bookmark) async {
    final db = await database;
    return await db.update(
      'bookmarks',
      bookmark.toMap(),
      where: 'novel_id = ?',
      whereArgs: [bookmark.novelId],
    );
  }

  Future<int> deleteBookmark(String novelId) async {
    final db = await database;
    return await db.delete('bookmarks', where: 'novel_id = ?', whereArgs: [novelId]);
  }

  Future<bool> isBookmarked(String novelId) async {
    final db = await database;
    final result = await db.query(
      'bookmarks',
      where: 'novel_id = ?',
      whereArgs: [novelId],
    );
    return result.isNotEmpty;
  }

  // Reading history operations
  Future<int> insertReadingHistory(ReadingHistory history) async {
    final db = await database;
    return await db.insert('reading_history', history.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ReadingHistory>> getReadingHistory() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reading_history',
      orderBy: 'last_viewed DESC',
      limit: 100,
    );
    return List.generate(maps.length, (i) => ReadingHistory.fromMap(maps[i]));
  }

  Future<List<ReadingHistory>> getAllReadingHistory() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reading_history',
      orderBy: 'last_viewed DESC',
    );
    return List.generate(maps.length, (i) => ReadingHistory.fromMap(maps[i]));
  }

  Future<ReadingHistory?> getReadingHistoryByNovelId(String novelId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reading_history',
      where: 'novel_id = ?',
      whereArgs: [novelId],
    );
    
    if (maps.isNotEmpty) {
      return ReadingHistory.fromMap(maps.first);
    }
    return null;
  }

  /// 読書履歴を更新（章番号のみ）- 0章対応版
  Future<int> updateReadingHistory(String novelId, int currentChapter) async {
    final db = await database;
    return await db.update(
      'reading_history',
      {
        'current_chapter': currentChapter,
        'last_viewed': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'novel_id = ?',
      whereArgs: [novelId],
    );
  }

  /// 読書履歴を更新（ReadingHistoryオブジェクト全体）
  Future<int> updateReadingHistoryFull(ReadingHistory history) async {
    final db = await database;
    return await db.update(
      'reading_history',
      history.toMap(),
      where: 'novel_id = ?',
      whereArgs: [history.novelId],
    );
  }

  /// 読書履歴を削除
  Future<int> deleteReadingHistory(String novelId) async {
    final db = await database;
    return await db.delete(
      'reading_history',
      where: 'novel_id = ?',
      whereArgs: [novelId],
    );
  }

  /// 読書位置の更新（章番号0対応版）
  Future<int> updateReadingPosition(String novelId, int currentChapter, double scrollPosition) async {
    final db = await database;
    return await db.update(
      'reading_history',
      {
        'current_chapter': currentChapter,
        'scroll_position': scrollPosition,
        'last_viewed': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'novel_id = ?',
      whereArgs: [novelId],
    );
  }

  /// ブックマーク位置の更新（章番号0対応版）
  Future<int> updateBookmarkPosition(String novelId, int currentChapter, double scrollPosition) async {
    final db = await database;
    return await db.update(
      'bookmarks',
      {
        'current_chapter': currentChapter,
        'scroll_position': scrollPosition,
        'last_viewed': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'novel_id = ?',
      whereArgs: [novelId],
    );
  }

  /// 読書履歴一覧取得（表示用の章番号テキスト付き）
  Future<List<Map<String, dynamic>>> getReadingHistoryWithChapterText() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reading_history',
      orderBy: 'last_viewed DESC',
    );

    return maps.map((map) {
      final currentChapter = map['current_chapter'] as int;
      final isSerialNovel = currentChapter > 0;
      final chapterText = isSerialNovel 
          ? '第${currentChapter}章'
          : '目次/短編';
      
      return {
        ...map,
        'chapter_text': chapterText,
        'is_serial_novel': isSerialNovel,
      };
    }).toList();
  }

  /// ブックマーク一覧取得（表示用の章番号テキスト付き）
  Future<List<Map<String, dynamic>>> getBookmarksWithChapterText() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bookmarks',
      orderBy: 'added_at DESC',
    );

    return maps.map((map) {
      final currentChapter = map['current_chapter'] as int;
      final isSerialNovel = currentChapter > 0;
      final chapterText = isSerialNovel 
          ? '第${currentChapter}章'
          : '目次/短編';
      
      return {
        ...map,
        'chapter_text': chapterText,
        'is_serial_novel': isSerialNovel,
      };
    }).toList();
  }

  /// 小説種別を判定するヘルパーメソッド
  bool isSerialNovelFromUrl(String url) {
    final serialRegex = RegExp(r'https://ncode\.syosetu\.com/([^/]+)/([0-9]+)/?');
    return serialRegex.hasMatch(url);
  }

  /// URLから章番号を抽出
  int extractChapterFromUrl(String url) {
    if (!isSerialNovelFromUrl(url)) return 0;

    final regex = RegExp(r'https://ncode\.syosetu\.com/([^/]+)/([0-9]+)/?');
    final match = regex.firstMatch(url);
    
    if (match != null) {
      return int.tryParse(match.group(2)!) ?? 0;
    }
    return 0;
  }

  /// 適切なURLを構築
  String buildNovelUrl(String novelId, int chapter) {
    final baseUrl = 'https://ncode.syosetu.com/${novelId.toLowerCase()}/';
    
    if (chapter > 0) {
      return '${baseUrl}$chapter/';
    } else {
      return baseUrl; // 目次または短編の場合
    }
  }

  /// ブックマーク情報を更新（API情報用）
  Future<void> updateBookmarkInfo(String novelId, String title, String author) async {
    final db = await database;
    await db.update(
      'bookmarks',
      {
        'novel_title': title,
        'author': author,
        'last_viewed': DateTime.now().millisecondsSinceEpoch,
        'is_serial_novel': isSerialNovelFromUrl(novelId) ? 1 : 0,
      },
      where: 'novel_id = ?',
      whereArgs: [novelId],
    );
  }
  
  /// 読書履歴情報を更新（API情報用）
  Future<void> updateReadingHistoryInfo(String novelId, String title, String author, int totalChapters) async {
    final db = await database;
    await db.update(
      'reading_history',
      {
        'novel_title': title,
        'author': author,
        'total_chapters': totalChapters,
        'last_viewed': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'novel_id = ?',
      whereArgs: [novelId],
    );
  }
  
  /// ブックマークの小説種別を更新
  Future<void> updateBookmarkSerialType(String novelId, bool isSerialNovel) async {
    final db = await database;
    await db.update(
      'bookmarks',
      {
        'is_serial_novel': isSerialNovel ? 1 : 0,
      },
      where: 'novel_id = ?',
      whereArgs: [novelId],
    );
  }

  /// 古い履歴を削除（指定した件数を超える古い履歴を削除）
  Future<void> cleanOldHistory({int keepCount = 20}) async {
    final db = await database;
    
    await db.delete(
      'reading_history',
      where: 'id NOT IN (SELECT id FROM reading_history ORDER BY last_viewed DESC LIMIT ?)',
      whereArgs: [keepCount],
    );
  }

  /// データベースの統計情報を取得
  Future<Map<String, int>> getDatabaseStats() async {
    final db = await database;
    
    final novelCount = await db.rawQuery('SELECT COUNT(*) as count FROM novels');
    final bookmarkCount = await db.rawQuery('SELECT COUNT(*) as count FROM bookmarks');
    final historyCount = await db.rawQuery('SELECT COUNT(*) as count FROM reading_history');
    
    return {
      'novels': novelCount.first['count'] as int,
      'bookmarks': bookmarkCount.first['count'] as int,
      'history': historyCount.first['count'] as int,
    };
  }

  /// データベースを閉じる
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}