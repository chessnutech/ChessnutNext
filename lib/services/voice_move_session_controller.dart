import 'dart:async';

import 'package:flutter/widgets.dart';

import '../widgets/voice_moves_shortcut.dart';
import 'board_settings_service.dart';
import 'voice_move_parser.dart';
import 'voice_move_recognition_service.dart';

class VoiceMoveSessionController {
  VoiceMoveSessionController({
    required this.service,
    required this.ownsService,
    required this.onChanged,
    required this.onMoveUci,
    required this.onMessage,
    this.currentFenProvider,
  }) {
    _subscription = service.events.listen(_handleEvent);
  }

  final VoiceMoveRecognitionService service;
  final bool ownsService;
  final VoidCallback onChanged;
  final ValueChanged<String> onMoveUci;
  final ValueChanged<String> onMessage;
  final String? Function()? currentFenProvider;

  StreamSubscription<VoiceMoveRecognitionEvent>? _subscription;
  bool _disposed = false;

  bool enabled = false;
  bool listening = false;

  Future<void> toggle({
    required BuildContext context,
    required bool canUse,
    required BoardSettingsState settings,
    required String unavailableMessage,
  }) async {
    if (enabled) {
      await stop();
      return;
    }
    if (!canUse) {
      onMessage(unavailableMessage);
      return;
    }
    if (!await ensureVoiceMovesOnlineReady(context)) return;
    if (!context.mounted || _disposed) return;
    _setState(enabled: true, listening: false);
    final started = await service.start(
      mode: settings.voiceMoveRecognitionMode,
      language: settings.voiceMoveLanguage,
      systemLocale: Localizations.maybeLocaleOf(context),
    );
    if (!context.mounted || _disposed) return;
    if (!started) {
      _setState(enabled: false, listening: false);
      return;
    }
    unawaited(showVoiceMovesMicPrompt(context));
  }

  Future<void> stop() async {
    await service.stop();
    if (_disposed) return;
    _setState(enabled: false, listening: false);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
    if (ownsService) {
      await service.dispose();
    } else {
      await service.stop();
    }
  }

  void _handleEvent(VoiceMoveRecognitionEvent event) {
    if (_disposed) return;
    switch (event.type) {
      case VoiceMoveEventType.ready:
        _setState(enabled: true, listening: false);
      case VoiceMoveEventType.listening:
        _setState(enabled: true, listening: true);
      case VoiceMoveEventType.ended:
        _setState(enabled: false, listening: false);
      case VoiceMoveEventType.result:
        _handleText(event.text ?? '');
      case VoiceMoveEventType.error:
        _setState(enabled: false, listening: false);
        onMessage(event.message ?? 'Voice recognition failed.');
    }
  }

  void _handleText(String text) {
    final uci = parseVoiceMoveText(text, fen: currentFenProvider?.call());
    if (uci == null) return;
    onMoveUci(uci);
  }

  void _setState({required bool enabled, required bool listening}) {
    if (this.enabled == enabled && this.listening == listening) return;
    this.enabled = enabled;
    this.listening = listening;
    onChanged();
  }
}
