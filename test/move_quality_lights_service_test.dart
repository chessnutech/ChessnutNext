import 'package:chessnut_flutter_export/services/move_quality_lights_service.dart';
import 'package:chessnut_flutter_export/services/physical_board_protocol.dart';
import 'package:chessnut_flutter_export/services/stockfish_analysis_service.dart';
import 'package:dartchess/dartchess.dart' as dc;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects a single lifted piece and returns its legal targets', () {
    const position = dc.Chess.initial;

    final selection = MoveQualityLightsService.detectLiftedPieceTargets(
      position: position,
      boardOnlyFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKB1R',
    );

    expect(selection, isNotNull);
    expect(selection!.sourceSquare, 'g1');
    expect(selection.targetSquares, containsAll(<String>{'f3', 'h3'}));
  });

  test('classifies lifted-piece target squares into five LED qualities', () {
    final qualities = MoveQualityLightsService.classifyTargetSquares(
      sourceSquare: 'g1',
      targetSquares: const {'f3', 'h3', 'e2', 'e4', 'd5', 'a1'},
      candidateMoves: const [
        EngineMoveCandidate(moveUci: 'g1f3', scoreCentipawns: 100),
        EngineMoveCandidate(moveUci: 'g1h3', scoreCentipawns: 91),
        EngineMoveCandidate(moveUci: 'g1e2', scoreCentipawns: 84),
        EngineMoveCandidate(moveUci: 'g1e4', scoreCentipawns: 72),
        EngineMoveCandidate(moveUci: 'g1d5', scoreCentipawns: 52),
        EngineMoveCandidate(moveUci: 'g1a1', scoreCentipawns: 0),
      ],
    );

    expect(qualities['f3'], MoveQualityLight.best);
    expect(qualities['h3'], MoveQualityLight.great);
    expect(qualities['e2'], MoveQualityLight.good);
    expect(qualities['e4'], MoveQualityLight.inaccuracy);
    expect(qualities['d5'], MoveQualityLight.mistake);
    expect(qualities['a1'], MoveQualityLight.blunder);
  });

  test('maps move quality lights to Move RGB colors', () {
    expect(MoveQualityLight.best.ledColor, ChessnutMoveLedColor.green);
    expect(MoveQualityLight.great.ledColor, ChessnutMoveLedColor.green);
    expect(MoveQualityLight.good.ledColor, ChessnutMoveLedColor.green);
    expect(MoveQualityLight.inaccuracy.ledColor, ChessnutMoveLedColor.blue);
    expect(MoveQualityLight.mistake.ledColor, ChessnutMoveLedColor.red);
    expect(MoveQualityLight.blunder.ledColor, ChessnutMoveLedColor.red);
  });
}
