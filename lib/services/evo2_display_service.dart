import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum Evo2ScreenOrientation {
  rotation0,
  rotation90,
  rotation180,
  rotation270;

  String get storageKey => name;

  String get label => switch (this) {
        Evo2ScreenOrientation.rotation0 => '0°',
        Evo2ScreenOrientation.rotation90 => '90°',
        Evo2ScreenOrientation.rotation180 => '180°',
        Evo2ScreenOrientation.rotation270 => '270°',
      };

  static Evo2ScreenOrientation fromStorage(Object? value) {
    final key = value?.toString();
    return Evo2ScreenOrientation.values.firstWhere(
      (orientation) => orientation.storageKey == key,
      orElse: () => Evo2ScreenOrientation.rotation0,
    );
  }
}

abstract interface class Evo2DisplayService {
  Future<bool> setScreenOrientation(Evo2ScreenOrientation orientation);
}

class MethodChannelEvo2DisplayService implements Evo2DisplayService {
  const MethodChannelEvo2DisplayService({
    MethodChannel channel = const MethodChannel('chessnut/evo2_display'),
    bool? isAndroid,
  })  : _channel = channel,
        _isAndroid = isAndroid;

  final MethodChannel _channel;
  final bool? _isAndroid;

  @override
  Future<bool> setScreenOrientation(
    Evo2ScreenOrientation orientation,
  ) async {
    if (kIsWeb || !(_isAndroid ?? Platform.isAndroid)) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'setScreenOrientation',
            {'orientation': orientation.storageKey},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
