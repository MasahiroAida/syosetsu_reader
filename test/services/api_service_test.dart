import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:syosetsu/services/api_service.dart';

http.Response jsonResponse(Object data) =>
    http.Response.bytes(utf8.encode(jsonEncode(data)), 200);

Map<String, dynamic> detail(String ncode, {int genre = 101}) => {
      'ncode': ncode,
      'title': '日本語の小説 $ncode',
      'writer': '作者',
      'genre': genre,
      'noveltype': 2,
      'end': 0,
      'length': 3000,
      'general_all_no': 1,
    };

void main() {
  setUp(ApiService.clearCache);
  tearDown(ApiService.clearCache);

  test('default service instances share cache and explicit clearing reloads it',
      () async {
    var requests = 0;
    await http.runWithClient(() async {
      await ApiService().getRanking();
      await ApiService().getRanking();
      expect(requests, 1);
      ApiService.clearCache();
      await ApiService().getRanking();
      expect(requests, 2);
    },
        () => MockClient((_) async {
              requests++;
              return jsonResponse([]);
            }));
  });

  test('clearing cache prevents an older pending request from restoring it',
      () async {
    var requests = 0;
    final firstResponse = Completer<http.Response>();
    await http.runWithClient(() async {
      final pending = ApiService().getRanking();
      ApiService.clearCache();
      firstResponse.complete(jsonResponse([]));
      await pending;
      await ApiService().getRanking();
      expect(requests, 2);
    },
        () => MockClient((_) async {
              requests++;
              if (requests == 1) return firstResponse.future;
              return jsonResponse([]);
            }));
  });

  test(
      'ranking includes rank one and joins details regardless of case or order',
      () async {
    final requests = <Uri>[];
    final service = ApiService(client: MockClient((request) async {
      requests.add(request.url);
      if (request.url.path.contains('rankget')) {
        return jsonResponse([
          {'ncode': 'n0001a', 'rank': 1, 'pt': 50},
          {'ncode': 'N0002A', 'rank': 2, 'pt': 30},
          {'ncode': 'N0003A', 'rank': 3, 'pt': 10},
        ]);
      }
      return jsonResponse([
        {'allcount': 2},
        detail('n0003a', genre: 201),
        detail('N0001A'),
      ]);
    }));

    final novels = await service.getRanking();

    expect(novels.map((novel) => novel.rank), [1, 3]);
    expect(novels.first.title, '日本語の小説 N0001A');
    expect(novels.first.point, 50);
    expect(novels.first.novelType, 2);
    expect(requests.last.queryParameters['ncode'], 'n0001a-n0002a-n0003a');
  });

  test('genre changes reuse ranking and metadata; refresh bypasses cache',
      () async {
    var requests = 0;
    final service = ApiService(client: MockClient((request) async {
      requests++;
      return request.url.path.contains('rankget')
          ? jsonResponse([
              {'ncode': 'N0001A', 'rank': 1, 'pt': requests},
              {'ncode': 'N0002A', 'rank': 2, 'pt': requests},
            ])
          : jsonResponse([
              {'allcount': 2},
              detail('N0001A'),
              detail('N0002A', genre: 201),
            ]);
    }));

    await service.getRanking();
    final filtered = await service.getRanking(genre: 201);
    expect(filtered.single.ncode, 'N0002A');
    expect(filtered.single.rank, 2);
    expect(requests, 2);

    final refreshed = await service.getRanking(forceRefresh: true);
    expect(requests, 4);
    expect(refreshed.first.point, 3);
  });

  test('concurrent genre requests share their HTTP requests', () async {
    var requests = 0;
    final response = Completer<http.Response>();
    final service = ApiService(client: MockClient((request) async {
      requests++;
      if (request.url.path.contains('rankget')) return response.future;
      return jsonResponse([
        {'allcount': 1},
        detail('N0001A'),
      ]);
    }));
    final first = service.getRanking();
    final second = service.getRanking(genre: 101);
    response.complete(jsonResponse([
      {'ncode': 'N0001A', 'rank': 1, 'pt': 50},
    ]));

    final results = await Future.wait([first, second]);
    expect(results.every((novels) => novels.length == 1), isTrue);
    expect(requests, 2);
  });

  test('quarterly snapshot uses this month and cache expires after 30 minutes',
      () async {
    var now = DateTime.utc(2026, 9, 8, 3);
    final requests = <Uri>[];
    final service = ApiService(
      now: () => now,
      client: MockClient((request) async {
        requests.add(request.url);
        return jsonResponse([]);
      }),
    );

    await service.getRanking(rtype: 'q');
    expect(requests.single.queryParameters['rtype'], '20260901-q');
    now = now.add(const Duration(minutes: 29));
    await service.getRanking(rtype: 'q');
    expect(requests.length, 1);
    now = now.add(const Duration(minutes: 1));
    await service.getRanking(rtype: 'q');
    expect(requests.length, 2);
  });

  test('snapshot changes at the Japanese morning boundary despite fresh cache',
      () async {
    var now = DateTime.utc(2026, 8, 31, 21, 59);
    final requestedTypes = <String>[];
    final service = ApiService(
      now: () => now,
      client: MockClient((request) async {
        requestedTypes.add(request.url.queryParameters['rtype']!);
        return jsonResponse([]);
      }),
    );
    await service.getRanking(rtype: 'q');
    await service.getRanking(rtype: 'w');
    now = now.add(const Duration(minutes: 1));
    await service.getRanking(rtype: 'q');
    await service.getRanking(rtype: 'w');
    expect(requestedTypes, [
      '20260801-q',
      '20260825-w',
      '20260901-q',
      '20260901-w',
    ]);
  });

  test('failed ranking metadata is reported and can be retried immediately',
      () async {
    var failDetails = true;
    final service = ApiService(client: MockClient((request) async {
      if (request.url.path.contains('rankget')) {
        return jsonResponse([
          {'ncode': 'N0001A', 'rank': 1, 'pt': 50},
        ]);
      }
      if (failDetails) return http.Response('Unavailable', 503);
      return jsonResponse([
        {'allcount': 1},
        detail('N0001A'),
      ]);
    }));

    await expectLater(
        service.getRanking(), throwsA(isA<http.ClientException>()));
    failDetails = false;
    expect(await service.getRanking(), hasLength(1));
  });

  test('search sends selected words, element flags, exclusions and last update',
      () async {
    late Uri uri;
    final service = ApiService(client: MockClient((request) async {
      uri = request.url;
      return jsonResponse([
        {'allcount': 1},
        {
          ...detail('N0001A'),
          'story': '日本語のあらすじ',
          'general_lastup': '2026-09-08 12:00:00',
        },
      ]);
    }));
    final results = await service.searchNovels(
      word: ' 魔法 ',
      notword: ' 除外 ',
      keywords: ['学園', '異世界転生', 'R15'],
      genres: [101, 201],
      type: 'er',
      lastup: 'sevenday',
    );
    expect(uri.queryParameters['word'], '魔法 学園');
    expect(uri.queryParameters, containsPair('istensei', '1'));
    expect(uri.queryParameters, containsPair('isr15', '1'));
    expect(uri.queryParameters, isNot(contains('keyword')));
    expect(uri.queryParameters['notword'], '除外');
    expect(uri.queryParameters['genre'], '101-201');
    expect(uri.queryParameters['type'], 'er');
    expect(uri.queryParameters['lastup'], 'sevenday');
    expect(results.single.story, '日本語のあらすじ');
  });

  test('R18 search uses site categories and decodes nocgenre', () async {
    late Uri uri;
    final service = ApiService(client: MockClient((request) async {
      uri = request.url;
      return jsonResponse([
        {'allcount': 1},
        {'ncode': 'N0001A', 'title': '作品', 'nocgenre': 3},
      ]);
    }));
    final results = await service.searchNovels(r18: true, genres: [1, 3]);
    expect(uri.path, '/novel18api/api/');
    expect(uri.queryParameters['nocgenre'], '1-3');
    expect(uri.queryParameters, isNot(contains('genre')));
    expect(uri.queryParameters['of']!.split('-'), contains('ng'));
    expect(results.single.genre, 3);
  });

  for (final body in ['', 'ERROR', '{}', '[1]']) {
    test('invalid search response $body is an error, not empty results',
        () async {
      final service = ApiService(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(service.searchNovels(), throwsFormatException);
    });
  }
}
