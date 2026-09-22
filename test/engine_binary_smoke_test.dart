import 'dart:io';

import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/services/uci_engine_adapter.dart';
import 'package:chessnut_flutter_export/widgets/chess_board.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('downloaded Windows engine binaries return legal opening moves',
      () async {
    final stockfish = File('${Directory.current.path}/stockfish/stockfish.exe');
    final lc0 = File('${Directory.current.path}/lc0/lc0.exe');
    final maia = File(
      '${Directory.current.path}/assets/maia_weights/maia-1500.pb.gz',
    );
    final lc0Weights = File(
      '${Directory.current.path}/assets/lc0_weights/791556.pb.gz',
    );

    if (!stockfish.existsSync() ||
        !lc0.existsSync() ||
        !maia.existsSync() ||
        !lc0Weights.existsSync()) {
      markTestSkipped('Engine binaries or weights are not present locally.');
      return;
    }

    final adapter = UciProcessBotEngineAdapter(
      moveTimeout: const Duration(seconds: 12),
    );
    addTearDown(adapter.dispose);
    final configs = {
      'stockfish fixed time': const BotGameConfig.defaultConfig().copyWith(
        engineKind: BotEngineKind.stockfish,
        stockfishThinkingTime: const Duration(milliseconds: 50),
      ),
      'stockfish auto time': const BotGameConfig.defaultConfig().copyWith(
        engineKind: BotEngineKind.stockfish,
        stockfishThinkingTime: Duration.zero,
      ),
      'maia': const BotGameConfig.defaultConfig().copyWith(
        engineKind: BotEngineKind.maia,
        maiaElo: 1500,
      ),
      'lc0': const BotGameConfig.defaultConfig().copyWith(
        engineKind: BotEngineKind.lc0,
      ),
    };

    for (final entry in configs.entries) {
      final result = await adapter.bestMove(
        fen: chessnutStandardStartFen,
        config: entry.value,
      );
      expect(result, isNotNull, reason: '${entry.key} did not move');
      expect(
        result!.uci,
        matches(RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$')),
        reason: '${entry.key} returned a malformed UCI move',
      );
      expect(result.isFallback, isFalse);
    }
  });

  test('downloaded Stockfish covers low Stockfish Elo weak profile', () async {
    final stockfish = File('${Directory.current.path}/stockfish/stockfish.exe');
    if (!stockfish.existsSync()) {
      markTestSkipped('Stockfish is not present locally.');
      return;
    }

    final adapter = UciProcessBotEngineAdapter(
      moveTimeout: const Duration(seconds: 12),
    );
    addTearDown(adapter.dispose);
    var fen = chessnutStandardStartFen;
    final config = const BotGameConfig.defaultConfig().copyWith(
      engineKind: BotEngineKind.stockfish,
      stockfishElo: 600,
      stockfishThinkingTime: const Duration(milliseconds: 50),
    );

    for (var ply = 0; ply < 4; ply += 1) {
      final result = await adapter.bestMove(fen: fen, config: config);
      expect(
        result,
        isNotNull,
        reason: 'Stockfish weak profile failed at ply $ply from $fen',
      );
      expect(result!.isFallback, isFalse);
      fen = result.fen;
      expect(loadDartChessPosition(fen).fen, fen);
    }
  });

  test('downloaded Stockfish covers maximum official Elo profile', () async {
    final stockfish = File('${Directory.current.path}/stockfish/stockfish.exe');
    if (!stockfish.existsSync()) {
      markTestSkipped('Stockfish is not present locally.');
      return;
    }

    final adapter = UciProcessBotEngineAdapter(
      moveTimeout: const Duration(seconds: 12),
    );
    addTearDown(adapter.dispose);
    var fen = chessnutStandardStartFen;
    final config = const BotGameConfig.defaultConfig().copyWith(
      engineKind: BotEngineKind.stockfish,
      stockfishElo: 3190,
      stockfishThinkingTime: const Duration(milliseconds: 50),
    );

    for (var ply = 0; ply < 4; ply += 1) {
      final result = await adapter.bestMove(fen: fen, config: config);
      expect(
        result,
        isNotNull,
        reason: 'Stockfish 3190 failed at ply $ply from $fen',
      );
      expect(result!.isFallback, isFalse);
      fen = result.fen;
      expect(loadDartChessPosition(fen).fen, fen);
    }
  });

  test('downloaded Maia 1100 responds after white plays e4', () async {
    final lc0Dir = Directory('${Directory.current.path}/lc0');
    final maia1100 = File(
      '${Directory.current.path}/assets/maia_weights/maia-1100.pb.gz',
    );

    if (!lc0Dir.existsSync() || !maia1100.existsSync()) {
      markTestSkipped('LC0 or Maia 1100 weights are not present locally.');
      return;
    }

    final adapter = UciProcessBotEngineAdapter(
      moveTimeout: const Duration(seconds: 16),
    );
    addTearDown(adapter.dispose);
    final result = await adapter.bestMove(
      fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
      config: const BotGameConfig.defaultConfig().copyWith(
        engineKind: BotEngineKind.maia,
        maiaElo: 1100,
      ),
    );

    expect(result, isNotNull);
    expect(result!.isFallback, isFalse);
    expect(result.uci, matches(RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$')));
  });

  test('Windows process engines start when the app path contains spaces',
      () async {
    final stockfish = File('${Directory.current.path}/stockfish/stockfish.exe');
    final lc0Dir = Directory('${Directory.current.path}/lc0');
    final maiaDir = Directory('${Directory.current.path}/assets/maia_weights');

    if (!stockfish.existsSync() ||
        !lc0Dir.existsSync() ||
        !maiaDir.existsSync()) {
      markTestSkipped('Engine binaries or weights are not present locally.');
      return;
    }

    final tempRoot = await Directory.systemTemp.createTemp(
      'chessnut engine path with spaces ',
    );
    UciProcessBotEngineAdapter? adapter;
    try {
      final stockfishTarget = Directory('${tempRoot.path}/stockfish');
      final lc0Target = Directory('${tempRoot.path}/lc0');
      final maiaTarget = Directory('${tempRoot.path}/assets/maia_weights');
      stockfishTarget.createSync(recursive: true);
      lc0Target.createSync(recursive: true);
      maiaTarget.createSync(recursive: true);
      stockfish.copySync('${stockfishTarget.path}/stockfish.exe');
      for (final item in lc0Dir.listSync()) {
        if (item is File) {
          item.copySync('${lc0Target.path}/${item.uri.pathSegments.last}');
        }
      }
      File('${maiaDir.path}/maia-1500.pb.gz')
          .copySync('${maiaTarget.path}/maia-1500.pb.gz');

      adapter = UciProcessBotEngineAdapter(
        workingDirectory: tempRoot.path,
        executableDirectory: tempRoot.path,
        moveTimeout: const Duration(seconds: 12),
      );

      for (final entry in {
        'stockfish fixed time': const BotGameConfig.defaultConfig().copyWith(
          engineKind: BotEngineKind.stockfish,
          stockfishThinkingTime: const Duration(milliseconds: 50),
        ),
        'stockfish auto time': const BotGameConfig.defaultConfig().copyWith(
          engineKind: BotEngineKind.stockfish,
          stockfishThinkingTime: Duration.zero,
        ),
        'maia': const BotGameConfig.defaultConfig().copyWith(
          engineKind: BotEngineKind.maia,
          maiaElo: 1500,
        ),
      }.entries) {
        final result = await adapter.bestMove(
          fen: chessnutStandardStartFen,
          config: entry.value,
        );
        expect(
          result,
          isNotNull,
          reason: '${entry.key} did not start under ${tempRoot.path}',
        );
      }
    } finally {
      await adapter?.dispose();
      for (var attempt = 0; attempt < 5; attempt += 1) {
        try {
          await tempRoot.delete(recursive: true);
          break;
        } on FileSystemException {
          if (attempt == 4) rethrow;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
    }
  });

  test('packaged Windows directory layout starts Stockfish and Maia', () async {
    final stockfish = File('${Directory.current.path}/stockfish/stockfish.exe');
    final lc0Dir = Directory('${Directory.current.path}/lc0');
    final maiaDir = Directory('${Directory.current.path}/assets/maia_weights');

    if (!stockfish.existsSync() ||
        !lc0Dir.existsSync() ||
        !maiaDir.existsSync()) {
      markTestSkipped('Engine binaries or weights are not present locally.');
      return;
    }

    final tempRoot = await Directory.systemTemp.createTemp(
      'chessnut packaged app layout ',
    );
    UciProcessBotEngineAdapter? adapter;
    try {
      final appDir = Directory('${tempRoot.path}/release')..createSync();
      final currentDir = Directory('${tempRoot.path}/launch-dir')..createSync();
      final stockfishTarget = Directory('${appDir.path}/stockfish')
        ..createSync(recursive: true);
      final lc0Target = Directory('${appDir.path}/lc0')
        ..createSync(recursive: true);
      final maiaTarget =
          Directory('${appDir.path}/data/flutter_assets/assets/maia_weights')
            ..createSync(recursive: true);

      stockfish.copySync('${stockfishTarget.path}/stockfish.exe');
      for (final item in lc0Dir.listSync()) {
        if (item is File) {
          item.copySync('${lc0Target.path}/${item.uri.pathSegments.last}');
        }
      }
      File('${maiaDir.path}/maia-1500.pb.gz')
          .copySync('${maiaTarget.path}/maia-1500.pb.gz');

      adapter = UciProcessBotEngineAdapter(
        workingDirectory: currentDir.path,
        executableDirectory: appDir.path,
        moveTimeout: const Duration(seconds: 16),
      );

      for (final entry in {
        'stockfish': const BotGameConfig.defaultConfig().copyWith(
          engineKind: BotEngineKind.stockfish,
          stockfishThinkingTime: const Duration(milliseconds: 50),
        ),
        'maia': const BotGameConfig.defaultConfig().copyWith(
          engineKind: BotEngineKind.maia,
          maiaElo: 1500,
        ),
      }.entries) {
        final result = await adapter.bestMove(
          fen: chessnutStandardStartFen,
          config: entry.value,
        );
        expect(
          result,
          isNotNull,
          reason: '${entry.key} did not start from packaged layout',
        );
        expect(result!.isFallback, isFalse);
      }
    } finally {
      await adapter?.dispose();
      for (var attempt = 0; attempt < 5; attempt += 1) {
        try {
          await tempRoot.delete(recursive: true);
          break;
        } on FileSystemException {
          if (attempt == 4) rethrow;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
    }
  });
}
