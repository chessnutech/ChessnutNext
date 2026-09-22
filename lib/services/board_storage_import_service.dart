import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dartchess/dartchess.dart' as dc;

import '../models/app_models.dart';
import '../widgets/chess_board.dart' show standardStartFen;
import 'chessnut_api_client.dart';
import 'game_notation_service.dart';
import 'game_record_save_service.dart';
import 'local_game_record_store.dart';

class BoardStorageImportService {
  const BoardStorageImportService({
    required this.apiClient,
    required this.recordsProvider,
    this.saveService,
    this.ownerUserId,
  });

  final ChessnutApiClient apiClient;
  final Future<List<GameRecord>> Function() recordsProvider;
  final GameRecordSaveService? saveService;
  final int? ownerUserId;

  static BoardStorageStoredGame parseStoredGame({
    required String rawFenSequence,
    DateTime? importedAt,
  }) {
    if (_looksLikePgn(rawFenSequence)) {
      return _parseStoredPgn(rawFenSequence, importedAt: importedAt);
    }
    return _parseStoredFenSequence(
      rawFenSequence,
      importedAt: importedAt,
    );
  }

  static BoardStorageStoredGame _parseStoredFenSequence(
    String rawFenSequence, {
    DateTime? importedAt,
  }) {
    final normalized = _normalizeRawSequence(rawFenSequence);
    final importKey = _importKey(normalized);
    final fens = normalized
        .split(';')
        .map((fen) => fen.trim())
        .where((fen) => fen.isNotEmpty)
        .toList(growable: false);
    if (fens.length < 2) {
      return BoardStorageStoredGame.invalid(
        rawFenSequence: normalized,
        importKey: importKey,
        errorMessage:
            'This board record has too few positions to build a game.',
      );
    }

    try {
      final replay = _bestFenReplay(fens);
      if (replay.sanMoves.isEmpty) {
        return BoardStorageStoredGame.invalid(
          rawFenSequence: normalized,
          importKey: importKey,
          errorMessage:
              'This board record has no positions that match legal chess moves.',
        );
      }

      final pgn = GameNotationService.buildPgn(
        sanMoves: replay.sanMoves,
        event: 'Chessnut Board Storage',
        site: 'Chessnut App',
        white: 'White',
        black: 'Black',
        result: '*',
        timeControl: '-',
        startFen: replay.startFen,
        extraHeaders: {
          'Source': 'Board storage',
          'BoardStorageHash': importKey,
        },
        date: importedAt,
      );
      return BoardStorageStoredGame(
        rawFenSequence: normalized,
        importKey: importKey,
        pgnHash: pgnFingerprint(pgn),
        pgn: pgn,
        whiteName: 'White',
        blackName: 'Black',
        gameStep: replay.sanMoves.length,
        isImportable: true,
      );
    } catch (error) {
      return BoardStorageStoredGame.invalid(
        rawFenSequence: normalized,
        importKey: importKey,
        errorMessage: 'This board record could not be read as a legal game.',
      );
    }
  }

  static BoardStorageStoredGame _parseStoredPgn(
    String rawPgn, {
    DateTime? importedAt,
  }) {
    final cleaned = rawPgn.replaceAll('\u0000', '').trim();
    final importKey = _importKey(_normalizeRawPgn(cleaned));
    try {
      final parseable = _ensurePgnHeaders(cleaned, importedAt: importedAt);
      final parsed = GameNotationService.parsePgn(parseable);
      final originalHeaders = parsed.headers;
      final result = _header(originalHeaders, 'Result', parsed.result);
      final extraHeaders = <String, String>{
        'Source': 'Board storage',
        'BoardStorageHash': importKey,
      };
      for (final key in [
        'Date',
        'Round',
        'Time',
        'UTCDate',
        'UTCTime',
        'WhiteTime',
        'BlackTime',
        'Speed',
        'PlayerSide',
      ]) {
        final value = originalHeaders[key]?.trim();
        if (value != null && value.isNotEmpty) {
          extraHeaders[key] = value;
        }
      }
      final pgn = GameNotationService.buildPgn(
        sanMoves: parsed.moves.map((move) => move.san).toList(growable: false),
        event: _header(
          originalHeaders,
          'Event',
          'Chessnut Board Storage',
        ),
        site: _header(originalHeaders, 'Site', 'Chessnut App'),
        white: _header(originalHeaders, 'White', 'White'),
        black: _header(originalHeaders, 'Black', 'Black'),
        result: result,
        timeControl: _header(originalHeaders, 'TimeControl', '-'),
        startFen: parsed.initialFen,
        extraHeaders: extraHeaders,
        date: importedAt,
      );
      return BoardStorageStoredGame(
        rawFenSequence: cleaned,
        importKey: importKey,
        pgnHash: pgnFingerprint(pgn),
        pgn: pgn,
        whiteName: _header(originalHeaders, 'White', 'White'),
        blackName: _header(originalHeaders, 'Black', 'Black'),
        gameStep: parsed.moves.length,
        isImportable: true,
      );
    } catch (_) {
      return BoardStorageStoredGame.invalid(
        rawFenSequence: cleaned,
        importKey: importKey,
        errorMessage: 'This board record could not be read as a legal game.',
      );
    }
  }

  BoardStorageImportPreview previewParsed(List<BoardStorageStoredGame> games) {
    return BoardStorageImportPreview(
      items: _markDuplicates(
        games,
        importedKeys: const {},
        existingPgnHashes: const {},
      ),
    );
  }

  Future<BoardStorageImportPreview> previewStoredGames(
    List<String> rawFenSequences, {
    Set<String> importedKeys = const {},
  }) async {
    final existing = await recordsProvider();
    return BoardStorageImportPreview(
      items: _markDuplicates(
        rawFenSequences
            .map((raw) => parseStoredGame(rawFenSequence: raw))
            .toList(growable: false),
        importedKeys: importedKeys,
        existingPgnHashes: existing.map((record) => pgnFingerprint(record.pgn)),
      ),
    );
  }

  Future<BoardStorageImportResult> importParsed(
    List<BoardStorageStoredGame> games,
  ) async {
    var imported = 0;
    var skipped = 0;
    var failed = 0;
    final importedKeysOut = <String>{};
    final errors = <String>[];
    for (final game in games) {
      if (!game.isImportable) {
        skipped += 1;
        continue;
      }
      final saver = saveService;
      if (saver != null) {
        final parsed = GameNotationService.parsePgn(game.pgn);
        final now = DateTime.now();
        final playedAt = _storedGameTime(parsed.headers) ?? now;
        final result = await saver.saveLive(
          GameRecordDraft(
            id: 'board-${ownerUserId ?? 'guest'}-${game.importKey}',
            pgn: game.pgn,
            whiteName: game.whiteName,
            blackName: game.blackName,
            playTime: (playedAt.millisecondsSinceEpoch ~/ 1000).toString(),
            playMode: 'otb',
            winId: switch (parsed.result) {
              '1-0' => 1,
              '0-1' => 2,
              '1/2-1/2' => 3,
              _ => 0
            },
            gameStatus: 2,
            gameStep: game.gameStep,
            result: parsed.result,
            savedAt: now,
            metadata: PgnSaveMetadata(
              timeControl: parsed.headers['TimeControl'],
              speed: parsed.headers['Speed']?.toLowerCase(),
              playerColor: parsed.headers['PlayerSide']?.toLowerCase(),
            ),
          ),
          ownerUserId: ownerUserId,
        );
        if (result.status.isSuccess) {
          imported++;
          importedKeysOut.add(game.importKey);
        } else {
          failed++;
          errors.add(result.status.errorMessage ??
              'A board game could not be imported.');
        }
        continue;
      }
      final ApiResult<UploadPgnResult> result;
      try {
        result = await apiClient.uploadPgn(
          pgn: game.pgn,
          whiteName: game.whiteName,
          blackName: game.blackName,
          playTime: (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
          playMode: 'otb',
          winId: 0,
          gameStatus: 2,
          gameStep: game.gameStep,
        );
      } catch (_) {
        failed += 1;
        errors.add('A board game could not be imported.');
        continue;
      }
      if (result.isSuccess) {
        imported += 1;
        importedKeysOut.add(game.importKey);
      } else {
        failed += 1;
        errors.add(
          result.status.errorMessage ?? 'A board game could not be imported.',
        );
      }
    }
    return BoardStorageImportResult(
      importedCount: imported,
      skippedCount: skipped,
      failedCount: failed,
      importedKeys: importedKeysOut,
      errors: errors,
    );
  }

  static DateTime? _storedGameTime(Map<String, String> headers) {
    DateTime? parse(String date, String time, {required bool utc}) {
      if (!RegExp(r'^\d{4}[.-]\d{2}[.-]\d{2}$').hasMatch(date)) return null;
      final clock =
          RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(time) ? time : '00:00:00';
      return DateTime.tryParse(
          '${date.replaceAll('.', '-')}T$clock${utc ? 'Z' : ''}');
    }

    return parse(headers['UTCDate'] ?? '', headers['UTCTime'] ?? '',
            utc: true) ??
        parse(headers['Date'] ?? '', headers['Time'] ?? '', utc: false);
  }

  static List<BoardStorageImportItem> _markDuplicates(
    List<BoardStorageStoredGame> games, {
    required Iterable<String> importedKeys,
    required Iterable<String> existingPgnHashes,
  }) {
    final imported = importedKeys.toSet();
    final existing = existingPgnHashes.toSet();
    final seen = <String>{};
    return [
      for (final game in games)
        BoardStorageImportItem(
          game: game,
          duplicate: imported.contains(game.importKey) ||
              (game.pgnHash.isNotEmpty && existing.contains(game.pgnHash)) ||
              !seen.add(game.importKey),
        ),
    ];
  }

  static dc.Position _positionFromBoardFen(
    String boardFen, {
    required bool whiteToMove,
  }) {
    final fullFen =
        '${_boardOnlyFen(boardFen)} ${whiteToMove ? 'w' : 'b'} KQkq - 0 1';
    return dc.Chess.fromSetup(dc.Setup.parseFen(fullFen));
  }

  static dc.Position? _tryPositionFromBoardFen(
    String boardFen, {
    required bool whiteToMove,
  }) {
    try {
      return _positionFromBoardFen(boardFen, whiteToMove: whiteToMove);
    } catch (_) {
      return null;
    }
  }

  static _FenReplay _bestFenReplay(List<String> fens) {
    final firstBoardFen = _boardOnlyFen(fens.first).isNotEmpty
        ? _boardOnlyFen(fens.first)
        : _boardOnlyFen(standardStartFen);
    final reversedFirstBoardFen = _reverseBoardFen(firstBoardFen);
    final candidates = <_FenReplay>[
      ..._fenReplayCandidatesFor(firstBoardFen),
      ..._fenReplayCandidatesFor(reversedFirstBoardFen, reverseInput: true),
    ];
    if (candidates.isEmpty) {
      throw const FormatException('No legal board storage start position.');
    }

    for (final fen in fens) {
      for (final candidate in candidates) {
        candidate.consume(fen);
      }
    }

    return candidates.reduce(
      (best, candidate) =>
          candidate.sanMoves.length > best.sanMoves.length ? candidate : best,
    );
  }

  static List<_FenReplay> _fenReplayCandidatesFor(
    String boardFen, {
    bool reverseInput = false,
  }) {
    return [
      for (final whiteToMove in [true, false])
        if (_tryPositionFromBoardFen(boardFen, whiteToMove: whiteToMove)
            case final position?)
          _FenReplay(
            startFen: '${_boardOnlyFen(boardFen)} '
                '${whiteToMove ? 'w' : 'b'} KQkq - 0 1',
            position: position,
            reverseInput: reverseInput,
          ),
    ];
  }

  static dc.NormalMove? _moveToBoardFen(dc.Position position, String boardFen) {
    final target = _boardOnlyFen(boardFen);
    for (final entry in position.legalMoves.entries) {
      final from = entry.key;
      for (final to in entry.value.squares) {
        for (final promotion in _promotionOptions(position, from, to)) {
          final rawMove =
              dc.NormalMove(from: from, to: to, promotion: promotion);
          final normalizedMove = position.normalizeMove(rawMove);
          if (normalizedMove is! dc.NormalMove) continue;
          final move = normalizedMove;
          if (!position.isLegal(move)) continue;
          final next = position.play(move);
          if (_boardOnlyFen(next.fen) == target) {
            return move;
          }
        }
      }
    }
    return null;
  }

  static Iterable<dc.Role?> _promotionOptions(
    dc.Position position,
    dc.Square from,
    dc.Square to,
  ) {
    final piece = position.board.pieceAt(from);
    if (piece?.role != dc.Role.pawn) return const [null];
    final promotes = to.rank == dc.Rank.first || to.rank == dc.Rank.eighth;
    if (!promotes) return const [null];
    return const [dc.Role.queen, dc.Role.rook, dc.Role.bishop, dc.Role.knight];
  }

  static String _normalizeRawSequence(String raw) {
    return raw
        .replaceAll('\u0000', '')
        .split(';')
        .map(_boardOnlyFen)
        .where((fen) => fen.isNotEmpty)
        .join(';');
  }

  static String _boardOnlyFen(String fen) {
    return fen.trim().split(RegExp(r'\s+')).first;
  }

  static String _reverseBoardFen(String fen) {
    return _boardOnlyFen(fen).split('').reversed.join();
  }

  static bool _looksLikePgn(String raw) {
    final cleaned = raw.replaceAll('\u0000', '').trim();
    if (cleaned.isEmpty) return false;
    if (RegExp(r'^\s*\[[A-Za-z0-9_]+\s+".*"\]\s*$', multiLine: true)
        .hasMatch(cleaned)) {
      return true;
    }
    return RegExp(r'(^|\s)\d+\.(\.\.)?\s*\S+').hasMatch(cleaned);
  }

  static String _ensurePgnHeaders(String raw, {DateTime? importedAt}) {
    final headers = _parsePgnHeaders(raw);
    final moveText = raw
        .split(RegExp(r'\r?\n'))
        .where((line) =>
            !RegExp(r'^\s*\[[A-Za-z0-9_]+\s+".*"\]\s*$').hasMatch(line))
        .join('\n')
        .trim();
    final result =
        _resultFromMoveText(moveText) ?? headers['Result']?.trim() ?? '*';
    final merged = <String, String>{
      'Event': 'Chessnut Board Storage',
      'Site': 'Chessnut App',
      'Date': _pgnDate(importedAt ?? DateTime.now()),
      'Round': '-',
      'White': 'White',
      'Black': 'Black',
      'Result': result,
      'TimeControl': '-',
      ...headers,
    };
    if ((merged['Result'] ?? '').trim().isEmpty) {
      merged['Result'] = result;
    }
    final body = moveText.isEmpty
        ? result
        : _moveTextHasResult(moveText)
            ? moveText
            : '$moveText ${merged['Result']}';
    final buffer = StringBuffer();
    merged.forEach((key, value) {
      buffer.writeln('[$key "${_escapeHeader(value)}"]');
    });
    buffer
      ..writeln()
      ..write(body);
    return buffer.toString();
  }

  static Map<String, String> _parsePgnHeaders(String pgn) {
    final headers = <String, String>{};
    final pattern = RegExp(r'^\s*\[([A-Za-z0-9_]+)\s+"(.*)"\]\s*$');
    for (final line in pgn.split(RegExp(r'\r?\n'))) {
      final match = pattern.firstMatch(line);
      if (match == null) continue;
      headers[match.group(1)!] =
          match.group(2)!.replaceAll(r'\"', '"').replaceAll(r'\\', r'\');
    }
    return headers;
  }

  static String _header(
    Map<String, String> headers,
    String key,
    String fallback,
  ) {
    final value = headers[key]?.trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  static String _normalizeRawPgn(String raw) {
    return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String? _resultFromMoveText(String moveText) {
    final match =
        RegExp(r'(1-0|0-1|1/2-1/2|\*)\s*$').firstMatch(moveText.trim());
    return match?.group(1);
  }

  static bool _moveTextHasResult(String moveText) {
    return _resultFromMoveText(moveText) != null;
  }

  static String _pgnDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String _escapeHeader(String value) {
    return value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  }

  static String _importKey(String normalizedRaw) {
    return 'board-storage:${sha256.convert(utf8.encode(normalizedRaw))}';
  }
}

class _FenReplay {
  _FenReplay({
    required this.startFen,
    required this.position,
    this.reverseInput = false,
  });

  final String startFen;
  dc.Position position;
  final bool reverseInput;
  final List<String> sanMoves = [];

  void consume(String rawFen) {
    final boardFen = reverseInput
        ? BoardStorageImportService._reverseBoardFen(rawFen)
        : BoardStorageImportService._boardOnlyFen(rawFen);
    if (BoardStorageImportService._boardOnlyFen(position.fen) == boardFen) {
      return;
    }
    final move = BoardStorageImportService._moveToBoardFen(position, boardFen);
    if (move == null) return;
    final next = position.makeSan(move);
    position = next.$1;
    sanMoves.add(next.$2);
  }
}

String pgnFingerprint(String pgn) {
  final normalized = pgn
      .replaceAll(
          RegExp(r'^\[(BoardStorageHash|Date|Source)\s+".*"\]\s*$',
              multiLine: true),
          '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return sha256.convert(utf8.encode(normalized)).toString();
}

class BoardStorageStoredGame {
  const BoardStorageStoredGame({
    required this.rawFenSequence,
    required this.importKey,
    required this.pgnHash,
    required this.pgn,
    required this.whiteName,
    required this.blackName,
    required this.gameStep,
    required this.isImportable,
    this.errorMessage = '',
  });

  factory BoardStorageStoredGame.invalid({
    required String rawFenSequence,
    required String importKey,
    required String errorMessage,
  }) {
    return BoardStorageStoredGame(
      rawFenSequence: rawFenSequence,
      importKey: importKey,
      pgnHash: '',
      pgn: '',
      whiteName: 'White',
      blackName: 'Black',
      gameStep: 0,
      isImportable: false,
      errorMessage: errorMessage,
    );
  }

  final String rawFenSequence;
  final String importKey;
  final String pgnHash;
  final String pgn;
  final String whiteName;
  final String blackName;
  final int gameStep;
  final bool isImportable;
  final String errorMessage;
}

class BoardStorageImportItem {
  const BoardStorageImportItem({
    required this.game,
    required this.duplicate,
  });

  final BoardStorageStoredGame game;
  final bool duplicate;

  bool get canImport => game.isImportable && !duplicate;
}

class BoardStorageImportPreview {
  const BoardStorageImportPreview({required this.items});

  final List<BoardStorageImportItem> items;

  int get totalCount => items.length;

  int get importableCount => items.where((item) => item.canImport).length;

  int get duplicateCount => items.where((item) => item.duplicate).length;

  int get invalidCount => items.where((item) => !item.game.isImportable).length;
}

class BoardStorageImportResult {
  const BoardStorageImportResult({
    required this.importedCount,
    required this.skippedCount,
    required this.failedCount,
    required this.importedKeys,
    required this.errors,
  });

  final int importedCount;
  final int skippedCount;
  final int failedCount;
  final Set<String> importedKeys;
  final List<String> errors;
}
