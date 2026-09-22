import 'package:dartchess/dartchess.dart' as dc;

import '../models/app_models.dart';
import '../widgets/chess_board.dart';
import 'bot_engine_adapter.dart';
import 'chessnut_api_client.dart';

class CloudMaia3BotEngineAdapter extends BotEngineAdapter {
  const CloudMaia3BotEngineAdapter({this.apiClient});

  final ChessnutApiClient? apiClient;

  @override
  Future<BotMoveResult?> bestMove({
    required String fen,
    required BotGameConfig config,
    List<String> moveHistory = const [],
  }) async {
    if (config.engineKind != BotEngineKind.maia3) return null;
    final client = apiClient ?? ChessnutApiClient();
    if (client.session == null) return null;
    final result = await client.maia3BotMove(
      fen: fen,
      moves: moveHistory,
      elo: config.maiaElo,
      multiPv: 5,
    );
    final data = result.data;
    if (!result.isSuccess || data == null || data.move.trim().isEmpty) {
      return null;
    }
    return _botMoveFromUci(fen: fen, uci: data.move, san: data.san);
  }
}

BotMoveResult? _botMoveFromUci({
  required String fen,
  required String uci,
  required String san,
}) {
  try {
    final position = loadDartChessPosition(fen);
    final move = dc.NormalMove.fromUci(uci.trim());
    if (!position.isLegal(move)) return null;
    final (nextPosition, generatedSan) = position.makeSan(move);
    return BotMoveResult(
      move: move,
      san: san.trim().isEmpty ? generatedSan : san.trim(),
      fen: nextPosition.fen,
      isFallback: false,
    );
  } catch (_) {
    return null;
  }
}
