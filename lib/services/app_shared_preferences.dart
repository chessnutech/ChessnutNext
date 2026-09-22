import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_language.dart';
import '../theme/chessnut_theme.dart';
import 'evo2_display_service.dart';

/// Owns the single SharedPreferences instance used by the application.
///
/// Setting values are not cached. [get] reads the underlying typed value and
/// falls back to the default registered for the key. [set] issues exactly one
/// typed SharedPreferences write without waiting for its result.
abstract final class AppSharedPreferences {
  static SharedPreferences? _instance;

  static const defaultLanguagePreference = AppLanguagePreference.system;
  static const defaultThemeMode = ThemeMode.system;
  static const defaultVisualTheme = ChessnutVisualTheme.modern;
  static const defaultVisualEffectsEnabled = true;
  static const defaultAutoPerformanceApplied = false;
  static const defaultBoardCoordinatesEnabled = false;
  static const defaultKeepBoardConnectedInBackground = false;
  static const defaultEvo2ScreenOrientation = Evo2ScreenOrientation.rotation0;
  static const defaultSoundEffectsEnabled = true;
  static const defaultMoveAnnouncementEnabled = false;
  static const defaultVisionRecognitionOnly = false;
  static const defaultSoundFromTo = true;
  static const defaultSoundMove = true;
  static const defaultSoundResult = true;
  static const defaultSoundKeyAction = true;
  static const defaultStandardAnalysisDepth = 16;
  static const defaultCommentaryVoiceGender = 'female';

  static const Map<String, Object> _defaults = {
    AppSettingKeys.language: 'system',
    AppSettingKeys.themeMode: 'system',
    AppSettingKeys.visualTheme: 'modern',
    AppSettingKeys.visualEffectsEnabled: defaultVisualEffectsEnabled,
    AppSettingKeys.autoPerformanceApplied: defaultAutoPerformanceApplied,
    AppSettingKeys.boardCoordinatesEnabled: defaultBoardCoordinatesEnabled,
    AppSettingKeys.keepBoardConnectedInBackground:
        defaultKeepBoardConnectedInBackground,
    AppSettingKeys.evo2ScreenOrientation: 'rotation0',
    AppSettingKeys.soundEffectsEnabled: defaultSoundEffectsEnabled,
    AppSettingKeys.moveAnnouncementEnabled: defaultMoveAnnouncementEnabled,
    AppSettingKeys.visionRecognitionOnly: defaultVisionRecognitionOnly,
    AppSettingKeys.soundFromTo: defaultSoundFromTo,
    AppSettingKeys.soundMove: defaultSoundMove,
    AppSettingKeys.soundResult: defaultSoundResult,
    AppSettingKeys.soundKeyAction: defaultSoundKeyAction,
    AppSettingKeys.boardGlobalBeep: true,
    AppSettingKeys.boardConnectBeep: true,
    AppSettingKeys.boardStartGameBeep: true,
    AppSettingKeys.boardCheckmateBeep: true,
    AppSettingKeys.boardPiecePositionLed: true,
    AppSettingKeys.boardEvaluateLed: true,
    AppSettingKeys.boardShowScorebar: true,
    AppSettingKeys.boardShowLegalMoves: true,
    AppSettingKeys.boardAllowTakeback: true,
    AppSettingKeys.boardAllowFlip: true,
    AppSettingKeys.boardAutoFlip: true,
    AppSettingKeys.boardClockSwitchAutomation: 'both_sides',
    AppSettingKeys.boardClockSwitchOpponentTiming: 'aggressive',
    AppSettingKeys.boardSubmitMoveOnClockSwitch: false,
    AppSettingKeys.boardChessComMoveControlMode: 'direct',
    AppSettingKeys.boardVoiceMovesEnabled: false,
    AppSettingKeys.boardVoiceMoveRecognitionMode: 'online',
    AppSettingKeys.boardVoiceMoveLanguage: 'system',
    AppSettingKeys.boardFenDelayMs: 800,
    AppSettingKeys.boardMoveRestoreDelayMs: 2000,
    AppSettingKeys.boardEvo2LedBrightness: 100,
    AppSettingKeys.boardEvo2LedPatterns: '{}',
    AppSettingKeys.updateDeferredVersion: '',
    AppSettingKeys.updateDeferredUntil: '',
    AppSettingKeys.updateIgnoredVersion: '',
    AppSettingKeys.moduleGuideSeenIds: <String>[],
    AppSettingKeys.initialGuideAutoPromptCompleted: false,
    AppSettingKeys.reviewCompletedGames: 0,
    AppSettingKeys.reviewPositiveMoments: 0,
    AppSettingKeys.reviewPromptCount: 0,
    AppSettingKeys.reviewLastPromptedAt: '',
    AppSettingKeys.reviewLastPromptedVersion: '',
    AppSettingKeys.widgetVisionEnabled: false,
    AppSettingKeys.dismissedContinueRecordKeys: <String>[],
    AppSettingKeys.lastBotGameConfig: '',
    AppSettingKeys.userBotGameConfigs: '{}',
    AppSettingKeys.otbShowPgnList: true,
    AppSettingKeys.otbTimeMinutes: 10,
    AppSettingKeys.otbIncrementSeconds: 5,
    AppSettingKeys.otbCustomTimeSelected: false,
    AppSettingKeys.otbStartingPosition: 'standard',
    AppSettingKeys.otbOpeningId: 'italian',
    AppSettingKeys.otbBoardEditorFen: '',
    AppSettingKeys.favoriteOpeningIds: <String>[],
    AppSettingKeys.standardAnalysisDepth: defaultStandardAnalysisDepth,
    AppSettingKeys.commentaryVoiceGender: defaultCommentaryVoiceGender,
  };

  static SharedPreferences get _preferences {
    final preferences = _instance;
    if (preferences == null) {
      throw StateError('AppSharedPreferences has not been initialized.');
    }
    return preferences;
  }

  static Future<void> initialize() async {
    _instance ??= await SharedPreferences.getInstance();
  }

  static T get<T>(String key) {
    final defaultValue = _defaults[key];
    if (defaultValue == null) {
      throw ArgumentError.value(key, 'key', 'No default value registered');
    }
    final Object? savedValue = switch (defaultValue) {
      bool _ => _preferences.getBool(key),
      int _ => _preferences.getInt(key),
      double _ => _preferences.getDouble(key),
      String _ => _preferences.getString(key),
      List<String> _ => _preferences.getStringList(key),
      _ => throw StateError('Unsupported default type for $key'),
    };
    final value = savedValue ?? defaultValue;
    if (value is! T) {
      throw StateError('Setting $key is not of type $T');
    }
    return value as T;
  }

  static void set<T>(String key, T value) {
    final defaultValue = _defaults[key];
    if (defaultValue == null) {
      throw ArgumentError.value(key, 'key', 'No default value registered');
    }
    if (value.runtimeType != defaultValue.runtimeType &&
        !(value is List<String> && defaultValue is List<String>)) {
      throw ArgumentError.value(value, key, 'Unexpected setting type');
    }
    if (_sameValue(get<Object>(key), value)) return;
    final write = switch (value) {
      bool value => _preferences.setBool(key, value),
      int value => _preferences.setInt(key, value),
      double value => _preferences.setDouble(key, value),
      String value => _preferences.setString(key, value),
      List<String> value => _preferences.setStringList(key, value),
      _ => throw ArgumentError.value(value, key, 'Unsupported setting type'),
    };
    unawaited(write);
  }

  static bool _sameValue(Object current, Object? next) {
    if (current is List<String> && next is List<String>) {
      return listEquals(current, next);
    }
    return current == next;
  }

  static bool containsKey(String key) => _preferences.containsKey(key);

  @visibleForTesting
  static SharedPreferences get instance => _preferences;

  @visibleForTesting
  static void useInstanceForTesting(SharedPreferences preferences) {
    _instance = preferences;
  }
}

abstract final class AppSettingKeys {
  static const language = 'app_settings.language';
  static const themeMode = 'app_settings.theme_mode';
  static const visualTheme = 'app_settings.visual_theme';
  static const visualEffectsEnabled = 'app_settings.visual_effects_enabled';
  static const autoPerformanceApplied = 'app_settings.auto_performance_applied';
  static const boardCoordinatesEnabled =
      'app_settings.board_coordinates_enabled';
  static const keepBoardConnectedInBackground =
      'app_settings.keep_board_connected_in_background';
  static const evo2ScreenOrientation = 'app_settings.evo2_screen_orientation';
  static const soundEffectsEnabled = 'app_settings.sound_effects_enabled';
  static const moveAnnouncementEnabled =
      'app_settings.move_announcement_enabled';
  static const visionRecognitionOnly = 'vision.recognition_only';
  static const soundFromTo = 'app_settings.sound.from_to';
  static const soundMove = 'app_settings.sound.move';
  static const soundResult = 'app_settings.sound.result';
  static const soundKeyAction = 'app_settings.sound.key_action';
  static const boardGlobalBeep = 'board_settings.global_beep';
  static const boardConnectBeep = 'board_settings.connect_beep';
  static const boardStartGameBeep = 'board_settings.start_game_beep';
  static const boardCheckmateBeep = 'board_settings.checkmate_beep';
  static const boardPiecePositionLed = 'board_settings.piece_position_led';
  static const boardEvaluateLed = 'board_settings.evaluate_led';
  static const boardShowScorebar = 'board_settings.show_scorebar';
  static const boardShowLegalMoves = 'board_settings.show_legal_moves';
  static const boardAllowTakeback = 'board_settings.allow_takeback';
  static const boardAllowFlip = 'board_settings.allow_flip';
  static const boardAutoFlip = 'board_settings.auto_flip';
  static const boardClockSwitchAutomation =
      'board_settings.clock_switch_automation';
  static const boardClockSwitchOpponentTiming =
      'board_settings.clock_switch_opponent_timing';
  static const boardSubmitMoveOnClockSwitch =
      'board_settings.submit_move_on_clock_switch';
  static const boardChessComMoveControlMode =
      'board_settings.chesscom_move_control_mode';
  static const boardVoiceMovesEnabled = 'board_settings.voice_moves_enabled';
  static const boardVoiceMoveRecognitionMode =
      'board_settings.voice_move_recognition_mode';
  static const boardVoiceMoveLanguage = 'board_settings.voice_move_language';
  static const boardFenDelayMs = 'board_settings.fen_delay_ms';
  static const boardMoveRestoreDelayMs = 'board_settings.move_restore_delay_ms';
  static const boardEvo2LedBrightness = 'board_settings.evo2_led_brightness';
  static const boardEvo2LedPatterns = 'board_settings.evo2_led_patterns';
  static const updateDeferredVersion = 'app_update.deferred_version';
  static const updateDeferredUntil = 'app_update.deferred_until';
  static const updateIgnoredVersion = 'app_update.ignored_version';
  static const moduleGuideSeenIds = 'module_guides.seen_ids';
  static const initialGuideAutoPromptCompleted =
      'module_guides.initial_auto_prompt_completed';
  static const reviewCompletedGames = 'review_prompt.completed_games';
  static const reviewPositiveMoments = 'review_prompt.positive_moments';
  static const reviewPromptCount = 'review_prompt.prompt_count';
  static const reviewLastPromptedAt = 'review_prompt.last_prompted_at';
  static const reviewLastPromptedVersion =
      'review_prompt.last_prompted_version';
  static const widgetVisionEnabled = 'home_widget.vision_enabled';
  static const dismissedContinueRecordKeys = 'continue_records.dismissed_keys';
  static const lastBotGameConfig = 'bot_game.last_config';
  static const userBotGameConfigs = 'bot_game.user_configs';
  static const otbShowPgnList = 'otb_game.show_pgn_list';
  static const otbTimeMinutes = 'otb_game.time_minutes';
  static const otbIncrementSeconds = 'otb_game.increment_seconds';
  static const otbCustomTimeSelected = 'otb_game.custom_time_selected';
  static const otbStartingPosition = 'otb_game.starting_position';
  static const otbOpeningId = 'otb_game.opening_id';
  static const otbBoardEditorFen = 'otb_game.board_editor_fen';
  static const favoriteOpeningIds = 'openings.favorite_ids';
  static const standardAnalysisDepth = 'analysis.standard_depth';
  static const commentaryVoiceGender = 'analysis.commentary_voice_gender';
}
