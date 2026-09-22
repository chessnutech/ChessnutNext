import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/services/game_record_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const moves = '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 1-0';

  String pgn({
    String lichessGameId = '',
    String chessnutGameId = '',
    String result = '1-0',
    String body = moves,
  }) {
    return [
      '[Event "Identity test"]',
      '[White "White"]',
      '[Black "Black"]',
      '[Result "$result"]',
      if (lichessGameId.isNotEmpty) '[LichessGameId "$lichessGameId"]',
      if (chessnutGameId.isNotEmpty) '[ChessnutGameId "$chessnutGameId"]',
      '',
      body,
    ].join('\n');
  }

  GameRecord record(
    String value, {
    String playMode = 'analysis',
    String lichessGameId = '',
  }) {
    return GameRecord(
      result: '1-0',
      title: 'White vs Black',
      subtitle: playMode,
      pgn: value,
      playMode: playMode,
      lichessGameIdOverride: lichessGameId,
    );
  }

  test('Lichess game ID is matched before all fallback identities', () {
    final original = GameRecordIdentity.fromRecord(
      record(
        pgn(lichessGameId: 'AbC123', chessnutGameId: 'local-original'),
        playMode: 'lichess',
      ),
    );
    final analysis = GameRecordIdentity.fromRecord(
      record(
        pgn(lichessGameId: 'abc123', chessnutGameId: 'local-analysis'),
      ),
    );

    expect(original.matches(analysis), isTrue);
  });

  test('Chessnut game ID matches bot and Chess.com records', () {
    final bot = GameRecordIdentity.fromRecord(
      record(pgn(chessnutGameId: 'GAME-42'), playMode: 'bot'),
    );
    final chessCom = GameRecordIdentity.fromRecord(
      record(pgn(chessnutGameId: 'game-42'), playMode: 'chesscom'),
    );

    expect(bot.matches(chessCom), isTrue);
  });

  test('empty explicit IDs still use identity headers from the PGN', () {
    final identity = GameRecordIdentity.fromPgn(
      pgn(lichessGameId: 'lichess-header', chessnutGameId: 'game-header'),
      lichessGameId: '',
      chessnutGameId: '',
    );

    expect(identity.lichessGameId, 'lichess-header');
    expect(identity.chessnutGameId, 'game-header');
  });

  test('normalized PGN fingerprint ignores non-identity headers and formatting',
      () {
    final original = GameRecordIdentity.fromRecord(record(pgn()));
    final reformatted = GameRecordIdentity.fromRecord(
      record(
        '[Event "Different event label"]\n'
        '[Black "Black"]\n'
        '[White "White"]\n'
        '[Result "1-0"]\n\n'
        '1.e4 e5 2.Nf3 Nc6 3.Bb5 a6 1-0',
      ),
    );

    expect(original.pgnFingerprint, reformatted.pgnFingerprint);
    expect(original.matches(reformatted), isTrue);
  });

  test('different Lichess IDs never merge even when the PGN is identical', () {
    final first = GameRecordIdentity.fromRecord(
      record(pgn(lichessGameId: 'lichess-one'), playMode: 'lichess'),
    );
    final second = GameRecordIdentity.fromRecord(
      record(pgn(lichessGameId: 'lichess-two'), playMode: 'lichess'),
    );

    expect(first.pgnFingerprint, second.pgnFingerprint);
    expect(first.matches(second), isFalse);
  });

  test('different Chessnut IDs do not fall back to the PGN fingerprint', () {
    final first = GameRecordIdentity.fromRecord(
      record(pgn(chessnutGameId: 'game-one'), playMode: 'bot'),
    );
    final second = GameRecordIdentity.fromRecord(
      record(pgn(chessnutGameId: 'game-two'), playMode: 'chesscom'),
    );

    expect(first.pgnFingerprint, second.pgnFingerprint);
    expect(first.matches(second), isFalse);
  });

  test('PGN fallback does not merge different players with the same moves', () {
    final first = GameRecordIdentity.fromPgn(pgn());
    final second = GameRecordIdentity.fromPgn(
      pgn().replaceFirst('[White "White"]', '[White "Another player"]'),
    );

    expect(first.pgnFingerprint, isNot(second.pgnFingerprint));
    expect(first.matches(second), isFalse);
  });
}
