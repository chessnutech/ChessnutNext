import 'dart:async';

import 'package:dartchess/dartchess.dart' as dc;

import '../models/app_models.dart';
import '../widgets/chess_board.dart';
import 'stockfish_analysis_service.dart';

typedef BotEvaluationListener = void Function(PositionEngineAnalysis analysis);

class BotMoveResult {
  const BotMoveResult({
    required this.move,
    required this.san,
    required this.fen,
    this.isFallback = true,
  });

  final dc.NormalMove move;
  final String san;
  final String fen;
  final bool isFallback;

  String get uci => move.uci;
}

abstract class BotEngineAdapter {
  const BotEngineAdapter();

  String? get lastErrorMessage => null;

  Future<BotMoveResult?> bestMove({
    required String fen,
    required BotGameConfig config,
    List<String> moveHistory = const [],
  });

  Future<void> prepare({required BotGameConfig config}) async {}

  Future<PositionEngineAnalysis?> analyzeFen({
    required String fen,
    required BotGameConfig config,
    int depth = 10,
    int multiPv = 1,
  }) async {
    return null;
  }

  void setEvaluationListener(BotEvaluationListener? listener) {}

  Future<void> dispose() async {}
}

class HeuristicBotEngineAdapter extends BotEngineAdapter {
  const HeuristicBotEngineAdapter();

  @override
  Future<BotMoveResult?> bestMove({
    required String fen,
    required BotGameConfig config,
    List<String> moveHistory = const [],
  }) async {
    final position = loadDartChessPosition(fen);
    if (position.isGameOver) return null;

    final moves = legalNormalMoves(position);
    if (moves.isEmpty) return null;

    await Future<void>.delayed(_thinkingDelay(config));

    final selected = _selectMove(position, moves, config);
    try {
      final (nextPosition, san) = position.makeSan(selected);
      return BotMoveResult(
        move: selected,
        san: san,
        fen: nextPosition.fen,
        isFallback: true,
      );
    } catch (_) {
      return null;
    }
  }

  Duration _thinkingDelay(BotGameConfig config) {
    if (config.engineKind == BotEngineKind.stockfish &&
        config.stockfishThinkingTime != Duration.zero) {
      return config.stockfishThinkingTime.clamp(
        const Duration(milliseconds: 120),
        const Duration(milliseconds: 850),
      );
    }
    return const Duration(milliseconds: 420);
  }

  dc.NormalMove _selectMove(
    dc.Position position,
    List<dc.NormalMove> moves,
    BotGameConfig config,
  ) {
    final scored = [
      for (final move in moves)
        _ScoredMove(move, _scoreMove(position, move, config))
    ]..sort((a, b) => b.score.compareTo(a.score));

    final variety = switch (config.engineKind) {
      BotEngineKind.maia => 4,
      BotEngineKind.maia3 => 3,
      BotEngineKind.stockfish => config.stockfishElo >= 1800 ? 1 : 3,
      BotEngineKind.lc0 => 2,
    };
    final index = (position.ply + fenSeed(position.fen)) %
        variety.clamp(1, scored.length);
    return scored[index].move;
  }

  int _scoreMove(
    dc.Position position,
    dc.NormalMove move,
    BotGameConfig config,
  ) {
    var score = 0;
    final movingPiece = position.board.pieceAt(move.from);
    final capturedPiece = _capturedPiece(position, move);

    if (movingPiece != null && capturedPiece != null) {
      score += _pieceValue(capturedPiece.role) -
          (_pieceValue(movingPiece.role) ~/ 10);
    }
    if (move.promotion != null) score += _pieceValue(move.promotion!);

    try {
      final nextPosition = position.play(move);
      if (nextPosition.isCheckmate) {
        score += 100000;
      } else if (nextPosition.isCheck) {
        score += 45;
      }
    } catch (_) {
      return -100000;
    }

    score += _centralBonus(move.to.name);
    score += _developmentBonus(position, move);
    score += _kingSafetyBonus(position, move);

    if (config.engineKind == BotEngineKind.maia ||
        config.engineKind == BotEngineKind.maia3) {
      score += _humanTempoBonus(position, move);
    }
    return score;
  }

  dc.Piece? _capturedPiece(dc.Position position, dc.NormalMove move) {
    final directCapture = position.board.pieceAt(move.to);
    if (directCapture != null) return directCapture;

    final movingPiece = position.board.pieceAt(move.from);
    if (movingPiece?.role == dc.Role.pawn &&
        position.epSquare == move.to &&
        move.from.file != move.to.file) {
      final capturedSquare = dc.Square(
        move.to.value + (position.turn == dc.Side.white ? -8 : 8),
      );
      return position.board.pieceAt(capturedSquare);
    }
    return null;
  }

  int _pieceValue(dc.Role role) {
    return switch (role) {
      dc.Role.pawn => 100,
      dc.Role.knight => 320,
      dc.Role.bishop => 330,
      dc.Role.rook => 500,
      dc.Role.queen => 900,
      dc.Role.king => 0,
    };
  }

  int _centralBonus(String square) {
    const center = {
      'd4': 24,
      'e4': 24,
      'd5': 24,
      'e5': 24,
      'c3': 10,
      'd3': 10,
      'e3': 10,
      'f3': 10,
      'c6': 10,
      'd6': 10,
      'e6': 10,
      'f6': 10,
    };
    return center[square] ?? 0;
  }

  int _developmentBonus(dc.Position position, dc.NormalMove move) {
    final piece = position.board.pieceAt(move.from);
    if ((piece?.role == dc.Role.knight || piece?.role == dc.Role.bishop) &&
        const {'b1', 'g1', 'c1', 'f1', 'b8', 'g8', 'c8', 'f8'}
            .contains(move.from.name)) {
      return 18;
    }
    return 0;
  }

  int _kingSafetyBonus(dc.Position position, dc.NormalMove move) {
    final piece = position.board.pieceAt(move.from);
    if (piece?.role == dc.Role.king && (move.to - move.from).abs() >= 2) {
      return 55;
    }
    return 0;
  }

  int _humanTempoBonus(dc.Position position, dc.NormalMove move) {
    final piece = position.board.pieceAt(move.from);
    if (piece?.role == dc.Role.queen) return -14;
    if (piece?.role == dc.Role.pawn && _capturedPiece(position, move) == null) {
      return 4;
    }
    return 0;
  }

  static int fenSeed(String fen) {
    var hash = 0;
    for (final unit in fen.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }
}

List<dc.NormalMove> legalNormalMoves(dc.Position position) {
  final moves = <dc.NormalMove>[];
  final legalTargets = dc.makeLegalMoves(position);
  for (final entry in legalTargets.entries) {
    final from = entry.key;
    final piece = position.board.pieceAt(from);
    if (piece == null) continue;

    for (final to in entry.value) {
      final promotionRoles = _promotionRolesFor(piece, to);
      if (promotionRoles.isEmpty) {
        moves.add(position.normalizeMove(dc.NormalMove(from: from, to: to))
            as dc.NormalMove);
      } else {
        for (final role in promotionRoles) {
          moves.add(dc.NormalMove(from: from, to: to, promotion: role));
        }
      }
    }
  }
  return moves.where(position.isLegal).toList(growable: false);
}

List<dc.Role> _promotionRolesFor(dc.Piece piece, dc.Square to) {
  if (piece.role != dc.Role.pawn ||
      (to.rank != dc.Rank.first && to.rank != dc.Rank.eighth)) {
    return const [];
  }
  return const [dc.Role.queen, dc.Role.rook, dc.Role.bishop, dc.Role.knight];
}

class _ScoredMove {
  const _ScoredMove(this.move, this.score);

  final dc.NormalMove move;
  final int score;
}

extension on Duration {
  Duration clamp(Duration min, Duration max) {
    if (this < min) return min;
    if (this > max) return max;
    return this;
  }
}
