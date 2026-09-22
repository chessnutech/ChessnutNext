import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../l10n/app_language.dart';
import 'analysis_report_cache_service.dart';
import 'app_shared_preferences.dart';
import 'board_settings_service.dart';
import 'chessnut_api_client.dart';
import 'course_progress_service.dart';
import 'lc0_weight_library_service.dart';
import 'mistake_book_service.dart';
import 'review_prompt_service.dart';

class StoredAppPreferences {
  const StoredAppPreferences({
    this.importedBoardStorageKeys = const {},
    this.lc0Weights = const [Lc0WeightLibraryEntry.defaultWeight],
    this.analysisReports = const {},
    this.courseProgress = const {},
    this.mistakeBook = const MistakeBookState(),
  });

  final Set<String> importedBoardStorageKeys;
  final List<Lc0WeightLibraryEntry> lc0Weights;
  final Map<String, GameAnalysisReportCacheEntry> analysisReports;
  final Map<String, CourseProgressEntry> courseProgress;
  final MistakeBookState mistakeBook;

  StoredAppPreferences copyWith({
    Set<String>? importedBoardStorageKeys,
    List<Lc0WeightLibraryEntry>? lc0Weights,
    Map<String, GameAnalysisReportCacheEntry>? analysisReports,
    Map<String, CourseProgressEntry>? courseProgress,
    MistakeBookState? mistakeBook,
  }) {
    return StoredAppPreferences(
      importedBoardStorageKeys:
          importedBoardStorageKeys ?? this.importedBoardStorageKeys,
      lc0Weights: lc0Weights ?? this.lc0Weights,
      analysisReports: analysisReports ?? this.analysisReports,
      courseProgress: courseProgress ?? this.courseProgress,
      mistakeBook: mistakeBook ?? this.mistakeBook,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imported_board_storage_keys':
          importedBoardStorageKeys.toList(growable: false),
      'lc0_weights': lc0Weights.map((entry) => entry.toJson()).toList(),
      'analysis_reports': {
        for (final entry in analysisReports.entries)
          entry.key: entry.value.toJson(),
      },
      'course_progress': {
        for (final entry in courseProgress.entries)
          entry.key: entry.value.toJson(),
      },
      'mistake_book': mistakeBook.toJson(),
    };
  }

  factory StoredAppPreferences.fromJson(Map<String, dynamic> json) {
    final lc0Weights = json['lc0_weights'];
    final importedBoardStorageKeys = json['imported_board_storage_keys'];
    final analysisReports = json['analysis_reports'];
    final courseProgress = json['course_progress'];
    final mistakeBook = json['mistake_book'];
    return StoredAppPreferences(
      importedBoardStorageKeys: importedBoardStorageKeys is List
          ? importedBoardStorageKeys
              .map((key) => key.toString())
              .where((key) => key.isNotEmpty)
              .toSet()
          : const {},
      lc0Weights: _lc0WeightList(lc0Weights),
      analysisReports: _analysisReportMap(analysisReports),
      courseProgress: _courseProgressMap(courseProgress),
      mistakeBook: mistakeBook is Map<String, dynamic>
          ? MistakeBookState.fromJson(mistakeBook)
          : const MistakeBookState(),
    );
  }
}

class AppUpdateReminderState {
  const AppUpdateReminderState({
    this.deferredVersion = '',
    this.deferredUntil,
    this.ignoredVersion = '',
  });

  final String deferredVersion;
  final DateTime? deferredUntil;
  final String ignoredVersion;

  AppUpdateReminderState copyWith({
    String? deferredVersion,
    DateTime? deferredUntil,
    bool clearDeferredUntil = false,
    String? ignoredVersion,
  }) {
    return AppUpdateReminderState(
      deferredVersion: deferredVersion ?? this.deferredVersion,
      deferredUntil:
          clearDeferredUntil ? null : (deferredUntil ?? this.deferredUntil),
      ignoredVersion: ignoredVersion ?? this.ignoredVersion,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deferred_version': deferredVersion,
      'deferred_until': deferredUntil?.toIso8601String(),
      'ignored_version': ignoredVersion,
    };
  }

  factory AppUpdateReminderState.fromJson(Map<String, dynamic> json) {
    return AppUpdateReminderState(
      deferredVersion: json['deferred_version']?.toString() ?? '',
      deferredUntil: DateTime.tryParse(
        json['deferred_until']?.toString() ?? '',
      ),
      ignoredVersion: json['ignored_version']?.toString() ?? '',
    );
  }

  bool shouldSuppress(String versionKey, DateTime now) {
    final cleanVersion = versionKey.trim();
    if (cleanVersion.isEmpty) return false;
    if (ignoredVersion == cleanVersion) return true;
    final until = deferredUntil;
    return deferredVersion == cleanVersion &&
        until != null &&
        now.isBefore(until);
  }
}

List<Lc0WeightLibraryEntry> _lc0WeightList(Object? value) {
  final parsed = value is List
      ? value
          .map(Lc0WeightLibraryEntry.fromJson)
          .where((entry) => entry.key.isNotEmpty && entry.path.isNotEmpty)
          .toList()
      : <Lc0WeightLibraryEntry>[];
  if (parsed.every((entry) => !entry.isDefault)) {
    parsed.insert(0, Lc0WeightLibraryEntry.defaultWeight);
  }
  final byKey = <String, Lc0WeightLibraryEntry>{};
  for (final entry in parsed) {
    byKey[entry.key] = entry;
  }
  return List.unmodifiable(byKey.values);
}

Map<String, CourseProgressEntry> _courseProgressMap(Object? value) {
  if (value is! Map) return const {};
  final progress = <String, CourseProgressEntry>{};
  for (final entry in value.entries) {
    final key = entry.key.toString();
    final rawProgress = entry.value;
    if (key.isEmpty || rawProgress is! Map) continue;
    final parsed = CourseProgressEntry.fromJson(
      rawProgress.map((key, value) => MapEntry(key.toString(), value)),
    );
    if (parsed.courseId.isNotEmpty) {
      progress[key] = parsed;
    }
  }
  return Map<String, CourseProgressEntry>.unmodifiable(progress);
}

Map<String, GameAnalysisReportCacheEntry> _analysisReportMap(Object? value) {
  if (value is! Map) return const {};
  final reports = <String, GameAnalysisReportCacheEntry>{};
  for (final entry in value.entries) {
    final key = entry.key.toString();
    final rawReport = entry.value;
    if (key.isEmpty || rawReport is! Map) continue;
    reports[key] = GameAnalysisReportCacheEntry.fromJson(
      rawReport.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
  return Map<String, GameAnalysisReportCacheEntry>.unmodifiable(reports);
}

abstract class AppPreferencesStore {
  Future<StoredAppPreferences> read();

  Future<void> write(StoredAppPreferences preferences);
}

class MemoryAppPreferencesStore implements AppPreferencesStore {
  MemoryAppPreferencesStore([StoredAppPreferences? preferences])
      : preferences = preferences ?? const StoredAppPreferences();

  StoredAppPreferences preferences;

  @override
  Future<StoredAppPreferences> read() async => preferences;

  @override
  Future<void> write(StoredAppPreferences preferences) async {
    this.preferences = preferences;
  }
}

class FileAppPreferencesStore implements AppPreferencesStore {
  const FileAppPreferencesStore();

  static const _fileName = 'chessnut_app_preferences.json';

  @override
  Future<StoredAppPreferences> read() async {
    try {
      final file = await _preferencesFile();
      if (!await file.exists()) return const StoredAppPreferences();
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return const StoredAppPreferences();
      }
      return StoredAppPreferences.fromJson(decoded);
    } catch (_) {
      return const StoredAppPreferences();
    }
  }

  @override
  Future<void> write(StoredAppPreferences preferences) async {
    try {
      final file = await _preferencesFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(preferences.toJson()), flush: true);
    } catch (_) {}
  }

  Future<File> _preferencesFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }
}

class SharedPreferencesReviewPromptStore implements ReviewPromptStore {
  const SharedPreferencesReviewPromptStore();

  @override
  Future<ReviewPromptState> read() async {
    return ReviewPromptState(
      completedGames: AppSharedPreferences.get<int>(
        AppSettingKeys.reviewCompletedGames,
      ),
      positiveMoments: AppSharedPreferences.get<int>(
        AppSettingKeys.reviewPositiveMoments,
      ),
      promptCount: AppSharedPreferences.get<int>(
        AppSettingKeys.reviewPromptCount,
      ),
      lastPromptedAt: DateTime.tryParse(
        AppSharedPreferences.get<String>(
          AppSettingKeys.reviewLastPromptedAt,
        ),
      ),
      lastPromptedVersion: AppSharedPreferences.get<String>(
        AppSettingKeys.reviewLastPromptedVersion,
      ),
    );
  }

  @override
  Future<void> write(ReviewPromptState state) async {
    AppSharedPreferences.set(
      AppSettingKeys.reviewCompletedGames,
      state.completedGames,
    );
    AppSharedPreferences.set(
      AppSettingKeys.reviewPositiveMoments,
      state.positiveMoments,
    );
    AppSharedPreferences.set(
      AppSettingKeys.reviewPromptCount,
      state.promptCount,
    );
    AppSharedPreferences.set(
      AppSettingKeys.reviewLastPromptedAt,
      state.lastPromptedAt?.toIso8601String() ?? '',
    );
    AppSharedPreferences.set(
      AppSettingKeys.reviewLastPromptedVersion,
      state.lastPromptedVersion,
    );
  }
}

class SharedPreferencesBoardSettingsStore implements BoardSettingsStore {
  const SharedPreferencesBoardSettingsStore();

  @override
  Future<BoardSettingsState> read() async {
    Object? ledPatterns;
    try {
      ledPatterns = jsonDecode(
        AppSharedPreferences.get<String>(AppSettingKeys.boardEvo2LedPatterns),
      );
    } catch (_) {}
    return BoardSettingsState(
      globalBeep:
          AppSharedPreferences.get<bool>(AppSettingKeys.boardGlobalBeep),
      connectBeep:
          AppSharedPreferences.get<bool>(AppSettingKeys.boardConnectBeep),
      startGameBeep:
          AppSharedPreferences.get<bool>(AppSettingKeys.boardStartGameBeep),
      checkmateBeep:
          AppSharedPreferences.get<bool>(AppSettingKeys.boardCheckmateBeep),
      piecePositionLed: AppSharedPreferences.get<bool>(
        AppSettingKeys.boardPiecePositionLed,
      ),
      evaluateLed:
          AppSharedPreferences.get<bool>(AppSettingKeys.boardEvaluateLed),
      showScorebar:
          AppSharedPreferences.get<bool>(AppSettingKeys.boardShowScorebar),
      showLegalMoves:
          AppSharedPreferences.get<bool>(AppSettingKeys.boardShowLegalMoves),
      allowTakeback:
          AppSharedPreferences.get<bool>(AppSettingKeys.boardAllowTakeback),
      allowFlip: AppSharedPreferences.get<bool>(AppSettingKeys.boardAllowFlip),
      autoFlip: AppSharedPreferences.get<bool>(AppSettingKeys.boardAutoFlip),
      clockSwitchAutomation: ClockSwitchAutomationMode.fromStorage(
        AppSharedPreferences.get<String>(
          AppSettingKeys.boardClockSwitchAutomation,
        ),
        legacyClockSwitch: true,
      ),
      clockSwitchOpponentTiming: ClockSwitchOpponentTiming.fromStorage(
        AppSharedPreferences.get<String>(
          AppSettingKeys.boardClockSwitchOpponentTiming,
        ),
      ),
      submitMoveOnClockSwitch: AppSharedPreferences.get<bool>(
        AppSettingKeys.boardSubmitMoveOnClockSwitch,
      ),
      chessComMoveControlMode: ChessComMoveControlMode.fromStorage(
        AppSharedPreferences.get<String>(
          AppSettingKeys.boardChessComMoveControlMode,
        ),
      ),
      voiceMovesEnabled: AppSharedPreferences.get<bool>(
        AppSettingKeys.boardVoiceMovesEnabled,
      ),
      voiceMoveRecognitionMode: VoiceMoveRecognitionMode.fromStorage(
        AppSharedPreferences.get<String>(
          AppSettingKeys.boardVoiceMoveRecognitionMode,
        ),
      ),
      voiceMoveLanguage: AppLanguagePreference.fromTag(
        AppSharedPreferences.get<String>(
          AppSettingKeys.boardVoiceMoveLanguage,
        ),
      ),
      fenDelayMs: AppSharedPreferences.get<int>(AppSettingKeys.boardFenDelayMs),
      moveRestoreDelayMs: AppSharedPreferences.get<int>(
        AppSettingKeys.boardMoveRestoreDelayMs,
      ),
      evo2LedBrightness: AppSharedPreferences.get<int>(
        AppSettingKeys.boardEvo2LedBrightness,
      ),
      evo2LedPatterns: Evo2LedPatternSet.fromJson(ledPatterns),
    );
  }

  @override
  Future<void> write(BoardSettingsState settings) async {
    AppSharedPreferences.set(
      AppSettingKeys.boardGlobalBeep,
      settings.globalBeep,
    );
    AppSharedPreferences.set(
      AppSettingKeys.boardConnectBeep,
      settings.connectBeep,
    );
    AppSharedPreferences.set(
      AppSettingKeys.boardStartGameBeep,
      settings.startGameBeep,
    );
    AppSharedPreferences.set(
      AppSettingKeys.boardCheckmateBeep,
      settings.checkmateBeep,
    );
    AppSharedPreferences.set(
      AppSettingKeys.boardPiecePositionLed,
      settings.piecePositionLed,
    );
    AppSharedPreferences.set(
      AppSettingKeys.boardEvaluateLed,
      settings.evaluateLed,
    );
    AppSharedPreferences.set(
      AppSettingKeys.boardShowScorebar,
      settings.showScorebar,
    );
    AppSharedPreferences.set(
      AppSettingKeys.boardShowLegalMoves,
      settings.showLegalMoves,
    );
    AppSharedPreferences.set(
      AppSettingKeys.boardAllowTakeback,
      settings.allowTakeback,
    );
    AppSharedPreferences.set(
      AppSettingKeys.boardAllowFlip,
      settings.allowFlip,
    );
    AppSharedPreferences.set(
      AppSettingKeys.boardAutoFlip,
      settings.autoFlip,
    );
    AppSharedPreferences.set(
      AppSettingKeys.boardClockSwitchAutomation,
      settings.clockSwitchAutomation.storageKey,
    );
    AppSharedPreferences.set(
      AppSettingKeys.boardClockSwitchOpponentTiming,
      settings.clockSwitchOpponentTiming.storageKey,
    );
    AppSharedPreferences.set(
      AppSettingKeys.boardSubmitMoveOnClockSwitch,
      settings.submitMoveOnClockSwitch,
    );
    AppSharedPreferences.set(
      AppSettingKeys.boardChessComMoveControlMode,
      settings.chessComMoveControlMode.storageKey,
    );
    AppSharedPreferences.set(
      AppSettingKeys.boardVoiceMovesEnabled,
      settings.voiceMovesEnabled,
    );
    AppSharedPreferences.set(
      AppSettingKeys.boardVoiceMoveRecognitionMode,
      settings.voiceMoveRecognitionMode.storageKey,
    );
    AppSharedPreferences.set(
      AppSettingKeys.boardVoiceMoveLanguage,
      settings.voiceMoveLanguage.tag,
    );
    AppSharedPreferences.set(
      AppSettingKeys.boardFenDelayMs,
      settings.fenDelayMs,
    );
    AppSharedPreferences.set(
      AppSettingKeys.boardMoveRestoreDelayMs,
      settings.moveRestoreDelayMs,
    );
    AppSharedPreferences.set(
      AppSettingKeys.boardEvo2LedBrightness,
      settings.evo2LedBrightness,
    );
    AppSharedPreferences.set(
      AppSettingKeys.boardEvo2LedPatterns,
      jsonEncode(settings.evo2LedPatterns.toJson()),
    );
  }
}

class AppPreferencesAnalysisReportCacheStore {
  AppPreferencesAnalysisReportCacheStore(this.store);

  final AppPreferencesStore store;
  Future<void> _writeQueue = Future.value();

  Future<GameAnalysisReportCacheEntry?> read(String key) async {
    return (await store.read()).analysisReports[key];
  }

  Future<Map<String, GameAnalysisReportStatus>> readStatuses() async {
    final reports = (await store.read()).analysisReports;
    return {
      for (final entry in reports.entries)
        if (entry.value.status.hasAny) entry.key: entry.value.status,
    };
  }

  Future<bool> delete(String key) async {
    if (key.trim().isEmpty) return false;
    var removed = false;
    final write = _writeQueue.then((_) async {
      final preferences = await store.read();
      final reports = Map<String, GameAnalysisReportCacheEntry>.from(
          preferences.analysisReports);
      removed = reports.remove(key) != null;
      if (removed) {
        await store.write(preferences.copyWith(analysisReports: reports));
      }
    });
    _writeQueue = write.catchError((Object _) {});
    await write;
    return removed;
  }

  Future<void> ensurePgn(String key, String pgn) async {
    await _updateEntry(key, (existing) {
      final trimmed = pgn.trim();
      if (trimmed.isEmpty || existing.pgn.trim().isNotEmpty) {
        return existing;
      }
      return existing.copyWith(
        pgn: trimmed,
        updatedAt: DateTime.now(),
      );
    });
  }

  Future<void> replacePgn(String key, String pgn) async {
    await _updateEntry(key, (existing) {
      return existing.copyWith(
        pgn: pgn.trim(),
        updatedAt: DateTime.now(),
      );
    });
  }

  Future<void> replacePgnAndMoveKey(
    String oldKey,
    String newKey,
    String pgn,
  ) async {
    final write = _writeQueue.then((_) async {
      final preferences = await store.read();
      final reports = Map<String, GameAnalysisReportCacheEntry>.from(
        preferences.analysisReports,
      );
      final existing =
          reports.remove(oldKey) ?? const GameAnalysisReportCacheEntry();
      reports[newKey] = existing.copyWith(
        pgn: pgn.trim(),
        updatedAt: DateTime.now(),
      );
      await store.write(preferences.copyWith(analysisReports: reports));
    });
    _writeQueue = write.catchError((Object _) {});
    await write;
  }

  Future<void> writeStandard(
    String key,
    String pgn,
    GameStandardAnalysisReport report,
  ) async {
    await _updateEntry(key, (existing) {
      return existing.copyWith(
        pgn: pgn.trim().isEmpty ? null : pgn,
        standardReport: report,
        updatedAt: DateTime.now(),
      );
    });
  }

  Future<void> markGrandeurUnlocked(
    String key,
    String pgn, {
    int commentId = 0,
    int serverPgnId = 0,
    String styleId = '',
  }) async {
    await _updateEntry(key, (existing) {
      return existing.copyWith(
        pgn: pgn.trim().isEmpty ? null : pgn,
        grandeurUnlocked: true,
        grandeurCommentId:
            commentId > 0 ? commentId : existing.grandeurCommentId,
        grandeurStyleId:
            styleId.trim().isEmpty ? existing.grandeurStyleId : styleId.trim(),
        serverPgnId: serverPgnId > 0 ? serverPgnId : existing.serverPgnId,
        updatedAt: DateTime.now(),
      );
    });
  }

  Future<void> markServerPgnId(String key, String pgn, int serverPgnId) async {
    if (serverPgnId <= 0) return;
    await _updateEntry(key, (existing) {
      return existing.copyWith(
        pgn: pgn.trim().isEmpty ? null : pgn,
        serverPgnId: serverPgnId,
        updatedAt: DateTime.now(),
      );
    });
  }

  Future<void> writeGrandeur(
    String key,
    String pgn,
    GrandeurAnalysisResult report, {
    String styleId = '',
  }) async {
    await _updateEntry(key, (existing) {
      return existing.copyWith(
        pgn: pgn.trim().isEmpty ? null : pgn,
        grandeurReport: report,
        grandeurUnlocked: true,
        grandeurStyleId:
            styleId.trim().isEmpty ? existing.grandeurStyleId : styleId.trim(),
        updatedAt: DateTime.now(),
      );
    });
  }

  Future<void> writeMaia3(
    String key,
    String pgn,
    Maia3HumanReviewReport report,
  ) async {
    await _updateEntry(key, (existing) {
      return existing.copyWith(
        pgn: pgn.trim().isEmpty ? null : pgn,
        maia3Report: report,
        updatedAt: DateTime.now(),
      );
    });
  }

  Future<void> _updateEntry(
    String key,
    GameAnalysisReportCacheEntry Function(GameAnalysisReportCacheEntry existing)
        update,
  ) async {
    final write = _writeQueue.then((_) async {
      final preferences = await store.read();
      final reports = Map<String, GameAnalysisReportCacheEntry>.from(
          preferences.analysisReports);
      final existing = reports[key] ?? const GameAnalysisReportCacheEntry();
      reports[key] = update(existing);
      final syncedMistakes = _syncStateFromAnalysisReports(
        preferences.mistakeBook,
        reports,
      );
      await store.write(
        preferences.copyWith(
          analysisReports: reports,
          mistakeBook: syncedMistakes,
        ),
      );
    });
    _writeQueue = write.catchError((Object _) {});
    await write;
  }
}

MistakeBookState _syncStateFromAnalysisReports(
  MistakeBookState state,
  Map<String, GameAnalysisReportCacheEntry> reports,
) {
  final currentTime = DateTime.now();
  var changed = false;
  final entries = Map<String, MistakeBookEntry>.from(state.entries);
  for (final reportEntry in reports.entries) {
    final report = reportEntry.value.standardReport;
    final pgn = reportEntry.value.pgn.trim();
    if (report == null || pgn.isEmpty) continue;
    final extracted = MistakeBookExtractor.extractFromStandardReport(
      reportKey: reportEntry.key,
      pgn: pgn,
      report: report,
      now: currentTime,
    );
    final extractedIds = extracted.map((entry) => entry.id).toSet();
    final reportedPlies = report.moves.map((move) => move.ply).toSet();
    final obsoleteIds = entries.values
        .where((entry) =>
            entry.reportKey == reportEntry.key &&
            reportedPlies.contains(entry.ply) &&
            !extractedIds.contains(entry.id))
        .map((entry) => entry.id)
        .toList(growable: false);
    if (obsoleteIds.isNotEmpty) {
      for (final id in obsoleteIds) {
        entries.remove(id);
      }
      changed = true;
    }
    for (final entry in extracted) {
      final existing = entries[entry.id];
      if (existing == null) {
        entries[entry.id] = entry;
        changed = true;
        continue;
      }
      if (_hasSameMistakeBookContent(existing, entry)) continue;
      entries[entry.id] = existing.copyWith(
        pgn: entry.pgn,
        sourceTitle: entry.sourceTitle,
        moveSan: entry.moveSan,
        bestMoveSan: entry.bestMoveSan,
        classification: entry.classification,
        summary: entry.summary,
        theme: entry.theme,
        fenBefore: entry.fenBefore,
        fenAfter: entry.fenAfter,
        engineLine: entry.engineLine,
        updatedAt: currentTime,
      );
      changed = true;
    }
  }
  return changed ? MistakeBookState(entries: Map.unmodifiable(entries)) : state;
}

bool _hasSameMistakeBookContent(
  MistakeBookEntry existing,
  MistakeBookEntry extracted,
) {
  return existing.pgn == extracted.pgn &&
      existing.sourceTitle == extracted.sourceTitle &&
      existing.moveSan == extracted.moveSan &&
      existing.bestMoveSan == extracted.bestMoveSan &&
      existing.classification == extracted.classification &&
      existing.summary == extracted.summary &&
      existing.theme == extracted.theme &&
      existing.fenBefore == extracted.fenBefore &&
      existing.fenAfter == extracted.fenAfter &&
      existing.engineLine == extracted.engineLine;
}
