import 'package:chessnut_flutter_export/services/screen_wake_lock_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only active chess routes keep the screen awake', () {
    for (final route in const {
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
    }) {
      expect(shouldKeepScreenAwakeForRoute(route), isTrue, reason: route);
    }

    for (final route in const {
      'Splash',
      'Auth',
      'Home',
      'Setup',
      'Bot',
      'Online',
      'OtbSetup',
      'Settings',
    }) {
      expect(shouldKeepScreenAwakeForRoute(route), isFalse, reason: route);
    }
  });

  testWidgets('wake lock follows scope state and releases on dispose',
      (tester) async {
    final service = _RecordingScreenWakeLockService();

    await tester.pumpWidget(
      ScreenWakeLockScope(
        enabled: false,
        service: service,
        child: const SizedBox(),
      ),
    );
    expect(service.values, [false]);

    await tester.pumpWidget(
      ScreenWakeLockScope(
        enabled: true,
        service: service,
        child: const SizedBox(),
      ),
    );
    expect(service.values, [false, true]);

    await tester.pumpWidget(const SizedBox());
    expect(service.values, [false, true, false]);
  });

  testWidgets('wake lock releases after 30 minutes without FEN activity',
      (tester) async {
    final service = _RecordingScreenWakeLockService();
    var idleTimeoutCount = 0;

    await tester.pumpWidget(
      ScreenWakeLockScope(
        enabled: true,
        service: service,
        onIdleTimeout: () => idleTimeoutCount += 1,
        child: const SizedBox(),
      ),
    );
    expect(service.values, [true]);

    await tester.pump(const Duration(minutes: 29));
    expect(service.values, [true]);
    await tester.pump(const Duration(minutes: 1));
    expect(service.values, [true, false]);
    expect(idleTimeoutCount, 1);
  });

  testWidgets('manual screen off pauses the display idle timer',
      (tester) async {
    final service = _RecordingScreenWakeLockService();
    var idleTimeoutCount = 0;

    await tester.pumpWidget(
      ScreenWakeLockScope(
        enabled: true,
        service: service,
        onIdleTimeout: () => idleTimeoutCount += 1,
        child: const SizedBox(),
      ),
    );
    await tester.pump(const Duration(minutes: 20));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 20));
    expect(service.values, [true]);
    expect(idleTimeoutCount, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(minutes: 29));
    expect(service.values, [true]);
    await tester.pump(const Duration(minutes: 1));
    expect(service.values, [true, false]);
    expect(idleTimeoutCount, 1);
  });

  testWidgets('physical FEN activity token restarts the idle timer',
      (tester) async {
    final service = _RecordingScreenWakeLockService();
    var activityToken = 0;

    Widget buildScope() => ScreenWakeLockScope(
          enabled: true,
          service: service,
          activityToken: activityToken,
          child: const SizedBox(),
        );

    await tester.pumpWidget(buildScope());
    await tester.pump(const Duration(minutes: 20));
    activityToken += 1;
    await tester.pumpWidget(buildScope());
    await tester.pump(const Duration(minutes: 20));
    expect(service.values, [true]);
    await tester.pump(const Duration(minutes: 10));
    expect(service.values, [true, false]);
  });

  testWidgets('virtual board FEN notification restarts the idle timer',
      (tester) async {
    final service = _RecordingScreenWakeLockService();
    var fen = '8/8/8/8/8/8/8/8 w - - 0 1';

    Widget buildScope() => ScreenWakeLockScope(
          enabled: true,
          service: service,
          child: ScreenWakeFenActivityReporter(
            fen: fen,
            child: const SizedBox(),
          ),
        );

    await tester.pumpWidget(buildScope());
    await tester.pump();
    await tester.pump(const Duration(minutes: 20));
    fen = '8/8/8/8/8/8/4P3/8 b - - 0 1';
    await tester.pumpWidget(buildScope());
    await tester.pump();
    await tester.pump(const Duration(minutes: 20));
    expect(service.values, [true]);
    await tester.pump(const Duration(minutes: 10));
    expect(service.values, [true, false]);
  });

  testWidgets('FEN changes after idle timeout do not restore wake lock',
      (tester) async {
    final service = _RecordingScreenWakeLockService();
    var activityToken = 0;

    Widget buildScope() => ScreenWakeLockScope(
          enabled: true,
          service: service,
          activityToken: activityToken,
          child: const SizedBox(),
        );

    await tester.pumpWidget(buildScope());
    await tester.pump(const Duration(minutes: 30));
    expect(service.values, [true, false]);

    activityToken += 1;
    await tester.pumpWidget(buildScope());
    expect(service.values, [true, false]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(service.values, [true, false, true]);
  });
}

class _RecordingScreenWakeLockService implements ScreenWakeLockService {
  final List<bool> values = [];

  @override
  Future<void> setEnabled(bool enabled) async {
    values.add(enabled);
  }
}
