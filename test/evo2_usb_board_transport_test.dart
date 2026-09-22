import 'package:chessnut_flutter_export/services/evo2_usb_board_transport.dart';
import 'package:chessnut_flutter_export/services/board_settings_service.dart';
import 'package:chessnut_flutter_export/services/physical_board_gateway.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/evo2_board');
  const eventChannel = EventChannel('test/evo2_board/events');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('maps general LED squares to EVO2 native row bytes', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    final transport = Evo2UsbBoardTransport(
      methodChannel: channel,
      eventChannel: eventChannel,
      isAndroid: true,
    );
    final gateway = ChessnutBoardGateway(transport: transport);

    final sent = await gateway.setGeneralLedSquares({'a8', 'h1'});

    expect(sent, isTrue);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'setLedRows');
    final arguments = calls.single.arguments as Map<dynamic, dynamic>;
    expect(
      List<int>.from(arguments['rows'] as Uint8List),
      [0x80, 0, 0, 0, 0, 0, 0, 0x01],
    );

    await gateway.dispose();
    await transport.dispose();
  });

  test('handles realtime FEN command without native write', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    final transport = Evo2UsbBoardTransport(
      methodChannel: channel,
      eventChannel: eventChannel,
      isAndroid: true,
    );
    final gateway = ChessnutBoardGateway(transport: transport);

    final sent = await gateway.enableRealtimeFen();

    expect(sent, isTrue);
    expect(calls, isEmpty);

    await gateway.dispose();
    await transport.dispose();
  });

  test('sends clamped EVO2 LED brightness to native controller', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    final transport = Evo2UsbBoardTransport(
      methodChannel: channel,
      eventChannel: eventChannel,
      isAndroid: true,
    );
    final gateway = ChessnutBoardGateway(transport: transport);

    final sent = await gateway.setEvo2LedBrightness(120);

    expect(sent, isTrue);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'setLedBrightness');
    expect(
      calls.single.arguments,
      containsPair('brightness', 100),
    );

    await gateway.dispose();
    await transport.dispose();
  });

  test('maps EVO2 FEN piece patterns to native pixel payload', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    final transport = Evo2UsbBoardTransport(
      methodChannel: channel,
      eventChannel: eventChannel,
      isAndroid: true,
    );
    final gateway = ChessnutBoardGateway(transport: transport);
    final pawnPattern = Evo2LedPattern(
      colors: [
        0x112233,
        ...List<int>.filled(evo2LedPatternCellCount - 1, 0),
      ],
    );
    final patterns = Evo2LedPatternSet.defaults.copyWithPattern(
      'P',
      pawnPattern,
    );

    final sent = await gateway.setEvo2LedPatternsForFen(
      'P7/8/8/8/8/8/8/8',
      patterns,
    );

    expect(sent, isTrue);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'setLedPatternPixels');
    final arguments = calls.single.arguments as Map<dynamic, dynamic>;
    final pixels = arguments['pixels'] as Uint8List;
    expect(pixels.length, 64 * evo2LedPatternCellCount * 3);
    expect(pixels[0], 0x11);
    expect(pixels[1], 0x22);
    expect(pixels[2], 0x33);

    await gateway.dispose();
    await transport.dispose();
  });

  test('maps EVO2 sparse pattern keys with blank-square pattern', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    final transport = Evo2UsbBoardTransport(
      methodChannel: channel,
      eventChannel: eventChannel,
      isAndroid: true,
    );
    final gateway = ChessnutBoardGateway(transport: transport);
    final blankPattern = Evo2LedPattern(
      colors: [
        0x445566,
        ...List<int>.filled(evo2LedPatternCellCount - 1, 0),
      ],
    );
    final patterns = Evo2LedPatternSet.defaults.copyWithPattern(
      'empty',
      blankPattern,
    );
    final keys = List<String?>.filled(64, null);
    keys[0] = 'empty';
    keys[1] = null;

    final sent = await gateway.setEvo2LedPatternKeys(keys, patterns);

    expect(sent, isTrue);
    expect(calls, hasLength(1));
    final arguments = calls.single.arguments as Map<dynamic, dynamic>;
    final pixels = arguments['pixels'] as Uint8List;
    expect(pixels[0], 0x44);
    expect(pixels[1], 0x55);
    expect(pixels[2], 0x66);
    expect(pixels[evo2LedPatternCellCount * 3], 0);
    expect(pixels[evo2LedPatternCellCount * 3 + 1], 0);
    expect(pixels[evo2LedPatternCellCount * 3 + 2], 0);

    await gateway.dispose();
    await transport.dispose();
  });
}
