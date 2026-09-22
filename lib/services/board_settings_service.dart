import 'package:flutter/foundation.dart';

import '../l10n/app_language.dart';

const int evo2LedPatternSize = 7;
const int evo2LedPatternCellCount = evo2LedPatternSize * evo2LedPatternSize;

class Evo2LedPattern {
  factory Evo2LedPattern({required List<int> colors}) {
    return Evo2LedPattern._(_normalizeColors(colors));
  }

  const Evo2LedPattern._(this.colors);

  factory Evo2LedPattern.fromJson(Object? value, Evo2LedPattern fallback) {
    if (value is! List) return fallback;
    final colors = <int>[];
    for (final item in value) {
      final color = _colorFromJson(item);
      if (color == null) return fallback;
      colors.add(color);
    }
    if (colors.length != evo2LedPatternCellCount) return fallback;
    return Evo2LedPattern._(List<int>.unmodifiable(colors));
  }

  static const empty = Evo2LedPattern._(_emptyEvo2LedPatternColors);

  final List<int> colors;

  int colorAt(int row, int col) => colors[row * evo2LedPatternSize + col];

  Evo2LedPattern copyWithCell(int index, int color) {
    if (index < 0 || index >= evo2LedPatternCellCount) return this;
    final next = List<int>.of(colors);
    next[index] = _normalizeColor(color);
    return Evo2LedPattern._(List<int>.unmodifiable(next));
  }

  Evo2LedPattern fill(int color) {
    return Evo2LedPattern._(
      List<int>.unmodifiable(
        List<int>.filled(evo2LedPatternCellCount, _normalizeColor(color)),
      ),
    );
  }

  List<int> toJson() => List<int>.unmodifiable(colors);

  @override
  bool operator ==(Object other) {
    return other is Evo2LedPattern && listEquals(other.colors, colors);
  }

  @override
  int get hashCode => Object.hashAll(colors);
}

class Evo2LedPatternSet {
  factory Evo2LedPatternSet({required Map<String, Evo2LedPattern> patterns}) {
    return Evo2LedPatternSet._(_normalizePatterns(patterns));
  }

  const Evo2LedPatternSet._(this.patterns);

  factory Evo2LedPatternSet.fromJson(Object? value) {
    final defaults = Evo2LedPatternSet.defaults;
    if (value is! Map) return defaults;
    final decoded = <String, Evo2LedPattern>{};
    for (final key in evo2LedPatternKeys) {
      decoded[key] = Evo2LedPattern.fromJson(
        value[key],
        defaults.patternFor(key),
      );
    }
    return Evo2LedPatternSet._(Map<String, Evo2LedPattern>.unmodifiable(
      decoded,
    ));
  }

  static final defaults = Evo2LedPatternSet._(
    Map<String, Evo2LedPattern>.unmodifiable({
      for (final key in evo2LedPatternKeys) key: _defaultEvo2PatternFor(key),
    }),
  );

  final Map<String, Evo2LedPattern> patterns;

  Evo2LedPattern patternFor(String key) {
    return patterns[key] ?? Evo2LedPattern.empty;
  }

  Evo2LedPatternSet copyWithPattern(String key, Evo2LedPattern pattern) {
    if (!evo2LedPatternKeys.contains(key)) return this;
    final next = Map<String, Evo2LedPattern>.of(patterns);
    next[key] = pattern;
    return Evo2LedPatternSet._(Map<String, Evo2LedPattern>.unmodifiable(next));
  }

  Map<String, dynamic> toJson() {
    return {
      for (final key in evo2LedPatternKeys) key: patternFor(key).toJson(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (other is! Evo2LedPatternSet) return false;
    for (final key in evo2LedPatternKeys) {
      if (patternFor(key) != other.patternFor(key)) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(
        evo2LedPatternKeys.map((key) => patternFor(key)),
      );
}

const List<String> evo2LedPatternKeys = [
  'empty',
  'P',
  'N',
  'B',
  'R',
  'Q',
  'K',
  'p',
  'n',
  'b',
  'r',
  'q',
  'k',
  'analysis_best',
  'analysis_great',
  'analysis_inaccuracy',
  'analysis_mistake',
  'analysis_blunder',
  'analysis_other',
];

String evo2LedPatternLabel(String key) {
  return switch (key) {
    'empty' => 'Empty',
    'P' => 'White pawn',
    'N' => 'White knight',
    'B' => 'White bishop',
    'R' => 'White rook',
    'Q' => 'White queen',
    'K' => 'White king',
    'p' => 'Black pawn',
    'n' => 'Black knight',
    'b' => 'Black bishop',
    'r' => 'Black rook',
    'q' => 'Black queen',
    'k' => 'Black king',
    'analysis_best' => 'Analysis !!',
    'analysis_great' => 'Analysis !',
    'analysis_inaccuracy' => 'Analysis ?!',
    'analysis_mistake' => 'Analysis ?',
    'analysis_blunder' => 'Analysis ??',
    'analysis_other' => 'Analysis other',
    _ => key,
  };
}

String evo2LedPatternShortLabel(String key) {
  return switch (key) {
    'empty' => 'Blank',
    'analysis_best' => '!!',
    'analysis_great' => '!',
    'analysis_inaccuracy' => '?!',
    'analysis_mistake' => '?',
    'analysis_blunder' => '??',
    'analysis_other' => 'Other',
    _ => key,
  };
}

const List<int> _emptyEvo2LedPatternColors = [
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
];

Map<String, Evo2LedPattern> _normalizePatterns(
  Map<String, Evo2LedPattern> patterns,
) {
  return Map<String, Evo2LedPattern>.unmodifiable({
    for (final key in evo2LedPatternKeys)
      key: patterns[key] ?? Evo2LedPatternSet.defaults.patternFor(key),
  });
}

List<int> _normalizeColors(List<int> colors) {
  final normalized = List<int>.filled(evo2LedPatternCellCount, 0);
  for (var i = 0; i < normalized.length && i < colors.length; i += 1) {
    normalized[i] = _normalizeColor(colors[i]);
  }
  return List<int>.unmodifiable(normalized);
}

int _normalizeColor(int color) {
  return color.clamp(0, 0xffffff).toInt();
}

int? _colorFromJson(Object? value) {
  if (value is int) return _normalizeColor(value);
  if (value is num) return _normalizeColor(value.toInt());
  if (value is String) {
    final trimmed = value.trim();
    final hex = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return _normalizeColor(parsed);
  }
  return null;
}

Evo2LedPattern _defaultEvo2PatternFor(String key) {
  final marker = _defaultEvo2AnalysisMarkerPatternRows[key];
  if (marker != null) return _patternFromRows(marker.$1, marker.$2);
  if (key == 'empty') return _patternFromColors(_defaultEvo2EmptyPatternColors);
  final piece = key.toUpperCase();
  final color = key == piece ? 0xffffff : 0x4db6ff;
  final rows = _defaultEvo2WhitePiecePatternRows[piece] ??
      _defaultEvo2WhitePiecePatternRows['P']!;
  return _patternFromRows(rows, color);
}

const List<int> _defaultEvo2EmptyPatternColors = [
  0xff3b30,
  0xff3b30,
  0xff3b30,
  0xff3b30,
  0xff3b30,
  0xff3b30,
  0xff3b30,
  0xff3b30,
  0x000000,
  0x000000,
  0x000000,
  0x000000,
  0x000000,
  0xff3b30,
  0xff3b30,
  0x000000,
  0x000000,
  0x000000,
  0x000000,
  0x000000,
  0xff3b30,
  0xff3b30,
  0x000000,
  0x000000,
  0x000000,
  0x000000,
  0x000000,
  0xff3b30,
  0xff3b30,
  0x000000,
  0x000000,
  0x000000,
  0x000000,
  0x000000,
  0xff3b30,
  0xff3b30,
  0x000000,
  0x000000,
  0x000000,
  0x000000,
  0x000000,
  0xff3b30,
  0xff3b30,
  0xff3b30,
  0xff3b30,
  0xff3b30,
  0xff3b30,
  0xff3b30,
  0xff3b30,
];

const Map<String, List<String>> _defaultEvo2WhitePiecePatternRows = {
  'P': [
    '.......',
    '..###..',
    '..###..',
    '..###..',
    '...#...',
    '..###..',
    '.#####.',
  ],
  'N': [
    '..#....',
    '..###..',
    '.#####.',
    '.##.##.',
    '....##.',
    '..####.',
    '.####..',
  ],
  'B': [
    '...#...',
    '..###..',
    '.##.##.',
    '.##.##.',
    '..###..',
    '..###..',
    '.#####.',
  ],
  'R': [
    '.#.#.#.',
    '.#####.',
    '.#####.',
    '..###..',
    '..###..',
    '.#####.',
    '.#####.',
  ],
  'Q': [
    '...#...',
    '.#.#.#.',
    '.#####.',
    '#.###.#',
    '.#####.',
    '..###..',
    '.#####.',
  ],
  'K': [
    '...#...',
    '..###..',
    '...#...',
    '.#####.',
    '.#.#.#.',
    '.#####.',
    '..###..',
  ],
};

const Map<String, (List<String>, int)> _defaultEvo2AnalysisMarkerPatternRows = {
  'analysis_best': (
    [
      '##.##..',
      '##.##..',
      '##.##..',
      '##.##..',
      '.......',
      '##.##..',
      '##.##..',
    ],
    0xa3e635,
  ),
  'analysis_great': (
    [
      '...#...',
      '...#...',
      '...#...',
      '...#...',
      '.......',
      '...#...',
      '...#...',
    ],
    0x22d3ee,
  ),
  'analysis_inaccuracy': (
    [
      '.###.#.',
      '#...#.#',
      '....#.#',
      '...#.#.',
      '..#....',
      '.......',
      '..#.#..',
    ],
    0xeac84a,
  ),
  'analysis_mistake': (
    [
      '.###...',
      '#...#..',
      '....#..',
      '...#...',
      '..#....',
      '.......',
      '..#....',
    ],
    0xf0a252,
  ),
  'analysis_blunder': (
    [
      '.###.##',
      '#...###',
      '....###',
      '...#.##',
      '..#....',
      '.......',
      '..#.##.',
    ],
    0xe2574c,
  ),
  'analysis_other': (
    [
      '.......',
      '.......',
      '.......',
      '...#...',
      '.......',
      '.......',
      '.......',
    ],
    0x94a3b8,
  ),
};

Evo2LedPattern _patternFromColors(List<int> colors) {
  return Evo2LedPattern(colors: colors);
}

Evo2LedPattern _patternFromRows(List<String> rows, int color) {
  final colors = <int>[];
  for (var row = 0; row < evo2LedPatternSize; row += 1) {
    final line = row < rows.length ? rows[row] : '';
    for (var col = 0; col < evo2LedPatternSize; col += 1) {
      colors.add(col < line.length && line[col] != '.' ? color : 0);
    }
  }
  return Evo2LedPattern(colors: colors);
}

enum ClockSwitchAutomationMode {
  off,
  opponentMoveOnly,
  bothSides;

  String get storageKey {
    return switch (this) {
      ClockSwitchAutomationMode.off => 'off',
      ClockSwitchAutomationMode.opponentMoveOnly => 'opponent_move_only',
      ClockSwitchAutomationMode.bothSides => 'both_sides',
    };
  }

  static ClockSwitchAutomationMode fromStorage(
    Object? value, {
    required bool legacyClockSwitch,
  }) {
    return switch (value?.toString()) {
      'off' => ClockSwitchAutomationMode.off,
      'opponent_move_only' => ClockSwitchAutomationMode.opponentMoveOnly,
      'both_sides' => ClockSwitchAutomationMode.bothSides,
      _ => legacyClockSwitch
          ? ClockSwitchAutomationMode.bothSides
          : ClockSwitchAutomationMode.off,
    };
  }
}

enum ClockSwitchOpponentTiming {
  aggressive,
  leisure;

  String get storageKey {
    return switch (this) {
      ClockSwitchOpponentTiming.aggressive => 'aggressive',
      ClockSwitchOpponentTiming.leisure => 'leisure',
    };
  }

  static ClockSwitchOpponentTiming fromStorage(Object? value) {
    return switch (value?.toString()) {
      'leisure' => ClockSwitchOpponentTiming.leisure,
      _ => ClockSwitchOpponentTiming.aggressive,
    };
  }
}

enum ChessComMoveControlMode {
  direct,
  web;

  String get storageKey {
    return switch (this) {
      ChessComMoveControlMode.direct => 'direct',
      ChessComMoveControlMode.web => 'web',
    };
  }

  static ChessComMoveControlMode fromStorage(Object? value) {
    return switch (value?.toString()) {
      'web' || 'webview' || 'web_control' => ChessComMoveControlMode.web,
      _ => ChessComMoveControlMode.direct,
    };
  }
}

enum VoiceMoveRecognitionMode {
  online;

  String get storageKey {
    return switch (this) {
      VoiceMoveRecognitionMode.online => 'online',
    };
  }

  static VoiceMoveRecognitionMode fromStorage(Object? value) {
    return VoiceMoveRecognitionMode.online;
  }
}

class BoardSettingsState {
  const BoardSettingsState({
    this.globalBeep = true,
    this.connectBeep = true,
    this.startGameBeep = true,
    this.checkmateBeep = true,
    this.piecePositionLed = true,
    this.evaluateLed = true,
    this.showScorebar = true,
    this.showLegalMoves = true,
    this.chessComShowLegalMoves = true,
    this.allowTakeback = true,
    this.allowFlip = true,
    this.autoFlip = true,
    this.clockSwitchAutomation = ClockSwitchAutomationMode.bothSides,
    this.clockSwitchOpponentTiming = ClockSwitchOpponentTiming.aggressive,
    this.submitMoveOnClockSwitch = false,
    this.chessComMoveControlMode = ChessComMoveControlMode.direct,
    this.voiceMovesEnabled = false,
    this.voiceMoveRecognitionMode = VoiceMoveRecognitionMode.online,
    this.voiceMoveLanguage = AppLanguagePreference.system,
    this.fenDelayMs = 800,
    this.moveRestoreDelayMs = 2000,
    this.evo2LedBrightness = 100,
    Evo2LedPatternSet? evo2LedPatterns,
  }) : _evo2LedPatterns = evo2LedPatterns;

  final bool globalBeep;
  final bool connectBeep;
  final bool startGameBeep;
  final bool checkmateBeep;
  final bool piecePositionLed;
  final bool evaluateLed;
  final bool showScorebar;
  final bool showLegalMoves;
  final bool chessComShowLegalMoves;
  final bool allowTakeback;
  final bool allowFlip;
  final bool autoFlip;
  final ClockSwitchAutomationMode clockSwitchAutomation;
  final ClockSwitchOpponentTiming clockSwitchOpponentTiming;
  final bool submitMoveOnClockSwitch;
  final ChessComMoveControlMode chessComMoveControlMode;
  final bool voiceMovesEnabled;
  final VoiceMoveRecognitionMode voiceMoveRecognitionMode;
  final AppLanguagePreference voiceMoveLanguage;
  final int fenDelayMs;
  final int moveRestoreDelayMs;
  final int evo2LedBrightness;
  final Evo2LedPatternSet? _evo2LedPatterns;

  bool get clockSwitch =>
      clockSwitchAutomation != ClockSwitchAutomationMode.off;
  bool get effectiveConnectBeep => globalBeep && connectBeep;
  bool get effectiveStartGameBeep => globalBeep && startGameBeep;
  bool get effectiveCheckmateBeep => globalBeep && checkmateBeep;
  bool get moveQualityLights => evaluateLed;
  Duration get fenDelay => Duration(milliseconds: fenDelayMs);
  Duration get moveRestoreDelay => Duration(milliseconds: moveRestoreDelayMs);
  Evo2LedPatternSet get evo2LedPatterns =>
      _evo2LedPatterns ?? Evo2LedPatternSet.defaults;

  BoardSettingsState copyWith({
    bool? globalBeep,
    bool? connectBeep,
    bool? startGameBeep,
    bool? checkmateBeep,
    bool? piecePositionLed,
    bool? evaluateLed,
    bool? showScorebar,
    bool? showLegalMoves,
    bool? chessComShowLegalMoves,
    bool? allowTakeback,
    bool? allowFlip,
    bool? autoFlip,
    bool? clockSwitch,
    ClockSwitchAutomationMode? clockSwitchAutomation,
    ClockSwitchOpponentTiming? clockSwitchOpponentTiming,
    bool? submitMoveOnClockSwitch,
    ChessComMoveControlMode? chessComMoveControlMode,
    bool? voiceMovesEnabled,
    VoiceMoveRecognitionMode? voiceMoveRecognitionMode,
    AppLanguagePreference? voiceMoveLanguage,
    int? fenDelayMs,
    int? moveRestoreDelayMs,
    int? evo2LedBrightness,
    Evo2LedPatternSet? evo2LedPatterns,
  }) {
    final nextClockSwitchAutomation = clockSwitchAutomation ??
        (clockSwitch == null
            ? this.clockSwitchAutomation
            : (clockSwitch
                ? ClockSwitchAutomationMode.bothSides
                : ClockSwitchAutomationMode.off));
    return BoardSettingsState(
      globalBeep: globalBeep ?? this.globalBeep,
      connectBeep: connectBeep ?? this.connectBeep,
      startGameBeep: startGameBeep ?? this.startGameBeep,
      checkmateBeep: checkmateBeep ?? this.checkmateBeep,
      piecePositionLed: piecePositionLed ?? this.piecePositionLed,
      evaluateLed: evaluateLed ?? this.evaluateLed,
      showScorebar: showScorebar ?? this.showScorebar,
      showLegalMoves: showLegalMoves ?? this.showLegalMoves,
      chessComShowLegalMoves:
          chessComShowLegalMoves ?? this.chessComShowLegalMoves,
      allowTakeback: allowTakeback ?? this.allowTakeback,
      allowFlip: allowFlip ?? this.allowFlip,
      autoFlip: autoFlip ?? this.autoFlip,
      clockSwitchAutomation: nextClockSwitchAutomation,
      clockSwitchOpponentTiming:
          clockSwitchOpponentTiming ?? this.clockSwitchOpponentTiming,
      submitMoveOnClockSwitch:
          submitMoveOnClockSwitch ?? this.submitMoveOnClockSwitch,
      chessComMoveControlMode:
          chessComMoveControlMode ?? this.chessComMoveControlMode,
      voiceMovesEnabled: voiceMovesEnabled ?? this.voiceMovesEnabled,
      voiceMoveRecognitionMode:
          voiceMoveRecognitionMode ?? this.voiceMoveRecognitionMode,
      voiceMoveLanguage: voiceMoveLanguage ?? this.voiceMoveLanguage,
      fenDelayMs: fenDelayMs ?? this.fenDelayMs,
      moveRestoreDelayMs: moveRestoreDelayMs ?? this.moveRestoreDelayMs,
      evo2LedBrightness: evo2LedBrightness ?? this.evo2LedBrightness,
      evo2LedPatterns: evo2LedPatterns ?? this.evo2LedPatterns,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'global_beep': globalBeep,
      'connect_beep': connectBeep,
      'start_game_beep': startGameBeep,
      'checkmate_beep': checkmateBeep,
      'piece_position_led': piecePositionLed,
      'evaluate_led': evaluateLed,
      'show_scorebar': showScorebar,
      'show_legal_moves': showLegalMoves,
      'chesscom_show_legal_moves': chessComShowLegalMoves,
      'allow_takeback': allowTakeback,
      'allow_flip': allowFlip,
      'auto_flip': autoFlip,
      'clock_switch': clockSwitch,
      'clock_switch_automation': clockSwitchAutomation.storageKey,
      'clock_switch_opponent_timing': clockSwitchOpponentTiming.storageKey,
      'submit_move_on_clock_switch': submitMoveOnClockSwitch,
      'chesscom_move_control_mode': chessComMoveControlMode.storageKey,
      'voice_move_language': voiceMoveLanguage.tag,
      'fen_delay_ms': fenDelayMs,
      'move_restore_delay_ms': moveRestoreDelayMs,
      'evo2_led_brightness': evo2LedBrightness,
      'evo2_led_patterns': evo2LedPatterns.toJson(),
    };
  }

  factory BoardSettingsState.fromJson(Map<String, dynamic> json) {
    const defaults = BoardSettingsState();
    return BoardSettingsState(
      globalBeep: _bool(json['global_beep'], defaults.globalBeep),
      connectBeep: _bool(json['connect_beep'], defaults.connectBeep),
      startGameBeep: _bool(json['start_game_beep'], defaults.startGameBeep),
      checkmateBeep: _bool(json['checkmate_beep'], defaults.checkmateBeep),
      piecePositionLed:
          _bool(json['piece_position_led'], defaults.piecePositionLed),
      evaluateLed: _bool(json['evaluate_led'], defaults.evaluateLed),
      showScorebar: _bool(json['show_scorebar'], defaults.showScorebar),
      showLegalMoves: _bool(json['show_legal_moves'], defaults.showLegalMoves),
      chessComShowLegalMoves: _bool(
        json['chesscom_show_legal_moves'],
        defaults.chessComShowLegalMoves,
      ),
      allowTakeback: _bool(json['allow_takeback'], defaults.allowTakeback),
      allowFlip: _bool(json['allow_flip'], defaults.allowFlip),
      autoFlip: _bool(json['auto_flip'], defaults.autoFlip),
      clockSwitchAutomation: ClockSwitchAutomationMode.fromStorage(
        json['clock_switch_automation'],
        legacyClockSwitch: _bool(json['clock_switch'], defaults.clockSwitch),
      ),
      clockSwitchOpponentTiming: ClockSwitchOpponentTiming.fromStorage(
        json['clock_switch_opponent_timing'],
      ),
      submitMoveOnClockSwitch: _bool(
        json['submit_move_on_clock_switch'],
        defaults.submitMoveOnClockSwitch,
      ),
      chessComMoveControlMode: ChessComMoveControlMode.fromStorage(
        json['chesscom_move_control_mode'],
      ),
      voiceMovesEnabled: false,
      voiceMoveRecognitionMode: VoiceMoveRecognitionMode.fromStorage(
        json['voice_move_recognition_mode'],
      ),
      voiceMoveLanguage: AppLanguagePreference.fromTag(
        json['voice_move_language']?.toString(),
      ),
      fenDelayMs: _int(json['fen_delay_ms'], defaults.fenDelayMs, 0, 3000),
      moveRestoreDelayMs: _int(
        json['move_restore_delay_ms'],
        defaults.moveRestoreDelayMs,
        250,
        5000,
      ),
      evo2LedBrightness: _int(
        json['evo2_led_brightness'],
        defaults.evo2LedBrightness,
        0,
        100,
      ),
      evo2LedPatterns: Evo2LedPatternSet.fromJson(json['evo2_led_patterns']),
    );
  }
}

abstract class BoardSettingsStore {
  Future<BoardSettingsState> read();

  Future<void> write(BoardSettingsState settings);
}

class BoardFenStabilityBuffer {
  BoardFenStabilityBuffer({
    required this.onStableFen,
  });

  final void Function(String fen) onStableFen;
  String? _candidateFen;
  String? _lastStableFen;
  int _candidateCount = 0;

  void add(String fen) {
    if (_candidateFen == fen) {
      _candidateCount += 1;
    } else {
      _candidateFen = fen;
      _candidateCount = 1;
    }

    if (_candidateCount >= 2 && _lastStableFen != fen) {
      _lastStableFen = fen;
      onStableFen(fen);
    }
  }

  void cancelPending() {
    _candidateFen = null;
    _candidateCount = 0;
  }

  void reset() {
    cancelPending();
    _lastStableFen = null;
  }

  void dispose() {
    cancelPending();
  }
}

bool _bool(Object? value, bool fallback) {
  return value is bool ? value : fallback;
}

int _int(Object? value, int fallback, int min, int max) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  return (parsed ?? fallback).clamp(min, max);
}
