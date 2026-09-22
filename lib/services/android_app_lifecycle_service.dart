import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AndroidAppLifecycleService {
  const AndroidAppLifecycleService._();

  static const MethodChannel _channel = MethodChannel(
    'chessnut/app_lifecycle',
  );

  static Future<bool> moveToBackground() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('moveToBackground') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
