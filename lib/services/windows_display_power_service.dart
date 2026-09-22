import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract class WindowsDisplayPowerService {
  bool get isSupported;

  Stream<bool> get displayOffChanges;

  Future<bool> isDisplayOff();
}

class MethodChannelWindowsDisplayPowerService
    implements WindowsDisplayPowerService {
  const MethodChannelWindowsDisplayPowerService({
    MethodChannel methodChannel = const MethodChannel(
      'chessnut/windows_display_power',
    ),
    EventChannel eventChannel = const EventChannel(
      'chessnut/windows_display_power/events',
    ),
  })  : _methodChannel = methodChannel,
        _eventChannel = eventChannel;

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  Stream<bool> get displayOffChanges => _eventChannel
      .receiveBroadcastStream()
      .where((event) => event is bool)
      .cast<bool>();

  @override
  Future<bool> isDisplayOff() async {
    try {
      return await _methodChannel.invokeMethod<bool>('isDisplayOff') ?? false;
    } on MissingPluginException {
      return false;
    }
  }
}
