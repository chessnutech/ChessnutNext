import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'physical_board_protocol.dart';

typedef MoveFirmwareWrite = Future<bool> Function(
  List<int> command, {
  required bool withoutResponse,
  required Duration minimumGap,
  required bool trackWriteTime,
});

typedef MoveFirmwareProgress = void Function(int transferred, int total);

class MoveFirmwareUpdateController {
  MoveFirmwareUpdateController({
    required MoveFirmwareWrite write,
    required Stream<List<int>> responseStream,
    required Stream<bool> connectionStream,
    required bool Function() isConnected,
    this.supportTimeout = const Duration(seconds: 1),
    this.wifiConnectTimeout = const Duration(seconds: 30),
    this.wifiUpdateTimeout = const Duration(minutes: 30),
    this.initialTransferTimeout = const Duration(seconds: 5),
    this.pollTimeout = const Duration(seconds: 2),
    this.maxPollTimeouts = 30,
  })  : _write = write,
        _responseStream = responseStream,
        _connectionStream = connectionStream,
        _isConnected = isConnected;

  static const Duration legacyCommandWriteGap = Duration(milliseconds: 200);

  final MoveFirmwareWrite _write;
  final Stream<List<int>> _responseStream;
  final Stream<bool> _connectionStream;
  final bool Function() _isConnected;
  final Duration supportTimeout;
  final Duration wifiConnectTimeout;
  final Duration wifiUpdateTimeout;
  final Duration initialTransferTimeout;
  final Duration pollTimeout;
  final int maxPollTimeouts;

  bool _busy = false;
  Completer<void>? _idleCompleter;

  bool get isBusy => _busy;

  Future<bool> checkBluetoothUpdateSupport() {
    return _runExclusive(() async {
      final response = _nextResponse(
        const {0x24},
        supportTimeout,
      );
      await _send(
        ChessnutMoveCommands.firmwareUpdateSupport,
        minimumGap: legacyCommandWriteGap,
        trackWriteTime: true,
      );
      return await response != null;
    });
  }

  Future<bool> configureWifi({
    required String ssid,
    required String password,
  }) {
    return _runExclusive(() async {
      await _send(
        ChessnutMoveCommands.setWifiSsid(ssid),
        minimumGap: legacyCommandWriteGap,
        trackWriteTime: true,
      );
      await _send(
        ChessnutMoveCommands.setWifiPassword(password),
        minimumGap: legacyCommandWriteGap,
        trackWriteTime: true,
      );
      final response = _nextResponse(
        const {0x05},
        wifiConnectTimeout,
      );
      await _send(
        ChessnutMoveCommands.connectWifi,
        minimumGap: legacyCommandWriteGap,
        trackWriteTime: true,
      );
      final data = await response;
      return ChessnutMoveCommandResponse.isSuccess(data, 0x05);
    });
  }

  Future<bool> startWifiUpdate() {
    return _runExclusive(() async {
      final response = _nextResponse(
        const {0x0a},
        wifiUpdateTimeout,
      );
      await _send(
        ChessnutMoveCommands.startWifiFirmwareUpdate,
        minimumGap: legacyCommandWriteGap,
        trackWriteTime: true,
      );
      final data = await response;
      return ChessnutMoveCommandResponse.isSuccess(data, 0x0a);
    });
  }

  Future<bool> sendFirmwareFile(
    Uint8List data, {
    MoveFirmwareProgress? onProgress,
  }) async {
    if (!_isConnected()) return false;

    return _runFirmwareFileTransfer(() async {
      var md5Check = utf8.encode(md5.convert(data).toString());

      // Keep the legacy response filter and subscribe only after each write.
      var getDataStream = _responseStream.where((res) {
        if (res.isNotEmpty && res.length >= 3) {
          return res[0] == 0x41 && (res[2] == 0x22 || res[2] == 0x23);
        }
        return false;
      });
      var chunkLength = 170;
      var totalIndex = (data.length / chunkLength).ceil();

      var totalIndexList = <int>[];
      totalIndexList.add(totalIndex >> 16 & ((1 << 8) - 1));
      totalIndexList.add(totalIndex >> 8 & ((1 << 8) - 1));
      totalIndexList.add(totalIndex & ((1 << 8) - 1));
      await _writeFirmwarePacket(
        [
          0x41,
          md5Check.length + 4,
          0x21,
          ...totalIndexList,
          ...md5Check,
        ],
        minimumGap: legacyCommandWriteGap,
      );

      var res = await getDataStream.first.timeout(
        initialTransferTimeout,
        onTimeout: () => <int>[],
      );

      if (res.isEmpty || res[2] != 0x22) {
        return false;
      }

      for (var i = 0; i < totalIndex; i++) {
        if (!_isConnected()) {
          return false;
        }
        if (onProgress != null) {
          onProgress(i * chunkLength, data.length * 2);
        }

        var rangeData = data
            .getRange(
              i * chunkLength,
              min(i * chunkLength + chunkLength, data.length),
            )
            .toList();

        var crc = moveFirmwareCrc32(Uint8List.fromList(rangeData));
        final bd = ByteData(4);
        bd.setUint32(0, crc, Endian.big);

        var nowIndexList = <int>[];
        nowIndexList.add(i >> 16 & ((1 << 8) - 1));
        nowIndexList.add(i >> 8 & ((1 << 8) - 1));
        nowIndexList.add(i & ((1 << 8) - 1));

        await _writeFirmwarePacket(
          [
            0x41,
            rangeData.length + 8,
            0x22,
            ...nowIndexList,
            ...rangeData,
            ...bd.buffer.asUint8List(),
          ],
          withoutResponse: true,
        );
      }

      var timeoutCount = 0;

      while (true) {
        if (!_isConnected()) {
          return false;
        }
        await _writeFirmwarePacket([0x41, 0x01, 0x22]);
        var res = await getDataStream.first.timeout(
          pollTimeout,
          onTimeout: () => <int>[],
        );

        if (res.isEmpty) {
          timeoutCount += 1;
          if (timeoutCount >= maxPollTimeouts) {
            break;
          }
          continue;
        }
        timeoutCount = 0;

        if (res[2] == 0x23) {
          if (onProgress != null) {
            onProgress(data.length * 2, data.length * 2);
          }
          if (res[3] == 0) {
            return true;
          } else {
            return false;
          }
        }

        if (res[2] == 0x22) {
          List<int> indexList = [];
          for (var i = 0; i < ((res[1] - 1) ~/ 3); i++) {
            indexList.add(
              (res[3 + (i * 3)] << 16) +
                  (res[4 + (i * 3)] << 8) +
                  res[5 + (i * 3)],
            );
          }

          for (var i in indexList) {
            if (onProgress != null) {
              onProgress(i * chunkLength + data.length, data.length * 2);
            }
            var nowIndexList = <int>[];
            nowIndexList.add(i >> 16 & ((1 << 8) - 1));
            nowIndexList.add(i >> 8 & ((1 << 8) - 1));
            nowIndexList.add(i & ((1 << 8) - 1));

            var rangeData = data
                .getRange(
                  i * chunkLength,
                  min(i * chunkLength + chunkLength, data.length),
                )
                .toList();

            var crc = moveFirmwareCrc32(Uint8List.fromList(rangeData));
            final bd = ByteData(4);
            bd.setUint32(0, crc, Endian.big);

            await _writeFirmwarePacket(
              [
                0x41,
                rangeData.length + 8,
                0x22,
                ...nowIndexList,
                ...rangeData,
                ...bd.buffer.asUint8List(),
              ],
              withoutResponse: true,
            );
          }
        }
      }

      return false;
    });
  }

  Future<bool> _writeFirmwarePacket(
    List<int> command, {
    bool withoutResponse = false,
    Duration minimumGap = Duration.zero,
  }) {
    return _write(
      command,
      withoutResponse: withoutResponse,
      minimumGap: minimumGap,
      trackWriteTime: false,
    );
  }

  Future<bool> _send(
    List<int> command, {
    bool withoutResponse = false,
    Duration minimumGap = Duration.zero,
    bool trackWriteTime = false,
  }) {
    return _write(
      command,
      withoutResponse: withoutResponse,
      minimumGap: minimumGap,
      trackWriteTime: trackWriteTime,
    );
  }

  Future<List<int>?> _nextResponse(
    Set<int> commandCodes,
    Duration timeout,
  ) {
    final completer = Completer<List<int>?>();
    StreamSubscription<List<int>>? responseSub;
    StreamSubscription<bool>? connectionSub;
    Timer? timer;

    void complete(List<int>? value) {
      if (completer.isCompleted) return;
      completer.complete(value);
      timer?.cancel();
      unawaited(responseSub?.cancel());
      unawaited(connectionSub?.cancel());
    }

    responseSub = _responseStream.listen(
      (data) {
        if (data.length >= 3 &&
            data[0] == 0x41 &&
            commandCodes.contains(data[2])) {
          complete(List<int>.unmodifiable(data));
        }
      },
      onError: (_) => complete(null),
      onDone: () => complete(null),
    );
    connectionSub = _connectionStream.listen((connected) {
      if (!connected) complete(null);
    });
    timer = Timer(timeout, () => complete(null));
    if (!_isConnected()) complete(null);
    return completer.future;
  }

  Future<bool> _runExclusive(Future<bool> Function() operation) async {
    if (_busy || !_isConnected()) return false;
    _busy = true;
    final idleCompleter = Completer<void>();
    _idleCompleter = idleCompleter;
    try {
      return await operation();
    } catch (_) {
      return false;
    } finally {
      _busy = false;
      if (!idleCompleter.isCompleted) idleCompleter.complete();
      if (identical(_idleCompleter, idleCompleter)) _idleCompleter = null;
    }
  }

  Future<bool> _runFirmwareFileTransfer(
    Future<bool> Function() operation,
  ) async {
    if (_busy || !_isConnected()) return false;
    _busy = true;
    final idleCompleter = Completer<void>();
    _idleCompleter = idleCompleter;
    try {
      return await operation();
    } finally {
      _busy = false;
      if (!idleCompleter.isCompleted) idleCompleter.complete();
      if (identical(_idleCompleter, idleCompleter)) _idleCompleter = null;
    }
  }

  Future<bool> writeWhenIdle(Future<bool> Function() write) async {
    final idle = _idleCompleter;
    if (idle != null) await idle.future;
    return write();
  }
}

int _moveFirmwareCrc32TableInit() {
  const int poly = 0xEDB88320;
  final table = List<int>.filled(256, 0);
  for (int i = 0; i < 256; i++) {
    int c = i;
    for (int k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (poly ^ (c >> 1)) : (c >> 1);
    }
    table[i] = c;
  }
  _moveFirmwareCrc32TableCache = table;
  return 1;
}

late List<int> _moveFirmwareCrc32TableCache;
bool _moveFirmwareCrc32TableInitialized = false;

int moveFirmwareCrc32(Uint8List bytes, {int seed = 0}) {
  if (!_moveFirmwareCrc32TableInitialized) {
    _moveFirmwareCrc32TableInit();
    _moveFirmwareCrc32TableInitialized = true;
  }

  int crc = (seed ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  for (final b in bytes) {
    crc = _moveFirmwareCrc32TableCache[(crc ^ b) & 0xFF] ^ (crc >> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
