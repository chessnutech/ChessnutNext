import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dartchess/dartchess.dart' as dc;
import 'package:stockfish/stockfish.dart' deferred as stockfish_package;

import 'game_notation_service.dart';
import 'native_engine_queue.dart';
import 'stockfish_network_service.dart';

class UciScore {
  const UciScore({
    this.centipawns,
    this.mate,
  });

  final int? centipawns;
  final int? mate;

  double whitePawnScore({required String sideToMove}) {
    final mateValue = mate;
    final raw = mateValue != null
        ? (mateValue > 0
            ? 10.0 - mateValue.abs() / 10
            : -10.0 + mateValue.abs() / 10)
        : (centipawns ?? 0) / 100.0;
    return sideToMove == 'b' ? -raw : raw;
  }

  int? whiteMate({required String sideToMove}) {
    final mateValue = mate;
    if (mateValue == null) return null;
    return sideToMove == 'b' ? -mateValue : mateValue;
  }
}

class UciWdl {
  const UciWdl({
    required this.wins,
    required this.draws,
    required this.losses,
  });

  final int wins;
  final int draws;
  final int losses;

  double get sideExpectation {
    final total = wins + draws + losses;
    if (total <= 0) return 0.5;
    return (wins + draws * 0.5) / total;
  }

  double expectation({required String sideToMove}) {
    return sideToMove == 'b' ? 1 - sideExpectation : sideExpectation;
  }
}

class UciInfo {
  const UciInfo({
    required this.depth,
    required this.score,
    required this.pv,
    this.multiPv = 1,
    this.wdl,
    this.isBound = false,
  });

  final int depth;
  final UciScore score;
  final List<String> pv;
  final int multiPv;
  final UciWdl? wdl;
  final bool isBound;
}

class UciInfoParser {
  const UciInfoParser._();

  static UciInfo? parseInfoLine(String line) {
    final tokens = line.trim().split(RegExp(r'\s+'));
    if (tokens.isEmpty || tokens.first != 'info') return null;
    final depthIndex = tokens.indexOf('depth');
    final scoreIndex = tokens.indexOf('score');
    if (depthIndex < 0 ||
        depthIndex + 1 >= tokens.length ||
        scoreIndex < 0 ||
        scoreIndex + 2 >= tokens.length) {
      return null;
    }

    final depth = int.tryParse(tokens[depthIndex + 1]);
    if (depth == null) return null;
    final multiPvIndex = tokens.indexOf('multipv');
    final multiPv = multiPvIndex >= 0 && multiPvIndex + 1 < tokens.length
        ? int.tryParse(tokens[multiPvIndex + 1]) ?? 1
        : 1;

    final scoreKind = tokens[scoreIndex + 1];
    final scoreValue = int.tryParse(tokens[scoreIndex + 2]);
    if (scoreValue == null) return null;
    final pvIndex = tokens.indexOf('pv');
    final pv = pvIndex >= 0 && pvIndex + 1 < tokens.length
        ? tokens.sublist(pvIndex + 1)
        : const <String>[];
    final wdlIndex = tokens.indexOf('wdl');
    final wdl = wdlIndex >= 0 && wdlIndex + 3 < tokens.length
        ? switch ((
            int.tryParse(tokens[wdlIndex + 1]),
            int.tryParse(tokens[wdlIndex + 2]),
            int.tryParse(tokens[wdlIndex + 3]),
          )) {
            (final int wins, final int draws, final int losses) => UciWdl(
                wins: wins,
                draws: draws,
                losses: losses,
              ),
            _ => null,
          }
        : null;

    return UciInfo(
      depth: depth,
      score: scoreKind == 'mate'
          ? UciScore(mate: scoreValue)
          : UciScore(centipawns: scoreValue),
      pv: List.unmodifiable(pv),
      multiPv: multiPv,
      wdl: wdl,
      isBound: tokens.contains('lowerbound') || tokens.contains('upperbound'),
    );
  }
}

enum EngineScoreMapLevel {
  unknown,
  best,
  excellent,
  good,
  inaccuracy,
  mistake,
  blunder,
}

class EngineMoveCandidate {
  const EngineMoveCandidate({
    required this.moveUci,
    this.scoreCentipawns,
    this.scoreMate,
    this.outcomeExpectation,
    this.pv = const [],
  });

  final String moveUci;
  final int? scoreCentipawns;
  final int? scoreMate;
  final double? outcomeExpectation;
  final List<String> pv;

  /// Stockfish reports a candidate score from the side-to-move perspective.
  /// Convert it to the fixed white perspective used by Lichess for display.
  double whitePawnScore({required String sideToMove}) => UciScore(
        centipawns: scoreCentipawns,
        mate: scoreMate,
      ).whitePawnScore(sideToMove: sideToMove);

  /// Returns the mate distance using the fixed white perspective.
  int? whiteMate({required String sideToMove}) => UciScore(
        centipawns: scoreCentipawns,
        mate: scoreMate,
      ).whiteMate(sideToMove: sideToMove);
}

class EngineScoreMap {
  const EngineScoreMap({
    required this.actualMoveUci,
    required this.candidates,
  })  : _assessedLevel = null,
        _assessedAccuracy = null;

  const EngineScoreMap.assessed({
    required EngineScoreMapLevel level,
    required double accuracyPercent,
  })  : actualMoveUci = '',
        candidates = const [],
        _assessedLevel = level,
        _assessedAccuracy = accuracyPercent;

  final String actualMoveUci;
  final List<EngineMoveCandidate> candidates;
  final EngineScoreMapLevel? _assessedLevel;
  final double? _assessedAccuracy;

  EngineScoreMapLevel get level {
    final assessed = _assessedLevel;
    if (assessed != null) return assessed;
    final target = _targetCandidate;
    if (target == null) return EngineScoreMapLevel.unknown;
    final best = _bestCandidate;
    if (best == null) return EngineScoreMapLevel.unknown;
    final mateLevel = _mateCandidateLevel(best: best, target: target);
    if (mateLevel != null) return mateLevel;
    final bestExpectation = _candidateExpectation(best);
    final targetExpectation = _candidateExpectation(target);
    if (bestExpectation == null || targetExpectation == null) {
      return EngineScoreMapLevel.unknown;
    }
    return _levelForOutcomeLoss(bestExpectation - targetExpectation);
  }

  int? get legacyLevel {
    return switch (level) {
      EngineScoreMapLevel.best => 1,
      EngineScoreMapLevel.excellent => 2,
      EngineScoreMapLevel.good => 3,
      EngineScoreMapLevel.inaccuracy => 4,
      EngineScoreMapLevel.mistake => 5,
      EngineScoreMapLevel.blunder => 6,
      EngineScoreMapLevel.unknown => null,
    };
  }

  double? get accuracyPercent {
    final assessed = _assessedAccuracy;
    if (assessed != null) return assessed;
    final target = _targetCandidate;
    if (target == null) return null;
    final best = _bestCandidate;
    if (best == null) return null;
    final bestMate = best.scoreMate;
    final targetMate = target.scoreMate;
    if (bestMate != null &&
        targetMate != null &&
        bestMate.sign == targetMate.sign) {
      if (bestMate > 0) {
        final extraMoves = targetMate.abs() - bestMate.abs();
        return (100 - math.max(0, extraMoves) * 5).clamp(70, 100).toDouble();
      }
      final lostMoves = bestMate.abs() - targetMate.abs();
      return (100 - math.max(0, lostMoves) * 8).clamp(40, 100).toDouble();
    }
    final bestExpectation = _candidateExpectation(best);
    final targetExpectation = _candidateExpectation(target);
    if (bestExpectation == null || targetExpectation == null) return null;
    return _accuracyForOutcomeLoss(bestExpectation - targetExpectation);
  }

  EngineMoveCandidate? get _bestCandidate {
    EngineMoveCandidate? best;
    double? bestExpectation;
    for (final candidate in candidates) {
      final expectation = _candidateExpectation(candidate);
      if (expectation == null) continue;
      if (best == null || expectation > bestExpectation!) {
        best = candidate;
        bestExpectation = expectation;
        continue;
      }
      if (expectation == bestExpectation &&
          candidate.scoreMate != null &&
          best.scoreMate != null) {
        final candidateMate = candidate.scoreMate!;
        final bestMate = best.scoreMate!;
        final candidateIsBetter = candidateMate > 0
            ? candidateMate.abs() < bestMate.abs()
            : candidateMate.abs() > bestMate.abs();
        if (candidateIsBetter) {
          best = candidate;
        }
      }
    }
    return best;
  }

  EngineMoveCandidate? get _targetCandidate {
    for (final candidate in candidates) {
      if (candidate.moveUci == actualMoveUci) return candidate;
    }
    return null;
  }
}

EngineScoreMapLevel? _mateCandidateLevel({
  required EngineMoveCandidate best,
  required EngineMoveCandidate target,
}) {
  final bestMate = best.scoreMate;
  final targetMate = target.scoreMate;
  if (bestMate == null && targetMate == null) return null;
  if (bestMate != null && bestMate > 0) {
    if (targetMate == null || targetMate <= 0) {
      return EngineScoreMapLevel.blunder;
    }
    final extraMoves = targetMate.abs() - bestMate.abs();
    if (extraMoves <= 0) return EngineScoreMapLevel.best;
    if (extraMoves == 1) return EngineScoreMapLevel.excellent;
    if (extraMoves <= 3) return EngineScoreMapLevel.good;
    return EngineScoreMapLevel.inaccuracy;
  }
  if (targetMate != null && targetMate > 0) return EngineScoreMapLevel.best;
  if (targetMate != null && targetMate < 0) {
    if (bestMate == null || bestMate >= 0) return EngineScoreMapLevel.blunder;
    final lostMoves = bestMate.abs() - targetMate.abs();
    if (lostMoves <= 0) return EngineScoreMapLevel.best;
    if (lostMoves == 1) return EngineScoreMapLevel.good;
    if (lostMoves <= 3) return EngineScoreMapLevel.inaccuracy;
    return EngineScoreMapLevel.mistake;
  }
  return null;
}

double? _candidateExpectation(EngineMoveCandidate candidate) {
  final mate = candidate.scoreMate;
  if (mate != null) {
    final mateCentipawns = mate > 0 ? 1000 : -1000;
    return _lichessWinPercentFromCentipawns(mateCentipawns) / 100;
  }
  final centipawns = candidate.scoreCentipawns;
  if (centipawns == null) return null;
  return _lichessWinPercentFromCentipawns(centipawns) / 100;
}

class PositionEngineAnalysis {
  const PositionEngineAnalysis({
    required this.fen,
    required this.depth,
    required this.whiteEval,
    required this.bestMoveUci,
    required this.pv,
    required this.isEngineBacked,
    this.candidateMoves = const [],
    this.whiteMate,
    this.whiteOutcomeExpectation,
  });

  final String fen;
  final int depth;
  final double whiteEval;
  final String? bestMoveUci;
  final List<String> pv;
  final bool isEngineBacked;
  final List<EngineMoveCandidate> candidateMoves;
  final int? whiteMate;
  final double? whiteOutcomeExpectation;
}

abstract interface class PositionAnalyzer {
  Future<PositionEngineAnalysis?> analyzeFen(
    String fen, {
    int depth = 12,
    int multiPv = 1,
  });
}

/// A depth limit for the interactive board analyzer. A null depth means that
/// Stockfish should keep searching until the session is stopped.
class StockfishAnalysisLimit {
  const StockfishAnalysisLimit.fixed(int depth)
      : depth = depth,
        assert(depth >= 6 && depth <= 20),
        isUnlimited = false;

  const StockfishAnalysisLimit.unlimited()
      : depth = null,
        isUnlimited = true;

  final int? depth;
  final bool isUnlimited;
}

/// Optional capability implemented by the real Stockfish analyzer. Keeping
/// this separate from [PositionAnalyzer] means test/fallback analyzers and
/// the PGN report pipeline do not need to become streaming analyzers.
abstract interface class LivePositionAnalyzer {
  StockfishAnalysisSession createLiveSession();
}

class StockfishPositionAnalyzer
    implements PositionAnalyzer, LivePositionAnalyzer {
  const StockfishPositionAnalyzer({
    this.workingDirectory,
    this.executableDirectory,
    this.timeout = const Duration(seconds: 10),
    this.startupTimeout = const Duration(seconds: 8),
    this.stockfishNetworks = const MethodChannelStockfishNetworkService(),
  });

  final String? workingDirectory;
  final String? executableDirectory;
  final Duration timeout;
  final Duration startupTimeout;
  final StockfishNetworkService stockfishNetworks;

  @override
  StockfishAnalysisSession createLiveSession() =>
      StockfishAnalysisSession(this);

  String get _effectiveWorkingDirectory =>
      workingDirectory ?? Directory.current.path;

  String get _effectiveExecutableDirectory =>
      executableDirectory ?? File(Platform.resolvedExecutable).parent.path;

  @override
  Future<PositionEngineAnalysis?> analyzeFen(
    String fen, {
    int depth = 12,
    int multiPv = 1,
  }) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final native = await _analyzeWithNativeStockfish(
        fen,
        depth: depth,
        multiPv: multiPv,
      );
      if (native != null) return native;
    }
    final runtime = _resolveStockfishRuntime();
    if (runtime == null) return null;

    Process? process;
    StreamSubscription<String>? outputSub;
    final lines = StreamController<String>();
    UciInfo? latestInfo;
    final latestByMultiPv = <int, UciInfo>{};
    try {
      process = await Process.start(
        runtime.executable,
        const [],
        workingDirectory: runtime.root,
        runInShell: Platform.isWindows,
      );
      outputSub = process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen((line) {
        final info = UciInfoParser.parseInfoLine(line);
        if (info != null && !info.isBound && info.pv.isNotEmpty) {
          latestInfo = info.multiPv == 1 ? info : latestInfo;
          latestByMultiPv[info.multiPv] = info;
        }
        lines.add(line);
      });
      process.stderr.drain<void>();

      final startupCommands = stockfishStartupCommands(
        [
          'setoption name MultiPV value ${multiPv.clamp(1, 256)}',
          'setoption name UCI_ShowWDL value true',
        ],
        _resolvePackagedStockfishNetworks(runtime),
      );
      for (final command in [
        'uci',
        ...startupCommands,
        'isready',
        'ucinewgame',
        'position fen $fen',
        'go depth $depth',
      ]) {
        process.stdin.writeln(command);
      }

      final bestMoveLine = await lines.stream
          .firstWhere((line) => line.startsWith('bestmove '))
          .timeout(timeout);
      final bestMove = bestMoveLine.split(RegExp(r'\s+')).elementAtOrNull(1);
      final info = latestInfo;
      if (info == null) return null;
      return PositionEngineAnalysis(
        fen: fen,
        depth: info.depth,
        whiteEval:
            info.score.whitePawnScore(sideToMove: _sideToMoveFromFen(fen)),
        whiteMate: info.score.whiteMate(sideToMove: _sideToMoveFromFen(fen)),
        whiteOutcomeExpectation:
            info.wdl?.expectation(sideToMove: _sideToMoveFromFen(fen)),
        bestMoveUci: bestMove == '(none)' ? null : bestMove,
        pv: info.pv,
        isEngineBacked: true,
        candidateMoves: _candidateMovesFromUciInfo(latestByMultiPv),
      );
    } catch (_) {
      return null;
    } finally {
      await outputSub?.cancel();
      await lines.close();
      process?.stdin.writeln('quit');
      process?.kill();
    }
  }

  Future<PositionEngineAnalysis?> _analyzeWithNativeStockfish(
    String fen, {
    required int depth,
    required int multiPv,
  }) async {
    return nativeEngineQueue.run(() async {
      dynamic engine;
      StreamSubscription<String>? outputSub;
      final lines = StreamController<String>.broadcast();
      UciInfo? latestInfo;
      final latestByMultiPv = <int, UciInfo>{};
      final stockfishPaths = await stockfishNetworks.prepare();
      if (Platform.isAndroid && stockfishPaths == null) {
        return null;
      }
      try {
        await stockfish_package.loadLibrary();
        await stockfish_package.disposeCurrentStockfish();
        engine =
            await stockfish_package.stockfishAsync().timeout(startupTimeout);
        outputSub = (engine.stdout as Stream<String>).listen((line) {
          final normalized = line.trim();
          if (normalized.isEmpty) return;
          final info = UciInfoParser.parseInfoLine(normalized);
          if (info != null && !info.isBound && info.pv.isNotEmpty) {
            latestInfo = info.multiPv == 1 ? info : latestInfo;
            latestByMultiPv[info.multiPv] = info;
          }
          lines.add(normalized);
        });

        void write(String command) {
          engine.stdin = command;
        }

        final uciOk = lines.stream
            .firstWhere((line) => line == 'uciok')
            .timeout(startupTimeout);
        write('uci');
        await uciOk;

        for (final command in stockfishStartupCommands(
          [
            'setoption name MultiPV value ${multiPv.clamp(1, 256)}',
            'setoption name UCI_ShowWDL value true',
          ],
          stockfishPaths,
        )) {
          write(command);
        }
        final readyOk = lines.stream
            .firstWhere((line) => line == 'readyok')
            .timeout(startupTimeout);
        write('isready');
        await readyOk;

        final bestMoveFuture = lines.stream
            .firstWhere((line) => line.startsWith('bestmove '))
            .timeout(timeout);
        write('ucinewgame');
        write('position fen $fen');
        write('go depth $depth');
        final bestMoveLine = await bestMoveFuture;
        final bestMove = bestMoveLine.split(RegExp(r'\s+')).elementAtOrNull(1);
        final info = latestInfo;
        if (info == null) return null;
        return PositionEngineAnalysis(
          fen: fen,
          depth: info.depth,
          whiteEval:
              info.score.whitePawnScore(sideToMove: _sideToMoveFromFen(fen)),
          whiteMate: info.score.whiteMate(sideToMove: _sideToMoveFromFen(fen)),
          whiteOutcomeExpectation:
              info.wdl?.expectation(sideToMove: _sideToMoveFromFen(fen)),
          bestMoveUci: bestMove == '(none)' ? null : bestMove,
          pv: info.pv,
          isEngineBacked: true,
          candidateMoves: _candidateMovesFromUciInfo(latestByMultiPv),
        );
      } catch (_) {
        return null;
      } finally {
        await outputSub?.cancel();
        await lines.close();
        try {
          engine?.dispose();
        } catch (_) {}
        if (engine != null) {
          try {
            await (engine.done as Future<void>).timeout(
              const Duration(seconds: 3),
            );
          } catch (_) {
            await Future<void>.delayed(const Duration(milliseconds: 300));
          }
        }
      }
    });
  }

  _ResolvedStockfishRuntime? _resolveStockfishRuntime() {
    for (final root in _engineSearchRoots()) {
      for (final candidate in const [
        'stockfish/stockfish.exe',
        'stockfish.exe',
        'stockfish',
      ]) {
        final file = File(_joinPath(root, candidate));
        if (file.existsSync() &&
            file.statSync().type == FileSystemEntityType.file) {
          return _ResolvedStockfishRuntime(
            executable: file.absolute.path,
            root: root,
          );
        }
      }
    }
    return null;
  }

  String? resolveExecutablePathForTest() =>
      _resolveStockfishRuntime()?.executable;

  List<String> _engineSearchRoots() {
    final roots = <String>[
      _effectiveWorkingDirectory,
      _effectiveExecutableDirectory,
      ..._macOSBundleSearchRoots(_effectiveExecutableDirectory),
    ];
    return roots.toSet().toList(growable: false);
  }

  String _joinPath(String root, String child) {
    final separator = Platform.pathSeparator;
    final normalizedChild = child.replaceAll('/', separator);
    if (root.endsWith(separator)) return '$root$normalizedChild';
    return '$root$separator$normalizedChild';
  }

  StockfishNetworkPaths? _resolvePackagedStockfishNetworks(
    _ResolvedStockfishRuntime runtime,
  ) {
    final big = _resolvePackagedStockfishNetworkFile(
      runtime,
      'nn-c288c895ea92.nnue',
    );
    final small = _resolvePackagedStockfishNetworkFile(
      runtime,
      'nn-37f18f62d772.nnue',
    );
    if (big == null || small == null) return null;
    return StockfishNetworkPaths(bigPath: big, smallPath: small);
  }

  String? _resolvePackagedStockfishNetworkFile(
    _ResolvedStockfishRuntime runtime,
    String fileName,
  ) {
    final roots = [
      runtime.root,
      File(runtime.executable).parent.path,
      ..._engineSearchRoots(),
    ];
    final candidates = <String>[
      fileName,
      _joinPath('stockfish', fileName),
      _joinPath('Resources', _joinPath('stockfish', fileName)),
      _joinPath('Resources', fileName),
    ];
    for (final root in roots.toSet()) {
      for (final candidate in candidates) {
        final file = File(_joinPath(root, candidate));
        if (file.existsSync()) return file.absolute.path;
      }
    }
    return null;
  }
}

/// A page-scoped UCI session used by the interactive board analyzer. The
/// regular [PositionAnalyzer.analyzeFen] API intentionally remains a one-shot
/// API for reports and other callers.
class StockfishAnalysisSession {
  StockfishAnalysisSession(this.analyzer);

  final StockfishPositionAnalyzer analyzer;
  dynamic _nativeEngine;
  Process? _process;
  StreamSubscription<String>? _outputSubscription;
  StreamController<String>? _lines;
  Future<void>? _initializing;
  _LiveSearch? _search;
  int _startGeneration = 0;
  bool _initialized = false;
  bool _disposed = false;

  Future<void> _ensureEngine() async {
    if (_initialized) return;
    final pending = _initializing;
    if (pending != null) return pending;
    final future = _initializeEngine();
    _initializing = future;
    try {
      await future;
    } finally {
      if (identical(_initializing, future)) _initializing = null;
    }
  }

  Future<void> _initializeEngine() async {
    if (_disposed) throw StateError('Stockfish analysis session disposed');
    _lines = StreamController<String>.broadcast();
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final paths = await analyzer.stockfishNetworks.prepare();
        _throwIfDisposed();
        if (Platform.isAndroid && paths == null) {
          throw StateError('Stockfish networks are not ready');
        }
        await stockfish_package.loadLibrary();
        _throwIfDisposed();
        await stockfish_package.disposeCurrentStockfish();
        _throwIfDisposed();
        final engine = await stockfish_package
            .stockfishAsync()
            .timeout(analyzer.startupTimeout);
        if (_disposed) {
          await _disposeNativeEngine(engine);
          throw StateError('Stockfish analysis session disposed');
        }
        _nativeEngine = engine;
        _outputSubscription = engine.stdout.listen(_onEngineLine);
        await _sendAndWait('uci', (line) => line == 'uciok');
        for (final command in stockfishStartupCommands(
          const [
            'setoption name MultiPV value 3',
            'setoption name UCI_ShowWDL value true',
          ],
          paths,
        )) {
          _send(command);
        }
        await _sendAndWait('isready', (line) => line == 'readyok');
      } else {
        final runtime = analyzer._resolveStockfishRuntime();
        if (runtime == null) throw StateError('Stockfish executable not found');
        final process = await Process.start(
          runtime.executable,
          const [],
          workingDirectory: runtime.root,
          runInShell: Platform.isWindows,
        );
        if (_disposed) {
          await _disposeProcess(process);
          throw StateError('Stockfish analysis session disposed');
        }
        _process = process;
        _outputSubscription = process.stdout
            .transform(const Utf8Decoder(allowMalformed: true))
            .transform(const LineSplitter())
            .listen(_onEngineLine);
        unawaited(process.stderr.drain<void>());
        final paths = analyzer._resolvePackagedStockfishNetworks(runtime);
        await _sendAndWait('uci', (line) => line == 'uciok');
        for (final command in stockfishStartupCommands(
          const [
            'setoption name MultiPV value 3',
            'setoption name UCI_ShowWDL value true',
          ],
          paths,
        )) {
          _send(command);
        }
        await _sendAndWait('isready', (line) => line == 'readyok');
      }
      _throwIfDisposed();
      _initialized = true;
    } catch (_) {
      await _closeEngineResources();
      rethrow;
    }
  }

  void _throwIfDisposed() {
    if (_disposed) throw StateError('Stockfish analysis session disposed');
  }

  Future<void> _sendAndWait(
    String command,
    bool Function(String line) predicate,
  ) async {
    final lines = _lines;
    if (lines == null) throw StateError('Stockfish output is unavailable');
    final future =
        lines.stream.firstWhere(predicate).timeout(analyzer.startupTimeout);
    _send(command);
    await future;
  }

  void _send(String command) {
    if (_nativeEngine != null) {
      _nativeEngine.stdin = command;
    } else {
      _process?.stdin.writeln(command);
    }
  }

  Future<PositionEngineAnalysis?> start(
    String fen, {
    required StockfishAnalysisLimit limit,
    int multiPv = 3,
    required void Function(PositionEngineAnalysis update) onUpdate,
  }) async {
    final generation = ++_startGeneration;
    await stop();
    await _ensureEngine();
    if (_disposed) throw StateError('Stockfish analysis session disposed');
    if (generation != _startGeneration) return null;
    final search = _LiveSearch(
      fen: fen,
      limit: limit,
      multiPv: multiPv.clamp(1, 256).toInt(),
      onUpdate: onUpdate,
    );
    _search = search;
    _send('setoption name MultiPV value ${search.multiPv}');
    _send('ucinewgame');
    _send('position fen $fen');
    _send(limit.isUnlimited ? 'go infinite' : 'go depth ${limit.depth}');
    return search.done.future;
  }

  Future<void> stop() async {
    final search = _search;
    if (search == null) return;
    search.stopping = true;
    try {
      _send('stop');
      await search.done.future.timeout(const Duration(seconds: 3));
    } catch (_) {
      if (!search.done.isCompleted) search.done.complete(null);
    } finally {
      if (identical(_search, search)) _search = null;
    }
  }

  void _onEngineLine(String rawLine) {
    final line = rawLine.trim();
    if (line.isEmpty) return;
    _lines?.add(line);
    final search = _search;
    if (search == null) return;
    if (line.startsWith('bestmove ')) {
      final parts = line.split(RegExp(r'\s+'));
      search.bestMoveUci =
          parts.length > 1 && parts[1] != '(none)' ? parts[1] : null;
      final result = _snapshotFor(search);
      if (search.stopping || !search.limit.isUnlimited) {
        if (!search.done.isCompleted) search.done.complete(result);
        if (!search.limit.isUnlimited && identical(_search, search)) {
          _search = null;
        }
      }
      return;
    }
    final info = UciInfoParser.parseInfoLine(line);
    if (info == null || info.isBound || info.pv.isEmpty) return;
    search.latestByMultiPv[info.multiPv] = info;
    if (info.multiPv != 1 && info.multiPv != search.multiPv) return;
    final primary = search.latestByMultiPv[1] ?? info;
    final completedCurrentMultiPv =
        info.multiPv == search.multiPv && info.depth == primary.depth;
    if (primary.depth > search.lastPublishedDepth ||
        (primary.depth == search.lastPublishedDepth &&
            completedCurrentMultiPv)) {
      search.lastPublishedDepth = primary.depth;
      search.onUpdate(_snapshotFor(search));
    }
  }

  PositionEngineAnalysis _snapshotFor(_LiveSearch search) {
    final primary = search.latestByMultiPv[1];
    final info = primary ?? search.latestByMultiPv.values.firstOrNull;
    final depth = info?.depth ?? 0;
    final currentDepthLines = <int, UciInfo>{
      for (final entry in search.latestByMultiPv.entries)
        if (entry.value.depth == depth) entry.key: entry.value,
    };
    final side = _sideToMoveFromFen(search.fen);
    return PositionEngineAnalysis(
      fen: search.fen,
      depth: depth,
      whiteEval: info?.score.whitePawnScore(sideToMove: side) ?? 0,
      whiteMate: info?.score.whiteMate(sideToMove: side),
      whiteOutcomeExpectation: info?.wdl?.expectation(sideToMove: side),
      bestMoveUci: search.bestMoveUci ?? info?.pv.firstOrNull,
      pv: info?.pv ?? const <String>[],
      isEngineBacked: true,
      candidateMoves: _candidateMovesFromUciInfo(currentDepthLines),
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _startGeneration++;
    await stop();
    await _closeEngineResources();
    final initializing = _initializing;
    if (initializing != null) {
      try {
        await initializing;
      } catch (_) {}
      await _closeEngineResources();
    }
  }

  Future<void> _closeEngineResources() async {
    final outputSubscription = _outputSubscription;
    _outputSubscription = null;
    await outputSubscription?.cancel();

    final nativeEngine = _nativeEngine;
    _nativeEngine = null;
    if (nativeEngine != null) await _disposeNativeEngine(nativeEngine);

    final process = _process;
    _process = null;
    if (process != null) await _disposeProcess(process);

    _initialized = false;
    final lines = _lines;
    _lines = null;
    await lines?.close();
  }

  Future<void> _disposeNativeEngine(dynamic engine) async {
    try {
      engine.stdin = 'quit';
    } catch (_) {}
    try {
      engine.dispose();
    } catch (_) {}
    try {
      await (engine.done as Future<void>).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<void> _disposeProcess(Process process) async {
    try {
      process.stdin.writeln('quit');
    } catch (_) {}
    process.kill();
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } catch (_) {}
  }
}

class _LiveSearch {
  _LiveSearch({
    required this.fen,
    required this.limit,
    required this.multiPv,
    required this.onUpdate,
  });

  final String fen;
  final StockfishAnalysisLimit limit;
  final int multiPv;
  final void Function(PositionEngineAnalysis update) onUpdate;
  final Completer<PositionEngineAnalysis?> done =
      Completer<PositionEngineAnalysis?>();
  final Map<int, UciInfo> latestByMultiPv = <int, UciInfo>{};
  int lastPublishedDepth = 0;
  String? bestMoveUci;
  bool stopping = false;
}

class _ResolvedStockfishRuntime {
  const _ResolvedStockfishRuntime({
    required this.executable,
    required this.root,
  });

  final String executable;
  final String root;
}

List<String> _macOSBundleSearchRoots(String executableDirectory) {
  if (!Platform.isMacOS) return const [];
  final executableDir = Directory(executableDirectory);
  final contentsDir = executableDir.parent;
  if (contentsDir.path.endsWith('${Platform.pathSeparator}Contents')) {
    return [
      _joinPlatformPath(contentsDir.path, 'Resources'),
      _joinPlatformPath(
        contentsDir.path,
        'Frameworks/App.framework/Versions/A/Resources/flutter_assets',
      ),
    ];
  }
  return const [];
}

String _joinPlatformPath(String root, String child) {
  final separator = Platform.pathSeparator;
  final normalizedChild = child.replaceAll('/', separator);
  if (root.endsWith(separator)) return '$root$normalizedChild';
  return '$root$separator$normalizedChild';
}

class MoveEngineInsight {
  const MoveEngineInsight({
    required this.ply,
    required this.evalBefore,
    required this.evalAfter,
    required this.depth,
    required this.bestMoveUci,
    required this.bestMoveSan,
    required this.engineLine,
    this.candidateVariations = const [],
    required this.classification,
    this.scoreMap,
    required this.isEngineBacked,
  });

  final int ply;
  final double evalBefore;
  final double evalAfter;
  final int depth;
  final String? bestMoveUci;
  final String? bestMoveSan;
  final String engineLine;
  final List<EngineVariationInsight> candidateVariations;
  final String classification;
  final EngineScoreMap? scoreMap;
  final bool isEngineBacked;
}

class EngineVariationInsight {
  const EngineVariationInsight({
    required this.moveUci,
    required this.line,
    required this.whiteEval,
    this.whiteMate,
  });

  final String moveUci;
  final String line;
  final double whiteEval;
  final int? whiteMate;
}

class MoveQualityAssessment {
  const MoveQualityAssessment({
    required this.classification,
    required this.level,
    required this.accuracyPercent,
  });

  final String classification;
  final EngineScoreMapLevel level;
  final double accuracyPercent;
}

class StockfishGameAnalysisProgress {
  const StockfishGameAnalysisProgress({
    required this.completedPositions,
    required this.totalPositions,
  });

  final int completedPositions;
  final int totalPositions;

  double get percent {
    if (totalPositions <= 0) return 0;
    return (completedPositions / totalPositions).clamp(0, 1).toDouble();
  }

  int get percentValue => (percent * 100).round().clamp(0, 100).toInt();

  String get percentLabel => '$percentValue%';
}

class StockfishGameAnalysisService {
  const StockfishGameAnalysisService({required this.engine});

  final PositionAnalyzer engine;

  Future<List<MoveEngineInsight>> analyzeGame(
    ParsedPgnGame game, {
    int depth = 16,
    void Function(StockfishGameAnalysisProgress progress)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    final cache = <String, PositionEngineAnalysis>{};
    final attempted = <String>{};
    var completedPositions = 0;
    final totalPositions =
        game.snapshots.map((snapshot) => snapshot.fen).toSet().length;

    void emitProgress() {
      onProgress?.call(StockfishGameAnalysisProgress(
        completedPositions: completedPositions.clamp(0, totalPositions).toInt(),
        totalPositions: totalPositions,
      ));
    }

    Future<PositionEngineAnalysis?> analyze(String fen) async {
      if (shouldCancel?.call() == true) return null;
      final cached = cache[fen];
      if (cached != null) return cached;
      if (!attempted.add(fen)) return null;
      final result = await engine.analyzeFen(fen, depth: depth, multiPv: 3);
      if (shouldCancel?.call() == true) return null;
      completedPositions++;
      emitProgress();
      if (result != null) {
        cache[fen] = result;
      }
      return result;
    }

    emitProgress();
    final insights = <MoveEngineInsight>[];
    for (final move in game.moves.reversed) {
      if (shouldCancel?.call() == true) break;
      final after = await analyze(move.fenAfter);
      if (shouldCancel?.call() == true) break;
      final before = await analyze(move.fenBefore);
      if (shouldCancel?.call() == true) break;
      if (before == null) continue;
      final isCheckmate = move.san.contains('#');
      if (after == null && !isCheckmate) continue;
      final whiteMoved = _sideToMoveFromFen(move.fenBefore) == 'w';
      final terminalWhiteEval = whiteMoved ? 10.0 : -10.0;
      final afterEval = after?.whiteEval ?? terminalWhiteEval;
      final candidateRank = _candidateRank(
        before.candidateMoves,
        move.uci,
      );
      final thirdCandidateExpectation = before.candidateMoves.length >= 3
          ? _candidateExpectation(before.candidateMoves[2])
          : null;
      final topCandidateExpectation = before.candidateMoves.isNotEmpty
          ? _candidateExpectation(before.candidateMoves.first)
          : null;
      final assessment = assessMove(
        whiteMoved: whiteMoved,
        actualMoveUci: move.uci,
        bestMoveUci: before.bestMoveUci,
        before: before.whiteEval,
        after: afterEval,
        beforeMate: before.whiteMate,
        afterMate:
            after?.whiteMate ?? (isCheckmate ? (whiteMoved ? 1 : -1) : null),
        beforeWhiteOutcomeExpectation: before.whiteOutcomeExpectation,
        afterWhiteOutcomeExpectation:
            after?.whiteOutcomeExpectation ?? (whiteMoved ? 1 : 0),
        deliveredCheckmate: isCheckmate,
        candidateRank: candidateRank,
        topCandidateExpectation: topCandidateExpectation,
        thirdCandidateExpectation: thirdCandidateExpectation,
      );
      insights.add(
        MoveEngineInsight(
          ply: move.ply,
          evalBefore: before.whiteEval,
          evalAfter: afterEval,
          depth: math.min(before.depth, after?.depth ?? before.depth),
          bestMoveUci: before.bestMoveUci,
          bestMoveSan: before.bestMoveUci == null
              ? null
              : _uciMoveToSan(
                  fen: move.fenBefore,
                  uci: before.bestMoveUci!,
                ),
          engineLine: _principalVariationSanLine(
            fen: move.fenBefore,
            uciMoves: before.pv,
          ),
          candidateVariations: _candidateVariations(
            fen: move.fenBefore,
            candidates: before.candidateMoves,
          ),
          classification: assessment.classification,
          scoreMap: EngineScoreMap.assessed(
            level: assessment.level,
            accuracyPercent: assessment.accuracyPercent,
          ),
          isEngineBacked:
              before.isEngineBacked && (after?.isEngineBacked ?? isCheckmate),
        ),
      );
    }
    insights.sort((left, right) => left.ply.compareTo(right.ply));
    return List.unmodifiable(insights);
  }

  static String classifyMove({
    required bool whiteMoved,
    required String actualMoveUci,
    required String? bestMoveUci,
    required double before,
    required double after,
  }) {
    return assessMove(
      whiteMoved: whiteMoved,
      actualMoveUci: actualMoveUci,
      bestMoveUci: bestMoveUci,
      before: before,
      after: after,
    ).classification;
  }

  static MoveQualityAssessment assessMove({
    required bool whiteMoved,
    required String actualMoveUci,
    required String? bestMoveUci,
    required double before,
    required double after,
    int? beforeMate,
    int? afterMate,
    double? beforeWhiteOutcomeExpectation,
    double? afterWhiteOutcomeExpectation,
    bool deliveredCheckmate = false,
    int? candidateRank,
    double? topCandidateExpectation,
    double? thirdCandidateExpectation,
  }) {
    // Error labels follow Lichess' Advice implementation. Positive labels
    // remain on the app's original score/expected-outcome scale so that
    // accurate moves retain the finer Best/Excellent/Good distinctions.
    final beforeMoverEval = whiteMoved ? before : -before;
    final afterMoverEval = whiteMoved ? after : -after;
    final beforeMoverMate = _mateForMover(
      beforeMate,
      whiteMoved: whiteMoved,
      whiteEval: before,
    );
    final afterMoverMate = _mateForMover(
      afterMate,
      whiteMoved: whiteMoved,
      whiteEval: after,
    );
    final beforeWinningChance = _lichessWinningChanceForMoverScore(
      beforeMoverEval,
      mate: beforeMoverMate,
    );
    final afterWinningChance = _lichessWinningChanceForMoverScore(
      afterMoverEval,
      mate: afterMoverMate,
    );
    final lichessAdviceDelta = math.max(
      0.0,
      beforeWinningChance - afterWinningChance,
    );
    final beforeWinPercent = _lichessWinPercentForMoverScore(
      beforeMoverEval,
      mate: beforeMoverMate,
    );
    final afterWinPercent = _lichessWinPercentForMoverScore(
      afterMoverEval,
      mate: afterMoverMate,
    );
    final lichessAccuracy = _lichessAccuracyForWinPercentLoss(
      math.max(0.0, beforeWinPercent - afterWinPercent),
    );

    // CpAdvice requires two cp scores. If either side is a mate score, only
    // Lichess' MateAdvice transition rules can produce an error label.
    final mateClassification = beforeMoverMate != null || afterMoverMate != null
        ? _lichessMateClassification(
            beforeMate: beforeMoverMate,
            afterMate: afterMoverMate,
            beforeMoverEval: beforeMoverEval,
            afterMoverEval: afterMoverEval,
          )
        : null;
    final lichessError = beforeMoverMate != null || afterMoverMate != null
        ? mateClassification
        : switch (_levelForLichessAdviceDelta(lichessAdviceDelta)) {
            EngineScoreMapLevel.inaccuracy => 'Inaccuracy',
            EngineScoreMapLevel.mistake => 'Mistake',
            EngineScoreMapLevel.blunder => 'Blunder',
            _ => null,
          };
    if (lichessError != null) {
      return MoveQualityAssessment(
        classification: lichessError,
        level: _levelForLichessClassification(lichessError),
        accuracyPercent: lichessAccuracy,
      );
    }

    // No Lichess Advice means the move is not an error. The historical curve
    // may only select a positive label; it must never introduce an
    // Inaccuracy, Mistake, or Blunder after Lichess has accepted the move.
    final beforeWhiteExpectation = beforeWhiteOutcomeExpectation ??
        _whiteExpectation(before, mate: beforeMate);
    final afterWhiteExpectation = afterWhiteOutcomeExpectation ??
        _whiteExpectation(after, mate: afterMate);
    final beforeMoverExpectation =
        whiteMoved ? beforeWhiteExpectation : 1 - beforeWhiteExpectation;
    final afterMoverExpectation =
        whiteMoved ? afterWhiteExpectation : 1 - afterWhiteExpectation;
    final outcomeLoss = math.max(
      0.0,
      beforeMoverExpectation - afterMoverExpectation,
    );
    final historicalLevel = _levelForOutcomeLoss(outcomeLoss);
    final level = switch (historicalLevel) {
      EngineScoreMapLevel.best => EngineScoreMapLevel.best,
      EngineScoreMapLevel.excellent => EngineScoreMapLevel.excellent,
      _ => EngineScoreMapLevel.good,
    };
    final classification = switch (historicalLevel) {
      EngineScoreMapLevel.best =>
        bestMoveUci != null && actualMoveUci == bestMoveUci ? 'Best' : 'Great',
      EngineScoreMapLevel.excellent => 'Excellent',
      _ => 'Good',
    };
    return MoveQualityAssessment(
      classification: classification,
      level: level,
      accuracyPercent: historicalLevel.index <= EngineScoreMapLevel.good.index
          ? _accuracyForOutcomeLoss(outcomeLoss)
          : lichessAccuracy,
    );
  }
}

int? _candidateRank(
  List<EngineMoveCandidate> candidates,
  String actualMoveUci,
) {
  final normalized = actualMoveUci.toLowerCase();
  final index = candidates.indexWhere(
    (candidate) => candidate.moveUci.toLowerCase() == normalized,
  );
  return index < 0 ? null : index + 1;
}

int? _mateForMover(
  int? whiteMate, {
  required bool whiteMoved,
  required double whiteEval,
}) {
  if (whiteMate == null) return null;
  if (whiteMate != 0) return whiteMoved ? whiteMate : -whiteMate;
  final moverEval = whiteMoved ? whiteEval : -whiteEval;
  return moverEval >= 0 ? 1 : -1;
}

/// Lichess WinPercent.winningChances. Advice applies it to the raw cp score.
double _lichessWinningChanceFromCentipawns(int centipawns) =>
    (2 / (1 + math.exp(-0.00368208 * centipawns)) - 1).clamp(-1, 1).toDouble();

/// Lichess WinPercent.fromCentiPawns. Accuracy caps cp at +/-1000 first.
double _lichessWinPercentFromCentipawns(int centipawns) =>
    50 +
    50 *
        _lichessWinningChanceFromCentipawns(
          centipawns.clamp(-1000, 1000).toInt(),
        );

double _lichessWinPercentFromPawnEval(double pawnEval) =>
    _lichessWinPercentFromCentipawns((pawnEval * 100).round());

double _lichessWinningChanceForMoverScore(double pawnEval, {int? mate}) {
  if (mate != null && mate != 0) {
    return _lichessWinningChanceFromCentipawns(mate > 0 ? 1000 : -1000);
  }
  return _lichessWinningChanceFromCentipawns((pawnEval * 100).round());
}

double _lichessWinPercentForMoverScore(double pawnEval, {int? mate}) {
  if (mate != null && mate != 0) {
    return _lichessWinPercentFromCentipawns(mate > 0 ? 1000 : -1000);
  }
  return _lichessWinPercentFromPawnEval(pawnEval);
}

EngineScoreMapLevel _levelForOutcomeLoss(double loss) => loss <= 0.005
    ? EngineScoreMapLevel.best
    : loss <= 0.015
        ? EngineScoreMapLevel.excellent
        : loss <= 0.035
            ? EngineScoreMapLevel.good
            : loss <= 0.08
                ? EngineScoreMapLevel.inaccuracy
                : loss <= 0.18
                    ? EngineScoreMapLevel.mistake
                    : EngineScoreMapLevel.blunder;

double _accuracyForOutcomeLoss(double loss) => loss <= 0
    ? 100
    : (103.1668 * math.exp(-0.04354 * loss * 100) - 3.1669)
        .clamp(0, 100)
        .toDouble();

double _whiteExpectation(double whiteEval, {int? mate}) {
  if (mate != null) {
    if (mate > 0) return 1;
    if (mate < 0) return 0;
    return whiteEval >= 0 ? 1 : 0;
  }
  final bounded = whiteEval.clamp(-12.0, 12.0).toDouble();
  return 1 / (1 + math.exp(-0.368208 * bounded));
}

/// Lichess AccuracyPercent.fromWinPercents. Winning chances (-1..1) are first
/// converted to WinPercent points with a factor of 50. Lichess adds a +1
/// uncertainty bonus and clamps the result to [0, 100].
double _lichessAccuracyForWinPercentLoss(double winPercentLoss) {
  if (winPercentLoss <= 0) return 100;
  final lossPercent = math.max(0.0, winPercentLoss);
  return (103.1668100711649 * math.exp(-0.04354415386753951 * lossPercent) -
          3.166924740191411 +
          1)
      .clamp(0, 100)
      .toDouble();
}

EngineScoreMapLevel _levelForLichessAdviceDelta(double delta) {
  if (delta >= 0.3) return EngineScoreMapLevel.blunder;
  if (delta >= 0.2) return EngineScoreMapLevel.mistake;
  if (delta >= 0.1) return EngineScoreMapLevel.inaccuracy;
  return EngineScoreMapLevel.good;
}

EngineScoreMapLevel _levelForLichessClassification(String classification) {
  return switch (classification) {
    'Blunder' => EngineScoreMapLevel.blunder,
    'Mistake' => EngineScoreMapLevel.mistake,
    'Inaccuracy' => EngineScoreMapLevel.inaccuracy,
    'Excellent' => EngineScoreMapLevel.good,
    'Best' || 'Great' => EngineScoreMapLevel.good,
    _ => EngineScoreMapLevel.good,
  };
}

String? _lichessMateClassification({
  required int? beforeMate,
  required int? afterMate,
  required double beforeMoverEval,
  required double afterMoverEval,
}) {
  // MateCreated: Cp -> Mate(-n), i.e. the move allows an unavoidable mate
  // against the mover. Lichess uses the pre-move cp bands exactly as below.
  if (beforeMate == null && afterMate != null && afterMate < 0) {
    final previousCp = beforeMoverEval * 100;
    if (previousCp < -999) return 'Inaccuracy';
    if (previousCp < -700) return 'Mistake';
    return 'Blunder';
  }
  // MateLost: Mate(+n) -> Cp (or Mate(-n)); the mover lost a forced mate.
  if (beforeMate != null &&
      beforeMate > 0 &&
      (afterMate == null || afterMate < 0)) {
    final currentCp = afterMoverEval * 100;
    if (currentCp > 999) return 'Inaccuracy';
    if (currentCp > 700) return 'Mistake';
    return 'Blunder';
  }
  return null;
}

List<EngineMoveCandidate> _candidateMovesFromUciInfo(
  Map<int, UciInfo> latestByMultiPv,
) {
  if (latestByMultiPv.isEmpty) return const [];
  final targetDepth = latestByMultiPv[1]?.depth ??
      latestByMultiPv.values
          .map((info) => info.depth)
          .reduce((a, b) => a > b ? a : b);
  final sortedKeys = latestByMultiPv.keys.toList()..sort();
  return List.unmodifiable([
    for (final key in sortedKeys)
      if (latestByMultiPv[key] case final info?
          when info.depth == targetDepth && info.pv.isNotEmpty)
        EngineMoveCandidate(
          moveUci: info.pv.first,
          scoreCentipawns: info.score.centipawns,
          scoreMate: info.score.mate,
          outcomeExpectation: info.wdl?.sideExpectation,
          pv: List.unmodifiable(info.pv),
        ),
  ]);
}

List<EngineVariationInsight> _candidateVariations({
  required String fen,
  required List<EngineMoveCandidate> candidates,
}) {
  final sideToMove = _sideToMoveFromFen(fen);
  return List.unmodifiable([
    for (final candidate in candidates.take(3))
      if (_principalVariationSanLine(fen: fen, uciMoves: candidate.pv)
          case final line when line.isNotEmpty)
        EngineVariationInsight(
          moveUci: candidate.moveUci,
          line: line,
          whiteEval: UciScore(
            centipawns: candidate.scoreCentipawns,
            mate: candidate.scoreMate,
          ).whitePawnScore(sideToMove: sideToMove),
          whiteMate: UciScore(
            centipawns: candidate.scoreCentipawns,
            mate: candidate.scoreMate,
          ).whiteMate(sideToMove: sideToMove),
        ),
  ]);
}

String? _uciMoveToSan({
  required String fen,
  required String uci,
}) {
  try {
    final position = dc.Chess.fromSetup(dc.Setup.parseFen(fen));
    final move = dc.NormalMove.fromUci(uci);
    if (!position.isLegal(move)) return uci;
    final (_, san) = position.makeSan(move);
    return san;
  } catch (_) {
    return uci;
  }
}

String _principalVariationSanLine({
  required String fen,
  required List<String> uciMoves,
}) {
  if (uciMoves.isEmpty) return '';
  try {
    dc.Position position = dc.Chess.fromSetup(dc.Setup.parseFen(fen));
    final sanMoves = <String>[];
    for (final uci in uciMoves) {
      final move = dc.NormalMove.fromUci(uci);
      if (!position.isLegal(move)) return uciMoves.join(' ');
      final (nextPosition, san) = position.makeSan(move);
      sanMoves.add(san);
      position = nextPosition;
    }
    return sanMoves.join(' ');
  } catch (_) {
    return uciMoves.join(' ');
  }
}

String _sideToMoveFromFen(String fen) {
  final parts = fen.split(RegExp(r'\s+'));
  return parts.length > 1 && parts[1] == 'b' ? 'b' : 'w';
}
