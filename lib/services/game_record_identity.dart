import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/app_models.dart';
import 'game_notation_service.dart';

/// The stable identities used to decide whether two saved games are the same.
///
/// Platform identifiers are preferred because two short games can legitimately
/// have the same moves. The PGN fingerprint is retained as a fallback for an
/// analysis copy that lost its platform metadata.
class GameRecordIdentity {
  const GameRecordIdentity({
    required this.lichessGameId,
    required this.chessnutGameId,
    required this.pgnFingerprint,
  });

  factory GameRecordIdentity.fromRecord(GameRecord record) {
    return GameRecordIdentity.fromPgn(
      record.pgn,
      lichessGameId: record.lichessGameId,
      chessnutGameId: record.chessnutGameId,
    );
  }

  factory GameRecordIdentity.fromPgn(
    String pgn, {
    String? lichessGameId,
    String? chessnutGameId,
  }) {
    final headers = _pgnHeaders(pgn);
    final explicitLichessGameId = lichessGameId?.trim() ?? '';
    final explicitChessnutGameId = chessnutGameId?.trim() ?? '';
    return GameRecordIdentity(
      lichessGameId: _normalizeId(
        explicitLichessGameId.isNotEmpty
            ? explicitLichessGameId
            : headers['LichessGameId'] ?? '',
      ),
      chessnutGameId: _normalizeId(
        explicitChessnutGameId.isNotEmpty
            ? explicitChessnutGameId
            : headers['ChessnutGameId'] ?? '',
      ),
      pgnFingerprint: normalizedPgnFingerprint(pgn),
    );
  }

  final String lichessGameId;
  final String chessnutGameId;
  final String pgnFingerprint;

  String get primaryKey {
    if (lichessGameId.isNotEmpty) return 'lichess:$lichessGameId';
    if (chessnutGameId.isNotEmpty) return 'chessnut:$chessnutGameId';
    return 'pgn:$pgnFingerprint';
  }

  bool matches(GameRecordIdentity other) {
    // If both records have the same platform identity, it is authoritative.
    if (lichessGameId.isNotEmpty && other.lichessGameId.isNotEmpty) {
      return lichessGameId == other.lichessGameId;
    }
    if (chessnutGameId.isNotEmpty && other.chessnutGameId.isNotEmpty) {
      return chessnutGameId == other.chessnutGameId;
    }
    // This covers analysis records whose custom headers were stripped by the
    // backend while retaining the same game PGN.
    return pgnFingerprint.isNotEmpty && pgnFingerprint == other.pgnFingerprint;
  }
}

String normalizedPgnFingerprint(String pgn) {
  final text = pgn.trim();
  if (text.isEmpty) return '';

  String canonical;
  try {
    final parsed = GameNotationService.parsePgn(text);
    canonical = [
      for (final header in const [
        'Site',
        'Date',
        'UTCDate',
        'UTCTime',
        'White',
        'Black',
        'TimeControl',
        'Variant',
      ])
        '$header:${_normalizeFingerprintValue(parsed.headers[header] ?? '')}',
      parsed.initialFen.trim().replaceAll(RegExp(r'\s+'), ' '),
      parsed.moves.map((move) => move.uci).join(' '),
      parsed.result.trim(),
    ].join('|');
  } catch (_) {
    canonical = text.replaceAll(RegExp(r'\s+'), ' ');
  }
  return sha1.convert(utf8.encode(canonical)).toString();
}

String _normalizeId(String value) => value.trim().toLowerCase();

String _normalizeFingerprintValue(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

Map<String, String> _pgnHeaders(String pgn) {
  final headers = <String, String>{};
  final pattern = RegExp(r'^\[([A-Za-z0-9_]+)\s+"(.*)"\]$', multiLine: true);
  for (final match in pattern.allMatches(pgn)) {
    headers[match.group(1)!] = match.group(2)!.replaceAll(r'\"', '"');
  }
  return headers;
}
