import 'dart:async';
import 'dart:typed_data';

import 'package:chessnut_flutter_export/services/move_firmware_update_service.dart';
import 'package:chessnut_flutter_export/services/physical_board_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the same CRC32 algorithm as the legacy Move updater', () {
    expect(
      moveFirmwareCrc32(Uint8List.fromList('123456789'.codeUnits)),
      0xcbf43926,
    );
  });

  test('checks Bluetooth update support with command 0x24', () async {
    final responses = StreamController<List<int>>.broadcast();
    final connections = StreamController<bool>.broadcast();
    final writes = <({
      List<int> bytes,
      bool withoutResponse,
      Duration minimumGap,
      bool trackWriteTime,
    })>[];
    final controller = MoveFirmwareUpdateController(
      write: (
        command, {
        required withoutResponse,
        required minimumGap,
        required trackWriteTime,
      }) async {
        writes.add((
          bytes: command,
          withoutResponse: withoutResponse,
          minimumGap: minimumGap,
          trackWriteTime: trackWriteTime,
        ));
        scheduleMicrotask(() => responses.add([0x41, 0x01, 0x24]));
        return true;
      },
      responseStream: responses.stream,
      connectionStream: connections.stream,
      isConnected: () => true,
      supportTimeout: const Duration(milliseconds: 20),
    );
    addTearDown(responses.close);
    addTearDown(connections.close);

    expect(await controller.checkBluetoothUpdateSupport(), isTrue);
    expect(writes.single.bytes, ChessnutMoveCommands.firmwareUpdateSupport);
    expect(writes.single.withoutResponse, isFalse);
    expect(
      writes.single.minimumGap,
      MoveFirmwareUpdateController.legacyCommandWriteGap,
    );
    expect(writes.single.trackWriteTime, isTrue);
  });

  test('queues normal board writes until the firmware operation is idle',
      () async {
    final responses = StreamController<List<int>>.broadcast();
    final connections = StreamController<bool>.broadcast();
    var normalWriteStarted = false;
    final controller = MoveFirmwareUpdateController(
      write: (
        command, {
        required withoutResponse,
        required minimumGap,
        required trackWriteTime,
      }) async =>
          true,
      responseStream: responses.stream,
      connectionStream: connections.stream,
      isConnected: () => true,
      supportTimeout: const Duration(milliseconds: 50),
    );
    addTearDown(responses.close);
    addTearDown(connections.close);

    final supportCheck = controller.checkBluetoothUpdateSupport();
    await Future<void>.delayed(Duration.zero);
    final normalWrite = controller.writeWhenIdle(() async {
      normalWriteStarted = true;
      return true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(normalWriteStarted, isFalse);

    responses.add([0x41, 0x01, 0x24]);
    expect(await supportCheck, isTrue);
    expect(await normalWrite, isTrue);
    expect(normalWriteStarted, isTrue);
  });

  test('configures Wi-Fi and waits for the legacy connect result', () async {
    final responses = StreamController<List<int>>.broadcast();
    final connections = StreamController<bool>.broadcast();
    final writes = <({
      List<int> bytes,
      bool withoutResponse,
      Duration minimumGap,
      bool trackWriteTime,
    })>[];
    final controller = MoveFirmwareUpdateController(
      write: (
        command, {
        required withoutResponse,
        required minimumGap,
        required trackWriteTime,
      }) async {
        writes.add((
          bytes: command,
          withoutResponse: withoutResponse,
          minimumGap: minimumGap,
          trackWriteTime: trackWriteTime,
        ));
        if (_sameBytes(command, ChessnutMoveCommands.connectWifi)) {
          scheduleMicrotask(() => responses.add([0x41, 0x02, 0x05, 0x00]));
        }
        return true;
      },
      responseStream: responses.stream,
      connectionStream: connections.stream,
      isConnected: () => true,
      wifiConnectTimeout: const Duration(milliseconds: 20),
    );
    addTearDown(responses.close);
    addTearDown(connections.close);

    expect(
      await controller.configureWifi(ssid: 'Move Wi-Fi', password: 'secret'),
      isTrue,
    );
    expect(writes.map((write) => write.bytes), [
      ChessnutMoveCommands.setWifiSsid('Move Wi-Fi'),
      ChessnutMoveCommands.setWifiPassword('secret'),
      ChessnutMoveCommands.connectWifi,
    ]);
    expect(writes.every((write) => !write.withoutResponse), isTrue);
    expect(
      writes.every(
        (write) =>
            write.minimumGap ==
            MoveFirmwareUpdateController.legacyCommandWriteGap,
      ),
      isTrue,
    );
    expect(writes.every((write) => write.trackWriteTime), isTrue);
  });

  test('resends requested chunks and polls again until Move reports success',
      () async {
    final responses = StreamController<List<int>>.broadcast();
    final connections = StreamController<bool>.broadcast();
    final writes = <({
      List<int> bytes,
      bool withoutResponse,
      Duration minimumGap,
      bool trackWriteTime,
    })>[];
    var statusPolls = 0;
    final controller = MoveFirmwareUpdateController(
      write: (
        command, {
        required withoutResponse,
        required minimumGap,
        required trackWriteTime,
      }) async {
        writes.add(
          (
            bytes: List<int>.from(command),
            withoutResponse: withoutResponse,
            minimumGap: minimumGap,
            trackWriteTime: trackWriteTime,
          ),
        );
        if (command.length >= 3 && command[2] == 0x21) {
          Timer.run(() => responses.add([0x41, 0x01, 0x22]));
        } else if (_sameBytes(
            command, ChessnutMoveCommands.firmwareFileStatus)) {
          statusPolls++;
          Timer.run(() {
            responses.add(
              statusPolls == 1
                  ? [0x41, 0x04, 0x22, 0x00, 0x00, 0x01]
                  : [0x41, 0x02, 0x23, 0x00],
            );
          });
        }
        return true;
      },
      responseStream: responses.stream,
      connectionStream: connections.stream,
      isConnected: () => true,
      initialTransferTimeout: const Duration(milliseconds: 20),
      pollTimeout: const Duration(milliseconds: 20),
    );
    addTearDown(responses.close);
    addTearDown(connections.close);
    final firmware = Uint8List.fromList(
      List<int>.generate(171, (index) => index & 0xff),
    );
    final progress = <({int transferred, int total})>[];

    expect(
      await controller.sendFirmwareFile(
        firmware,
        onProgress: (transferred, total) =>
            progress.add((transferred: transferred, total: total)),
      ),
      isTrue,
    );

    final begin = writes.first.bytes;
    expect(begin.take(6), [0x41, 36, 0x21, 0x00, 0x00, 0x02]);
    expect(String.fromCharCodes(begin.skip(6)), hasLength(32));
    expect(writes.first.withoutResponse, isFalse);
    expect(
      writes.first.minimumGap,
      MoveFirmwareUpdateController.legacyCommandWriteGap,
    );
    expect(writes.first.trackWriteTime, isFalse);

    final chunkWrites = writes.where(
      (write) => write.bytes.length > 3 && write.bytes[2] == 0x22,
    );
    expect(chunkWrites, hasLength(3));
    expect(chunkWrites.every((write) => write.withoutResponse), isTrue);
    expect(
      chunkWrites.every((write) => write.minimumGap == Duration.zero),
      isTrue,
    );
    expect(chunkWrites.every((write) => !write.trackWriteTime), isTrue);
    expect(
      chunkWrites.map((write) => _chunkIndex(write.bytes)),
      [0, 1, 1],
    );
    expect(statusPolls, 2);
    final statusWrites = writes.where(
      (write) =>
          _sameBytes(write.bytes, ChessnutMoveCommands.firmwareFileStatus),
    );
    expect(statusWrites.every((write) => !write.withoutResponse), isTrue);
    expect(
      statusWrites.every((write) => write.minimumGap == Duration.zero),
      isTrue,
    );
    expect(progress.last, (transferred: 342, total: 342));

    final lastChunk = chunkWrites.last.bytes;
    final payload = firmware.sublist(170);
    final checksum = moveFirmwareCrc32(Uint8List.fromList(payload));
    expect(lastChunk, [
      0x41,
      9,
      0x22,
      0x00,
      0x00,
      0x01,
      ...payload,
      (checksum >> 24) & 0xff,
      (checksum >> 16) & 0xff,
      (checksum >> 8) & 0xff,
      checksum & 0xff,
    ]);
  });

  test('stops after the legacy number of unanswered status polls', () async {
    final responses = StreamController<List<int>>.broadcast();
    final connections = StreamController<bool>.broadcast();
    var statusPolls = 0;
    final controller = MoveFirmwareUpdateController(
      write: (
        command, {
        required withoutResponse,
        required minimumGap,
        required trackWriteTime,
      }) async {
        if (command.length >= 3 && command[2] == 0x21) {
          Timer.run(() => responses.add([0x41, 0x01, 0x22]));
        } else if (_sameBytes(
            command, ChessnutMoveCommands.firmwareFileStatus)) {
          statusPolls++;
        }
        return true;
      },
      responseStream: responses.stream,
      connectionStream: connections.stream,
      isConnected: () => true,
      initialTransferTimeout: const Duration(milliseconds: 20),
      pollTimeout: const Duration(milliseconds: 1),
      maxPollTimeouts: 3,
    );
    addTearDown(responses.close);
    addTearDown(connections.close);

    expect(
      await controller.sendFirmwareFile(Uint8List.fromList([1, 2, 3])),
      isFalse,
    );
    expect(statusPolls, 3);
  });

  test('recovers a failed chunk write through the legacy missing-packet loop',
      () async {
    final responses = StreamController<List<int>>.broadcast();
    final connections = StreamController<bool>.broadcast();
    var chunkWrites = 0;
    var statusPolls = 0;
    final controller = MoveFirmwareUpdateController(
      write: (
        command, {
        required withoutResponse,
        required minimumGap,
        required trackWriteTime,
      }) async {
        if (command.length >= 3 && command[2] == 0x21) {
          Timer.run(() => responses.add([0x41, 0x01, 0x22]));
        } else if (command.length > 3 && command[2] == 0x22) {
          chunkWrites++;
          return chunkWrites > 1;
        } else if (_sameBytes(
          command,
          ChessnutMoveCommands.firmwareFileStatus,
        )) {
          statusPolls++;
          Timer.run(() {
            responses.add(
              statusPolls == 1
                  ? [0x41, 0x04, 0x22, 0x00, 0x00, 0x00]
                  : [0x41, 0x02, 0x23, 0x00],
            );
          });
        }
        return true;
      },
      responseStream: responses.stream,
      connectionStream: connections.stream,
      isConnected: () => true,
      initialTransferTimeout: const Duration(milliseconds: 20),
      pollTimeout: const Duration(milliseconds: 20),
    );
    addTearDown(responses.close);
    addTearDown(connections.close);

    expect(
      await controller.sendFirmwareFile(Uint8List.fromList([1, 2, 3])),
      isTrue,
    );
    expect(chunkWrites, 2);
    expect(statusPolls, 2);
  });
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

int _chunkIndex(List<int> packet) {
  return (packet[3] << 16) | (packet[4] << 8) | packet[5];
}
