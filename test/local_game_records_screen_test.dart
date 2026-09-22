import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/screens/game_record_screen.dart';
import 'package:chessnut_flutter_export/screens/local_game_records_screen.dart';
import 'package:chessnut_flutter_export/services/chessnut_api_client.dart';
import 'package:chessnut_flutter_export/services/game_record_save_service.dart';
import 'package:chessnut_flutter_export/services/game_record_repository.dart';
import 'package:chessnut_flutter_export/services/local_game_record_store.dart';
import 'package:chessnut_flutter_export/widgets/chess_board.dart';
import 'package:chessnut_flutter_export/widgets/game_record_tile.dart';

import 'local_game_record_store_test.dart' show draft, recordedDraft;

void main() {
  testWidgets('local games remain visible after logout and account switching',
      (tester) async {
    final store = LocalGameRecordStore.inMemory();
    addTearDown(store.close);
    await store.saveFallback(recordedDraft(), remoteUserId: 1);
    final api = ChessnutApiClient();
    final saver = GameRecordSaveService(apiClient: api, localStore: store);
    for (final userId in <int?>[1, null, 2, 1]) {
      api.session = userId == null
          ? null
          : ChessnutApiSession(userId: userId, token: 'test');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: LocalGameRecordsScreen(
          store: store,
          saveService: saver,
          userId: userId,
          onNavigate: (_) {},
          onReview: (_) {},
        )),
      ));
      await tester.pumpAndSettle();
      expect((await store.find('original-game'))!.remoteUserId, 1);
      expect(find.byKey(const ValueKey('local-game-original-game')),
          findsOneWidget,
          reason: 'Saved games must remain visible for $userId.');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('local archive choice survives leaving and reopening records',
      (tester) async {
    final store = LocalGameRecordStore.inMemory();
    addTearDown(store.close);
    await store.saveFallback(recordedDraft(), remoteUserId: null);
    final api = ChessnutApiClient(
        session: const ChessnutApiSession(userId: 1, token: 'a'));
    final saver = GameRecordSaveService(apiClient: api, localStore: store);
    var showRecords = true;
    late StateSetter updateHost;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
        updateHost = setState;
        return showRecords
            ? GameRecordScreen(
                signedIn: true,
                records: const [],
                localStore: store,
                recordSaveService: saver,
                onNavigate: (_) {},
                onAnalyzeRecord: (_) {},
              )
            : const SizedBox();
      })),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Local games'));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('local-game-original-game')), findsOneWidget);
    updateHost(() => showRecords = false);
    await tester.pumpAndSettle();
    updateHost(() => showRecords = true);
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('local-game-original-game')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
      'guest can open local archive without a cloud session or requests',
      (tester) async {
    final store = LocalGameRecordStore.inMemory();
    addTearDown(store.close);
    await store.saveFallback(draft(), remoteUserId: null);
    var requests = 0;
    final api = ChessnutApiClient(httpClient: MockClient((_) async {
      requests++;
      return http.Response('{}', 500);
    }));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: GameRecordScreen(
      signedIn: false,
      records: const [],
      onNavigate: (_) {},
      onAnalyzeRecord: (_) {},
      localStore: store,
      recordSaveService:
          GameRecordSaveService(apiClient: api, localStore: store),
    ))));
    await tester.pumpAndSettle();
    expect(find.textContaining('White: White'), findsOneWidget);
    expect(find.text('Not synced'), findsOneWidget);
    expect(requests, 0);
    await tester.tap(find.text('Cloud games'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to view records'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('any account can upload and all accounts see the synced receipt',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = LocalGameRecordStore.inMemory();
    addTearDown(store.close);
    await store.saveFallback(draft(), remoteUserId: 1);
    var requests = 0;
    final api = ChessnutApiClient(
      session: const ChessnutApiSession(userId: 2, token: 'b'),
      httpClient: MockClient((request) async {
        expect(request.bodyFields['user_id'], '2');
        requests++;
        return http.Response(
            jsonEncode({
              'code': 200,
              'data': {'pgn_id': 99, 's_id': 's99'}
            }),
            200);
      }),
    );
    Widget app(int userId) => MaterialApp(
            home: Scaffold(
                body: LocalGameRecordsScreen(
          store: store,
          saveService: GameRecordSaveService(apiClient: api, localStore: store),
          userId: userId,
          onNavigate: (_) {},
          onReview: (_) {},
        )));
    await tester.pumpWidget(app(2));
    await tester.pumpAndSettle();
    expect(requests, 0);
    await tester
        .ensureVisible(find.byKey(const ValueKey('local-game-upload-game-1')));
    await tester.tap(find.byKey(const ValueKey('local-game-upload-game-1')));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.text('Synced'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('local-game-upload-game-1')), findsNothing);
    expect(find.textContaining('Uploaded to account 2'), findsOneWidget);
    api.session = const ChessnutApiSession(userId: 1, token: 'a');
    await tester.pumpWidget(app(1));
    await tester.pumpAndSettle();
    expect(find.text('Synced'), findsOneWidget);
    expect(find.textContaining('Uploaded to account 2'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('local-game-upload-game-1')), findsNothing);
    expect(requests, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final switchWhileUploading in [false, true]) {
    testWidgets(
        'upload refreshes cloud records immediately (switch tab: $switchWhileUploading)',
        (tester) async {
      final store = LocalGameRecordStore.inMemory();
      addTearDown(store.close);
      final original = recordedDraft();
      await store.saveFallback(original, remoteUserId: 1);
      final response = Completer<http.Response>();
      final api = ChessnutApiClient(
        session: const ChessnutApiSession(userId: 1, token: 'a'),
        httpClient: MockClient((_) => response.future),
      );
      final saver = GameRecordSaveService(apiClient: api, localStore: store);
      var refreshes = 0;
      var cloudRecords = <GameRecord>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
          return GameRecordScreen(
            signedIn: true,
            records: cloudRecords,
            localStore: store,
            localUserId: 1,
            recordSaveService: saver,
            onNavigate: (_) {},
            onAnalyzeRecord: (_) {},
            onRefresh: () async {
              refreshes++;
              setState(() => cloudRecords = [original.toRecord(pgnId: 99)]);
            },
          );
        })),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Local games'));
      await tester.pumpAndSettle();
      expect(refreshes, 0);
      await tester
          .tap(find.byKey(const ValueKey('local-game-upload-original-game')));
      await tester.pump();
      if (switchWhileUploading) {
        await tester.tap(find.text('Cloud games'));
        await tester.pumpAndSettle();
      }
      response.complete(http.Response(
          jsonEncode({
            'code': 200,
            'data': {'pgn_id': 99}
          }),
          200));
      await tester.pumpAndSettle();
      expect(refreshes, 1);
      if (!switchWhileUploading) {
        await tester.tap(find.text('Cloud games'));
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('White: Original White'), findsOneWidget);
      expect(find.byKey(const ValueKey('game-record-context-target-pgn:99')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('upload also refreshes retained cloud search results',
      (tester) async {
    final store = LocalGameRecordStore.inMemory();
    addTearDown(store.close);
    final original = recordedDraft();
    await store.saveFallback(original, remoteUserId: 1);
    var uploaded = false;
    var refreshes = 0;
    var searches = 0;
    final api = ChessnutApiClient(
      session: const ChessnutApiSession(userId: 1, token: 'a'),
      httpClient: MockClient((_) async {
        uploaded = true;
        return http.Response(
            jsonEncode({
              'code': 200,
              'data': {'pgn_id': 99}
            }),
            200);
      }),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: GameRecordScreen(
        signedIn: true,
        records: const [],
        localStore: store,
        localUserId: 1,
        recordSaveService:
            GameRecordSaveService(apiClient: api, localStore: store),
        onNavigate: (_) {},
        onAnalyzeRecord: (_) {},
        onRefresh: () async {
          refreshes++;
        },
        onSearchRemoteRecords: (_, page, count) async {
          searches++;
          return GameRecordRemoteSearchResult(
            status: const ApiStatus.success(),
            records: uploaded ? [original.toRecord(pgnId: 99)] : const [],
            page: page,
            count: count,
          );
        },
      )),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-record-source-local')));
    await tester.pumpAndSettle();
    expect(searches, 1);
    await tester.tap(find.text('Local games'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('local-game-upload-original-game')));
    await tester.pumpAndSettle();
    expect(refreshes, 1);
    expect(searches, 2);
    await tester.tap(find.text('Cloud games'));
    await tester.pumpAndSettle();
    expect(find.textContaining('White: Original White'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final successes in [0, 1, 2]) {
    testWidgets('batch with $successes successful uploads refreshes only once',
        (tester) async {
      final store = LocalGameRecordStore.inMemory();
      addTearDown(store.close);
      await store.saveFallback(draft(id: 'one'), remoteUserId: 1);
      await store.saveFallback(draft(id: 'two'), remoteUserId: 2);
      var requests = 0;
      var refreshes = 0;
      final api = ChessnutApiClient(
        session: const ChessnutApiSession(userId: 1, token: 'a'),
        httpClient: MockClient((_) async {
          requests++;
          return requests <= successes
              ? http.Response(
                  jsonEncode({
                    'code': 200,
                    'data': {'pgn_id': requests}
                  }),
                  200)
              : http.Response('{"code":500,"info":"Upload failed"}', 200);
        }),
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: LocalGameRecordsScreen(
          store: store,
          saveService: GameRecordSaveService(apiClient: api, localStore: store),
          userId: 1,
          onNavigate: (_) {},
          onReview: (_) {},
          onUploaded: () async {
            refreshes++;
          },
        )),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('local-games-select-all')));
      await tester.pump();
      await tester
          .tap(find.byKey(const ValueKey('local-games-upload-selected')));
      await tester.pumpAndSettle();
      expect(requests, successes == 0 ? 1 : 2);
      expect(refreshes, successes == 0 ? 0 : 1);
      expect(
          (await store.list()).where((r) => r.isSynced), hasLength(successes));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('batch deletes only selected local games after confirmation',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = LocalGameRecordStore.inMemory();
    addTearDown(store.close);
    for (final id in ['one', 'two', 'three']) {
      await store.saveFallback(draft(id: id), remoteUserId: null);
    }
    final api = ChessnutApiClient();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LocalGameRecordsScreen(
          store: store,
          saveService: GameRecordSaveService(apiClient: api, localStore: store),
          userId: null,
          onNavigate: (_) {},
          onReview: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('local-games-select-all')));
    await tester.pump();
    await tester
        .tap(find.byKey(const ValueKey('game-record-select-local-two')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('local-games-delete-selected')));
    await tester.pumpAndSettle();

    expect(find.text('Delete selected records?'), findsOneWidget);
    expect(await store.list(), hasLength(3));
    await tester
        .tap(find.byKey(const ValueKey('local-games-delete-dialog-confirm')));
    await tester.pumpAndSettle();

    final remaining = await store.list();
    expect(remaining.map((record) => record.id), ['two']);
    expect(find.byKey(const ValueKey('local-game-one')), findsNothing);
    expect(find.byKey(const ValueKey('local-game-two')), findsOneWidget);
    expect(find.byKey(const ValueKey('local-game-three')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets('local list uses online layout and original metadata at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = LocalGameRecordStore.inMemory();
      addTearDown(store.close);
      final original = recordedDraft();
      await store.saveFallback(original, remoteUserId: null);
      final api = ChessnutApiClient();
      var reviewed = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LocalGameRecordsScreen(
            store: store,
            saveService:
                GameRecordSaveService(apiClient: api, localStore: store),
            userId: null,
            onNavigate: (_) {},
            onReview: (record) {
              reviewed = true;
              expect(record.pgn, original.pgn);
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final tile = find.byType(GameRecordTile);
      expect(tile, findsOneWidget);
      expect(find.descendant(of: tile, matching: find.byType(ChessBoard)),
          findsOneWidget);
      expect(find.textContaining('White: Original White'), findsOneWidget);
      expect(find.textContaining('Black: Original Black'), findsOneWidget);
      expect(find.text('Bot / Time: 15+10'), findsOneWidget);
      expect(find.text('Date: 2024-01-02'), findsOneWidget);
      expect(find.text('Location: Chessnut App'), findsOneWidget);
      expect(find.text('Result: Original White wins'), findsOneWidget);
      expect(find.text('Not synced'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(ChessBoard));
      expect(reviewed, isTrue);
      await tester.tap(
          find.byKey(const ValueKey('game-record-more-local-original-game')));
      await tester.pumpAndSettle();
      expect(find.text('Copy PGN'), findsOneWidget);
      expect(find.text('Delete record'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
