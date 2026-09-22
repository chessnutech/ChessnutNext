import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/screens/game_room_screen.dart';
import 'package:chessnut_flutter_export/services/chess_clock_switch_service.dart';
import 'package:chessnut_flutter_export/services/chessnut_api_client.dart';
import 'package:chessnut_flutter_export/services/game_record_save_service.dart';
import 'package:chessnut_flutter_export/services/local_game_record_store.dart';
import 'package:chessnut_flutter_export/theme/chessnut_theme.dart';
import 'package:chessnut_flutter_export/widgets/chess_board.dart';

import 'local_game_record_store_test.dart' show draft, recordedDraft;

void main() {
  testWidgets(
      'another account can resume a local game and save new moves online',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = LocalGameRecordStore.inMemory();
    addTearDown(store.close);
    await store.saveFallback(draft(), remoteUserId: 1, pgnId: 42);
    final local = (await store.find('game-1'))!;
    final requests = <http.Request>[];
    final api = ChessnutApiClient(
      session: const ChessnutApiSession(userId: 2, token: 'b'),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
            jsonEncode({
              'code': 200,
              'data': {'pgn_id': 99},
            }),
            200);
      }),
    );
    final saver = GameRecordSaveService(apiClient: api, localStore: store);
    final clock = ChessClockSwitchService(enableUsbButtons: false);
    addTearDown(clock.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: ChessnutTheme.light(),
      home: Scaffold(
          body: GameRoomScreen(
        onNavigate: (_) {},
        mode: GameLaunchMode.otb,
        apiClient: api,
        recordSaveService: saver,
        initialLocalRecord: local,
        initialPgnId: 42,
        otbConfig: OtbGameConfig(
            timeMinutes: 10, incrementSeconds: 0, resumePgn: local.record.pgn),
        clockSwitchService: clock,
      )),
    ));
    await tester.pumpAndSettle();
    await _move(tester, 'g1', 'f3');
    await saver.idle;
    expect(requests, isNotEmpty);
    expect(requests.first.url.path, '/api/uploadPgn');
    expect(requests.every((r) => r.bodyFields['user_id'] == '2'), isTrue);
    expect(requests.every((r) => r.bodyFields['pgn_id'] != '42'), isTrue);
    expect(requests.last.bodyFields['game_step'], '3');
    expect(requests.last.bodyFields['client_game_id'], local.id);
    expect((await store.find(local.id))!.syncedUserId, 2);
    expect(await store.list(), hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
      'guest OTB saves each move and resumes the same game after recreation',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = LocalGameRecordStore.inMemory();
    addTearDown(store.close);
    final api = ChessnutApiClient();
    final service = GameRecordSaveService(apiClient: api, localStore: store);
    final clock = ChessClockSwitchService(enableUsbButtons: false);
    addTearDown(clock.dispose);
    Widget app({LocalGameRecord? local}) => MaterialApp(
          theme: ChessnutTheme.light(),
          home: Scaffold(
              body: GameRoomScreen(
            onNavigate: (_) {},
            mode: GameLaunchMode.otb,
            apiClient: api,
            recordSaveService: service,
            initialLocalRecord: local,
            otbConfig: OtbGameConfig(
                timeMinutes: 10,
                incrementSeconds: 0,
                resumePgn: local?.record.pgn),
            clockSwitchService: clock,
          )),
        );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await _move(tester, 'e2', 'e4');
    await _move(tester, 'e7', 'e5');
    await service.idle;
    var records = await store.list();
    expect(records, hasLength(1));
    expect(records.single.draft.gameStep, 2);
    expect(records.single.isSynced, isFalse);
    final id = records.single.id;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(local: records.single));
    await tester.pumpAndSettle();
    expect(find.text('e4'), findsOneWidget);
    expect(find.text('e5'), findsOneWidget);
    await _move(tester, 'g1', 'f3');
    await service.idle;
    records = await store.list();
    expect(records, hasLength(1));
    expect(records.single.id, id);
    expect(records.single.draft.gameStep, 3);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('resuming a local bot game preserves its players and start time',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = LocalGameRecordStore.inMemory();
    addTearDown(store.close);
    final original = recordedDraft();
    final draft = GameRecordDraft.fromJson({
      ...original.toJson(),
      'pgn': original.pgn.replaceAll('1-0', '*'),
      'result': '*',
      'win_id': 0,
      'game_status': 1,
    });
    await store.saveFallback(draft, remoteUserId: null);
    final local = (await store.find(draft.id))!;
    final api = ChessnutApiClient();
    final saver = GameRecordSaveService(apiClient: api, localStore: store);
    final clock = ChessClockSwitchService(enableUsbButtons: false);
    addTearDown(clock.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: ChessnutTheme.light(),
      home: Scaffold(
        body: GameRoomScreen(
          onNavigate: (_) {},
          mode: GameLaunchMode.bot,
          apiClient: api,
          recordSaveService: saver,
          initialLocalRecord: local,
          botConfig: const BotGameConfig.defaultConfig().copyWith(
            resumePgn: local.record.pgn,
            timeMinutes: 15,
            incrementSeconds: 10,
          ),
          clockSwitchService: clock,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await _move(tester, 'g1', 'f3');
    await saver.idle;
    final saved = (await store.find(draft.id))!.draft;
    expect(saved.gameStep, 3);
    expect(saved.whiteName, original.whiteName);
    expect(saved.blackName, original.blackName);
    expect(saved.playTime, original.playTime);
    expect(saved.metadata.timeControl, '15+10');
    expect(saved.pgn, contains('[White "Original White"]'));
    expect(saved.pgn, contains('[Black "Original Black"]'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

Future<void> _move(WidgetTester tester, String from, String to) async {
  final rect = tester.getRect(find.byType(InteractiveChessBoard).first);
  Offset square(String name) => Offset(
        rect.left + ('abcdefgh'.indexOf(name[0]) + 0.5) * rect.width / 8,
        rect.top + (8 - int.parse(name[1]) + 0.5) * rect.width / 8,
      );
  await tester.tapAt(square(from));
  await tester.pump();
  await tester.tapAt(square(to));
  await tester.pumpAndSettle();
}
