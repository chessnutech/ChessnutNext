import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:record/record.dart';

import '../l10n/app_language.dart';
import 'board_settings_service.dart';

typedef OpenAiKeyProvider = Future<String?> Function();

const openAiTranscriptionModel = 'gpt-4o-transcribe';
const openAiRealtimeTranscriptionUrl =
    'wss://api.openai.com/v1/realtime?intent=transcription';
const voiceMoveRecordConfig = RecordConfig(
  encoder: AudioEncoder.pcm16bits,
  sampleRate: 24000,
  numChannels: 1,
  autoGain: true,
  echoCancel: true,
  noiseSuppress: true,
  audioInterruption: AudioInterruptionMode.none,
);

RecordConfig voiceMoveRecordConfigForPlatform(String operatingSystem) {
  if (operatingSystem == 'macos') {
    // record_macos implements echo cancellation by enabling AVAudioEngine voice
    // processing. On some Macs this produces correctly sized PCM buffers whose
    // samples are all zero. Capture raw PCM on macOS and leave voice processing
    // to the transcription service.
    return voiceMoveRecordConfig.copyWith(
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
    );
  }
  if (operatingSystem == 'ios') {
    // On iOS, echo cancellation causes the system to lower speaker volume
    // significantly during voice recognition to prevent feedback. Disable it
    // to maintain normal playback volume for move announcements.
    return voiceMoveRecordConfig.copyWith(
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
    );
  }
  return voiceMoveRecordConfig;
}

String openAiVoiceMovePrompt(String language) =>
    'Transcribe only the spoken chess move. Preserve any origin and '
    'destination squares, use Arabic numerals, and do not add commentary. '
    'The speaker uses $language.';

String openAiTranscriptionLanguageCode(
  AppLanguagePreference language,
  Locale? systemLocale,
) =>
    _recognitionLocale(language, systemLocale).languageCode;

Map<String, String> openAiRealtimeHeaders(String key) => {
      HttpHeaders.authorizationHeader: 'Bearer $key',
    };

class VoiceMoveRecognitionService {
  VoiceMoveRecognitionService({
    OpenAiKeyProvider? openAiKeyProvider,
    VoiceMoveAudioRecorder? audioRecorder,
  })  : _openAiKeyProvider = openAiKeyProvider,
        _audioRecorder = audioRecorder ?? RecordVoiceMoveAudioRecorder();

  final OpenAiKeyProvider? _openAiKeyProvider;
  final VoiceMoveAudioRecorder _audioRecorder;
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<dynamic>? _onlineSocketSub;
  WebSocket? _onlineSocket;
  Completer<void>? _onlineSessionReady;
  int _onlineStartToken = 0;
  final _events = StreamController<VoiceMoveRecognitionEvent>.broadcast();

  Stream<VoiceMoveRecognitionEvent> get events => _events.stream;

  Future<bool> isAvailable({
    required VoiceMoveRecognitionMode mode,
  }) async {
    return _openAiKeyProvider != null;
  }

  Future<bool> start({
    required VoiceMoveRecognitionMode mode,
    required AppLanguagePreference language,
    Locale? systemLocale,
  }) async {
    await stop();
    return _startOnline(language: language, systemLocale: systemLocale);
  }

  Future<bool> _startOnline({
    required AppLanguagePreference language,
    Locale? systemLocale,
  }) async {
    final keyProvider = _openAiKeyProvider;
    if (keyProvider == null) {
      _events.add(const VoiceMoveRecognitionEvent.error(
        'Online voice recognition requires sign-in.',
      ));
      return false;
    }
    final String? key;
    try {
      key = (await keyProvider())?.trim();
    } on VoiceMoveOpenAiSessionException catch (error) {
      _events.add(VoiceMoveRecognitionEvent.error(error.message));
      return false;
    } catch (error) {
      _events.add(VoiceMoveRecognitionEvent.error(
        'Online voice recognition could not get an OpenAI session: $error',
      ));
      return false;
    }
    if (key == null || key.isEmpty) {
      _events.add(const VoiceMoveRecognitionEvent.error(
        'Online voice recognition could not get an OpenAI session.',
      ));
      return false;
    }

    if (!await _ensureAudioPermission()) {
      _events.add(const VoiceMoveRecognitionEvent.error(
        'Microphone permission denied.',
      ));
      return false;
    }

    final token = ++_onlineStartToken;
    final spokenLanguage = _spokenLanguageName(language, systemLocale);
    final prompt = openAiVoiceMovePrompt(spokenLanguage);
    final languageCode =
        openAiTranscriptionLanguageCode(language, systemLocale);
    _onlineSessionReady = Completer<void>();

    try {
      final socket = await WebSocket.connect(
        openAiRealtimeTranscriptionUrl,
        headers: openAiRealtimeHeaders(key),
      ).timeout(const Duration(seconds: 10));
      if (token != _onlineStartToken) {
        await socket.close();
        return false;
      }

      _onlineSocket = socket;
      _onlineSocketSub = socket.listen(
        (event) => _handleOnlineEvent(event, prompt, languageCode),
        onError: (Object error) {
          _events.add(VoiceMoveRecognitionEvent.error(
            'Online voice recognition error: $error',
          ));
        },
        onDone: () {
          if (token == _onlineStartToken) {
            _events.add(const VoiceMoveRecognitionEvent.ended());
          }
        },
      );

      _events.add(const VoiceMoveRecognitionEvent.ready());
      await _onlineSessionReady!.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw TimeoutException(
          'OpenAI transcription session did not become ready.',
        ),
      );

      final audioStream = await _audioRecorder.startStream();
      _audioSubscription = audioStream.listen(
        _sendOnlineAudio,
        onError: (Object error) {
          _events.add(VoiceMoveRecognitionEvent.error(
            'Microphone recording error: $error',
          ));
        },
      );
      if (token != _onlineStartToken) {
        await _audioSubscription?.cancel();
        _audioSubscription = null;
        await _audioRecorder.stop();
        return false;
      }
      _events.add(const VoiceMoveRecognitionEvent.listening());
      return true;
    } catch (error) {
      await _stopOnline();
      _events.add(VoiceMoveRecognitionEvent.error(
        'Online voice recognition failed: $error',
      ));
      return false;
    }
  }

  Future<bool> _ensureAudioPermission() async {
    try {
      return await _audioRecorder.hasPermission();
    } catch (error) {
      _events.add(VoiceMoveRecognitionEvent.error(
        'Microphone permission check failed: $error',
      ));
      return false;
    }
  }

  Future<void> stop() async {
    await _stopOnline();
  }

  Future<void> dispose() async {
    await stop();
    await _audioRecorder.dispose();
    await _events.close();
  }

  Future<void> _stopOnline() async {
    _onlineStartToken++;
    _onlineSessionReady = null;
    try {
      await _audioRecorder.stop();
    } catch (_) {}
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _onlineSocketSub?.cancel();
    _onlineSocketSub = null;
    final socket = _onlineSocket;
    _onlineSocket = null;
    try {
      await socket?.close();
    } catch (_) {}
  }

  void _handleOnlineEvent(
    dynamic event,
    String prompt,
    String languageCode,
  ) {
    if (event is! String || event.isEmpty) return;
    final decoded = jsonDecode(event);
    if (decoded is! Map<String, dynamic>) return;
    final type = decoded['type']?.toString();

    if (type == 'session.created' || type == 'transcription_session.created') {
      _onlineSocket?.add(
        jsonEncode(_buildSessionUpdateEvent(prompt, languageCode)),
      );
      return;
    }

    if (type == 'session.updated' || type == 'transcription_session.updated') {
      _completeOnlineSessionReady();
      return;
    }

    if (type == 'conversation.item.input_audio_transcription.completed') {
      final text = decoded['transcript']?.toString().trim();
      if (text != null && text.isNotEmpty) {
        _events.add(VoiceMoveRecognitionEvent.result(text));
      }
      return;
    }

    if (type == 'error') {
      final error = decoded['error'];
      final message = error is Map
          ? error['message']?.toString()
          : decoded['message']?.toString();
      _events.add(VoiceMoveRecognitionEvent.error(
        message ?? 'Online voice recognition failed.',
      ));
    }
  }

  void _completeOnlineSessionReady() {
    final completer = _onlineSessionReady;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void _sendOnlineAudio(Uint8List chunk) {
    final socket = _onlineSocket;
    if (socket == null || socket.readyState != WebSocket.open) return;
    socket.add(jsonEncode({
      'type': 'input_audio_buffer.append',
      'audio': base64Encode(chunk),
    }));
  }
}

abstract interface class VoiceMoveAudioRecorder {
  Future<bool> hasPermission();

  Future<Stream<Uint8List>> startStream();

  Future<void> stop();

  Future<void> dispose();
}

class RecordVoiceMoveAudioRecorder implements VoiceMoveAudioRecorder {
  RecordVoiceMoveAudioRecorder({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<Stream<Uint8List>> startStream() => _recorder.startStream(
        voiceMoveRecordConfigForPlatform(Platform.operatingSystem),
      );

  @override
  Future<void> stop() async {
    await _recorder.stop();
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}

Map<String, Object?> _buildSessionUpdateEvent(
  String prompt,
  String languageCode,
) {
  return {
    'type': 'session.update',
    'session': {
      'type': 'transcription',
      'audio': {
        'input': {
          'format': {
            'type': 'audio/pcm',
            'rate': 24000,
          },
          'transcription': {
            'model': openAiTranscriptionModel,
            'language': languageCode,
            'prompt': prompt,
          },
          'turn_detection': {
            'type': 'server_vad',
            'prefix_padding_ms': 300,
            'threshold': 0.5,
            'silence_duration_ms': 500,
          },
          'noise_reduction': {'type': 'far_field'},
        },
      },
    },
  };
}

class VoiceMoveRecognitionEvent {
  const VoiceMoveRecognitionEvent._(this.type, {this.text, this.message});

  const VoiceMoveRecognitionEvent.ready() : this._(VoiceMoveEventType.ready);

  const VoiceMoveRecognitionEvent.listening()
      : this._(VoiceMoveEventType.listening);

  const VoiceMoveRecognitionEvent.ended() : this._(VoiceMoveEventType.ended);

  const VoiceMoveRecognitionEvent.result(String text)
      : this._(VoiceMoveEventType.result, text: text);

  const VoiceMoveRecognitionEvent.error(String message)
      : this._(VoiceMoveEventType.error, message: message);

  final VoiceMoveEventType type;
  final String? text;
  final String? message;
}

enum VoiceMoveEventType { ready, listening, ended, result, error }

class VoiceMoveOpenAiSessionException implements Exception {
  const VoiceMoveOpenAiSessionException(this.message);

  final String message;

  @override
  String toString() => message;
}

Locale _recognitionLocale(
  AppLanguagePreference language,
  Locale? systemLocale,
) {
  final locale = language.locale ?? systemLocale;
  if (locale == null) return const Locale('en');
  if (locale.languageCode == 'en') {
    return const Locale.fromSubtags(languageCode: 'en', countryCode: 'US');
  }
  if (locale.languageCode == 'zh') {
    return locale.scriptCode == 'Hant'
        ? const Locale.fromSubtags(languageCode: 'zh', countryCode: 'HK')
        : const Locale.fromSubtags(languageCode: 'zh', countryCode: 'CN');
  }
  return locale;
}

String _spokenLanguageName(
  AppLanguagePreference language,
  Locale? systemLocale,
) {
  final locale = _recognitionLocale(language, systemLocale);
  if (locale.languageCode == 'zh') {
    return locale.scriptCode == 'Hant' || locale.countryCode == 'HK'
        ? 'Cantonese'
        : 'Mandarin';
  }
  return switch (locale.languageCode) {
    'de' => 'German',
    'es' => 'Spanish',
    'fr' => 'French',
    'it' => 'Italian',
    'ja' => 'Japanese',
    'ko' => 'Korean',
    'nl' => 'Dutch',
    'ru' => 'Russian',
    _ => 'English',
  };
}
