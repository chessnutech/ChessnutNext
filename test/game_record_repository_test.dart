import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/services/chessnut_api_client.dart';
import 'package:chessnut_flutter_export/services/game_record_repository.dart';
import 'package:chessnut_flutter_export/services/game_record_pgn_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads backend PGN records and resolves remote PGN content', () async {
    final requests = <http.Request>[];
    final apiClient = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST' &&
            request.url.toString() ==
                'https://api.chessnutech.com/api/getPgnList') {
          return http.Response(
            jsonEncode({
              'ret': 1,
              'code': 200,
              'info': 'ok',
              'data': {
                'total_page': 1,
                'total': 32,
                'pgnList': [
                  {
                    'id': 99,
                    's_id': 'share-abc',
                    'pgn': 'https://api.chessnutech.com/pgn/99.pgn',
                    'white_name': 'Alice',
                    'black_name': 'Bob',
                    'play_time': 1715900000,
                    'play_mode': 'lichess_rapid',
                    'win_id': 1,
                    'game_status': 2,
                    'game_step': 12,
                    'collectd': false,
                    'lichess_game_id': 'lichess-game-1',
                    'lichess_token': 'lichess-token',
                    'lichess_name': 'AliceLichess',
                  }
                ],
              },
            }),
            200,
          );
        }
        if (request.method == 'GET' &&
            request.url.toString() ==
                'https://api.chessnutech.com/pgn/99.pgn') {
          return http.Response(
            '[Event "OTB"]\n'
            '[White "Alice"]\n'
            '[Black "Bob"]\n'
            '[Result "1-0"]\n'
            '[TimeControl "5+3"]\n\n'
            '1. e4 e5 1-0',
            200,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    final result = await GameRecordRepository(apiClient: apiClient).loadRecords(
      page: 2,
      count: 20,
    );

    expect(result.isSuccess, isTrue);
    expect(result.page, 2);
    expect(result.count, 20);
    expect(result.total, 32);
    expect(result.totalPage, 1);
    expect(result.records.single.title, 'Alice vs Bob');
    expect(result.records.single.subtitle, 'Lichess Rapid / 12 moves');
    expect(result.records.single.playerSummary, 'White: Alice / Black: Bob');
    expect(result.records.single.timeSummary, 'Time: 5+3');
    expect(result.records.single.resultLabel, 'Alice wins');
    expect(result.records.single.result, '1-0');
    expect(result.records.single.pgn, contains('1. e4 e5'));
    expect(result.records.single.pgnId, 99);
    expect(result.records.single.shareId, 'share-abc');
    expect(result.records.single.playMode, 'lichess_rapid');
    expect(result.records.single.gameStatus, 2);
    expect(result.records.single.gameStep, 12);
    expect(result.records.single.winId, 1);
    expect(result.records.single.lichessGameId, 'lichess-game-1');
    expect(result.records.single.lichessToken, 'lichess-token');
    expect(result.records.single.lichessName, 'AliceLichess');
    expect(result.records.single.whiteName, 'Alice');
    expect(result.records.single.blackName, 'Bob');
    expect(
      result.records.single.sortAt,
      DateTime.fromMillisecondsSinceEpoch(1715900000 * 1000),
    );
    expect(requests.first.bodyFields['user_id'], '7');
    expect(
        requests.first.bodyFields['token'], '12345678901234567890123456789012');
    expect(requests.first.bodyFields['page'], '2');
    expect(requests.first.bodyFields['count'], '20');
    expect(requests.map((request) => request.method).toList(), ['POST', 'GET']);
  });

  test('deferred records return placeholders then download PGNs concurrently',
      () async {
    final cacheDirectory = await Directory.systemTemp.createTemp(
      'game-record-pgn-cache-',
    );
    addTearDown(() => cacheDirectory.delete(recursive: true));
    var activeDownloads = 0;
    var maxActiveDownloads = 0;
    final apiClient = ChessnutApiClient(
      session: const ChessnutApiSession(userId: 7, token: 'token'),
      httpClient: MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'code': 200,
              'info': 'ok',
              'data': {
                'total_page': 1,
                'total': 3,
                'pgnList': [
                  for (var id = 1; id <= 3; id++)
                    {
                      'id': id,
                      'pgn': 'https://records.test/$id.pgn',
                      'white_name': 'White $id',
                      'black_name': 'Black $id',
                      'play_mode': 'otb',
                      'game_status': 2,
                      'game_step': 2,
                      'win_id': 1,
                    },
                ],
              },
            }),
            200,
          );
        }
        activeDownloads++;
        maxActiveDownloads = math.max(maxActiveDownloads, activeDownloads);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        activeDownloads--;
        return http.Response('[Result "1-0"]\n\n1. e4 e5 1-0', 200);
      }),
    );
    final repository = GameRecordRepository(
      apiClient: apiClient,
      pgnCache: GameRecordPgnCache(cacheDirectory: cacheDirectory),
    );

    final result = await repository.loadRecords(deferRemotePgn: true);

    expect(result.records, hasLength(3));
    expect(result.records.every((record) => record.isPgnPending), isTrue);
    final hydrated = await Future.wait(result.hydratedRecords!);
    expect(maxActiveDownloads, greaterThan(1));
    expect(hydrated.every((record) => record.pgn.contains('1. e4')), isTrue);
  });

  test('each deferred PGN future completes independently', () async {
    final cacheDirectory = await Directory.systemTemp.createTemp(
      'game-record-independent-pgn-',
    );
    addTearDown(() => cacheDirectory.delete(recursive: true));
    final releaseSlowPgn = Completer<void>();
    final apiClient = ChessnutApiClient(
      session: const ChessnutApiSession(userId: 7, token: 'token'),
      httpClient: MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'code': 200,
              'info': 'ok',
              'data': {
                'total_page': 1,
                'total': 2,
                'pgnList': [
                  for (var id = 1; id <= 2; id++)
                    {
                      'id': id,
                      'pgn': 'https://records.test/$id.pgn',
                      'white_name': 'White $id',
                      'black_name': 'Black $id',
                      'play_mode': 'otb',
                      'game_status': 2,
                      'game_step': 2,
                      'win_id': 1,
                    },
                ],
              },
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/1.pgn')) {
          await releaseSlowPgn.future;
        }
        return http.Response(
          '[Result "1-0"]\n\n1. ${request.url.path.endsWith('/1.pgn') ? 'e4' : 'd4'} 1-0',
          200,
        );
      }),
    );
    final repository = GameRecordRepository(
      apiClient: apiClient,
      pgnCache: GameRecordPgnCache(cacheDirectory: cacheDirectory),
    );

    final result = await repository.loadRecords(deferRemotePgn: true);
    final hydrated = result.hydratedRecords!;
    final fastRecord = await hydrated[1].timeout(const Duration(seconds: 1));

    expect(fastRecord.pgnId, 2);
    expect(fastRecord.pgn, contains('1. d4'));
    releaseSlowPgn.complete();
    expect((await hydrated[0]).pgn, contains('1. e4'));
  });

  test('deferred records reuse cached PGN by pgn id', () async {
    final cacheDirectory = await Directory.systemTemp.createTemp(
      'game-record-pgn-cache-',
    );
    addTearDown(() => cacheDirectory.delete(recursive: true));
    var downloads = 0;
    final apiClient = ChessnutApiClient(
      session: const ChessnutApiSession(userId: 7, token: 'token'),
      httpClient: MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'code': 200,
              'info': 'ok',
              'data': {
                'total_page': 1,
                'total': 1,
                'pgnList': [
                  {
                    'id': 88,
                    'pgn': 'https://records.test/88.pgn',
                    'white_name': 'White',
                    'black_name': 'Black',
                    'play_mode': 'otb',
                    'game_status': 2,
                    'game_step': 2,
                    'win_id': 1,
                  },
                ],
              },
            }),
            200,
          );
        }
        downloads++;
        return http.Response('[Result "1-0"]\n\n1. e4 e5 1-0', 200);
      }),
    );
    final repository = GameRecordRepository(
      apiClient: apiClient,
      pgnCache: GameRecordPgnCache(cacheDirectory: cacheDirectory),
    );

    final first = await repository.loadRecords(deferRemotePgn: true);
    await Future.wait(first.hydratedRecords!);
    final second = await repository.loadRecords(deferRemotePgn: true);
    await Future.wait(second.hydratedRecords!);

    expect(downloads, 1);
  });

  test('saved record invalidation removes its cached PGN', () async {
    final cacheDirectory = await Directory.systemTemp.createTemp(
      'game-record-pgn-cache-invalidation-',
    );
    addTearDown(() => cacheDirectory.delete(recursive: true));
    final cache = GameRecordPgnCache(cacheDirectory: cacheDirectory);
    final repository = GameRecordRepository(
      apiClient: ChessnutApiClient(),
      pgnCache: cache,
    );

    await cache.write(90, '[Result "*"]\n\n1. e4 *');
    expect(await cache.read(90), contains('1. e4'));

    await repository.invalidateRecordPgn(90);

    expect(await cache.read(90), isNull);
  });

  test('refreshing a PGN deletes its cache and downloads it again', () async {
    final cacheDirectory = await Directory.systemTemp.createTemp(
      'game-record-pgn-cache-',
    );
    addTearDown(() => cacheDirectory.delete(recursive: true));
    var downloads = 0;
    final apiClient = ChessnutApiClient(
      session: const ChessnutApiSession(userId: 7, token: 'token'),
      httpClient: MockClient((request) async {
        downloads++;
        return http.Response(
          '[Result "1-0"]\n\n1. e4 e5 ${downloads == 1 ? '' : '2. Nf3'} 1-0',
          200,
        );
      }),
    );
    final repository = GameRecordRepository(
      apiClient: apiClient,
      pgnCache: GameRecordPgnCache(cacheDirectory: cacheDirectory),
    );
    const record = GameRecord(
      pgnId: 89,
      result: '1-0',
      title: 'White vs Black',
      subtitle: 'OTB / 2 moves',
      pgn: '',
      pgnSource: 'https://records.test/89.pgn',
      whiteName: 'White',
      blackName: 'Black',
      playMode: 'otb',
      gameStatus: 2,
      gameStep: 2,
      winId: 1,
    );

    final first = await repository.refreshRecordPgn(record);
    final refreshed = await repository.refreshRecordPgn(first.data!);

    expect(downloads, 2);
    expect(refreshed.isSuccess, isTrue);
    expect(refreshed.data!.pgn, contains('2. Nf3'));
  });

  test('propagates auth expiry instead of returning stale local records',
      () async {
    final apiClient = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'ret': 0,
            'code': 600,
            'info': 'token expired',
            'data': null,
          }),
          200,
        );
      }),
    );

    final result =
        await GameRecordRepository(apiClient: apiClient).loadRecords();

    expect(result.isSuccess, isFalse);
    expect(result.status.apiErrorCode, 600);
    expect(result.records, isEmpty);
    expect(result.page, 1);
    expect(result.count, 10);
  });

  test('resolves local backend PGN paths against the configured API host',
      () async {
    final requests = <http.Request>[];
    final apiClient = ChessnutApiClient(
      baseUri: Uri.parse('http://192.168.0.28:8888'),
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST' &&
            request.url.toString() ==
                'http://192.168.0.28:8888/api/getPgnList') {
          return http.Response(
            jsonEncode({
              'ret': 1,
              'code': 200,
              'info': 'ok',
              'data': {
                'total_page': 1,
                'pgnList': [
                  {
                    'id': 18,
                    's_id': 'offline-draft',
                    'pgn': '/static/local_pgn/7/draft.pgn',
                    'white_name': 'Chessnut Player',
                    'black_name': 'Maia 1500',
                    'play_time': 1715900000,
                    'play_mode': 'bot',
                    'win_id': 0,
                    'game_status': 1,
                    'game_step': 3,
                  },
                ],
              },
            }),
            200,
          );
        }
        if (request.method == 'GET' &&
            request.url.toString() ==
                'http://192.168.0.28:8888/static/local_pgn/7/draft.pgn') {
          return http.Response('[Result "*"]\n\n1. e4 e5 2. Nf3 *', 200);
        }
        return http.Response('not found', 404);
      }),
    );

    final result =
        await GameRecordRepository(apiClient: apiClient).loadRecords();

    expect(result.isSuccess, isTrue);
    expect(result.records.single.pgn, contains('2. Nf3'));
    expect(
      requests.last.url.toString(),
      'http://192.168.0.28:8888/static/local_pgn/7/draft.pgn',
    );
  });

  test('searches V3 game records and resolves returned PGN paths', () async {
    final requests = <http.Request>[];
    final apiClient = ChessnutApiClient(
      baseUri: Uri.parse('http://192.168.0.28:8888'),
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST' &&
            request.url.toString() ==
                'http://192.168.0.28:8888/api/v3/gameRecords/search') {
          return http.Response(
            jsonEncode({
              'ret': 1,
              'code': 200,
              'info': 'ok',
              'data': {
                'total_page': 4,
                'total': 77,
                'server_index_supported': true,
                'records': [
                  {
                    'id': 91,
                    's_id': 'search-share',
                    'pgn': '/static/local_pgn/7/search.pgn',
                    'white_name': 'Search White',
                    'black_name': 'Search Black',
                    'play_time': 1715900000,
                    'play_mode': 'lichess_blitz',
                    'win_id': 2,
                    'game_status': 2,
                    'game_step': 44,
                    'has_grandeur_report': false,
                  },
                ],
              },
            }),
            200,
          );
        }
        if (request.method == 'GET' &&
            request.url.toString() ==
                'http://192.168.0.28:8888/static/local_pgn/7/search.pgn') {
          return http.Response('[Result "0-1"]\n\n1. e4 c5 0-1', 200);
        }
        return http.Response('not found', 404);
      }),
    );

    final result = await GameRecordRepository(apiClient: apiClient)
        .searchRecords(const GameRecordSearchRequest(
      page: 2,
      count: 20,
      query: 'search',
      mode: 'lichess',
      result: 'win',
      speed: 'blitz',
      color: 'white',
      report: 'standard',
      sort: 'oldest',
    ));

    expect(result.isSuccess, isTrue);
    expect(result.page, 2);
    expect(result.count, 20);
    expect(result.total, 77);
    expect(result.totalPage, 4);
    expect(result.records.single.title, 'Search White vs Search Black');
    expect(result.records.single.subtitle, 'Lichess Blitz / 44 moves');
    expect(result.records.single.pgn, contains('1. e4 c5'));
    expect(requests.first.bodyFields['query'], 'search');
    expect(requests.first.bodyFields['mode'], 'lichess');
    expect(requests.first.bodyFields['result'], 'win');
    expect(requests.first.bodyFields['speed'], 'blitz');
    expect(requests.first.bodyFields['color'], 'white');
    expect(requests.first.bodyFields['report'], 'standard');
    expect(requests.first.bodyFields['sort'], 'oldest');
  });

  test('loads inline backend PGN without fetching an extra URL', () async {
    final requests = <http.Request>[];
    const inlinePgn = '''
[Event "Bot game room"]
[Site "Chessnut App"]
[White "Chessnut Player"]
[Black "Maia 1500"]
[Result "*"]
[TimeControl "10+5"]

1. e4 *
''';
    final apiClient = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST' &&
            request.url.toString() ==
                'https://api.chessnutech.com/api/getPgnList') {
          return http.Response(
            jsonEncode({
              'ret': 1,
              'code': 200,
              'info': 'ok',
              'data': {
                'total_page': 1,
                'pgnList': [
                  {
                    'id': 555,
                    's_id': 'resume-inline',
                    'pgn': inlinePgn,
                    'white_name': 'Chessnut Player',
                    'black_name': 'Maia 1500',
                    'play_time': 1715900000,
                    'play_mode': 'bot',
                    'win_id': 0,
                    'game_status': 1,
                    'game_step': 1,
                  },
                ],
              },
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    final result =
        await GameRecordRepository(apiClient: apiClient).loadRecords();

    expect(result.isSuccess, isTrue);
    expect(result.records.single.pgn, inlinePgn.trim());
    expect(result.records.single.canContinueBotGame, isTrue);
    expect(requests.map((request) => request.method).toList(), ['POST']);
  });

  test('derives exact total from last page when backend omits total', () async {
    final requests = <http.Request>[];
    final apiClient = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST' &&
            request.url.toString() ==
                'https://api.chessnutech.com/api/getPgnList') {
          final page = request.bodyFields['page'];
          return http.Response(
            jsonEncode({
              'ret': 1,
              'code': 200,
              'info': 'ok',
              'data': {
                'total_page': 3,
                'pgnList': [
                  for (final id in page == '3' ? [21, 22, 23] : [1, 2, 3])
                    {
                      'id': id,
                      'pgn': '[White "White $id"]\n'
                          '[Black "Black $id"]\n'
                          '[Result "1-0"]\n\n'
                          '1. e4 e5 1-0',
                      'white_name': 'White $id',
                      'black_name': 'Black $id',
                      'play_mode': 'bot',
                      'win_id': 1,
                      'game_status': 2,
                      'game_step': 2,
                    },
                ],
              },
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    final result = await GameRecordRepository(apiClient: apiClient).loadRecords(
      page: 1,
      count: 10,
    );

    expect(result.isSuccess, isTrue);
    expect(result.total, 23);
    expect(result.totalPage, 3);
    expect(
      requests
          .where((request) => request.url.path == '/api/getPgnList')
          .map((request) => request.bodyFields['page'])
          .toList(),
      ['1', '3'],
    );
  });

  test('loads base64 backend PGN without fetching an extra URL', () async {
    final requests = <http.Request>[];
    const rawPgn = '''
[Event "Bot game room"]
[Site "Chessnut App"]
[White "Chessnut Player"]
[Black "Maia 1500"]
[Result "*"]
[TimeControl "10+5"]

1. e4 e5 2. Nf3 *
''';
    final encodedPgn = base64Encode(utf8.encode(rawPgn));
    final apiClient = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST' &&
            request.url.toString() ==
                'https://api.chessnutech.com/api/getPgnList') {
          return http.Response(
            jsonEncode({
              'ret': 1,
              'code': 200,
              'info': 'ok',
              'data': {
                'total_page': 1,
                'pgnList': [
                  {
                    'id': 556,
                    's_id': 'resume-base64',
                    'pgn': encodedPgn,
                    'white_name': 'Chessnut Player',
                    'black_name': 'Maia 1500',
                    'play_time': 1715900000,
                    'play_mode': 'bot',
                    'win_id': 0,
                    'game_status': 1,
                    'game_step': 3,
                  },
                ],
              },
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    final result =
        await GameRecordRepository(apiClient: apiClient).loadRecords();

    expect(result.isSuccess, isTrue);
    expect(result.records.single.pgn, rawPgn.trim());
    expect(result.records.single.canContinueBotGame, isTrue);
    expect(requests.map((request) => request.method).toList(), ['POST']);
  });

  test('ends an unfinished backend record as a completed draw', () async {
    final requests = <http.Request>[];
    final apiClient = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST' &&
            request.url.toString() ==
                'https://api.chessnutech.com/api/updatePgn') {
          return http.Response(
            jsonEncode({'ret': 1, 'code': 200, 'info': 'ok', 'data': {}}),
            200,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    final result = await GameRecordRepository(apiClient: apiClient).endRecord(
      const GameRecord(
        pgnId: 556,
        result: '*',
        title: 'Chessnut Player vs Maia 1500',
        subtitle: 'Bot / 3 moves',
        pgn: '[White "Chessnut Player"]\n'
            '[Black "Maia 1500"]\n'
            '[Result "*"]\n\n'
            '1. e4 e5 2. Nf3 *',
        playMode: 'bot',
        gameStatus: 1,
        gameStep: 3,
      ),
    );

    expect(result.isSuccess, isTrue);
    final request = requests.single;
    expect(request.url.path, '/api/updatePgn');
    expect(request.bodyFields['pgn_id'], '556');
    expect(request.bodyFields['win_id'], '3');
    expect(request.bodyFields['game_status'], '2');
    expect(request.bodyFields['pgn'], contains('[Result "1/2-1/2"]'));
    expect(request.bodyFields['pgn'], contains('2. Nf3 1/2-1/2'));
  });

  test('keeps every record returned by the backend without deduplicating',
      () async {
    const gamePgn = '[Event "Lichess game"]\n'
        '[White "xlhkkk"]\n'
        '[Black "kniem2018"]\n'
        '[Result "1-0"]\n'
        '[LichessGameId "lichess-duplicate-1"]\n\n'
        '1. e4 e5 2. Nf3 Nc6 1-0';
    final apiClient = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'ret': 1,
            'code': 200,
            'info': 'ok',
            'data': {
              'total_page': 1,
              'total': 2,
              'pgnList': [
                {
                  'id': 701,
                  'pgn': gamePgn,
                  'white_name': 'xlhkkk',
                  'black_name': 'kniem2018',
                  'play_time': 1715900000,
                  'play_mode': 'lichess_blitz',
                  'win_id': 1,
                  'game_status': 2,
                  'game_step': 4,
                  'lichess_game_id': 'lichess-duplicate-1',
                },
                {
                  'id': 702,
                  'pgn': gamePgn,
                  'white_name': 'xlhkkk',
                  'black_name': 'kniem2018',
                  'play_time': 1715900100,
                  'play_mode': 'analysis',
                  'win_id': 1,
                  'game_status': 2,
                  'game_step': 4,
                  'lichess_game_id': 'lichess-duplicate-1',
                },
              ],
            },
          }),
          200,
        );
      }),
    );

    final result = await GameRecordRepository(apiClient: apiClient)
        .loadRecords(page: 1, count: 20);

    expect(result.isSuccess, isTrue);
    expect(result.records, hasLength(2));
    expect(result.records.map((record) => record.pgnId), [701, 702]);
    expect(result.records.map((record) => record.playMode), [
      'lichess_blitz',
      'analysis',
    ]);
  });

  test('finds an existing record by normalized PGN when IDs are unavailable',
      () async {
    const storedPgn = '[Event "Stored game"]\n'
        '[White "xlhkkk"]\n'
        '[Black "kniem2018"]\n'
        '[Result "1-0"]\n\n'
        '1. e4 e5 2. Nf3 Nc6 1-0';
    const analysisPgn = '[Event "Analysis copy"]\n'
        '[White "xlhkkk"]\n'
        '[Black "kniem2018"]\n'
        '[Result "1-0"]\n\n'
        '1.e4 e5 2.Nf3 Nc6 1-0';
    final requests = <http.Request>[];
    final apiClient = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/getPgnList') {
          return http.Response(
            jsonEncode({
              'ret': 1,
              'code': 200,
              'info': 'ok',
              'data': {
                'total_page': 1,
                'total': 1,
                'pgnList': [
                  {
                    'id': 801,
                    'pgn': storedPgn,
                    'white_name': 'xlhkkk',
                    'black_name': 'kniem2018',
                    'play_time': 1715900000,
                    'play_mode': 'lichess_blitz',
                    'win_id': 1,
                    'game_status': 2,
                    'game_step': 4,
                  },
                ],
              },
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    final existing = await GameRecordRepository(apiClient: apiClient)
        .findExistingRecord(pgn: analysisPgn);

    expect(existing?.pgnId, 801);
    expect(requests.single.url.path, '/api/getPgnList');
  });

  test('targeted Lichess lookup does not scan the account archive on a miss',
      () async {
    const gamePgn = '[White "xlhkkk"]\n'
        '[Black "kniem2018"]\n'
        '[Result "1-0"]\n'
        '[LichessGameId "missing-lichess-game"]\n\n'
        '1. e4 e5 2. Nf3 Nc6 1-0';
    final requests = <http.Request>[];
    final apiClient = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v3/gameRecords/search') {
          return http.Response(
            jsonEncode({
              'ret': 1,
              'code': 200,
              'info': 'ok',
              'data': {
                'total_page': 1,
                'total': 0,
                'pgnList': <Object>[],
              },
            }),
            200,
          );
        }
        if (request.url.path == '/api/getPgnList') {
          return http.Response('archive scan must not run', 500);
        }
        return http.Response('not found', 404);
      }),
    );

    final existing =
        await GameRecordRepository(apiClient: apiClient).findExistingRecord(
      pgn: gamePgn,
      lichessGameId: 'missing-lichess-game',
    );

    expect(existing, isNull);
    expect(
      requests.map((request) => request.url.path),
      ['/api/v3/gameRecords/search'],
    );
  });

  test('scans past a newer analysis copy to reuse the original record',
      () async {
    const gamePgn = '[White "xlhkkk"]\n'
        '[Black "kniem2018"]\n'
        '[Result "1-0"]\n\n'
        '1. e4 e5 2. Nf3 Nc6 1-0';
    final requestedPages = <String>[];
    final apiClient = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        final page = request.bodyFields['page'] ?? '1';
        requestedPages.add(page);
        final isFirstPage = page == '1';
        return http.Response(
          jsonEncode({
            'ret': 1,
            'code': 200,
            'info': 'ok',
            'data': {
              'total_page': 2,
              'total': 101,
              'pgnList': [
                {
                  'id': isFirstPage ? 902 : 901,
                  'pgn': gamePgn,
                  'white_name': 'xlhkkk',
                  'black_name': 'kniem2018',
                  'play_time': isFirstPage ? 1715900100 : 1715900000,
                  'play_mode': isFirstPage ? 'analysis' : 'lichess_blitz',
                  'win_id': 1,
                  'game_status': 2,
                  'game_step': 4,
                },
              ],
            },
          }),
          200,
        );
      }),
    );

    final existing = await GameRecordRepository(apiClient: apiClient)
        .findExistingRecord(pgn: gamePgn);

    expect(existing?.pgnId, 901);
    expect(existing?.playMode, 'lichess_blitz');
    expect(requestedPages, ['1', '2']);
  });
}
