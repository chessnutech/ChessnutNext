import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/services/game_notation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a playable PGN from SAN history and headers', () {
    final pgn = GameNotationService.buildPgn(
      sanMoves: const ['e4', 'e5', 'Nf3'],
      event: 'Chessnut Bot Game',
      site: 'Chessnut App',
      white: 'Chessnut Player',
      black: 'Maia 1500',
      result: '*',
      timeControl: '10+5',
      startFen: chessnutStandardStartFen,
    );

    expect(pgn, contains('[Event "Chessnut Bot Game"]'));
    expect(pgn, contains('[White "Chessnut Player"]'));
    expect(pgn, contains('[Black "Maia 1500"]'));
    expect(pgn, contains('[TimeControl "10+5"]'));
    expect(pgn, contains('1. e4 e5 2. Nf3 *'));
  });

  test('builds PGN move numbers from a black-to-move FEN', () {
    const startFen = '4k3/8/8/8/8/8/4P3/4K3 b - - 0 17';
    final pgn = GameNotationService.buildPgn(
      sanMoves: const ['Kd7', 'e4', 'Ke6'],
      event: 'Black to move',
      site: 'Chessnut App',
      white: 'White',
      black: 'Black',
      result: '*',
      timeControl: '10+5',
      startFen: startFen,
    );

    expect(pgn, contains('17... Kd7 18. e4 Ke6 *'));
    expect(
      GameNotationService.parsePgn(pgn).moves.map((move) => move.san).toList(),
      ['Kd7', 'e4', 'Ke6'],
    );
  });

  test('replays Lichess UCI move text into SAN moves and FEN snapshots', () {
    final history = GameNotationService.replayUciMoves(
      initialFen: chessnutStandardStartFen,
      movesText: 'e2e4 e7e5 g1f3',
    );

    expect(history.sanMoves, ['e4', 'e5', 'Nf3']);
    expect(history.snapshots, hasLength(4));
    expect(history.snapshots.last.lastMove, ['g1', 'f3']);
    expect(history.snapshots.last.fen,
        'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2');
  });

  test('rejects illegal UCI moves while replaying stream history', () {
    expect(
      () => GameNotationService.replayUciMoves(
        initialFen: chessnutStandardStartFen,
        movesText: 'e2e5',
      ),
      throwsFormatException,
    );
  });

  test('parses PGN into legal SAN moves, UCI moves, and FEN snapshots', () {
    const pgn = '''
[Event "Chessnut Review"]
[Site "Chessnut App"]
[White "Alice"]
[Black "Bob"]
[Result "1-0"]

1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 1-0
''';

    final game = GameNotationService.parsePgn(pgn);

    expect(game.headers['White'], 'Alice');
    expect(game.result, '1-0');
    expect(game.moves.map((move) => move.san).toList(),
        ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6']);
    expect(game.moves.map((move) => move.uci).toList(),
        ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5', 'a7a6']);
    expect(game.moves[4].fenBefore,
        'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3');
    expect(game.moves[4].fenAfter,
        'r1bqkbnr/pppp1ppp/2n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3');
    expect(game.snapshots.last.fen, game.moves.last.fenAfter);
    expect(game.snapshots.last.lastMove, ['a7', 'a6']);
  });

  test('parses Chess.com PGN with clocks, comments, and result text', () {
    const pgn = '''
[Event "Live Chess"]
[Site "https://www.chess.com/game/live/123"]
[White "Alice"]
[Black "Bob"]
[Result "1-0"]

1. e4 {[%clk 0:04:59]} e5 {book} 2. Nf3 (2. Bc4) Nc6 1-0 Alice won by resignation
''';

    final game = GameNotationService.parsePgn(pgn);

    expect(game.result, '1-0');
    expect(game.moves.map((move) => move.san).toList(),
        ['e4', 'e5', 'Nf3', 'Nc6']);
  });

  test('repairs a compact Chess.com pawn capture while building PGN', () {
    const fen = '4k3/8/5n2/4P3/8/8/8/4K3 w - - 0 1';

    final pgn = GameNotationService.buildPgn(
      sanMoves: const ['xf6'],
      event: 'Chess.com Game',
      site: 'https://www.chess.com/game/live/123',
      white: 'Alice',
      black: 'Bob',
      result: '*',
      timeControl: '300',
      startFen: fen,
    );
    final game = GameNotationService.parsePgn(pgn);

    expect(pgn, contains('1. exf6 *'));
    expect(game.moves.single.san, 'exf6');
    expect(game.moves.single.uci, 'e5f6');
  });

  test('repairs a compact Chess.com piece capture while parsing PGN', () {
    const pgn = '''
[Event "Chess.com Game"]
[Site "https://www.chess.com/game/live/123"]
[SetUp "1"]
[FEN "4k3/8/5p2/8/4N3/8/8/4K3 w - - 0 1"]
[Result "*"]

1. xf6 *
''';

    final game = GameNotationService.parsePgn(pgn);

    expect(game.moves.single.san, 'Nxf6+');
    expect(game.moves.single.uci, 'e4f6');
  });

  test('repairs compact Chess.com capture inside a complete PGN', () {
    const pgn = '''
[Event "Live Chess"]
[Site "https://www.chess.com/game/live/123"]
[SetUp "1"]
[FEN "4k3/8/5n2/4P3/8/8/8/4K3 w - - 0 1"]
[White "Alice"]
[Black "Bob"]
[Result "*"]

1. xf6 *
''';

    final repaired = GameNotationService.repairCompressedCaptureSanInPgn(pgn);
    final game = GameNotationService.parsePgn(repaired);

    expect(repaired, contains('1. exf6 *'));
    expect(repaired, isNot(contains('1. xf6 *')));
    expect(game.moves.single.san, 'exf6');
    expect(game.moves.single.uci, 'e5f6');
  });

  test('repairs a compact Chess.com promotion capture', () {
    const fen = 'k5r1/7P/8/8/8/8/8/4K3 w - - 0 1';

    final pgn = GameNotationService.buildPgn(
      sanMoves: const ['xg8=Q'],
      event: 'Chess.com Game',
      site: 'https://www.chess.com/game/live/123',
      white: 'Alice',
      black: 'Bob',
      result: '*',
      timeControl: '300',
      startFen: fen,
    );
    final game = GameNotationService.parsePgn(pgn);

    expect(pgn, contains('1. hxg8=Q+ *'));
    expect(game.moves.single.san, 'hxg8=Q+');
    expect(game.moves.single.uci, 'h7g8q');
  });

  test('rejects ambiguous compact Chess.com captures', () {
    const pgn = '''
[Event "Chess.com Game"]
[SetUp "1"]
[FEN "4k3/8/5n2/4P1P1/8/8/8/4K3 w - - 0 1"]
[Result "*"]

1. xf6 *
''';

    expect(
      () => GameNotationService.parsePgn(pgn),
      throwsFormatException,
    );
  });

  test('parses PGN with FEN header from a custom starting position', () {
    const pgn = '''
[Event "Custom"]
[SetUp "1"]
[FEN "k7/8/8/8/8/8/4P3/4K3 w - - 0 1"]
[Result "*"]

1. e4 *
''';

    final game = GameNotationService.parsePgn(pgn);

    expect(game.initialFen, 'k7/8/8/8/8/8/4P3/4K3 w - - 0 1');
    expect(game.moves.single.san, 'e4');
    expect(game.moves.single.uci, 'e2e4');
    expect(game.snapshots, hasLength(2));
  });

  test('rejects PGN that has no legal mainline moves', () {
    expect(
      () => GameNotationService.parsePgn('1. e5 *'),
      throwsFormatException,
    );
  });
}
