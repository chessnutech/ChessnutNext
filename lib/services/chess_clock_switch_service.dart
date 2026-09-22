import 'dart:async';

import 'usb_clock_service.dart';

enum ChessClockSide {
  left(1),
  right(2);

  const ChessClockSide(this.value);

  final int value;

  ChessClockSide get opposite =>
      this == ChessClockSide.left ? ChessClockSide.right : ChessClockSide.left;

  static ChessClockSide? fromValue(int value) {
    return switch (value) {
      1 => ChessClockSide.left,
      2 => ChessClockSide.right,
      _ => null,
    };
  }
}

/// 棋钟切换服务
///
/// 监听 USB 棋钟按钮事件，提供统一的棋钟切换信号。
/// 用于 GameRoomScreen 等对局页面自动切换计时方。
class ChessClockSwitchService {
  ChessClockSwitchService({
    bool enableUsbButtons = true,
  }) : _usbButtonsEnabled = enableUsbButtons;

  bool _usbButtonsEnabled;

  StreamSubscription<UsbClockButtonEvent>? _usbButtonSub;
  StreamSubscription<UsbClockConnectionState>? _usbConnectionSub;
  final _switchEvents = StreamController<int>.broadcast();
  final _connectionEvents = StreamController<bool>.broadcast();
  ChessClockSide? _lastSide;
  Future<void> _switchQueue = Future<void>.value();
  bool _isConnected = false;
  bool _initialized = false;

  /// 棋钟切换事件流
  ///
  /// 发出的值：1 = 左侧，2 = 右侧
  Stream<int> get switchEvents => _switchEvents.stream;

  /// USB 连接状态流
  ///
  /// true = 已连接，false = 未连接
  Stream<bool> get connectionEvents => _connectionEvents.stream;

  /// 当前是否已连接 USB 棋钟
  bool get isConnected => _isConnected;

  /// 初始化并开始监听 USB 按钮
  void initialize() {
    if (_initialized) return;
    if (!_usbButtonsEnabled) return;
    _initialized = true;

    // 监听连接状态
    _usbConnectionSub =
        UsbClockService.instance.connectionStateEvents.listen((state) {
      final connected = state == UsbClockConnectionState.connected;
      if (_isConnected != connected) {
        _isConnected = connected;
        _connectionEvents.add(connected);
      }
    });

    // 监听按钮事件
    _usbButtonSub = UsbClockService.instance.buttonEvents.listen((event) {
      // 只响应按下事件，忽略释放
      if (!event.pressed) return;

      // 转换为棋钟切换事件
      final side = event.button == UsbClockButton.left
          ? ChessClockSide.left
          : ChessClockSide.right;

      _lastSide = side;
      _switchEvents.add(side.value);
    });
  }

  void enableUsbButtons() {
    if (_usbButtonsEnabled) return;
    _usbButtonsEnabled = true;
    initialize();
  }

  /// 主动切换到指定侧
  ///
  /// 通过 USB HID 发送切换命令到棋钟设备
  Future<bool> switchTo(ChessClockSide side) async {
    if (!_usbButtonsEnabled) return false;

    // 发送切换命令到 USB 设备
    final success = await UsbClockService.instance.setActiveSide(
      side == ChessClockSide.left ? UsbClockButton.left : UsbClockButton.right,
    );

    if (!success) return false;
    _lastSide = side;
    return true;
  }

  /// 切换到对面
  Future<bool> switchToOpposite() {
    final next = _switchQueue.then<bool>((_) => _switchToOppositeLocked());
    _switchQueue = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return next;
  }

  Future<ChessClockSide?> readLastSide() => _readLastSideFromHardware();

  Future<bool> _switchToOppositeLocked() async {
    final lastSide = _lastSide ?? await _readLastSideFromHardware();
    if (lastSide == null) {
      return switchTo(ChessClockSide.right);
    }
    return switchTo(lastSide.opposite);
  }

  Future<ChessClockSide?> _readLastSideFromHardware() async {
    if (!_usbButtonsEnabled) return _lastSide;
    final button = await UsbClockService.instance.getLastButton();
    final side = switch (button) {
      UsbClockButton.left => ChessClockSide.left,
      UsbClockButton.right => ChessClockSide.right,
      null => null,
    };
    if (side != null) {
      _lastSide = side;
      return side;
    }
    return null;
  }

  /// 释放资源
  Future<void> dispose() async {
    await _usbButtonSub?.cancel();
    await _usbConnectionSub?.cancel();
    await _switchEvents.close();
    await _connectionEvents.close();
  }
}
