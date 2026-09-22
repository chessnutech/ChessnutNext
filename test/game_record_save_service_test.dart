import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:chessnut_flutter_export/services/chessnut_api_client.dart';
import 'package:chessnut_flutter_export/services/game_record_save_service.dart';
import 'package:chessnut_flutter_export/services/local_game_record_store.dart';
import 'package:chessnut_flutter_export/services/board_storage_import_service.dart';

import 'local_game_record_store_test.dart' show draft, recordedDraft;

const accountA = ChessnutApiSession(userId: 1, token: 'a');
const accountB = ChessnutApiSession(userId: 2, token: 'b');
http.Response uploaded() => http.Response(
    jsonEncode({
      'code': 200,
      'data': {'pgn_id': 99, 's_id': 'share-99'},
    }),
    200);

void main() {
  late LocalGameRecordStore store;
  setUp(() => store = LocalGameRecordStore.inMemory());
  tearDown(() => store.close());

  test('online success saves only remotely; no local game is created',
      () async {
    final requests = <http.Request>[];
    final api = ChessnutApiClient(
        session: accountA,
        httpClient: MockClient((request) async {
          requests.add(request);
          return uploaded();
        }));
    final service = GameRecordSaveService(apiClient: api, localStore: store);
    final result = await service.saveLive(draft(), ownerUserId: 1);
    expect(result.status.isSuccess, isTrue);
    expect(result.savedLocally, isFalse);
    expect(await store.list(), isEmpty);
    expect(requests.single.url.path, '/api/uploadPgn');
    expect(requests.single.bodyFields['client_game_id'], 'game-1');
  });

  test('guest saves locally without any request, even on a healthy network',
      () async {
    var requests = 0;
    final api = ChessnutApiClient(httpClient: MockClient((_) async {
      requests++;
      return uploaded();
    }));
    final service = GameRecordSaveService(apiClient: api, localStore: store);
    final result = await service.saveLive(draft(), ownerUserId: null);
    expect(result.savedLocally, isTrue);
    expect((await store.list()).single.isSynced, isFalse);
    api.session = accountA;
    await Future<void>.delayed(Duration.zero);
    expect(requests, 0,
        reason: 'Signing in must not upload historical local games.');
  });

  test(
      'failed cloud request falls back; active play can recover without uploading history',
      () async {
    var offline = true;
    final requests = <http.Request>[];
    final api = ChessnutApiClient(
        session: accountA,
        httpClient: MockClient((request) async {
          requests.add(request);
          if (offline) throw const SocketException('offline');
          return uploaded();
        }));
    final service = GameRecordSaveService(
        apiClient: api, localStore: store, offlineRetryDelay: Duration.zero);
    await store.saveFallback(draft(id: 'history'), remoteUserId: 1);
    final failed = await service.saveLive(draft(moves: 1), ownerUserId: 1);
    expect(failed.savedLocally, isTrue);
    offline = false;
    final success = await service.saveLive(draft(moves: 2), ownerUserId: 1);
    expect(success.savedLocally, isFalse);
    expect((await store.find('game-1'))!.isSynced, isTrue);
    expect((await store.find('game-1'))!.draft.gameStep, 1,
        reason: 'Cloud success does not replace the local copy.');
    expect((await store.find('history'))!.isSynced, isFalse);
    expect(requests, hasLength(2));
  });

  test('manual upload skips uploaded games and never reads remote lists',
      () async {
    final requests = <http.Request>[];
    final api = ChessnutApiClient(
        session: accountA,
        httpClient: MockClient((request) async {
          requests.add(request);
          return uploaded();
        }));
    final service = GameRecordSaveService(apiClient: api, localStore: store);
    await store.saveFallback(draft(), remoteUserId: null);
    final results = await Future.wait(
        [service.uploadLocal('game-1'), service.uploadLocal('game-1')]);
    expect(results.every((r) => r.status.isSuccess), isTrue);
    expect(results.last.alreadyUploaded, isTrue);
    expect(requests.single.url.path, '/api/uploadPgn');
    final local = (await store.find('game-1'))!;
    expect(local.syncedUserId, 1);
    expect(local.pgnId, 99);
    await store.saveFallback(draft(moves: 1), remoteUserId: null);
    expect((await service.uploadLocal('game-1')).alreadyUploaded, isTrue);
    expect(requests, hasLength(1));
    await store.delete('game-1');
    expect(requests, hasLength(1),
        reason: 'Local deletion must not delete cloud data.');
  });

  test('upload captures its account and the receipt is shared after switching',
      () async {
    final response = Completer<http.Response>();
    final sent = Completer<void>();
    final requests = <http.Request>[];
    final api = ChessnutApiClient(
        session: accountA,
        httpClient: MockClient((request) {
          requests.add(request);
          sent.complete();
          return response.future;
        }));
    final service = GameRecordSaveService(apiClient: api, localStore: store);
    await store.saveFallback(draft(), remoteUserId: 1);
    final upload = service.uploadLocal('game-1');
    await sent.future;
    api.session = accountB;
    response.complete(uploaded());
    expect((await upload).status.isSuccess, isTrue);
    expect(requests.single.bodyFields['user_id'], '1');
    expect((await store.find('game-1'))!.syncedUserId, 1);
    expect((await service.uploadLocal('game-1')).alreadyUploaded, isTrue);
    expect(requests, hasLength(1));
  });

  for (final remoteId in <int?>[null, 42]) {
    test('manual upload after restart preserves original metadata ($remoteId)',
        () async {
      final dir = await Directory.systemTemp.createTemp('record-upload-');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/records.sqlite';
      var diskStore = LocalGameRecordStore(databasePath: () async => path);
      final original = recordedDraft();
      await diskStore.saveFallback(original,
          remoteUserId: remoteId == null ? null : 2, pgnId: remoteId);
      await diskStore.close();
      diskStore = LocalGameRecordStore(databasePath: () async => path);
      addTearDown(diskStore.close);
      final requests = <http.Request>[];
      final api = ChessnutApiClient(
        session: accountB,
        httpClient: MockClient((request) async {
          requests.add(request);
          return uploaded();
        }),
      );
      final service =
          GameRecordSaveService(apiClient: api, localStore: diskStore);
      final result = await service.uploadLocal(original.id);
      expect(result.status.isSuccess, isTrue);
      final request = requests.single;
      expect(request.url.path,
          remoteId == null ? '/api/uploadPgn' : '/api/updatePgn');
      final fields = request.bodyFields;
      expect(fields['white_name'], original.whiteName);
      expect(fields['black_name'], original.blackName);
      expect(fields['play_mode'], original.playMode);
      expect(fields['play_time'], original.playTime);
      expect(fields['time_control'], '15+10');
      expect(fields['speed'], 'rapid');
      expect(fields['player_color'], 'white');
      expect(fields['opponent_name'], 'Original Black');
      expect(fields['game_status'], '2');
      expect(fields['game_step'], '2');
      expect(fields['win_id'], '1');
      expect(fields['pgn'], original.pgn);
      final local = (await diskStore.find(original.id))!;
      expect(local.draft.toJson(), original.toJson());
      expect(local.isSynced, isTrue);
    });
  }

  test('timeout and server rejection retain unsynced local snapshots',
      () async {
    final response = Completer<http.Response>();
    final api = ChessnutApiClient(
        session: accountA, httpClient: MockClient((_) => response.future));
    final service = GameRecordSaveService(
        apiClient: api,
        localStore: store,
        requestTimeout: const Duration(milliseconds: 20));
    expect(
        (await service.saveLive(draft(), ownerUserId: 1)).savedLocally, isTrue);
    expect((await store.find('game-1'))!.isSynced, isFalse);
    response.complete(uploaded());
    await Future<void>.delayed(Duration.zero);
    expect((await store.find('game-1'))!.isSynced, isFalse);
  });

  test('local write failure is surfaced instead of reporting a successful save',
      () async {
    final unavailable = LocalGameRecordStore(
        databasePath: () async => throw const FileSystemException('full'));
    addTearDown(() async {
      try {
        await unavailable.close();
      } catch (_) {}
    });
    final service = GameRecordSaveService(
        apiClient: ChessnutApiClient(), localStore: unavailable);
    final result = await service.saveLive(draft(), ownerUserId: null);
    expect(result.status.isSuccess, isFalse);
    expect(result.status.apiErrorCode, 507);
  });

  test(
      'a rejected or incomplete server response cannot mark a local game synced',
      () async {
    for (final body in [
      {'code': 500, 'info': 'save failed'},
      {
        'code': 200,
        'data': {'pgn_id': 0}
      },
    ]) {
      final api = ChessnutApiClient(
          session: accountA,
          httpClient:
              MockClient((_) async => http.Response(jsonEncode(body), 200)));
      final service = GameRecordSaveService(apiClient: api, localStore: store);
      final result = await service.saveLive(draft(), ownerUserId: 1);
      expect(result.savedLocally, isTrue);
      expect((await store.find('game-1'))!.isSynced, isFalse);
    }
  });

  test('a local game can be continued offline from another account', () async {
    await store.saveFallback(draft(), remoteUserId: 1);
    final api = ChessnutApiClient(
      session: accountB,
      httpClient:
          MockClient((_) async => throw const SocketException('offline')),
    );
    final service = GameRecordSaveService(apiClient: api, localStore: store);
    final result = await service.saveLive(draft(moves: 1), ownerUserId: 2);
    expect(result.status.isSuccess, isTrue);
    expect(result.savedLocally, isTrue);
    expect((await store.find('game-1'))!.draft.gameStep, 1);
    expect(await store.list(), hasLength(1));
  });

  for (final remoteId in <int?>[null, 42]) {
    test('any account can manually upload a shared game ($remoteId)', () async {
      await store.saveFallback(draft(), remoteUserId: 1, pgnId: remoteId);
      final requests = <http.Request>[];
      final api = ChessnutApiClient(
        session: accountB,
        httpClient: MockClient((request) async {
          requests.add(request);
          return uploaded();
        }),
      );
      final service = GameRecordSaveService(apiClient: api, localStore: store);
      expect((await service.uploadLocal('game-1')).status.isSuccess, isTrue);
      expect(requests.single.url.path, '/api/uploadPgn',
          reason: 'A cloud ID from account A must never be updated as B.');
      expect(requests.single.bodyFields['user_id'], '2');
      final local = (await store.find('game-1'))!;
      expect(local.isSynced, isTrue);
      expect(local.syncedUserId, 2);
      expect(local.remoteUserId, 2);
      api.session = accountA;
      expect((await service.uploadLocal('game-1')).alreadyUploaded, isTrue);
      expect(requests, hasLength(1));
    });
  }

  test('shared game continuation saves online under the current account',
      () async {
    await store.saveFallback(draft(), remoteUserId: 1, pgnId: 42);
    final requests = <http.Request>[];
    final api = ChessnutApiClient(
      session: accountB,
      httpClient: MockClient((request) async {
        requests.add(request);
        return uploaded();
      }),
    );
    final service = GameRecordSaveService(apiClient: api, localStore: store);
    final result =
        await service.saveLive(draft(moves: 1), ownerUserId: 2, pgnId: 42);
    expect(result.status.isSuccess, isTrue);
    expect(result.savedLocally, isFalse);
    expect(requests.single.url.path, '/api/uploadPgn');
    expect(requests.single.bodyFields['user_id'], '2');
    await service.saveLive(draft(),
        ownerUserId: 2, pgnId: result.record!.pgnId);
    expect(requests.last.url.path, '/api/updatePgn');
    expect(requests.last.bodyFields['pgn_id'], '99');
  });

  test('board import also falls back locally without a login', () async {
    final api = ChessnutApiClient(
        httpClient: MockClient(
            (_) async => throw StateError('No network request expected')));
    final service = GameRecordSaveService(apiClient: api, localStore: store);
    final importer = BoardStorageImportService(
      apiClient: api,
      recordsProvider: () async => [],
      saveService: service,
    );
    final game =
        BoardStorageImportService.parseStoredGame(rawFenSequence: draft().pgn);
    final result = await importer.importParsed([game]);
    expect(result.importedCount, 1);
    final records = await store.list();
    expect(records, hasLength(1));
    expect(records.single.isSynced, isFalse);
    expect(records.single.draft.gameStatus, 2);
  });

  test('board PGN import retains supplied names, clock and original game time',
      () async {
    final api = ChessnutApiClient();
    final importer = BoardStorageImportService(
      apiClient: api,
      recordsProvider: () async => [],
      saveService: GameRecordSaveService(apiClient: api, localStore: store),
    );
    final pgn = '${recordedDraft().pgn}\n'.replaceFirst('[Time "14:30:00"]',
        '[Time "14:30:00"]\n[UTCDate "2024.01.02"]\n[UTCTime "14:30:00"]');
    final parsed =
        BoardStorageImportService.parseStoredGame(rawFenSequence: pgn);
    expect((await importer.importParsed([parsed])).importedCount, 1);
    final local = (await store.list()).single;
    expect(local.draft.whiteName, 'Original White');
    expect(local.draft.blackName, 'Original Black');
    expect(local.draft.playMode, 'otb');
    expect(local.draft.playTime, recordedDraft().playTime);
    expect(local.draft.metadata.timeControl, '15+10');
    expect(local.draft.pgn, contains('[WhiteTime "885"]'));
  });
}
