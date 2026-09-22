import 'package:chessnut_flutter_export/services/model_build_source_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('counts PGN games from Event headers', () {
    final pgn = List.generate(
      20,
      (index) => '[Event "Chessnut $index"]\n1. e4 e5 2. Nf3 Nc6 *',
    ).join('\n\n');

    expect(countModelBuildPgnGames(pgn), 20);
  });

  test('counts PGN games from result tokens when headers are absent', () {
    const pgn = '1. e4 e5 1-0\n\n1. d4 d5 0-1\n\n1. c4 e6 1/2-1/2';

    expect(countModelBuildPgnGames(pgn), 3);
  });

  test('merges selected PGN files with stable blank separators', () {
    final merged = mergeModelBuildPgnFiles([
      '[Event "A"]\n1. e4 e5 1-0\n',
      '\n[Event "B"]\n1. d4 d5 0-1',
    ]);

    expect(merged, '[Event "A"]\n1. e4 e5 1-0\n\n\n[Event "B"]\n1. d4 d5 0-1');
    expect(countModelBuildPgnGames(merged), 2);
  });

  test('adds a white Train tag by matching the PGN player name', () {
    const pgn = '[Event "White game"]\n'
        '[White "  Chessnut Player  "]\n'
        '[Black "Opponent"]\n\n'
        '1. e4 e5 *';

    final tagged = addModelBuildTrainTag(
      pgn,
      playerName: 'chessnut   player',
    );

    expect(tagged, contains('[Black "Opponent"]\n[Train "w"]\n\n'));
  });

  test('adds a black Train tag and matches names case-insensitively', () {
    const pgn = '[Event "Black game"]\n'
        '[White "Opponent"]\n'
        '[Black "Storm123"]\n\n'
        '1. d4 d5 *';

    final tagged = addModelBuildTrainTag(pgn, playerName: 'STORM123');

    expect(tagged, contains('[Train "b"]'));
  });

  test('uses record player names only when PGN side headers are missing', () {
    const pgn = '[Event "Record game"]\n[Result "*"]\n\n1. c4 e5 *';

    final tagged = addModelBuildTrainTag(
      pgn,
      playerName: 'Chessnut Player',
      whiteName: 'Opponent',
      blackName: 'Chessnut Player',
    );

    expect(tagged, contains('[Result "*"]\n[Train "b"]\n\n'));
  });

  test('updates an existing Train tag without adding a duplicate', () {
    const pgn = '[Event "Retag"]\n'
        '[White "Opponent"]\n'
        '[Black "storm123"]\n'
        '[Train "w"]\n\n'
        '1. Nf3 d5 *';

    final tagged = addModelBuildTrainTag(pgn, playerName: 'storm123');

    expect(
        RegExp(r'^\[Train ', multiLine: true).allMatches(tagged), hasLength(1));
    expect(tagged, contains('[Train "b"]'));
  });

  test('leaves a game unchanged when neither side matches the player', () {
    const pgn = '[Event "Other game"]\n'
        '[White "Alice"]\n'
        '[Black "Bob"]\n\n'
        '1. e4 c5 *';

    expect(
      addModelBuildTrainTag(pgn, playerName: 'Chessnut Player'),
      pgn,
    );
  });

  test('prefers usable game total over preview sample count', () {
    final preview = ModelBuildPreview.fromJson({
      'usable_count': 64,
      'matched_count': 72,
      'game_count': 4,
      'source_label': 'Game Record storm123',
      'games': [
        for (var index = 1; index <= 4; index++)
          {
            'pgn': '[Event "Sample $index"]\n'
                '[White "storm123"]\n'
                '[Black "Opponent $index"]\n\n'
                '1. e4 e5 *',
          },
      ],
    });

    expect(preview.gameCount, 64);
    expect(preview.sourceLabel, 'Game Record storm123');
    expect(countModelBuildPgnGames(preview.pgn), 4);
  });

  test('limits preview PGN arrays to a small sample', () {
    final preview = ModelBuildPreview.fromJson({
      'usable_count': 200,
      'source_label': 'Lichess storm123',
      'games': [
        for (var index = 1; index <= 100; index++)
          {
            'pgn': '[Event "Lichess Sample $index"]\n'
                '[White "storm123"]\n'
                '[Black "Opponent $index"]\n\n'
                '1. e4 e5 *',
          },
      ],
    });

    expect(preview.gameCount, 200);
    expect(countModelBuildPgnGames(preview.pgn), 20);
    expect(preview.pgn, contains('[Event "Lichess Sample 20"]'));
    expect(preview.pgn, isNot(contains('[Event "Lichess Sample 21"]')));
  });

  test('validates minimum and recommended game counts', () {
    expect(isModelBuildGameCountSubmittable(19), isFalse);
    expect(isModelBuildGameCountSubmittable(20), isTrue);
    expect(isModelBuildGameCountSubmittable(200), isTrue);
    expect(isModelBuildGameCountSubmittable(201), isFalse);
    expect(isModelBuildGameCountRecommended(49), isFalse);
    expect(isModelBuildGameCountRecommended(50), isTrue);
  });
}
