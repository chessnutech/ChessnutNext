import 'dart:async';
import 'dart:ui';

import 'package:chessnut_flutter_export/services/android_accessibility_vision_service.dart';
import 'package:chessnut_flutter_export/services/board_settings_service.dart';
import 'package:chessnut_flutter_export/services/board_vision_recognizer.dart';
import 'package:chessnut_flutter_export/services/physical_board_gateway.dart';
import 'package:chessnut_flutter_export/services/physical_board_protocol.dart';
import 'package:chessnut_flutter_export/services/widget_vision_play_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('changing the app language refreshes an active Vision notification',
      () async {
    final gateway = MemoryPhysicalBoardGateway();
    addTearDown(gateway.dispose);
    await gateway.connect();
    final bridge = _FakeAccessibilityVisionBridge();
    final service = _testVisionPlayService(
      boardGatewayProvider: () => gateway,
      accessibilityService: bridge,
      interval: const Duration(days: 1),
    );
    for (final language in ['en', 'zh-CN', 'zh-Hant', 'ar', 'system']) {
      service.update(
        enabled: true,
        boardConnected: true,
        lifecycleState: AppLifecycleState.paused,
        languageTag: language,
      );
      expect(bridge.notificationLanguages.last, language);
      expect(bridge.notificationStates.last, (true, true, true));
    }
    expect(bridge.notificationLanguages, hasLength(5));
    service.update(
      enabled: false,
      boardConnected: true,
      lifecycleState: AppLifecycleState.resumed,
      languageTag: 'fr',
    );
    expect(bridge.notificationLanguages.last, 'fr');
    expect(bridge.notificationStates.last, (false, false, false));
    await service.dispose();
  });

  test('Vision notification follows enable, background, disconnect and disable',
      () async {
    final gateway = MemoryPhysicalBoardGateway();
    addTearDown(gateway.dispose);
    final bridge = _FakeAccessibilityVisionBridge();
    final service = _testVisionPlayService(
      boardGatewayProvider: () => gateway,
      accessibilityService: bridge,
      interval: const Duration(days: 1),
    );
    addTearDown(service.dispose);

    service.update(
        enabled: true,
        boardConnected: false,
        lifecycleState: AppLifecycleState.resumed);
    expect(bridge.notificationStates.last, (true, false, false));
    await gateway.connect();
    service.update(
        enabled: true,
        boardConnected: true,
        lifecycleState: AppLifecycleState.resumed);
    expect(bridge.notificationStates.last, (true, false, true));
    service.update(
        enabled: true,
        boardConnected: true,
        lifecycleState: AppLifecycleState.paused,
        recognitionOnly: true);
    expect(bridge.notificationStates.last, (true, true, true));
    final notifications = bridge.notificationStates.length;
    service.update(
        enabled: true,
        boardConnected: true,
        lifecycleState: AppLifecycleState.paused,
        recognitionOnly: false);
    expect(bridge.notificationStates, hasLength(notifications),
        reason: 'Mode changes should not post duplicate status notifications.');
    service.update(
        enabled: true,
        boardConnected: true,
        lifecycleState: AppLifecycleState.resumed);
    expect(bridge.notificationStates.last, (true, false, true));
    await gateway.disconnect();
    service.update(
        enabled: true,
        boardConnected: false,
        lifecycleState: AppLifecycleState.paused);
    expect(bridge.notificationStates.last, (true, false, false));
    service.update(
        enabled: false,
        boardConnected: false,
        lifecycleState: AppLifecycleState.paused);
    expect(bridge.notificationStates.last, (false, false, false));
  });

  test('disposing during recognition clears the notification permanently',
      () async {
    final gateway = MemoryPhysicalBoardGateway();
    await gateway.connect();
    addTearDown(gateway.dispose);
    final bridge = _ControlledAccessibilityVisionBridge();
    final service = _testVisionPlayService(
      boardGatewayProvider: () => gateway,
      accessibilityService: bridge,
      interval: const Duration(days: 1),
    );
    service.update(
        enabled: true,
        boardConnected: true,
        lifecycleState: AppLifecycleState.paused);
    await _waitUntil(() => bridge.recognitionCalls == 1);
    expect(bridge.notificationStates.last, (true, true, true));
    await service.dispose();
    expect(bridge.notificationStates.last, (false, false, false));
    final notifications = bridge.notificationStates.length;
    bridge.completeAll('{}');
    await Future<void>.delayed(Duration.zero);
    service.update(
        enabled: true,
        boardConnected: true,
        lifecycleState: AppLifecycleState.paused);
    expect(bridge.notificationStates, hasLength(notifications));
  });

  test('VisionRecognitionResult parses board FEN and positions', () {
    final result = VisionRecognitionResult.tryParse(
      '{"fen":"8/8/8/8/4P3/8/8/8","position":[{"x":1,"y":2,"w":3,"h":4,"label":"e4","prob":0.9}]}',
    );

    expect(result, isNotNull);
    expect(result!.fen, '8/8/8/8/4P3/8/8/8');
    expect(result.positions.single.rect, const Rect.fromLTWH(1, 2, 3, 4));
    expect(result.positions.single.label, 'e4');
  });

  test('fast recognition waits for the remainder of the interval', () async {
    const fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR';
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.move,
    );
    await gateway.connect();
    final bridge = _ControlledAccessibilityVisionBridge();
    final service = _testVisionPlayService(
      boardGatewayProvider: () => gateway,
      accessibilityService: bridge,
      interval: const Duration(milliseconds: 100),
    );

    service.update(
      enabled: true,
      boardConnected: true,
      lifecycleState: AppLifecycleState.paused,
    );
    await _waitUntil(() => bridge.recognitionCalls == 1);
    expect(bridge.recognitionCalls, 1);

    await Future<void>.delayed(const Duration(milliseconds: 10));
    bridge.completeNext(_visionBoardJson(fen));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(bridge.recognitionCalls, 1);

    await _waitUntil(() => bridge.recognitionCalls == 2);
    expect(bridge.recognitionCalls, 2);

    await service.dispose();
    bridge.completeAll(_visionBoardJson(fen));
    await Future<void>.delayed(Duration.zero);
  });

  test('slow recognition starts the next cycle immediately', () async {
    const fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR';
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.move,
    );
    await gateway.connect();
    final bridge = _ControlledAccessibilityVisionBridge();
    final service = _testVisionPlayService(
      boardGatewayProvider: () => gateway,
      accessibilityService: bridge,
      interval: const Duration(milliseconds: 200),
    );

    service.update(
      enabled: true,
      boardConnected: true,
      lifecycleState: AppLifecycleState.paused,
    );
    await _waitUntil(() => bridge.recognitionCalls == 1);
    expect(bridge.recognitionCalls, 1);

    await Future<void>.delayed(const Duration(milliseconds: 250));
    bridge.completeNext(_visionBoardJson(fen));
    await _waitUntil(
      () => bridge.recognitionCalls == 2,
      timeout: const Duration(milliseconds: 100),
    );
    expect(bridge.recognitionCalls, 2);

    await service.dispose();
    bridge.completeAll(_visionBoardJson(fen));
    await Future<void>.delayed(Duration.zero);
  });

  test('matching Move board only sends one clear LED command', () async {
    const fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR';
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.move,
    );
    await gateway.connect();
    final service = _testVisionPlayService(
      boardGatewayProvider: () => gateway,
      recognizer: _FakeVisionRecognizer(_visionBoardJson(fen)),
      interval: const Duration(days: 1),
    );

    service.update(
      enabled: true,
      boardConnected: true,
      lifecycleState: AppLifecycleState.paused,
    );
    await Future<void>.delayed(Duration.zero);
    gateway.addBoardFen(fen);
    await service.debugTickForTest();
    await service.debugTickForTest();
    await service.debugTickForTest();
    await service.debugTickForTest();

    final clearCommand = ChessnutMoveLedCodec.offCommand();
    final clearCount =
        gateway.writes.where((write) => listEquals(write, clearCommand)).length;
    expect(clearCount, 1);

    await service.dispose();
  });

  test(
      'stable vision FEN lights and restores an unmatched Move board after timeout',
      () async {
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.move,
    );
    await gateway.connect();
    const recognizer = _FakeVisionRecognizer(
      '{"fen":"8/8/8/8/4P3/8/8/8","position":[{"x":1,"y":2,"w":3,"h":4,"label":"e4","prob":0.9}]}',
    );
    final service = _testVisionPlayService(
      boardGatewayProvider: () => gateway,
      accessibilityService: _FakeAccessibilityVisionBridge(),
      recognizer: recognizer,
      interval: const Duration(days: 1),
      boardSettings: const BoardSettingsState(
        fenDelayMs: 0,
        moveRestoreDelayMs: 250,
      ),
    );

    service.update(
      enabled: true,
      boardConnected: true,
      lifecycleState: AppLifecycleState.paused,
    );
    await Future<void>.delayed(Duration.zero);
    gateway.addBoardFen(
      '8/8/8/8/8/8/8/8',
    );
    await service.debugTickForTest();
    await service.debugTickForTest();

    expect(
      gateway.writes,
      contains(equals(ChessnutMoveCommands.enableRealtimeFen)),
    );
    expect(
      gateway.writes,
      contains(equals(
        ChessnutMoveLedCodec.commandFromSquares({
          'e4': ChessnutMoveLedColor.red,
        }),
      )),
    );
    final restoreCommand = ChessnutMoveBoardCodec.setBoardCommand(
      '8/8/8/8/4P3/8/8/8',
      strictMode: true,
    );
    expect(
      gateway.writes.where((write) {
        return listEquals(write, restoreCommand);
      }),
      isEmpty,
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    await service.debugTickForTest();

    expect(
      gateway.writes,
      contains(equals(restoreCommand)),
    );

    await service.dispose();
  });

  test('new stable vision FEN bypasses pending physical restore delay',
      () async {
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.move,
    );
    await gateway.connect();
    const firstVisionFen = '8/8/8/8/4P3/8/8/8';
    const secondVisionFen = '8/8/8/8/4P3/8/8/4K3';
    final recognizer = _MutableVisionRecognizer(
      _singlePositionVisionJson(firstVisionFen),
    );
    final service = _testVisionPlayService(
      boardGatewayProvider: () => gateway,
      accessibilityService: _FakeAccessibilityVisionBridge(),
      recognizer: recognizer,
      interval: const Duration(days: 1),
      boardSettings: const BoardSettingsState(
        fenDelayMs: 0,
        moveRestoreDelayMs: 5000,
      ),
    );

    service.update(
      enabled: true,
      boardConnected: true,
      lifecycleState: AppLifecycleState.paused,
    );
    await Future<void>.delayed(Duration.zero);
    gateway.addBoardFen('8/8/8/8/8/8/8/8');
    await service.debugTickForTest();
    await service.debugTickForTest();

    final firstRestoreCommand = ChessnutMoveBoardCodec.setBoardCommand(
      firstVisionFen,
      strictMode: true,
    );
    expect(
      gateway.writes.where((write) => listEquals(write, firstRestoreCommand)),
      isEmpty,
    );

    final secondRestoreCommand = ChessnutMoveBoardCodec.setBoardCommand(
      secondVisionFen,
      strictMode: true,
    );
    recognizer.json = _singlePositionVisionJson(secondVisionFen);
    await service.debugTickForTest();
    expect(
      gateway.writes.where((write) => listEquals(write, secondRestoreCommand)),
      isEmpty,
    );
    await service.debugTickForTest();

    expect(
      gateway.writes,
      contains(equals(secondRestoreCommand)),
    );

    await service.dispose();
  });

  test('reversed physical FEN matching Vision does not restore Move board',
      () async {
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.move,
    );
    await gateway.connect();
    const visionFen = '8/8/8/8/4P3/8/8/4K3';
    const recognizer = _FakeVisionRecognizer(
      '{"fen":"$visionFen","position":[{"x":1,"y":2,"w":3,"h":4,"label":"e4","prob":0.9}]}',
    );
    final service = _testVisionPlayService(
      boardGatewayProvider: () => gateway,
      accessibilityService: _FakeAccessibilityVisionBridge(),
      recognizer: recognizer,
      interval: const Duration(days: 1),
      boardSettings: const BoardSettingsState(
        fenDelayMs: 0,
        moveRestoreDelayMs: 0,
      ),
    );

    service.update(
      enabled: true,
      boardConnected: true,
      lifecycleState: AppLifecycleState.paused,
    );
    await Future<void>.delayed(Duration.zero);
    gateway.addBoardFen('3K4/8/8/3P4/8/8/8/8');
    await service.debugTickForTest();
    await service.debugTickForTest();

    expect(gateway.writes.any((write) => write.first == 0x42), isFalse);

    await service.dispose();
  });

  test('stable vision FEN lights normalized squares for general board',
      () async {
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.air,
    );
    await gateway.connect();
    const recognizer = _FakeVisionRecognizer(
      '{"fen":"8/8/8/8/4P3/8/8/4K3","position":[{"x":1,"y":2,"w":3,"h":4,"label":"e4","prob":0.9}]}',
    );
    final service = _testVisionPlayService(
      boardGatewayProvider: () => gateway,
      accessibilityService: _FakeAccessibilityVisionBridge(),
      recognizer: recognizer,
      interval: const Duration(days: 1),
    );

    service.update(
      enabled: true,
      boardConnected: true,
      lifecycleState: AppLifecycleState.paused,
    );
    await Future<void>.delayed(Duration.zero);
    gateway.addBoardFen('3K4/8/8/3P4/8/8/8/8');
    await service.debugTickForTest();
    await service.debugTickForTest();

    expect(
      gateway.writes,
      contains(equals(ChessnutLedCodec.ledCommand(List<int>.filled(64, 0)))),
    );

    await service.dispose();
  });

  test('reverse general board guidance maps LEDs to physical squares',
      () async {
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.air,
    );
    await gateway.connect();
    const recognizer = _FakeVisionRecognizer(
      '{"fen":"8/8/8/8/4P3/8/8/4K3","position":[{"x":1,"y":2,"w":3,"h":4,"label":"e4","prob":0.9}]}',
    );
    final service = _testVisionPlayService(
      boardGatewayProvider: () => gateway,
      accessibilityService: _FakeAccessibilityVisionBridge(),
      recognizer: recognizer,
      interval: const Duration(days: 1),
    );

    service.update(
      enabled: true,
      boardConnected: true,
      lifecycleState: AppLifecycleState.paused,
    );
    await Future<void>.delayed(Duration.zero);
    gateway.addBoardFen('3K4/8/8/8/8/8/8/8');
    await service.debugTickForTest();
    await service.debugTickForTest();

    expect(
      gateway.writes,
      contains(equals(ChessnutLedCodec.ledCommandFromSquares({'d5'}))),
    );
    expect(
      gateway.writes.any(
        (write) => listEquals(
          write,
          ChessnutLedCodec.ledCommandFromSquares({'e4'}),
        ),
      ),
      isFalse,
    );

    await service.dispose();
  });

  test('general board guidance only writes LEDs when state changes', () async {
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.air,
    );
    await gateway.connect();
    const recognizer = _FakeVisionRecognizer(
      '{"fen":"8/8/8/8/4P3/8/8/4K3","position":[{"x":1,"y":2,"w":3,"h":4,"label":"e4","prob":0.9}]}',
    );
    final service = _testVisionPlayService(
      boardGatewayProvider: () => gateway,
      accessibilityService: _FakeAccessibilityVisionBridge(),
      recognizer: recognizer,
      interval: const Duration(days: 1),
    );

    service.update(
      enabled: true,
      boardConnected: true,
      lifecycleState: AppLifecycleState.paused,
    );
    await Future<void>.delayed(Duration.zero);
    gateway.addBoardFen('3K4/8/8/8/8/8/8/8');
    await service.debugTickForTest();
    await service.debugTickForTest();

    final ledCommand = ChessnutLedCodec.ledCommandFromSquares({'d5'});
    expect(
      gateway.writes.where((write) => listEquals(write, ledCommand)),
      hasLength(1),
    );

    gateway.addBoardFen('3K4/8/8/8/8/8/8/8');
    gateway.addBoardFen('3K4/8/8/8/8/8/8/8');
    await service.debugTickForTest();

    expect(
      gateway.writes.where((write) => listEquals(write, ledCommand)),
      hasLength(1),
    );

    await service.dispose();
  });

  test('general board guidance writes LEDs after squares change', () async {
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.air,
    );
    await gateway.connect();
    const recognizer = _FakeVisionRecognizer(
      '{"fen":"8/8/8/8/4P3/8/8/4K3","position":[{"x":1,"y":2,"w":3,"h":4,"label":"e4","prob":0.9}]}',
    );
    final service = _testVisionPlayService(
      boardGatewayProvider: () => gateway,
      accessibilityService: _FakeAccessibilityVisionBridge(),
      recognizer: recognizer,
      interval: const Duration(days: 1),
    );

    service.update(
      enabled: true,
      boardConnected: true,
      lifecycleState: AppLifecycleState.paused,
    );
    await Future<void>.delayed(Duration.zero);
    gateway.addBoardFen('3K4/8/8/8/8/8/8/8');
    await service.debugTickForTest();
    await service.debugTickForTest();

    final firstCommand = ChessnutLedCodec.ledCommandFromSquares({'d5'});
    expect(
      gateway.writes.where((write) => listEquals(write, firstCommand)),
      hasLength(1),
    );

    gateway.addBoardFen('3K4/8/8/8/5P2/8/8/8');
    await Future<void>.delayed(Duration.zero);

    final secondCommand = ChessnutLedCodec.ledCommandFromSquares({'d5', 'f4'});
    expect(
      gateway.writes.where((write) => listEquals(write, secondCommand)),
      hasLength(1),
    );

    await service.dispose();
  });

  test('physical move is dispatched to screen from vision coordinates',
      () async {
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.move,
    );
    await gateway.connect();
    final bridge = _FakeAccessibilityVisionBridge();
    final recognizer = _MutableVisionRecognizer(_visionBoardJson(
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
    ));
    final service = _testVisionPlayService(
      boardGatewayProvider: () => gateway,
      accessibilityService: bridge,
      recognizer: recognizer,
      interval: const Duration(days: 1),
    );

    service.update(
      enabled: true,
      boardConnected: true,
      lifecycleState: AppLifecycleState.paused,
    );
    await Future<void>.delayed(Duration.zero);
    gateway.addBoardFen(
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR',
    );
    await service.debugTickForTest();
    await service.debugTickForTest();

    expect(bridge.gestures, hasLength(1));
    expect(bridge.gestures.single.from, const Rect.fromLTWH(44, 64, 8, 8));
    expect(bridge.gestures.single.to, const Rect.fromLTWH(44, 44, 8, 8));
    expect(
      gateway.writes,
      contains(equals(
        ChessnutMoveLedCodec.commandFromSquares({
          'e2': ChessnutMoveLedColor.red,
          'e4': ChessnutMoveLedColor.red,
        }),
      )),
    );
    expect(
      gateway.writes.any((write) => write.first == 0x42),
      isFalse,
    );

    await service.dispose();
  });

  test('screen move retries do not block the promotion picker', () async {
    const visionFen = '7k/P7/8/8/8/8/8/7K';
    const physicalFen = 'Q6k/8/8/8/8/8/8/7K';
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.move,
    );
    await gateway.connect();
    final bridge = _FakeAccessibilityVisionBridge();
    final recognizer = _MutableVisionRecognizer(_visionBoardJson(visionFen));
    final service = _testVisionPlayService(
      boardGatewayProvider: () => gateway,
      accessibilityService: bridge,
      recognizer: recognizer,
      interval: const Duration(days: 1),
      boardSettings: const BoardSettingsState(
        fenDelayMs: 0,
        moveRestoreDelayMs: 5000,
      ),
    );

    service.update(
      enabled: true,
      boardConnected: true,
      lifecycleState: AppLifecycleState.paused,
    );
    await Future<void>.delayed(Duration.zero);
    gateway.addBoardFen(physicalFen);
    await service.debugTickForTest();
    await service.debugTickForTest();
    expect(bridge.gestures, hasLength(1));

    recognizer.json = _promotionPickerVisionJson(visionFen);
    await service.debugTickForTest();

    expect(bridge.gestures, hasLength(2));
    expect(bridge.gestures.last.from, const Rect.fromLTWH(1, 2, 3, 4));
    expect(bridge.gestures.last.to, isNull);

    await service.dispose();
  });

  test('recognition-only mode guides the board without dispatching screen taps',
      () async {
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.move,
    );
    await gateway.connect();
    final bridge = _FakeAccessibilityVisionBridge();
    final recognizer = _MutableVisionRecognizer(_visionBoardJson(
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
    ));
    final service = _testVisionPlayService(
      boardGatewayProvider: () => gateway,
      accessibilityService: bridge,
      recognizer: recognizer,
      interval: const Duration(days: 1),
    );

    service.update(
      enabled: true,
      boardConnected: true,
      lifecycleState: AppLifecycleState.paused,
      recognitionOnly: true,
    );
    await Future<void>.delayed(Duration.zero);
    gateway.addBoardFen(
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR',
    );
    await service.debugTickForTest();
    await service.debugTickForTest();

    expect(bridge.gestures, isEmpty);
    expect(
      gateway.writes,
      contains(equals(
        ChessnutMoveLedCodec.commandFromSquares({
          'e2': ChessnutMoveLedColor.red,
          'e4': ChessnutMoveLedColor.red,
        }),
      )),
    );

    service.update(
      enabled: true,
      boardConnected: true,
      lifecycleState: AppLifecycleState.paused,
      recognitionOnly: false,
    );
    await Future<void>.delayed(Duration.zero);
    if (bridge.gestures.isEmpty) {
      await service.debugTickForTest();
    }
    expect(bridge.gestures, hasLength(1));

    await service.dispose();
  });

  test('physical move dispatch is not repeated for the same state', () async {
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.move,
    );
    await gateway.connect();
    final bridge = _FakeAccessibilityVisionBridge();
    final recognizer = _MutableVisionRecognizer(_visionBoardJson(
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
    ));
    final service = _testVisionPlayService(
      boardGatewayProvider: () => gateway,
      accessibilityService: bridge,
      recognizer: recognizer,
      interval: const Duration(days: 1),
    );

    service.update(
      enabled: true,
      boardConnected: true,
      lifecycleState: AppLifecycleState.paused,
    );
    await Future<void>.delayed(Duration.zero);
    gateway.addBoardFen(
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR',
    );
    await service.debugTickForTest();
    await service.debugTickForTest();
    await service.debugTickForTest();
    await service.debugTickForTest();

    expect(bridge.gestures, hasLength(1));

    await Future<void>.delayed(const Duration(milliseconds: 550));
    recognizer.json = _visionBoardJson(
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR',
    );
    await service.debugTickForTest();
    await service.debugTickForTest();
    gateway.addBoardFen(
      'rnbqkbnr/pppppppp/8/8/3PP3/8/PPP2PPP/RNBQKBNR',
    );
    await Future<void>.delayed(Duration.zero);

    expect(bridge.gestures, hasLength(2));

    await service.dispose();
  });

  test('ordinary move retries three times before Move restore', () async {
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.move,
    );
    await gateway.connect();
    final bridge = _FakeAccessibilityVisionBridge();
    final recognizer = _MutableVisionRecognizer(_visionBoardJson(
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
    ));
    final service = _testVisionPlayService(
      boardGatewayProvider: () => gateway,
      accessibilityService: bridge,
      recognizer: recognizer,
      interval: const Duration(days: 1),
      boardSettings: const BoardSettingsState(
        fenDelayMs: 0,
        moveRestoreDelayMs: 250,
      ),
    );

    service.update(
      enabled: true,
      boardConnected: true,
      lifecycleState: AppLifecycleState.paused,
    );
    await Future<void>.delayed(Duration.zero);
    gateway.addBoardFen(
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR',
    );
    await service.debugTickForTest();
    await service.debugTickForTest();
    expect(bridge.gestures, hasLength(1));
    expect(gateway.writes.any((write) => write.first == 0x42), isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 300));
    await service.debugTickForTest();
    expect(bridge.gestures, hasLength(2));
    expect(gateway.writes.any((write) => write.first == 0x42), isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 300));
    await service.debugTickForTest();
    expect(bridge.gestures, hasLength(3));
    expect(gateway.writes.any((write) => write.first == 0x42), isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 300));
    await service.debugTickForTest();
    expect(
      gateway.writes,
      contains(equals(
        ChessnutMoveBoardCodec.setBoardCommand(
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
          strictMode: true,
        ),
      )),
    );
    expect(bridge.gestures, hasLength(3));

    await service.dispose();
  });

  test(
      'castling retries king-to-rook then king-to-destination for three rounds',
      () async {
    const visionFen = 'r3k2r/8/8/8/8/8/8/R3K2R';
    const physicalFen = 'r3k2r/8/8/8/8/8/8/R4RK1';
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.move,
    );
    await gateway.connect();
    final bridge = _FakeAccessibilityVisionBridge();
    final recognizer = _MutableVisionRecognizer(_visionBoardJson(visionFen));
    final service = _testVisionPlayService(
      boardGatewayProvider: () => gateway,
      accessibilityService: bridge,
      recognizer: recognizer,
      interval: const Duration(days: 1),
      boardSettings: const BoardSettingsState(
        fenDelayMs: 0,
        moveRestoreDelayMs: 0,
      ),
    );

    service.update(
      enabled: true,
      boardConnected: true,
      lifecycleState: AppLifecycleState.paused,
    );
    await Future<void>.delayed(Duration.zero);
    gateway.addBoardFen(physicalFen);
    await service.debugTickForTest();
    await service.debugTickForTest();
    for (var i = 0; i < 6; i++) {
      await service.debugTickForTest();
    }

    expect(bridge.gestures, hasLength(6));
    expect(
      bridge.gestures.map((gesture) => gesture.from),
      everyElement(const Rect.fromLTWH(44, 74, 8, 8)),
    );
    expect(
      bridge.gestures.map((gesture) => gesture.to),
      equals([
        const Rect.fromLTWH(74, 74, 8, 8),
        const Rect.fromLTWH(64, 74, 8, 8),
        const Rect.fromLTWH(74, 74, 8, 8),
        const Rect.fromLTWH(64, 74, 8, 8),
        const Rect.fromLTWH(74, 74, 8, 8),
        const Rect.fromLTWH(64, 74, 8, 8),
      ]),
    );
    expect(
      gateway.writes,
      contains(equals(
        ChessnutMoveBoardCodec.setBoardCommand(
          visionFen,
          strictMode: true,
        ),
      )),
    );

    await service.dispose();
  });

  test('castling stops retrying after the fallback succeeds', () async {
    const visionFen = 'r3k2r/8/8/8/8/8/8/R3K2R';
    const physicalFen = 'r3k2r/8/8/8/8/8/8/R4RK1';
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.move,
    );
    await gateway.connect();
    final bridge = _FakeAccessibilityVisionBridge();
    final recognizer = _MutableVisionRecognizer(_visionBoardJson(visionFen));
    final service = _testVisionPlayService(
      boardGatewayProvider: () => gateway,
      accessibilityService: bridge,
      recognizer: recognizer,
      interval: const Duration(days: 1),
      boardSettings: const BoardSettingsState(
        fenDelayMs: 0,
        moveRestoreDelayMs: 250,
      ),
    );

    service.update(
      enabled: true,
      boardConnected: true,
      lifecycleState: AppLifecycleState.paused,
    );
    await Future<void>.delayed(Duration.zero);
    gateway.addBoardFen(physicalFen);
    await service.debugTickForTest();
    await service.debugTickForTest();
    expect(bridge.gestures, hasLength(1));

    await Future<void>.delayed(const Duration(milliseconds: 300));
    await service.debugTickForTest();
    expect(bridge.gestures, hasLength(2));

    recognizer.json = _visionBoardJson(physicalFen);
    for (var i = 0; i < 6; i++) {
      await service.debugTickForTest();
    }

    expect(bridge.gestures, hasLength(2));
    expect(gateway.writes.any((write) => write.first == 0x42), isFalse);

    await service.dispose();
  });

  test('new vision FEN cancels screen sync wait before Move restore timeout',
      () async {
    const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR';
    const physicalE4Fen = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR';
    const visionE4E6Fen = 'rnbqkbnr/pppp1ppp/4p3/8/4P3/8/PPPP1PPP/RNBQKBNR';
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.move,
    );
    await gateway.connect();
    final bridge = _FakeAccessibilityVisionBridge();
    final recognizer = _MutableVisionRecognizer(_visionBoardJson(startFen));
    final service = _testVisionPlayService(
      boardGatewayProvider: () => gateway,
      accessibilityService: bridge,
      recognizer: recognizer,
      interval: const Duration(days: 1),
      boardSettings: const BoardSettingsState(
        fenDelayMs: 0,
        moveRestoreDelayMs: 5000,
      ),
    );

    service.update(
      enabled: true,
      boardConnected: true,
      lifecycleState: AppLifecycleState.paused,
    );
    await Future<void>.delayed(Duration.zero);
    gateway.addBoardFen(physicalE4Fen);
    await service.debugTickForTest();
    await service.debugTickForTest();
    expect(bridge.gestures, hasLength(1));

    final restoreCommand = ChessnutMoveBoardCodec.setBoardCommand(
      visionE4E6Fen,
      strictMode: true,
    );
    recognizer.json = _visionBoardJson(visionE4E6Fen);
    await service.debugTickForTest();
    expect(
      gateway.writes.where((write) => listEquals(write, restoreCommand)),
      isEmpty,
    );
    await service.debugTickForTest();

    expect(
      gateway.writes,
      contains(equals(restoreCommand)),
    );
    expect(bridge.gestures, hasLength(1));

    await service.dispose();
  });

  test('new stable vision FEN syncs Move before speculative screen move',
      () async {
    const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR';
    const physicalE4Fen = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR';
    const visionE4Nf6Fen = 'rnbqkb1r/pppppppp/5n2/8/4P3/8/PPPP1PPP/RNBQKBNR';
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.move,
    );
    await gateway.connect();
    final bridge = _FakeAccessibilityVisionBridge();
    final recognizer = _MutableVisionRecognizer(_visionBoardJson(startFen));
    final service = _testVisionPlayService(
      boardGatewayProvider: () => gateway,
      accessibilityService: bridge,
      recognizer: recognizer,
      interval: const Duration(days: 1),
      boardSettings: const BoardSettingsState(
        fenDelayMs: 0,
        moveRestoreDelayMs: 5000,
      ),
    );

    service.update(
      enabled: true,
      boardConnected: true,
      lifecycleState: AppLifecycleState.paused,
    );
    await Future<void>.delayed(Duration.zero);
    gateway.addBoardFen(physicalE4Fen);
    await service.debugTickForTest();
    await service.debugTickForTest();
    expect(bridge.gestures, hasLength(1));

    final restoreCommand = ChessnutMoveBoardCodec.setBoardCommand(
      visionE4Nf6Fen,
      strictMode: true,
    );
    recognizer.json = _visionBoardJson(visionE4Nf6Fen);
    await service.debugTickForTest();
    expect(
      gateway.writes.where((write) => listEquals(write, restoreCommand)),
      isEmpty,
    );
    await service.debugTickForTest();

    expect(
      gateway.writes,
      contains(equals(restoreCommand)),
    );
    expect(bridge.gestures, hasLength(1));

    await service.dispose();
  });

  test('physical move screen sync prevents Move restore after timeout',
      () async {
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.move,
    );
    await gateway.connect();
    final bridge = _FakeAccessibilityVisionBridge();
    final recognizer = _MutableVisionRecognizer(_visionBoardJson(
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
    ));
    final service = _testVisionPlayService(
      boardGatewayProvider: () => gateway,
      accessibilityService: bridge,
      recognizer: recognizer,
      interval: const Duration(days: 1),
      boardSettings: const BoardSettingsState(
        fenDelayMs: 0,
        moveRestoreDelayMs: 250,
      ),
    );

    service.update(
      enabled: true,
      boardConnected: true,
      lifecycleState: AppLifecycleState.paused,
    );
    await Future<void>.delayed(Duration.zero);
    gateway.addBoardFen(
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR',
    );
    await service.debugTickForTest();
    await service.debugTickForTest();
    expect(bridge.gestures, hasLength(1));

    await Future<void>.delayed(const Duration(milliseconds: 300));
    await service.debugTickForTest();
    expect(gateway.writes.any((write) => write.first == 0x42), isFalse);

    recognizer.json = _visionBoardJson(
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR',
    );
    await service.debugTickForTest();
    await service.debugTickForTest();
    for (var timeout = 0; timeout < 3; timeout++) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await service.debugTickForTest();
    }

    expect(gateway.writes.any((write) => write.first == 0x42), isFalse);

    await service.dispose();
  });

  test('reversed physical Move board stays synced after legal screen move',
      () async {
    const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR';
    const e4Fen = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR';
    final reversedE4Fen = e4Fen.split('').reversed.join();
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.move,
    );
    await gateway.connect();
    final bridge = _FakeAccessibilityVisionBridge();
    final recognizer = _MutableVisionRecognizer(_visionBoardJson(startFen));
    final service = _testVisionPlayService(
      boardGatewayProvider: () => gateway,
      accessibilityService: bridge,
      recognizer: recognizer,
      interval: const Duration(days: 1),
      boardSettings: const BoardSettingsState(
        fenDelayMs: 0,
        moveRestoreDelayMs: 100,
      ),
    );

    service.update(
      enabled: true,
      boardConnected: true,
      lifecycleState: AppLifecycleState.paused,
    );
    await Future<void>.delayed(Duration.zero);
    gateway.addBoardFen(reversedE4Fen);
    await service.debugTickForTest();
    await service.debugTickForTest();
    expect(bridge.gestures, hasLength(1));

    recognizer.json = _visionBoardJson(e4Fen);
    await service.debugTickForTest();
    await service.debugTickForTest();
    for (var timeout = 0; timeout < 3; timeout++) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await service.debugTickForTest();
    }

    expect(gateway.writes.any((write) => write.first == 0x42), isFalse);

    await service.dispose();
  });

  test('physical move dispatch waits for configured FEN delay', () async {
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.move,
    );
    await gateway.connect();
    final bridge = _FakeAccessibilityVisionBridge();
    final recognizer = _FakeVisionRecognizer(_visionBoardJson(
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
    ));
    bridge._recognizer = recognizer;
    final service = WidgetVisionPlayService(
      boardGatewayProvider: () => gateway,
      boardSettingsProvider: () => const BoardSettingsState(fenDelayMs: 800),
      accessibilityService: bridge,
      interval: const Duration(days: 1),
    );

    service.update(
      enabled: true,
      boardConnected: true,
      lifecycleState: AppLifecycleState.paused,
    );
    await service.debugTickForTest();
    await service.debugTickForTest();

    gateway.addBoardFen(
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR',
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await service.debugTickForTest();
    expect(bridge.gestures, isEmpty);

    gateway.addBoardFen(
      'rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR',
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await service.debugTickForTest();
    expect(bridge.gestures, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 600));

    expect(bridge.gestures, hasLength(1));
    expect(bridge.gestures.single.from, const Rect.fromLTWH(34, 64, 8, 8));
    expect(bridge.gestures.single.to, const Rect.fromLTWH(34, 44, 8, 8));

    await service.dispose();
  });
}

class _FakeAccessibilityVisionBridge implements AccessibilityVisionBridge {
  _FakeAccessibilityVisionBridge({BoardVisionFenRecognizer? recognizer})
      : _recognizer = recognizer;

  final List<_DispatchedGesture> gestures = [];
  final notificationStates = <(bool, bool, bool)>[];
  final notificationLanguages = <String>[];
  BoardVisionFenRecognizer? _recognizer;

  @override
  Future<void> setRecognitionStatus({
    required bool enabled,
    required bool recognizing,
    required bool boardConnected,
    required String languageTag,
  }) async {
    notificationStates.add((enabled, recognizing, boardConnected));
    notificationLanguages.add(languageTag);
  }

  @override
  Future<bool> dispatchMoveGesture({
    required Rect from,
    Rect? to,
  }) async {
    gestures.add(_DispatchedGesture(from: from, to: to));
    return true;
  }

  @override
  Future<bool> isAccessibilityRunning() async => true;

  @override
  Future<void> openAccessibilitySettings() async {}

  @override
  Future<String?> recognizeScreenshot() async =>
      _recognizer?.recognizeJson(const []);
}

class _ControlledAccessibilityVisionBridge
    extends _FakeAccessibilityVisionBridge {
  int recognitionCalls = 0;
  final List<Completer<String?>> _pending = [];

  @override
  Future<String?> recognizeScreenshot() {
    recognitionCalls++;
    final completer = Completer<String?>();
    _pending.add(completer);
    return completer.future;
  }

  void completeNext(String json) {
    _pending.removeAt(0).complete(json);
  }

  void completeAll(String json) {
    for (final completer in _pending) {
      if (!completer.isCompleted) completer.complete(json);
    }
    _pending.clear();
  }
}

WidgetVisionPlayService _testVisionPlayService({
  required PhysicalBoardGateway Function() boardGatewayProvider,
  AccessibilityVisionBridge? accessibilityService,
  BoardVisionFenRecognizer? recognizer,
  Duration interval = const Duration(milliseconds: 500),
  BoardSettingsState boardSettings = const BoardSettingsState(fenDelayMs: 0),
}) {
  final bridge = accessibilityService ?? _FakeAccessibilityVisionBridge();
  if (bridge is _FakeAccessibilityVisionBridge) {
    bridge._recognizer = recognizer;
  }
  return WidgetVisionPlayService(
    boardGatewayProvider: boardGatewayProvider,
    boardSettingsProvider: () => boardSettings,
    accessibilityService: bridge,
    interval: interval,
  );
}

class _DispatchedGesture {
  const _DispatchedGesture({
    required this.from,
    required this.to,
  });

  final Rect from;
  final Rect? to;
}

class _FakeVisionRecognizer implements BoardVisionFenRecognizer {
  const _FakeVisionRecognizer(this.json);

  final String json;

  @override
  Future<String?> recognizeFen(List<int> imageBytes) async => null;

  @override
  Future<String?> recognizeJson(List<int> imageBytes) async => json;
}

class _MutableVisionRecognizer implements BoardVisionFenRecognizer {
  _MutableVisionRecognizer(this.json);

  String json;

  @override
  Future<String?> recognizeFen(List<int> imageBytes) async => null;

  @override
  Future<String?> recognizeJson(List<int> imageBytes) async => json;
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 1),
}) async {
  final stopwatch = Stopwatch()..start();
  while (!condition()) {
    if (stopwatch.elapsed >= timeout) {
      fail('Condition not met within ${timeout.inMilliseconds}ms');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

String _visionBoardJson(String fen) {
  final positions = <String>[];
  for (var index = 0; index < 64; index++) {
    final rankFromTop = index ~/ 8;
    final file = index % 8;
    positions.add(
      '{"x":${file * 10 + 4},"y":${rankFromTop * 10 + 4},'
      '"w":8,"h":8,"label":"$index","prob":0.9}',
    );
  }
  return '{"fen":"$fen","position":[${positions.join(',')}]}';
}

String _singlePositionVisionJson(String fen) {
  return '{"fen":"$fen","position":[{"x":1,"y":2,"w":3,"h":4,"label":"e4","prob":0.9}]}';
}

String _promotionPickerVisionJson(String fen) {
  return '{"fen":"$fen","position":['
      '{"x":1,"y":2,"w":3,"h":4,"label":"q","prob":0.9},'
      '{"x":5,"y":6,"w":3,"h":4,"label":"r","prob":0.9},'
      '{"x":9,"y":10,"w":3,"h":4,"label":"b","prob":0.9},'
      '{"x":13,"y":14,"w":3,"h":4,"label":"n","prob":0.9}'
      ']}';
}
