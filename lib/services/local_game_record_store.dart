import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/app_models.dart';
import 'chessnut_api_client.dart';

/// One immutable game snapshot. Credentials are never written to the archive.
class GameRecordDraft {
  const GameRecordDraft({
    required this.id,
    required this.pgn,
    required this.whiteName,
    required this.blackName,
    required this.playTime,
    required this.playMode,
    required this.winId,
    required this.gameStatus,
    required this.gameStep,
    required this.result,
    required this.savedAt,
    this.metadata = const PgnSaveMetadata(),
  });

  final String id;
  final String pgn;
  final String whiteName;
  final String blackName;
  final String playTime;
  final String playMode;
  final int winId;
  final int gameStatus;
  final int gameStep;
  final String result;
  final DateTime savedAt;
  final PgnSaveMetadata metadata;

  /// The original game time, independent of later saves or manual uploads.
  DateTime? get playedAt {
    final timestamp = int.tryParse(playTime);
    if (timestamp != null) {
      final milliseconds =
          timestamp.abs() < 100000000000 ? timestamp * 1000 : timestamp;
      if (milliseconds.abs() <= 8640000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(milliseconds);
      }
      return null;
    }
    return DateTime.tryParse(playTime)?.toLocal();
  }

  String get archivePgn => pgn.replaceAll(
        RegExp(r'^\[LichessToken\s+".*"\]\s*\n?', multiLine: true),
        '',
      );

  String get digest => sha256
      .convert(utf8.encode(jsonEncode({
        ...toJson()..remove('saved_at'),
      })))
      .toString();

  GameRecord toRecord({int? pgnId, String? shareId, bool local = false}) =>
      GameRecord(
        result: result,
        title: '$whiteName vs $blackName',
        subtitle: '$playMode / $gameStep moves',
        pgn: archivePgn,
        localRecordId: local ? id : '',
        pgnId: pgnId,
        shareId: shareId,
        playMode: playMode,
        gameStatus: gameStatus,
        gameStep: gameStep,
        winId: winId,
        whiteName: whiteName,
        blackName: blackName,
        sortAt: playedAt,
        chessnutGameIdOverride: id,
        lichessGameIdOverride: metadata.lichessGameId ?? '',
        lichessNameOverride: metadata.lichessName ?? '',
        playerColorOverride: metadata.playerColor ?? '',
        speedOverride: metadata.speed ?? '',
        timeControlOverride: metadata.timeControl ?? '',
        opponentNameOverride: metadata.opponentName ?? '',
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'pgn': archivePgn,
        'white_name': whiteName,
        'black_name': blackName,
        'play_time': playTime,
        'play_mode': playMode,
        'win_id': winId,
        'game_status': gameStatus,
        'game_step': gameStep,
        'result': result,
        'saved_at': savedAt.toIso8601String(),
        'metadata': {...metadata.toFields()}..remove('lichess_token'),
      };

  factory GameRecordDraft.fromJson(Map<String, dynamic> json) {
    final metadata = (json['metadata'] as Map).cast<String, dynamic>();
    return GameRecordDraft(
      id: json['id'] as String,
      pgn: json['pgn'] as String,
      whiteName: json['white_name'] as String,
      blackName: json['black_name'] as String,
      playTime: json['play_time'] as String,
      playMode: json['play_mode'] as String,
      winId: json['win_id'] as int,
      gameStatus: json['game_status'] as int,
      gameStep: json['game_step'] as int,
      result: json['result'] as String,
      savedAt: DateTime.parse(json['saved_at'] as String),
      metadata: PgnSaveMetadata(
        clientGameId: json['id'] as String,
        lichessGameId: metadata['lichess_game_id'] as String?,
        lichessName: metadata['lichess_name'] as String?,
        playerColor: metadata['player_color'] as String?,
        speed: metadata['speed'] as String?,
        timeControl: metadata['time_control'] as String?,
        opponentName: metadata['opponent_name'] as String?,
      ),
    );
  }
}

class LocalGameRecord {
  const LocalGameRecord({
    required this.draft,
    required this.remoteUserId,
    required this.revision,
    this.pgnId,
    this.shareId,
    this.syncedUserId,
    this.syncedAt,
    this.syncedDigest,
  });

  final GameRecordDraft draft;

  /// Account associated with [pgnId], never a local access restriction.
  final int? remoteUserId;
  final int revision;
  final int? pgnId;
  final String? shareId;
  final int? syncedUserId;
  final DateTime? syncedAt;
  final String? syncedDigest;

  String get id => draft.id;
  bool get isSynced => syncedAt != null;
  bool get changedSinceUpload => isSynced && syncedDigest != draft.digest;
  GameRecord get record =>
      draft.toRecord(pgnId: pgnId, shareId: shareId, local: true);
}

/// A separate, durable fallback archive. It never downloads or uploads games.
/// The database contains whole snapshots, so a takeback replaces the previous
/// snapshot even when the move count decreases.
class LocalGameRecordStore extends ChangeNotifier {
  LocalGameRecordStore({Future<String> Function()? databasePath})
      : _databasePath = databasePath ?? _defaultPath;

  LocalGameRecordStore.inMemory() : _databasePath = (() async => ':memory:');

  final Future<String> Function() _databasePath;
  Future<Database>? _databaseFuture;
  Database? _openedDatabase;
  bool _closed = false;

  static Future<String> _defaultPath() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return '${dir.path}${Platform.pathSeparator}local_game_records.sqlite';
  }

  Future<Database> _database() {
    if (_closed) throw StateError('Local game archive is closed.');
    return _databaseFuture ??= _open();
  }

  Future<Database> _open() async {
    final db = sqlite3.open(await _databasePath());
    db.execute('PRAGMA busy_timeout = 5000');
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('PRAGMA synchronous = FULL');
    db.execute('''CREATE TABLE IF NOT EXISTS local_games (
      id TEXT PRIMARY KEY,
      owner_user_id INTEGER,
      draft TEXT NOT NULL,
      revision INTEGER NOT NULL,
      pgn_id INTEGER,
      share_id TEXT,
      synced_user_id INTEGER,
      synced_at TEXT,
      synced_digest TEXT,
      updated_at TEXT NOT NULL
    )''');
    // Keep the legacy column so existing archives remain readable. Its only
    // purpose is to associate a cloud ID with the account that can update it.
    if ((db.select('PRAGMA user_version').first.values.first as int) < 2) {
      db.execute('''UPDATE local_games SET owner_user_id = synced_user_id
        WHERE synced_user_id IS NOT NULL''');
      db.execute('PRAGMA user_version = 2');
    }
    _openedDatabase = db;
    return db;
  }

  /// All users, including guests, share the same device archive.
  Future<List<LocalGameRecord>> list() async {
    final db = await _database();
    return db
        .select('SELECT * FROM local_games ORDER BY updated_at DESC, id')
        .map(_decode)
        .toList();
  }

  Future<LocalGameRecord?> find(String id) async {
    final db = await _database();
    final rows = db.select('SELECT * FROM local_games WHERE id = ?', [id]);
    return rows.isEmpty ? null : _decode(rows.first);
  }

  /// Online saving must not wait for the archive directory/plugin to open.
  /// App startup, local continuation and fallback writes open it beforehand.
  LocalGameRecord? peek(String id) {
    final db = _openedDatabase;
    if (db == null || _closed) return null;
    final rows = db.select('SELECT * FROM local_games WHERE id = ?', [id]);
    return rows.isEmpty ? null : _decode(rows.first);
  }

  Future<void> saveFallback(
    GameRecordDraft draft, {
    int? remoteUserId,
    int? pgnId,
    String? shareId,
  }) async {
    final db = await _database();
    // A single statement is atomic. Preserve the upload receipt across edits
    // and account changes; a new cloud reference carries its own account.
    db.execute('''INSERT INTO local_games
      (id, owner_user_id, draft, revision, pgn_id, share_id, updated_at)
      VALUES (?, ?, ?, 1, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        draft = excluded.draft,
        revision = local_games.revision + 1,
        owner_user_id = CASE WHEN excluded.pgn_id IS NOT NULL
          THEN excluded.owner_user_id ELSE local_games.owner_user_id END,
        pgn_id = COALESCE(excluded.pgn_id, local_games.pgn_id),
        share_id = COALESCE(excluded.share_id, local_games.share_id),
        updated_at = excluded.updated_at''', [
      draft.id,
      remoteUserId,
      jsonEncode(draft.toJson()),
      pgnId,
      shareId,
      draft.savedAt.toUtc().toIso8601String(),
    ]);
    notifyListeners();
  }

  /// Marks only the local revision covered by this successful request. It does
  /// not create a local copy of an online game or overwrite the local PGN.
  Future<void> markUploaded({
    required LocalGameRecord local,
    required int userId,
    required int pgnId,
    String? shareId,
  }) async {
    final db = await _database();
    db.execute(
        '''UPDATE local_games SET pgn_id = ?, share_id = ?, owner_user_id = ?,
      synced_user_id = ?, synced_at = ?, synced_digest = ?
      WHERE id = ? AND revision = ?''',
        [
          pgnId,
          shareId,
          userId,
          userId,
          DateTime.now().toUtc().toIso8601String(),
          local.draft.digest,
          local.id,
          local.revision,
        ]);
    notifyListeners();
  }

  Future<void> delete(String id) => deleteMany([id]);

  Future<void> deleteMany(Iterable<String> ids) async {
    final uniqueIds = ids.toSet();
    if (uniqueIds.isEmpty) return;
    final db = await _database();
    final placeholders = List.filled(uniqueIds.length, '?').join(', ');
    db.execute(
      'DELETE FROM local_games WHERE id IN ($placeholders)',
      uniqueIds.toList(),
    );
    notifyListeners();
  }

  static LocalGameRecord _decode(Row row) => LocalGameRecord(
        draft: GameRecordDraft.fromJson(
          jsonDecode(row['draft'] as String) as Map<String, dynamic>,
        ),
        remoteUserId: row['owner_user_id'] as int?,
        revision: row['revision'] as int,
        pgnId: row['pgn_id'] as int?,
        shareId: row['share_id'] as String?,
        syncedUserId: row['synced_user_id'] as int?,
        syncedAt: DateTime.tryParse(row['synced_at'] as String? ?? ''),
        syncedDigest: row['synced_digest'] as String?,
      );

  Future<void> close() async {
    final opening = _databaseFuture;
    if (_closed) return;
    _closed = true;
    final opened = _openedDatabase;
    if (opened != null) {
      opened.close();
    } else if (opening != null) {
      (await opening).close();
    }
    dispose();
  }
}
