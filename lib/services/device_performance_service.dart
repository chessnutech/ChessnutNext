import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DevicePerformanceProfile {
  const DevicePerformanceProfile({
    required this.platform,
    required this.model,
    required this.manufacturer,
    required this.sdkInt,
    required this.isLowRamDevice,
    required this.memoryClassMb,
    required this.largeMemoryClassMb,
    required this.totalRamMb,
    required this.cpuCores,
    this.osVersion = '',
    this.isChessnutClock = false,
    this.isChessnutEvo2 = false,
  });

  final String platform;
  final String model;
  final String manufacturer;
  final int sdkInt;
  final bool isLowRamDevice;
  final int memoryClassMb;
  final int largeMemoryClassMb;
  final int totalRamMb;
  final int cpuCores;
  final String osVersion;
  final bool isChessnutClock;
  final bool isChessnutEvo2;

  bool get isAndroid => platform.toLowerCase() == 'android';

  bool get prefersClassicLowEffects {
    if (!isAndroid) return false;
    if (isChessnutEvo2) return false;
    if (isChessnutClock) return true;
    if (isLowRamDevice) return true;
    if (sdkInt > 0 && sdkInt <= 28) return true;
    if (totalRamMb > 0 && totalRamMb <= 3072) return true;
    if (memoryClassMb > 0 && memoryClassMb <= 192) return true;
    if (cpuCores > 0 && cpuCores <= 4 && totalRamMb <= 4096) return true;
    return false;
  }

  bool get requiresVisualEffectsDisabled => isChessnutClock || isChessnutEvo2;

  factory DevicePerformanceProfile.fromMap(Map<dynamic, dynamic> map) {
    final model = map['model']?.toString() ?? '';
    final manufacturer = map['manufacturer']?.toString() ?? '';
    final isChessnutEvo2 = map['isChessnutEvo2'] == true ||
        (_evo2DeviceDetectionEnabled &&
            _looksLikeChessnutEvo2(model, manufacturer));
    final isChessnutClock = !isChessnutEvo2 &&
        (map['isChessnutClock'] == true ||
            _looksLikeChessnutClock(model, manufacturer));
    return DevicePerformanceProfile(
      platform: map['platform']?.toString() ?? '',
      model: model,
      manufacturer: manufacturer,
      sdkInt: _int(map['sdkInt']),
      isLowRamDevice: map['isLowRamDevice'] == true,
      memoryClassMb: _int(map['memoryClassMb']),
      largeMemoryClassMb: _int(map['largeMemoryClassMb']),
      totalRamMb: _int(map['totalRamMb']),
      cpuCores: _int(map['cpuCores']),
      osVersion: map['osVersion']?.toString() ?? '',
      isChessnutClock: isChessnutClock,
      isChessnutEvo2: isChessnutEvo2,
    );
  }
}

abstract class DevicePerformanceService {
  Future<DevicePerformanceProfile?> readProfile();
}

class MethodChannelDevicePerformanceService
    implements DevicePerformanceService {
  const MethodChannelDevicePerformanceService();

  static const MethodChannel _channel =
      MethodChannel('chessnut/device_performance');

  @override
  Future<DevicePerformanceProfile?> readProfile() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('profile');
      if (result == null) return null;
      return DevicePerformanceProfile.fromMap(result);
    } catch (_) {
      return null;
    }
  }
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

// Keep model-based EVO2 detection disabled until EVO2 support is re-enabled.
const bool _evo2DeviceDetectionEnabled = false;

bool _looksLikeChessnutClock(String model, String manufacturer) {
  final normalizedModel =
      model.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final normalizedManufacturer =
      manufacturer.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (!normalizedManufacturer.contains('chessnut')) return false;
  return normalizedModel == 'chessnutcompanion' ||
      normalizedModel.contains('companion') ||
      normalizedModel.contains('chessclock');
}

bool _looksLikeChessnutEvo2(String model, String manufacturer) {
  final normalizedModel =
      model.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final normalizedManufacturer =
      manufacturer.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return normalizedModel.contains('chessnutevo2') ||
      normalizedModel.contains('evo2') ||
      (normalizedModel == 'a733pro3' &&
          normalizedManufacturer.contains('allwinner'));
}
