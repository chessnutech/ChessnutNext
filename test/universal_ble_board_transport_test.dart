import 'package:chessnut_flutter_export/services/physical_board_protocol.dart';
import 'package:chessnut_flutter_export/services/physical_board_gateway.dart';
import 'package:chessnut_flutter_export/services/universal_ble_board_transport.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

import '../third_party/universal_ble/test/universal_ble_test_mock.dart';

void main() {
  test('recognizes Chessnut BLE advertisements by name or manufacturer prefix',
      () {
    expect(UniversalBleChessnutMatcher.isChessnutDeviceName('Chessnut Move'),
        isTrue);
    expect(
        UniversalBleChessnutMatcher.isChessnutDeviceName('Chess Air'), isTrue);
    expect(UniversalBleChessnutMatcher.isChessnutDeviceName('Demo board'),
        isFalse);

    expect(
      UniversalBleChessnutMatcher.hasChessnutManufacturerPrefix([
        0x50,
        0x44,
        0x43,
        0x53,
        0x10,
      ]),
      isTrue,
    );
    expect(
      UniversalBleChessnutMatcher.hasChessnutManufacturerPrefix([0x01, 0x02]),
      isFalse,
    );
    expect(
      UniversalBleChessnutMatcher.isChessnutManufacturerData(
        ManufacturerData(
          UniversalBleChessnutProfile.manufacturerCompanyId,
          UniversalBleChessnutProfile.manufacturerPayloadPrefix,
        ),
      ),
      isTrue,
    );

    expect(
      UniversalBleChessnutMatcher.modelFromName('Chessnut Move'),
      PhysicalBoardModel.move,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromName('Chessnut Air'),
      PhysicalBoardModel.air,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromName('Chess Air'),
      PhysicalBoardModel.air,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromName('ChessAir'),
      PhysicalBoardModel.air,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromName('Chessnut Air+'),
      PhysicalBoardModel.airPlus,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromName('Chessnut Air +'),
      PhysicalBoardModel.airPlus,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromName('Chessnut Air Plus'),
      PhysicalBoardModel.airPlus,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromName('CHESSNUT-AIR+'),
      PhysicalBoardModel.airPlus,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromName('Chessnut Air II'),
      PhysicalBoardModel.air,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromName('Chessnut Air2'),
      PhysicalBoardModel.air,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromName('Chessnut'),
      PhysicalBoardModel.general,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromName('Chessnut Pro'),
      PhysicalBoardModel.pro,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromName('Chessnut Go'),
      PhysicalBoardModel.go,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromDevice(
        BleDevice(
          deviceId: 'air-without-name',
          name: null,
          manufacturerDataList: [
            ManufacturerData(
              UniversalBleChessnutProfile.manufacturerCompanyId,
              UniversalBleChessnutProfile.manufacturerPayloadPrefix,
            ),
          ],
        ),
      ),
      PhysicalBoardModel.general,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromManufacturerData(
        ManufacturerData(
          UniversalBleChessnutProfile.manufacturerCompanyId,
          Uint8List.fromList([0x43, 0x53, 0x82, 0x01]),
        ),
      ),
      PhysicalBoardModel.general,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromManufacturerData(
        ManufacturerData(
          UniversalBleChessnutProfile.manufacturerCompanyId,
          Uint8List.fromList('CSChessnut Air Plus'.codeUnits),
        ),
      ),
      PhysicalBoardModel.general,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromDevice(
        BleDevice(
          deviceId: 'unnamed-air-plus-product-code',
          name: null,
          manufacturerDataList: [
            ManufacturerData(
              UniversalBleChessnutProfile.manufacturerCompanyId,
              Uint8List.fromList([0x43, 0x53, 0x82, 0x01]),
            ),
          ],
        ),
      ),
      PhysicalBoardModel.general,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromDevice(
        BleDevice(
          deviceId: 'air-plus-with-generic-name',
          name: 'Chessnut Air',
          manufacturerDataList: [
            ManufacturerData(
              UniversalBleChessnutProfile.manufacturerCompanyId,
              Uint8List.fromList([0x43, 0x53, 0x82, 0x01]),
            ),
          ],
        ),
      ),
      PhysicalBoardModel.air,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromDevice(
        BleDevice(
          deviceId: 'air-plus-with-generic-chessnut-manufacturer-data',
          name: 'Chessnut Air',
          manufacturerDataList: [
            ManufacturerData(
              UniversalBleChessnutProfile.manufacturerCompanyId,
              UniversalBleChessnutProfile.manufacturerPayloadPrefix,
            ),
          ],
        ),
      ),
      PhysicalBoardModel.air,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromDevice(
        BleDevice(
          deviceId: 'air-plus-with-go-like-payload-byte',
          name: 'Chessnut Air',
          manufacturerDataList: [
            ManufacturerData(
              UniversalBleChessnutProfile.manufacturerCompanyId,
              Uint8List.fromList([0x43, 0x53, 0x00, 0x85]),
            ),
          ],
        ),
      ),
      PhysicalBoardModel.air,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromDevice(
        BleDevice(
          deviceId: 'air-plus-with-air-plus-name',
          name: 'Chessnut Air Plus',
          manufacturerDataList: [
            ManufacturerData(
              UniversalBleChessnutProfile.manufacturerCompanyId,
              UniversalBleChessnutProfile.manufacturerPayloadPrefix,
            ),
          ],
        ),
      ),
      PhysicalBoardModel.airPlus,
    );
  });

  test('iOS Pro inference uses the BLE product code without relabeling others',
      () {
    final proByProductCode = BleDevice(
      deviceId: 'ios-pro-product-code',
      name: null,
      manufacturerDataList: [
        ManufacturerData(
          UniversalBleChessnutProfile.manufacturerCompanyId,
          Uint8List.fromList([0x43, 0x53, 0x81, 0x01]),
        ),
      ],
    );
    final proByAdvertisementText = BleDevice(
      deviceId: 'ios-pro-advertisement-text',
      name: null,
      manufacturerDataList: [
        ManufacturerData(
          UniversalBleChessnutProfile.manufacturerCompanyId,
          Uint8List.fromList('CSChessnut Pro'.codeUnits),
        ),
      ],
    );
    final airPlusByProductCode = BleDevice(
      deviceId: 'ios-air-plus-product-code',
      name: null,
      manufacturerDataList: [
        ManufacturerData(
          UniversalBleChessnutProfile.manufacturerCompanyId,
          Uint8List.fromList([0x43, 0x53, 0x82, 0x01]),
        ),
      ],
    );

    expect(
      UniversalBleChessnutMatcher.modelFromDevice(proByProductCode),
      PhysicalBoardModel.general,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromDevice(
        proByProductCode,
        inferProFromManufacturerData: true,
      ),
      PhysicalBoardModel.pro,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromDevice(
        proByAdvertisementText,
        inferProFromManufacturerData: true,
      ),
      PhysicalBoardModel.pro,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromDevice(
        airPlusByProductCode,
        inferProFromManufacturerData: true,
      ),
      PhysicalBoardModel.general,
    );
  });

  test('macOS identifies boards only from the advertised Bluetooth name', () {
    expect(
      UniversalBleChessnutMatcher.modelFromDevice(
        BleDevice(
          deviceId: 'macos-air-plus',
          name: 'Chessnut Air Plus',
          manufacturerDataList: [
            ManufacturerData(
              UniversalBleChessnutProfile.manufacturerCompanyId,
              Uint8List.fromList([0x43, 0x53, 0x80, 0x01]),
            ),
          ],
        ),
        requireBroadcastName: true,
      ),
      PhysicalBoardModel.airPlus,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromDevice(
        BleDevice(
          deviceId: 'macos-conflicting-pro-data',
          name: 'Chessnut Air Plus',
          manufacturerDataList: [
            ManufacturerData(
              UniversalBleChessnutProfile.manufacturerCompanyId,
              Uint8List.fromList([0x43, 0x53, 0x81, 0x01]),
            ),
          ],
        ),
        requireBroadcastName: true,
      ),
      PhysicalBoardModel.airPlus,
    );
    expect(
      UniversalBleChessnutMatcher.modelFromDevice(
        BleDevice(
          deviceId: 'macos-unnamed-air-plus-data',
          name: null,
          manufacturerDataList: [
            ManufacturerData(
              UniversalBleChessnutProfile.manufacturerCompanyId,
              Uint8List.fromList([0x43, 0x53, 0x82, 0x01]),
            ),
          ],
        ),
        requireBroadcastName: true,
      ),
      PhysicalBoardModel.unknown,
    );
  });

  test('broadcast-name-only matching is enabled only on macOS', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(UniversalBleBoardTransport().requireBroadcastName, isTrue);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(UniversalBleBoardTransport().requireBroadcastName, isFalse);

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(UniversalBleBoardTransport().requireBroadcastName, isFalse);
  });

  test(
      'stores the shared Chessnut BLE characteristic contract used by transport',
      () {
    expect(UniversalBleChessnutProfile.boardService,
        ChessnutBleUuids.boardService);
    expect(UniversalBleChessnutProfile.boardCharacteristic,
        ChessnutBleUuids.boardCharacteristic);
    expect(UniversalBleChessnutProfile.responseCharacteristic,
        ChessnutBleUuids.readCharacteristic);
    expect(UniversalBleChessnutProfile.writeCharacteristic,
        ChessnutBleUuids.writeCharacteristic);
    expect(
        UniversalBleChessnutProfile.requiredServices,
        containsAll([
          ChessnutBleUuids.boardService,
          ChessnutBleUuids.readService,
          ChessnutBleUuids.readFileService,
        ]));
    expect(UniversalBleChessnutProfile.scanFilter.withNamePrefix,
        containsAll(['Chessnut', 'chessnut', 'Chess Air', 'ChessAir']));
    expect(
      UniversalBleChessnutProfile
          .scanFilter.withManufacturerData.single.companyIdentifier,
      UniversalBleChessnutProfile.manufacturerCompanyId,
    );
    expect(
      UniversalBleChessnutProfile
          .scanFilter.withManufacturerData.single.payloadPrefix,
      UniversalBleChessnutProfile.manufacturerPayloadPrefix,
    );
    expect(UniversalBleChessnutProfile.scanFilter.withServices, isEmpty);
  });

  test('transport emits disconnected when BLE connection drops', () async {
    final platform = _UniversalBleTransportMock();
    UniversalBle.setInstance(platform);
    final transport = UniversalBleBoardTransport(
      scanTimeout: const Duration(seconds: 1),
      connectTimeout: const Duration(seconds: 1),
    );
    addTearDown(transport.dispose);
    final states = <PhysicalBoardConnectionState>[];
    final stateSub = transport.stateStream.listen(states.add);
    addTearDown(stateSub.cancel);

    final connected = await transport.connect();
    await Future<void>.delayed(Duration.zero);

    expect(connected, isTrue);
    expect(transport.currentState, PhysicalBoardConnectionState.connected);
    expect(transport.boardModel, PhysicalBoardModel.move);

    platform.updateConnection('move-1', false);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(transport.currentState, PhysicalBoardConnectionState.disconnected);
    expect(transport.boardModel, PhysicalBoardModel.unknown);
    expect(states, contains(PhysicalBoardConnectionState.disconnected));
  });

  test('transport emits disconnected when Apple Bluetooth is turned off',
      () async {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final platform = _UniversalBleTransportMock();
    UniversalBle.setInstance(platform);
    final transport = UniversalBleBoardTransport(
      scanTimeout: const Duration(seconds: 1),
      connectTimeout: const Duration(seconds: 1),
    );
    addTearDown(transport.dispose);
    final states = <PhysicalBoardConnectionState>[];
    final stateSub = transport.stateStream.listen(states.add);
    addTearDown(stateSub.cancel);

    expect(await transport.connect(), isTrue);
    expect(transport.currentState, PhysicalBoardConnectionState.connected);

    platform.updateAvailability(AvailabilityState.poweredOff);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(transport.currentState, PhysicalBoardConnectionState.disconnected);
    expect(transport.boardModel, PhysicalBoardModel.unknown);
    expect(states, contains(PhysicalBoardConnectionState.disconnected));
  });

  test('transport detects a dropped Apple BLE link when no callback arrives',
      () async {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final platform = _UniversalBleTransportMock();
    UniversalBle.setInstance(platform);
    final transport = UniversalBleBoardTransport(
      scanTimeout: const Duration(seconds: 1),
      connectTimeout: const Duration(seconds: 1),
      connectionCheckInterval: const Duration(milliseconds: 20),
    );
    addTearDown(transport.dispose);
    final states = <PhysicalBoardConnectionState>[];
    final stateSub = transport.stateStream.listen(states.add);
    addTearDown(stateSub.cancel);

    expect(await transport.connect(), isTrue);
    expect(transport.currentState, PhysicalBoardConnectionState.connected);

    platform.state = BleConnectionState.disconnected;
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(transport.currentState, PhysicalBoardConnectionState.disconnected);
    expect(transport.boardModel, PhysicalBoardModel.unknown);
    expect(states, contains(PhysicalBoardConnectionState.disconnected));
  });

  test('transport does not report connected when native BLE is already down',
      () async {
    final platform = _UniversalBleTransportMock()
      ..disconnectBeforeConnectionValidation = true;
    UniversalBle.setInstance(platform);
    final transport = UniversalBleBoardTransport(
      scanTimeout: const Duration(seconds: 1),
      connectTimeout: const Duration(seconds: 1),
    );
    addTearDown(transport.dispose);

    expect(await transport.connect(), isFalse);
    expect(transport.currentState, PhysicalBoardConnectionState.disconnected);
    expect(transport.boardModel, PhysicalBoardModel.unknown);
  });

  test('Apple transport requires live board protocol activity before online',
      () async {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final platform = _UniversalBleTransportMock()
      ..sendProtocolActivityOnRealtimeEnable = false;
    UniversalBle.setInstance(platform);
    final transport = UniversalBleBoardTransport(
      scanTimeout: const Duration(seconds: 1),
      connectTimeout: const Duration(seconds: 1),
      protocolHandshakeTimeout: const Duration(milliseconds: 30),
    );
    addTearDown(transport.dispose);

    expect(await transport.connect(), isFalse);
    expect(transport.currentState, PhysicalBoardConnectionState.disconnected);
    expect(transport.boardModel, PhysicalBoardModel.unknown);
  });

  test('transport spaces BLE writes by at least 100ms', () async {
    final platform = _UniversalBleTransportMock();
    UniversalBle.setInstance(platform);
    final transport = UniversalBleBoardTransport(
      scanTimeout: const Duration(seconds: 1),
      connectTimeout: const Duration(seconds: 1),
    );
    addTearDown(transport.dispose);

    expect(await transport.connect(), isTrue);
    platform.writeTimes.clear();

    expect(await transport.write([0x01]), isTrue);
    expect(await transport.write([0x02]), isTrue);

    expect(platform.writeTimes, hasLength(2));
    expect(
      platform.writeTimes[1].difference(platform.writeTimes[0]),
      greaterThanOrEqualTo(const Duration(milliseconds: 95)),
    );
  });

  test('Move firmware writes use legacy modes and transfer timing', () async {
    final platform = _UniversalBleTransportMock();
    UniversalBle.setInstance(platform);
    final transport = UniversalBleBoardTransport(
      scanTimeout: const Duration(seconds: 1),
      connectTimeout: const Duration(seconds: 1),
    );
    addTearDown(transport.dispose);

    expect(await transport.connect(), isTrue);
    final previousWriteAt = platform.writeTimes.last;

    expect(
      await transport.writeMoveFirmwarePacket(
        [0x41, 0x24, 0x21],
        withoutResponse: false,
        minimumGap: const Duration(milliseconds: 200),
        trackWriteTime: false,
      ),
      isTrue,
    );
    final beginWriteAt = platform.writeTimes.last;
    expect(
      beginWriteAt.difference(previousWriteAt),
      greaterThanOrEqualTo(const Duration(milliseconds: 190)),
    );

    expect(
      await transport.writeMoveFirmwarePacket(
        [0x41, 0x09, 0x22, 0, 0, 0, 1, 2, 3],
        withoutResponse: true,
        minimumGap: Duration.zero,
        trackWriteTime: false,
      ),
      isTrue,
    );
    final chunkWriteAt = platform.writeTimes.last;
    expect(
      chunkWriteAt.difference(beginWriteAt),
      lessThan(const Duration(milliseconds: 90)),
    );

    expect(
      await transport.writeMoveFirmwarePacket(
        ChessnutMoveCommands.firmwareFileStatus,
        withoutResponse: false,
        minimumGap: Duration.zero,
        trackWriteTime: false,
      ),
      isTrue,
    );
    expect(
        platform.writeProperties.sublist(platform.writeProperties.length - 3), [
      BleOutputProperty.withResponse,
      BleOutputProperty.withoutResponse,
      BleOutputProperty.withResponse,
    ]);
  });

  test('Move firmware writes do not retry with the opposite BLE mode',
      () async {
    final platform = _UniversalBleTransportMock();
    UniversalBle.setInstance(platform);
    final transport = UniversalBleBoardTransport(
      scanTimeout: const Duration(seconds: 1),
      connectTimeout: const Duration(seconds: 1),
    );
    addTearDown(transport.dispose);

    expect(await transport.connect(), isTrue);
    platform.writeProperties.clear();
    platform.failedWriteProperty = BleOutputProperty.withoutResponse;

    expect(
      await transport.writeMoveFirmwarePacket(
        [0x41, 0x09, 0x22, 0, 0, 0, 1, 2, 3],
        withoutResponse: true,
        minimumGap: Duration.zero,
        trackWriteTime: false,
      ),
      isFalse,
    );
    expect(platform.writeProperties, [BleOutputProperty.withoutResponse]);
  });

  test('Move firmware writes split packets at the negotiated MTU', () async {
    final platform = _UniversalBleTransportMock()..negotiatedMtu = 20;
    UniversalBle.setInstance(platform);
    final transport = UniversalBleBoardTransport(
      scanTimeout: const Duration(seconds: 1),
      connectTimeout: const Duration(seconds: 1),
    );
    addTearDown(transport.dispose);

    expect(await transport.connect(), isTrue);
    platform.writeValues.clear();
    platform.writeProperties.clear();

    expect(
      await transport.writeMoveFirmwarePacket(
        List<int>.generate(45, (index) => index),
        withoutResponse: true,
        minimumGap: Duration.zero,
        trackWriteTime: false,
      ),
      isTrue,
    );
    expect(platform.writeValues.map((value) => value.length), [20, 20, 5]);
    expect(
      platform.writeProperties,
      List.filled(3, BleOutputProperty.withoutResponse),
    );
  });

  test('recognizes LED commands for the faster BLE write gap', () {
    expect(
      isChessnutLedCommandForTest(
        ChessnutLedCodec.ledCommandFromSquares({'e4'}),
      ),
      isTrue,
    );
    expect(
      isChessnutLedCommandForTest(
        ChessnutMoveLedCodec.commandFromSquares({
          'e4': ChessnutMoveLedColor.green,
        }),
      ),
      isTrue,
    );
    expect(
      isChessnutLedCommandForTest(ChessnutGeneralCommands.enableRealtimeFen),
      isFalse,
    );
    expect(
      isChessnutLedCommandForTest(
        ChessnutMoveBoardCodec.setBoardCommand(
          '8/8/8/8/8/8/8/8 w - - 0 1',
        ),
      ),
      isFalse,
    );
  });

  test('transport writes requested commands without response first', () async {
    final platform = _UniversalBleTransportMock();
    UniversalBle.setInstance(platform);
    final transport = UniversalBleBoardTransport(
      scanTimeout: const Duration(seconds: 1),
      connectTimeout: const Duration(seconds: 1),
    );
    addTearDown(transport.dispose);

    expect(await transport.connect(), isTrue);
    platform.writeProperties.clear();

    expect(
      await transport.write(
        ChessnutMoveLedCodec.commandFromSquares({
          'e4': ChessnutMoveLedColor.green,
        }),
        withoutResponse: true,
      ),
      isTrue,
    );

    expect(platform.writeProperties, [
      BleOutputProperty.withoutResponse,
    ]);
  });
}

class _UniversalBleTransportMock extends UniversalBlePlatformMock {
  final device = BleDevice(
    deviceId: 'move-1',
    name: 'Chessnut Move',
  );
  bool scanning = false;
  BleConnectionState state = BleConnectionState.disconnected;
  final List<DateTime> writeTimes = [];
  final List<BleOutputProperty> writeProperties = [];
  final List<List<int>> writeValues = [];
  int negotiatedMtu = 512;
  BleOutputProperty? failedWriteProperty;
  bool disconnectBeforeConnectionValidation = false;
  bool sendProtocolActivityOnRealtimeEnable = true;

  @override
  Future<AvailabilityState> getBluetoothAvailabilityState() async {
    return AvailabilityState.poweredOn;
  }

  @override
  Future<void> requestPermissions({
    bool withAndroidFineLocation = false,
  }) async {}

  @override
  Future<void> startScan({
    ScanFilter? scanFilter,
    PlatformConfig? platformConfig,
  }) async {
    scanning = true;
    updateScanResult(device);
  }

  @override
  Future<void> stopScan() async {
    scanning = false;
  }

  @override
  Future<bool> isScanning() async => scanning;

  @override
  Future<void> connect(String deviceId, {Duration? connectionTimeout}) async {
    state = BleConnectionState.connected;
    updateConnection(deviceId, true);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    state = BleConnectionState.disconnected;
    updateConnection(deviceId, false);
  }

  @override
  Future<BleConnectionState> getConnectionState(String deviceId) async => state;

  @override
  Future<List<BleService>> discoverServices(
    String deviceId,
    bool withDescriptors,
  ) async {
    if (disconnectBeforeConnectionValidation) {
      state = BleConnectionState.disconnected;
    }
    return const [];
  }

  @override
  Future<int> requestMtu(String deviceId, int expectedMtu) async {
    return negotiatedMtu;
  }

  @override
  Future<void> setNotifiable(
    String deviceId,
    String service,
    String characteristic,
    BleInputProperty bleInputProperty,
  ) async {}

  @override
  Future<void> writeValue(
    String deviceId,
    String service,
    String characteristic,
    Uint8List value,
    BleOutputProperty bleOutputProperty,
  ) async {
    writeTimes.add(DateTime.now());
    writeProperties.add(bleOutputProperty);
    writeValues.add(List<int>.from(value));
    if (bleOutputProperty == failedWriteProperty) {
      throw StateError('Configured BLE write failure.');
    }
    if (sendProtocolActivityOnRealtimeEnable &&
        (listEquals(value, ChessnutMoveCommands.enableRealtimeFen) ||
            listEquals(value, ChessnutMoveCommands.batteryStatus))) {
      Future<void>.microtask(() {
        updateCharacteristicValue(
          deviceId,
          UniversalBleChessnutProfile.boardCharacteristic,
          Uint8List.fromList([0x01]),
          null,
        );
      });
    }
  }
}
