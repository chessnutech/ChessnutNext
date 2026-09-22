import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

enum AppSoundEvent {
  gameStart,
  move,
  capture,
  check,
  hint,
  confirm,
  puzzleError,
  puzzleSuccess,
  victory,
  defeat,
  draw,
}

class SoundEffectsSettings {
  const SoundEffectsSettings({
    this.fromTo = true,
    this.move = true,
    this.result = true,
    this.keyAction = true,
  });

  final bool fromTo;
  final bool move;
  final bool result;
  final bool keyAction;

  SoundEffectsSettings copyWith({
    bool? fromTo,
    bool? move,
    bool? result,
    bool? keyAction,
  }) {
    return SoundEffectsSettings(
      fromTo: fromTo ?? this.fromTo,
      move: move ?? this.move,
      result: result ?? this.result,
      keyAction: keyAction ?? this.keyAction,
    );
  }

  bool allows(AppSoundEvent event) {
    return switch (event) {
      AppSoundEvent.move ||
      AppSoundEvent.capture ||
      AppSoundEvent.check =>
        move,
      AppSoundEvent.victory ||
      AppSoundEvent.defeat ||
      AppSoundEvent.draw =>
        result,
      AppSoundEvent.gameStart ||
      AppSoundEvent.hint ||
      AppSoundEvent.confirm ||
      AppSoundEvent.puzzleError ||
      AppSoundEvent.puzzleSuccess =>
        keyAction,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'from_to': fromTo,
      'move': move,
      'result': result,
      'key_action': keyAction,
    };
  }

  factory SoundEffectsSettings.fromJson(Object? value) {
    if (value is! Map) return const SoundEffectsSettings();
    return SoundEffectsSettings(
      fromTo: value['from_to'] is bool ? value['from_to'] as bool : true,
      move: value['move'] is bool ? value['move'] as bool : true,
      result: value['result'] is bool ? value['result'] as bool : true,
      keyAction:
          value['key_action'] is bool ? value['key_action'] as bool : true,
    );
  }
}

class AppMoveSound {
  const AppMoveSound({
    required this.from,
    required this.to,
    required this.san,
    required this.inCheck,
    required this.inCheckmate,
    required this.inStalemate,
  });

  final String from;
  final String to;
  final String san;
  final bool inCheck;
  final bool inCheckmate;
  final bool inStalemate;

  String get uci => '$from$to';

  bool get isKingSideCastle {
    final normalized = _normalizedSan;
    return normalized == 'O-O' ||
        (from == 'e1' && to == 'g1') ||
        (from == 'e8' && to == 'g8');
  }

  bool get isQueenSideCastle {
    final normalized = _normalizedSan;
    return normalized == 'O-O-O' ||
        (from == 'e1' && to == 'c1') ||
        (from == 'e8' && to == 'c8');
  }

  AppSoundEvent get fallbackEvent {
    if (inCheck || inCheckmate) return AppSoundEvent.check;
    if (san.contains('x')) return AppSoundEvent.capture;
    return AppSoundEvent.move;
  }

  String get _normalizedSan {
    return san.replaceAll('0', 'O').replaceAll(RegExp(r'[+#?!]'), '').trim();
  }
}

abstract class AppSoundService {
  const AppSoundService();

  Future<void> play(AppSoundEvent event);

  Future<void> playMove(AppMoveSound move) => play(move.fallbackEvent);

  Future<void> playMoveAudio(
    AppMoveSound move, {
    required bool announceSquares,
    required bool playEffect,
  }) async {
    if (announceSquares) await playMove(move);
    if (playEffect) await play(move.fallbackEvent);
  }
}

class AssetAppSoundService extends AppSoundService {
  const AssetAppSoundService();

  static final _sharedPlayer = _SharedAppSoundPlayer();
  // Move-voice assets use the same fixed 4x sample gain and limiting as the
  // generated commentary WAV files, then play at full media volume.
  static const _moveVoiceVolume = 1.0;

  @override
  Future<void> play(AppSoundEvent event) async {
    try {
      await _sharedPlayer.play([
        _AppSoundClip(
          assetPath: _assetPathFor(event),
          volume: _volumeFor(event),
        ),
      ]);
      return;
    } catch (_) {
      await _playSystemFallback(event);
    }
  }

  @override
  Future<void> playMove(AppMoveSound move) async {
    final assetPaths = _moveAssetPathsFor(move);
    if (assetPaths.isEmpty) {
      await play(move.fallbackEvent);
      return;
    }
    try {
      await _sharedPlayer.play([
        for (final assetPath in assetPaths)
          _AppSoundClip(
            assetPath: assetPath,
            volume: _moveVoiceVolume,
          ),
      ]);
    } catch (_) {
      await play(move.fallbackEvent);
    }
  }

  @override
  Future<void> playMoveAudio(
    AppMoveSound move, {
    required bool announceSquares,
    required bool playEffect,
  }) async {
    final clips = <_AppSoundClip>[
      if (announceSquares)
        for (final assetPath in _moveAssetPathsFor(move))
          _AppSoundClip(
            assetPath: assetPath,
            volume: _moveVoiceVolume,
          ),
      if (playEffect)
        _AppSoundClip(
          assetPath: _assetPathFor(move.fallbackEvent),
          volume: _volumeFor(move.fallbackEvent),
        ),
    ];
    if (clips.isEmpty) return;
    try {
      await _sharedPlayer.play(clips);
    } catch (_) {
      if (playEffect) await _playSystemFallback(move.fallbackEvent);
    }
  }

  double _volumeFor(AppSoundEvent event) {
    return switch (event) {
      AppSoundEvent.victory => 0.78,
      AppSoundEvent.defeat => 0.72,
      AppSoundEvent.draw => 0.70,
      AppSoundEvent.gameStart => 0.68,
      AppSoundEvent.puzzleSuccess => 0.76,
      AppSoundEvent.puzzleError => 0.72,
      AppSoundEvent.capture || AppSoundEvent.check => 0.62,
      AppSoundEvent.move || AppSoundEvent.hint || AppSoundEvent.confirm => 0.56,
    };
  }

  String _assetPathFor(AppSoundEvent event) {
    // App sound assets are sourced from lichess-org/lila public/sound.
    return switch (event) {
      AppSoundEvent.gameStart => 'sounds/game_start.mp3',
      AppSoundEvent.move => 'sounds/move.mp3',
      AppSoundEvent.capture => 'sounds/capture.mp3',
      AppSoundEvent.check => 'sounds/check.mp3',
      AppSoundEvent.hint => 'sounds/hint.mp3',
      AppSoundEvent.confirm => 'sounds/confirm.mp3',
      AppSoundEvent.puzzleError => 'sounds/puzzle_error.wav',
      AppSoundEvent.puzzleSuccess => 'sounds/puzzle_success.wav',
      AppSoundEvent.victory => 'sounds/victory.mp3',
      AppSoundEvent.defeat => 'sounds/defeat.mp3',
      AppSoundEvent.draw => 'sounds/draw.mp3',
    };
  }

  List<String> _moveAssetPathsFor(AppMoveSound move) {
    final names = <String>[];
    if (move.isQueenSideCastle) {
      names.add('ooo');
    } else if (move.isKingSideCastle) {
      names.add('oo');
    } else {
      if (_isSquareName(move.from)) names.add(move.from);
      if (_isSquareName(move.to)) names.add(move.to);
    }
    if (move.inCheckmate) {
      names.add('checkmate');
    } else if (move.inStalemate) {
      names.add('stalemate');
    } else if (move.inCheck) {
      names.add('check');
    }
    return [
      for (final name in names) 'sounds/voice/$name.mp3',
    ];
  }

  bool _isSquareName(String value) {
    return RegExp(r'^[a-h][1-8]$').hasMatch(value);
  }

  Future<void> _playSystemFallback(AppSoundEvent event) async {
    switch (event) {
      case AppSoundEvent.gameStart:
      case AppSoundEvent.confirm:
      case AppSoundEvent.puzzleSuccess:
      case AppSoundEvent.move:
        await SystemSound.play(SystemSoundType.click);
      case AppSoundEvent.capture:
      case AppSoundEvent.check:
      case AppSoundEvent.hint:
      case AppSoundEvent.puzzleError:
        await SystemSound.play(SystemSoundType.click);
        await Future<void>.delayed(const Duration(milliseconds: 90));
        await SystemSound.play(SystemSoundType.click);
      case AppSoundEvent.victory:
        await SystemSound.play(SystemSoundType.click);
        await Future<void>.delayed(const Duration(milliseconds: 90));
        await SystemSound.play(SystemSoundType.click);
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await SystemSound.play(SystemSoundType.click);
      case AppSoundEvent.defeat:
        await SystemSound.play(SystemSoundType.alert);
      case AppSoundEvent.draw:
        await SystemSound.play(SystemSoundType.click);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await SystemSound.play(SystemSoundType.alert);
    }
  }
}

class SystemAppSoundService extends AssetAppSoundService {
  const SystemAppSoundService();
}

class _AppSoundClip {
  const _AppSoundClip({
    required this.assetPath,
    required this.volume,
  });

  final String assetPath;
  final double volume;
}

class _SharedAppSoundPlayer {
  static const _completionTimeout = Duration(seconds: 10);

  final AudioPlayer _player = AudioPlayer();
  Future<void> _queue = Future<void>.value();
  bool _initialized = false;

  Future<void> play(List<_AppSoundClip> clips) {
    if (clips.isEmpty) return Future<void>.value();

    final operation = _queue.then(
      (_) => _playClips(clips),
    );
    _queue = operation.then<void>((_) {}, onError: (_) {});
    return operation;
  }

  Future<void> _playClips(List<_AppSoundClip> clips) async {
    await _ensureInitialized();
    await _player.stop();
    for (final clip in clips) {
      final completed = Completer<void>();
      final completionSubscription = _player.onPlayerComplete.listen((_) {
        if (!completed.isCompleted) completed.complete();
      });
      final completionTimeout = Timer(_completionTimeout, () {
        if (!completed.isCompleted) completed.complete();
      });
      try {
        await _player.play(
          AssetSource(clip.assetPath),
          volume: clip.volume,
          mode: PlayerMode.mediaPlayer,
        );
        await completed.future;
      } finally {
        completionTimeout.cancel();
        await completionSubscription.cancel();
      }
      await _player.stop();
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );
    _initialized = true;
  }
}
