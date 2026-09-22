import 'dart:convert';

import 'package:dartchess/dartchess.dart' as dc;

import '../widgets/chess_board.dart';
import 'board_settings_service.dart';
import 'physical_board_protocol.dart';

class ChessComResolvedMove {
  const ChessComResolvedMove({
    required this.uci,
    required this.resultingFen,
  });

  final String uci;
  final String resultingFen;
}

class ChessComLegalTargetSelection {
  const ChessComLegalTargetSelection({
    required this.sourceSquare,
    required this.targetSquares,
  });

  final String sourceSquare;
  final Set<String> targetSquares;

  Map<String, ChessnutMoveLedColor> get moveLedColors => {
        for (final square in targetSquares) square: ChessnutMoveLedColor.green,
      };
}

enum ChessComBoardSyncStatus {
  sent,
  sentWithFallback,
  unchanged,
  illegal,
  rejected,
}

class ChessComBoardSyncResult {
  const ChessComBoardSyncResult({
    required this.status,
    this.move,
    this.fallbackUsed = false,
  });

  final ChessComBoardSyncStatus status;
  final ChessComResolvedMove? move;
  final bool fallbackUsed;
}

typedef ChessComJavaScriptRunner = Future<Object?> Function(String script);

class ChessComBoardSync {
  const ChessComBoardSync({
    required this.runJavaScript,
    this.controlMode = ChessComMoveControlMode.direct,
  });

  final ChessComJavaScriptRunner runJavaScript;
  final ChessComMoveControlMode controlMode;

  ChessComBoardSyncResult resolveBoardFen({
    required String webFen,
    required String boardFen,
  }) {
    if (webFen.split(' ').first == boardFen.split(' ').first) {
      return const ChessComBoardSyncResult(
        status: ChessComBoardSyncStatus.unchanged,
      );
    }
    final move = ChessComMoveResolver.resolve(
      webFen: webFen,
      boardFen: boardFen,
    );
    if (move == null) {
      return const ChessComBoardSyncResult(
        status: ChessComBoardSyncStatus.illegal,
      );
    }
    return ChessComBoardSyncResult(
      status: ChessComBoardSyncStatus.sent,
      move: move,
    );
  }

  Future<ChessComBoardSyncResult> submitBoardFen({
    required String webFen,
    required String boardFen,
  }) async {
    final resolved = resolveBoardFen(webFen: webFen, boardFen: boardFen);
    final move = resolved.move;
    if (move == null) return resolved;
    final result = await runJavaScript(
      'window.makeUCIMove(${jsonEncode(move.uci)})',
    );
    return ChessComBoardSyncResult(
      status: _javaScriptCallSucceeded(result)
          ? ChessComBoardSyncStatus.sent
          : ChessComBoardSyncStatus.rejected,
      move: move,
    );
  }
}

bool _javaScriptCallSucceeded(Object? value) {
  if (value == true) return true;
  return value?.toString().replaceAll('"', '').trim().toLowerCase() == 'true';
}

class ChessComMoveResolver {
  const ChessComMoveResolver._();

  static ChessComResolvedMove? resolve({
    required String webFen,
    required String boardFen,
  }) {
    final position = loadDartChessPosition(webFen);
    final normalizedBoardFen = boardFen.split(' ').first.trim();
    for (final candidate in _chessComLegalMoveCandidates(position)) {
      try {
        final next = position.play(candidate.playMove);
        if (next.board.fen == normalizedBoardFen) {
          return ChessComResolvedMove(
            uci: candidate.uci,
            resultingFen: next.fen,
          );
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}

class _ChessComMoveCandidate {
  const _ChessComMoveCandidate({
    required this.playMove,
    required this.uci,
  });

  final dc.NormalMove playMove;
  final String uci;
}

List<_ChessComMoveCandidate> _chessComLegalMoveCandidates(
  dc.Position position,
) {
  final castlingCandidates = <_ChessComMoveCandidate>[];
  final otherCandidates = <_ChessComMoveCandidate>[];
  for (final entry in dc.makeLegalMoves(position).entries) {
    final from = entry.key;
    final piece = position.board.pieceAt(from);
    if (piece == null) continue;
    for (final to in entry.value) {
      final promotions = _chessComPromotionRolesFor(piece, to);
      if (promotions.isEmpty) {
        final rawMove = dc.NormalMove(from: from, to: to);
        final normalized = position.normalizeMove(rawMove);
        if (normalized is! dc.NormalMove || !position.isLegal(normalized)) {
          continue;
        }
        final candidate = _ChessComMoveCandidate(
          playMove: normalized,
          uci: rawMove.uci,
        );
        if (_isChessComCastlingUci(piece, rawMove, normalized)) {
          castlingCandidates.add(candidate);
        } else {
          otherCandidates.add(candidate);
        }
        continue;
      }
      for (final role in promotions) {
        final move = dc.NormalMove(from: from, to: to, promotion: role);
        if (!position.isLegal(move)) continue;
        otherCandidates.add(_ChessComMoveCandidate(
          playMove: move,
          uci: move.uci,
        ));
      }
    }
  }
  return [...castlingCandidates, ...otherCandidates];
}

bool _isChessComCastlingUci(
  dc.Piece piece,
  dc.NormalMove rawMove,
  dc.NormalMove normalized,
) {
  return piece.role == dc.Role.king &&
      rawMove.promotion == null &&
      rawMove.from == normalized.from &&
      rawMove.to != normalized.to &&
      (rawMove.to.file == dc.File.c || rawMove.to.file == dc.File.g);
}

List<dc.Role> _chessComPromotionRolesFor(dc.Piece piece, dc.Square to) {
  if (piece.role != dc.Role.pawn ||
      (to.rank != dc.Rank.first && to.rank != dc.Rank.eighth)) {
    return const [];
  }
  return const [dc.Role.queen, dc.Role.rook, dc.Role.bishop, dc.Role.knight];
}

class ChessComLegalTargetResolver {
  const ChessComLegalTargetResolver._();

  static ChessComLegalTargetSelection? resolveLiftedPiece({
    required String webFen,
    required String boardFen,
  }) {
    final position = loadDartChessPosition(webFen);
    final webBoard = _expandBoardFen(position.board.fen);
    final physicalBoard = _expandBoardFen(_boardOnlyFen(boardFen));
    if (webBoard == null || physicalBoard == null) return null;

    dc.Square? liftedSquare;
    for (final square in dc.Square.values) {
      final piece = position.board.pieceAt(square);
      if (piece == null || piece.color != position.turn) continue;
      final index = _boardFenIndexForSquare(square);
      if (index == null) continue;
      if (webBoard[index].isEmpty ||
          physicalBoard[index].isNotEmpty ||
          webBoard[index] == physicalBoard[index]) {
        continue;
      }
      for (var otherIndex = 0; otherIndex < webBoard.length; otherIndex += 1) {
        if (otherIndex == index) continue;
        if (webBoard[otherIndex] != physicalBoard[otherIndex]) return null;
      }
      if (liftedSquare != null) return null;
      liftedSquare = square;
    }

    if (liftedSquare == null) return null;
    final targetSquares = dc
        .makeLegalMoves(position)[liftedSquare]
        ?.map((square) => square.name)
        .toSet();
    if (targetSquares == null || targetSquares.isEmpty) return null;
    return ChessComLegalTargetSelection(
      sourceSquare: liftedSquare.name,
      targetSquares: Set<String>.unmodifiable(targetSquares),
    );
  }
}

class ChessComBoardGuidance {
  const ChessComBoardGuidance._();

  static Set<String> differentSquares({
    required String sourceBoardFen,
    required String targetBoardFen,
  }) {
    final source = _expandBoardFen(sourceBoardFen);
    final target = _expandBoardFen(targetBoardFen);
    if (source == null || target == null) return const {};
    final squares = <String>{};
    for (var index = 0; index < source.length; index += 1) {
      if (source[index] == target[index]) continue;
      final file = index % 8;
      final rank = index ~/ 8;
      squares.add('${ChessBoard.files[file]}${8 - rank}');
    }
    return Set<String>.unmodifiable(squares);
  }
}

int? _boardFenIndexForSquare(dc.Square square) {
  return (7 - square.rank.value) * 8 + square.file.value;
}

String _boardOnlyFen(String fen) => fen.trim().split(RegExp(r'\s+')).first;

List<String>? _expandBoardFen(String fen) {
  final expanded = <String>[];
  for (final rank in _boardOnlyFen(fen).split('/')) {
    for (final codeUnit in rank.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      final empty = int.tryParse(char);
      if (empty != null) {
        expanded.addAll(List<String>.filled(empty, ''));
      } else {
        expanded.add(char);
      }
    }
  }
  return expanded.length == 64 ? expanded : null;
}
