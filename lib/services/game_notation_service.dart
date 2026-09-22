import 'package:dartchess/dartchess.dart' as dc;

import '../widgets/chess_board.dart';

class GameMoveSnapshot {
  const GameMoveSnapshot({required this.fen, required this.lastMove});

  final String fen;
  final List<String> lastMove;
}

class GameMoveHistory {
  const GameMoveHistory({
    required this.sanMoves,
    required this.snapshots,
  });

  final List<String> sanMoves;
  final List<GameMoveSnapshot> snapshots;
}

class ParsedPgnGame {
  const ParsedPgnGame({
    required this.headers,
    required this.initialFen,
    required this.result,
    required this.moves,
    required this.snapshots,
  });

  final Map<String, String> headers;
  final String initialFen;
  final String result;
  final List<ParsedPgnMove> moves;
  final List<GameMoveSnapshot> snapshots;
}

class ParsedPgnMove {
  const ParsedPgnMove({
    required this.ply,
    required this.san,
    required this.uci,
    required this.fenBefore,
    required this.fenAfter,
    required this.lastMove,
  });

  final int ply;
  final String san;
  final String uci;
  final String fenBefore;
  final String fenAfter;
  final List<String> lastMove;
}

class GameNotationService {
  const GameNotationService._();

  static GameMoveHistory replayUciMoves({
    required String initialFen,
    required String movesText,
  }) {
    var position = loadDartChessPosition(initialFen);
    final sanMoves = <String>[];
    final snapshots = <GameMoveSnapshot>[
      GameMoveSnapshot(fen: position.fen, lastMove: const []),
    ];

    for (final token in movesText.split(RegExp(r'\s+'))) {
      final uci = token.trim();
      if (uci.isEmpty) continue;
      final move = dc.NormalMove.fromUci(uci);
      if (!position.isLegal(move)) {
        throw FormatException('Illegal UCI move in history: $uci');
      }
      final (nextPosition, san) = position.makeSan(move);
      position = nextPosition;
      sanMoves.add(san);
      snapshots.add(
        GameMoveSnapshot(
          fen: position.fen,
          lastMove: [move.from.name, move.to.name],
        ),
      );
    }

    return GameMoveHistory(
      sanMoves: List.unmodifiable(sanMoves),
      snapshots: List.unmodifiable(snapshots),
    );
  }

  static ParsedPgnGame parsePgn(String pgn) {
    final normalizedPgn = _normalizePgnForParsing(pgn);
    final reparsedPgn = _repairCompressedCaptureSanInPgn(normalizedPgn);
    final game = dc.PgnGame.parsePgn(reparsedPgn);
    var position = dc.PgnGame.startingPosition(game.headers);
    final moves = <ParsedPgnMove>[];
    final snapshots = <GameMoveSnapshot>[
      GameMoveSnapshot(fen: position.fen, lastMove: const []),
    ];

    for (final node in game.moves.mainline()) {
      final dc.Move? move;
      try {
        move = position.parseSan(node.san);
      } catch (_) {
        throw FormatException('Illegal SAN move in PGN: ${node.san}');
      }
      if (move == null) {
        throw FormatException('Illegal SAN move in PGN: ${node.san}');
      }
      final before = position.fen;
      final nextPosition = position.play(move);
      final lastMove = move.squares.map((square) => square.name).toList(
            growable: false,
          );
      moves.add(
        ParsedPgnMove(
          ply: moves.length + 1,
          san: node.san,
          uci: move.uci,
          fenBefore: before,
          fenAfter: nextPosition.fen,
          lastMove: lastMove,
        ),
      );
      position = nextPosition;
      snapshots.add(
        GameMoveSnapshot(fen: position.fen, lastMove: lastMove),
      );
    }

    if (moves.isEmpty) {
      throw const FormatException('PGN has no legal mainline moves.');
    }

    return ParsedPgnGame(
      headers: Map.unmodifiable(game.headers),
      initialFen: snapshots.first.fen,
      result: game.headers['Result'] ?? '*',
      moves: List.unmodifiable(moves),
      snapshots: List.unmodifiable(snapshots),
    );
  }

  static String repairCompressedCaptureSanInPgn(String pgn) {
    final normalizedPgn = _normalizePgnForParsing(pgn);
    return _repairCompressedCaptureSanInPgn(normalizedPgn);
  }

  static String buildPgn({
    required List<String> sanMoves,
    required String event,
    required String site,
    required String white,
    required String black,
    required String result,
    required String timeControl,
    required String startFen,
    Map<String, String> extraHeaders = const {},
    DateTime? date,
  }) {
    final playedAt = date ?? DateTime.now();
    final dateText =
        '${playedAt.year.toString().padLeft(4, '0')}.${playedAt.month.toString().padLeft(2, '0')}.${playedAt.day.toString().padLeft(2, '0')}';
    final headers = <String, String>{
      'Event': event,
      'Site': site,
      'Date': dateText,
      'Round': '-',
      'White': white,
      'Black': black,
      'Result': result,
      'TimeControl': timeControl,
    };
    if (_normalizeFenForHeader(startFen) !=
        _normalizeFenForHeader(standardStartFen)) {
      headers['SetUp'] = '1';
      headers['FEN'] = startFen;
    }
    headers.addAll(extraHeaders);

    final buffer = StringBuffer();
    headers.forEach((key, value) {
      buffer.writeln('[$key "${_escapeHeader(value)}"]');
    });
    buffer.writeln();
    final normalizedSanMoves = _repairCompressedCaptureSanMoves(
      sanMoves: sanMoves,
      startFen: startFen,
    );
    buffer.write(_moveText(
      normalizedSanMoves,
      result,
      startFen: startFen,
    ));
    return buffer.toString();
  }

  static String _moveText(
    List<String> sanMoves,
    String result, {
    String startFen = standardStartFen,
  }) {
    if (sanMoves.isEmpty) return result;
    final fenFields = startFen.trim().split(RegExp(r'\s+'));
    var whiteToMove = fenFields.length < 2 || fenFields[1] != 'b';
    var moveNumber = fenFields.length > 5
        ? (int.tryParse(fenFields[5]) ?? 1).clamp(1, 999999)
        : 1;
    final tokens = <String>[];
    for (var index = 0; index < sanMoves.length; index++) {
      if (whiteToMove) {
        tokens.add('$moveNumber.');
      } else if (index == 0) {
        tokens.add('$moveNumber...');
      }
      tokens.add(sanMoves[index]);
      if (whiteToMove) {
        whiteToMove = false;
      } else {
        whiteToMove = true;
        moveNumber += 1;
      }
    }
    tokens.add(result);
    return tokens.join(' ');
  }

  static String _escapeHeader(String value) {
    return value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  }

  static String _normalizeFenForHeader(String fen) {
    return fen.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _normalizePgnForParsing(String pgn) {
    final separator = RegExp(r'\r?\n\r?\n');
    final match = separator.firstMatch(pgn);
    final headers = match == null ? '' : pgn.substring(0, match.end);
    final moveText = match == null ? pgn : pgn.substring(match.end);
    final cleanedMoveText = moveText
        .replaceAll(RegExp(r'\{[^}]*\}'), ' ')
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'\$\d+'), ' ')
        .replaceAll(RegExp(r'\[%[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\b(e\.p\.|ep)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
    final normalizedMoveText = cleanedMoveText
        .replaceAllMapped(
          RegExp(r'(1-0|0-1|1/2-1/2|\*)\s+.+$', dotAll: true),
          (match) => match.group(1)!,
        )
        .trim();
    return '$headers$normalizedMoveText'.trim();
  }

  static String _repairCompressedCaptureSanInPgn(String pgn) {
    final separator = RegExp(r'\r?\n\r?\n');
    final match = separator.firstMatch(pgn);
    final headersText = match == null ? '' : pgn.substring(0, match.end);
    final moveText = match == null ? pgn : pgn.substring(match.end);
    final headers = _parseHeaders(headersText);
    final startFen = headers['FEN'] ?? standardStartFen;
    final tokens = _moveTokens(moveText);
    final sanMoves =
        tokens.where((token) => !_isGameResult(token)).toList(growable: false);
    final result = tokens.lastWhere(_isGameResult, orElse: () => '*');
    final repaired = _repairCompressedCaptureSanMoves(
      sanMoves: sanMoves,
      startFen: startFen,
    );
    return '$headersText${_moveText(repaired, result, startFen: startFen)}'
        .trim();
  }

  static Map<String, String> _parseHeaders(String headersText) {
    final headers = <String, String>{};
    for (final match
        in RegExp(r'^\[(\w+)\s+"((?:\\.|[^"])*)"\]\s*$', multiLine: true)
            .allMatches(headersText)) {
      headers[match.group(1)!] =
          match.group(2)!.replaceAll(r'\"', '"').replaceAll(r'\\', r'\');
    }
    return headers;
  }

  static List<String> _moveTokens(String moveText) {
    final tokens = <String>[];
    for (final raw in moveText.split(RegExp(r'\s+'))) {
      var token = raw.trim();
      if (token.isEmpty) continue;
      token = token.replaceAll(RegExp(r'^\d+\.(\.\.)?'), '');
      token = token.replaceAll(RegExp(r'^\.+'), '');
      if (token.isEmpty) continue;
      tokens.add(token);
    }
    return tokens;
  }

  static bool _isGameResult(String token) =>
      token == '1-0' || token == '0-1' || token == '1/2-1/2' || token == '*';

  static List<String> _repairCompressedCaptureSanMoves({
    required List<String> sanMoves,
    required String startFen,
  }) {
    var position = loadDartChessPosition(startFen);
    final repaired = <String>[];
    for (final san in sanMoves) {
      final dc.Move? move;
      try {
        move = position.parseSan(san);
      } catch (_) {
        final repair = _repairCompressedCaptureSan(position, san);
        if (repair == null) {
          repaired.add(san);
          continue;
        }

        repaired.add(repair.san);
        position = repair.position;
        continue;
      }
      if (move != null) {
        repaired.add(san);
        position = position.play(move);
        continue;
      }

      final repair = _repairCompressedCaptureSan(position, san);
      if (repair == null) {
        repaired.add(san);
        continue;
      }

      repaired.add(repair.san);
      position = repair.position;
    }
    return List.unmodifiable(repaired);
  }

  static _SanRepair? _repairCompressedCaptureSan(
    dc.Position position,
    String san,
  ) {
    final match = RegExp(r'^x([a-h][1-8])(=([QRBN]))?([+#])?$').firstMatch(san);
    if (match == null) return null;

    final target = dc.Square.parse(match.group(1)!);
    if (target == null) return null;
    final promotion = match.group(3) == null
        ? null
        : dc.Role.fromChar(match.group(3)!.toLowerCase());
    final candidates = <_SanRepair>[];
    for (final move in _legalNormalMoves(position)) {
      if (move.to != target) continue;
      if (move.promotion != promotion) continue;
      try {
        final (nextPosition, canonicalSan) = position.makeSan(move);
        if (!_isCaptureSanForTarget(canonicalSan, target.name)) continue;
        candidates.add(_SanRepair(san: canonicalSan, position: nextPosition));
      } catch (_) {
        continue;
      }
    }
    return candidates.length == 1 ? candidates.single : null;
  }

  static bool _isCaptureSanForTarget(String san, String targetName) {
    final normalized = san
        .replaceAll(RegExp(r'[+#]+$'), '')
        .replaceAll(RegExp(r'=([QRBN])'), '');
    return normalized.contains('x') && normalized.endsWith(targetName);
  }

  static List<dc.NormalMove> _legalNormalMoves(dc.Position position) {
    final moves = <dc.NormalMove>[];
    final legalTargets = dc.makeLegalMoves(position);
    for (final entry in legalTargets.entries) {
      final from = entry.key;
      final piece = position.board.pieceAt(from);
      if (piece == null) continue;

      for (final to in entry.value) {
        final promotionRoles = _promotionRolesFor(piece, to);
        if (promotionRoles.isEmpty) {
          final move =
              position.normalizeMove(dc.NormalMove(from: from, to: to));
          if (move is dc.NormalMove) moves.add(move);
        } else {
          for (final role in promotionRoles) {
            moves.add(dc.NormalMove(from: from, to: to, promotion: role));
          }
        }
      }
    }
    return moves.where(position.isLegal).toList(growable: false);
  }

  static List<dc.Role> _promotionRolesFor(dc.Piece piece, dc.Square to) {
    if (piece.role != dc.Role.pawn ||
        (to.rank != dc.Rank.first && to.rank != dc.Rank.eighth)) {
      return const [];
    }
    return const [dc.Role.queen, dc.Role.rook, dc.Role.bishop, dc.Role.knight];
  }
}

class _SanRepair {
  const _SanRepair({required this.san, required this.position});

  final String san;
  final dc.Position position;
}
