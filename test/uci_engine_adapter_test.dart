import 'dart:io';

import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/services/bot_engine_adapter.dart';
import 'package:chessnut_flutter_export/services/uci_engine_adapter.dart';
import 'package:chessnut_flutter_export/widgets/chess_board.dart';
import 'package:dartchess/dartchess.dart' as dc;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UCI profile maps original project engine settings', () {
    final stockfish = UciEngineProfile.primaryFromBotConfig(
      const BotGameConfig.defaultConfig().copyWith(
        engineKind: BotEngineKind.stockfish,
        stockfishElo: 1800,
        stockfishThinkingTime: const Duration(milliseconds: 700),
      ),
    );

    expect(stockfish.executableCandidates, contains('stockfish/stockfish.exe'));
    expect(stockfish.startupCommands, isNot(contains('stop')));
    expect(stockfish.startupCommands,
        isNot(contains('setoption name UCI_Chess960 value true')));
    expect(stockfish.startupCommands,
        contains('setoption name UCI_Elo value 1800'));
    expect(stockfish.thinkMode,
        const UciThinkMode.movetime(Duration(milliseconds: 700)));

    final maia = UciEngineProfile.primaryFromBotConfig(
      const BotGameConfig.defaultConfig().copyWith(
        engineKind: BotEngineKind.maia,
        maiaElo: 1500,
      ),
    );

    expect(maia.executableCandidates, contains('lc0/lc0.exe'));
    expect(maia.startupCommands, isNot(contains('stop')));
    expect(maia.startupCommands.join('\n'), contains('maia-1500.pb.gz'));
    expect(maia.thinkMode, const UciThinkMode.depth(1));

    final pureMaia = UciEngineProfile.primaryFromBotConfig(
      const BotGameConfig.defaultConfig().copyWith(
        engineKind: BotEngineKind.maia,
        maiaSearchStyle: MaiaSearchStyle.pure,
      ),
    );

    expect(pureMaia.thinkMode, const UciThinkMode.nodes(1));

    final lc0 = UciEngineProfile.primaryFromBotConfig(
      const BotGameConfig.defaultConfig()
          .copyWith(engineKind: BotEngineKind.lc0),
    );

    expect(lc0.executableCandidates, contains('lc0/lc0.exe'));
    expect(lc0.startupCommands, isNot(contains('stop')));
    expect(lc0.startupCommands.join('\n'), contains('791556.pb.gz'));
  });

  test('LC0 UCI profile uses the selected weight path from config', () {
    final lc0 = UciEngineProfile.primaryFromBotConfig(
      const BotGameConfig.defaultConfig().copyWith(
        engineKind: BotEngineKind.lc0,
        lc0WeightLabel: 'Rapid model',
        lc0WeightPath: 'C:/Chessnut/weights/rapid.pb.gz',
      ),
    );

    expect(lc0.name, 'LC0 Rapid model');
    expect(
      lc0.startupCommands,
      contains(
          'setoption name WeightsFile value C:/Chessnut/weights/rapid.pb.gz'),
    );
    expect(lc0.startupCommands.join('\n'), isNot(contains('791556.pb.gz')));
  });

  test('Maia3 does not create a local UCI profile', () {
    final profiles = UciEngineProfile.fromBotConfig(
      const BotGameConfig.defaultConfig().copyWith(
        engineKind: BotEngineKind.maia3,
      ),
    );

    expect(profiles, isEmpty);
  });

  test('native LC0 startup uses extracted weights from engine launch', () {
    final adapter = NativeFlutterBotEngineAdapter();
    final profile = UciEngineProfile.primaryFromBotConfig(
      const BotGameConfig.defaultConfig().copyWith(
        engineKind: BotEngineKind.lc0,
        chess960: true,
      ),
    );

    final commands = adapter.resolveNativeLc0StartupCommandsForTest(profile);

    expect(commands.join('\n'), isNot(contains('WeightsFile')));
    expect(commands, contains('setoption name UCI_Chess960 value true'));
    expect(commands, contains('setoption name Temperature value 1.00'));
    expect(commands, contains('setoption name TempDecayMoves value 4'));
  });

  test('native engine adapter allows slow Android UCI startup', () {
    final adapter = NativeFlutterBotEngineAdapter();

    expect(adapter.startupTimeout, const Duration(seconds: 30));
    expect(adapter.protocolTimeout, const Duration(seconds: 30));
    expect(adapter.moveTimeout, const Duration(seconds: 20));
  });

  test('cached LC0 weights are refreshed when contents differ', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'lc0-weight-cache-test-',
    );
    try {
      final cached = File('${tempDir.path}/maia-1300.pb.gz')
        ..writeAsBytesSync([1, 2, 3, 4]);

      expect(engineAssetFileMatchesForTest(cached, [1, 2, 3, 4]), isTrue);
      expect(engineAssetFileMatchesForTest(cached, [4, 3, 2, 1]), isFalse);
      expect(engineAssetFileMatchesForTest(cached, [1, 2, 3]), isFalse);
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test('UCI profile enables Chess960 when configured', () {
    final stockfish = UciEngineProfile.primaryFromBotConfig(
      const BotGameConfig.defaultConfig().copyWith(
        engineKind: BotEngineKind.stockfish,
        chess960: true,
      ),
    );
    expect(
      stockfish.startupCommands,
      contains('setoption name UCI_Chess960 value true'),
    );

    final maia = UciEngineProfile.primaryFromBotConfig(
      const BotGameConfig.defaultConfig().copyWith(chess960: true),
    );
    expect(
      maia.startupCommands,
      contains('setoption name UCI_Chess960 value true'),
    );
  });

  test('Stockfish 600 uses cross-platform weak profile without invalid UCI_Elo',
      () {
    final profiles = UciEngineProfile.fromBotConfig(
      const BotGameConfig.defaultConfig().copyWith(
        engineKind: BotEngineKind.stockfish,
        stockfishElo: 600,
      ),
    );

    expect(profiles, hasLength(1));
    expect(profiles.single.name, contains('Stockfish weak 600'));
    expect(
      profiles.single.executableCandidates,
      contains('stockfish/stockfish.exe'),
    );
    expect(profiles.single.startupCommands,
        isNot(contains('setoption name UCI_Elo value 600')));
    expect(profiles.single.startupCommands,
        contains('setoption name UCI_LimitStrength value false'));
    expect(profiles.single.startupCommands,
        contains('setoption name Skill Level value 1'));
    expect(profiles.single.thinkMode.kind, UciThinkModeKind.depthAndMovetime);
    expect(profiles.single.thinkMode.value, 5);
    expect(
      profiles.single.thinkMode.duration,
      const Duration(milliseconds: 68),
    );
    expect(profiles.single.thinkMode.command(), 'go movetime 68 depth 5');
  });

  test('Stockfish 1320 uses official UCI_Elo profile only', () {
    final profiles = UciEngineProfile.fromBotConfig(
      const BotGameConfig.defaultConfig().copyWith(
        engineKind: BotEngineKind.stockfish,
        stockfishElo: 1320,
      ),
    );

    expect(profiles, hasLength(1));
    expect(profiles.single.name, 'Stockfish 1320');
    expect(profiles.single.startupCommands,
        contains('setoption name UCI_Elo value 1320'));
    expect(profiles.single.startupCommands,
        isNot(contains('setoption name Skill Level value 1')));
  });

  test('fixed movetime modes schedule a local stop command guard', () {
    expect(
      const UciThinkMode.movetime(Duration(milliseconds: 100)).stopAfter,
      const Duration(milliseconds: 150),
    );
    expect(
      const UciThinkMode.depthAndMovetime(
        depth: 5,
        movetime: Duration(milliseconds: 68),
      ).stopAfter,
      const Duration(milliseconds: 118),
    );
    expect(const UciThinkMode.autoTime().stopAfter, isNull);
    expect(const UciThinkMode.depth(1).stopAfter, isNull);
    expect(const UciThinkMode.nodes(1).stopAfter, isNull);
  });

  test('reusable UCI session initializes once and keeps fixed movetime',
      () async {
    const profile = UciEngineProfile(
      name: 'test stockfish',
      executableCandidates: ['stockfish'],
      startupCommands: ['setoption name UCI_Elo value 1320'],
      thinkMode: UciThinkMode.movetime(Duration(milliseconds: 100)),
    );

    final commands = await runReusableUciSessionCommandsForTest(
      profile: profile,
      startupCommands: profile.startupCommands,
      fens: const [
        chessnutStandardStartFen,
        'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
      ],
      bestMoves: const ['e2e4', 'e7e5'],
    );

    expect(commands.where((command) => command == 'uci'), hasLength(1));
    expect(commands.where((command) => command == 'isready'), hasLength(1));
    expect(commands.where((command) => command == 'ucinewgame'), hasLength(1));
    expect(
      commands.where((command) => command == 'go movetime 100'),
      hasLength(2),
    );
    expect(
      commands,
      containsAllInOrder([
        'uci',
        'setoption name UCI_Elo value 1320',
        'isready',
        'ucinewgame',
        'position fen $chessnutStandardStartFen',
        'go movetime 100',
        'position fen rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
        'go movetime 100',
      ]),
    );
  });

  test('desktop Maia reuses one LC0 process for consecutive moves', () async {
    if (Platform.isWindows) {
      markTestSkipped('The fake UCI executable uses a POSIX shell script.');
      return;
    }

    final tempDir = await Directory.systemTemp.createTemp(
      'reusable-maia-process-test-',
    );
    final launchCount = File('${tempDir.path}/launch-count.txt');
    final appDir = Directory('${tempDir.path}/app')..createSync();
    final executable = File('${appDir.path}/lc0');
    final escapedCountPath = launchCount.path.replaceAll("'", "'\"'\"'");
    executable.writeAsStringSync(
      r'''#!/bin/sh
echo launch >> '__COUNT_PATH__'
moves=0
while IFS= read -r line; do
  case "$line" in
    uci) echo uciok ;;
    isready) echo readyok ;;
    go\ *)
      moves=$((moves + 1))
      if [ "$moves" -eq 1 ]; then
        echo "bestmove e2e4"
      else
        echo "bestmove e7e5"
      fi
      ;;
    quit) exit 0 ;;
  esac
done
'''
          .replaceAll('__COUNT_PATH__', escapedCountPath),
    );
    final chmod = await Process.run('chmod', ['755', executable.path]);
    expect(chmod.exitCode, 0, reason: chmod.stderr.toString());

    final adapter = UciProcessBotEngineAdapter(
      workingDirectory: tempDir.path,
      executableDirectory: appDir.path,
      moveTimeout: const Duration(seconds: 2),
      protocolTimeout: const Duration(seconds: 2),
    );
    final config = const BotGameConfig.defaultConfig().copyWith(
      engineKind: BotEngineKind.maia,
      maiaElo: 1500,
    );
    try {
      await adapter.prepare(config: config);
      final first = await adapter.bestMove(
        fen: chessnutStandardStartFen,
        config: config,
      );
      final second = await adapter.bestMove(
        fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
        config: config,
      );

      expect(first?.uci, 'e2e4');
      expect(second?.uci, 'e7e5');
      expect(launchCount.readAsLinesSync(), hasLength(1));
    } finally {
      await adapter.dispose();
      await tempDir.delete(recursive: true);
    }
  });

  test('UCI best move forwards live engine evaluations', () async {
    const profile = UciEngineProfile(
      name: 'test lc0',
      executableCandidates: ['lc0'],
      startupCommands: ['setoption name WeightsFile value maia.pb.gz'],
      thinkMode: UciThinkMode.depth(1),
    );

    final evaluations = await runUciBestMoveEvaluationsForTest(
      profile: profile,
      fen: chessnutStandardStartFen,
      bestMove: 'e2e4',
      infoLines: const [
        'info depth 1 score cp 12 pv e2e4 e7e5',
        'info depth 2 score cp 31 pv e2e4 c7c5',
        'info depth 3 score mate 2 pv e2e4 e7e5 d1h5',
      ],
    );

    expect(evaluations, hasLength(3));
    expect(evaluations[0].whiteEval, 0.12);
    expect(evaluations[1].whiteEval, 0.31);
    expect(evaluations[2].whiteMate, 2);
    expect(evaluations[2].bestMoveUci, 'e2e4');
  });

  test('DefaultBotEngineAdapter forwards lifecycle to selected adapter',
      () async {
    final process = _LifecycleBotEngineAdapter('e2e4');
    final adapter = DefaultBotEngineAdapter(
      native: _LifecycleBotEngineAdapter('e7e5'),
      process: process,
    );
    final config = const BotGameConfig.defaultConfig().copyWith(
      engineKind: BotEngineKind.stockfish,
      stockfishThinkingTime: const Duration(milliseconds: 100),
    );

    await adapter.prepare(config: config);
    final result = await adapter.bestMove(
      fen: chessnutStandardStartFen,
      config: config,
    );
    await adapter.dispose();

    expect(process.prepareCalls, 1);
    expect(process.bestMoveCalls, 1);
    expect(process.disposeCalls, 1);
    expect(result?.uci, 'e2e4');
  });

  test('DefaultBotEngineAdapter exposes the selected adapter error', () async {
    final process = _LifecycleBotEngineAdapter(
      'e2e4',
      errorMessage: 'Maia 1500 [search] TimeoutException after 20 seconds',
    );
    final adapter = DefaultBotEngineAdapter(
      native: _LifecycleBotEngineAdapter('e7e5'),
      process: process,
    );
    final config = const BotGameConfig.defaultConfig().copyWith(
      engineKind: BotEngineKind.maia,
      maiaElo: 1500,
    );

    final result = await adapter.bestMove(
      fen: chessnutStandardStartFen,
      config: config,
    );

    expect(result, isNull);
    expect(
      adapter.lastErrorMessage,
      'Maia 1500 [search] TimeoutException after 20 seconds',
    );
  });

  test('DefaultBotEngineAdapter keeps Maia3 cloud-only when unavailable',
      () async {
    final cloud = _LifecycleBotEngineAdapter('a1a2');
    final fallback = _LifecycleBotEngineAdapter('e7e5');
    final adapter = DefaultBotEngineAdapter(
      native: _LifecycleBotEngineAdapter('b8c6'),
      process: _LifecycleBotEngineAdapter('b8c6'),
      cloud: cloud,
      fallback: fallback,
    );
    final config = const BotGameConfig.defaultConfig().copyWith(
      engineKind: BotEngineKind.maia3,
      maiaElo: 1500,
    );

    final result = await adapter.bestMove(
      fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
      config: config,
      moveHistory: const ['e2e4'],
    );
    await adapter.dispose();

    expect(cloud.bestMoveCalls, 1);
    expect(fallback.bestMoveCalls, 0);
    expect(result, isNull);
  });

  test('FallbackBotEngineAdapter delegates when real UCI engine is unavailable',
      () async {
    const adapter = FallbackBotEngineAdapter(
      primary: UnavailableBotEngineAdapter(),
      fallback: HeuristicBotEngineAdapter(),
    );

    final result = await adapter.bestMove(
      fen: chessnutStandardStartFen,
      config: const BotGameConfig.defaultConfig(),
    );

    expect(result, isNotNull);
    expect(result!.uci, matches(RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$')));
    expect(result.isFallback, isTrue);
  });

  test('StrictRealBotEngineAdapter does not silently fall back to heuristic',
      () async {
    const adapter = StrictRealBotEngineAdapter(
      primary: UnavailableBotEngineAdapter(),
    );

    final result = await adapter.bestMove(
      fen: chessnutStandardStartFen,
      config: const BotGameConfig.defaultConfig(),
    );

    expect(result, isNull);
  });

  test('UCI adapter resolves executables relative to the working directory',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('uci-adapter-test-');
    final engineDir = Directory('${tempDir.path}/stockfish')..createSync();
    File('${engineDir.path}/stockfish.exe').writeAsStringSync('fake engine');

    final adapter = UciProcessBotEngineAdapter(workingDirectory: tempDir.path);
    final stockfishPath = adapter.resolveExecutablePathForTest(
      const UciEngineProfile(
        name: 'test stockfish',
        executableCandidates: ['stockfish/stockfish.exe'],
        startupCommands: [],
        thinkMode: UciThinkMode.nodes(1),
      ),
    );

    expect(stockfishPath, isNotNull);
    expect(stockfishPath, endsWith('stockfish.exe'));
    await tempDir.delete(recursive: true);
  });

  test('UCI adapter resolves packaged engines relative to the executable',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('uci-app-dir-test-');
    final appDir = Directory('${tempDir.path}/app')..createSync();
    final currentDir = Directory('${tempDir.path}/current')..createSync();
    final engineDir = Directory('${appDir.path}/lc0')..createSync();
    File('${engineDir.path}/lc0.exe').writeAsStringSync('fake lc0');

    final adapter = UciProcessBotEngineAdapter(
      workingDirectory: currentDir.path,
      executableDirectory: appDir.path,
    );
    final lc0Path = adapter.resolveExecutablePathForTest(
      const UciEngineProfile(
        name: 'test lc0',
        executableCandidates: ['lc0/lc0.exe'],
        startupCommands: [],
        thinkMode: UciThinkMode.nodes(1),
      ),
    );

    expect(lc0Path, isNotNull);
    expect(lc0Path, endsWith('lc0.exe'));
    expect(lc0Path, startsWith(appDir.path));
    expect(
        adapter.resolveRuntimeRootForTest(
          const UciEngineProfile(
            name: 'test lc0',
            executableCandidates: ['lc0/lc0.exe'],
            startupCommands: [],
            thinkMode: UciThinkMode.nodes(1),
          ),
        ),
        appDir.path);
    await tempDir.delete(recursive: true);
  });

  test('UCI adapter resolves macOS bundle Stockfish and NNUE files', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('uci-macos-bundle-test-');
    final contentsDir = Directory('${tempDir.path}/Chessnut.app/Contents')
      ..createSync(recursive: true);
    final executableDir = Directory('${contentsDir.path}/MacOS')..createSync();
    final resourcesDir = Directory('${contentsDir.path}/Resources/stockfish')
      ..createSync(recursive: true);
    final executable = File('${executableDir.path}/stockfish')
      ..writeAsStringSync('fake stockfish');
    final bigNet = File('${resourcesDir.path}/nn-c288c895ea92.nnue')
      ..writeAsStringSync('fake big net');
    final smallNet = File('${resourcesDir.path}/nn-37f18f62d772.nnue')
      ..writeAsStringSync('fake small net');

    final adapter = UciProcessBotEngineAdapter(
      workingDirectory: tempDir.path,
      executableDirectory: executableDir.path,
    );
    final profile = UciEngineProfile.primaryFromBotConfig(
      const BotGameConfig.defaultConfig().copyWith(
        engineKind: BotEngineKind.stockfish,
      ),
    );

    expect(
      _samePath(adapter.resolveExecutablePathForTest(profile) ?? '',
          executable.absolute.path),
      isTrue,
    );

    final commands = adapter.resolveStartupCommandsForTest(profile);
    expect(
      commands,
      contains(
        predicate<String>(
          (command) =>
              command.startsWith('setoption name EvalFile value ') &&
              _samePath(command.split(' value ').last, bigNet.absolute.path),
        ),
      ),
    );
    expect(
      commands,
      contains(
        predicate<String>(
          (command) =>
              command.startsWith('setoption name EvalFileSmall value ') &&
              _samePath(command.split(' value ').last, smallNet.absolute.path),
        ),
      ),
    );
    await tempDir.delete(recursive: true);
  });

  test('UCI adapter resolves macOS bundle LC0 and Maia weights', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('uci-macos-lc0-bundle-test-');
    final contentsDir = Directory('${tempDir.path}/Chessnut.app/Contents')
      ..createSync(recursive: true);
    final executableDir = Directory('${contentsDir.path}/MacOS')..createSync();
    final flutterAssetsDir = Directory(
      '${contentsDir.path}/Frameworks/App.framework/Versions/A/Resources/'
      'flutter_assets/assets/maia_weights',
    )..createSync(recursive: true);
    final executable = File('${executableDir.path}/lc0')
      ..writeAsStringSync('fake lc0');
    final weights = File('${flutterAssetsDir.path}/maia-1500.pb.gz')
      ..writeAsStringSync('fake weights');

    final adapter = UciProcessBotEngineAdapter(
      workingDirectory: tempDir.path,
      executableDirectory: executableDir.path,
    );
    final profile = UciEngineProfile.primaryFromBotConfig(
      const BotGameConfig.defaultConfig().copyWith(
        engineKind: BotEngineKind.maia,
        maiaElo: 1500,
      ),
    );

    expect(
      _samePath(adapter.resolveExecutablePathForTest(profile) ?? '',
          executable.absolute.path),
      isTrue,
    );

    final commands = adapter.resolveStartupCommandsForTest(profile);
    expect(
      commands.any(
        (command) =>
            command.startsWith('setoption name WeightsFile value ') &&
            _samePath(
              command.split(' value ').last,
              weights.absolute.path,
            ),
      ),
      isTrue,
    );
    await tempDir.delete(recursive: true);
  });

  test('UCI adapter resolves LC0 weights to absolute packaged paths', () async {
    final tempDir = await Directory.systemTemp.createTemp('uci-weights-test-');
    final appDir = Directory('${tempDir.path}/app')..createSync();
    final engineDir = Directory('${appDir.path}/lc0')..createSync();
    final weightsDir = Directory('${appDir.path}/assets/maia_weights')
      ..createSync(recursive: true);
    File('${engineDir.path}/lc0.exe').writeAsStringSync('fake lc0');
    final weights = File('${weightsDir.path}/maia-1500.pb.gz')
      ..writeAsStringSync('fake weights');

    final adapter = UciProcessBotEngineAdapter(
      workingDirectory: tempDir.path,
      executableDirectory: appDir.path,
    );
    final commands = adapter.resolveStartupCommandsForTest(
      UciEngineProfile.primaryFromBotConfig(
        const BotGameConfig.defaultConfig().copyWith(
          engineKind: BotEngineKind.maia,
          maiaElo: 1500,
        ),
      ),
    );

    expect(
      commands.any(
        (command) =>
            command.startsWith('setoption name WeightsFile value ') &&
            _samePath(
              command.split(' value ').last,
              weights.absolute.path,
            ),
      ),
      isTrue,
    );
    await tempDir.delete(recursive: true);
  });

  test('UCI adapter resolves LC0 weights from Flutter asset bundle path',
      () async {
    final tempDir =
        await Directory.systemTemp.createTemp('uci-flutter-assets-test-');
    final appDir = Directory('${tempDir.path}/app')..createSync();
    final engineDir = Directory('${appDir.path}/lc0')..createSync();
    final weightsDir =
        Directory('${appDir.path}/data/flutter_assets/assets/maia_weights')
          ..createSync(recursive: true);
    File('${engineDir.path}/lc0.exe').writeAsStringSync('fake lc0');
    final weights = File('${weightsDir.path}/maia-1500.pb.gz')
      ..writeAsStringSync('fake weights');

    final adapter = UciProcessBotEngineAdapter(
      workingDirectory: tempDir.path,
      executableDirectory: appDir.path,
    );
    final commands = adapter.resolveStartupCommandsForTest(
      UciEngineProfile.primaryFromBotConfig(
        const BotGameConfig.defaultConfig().copyWith(
          engineKind: BotEngineKind.maia,
          maiaElo: 1500,
        ),
      ),
    );

    expect(
      commands.any(
        (command) =>
            command.startsWith('setoption name WeightsFile value ') &&
            _samePath(
              command.split(' value ').last,
              weights.absolute.path,
            ),
      ),
      isTrue,
    );
    await tempDir.delete(recursive: true);
  });
}

class _LifecycleBotEngineAdapter extends BotEngineAdapter {
  _LifecycleBotEngineAdapter(this.uci, {this.errorMessage});

  final String uci;
  final String? errorMessage;
  int prepareCalls = 0;
  int bestMoveCalls = 0;
  int disposeCalls = 0;

  @override
  String? get lastErrorMessage => errorMessage;

  @override
  Future<void> prepare({required BotGameConfig config}) async {
    prepareCalls += 1;
  }

  @override
  Future<BotMoveResult?> bestMove({
    required String fen,
    required BotGameConfig config,
    List<String> moveHistory = const [],
  }) async {
    bestMoveCalls += 1;
    if (errorMessage != null) return null;
    final position = loadDartChessPosition(fen);
    final move = dc.NormalMove.fromUci(uci);
    if (!position.isLegal(move)) return null;
    final (nextPosition, san) = position.makeSan(move);
    return BotMoveResult(move: move, san: san, fen: nextPosition.fen);
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
  }
}

bool _samePath(String a, String b) {
  String normalize(String value) =>
      value.replaceAll('\\', Platform.pathSeparator).replaceAll(
            '/',
            Platform.pathSeparator,
          );
  return normalize(a) == normalize(b);
}
