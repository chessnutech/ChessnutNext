import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum Evo2ScreenPowerEvent { screenOff, unlocked }

abstract interface class Evo2UsbPowerService {
  Stream<Evo2ScreenPowerEvent> get screenStateChanges;

  Future<bool> isScreenOff();

  Future<bool> setUsbPower(bool enabled);

  Future<bool> setScreenOffPolicy({
    required bool enabled,
    required bool gameActive,
  });
}

class MethodChannelEvo2UsbPowerService implements Evo2UsbPowerService {
  const MethodChannelEvo2UsbPowerService({
    MethodChannel methodChannel = const MethodChannel('chessnut/evo2_power'),
    EventChannel eventChannel =
        const EventChannel('chessnut/evo2_power/events'),
  })  : _methodChannel = methodChannel,
        _eventChannel = eventChannel;

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  bool get _isSupported => !kIsWeb && Platform.isAndroid;

  @override
  Stream<Evo2ScreenPowerEvent> get screenStateChanges {
    if (!_isSupported) return const Stream.empty();
    return _eventChannel
        .receiveBroadcastStream()
        .where((event) => event is Map)
        .cast<Map>()
        .map(
      (event) {
        return event['screenOff'] == true
            ? Evo2ScreenPowerEvent.screenOff
            : Evo2ScreenPowerEvent.unlocked;
      },
    );
  }

  @override
  Future<bool> isScreenOff() => _invokeBool('isScreenOff');

  @override
  Future<bool> setUsbPower(bool enabled) {
    return _invokeBool('setUsbPower', {'enabled': enabled});
  }

  @override
  Future<bool> setScreenOffPolicy({
    required bool enabled,
    required bool gameActive,
  }) {
    return _invokeBool('setScreenOffPolicy', {
      'enabled': enabled,
      'gameActive': gameActive,
    });
  }

  Future<bool> _invokeBool(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    if (!_isSupported) return false;
    try {
      return await _methodChannel.invokeMethod<bool>(method, arguments) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      debugPrint('Unable to control EVO2 USB power: $error');
      return false;
    }
  }
}

class Evo2ScreenOffGameController {
  Evo2ScreenOffGameController({
    required this.powerService,
    required this.clearLeds,
    required this.onPowerSuspendedChanged,
    required this.onPowerRestored,
    required this.onGameLedsShouldRefresh,
    this.idleDelay = const Duration(minutes: 30),
  });

  final Evo2UsbPowerService powerService;
  final Future<void> Function() clearLeds;
  final ValueChanged<bool> onPowerSuspendedChanged;
  final FutureOr<void> Function() onPowerRestored;
  final FutureOr<void> Function() onGameLedsShouldRefresh;
  final Duration idleDelay;

  StreamSubscription<Evo2ScreenPowerEvent>? _screenStateSub;
  Timer? _idleTimer;
  bool _screenOff = false;
  bool _enabled = false;
  bool _gameActive = false;
  bool _powerSuspended = false;
  bool _stoppedForIdle = false;
  String? _lastBoardFen;

  bool get screenOff => _screenOff;
  bool get enabled => _enabled;
  bool get gameActive => _gameActive;
  bool get powerSuspended => _powerSuspended;

  Future<void> start() async {
    await _screenStateSub?.cancel();
    _screenStateSub = powerService.screenStateChanges.listen(
      (event) => unawaited(_handleScreenState(event)),
      onError: (_) {},
    );
    await _syncNativePolicy();
    if (await powerService.isScreenOff()) {
      await _handleScreenState(Evo2ScreenPowerEvent.screenOff);
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (_enabled == enabled) return;
    _enabled = enabled;
    if (!_screenOff) {
      await _syncNativePolicy();
      return;
    }
    if (!enabled) {
      await _stopLockedSession(clearLights: _gameActive);
      return;
    }
    if (_gameActive && !_stoppedForIdle) {
      _setPowerSuspended(false);
      if (await _syncNativePolicy()) {
        _restartIdleTimer();
        await onGameLedsShouldRefresh();
      }
    }
  }

  Future<void> setGameActive(bool active) async {
    if (_gameActive == active) return;
    _gameActive = active;
    if (!_screenOff) {
      await _syncNativePolicy();
      return;
    }
    if (!active) {
      await _stopLockedSession(clearLights: true);
      return;
    }
    if (!_enabled || _stoppedForIdle) return;
    _setPowerSuspended(false);
    if (await _syncNativePolicy()) {
      _restartIdleTimer();
      await onGameLedsShouldRefresh();
    }
  }

  void handleBoardFen(String fen) {
    final boardFen = fen.trim().split(RegExp(r'\s+')).first;
    if (boardFen.isEmpty || boardFen == _lastBoardFen) return;
    _lastBoardFen = boardFen;
    if (_screenOff && _enabled && _gameActive && !_stoppedForIdle) {
      _restartIdleTimer();
    }
  }

  void handleDisplayIdleTimeout() {
    _stoppedForIdle = true;
    _lastBoardFen = null;
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  Future<void> restoreOnAppResume() async {
    if (await powerService.isScreenOff()) return;
    await _handleScreenState(Evo2ScreenPowerEvent.unlocked);
  }

  Future<void> dispose() async {
    _idleTimer?.cancel();
    _idleTimer = null;
    await _screenStateSub?.cancel();
    _screenStateSub = null;
  }

  Future<void> _handleScreenState(Evo2ScreenPowerEvent event) async {
    switch (event) {
      case Evo2ScreenPowerEvent.screenOff:
        if (_screenOff) return;
        _screenOff = true;
        _lastBoardFen = null;
        if (_stoppedForIdle) {
          await _stopLockedSession(clearLights: true, powerOffNow: true);
          return;
        }
        if (_enabled && _gameActive) {
          _setPowerSuspended(false);
          if (await _syncNativePolicy()) {
            _restartIdleTimer();
            await onGameLedsShouldRefresh();
          }
        } else {
          await _stopLockedSession(clearLights: true);
        }
      case Evo2ScreenPowerEvent.unlocked:
        _screenOff = false;
        _stoppedForIdle = false;
        _lastBoardFen = null;
        _idleTimer?.cancel();
        _idleTimer = null;
        await powerService.setUsbPower(true);
        _setPowerSuspended(false);
        await _syncNativePolicy();
        await onPowerRestored();
    }
  }

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleDelay, () {
      _stoppedForIdle = true;
      unawaited(_stopLockedSession(clearLights: true));
    });
  }

  Future<void> _stopLockedSession({
    required bool clearLights,
    bool powerOffNow = false,
  }) async {
    _idleTimer?.cancel();
    _idleTimer = null;
    if (_powerSuspended) {
      await _syncNativePolicy(forceInactive: true);
      if (powerOffNow) await powerService.setUsbPower(false);
      return;
    }
    _setPowerSuspended(true);
    if (clearLights) {
      await clearLeds();
    }
    await _syncNativePolicy(forceInactive: true);
    if (powerOffNow) await powerService.setUsbPower(false);
  }

  Future<bool> _syncNativePolicy({bool forceInactive = false}) {
    return powerService.setScreenOffPolicy(
      enabled: !forceInactive && _enabled,
      gameActive: !forceInactive && _gameActive,
    );
  }

  void _setPowerSuspended(bool suspended) {
    if (_powerSuspended == suspended) return;
    _powerSuspended = suspended;
    onPowerSuspendedChanged(suspended);
  }
}
