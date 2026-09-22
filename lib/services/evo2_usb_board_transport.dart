import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'board_settings_service.dart';
import 'physical_board_gateway.dart';
import 'physical_board_protocol.dart';

class Evo2UsbBoardTransport
    implements PhysicalBoardTransport, Evo2LedPatternBoardTransport {
  Evo2UsbBoardTransport({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
    bool? isAndroid,
  })  : _methodChannel =
            methodChannel ?? const MethodChannel('chessnut/evo2_board'),
        _eventChannel =
            eventChannel ?? const EventChannel('chessnut/evo2_board/events'),
        _isAndroid = isAndroid ?? Platform.isAndroid;

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  final bool _isAndroid;
  final _stateController =
      StreamController<PhysicalBoardConnectionState>.broadcast();
  final _fenController = StreamController<List<int>>.broadcast();
  final _responseController = StreamController<List<int>>.broadcast();
  StreamSubscription<dynamic>? _eventSub;
  PhysicalBoardConnectionState _state =
      PhysicalBoardConnectionState.disconnected;
  Completer<bool>? _pendingConnect;

  @override
  PhysicalBoardModel get boardModel => PhysicalBoardModel.evo2;

  @override
  PhysicalBoardConnectionState get currentState => _state;

  @override
  Stream<PhysicalBoardConnectionState> get stateStream =>
      _stateController.stream;

  @override
  Stream<List<int>> get fenPayloadStream => _fenController.stream;

  @override
  Stream<List<int>> get responseStream => _responseController.stream;

  @override
  Stream<List<int>> get filePayloadStream => const Stream.empty();

  @override
  Future<bool> connect() async {
    if (kIsWeb || !_isAndroid) return false;
    _ensureEventSubscription();
    _setState(PhysicalBoardConnectionState.connecting);
    try {
      final connected = await _methodChannel.invokeMethod<bool>('connect');
      if (connected == true) {
        _setState(PhysicalBoardConnectionState.connected);
        _completePendingConnect(true);
        return true;
      }
    } catch (_) {
      _setState(PhysicalBoardConnectionState.disconnected);
      _completePendingConnect(false);
      return false;
    }
    final completer = Completer<bool>();
    _pendingConnect?.complete(false);
    _pendingConnect = completer;
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        if (identical(_pendingConnect, completer)) {
          _pendingConnect = null;
        }
        return _state == PhysicalBoardConnectionState.connected;
      },
    );
  }

  @override
  Future<void> disconnect() async {
    _pendingConnect?.complete(false);
    _pendingConnect = null;
    try {
      await _methodChannel.invokeMethod<void>('disconnect');
    } catch (_) {}
    await _eventSub?.cancel();
    _eventSub = null;
    _setState(PhysicalBoardConnectionState.disconnected);
  }

  @override
  Future<bool> write(
    List<int> command, {
    bool withoutResponse = false,
  }) async {
    if (kIsWeb || !_isAndroid) return false;
    if (_isRealtimeFenCommand(command)) return true;
    final rows = _generalLedRows(command);
    if (rows != null) {
      try {
        return await _methodChannel.invokeMethod<bool>(
              'setLedRows',
              {'rows': Uint8List.fromList(rows)},
            ) ??
            false;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  @override
  Future<bool> setEvo2LedBrightness(int brightness) async {
    if (kIsWeb || !_isAndroid) return false;
    try {
      return await _methodChannel.invokeMethod<bool>(
            'setLedBrightness',
            {'brightness': brightness.clamp(0, 100)},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> setEvo2LedPatternsForFen(
    String boardOnlyFen,
    Evo2LedPatternSet patterns,
  ) async {
    final pieces = _evo2PiecesFromFen(boardOnlyFen);
    if (pieces == null) return false;
    return setEvo2LedPatternKeys(
      [for (final piece in pieces) piece ?? 'empty'],
      patterns,
    );
  }

  @override
  Future<bool> setEvo2LedPatternKeys(
    List<String?> squarePatternKeys,
    Evo2LedPatternSet patterns,
  ) async {
    if (kIsWeb || !_isAndroid || squarePatternKeys.length != 64) return false;
    final payload = Uint8List(64 * evo2LedPatternCellCount * 3);
    var offset = 0;
    for (final key in squarePatternKeys) {
      if (key != null && !evo2LedPatternKeys.contains(key)) return false;
      final colors =
          key == null ? const <int>[] : patterns.patternFor(key).colors;
      for (var i = 0; i < evo2LedPatternCellCount; i += 1) {
        final color = i < colors.length ? colors[i] : 0;
        payload[offset] = (color >> 16) & 0xff;
        payload[offset + 1] = (color >> 8) & 0xff;
        payload[offset + 2] = color & 0xff;
        offset += 3;
      }
    }
    try {
      return await _methodChannel.invokeMethod<bool>(
            'setLedPatternPixels',
            {'pixels': payload},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
    await _fenController.close();
    await _responseController.close();
  }

  void _ensureEventSubscription() {
    _eventSub ??= _eventChannel.receiveBroadcastStream().listen(
      _handleEvent,
      onError: (_) {
        _setState(PhysicalBoardConnectionState.disconnected);
        _completePendingConnect(false);
      },
    );
  }

  void _handleEvent(dynamic event) {
    if (event is! Map) return;
    switch (event['type']) {
      case 'connection':
        final state = _stateFromNative(event['state']?.toString());
        _setState(state);
        if (state == PhysicalBoardConnectionState.connected) {
          _completePendingConnect(true);
        } else if (state == PhysicalBoardConnectionState.disconnected) {
          _completePendingConnect(false);
        }
        return;
      case 'fen':
        final data = _bytes(event['data']);
        if (data != null) _fenController.add(data);
        return;
      case 'response':
        final data = _bytes(event['data']);
        if (data != null) _responseController.add(data);
        return;
      case 'error':
        return;
    }
  }

  void _setState(PhysicalBoardConnectionState state) {
    if (_state == state) return;
    _state = state;
    _stateController.add(state);
  }

  void _completePendingConnect(bool value) {
    final completer = _pendingConnect;
    _pendingConnect = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(value);
    }
  }
}

bool _isRealtimeFenCommand(List<int> command) {
  return _sameCommand(command, ChessnutGeneralCommands.enableRealtimeFen) ||
      _sameCommand(command, ChessnutMoveCommands.enableRealtimeFen);
}

List<int>? _generalLedRows(List<int> command) {
  if (command.length == 10 && command[0] == 0x0a && command[1] == 0x08) {
    return List<int>.unmodifiable(command.sublist(2, 10));
  }
  return null;
}

List<String?>? _evo2PiecesFromFen(String boardOnlyFen) {
  final pieces = <String?>[];
  final rows = boardOnlyFen.trim().split('/');
  if (rows.length != 8) return null;
  for (final row in rows) {
    var columns = 0;
    for (var i = 0; i < row.length; i += 1) {
      final char = row[i];
      final empty = int.tryParse(char);
      if (empty != null) {
        if (empty < 1 || empty > 8) return null;
        for (var j = 0; j < empty; j += 1) {
          pieces.add(null);
          columns += 1;
        }
        continue;
      }
      if (!evo2LedPatternKeys.contains(char)) return null;
      pieces.add(char);
      columns += 1;
    }
    if (columns != 8) return null;
  }
  return pieces.length == 64 ? List<String?>.unmodifiable(pieces) : null;
}

bool _sameCommand(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i += 1) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

PhysicalBoardConnectionState _stateFromNative(String? value) {
  return switch (value?.toUpperCase()) {
    'CONNECTED' => PhysicalBoardConnectionState.connected,
    'CONNECTING' => PhysicalBoardConnectionState.connecting,
    'SCANNING' => PhysicalBoardConnectionState.scanning,
    _ => PhysicalBoardConnectionState.disconnected,
  };
}

List<int>? _bytes(Object? value) {
  if (value is Uint8List) return List<int>.unmodifiable(value);
  if (value is ByteData) {
    return List<int>.unmodifiable(value.buffer.asUint8List());
  }
  if (value is List) {
    return List<int>.unmodifiable(value.map((item) => (item as num).toInt()));
  }
  return null;
}
