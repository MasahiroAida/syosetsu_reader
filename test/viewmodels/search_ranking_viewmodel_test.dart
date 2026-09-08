import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:syosetsu/models/ranking_novel.dart';
import 'package:syosetsu/models/search_novel.dart';
import 'package:syosetsu/services/api_service.dart';
import 'package:syosetsu/viewmodels/ranking_viewmodel.dart';
import 'package:syosetsu/viewmodels/search_viewmodel.dart';

class SearchRequest {
  final String? word;
  final String? lastup;
  final Completer<List<SearchNovel>> response = Completer();

  SearchRequest(this.word, this.lastup);
}

class RankingRequest {
  final String type;
  final int? genre;
  final bool forceRefresh;
  final Completer<List<RankingNovel>> response = Completer();

  RankingRequest(this.type, this.genre, this.forceRefresh);
}

class ControlledApiService extends ApiService {
  final searchRequests = <SearchRequest>[];
  final rankingRequests = <RankingRequest>[];

  @override
  Future<List<SearchNovel>> searchNovels({
    String? word,
    String? notword,
    List<int>? genres,
    List<String>? keywords,
    String? type,
    String? lastup,
    String order = 'new',
    int limit = 20,
    bool r18 = false,
  }) {
    final request = SearchRequest(word, lastup);
    searchRequests.add(request);
    return request.response.future;
  }

  @override
  Future<List<RankingNovel>> getRanking({
    String rtype = 'd',
    int? genre,
    bool forceRefresh = false,
  }) {
    final request = RankingRequest(rtype, genre, forceRefresh);
    rankingRequests.add(request);
    return request.response.future;
  }
}

SearchNovel searchNovel(String title) => SearchNovel.fromMap({'title': title});
RankingNovel rankingNovel(String title) =>
    RankingNovel.fromMap({'title': title});

void main() {
  test('older search cannot overwrite a newer result', () async {
    final api = ControlledApiService();
    final model = SearchViewModel(apiService: api);
    addTearDown(model.dispose);
    final first = model.performSearch(keyword: 'old');
    final second = model.performSearch(keyword: 'new');

    api.searchRequests[1].response.complete([searchNovel('new')]);
    await second;
    api.searchRequests[0].response.complete([searchNovel('old')]);
    await first;

    expect(model.searchResults.single.title, 'new');
    expect(model.isLoading, isFalse);
    expect(model.hasSearched, isTrue);
    expect(model.errorMessage, isNull);
  });

  test('older failed search does not end a newer loading state', () async {
    final api = ControlledApiService();
    final model = SearchViewModel(apiService: api);
    addTearDown(model.dispose);
    final first = model.performSearch(keyword: 'old');
    final second = model.performSearch(keyword: 'new');
    api.searchRequests[0].response.completeError(Exception('offline'));
    await first;
    expect(model.isLoading, isTrue);
    expect(model.errorMessage, isNull);
    api.searchRequests[1].response.complete([]);
    await second;
    expect(model.isLoading, isFalse);
  });

  test('clearing search invalidates its pending result', () async {
    final api = ControlledApiService();
    final model = SearchViewModel(apiService: api);
    addTearDown(model.dispose);
    final pending = model.performSearch(keyword: 'word');
    model.clearResults();
    api.searchRequests.single.response.complete([searchNovel('late')]);
    await pending;
    expect(model.searchResults, isEmpty);
    expect(model.isLoading, isFalse);
    expect(model.hasSearched, isFalse);
  });

  test('search distinguishes empty results from failure and forwards lastup',
      () async {
    final api = ControlledApiService();
    final model = SearchViewModel(apiService: api);
    addTearDown(model.dispose);
    model.updateLastUpdate('sevenday');
    final failed = model.performSearch(keyword: 'word');
    expect(api.searchRequests.single.lastup, 'sevenday');
    api.searchRequests.single.response.completeError(Exception('offline'));
    await failed;
    expect(model.errorMessage, isNotNull);

    final empty = model.performSearch(keyword: 'word');
    api.searchRequests.last.response.complete([]);
    await empty;
    expect(model.errorMessage, isNull);
    expect(model.hasSearched, isTrue);
    expect(model.searchResults, isEmpty);
  });

  test('pending search does not notify after disposal', () async {
    final api = ControlledApiService();
    final model = SearchViewModel(apiService: api);
    var notifications = 0;
    model.addListener(() => notifications++);
    final pending = model.performSearch(keyword: 'word');
    model.dispose();
    api.searchRequests.single.response.complete([searchNovel('late')]);
    await expectLater(pending, completes);
    expect(notifications, 1);
  });

  test('all ranking periods load without waiting for the daily request',
      () async {
    final api = ControlledApiService();
    final model = RankingViewModel(apiService: api);
    addTearDown(model.dispose);
    final pending = model.loadRankings();
    expect(api.rankingRequests.map((request) => request.type),
        ['d', 'w', 'm', 'q']);
    for (final request in api.rankingRequests) {
      request.response.complete([rankingNovel(request.type)]);
    }
    await pending;
    expect(model.getRanking('q').single.title, 'q');
  });

  test('genre change supersedes every older ranking period', () async {
    final api = ControlledApiService();
    final model = RankingViewModel(apiService: api);
    addTearDown(model.dispose);
    final old = model.loadRankings();
    model.updateGenre(101);
    expect(api.rankingRequests, hasLength(8));
    for (final request in api.rankingRequests.skip(4)) {
      expect(request.genre, 101);
      request.response.complete([rankingNovel('new')]);
    }
    for (final request in api.rankingRequests.take(4)) {
      request.response.complete([rankingNovel('old')]);
    }
    await old;
    await Future<void>.delayed(Duration.zero);
    for (final type in ['d', 'w', 'm', 'q']) {
      expect(model.getRanking(type).single.title, 'new');
      expect(model.isLoading(type), isFalse);
    }
  });

  test('ranking refresh bypasses cache and reports retryable errors', () async {
    final api = ControlledApiService();
    final model = RankingViewModel(apiService: api);
    addTearDown(model.dispose);
    final pending = model.refreshRanking('d');
    expect(api.rankingRequests.single.forceRefresh, isTrue);
    api.rankingRequests.single.response.completeError(Exception('offline'));
    await pending;
    expect(model.errorMessage('d'), isNotNull);
    expect(model.isLoading('d'), isFalse);
  });

  test('pending ranking requests do not notify after disposal', () async {
    final api = ControlledApiService();
    final model = RankingViewModel(apiService: api);
    var notifications = 0;
    model.addListener(() => notifications++);
    final pending = model.loadRankingByType('d');
    model.dispose();
    api.rankingRequests.single.response.completeError(Exception('offline'));
    await expectLater(pending, completes);
    expect(notifications, 1);
  });
}
