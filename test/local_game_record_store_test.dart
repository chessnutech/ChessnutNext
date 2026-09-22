import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chessnut_flutter_export/services/chessnut_api_client.dart';
import 'package:chessnut_flutter_export/services/local_game_record_store.dart';
import 'package:sqlite3/sqlite3.dart';

GameRecordDraft draft(
        {String id = 'game-1', int moves = 2, String result = '*'}) =>
    GameRecordDraft(
      id: id,
      pgn:
          '[ChessnutGameId "$id"]\n[LichessToken "private-token"]\n[White "White"]\n[Black "Black"]\n[Result "$result"]\n\n1. e4${moves > 1 ? ' e5' : ''} $result',
      whiteName: 'White',
      blackName: 'Black',
      playTime: '1700000000',
      playMode: 'otb',
      winId: 0,
      gameStatus: result == '*' ? 1 : 2,
      gameStep: moves,
      result: result,
      savedAt: DateTime.utc(2026, 9, 18),
      metadata:
          PgnSaveMetadata(clientGameId: id, lichessToken: 'private-token'),
    );

GameRecordDraft recordedDraft() => GameRecordDraft(
      id: 'original-game',
      pgn: '[ChessnutGameId "original-game"]\n'
          '[White "Original White"]\n[Black "Original Black"]\n'
          '[Date "2024.01.02"]\n[Time "14:30:00"]\n'
          '[Site "Chessnut App"]\n[TimeControl "15+10"]\n'
          '[WhiteTime "885"]\n[BlackTime "889"]\n'
          '[Result "1-0"]\n\n1. e4 e5 1-0',
      whiteName: 'Original White',
      blackName: 'Original Black',
      playTime:
          (DateTime.utc(2024, 1, 2, 14, 30).millisecondsSinceEpoch ~/ 1000)
              .toString(),
      playMode: 'bot',
      winId: 1,
      gameStatus: 2,
      gameStep: 2,
      result: '1-0',
      savedAt: DateTime.utc(2026, 9, 18),
      metadata: const PgnSaveMetadata(
        clientGameId: 'original-game',
        playerColor: 'white',
        speed: 'rapid',
        timeControl: '15+10',
        opponentName: 'Original Black',
      ),
    );

void main() {
  test('legacy account archives reopen together without losing upload receipts',
      () async {
    final dir = await Directory.systemTemp.createTemp('legacy-local-games-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/records.sqlite';
    final db = sqlite3.open(path);
    db.execute('''CREATE TABLE local_games (
      id TEXT PRIMARY KEY, owner_user_id INTEGER, draft TEXT NOT NULL,
      revision INTEGER NOT NULL, pgn_id INTEGER, share_id TEXT,
      synced_user_id INTEGER, synced_at TEXT, synced_digest TEXT,
      updated_at TEXT NOT NULL
    )''');
    for (final user in [null, 1, 2]) {
      final original = draft(id: 'legacy-$user');
      db.execute('''INSERT INTO local_games
        (id, owner_user_id, draft, revision, pgn_id, synced_user_id,
         synced_at, synced_digest, updated_at)
        VALUES (?, ?, ?, 1, ?, ?, ?, ?, ?)''', [
        original.id,
        user,
        jsonEncode(original.toJson()),
        user == null ? 99 : null,
        user == null ? 3 : null,
        user == null ? original.savedAt.toIso8601String() : null,
        user == null ? original.digest : null,
        original.savedAt.toIso8601String(),
      ]);
    }
    db.execute('PRAGMA user_version = 1');
    db.close();
    final store = LocalGameRecordStore(databasePath: () async => path);
    addTearDown(store.close);
    final records = await store.list();
    expect(records.map((r) => r.id),
        unorderedEquals(['legacy-null', 'legacy-1', 'legacy-2']));
    final synced = records.singleWhere((r) => r.isSynced);
    expect(synced.remoteUserId, 3);
    expect(synced.syncedUserId, 3);
    expect(synced.pgnId, 99);
    expect(synced.changedSinceUpload, isFalse);
  });

  test('fallback survives reopening and never persists credentials', () async {
    final dir = await Directory.systemTemp.createTemp('local-games-test-');
    addTearDown(() => dir.delete(recursive: true));
    final dbPath = '${dir.path}/records.sqlite';
    var store = LocalGameRecordStore(databasePath: () async => dbPath);
    await store.saveFallback(draft(), remoteUserId: null);
    await store.close();
    store = LocalGameRecordStore(databasePath: () async => dbPath);
    final records = await store.list();
    expect(records, hasLength(1));
    expect(records.single.record.canContinueOtbGame, isTrue);
    expect(records.single.draft.pgn, isNot(contains('private-token')));
    expect(records.single.draft.metadata.lichessToken, isNull);
    expect(records.single.record.localRecordId, 'game-1');
    await store.close();
  });

  test('original game metadata survives reopening and determines display date',
      () async {
    final dir = await Directory.systemTemp.createTemp('local-game-metadata-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/records.sqlite';
    var store = LocalGameRecordStore(databasePath: () async => path);
    final original = recordedDraft();
    await store.saveFallback(original, remoteUserId: null);
    await store.close();
    store = LocalGameRecordStore(databasePath: () async => path);
    addTearDown(store.close);
    final saved = (await store.find(original.id))!;
    expect(saved.draft.toJson(), original.toJson());
    expect(saved.record.displayWhiteName, 'Original White');
    expect(saved.record.displayBlackName, 'Original Black');
    expect(saved.record.playMode, 'bot');
    expect(saved.record.timeLabel, '15+10');
    expect(saved.record.dateLabel, '2024-01-02');
    expect(saved.record.sortAt!.toUtc(), DateTime.utc(2024, 1, 2, 14, 30));
    expect(saved.record.pgn, contains('[WhiteTime "885"]'));
    expect(saved.record.pgn, contains('[BlackTime "889"]'));
  });

  test('guests and all accounts share one archive and can continue any game',
      () async {
    final store = LocalGameRecordStore.inMemory();
    addTearDown(store.close);
    await store.saveFallback(draft(id: 'guest'), remoteUserId: null);
    await store.saveFallback(draft(id: 'a'), remoteUserId: 1);
    await store.saveFallback(draft(id: 'b'), remoteUserId: 2);
    expect((await store.list()).map((r) => r.id),
        unorderedEquals(['guest', 'a', 'b']));
    await store.saveFallback(draft(id: 'a', moves: 1), remoteUserId: 2);
    expect((await store.find('a'))!.draft.gameStep, 1);
    expect((await store.find('b'))!.draft.gameStep, 2);
    expect(await store.list(), hasLength(3));
  });

  test(
      'takeback replaces snapshot and upload receipt survives subsequent edits',
      () async {
    final store = LocalGameRecordStore.inMemory();
    addTearDown(store.close);
    await store.saveFallback(draft(), remoteUserId: 1);
    var record = (await store.find('game-1'))!;
    await store.markUploaded(local: record, userId: 1, pgnId: 99);
    record = (await store.find('game-1'))!;
    expect(record.isSynced, isTrue);
    expect(record.changedSinceUpload, isFalse);
    await store.saveFallback(draft(moves: 1), remoteUserId: 2);
    record = (await store.find('game-1'))!;
    expect(record.draft.gameStep, 1);
    expect(record.isSynced, isTrue);
    expect(record.changedSinceUpload, isTrue);
    expect(record.pgnId, 99);
  });

  test('a stale acknowledgement cannot mark a newer snapshot uploaded',
      () async {
    final store = LocalGameRecordStore.inMemory();
    addTearDown(store.close);
    await store.saveFallback(draft(moves: 1), remoteUserId: 1);
    final old = (await store.find('game-1'))!;
    await store.saveFallback(draft(moves: 2), remoteUserId: 1);
    await store.markUploaded(local: old, userId: 1, pgnId: 99);
    expect((await store.find('game-1'))!.isSynced, isFalse);
  });
}
