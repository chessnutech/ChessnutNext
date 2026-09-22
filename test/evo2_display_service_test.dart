import 'package:chessnut_flutter_export/services/evo2_display_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/evo2_display');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('maps EVO2 screen orientation to native channel value', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      received = call;
      return true;
    });
    const service = MethodChannelEvo2DisplayService(
      channel: channel,
      isAndroid: true,
    );

    final applied = await service.setScreenOrientation(
      Evo2ScreenOrientation.rotation180,
    );

    expect(applied, isTrue);
    expect(received?.method, 'setScreenOrientation');
    expect(
      received?.arguments,
      containsPair('orientation', 'rotation180'),
    );
  });
}
