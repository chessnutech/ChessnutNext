import 'dart:async';

import 'package:chessnut_flutter_export/services/physical_board_gateway.dart';
import 'package:chessnut_flutter_export/services/physical_board_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('distinguishes color LED support from command availability', () {
    expect(PhysicalBoardModel.move.supportsColorLeds, isTrue);
    expect(PhysicalBoardModel.move.canSendColorLedCommands, isTrue);
    expect(PhysicalBoardModel.evo.supportsColorLeds, isTrue);
    expect(PhysicalBoardModel.evo.canSendColorLedCommands, isFalse);
    expect(PhysicalBoardModel.evo2.usesGeneralProtocol, isTrue);
    expect(PhysicalBoardModel.evo2.supportsColorLeds, isTrue);
    expect(PhysicalBoardModel.evo2.canSendColorLedCommands, isFalse);
    expect(PhysicalBoardModel.air.supportsColorLeds, isFalse);
    expect(PhysicalBoardModel.air.canSendColorLedCommands, isFalse);
  });

  test('general board gateway decodes FEN and general board responses',
      () async {
    final transport = FakePhysicalBoardTransport(
      model: PhysicalBoardModel.general,
    );
    final gateway = ChessnutBoardGateway(transport: transport);
    final fenEvents = <String>[];
    final batteryEvents = <ChessnutGeneralBatteryStatus>[];
    final versionEvents = <String>[];
    final fileCountEvents = <int>[];
    final fenSub = gateway.boardFenStream.listen(fenEvents.add);
    final batterySub = gateway.generalBatteryStatusStream.listen(
      batteryEvents.add,
    );
    final versionSub = gateway.generalVersionStream.listen(versionEvents.add);
    final fileCountSub = gateway.generalFileCountStream.listen(
      fileCountEvents.add,
    );

    await gateway.connect();
    transport.addFenPayload(_startPositionPayload());
    transport.addResponse([0x2a, 0x02, 82, 0]);
    transport.addResponse([0x28, 0x07, 0x00, ...'BLE-1.2'.codeUnits]);
    transport.addResponse([0x32, 0x01, 4]);
    await gateway.enableRealtimeFen();
    await gateway.queryGeneralBatteryStatus();
    await gateway.queryGeneralBleVersion();
    await gateway.queryGeneralFileCount();
    await gateway.setGeneralLedSquares({'e4'});
    await gateway.setBoardBeepEnabled(false);
    await gateway.playBeep();
    await Future<void>.delayed(Duration.zero);

    expect(fenEvents.single, 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR');
    expect(batteryEvents.single.level, 82);
    expect(batteryEvents.single.isCharging, isFalse);
    expect(versionEvents.single, 'BLE-1.2');
    expect(fileCountEvents.single, 4);
    expect(transport.writes[0], ChessnutGeneralCommands.enableRealtimeFen);
    expect(transport.writes[1], ChessnutGeneralCommands.batteryStatus);
    expect(transport.writes[2], ChessnutGeneralCommands.bleVersion);
    expect(transport.writes[3], ChessnutGeneralCommands.fileCount);
    expect(transport.writes[4].first, 0x0a);
    expect(transport.writes[5], ChessnutGeneralCommands.setBeep(false));
    expect(transport.writes[6], ChessnutGeneralCommands.beep());

    await fenSub.cancel();
    await batterySub.cancel();
    await versionSub.cancel();
    await fileCountSub.cancel();
  });

  test('Air gateway uses general realtime FEN and LED commands', () async {
    final transport = FakePhysicalBoardTransport(
      model: PhysicalBoardModel.air,
    );
    final gateway = ChessnutBoardGateway(transport: transport);

    await gateway.connect();
    await gateway.enableRealtimeFen();
    await gateway.setGeneralLedSquares({'e2', 'e4'});
    await gateway.clearGeneralLeds();

    expect(transport.writes[0], ChessnutGeneralCommands.enableRealtimeFen);
    expect(transport.writeWithoutResponse[0], isTrue);
    expect(
      transport.writes[1],
      ChessnutLedCodec.ledCommandFromSquares({'e2', 'e4'}),
    );
    expect(transport.writeWithoutResponse[1], isTrue);
    expect(
      transport.writes[2],
      ChessnutLedCodec.ledCommand(List<int>.filled(64, 0)),
    );
    expect(transport.writeWithoutResponse[2], isTrue);
  });

  test('Move gateway decodes transport streams and writes protocol commands',
      () async {
    final transport = FakePhysicalBoardTransport();
    final gateway = ChessnutMoveGateway(transport: transport);
    final fenEvents = <String>[];
    final batteryEvents = <ChessnutMoveBatteryStatus>[];
    final fenSub = gateway.boardFenStream.listen(fenEvents.add);
    final batterySub = gateway.batteryStatusStream.listen(batteryEvents.add);

    await gateway.connect();
    transport.addFenPayload(_startPositionPayload());
    transport.addResponse([0x41, 0x03, 0x0c, 1, 64]);
    await gateway.enableRealtimeFen();
    await gateway.playBeep();
    await gateway.setMoveLedSquares({'e4': ChessnutMoveLedColor.green});
    await gateway.clearMoveLeds();
    await Future<void>.delayed(Duration.zero);

    expect(fenEvents.single, 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR');
    expect(batteryEvents.single.level, 64);
    expect(batteryEvents.single.isCharging, isTrue);
    expect(transport.writes[0], ChessnutMoveCommands.enableRealtimeFen);
    expect(transport.writes[1], ChessnutGeneralCommands.beep());
    expect(
      transport.writes[2],
      ChessnutMoveLedCodec.commandFromSquares({
        'e4': ChessnutMoveLedColor.green,
      }),
    );
    expect(transport.writeWithoutResponse[2], isTrue);
    expect(transport.writes[3], ChessnutMoveLedCodec.offCommand());
    expect(transport.writeWithoutResponse[3], isTrue);

    await fenSub.cancel();
    await batterySub.cancel();
  });

  test('Move gateway queries and emits Move and Bluetooth firmware versions',
      () async {
    final transport = FakePhysicalBoardTransport();
    final gateway = ChessnutMoveGateway(transport: transport);
    final versionEvents = <BoardFirmwareVersions>[];
    final versionSub = gateway.boardFirmwareVersionsStream.listen(
      versionEvents.add,
    );

    await gateway.connect();
    final sent = await gateway.queryBoardFirmwareVersion();
    transport.addResponse([0x28, 0x07, 0x00, ...'BLE-1.2'.codeUnits]);
    transport.addResponse([0x41, 0x05, 0x09, ...'2.1.8'.codeUnits]);
    await Future<void>.delayed(Duration.zero);

    expect(sent, isTrue);
    expect(transport.writes[0], ChessnutGeneralCommands.bleVersion);
    expect(transport.writes[1], ChessnutMoveCommands.firmwareVersion);
    expect(versionEvents, hasLength(2));
    expect(versionEvents.last.bluetoothVersion, 'BLE-1.2');
    expect(versionEvents.last.moveVersion, '2.1.8');

    await versionSub.cancel();
  });

  test('general gateway queries Move firmware when transport model is Move',
      () async {
    final transport = FakePhysicalBoardTransport();
    final gateway = ChessnutBoardGateway(transport: transport);
    final versionEvents = <BoardFirmwareVersions>[];
    final versionSub = gateway.boardFirmwareVersionsStream.listen(
      versionEvents.add,
    );

    await gateway.connect();
    final sent = await gateway.queryBoardFirmwareVersion();
    transport.addResponse([0x28, 0x07, 0x00, ...'BLE-1.2'.codeUnits]);
    transport.addResponse([0x41, 0x05, 0x09, ...'2.1.8'.codeUnits]);
    await Future<void>.delayed(Duration.zero);

    expect(sent, isTrue);
    expect(transport.writes[0], ChessnutGeneralCommands.bleVersion);
    expect(transport.writes[1], ChessnutMoveCommands.firmwareVersion);
    expect(versionEvents, hasLength(2));
    expect(versionEvents.last.bluetoothVersion, 'BLE-1.2');
    expect(versionEvents.last.moveVersion, '2.1.8');

    await versionSub.cancel();
  });

  test('memory gateway emits decoded FEN notifications', () async {
    final gateway = MemoryPhysicalBoardGateway();
    final fenEvents = <String>[];
    final sub = gateway.boardFenStream.listen(fenEvents.add);

    await gateway.connect();
    gateway.addRawFenPayload(_startPositionPayload());
    await Future<void>.delayed(Duration.zero);

    expect(fenEvents, [
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
    ]);
    await sub.cancel();
  });

  test('gateway reassembles split Air FEN notifications', () async {
    final transport = FakePhysicalBoardTransport(
      model: PhysicalBoardModel.air,
    );
    final gateway = ChessnutBoardGateway(transport: transport);
    final fenEvents = <String>[];
    final sub = gateway.boardFenStream.listen(fenEvents.add);
    final payload = _startPositionPayload();

    await gateway.connect();
    transport.addFenPayload(payload.sublist(0, 20));
    await Future<void>.delayed(Duration.zero);
    expect(fenEvents, isEmpty);

    transport.addFenPayload(payload.sublist(20));
    await Future<void>.delayed(Duration.zero);

    expect(fenEvents, [
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
    ]);
    await sub.cancel();
  });

  test('general board reads stored game from file notifications without delete',
      () async {
    final transport = FakePhysicalBoardTransport(
      model: PhysicalBoardModel.air,
    );
    final gateway = ChessnutBoardGateway(transport: transport);

    await gateway.connect();

    final readFuture = gateway.peekStoredGameFile();
    await Future<void>.delayed(Duration.zero);
    transport.addResponse([0x32, 0x01, 1]);
    await Future<void>.delayed(Duration.zero);
    transport.addFilePayload([0x37, 0x01, 0xbe]);
    transport.addFilePayload(_startPositionPayload());
    transport.addFilePayload(_afterE4Payload());
    transport.addFilePayload([0x37, 0x01, 0xed]);

    final raw = await readFuture;

    expect(
      raw,
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR;'
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR',
    );
    expect(_hasCommand(transport.writes, ChessnutGeneralCommands.fileCount),
        isTrue);
    expect(_hasCommand(transport.writes, ChessnutGeneralCommands.startFileRead),
        isTrue);
    expect(_hasCommand(transport.writes, ChessnutGeneralCommands.deleteFiles),
        isFalse);
    expect(transport.writes.last, ChessnutGeneralCommands.enableRealtimeFen);
  });

  test('general board deletes stored game only after delete import read',
      () async {
    final transport = FakePhysicalBoardTransport(
      model: PhysicalBoardModel.air,
    );
    final gateway = ChessnutBoardGateway(transport: transport);

    await gateway.connect();

    final readFuture = gateway.readAndDeleteStoredGameFile();
    await Future<void>.delayed(Duration.zero);
    transport.addResponse([0x32, 0x01, 1]);
    await Future<void>.delayed(Duration.zero);
    transport.addFilePayload([0x37, 0x01, 0xbe]);
    transport.addFilePayload(_startPositionPayload());
    transport.addFilePayload(_afterE4Payload());
    transport.addFilePayload([0x37, 0x01, 0xed]);

    final raw = await readFuture;

    expect(raw, isNotNull);
    expect(_hasCommand(transport.writes, ChessnutGeneralCommands.deleteFiles),
        isTrue);
    expect(
      transport.writes.last,
      ChessnutGeneralCommands.enableRealtimeFen,
    );
  });

  test('app board gateway reads Move stored PGN and deletes on delete read',
      () async {
    final transport = FakePhysicalBoardTransport();
    final gateway = ChessnutBoardGateway(transport: transport);

    await gateway.connect();

    expect(gateway.supportsStoredGameImport, isTrue);

    final peekFuture = gateway.peekStoredGameFile();
    await Future<void>.delayed(Duration.zero);
    transport.addResponse([0x41, 0x01, 0x15, 1]);
    await Future<void>.delayed(Duration.zero);
    transport.addResponse([
      0x41,
      0x0a,
      0x16,
      0x01,
      ...'1. e4 e5'.codeUnits,
    ]);
    transport.addResponse([0x41, 0x01, 0x16, 0x00]);

    expect(await peekFuture, '1. e4 e5');
    expect(
        _hasCommand(transport.writes, ChessnutMoveCommands.fileCount), isTrue);
    expect(
        _hasCommand(transport.writes, ChessnutMoveCommands.readStoredGameFile),
        isTrue);
    expect(
        _hasCommand(
            transport.writes, ChessnutMoveCommands.deleteStoredGameFile),
        isFalse);

    final deleteFuture = gateway.readAndDeleteStoredGameFile();
    await Future<void>.delayed(Duration.zero);
    transport.addResponse([0x41, 0x01, 0x15, 1]);
    await Future<void>.delayed(Duration.zero);
    transport.addResponse([
      0x41,
      0x0b,
      0x16,
      0x01,
      ...'1. d4 d5'.codeUnits,
    ]);
    transport.addResponse([0x41, 0x01, 0x16, 0x00]);

    expect(await deleteFuture, '1. d4 d5');
    expect(
        _hasCommand(
            transport.writes, ChessnutMoveCommands.deleteStoredGameFile),
        isTrue);
  });

  test('Move gateway reads stored PGN and deletes only on delete read',
      () async {
    final transport = FakePhysicalBoardTransport();
    final gateway = ChessnutMoveGateway(transport: transport);

    await gateway.connect();

    final peekFuture = gateway.peekStoredGameFile();
    await Future<void>.delayed(Duration.zero);
    transport.addResponse([0x41, 0x01, 0x15, 1]);
    await Future<void>.delayed(Duration.zero);
    transport.addResponse([
      0x41,
      0x0a,
      0x16,
      0x01,
      ...'1. e4 e5'.codeUnits,
    ]);
    transport.addResponse([0x41, 0x01, 0x16, 0x00]);

    expect(await peekFuture, '1. e4 e5');
    expect(
        _hasCommand(transport.writes, ChessnutMoveCommands.fileCount), isTrue);
    expect(
        _hasCommand(transport.writes, ChessnutMoveCommands.readStoredGameFile),
        isTrue);
    expect(
        _hasCommand(
            transport.writes, ChessnutMoveCommands.deleteStoredGameFile),
        isFalse);

    final deleteFuture = gateway.readAndDeleteStoredGameFile();
    await Future<void>.delayed(Duration.zero);
    transport.addResponse([0x41, 0x01, 0x15, 1]);
    await Future<void>.delayed(Duration.zero);
    transport.addResponse([
      0x41,
      0x0b,
      0x16,
      0x01,
      ...'1. d4 d5'.codeUnits,
    ]);
    transport.addResponse([0x41, 0x01, 0x16, 0x00]);

    expect(await deleteFuture, '1. d4 d5');
    expect(
        _hasCommand(
            transport.writes, ChessnutMoveCommands.deleteStoredGameFile),
        isTrue);
  });

  test('memory gateway can emit board-only FEN for UI integration tests',
      () async {
    final gateway = MemoryPhysicalBoardGateway();
    final fenEvents = <String>[];
    final sub = gateway.boardFenStream.listen(fenEvents.add);

    gateway.addBoardFen(
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 1',
    );
    await Future<void>.delayed(Duration.zero);

    expect(fenEvents, [
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR',
    ]);
    await sub.cancel();
  });

  test('memory gateway records commands sent through board operations',
      () async {
    final gateway = MemoryPhysicalBoardGateway();

    await gateway.connect();
    await gateway.enableRealtimeFen();
    await gateway.setMoveBoardFen(
      '8/8/8/8/4P3/8/8/4K3',
      strictMode: true,
    );
    await gateway.setMoveLedSquares({'e4': ChessnutMoveLedColor.green});

    expect(gateway.writes[0], ChessnutMoveCommands.enableRealtimeFen);
    expect(gateway.writes[1].first, 0x42);
    expect(gateway.writes[1].last, 1);
    expect(gateway.writes[2].first, 0x43);
  });

  test('memory gateway exposes Move piece set management operations', () async {
    final gateway = MemoryPhysicalBoardGateway();

    await gateway.connect();
    gateway.movePieceData = ['Chess Pieces 01', '', '', 'Backup set'];
    gateway.moveChannel = 0;
    gateway.moveDiscoveredChannel = 3;
    gateway.movePairingWillSucceed = true;

    expect(await gateway.queryMovePieceData(), [
      'Chess Pieces 01',
      '',
      '',
      'Backup set',
    ]);
    expect(await gateway.queryMoveChannel(), 0);
    expect(await gateway.discoverMovePieceChannel(), 3);

    expect(await gateway.setMoveChannel(2), isTrue);
    expect(gateway.moveChannel, 2);
    expect(gateway.writes.last, ChessnutMoveCommands.setChannel(2));

    expect(await gateway.setMovePieceData(['Set A', 'Set B']), isTrue);
    expect(gateway.movePieceData, ['Set A', 'Set B', '', '']);

    expect(await gateway.startMovePiecePairing(1), isTrue);
    expect(gateway.writes.last, ChessnutMoveCommands.startPiecePairing(1));
    expect(await gateway.finishMovePiecePairing(), isTrue);
    expect(gateway.writes.last, ChessnutMoveCommands.finishPiecePairing());

    expect(await gateway.exitMovePiecePairing(), isTrue);
    expect(gateway.writes.last, ChessnutMoveCommands.exitPiecePairing());

    expect(await gateway.setMovePieceAutoPoweroff(true), isTrue);
    expect(
        gateway.writes.last, ChessnutMoveCommands.setPieceAutoPoweroff(true));
  });

  test('memory gateway replays Move piece status on query', () async {
    final gateway = MemoryPhysicalBoardGateway();
    await gateway.connect();
    gateway.addMovePieceStatus(const [
      ChessnutMovePieceStatus(
        index: 1,
        identity: 6,
        rawX: 223,
        rawY: 110,
        batteryLevel: 88,
      ),
      ChessnutMovePieceStatus(
        index: 2,
        identity: 11,
        rawX: 0,
        rawY: 0,
        batteryLevel: 71,
      ),
    ]);

    final events = <List<ChessnutMovePieceStatus>>[];
    final sub = gateway.movePieceStatusStream.listen(events.add);
    await gateway.queryMovePieceStatus();
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1));
    expect(events.single.map((piece) => piece.fenChar), ['K', 'q']);
    expect(events.single.first.isOnBoard, isTrue);
    expect(events.single.last.isOutOfBoard, isTrue);
    expect(gateway.writes.last, ChessnutMoveCommands.pieceStatus);
    await sub.cancel();
  });

  test('memory gateway simulates stored board game import cursor', () async {
    final gateway = MemoryPhysicalBoardGateway()
      ..storedGameImportSupported = true
      ..storedGameFiles.addAll(['game-one', 'game-two']);

    await gateway.connect();

    expect(gateway.supportsStoredGameImport, isTrue);
    expect(await gateway.queryStoredGameCount(), 2);
    expect(await gateway.peekStoredGameFile(), 'game-one');
    expect(await gateway.queryStoredGameCount(), 2);
    expect(await gateway.readAndDeleteStoredGameFile(), 'game-one');
    expect(await gateway.peekStoredGameFile(), 'game-two');
    expect(await gateway.queryStoredGameCount(), 1);
  });
}

List<int> _startPositionPayload() {
  final data = List<int>.filled(34, 0);

  void setSquare(int boardIndex, String piece) {
    final dataIndex = boardIndex ~/ 2 + 2;
    final value = ChessnutBoardFenCodec.pieceToCode[piece]!;
    if (boardIndex.isEven) {
      data[dataIndex] = (data[dataIndex] & 0xf0) | value;
    } else {
      data[dataIndex] = (data[dataIndex] & 0x0f) | (value << 4);
    }
  }

  setSquare(7, 'r');
  setSquare(6, 'n');
  setSquare(5, 'b');
  setSquare(4, 'q');
  setSquare(3, 'k');
  setSquare(2, 'b');
  setSquare(1, 'n');
  setSquare(0, 'r');
  for (var i = 8; i < 16; i++) {
    setSquare(i, 'p');
  }
  for (var i = 48; i < 56; i++) {
    setSquare(i, 'P');
  }
  setSquare(63, 'R');
  setSquare(62, 'N');
  setSquare(61, 'B');
  setSquare(60, 'Q');
  setSquare(59, 'K');
  setSquare(58, 'B');
  setSquare(57, 'N');
  setSquare(56, 'R');
  return data;
}

bool _hasCommand(List<List<int>> writes, List<int> expected) {
  return writes.any(
    (write) =>
        write.length == expected.length &&
        Iterable.generate(write.length).every(
          (index) => write[index] == expected[index],
        ),
  );
}

List<int> _afterE4Payload() {
  final data = _startPositionPayload();
  void clearSquare(int boardIndex) {
    final dataIndex = boardIndex ~/ 2 + 2;
    if (boardIndex.isEven) {
      data[dataIndex] &= 0xf0;
    } else {
      data[dataIndex] &= 0x0f;
    }
  }

  void setSquare(int boardIndex, String piece) {
    final dataIndex = boardIndex ~/ 2 + 2;
    final value = ChessnutBoardFenCodec.pieceToCode[piece]!;
    if (boardIndex.isEven) {
      data[dataIndex] = (data[dataIndex] & 0xf0) | value;
    } else {
      data[dataIndex] = (data[dataIndex] & 0x0f) | (value << 4);
    }
  }

  clearSquare(51);
  setSquare(35, 'P');
  return data;
}

class FakePhysicalBoardTransport implements PhysicalBoardTransport {
  FakePhysicalBoardTransport({
    this.model = PhysicalBoardModel.move,
  });

  final PhysicalBoardModel model;
  final stateController =
      StreamController<PhysicalBoardConnectionState>.broadcast();
  final fenController = StreamController<List<int>>.broadcast();
  final responseController = StreamController<List<int>>.broadcast();
  final fileController = StreamController<List<int>>.broadcast();
  final writes = <List<int>>[];
  final writeWithoutResponse = <bool>[];

  @override
  PhysicalBoardModel get boardModel => model;

  @override
  PhysicalBoardConnectionState currentState =
      PhysicalBoardConnectionState.disconnected;

  @override
  Stream<PhysicalBoardConnectionState> get stateStream =>
      stateController.stream;

  @override
  Stream<List<int>> get fenPayloadStream => fenController.stream;

  @override
  Stream<List<int>> get responseStream => responseController.stream;

  @override
  Stream<List<int>> get filePayloadStream => fileController.stream;

  @override
  Future<bool> connect() async {
    currentState = PhysicalBoardConnectionState.connected;
    stateController.add(PhysicalBoardConnectionState.connected);
    return true;
  }

  @override
  Future<void> disconnect() async {
    currentState = PhysicalBoardConnectionState.disconnected;
    stateController.add(PhysicalBoardConnectionState.disconnected);
  }

  @override
  Future<bool> write(
    List<int> command, {
    bool withoutResponse = false,
  }) async {
    writes.add(List<int>.unmodifiable(command));
    writeWithoutResponse.add(withoutResponse);
    return true;
  }

  void addFenPayload(List<int> data) {
    fenController.add(data);
  }

  void addResponse(List<int> data) {
    responseController.add(data);
  }

  void addFilePayload(List<int> data) {
    fileController.add(data);
  }
}
