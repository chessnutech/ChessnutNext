import 'package:chessnut_flutter_export/l10n/app_language.dart';
import 'package:chessnut_flutter_export/services/board_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migrates legacy clock switch bool into automation mode', () {
    final enabled = BoardSettingsState.fromJson(const {
      'clock_switch': true,
    });
    final disabled = BoardSettingsState.fromJson(const {
      'clock_switch': false,
    });

    expect(enabled.clockSwitchAutomation, ClockSwitchAutomationMode.bothSides);
    expect(enabled.clockSwitch, isTrue);
    expect(disabled.clockSwitchAutomation, ClockSwitchAutomationMode.off);
    expect(disabled.clockSwitch, isFalse);
  });

  test('serializes clock switch automation and confirm settings', () {
    const settings = BoardSettingsState(
      clockSwitchAutomation: ClockSwitchAutomationMode.opponentMoveOnly,
      clockSwitchOpponentTiming: ClockSwitchOpponentTiming.leisure,
      submitMoveOnClockSwitch: true,
    );

    expect(settings.clockSwitch, isTrue);
    expect(settings.toJson(), containsPair('clock_switch', true));
    expect(
      settings.toJson(),
      containsPair('clock_switch_automation', 'opponent_move_only'),
    );
    expect(
      settings.toJson(),
      containsPair('clock_switch_opponent_timing', 'leisure'),
    );
    expect(
        settings.toJson(), containsPair('submit_move_on_clock_switch', true));

    final decoded = BoardSettingsState.fromJson(settings.toJson());
    expect(
      decoded.clockSwitchAutomation,
      ClockSwitchAutomationMode.opponentMoveOnly,
    );
    expect(
      decoded.clockSwitchOpponentTiming,
      ClockSwitchOpponentTiming.leisure,
    );
    expect(decoded.submitMoveOnClockSwitch, isTrue);
  });

  test('serializes game option display preferences', () {
    const settings = BoardSettingsState(
      showScorebar: false,
      showLegalMoves: false,
      chessComShowLegalMoves: false,
    );

    expect(settings.toJson(), containsPair('show_scorebar', false));
    expect(settings.toJson(), containsPair('show_legal_moves', false));
    expect(
      settings.toJson(),
      containsPair('chesscom_show_legal_moves', false),
    );

    final decoded = BoardSettingsState.fromJson(settings.toJson());
    expect(decoded.showScorebar, isFalse);
    expect(decoded.showLegalMoves, isFalse);
    expect(decoded.chessComShowLegalMoves, isFalse);
  });

  test('defaults opponent clock timing to aggressive mode', () {
    const settings = BoardSettingsState();
    expect(
      settings.clockSwitchOpponentTiming,
      ClockSwitchOpponentTiming.aggressive,
    );
    expect(
      BoardSettingsState.fromJson(const {}).clockSwitchOpponentTiming,
      ClockSwitchOpponentTiming.aggressive,
    );
  });

  test('stores Chess.com move control preference', () {
    const defaults = BoardSettingsState();
    expect(defaults.chessComMoveControlMode, ChessComMoveControlMode.direct);

    const settings = BoardSettingsState(
      chessComMoveControlMode: ChessComMoveControlMode.web,
    );

    expect(
      settings.toJson(),
      containsPair('chesscom_move_control_mode', 'web'),
    );
    expect(
      BoardSettingsState.fromJson(settings.toJson()).chessComMoveControlMode,
      ChessComMoveControlMode.web,
    );
    expect(
      BoardSettingsState.fromJson(
        const {'chesscom_move_control_mode': 'webview'},
      ).chessComMoveControlMode,
      ChessComMoveControlMode.web,
    );
  });

  test('stores Chessnut Move speech language and forces online recognition',
      () {
    const defaults = BoardSettingsState();
    expect(defaults.voiceMovesEnabled, isFalse);
    expect(
      defaults.voiceMoveRecognitionMode,
      VoiceMoveRecognitionMode.online,
    );
    expect(defaults.voiceMoveLanguage, AppLanguagePreference.system);

    const settings = BoardSettingsState(
      voiceMovesEnabled: true,
      voiceMoveRecognitionMode: VoiceMoveRecognitionMode.online,
      voiceMoveLanguage: AppLanguagePreference.zhHant,
    );

    expect(settings.toJson(), isNot(contains('voice_moves_enabled')));
    expect(settings.toJson(), isNot(contains('voice_move_recognition_mode')));
    expect(settings.toJson(), containsPair('voice_move_language', 'zh-Hant'));
    expect(
      BoardSettingsState.fromJson(settings.toJson()).voiceMovesEnabled,
      isFalse,
    );
    expect(
      BoardSettingsState.fromJson(const {
        'voice_moves_enabled': true,
        'voice_move_recognition_mode': 'local',
      }).voiceMovesEnabled,
      isFalse,
    );
    expect(
      BoardSettingsState.fromJson(const {
        'voice_move_recognition_mode': 'local',
      }).voiceMoveRecognitionMode,
      VoiceMoveRecognitionMode.online,
    );
    expect(
      BoardSettingsState.fromJson(settings.toJson()).voiceMoveRecognitionMode,
      VoiceMoveRecognitionMode.online,
    );
    expect(
      BoardSettingsState.fromJson(settings.toJson()).voiceMoveLanguage,
      AppLanguagePreference.zhHant,
    );
  });

  test('stores EVO2 LED patterns', () {
    final customPawn = Evo2LedPattern(
      colors: [
        0xff0000,
        ...List<int>.filled(evo2LedPatternCellCount - 1, 0),
      ],
    );
    final customAnalysisMarker = Evo2LedPattern(
      colors: [
        0x00ff00,
        ...List<int>.filled(evo2LedPatternCellCount - 1, 0),
      ],
    );
    final settings = BoardSettingsState(
      evo2LedPatterns: Evo2LedPatternSet.defaults
          .copyWithPattern('P', customPawn)
          .copyWithPattern('analysis_best', customAnalysisMarker),
    );

    final json = settings.toJson();
    final patternJson = json['evo2_led_patterns'] as Map<String, dynamic>;

    expect(patternJson['P'], isA<List<int>>());
    expect((patternJson['P'] as List<int>).first, 0xff0000);
    expect(patternJson['analysis_best'], isA<List<int>>());
    expect(
      (patternJson['analysis_best'] as List<int>).first,
      0x00ff00,
    );

    final decoded = BoardSettingsState.fromJson(json);
    expect(decoded.evo2LedPatterns.patternFor('P'), customPawn);
    expect(
      decoded.evo2LedPatterns.patternFor('analysis_best'),
      customAnalysisMarker,
    );
    expect(
      decoded.evo2LedPatterns.patternFor('empty'),
      Evo2LedPatternSet.defaults.patternFor('empty'),
    );
  });

  test('stores and clamps EVO2 LED brightness', () {
    const settings = BoardSettingsState(evo2LedBrightness: 65);

    expect(settings.toJson(), containsPair('evo2_led_brightness', 65));
    expect(
      BoardSettingsState.fromJson(settings.toJson()).evo2LedBrightness,
      65,
    );
    expect(
      BoardSettingsState.fromJson(
        const {'evo2_led_brightness': 130},
      ).evo2LedBrightness,
      100,
    );
    expect(
      BoardSettingsState.fromJson(
        const {'evo2_led_brightness': -10},
      ).evo2LedBrightness,
      0,
    );
  });

  test('uses saved EVO2 artwork as default piece patterns', () {
    final defaults = Evo2LedPatternSet.defaults;
    expect(defaults.patternFor('empty').colors.first, 0xff3b30);
    expect(defaults.patternFor('P').colors, [
      0x000000,
      0x000000,
      0x000000,
      0x000000,
      0x000000,
      0x000000,
      0x000000,
      0x000000,
      0x000000,
      0xffffff,
      0xffffff,
      0xffffff,
      0x000000,
      0x000000,
      0x000000,
      0x000000,
      0xffffff,
      0xffffff,
      0xffffff,
      0x000000,
      0x000000,
      0x000000,
      0x000000,
      0xffffff,
      0xffffff,
      0xffffff,
      0x000000,
      0x000000,
      0x000000,
      0x000000,
      0x000000,
      0xffffff,
      0x000000,
      0x000000,
      0x000000,
      0x000000,
      0x000000,
      0xffffff,
      0xffffff,
      0xffffff,
      0x000000,
      0x000000,
      0x000000,
      0xffffff,
      0xffffff,
      0xffffff,
      0xffffff,
      0xffffff,
      0x000000,
    ]);
    expect(
      defaults.patternFor('p').colors,
      defaults
          .patternFor('P')
          .colors
          .map((color) => color == 0xffffff ? 0x4db6ff : color)
          .toList(growable: false),
    );
  });
}
