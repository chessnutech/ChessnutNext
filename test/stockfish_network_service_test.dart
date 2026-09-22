import 'dart:io';

import 'package:chessnut_flutter_export/services/stockfish_network_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('chessnut/stockfish_networks');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    MethodChannelStockfishNetworkService.clearCacheForTest();
  });

  test('Android network service returns absolute NNUE paths and caches them',
      () async {
    var calls = 0;
    final root = Directory.systemTemp.absolute.path;
    final separator = Platform.pathSeparator;
    final big = '$root${separator}nn-c288c895ea92.nnue';
    final small = '$root${separator}nn-37f18f62d772.nnue';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'prepare');
      calls += 1;
      return <String, String>{
        'big': big,
        'small': small,
      };
    });

    const service = MethodChannelStockfishNetworkService(
      forceAndroidForTest: true,
    );
    final first = await service.prepare();
    final second = await service.prepare();

    expect(first, isNotNull);
    expect(first!.bigPath, big);
    expect(first.smallPath, small);
    expect(second, same(first));
    expect(calls, 1);
  });

  test('Stockfish network commands precede engine profile options', () {
    const paths = StockfishNetworkPaths(
      bigPath: r'C:\engine\nn-c288c895ea92.nnue',
      smallPath: r'C:\engine\nn-37f18f62d772.nnue',
    );

    final commands = stockfishStartupCommands(
      const ['setoption name MultiPV value 1'],
      paths,
    );

    expect(commands, [
      r'setoption name EvalFile value C:\engine\nn-c288c895ea92.nnue',
      r'setoption name EvalFileSmall value C:\engine\nn-37f18f62d772.nnue',
      'setoption name MultiPV value 1',
    ]);
  });

  test('non-Android platforms keep embedded Stockfish startup unchanged',
      () async {
    const service = MethodChannelStockfishNetworkService();

    expect(await service.prepare(), isNull);
    expect(
      stockfishStartupCommands(
        const ['setoption name MultiPV value 1'],
        null,
      ),
      const ['setoption name MultiPV value 1'],
    );
  });
}
