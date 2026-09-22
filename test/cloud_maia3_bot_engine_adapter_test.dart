import 'dart:convert';

import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/services/chessnut_api_client.dart';
import 'package:chessnut_flutter_export/services/cloud_maia3_bot_engine_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('cloud Maia3 bot move converts backend UCI into board move', () async {
    late http.Request captured;
    final apiClient = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'ret': 1,
            'code': 200,
            'info': 'ok',
            'data': {
              'move': 'e7e5',
              'san': 'e5',
              'probability': 0.28,
              'model': 'maia3-5m',
              'elo': 1500,
              'candidates': [
                {'move': 'e7e5', 'san': 'e5', 'probability': 0.28},
              ],
            },
          }),
          200,
        );
      }),
    );

    final adapter = CloudMaia3BotEngineAdapter(apiClient: apiClient);
    final result = await adapter.bestMove(
      fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
      config: const BotGameConfig.defaultConfig().copyWith(
        engineKind: BotEngineKind.maia3,
        maiaElo: 1500,
      ),
      moveHistory: const ['e2e4'],
    );

    expect(captured.url.path, '/api/v3/maia3/botMove');
    expect(captured.bodyFields['moves'], 'e2e4');
    expect(result?.uci, 'e7e5');
    expect(result?.san, 'e5');
    expect(result?.isFallback, isFalse);
    expect(result?.fen, contains(' w '), reason: 'FEN should remain valid');
  });
}
