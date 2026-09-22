import 'package:dartchess/dartchess.dart' as dc;

import 'physical_board_protocol.dart';
import 'stockfish_analysis_service.dart';

enum MoveQualityLight {
  best,
  great,
  good,
  inaccuracy,
  mistake,
  blunder,
}

extension MoveQualityLightColor on MoveQualityLight {
  ChessnutMoveLedColor get ledColor {
    return switch (this) {
      MoveQualityLight.best => ChessnutMoveLedColor.green,
      MoveQualityLight.great => ChessnutMoveLedColor.green,
      MoveQualityLight.good => ChessnutMoveLedColor.green,
      MoveQualityLight.inaccuracy => ChessnutMoveLedColor.blue,
      MoveQualityLight.mistake => ChessnutMoveLedColor.red,
      MoveQualityLight.blunder => ChessnutMoveLedColor.red,
    };
  }
}

class LiftedPieceTargets {
  const LiftedPieceTargets({
    required this.sourceSquare,
    required this.targetSquares,
  });

  final String sourceSquare;
  final Set<String> targetSquares;
}

class MoveQualityLightsService {
  const MoveQualityLightsService._();

  static LiftedPieceTargets? detectLiftedPieceTargets({
    required dc.Position position,
    required String boardOnlyFen,
  }) {
    try {
      final compare = dc.Board.parseFen(boardOnlyFen);
      dc.Square? liftedSquare;
      for (final square in dc.Square.values) {
        final expected = position.board.pieceAt(square);
        final actual = compare.pieceAt(square);
        if (expected == actual) continue;
        if (expected != null && actual == null) {
          if (liftedSquare != null) return null;
          liftedSquare = square;
          continue;
        }
        return null;
      }

      if (liftedSquare == null) return null;
      final targets = dc
          .makeLegalMoves(position)[liftedSquare]
          ?.map((square) => square.name)
          .toSet();
      if (targets == null || targets.isEmpty) return null;
      return LiftedPieceTargets(
        sourceSquare: liftedSquare.name,
        targetSquares: Set.unmodifiable(targets),
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, MoveQualityLight> classifyTargetSquares({
    required String sourceSquare,
    required Set<String> targetSquares,
    required List<EngineMoveCandidate> candidateMoves,
  }) {
    final moveQualities = _legacyMoveQualities(candidateMoves);
    final result = <String, MoveQualityLight>{};
    for (final target in targetSquares) {
      final quality = _bestQualityForTarget(
        sourceSquare: sourceSquare,
        targetSquare: target,
        moveQualities: moveQualities,
      );
      result[target] = quality ?? MoveQualityLight.good;
    }
    return Map.unmodifiable(result);
  }

  static Map<String, Map<String, MoveQualityLight>>
      classifyLegalTargetsBySource({
    required dc.Position position,
    required List<EngineMoveCandidate> candidateMoves,
  }) {
    final legalTargets = dc.makeLegalMoves(position);
    return Map.unmodifiable({
      for (final entry in legalTargets.entries)
        if (entry.value.isNotEmpty)
          entry.key.name: classifyTargetSquares(
            sourceSquare: entry.key.name,
            targetSquares: entry.value.map((square) => square.name).toSet(),
            candidateMoves: candidateMoves,
          ),
    });
  }

  static MoveQualityLight? _bestQualityForTarget({
    required String sourceSquare,
    required String targetSquare,
    required Map<String, MoveQualityLight> moveQualities,
  }) {
    final prefix = '$sourceSquare$targetSquare';
    MoveQualityLight? bestQuality;
    for (final entry in moveQualities.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      if (bestQuality == null ||
          _scoreForQuality(entry.value) > _scoreForQuality(bestQuality)) {
        bestQuality = entry.value;
      }
    }
    return bestQuality;
  }

  static Map<String, MoveQualityLight> _legacyMoveQualities(
    List<EngineMoveCandidate> candidateMoves,
  ) {
    if (candidateMoves.isEmpty) return const {};

    final result = <String, MoveQualityLight>{};
    var maxCp = -0x7fffffff;
    var minCp = 0x7fffffff;
    var maxIndex = candidateMoves.length - 1;
    var minIndex = 0;

    for (var i = 0; i < candidateMoves.length; i += 1) {
      final candidate = candidateMoves[i];
      final mate = candidate.scoreMate;
      if (mate != null) {
        result[candidate.moveUci] =
            mate > 0 ? MoveQualityLight.best : MoveQualityLight.blunder;
        continue;
      }

      final cp = candidate.scoreCentipawns;
      if (cp == null) continue;
      if (cp > maxCp) {
        maxCp = cp;
        maxIndex = i;
      }
      if (cp < minCp) {
        minCp = cp;
        minIndex = i;
      }
    }

    if (maxCp == -0x7fffffff || minCp == 0x7fffffff) {
      return Map.unmodifiable(result);
    }

    final scoreDiff = maxCp - minCp;
    for (var i = 0; i < candidateMoves.length; i += 1) {
      final candidate = candidateMoves[i];
      if (candidate.scoreMate != null) continue;
      final cp = candidate.scoreCentipawns;
      if (cp == null) continue;
      if (maxIndex <= minIndex) {
        result[candidate.moveUci] = _qualityForLegacyScore(
          _legacyScore(maxCp: maxCp, cp: cp, scoreDiff: scoreDiff),
        );
      } else {
        result[candidate.moveUci] = MoveQualityLight.good;
      }
    }

    return Map.unmodifiable(result);
  }

  static int _legacyScore({
    required int maxCp,
    required int cp,
    required int scoreDiff,
  }) {
    if (scoreDiff <= 0) return 5;
    final loss = maxCp - cp;
    if (loss < 0.05 * scoreDiff) return 5;
    if (loss < 0.1 * scoreDiff) return 4;
    if (loss < 0.2 * scoreDiff) return 3;
    if (loss < 0.3 * scoreDiff) return 2;
    if (loss < 0.5 * scoreDiff) return 1;
    return 0;
  }

  static MoveQualityLight _qualityForLegacyScore(int score) {
    return switch (score) {
      5 => MoveQualityLight.best,
      4 => MoveQualityLight.great,
      3 => MoveQualityLight.good,
      2 => MoveQualityLight.inaccuracy,
      1 => MoveQualityLight.mistake,
      _ => MoveQualityLight.blunder,
    };
  }

  static int _scoreForQuality(MoveQualityLight quality) {
    return switch (quality) {
      MoveQualityLight.best => 5,
      MoveQualityLight.great => 4,
      MoveQualityLight.good => 3,
      MoveQualityLight.inaccuracy => 2,
      MoveQualityLight.mistake => 1,
      MoveQualityLight.blunder => 0,
    };
  }
}
