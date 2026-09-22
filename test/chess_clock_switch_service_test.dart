import 'package:chessnut_flutter_export/services/chess_clock_switch_service.dart';
import 'package:chessnut_flutter_export/services/usb_clock_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('chessnut/clock_hid');
  const eventChannel = MethodChannel('chessnut/clock_hid/events');

  tearDown(() {
    UsbClockService.instance.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(eventChannel, null);
  });

  test('switchToOpposite uses the hardware last side on the first switch',
      () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'getLastButton' => 'RIGHT',
        'setActiveSide' => true,
        _ => null,
      };
    });

    final service = ChessClockSwitchService();
    await service.switchToOpposite();
    await service.dispose();

    expect(
      calls.map((call) => call.method),
      ['getLastButton', 'setActiveSide'],
    );
    expect(calls.last.arguments, {'side': 'LEFT'});
  });

  test('switchToOpposite keeps its own side after a successful switch',
      () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'getLastButton' => 'RIGHT',
        'setActiveSide' => true,
        _ => null,
      };
    });

    final service = ChessClockSwitchService();
    await service.switchToOpposite();
    await service.switchToOpposite();
    await service.dispose();

    expect(
      calls.map((call) => call.method),
      ['getLastButton', 'setActiveSide', 'setActiveSide'],
    );
    expect(calls[1].arguments, {'side': 'LEFT'});
    expect(calls[2].arguments, {'side': 'RIGHT'});
  });

  test('switchEvents forwards hardware button events after initialization',
      () async {
    final eventChannelCalls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(eventChannel, (call) async {
      eventChannelCalls.add(call.method);
      return null;
    });

    final service = ChessClockSwitchService();
    final events = <int>[];
    final sub = service.switchEvents.listen(events.add);

    service.initialize();
    service.initialize();
    await pumpEventQueue();

    await _emitUsbClockEvent(const {
      'type': 'button',
      'button': 'LEFT',
      'pressed': true,
      'timestamp': 1,
    });
    await _emitUsbClockEvent(const {
      'type': 'button',
      'button': 'RIGHT',
      'pressed': true,
      'timestamp': 2,
    });

    await sub.cancel();
    await service.dispose();

    expect(
      eventChannelCalls.where((method) => method == 'listen'),
      hasLength(1),
    );
    expect(events, [ChessClockSide.left.value, ChessClockSide.right.value]);
  });

  test('disabled service starts listening when USB buttons are enabled later',
      () async {
    final eventChannelCalls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(eventChannel, (call) async {
      eventChannelCalls.add(call.method);
      return null;
    });

    final service = ChessClockSwitchService(enableUsbButtons: false);
    final events = <int>[];
    final sub = service.switchEvents.listen(events.add);

    service.initialize();
    await pumpEventQueue();
    expect(eventChannelCalls, isEmpty);

    service.enableUsbButtons();
    service.enableUsbButtons();
    await pumpEventQueue();

    await _emitUsbClockEvent(const {
      'type': 'button',
      'button': 'LEFT',
      'pressed': true,
      'timestamp': 1,
    });

    await sub.cancel();
    await service.dispose();

    expect(
      eventChannelCalls.where((method) => method == 'listen'),
      hasLength(1),
    );
    expect(events, [ChessClockSide.left.value]);
  });
}

Future<void> _emitUsbClockEvent(Map<String, Object?> event) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    'chessnut/clock_hid/events',
    const StandardMethodCodec().encodeSuccessEnvelope(event),
    (_) {},
  );
  await pumpEventQueue();
}
