import 'package:flutter/services.dart';

import '../models/app_models.dart';

abstract class BoardBackgroundConnectionService {
  Future<void> setKeepAlive({
    required bool enabled,
    required bool connected,
    required ChessnutBoardModel boardModel,
  });

  Future<void> disconnectBoardHardware();
}

class MethodChannelBoardBackgroundConnectionService
    implements BoardBackgroundConnectionService {
  const MethodChannelBoardBackgroundConnectionService();

  static const MethodChannel _channel =
      MethodChannel('chessnut/board_background_connection');

  @override
  Future<void> setKeepAlive({
    required bool enabled,
    required bool connected,
    required ChessnutBoardModel boardModel,
  }) async {
    try {
      await _channel.invokeMethod<void>('setKeepAlive', {
        'enabled': enabled,
        'connected': connected,
        'boardName': boardModel.displayName,
      });
    } on MissingPluginException {
      // Non-mobile platforms do not need a native keepalive service.
    }
  }

  @override
  Future<void> disconnectBoardHardware() async {
    try {
      await _channel.invokeMethod<void>('disconnectBoardHardware');
    } on MissingPluginException {
      // Non-mobile platforms do not own Android BluetoothGatt handles.
    }
  }
}
