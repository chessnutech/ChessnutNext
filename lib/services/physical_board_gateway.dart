import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'board_settings_service.dart';
import 'easy_link_sdk_contract.dart';
import 'move_firmware_update_service.dart';
import 'physical_board_protocol.dart';

enum PhysicalBoardConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
}

enum PhysicalBoardModel {
  air,
  airPlus,
  pro,
  go,
  evo,
  evo2,
  general,
  pi,
  move,
  unknown,
}

extension PhysicalBoardModelProtocol on PhysicalBoardModel {
  bool get usesGeneralProtocol {
    return switch (this) {
      PhysicalBoardModel.air ||
      PhysicalBoardModel.airPlus ||
      PhysicalBoardModel.pro ||
      PhysicalBoardModel.go ||
      PhysicalBoardModel.evo ||
      PhysicalBoardModel.evo2 ||
      PhysicalBoardModel.general ||
      PhysicalBoardModel.pi =>
        true,
      PhysicalBoardModel.move || PhysicalBoardModel.unknown => false,
    };
  }

  bool get supportsColorLeds {
    return switch (this) {
      PhysicalBoardModel.move ||
      PhysicalBoardModel.evo ||
      PhysicalBoardModel.evo2 =>
        true,
      _ => false,
    };
  }

  bool get canSendColorLedCommands {
    return switch (this) {
      PhysicalBoardModel.move => true,
      _ => false,
    };
  }
}

class BoardBatteryStatus {
  const BoardBatteryStatus({
    required this.level,
    required this.isCharging,
  });

  final int level;
  final bool isCharging;

  int get bars {
    final clamped = level.clamp(0, 100);
    if (clamped <= 0) return 0;
    if (clamped <= 20) return 1;
    if (clamped <= 40) return 2;
    if (clamped <= 60) return 3;
    if (clamped <= 80) return 4;
    return 5;
  }

  bool get isLow => !isCharging && bars <= 1;
}

class BoardFirmwareVersions {
  const BoardFirmwareVersions({
    this.moveVersion,
    this.bluetoothVersion,
    this.mcuVersion,
  });

  final String? moveVersion;
  final String? bluetoothVersion;
  final String? mcuVersion;

  BoardFirmwareVersions copyWith({
    String? moveVersion,
    String? bluetoothVersion,
    String? mcuVersion,
  }) {
    return BoardFirmwareVersions(
      moveVersion: moveVersion ?? this.moveVersion,
      bluetoothVersion: bluetoothVersion ?? this.bluetoothVersion,
      mcuVersion: mcuVersion ?? this.mcuVersion,
    );
  }

  bool get hasAnyVersion =>
      _hasText(moveVersion) ||
      _hasText(bluetoothVersion) ||
      _hasText(mcuVersion);

  String? get primaryVersion =>
      _firstNonEmptyString([moveVersion, bluetoothVersion, mcuVersion]);
}

abstract class PhysicalBoardGateway {
  PhysicalBoardModel get boardModel;

  PhysicalBoardConnectionState get currentState =>
      PhysicalBoardConnectionState.disconnected;

  String? get latestBoardFen => null;

  Stream<PhysicalBoardConnectionState> get stateStream;

  Stream<String> get boardFenStream;

  Stream<BoardBatteryStatus> get boardBatteryStatusStream =>
      const Stream.empty();

  Stream<String> get boardFirmwareVersionStream => const Stream.empty();

  Stream<BoardFirmwareVersions> get boardFirmwareVersionsStream =>
      const Stream.empty();

  Stream<List<ChessnutMovePieceStatus>> get movePieceStatusStream =>
      const Stream.empty();

  bool get supportsStoredGameImport => false;

  Future<bool> connect();

  Future<void> disconnect();

  Future<bool> write(List<int> command, {bool withoutResponse = false});

  Future<bool> setEvo2LedPatternsForFen(
    String boardOnlyFen,
    Evo2LedPatternSet patterns,
  ) {
    return Future.value(false);
  }

  Future<bool> setEvo2LedPatternKeys(
    List<String?> squarePatternKeys,
    Evo2LedPatternSet patterns,
  ) {
    return Future.value(false);
  }

  Future<bool> setEvo2LedBrightness(int brightness) {
    return Future.value(false);
  }

  Future<bool> enableRealtimeFen() {
    final isMove = boardModel == PhysicalBoardModel.move;
    return write(
      isMove
          ? ChessnutMoveCommands.enableRealtimeFen
          : ChessnutGeneralCommands.enableRealtimeFen,
      withoutResponse: !isMove,
    );
  }

  Future<bool> setMoveBoardFen(
    String fen, {
    bool strictMode = false,
    bool isReverse = false,
  }) {
    return write(
      ChessnutMoveBoardCodec.setBoardCommand(
        fen,
        strictMode: strictMode,
        isReverse: isReverse,
      ),
    );
  }

  Future<bool> stopMoveBoard() {
    return write(ChessnutMoveBoardCodec.stopCommand());
  }

  Future<bool> setMoveLedSquares(Map<String, ChessnutMoveLedColor> squares) {
    return write(
      ChessnutMoveLedCodec.commandFromSquares(squares),
      withoutResponse: true,
    );
  }

  Future<bool> clearMoveLeds() {
    return write(ChessnutMoveLedCodec.offCommand(), withoutResponse: true);
  }

  Future<bool> setGeneralLedSquares(Set<String> squares) {
    return write(
      ChessnutLedCodec.ledCommandFromSquares(squares),
      withoutResponse: true,
    );
  }

  Future<bool> clearGeneralLeds() {
    return write(
      ChessnutLedCodec.ledCommand(List<int>.filled(64, 0)),
      withoutResponse: true,
    );
  }

  Future<bool> setBoardBeepEnabled(bool enabled) {
    if (boardModel == PhysicalBoardModel.move) return Future.value(false);
    return write(
      ChessnutGeneralCommands.setBeep(enabled),
      withoutResponse: true,
    );
  }

  Future<bool> playBeep({int frequency = 1000, int duration = 200}) {
    return write(
      ChessnutGeneralCommands.beep(
        frequency: frequency,
        duration: duration,
      ),
      withoutResponse: boardModel.usesGeneralProtocol,
    );
  }

  Future<bool> queryGeneralBatteryStatus() {
    return write(
      ChessnutGeneralCommands.batteryStatus,
      withoutResponse: true,
    );
  }

  Future<bool> queryBoardBatteryStatus() {
    if (boardModel == PhysicalBoardModel.move) {
      return write(ChessnutMoveCommands.batteryStatus);
    }
    return queryGeneralBatteryStatus();
  }

  Future<bool> queryMovePieceStatus() {
    if (boardModel != PhysicalBoardModel.move) return Future.value(false);
    return write(ChessnutMoveCommands.pieceStatus);
  }

  Future<bool> queryBoardFirmwareVersion() {
    return queryGeneralBleVersion();
  }

  bool get isMoveFirmwareUpdateInProgress => false;

  Future<bool> checkMoveFirmwareUpdateSupport() async => false;

  Future<bool> configureMoveFirmwareWifi({
    required String ssid,
    required String password,
  }) async =>
      false;

  Future<bool> startMoveWifiFirmwareUpdate() async => false;

  Future<bool> sendMoveFirmwareUpdateFile(
    Uint8List data, {
    MoveFirmwareProgress? onProgress,
  }) async =>
      false;

  Future<bool> queryGeneralBleVersion() {
    return write(
      ChessnutGeneralCommands.bleVersion,
      withoutResponse: true,
    );
  }

  Future<bool> queryGeneralMcuVersion() {
    return write(
      ChessnutGeneralCommands.mcuVersion,
      withoutResponse: true,
    );
  }

  Future<bool> queryGeneralFileCount() {
    return write(
      ChessnutGeneralCommands.fileCount,
      withoutResponse: true,
    );
  }

  Future<int?> queryMoveChannel() async {
    return null;
  }

  Future<bool> setMoveChannel(int channel) {
    if (boardModel != PhysicalBoardModel.move) return Future.value(false);
    return write(ChessnutMoveCommands.setChannel(channel));
  }

  Future<int?> discoverMovePieceChannel() async {
    return null;
  }

  Future<List<String>?> queryMovePieceData() async {
    return null;
  }

  Future<bool> setMovePieceData(List<String> names) {
    if (boardModel != PhysicalBoardModel.move) return Future.value(false);
    return write(_moveSetPieceDataCommand(names));
  }

  Future<bool> startMovePiecePairing(int channel) {
    if (boardModel != PhysicalBoardModel.move) return Future.value(false);
    return write(ChessnutMoveCommands.startPiecePairing(channel));
  }

  Future<bool> finishMovePiecePairing() {
    if (boardModel != PhysicalBoardModel.move) return Future.value(false);
    return write(ChessnutMoveCommands.finishPiecePairing());
  }

  Future<bool> exitMovePiecePairing() {
    if (boardModel != PhysicalBoardModel.move) return Future.value(false);
    return write(ChessnutMoveCommands.exitPiecePairing());
  }

  Future<bool> setMovePieceAutoPoweroff(bool enabled) {
    if (boardModel != PhysicalBoardModel.move) return Future.value(false);
    return write(ChessnutMoveCommands.setPieceAutoPoweroff(enabled));
  }

  Future<int?> queryStoredGameCount() async {
    return null;
  }

  Future<String?> peekStoredGameFile() async {
    return null;
  }

  Future<String?> readAndDeleteStoredGameFile() async {
    return null;
  }

  /// Called only after the app has durably saved the previously peeked file.
  Future<bool> deleteStoredGameFile() async => false;
}

abstract class PhysicalBoardTransport {
  PhysicalBoardModel get boardModel;

  PhysicalBoardConnectionState get currentState =>
      PhysicalBoardConnectionState.disconnected;

  Stream<PhysicalBoardConnectionState> get stateStream;

  Stream<List<int>> get fenPayloadStream;

  Stream<List<int>> get responseStream;

  Stream<List<int>> get filePayloadStream => const Stream.empty();

  Future<bool> connect();

  Future<void> disconnect();

  Future<bool> write(List<int> command, {bool withoutResponse = false});
}

abstract interface class MoveFirmwarePacketTransport {
  Future<bool> writeMoveFirmwarePacket(
    List<int> command, {
    required bool withoutResponse,
    required Duration minimumGap,
    required bool trackWriteTime,
  });
}

MoveFirmwareUpdateController _createMoveFirmwareUpdateController(
  PhysicalBoardTransport transport,
) {
  return MoveFirmwareUpdateController(
    write: (
      command, {
      bool withoutResponse = false,
      Duration minimumGap = Duration.zero,
      bool trackWriteTime = false,
    }) {
      if (transport is MoveFirmwarePacketTransport) {
        return (transport as MoveFirmwarePacketTransport)
            .writeMoveFirmwarePacket(
          command,
          withoutResponse: withoutResponse,
          minimumGap: minimumGap,
          trackWriteTime: trackWriteTime,
        );
      }
      return transport.write(command, withoutResponse: withoutResponse);
    },
    responseStream: transport.responseStream,
    connectionStream: transport.stateStream.map(
      (state) => state == PhysicalBoardConnectionState.connected,
    ),
    isConnected: () =>
        transport.currentState == PhysicalBoardConnectionState.connected,
  );
}

abstract class Evo2LedPatternBoardTransport {
  Future<bool> setEvo2LedBrightness(int brightness);

  Future<bool> setEvo2LedPatternsForFen(
    String boardOnlyFen,
    Evo2LedPatternSet patterns,
  );

  Future<bool> setEvo2LedPatternKeys(
    List<String?> squarePatternKeys,
    Evo2LedPatternSet patterns,
  );
}

class ChessnutBoardGateway extends PhysicalBoardGateway {
  ChessnutBoardGateway({required this.transport}) {
    _moveFirmwareUpdateController = _createMoveFirmwareUpdateController(
      transport,
    );
    _fenSub = transport.fenPayloadStream.listen(_handleFenPayload);
    _responseSub = transport.responseStream.listen(_handleResponse);
    _fileSub = transport.filePayloadStream.listen(_handleFilePayload);
  }

  final PhysicalBoardTransport transport;
  late final MoveFirmwareUpdateController _moveFirmwareUpdateController;
  final _fenController = StreamController<String>.broadcast();
  final _generalBatteryController =
      StreamController<ChessnutGeneralBatteryStatus>.broadcast();
  final _generalVersionController = StreamController<String>.broadcast();
  final _boardFirmwareVersionsController =
      StreamController<BoardFirmwareVersions>.broadcast();
  final _generalFileCountController = StreamController<int>.broadcast();
  final _moveBatteryController =
      StreamController<ChessnutMoveBatteryStatus>.broadcast();
  final _movePieceStatusController =
      StreamController<List<ChessnutMovePieceStatus>>.broadcast();
  final _boardBatteryController =
      StreamController<BoardBatteryStatus>.broadcast();
  final _fenAssembler = _FenPayloadAssembler();
  String? _latestBoardFen;
  StreamSubscription<List<int>>? _fenSub;
  StreamSubscription<List<int>>? _responseSub;
  StreamSubscription<List<int>>? _fileSub;
  Completer<int?>? _pendingFileCount;
  Completer<String?>? _pendingStoredGameFile;
  Completer<int?>? _pendingMoveChannel;
  Completer<int?>? _pendingMoveDiscoveredChannel;
  Completer<List<String>?>? _pendingMovePieceData;
  Completer<bool>? _pendingMovePairingResult;
  bool _storedGameFileReading = false;
  final _storedGameFileFens = <String>[];
  final _moveStoredGameFileBuffer = StringBuffer();
  BoardFirmwareVersions _boardFirmwareVersions = const BoardFirmwareVersions();

  @override
  PhysicalBoardModel get boardModel => transport.boardModel;

  @override
  PhysicalBoardConnectionState get currentState => transport.currentState;

  @override
  Stream<PhysicalBoardConnectionState> get stateStream => transport.stateStream;

  @override
  Stream<String> get boardFenStream => _fenController.stream;

  @override
  String? get latestBoardFen => _latestBoardFen;

  Stream<ChessnutGeneralBatteryStatus> get generalBatteryStatusStream =>
      _generalBatteryController.stream;

  Stream<String> get generalVersionStream => _generalVersionController.stream;

  @override
  Stream<String> get boardFirmwareVersionStream =>
      _generalVersionController.stream;

  @override
  Stream<BoardFirmwareVersions> get boardFirmwareVersionsStream =>
      _boardFirmwareVersionsController.stream;

  Stream<int> get generalFileCountStream => _generalFileCountController.stream;

  Stream<ChessnutMoveBatteryStatus> get moveBatteryStatusStream =>
      _moveBatteryController.stream;

  @override
  Stream<List<ChessnutMovePieceStatus>> get movePieceStatusStream =>
      _movePieceStatusController.stream;

  @override
  Stream<BoardBatteryStatus> get boardBatteryStatusStream =>
      _boardBatteryController.stream;

  @override
  bool get supportsStoredGameImport =>
      boardModel.usesGeneralProtocol || boardModel == PhysicalBoardModel.move;

  @override
  Future<bool> connect() {
    return transport.connect();
  }

  @override
  Future<void> disconnect() {
    return transport.disconnect();
  }

  @override
  Future<bool> write(
    List<int> command, {
    bool withoutResponse = false,
  }) {
    if (_moveFirmwareUpdateController.isBusy) {
      return _moveFirmwareUpdateController.writeWhenIdle(
        () => transport.write(command, withoutResponse: withoutResponse),
      );
    }
    return transport.write(command, withoutResponse: withoutResponse);
  }

  @override
  bool get isMoveFirmwareUpdateInProgress =>
      _moveFirmwareUpdateController.isBusy;

  @override
  Future<bool> checkMoveFirmwareUpdateSupport() {
    if (boardModel != PhysicalBoardModel.move) return Future.value(false);
    return _moveFirmwareUpdateController.checkBluetoothUpdateSupport();
  }

  @override
  Future<bool> configureMoveFirmwareWifi({
    required String ssid,
    required String password,
  }) {
    if (boardModel != PhysicalBoardModel.move) return Future.value(false);
    return _moveFirmwareUpdateController.configureWifi(
      ssid: ssid,
      password: password,
    );
  }

  @override
  Future<bool> startMoveWifiFirmwareUpdate() {
    if (boardModel != PhysicalBoardModel.move) return Future.value(false);
    return _moveFirmwareUpdateController.startWifiUpdate();
  }

  @override
  Future<bool> sendMoveFirmwareUpdateFile(
    Uint8List data, {
    MoveFirmwareProgress? onProgress,
  }) {
    if (boardModel != PhysicalBoardModel.move) return Future.value(false);
    return _moveFirmwareUpdateController.sendFirmwareFile(
      data,
      onProgress: onProgress,
    );
  }

  @override
  Future<bool> setEvo2LedPatternsForFen(
    String boardOnlyFen,
    Evo2LedPatternSet patterns,
  ) {
    final evo2Transport = transport;
    if (evo2Transport is Evo2LedPatternBoardTransport) {
      return (evo2Transport as Evo2LedPatternBoardTransport)
          .setEvo2LedPatternsForFen(boardOnlyFen, patterns);
    }
    return Future.value(false);
  }

  @override
  Future<bool> setEvo2LedBrightness(int brightness) {
    final evo2Transport = transport;
    if (evo2Transport is Evo2LedPatternBoardTransport) {
      return (evo2Transport as Evo2LedPatternBoardTransport)
          .setEvo2LedBrightness(brightness);
    }
    return Future.value(false);
  }

  @override
  Future<bool> setEvo2LedPatternKeys(
    List<String?> squarePatternKeys,
    Evo2LedPatternSet patterns,
  ) {
    final evo2Transport = transport;
    if (evo2Transport is Evo2LedPatternBoardTransport) {
      return (evo2Transport as Evo2LedPatternBoardTransport)
          .setEvo2LedPatternKeys(squarePatternKeys, patterns);
    }
    return Future.value(false);
  }

  @override
  Future<bool> enableRealtimeFen() {
    final isMove = boardModel == PhysicalBoardModel.move;
    return write(
      isMove
          ? ChessnutMoveCommands.enableRealtimeFen
          : ChessnutGeneralCommands.enableRealtimeFen,
      withoutResponse: !isMove,
    );
  }

  Future<void> dispose() async {
    await transport.disconnect();
    await _fenSub?.cancel();
    await _responseSub?.cancel();
    await _fileSub?.cancel();
    await _fenController.close();
    await _generalBatteryController.close();
    await _generalVersionController.close();
    await _boardFirmwareVersionsController.close();
    await _generalFileCountController.close();
    await _moveBatteryController.close();
    await _movePieceStatusController.close();
    await _boardBatteryController.close();
  }

  void _handleFenPayload(List<int> data) {
    for (final payload in _fenAssembler.add(data)) {
      final fen = ChessnutBoardFenCodec.tryDecode(payload);
      if (fen != null) {
        _latestBoardFen = fen;
        _fenController.add(fen);
      }
    }
  }

  void _handleResponse(List<int> data) {
    if (data.isEmpty) return;
    if (data.length >= 3 && data[0] == 0x37 && data[1] == 0x01) {
      _handleFilePayload(data);
      return;
    }
    if (_storedGameFileReading && data[0] == 0x01) {
      _handleFilePayload(data);
      return;
    }
    if (data.length >= 3 && data[0] == 0x41) {
      switch (data[2]) {
        case 0x0c:
          final battery = ChessnutMoveBatteryStatus.parse(data);
          _moveBatteryController.add(battery);
          _boardBatteryController.add(
            BoardBatteryStatus(
              level: battery.level,
              isCharging: battery.isCharging,
            ),
          );
        case 0x0b:
          _movePieceStatusController.add(
            ChessnutMovePieceStatus.parseResponse(data),
          );
        case 0x15:
          _completeFileCount(_parseMoveFileCount(data));
        case 0x16:
          _handleMoveStoredGameFile(data);
        case 0x13:
          _completeMoveChannel(_parseMoveSingleBytePayload(data));
        case 0x19:
          _completeMoveDiscoveredChannel(_parseMoveDiscoveredChannel(data));
        case 0x1b:
          _completeMovePieceData(_parseMovePieceData(data));
        case 0x10:
          _completeMovePairing(_parseMovePairingResult(data));
        case 0x09:
          _emitBoardFirmwareVersions(
            _boardFirmwareVersions.copyWith(
              moveVersion: ChessnutMoveFirmwareVersionResponse.parse(data),
            ),
          );
      }
      return;
    }

    switch (data[0]) {
      case 0x2a:
        final battery = ChessnutGeneralBatteryStatus.parse(data);
        _generalBatteryController.add(battery);
        _boardBatteryController.add(
          BoardBatteryStatus(
            level: battery.level,
            isCharging: battery.isCharging,
          ),
        );
      case 0x28:
        final version = ChessnutGeneralVersionResponse.parse(data);
        _generalVersionController.add(version);
        _emitBoardFirmwareVersions(
          _boardFirmwareVersions.copyWith(bluetoothVersion: version),
        );
      case 0x32:
        final count = ChessnutGeneralFileCountResponse.parse(data);
        _generalFileCountController.add(count);
        _completeFileCount(count);
    }
  }

  @override
  Future<bool> queryBoardFirmwareVersion() async {
    final bluetoothSent = await queryGeneralBleVersion();
    if (boardModel != PhysicalBoardModel.move) {
      return bluetoothSent;
    }
    final moveSent = await write(ChessnutMoveCommands.firmwareVersion);
    return bluetoothSent || moveSent;
  }

  @override
  Future<int?> queryStoredGameCount() async {
    if (!supportsStoredGameImport) return null;
    final completer = Completer<int?>();
    _pendingFileCount?.complete(null);
    _pendingFileCount = completer;
    final sent = boardModel == PhysicalBoardModel.move
        ? await write(ChessnutMoveCommands.fileCount)
        : await queryGeneralFileCount();
    if (!sent) {
      if (identical(_pendingFileCount, completer)) {
        _pendingFileCount = null;
      }
      return null;
    }
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        if (identical(_pendingFileCount, completer)) {
          _pendingFileCount = null;
        }
        return null;
      },
    );
  }

  @override
  Future<String?> peekStoredGameFile() async {
    if (!supportsStoredGameImport) return null;
    return _readStoredGameFile(deleteAfterRead: false);
  }

  @override
  Future<String?> readAndDeleteStoredGameFile() async {
    if (!supportsStoredGameImport) return null;
    return _readStoredGameFile(deleteAfterRead: true);
  }

  @override
  Future<bool> deleteStoredGameFile() async {
    if (!supportsStoredGameImport) return false;
    if (boardModel == PhysicalBoardModel.move) {
      return write(ChessnutMoveCommands.deleteStoredGameFile);
    }
    if (!boardModel.usesGeneralProtocol) return false;
    return write(ChessnutGeneralCommands.deleteFiles, withoutResponse: true);
  }

  Future<String?> _readStoredGameFile({required bool deleteAfterRead}) async {
    if (boardModel == PhysicalBoardModel.move) {
      return _readMoveStoredGameFile(deleteAfterRead: deleteAfterRead);
    }
    if (!boardModel.usesGeneralProtocol) return null;
    final count = await queryStoredGameCount();
    if (count == null || count <= 0) return null;
    final completer = Completer<String?>();
    _pendingStoredGameFile?.complete(null);
    _pendingStoredGameFile = completer;
    _storedGameFileReading = false;
    _storedGameFileFens.clear();
    _moveStoredGameFileBuffer.clear();

    await write(
      ChessnutGeneralCommands.enableFileUploadMode,
      withoutResponse: true,
    );
    await write(ChessnutGeneralCommands.startFileRead, withoutResponse: true);
    final sent = await write(
      ChessnutGeneralCommands.readNextFileChunk,
      withoutResponse: true,
    );
    if (!sent) {
      _clearStoredGameRead(completer);
      return null;
    }

    final content = await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        if (identical(_pendingStoredGameFile, completer)) {
          final partial = _finishStoredGameRead();
          _pendingStoredGameFile = null;
          return partial;
        }
        return null;
      },
    );
    if (deleteAfterRead && content != null && content.trim().isNotEmpty) {
      await write(
        ChessnutGeneralCommands.deleteFiles,
        withoutResponse: true,
      );
    }
    await enableRealtimeFen();
    return content;
  }

  Future<String?> _readMoveStoredGameFile({
    required bool deleteAfterRead,
  }) async {
    final count = await queryStoredGameCount();
    if (count == null || count <= 0) return null;
    final completer = Completer<String?>();
    _pendingStoredGameFile?.complete(null);
    _pendingStoredGameFile = completer;
    _storedGameFileReading = false;
    _storedGameFileFens.clear();
    _moveStoredGameFileBuffer.clear();

    final sent = await write(ChessnutMoveCommands.readStoredGameFile);
    if (!sent) {
      _clearStoredGameRead(completer);
      return null;
    }

    final content = await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        if (identical(_pendingStoredGameFile, completer)) {
          final partial = _finishMoveStoredGameRead();
          _pendingStoredGameFile = null;
          return partial;
        }
        return null;
      },
    );
    if (deleteAfterRead && content != null && content.trim().isNotEmpty) {
      await write(ChessnutMoveCommands.deleteStoredGameFile);
    }
    return content;
  }

  void _handleFilePayload(List<int> data) {
    if (data.length >= 3 && data[0] == 0x37 && data[1] == 0x01) {
      if (data[2] == 0xbe) {
        _storedGameFileReading = true;
        _storedGameFileFens.clear();
        return;
      }
      if (data[2] == 0xed) {
        final content = _finishStoredGameRead();
        final completer = _pendingStoredGameFile;
        _pendingStoredGameFile = null;
        if (completer != null && !completer.isCompleted) {
          completer.complete(content);
        }
        return;
      }
    }
    if (!_storedGameFileReading) return;
    final fen = ChessnutBoardFenCodec.tryDecode(data);
    if (fen != null) {
      _storedGameFileFens.add(fen);
    }
  }

  void _handleMoveStoredGameFile(List<int> data) {
    if (data.length < 4) return;
    final flag = data[3];
    if (flag == 0x01) {
      if (data.length > 4) {
        _moveStoredGameFileBuffer.write(utf8.decode(data.sublist(4)));
      }
      return;
    }
    if (flag == 0x00) {
      final content = _finishMoveStoredGameRead();
      final completer = _pendingStoredGameFile;
      _pendingStoredGameFile = null;
      if (completer != null && !completer.isCompleted) {
        completer.complete(content);
      }
    }
  }

  String? _finishStoredGameRead() {
    _storedGameFileReading = false;
    final content = _storedGameFileFens.join(';');
    _storedGameFileFens.clear();
    return content.isEmpty ? null : content;
  }

  String? _finishMoveStoredGameRead() {
    final content = _moveStoredGameFileBuffer.toString().trim();
    _moveStoredGameFileBuffer.clear();
    return content.isEmpty ? null : content;
  }

  void _clearStoredGameRead(Completer<String?> completer) {
    if (identical(_pendingStoredGameFile, completer)) {
      _pendingStoredGameFile = null;
    }
    _storedGameFileReading = false;
    _storedGameFileFens.clear();
    _moveStoredGameFileBuffer.clear();
  }

  void _completeFileCount(int? count) {
    final completer = _pendingFileCount;
    _pendingFileCount = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(count);
    }
  }

  int? _parseMoveFileCount(List<int> data) {
    if (data.length < 4) return null;
    return data[3];
  }

  @override
  Future<int?> queryMoveChannel() async {
    if (boardModel != PhysicalBoardModel.move) return null;
    final completer = Completer<int?>();
    _pendingMoveChannel?.complete(null);
    _pendingMoveChannel = completer;
    final sent = await write(ChessnutMoveCommands.getChannel);
    if (!sent) {
      _clearPending(_pendingMoveChannel, completer, () {
        _pendingMoveChannel = null;
      });
      return null;
    }
    return _timeoutPending(
      completer,
      const Duration(seconds: 5),
      () => _pendingMoveChannel = null,
    );
  }

  @override
  Future<int?> discoverMovePieceChannel() async {
    if (boardModel != PhysicalBoardModel.move) return null;
    final completer = Completer<int?>();
    _pendingMoveDiscoveredChannel?.complete(null);
    _pendingMoveDiscoveredChannel = completer;
    final sent = await write(ChessnutMoveCommands.discoverPieceChannel);
    if (!sent) {
      _clearPending(_pendingMoveDiscoveredChannel, completer, () {
        _pendingMoveDiscoveredChannel = null;
      });
      return null;
    }
    return _timeoutPending(
      completer,
      const Duration(seconds: 10),
      () => _pendingMoveDiscoveredChannel = null,
    );
  }

  @override
  Future<List<String>?> queryMovePieceData() async {
    if (boardModel != PhysicalBoardModel.move) return null;
    final completer = Completer<List<String>?>();
    _pendingMovePieceData?.complete(null);
    _pendingMovePieceData = completer;
    final sent = await write(ChessnutMoveCommands.getPieceData);
    if (!sent) {
      _clearPending(_pendingMovePieceData, completer, () {
        _pendingMovePieceData = null;
      });
      return null;
    }
    return _timeoutPending(
      completer,
      const Duration(seconds: 10),
      () => _pendingMovePieceData = null,
    );
  }

  @override
  Future<bool> finishMovePiecePairing() async {
    if (boardModel != PhysicalBoardModel.move) return false;
    final completer = Completer<bool>();
    _pendingMovePairingResult?.complete(false);
    _pendingMovePairingResult = completer;
    final sent = await write(ChessnutMoveCommands.finishPiecePairing());
    if (!sent) {
      _clearPending(_pendingMovePairingResult, completer, () {
        _pendingMovePairingResult = null;
      });
      return false;
    }
    return _timeoutPending(
      completer,
      const Duration(minutes: 60),
      () => _pendingMovePairingResult = null,
      fallback: false,
    );
  }

  void _completeMoveChannel(int? value) {
    final completer = _pendingMoveChannel;
    _pendingMoveChannel = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(value);
    }
  }

  void _completeMoveDiscoveredChannel(int? value) {
    final completer = _pendingMoveDiscoveredChannel;
    _pendingMoveDiscoveredChannel = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(value);
    }
  }

  void _completeMovePieceData(List<String>? value) {
    final completer = _pendingMovePieceData;
    _pendingMovePieceData = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(value);
    }
  }

  void _completeMovePairing(bool value) {
    final completer = _pendingMovePairingResult;
    _pendingMovePairingResult = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(value);
    }
  }

  void _emitBoardFirmwareVersions(BoardFirmwareVersions versions) {
    if (!versions.hasAnyVersion) return;
    _boardFirmwareVersions = versions;
    _boardFirmwareVersionsController.add(versions);
  }
}

class ChessnutMoveGateway extends PhysicalBoardGateway {
  ChessnutMoveGateway({required this.transport}) {
    _moveFirmwareUpdateController = _createMoveFirmwareUpdateController(
      transport,
    );
    _fenSub = transport.fenPayloadStream.listen(_handleFenPayload);
    _responseSub = transport.responseStream.listen(_handleResponse);
  }

  final PhysicalBoardTransport transport;
  late final MoveFirmwareUpdateController _moveFirmwareUpdateController;
  final _fenController = StreamController<String>.broadcast();
  final _batteryController =
      StreamController<ChessnutMoveBatteryStatus>.broadcast();
  final _pieceStatusController =
      StreamController<List<ChessnutMovePieceStatus>>.broadcast();
  final _firmwareVersionController = StreamController<String>.broadcast();
  final _firmwareVersionsController =
      StreamController<BoardFirmwareVersions>.broadcast();
  final _fenAssembler = _FenPayloadAssembler();
  String? _latestBoardFen;
  StreamSubscription<List<int>>? _fenSub;
  StreamSubscription<List<int>>? _responseSub;
  Completer<int?>? _pendingFileCount;
  Completer<String?>? _pendingStoredGameFile;
  Completer<int?>? _pendingMoveChannel;
  Completer<int?>? _pendingMoveDiscoveredChannel;
  Completer<List<String>?>? _pendingMovePieceData;
  Completer<bool>? _pendingMovePairingResult;
  final _storedGameFileBuffer = StringBuffer();
  BoardFirmwareVersions _firmwareVersions = const BoardFirmwareVersions();

  @override
  PhysicalBoardModel get boardModel => PhysicalBoardModel.move;

  @override
  PhysicalBoardConnectionState get currentState => transport.currentState;

  @override
  Stream<PhysicalBoardConnectionState> get stateStream => transport.stateStream;

  @override
  Stream<String> get boardFenStream => _fenController.stream;

  @override
  String? get latestBoardFen => _latestBoardFen;

  Stream<ChessnutMoveBatteryStatus> get batteryStatusStream =>
      _batteryController.stream;

  @override
  Stream<String> get boardFirmwareVersionStream =>
      _firmwareVersionController.stream;

  @override
  Stream<BoardFirmwareVersions> get boardFirmwareVersionsStream =>
      _firmwareVersionsController.stream;

  @override
  Stream<List<ChessnutMovePieceStatus>> get movePieceStatusStream =>
      _pieceStatusController.stream;

  @override
  Stream<BoardBatteryStatus> get boardBatteryStatusStream =>
      batteryStatusStream.map(
        (battery) => BoardBatteryStatus(
          level: battery.level,
          isCharging: battery.isCharging,
        ),
      );

  @override
  bool get supportsStoredGameImport => true;

  @override
  Future<bool> connect() {
    return transport.connect();
  }

  @override
  Future<void> disconnect() {
    return transport.disconnect();
  }

  @override
  Future<bool> write(
    List<int> command, {
    bool withoutResponse = false,
  }) {
    if (_moveFirmwareUpdateController.isBusy) {
      return _moveFirmwareUpdateController.writeWhenIdle(
        () => transport.write(command, withoutResponse: withoutResponse),
      );
    }
    return transport.write(command, withoutResponse: withoutResponse);
  }

  @override
  bool get isMoveFirmwareUpdateInProgress =>
      _moveFirmwareUpdateController.isBusy;

  @override
  Future<bool> checkMoveFirmwareUpdateSupport() {
    return _moveFirmwareUpdateController.checkBluetoothUpdateSupport();
  }

  @override
  Future<bool> configureMoveFirmwareWifi({
    required String ssid,
    required String password,
  }) {
    return _moveFirmwareUpdateController.configureWifi(
      ssid: ssid,
      password: password,
    );
  }

  @override
  Future<bool> startMoveWifiFirmwareUpdate() {
    return _moveFirmwareUpdateController.startWifiUpdate();
  }

  @override
  Future<bool> sendMoveFirmwareUpdateFile(
    Uint8List data, {
    MoveFirmwareProgress? onProgress,
  }) {
    return _moveFirmwareUpdateController.sendFirmwareFile(
      data,
      onProgress: onProgress,
    );
  }

  Future<void> dispose() async {
    await transport.disconnect();
    await _fenSub?.cancel();
    await _responseSub?.cancel();
    await _fenController.close();
    await _batteryController.close();
    await _pieceStatusController.close();
    await _firmwareVersionController.close();
    await _firmwareVersionsController.close();
  }

  void _handleFenPayload(List<int> data) {
    for (final payload in _fenAssembler.add(data)) {
      final fen = ChessnutBoardFenCodec.tryDecode(payload);
      if (fen != null) {
        _latestBoardFen = fen;
        _fenController.add(fen);
      }
    }
  }

  void _handleResponse(List<int> data) {
    if (data.isNotEmpty && data[0] == 0x28) {
      _emitFirmwareVersions(
        _firmwareVersions.copyWith(
          bluetoothVersion: ChessnutGeneralVersionResponse.parse(data),
        ),
      );
      return;
    }
    if (data.length < 3 || data[0] != 0x41) {
      return;
    }
    switch (data[2]) {
      case 0x0c:
        _batteryController.add(ChessnutMoveBatteryStatus.parse(data));
      case 0x0b:
        _pieceStatusController.add(ChessnutMovePieceStatus.parseResponse(data));
      case 0x15:
        _completeFileCount(_parseMoveFileCount(data));
      case 0x16:
        _handleMoveStoredGameFile(data);
      case 0x13:
        _completeMoveChannel(_parseMoveSingleBytePayload(data));
      case 0x19:
        _completeMoveDiscoveredChannel(_parseMoveDiscoveredChannel(data));
      case 0x1b:
        _completeMovePieceData(_parseMovePieceData(data));
      case 0x10:
        _completeMovePairing(_parseMovePairingResult(data));
      case 0x09:
        _emitFirmwareVersions(
          _firmwareVersions.copyWith(
            moveVersion: ChessnutMoveFirmwareVersionResponse.parse(data),
          ),
        );
    }
  }

  @override
  Future<bool> queryBoardFirmwareVersion() async {
    final bluetoothSent = await queryGeneralBleVersion();
    final moveSent = await write(ChessnutMoveCommands.firmwareVersion);
    return bluetoothSent || moveSent;
  }

  @override
  Future<int?> queryStoredGameCount() async {
    final completer = Completer<int?>();
    _pendingFileCount?.complete(null);
    _pendingFileCount = completer;
    final sent = await write(ChessnutMoveCommands.fileCount);
    if (!sent) {
      if (identical(_pendingFileCount, completer)) {
        _pendingFileCount = null;
      }
      return null;
    }
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        if (identical(_pendingFileCount, completer)) {
          _pendingFileCount = null;
        }
        return null;
      },
    );
  }

  @override
  Future<String?> peekStoredGameFile() {
    return _readStoredGameFile(deleteAfterRead: false);
  }

  @override
  Future<String?> readAndDeleteStoredGameFile() {
    return _readStoredGameFile(deleteAfterRead: true);
  }

  @override
  Future<bool> deleteStoredGameFile() => write(ChessnutMoveCommands.deleteStoredGameFile);

  Future<String?> _readStoredGameFile({required bool deleteAfterRead}) async {
    final count = await queryStoredGameCount();
    if (count == null || count <= 0) return null;
    final completer = Completer<String?>();
    _pendingStoredGameFile?.complete(null);
    _pendingStoredGameFile = completer;
    _storedGameFileBuffer.clear();

    final sent = await write(ChessnutMoveCommands.readStoredGameFile);
    if (!sent) {
      _clearStoredGameRead(completer);
      return null;
    }

    final content = await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        if (identical(_pendingStoredGameFile, completer)) {
          final partial = _finishStoredGameRead();
          _pendingStoredGameFile = null;
          return partial;
        }
        return null;
      },
    );
    if (deleteAfterRead && content != null && content.trim().isNotEmpty) {
      await write(ChessnutMoveCommands.deleteStoredGameFile);
    }
    return content;
  }

  void _handleMoveStoredGameFile(List<int> data) {
    if (data.length < 4) return;
    final flag = data[3];
    if (flag == 0x01) {
      if (data.length > 4) {
        _storedGameFileBuffer.write(utf8.decode(data.sublist(4)));
      }
      return;
    }
    if (flag == 0x00) {
      final content = _finishStoredGameRead();
      final completer = _pendingStoredGameFile;
      _pendingStoredGameFile = null;
      if (completer != null && !completer.isCompleted) {
        completer.complete(content);
      }
    }
  }

  String? _finishStoredGameRead() {
    final content = _storedGameFileBuffer.toString().trim();
    _storedGameFileBuffer.clear();
    return content.isEmpty ? null : content;
  }

  void _clearStoredGameRead(Completer<String?> completer) {
    if (identical(_pendingStoredGameFile, completer)) {
      _pendingStoredGameFile = null;
    }
    _storedGameFileBuffer.clear();
  }

  void _completeFileCount(int? count) {
    final completer = _pendingFileCount;
    _pendingFileCount = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(count);
    }
  }

  @override
  Future<int?> queryMoveChannel() async {
    final completer = Completer<int?>();
    _pendingMoveChannel?.complete(null);
    _pendingMoveChannel = completer;
    final sent = await write(ChessnutMoveCommands.getChannel);
    if (!sent) {
      _clearPending(_pendingMoveChannel, completer, () {
        _pendingMoveChannel = null;
      });
      return null;
    }
    return _timeoutPending(
      completer,
      const Duration(seconds: 5),
      () => _pendingMoveChannel = null,
    );
  }

  @override
  Future<int?> discoverMovePieceChannel() async {
    final completer = Completer<int?>();
    _pendingMoveDiscoveredChannel?.complete(null);
    _pendingMoveDiscoveredChannel = completer;
    final sent = await write(ChessnutMoveCommands.discoverPieceChannel);
    if (!sent) {
      _clearPending(_pendingMoveDiscoveredChannel, completer, () {
        _pendingMoveDiscoveredChannel = null;
      });
      return null;
    }
    return _timeoutPending(
      completer,
      const Duration(seconds: 10),
      () => _pendingMoveDiscoveredChannel = null,
    );
  }

  @override
  Future<List<String>?> queryMovePieceData() async {
    final completer = Completer<List<String>?>();
    _pendingMovePieceData?.complete(null);
    _pendingMovePieceData = completer;
    final sent = await write(ChessnutMoveCommands.getPieceData);
    if (!sent) {
      _clearPending(_pendingMovePieceData, completer, () {
        _pendingMovePieceData = null;
      });
      return null;
    }
    return _timeoutPending(
      completer,
      const Duration(seconds: 10),
      () => _pendingMovePieceData = null,
    );
  }

  @override
  Future<bool> finishMovePiecePairing() async {
    final completer = Completer<bool>();
    _pendingMovePairingResult?.complete(false);
    _pendingMovePairingResult = completer;
    final sent = await write(ChessnutMoveCommands.finishPiecePairing());
    if (!sent) {
      _clearPending(_pendingMovePairingResult, completer, () {
        _pendingMovePairingResult = null;
      });
      return false;
    }
    return _timeoutPending(
      completer,
      const Duration(minutes: 60),
      () => _pendingMovePairingResult = null,
      fallback: false,
    );
  }

  void _completeMoveChannel(int? value) {
    final completer = _pendingMoveChannel;
    _pendingMoveChannel = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(value);
    }
  }

  void _completeMoveDiscoveredChannel(int? value) {
    final completer = _pendingMoveDiscoveredChannel;
    _pendingMoveDiscoveredChannel = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(value);
    }
  }

  void _completeMovePieceData(List<String>? value) {
    final completer = _pendingMovePieceData;
    _pendingMovePieceData = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(value);
    }
  }

  void _completeMovePairing(bool value) {
    final completer = _pendingMovePairingResult;
    _pendingMovePairingResult = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(value);
    }
  }

  int? _parseMoveFileCount(List<int> data) {
    if (data.length < 4) return null;
    return data[3];
  }

  void _emitFirmwareVersions(BoardFirmwareVersions versions) {
    if (!versions.hasAnyVersion) return;
    _firmwareVersions = versions;
    final primary = versions.primaryVersion;
    if (primary != null) {
      _firmwareVersionController.add(primary);
    }
    _firmwareVersionsController.add(versions);
  }
}

class EasyLinkBoardGateway extends PhysicalBoardGateway {
  EasyLinkBoardGateway({EasyLinkSdkBindings? sdk})
      : sdk = sdk ?? EasyLinkSdkBindings.open();

  final EasyLinkSdkBindings sdk;
  final _stateController =
      StreamController<PhysicalBoardConnectionState>.broadcast();
  final _fenController = StreamController<String>.broadcast();
  final _batteryController = StreamController<BoardBatteryStatus>.broadcast();
  final _firmwareVersionController = StreamController<String>.broadcast();
  final _firmwareVersionsController =
      StreamController<BoardFirmwareVersions>.broadcast();
  String? _latestBoardFen;

  PhysicalBoardConnectionState _state =
      PhysicalBoardConnectionState.disconnected;

  @override
  PhysicalBoardModel get boardModel =>
      _physicalModelFromEasyLink(sdk.boardModel);

  @override
  PhysicalBoardConnectionState get currentState => _state;

  @override
  Stream<PhysicalBoardConnectionState> get stateStream =>
      _stateController.stream;

  @override
  Stream<String> get boardFenStream => _fenController.stream;

  @override
  String? get latestBoardFen => _latestBoardFen;

  @override
  Stream<BoardBatteryStatus> get boardBatteryStatusStream =>
      _batteryController.stream;

  @override
  Stream<String> get boardFirmwareVersionStream =>
      _firmwareVersionController.stream;

  @override
  Stream<BoardFirmwareVersions> get boardFirmwareVersionsStream =>
      _firmwareVersionsController.stream;

  @override
  bool get supportsStoredGameImport => true;

  @override
  Future<bool> connect() async {
    _setState(PhysicalBoardConnectionState.connecting);
    final connected = sdk.connect();
    if (!connected) {
      _setState(PhysicalBoardConnectionState.disconnected);
      return false;
    }
    sdk.setRealtimeFenCallback((fen) {
      _latestBoardFen = fen.trim().split(RegExp(r'\s+')).first;
      _fenController.add(_latestBoardFen!);
    });
    sdk.switchRealtimeMode();
    _setState(PhysicalBoardConnectionState.connected);
    return true;
  }

  @override
  Future<void> disconnect() async {
    sdk.setRealtimeFenCallback(null);
    sdk.disconnect();
    _setState(PhysicalBoardConnectionState.disconnected);
  }

  @override
  Future<bool> write(List<int> command, {bool withoutResponse = false}) async {
    return false;
  }

  @override
  Future<bool> enableRealtimeFen() async {
    return sdk.switchRealtimeMode();
  }

  @override
  Future<bool> queryBoardBatteryStatus() async {
    final level = sdk.batteryLevel();
    if (level == null) return false;
    _batteryController.add(BoardBatteryStatus(level: level, isCharging: false));
    return true;
  }

  @override
  Future<bool> queryBoardFirmwareVersion() async {
    final versions = BoardFirmwareVersions(
      bluetoothVersion: _cleanVersion(sdk.bleVersion()),
      mcuVersion: _cleanVersion(sdk.mcuVersion()),
    );
    final version = versions.primaryVersion;
    if (version == null) return false;
    _firmwareVersionController.add(version);
    _firmwareVersionsController.add(versions);
    return true;
  }

  @override
  Future<bool> setGeneralLedSquares(Set<String> squares) async {
    return sdk.setLedSquares(squares);
  }

  @override
  Future<bool> clearGeneralLeds() async {
    return sdk.setLedRows(EasyLinkLedMatrixCodec.emptyRows());
  }

  @override
  Future<bool> playBeep({int frequency = 1000, int duration = 200}) async {
    return sdk.beep(frequencyHz: frequency, durationMs: duration);
  }

  @override
  Future<int?> queryStoredGameCount() async {
    return sdk.fileCount();
  }

  @override
  Future<String?> peekStoredGameFile() async {
    return sdk.peekGameFile();
  }

  @override
  Future<String?> readAndDeleteStoredGameFile() async {
    return sdk.readAndDeleteGameFile();
  }

  @override
  Future<bool> deleteStoredGameFile() async {
    // This SDK exposes read-and-delete rather than a separate delete command.
    // The caller has already persisted the file returned by peekGameFile.
    return sdk.readAndDeleteGameFile() != null;
  }

  Future<void> dispose() async {
    sdk.dispose();
    await _stateController.close();
    await _fenController.close();
    await _batteryController.close();
    await _firmwareVersionController.close();
    await _firmwareVersionsController.close();
  }

  void _setState(PhysicalBoardConnectionState state) {
    _state = state;
    _stateController.add(state);
  }
}

class MemoryPhysicalBoardGateway extends PhysicalBoardGateway {
  MemoryPhysicalBoardGateway({
    this.boardModel = PhysicalBoardModel.move,
  });

  @override
  final PhysicalBoardModel boardModel;

  final _stateController =
      StreamController<PhysicalBoardConnectionState>.broadcast();
  final _fenController = StreamController<String>.broadcast();
  final _batteryController = StreamController<BoardBatteryStatus>.broadcast();
  final _movePieceStatusController =
      StreamController<List<ChessnutMovePieceStatus>>.broadcast();
  final _firmwareVersionController = StreamController<String>.broadcast();
  final _firmwareVersionsController =
      StreamController<BoardFirmwareVersions>.broadcast();
  String? _latestBoardFen;

  final List<List<int>> writes = [];
  final List<String> commandLabels = [];
  final List<String> storedGameFiles = [];
  final List<List<String?>> evo2PatternKeyWrites = [];
  final List<int> evo2BrightnessWrites = [];
  List<String> movePieceData = ['', '', '', ''];
  List<ChessnutMovePieceStatus> movePieceStatuses = const [];
  int? moveChannel;
  int? moveDiscoveredChannel;
  bool movePairingWillSucceed = true;
  bool storedGameImportSupported = false;
  bool moveFirmwareUpdateSupported = true;
  bool moveFirmwareWifiWillSucceed = true;
  bool moveFirmwareBluetoothWillSucceed = true;
  Uint8List? lastMoveFirmwareFile;
  (String, String)? lastMoveFirmwareWifiCredentials;

  PhysicalBoardConnectionState state =
      PhysicalBoardConnectionState.disconnected;

  @override
  PhysicalBoardConnectionState get currentState => state;

  @override
  Stream<PhysicalBoardConnectionState> get stateStream =>
      _stateController.stream;

  @override
  Stream<String> get boardFenStream => _fenController.stream;

  @override
  String? get latestBoardFen => _latestBoardFen;

  @override
  Stream<BoardBatteryStatus> get boardBatteryStatusStream =>
      _batteryController.stream;

  @override
  Stream<String> get boardFirmwareVersionStream =>
      _firmwareVersionController.stream;

  @override
  Stream<BoardFirmwareVersions> get boardFirmwareVersionsStream =>
      _firmwareVersionsController.stream;

  @override
  Stream<List<ChessnutMovePieceStatus>> get movePieceStatusStream =>
      _movePieceStatusController.stream;

  @override
  bool get supportsStoredGameImport => storedGameImportSupported;

  @override
  Future<bool> connect() async {
    _setState(PhysicalBoardConnectionState.connected);
    return true;
  }

  @override
  Future<void> disconnect() async {
    _setState(PhysicalBoardConnectionState.disconnected);
  }

  @override
  Future<bool> write(
    List<int> command, {
    bool withoutResponse = false,
  }) async {
    if (state != PhysicalBoardConnectionState.connected) {
      return false;
    }
    writes.add(List<int>.unmodifiable(command));
    return true;
  }

  @override
  Future<bool> setEvo2LedPatternKeys(
    List<String?> squarePatternKeys,
    Evo2LedPatternSet patterns,
  ) async {
    if (state != PhysicalBoardConnectionState.connected ||
        boardModel != PhysicalBoardModel.evo2 ||
        squarePatternKeys.length != 64) {
      return false;
    }
    evo2PatternKeyWrites.add(List<String?>.unmodifiable(squarePatternKeys));
    return true;
  }

  @override
  Future<bool> setEvo2LedBrightness(int brightness) async {
    if (state != PhysicalBoardConnectionState.connected ||
        boardModel != PhysicalBoardModel.evo2) {
      return false;
    }
    evo2BrightnessWrites.add(brightness.clamp(0, 100).toInt());
    return true;
  }

  @override
  Future<int?> queryMoveChannel() async {
    if (boardModel != PhysicalBoardModel.move) return null;
    await write(ChessnutMoveCommands.getChannel);
    return moveChannel;
  }

  @override
  Future<bool> setMoveChannel(int channel) async {
    if (boardModel != PhysicalBoardModel.move) return false;
    final sent = await super.setMoveChannel(channel);
    if (sent) moveChannel = channel.clamp(0, 3);
    return sent;
  }

  @override
  Future<int?> discoverMovePieceChannel() async {
    if (boardModel != PhysicalBoardModel.move) return null;
    await write(ChessnutMoveCommands.discoverPieceChannel);
    return moveDiscoveredChannel;
  }

  @override
  Future<List<String>?> queryMovePieceData() async {
    if (boardModel != PhysicalBoardModel.move) return null;
    await write(ChessnutMoveCommands.getPieceData);
    return List<String>.unmodifiable(_normalizeMovePieceData(movePieceData));
  }

  @override
  Future<bool> setMovePieceData(List<String> names) async {
    if (boardModel != PhysicalBoardModel.move) return false;
    final sent = await super.setMovePieceData(names);
    if (sent) movePieceData = _normalizeMovePieceData(names);
    return sent;
  }

  @override
  Future<bool> queryMovePieceStatus() async {
    if (boardModel != PhysicalBoardModel.move) return false;
    final sent = await write(ChessnutMoveCommands.pieceStatus);
    if (sent && movePieceStatuses.isNotEmpty) {
      addMovePieceStatus(movePieceStatuses);
    }
    return sent;
  }

  @override
  Future<bool> queryBoardBatteryStatus() async {
    final sent = await super.queryBoardBatteryStatus();
    if (sent && boardModel == PhysicalBoardModel.move) {
      _batteryController.add(
        const BoardBatteryStatus(level: 88, isCharging: false),
      );
    }
    return sent;
  }

  @override
  Future<bool> checkMoveFirmwareUpdateSupport() async {
    return state == PhysicalBoardConnectionState.connected &&
        boardModel == PhysicalBoardModel.move &&
        moveFirmwareUpdateSupported;
  }

  @override
  Future<bool> configureMoveFirmwareWifi({
    required String ssid,
    required String password,
  }) async {
    if (state != PhysicalBoardConnectionState.connected ||
        boardModel != PhysicalBoardModel.move ||
        ssid.isEmpty) {
      return false;
    }
    lastMoveFirmwareWifiCredentials = (ssid, password);
    return moveFirmwareWifiWillSucceed;
  }

  @override
  Future<bool> startMoveWifiFirmwareUpdate() async {
    return state == PhysicalBoardConnectionState.connected &&
        boardModel == PhysicalBoardModel.move &&
        moveFirmwareWifiWillSucceed;
  }

  @override
  Future<bool> sendMoveFirmwareUpdateFile(
    Uint8List data, {
    MoveFirmwareProgress? onProgress,
  }) async {
    if (state != PhysicalBoardConnectionState.connected ||
        boardModel != PhysicalBoardModel.move ||
        data.isEmpty) {
      return false;
    }
    lastMoveFirmwareFile = Uint8List.fromList(data);
    onProgress?.call(data.length * 2, data.length * 2);
    return moveFirmwareBluetoothWillSucceed;
  }

  @override
  Future<bool> finishMovePiecePairing() async {
    if (boardModel != PhysicalBoardModel.move) return false;
    final sent = await write(ChessnutMoveCommands.finishPiecePairing());
    return sent && movePairingWillSucceed;
  }

  @override
  Future<bool> setBoardBeepEnabled(bool enabled) async {
    commandLabels.add(enabled ? 'set-beep-on' : 'set-beep-off');
    return super.setBoardBeepEnabled(enabled);
  }

  @override
  Future<bool> playBeep({int frequency = 1000, int duration = 200}) async {
    commandLabels.add('beep');
    return super.playBeep(frequency: frequency, duration: duration);
  }

  @override
  Future<int?> queryStoredGameCount() async {
    return supportsStoredGameImport ? storedGameFiles.length : null;
  }

  @override
  Future<String?> peekStoredGameFile() async {
    if (!supportsStoredGameImport || storedGameFiles.isEmpty) return null;
    return storedGameFiles.first;
  }

  @override
  Future<String?> readAndDeleteStoredGameFile() async {
    if (!supportsStoredGameImport || storedGameFiles.isEmpty) return null;
    return storedGameFiles.removeAt(0);
  }

  @override
  Future<bool> deleteStoredGameFile() async {
    if (!supportsStoredGameImport || storedGameFiles.isEmpty) return false;
    storedGameFiles.removeAt(0);
    return true;
  }

  void addRawFenPayload(List<int> data) {
    final fen = ChessnutBoardFenCodec.tryDecode(data);
    if (fen != null) {
      _latestBoardFen = fen;
      _fenController.add(fen);
    }
  }

  void addBoardFen(String boardOnlyFen) {
    _latestBoardFen = boardOnlyFen.trim().split(RegExp(r'\s+')).first;
    _fenController.add(_latestBoardFen!);
  }

  void addBoardBatteryStatus(BoardBatteryStatus status) {
    _batteryController.add(status);
  }

  void addBoardFirmwareVersion(String version) {
    final cleaned = _cleanVersion(version);
    if (cleaned != null) {
      _firmwareVersionController.add(cleaned);
      _firmwareVersionsController.add(
        BoardFirmwareVersions(bluetoothVersion: cleaned),
      );
    }
  }

  void addBoardFirmwareVersions(BoardFirmwareVersions versions) {
    final cleaned = BoardFirmwareVersions(
      moveVersion: _cleanVersion(versions.moveVersion),
      bluetoothVersion: _cleanVersion(versions.bluetoothVersion),
      mcuVersion: _cleanVersion(versions.mcuVersion),
    );
    final primary = cleaned.primaryVersion;
    if (primary != null) {
      _firmwareVersionController.add(primary);
      _firmwareVersionsController.add(cleaned);
    }
  }

  void addMovePieceStatus(List<ChessnutMovePieceStatus> pieces) {
    movePieceStatuses = List<ChessnutMovePieceStatus>.unmodifiable(pieces);
    _movePieceStatusController.add(List<ChessnutMovePieceStatus>.unmodifiable(
      pieces,
    ));
  }

  Future<void> dispose() async {
    await _stateController.close();
    await _fenController.close();
    await _batteryController.close();
    await _movePieceStatusController.close();
    await _firmwareVersionController.close();
    await _firmwareVersionsController.close();
  }

  void _setState(PhysicalBoardConnectionState value) {
    state = value;
    _stateController.add(value);
  }
}

String? _firstNonEmptyString(Iterable<String?> values) {
  for (final value in values) {
    final cleaned = _cleanVersion(value);
    if (cleaned != null) {
      return cleaned;
    }
  }
  return null;
}

String? _cleanVersion(String? version) {
  final cleaned = version?.trim();
  return cleaned == null || cleaned.isEmpty ? null : cleaned;
}

bool _hasText(String? value) => _cleanVersion(value) != null;

PhysicalBoardModel _physicalModelFromEasyLink(EasyLinkBoardModel? model) {
  return switch (model) {
    EasyLinkBoardModel.air => PhysicalBoardModel.air,
    EasyLinkBoardModel.pro => PhysicalBoardModel.pro,
    EasyLinkBoardModel.airPlus => PhysicalBoardModel.airPlus,
    EasyLinkBoardModel.evo => PhysicalBoardModel.evo,
    EasyLinkBoardModel.go => PhysicalBoardModel.go,
    null => PhysicalBoardModel.general,
  };
}

List<int> _moveSetPieceDataCommand(List<String> names) {
  final normalized = _normalizeMovePieceData(names);
  final encoded = utf8.encode(jsonEncode(normalized));
  return [
    0x41,
    encoded.length + 1,
    0x1a,
    ...encoded,
  ];
}

List<String> _normalizeMovePieceData(List<String> names) {
  return [
    for (var i = 0; i < 4; i++) i < names.length ? names[i].trim() : '',
  ];
}

T? _parseMovePayload<T>(List<int> data, T? Function(List<int> payload) parse) {
  if (data.length < 3 || data[0] != 0x41) return null;
  const start = 3;
  final payloadLength = data[1];
  final end = (start + payloadLength).clamp(start, data.length);
  return parse(data.sublist(start, end));
}

int? _parseMoveSingleBytePayload(List<int> data) {
  return _parseMovePayload<int>(
    data,
    (payload) => payload.isEmpty ? null : payload.first,
  );
}

int? _parseMoveDiscoveredChannel(List<int> data) {
  return _parseMovePayload<int>(data, (payload) {
    if (payload.isEmpty) return null;
    if (payload.length >= 2 && payload[1] != 0) return payload[1] + 10;
    return payload.first;
  });
}

List<String>? _parseMovePieceData(List<int> data) {
  return _parseMovePayload<List<String>>(data, (payload) {
    if (payload.isEmpty) return ['', '', '', ''];
    try {
      final decoded = jsonDecode(utf8.decode(payload));
      if (decoded is! List) return null;
      return _normalizeMovePieceData(decoded.map((item) => '$item').toList());
    } catch (_) {
      return null;
    }
  });
}

bool _parseMovePairingResult(List<int> data) {
  return _parseMovePayload<bool>(
        data,
        (payload) => payload.isNotEmpty && payload.first == 0,
      ) ??
      false;
}

void _clearPending<T>(
  Completer<T>? current,
  Completer<T> expected,
  void Function() clear,
) {
  if (identical(current, expected)) clear();
}

Future<T> _timeoutPending<T>(
  Completer<T> completer,
  Duration timeout,
  void Function() clear, {
  T? fallback,
}) {
  return completer.future.timeout(
    timeout,
    onTimeout: () {
      clear();
      final value = fallback;
      if (value != null) return value;
      return null as T;
    },
  );
}

class _FenPayloadAssembler {
  final _buffer = <int>[];

  List<List<int>> add(List<int> data) {
    if (data.length >= 32) {
      _buffer.clear();
      return [List<int>.unmodifiable(data)];
    }
    if (data.isEmpty) return const [];

    _buffer.addAll(data);
    if (_buffer.length < 32) {
      return const [];
    }

    final payloadLength = _buffer.length >= 34
        ? 34
        : _buffer.length == 33
            ? 33
            : 32;
    final payload = List<int>.unmodifiable(_buffer.take(payloadLength));
    _buffer.removeRange(0, payloadLength);
    if (_buffer.length > 34) {
      _buffer.clear();
    }
    return [payload];
  }
}
