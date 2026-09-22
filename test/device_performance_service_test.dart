import 'package:flutter_test/flutter_test.dart';

import 'package:chessnut_flutter_export/services/device_performance_service.dart';

void main() {
  test('Chessnut clock profile is parsed as a locked low-effects device', () {
    final profile = DevicePerformanceProfile.fromMap({
      'platform': 'android',
      'model': 'Chessnut_Companion',
      'manufacturer': 'Chessnut',
      'sdkInt': 33,
      'osVersion': '13',
      'isLowRamDevice': false,
      'memoryClassMb': 256,
      'largeMemoryClassMb': 512,
      'totalRamMb': 4096,
      'cpuCores': 8,
      'isChessnutClock': true,
    });

    expect(profile.isChessnutClock, isTrue);
    expect(profile.osVersion, '13');
    expect(profile.prefersClassicLowEffects, isTrue);
    expect(profile.requiresVisualEffectsDisabled, isTrue);
  });

  test('Chessnut clock profile falls back to model detection', () {
    final profile = DevicePerformanceProfile.fromMap({
      'platform': 'android',
      'model': 'Chessnut_Companion',
      'manufacturer': 'Chessnut',
    });

    expect(profile.isChessnutClock, isTrue);
    expect(profile.requiresVisualEffectsDisabled, isTrue);
  });

  test('Chessnut EVO2 profile is parsed as a locked low-effects device', () {
    final profile = DevicePerformanceProfile.fromMap({
      'platform': 'android',
      'model': 'A733 PRO3',
      'manufacturer': 'Allwinner',
      'sdkInt': 35,
      'isLowRamDevice': false,
      'memoryClassMb': 512,
      'largeMemoryClassMb': 512,
      'totalRamMb': 4096,
      'cpuCores': 8,
      'isChessnutEvo2': true,
    });

    expect(profile.isChessnutEvo2, isTrue);
    expect(profile.prefersClassicLowEffects, isFalse);
    expect(profile.requiresVisualEffectsDisabled, isTrue);
  });

  test('Chessnut EVO2 model detection is disabled', () {
    final profile = DevicePerformanceProfile.fromMap({
      'platform': 'android',
      'model': 'Chessnut EVO2',
      'manufacturer': 'Chessnut',
      'isLowRamDevice': true,
    });

    expect(profile.isChessnutEvo2, isFalse);
    expect(profile.prefersClassicLowEffects, isTrue);
    expect(profile.requiresVisualEffectsDisabled, isFalse);
  });

  test('Chessnut EVO2 A733 PRO3 detection is disabled', () {
    final profile = DevicePerformanceProfile.fromMap({
      'platform': 'android',
      'model': 'A733 PRO3',
      'manufacturer': 'Allwinner',
      'isLowRamDevice': true,
    });

    expect(profile.isChessnutEvo2, isFalse);
    expect(profile.prefersClassicLowEffects, isTrue);
    expect(profile.requiresVisualEffectsDisabled, isFalse);
  });

  test('Chessnut EVO2 classification overrides Companion classification', () {
    final profile = DevicePerformanceProfile.fromMap({
      'platform': 'android',
      'model': 'Chessnut_Companion',
      'manufacturer': 'Chessnut',
      'isChessnutClock': true,
      'isChessnutEvo2': true,
    });

    expect(profile.isChessnutEvo2, isTrue);
    expect(profile.isChessnutClock, isFalse);
    expect(profile.prefersClassicLowEffects, isFalse);
  });
}
