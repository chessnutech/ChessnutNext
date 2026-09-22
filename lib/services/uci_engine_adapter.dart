import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dartchess/dartchess.dart' as dc;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:leela_chess_zero/lc0.dart' deferred as lc0_package;
import 'package:path_provider/path_provider.dart';
import 'package:stockfish/stockfish.dart' deferred as stockfish_package;

import '../models/app_models.dart';
import '../widgets/chess_board.dart';
import 'bot_engine_adapter.dart';
import 'cloud_maia3_bot_engine_adapter.dart';
import 'native_engine_queue.dart';
import 'stockfish_analysis_service.dart';
import 'stockfish_network_service.dart';

enum UciThinkModeKind { nodes, depth, movetime, depthAndMovetime, autoTime }

class UciThinkMode {
  const UciThinkMode.nodes(int nodes)
      : kind = UciThinkModeKind.nodes,
        value = nodes,
        secondaryValue = 0,
        duration = Duration.zero;

  const UciThinkMode.depth(int depth)
      : kind = UciThinkModeKind.depth,
        value = depth,
        secondaryValue = 0,
        duration = Duration.zero;

  const UciThinkMode.movetime(Duration movetime)
      : kind = UciThinkModeKind.movetime,
        value = 0,
        secondaryValue = 0,
        duration = movetime;

  const UciThinkMode.autoTime()
      : kind = UciThinkModeKind.autoTime,
        value = 0,
        secondaryValue = 0,
        duration = Duration.zero;

  const UciThinkMode.depthAndMovetime({
    required int depth,
    required Duration movetime,
  })  : kind = UciThinkModeKind.depthAndMovetime,
        value = depth,
        secondaryValue = 0,
        duration = movetime;

  final UciThinkModeKind kind;
  final int value;
  final int secondaryValue;
  final Duration duration;

  String command({
    int? whiteTimeMs,
    int? blackTimeMs,
    int? whiteIncrementMs,
    int? blackIncrementMs,
  }) {
    return switch (kind) {
      UciThinkModeKind.nodes => 'go nodes $value',
      UciThinkModeKind.depth => 'go depth $value',
      UciThinkModeKind.movetime => 'go movetime ${duration.inMilliseconds}',
      UciThinkModeKind.depthAndMovetime =>
        'go movetime ${duration.inMilliseconds} depth $value',
      UciThinkModeKind.autoTime =>
        'go wtime ${whiteTimeMs ?? 60000} btime ${blackTimeMs ?? 60000} '
            'winc ${whiteIncrementMs ?? 0} binc ${blackIncrementMs ?? 0}',
    };
  }

  Duration? get stopAfter {
    return switch (kind) {
      UciThinkModeKind.movetime ||
      UciThinkModeKind.depthAndMovetime when duration > Duration.zero =>
        duration + const Duration(milliseconds: 50),
      _ => null,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is UciThinkMode &&
        other.kind == kind &&
        other.value == value &&
        other.secondaryValue == secondaryValue &&
        other.duration == duration;
  }

  @override
  int get hashCode => Object.hash(kind, value, secondaryValue, duration);
}

class UciEngineProfile {
  const UciEngineProfile({
    required this.name,
    required this.executableCandidates,
    required this.startupCommands,
    required this.thinkMode,
  });

  static const int stockfishLowestUciElo = 1320;
  static const int stockfishHighestUciElo = 3190;
  static const int stockfishWeakLowestElo = 500;

  static List<UciEngineProfile> fromBotConfig(BotGameConfig config) {
    return switch (config.engineKind) {
      BotEngineKind.stockfish => _stockfishProfiles(config),
      BotEngineKind.maia3 => const <UciEngineProfile>[],
      BotEngineKind.maia => [
          UciEngineProfile(
            name: 'Maia ${config.maiaElo}',
            executableCandidates: const ['lc0/lc0.exe', 'lc0.exe', 'lc0'],
            startupCommands: [
              if (config.chess960) 'setoption name UCI_Chess960 value true',
              'setoption name WeightsFile value assets/maia_weights/maia-${config.maiaElo}.pb.gz',
              'setoption name Temperature value 1.00',
              'setoption name TempDecayMoves value 4',
            ],
            thinkMode: config.maiaSearchStyle == MaiaSearchStyle.pure
                ? const UciThinkMode.nodes(1)
                : UciThinkMode.depth(config.maiaSearchDepth),
          ),
        ],
      BotEngineKind.lc0 => [
          UciEngineProfile(
            name: 'LC0 ${config.lc0WeightLabel}',
            executableCandidates: const ['lc0/lc0.exe', 'lc0.exe', 'lc0'],
            startupCommands: [
              if (config.chess960) 'setoption name UCI_Chess960 value true',
              'setoption name WeightsFile value ${config.lc0WeightPath}',
              'setoption name Temperature value 1.00',
              'setoption name TempDecayMoves value 4',
            ],
            thinkMode: const UciThinkMode.nodes(1),
          ),
        ],
    };
  }

  static UciEngineProfile primaryFromBotConfig(BotGameConfig config) =>
      fromBotConfig(config).first;

  static List<UciEngineProfile> _stockfishProfiles(BotGameConfig config) {
    final elo = config.stockfishElo
        .clamp(stockfishWeakLowestElo, stockfishHighestUciElo)
        .toInt();
    final thinkMode = config.stockfishThinkingTime == Duration.zero
        ? const UciThinkMode.autoTime()
        : UciThinkMode.movetime(config.stockfishThinkingTime);

    if (elo >= stockfishLowestUciElo) {
      return [
        UciEngineProfile(
          name: 'Stockfish $elo',
          executableCandidates: const [
            'stockfish/stockfish.exe',
            'stockfish.exe',
            'stockfish',
          ],
          startupCommands: [
            if (config.chess960) 'setoption name UCI_Chess960 value true',
            'setoption name UCI_LimitStrength value true',
            'setoption name UCI_Elo value $elo',
            'setoption name MultiPV value 1',
          ],
          thinkMode: thinkMode,
        ),
      ];
    }

    return [_lowEloStockfishProfile(config)];
  }

  static UciEngineProfile _lowEloStockfishProfile(BotGameConfig config) {
    final elo = config.stockfishElo
        .clamp(stockfishWeakLowestElo, stockfishLowestUciElo - 1)
        .toInt();
    return UciEngineProfile(
      name: 'Stockfish weak $elo',
      executableCandidates: const [
        'stockfish/stockfish.exe',
        'stockfish.exe',
        'stockfish',
      ],
      startupCommands: [
        if (config.chess960) 'setoption name UCI_Chess960 value true',
        'setoption name UCI_LimitStrength value false',
        'setoption name Skill Level value ${_lowEloSkillLevel(elo)}',
        'setoption name MultiPV value 1',
      ],
      thinkMode: _lowEloThinkMode(config),
    );
  }

  static int _lowEloSkillLevel(int elo) {
    final normalized = ((elo - stockfishWeakLowestElo) /
            (stockfishLowestUciElo - stockfishWeakLowestElo))
        .clamp(0.0, 1.0);
    return (normalized * 7).round().clamp(0, 7);
  }

  static UciThinkMode _lowEloThinkMode(BotGameConfig config) {
    if (config.stockfishThinkingTime != Duration.zero) {
      return UciThinkMode.movetime(config.stockfishThinkingTime);
    }
    final elo = config.stockfishElo
        .clamp(stockfishWeakLowestElo, stockfishLowestUciElo - 1)
        .toInt();
    final normalized = ((elo - stockfishWeakLowestElo) /
            (stockfishLowestUciElo - stockfishWeakLowestElo))
        .clamp(0.0, 1.0);
    final movetimeMs = 50 + (normalized * 150).round();
    final depth = min(8, 5 + (normalized * 3).round());
    return UciThinkMode.depthAndMovetime(
      depth: depth,
      movetime: Duration(milliseconds: movetimeMs),
    );
  }

  final String name;
  final List<String> executableCandidates;
  final List<String> startupCommands;
  final UciThinkMode thinkMode;
}

class _UciSessionKey {
  _UciSessionKey({
    required this.engineKind,
    required this.profileName,
    required List<String> startupCommands,
    required this.weightsPath,
  }) : startupCommands = List.unmodifiable(startupCommands);

  final BotEngineKind engineKind;
  final String profileName;
  final List<String> startupCommands;
  final String? weightsPath;

  @override
  bool operator ==(Object other) {
    return other is _UciSessionKey &&
        other.engineKind == engineKind &&
        other.profileName == profileName &&
        other.weightsPath == weightsPath &&
        _stringListsEqual(other.startupCommands, startupCommands);
  }

  @override
  int get hashCode => Object.hash(
        engineKind,
        profileName,
        weightsPath,
        Object.hashAll(startupCommands),
      );
}

bool _stringListsEqual(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

List<String> nativeLc0StartupCommands(List<String> profileCommands) {
  return [
    for (final command in profileCommands)
      if (!command.startsWith('setoption name WeightsFile value ')) command,
  ];
}

class UciProcessBotEngineAdapter extends BotEngineAdapter {
  UciProcessBotEngineAdapter({
    this.workingDirectory,
    this.executableDirectory,
    this.moveTimeout = const Duration(seconds: 16),
    this.protocolTimeout = const Duration(seconds: 8),
  });

  final String? workingDirectory;
  final String? executableDirectory;
  final Duration moveTimeout;
  final Duration protocolTimeout;
  final NativeEngineQueue _queue = NativeEngineQueue();
  _ReusableUciSession? _session;

  String get _effectiveWorkingDirectory =>
      workingDirectory ?? Directory.current.path;

  String get _effectiveExecutableDirectory =>
      executableDirectory ?? File(Platform.resolvedExecutable).parent.path;

  @override
  Future<void> prepare({required BotGameConfig config}) {
    return _queue.run(() async {
      if (!_usesReusableProcessSession(config)) {
        await _disposeSession();
        return;
      }
      try {
        await _ensureSessionForConfig(config);
      } catch (_) {
        await _disposeSession();
      }
    });
  }

  @override
  Future<BotMoveResult?> bestMove({
    required String fen,
    required BotGameConfig config,
    List<String> moveHistory = const [],
  }) async {
    if (config.engineKind == BotEngineKind.maia3) return null;
    return _queue.run(() async {
      if (_usesReusableProcessSession(config)) {
        return _bestMoveWithReusableSession(fen, config);
      }
      await _disposeSession();
      return _bestMoveWithNewProcess(fen, config);
    });
  }

  bool _usesReusableProcessSession(BotGameConfig config) {
    return config.engineKind == BotEngineKind.maia ||
        config.engineKind == BotEngineKind.lc0;
  }

  Future<BotMoveResult?> _bestMoveWithReusableSession(
    String fen,
    BotGameConfig config,
  ) async {
    try {
      var session = await _ensureSessionForConfig(config);
      if (session == null) return null;
      try {
        return await _runInitializedUciBestMoveWithReader(
          fen: fen,
          profile: UciEngineProfile.primaryFromBotConfig(config),
          engine: session.engine,
          reader: session.reader,
          moveTimeout: moveTimeout,
        );
      } catch (_) {
        await _disposeSession();
        session = await _ensureSessionForConfig(config);
        if (session == null) return null;
        return await _runInitializedUciBestMoveWithReader(
          fen: fen,
          profile: UciEngineProfile.primaryFromBotConfig(config),
          engine: session.engine,
          reader: session.reader,
          moveTimeout: moveTimeout,
        );
      }
    } catch (_) {
      await _disposeSession();
      return null;
    }
  }

  Future<BotMoveResult?> _bestMoveWithNewProcess(
    String fen,
    BotGameConfig config,
  ) async {
    _ResolvedUciRuntime? runtime;
    for (final profile in UciEngineProfile.fromBotConfig(config)) {
      runtime = _resolveRuntime(profile);
      if (runtime == null) continue;

      Process? process;
      _ProcessUciEngineIo? engine;
      try {
        final startupCommands = _startupCommandsForRuntime(profile, runtime);
        process = await Process.start(
          File(runtime.executable).absolute.path,
          const [],
          workingDirectory: runtime.root,
        );
        unawaited(process.stderr.drain<void>());
        engine = _ProcessUciEngineIo(process);
        final result = await _runUciBestMove(
          fen: fen,
          profile: profile,
          engine: engine,
          startupCommands: startupCommands,
          moveTimeout: moveTimeout,
          protocolTimeout: protocolTimeout,
        );
        if (result != null) return result;
      } catch (_) {
      } finally {
        await engine?.dispose();
      }
    }
    return null;
  }

  Future<_ReusableUciSession?> _ensureSessionForConfig(
    BotGameConfig config,
  ) async {
    final profile = UciEngineProfile.primaryFromBotConfig(config);
    final runtime = _resolveRuntime(profile);
    if (runtime == null) return null;
    final startupCommands = _startupCommandsForRuntime(profile, runtime);
    final key = _UciSessionKey(
      engineKind: config.engineKind,
      profileName: profile.name,
      startupCommands: startupCommands,
      weightsPath: runtime.executable,
    );
    final current = _session;
    if (current != null && current.key == key) return current;

    await _disposeSession();
    final process = await Process.start(
      File(runtime.executable).absolute.path,
      const [],
      workingDirectory: runtime.root,
    );
    unawaited(process.stderr.drain<void>());
    final engine = _ProcessUciEngineIo(process);
    final reader = _UciLineReader(engine.stdout);
    try {
      await _initializeUciEngineWithReader(
        engine: engine,
        reader: reader,
        startupCommands: startupCommands,
        protocolTimeout: protocolTimeout,
      );
      final session = _ReusableUciSession(
        key: key,
        engine: engine,
        reader: reader,
      );
      _session = session;
      return session;
    } catch (_) {
      await reader.dispose();
      await engine.dispose();
      rethrow;
    }
  }

  Future<void> _disposeSession() async {
    final session = _session;
    _session = null;
    await session?.dispose();
  }

  @override
  Future<void> dispose() => _queue.run(_disposeSession);

  _ResolvedUciRuntime? _resolveRuntime(UciEngineProfile profile) {
    for (final root in _engineSearchRoots()) {
      for (final candidate in profile.executableCandidates) {
        final file = File(_joinPath(root, candidate));
        if (file.existsSync() &&
            file.statSync().type == FileSystemEntityType.file) {
          return _ResolvedUciRuntime(executable: file.path, root: root);
        }
      }
    }
    return null;
  }

  String? resolveExecutablePathForTest(UciEngineProfile profile) {
    return _resolveRuntime(profile)?.executable;
  }

  String? resolveExecutablePathForConfigForTest(BotGameConfig config) {
    for (final profile in UciEngineProfile.fromBotConfig(config)) {
      final runtime = _resolveRuntime(profile);
      if (runtime != null) return runtime.executable;
    }
    return null;
  }

  String? resolveRuntimeRootForTest(UciEngineProfile profile) {
    return _resolveRuntime(profile)?.root;
  }

  List<String> resolveStartupCommandsForTest(UciEngineProfile profile) {
    final runtime = _resolveRuntime(profile);
    if (runtime == null) return profile.startupCommands;
    return _startupCommandsForRuntime(profile, runtime);
  }

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

  List<String> _startupCommandsForRuntime(
    UciEngineProfile profile,
    _ResolvedUciRuntime runtime,
  ) {
    final commands = [
      for (final command in profile.startupCommands)
        if (command.startsWith('setoption name WeightsFile value '))
          'setoption name WeightsFile value '
              '${_resolveWeightsPath(runtime, command.split(' value ').last)}'
        else
          command,
    ];
    if (_isStockfishProfile(profile)) {
      return stockfishStartupCommands(
        commands,
        _resolvePackagedStockfishNetworks(runtime),
      );
    }
    return commands;
  }

  String _resolveWeightsPath(_ResolvedUciRuntime runtime, String weightsPath) {
    final direct = File(weightsPath);
    if (direct.isAbsolute && direct.existsSync()) return direct.absolute.path;

    final packagedAssetPath = 'data/flutter_assets/$weightsPath';
    for (final root in _engineSearchRoots()) {
      for (final path in [
        weightsPath,
        packagedAssetPath,
        _joinPath('Resources', weightsPath),
        _joinPath('Resources', packagedAssetPath),
      ]) {
        final candidate = File(_joinPath(root, path));
        if (candidate.existsSync()) return candidate.absolute.path;
      }
    }

    final runtimeCandidate = File(_joinPath(runtime.root, packagedAssetPath));
    if (runtimeCandidate.existsSync()) return runtimeCandidate.absolute.path;
    return runtimeCandidate.absolute.path;
  }

  StockfishNetworkPaths? _resolvePackagedStockfishNetworks(
    _ResolvedUciRuntime runtime,
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
    _ResolvedUciRuntime runtime,
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

  bool _isStockfishProfile(UciEngineProfile profile) {
    return profile.executableCandidates.any((candidate) {
      final normalized = candidate.replaceAll('\\', '/').toLowerCase();
      return normalized == 'stockfish' ||
          normalized.endsWith('/stockfish') ||
          normalized.endsWith('/stockfish.exe') ||
          normalized == 'stockfish.exe';
    });
  }
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

class NativeFlutterBotEngineAdapter extends BotEngineAdapter {
  NativeFlutterBotEngineAdapter({
    this.moveTimeout = const Duration(seconds: 20),
    this.startupTimeout = const Duration(seconds: 30),
    this.protocolTimeout = const Duration(seconds: 30),
    this.stockfishNetworks = const MethodChannelStockfishNetworkService(),
  });

  final Duration moveTimeout;
  final Duration startupTimeout;
  final Duration protocolTimeout;
  final StockfishNetworkService stockfishNetworks;
  _ReusableNativeUciSession? _session;
  BotEvaluationListener? _evaluationListener;
  String? _lastErrorMessage;

  @override
  String? get lastErrorMessage => _lastErrorMessage;

  @override
  Future<void> prepare({required BotGameConfig config}) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await nativeEngineQueue.run(() async {
      try {
        await _ensureSessionForConfig(config);
      } catch (error, stackTrace) {
        _recordFailure(config, 'prepare', error, stackTrace);
        await _disposeSession();
      }
    });
  }

  @override
  Future<BotMoveResult?> bestMove({
    required String fen,
    required BotGameConfig config,
    List<String> moveHistory = const [],
  }) async {
    _lastErrorMessage = null;
    if (!Platform.isAndroid && !Platform.isIOS) {
      _recordFailureMessage(
        config,
        'platform',
        'Native engines require Android or iOS, current platform is '
            '${Platform.operatingSystem}.',
      );
      return null;
    }
    if (config.engineKind == BotEngineKind.maia3) {
      _recordFailureMessage(
        config,
        'engine selection',
        'Maia 3 uses the cloud adapter, not the native LC0 adapter.',
      );
      return null;
    }

    return nativeEngineQueue.run(() async {
      final profile = UciEngineProfile.primaryFromBotConfig(config);
      try {
        final session = await _ensureSessionForConfig(config);
        if (session == null) {
          _recordFailureMessage(
            config,
            'startup',
            'The native engine session could not be created.',
          );
          return null;
        }
        BotMoveResult? result;
        try {
          result = await _runInitializedUciBestMove(
            fen: fen,
            profile: profile,
            engine: session.engine,
            moveTimeout: moveTimeout,
            onEvaluation: _evaluationListener,
          );
        } catch (error, stackTrace) {
          _recordFailure(config, 'search', error, stackTrace);
          await _disposeSession();
          try {
            final retrySession = await _ensureSessionForConfig(config);
            if (retrySession != null) {
              result = await _runInitializedUciBestMove(
                fen: fen,
                profile: profile,
                engine: retrySession.engine,
                moveTimeout: moveTimeout,
                onEvaluation: _evaluationListener,
              );
            }
          } catch (retryError, retryStackTrace) {
            _recordFailure(
              config,
              'search retry',
              retryError,
              retryStackTrace,
            );
          }
        }
        if (result == null && _lastErrorMessage == null) {
          _recordFailureMessage(
            config,
            'search',
            'The engine returned no legal best move for the current FEN.',
          );
        }
        if (result != null) _lastErrorMessage = null;
        return result;
      } catch (error, stackTrace) {
        _recordFailure(config, 'startup', error, stackTrace);
        await _disposeSession();
        return null;
      }
    });
  }

  @override
  Future<PositionEngineAnalysis?> analyzeFen({
    required String fen,
    required BotGameConfig config,
    int depth = 10,
    int multiPv = 1,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) return null;
    if (config.engineKind != BotEngineKind.stockfish) return null;

    return nativeEngineQueue.run(() async {
      try {
        final session = await _ensureSessionForConfig(config);
        if (session == null) return null;
        PositionEngineAnalysis? result;
        try {
          result = await _runInitializedUciAnalysis(
            fen: fen,
            depth: depth,
            multiPv: multiPv,
            engine: session.engine,
            timeout: moveTimeout,
            onEvaluation: _evaluationListener,
          );
        } catch (_) {
          await _disposeSession();
        }
        if (result != null) return result;
        final retrySession = await _ensureSessionForConfig(config);
        if (retrySession == null) return null;
        return await _runInitializedUciAnalysis(
          fen: fen,
          depth: depth,
          multiPv: multiPv,
          engine: retrySession.engine,
          timeout: moveTimeout,
          onEvaluation: _evaluationListener,
        );
      } catch (_) {
        await _disposeSession();
        return null;
      }
    });
  }

  @override
  void setEvaluationListener(BotEvaluationListener? listener) {
    _evaluationListener = listener;
  }

  void _recordFailure(
    BotGameConfig config,
    String stage,
    Object error,
    StackTrace stackTrace,
  ) {
    final detail = error.toString().trim();
    _recordFailureMessage(
      config,
      stage,
      '${error.runtimeType}: ${detail.isEmpty ? 'No error message' : detail}',
      stackTrace: stackTrace,
    );
  }

  void _recordFailureMessage(
    BotGameConfig config,
    String stage,
    String detail, {
    StackTrace? stackTrace,
  }) {
    final message = '${_engineDiagnosticName(config)} [$stage] $detail';
    _lastErrorMessage = message;
    debugPrint('[BotEngine] $message');
    if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
  }

  String _engineDiagnosticName(BotGameConfig config) =>
      switch (config.engineKind) {
        BotEngineKind.maia => 'Maia ${config.maiaElo}',
        BotEngineKind.maia3 => 'Maia 3 ${config.maiaElo}',
        BotEngineKind.stockfish => 'Stockfish ${config.stockfishElo}',
        BotEngineKind.lc0 => 'LC0 ${config.lc0WeightLabel}',
      };

  Future<_ReusableNativeUciSession?> _ensureSessionForConfig(
    BotGameConfig config,
  ) async {
    final profile = UciEngineProfile.primaryFromBotConfig(config);
    final key = _UciSessionKey(
      engineKind: config.engineKind,
      profileName: profile.name,
      startupCommands: profile.startupCommands,
      weightsPath: null,
    );
    final current = _session;
    if (current != null && current.key == key) return current;

    final startup = await _nativeStartupForConfig(config, profile);
    if (startup.unavailable) return null;
    return _ensureSession(
      key: key,
      config: config,
      profile: profile,
      startupCommands: startup.commands,
      weightsPath: startup.weightsPath,
    );
  }

  Future<_NativeStartup> _nativeStartupForConfig(
    BotGameConfig config,
    UciEngineProfile profile,
  ) async {
    if (config.engineKind == BotEngineKind.maia3) {
      return const _NativeStartup.unavailable();
    }
    if (config.engineKind == BotEngineKind.stockfish) {
      final stockfishPaths = await stockfishNetworks.prepare();
      if (Platform.isAndroid && stockfishPaths == null) {
        return const _NativeStartup.unavailable();
      }
      return _NativeStartup(
        commands: stockfishStartupCommands(
          profile.startupCommands,
          stockfishPaths,
        ),
      );
    }

    return _NativeStartup(
      commands: nativeLc0StartupCommands(profile.startupCommands),
      weightsPath: await _extractLc0Weights(config),
    );
  }

  Future<_ReusableNativeUciSession?> _ensureSession({
    required _UciSessionKey key,
    required BotGameConfig config,
    required UciEngineProfile profile,
    required List<String> startupCommands,
    required String? weightsPath,
  }) async {
    final current = _session;
    if (current != null && current.key == key) {
      return current;
    }

    await _disposeSession();
    final engine = await _openNativeEngineWithRetry(
      config,
      weightsPath: weightsPath,
    );
    if (engine == null) return null;
    try {
      await _initializeUciEngine(
        engine: engine,
        startupCommands: startupCommands,
        protocolTimeout: protocolTimeout,
      );
      final session = _ReusableNativeUciSession(key: key, engine: engine);
      _session = session;
      return session;
    } catch (_) {
      await engine.dispose();
      rethrow;
    }
  }

  Future<void> _disposeSession() async {
    final session = _session;
    _session = null;
    await session?.engine.dispose();
  }

  @override
  Future<void> dispose() {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return Future<void>.value();
    }
    return nativeEngineQueue.run(_disposeSession);
  }

  Future<_UciEngineIo?> _openNativeEngineWithRetry(
    BotGameConfig config, {
    String? weightsPath,
  }) async {
    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        return await _openNativeEngine(config, weightsPath: weightsPath);
      } catch (error) {
        final canRetry =
            error is StateError && error.message.contains('one instance');
        if (!canRetry || attempt == 2) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 450 * (attempt + 1)));
      }
    }
    return null;
  }

  Future<_UciEngineIo?> _openNativeEngine(
    BotGameConfig config, {
    String? weightsPath,
  }) async {
    switch (config.engineKind) {
      case BotEngineKind.stockfish:
        await stockfish_package.loadLibrary();
        await stockfish_package.disposeCurrentStockfish();
        final engine = await _startNativeEngine(
          stockfish_package.stockfishAsync,
          stockfish_package.disposeCurrentStockfish,
        );
        return _NativeUciEngineIo(engine);
      case BotEngineKind.maia3:
        return null;
      case BotEngineKind.maia:
      case BotEngineKind.lc0:
        await lc0_package.loadLibrary();
        final engine = await _startNativeEngine(
          () => lc0_package.lc0Async(weightsPath: weightsPath),
          lc0_package.disposeCurrentLc0,
        );
        return _NativeUciEngineIo(engine);
    }
  }

  Future<dynamic> _startNativeEngine(
    Future<dynamic> Function() start,
    Future<void> Function() disposeCurrent,
  ) async {
    try {
      return await start().timeout(startupTimeout);
    } catch (_) {
      await disposeCurrent();
      rethrow;
    }
  }

  List<String> resolveNativeLc0StartupCommandsForTest(
    UciEngineProfile profile,
  ) =>
      nativeLc0StartupCommands(profile.startupCommands);

  Future<String> _extractLc0Weights(BotGameConfig config) async {
    final assetPath = switch (config.engineKind) {
      BotEngineKind.maia => 'assets/maia_weights/maia-${config.maiaElo}.pb.gz',
      BotEngineKind.lc0 => config.lc0WeightPath,
      BotEngineKind.stockfish =>
        throw StateError('Stockfish has no LC0 weights'),
      BotEngineKind.maia3 => throw StateError('Maia3 runs through cloud API'),
    };
    final directFile = File(assetPath);
    if (directFile.isAbsolute && directFile.existsSync()) {
      return directFile.absolute.path;
    }
    return _extractAssetFile(assetPath);
  }

  Future<String> _extractAssetFile(String assetPath) async {
    final supportDir = await getApplicationSupportDirectory();
    final engineDir = Directory(
      '${supportDir.path}${Platform.pathSeparator}engine_weights',
    );
    if (!engineDir.existsSync()) {
      engineDir.createSync(recursive: true);
    }
    final file = File(
      '${engineDir.path}${Platform.pathSeparator}${assetPath.split('/').last}',
    );
    final data = await rootBundle.load(assetPath);
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    if (!_engineAssetFileMatches(file, bytes)) {
      final tempFile = File('${file.path}.tmp');
      await tempFile.writeAsBytes(bytes, flush: true);
      if (file.existsSync()) {
        await file.delete();
      }
      await tempFile.rename(file.path);
    }
    return file.path;
  }
}

bool _engineAssetFileMatches(File file, List<int> bytes) {
  if (!file.existsSync() || file.lengthSync() != bytes.length) return false;
  final existing = file.readAsBytesSync();
  if (existing.length != bytes.length) return false;
  for (var i = 0; i < bytes.length; i += 1) {
    if (existing[i] != bytes[i]) return false;
  }
  return true;
}

@visibleForTesting
bool engineAssetFileMatchesForTest(File file, List<int> bytes) =>
    _engineAssetFileMatches(file, bytes);

class DefaultBotEngineAdapter extends BotEngineAdapter {
  DefaultBotEngineAdapter({
    BotEngineAdapter? native,
    BotEngineAdapter? process,
    this.cloud = const CloudMaia3BotEngineAdapter(),
    this.fallback = const HeuristicBotEngineAdapter(),
  })  : native = native ?? NativeFlutterBotEngineAdapter(),
        process = process ?? UciProcessBotEngineAdapter();

  final BotEngineAdapter native;
  final BotEngineAdapter process;
  final BotEngineAdapter cloud;
  final BotEngineAdapter fallback;
  String? _lastErrorMessage;

  @override
  String? get lastErrorMessage => _lastErrorMessage;

  @override
  Future<void> prepare({required BotGameConfig config}) {
    if (config.engineKind == BotEngineKind.maia3) {
      return cloud.prepare(config: config);
    }
    final adapter = Platform.isAndroid || Platform.isIOS ? native : process;
    return adapter.prepare(config: config);
  }

  @override
  Future<BotMoveResult?> bestMove({
    required String fen,
    required BotGameConfig config,
    List<String> moveHistory = const [],
  }) async {
    if (config.engineKind == BotEngineKind.maia3) {
      final result = await cloud.bestMove(
        fen: fen,
        config: config,
        moveHistory: moveHistory,
      );
      _lastErrorMessage = cloud.lastErrorMessage;
      return result;
    }
    final adapter = Platform.isAndroid || Platform.isIOS ? native : process;
    final result = await adapter.bestMove(
      fen: fen,
      config: config,
      moveHistory: moveHistory,
    );
    _lastErrorMessage = adapter.lastErrorMessage;
    return result;
  }

  @override
  Future<PositionEngineAnalysis?> analyzeFen({
    required String fen,
    required BotGameConfig config,
    int depth = 10,
    int multiPv = 1,
  }) {
    final adapter = Platform.isAndroid || Platform.isIOS ? native : process;
    return adapter.analyzeFen(
      fen: fen,
      config: config,
      depth: depth,
      multiPv: multiPv,
    );
  }

  @override
  void setEvaluationListener(BotEvaluationListener? listener) {
    native.setEvaluationListener(listener);
    process.setEvaluationListener(listener);
  }

  @override
  Future<void> dispose() async {
    await Future.wait([
      native.dispose(),
      process.dispose(),
      cloud.dispose(),
      fallback.dispose(),
    ]);
  }
}

class _ReusableNativeUciSession {
  const _ReusableNativeUciSession({
    required this.key,
    required this.engine,
  });

  final _UciSessionKey key;
  final _UciEngineIo engine;
}

class _NativeStartup {
  const _NativeStartup({
    required this.commands,
    this.weightsPath,
  }) : unavailable = false;

  const _NativeStartup.unavailable()
      : commands = const [],
        weightsPath = null,
        unavailable = true;

  final List<String> commands;
  final String? weightsPath;
  final bool unavailable;
}

class _ResolvedUciRuntime {
  const _ResolvedUciRuntime({
    required this.executable,
    required this.root,
  });

  final String executable;
  final String root;
}

class _ReusableUciSession {
  const _ReusableUciSession({
    required this.key,
    required this.engine,
    required this.reader,
  });

  final _UciSessionKey key;
  final _UciEngineIo engine;
  final _UciLineReader reader;

  Future<void> dispose() async {
    await reader.dispose();
    await engine.dispose();
  }
}

class UnavailableBotEngineAdapter extends BotEngineAdapter {
  const UnavailableBotEngineAdapter();

  @override
  Future<BotMoveResult?> bestMove({
    required String fen,
    required BotGameConfig config,
    List<String> moveHistory = const [],
  }) async {
    return null;
  }
}

class StrictRealBotEngineAdapter extends BotEngineAdapter {
  const StrictRealBotEngineAdapter({
    required this.primary,
  });

  final BotEngineAdapter primary;

  @override
  Future<BotMoveResult?> bestMove({
    required String fen,
    required BotGameConfig config,
    List<String> moveHistory = const [],
  }) {
    return primary.bestMove(
      fen: fen,
      config: config,
      moveHistory: moveHistory,
    );
  }
}

class FallbackBotEngineAdapter extends BotEngineAdapter {
  const FallbackBotEngineAdapter({
    required this.primary,
    required this.fallback,
  });

  final BotEngineAdapter primary;
  final BotEngineAdapter fallback;

  @override
  Future<BotMoveResult?> bestMove({
    required String fen,
    required BotGameConfig config,
    List<String> moveHistory = const [],
  }) async {
    final primaryResult = await primary.bestMove(
      fen: fen,
      config: config,
      moveHistory: moveHistory,
    );
    if (primaryResult != null) return primaryResult;
    return fallback.bestMove(
      fen: fen,
      config: config,
      moveHistory: moveHistory,
    );
  }
}

abstract interface class _UciEngineIo {
  Stream<String> get stdout;

  void writeLine(String command);

  Future<void> dispose();
}

class _ProcessUciEngineIo implements _UciEngineIo {
  const _ProcessUciEngineIo(this.process);

  final Process process;

  @override
  Stream<String> get stdout => process.stdout
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter());

  @override
  void writeLine(String command) => process.stdin.writeln(command);

  @override
  Future<void> dispose() async {
    try {
      process.stdin.writeln('quit');
    } catch (_) {}
    process.kill();
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } catch (_) {}
  }
}

class _NativeUciEngineIo implements _UciEngineIo {
  const _NativeUciEngineIo(this.engine);

  final dynamic engine;

  @override
  Stream<String> get stdout => engine.stdout as Stream<String>;

  @override
  void writeLine(String command) {
    engine.stdin = command;
  }

  @override
  Future<void> dispose() async {
    try {
      engine.dispose();
    } catch (_) {}
    try {
      await (engine.done as Future<void>).timeout(const Duration(seconds: 3));
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }
}

Future<BotMoveResult?> _runUciBestMove({
  required String fen,
  required UciEngineProfile profile,
  required _UciEngineIo engine,
  required List<String> startupCommands,
  required Duration moveTimeout,
  required Duration protocolTimeout,
  BotEvaluationListener? onEvaluation,
}) async {
  final reader = _UciLineReader(engine.stdout);
  try {
    engine.writeLine('uci');
    await reader.firstWhere((line) => line == 'uciok').timeout(protocolTimeout);

    for (final command in startupCommands) {
      engine.writeLine(command);
    }
    engine.writeLine('isready');
    await reader
        .firstWhere((line) => line == 'readyok')
        .timeout(protocolTimeout);

    engine.writeLine('ucinewgame');
    return await _runInitializedUciBestMoveWithReader(
      fen: fen,
      profile: profile,
      engine: engine,
      reader: reader,
      moveTimeout: moveTimeout,
      onEvaluation: onEvaluation,
    );
  } finally {
    await reader.dispose();
  }
}

Future<void> _initializeUciEngine({
  required _UciEngineIo engine,
  required List<String> startupCommands,
  required Duration protocolTimeout,
}) async {
  final reader = _UciLineReader(engine.stdout);
  try {
    await _initializeUciEngineWithReader(
      engine: engine,
      reader: reader,
      startupCommands: startupCommands,
      protocolTimeout: protocolTimeout,
    );
  } finally {
    await reader.dispose();
  }
}

Future<void> _initializeUciEngineWithReader({
  required _UciEngineIo engine,
  required _UciLineReader reader,
  required List<String> startupCommands,
  required Duration protocolTimeout,
}) async {
  engine.writeLine('uci');
  await reader.firstWhere((line) => line == 'uciok').timeout(protocolTimeout);

  for (final command in startupCommands) {
    engine.writeLine(command);
  }
  engine.writeLine('isready');
  await reader.firstWhere((line) => line == 'readyok').timeout(protocolTimeout);
  engine.writeLine('ucinewgame');
}

Future<BotMoveResult?> _runInitializedUciBestMove({
  required String fen,
  required UciEngineProfile profile,
  required _UciEngineIo engine,
  required Duration moveTimeout,
  BotEvaluationListener? onEvaluation,
}) async {
  final reader = _UciLineReader(engine.stdout);
  try {
    return await _runInitializedUciBestMoveWithReader(
      fen: fen,
      profile: profile,
      engine: engine,
      reader: reader,
      moveTimeout: moveTimeout,
      onEvaluation: onEvaluation,
    );
  } finally {
    await reader.dispose();
  }
}

Future<BotMoveResult?> _runInitializedUciBestMoveWithReader({
  required String fen,
  required UciEngineProfile profile,
  required _UciEngineIo engine,
  required _UciLineReader reader,
  required Duration moveTimeout,
  BotEvaluationListener? onEvaluation,
}) async {
  for (final command in profile.startupCommands) {
    if (command.startsWith('setoption name MultiPV value ')) {
      engine.writeLine(command);
      break;
    }
  }
  engine.writeLine('position fen $fen');
  engine.writeLine(profile.thinkMode.command());
  final stopAfter = profile.thinkMode.stopAfter;
  Timer? stopTimer;
  if (stopAfter != null) {
    stopTimer = Timer(stopAfter, () => engine.writeLine('stop'));
  }

  final bestMoveLine = await reader
      .firstWhere((line) {
        _emitEvaluationFromInfoLine(
          line: line,
          fen: fen,
          onEvaluation: onEvaluation,
        );
        return line.startsWith('bestmove ');
      })
      .timeout(moveTimeout)
      .whenComplete(() => stopTimer?.cancel());
  final uci = bestMoveLine.split(RegExp(r'\s+')).elementAtOrNull(1);
  if (uci == null || uci == '(none)') return null;

  final position = loadDartChessPosition(fen);
  final move = dc.NormalMove.fromUci(uci);
  if (!position.isLegal(move)) return null;
  final (nextPosition, san) = position.makeSan(move);
  return BotMoveResult(
    move: move,
    san: san,
    fen: nextPosition.fen,
    isFallback: false,
  );
}

Future<PositionEngineAnalysis?> _runInitializedUciAnalysis({
  required String fen,
  required int depth,
  required int multiPv,
  required _UciEngineIo engine,
  required Duration timeout,
  BotEvaluationListener? onEvaluation,
}) async {
  final reader = _UciLineReader(engine.stdout);
  UciInfo? latestInfo;
  final latestByMultiPv = <int, UciInfo>{};
  try {
    engine.writeLine('setoption name MultiPV value ${multiPv.clamp(1, 256)}');
    engine.writeLine('isready');
    await reader.firstWhere((line) => line == 'readyok').timeout(timeout);

    engine.writeLine('ucinewgame');
    engine.writeLine('position fen $fen');
    engine.writeLine('go depth $depth');

    final bestMoveLine = await reader.firstWhere((line) {
      final info = UciInfoParser.parseInfoLine(line);
      if (info != null && info.pv.isNotEmpty) {
        latestInfo = info.multiPv == 1 ? info : latestInfo;
        latestByMultiPv[info.multiPv] = info;
        _emitEvaluationFromInfo(
          fen: fen,
          info: info,
          onEvaluation: onEvaluation,
        );
      }
      return line.startsWith('bestmove ');
    }).timeout(timeout);
    final bestMove = bestMoveLine.split(RegExp(r'\s+')).elementAtOrNull(1);
    final info = latestInfo;
    if (info == null) return null;
    return PositionEngineAnalysis(
      fen: fen,
      depth: info.depth,
      whiteEval:
          info.score.whitePawnScore(sideToMove: _uciSideToMoveFromFen(fen)),
      whiteMate: info.score.whiteMate(sideToMove: _uciSideToMoveFromFen(fen)),
      bestMoveUci: bestMove == '(none)' ? null : bestMove,
      pv: info.pv,
      isEngineBacked: true,
      candidateMoves: _uciCandidateMovesFromInfo(latestByMultiPv),
    );
  } finally {
    await reader.dispose();
  }
}

void _emitEvaluationFromInfoLine({
  required String line,
  required String fen,
  required BotEvaluationListener? onEvaluation,
}) {
  final info = UciInfoParser.parseInfoLine(line);
  if (info == null || info.multiPv != 1 || info.pv.isEmpty) return;
  _emitEvaluationFromInfo(fen: fen, info: info, onEvaluation: onEvaluation);
}

void _emitEvaluationFromInfo({
  required String fen,
  required UciInfo info,
  required BotEvaluationListener? onEvaluation,
}) {
  if (onEvaluation == null || info.multiPv != 1 || info.pv.isEmpty) return;
  onEvaluation(
    PositionEngineAnalysis(
      fen: fen,
      depth: info.depth,
      whiteEval:
          info.score.whitePawnScore(sideToMove: _uciSideToMoveFromFen(fen)),
      whiteMate: info.score.whiteMate(sideToMove: _uciSideToMoveFromFen(fen)),
      bestMoveUci: info.pv.firstOrNull,
      pv: info.pv,
      isEngineBacked: true,
      candidateMoves: [
        EngineMoveCandidate(
          moveUci: info.pv.first,
          scoreCentipawns: info.score.centipawns,
          scoreMate: info.score.mate,
          pv: List.unmodifiable(info.pv),
        ),
      ],
    ),
  );
}

List<EngineMoveCandidate> _uciCandidateMovesFromInfo(
  Map<int, UciInfo> latestByMultiPv,
) {
  if (latestByMultiPv.isEmpty) return const [];
  final sortedKeys = latestByMultiPv.keys.toList()..sort();
  return List.unmodifiable([
    for (final key in sortedKeys)
      if (latestByMultiPv[key] case final info? when info.pv.isNotEmpty)
        EngineMoveCandidate(
          moveUci: info.pv.first,
          scoreCentipawns: info.score.centipawns,
          scoreMate: info.score.mate,
          pv: List.unmodifiable(info.pv),
        ),
  ]);
}

String _uciSideToMoveFromFen(String fen) {
  final parts = fen.split(RegExp(r'\s+'));
  return parts.length > 1 && parts[1] == 'b' ? 'b' : 'w';
}

@visibleForTesting
Future<List<String>> runReusableUciSessionCommandsForTest({
  required UciEngineProfile profile,
  required List<String> fens,
  required List<String> bestMoves,
  List<String> startupCommands = const [],
  Duration moveTimeout = const Duration(seconds: 1),
  Duration protocolTimeout = const Duration(seconds: 1),
}) async {
  final engine = _ScriptedUciEngineIo(bestMoves);
  try {
    await _initializeUciEngine(
      engine: engine,
      startupCommands: startupCommands,
      protocolTimeout: protocolTimeout,
    );
    for (final fen in fens) {
      await _runInitializedUciBestMove(
        fen: fen,
        profile: profile,
        engine: engine,
        moveTimeout: moveTimeout,
      );
    }
    return List.unmodifiable(engine.commands);
  } finally {
    await engine.dispose();
  }
}

@visibleForTesting
Future<List<PositionEngineAnalysis>> runUciBestMoveEvaluationsForTest({
  required UciEngineProfile profile,
  required String fen,
  required List<String> infoLines,
  required String bestMove,
  Duration moveTimeout = const Duration(seconds: 1),
  Duration protocolTimeout = const Duration(seconds: 1),
}) async {
  final engine = _ScriptedUciEngineIo(
    [bestMove],
    infoLinesByMove: [infoLines],
  );
  final evaluations = <PositionEngineAnalysis>[];
  try {
    await _runUciBestMove(
      fen: fen,
      profile: profile,
      engine: engine,
      startupCommands: profile.startupCommands,
      moveTimeout: moveTimeout,
      protocolTimeout: protocolTimeout,
      onEvaluation: evaluations.add,
    );
    return List.unmodifiable(evaluations);
  } finally {
    await engine.dispose();
  }
}

class _UciLineReader {
  _UciLineReader(Stream<String> lines) {
    _subscription = lines.listen(
      _handleLine,
      onDone: _handleDone,
      onError: _handleError,
    );
  }

  final List<String> _buffer = [];
  final List<_UciLineWaiter> _waiters = [];
  late final StreamSubscription<String> _subscription;
  bool _done = false;

  Future<String> firstWhere(bool Function(String line) test) {
    for (var i = 0; i < _buffer.length; i += 1) {
      final line = _buffer[i];
      if (test(line)) {
        _buffer.removeAt(i);
        return Future.value(line);
      }
    }
    if (_done) return Future.error(StateError('UCI engine output closed'));

    final waiter = _UciLineWaiter(test);
    _waiters.add(waiter);
    return waiter.completer.future.whenComplete(() {
      _waiters.remove(waiter);
    });
  }

  Future<void> dispose() => _subscription.cancel();

  void _handleLine(String line) {
    final normalized = line.trim();
    if (normalized.isEmpty) return;
    for (final waiter in List<_UciLineWaiter>.from(_waiters)) {
      if (waiter.test(normalized) && !waiter.completer.isCompleted) {
        waiter.completer.complete(normalized);
        return;
      }
    }
    _buffer.add(normalized);
    if (_buffer.length > 200) _buffer.removeAt(0);
  }

  void _handleDone() {
    _done = true;
    for (final waiter in List<_UciLineWaiter>.from(_waiters)) {
      if (!waiter.completer.isCompleted) {
        waiter.completer.completeError(StateError('UCI engine output closed'));
      }
    }
    _waiters.clear();
  }

  void _handleError(Object error, StackTrace stackTrace) {
    for (final waiter in List<_UciLineWaiter>.from(_waiters)) {
      if (!waiter.completer.isCompleted) {
        waiter.completer.completeError(error, stackTrace);
      }
    }
    _waiters.clear();
  }
}

class _ScriptedUciEngineIo implements _UciEngineIo {
  _ScriptedUciEngineIo(
    this.bestMoves, {
    this.infoLinesByMove = const [],
  });

  final List<String> bestMoves;
  final List<List<String>> infoLinesByMove;
  final List<String> commands = [];
  final StreamController<String> _stdout = StreamController<String>.broadcast();
  int _bestMoveIndex = 0;

  @override
  Stream<String> get stdout => _stdout.stream;

  @override
  void writeLine(String command) {
    commands.add(command);
    if (command == 'uci') {
      _stdout.add('uciok');
    } else if (command == 'isready') {
      _stdout.add('readyok');
    } else if (command.startsWith('go ')) {
      final index = _bestMoveIndex.clamp(0, bestMoves.length - 1);
      _bestMoveIndex += 1;
      if (index < infoLinesByMove.length) {
        for (final line in infoLinesByMove[index]) {
          _stdout.add(line);
        }
      }
      _stdout.add('bestmove ${bestMoves[index]}');
    }
  }

  @override
  Future<void> dispose() => _stdout.close();
}

class _UciLineWaiter {
  _UciLineWaiter(this.test);

  final bool Function(String line) test;
  final Completer<String> completer = Completer<String>();
}
