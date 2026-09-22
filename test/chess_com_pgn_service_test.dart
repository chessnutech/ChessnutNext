import 'package:chessnut_flutter_export/services/chess_com_pgn_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  String pgnGame(String event, String date) => '[Event "$event"]\n'
      '[UTCDate "$date"]\n'
      '[White "White $event"]\n'
      '[Black "Black $event"]\n'
      '[Result "1-0"]\n\n'
      '1. e4 e5 1-0';

  test('loads Chess.com archives newest month first and stops at the limit',
      () async {
    final requested = <Uri>[];
    final service = ChessComPgnService(
      httpClient: MockClient((request) async {
        requested.add(request.url);
        if (request.url.path.endsWith('/games/archives')) {
          return http.Response(
            '{"archives":['
            '"https://api.chess.com/pub/player/player%20one/games/2026/06",'
            '"https://api.chess.com/pub/player/player%20one/games/2026/07"'
            ']}',
            200,
          );
        }
        if (request.url.path.endsWith('/2026/07/pgn')) {
          return http.Response(
            [pgnGame('july-1', '2026.07.30'), pgnGame('july-2', '2026.07.01')]
                .join('\n\n'),
            200,
          );
        }
        return http.Response(pgnGame('june-1', '2026.06.20'), 200);
      }),
    );

    final result = await service.fetchGames(
      options: const ChessComPgnFetchOptions(
        username: 'player one',
        since: '2026-06-01',
        until: '2026-07-31',
      ),
      maxGames: 3,
    );

    expect(requested.map((uri) => uri.path), [
      '/pub/player/player%20one/games/archives',
      '/pub/player/player%20one/games/2026/07/pgn',
      '/pub/player/player%20one/games/2026/06/pgn',
    ]);
    expect(result.games, hasLength(3));
    expect(result.games.first, contains('july-1'));
  });

  test('ignores missing monthly archives', () async {
    final service = ChessComPgnService(
      httpClient: MockClient((_) async => http.Response('', 404)),
    );
    final result = await service.fetchGames(
      options: const ChessComPgnFetchOptions(
        username: 'player',
        since: '2026-01-01',
        until: '2026-01-31',
      ),
    );
    expect(result.games, isEmpty);
  });
}
