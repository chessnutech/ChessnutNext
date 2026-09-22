import 'dart:async';
import 'dart:convert';

import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/screens/game_room_screen.dart';
import 'package:chessnut_flutter_export/services/chessnut_api_client.dart';
import 'package:chessnut_flutter_export/theme/chessnut_theme.dart';
import 'package:chessnut_flutter_export/widgets/chess_board.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('Lichess move keeps one game stream and sends one move request',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = _OpenLichessGameClient();
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: ChessnutTheme.light(),
        home: Scaffold(
          body: GameRoomScreen(
            onNavigate: (_) {},
            mode: GameLaunchMode.lichess,
            apiClient: ChessnutApiClient(httpClient: client),
            lichessConfig: const LichessGameConfig(
              gameId: 'single-stream-game',
              token: 'lichess-token',
              lichessName: 'ChessnutPlayer',
              timeMinutes: 10,
              incrementSeconds: 5,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final board = tester.widget<InteractiveChessBoard>(
      find.byType(InteractiveChessBoard).first,
    );
    final moveState = ChessBoardState.fromFen(
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
      lastMove: const ['e2', 'e4'],
    );
    board.onMove?.call(ChessBoardMove(
      from: 'e2',
      to: 'e4',
      san: 'e4',
      fen: moveState.fen,
      state: moveState,
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(client.gameStreamRequests, 1);
    expect(client.moveRequests, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Lichess game stream reconnects only after it closes',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var streamRequests = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/board/game/stream/reconnect-game') {
        streamRequests += 1;
        return http.Response(
          jsonEncode({
            'type': 'gameFull',
            'id': 'reconnect-game',
            'initialFen': 'startpos',
            'white': {'id': 'chessnutplayer', 'name': 'ChessnutPlayer'},
            'black': {'id': 'opponent', 'name': 'Opponent'},
            'state': {'moves': '', 'status': 'started'},
          }),
          200,
        );
      }
      return http.Response('not found', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ChessnutTheme.light(),
        home: Scaffold(
          body: GameRoomScreen(
            onNavigate: (_) {},
            mode: GameLaunchMode.lichess,
            apiClient: ChessnutApiClient(httpClient: client),
            lichessConfig: const LichessGameConfig(
              gameId: 'reconnect-game',
              token: 'lichess-token',
              lichessName: 'ChessnutPlayer',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(streamRequests, 1);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(streamRequests, 2);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Lichess move panel shows server time control and rated mode',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = MockClient((request) async {
      if (request.url.path == '/api/board/game/stream/game-info') {
        return http.Response(
          jsonEncode({
            'type': 'gameFull',
            'id': 'game-info',
            'initialFen': 'startpos',
            'rated': true,
            'clock': {'initial': 180000, 'increment': 2000},
            'state': {
              'moves': '',
              'status': 'started',
              'wtime': 180000,
              'btime': 180000,
            },
          }),
          200,
        );
      }
      return http.Response('not found', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ChessnutTheme.light(),
        home: Scaffold(
          body: GameRoomScreen(
            onNavigate: (_) {},
            mode: GameLaunchMode.lichess,
            apiClient: ChessnutApiClient(httpClient: client),
            lichessConfig: const LichessGameConfig(
              gameId: 'game-info',
              token: 'lichess-token',
              timeMinutes: 10,
              incrementSeconds: 5,
              rated: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final info = find.byKey(const ValueKey('lichess-game-info'));
    expect(info, findsOneWidget);
    expect(
      find.descendant(of: info, matching: find.text('3+2')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: info, matching: find.text('Rated')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Timed Lichess room ignores a sentinel clock on every device',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = MockClient((request) async {
      if (request.url.path == '/api/board/game/stream/lichess-timed-game') {
        return http.Response(
          jsonEncode({
            'type': 'gameFull',
            'id': 'lichess-timed-game',
            'initialFen': 'startpos',
            'clock': {'initial': 600000, 'increment': 5000},
            'state': {
              'moves': 'e2e4 e7e5',
              'status': 'started',
              'wtime': 2147483647,
              'btime': 2147483647,
            },
          }),
          200,
        );
      }
      return http.Response('not found', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ChessnutTheme.light(),
        home: Scaffold(
          body: GameRoomScreen(
            onNavigate: (_) {},
            mode: GameLaunchMode.lichess,
            apiClient: ChessnutApiClient(httpClient: client),
            lichessConfig: const LichessGameConfig(
              gameId: 'lichess-timed-game',
              token: 'lichess-token',
              lichessName: 'ChessnutPlayer',
              timeMinutes: 10,
              incrementSeconds: 5,
            ),
            isChessnutClockDevice: true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('16666:39'), findsNothing);
    expect(find.text('10:00'), findsNWidgets(2));

    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Unlimited Lichess room shows elapsed time from the sentinel',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const initialMs = 2147483647;
    final client = MockClient((request) async {
      if (request.url.path == '/api/board/game/stream/lichess-unlimited-game') {
        return http.Response(
          jsonEncode({
            'type': 'gameFull',
            'id': 'lichess-unlimited-game',
            'initialFen': 'startpos',
            'clock': {'initial': initialMs, 'increment': 0},
            'white': {'id': 'chessnutplayer', 'name': 'ChessnutPlayer'},
            'black': {'id': 'opponent', 'name': 'Opponent'},
            'state': {
              'moves': 'e2e4 e7e5',
              'status': 'started',
              'wtime': initialMs - 35000,
              'btime': initialMs - 185000,
            },
          }),
          200,
        );
      }
      return http.Response('not found', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ChessnutTheme.light(),
        home: Scaffold(
          body: GameRoomScreen(
            onNavigate: (_) {},
            mode: GameLaunchMode.lichess,
            apiClient: ChessnutApiClient(httpClient: client),
            lichessConfig: const LichessGameConfig(
              gameId: 'lichess-unlimited-game',
              token: 'lichess-token',
              lichessName: 'ChessnutPlayer',
              timeMinutes: 10,
              incrementSeconds: 5,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('16666:39'), findsNothing);
    expect(find.text('Unlimited'), findsWidgets);
    expect(find.text('0:35'), findsOneWidget);
    expect(find.text('3:05'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Lichess clock sentinel is ignored when no initial clock exists',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = MockClient((request) async {
      if (request.url.path == '/api/board/game/stream/lichess-sentinel') {
        return http.Response(
          jsonEncode({
            'type': 'gameFull',
            'id': 'lichess-sentinel',
            'initialFen': 'startpos',
            'state': {
              'moves': '',
              'status': 'started',
              'wtime': 999999000,
              'btime': 999999000,
            },
          }),
          200,
        );
      }
      return http.Response('not found', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ChessnutTheme.light(),
        home: Scaffold(
          body: GameRoomScreen(
            onNavigate: (_) {},
            mode: GameLaunchMode.lichess,
            apiClient: ChessnutApiClient(httpClient: client),
            lichessConfig: const LichessGameConfig(
              gameId: 'lichess-sentinel',
              token: 'lichess-token',
              timeMinutes: 0,
              incrementSeconds: 0,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('16666:39'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _OpenLichessGameClient extends http.BaseClient {
  final StreamController<List<int>> _gameStream = StreamController();
  int gameStreamRequests = 0;
  int moveRequests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path == '/api/board/game/stream/single-stream-game') {
      gameStreamRequests += 1;
      if (gameStreamRequests == 1) {
        _gameStream.add(utf8.encode('${jsonEncode({
              'type': 'gameFull',
              'id': 'single-stream-game',
              'initialFen': 'startpos',
              'clock': {'initial': 600000, 'increment': 5000},
              'white': {
                'id': 'chessnutplayer',
                'name': 'ChessnutPlayer',
              },
              'black': {'id': 'opponent', 'name': 'Opponent'},
              'state': {
                'moves': '',
                'status': 'started',
                'wtime': 600000,
                'btime': 600000,
              },
            })}\n'));
      }
      return http.StreamedResponse(_gameStream.stream, 200);
    }
    if (request.method == 'POST' &&
        request.url.path == '/api/board/game/single-stream-game/move/e2e4') {
      moveRequests += 1;
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"ok":true}')),
        200,
      );
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode('not found')),
      404,
    );
  }

  @override
  void close() {
    unawaited(_gameStream.close());
  }
}
