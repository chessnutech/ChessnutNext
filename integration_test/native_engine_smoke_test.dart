import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/services/stockfish_analysis_service.dart';
import 'package:chessnut_flutter_export/services/uci_engine_adapter.dart';
import 'package:chessnut_flutter_export/widgets/chess_board.dart';
import 'package:dartchess/dartchess.dart' as dc;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final adapter = NativeFlutterBotEngineAdapter(
    startupTimeout: const Duration(seconds: 30),
    moveTimeout: const Duration(seconds: 30),
  );

  tearDownAll(() async {
    await adapter.dispose();
  });

  Future<void> expectNativeMove({
    required String label,
    required BotGameConfig config,
    String fen = chessnutStandardStartFen,
  }) async {
    final result = await adapter.bestMove(
      fen: fen,
      config: config,
    );

    expect(result, isNotNull, reason: '$label did not return a move.');
    expect(result!.isFallback, isFalse);
    expect(
      result.uci,
      matches(RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$')),
    );
  }

  String applyMove(String fen, String uci) {
    final position = loadDartChessPosition(fen);
    final move = dc.NormalMove.fromUci(uci);
    expect(position.isLegal(move), isTrue, reason: '$uci is illegal in $fen');
    return position.play(move).fen;
  }

  testWidgets('native Stockfish returns a real legal move', (_) async {
    await expectNativeMove(
      label: 'Stockfish',
      config: const BotGameConfig.defaultConfig().copyWith(
        engineKind: BotEngineKind.stockfish,
        stockfishElo: 1500,
        stockfishThinkingTime: const Duration(milliseconds: 100),
      ),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('native Stockfish analyzer returns a real evaluation', (_) async {
    final analysis = await const StockfishPositionAnalyzer(
      timeout: Duration(seconds: 20),
      startupTimeout: Duration(seconds: 30),
    ).analyzeFen(chessnutStandardStartFen, depth: 6, multiPv: 1);

    expect(analysis, isNotNull);
    expect(analysis!.isEngineBacked, isTrue);
    expect(analysis.bestMoveUci, isNotNull);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('native Stockfish bot session analyzes around real moves',
      (_) async {
    final stockfish = const BotGameConfig.defaultConfig().copyWith(
      engineKind: BotEngineKind.stockfish,
      stockfishElo: 1500,
      stockfishThinkingTime: const Duration(milliseconds: 100),
    );

    final openingAnalysis = await adapter.analyzeFen(
      fen: chessnutStandardStartFen,
      config: stockfish,
      depth: 6,
      multiPv: 1,
    );
    expect(openingAnalysis, isNotNull);
    expect(openingAnalysis!.isEngineBacked, isTrue);
    expect(openingAnalysis.bestMoveUci, isNotNull);

    final move = await adapter.bestMove(
      fen: chessnutStandardStartFen,
      config: stockfish,
    );
    expect(move, isNotNull);
    expect(move!.isFallback, isFalse);

    final followUpAnalysis = await adapter.analyzeFen(
      fen: move.fen,
      config: stockfish,
      depth: 6,
      multiPv: 1,
    );
    expect(followUpAnalysis, isNotNull);
    expect(followUpAnalysis!.isEngineBacked, isTrue);
    expect(followUpAnalysis.bestMoveUci, isNotNull);
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('native Maia returns a real legal move', (_) async {
    await expectNativeMove(
      label: 'Maia',
      config: const BotGameConfig.defaultConfig().copyWith(
        engineKind: BotEngineKind.maia,
        maiaElo: 1500,
      ),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('native LC0 returns a real legal move', (_) async {
    await expectNativeMove(
      label: 'LC0',
      config: const BotGameConfig.defaultConfig().copyWith(
        engineKind: BotEngineKind.lc0,
      ),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('native engine can switch Stockfish to Maia to Stockfish',
      (_) async {
    final stockfish = const BotGameConfig.defaultConfig().copyWith(
      engineKind: BotEngineKind.stockfish,
      stockfishElo: 1500,
      stockfishThinkingTime: const Duration(milliseconds: 100),
    );
    await expectNativeMove(label: 'Stockfish before Maia', config: stockfish);
    await expectNativeMove(
      label: 'Maia between Stockfish sessions',
      config: const BotGameConfig.defaultConfig().copyWith(
        engineKind: BotEngineKind.maia,
        maiaElo: 1500,
      ),
    );
    await expectNativeMove(label: 'Stockfish after Maia', config: stockfish);
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('native Maia survives repeated bot game positions', (_) async {
    final maia = const BotGameConfig.defaultConfig().copyWith(
      engineKind: BotEngineKind.maia,
      maiaElo: 1500,
    );

    final afterWhiteMove = applyMove(chessnutStandardStartFen, 'e2e4');
    final blackReply =
        await adapter.bestMove(fen: afterWhiteMove, config: maia);
    expect(blackReply, isNotNull, reason: 'Maia failed after white move.');

    final afterMaiaFirstMove =
        await adapter.bestMove(fen: chessnutStandardStartFen, config: maia);
    expect(afterMaiaFirstMove, isNotNull, reason: 'Maia failed as white.');
    final afterBlackMove = applyMove(afterMaiaFirstMove!.fen, 'e7e5');
    final maiaSecondMove = await adapter.bestMove(
      fen: afterBlackMove,
      config: maia,
    );
    expect(
      maiaSecondMove,
      isNotNull,
      reason: 'Maia failed on its second move.',
    );
  }, timeout: const Timeout(Duration(minutes: 4)));
}
