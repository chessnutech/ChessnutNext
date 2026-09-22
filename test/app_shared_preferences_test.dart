import 'dart:convert';

import 'package:chessnut_flutter_export/l10n/app_language.dart';
import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/services/app_preferences_store.dart';
import 'package:chessnut_flutter_export/services/app_shared_preferences.dart';
import 'package:chessnut_flutter_export/services/board_settings_service.dart';
import 'package:chessnut_flutter_export/services/review_prompt_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppSharedPreferences.useInstanceForTesting(
      await SharedPreferences.getInstance(),
    );
  });

  test('reads and writes independent keys through the unified interface', () {
    AppSharedPreferences.set(AppSettingKeys.themeMode, 'dark');
    AppSharedPreferences.set(AppSettingKeys.visualEffectsEnabled, false);
    AppSharedPreferences.set(AppSettingKeys.standardAnalysisDepth, 20);

    expect(
      AppSharedPreferences.get<String>(AppSettingKeys.themeMode),
      'dark',
    );
    expect(
      AppSharedPreferences.get<bool>(AppSettingKeys.visualEffectsEnabled),
      isFalse,
    );
    expect(
      AppSharedPreferences.get<int>(AppSettingKeys.standardAnalysisDepth),
      20,
    );
    expect(
      AppSharedPreferences.containsKey(AppSettingKeys.visualTheme),
      isFalse,
    );
  });

  test('stores every app settings page value through independent keys', () {
    AppSharedPreferences.set(AppSettingKeys.language, 'ja');
    AppSharedPreferences.set(AppSettingKeys.themeMode, 'dark');
    AppSharedPreferences.set(AppSettingKeys.visualTheme, 'classic');
    AppSharedPreferences.set(AppSettingKeys.visualEffectsEnabled, false);
    AppSharedPreferences.set(AppSettingKeys.boardCoordinatesEnabled, true);
    AppSharedPreferences.set(
      AppSettingKeys.keepBoardConnectedInBackground,
      true,
    );
    AppSharedPreferences.set(
      AppSettingKeys.evo2ScreenOrientation,
      'rotation180',
    );
    AppSharedPreferences.set(AppSettingKeys.soundEffectsEnabled, false);
    AppSharedPreferences.set(AppSettingKeys.moveAnnouncementEnabled, true);
    AppSharedPreferences.set(AppSettingKeys.visionRecognitionOnly, true);
    AppSharedPreferences.set(AppSettingKeys.soundFromTo, false);
    AppSharedPreferences.set(AppSettingKeys.soundMove, false);
    AppSharedPreferences.set(AppSettingKeys.soundResult, false);
    AppSharedPreferences.set(AppSettingKeys.soundKeyAction, false);

    expect(AppSharedPreferences.get<String>(AppSettingKeys.language), 'ja');
    expect(AppSharedPreferences.get<String>(AppSettingKeys.themeMode), 'dark');
    expect(
      AppSharedPreferences.get<String>(AppSettingKeys.visualTheme),
      'classic',
    );
    expect(
      AppSharedPreferences.get<bool>(AppSettingKeys.visualEffectsEnabled),
      isFalse,
    );
    expect(
      AppSharedPreferences.get<bool>(AppSettingKeys.boardCoordinatesEnabled),
      isTrue,
    );
    expect(
      AppSharedPreferences.get<bool>(
        AppSettingKeys.keepBoardConnectedInBackground,
      ),
      isTrue,
    );
    expect(
      AppSharedPreferences.get<String>(
        AppSettingKeys.evo2ScreenOrientation,
      ),
      'rotation180',
    );
    expect(
      AppSharedPreferences.get<bool>(AppSettingKeys.soundEffectsEnabled),
      isFalse,
    );
    expect(
      AppSharedPreferences.get<bool>(AppSettingKeys.moveAnnouncementEnabled),
      isTrue,
    );
    expect(
      AppSharedPreferences.get<bool>(AppSettingKeys.visionRecognitionOnly),
      isTrue,
    );
    expect(
      AppSharedPreferences.get<bool>(AppSettingKeys.soundFromTo),
      isFalse,
    );
    expect(
      AppSharedPreferences.get<bool>(AppSettingKeys.soundMove),
      isFalse,
    );
    expect(
      AppSharedPreferences.get<bool>(AppSettingKeys.soundResult),
      isFalse,
    );
    expect(
      AppSharedPreferences.get<bool>(AppSettingKeys.soundKeyAction),
      isFalse,
    );
  });

  test('uses centralized defaults when setting keys have no saved value', () {
    expect(
      AppSharedPreferences.get<String>(AppSettingKeys.language),
      AppSharedPreferences.defaultLanguagePreference.tag,
    );
    expect(
      AppSharedPreferences.get<String>(AppSettingKeys.themeMode),
      AppSharedPreferences.defaultThemeMode.name,
    );
    expect(
      AppSharedPreferences.get<String>(AppSettingKeys.visualTheme),
      AppSharedPreferences.defaultVisualTheme.name,
    );
    expect(
      AppSharedPreferences.get<bool>(AppSettingKeys.visualEffectsEnabled),
      isTrue,
    );
    expect(
      AppSharedPreferences.get<bool>(AppSettingKeys.autoPerformanceApplied),
      isFalse,
    );
    expect(
      AppSharedPreferences.get<bool>(AppSettingKeys.boardCoordinatesEnabled),
      isFalse,
    );
    expect(
      AppSharedPreferences.get<bool>(
        AppSettingKeys.keepBoardConnectedInBackground,
      ),
      isFalse,
    );
    expect(
      AppSharedPreferences.get<bool>(AppSettingKeys.visionRecognitionOnly),
      AppSharedPreferences.defaultVisionRecognitionOnly,
    );
    expect(
      AppSharedPreferences.get<String>(
        AppSettingKeys.evo2ScreenOrientation,
      ),
      AppSharedPreferences.defaultEvo2ScreenOrientation.storageKey,
    );
    expect(
      AppSharedPreferences.get<bool>(AppSettingKeys.soundEffectsEnabled),
      isTrue,
    );
    expect(
      AppSharedPreferences.get<bool>(AppSettingKeys.moveAnnouncementEnabled),
      isFalse,
    );
    expect(
      AppSharedPreferences.get<bool>(AppSettingKeys.soundFromTo),
      isTrue,
    );
    expect(
      AppSharedPreferences.get<bool>(AppSettingKeys.soundMove),
      isTrue,
    );
    expect(
      AppSharedPreferences.get<bool>(AppSettingKeys.soundResult),
      isTrue,
    );
    expect(
      AppSharedPreferences.get<bool>(AppSettingKeys.soundKeyAction),
      isTrue,
    );
    expect(
      AppSharedPreferences.get<bool>(AppSettingKeys.boardGlobalBeep),
      isTrue,
    );
    expect(
      AppSharedPreferences.get<int>(AppSettingKeys.boardFenDelayMs),
      800,
    );
    expect(
      AppSharedPreferences.get<int>(AppSettingKeys.boardMoveRestoreDelayMs),
      2000,
    );
    expect(
      AppSharedPreferences.get<int>(AppSettingKeys.boardEvo2LedBrightness),
      100,
    );
    expect(
      AppSharedPreferences.get<String>(AppSettingKeys.updateDeferredVersion),
      isEmpty,
    );
    expect(
      AppSharedPreferences.get<List<String>>(
        AppSettingKeys.moduleGuideSeenIds,
      ),
      isEmpty,
    );
    expect(
      AppSharedPreferences.get<bool>(
        AppSettingKeys.initialGuideAutoPromptCompleted,
      ),
      isFalse,
    );
    expect(
      AppSharedPreferences.get<int>(AppSettingKeys.reviewCompletedGames),
      0,
    );
    expect(
      AppSharedPreferences.get<int>(AppSettingKeys.standardAnalysisDepth),
      AppSharedPreferences.defaultStandardAnalysisDepth,
    );
  });

  test('stores every physical board setting through independent keys',
      () async {
    final pattern = Evo2LedPattern(
      colors: List<int>.generate(
        evo2LedPatternCellCount,
        (index) => index,
      ),
    );
    final settings = BoardSettingsState(
      globalBeep: false,
      connectBeep: false,
      startGameBeep: false,
      checkmateBeep: false,
      piecePositionLed: false,
      evaluateLed: false,
      showScorebar: false,
      showLegalMoves: false,
      allowTakeback: false,
      allowFlip: false,
      autoFlip: false,
      clockSwitchAutomation: ClockSwitchAutomationMode.opponentMoveOnly,
      clockSwitchOpponentTiming: ClockSwitchOpponentTiming.leisure,
      submitMoveOnClockSwitch: true,
      chessComMoveControlMode: ChessComMoveControlMode.web,
      voiceMovesEnabled: true,
      voiceMoveRecognitionMode: VoiceMoveRecognitionMode.online,
      voiceMoveLanguage: AppLanguagePreference.ja,
      fenDelayMs: 1200,
      moveRestoreDelayMs: 3500,
      evo2LedBrightness: 65,
      evo2LedPatterns: Evo2LedPatternSet.defaults.copyWithPattern(
        'P',
        pattern,
      ),
    );

    const store = SharedPreferencesBoardSettingsStore();
    await store.write(settings);
    final restored = await store.read();

    expect(restored.globalBeep, isFalse);
    expect(restored.connectBeep, isFalse);
    expect(restored.startGameBeep, isFalse);
    expect(restored.checkmateBeep, isFalse);
    expect(restored.piecePositionLed, isFalse);
    expect(restored.evaluateLed, isFalse);
    expect(restored.showScorebar, isFalse);
    expect(restored.showLegalMoves, isFalse);
    expect(restored.allowTakeback, isFalse);
    expect(restored.allowFlip, isFalse);
    expect(restored.autoFlip, isFalse);
    expect(
      restored.clockSwitchAutomation,
      ClockSwitchAutomationMode.opponentMoveOnly,
    );
    expect(
      restored.clockSwitchOpponentTiming,
      ClockSwitchOpponentTiming.leisure,
    );
    expect(restored.submitMoveOnClockSwitch, isTrue);
    expect(restored.chessComMoveControlMode, ChessComMoveControlMode.web);
    expect(restored.voiceMovesEnabled, isTrue);
    expect(
      restored.voiceMoveRecognitionMode,
      VoiceMoveRecognitionMode.online,
    );
    expect(restored.voiceMoveLanguage, AppLanguagePreference.ja);
    expect(restored.fenDelayMs, 1200);
    expect(restored.moveRestoreDelayMs, 3500);
    expect(restored.evo2LedBrightness, 65);
    expect(restored.evo2LedPatterns.patternFor('P'), pattern);
  });

  test('stores app review prompt state through independent keys', () async {
    final promptedAt = DateTime.utc(2026, 8, 21, 10, 30);
    const store = SharedPreferencesReviewPromptStore();

    await store.write(
      ReviewPromptState(
        completedGames: 12,
        positiveMoments: 7,
        promptCount: 2,
        lastPromptedAt: promptedAt,
        lastPromptedVersion: '1.0.1+10001',
      ),
    );
    final restored = await store.read();

    expect(restored.completedGames, 12);
    expect(restored.positiveMoments, 7);
    expect(restored.promptCount, 2);
    expect(restored.lastPromptedAt, promptedAt);
    expect(restored.lastPromptedVersion, '1.0.1+10001');
  });

  test('stores update reminder and viewed module guides by dedicated keys', () {
    final deferredUntil = DateTime.utc(2026, 8, 22, 8);

    AppSharedPreferences.set(
      AppSettingKeys.updateDeferredVersion,
      'android-play:10001',
    );
    AppSharedPreferences.set(
      AppSettingKeys.updateDeferredUntil,
      deferredUntil.toIso8601String(),
    );
    AppSharedPreferences.set(
      AppSettingKeys.updateIgnoredVersion,
      'android-play:10000',
    );
    AppSharedPreferences.set<List<String>>(
      AppSettingKeys.moduleGuideSeenIds,
      const ['home', 'practice'],
    );
    AppSharedPreferences.set(
      AppSettingKeys.initialGuideAutoPromptCompleted,
      true,
    );

    expect(
      AppSharedPreferences.get<String>(AppSettingKeys.updateDeferredVersion),
      'android-play:10001',
    );
    expect(
      DateTime.parse(
        AppSharedPreferences.get<String>(
          AppSettingKeys.updateDeferredUntil,
        ),
      ),
      deferredUntil,
    );
    expect(
      AppSharedPreferences.get<String>(AppSettingKeys.updateIgnoredVersion),
      'android-play:10000',
    );
    expect(
      AppSharedPreferences.get<List<String>>(
        AppSettingKeys.moduleGuideSeenIds,
      ),
      ['home', 'practice'],
    );
    expect(
      AppSharedPreferences.get<bool>(
        AppSettingKeys.initialGuideAutoPromptCompleted,
      ),
      isTrue,
    );
  });

  test('legacy preferences JSON no longer contains migrated settings', () {
    final json = const StoredAppPreferences().toJson();

    expect(json, isNot(contains('board_settings')));
    expect(json, isNot(contains('app_update_reminder')));
    expect(json, isNot(contains('module_guide_seen_ids')));
    expect(json, isNot(contains('review_prompt')));
    expect(json, isNot(contains('widget_vision_enabled')));
    expect(json, isNot(contains('dismissed_continue_record_keys')));
    expect(json, isNot(contains('last_bot_game_config')));
    expect(json, isNot(contains('user_bot_game_configs')));
    expect(json, isNot(contains('favorite_opening_ids')));
  });

  test('stores migrated app preferences through independent keys', () {
    AppSharedPreferences.set(AppSettingKeys.widgetVisionEnabled, true);
    AppSharedPreferences.set<List<String>>(
      AppSettingKeys.dismissedContinueRecordKeys,
      ['pgn:12'],
    );
    AppSharedPreferences.set(
      AppSettingKeys.lastBotGameConfig,
      '{"engine_kind":"maia"}',
    );
    AppSharedPreferences.set(
      AppSettingKeys.userBotGameConfigs,
      '{"guest":{"engine_kind":"maia"}}',
    );
    AppSharedPreferences.set<List<String>>(
      AppSettingKeys.favoriteOpeningIds,
      ['italian'],
    );

    expect(
      AppSharedPreferences.get<bool>(AppSettingKeys.widgetVisionEnabled),
      isTrue,
    );
    expect(
      AppSharedPreferences.get<List<String>>(
        AppSettingKeys.dismissedContinueRecordKeys,
      ),
      ['pgn:12'],
    );
    expect(
      AppSharedPreferences.get<String>(AppSettingKeys.lastBotGameConfig),
      contains('maia'),
    );
    expect(
      AppSharedPreferences.get<String>(AppSettingKeys.userBotGameConfigs),
      contains('guest'),
    );
    expect(
      AppSharedPreferences.get<List<String>>(
        AppSettingKeys.favoriteOpeningIds,
      ),
      ['italian'],
    );
  });

  test('round-trips bot setup JSON stored by the unified preferences', () {
    final config = const BotGameConfig.defaultConfig().copyWith(
      engineKind: BotEngineKind.stockfish,
      stockfishElo: 2180,
      timeMinutes: 15,
      incrementSeconds: 10,
    );
    AppSharedPreferences.set(
      AppSettingKeys.lastBotGameConfig,
      jsonEncode(config.toJson()),
    );
    AppSharedPreferences.set(
      AppSettingKeys.userBotGameConfigs,
      jsonEncode({'user:7': config.toJson()}),
    );

    final restoredLast = BotGameConfig.fromJson(
      jsonDecode(
        AppSharedPreferences.get<String>(AppSettingKeys.lastBotGameConfig),
      ) as Map<String, dynamic>,
    );
    final restoredUsers = jsonDecode(
      AppSharedPreferences.get<String>(AppSettingKeys.userBotGameConfigs),
    ) as Map<String, dynamic>;
    final restoredUser = BotGameConfig.fromJson(
      restoredUsers['user:7'] as Map<String, dynamic>,
    );

    expect(restoredLast.engineKind, BotEngineKind.stockfish);
    expect(restoredLast.stockfishElo, 2180);
    expect(restoredUser.timeMinutes, 15);
    expect(restoredUser.incrementSeconds, 10);
  });
}
