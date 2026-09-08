import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:syosetsu/models/bookmark.dart';
import 'package:syosetsu/models/reading_history.dart';
import 'package:syosetsu/services/database_helper.dart';
import 'package:syosetsu/viewmodels/bookmark_viewmodel.dart';
import 'package:syosetsu/viewmodels/history_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late DatabaseHelper database;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('syosetsu-storage-test-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(BookmarkAdapter());
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ReadingHistoryAdapter());
    }
    await Hive.openBox<Bookmark>(DatabaseHelper.bookmarkBoxName);
    await Hive.openBox<ReadingHistory>(DatabaseHelper.historyBoxName);
    database = DatabaseHelper();
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  ReadingHistory history(String id,
          {int chapter = 2,
          int total = 5,
          bool r18 = false,
          DateTime? viewed}) =>
      ReadingHistory(
        id: id,
        novelId: id,
        novelTitle: '旧タイトル $id',
        author: '作者',
        currentChapter: chapter,
        totalChapters: total,
        lastViewed: viewed ?? DateTime(2025, 1, 1),
        url: database.buildNovelUrl(id, chapter, r18: r18),
        scrollPosition: 120,
        isSerialNovel: true,
      );

  Bookmark bookmark(String id) => Bookmark(
        id: id,
        novelId: id,
        novelTitle: '旧タイトル $id',
        author: '作者',
        currentChapter: 2,
        addedAt: DateTime(2024),
        lastViewed: DateTime(2025, 1, 1),
        isSerialNovel: true,
      );

  http.Response details(String id, {int total = 8, int type = 1}) =>
      http.Response.bytes(
          utf8.encode(jsonEncode([
            {'allcount': 1},
            {
              'ncode': id.toUpperCase(),
              'title': '新タイトル $id',
              'writer': '作者',
              'general_all_no': total,
              'novel_type': type,
              'general_lastup': '2026-09-01 12:00:00',
            },
          ])),
          200);

  test('metadata updates preserve reading order and saved progress', () async {
    final item = history('n1234ab');
    final saved = bookmark('n1234ab');
    await database.insertReadingHistory(item);
    await database.insertBookmark(saved);
    final lastViewed = item.lastViewed;
    await database.updateReadingHistoryInfo(
      'N1234AB',
      '更新タイトル',
      '別の作者',
      9,
      isSerialNovel: true,
      lastUpdate: DateTime(2026, 9, 1),
    );
    await database.updateBookmarkInfo('N1234AB', '更新タイトル', '別の作者');
    await database.updateBookmarkSerialType('N1234AB', false);

    expect(item.lastViewed, lastViewed);
    expect(saved.lastViewed, lastViewed);
    expect(item.currentChapter, 2);
    expect(item.scrollPosition, 120);
    expect(item.lastUpdate, DateTime(2026, 9, 1));
  });

  test('position updates keep the R18 resume URL aligned with the chapter',
      () async {
    await database.insertReadingHistory(history('n1234ab', r18: true));
    await database.updateReadingPosition('N1234AB', 4, 320);
    var item = (await database.getReadingHistoryByNovelId('n1234ab'))!;
    expect(item.url, 'https://novel18.syosetu.com/n1234ab/4/');
    expect(item.scrollPosition, 320);
    await database.updateReadingHistory('n1234ab', 0);
    item = (await database.getReadingHistoryByNovelId('n1234ab'))!;
    expect(item.url, 'https://novel18.syosetu.com/n1234ab/');
  });

  test('history limits display without deleting until explicit cleanup',
      () async {
    for (var index = 104; index >= 0; index--) {
      await database.insertReadingHistory(history('n${index}ab',
          viewed: DateTime(2025, 1, 1).add(Duration(minutes: index))));
    }
    expect(await database.getAllReadingHistory(), hasLength(105));
    final items = await database.getReadingHistory();
    expect(items, hasLength(100));
    expect(items.first.novelId, 'n104ab');
    expect(items.last.novelId, 'n5ab');
    final model = HistoryViewModel();
    addTearDown(model.dispose);
    await model.loadHistory();
    expect(model.history, hasLength(100));
    expect(await database.getAllReadingHistory(), hasLength(105));
    await database.cleanOldHistory(keepCount: 100);
    await expectLater(
        database.cleanOldHistory(keepCount: -1), throwsArgumentError);
    expect(await database.getAllReadingHistory(), hasLength(100));
  });

  test('refresh processes each history once and corrects serial metadata',
      () async {
    final requests = <String>[];
    for (var index = 0; index < 3; index++) {
      final item = history('n${index}ab',
          viewed: DateTime(2025, 1, 1).add(Duration(days: index)));
      item.isSerialNovel = false;
      await database.insertReadingHistory(item);
    }
    final before = await database.getAllReadingHistory();
    final dates = {for (final item in before) item.novelId: item.lastViewed};
    final client = MockClient((request) async {
      final id = request.url.queryParameters['ncode']!;
      requests.add(id);
      return details(id);
    });
    final model = HistoryViewModel(client: client);
    addTearDown(model.dispose);
    addTearDown(client.close);
    await model.loadHistory();
    expect(await model.refreshFromApi(), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(requests, ['n2ab', 'n1ab', 'n0ab']);
    expect(model.history.map((item) => item.novelId), requests);
    for (final item in model.history) {
      expect(item.lastViewed, dates[item.novelId]);
      expect(item.isSerialNovel, isTrue);
      expect(item.novelTitle, '新タイトル ${item.novelId}');
      expect(item.unreadChapters, 6);
    }
  });

  test(
      'overlapping refresh is rejected and deletion during fetch stays deleted',
      () async {
    await database.insertReadingHistory(history('n1234ab'));
    final response = Completer<http.Response>();
    final requested = Completer<void>();
    var requests = 0;
    final client = MockClient((_) {
      requests++;
      requested.complete();
      return response.future;
    });
    final model = HistoryViewModel(client: client);
    addTearDown(model.dispose);
    addTearDown(client.close);
    await model.loadHistory();
    final pending = model.refreshSingleHistory('n1234ab');
    await requested.future;
    expect(await model.refreshFromApi(), isFalse);
    await database.deleteReadingHistory('n1234ab');
    response.complete(details('n1234ab'));
    expect(await pending, isFalse);
    expect(requests, 1);
    expect(await database.getAllReadingHistory(), isEmpty);
  });

  test('reading progress saved during metadata fetch is preserved', () async {
    await database.insertReadingHistory(history('n1234ab'));
    final response = Completer<http.Response>();
    final requested = Completer<void>();
    final client = MockClient((_) {
      requested.complete();
      return response.future;
    });
    final model = HistoryViewModel(client: client);
    addTearDown(model.dispose);
    addTearDown(client.close);
    await model.loadHistory();
    final pending = model.refreshSingleHistory('n1234ab');
    await requested.future;
    await database.updateReadingPosition('n1234ab', 6, 950);
    final viewed =
        (await database.getReadingHistoryByNovelId('n1234ab'))!.lastViewed;
    response.complete(details('n1234ab'));
    expect(await pending, isTrue);
    final item = (await database.getReadingHistoryByNovelId('n1234ab'))!;
    expect(item.currentChapter, 6);
    expect(item.scrollPosition, 950);
    expect(item.lastViewed, viewed);
    expect(item.totalChapters, 8);
  });

  test(
      'bookmark local reloads avoid network and observe history unread changes',
      () async {
    await database.insertBookmark(bookmark('n1234ab'));
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return details('n1234ab');
    });
    final model = BookmarkViewModel(client: client);
    addTearDown(model.dispose);
    addTearDown(client.close);
    await model.loadBookmarks();
    expect(requests, 0);
    final item = (await database.getBookmarkByNovelId('n1234ab'))!;
    item.scrollPosition = 300;
    await item.save();
    await Future<void>.delayed(Duration.zero);
    expect(requests, 0);
    await database.insertReadingHistory(history('n1234ab', total: 7));
    await Future<void>.delayed(Duration.zero);
    expect(model.getUnreadCount('n1234ab'), 5);
    await database.updateReadingPosition('n1234ab', 4, 400);
    await Future<void>.delayed(Duration.zero);
    expect(model.getUnreadCount('n1234ab'), 3);
    expect(requests, 0);
  });

  test('bookmark refresh uses R18 endpoint and updates unread totals',
      () async {
    await database.insertBookmark(bookmark('n1234ab'));
    await database.insertReadingHistory(history('n1234ab', r18: true));
    final requested = <Uri>[];
    final client = MockClient((request) async {
      requested.add(request.url);
      return details('n1234ab', total: 10);
    });
    final model = BookmarkViewModel(client: client);
    addTearDown(model.dispose);
    addTearDown(client.close);
    await model.loadBookmarks();
    expect(model.isR18Bookmark('N1234AB'), isTrue);
    expect(await model.refreshSingleBookmark('n1234ab'), isTrue);
    expect(requested.single.path, '/novel18api/api');
    expect(model.getUnreadCount('n1234ab'), 8);
    expect((await database.getReadingHistoryByNovelId('n1234ab'))!.lastViewed,
        DateTime(2025, 1, 1));
  });

  test('bookmark without history updates unread count when only total changes',
      () async {
    final saved = bookmark('n1234ab')
      ..novelTitle = '新タイトル n1234ab'
      ..lastUpdate = DateTime(2026, 9, 1, 12);
    await database.insertBookmark(saved);
    final client = MockClient((_) async => details('n1234ab', total: 11));
    final model = BookmarkViewModel(client: client);
    addTearDown(model.dispose);
    addTearDown(client.close);
    await model.loadBookmarks();
    expect(await model.refreshSingleBookmark('n1234ab'), isTrue);
    expect(model.getUnreadCount('n1234ab'), 9);
    await model.loadBookmarks();
    expect(model.getUnreadCount('n1234ab'), 9);
    expect(await database.getAllReadingHistory(), isEmpty);
    expect(saved.lastViewed, DateTime(2025, 1, 1));
  });

  test('unsuccessful API fetch reports failure rather than success', () async {
    await database.insertReadingHistory(history('n1234ab'));
    final client = MockClient((_) async => http.Response('unavailable', 503));
    final model = HistoryViewModel(client: client);
    addTearDown(model.dispose);
    addTearDown(client.close);
    await model.loadHistory();
    expect(await model.refreshFromApi(), isFalse);
    expect(model.isUpdatingFromApi, isFalse);
    expect(model.isApiUpdateOnCooldown, isFalse);
    expect(model.refreshUnavailableMessage, contains('取得できませんでした'));
  });
}
