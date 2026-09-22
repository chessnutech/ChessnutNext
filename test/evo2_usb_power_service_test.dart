import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:chessnut_flutter_export/services/evo2_usb_power_service.dart';

void main() {
  testWidgets(
    'EVO2 screen-off game powers down after 30 minutes without board changes',
    (tester) async {
      final power = _FakeEvo2UsbPowerService();
      var clearCount = 0;
      final suspended = <bool>[];
      final controller = Evo2ScreenOffGameController(
        powerService: power,
        clearLeds: () async => clearCount += 1,
        onPowerSuspendedChanged: suspended.add,
        onPowerRestored: () {},
        onGameLedsShouldRefresh: () {},
      );
      addTearDown(controller.dispose);
      addTearDown(power.dispose);

      await controller.setEnabled(true);
      await controller.start();
      await controller.setGameActive(true);
      power.emit(Evo2ScreenPowerEvent.screenOff);
      await tester.pump();

      controller.handleBoardFen('8/8/8/8/8/8/8/8');
      await tester.pump(const Duration(minutes: 29, seconds: 59));
      controller.handleBoardFen('8/8/8/8/8/8/8/K7');
      await tester.pump(const Duration(seconds: 1));

      expect(clearCount, 0);
      expect(controller.powerSuspended, isFalse);

      await tester.pump(const Duration(minutes: 30));
      await tester.pump();

      expect(clearCount, 1);
      expect(controller.powerSuspended, isTrue);
      expect(suspended, [true]);
      expect(power.policyRequests.last.enabled, isFalse);
      expect(power.policyRequests.last.gameActive, isFalse);
    },
  );

  testWidgets('EVO2 game end clears LEDs before locked USB power is disabled',
      (tester) async {
    final power = _FakeEvo2UsbPowerService();
    final actions = <String>[];
    final controller = Evo2ScreenOffGameController(
      powerService: power,
      clearLeds: () async => actions.add('clear'),
      onPowerSuspendedChanged: (suspended) {
        if (suspended) actions.add('suspend');
      },
      onPowerRestored: () => actions.add('restore'),
      onGameLedsShouldRefresh: () => actions.add('refresh'),
    );
    addTearDown(controller.dispose);
    addTearDown(power.dispose);

    await controller.setEnabled(true);
    await controller.start();
    await controller.setGameActive(true);
    power.emit(Evo2ScreenPowerEvent.screenOff);
    await tester.pump();
    actions.clear();
    power.onSetPolicy = (enabled, gameActive) {
      if (!enabled || !gameActive) actions.add('powerOff');
    };

    await controller.setGameActive(false);

    expect(actions, ['suspend', 'clear', 'powerOff']);

    power.screenOff = false;
    power.emit(Evo2ScreenPowerEvent.unlocked);
    await tester.pump();

    expect(power.usbPowerRequests.last, isTrue);
    expect(controller.powerSuspended, isFalse);
    expect(actions.last, 'restore');
  });

  testWidgets('disabled screen-off play clears LEDs and suspends interaction',
      (tester) async {
    final power = _FakeEvo2UsbPowerService();
    var clearCount = 0;
    final controller = Evo2ScreenOffGameController(
      powerService: power,
      clearLeds: () async => clearCount += 1,
      onPowerSuspendedChanged: (_) {},
      onPowerRestored: () {},
      onGameLedsShouldRefresh: () {},
    );
    addTearDown(controller.dispose);
    addTearDown(power.dispose);

    await controller.start();
    await controller.setEnabled(false);
    await controller.setGameActive(true);
    power.emit(Evo2ScreenPowerEvent.screenOff);
    await tester.pump();

    expect(controller.powerSuspended, isTrue);
    expect(power.policyRequests.last.enabled, isFalse);
    expect(power.policyRequests.last.gameActive, isFalse);
    expect(clearCount, 1);
  });

  testWidgets('enabled EVO2 locked game keeps power and refreshes LEDs',
      (tester) async {
    final power = _FakeEvo2UsbPowerService();
    var refreshCount = 0;
    final controller = Evo2ScreenOffGameController(
      powerService: power,
      clearLeds: () async {},
      onPowerSuspendedChanged: (_) {},
      onPowerRestored: () {},
      onGameLedsShouldRefresh: () => refreshCount += 1,
    );
    addTearDown(controller.dispose);
    addTearDown(power.dispose);

    await controller.setEnabled(true);
    await controller.start();
    await controller.setGameActive(true);
    power.emit(Evo2ScreenPowerEvent.screenOff);
    await tester.pump();

    expect(power.policyRequests.last.enabled, isTrue);
    expect(power.policyRequests.last.gameActive, isTrue);
    expect(controller.powerSuspended, isFalse);
    expect(refreshCount, 1);
    await controller.setGameActive(false);
  });

  testWidgets('display idle timeout powers EVO2 off when the screen turns off',
      (tester) async {
    final power = _FakeEvo2UsbPowerService();
    var clearCount = 0;
    var refreshCount = 0;
    final controller = Evo2ScreenOffGameController(
      powerService: power,
      clearLeds: () async => clearCount += 1,
      onPowerSuspendedChanged: (_) {},
      onPowerRestored: () {},
      onGameLedsShouldRefresh: () => refreshCount += 1,
    );
    addTearDown(controller.dispose);
    addTearDown(power.dispose);

    await controller.setEnabled(true);
    await controller.start();
    await controller.setGameActive(true);
    controller.handleDisplayIdleTimeout();

    expect(clearCount, 0);
    expect(power.usbPowerRequests, isEmpty);

    power.emit(Evo2ScreenPowerEvent.screenOff);
    await tester.pump();

    expect(clearCount, 1);
    expect(refreshCount, 0);
    expect(controller.powerSuspended, isTrue);
    expect(power.policyRequests.last.enabled, isFalse);
    expect(power.policyRequests.last.gameActive, isFalse);
    expect(power.usbPowerRequests.last, isFalse);

    power.emit(Evo2ScreenPowerEvent.unlocked);
    await tester.pump();

    expect(power.usbPowerRequests.last, isTrue);
    expect(controller.powerSuspended, isFalse);
  });
}

class _FakeEvo2UsbPowerService implements Evo2UsbPowerService {
  final _events = StreamController<Evo2ScreenPowerEvent>.broadcast(sync: true);
  final policyRequests = <_Evo2PolicyRequest>[];
  final usbPowerRequests = <bool>[];
  bool screenOff = false;
  void Function(bool enabled, bool gameActive)? onSetPolicy;

  @override
  Stream<Evo2ScreenPowerEvent> get screenStateChanges => _events.stream;

  void emit(Evo2ScreenPowerEvent event) {
    screenOff = event == Evo2ScreenPowerEvent.screenOff;
    _events.add(event);
  }

  @override
  Future<bool> isScreenOff() async => screenOff;

  @override
  Future<bool> setScreenOffPolicy({
    required bool enabled,
    required bool gameActive,
  }) async {
    policyRequests.add(_Evo2PolicyRequest(enabled, gameActive));
    onSetPolicy?.call(enabled, gameActive);
    return true;
  }

  @override
  Future<bool> setUsbPower(bool enabled) async {
    usbPowerRequests.add(enabled);
    return true;
  }

  Future<void> dispose() => _events.close();
}

class _Evo2PolicyRequest {
  const _Evo2PolicyRequest(this.enabled, this.gameActive);

  final bool enabled;
  final bool gameActive;
}
