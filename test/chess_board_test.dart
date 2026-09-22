import 'package:chessnut_flutter_export/widgets/chess_board.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rotateFenPieces180 rotates pieces and preserves FEN metadata', () {
    const reversedStart =
        'RNBKQBNR/PPPPPPPP/8/8/8/8/pppppppp/rnbkqbnr w KQkq - 0 1';

    expect(rotateFenPieces180(reversedStart), standardStartFen);
    expect(rotateFenPieces180(standardStartFen), reversedStart);
  });

  test('piecesFromBoardOnlyFen parses course positions without kings', () {
    final pieces = piecesFromBoardOnlyFen(
      '8/pppppppp/8/8/4P3/8/PPPP1PPP/8 w - - 0 1',
    );

    expect(pieces, hasLength(16));
    expect(
      pieces.any((piece) => piece.square == 'e4' && piece.code == 'wp'),
      isTrue,
    );
    expect(
      pieces.any((piece) => piece.square == 'd7' && piece.code == 'bp'),
      isTrue,
    );
  });

  test('checkedKingSquareFromFen finds only the king currently in check', () {
    expect(
      checkedKingSquareFromFen('4k3/4R3/8/8/8/8/8/K7 b - - 0 1'),
      'e8',
    );
    expect(
      checkedKingSquareFromFen('4k3/4R3/8/8/8/8/8/K7 w - - 0 1'),
      isNull,
    );
  });
}
