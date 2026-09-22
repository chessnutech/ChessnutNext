import 'dart:typed_data';

import 'package:chessnut_flutter_export/l10n/app_language.dart';
import 'package:chessnut_flutter_export/services/board_settings_service.dart';
import 'package:chessnut_flutter_export/services/voice_move_recognition_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:record/record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses the selected language for online transcription', () {
    expect(
      openAiTranscriptionLanguageCode(AppLanguagePreference.zhHant, null),
      'zh',
    );
    expect(
      openAiTranscriptionLanguageCode(AppLanguagePreference.ja, null),
      'ja',
    );
    expect(
      openAiTranscriptionLanguageCode(
        AppLanguagePreference.system,
        const Locale('fr'),
      ),
      'fr',
    );
  });

  test('voice recording stays active while move audio plays', () {
    expect(
      voiceMoveRecordConfig.audioInterruption,
      AudioInterruptionMode.none,
    );
  });

  test('macOS records raw PCM without AVAudioEngine voice processing', () {
    final config = voiceMoveRecordConfigForPlatform('macos');

    expect(config.encoder, AudioEncoder.pcm16bits);
    expect(config.sampleRate, 24000);
    expect(config.numChannels, 1);
    expect(config.echoCancel, isFalse);
    expect(config.autoGain, isFalse);
    expect(config.noiseSuppress, isFalse);
  });

  test('non-macOS platforms keep voice processing enabled', () {
    final config = voiceMoveRecordConfigForPlatform('android');

    expect(config.echoCancel, isTrue);
    expect(config.autoGain, isTrue);
    expect(config.noiseSuppress, isTrue);
  });

  test('online voice moves request microphone permission before starting',
      () async {
    final calls = <String>[];
    final recorder = _FakeVoiceMoveAudioRecorder(
      calls: calls,
      permissionGranted: false,
    );
    final service = VoiceMoveRecognitionService(
      openAiKeyProvider: () async {
        calls.add('openAiKey');
        return 'test-key';
      },
      audioRecorder: recorder,
    );
    addTearDown(service.dispose);
    final events = <VoiceMoveRecognitionEvent>[];
    final sub = service.events.listen(events.add);
    addTearDown(sub.cancel);

    final started = await service.start(
      mode: VoiceMoveRecognitionMode.online,
      language: AppLanguagePreference.system,
    );
    await Future<void>.delayed(Duration.zero);

    expect(started, isFalse);
    expect(
      calls,
      ['stop', 'openAiKey', 'hasPermission'],
    );
    expect(
      events.map((event) => event.message),
      contains('Microphone permission denied.'),
    );
  });
}

class _FakeVoiceMoveAudioRecorder implements VoiceMoveAudioRecorder {
  _FakeVoiceMoveAudioRecorder({
    required this.calls,
    required this.permissionGranted,
  });

  final List<String> calls;
  final bool permissionGranted;

  @override
  Future<bool> hasPermission() async {
    calls.add('hasPermission');
    return permissionGranted;
  }

  @override
  Future<Stream<Uint8List>> startStream() async {
    calls.add('startStream');
    return const Stream.empty();
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
  }
}
