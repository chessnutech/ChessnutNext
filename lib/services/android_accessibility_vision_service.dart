import 'package:flutter/services.dart';

abstract class AccessibilityVisionBridge {
  Future<void> setRecognitionStatus({
    required bool enabled,
    required bool recognizing,
    required bool boardConnected,
    required String languageTag,
  });

  Future<bool> isAccessibilityRunning();

  Future<void> openAccessibilitySettings();

  Future<String?> recognizeScreenshot();

  Future<bool> dispatchMoveGesture({
    required Rect from,
    Rect? to,
  });
}

class AccessibilityVisionException implements Exception {
  const AccessibilityVisionException(this.code);

  final String code;
}

class AndroidAccessibilityVisionService implements AccessibilityVisionBridge {
  const AndroidAccessibilityVisionService({
    MethodChannel? channel,
  }) : _channel =
            channel ?? const MethodChannel('chessnut/accessibility_vision');

  final MethodChannel _channel;

  @override
  Future<void> setRecognitionStatus({
    required bool enabled,
    required bool recognizing,
    required bool boardConnected,
    required String languageTag,
  }) async {
    try {
      await _channel.invokeMethod<void>('setRecognitionStatus', {
        'enabled': enabled,
        'recognizing': recognizing,
        'boardConnected': boardConnected,
        'languageTag': languageTag,
      });
    } on MissingPluginException {
      // Other platforms do not have an Android notification drawer.
    } on PlatformException {
      // Notification availability must not interrupt Vision recognition.
    }
  }

  @override
  Future<bool> isAccessibilityRunning() async {
    try {
      return await _channel.invokeMethod<bool>('isAccessibilityRunning') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod<void>('openAccessibilitySettings');
    } on MissingPluginException {
      return;
    }
  }

  @override
  Future<String?> recognizeScreenshot() async {
    try {
      final result = await _channel
          .invokeMethod<String>('recognizeScreenshot')
          .timeout(const Duration(seconds: 4), onTimeout: () {
        throw const AccessibilityVisionException('vision_channel_timeout');
      });
      final trimmed = result?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      throw AccessibilityVisionException(error.code);
    }
  }

  @override
  Future<bool> dispatchMoveGesture({
    required Rect from,
    Rect? to,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('dispatchMoveGesture', {
            'from': _rectToJson(from),
            if (to != null) 'to': _rectToJson(to),
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Map<String, double> _rectToJson(Rect rect) {
    return {
      'left': rect.left,
      'top': rect.top,
      'width': rect.width,
      'height': rect.height,
    };
  }
}
