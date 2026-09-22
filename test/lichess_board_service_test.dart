import 'dart:async';
import 'dart:convert';

import 'package:chessnut_flutter_export/services/lichess_board_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Lichess following uses the official scoped ndjson endpoint', () async {
    late http.Request captured;
    final service = LichessBoardService(
      token: 'friend-token',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          [
            jsonEncode({
              'id': 'online-friend',
              'username': 'OnlineFriend',
              'online': true,
              'title': 'NM',
              'perfs': {
                'rapid': {'rating': 1842},
              },
            }),
            jsonEncode({
              'id': 'other-friend',
              'username': 'OtherFriend',
              'perfs': {
                'blitz': {'rating': 1700},
              },
            }),
          ].join('\n'),
          200,
        );
      }),
    );

    final friends = await service.getFollowing();

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/rel/following');
    expect(captured.headers['Authorization'], 'Bearer friend-token');
    expect(friends, hasLength(2));
    expect(friends!.first.username, 'OnlineFriend');
    expect(friends.first.title, 'NM');
    expect(friends.first.ratingFor('Rapid'), 1842);
  });

  test('Lichess following preserves missing-scope status for reauthorization',
      () async {
    final service = LichessBoardService(
      token: 'old-token',
      httpClient: MockClient(
        (_) async =>
            http.Response('{"error":"Missing scope: follow:read"}', 403),
      ),
    );

    expect(await service.getFollowing(), isNull);
    expect(service.lastStatusCode, 403);
    expect(service.lastErrorMessage, 'Missing scope: follow:read');
  });

  test('Lichess direct challenge keeps alive and reports acceptance', () async {
    late http.Request captured;
    final service = LichessBoardService(
      token: 'friend-token',
      localLichessName: 'ChessnutPlayer',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          [
            jsonEncode({
              'challenge': {
                'id': 'friend-game',
                'direction': 'out',
                'status': 'created',
                'challenger': {'name': 'ChessnutPlayer'},
                'destUser': {'name': 'FriendPlayer'},
                'variant': {'key': 'standard'},
                'speed': 'rapid',
                'rated': true,
                'color': 'white',
                'timeControl': {'limit': 600, 'increment': 5},
              },
            }),
            jsonEncode({'done': 'accepted'}),
          ].join('\n'),
          200,
        );
      }),
    );

    final progress = await service
        .createChallenge(
          const LichessChallengeRequest(
            username: 'FriendPlayer',
            timeMinutes: 10,
            incrementSeconds: 5,
            rated: true,
            color: 'white',
          ),
        )
        .toList();

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/challenge/FriendPlayer');
    expect(captured.bodyFields['clock.limit'], '600');
    expect(captured.bodyFields['clock.increment'], '5');
    expect(captured.bodyFields['keepAliveStream'], 'true');
    expect(progress.map((item) => item.state), [
      LichessChallengeProgressState.created,
      LichessChallengeProgressState.accepted,
    ]);
    expect(progress.first.challenge?.id, 'friend-game');
    expect(progress.first.challenge?.opponentName, 'FriendPlayer');
  });

  test('Lichess challenge list and response commands use official endpoints',
      () async {
    final paths = <String>[];
    final service = LichessBoardService(
      token: 'friend-token',
      localLichessName: 'ChessnutPlayer',
      commandRateLimit: Duration.zero,
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path == '/api/challenge') {
          return http.Response(
            jsonEncode({
              'in': [
                {
                  'id': 'incoming-1',
                  'direction': 'in',
                  'challenger': {'name': 'FriendPlayer'},
                  'destUser': {'name': 'ChessnutPlayer'},
                  'variant': {'key': 'standard'},
                  'speed': 'blitz',
                  'rated': false,
                  'timeControl': {'limit': 300, 'increment': 3},
                },
              ],
            }),
            200,
          );
        }
        return http.Response('{"ok":true}', 200);
      }),
    );

    final challenges = await service.getChallenges();
    expect(challenges, hasLength(1));
    expect(challenges!.single.opponentName, 'FriendPlayer');
    expect(challenges.single.supportsBoardApi, isTrue);
    expect(await service.acceptChallenge('incoming-1'), isTrue);
    expect(await service.declineChallenge('incoming-1'), isTrue);
    expect(await service.cancelChallenge('incoming-1'), isTrue);
    expect(paths, [
      '/api/challenge',
      '/api/challenge/incoming-1/accept',
      '/api/challenge/incoming-1/decline',
      '/api/challenge/incoming-1/cancel',
    ]);
  });

  test('Lichess ongoing games uses the official account playing endpoint',
      () async {
    late http.Request captured;
    final service = LichessBoardService(
      token: 'lichess-token',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'nowPlaying': [
              {
                'gameId': 'game-white',
                'fullId': 'game-white-player',
                'color': 'white',
                'fen': '8/8/8/8/8/8/8/8 w - - 0 1',
                'lastMove': 'e7e5',
                'opponent': {
                  'id': 'nightbishop',
                  'username': 'NightBishop',
                  'rating': 1800,
                },
                'speed': 'blitz',
                'variant': 'standard',
                'source': 'api',
                'secondsLeft': 420,
                'hasMoved': true,
                'isMyTurn': true,
              },
              {
                'gameId': 'game-black',
                'color': 'black',
                'opponent': {'id': 'whiteplayer'},
                'speed': 'rapid',
              },
            ],
          }),
          200,
        );
      }),
    );

    final games = await service.getOngoingGames();

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/account/playing');
    expect(captured.url.queryParameters['nb'], '50');
    expect(captured.headers['Authorization'], 'Bearer lichess-token');
    expect(games, hasLength(2));
    expect(games!.first.gameId, 'game-white');
    expect(games.first.color, LichessPlayerSide.white);
    expect(games.first.opponentName, 'NightBishop');
    expect(games.first.speed, 'blitz');
    expect(games.first.secondsLeft, 420);
    expect(games.first.hasMoved, isTrue);
    expect(games.first.isMyTurn, isTrue);
    expect(games.first.supportsBoardApi, isTrue);
    expect(games.last.gameId, 'game-black');
    expect(games.last.color, LichessPlayerSide.black);
  });

  test('Lichess ongoing games returns an empty list when none are active',
      () async {
    final service = LichessBoardService(
      token: 'lichess-token',
      httpClient: MockClient(
        (_) async => http.Response('{"nowPlaying":[]}', 200),
      ),
    );

    expect(await service.getOngoingGames(), isEmpty);
    expect(service.lastErrorMessage, isNull);
  });

  test('Board API support follows official speed and source compatibility', () {
    expect(
      LichessOngoingGame.fromJson({
        'gameId': 'rapid',
        'speed': 'rapid',
        'source': 'pool',
      }).supportsBoardApi,
      isTrue,
    );
    expect(
      LichessOngoingGame.fromJson({
        'gameId': 'pool-blitz',
        'speed': 'blitz',
        'source': 'pool',
      }).supportsBoardApi,
      isFalse,
    );
    expect(
      LichessOngoingGame.fromJson({
        'gameId': 'api-blitz',
        'speed': 'blitz',
        'source': 'api',
      }).supportsBoardApi,
      isTrue,
    );
    expect(
      LichessOngoingGame.fromJson({
        'gameId': 'correspondence',
        'speed': 'correspondence',
      }).supportsBoardApi,
      isTrue,
    );
  });

  test('Lichess ongoing games preserves HTTP failure details', () async {
    final service = LichessBoardService(
      token: 'expired-token',
      httpClient: MockClient(
        (_) async => http.Response('{"error":"Invalid token"}', 401),
      ),
    );

    expect(await service.getOngoingGames(), isNull);
    expect(service.lastStatusCode, 401);
    expect(service.lastErrorMessage, 'Invalid token');
  });

  test('Lichess seek posts official Board API form fields', () async {
    late http.Request captured;
    final service = LichessBoardService(
      token: 'lichess-token',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response('\n', 200);
      }),
    );

    final result = await service.createSeek(
      const LichessSeekRequest(
        rated: true,
        timeMinutes: 10,
        incrementSeconds: 5,
        variant: 'standard',
        color: 'random',
      ),
    );

    expect(result, isTrue);
    expect(captured.method, 'POST');
    expect(captured.url.toString(), 'https://lichess.org/api/board/seek');
    expect(captured.headers['Authorization'], 'Bearer lichess-token');
    expect(captured.bodyFields, containsPair('rated', 'true'));
    expect(captured.bodyFields, containsPair('time', '10'));
    expect(captured.bodyFields, containsPair('increment', '5'));
    expect(captured.bodyFields, containsPair('variant', 'standard'));
    expect(captured.bodyFields, containsPair('color', 'random'));
  });

  test('Lichess seek accepts an open streaming response without waiting',
      () async {
    final stream = StreamController<List<int>>();
    addTearDown(stream.close);
    late http.Request captured;
    final service = LichessBoardService(
      token: 'lichess-token',
      httpClient: MockClient.streaming((request, bodyStream) async {
        captured = request as http.Request;
        return http.StreamedResponse(stream.stream, 200);
      }),
    );

    final result = await service
        .createSeek(
          const LichessSeekRequest(
            timeMinutes: 10,
            incrementSeconds: 5,
          ),
        )
        .timeout(const Duration(seconds: 1));

    expect(result, isTrue);
    expect(captured.method, 'POST');
    expect(captured.bodyFields, containsPair('time', '10'));
  });

  test('Lichess game stream parses ndjson gameFull and gameState events',
      () async {
    final service = LichessBoardService(
      token: 'lichess-token',
      httpClient: MockClient((request) async {
        expect(request.url.toString(),
            'https://lichess.org/api/board/game/stream/game123');
        return http.Response(
          [
            jsonEncode({
              'type': 'gameFull',
              'id': 'game123',
              'initialFen': 'startpos',
              'rated': true,
              'clock': {'initial': 600000, 'increment': 5000},
              'state': {
                'moves': 'e2e4 e7e5',
                'status': 'started',
                'wtime': 580000,
                'btime': 575000,
              },
            }),
            '',
            jsonEncode({
              'type': 'gameState',
              'moves': 'e2e4 e7e5 g1f3',
              'status': 'started',
            }),
          ].join('\n'),
          200,
        );
      }),
    );

    final events = await service.streamGame('game123').toList();

    expect(events, hasLength(2));
    expect(events.first.type, LichessBoardEventType.gameFull);
    expect(events.first.initialFen, LichessBoardService.startposFen);
    expect(events.first.moves, 'e2e4 e7e5');
    expect(events.first.whiteTimeMs, 580000);
    expect(events.first.blackTimeMs, 575000);
    expect(events.first.clockInitialMs, 600000);
    expect(events.first.clockIncrementMs, 5000);
    expect(events.first.rated, isTrue);
    expect(events.last.type, LichessBoardEventType.gameState);
    expect(events.last.moves, 'e2e4 e7e5 g1f3');
  });

  test('Lichess game stream parses player names and local side', () async {
    final service = LichessBoardService(
      token: 'lichess-token',
      localLichessName: 'ChessnutPlayer',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'type': 'gameFull',
            'id': 'game123',
            'initialFen': 'startpos',
            'white': {
              'id': 'chessnutplayer',
              'name': 'ChessnutPlayer',
              'rating': 1520,
            },
            'black': {
              'id': 'nightbishop',
              'name': 'nightbishop',
              'rating': 1640,
            },
            'state': {'moves': '', 'status': 'started'},
          }),
          200,
        );
      }),
    );

    final event = await service.streamGame('game123').single;

    expect(event.whiteName, 'ChessnutPlayer');
    expect(event.blackName, 'nightbishop');
    expect(event.whiteRating, 1520);
    expect(event.blackRating, 1640);
    expect(event.localSide, LichessPlayerSide.white);
    expect(event.opponentName, 'nightbishop');
  });

  test('Lichess game stream names AI opponents from aiLevel', () async {
    final service = LichessBoardService(
      token: 'lichess-token',
      localLichessName: 'ChessnutPlayer',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'type': 'gameFull',
            'id': 'game-ai',
            'initialFen': 'startpos',
            'white': {
              'id': 'chessnutplayer',
              'name': 'ChessnutPlayer',
            },
            'black': {'aiLevel': 8},
            'state': {'moves': '', 'status': 'started'},
          }),
          200,
        );
      }),
    );

    final event = await service.streamGame('game-ai').single;

    expect(event.localSide, LichessPlayerSide.white);
    expect(event.blackName, 'Lichess AI level 8');
    expect(event.opponentName, 'Lichess AI level 8');
  });

  test('Lichess game stream parses terminal winner metadata', () async {
    final service = LichessBoardService(
      token: 'lichess-token',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'type': 'gameState',
            'moves': 'e2e4 e7e5',
            'status': 'resign',
            'winner': 'white',
          }),
          200,
        );
      }),
    );

    final event = await service.streamGame('game123').single;

    expect(event.status, 'resign');
    expect(event.winner, 'white');
  });

  test('Lichess game state parses a black draw offer', () async {
    final service = LichessBoardService(
      token: 'lichess-token',
      localLichessName: 'white-player',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'type': 'gameState',
            'status': 'started',
            'bdraw': true,
          }),
          200,
        );
      }),
    );

    final event = await service.streamGame('game123').single;

    expect(event.drawOfferFrom, LichessPlayerSide.black);
  });

  test('Lichess game state parses a white draw offer from state payload',
      () async {
    final service = LichessBoardService(
      token: 'lichess-token',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'type': 'gameState',
            'state': {'wdraw': true},
          }),
          200,
        );
      }),
    );

    final event = await service.streamGame('game123').single;

    expect(event.drawOfferFrom, LichessPlayerSide.white);
  });

  test('Lichess commands build move resign draw and takeback endpoints',
      () async {
    final captured = <http.Request>[];
    final service = LichessBoardService(
      token: 'lichess-token',
      commandRateLimit: Duration.zero,
      httpClient: MockClient((request) async {
        captured.add(request);
        return http.Response('{"ok":true}', 200);
      }),
    );

    expect(await service.makeMove(gameId: 'game123', uci: 'e2e4'), isTrue);
    expect(await service.resign('game123'), isTrue);
    expect(await service.offerOrAcceptDraw(gameId: 'game123', accept: true),
        isTrue);
    expect(
      await service.offerOrAcceptTakeback(gameId: 'game123', accept: false),
      isTrue,
    );

    expect(captured.map((request) => request.url.toString()).toList(), [
      'https://lichess.org/api/board/game/game123/move/e2e4',
      'https://lichess.org/api/board/game/game123/resign',
      'https://lichess.org/api/board/game/game123/draw/yes',
      'https://lichess.org/api/board/game/game123/takeback/no',
    ]);
  });

  test('Lichess draw rejection uses the official draw/no endpoint', () async {
    late http.Request captured;
    final service = LichessBoardService(
      token: 'lichess-token',
      commandRateLimit: Duration.zero,
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response('{"ok":true}', 200);
      }),
    );

    expect(
      await service.offerOrAcceptDraw(gameId: 'game123', accept: false),
      isTrue,
    );
    expect(captured.method, 'POST');
    expect(
      captured.url.toString(),
      'https://lichess.org/api/board/game/game123/draw/no',
    );
  });

  test('Lichess commands expose rejected response reasons', () async {
    final service = LichessBoardService(
      token: 'lichess-token',
      commandRateLimit: Duration.zero,
      httpClient: MockClient((request) async {
        return http.Response('{"error":"Invalid move"}', 400,
            reasonPhrase: 'Bad Request');
      }),
    );

    final ok = await service.makeMove(gameId: 'game123', uci: 'e2e4');

    expect(ok, isFalse);
    expect(service.lastErrorMessage, 'Invalid move');
  });

  test('Lichess commands expose ok false response reasons', () async {
    final service = LichessBoardService(
      token: 'lichess-token',
      commandRateLimit: Duration.zero,
      httpClient: MockClient((request) async {
        return http.Response('{"ok":false,"error":"Too early"}', 200);
      }),
    );

    final ok = await service.makeMove(gameId: 'game123', uci: 'e2e4');

    expect(ok, isFalse);
    expect(service.lastErrorMessage, 'Too early');
  });

  test('Lichess commands share one sequential one-second rate limit', () async {
    final startedAt = <DateTime>[];
    final delayedBy = <Duration>[];
    var now = DateTime(2026, 1, 1, 12);
    var activeRequests = 0;
    var maxActiveRequests = 0;
    final responseCompleters = <Completer<void>>[];
    final service = LichessBoardService(
      token: 'lichess-token',
      commandRateLimit: const Duration(seconds: 1),
      commandClock: () => now,
      commandDelay: (duration) {
        delayedBy.add(duration);
        now = now.add(duration);
        return Future<void>.value();
      },
      httpClient: MockClient((request) async {
        startedAt.add(now);
        activeRequests += 1;
        maxActiveRequests = activeRequests > maxActiveRequests
            ? activeRequests
            : maxActiveRequests;
        final completer = Completer<void>();
        responseCompleters.add(completer);
        await completer.future;
        activeRequests -= 1;
        return http.Response('{"ok":true}', 200);
      }),
    );

    final move = service.makeMove(gameId: 'game123', uci: 'e2e4');
    final resign = service.resign('game123');
    final draw = service.offerOrAcceptDraw(gameId: 'game123', accept: true);
    final takeback =
        service.offerOrAcceptTakeback(gameId: 'game123', accept: false);

    await Future<void>.delayed(Duration.zero);
    expect(startedAt, hasLength(1));
    expect(responseCompleters, hasLength(1));

    responseCompleters.removeAt(0).complete();
    await Future<void>.delayed(Duration.zero);
    expect(startedAt, hasLength(2));

    responseCompleters.removeAt(0).complete();
    await Future<void>.delayed(Duration.zero);
    expect(startedAt, hasLength(3));

    responseCompleters.removeAt(0).complete();
    await Future<void>.delayed(Duration.zero);
    expect(startedAt, hasLength(4));

    responseCompleters.removeAt(0).complete();
    expect(await Future.wait([move, resign, draw, takeback]),
        everyElement(isTrue));

    expect(maxActiveRequests, 1);
    expect(delayedBy, [
      const Duration(seconds: 1),
      const Duration(seconds: 1),
      const Duration(seconds: 1),
    ]);
    expect(startedAt, [
      DateTime(2026, 1, 1, 12),
      DateTime(2026, 1, 1, 12, 0, 1),
      DateTime(2026, 1, 1, 12, 0, 2),
      DateTime(2026, 1, 1, 12, 0, 3),
    ]);
  });

  test('Lichess event stream exposes game start ids', () async {
    final service = LichessBoardService(
      token: 'lichess-token',
      httpClient: MockClient((request) async {
        expect(request.url.toString(), 'https://lichess.org/api/stream/event');
        return http.Response(
          [
            '',
            jsonEncode({
              'type': 'gameStart',
              'game': {'id': 'started123'},
            }),
          ].join('\n'),
          200,
        );
      }),
    );

    final events = await service.streamEvents().toList();

    expect(events.single.type, LichessBoardEventType.gameStart);
    expect(events.single.gameId, 'started123');
  });

  test('Lichess game stream exposes rejected response reasons', () async {
    final service = LichessBoardService(
      token: 'lichess-token',
      httpClient: MockClient((request) async {
        return http.Response('{"error":"Missing scope"}', 401,
            reasonPhrase: 'Unauthorized');
      }),
    );

    final events = await service.streamGame('game123').toList();

    expect(events, isEmpty);
    expect(service.lastErrorMessage, 'Missing scope');
    expect(service.lastStreamErrorMessage, 'Missing scope');
  });

  test('waitForGameStart returns the next started game id after seek',
      () async {
    final service = LichessBoardService(
      token: 'lichess-token',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/stream/event') {
          return http.Response(
            [
              jsonEncode({'type': 'challenge'}),
              jsonEncode({
                'type': 'gameStart',
                'game': {'id': 'live-game-9'},
              }),
            ].join('\n'),
            200,
          );
        }
        return http.Response('', 200);
      }),
    );

    final gameId = await service.waitForGameStart(
      timeout: const Duration(seconds: 1),
    );

    expect(gameId, 'live-game-9');
  });

  test('waitForGameStart resolves from an open streaming event response',
      () async {
    final lines = StreamController<List<int>>();
    addTearDown(lines.close);
    final service = LichessBoardService(
      token: 'lichess-token',
      httpClient: MockClient.streaming((request, bodyStream) async {
        expect(request.url.toString(), 'https://lichess.org/api/stream/event');
        Future<void>.microtask(() {
          lines.add(utf8.encode('${jsonEncode({
                'type': 'gameStart',
                'game': {'id': 'stream-started-1'},
              })}\n'));
        });
        return http.StreamedResponse(lines.stream, 200);
      }),
    );

    final gameId = await service.waitForGameStart(
      timeout: const Duration(seconds: 1),
    );

    expect(gameId, 'stream-started-1');
  });

  test('waitForGameStart skips games with a different time control', () async {
    final service = LichessBoardService(
      token: 'lichess-token',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/stream/event') {
          return http.Response(
            [
              jsonEncode({
                'type': 'gameStart',
                'game': {'id': 'unlimited-game'},
              }),
              jsonEncode({
                'type': 'gameStart',
                'game': {'id': 'requested-game'},
              }),
            ].join('\n'),
            200,
          );
        }
        if (request.url.path.endsWith('/unlimited-game')) {
          return http.Response(
            jsonEncode({
              'type': 'gameFull',
              'id': 'unlimited-game',
              'clock': {'initial': 2147483647, 'increment': 0},
              'state': {'moves': '', 'status': 'started'},
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/requested-game')) {
          return http.Response(
            jsonEncode({
              'type': 'gameFull',
              'id': 'requested-game',
              'clock': {'initial': 600000, 'increment': 5000},
              'state': {'moves': '', 'status': 'started'},
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    final gameId = await service.waitForGameStart(
      timeout: const Duration(seconds: 1),
      expectedInitialTimeMs: 600000,
      expectedIncrementMs: 5000,
    );

    expect(gameId, 'requested-game');
  });

  test('waitForGameStart accepts a sentinel clock for unlimited games',
      () async {
    final service = LichessBoardService(
      token: 'lichess-token',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/stream/event') {
          return http.Response(
            jsonEncode({
              'type': 'gameStart',
              'game': {'id': 'unlimited-game'},
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/unlimited-game')) {
          return http.Response(
            jsonEncode({
              'type': 'gameFull',
              'id': 'unlimited-game',
              'clock': {'initial': 2147483647, 'increment': 0},
              'state': {'moves': '', 'status': 'started'},
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    final gameId = await service.waitForGameStart(
      timeout: const Duration(seconds: 1),
      expectedInitialTimeMs: 0,
      expectedIncrementMs: 0,
    );

    expect(gameId, 'unlimited-game');
  });

  test('checkGame maps active and finished stream states', () async {
    final active = LichessBoardService(
      token: 'lichess-token',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'type': 'gameFull',
            'id': 'active123',
            'state': {'moves': 'e2e4', 'status': 'started'},
          }),
          200,
        );
      }),
    );
    final activeSnapshot = await active.checkGame('active123');

    expect(activeSnapshot.canContinue, isTrue);
    expect(activeSnapshot.resultToken, '*');

    final finished = LichessBoardService(
      token: 'lichess-token',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'type': 'gameState',
            'moves': 'e2e4 e7e5',
            'status': 'resign',
            'winner': 'black',
          }),
          200,
        );
      }),
    );
    final finishedSnapshot = await finished.checkGame('finished123');

    expect(finishedSnapshot.canContinue, isFalse);
    expect(finishedSnapshot.resultToken, '0-1');
  });

  test('checkGame resolves active status without waiting for stream closure',
      () async {
    final lines = StreamController<List<int>>();
    addTearDown(lines.close);
    final service = LichessBoardService(
      token: 'lichess-token',
      httpClient: MockClient.streaming((request, bodyStream) async {
        Future<void>.microtask(() {
          lines.add(utf8.encode('${jsonEncode({
                'type': 'gameFull',
                'id': 'open-active-game',
                'state': {'moves': 'e2e4', 'status': 'started'},
              })}\n'));
        });
        return http.StreamedResponse(lines.stream, 200);
      }),
    );

    final snapshot = await service
        .checkGame('open-active-game')
        .timeout(const Duration(seconds: 1));

    expect(snapshot.canContinue, isTrue);
    expect(snapshot.moves, 'e2e4');
  });
}
