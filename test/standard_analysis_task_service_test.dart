import 'dart:async';

import 'package:chessnut_flutter_export/services/analysis_report_cache_service.dart';
import 'package:chessnut_flutter_export/services/app_preferences_store.dart';
import 'package:chessnut_flutter_export/services/game_notation_service.dart';
import 'package:chessnut_flutter_export/services/standard_analysis_task_service.dart';
import 'package:chessnut_flutter_export/services/stockfish_analysis_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standard analysis task continues and can be reattached', () async {
    const pgn = '''
[Event "Background Service"]
[Result "*"]

1. e4 e5 *
''';
    final parsedGame = GameNotationService.parsePgn(pgn);
    final completer = Completer<void>();
    final analyzer = _DelayedAnalyzer(completer);
    final store = AppPreferencesAnalysisReportCacheStore(
      MemoryAppPreferencesStore(),
    );
    var cacheChanged = 0;
    final coordinator = StandardAnalysisTaskCoordinator();

    final first = coordinator.startOrAttachLocal(
      cacheKey: 'pgnhash:test-background-service',
      pgn: pgn,
      parsedGame: parsedGame,
      engine: analyzer,
      cacheStore: store,
      onReportCacheChanged: () => cacheChanged++,
      depth: 20,
      reportBuilder: (insights) => GameStandardAnalysisReport(
        moves: [
          for (final insight in insights)
            CachedReviewMove(
              ply: insight.ply,
              move: 'Move ${insight.ply}',
              evalBefore: insight.evalBefore,
              evalAfter: insight.evalAfter,
              classification: insight.classification,
              summary: 'Analyzed',
              fen: parsedGame.moves[insight.ply - 1].fenAfter,
              lastMove: parsedGame.moves[insight.ply - 1].lastMove,
              focusSquare: parsedGame.moves[insight.ply - 1].lastMove.last,
              engineLine: insight.engineLine,
              bestMove: insight.bestMoveUci ?? '',
              keyMoment: false,
              engineDepth: insight.depth,
              isEngineBacked: insight.isEngineBacked,
            ),
        ],
        stockfishBacked: true,
        stockfishStatus: 'ready',
        generatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(analyzer.calls, 1);

    final second = coordinator.startOrAttachLocal(
      cacheKey: 'pgnhash:test-background-service',
      pgn: pgn,
      parsedGame: parsedGame,
      engine: analyzer,
      cacheStore: store,
      onReportCacheChanged: () => cacheChanged++,
      depth: 20,
      reportBuilder: (_) => throw StateError('should attach existing task'),
    );

    expect(identical(first, second), isTrue);
    expect(analyzer.calls, 1);

    completer.complete();
    final snapshot = await second.done;

    expect(snapshot.state, StandardAnalysisTaskState.completed);
    expect(snapshot.report?.moves, hasLength(2));
    expect(cacheChanged, 1);
    expect(analyzer.depths, everyElement(20));
    expect(analyzer.multiPvs, everyElement(3));
    expect(
      (await store.read('pgnhash:test-background-service'))?.hasStandard,
      isTrue,
    );
  });

  test('does not attach a different PGN to the same record task', () async {
    const firstPgn = '[Result "*"]\n\n1. e4 *';
    const secondPgn = '[Result "*"]\n\n1. d4 *';
    final firstCompleter = Completer<void>();
    final secondCompleter = Completer<void>();
    final firstAnalyzer = _DelayedAnalyzer(firstCompleter);
    final secondAnalyzer = _DelayedAnalyzer(secondCompleter);
    final coordinator = StandardAnalysisTaskCoordinator();

    GameStandardAnalysisReport buildReport(List<MoveEngineInsight> insights) {
      return GameStandardAnalysisReport(
        moves: const [],
        stockfishBacked: true,
        stockfishStatus: 'ready',
        generatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        isComplete: false,
      );
    }

    final first = coordinator.startOrAttachLocal(
      cacheKey: 'pgn:42',
      pgn: firstPgn,
      parsedGame: GameNotationService.parsePgn(firstPgn),
      engine: firstAnalyzer,
      cacheStore: null,
      onReportCacheChanged: null,
      reportBuilder: buildReport,
    );
    final second = coordinator.startOrAttachLocal(
      cacheKey: 'pgn:42',
      pgn: secondPgn,
      parsedGame: GameNotationService.parsePgn(secondPgn),
      engine: secondAnalyzer,
      cacheStore: null,
      onReportCacheChanged: null,
      reportBuilder: buildReport,
    );
    await Future<void>.delayed(Duration.zero);

    expect(identical(first, second), isFalse);
    expect(firstAnalyzer.calls, 1);
    expect(secondAnalyzer.calls, 1);

    firstCompleter.complete();
    secondCompleter.complete();
    await Future.wait([first.done, second.done]);
  });

  test('does not attach a different depth to the same PGN task', () async {
    const pgn = '[Result "*"]\n\n1. e4 *';
    final firstCompleter = Completer<void>();
    final secondCompleter = Completer<void>();
    final firstAnalyzer = _DelayedAnalyzer(firstCompleter);
    final secondAnalyzer = _DelayedAnalyzer(secondCompleter);
    final coordinator = StandardAnalysisTaskCoordinator();

    GameStandardAnalysisReport buildReport(List<MoveEngineInsight> insights) {
      return GameStandardAnalysisReport(
        moves: const [],
        stockfishBacked: true,
        stockfishStatus: 'ready',
        generatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        isComplete: false,
      );
    }

    final first = coordinator.startOrAttachLocal(
      cacheKey: 'pgn:42',
      pgn: pgn,
      parsedGame: GameNotationService.parsePgn(pgn),
      engine: firstAnalyzer,
      cacheStore: null,
      onReportCacheChanged: null,
      depth: 6,
      reportBuilder: buildReport,
    );
    final second = coordinator.startOrAttachLocal(
      cacheKey: 'pgn:42',
      pgn: pgn,
      parsedGame: GameNotationService.parsePgn(pgn),
      engine: secondAnalyzer,
      cacheStore: null,
      onReportCacheChanged: null,
      depth: 20,
      reportBuilder: buildReport,
    );
    await Future<void>.delayed(Duration.zero);

    expect(identical(first, second), isFalse);
    expect(firstAnalyzer.depths, everyElement(6));
    expect(secondAnalyzer.depths, everyElement(20));

    firstCompleter.complete();
    secondCompleter.complete();
    await Future.wait([first.done, second.done]);
  });

  test('cancelling standard analysis stops before later positions', () async {
    const pgn = '''
[Event "Cancelled Analysis"]
[Result "*"]

1. e4 e5 2. Nf3 Nc6 *
''';
    final parsedGame = GameNotationService.parsePgn(pgn);
    final firstCall = Completer<void>();
    final analyzer = _DelayedAnalyzer(firstCall);
    final coordinator = StandardAnalysisTaskCoordinator();

    final task = coordinator.startOrAttachLocal(
      cacheKey: 'pgnhash:test-cancelled-analysis',
      pgn: pgn,
      parsedGame: parsedGame,
      engine: analyzer,
      cacheStore: null,
      onReportCacheChanged: null,
      reportBuilder: (_) => throw StateError('cancelled task built a report'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(analyzer.calls, 1);

    final cancelling = task.cancel();
    firstCall.complete();
    await cancelling;
    final snapshot = await task.done;

    expect(snapshot.state, StandardAnalysisTaskState.cancelled);
    expect(analyzer.calls, 1);
  });

  test('cancelling standard analysis disposes its live engine session',
      () async {
    const pgn = '''
[Event "Disposed Analysis"]
[Result "*"]

1. e4 e5 *
''';
    final parsedGame = GameNotationService.parsePgn(pgn);
    final analyzer = _LiveDelayedAnalyzer();
    final coordinator = StandardAnalysisTaskCoordinator();

    final task = coordinator.startOrAttachLocal(
      cacheKey: 'pgnhash:test-disposed-analysis',
      pgn: pgn,
      parsedGame: parsedGame,
      engine: analyzer,
      cacheStore: null,
      onReportCacheChanged: null,
      reportBuilder: (_) => throw StateError('cancelled task built a report'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(analyzer.session.startCalls, 1);

    await task.cancel();
    final snapshot = await task.done;

    expect(snapshot.state, StandardAnalysisTaskState.cancelled);
    expect(analyzer.session.disposeCalls, 1);
  });

  test('restarts the full standard analysis after a Stockfish timeout',
      () async {
    const pgn = '''
[Event "Timeout Recovery"]
[Result "*"]

1. e4 *
''';
    final parsedGame = GameNotationService.parsePgn(pgn);
    final analyzer = _TimeoutThenSuccessLiveAnalyzer();
    final statuses = <String>[];

    final task = StandardAnalysisTaskCoordinator().startOrAttachLocal(
      cacheKey: 'pgnhash:test-timeout-recovery',
      pgn: pgn,
      parsedGame: parsedGame,
      engine: analyzer,
      cacheStore: null,
      onReportCacheChanged: null,
      reportBuilder: (insights) => GameStandardAnalysisReport(
        moves: [
          for (final insight in insights)
            CachedReviewMove(
              ply: insight.ply,
              move: 'Move ${insight.ply}',
              evalBefore: insight.evalBefore,
              evalAfter: insight.evalAfter,
              classification: insight.classification,
              summary: 'Analyzed',
              fen: parsedGame.moves[insight.ply - 1].fenAfter,
              lastMove: parsedGame.moves[insight.ply - 1].lastMove,
              focusSquare: parsedGame.moves[insight.ply - 1].lastMove.last,
              engineLine: insight.engineLine,
              bestMove: insight.bestMoveUci ?? '',
              keyMoment: false,
              engineDepth: insight.depth,
              isEngineBacked: insight.isEngineBacked,
            ),
        ],
        stockfishBacked: true,
        stockfishStatus: 'ready',
        generatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    task.addListener(() => statuses.add(task.value.status));

    final snapshot = await task.done;

    expect(snapshot.state, StandardAnalysisTaskState.completed);
    expect(snapshot.report?.moves, hasLength(1));
    expect(analyzer.sessions, hasLength(2));
    expect(analyzer.sessions.first.disposeCalls, 1);
    expect(analyzer.sessions.last.disposeCalls, 1);
    expect(
      statuses,
      contains(
        'Stockfish timed out. Restarting analysis automatically (attempt 2)...',
      ),
    );
  });

  test('fails after five automatic Stockfish timeout restarts', () async {
    const pgn = '''
[Event "Timeout Limit"]
[Result "*"]

1. e4 *
''';
    final analyzer = _AlwaysTimeoutLiveAnalyzer();

    final task = StandardAnalysisTaskCoordinator().startOrAttachLocal(
      cacheKey: 'pgnhash:test-timeout-limit',
      pgn: pgn,
      parsedGame: GameNotationService.parsePgn(pgn),
      engine: analyzer,
      cacheStore: null,
      onReportCacheChanged: null,
      reportBuilder: (_) => throw StateError('timed out task built a report'),
    );

    final snapshot = await task.done;

    expect(snapshot.state, StandardAnalysisTaskState.failed);
    expect(analyzer.sessions, hasLength(6));
    expect(
      analyzer.sessions.map((session) => session.disposeCalls),
      everyElement(1),
    );
  });

  test('invalidates standard reports produced by an older algorithm', () {
    final current = GameStandardAnalysisReport(
      moves: const [],
      stockfishBacked: true,
      stockfishStatus: 'ready',
      generatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
    final currentEntry = GameAnalysisReportCacheEntry.fromJson({
      'standard_report': current.toJson(),
    });
    final oldJson = current.toJson()..['algorithm_version'] = 2;
    final oldEntry = GameAnalysisReportCacheEntry.fromJson({
      'standard_report': oldJson,
    });

    expect(currentEntry.standardReport, isNotNull);
    expect(currentEntry.standardReport?.usesCurrentAlgorithm, isTrue);
    expect(currentEntry.standardReport?.analysisDepth, 16);
    expect(oldEntry.standardReport, isNull);
  });

  test('matches cached reports to their exact normalized PGN', () {
    const original = '[Event "Original"]\n\n1. e4 e5 *';
    const reformatted = '[Event "Original"]\n\n1.  e4   e5  *';
    const updated = '[Event "Updated"]\n\n1. d4 d5 *';
    const entry = GameAnalysisReportCacheEntry(pgn: original);

    expect(gameAnalysisReportCacheEntryMatchesPgn(entry, reformatted), isTrue);
    expect(gameAnalysisReportCacheEntryMatchesPgn(entry, updated), isFalse);
    expect(
      gameAnalysisReportCacheEntryMatchesPgn(
        const GameAnalysisReportCacheEntry(),
        original,
      ),
      isFalse,
    );
  });

  test('does not persist an incomplete standard report', () async {
    const pgn = '''
[Event "Incomplete Analysis"]
[Result "*"]

1. e4 *
''';
    final parsedGame = GameNotationService.parsePgn(pgn);
    final completed = Completer<void>()..complete();
    final store = AppPreferencesAnalysisReportCacheStore(
      MemoryAppPreferencesStore(),
    );
    var cacheChanged = 0;

    final task = StandardAnalysisTaskCoordinator().startOrAttachLocal(
      cacheKey: 'pgnhash:test-incomplete-analysis',
      pgn: pgn,
      parsedGame: parsedGame,
      engine: _DelayedAnalyzer(completed),
      cacheStore: store,
      onReportCacheChanged: () => cacheChanged++,
      reportBuilder: (_) => GameStandardAnalysisReport(
        moves: const [],
        stockfishBacked: true,
        stockfishStatus: 'partially ready',
        generatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        isComplete: false,
      ),
    );

    final snapshot = await task.done;

    expect(snapshot.state, StandardAnalysisTaskState.completed);
    expect(cacheChanged, 0);
    expect(
      await store.read('pgnhash:test-incomplete-analysis'),
      isNull,
    );
  });

  test('persists real engine candidate variations in standard reports', () {
    const move = CachedReviewMove(
      ply: 1,
      move: '1. e4',
      evalBefore: 0,
      evalAfter: 0.2,
      classification: 'Best',
      summary: 'Analyzed',
      fen: '',
      lastMove: ['e2', 'e4'],
      focusSquare: 'e4',
      engineLine: 'e4 e5',
      bestMove: 'Best: e4',
      keyMoment: false,
      candidateVariations: [
        CachedEngineVariation(
          moveUci: 'e2e4',
          line: 'e4 e5',
          whiteEval: 0.2,
        ),
        CachedEngineVariation(
          moveUci: 'd2d4',
          line: 'd4 d5',
          whiteEval: 0.1,
        ),
      ],
    );

    final restored = CachedReviewMove.fromJson(move.toJson());

    expect(restored.candidateVariations, hasLength(2));
    expect(restored.candidateVariations.last.moveUci, 'd2d4');
    expect(restored.candidateVariations.last.line, 'd4 d5');
  });
}

class _DelayedAnalyzer implements PositionAnalyzer {
  _DelayedAnalyzer(this.completer);

  final Completer<void> completer;
  int calls = 0;
  final depths = <int>[];
  final multiPvs = <int>[];

  @override
  Future<PositionEngineAnalysis?> analyzeFen(
    String fen, {
    int depth = 12,
    int multiPv = 1,
  }) async {
    calls++;
    depths.add(depth);
    multiPvs.add(multiPv);
    await completer.future;
    return PositionEngineAnalysis(
      fen: fen,
      depth: depth,
      whiteEval: calls.isOdd ? 0.25 : 0.10,
      bestMoveUci: 'e2e4',
      pv: const ['e2e4', 'e7e5'],
      isEngineBacked: true,
    );
  }
}

class _LiveDelayedAnalyzer implements PositionAnalyzer, LivePositionAnalyzer {
  final _DisposableStockfishSession session = _DisposableStockfishSession();

  @override
  StockfishAnalysisSession createLiveSession() => session;

  @override
  Future<PositionEngineAnalysis?> analyzeFen(
    String fen, {
    int depth = 12,
    int multiPv = 1,
  }) =>
      throw StateError('standard task should use the live session');
}

class _DisposableStockfishSession extends StockfishAnalysisSession {
  _DisposableStockfishSession() : super(const StockfishPositionAnalyzer());

  final Completer<PositionEngineAnalysis?> _analysis = Completer();
  int startCalls = 0;
  int disposeCalls = 0;
  bool _disposed = false;

  @override
  Future<PositionEngineAnalysis?> start(
    String fen, {
    required StockfishAnalysisLimit limit,
    int multiPv = 3,
    required void Function(PositionEngineAnalysis update) onUpdate,
  }) {
    startCalls++;
    return _analysis.future;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    disposeCalls++;
    _analysis.complete(null);
  }
}

class _TimeoutThenSuccessLiveAnalyzer
    implements PositionAnalyzer, LivePositionAnalyzer {
  final sessions = <_TimeoutThenSuccessSession>[];

  @override
  StockfishAnalysisSession createLiveSession() {
    final session = _TimeoutThenSuccessSession(
      shouldTimeout: sessions.isEmpty,
    );
    sessions.add(session);
    return session;
  }

  @override
  Future<PositionEngineAnalysis?> analyzeFen(
    String fen, {
    int depth = 12,
    int multiPv = 1,
  }) =>
      throw StateError('standard task should use the live session');
}

class _TimeoutThenSuccessSession extends StockfishAnalysisSession {
  _TimeoutThenSuccessSession({required this.shouldTimeout})
      : super(const StockfishPositionAnalyzer());

  final bool shouldTimeout;
  int startCalls = 0;
  int disposeCalls = 0;

  @override
  Future<PositionEngineAnalysis?> start(
    String fen, {
    required StockfishAnalysisLimit limit,
    int multiPv = 3,
    required void Function(PositionEngineAnalysis update) onUpdate,
  }) async {
    startCalls++;
    if (shouldTimeout) {
      throw TimeoutException('Stockfish startup timed out');
    }
    return PositionEngineAnalysis(
      fen: fen,
      depth: limit.depth ?? 20,
      whiteEval: 0.2,
      bestMoveUci: 'e2e4',
      pv: const ['e2e4'],
      isEngineBacked: true,
    );
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

class _AlwaysTimeoutLiveAnalyzer
    implements PositionAnalyzer, LivePositionAnalyzer {
  final sessions = <_TimeoutThenSuccessSession>[];

  @override
  StockfishAnalysisSession createLiveSession() {
    final session = _TimeoutThenSuccessSession(shouldTimeout: true);
    sessions.add(session);
    return session;
  }

  @override
  Future<PositionEngineAnalysis?> analyzeFen(
    String fen, {
    int depth = 12,
    int multiPv = 1,
  }) =>
      throw StateError('standard task should use the live session');
}
