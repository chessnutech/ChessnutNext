import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// USB 棋钟按钮侧
enum UsbClockButton {
  left,
  right;

  static UsbClockButton fromString(String value) {
    return switch (value.toUpperCase()) {
      'LEFT' => UsbClockButton.left,
      'RIGHT' => UsbClockButton.right,
      _ => throw ArgumentError('Unknown button: $value'),
    };
  }
}

/// USB 棋钟按钮事件
class UsbClockButtonEvent {
  const UsbClockButtonEvent({
    required this.button,
    required this.pressed,
    required this.timestamp,
  });

  final UsbClockButton button;
  final bool pressed;
  final int timestamp;

  factory UsbClockButtonEvent.fromMap(Map<dynamic, dynamic> map) {
    return UsbClockButtonEvent(
      button: UsbClockButton.fromString(map['button'] as String),
      pressed: map['pressed'] as bool,
      timestamp: map['timestamp'] as int,
    );
  }

  @override
  String toString() {
    return 'UsbClockButtonEvent(button: ${button.name}, pressed: $pressed, timestamp: $timestamp)';
  }
}

/// USB 棋钟连接状态
enum UsbClockConnectionState {
  disconnected,
  connecting,
  connected;

  static UsbClockConnectionState fromString(String value) {
    return switch (value.toUpperCase()) {
      'DISCONNECTED' => UsbClockConnectionState.disconnected,
      'CONNECTING' => UsbClockConnectionState.connecting,
      'CONNECTED' => UsbClockConnectionState.connected,
      _ => UsbClockConnectionState.disconnected,
    };
  }
}

/// USB 棋钟服务
class UsbClockService {
  UsbClockService._();

  static final UsbClockService instance = UsbClockService._();
  static const Duration _methodTimeout = Duration(milliseconds: 700);
  static const Duration _commandMinInterval = Duration(milliseconds: 200);
  static const Duration _verificationInterval = Duration(milliseconds: 50);
  static const int _verificationChecks = 10;

  static const MethodChannel _methodChannel =
      MethodChannel('chessnut/clock_hid');
  static const EventChannel _eventChannel =
      EventChannel('chessnut/clock_hid/events');

  StreamController<UsbClockButtonEvent>? _buttonEventController;
  StreamController<UsbClockConnectionState>? _connectionStateController;
  StreamSubscription<dynamic>? _eventSubscription;

  UsbClockButton? _lastButton;
  Future<void> _commandQueue = Future<void>.value();
  int? _lastCommandSentAtMs;
  UsbClockButton? _pendingCommandButton;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// 按钮事件流（仅在按钮变化时触发）
  Stream<UsbClockButtonEvent> get buttonEvents {
    _ensureInitialized();
    return _buttonEventController!.stream;
  }

  /// 连接状态流
  Stream<UsbClockConnectionState> get connectionStateEvents {
    _ensureInitialized();
    return _connectionStateController!.stream;
  }

  /// 当前最后按下的按钮
  UsbClockButton? get lastButton => _lastButton;

  Future<UsbClockButton?> getLastButton() async {
    if (!isSupported) return _lastButton;

    try {
      final result = await _methodChannel
          .invokeMethod<String>('getLastButton')
          .timeout(_methodTimeout);
      if (result == null || result.isEmpty) return _lastButton;
      final button = UsbClockButton.fromString(result);
      _lastButton = button;
      return button;
    } on TimeoutException {
      return _lastButton;
    } catch (_) {
      return _lastButton;
    }
  }

  void _ensureInitialized() {
    if (_buttonEventController == null) {
      _buttonEventController =
          StreamController<UsbClockButtonEvent>.broadcast();
      _connectionStateController =
          StreamController<UsbClockConnectionState>.broadcast();
      _startListening();
    }
  }

  void _startListening() {
    if (!isSupported) return;

    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is! Map) return;

        final type = event['type'] as String?;
        if (type == 'button') {
          _handleButtonEvent(event);
        } else if (type == 'connection') {
          _handleConnectionEvent(event);
        }
      },
      onError: (_) {},
    );
  }

  void _handleButtonEvent(Map<dynamic, dynamic> event) {
    try {
      final buttonEvent = UsbClockButtonEvent.fromMap(event);
      final buttonChanged = _lastButton != buttonEvent.button;
      final isCommandConfirmation =
          buttonEvent.pressed && _pendingCommandButton == buttonEvent.button;

      // 始终先记录最新的物理方向，主动切换方法会轮询这个值确认结果。
      _lastButton = buttonEvent.button;

      // 主动切换产生的目标方向回报只作为确认，不再向页面冒充一次新的
      // 物理按键，避免页面重复切换；相反方向的真实按键仍然正常转发。
      if (isCommandConfirmation) return;
      if (buttonChanged) _buttonEventController?.add(buttonEvent);
    } catch (_) {}
  }

  void _handleConnectionEvent(Map<dynamic, dynamic> event) {
    try {
      final state =
          UsbClockConnectionState.fromString(event['state'] as String);
      _connectionStateController?.add(state);
    } catch (_) {}
  }

  /// 连接设备
  Future<bool> connect() async {
    if (!isSupported) return false;

    try {
      final result = await _methodChannel
          .invokeMethod<bool>('connect')
          .timeout(_methodTimeout);
      return result ?? false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    if (!isSupported) return;

    try {
      await _methodChannel
          .invokeMethod<void>('disconnect')
          .timeout(_methodTimeout);
    } on TimeoutException {
      return;
    } catch (_) {
      return;
    }
  }

  /// 设置激活侧并等待设备确认。
  ///
  /// 所有主动切换都必须通过这里：调用全局串行化，USB 命令发送间隔
  /// 至少 200ms；命令发送后每 50ms 检查一次物理设备上报的方向，最多
  /// 检查 10 次。只有收到与目标一致的物理方向才认为切换成功。
  Future<bool> setActiveSide(UsbClockButton button) {
    final operation = _commandQueue.then<bool>(
      (_) => _setActiveSideLocked(button),
    );
    _commandQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  Future<bool> _setActiveSideLocked(UsbClockButton button) async {
    if (!isSupported) return false;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final lastSentAt = _lastCommandSentAtMs;
      if (lastSentAt != null) {
        final elapsed = now - lastSentAt;
        final remaining = _commandMinInterval.inMilliseconds - elapsed;
        if (remaining > 0) {
          await Future<void>.delayed(Duration(milliseconds: remaining));
        }
      }

      _pendingCommandButton = button;
      _lastCommandSentAtMs = DateTime.now().millisecondsSinceEpoch;
      final result = await _methodChannel.invokeMethod<bool>('setActiveSide', {
        'side': button.name.toUpperCase(),
      }).timeout(_methodTimeout);
      if (result != true) {
        _pendingCommandButton = null;
        return false;
      }

      for (var check = 0; check < _verificationChecks; check++) {
        await Future<void>.delayed(_verificationInterval);
        // 事件流会持续更新 _lastButton，这里每 50ms 检查一次最新的
        // 物理方向，避免在确认循环中再发起并行的 USB 查询。
        if (_lastButton == button) {
          _pendingCommandButton = null;
          return true;
        }
      }
      _pendingCommandButton = null;
      return false;
    } on TimeoutException {
      _pendingCommandButton = null;
      return false;
    } catch (_) {
      _pendingCommandButton = null;
      return false;
    }
  }

  /// 获取连接状态
  Future<UsbClockConnectionState> getConnectionState() async {
    if (!isSupported) return UsbClockConnectionState.disconnected;

    try {
      final result = await _methodChannel
          .invokeMethod<String>('getConnectionState')
          .timeout(_methodTimeout);
      return UsbClockConnectionState.fromString(result ?? 'DISCONNECTED');
    } on TimeoutException {
      return UsbClockConnectionState.disconnected;
    } catch (_) {
      return UsbClockConnectionState.disconnected;
    }
  }

  /// 释放资源
  void dispose() {
    _eventSubscription?.cancel();
    _buttonEventController?.close();
    _connectionStateController?.close();
    _buttonEventController = null;
    _connectionStateController = null;
    _eventSubscription = null;
    _lastButton = null;
  }
}
