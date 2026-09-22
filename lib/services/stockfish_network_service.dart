import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class StockfishNetworkPaths {
  const StockfishNetworkPaths({
    required this.bigPath,
    required this.smallPath,
  });

  final String bigPath;
  final String smallPath;
}

abstract class StockfishNetworkService {
  Future<StockfishNetworkPaths?> prepare();
}

class MethodChannelStockfishNetworkService implements StockfishNetworkService {
  const MethodChannelStockfishNetworkService({
    bool forceAndroidForTest = false,
  }) : _forceAndroidForTest = forceAndroidForTest;

  static const MethodChannel _channel =
      MethodChannel('chessnut/stockfish_networks');

  static Future<StockfishNetworkPaths?>? _cachedPrepare;

  final bool _forceAndroidForTest;

  @override
  Future<StockfishNetworkPaths?> prepare() async {
    if (!_isAndroid) return null;
    return _cachedPrepare ??= _prepare();
  }

  static void clearCacheForTest() {
    _cachedPrepare = null;
  }

  bool get _isAndroid =>
      _forceAndroidForTest || (!kIsWeb && Platform.isAndroid);

  Future<StockfishNetworkPaths?> _prepare() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('prepare');
      final big = result?['big']?.toString();
      final small = result?['small']?.toString();
      if (big == null || big.isEmpty || small == null || small.isEmpty) {
        return null;
      }
      return StockfishNetworkPaths(bigPath: big, smallPath: small);
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }
}

List<String> stockfishStartupCommands(
  List<String> profileCommands,
  StockfishNetworkPaths? paths,
) {
  if (paths == null) return profileCommands;
  return [
    'setoption name EvalFile value ${paths.bigPath}',
    'setoption name EvalFileSmall value ${paths.smallPath}',
    for (final command in profileCommands)
      if (!command.startsWith('setoption name EvalFile value ') &&
          !command.startsWith('setoption name EvalFileSmall value '))
        command,
  ];
}
