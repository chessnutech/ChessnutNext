import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum PlayInAppUpdateResult {
  started,
  unavailable,
  notAllowed,
  failed,
  unsupported,
}

class PlayInAppUpdateAvailability {
  const PlayInAppUpdateAvailability({
    required this.available,
    required this.immediateAllowed,
    required this.flexibleAllowed,
    this.availableVersionCode,
    this.installerPackageName,
    this.installedFromGooglePlay = true,
    this.checkFailed = false,
  });

  final bool available;
  final bool immediateAllowed;
  final bool flexibleAllowed;
  final int? availableVersionCode;
  final String? installerPackageName;
  final bool installedFromGooglePlay;
  final bool checkFailed;

  bool get canStart => available && (immediateAllowed || flexibleAllowed);
}

class PlayInAppUpdateService {
  const PlayInAppUpdateService({
    MethodChannel channel = const MethodChannel('chessnut/play_in_app_update'),
    bool Function()? isAndroidProvider,
  })  : _channel = channel,
        _isAndroidProvider = isAndroidProvider;

  final MethodChannel _channel;
  final bool Function()? _isAndroidProvider;

  bool get _isAndroid =>
      _isAndroidProvider?.call() ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  Future<PlayInAppUpdateAvailability> checkAvailability() async {
    if (!_isAndroid) {
      return const PlayInAppUpdateAvailability(
        available: false,
        immediateAllowed: false,
        flexibleAllowed: false,
      );
    }
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'checkAvailability',
      );
      if (result == null) {
        return const PlayInAppUpdateAvailability(
          available: false,
          immediateAllowed: false,
          flexibleAllowed: false,
        );
      }
      return PlayInAppUpdateAvailability(
        available: result['available'] == true,
        immediateAllowed: result['immediateAllowed'] == true,
        flexibleAllowed: result['flexibleAllowed'] == true,
        availableVersionCode: result['availableVersionCode'] is int
            ? result['availableVersionCode'] as int
            : null,
        installerPackageName: result['installerPackageName'] is String
            ? result['installerPackageName'] as String
            : null,
        installedFromGooglePlay: result['installedFromGooglePlay'] != false,
      );
    } on MissingPluginException {
      return const PlayInAppUpdateAvailability(
        available: false,
        immediateAllowed: false,
        flexibleAllowed: false,
      );
    } on PlatformException {
      return const PlayInAppUpdateAvailability(
        available: false,
        immediateAllowed: false,
        flexibleAllowed: false,
        checkFailed: true,
      );
    }
  }

  Future<PlayInAppUpdateResult> startUpdate({required bool immediate}) async {
    if (!_isAndroid) return PlayInAppUpdateResult.unsupported;
    try {
      final result = await _channel.invokeMethod<String>('startUpdate', {
        'immediate': immediate,
      });
      return _parseResult(result);
    } on MissingPluginException {
      return PlayInAppUpdateResult.unsupported;
    } on PlatformException {
      return PlayInAppUpdateResult.failed;
    }
  }

  static PlayInAppUpdateResult _parseResult(String? value) {
    switch (value) {
      case 'started':
        return PlayInAppUpdateResult.started;
      case 'unavailable':
        return PlayInAppUpdateResult.unavailable;
      case 'notAllowed':
        return PlayInAppUpdateResult.notAllowed;
      case 'failed':
        return PlayInAppUpdateResult.failed;
      default:
        return PlayInAppUpdateResult.failed;
    }
  }
}
