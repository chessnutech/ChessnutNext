import 'package:flutter_test/flutter_test.dart';

import 'package:chessnut_flutter_export/services/voice_move_parser.dart';
import 'package:chessnut_flutter_export/services/voice_move_recognition_service.dart';

void main() {
  const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  test('parses compact coordinate voice moves', () {
    expect(parseVoiceMoveText('e2 e4'), 'e2e4');
    expect(parseVoiceMoveText('e2e4'), 'e2e4');
    expect(parseVoiceMoveText('from g1 to f3'), 'g1f3');
  });

  test('parses spoken files and ranks', () {
    expect(parseVoiceMoveText('from e two to e four'), 'e2e4');
    expect(parseVoiceMoveText('gee one eff three'), 'g1f3');
  });

  test('parses Chinese rank words', () {
    expect(parseVoiceMoveText('e 二 到 e 四'), 'e2e4');
  });

  test('parses natural algebraic moves using the current position', () {
    expect(parseVoiceMoveText('e4', fen: startFen), 'e2e4');
    expect(parseVoiceMoveText('Nf3', fen: startFen), 'g1f3');
    expect(parseVoiceMoveText('knight f three', fen: startFen), 'g1f3');
    expect(parseVoiceMoveText('\u9a6c f \u4e09', fen: startFen), 'g1f3');
  });

  test('rejects natural moves that are not legal in the current position', () {
    expect(parseVoiceMoveText('e5', fen: startFen), isNull);
    expect(parseVoiceMoveText('king e2', fen: startFen), isNull);
  });

  test('only adds promotion when promotion words are present', () {
    expect(parseVoiceMoveText('b2 b4'), 'b2b4');
    expect(parseVoiceMoveText('e7 e8 promote queen'), 'e7e8q');
    expect(parseVoiceMoveText('e7 e8 升变 后'), 'e7e8q');
  });

  test('uses chess transcription prompt for online recognition', () {
    expect(
      openAiVoiceMovePrompt('Mandarin'),
      'Transcribe only the spoken chess move. Preserve any origin and '
      'destination squares, use Arabic numerals, and do not add commentary. '
      'The speaker uses Mandarin.',
    );
    expect(openAiTranscriptionModel, 'gpt-4o-transcribe');
  });

  test('uses GA realtime endpoint without beta header', () {
    expect(
      openAiRealtimeTranscriptionUrl,
      'wss://api.openai.com/v1/realtime?intent=transcription',
    );
    expect(
      openAiRealtimeHeaders('ek-test'),
      {'authorization': 'Bearer ek-test'},
    );
    expect(openAiRealtimeHeaders('ek-test'), isNot(contains('OpenAI-Beta')));
  });
}
