import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:syosetsu/viewmodels/webview_viewmodel.dart';
import 'package:syosetsu/models/bookmark.dart';
import 'package:syosetsu/services/database_helper.dart';

http.Response detailsResponse(String title) => http.Response.bytes(
      utf8.encode(jsonEncode([
        {'allcount': 1},
        {'title': title, 'novel_type': 1},
      ])),
      200,
    );

class _DelayedBookmarkDatabase extends DatabaseHelper {
  final mutation = Completer<int>();
  bool bookmarked = false;

  @override
  Future<int> insertBookmark(Bookmark bookmark) => mutation.future;

  @override
  Future<int> deleteBookmark(String novelId) => mutation.future;

  @override
  Future<bool> isBookmarked(String novelId) async => bookmarked;
}

void main() {
  test('old-page bookmark add cannot override the new page status', () async {
    final database = _DelayedBookmarkDatabase();
    final vm = WebViewViewModel(database: database);
    addTearDown(vm.dispose);
    final pendingAdd = vm.addBookmark('n1234ab', 'old page');
    await vm.checkBookmarkStatus('n5678cd');
    database.mutation.complete(0);
    expect(await pendingAdd, isTrue);
    expect(vm.isBookmarked, isFalse);
  });

  test('old-page bookmark removal cannot override the new page status',
      () async {
    final database = _DelayedBookmarkDatabase()..bookmarked = true;
    final vm = WebViewViewModel(database: database);
    addTearDown(vm.dispose);
    final pendingRemove = vm.removeBookmark('n1234ab');
    await vm.checkBookmarkStatus('n5678cd');
    database.mutation.complete(0);
    expect(await pendingRemove, isTrue);
    expect(vm.isBookmarked, isTrue);
  });

  test('older details response cannot replace the active novel', () async {
    final first = Completer<http.Response>();
    final second = Completer<http.Response>();
    final vm = WebViewViewModel(client: MockClient((request) {
      return request.url.queryParameters['ncode'] == 'n1234ab'
          ? first.future
          : second.future;
    }));
    addTearDown(vm.dispose);
    final older = vm.fetchNovelDetails('n1234ab');
    final newer = vm.fetchNovelDetails('n5678cd');
    first.complete(detailsResponse('古い作品'));
    await older;
    expect(vm.novelDetails, isNull);
    expect(vm.isLoadingNovelDetails, isTrue);
    second.complete(detailsResponse('新しい作品'));
    await newer;
    expect(vm.novelDetails?['title'], '新しい作品');
    expect(vm.isLoadingNovelDetails, isFalse);
  });

  test('a cache hit remains active when a previous request finishes', () async {
    final pending = Completer<http.Response>();
    final vm = WebViewViewModel(client: MockClient((request) async {
      return request.url.queryParameters['ncode'] == 'n1234ab'
          ? detailsResponse('cached')
          : pending.future;
    }));
    addTearDown(vm.dispose);
    await vm.fetchNovelDetails('n1234ab');
    final older = vm.fetchNovelDetails('n5678cd');
    await vm.fetchNovelDetails('n1234ab');
    pending.complete(detailsResponse('old request'));
    await older;
    expect(vm.novelDetails?['title'], 'cached');
    expect(vm.isLoadingNovelDetails, isFalse);
  });

  test('concurrent chapters share a request and general/R18 caches differ',
      () async {
    var requests = 0;
    final response = Completer<http.Response>();
    final vm = WebViewViewModel(client: MockClient((request) async {
      requests++;
      if (request.url.path.contains('novel18api')) {
        return detailsResponse('adult');
      }
      return response.future;
    }));
    addTearDown(vm.dispose);
    final a =
        vm.fetchNovelDetailsFromUrl('https://ncode.syosetu.com/n1234ab/1/');
    final b =
        vm.fetchNovelDetailsFromUrl('https://ncode.syosetu.com/n1234ab/2/');
    response.complete(detailsResponse('general'));
    await Future.wait([a, b]);
    expect(requests, 1);
    await vm.fetchNovelDetails('N1234AB', r18: true);
    expect(requests, 2);
    expect(vm.novelDetails?['title'], 'adult');
  });

  test('leaving a novel or disposing ignores pending completion', () async {
    final pending = Completer<http.Response>();
    final vm = WebViewViewModel(client: MockClient((_) => pending.future));
    final request = vm.fetchNovelDetails('n1234ab');
    await vm.fetchNovelDetailsFromUrl('https://syosetu.com/');
    expect(vm.novelDetails, isNull);
    expect(vm.isLoadingNovelDetails, isFalse);
    vm.dispose();
    pending.complete(detailsResponse('late response'));
    await expectLater(request, completes);
    expect(vm.novelDetails, isNull);
  });

  test('invalid API data does not leave stale details or a loading flag',
      () async {
    var calls = 0;
    final vm = WebViewViewModel(client: MockClient((_) async {
      calls++;
      return calls == 1 ? detailsResponse('valid') : http.Response('[]', 200);
    }));
    addTearDown(vm.dispose);
    await vm.fetchNovelDetails('n1234ab');
    await vm.fetchNovelDetails('n5678cd');
    expect(vm.novelDetails, isNull);
    expect(vm.isLoadingNovelDetails, isFalse);
    expect(vm.isSerialNovel({'novel_type': '1'}), isTrue);
  });
}
