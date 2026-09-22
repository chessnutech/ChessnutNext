import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import 'easy_link_sdk_contract.dart';
import 'physical_board_gateway.dart';
import 'physical_board_protocol.dart';

class UniversalBleChessnutProfile {
  const UniversalBleChessnutProfile._();

  static const manufacturerCompanyId = 0x4450;
  static final manufacturerPayloadPrefix = Uint8List.fromList([0x43, 0x53]);

  static const boardService = ChessnutBleUuids.boardService;
  static const boardCharacteristic = ChessnutBleUuids.boardCharacteristic;
  static const responseService = ChessnutBleUuids.readService;
  static const responseCharacteristic = ChessnutBleUuids.readCharacteristic;
  static const writeService = ChessnutBleUuids.writeService;
  static const writeCharacteristic = ChessnutBleUuids.writeCharacteristic;
  static const fileService = ChessnutBleUuids.readFileService;
  static const fileCharacteristic = ChessnutBleUuids.readFileCharacteristic;

  static const requiredServices = [
    boardService,
    responseService,
    fileService,
  ];

  static ScanFilter get scanFilter => ScanFilter(
        withNamePrefix: const [
          'Chessnut',
          'chessnut',
          'CHESSNUT',
          'Chess Air',
          'ChessAir',
          'chess air',
          'chessair',
          'CHESS AIR',
          'CHESSAIR',
        ],
        withManufacturerData: [
          ManufacturerDataFilter(
            companyIdentifier: manufacturerCompanyId,
            payloadPrefix: manufacturerPayloadPrefix,
          ),
        ],
      );
}

class UniversalBleChessnutMatcher {
  const UniversalBleChessnutMatcher._();

  static bool isChessnutDeviceName(String? name) {
    final normalized = name?.toLowerCase() ?? '';
    final compact = normalized.replaceAll(RegExp(r'[^a-z0-9+]'), '');
    return normalized.contains('chessnut') || compact.contains('chessair');
  }

  static bool hasChessnutManufacturerPrefix(List<int> data) {
    return data.length >= 4 &&
        data[0] == 0x50 &&
        data[1] == 0x44 &&
        data[2] == 0x43 &&
        data[3] == 0x53;
  }

  static bool isChessnutManufacturerData(ManufacturerData data) {
    return hasChessnutManufacturerPrefix(data.toUint8List()) ||
        hasChessnutManufacturerPrefix(data.payload) ||
        (data.companyId == UniversalBleChessnutProfile.manufacturerCompanyId &&
            data.payload.length >=
                UniversalBleChessnutProfile.manufacturerPayloadPrefix.length &&
            _matchesPrefix(
              data.payload,
              UniversalBleChessnutProfile.manufacturerPayloadPrefix,
            ));
  }

  static bool isChessnutDevice(BleDevice device) {
    if (isChessnutDeviceName(device.name)) {
      return true;
    }
    return device.manufacturerDataList.any(
      isChessnutManufacturerData,
    );
  }

  static PhysicalBoardModel modelFromDevice(
    BleDevice device, {
    bool inferProFromManufacturerData = false,
    bool requireBroadcastName = false,
  }) {
    final nameModel = modelFromName(device.name);
    if (requireBroadcastName) {
      return nameModel;
    }
    if (inferProFromManufacturerData) {
      final manufacturerModel = _proModelFromManufacturerDataList(
        device.manufacturerDataList,
      );
      if (manufacturerModel == PhysicalBoardModel.pro) {
        return manufacturerModel;
      }
    }
    if (nameModel != PhysicalBoardModel.unknown) {
      return nameModel;
    }
    if (isChessnutDevice(device)) {
      return PhysicalBoardModel.general;
    }
    return PhysicalBoardModel.unknown;
  }

  static PhysicalBoardModel modelFromManufacturerDataList(
    List<ManufacturerData> manufacturerDataList,
  ) {
    if (manufacturerDataList.any(isChessnutManufacturerData)) {
      return PhysicalBoardModel.general;
    }
    return PhysicalBoardModel.unknown;
  }

  static PhysicalBoardModel modelFromManufacturerData(ManufacturerData data) {
    if (!isChessnutManufacturerData(data)) {
      return PhysicalBoardModel.unknown;
    }
    return PhysicalBoardModel.general;
  }

  static PhysicalBoardModel _proModelFromManufacturerDataList(
    List<ManufacturerData> manufacturerDataList,
  ) {
    for (final data in manufacturerDataList) {
      final model = _proModelFromManufacturerData(data);
      if (model == PhysicalBoardModel.pro) return model;
    }
    return PhysicalBoardModel.unknown;
  }

  static PhysicalBoardModel _proModelFromManufacturerData(
    ManufacturerData data,
  ) {
    if (!isChessnutManufacturerData(data)) {
      return PhysicalBoardModel.unknown;
    }

    final advertisedText = String.fromCharCodes([
      ...data.payload.where(_isPrintableAscii),
      ...data.toUint8List().where(_isPrintableAscii),
    ]);
    if (easyLinkBoardModelFromText(advertisedText) == EasyLinkBoardModel.pro) {
      return PhysicalBoardModel.pro;
    }

    final payload = data.payload;
    final prefix = UniversalBleChessnutProfile.manufacturerPayloadPrefix;
    if (data.companyId == UniversalBleChessnutProfile.manufacturerCompanyId &&
        _matchesPrefix(payload, prefix) &&
        payload.length > prefix.length) {
      final productFamily = payload[prefix.length];
      if (EasyLinkHidProducts.modelForProductId(productFamily << 8) ==
          EasyLinkBoardModel.pro) {
        return PhysicalBoardModel.pro;
      }
    }
    return PhysicalBoardModel.general;
  }

  static PhysicalBoardModel modelFromName(String? name) {
    final easyLinkModel = easyLinkBoardModelFromText(name);
    if (easyLinkModel != null) {
      return _physicalModelFromEasyLinkModel(easyLinkModel);
    }
    final normalized = name?.toLowerCase() ?? '';
    if (normalized.contains('move')) {
      return PhysicalBoardModel.move;
    }
    if (normalized.contains('pi')) {
      return PhysicalBoardModel.pi;
    }
    if (normalized.contains('chessnut')) {
      return PhysicalBoardModel.general;
    }
    return PhysicalBoardModel.unknown;
  }
}

PhysicalBoardModel _physicalModelFromEasyLinkModel(EasyLinkBoardModel model) {
  return switch (model) {
    EasyLinkBoardModel.air => PhysicalBoardModel.air,
    EasyLinkBoardModel.pro => PhysicalBoardModel.pro,
    EasyLinkBoardModel.airPlus => PhysicalBoardModel.airPlus,
    EasyLinkBoardModel.evo => PhysicalBoardModel.evo,
    EasyLinkBoardModel.go => PhysicalBoardModel.go,
  };
}

class UniversalBleBoardTransport
    implements PhysicalBoardTransport, MoveFirmwarePacketTransport {
  UniversalBleBoardTransport({
    this.scanTimeout = const Duration(seconds: 30),
    this.connectTimeout = const Duration(seconds: 12),
    this.connectionCheckInterval = const Duration(seconds: 2),
    this.protocolHandshakeTimeout = const Duration(seconds: 4),
    bool? inferProFromManufacturerData,
    bool? requireBroadcastName,
    bool? requireProtocolHandshake,
  })  : inferProFromManufacturerData = inferProFromManufacturerData ??
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS),
        requireBroadcastName = requireBroadcastName ??
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS),
        requireProtocolHandshake = requireProtocolHandshake ??
            (!kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.iOS ||
                    defaultTargetPlatform == TargetPlatform.macOS));

  final Duration scanTimeout;
  final Duration connectTimeout;
  final Duration connectionCheckInterval;
  final Duration protocolHandshakeTimeout;
  final bool inferProFromManufacturerData;
  final bool requireBroadcastName;
  final bool requireProtocolHandshake;

  final _stateController =
      StreamController<PhysicalBoardConnectionState>.broadcast();
  final _fenController = StreamController<List<int>>.broadcast();
  final _responseController = StreamController<List<int>>.broadcast();
  final _fileController = StreamController<List<int>>.broadcast();

  StreamSubscription<BleDevice>? _scanSub;
  StreamSubscription<AvailabilityState>? _availabilitySub;
  StreamSubscription<bool>? _connectionSub;
  StreamSubscription<Uint8List>? _boardFenSub;
  StreamSubscription<Uint8List>? _responseSub;
  StreamSubscription<Uint8List>? _fileSub;
  Timer? _connectionCheckTimer;
  bool _connectionCheckInFlight = false;
  Completer<void>? _protocolActivityCompleter;
  String? _deviceId;
  PhysicalBoardModel _boardModel = PhysicalBoardModel.unknown;
  PhysicalBoardConnectionState _currentState =
      PhysicalBoardConnectionState.disconnected;
  Future<void> _writeQueue = Future.value();
  DateTime _lastWriteAt = DateTime.fromMillisecondsSinceEpoch(0);
  int? _negotiatedMtu;
  static const _minimumWriteGap = Duration(milliseconds: 100);

  @override
  PhysicalBoardModel get boardModel => _boardModel;

  @override
  PhysicalBoardConnectionState get currentState => _currentState;

  @override
  Stream<PhysicalBoardConnectionState> get stateStream =>
      _stateController.stream;

  @override
  Stream<List<int>> get fenPayloadStream => _fenController.stream;

  @override
  Stream<List<int>> get responseStream => _responseController.stream;

  @override
  Stream<List<int>> get filePayloadStream => _fileController.stream;

  @override
  Future<bool> connect() async {
    await _availabilitySub?.cancel();
    if (_usesAppleConnectionVerification ||
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)) {
      _availabilitySub = UniversalBle.availabilityStream.listen((availability) {
        final deviceId = _deviceId;
        if (availability != AvailabilityState.poweredOn && deviceId != null) {
          unawaited(_handleRemoteDisconnect(deviceId));
        }
      });
    }
    final availability = await UniversalBle.getBluetoothAvailabilityState();
    if (availability != AvailabilityState.poweredOn) {
      _emitState(PhysicalBoardConnectionState.disconnected);
      return false;
    }

    _emitState(PhysicalBoardConnectionState.scanning);
    await UniversalBle.requestPermissions(withAndroidFineLocation: false);

    final completer = Completer<BleDevice?>();
    _scanSub = UniversalBle.scanStream.listen((device) {
      final matches = requireBroadcastName
          ? UniversalBleChessnutMatcher.isChessnutDeviceName(device.name)
          : UniversalBleChessnutMatcher.isChessnutDevice(device);
      if (!matches) {
        return;
      }
      if (!completer.isCompleted) {
        completer.complete(device);
      }
    });

    await UniversalBle.startScan(
      scanFilter: UniversalBleChessnutProfile.scanFilter,
      platformConfig: PlatformConfig(
        web: WebOptions(
          optionalServices: UniversalBleChessnutProfile.requiredServices,
        ),
      ),
    );

    final device = await completer.future.timeout(
      scanTimeout,
      onTimeout: () => null,
    );
    await UniversalBle.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;

    if (device == null) {
      _emitState(PhysicalBoardConnectionState.disconnected);
      return false;
    }

    _emitState(PhysicalBoardConnectionState.connecting);
    _deviceId = device.deviceId;
    _protocolActivityCompleter = Completer<void>();
    _boardModel = UniversalBleChessnutMatcher.modelFromDevice(
      device,
      inferProFromManufacturerData: inferProFromManufacturerData,
      requireBroadcastName: requireBroadcastName,
    );
    try {
      await UniversalBle.connect(device.deviceId, timeout: connectTimeout);
      _subscribeConnectionChanges(device.deviceId);
      await UniversalBle.discoverServices(device.deviceId);
      await _requestPreferredMtu(device.deviceId);
      await _subscribeNotifications(device.deviceId);
      if (_deviceId != device.deviceId ||
          !await _nativeConnectionIsReady(device.deviceId)) {
        await disconnect();
        return false;
      }
      final realtimeEnabled = await _startRealtimeFenIfSupported();
      if (realtimeEnabled && requireProtocolHandshake) {
        await _requestProtocolHandshake();
      }
      if (!realtimeEnabled ||
          (requireProtocolHandshake &&
              !await _waitForProtocolActivity(device.deviceId))) {
        await disconnect();
        return false;
      }
      _emitState(PhysicalBoardConnectionState.connected);
      _startConnectionChecks(device.deviceId);
      return _deviceId == device.deviceId &&
          _currentState == PhysicalBoardConnectionState.connected;
    } catch (_) {
      await disconnect();
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    final deviceId = _deviceId;
    _deviceId = null;
    _boardModel = PhysicalBoardModel.unknown;
    _protocolActivityCompleter = null;
    _stopConnectionChecks();
    await _availabilitySub?.cancel();
    await _connectionSub?.cancel();
    await _boardFenSub?.cancel();
    await _responseSub?.cancel();
    await _fileSub?.cancel();
    _availabilitySub = null;
    _connectionSub = null;
    _boardFenSub = null;
    _responseSub = null;
    _fileSub = null;
    _negotiatedMtu = null;
    if (deviceId != null) {
      try {
        await UniversalBle.disconnect(deviceId);
      } catch (_) {}
    }
    _emitState(PhysicalBoardConnectionState.disconnected);
  }

  @override
  Future<bool> write(
    List<int> command, {
    bool withoutResponse = false,
  }) async {
    final operation = _writeQueue.then(
      (_) => _writeWithRetry(command, withoutResponse: withoutResponse),
    );
    _writeQueue = operation.then((_) {}, onError: (_) {});
    return operation;
  }

  @override
  Future<bool> writeMoveFirmwarePacket(
    List<int> command, {
    required bool withoutResponse,
    required Duration minimumGap,
    required bool trackWriteTime,
  }) async {
    final operation = _writeQueue.then(
      (_) => _writeMoveFirmwarePacket(
        command,
        withoutResponse: withoutResponse,
        minimumGap: minimumGap,
        trackWriteTime: trackWriteTime,
      ),
    );
    _writeQueue = operation.then((_) {}, onError: (_) {});
    return operation;
  }

  Future<bool> _writeMoveFirmwarePacket(
    List<int> command, {
    required bool withoutResponse,
    required Duration minimumGap,
    required bool trackWriteTime,
  }) async {
    final deviceId = _deviceId;
    if (deviceId == null) return false;

    await _waitForWriteGap(minimumGap);
    try {
      final mtu = _negotiatedMtu;
      if (mtu != null && mtu > 0 && command.length > mtu) {
        for (var offset = 0; offset < command.length; offset += mtu) {
          final end =
              offset + mtu < command.length ? offset + mtu : command.length;
          await _writeRaw(
            deviceId,
            command.sublist(offset, end),
            withoutResponse: withoutResponse,
          );
        }
      } else {
        await _writeRaw(
          deviceId,
          command,
          withoutResponse: withoutResponse,
        );
      }
      if (trackWriteTime) _lastWriteAt = DateTime.now();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _writeWithRetry(
    List<int> command, {
    required bool withoutResponse,
  }) async {
    final deviceId = _deviceId;
    if (deviceId == null) {
      return false;
    }

    await _waitForWriteGap(_minimumWriteGap);
    final preferredWithoutResponse =
        withoutResponse || _boardModel.usesGeneralProtocol;
    final attempts =
        preferredWithoutResponse ? const [true, false] : const [false, true];
    for (final useWithoutResponse in attempts) {
      try {
        await _writeRaw(
          deviceId,
          command,
          withoutResponse: useWithoutResponse,
        );
        _lastWriteAt = DateTime.now();
        return true;
      } catch (_) {}
    }
    return false;
  }

  Future<void> _waitForWriteGap(Duration minimumGap) async {
    final remaining = minimumGap - DateTime.now().difference(_lastWriteAt);
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _scanSub?.cancel();
    await _availabilitySub?.cancel();
    _availabilitySub = null;
    await _stateController.close();
    await _fenController.close();
    await _responseController.close();
    await _fileController.close();
  }

  void _subscribeConnectionChanges(String deviceId) {
    unawaited(_connectionSub?.cancel());
    _connectionSub = UniversalBle.connectionStream(deviceId).listen(
      (connected) {
        if (!connected && _deviceId == deviceId) {
          unawaited(_handleRemoteDisconnect(deviceId));
        }
      },
      onError: (_) {},
    );
  }

  Future<void> _handleRemoteDisconnect(String deviceId) async {
    if (_deviceId != deviceId ||
        _currentState == PhysicalBoardConnectionState.disconnected) {
      return;
    }
    _deviceId = null;
    _boardModel = PhysicalBoardModel.unknown;
    _protocolActivityCompleter = null;
    _stopConnectionChecks();
    await _availabilitySub?.cancel();
    await _connectionSub?.cancel();
    await _boardFenSub?.cancel();
    await _responseSub?.cancel();
    await _fileSub?.cancel();
    _availabilitySub = null;
    _connectionSub = null;
    _boardFenSub = null;
    _responseSub = null;
    _fileSub = null;
    _emitState(PhysicalBoardConnectionState.disconnected);
  }

  Future<bool> _nativeConnectionIsReady(String deviceId) async {
    try {
      return await UniversalBle.getConnectionState(
            deviceId,
            timeout: connectTimeout,
          ) ==
          BleConnectionState.connected;
    } catch (_) {
      return false;
    }
  }

  void _startConnectionChecks(String deviceId) {
    _stopConnectionChecks();
    if (!_usesAppleConnectionVerification ||
        connectionCheckInterval <= Duration.zero) {
      return;
    }
    _connectionCheckTimer = Timer.periodic(connectionCheckInterval, (_) {
      unawaited(_checkNativeConnection(deviceId));
    });
  }

  void _stopConnectionChecks() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
    _connectionCheckInFlight = false;
  }

  Future<void> _checkNativeConnection(String deviceId) async {
    if (_connectionCheckInFlight ||
        _deviceId != deviceId ||
        _currentState != PhysicalBoardConnectionState.connected) {
      return;
    }
    _connectionCheckInFlight = true;
    try {
      final state = await UniversalBle.getConnectionState(
        deviceId,
        timeout: connectionCheckInterval,
      );
      if (_deviceId == deviceId &&
          state != BleConnectionState.connected &&
          state != BleConnectionState.connecting) {
        await _handleRemoteDisconnect(deviceId);
      }
    } catch (_) {
      // A transient native query failure is not proof that the board dropped.
      // The next poll or the connection callback will verify it again.
    } finally {
      _connectionCheckInFlight = false;
    }
  }

  Future<void> _subscribeNotifications(String deviceId) async {
    _boardFenSub = UniversalBle.characteristicValueStream(
      deviceId,
      UniversalBleChessnutProfile.boardCharacteristic,
    ).listen((value) {
      final data = value.toList();
      _markProtocolActivity(data);
      _fenController.add(data);
    });
    _responseSub = UniversalBle.characteristicValueStream(
      deviceId,
      UniversalBleChessnutProfile.responseCharacteristic,
    ).listen((value) {
      final data = value.toList();
      _markProtocolActivity(data);
      _responseController.add(data);
    });
    _fileSub = UniversalBle.characteristicValueStream(
      deviceId,
      UniversalBleChessnutProfile.fileCharacteristic,
    ).listen((value) {
      final data = value.toList();
      _markProtocolActivity(data);
      _fileController.add(data);
    });

    await UniversalBle.subscribeNotifications(
      deviceId,
      UniversalBleChessnutProfile.boardService,
      UniversalBleChessnutProfile.boardCharacteristic,
    );
    await UniversalBle.subscribeNotifications(
      deviceId,
      UniversalBleChessnutProfile.responseService,
      UniversalBleChessnutProfile.responseCharacteristic,
    );
    await UniversalBle.subscribeNotifications(
      deviceId,
      UniversalBleChessnutProfile.fileService,
      UniversalBleChessnutProfile.fileCharacteristic,
    );
  }

  void _markProtocolActivity(List<int> data) {
    if (data.isEmpty) return;
    final completer = _protocolActivityCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<bool> _waitForProtocolActivity(String deviceId) async {
    final completer = _protocolActivityCompleter;
    if (completer == null) return false;
    try {
      await completer.future.timeout(protocolHandshakeTimeout);
      return _deviceId == deviceId;
    } on TimeoutException {
      return false;
    }
  }

  Future<void> _requestProtocolHandshake() async {
    final isMove = _boardModel == PhysicalBoardModel.move;
    await write(
      isMove
          ? ChessnutMoveCommands.batteryStatus
          : ChessnutGeneralCommands.batteryStatus,
      withoutResponse: !isMove,
    );
  }

  bool get _usesAppleConnectionVerification =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> _requestPreferredMtu(String deviceId) async {
    try {
      _negotiatedMtu = await UniversalBle.requestMtu(deviceId, 512);
    } catch (_) {
      _negotiatedMtu = null;
    }
  }

  Future<bool> _startRealtimeFenIfSupported() async {
    final isMove = _boardModel == PhysicalBoardModel.move;
    final command = isMove
        ? ChessnutMoveCommands.enableRealtimeFen
        : ChessnutGeneralCommands.enableRealtimeFen;
    return write(command, withoutResponse: !isMove);
  }

  Future<void> _writeRaw(
    String deviceId,
    List<int> command, {
    required bool withoutResponse,
  }) {
    return UniversalBle.write(
      deviceId,
      UniversalBleChessnutProfile.writeService,
      UniversalBleChessnutProfile.writeCharacteristic,
      Uint8List.fromList(command),
      withoutResponse: withoutResponse,
    );
  }

  void _emitState(PhysicalBoardConnectionState state) {
    _currentState = state;
    _stateController.add(state);
  }
}

bool isChessnutLedCommandForTest(List<int> command) => _isLedCommand(command);

bool _isLedCommand(List<int> command) {
  if (command.length == 10 && command[0] == 0x0a && command[1] == 0x08) {
    return true;
  }
  if (command.length == 34 && command[0] == 0x43 && command[1] == 0x20) {
    return true;
  }
  return false;
}

bool _matchesPrefix(Uint8List data, Uint8List prefix) {
  if (prefix.length > data.length) {
    return false;
  }
  for (var i = 0; i < prefix.length; i++) {
    if (data[i] != prefix[i]) {
      return false;
    }
  }
  return true;
}

bool _isPrintableAscii(int byte) => byte >= 0x20 && byte <= 0x7e;
