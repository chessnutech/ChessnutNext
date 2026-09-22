import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const Set<String> screenAwakeRouteLabels = {
  'Play',
  'ChessCom',
  'Clock',
  'Spectator',
  'BoardAnalyzer',
  'Courses',
  'PuzzleStorm',
  'PuzzleThemes',
  'MistakeBook',
  'Analysis',
};

bool shouldKeepScreenAwakeForRoute(String routeLabel) =>
    screenAwakeRouteLabels.contains(routeLabel);

abstract interface class ScreenWakeLockService {
  Future<void> setEnabled(bool enabled);
}

class SystemScreenWakeLockService implements ScreenWakeLockService {
  const SystemScreenWakeLockService();

  @override
  Future<void> setEnabled(bool enabled) async {
    try {
      await WakelockPlus.toggle(enable: enabled);
    } on MissingPluginException {
      // Unit tests and unsupported embedders do not provide the plugin.
    } on PlatformException {
      // Leave the platform's normal screen timeout in place if toggling fails.
    } on UnsupportedError {
      // Keep the normal screen timeout on unsupported platforms.
    }
  }
}

class ScreenWakeLockScope extends StatefulWidget {
  const ScreenWakeLockScope({
    required this.enabled,
    required this.service,
    required this.child,
    this.activityToken = 0,
    this.sessionKey,
    this.idleTimeout = const Duration(minutes: 30),
    this.onIdleTimeout,
    super.key,
  });

  final bool enabled;
  final ScreenWakeLockService service;
  final Widget child;
  final Object activityToken;
  final Object? sessionKey;
  final Duration idleTimeout;
  final VoidCallback? onIdleTimeout;

  @override
  State<ScreenWakeLockScope> createState() => _ScreenWakeLockScopeState();
}

class _ScreenWakeLockScopeState extends State<ScreenWakeLockScope>
    with WidgetsBindingObserver {
  bool? _appliedEnabled;
  Timer? _idleTimer;
  bool _idleTimedOut = false;
  AppLifecycleState? _lifecycleState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycleState = WidgetsBinding.instance.lifecycleState;
    _startWakeSession();
  }

  @override
  void didUpdateWidget(covariant ScreenWakeLockScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    final serviceChanged = !identical(oldWidget.service, widget.service);
    if (serviceChanged) {
      if (_appliedEnabled == true) {
        unawaited(oldWidget.service.setEnabled(false));
      }
      _appliedEnabled = null;
    }
    if (!widget.enabled) {
      _stopWakeSession();
      return;
    }
    if (serviceChanged ||
        !oldWidget.enabled ||
        oldWidget.sessionKey != widget.sessionKey) {
      _startWakeSession();
      return;
    }
    if (oldWidget.activityToken != widget.activityToken) {
      _recordFenActivity();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasResumed = _lifecycleState == AppLifecycleState.resumed;
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed && !wasResumed && widget.enabled) {
      _startWakeSession();
    } else if (state != AppLifecycleState.resumed) {
      _idleTimer?.cancel();
      _idleTimer = null;
    }
  }

  void _startWakeSession() {
    if (!widget.enabled) {
      _stopWakeSession();
      return;
    }
    _idleTimedOut = false;
    _setWakeLockEnabled(true);
    _restartIdleTimer();
  }

  void _stopWakeSession() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _idleTimedOut = false;
    _setWakeLockEnabled(false);
  }

  void _recordFenActivity() {
    if (!widget.enabled || _idleTimedOut) return;
    _restartIdleTimer();
  }

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(widget.idleTimeout, _handleIdleTimeout);
  }

  void _handleIdleTimeout() {
    _idleTimer = null;
    if (!mounted || !widget.enabled) return;
    _idleTimedOut = true;
    widget.onIdleTimeout?.call();
    _setWakeLockEnabled(false);
  }

  void _setWakeLockEnabled(bool enabled) {
    if (_appliedEnabled == enabled) return;
    _appliedEnabled = enabled;
    unawaited(widget.service.setEnabled(enabled));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    if (_appliedEnabled == true) {
      unawaited(widget.service.setEnabled(false));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScreenWakeFenActivityNotification>(
      onNotification: (notification) {
        _recordFenActivity();
        return false;
      },
      child: widget.child,
    );
  }
}

class ScreenWakeFenActivityNotification extends Notification {
  const ScreenWakeFenActivityNotification();
}

class ScreenWakeFenActivityReporter extends StatefulWidget {
  const ScreenWakeFenActivityReporter({
    required this.fen,
    required this.child,
    super.key,
  });

  final String fen;
  final Widget child;

  @override
  State<ScreenWakeFenActivityReporter> createState() =>
      _ScreenWakeFenActivityReporterState();
}

class _ScreenWakeFenActivityReporterState
    extends State<ScreenWakeFenActivityReporter> {
  @override
  void initState() {
    super.initState();
    _reportAfterFrame(widget.fen);
  }

  @override
  void didUpdateWidget(covariant ScreenWakeFenActivityReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_boardOnlyFen(oldWidget.fen) != _boardOnlyFen(widget.fen)) {
      _reportAfterFrame(widget.fen);
    }
  }

  void _reportAfterFrame(String fen) {
    final normalizedFen = _boardOnlyFen(fen);
    if (normalizedFen.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _boardOnlyFen(widget.fen) != normalizedFen) return;
      const ScreenWakeFenActivityNotification().dispatch(context);
    });
  }

  String _boardOnlyFen(String fen) => fen.trim().split(RegExp(r'\s+')).first;

  @override
  Widget build(BuildContext context) => widget.child;
}
