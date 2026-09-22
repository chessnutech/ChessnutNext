import 'package:chessnut_flutter_export/services/lichess_pgn_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  String pgnGame({
    required String event,
    required String utcDate,
    required String utcTime,
  }) {
    return '[Event "$event"]\n'
        '[Site "https://lichess.org/$event"]\n'
        '[Date "$utcDate"]\n'
        '[UTCDate "$utcDate"]\n'
        '[UTCTime "$utcTime"]\n'
        '[White "storm123"]\n'
        '[Black "opponent"]\n\n'
        '1. e4 e5 *';
  }

  test('builds Lichess games URL from model build options', () {
    final service = LichessPgnService(
      httpClient: MockClient((_) async => http.Response('', 200)),
    );

    final uri = service.buildGamesUri(
      options: const LichessPgnFetchOptions(
        playerId: 'storm 123',
        since: '2026-06-01',
        until: '2026.06.24',
        speed: 'rapid',
        rated: 'true',
        color: 'white',
      ),
      pageSize: 80,
    );

    expect(uri.host, 'lichess.org');
    expect(uri.path, '/api/games/user/storm%20123');
    expect(uri.queryParameters['max'], '80');
    expect(uri.queryParameters['pgnInJson'], 'false');
    expect(uri.queryParameters['clocks'], 'false');
    expect(uri.queryParameters['evals'], 'false');
    expect(uri.queryParameters['opening'], 'true');
    expect(uri.queryParameters['tags'], 'true');
    expect(
      uri.queryParameters['since'],
      DateTime.utc(2026, 6, 1).millisecondsSinceEpoch.toString(),
    );
    expect(
      uri.queryParameters['until'],
      DateTime.utc(2026, 6, 24).millisecondsSinceEpoch.toString(),
    );
    expect(uri.queryParameters['perfType'], 'rapid');
    expect(uri.queryParameters['rated'], 'true');
    expect(uri.queryParameters['color'], 'white');
  });

  test('fetches PGN and calculates next until cursor from oldest game',
      () async {
    late http.Request captured;
    final pgn = [
      pgnGame(
        event: 'newer',
        utcDate: '2026.06.24',
        utcTime: '12:00:00',
      ),
      pgnGame(
        event: 'older',
        utcDate: '2026.06.20',
        utcTime: '09:30:00',
      ),
    ].join('\n\n\n');
    final service = LichessPgnService(
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(pgn, 200);
      }),
    );

    final page = await service.fetchGames(
      options: const LichessPgnFetchOptions(playerId: 'storm123'),
      pageSize: 2,
    );

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/games/user/storm123');
    expect(captured.headers['Accept'], 'application/x-chess-pgn');
    expect(page.pgn, pgn);
    expect(page.hasMore, isTrue);
    expect(
      page.nextUntil,
      DateTime.utc(2026, 6, 20, 9, 30).millisecondsSinceEpoch - 1,
    );
  });

  test('uses until cursor for next page requests', () {
    final service = LichessPgnService(
      httpClient: MockClient((_) async => http.Response('', 200)),
    );

    final uri = service.buildGamesUri(
      options: const LichessPgnFetchOptions(
        playerId: 'storm123',
        until: '2026-06-24',
      ),
      pageSize: 20,
      untilCursor: 1782000000123,
    );

    expect(uri.queryParameters['until'], '1782000000123');
  });

  test('splits PGN games and rejects unparseable date filters', () {
    final pgn = [
      pgnGame(event: 'one', utcDate: '2026.06.24', utcTime: '12:00:00'),
      pgnGame(event: 'two', utcDate: '2026.06.23', utcTime: '12:00:00'),
      pgnGame(event: 'three', utcDate: '2026.06.22', utcTime: '12:00:00'),
    ].join('\n\n\n');
    final service = LichessPgnService(
      httpClient: MockClient((_) async => http.Response('', 200)),
    );

    expect(splitPgnGames(pgn, limit: 2), hasLength(2));
    expect(
      () => service.buildGamesUri(
        options: const LichessPgnFetchOptions(
          playerId: 'storm123',
          since: 'last month',
        ),
      ),
      throwsA(isA<LichessPgnException>()),
    );
  });
}
