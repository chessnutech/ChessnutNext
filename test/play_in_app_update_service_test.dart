import 'package:chessnut_flutter_export/services/play_in_app_update_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('checkAvailability parses Play Core availability payload', () async {
    const channel = MethodChannel('test/play_update');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'checkAvailability');
      return {
        'available': true,
        'immediateAllowed': false,
        'flexibleAllowed': true,
        'availableVersionCode': 45,
      };
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final service = PlayInAppUpdateService(
      channel: channel,
      isAndroidProvider: () => true,
    );
    final availability = await service.checkAvailability();

    expect(availability.available, isTrue);
    expect(availability.immediateAllowed, isFalse);
    expect(availability.flexibleAllowed, isTrue);
    expect(availability.availableVersionCode, 45);
    expect(availability.canStart, isTrue);
  });

  test('checkAvailability distinguishes Play Core failures from no update',
      () async {
    const channel = MethodChannel('test/play_update_failed');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'checkAvailability');
      throw PlatformException(code: 'PLAY_UNAVAILABLE');
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final service = PlayInAppUpdateService(
      channel: channel,
      isAndroidProvider: () => true,
    );
    final availability = await service.checkAvailability();

    expect(availability.available, isFalse);
    expect(availability.checkFailed, isTrue);
    expect(availability.canStart, isFalse);
  });

  test('checkAvailability treats available false as a normal no-update state',
      () async {
    const channel = MethodChannel('test/play_update_none');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'checkAvailability');
      return {
        'available': false,
        'immediateAllowed': false,
        'flexibleAllowed': false,
      };
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final service = PlayInAppUpdateService(
      channel: channel,
      isAndroidProvider: () => true,
    );
    final availability = await service.checkAvailability();

    expect(availability.available, isFalse);
    expect(availability.checkFailed, isFalse);
    expect(availability.canStart, isFalse);
  });

  test('startUpdate maps native status strings', () async {
    const channel = MethodChannel('test/play_update_start');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'startUpdate');
      expect(call.arguments, {'immediate': true});
      return 'notAllowed';
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final service = PlayInAppUpdateService(
      channel: channel,
      isAndroidProvider: () => true,
    );
    final result = await service.startUpdate(immediate: true);

    expect(result, PlayInAppUpdateResult.notAllowed);
  });
}
