import 'package:chessnut_flutter_export/services/windows_display_power_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('test/windows_display_power');
  const eventChannel = EventChannel('test/windows_display_power/events');
  const service = MethodChannelWindowsDisplayPowerService(
    methodChannel: methodChannel,
    eventChannel: eventChannel,
  );

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(eventChannel.name, null);
  });

  test('reads the current Windows display power state', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      expect(call.method, 'isDisplayOff');
      return true;
    });

    expect(await service.isDisplayOff(), isTrue);
  });

  test('only enables the native listener on Windows', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(service.isSupported, isTrue);
  });

  test('defaults to display on when the Windows channel is unavailable',
      () async {
    expect(await service.isDisplayOff(), isFalse);
  });
}
