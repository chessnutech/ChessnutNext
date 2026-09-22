import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chessnut_flutter_export/l10n/app_language.dart';
import 'package:chessnut_flutter_export/services/board_settings_service.dart';
import 'package:chessnut_flutter_export/services/voice_move_recognition_service.dart';
import 'package:chessnut_flutter_export/services/voice_move_session_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('silently ignores recognized text that cannot be parsed as a move',
      () async {
    final service = _FakeVoiceMoveRecognitionService();
    final messages = <String>[];
    final moves = <String>[];
    final controller = VoiceMoveSessionController(
      service: service,
      ownsService: false,
      onChanged: () {},
      onMoveUci: moves.add,
      onMessage: messages.add,
      currentFenProvider: () =>
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    );

    service.addResult('hello chessnut');
    await pumpEventQueue();

    expect(messages, isEmpty);
    expect(moves, isEmpty);

    service.addResult('e4');
    await pumpEventQueue();

    expect(messages, isEmpty);
    expect(moves, ['e2e4']);

    await controller.dispose();
    await service.dispose();
  });
}

class _FakeVoiceMoveRecognitionService extends VoiceMoveRecognitionService {
  _FakeVoiceMoveRecognitionService()
      : super(
          openAiKeyProvider: () async => 'test-key',
          audioRecorder: _FakeVoiceMoveAudioRecorder(),
        );

  final _fakeEvents = StreamController<VoiceMoveRecognitionEvent>.broadcast();

  @override
  Stream<VoiceMoveRecognitionEvent> get events => _fakeEvents.stream;

  void addResult(String text) {
    _fakeEvents.add(VoiceMoveRecognitionEvent.result(text));
  }

  @override
  Future<bool> start({
    required VoiceMoveRecognitionMode mode,
    required AppLanguagePreference language,
    Locale? systemLocale,
  }) async {
    return true;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() => _fakeEvents.close();
}

class _FakeVoiceMoveAudioRecorder implements VoiceMoveAudioRecorder {
  @override
  Future<void> dispose() async {}

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<Stream<Uint8List>> startStream() async => const Stream.empty();

  @override
  Future<void> stop() async {}
}
