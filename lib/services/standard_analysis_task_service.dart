import 'dart:async';

import 'package:flutter/foundation.dart';

import 'analysis_report_cache_service.dart';
import 'app_preferences_store.dart';
import 'game_notation_service.dart';
import 'stockfish_analysis_service.dart';

enum StandardAnalysisTaskState { running, completed, failed, cancelled }

class StandardAnalysisTaskSnapshot {
  const StandardAnalysisTaskSnapshot({
    required this.state,
    required this.status,
    this.progress = 0,
    this.completedPositions = 0,
    this.totalPositions = 0,
    this.report,
  });

  final StandardAnalysisTaskState state;
  final String status;
  final double progress;
  final int completedPositions;
  final int totalPositions;
  final GameStandardAnalysisReport? report;
}

typedef StandardAnalysisReportBuilder = GameStandardAnalysisReport Function(
  List<MoveEngineInsight> insights,
);

abstract class StandardAnalysisTaskHandle
    extends ValueNotifier<StandardAnalysisTaskSnapshot> {
  StandardAnalysisTaskHandle(super.value);

  Future<StandardAnalysisTaskSnapshot> get done;

  bool get isCancelled;

  Future<void> cancel();
}

class StandardAnalysisTask extends StandardAnalysisTaskHandle {
  static const int _maxAutomaticTimeoutRestarts = 5;

  StandardAnalysisTask({
    required this.cacheKey,
    required this.pgn,
    required this.parsedGame,
    required this.engine,
    required this.cacheStore,
    required this.onReportCacheChanged,
    required this.reportBuilder,
    this.depth = 16,
  }) : super(StandardAnalysisTaskSnapshot(
          state: StandardAnalysisTaskState.running,
          status: 'Stockfish is evaluating every PGN position...',
          totalPositions: parsedGame.snapshots.length,
        )) {
    done = _run();
  }

  final String cacheKey;
  final String pgn;
  final ParsedPgnGame parsedGame;
  final PositionAnalyzer engine;
  final AppPreferencesAnalysisReportCacheStore? cacheStore;
  final FutureOr<void> Function()? onReportCacheChanged;
  final StandardAnalysisReportBuilder reportBuilder;
  final int depth;
  @override
  late final Future<StandardAnalysisTaskSnapshot> done;
  StockfishAnalysisSession? _ownedSession;
  bool _cancelled = false;
  bool _finished = false;

  @override
  bool get isCancelled => _cancelled;

  @override
  Future<void> cancel() async {
    if (_cancelled || _finished) return;
    _cancelled = true;
    final session = _ownedSession;
    if (session != null) await session.dispose();
  }

  Future<StandardAnalysisTaskSnapshot> _run() async {
    try {
      final insights = await _analyzeWithAutomaticTimeoutRestart();
      if (_cancelled) return _cancelledSnapshot();
      if (insights == null) return _cancelledSnapshot();
      if (insights.isEmpty) {
        const snapshot = StandardAnalysisTaskSnapshot(
          state: StandardAnalysisTaskState.completed,
          status: 'Stockfish could not analyze this game. Please try again.',
        );
        value = snapshot;
        return snapshot;
      }

      final report = reportBuilder(insights);
      if (report.isComplete) {
        await cacheStore?.writeStandard(cacheKey, pgn, report);
        await onReportCacheChanged?.call();
      }
      final snapshot = StandardAnalysisTaskSnapshot(
        state: StandardAnalysisTaskState.completed,
        progress: 1,
        completedPositions: report.moves.length + 1,
        totalPositions: report.moves.length + 1,
        status: report.stockfishStatus,
        report: report,
      );
      value = snapshot;
      return snapshot;
    } catch (error) {
      if (_cancelled) return _cancelledSnapshot();
      const snapshot = StandardAnalysisTaskSnapshot(
        state: StandardAnalysisTaskState.failed,
        status: 'Stockfish analysis failed. Please try again.',
      );
      value = snapshot;
      return snapshot;
    } finally {
      await _ownedSession?.dispose();
      _ownedSession = null;
      _finished = true;
    }
  }

  Future<List<MoveEngineInsight>?> _analyzeWithAutomaticTimeoutRestart() async {
    var restartCount = 0;
    while (!_cancelled) {
      PositionAnalyzer taskEngine = engine;
      if (engine case final LivePositionAnalyzer liveAnalyzer) {
        final session = liveAnalyzer.createLiveSession();
        _ownedSession = session;
        if (_cancelled) {
          await session.dispose();
          _ownedSession = null;
          return null;
        }
        taskEngine = _SessionPositionAnalyzer(session);
      }

      try {
        final service = StockfishGameAnalysisService(engine: taskEngine);
        return await service.analyzeGame(
          parsedGame,
          depth: depth.clamp(6, 20).toInt(),
          shouldCancel: () => _cancelled,
          onProgress: (progress) {
            if (_cancelled) return;
            value = StandardAnalysisTaskSnapshot(
              state: StandardAnalysisTaskState.running,
              progress: progress.percent,
              completedPositions: progress.completedPositions,
              totalPositions: progress.totalPositions,
              status:
                  'Stockfish is evaluating PGN positions: ${progress.percentLabel}.',
            );
          },
        );
      } on TimeoutException {
        restartCount++;
        final timedOutSession = _ownedSession;
        _ownedSession = null;
        await timedOutSession?.dispose();
        if (_cancelled) return null;
        if (restartCount > _maxAutomaticTimeoutRestarts) rethrow;
        value = StandardAnalysisTaskSnapshot(
          state: StandardAnalysisTaskState.running,
          progress: 0,
          completedPositions: 0,
          totalPositions: parsedGame.snapshots.length,
          status:
              'Stockfish timed out. Restarting analysis automatically (attempt ${restartCount + 1})...',
        );
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    return null;
  }

  StandardAnalysisTaskSnapshot _cancelledSnapshot() {
    final snapshot = StandardAnalysisTaskSnapshot(
      state: StandardAnalysisTaskState.cancelled,
      status: 'Stockfish analysis stopped.',
      progress: value.progress,
      completedPositions: value.completedPositions,
      totalPositions: value.totalPositions,
    );
    value = snapshot;
    return snapshot;
  }
}

class _SessionPositionAnalyzer implements PositionAnalyzer {
  const _SessionPositionAnalyzer(this.session);

  final StockfishAnalysisSession session;

  @override
  Future<PositionEngineAnalysis?> analyzeFen(
    String fen, {
    int depth = 12,
    int multiPv = 1,
  }) {
    return session.start(
      fen,
      limit: StockfishAnalysisLimit.fixed(depth.clamp(6, 20).toInt()),
      multiPv: multiPv,
      onUpdate: (_) {},
    );
  }
}

class StandardAnalysisTaskCoordinator {
  final Map<String, StandardAnalysisTaskHandle> _tasks = {};

  StandardAnalysisTaskHandle startOrAttachLocal({
    required String cacheKey,
    required String pgn,
    required ParsedPgnGame parsedGame,
    required PositionAnalyzer engine,
    required AppPreferencesAnalysisReportCacheStore? cacheStore,
    required FutureOr<void> Function()? onReportCacheChanged,
    required StandardAnalysisReportBuilder reportBuilder,
    int depth = 16,
  }) {
    final normalizedDepth = depth.clamp(6, 20).toInt();
    final taskKey =
        'local:$cacheKey:${gameAnalysisReportCacheKeyForPgn(pgn)}:depth-$normalizedDepth';
    final existing = _tasks[taskKey];
    if (existing != null && !existing.isCancelled) return existing;
    if (identical(_tasks[taskKey], existing)) {
      _tasks.remove(taskKey);
    }
    final task = StandardAnalysisTask(
      cacheKey: cacheKey,
      pgn: pgn,
      parsedGame: parsedGame,
      engine: engine,
      cacheStore: cacheStore,
      onReportCacheChanged: onReportCacheChanged,
      reportBuilder: reportBuilder,
      depth: normalizedDepth,
    );
    _tasks[taskKey] = task;
    task.done.whenComplete(() {
      if (identical(_tasks[taskKey], task)) {
        _tasks.remove(taskKey);
      }
    });
    return task;
  }
}

final standardAnalysisTaskCoordinator = StandardAnalysisTaskCoordinator();
