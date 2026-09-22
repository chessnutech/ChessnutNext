import 'dart:io';

import 'package:chessnut_flutter_export/services/game_notation_service.dart';
import 'package:chessnut_flutter_export/services/stockfish_analysis_service.dart';
import 'package:chessnut_flutter_export/screens/analysis_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses UCI info score lines with depth and PV', () {
    final cp = UciInfoParser.parseInfoLine(
      'info depth 18 seldepth 22 score cp -34 nodes 100 pv e2e4 e7e5 g1f3',
    );

    expect(cp, isNotNull);
    expect(cp!.depth, 18);
    expect(cp.score.centipawns, -34);
    expect(cp.score.mate, isNull);
    expect(cp.pv, ['e2e4', 'e7e5', 'g1f3']);
    expect(cp.score.whitePawnScore(sideToMove: 'w'), -0.34);
    expect(cp.score.whitePawnScore(sideToMove: 'b'), 0.34);

    final mate = UciInfoParser.parseInfoLine(
      'info depth 12 score mate -3 pv h2h4 h7h5',
    );

    expect(mate, isNotNull);
    expect(mate!.score.centipawns, isNull);
    expect(mate.score.mate, -3);
    expect(mate.score.whitePawnScore(sideToMove: 'b'), 9.7);
    expect(mate.score.whiteMate(sideToMove: 'w'), -3);
    expect(mate.score.whiteMate(sideToMove: 'b'), 3);
  });

  test('candidate scores can be displayed in the fixed white perspective', () {
    const candidate = EngineMoveCandidate(
      moveUci: 'e7e5',
      scoreCentipawns: 96,
      scoreMate: null,
    );
    expect(candidate.whitePawnScore(sideToMove: 'w'), 0.96);
    expect(candidate.whitePawnScore(sideToMove: 'b'), -0.96);

    const mate = EngineMoveCandidate(moveUci: 'e7e5', scoreMate: 3);
    expect(mate.whiteMate(sideToMove: 'w'), 3);
    expect(mate.whiteMate(sideToMove: 'b'), -3);
  });

  test('parses WDL and marks bound scores as non-exact', () {
    final white = UciInfoParser.parseInfoLine(
      'info depth 16 score cp 42 wdl 620 250 130 pv e2e4 e7e5',
    );
    final black = UciInfoParser.parseInfoLine(
      'info depth 16 score cp 42 wdl 620 250 130 pv e7e5 e2e4',
    );
    final bound = UciInfoParser.parseInfoLine(
      'info depth 12 score cp 90 lowerbound wdl 700 200 100 pv d2d4',
    );

    expect(white?.wdl?.sideExpectation, closeTo(0.745, 0.0001));
    expect(
      white?.wdl?.expectation(sideToMove: 'w'),
      closeTo(0.745, 0.0001),
    );
    expect(
      black?.wdl?.expectation(sideToMove: 'b'),
      closeTo(0.255, 0.0001),
    );
    expect(bound?.isBound, isTrue);
  });

  test('analyzes a PGN timeline with engine scores and move quality', () async {
    const pgn = '''
[Event "Chessnut Review"]
[Result "*"]

1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *
''';
    final game = GameNotationService.parsePgn(pgn);
    final engine = _FakePositionAnalyzer({
      for (var i = 0; i < game.snapshots.length; i++)
        game.snapshots[i].fen: PositionEngineAnalysis(
          fen: game.snapshots[i].fen,
          depth: 12,
          whiteEval: switch (i) {
            0 => 0.20,
            1 => 0.30,
            2 => 0.25,
            3 => 0.32,
            4 => 0.30,
            5 => 0.95,
            _ => 1.80,
          },
          bestMoveUci: i == 5 ? 'g8f6' : 'e2e4',
          pv: i == 5 ? const ['g8f6', 'e1g1'] : const ['e2e4', 'e7e5'],
          isEngineBacked: true,
        ),
    });
    final service = StockfishGameAnalysisService(engine: engine);

    final insights = await service.analyzeGame(game);

    expect(insights, hasLength(6));
    expect(insights[4].ply, 5);
    expect(insights[4].evalBefore, 0.30);
    expect(insights[4].evalAfter, 0.95);
    expect(insights[4].classification, 'Great');
    expect(insights[5].ply, 6);
    expect(insights[5].bestMoveUci, 'g8f6');
    expect(insights[5].bestMoveSan, 'Nf6');
    expect(insights[5].engineLine, 'Nf6 O-O');
    expect(insights[5].classification, 'Inaccuracy');
  });

  test('reports real progress from analyzed positions', () async {
    const pgn = '''
[Event "Chessnut Review"]
[Result "*"]

1. e4 e5 *
''';
    final game = GameNotationService.parsePgn(pgn);
    final engine = _FakePositionAnalyzer({
      for (final snapshot in game.snapshots)
        snapshot.fen: PositionEngineAnalysis(
          fen: snapshot.fen,
          depth: 12,
          whiteEval: 0.20,
          bestMoveUci: 'e2e4',
          pv: const ['e2e4', 'e7e5'],
          isEngineBacked: true,
        ),
    });
    final service = StockfishGameAnalysisService(engine: engine);
    final progress = <StockfishGameAnalysisProgress>[];

    final insights = await service.analyzeGame(
      game,
      onProgress: progress.add,
    );

    expect(insights, hasLength(2));
    expect(progress, isNotEmpty);
    expect(progress.first.completedPositions, 0);
    expect(progress.first.totalPositions, game.snapshots.length);
    expect(progress.last.completedPositions, game.snapshots.length);
    expect(progress.last.percent, 1);
  });

  test('analyzes Stockfish positions from the final position backwards',
      () async {
    const pgn = '''
[Event "Reverse Analysis"]
[Result "*"]

1. e4 e5 2. Nf3 Nc6 *
''';
    final game = GameNotationService.parsePgn(pgn);
    final engine = _RecordingFakePositionAnalyzer({
      for (final snapshot in game.snapshots)
        snapshot.fen: PositionEngineAnalysis(
          fen: snapshot.fen,
          depth: 16,
          whiteEval: 0,
          bestMoveUci: null,
          pv: const [],
          isEngineBacked: true,
        ),
    });

    final insights =
        await StockfishGameAnalysisService(engine: engine).analyzeGame(game);

    expect(
      engine.calls,
      game.snapshots.reversed.map((snapshot) => snapshot.fen).toList(),
    );
    expect(insights.map((insight) => insight.ply), [1, 2, 3, 4]);
  });

  test('keeps a checkmating final move when terminal analysis is empty',
      () async {
    const pgn = '''
[Event "Terminal Mate"]
[Result "0-1"]

1. f3 e5 2. g4 Qh4# 0-1
''';
    final game = GameNotationService.parsePgn(pgn);
    final engine = _FakePositionAnalyzer({
      for (var i = 0; i < game.moves.length; i++)
        game.snapshots[i].fen: PositionEngineAnalysis(
          fen: game.snapshots[i].fen,
          depth: 16,
          whiteEval: i == game.moves.length - 1 ? -9.9 : 0,
          whiteMate: i == game.moves.length - 1 ? -1 : null,
          bestMoveUci: game.moves[i].uci,
          pv: [game.moves[i].uci],
          isEngineBacked: true,
        ),
    });

    final insights =
        await StockfishGameAnalysisService(engine: engine).analyzeGame(game);

    expect(insights, hasLength(game.moves.length));
    expect(insights.last.classification, 'Best');
    expect(insights.last.evalAfter, -10);
    expect(insights.last.isEngineBacked, isTrue);
  });

  test('uses Lichess for errors and the historical curve for good moves', () {
    expect(
      StockfishGameAnalysisService.classifyMove(
        whiteMoved: true,
        actualMoveUci: 'g1f3',
        bestMoveUci: 'g1f3',
        before: 0.20,
        after: 0.22,
      ),
      'Best',
    );
    expect(
      StockfishGameAnalysisService.classifyMove(
        whiteMoved: false,
        actualMoveUci: 'f1b5',
        bestMoveUci: 'g1f3',
        before: 0.20,
        after: 0.17,
      ),
      'Great',
    );
    expect(
      StockfishGameAnalysisService.classifyMove(
        whiteMoved: true,
        actualMoveUci: 'g1f3',
        bestMoveUci: 'b1c3',
        before: 0.18,
        after: 0.06,
      ),
      'Excellent',
    );
    expect(
      StockfishGameAnalysisService.classifyMove(
        whiteMoved: true,
        actualMoveUci: 'd1h5',
        bestMoveUci: 'd1e2',
        before: 3.20,
        after: 0.55,
      ),
      'Blunder',
    );

    final blackBlunder = StockfishGameAnalysisService.assessMove(
      whiteMoved: false,
      actualMoveUci: 'a7a6',
      bestMoveUci: 'g8f6',
      before: 0,
      after: 0,
      beforeWhiteOutcomeExpectation: 0.40,
      afterWhiteOutcomeExpectation: 0.72,
    );
    expect(blackBlunder.classification, 'Good');
    expect(blackBlunder.level, EngineScoreMapLevel.good);
  });

  test('uses Lichess thresholds as the exclusive source of error labels', () {
    MoveQualityAssessment assess(double after, {bool whiteMoved = true}) {
      return StockfishGameAnalysisService.assessMove(
        whiteMoved: whiteMoved,
        actualMoveUci: 'a2a3',
        bestMoveUci: 'a2a4',
        before: 0,
        after: after,
      );
    }

    // The historical curve considers this deterioration an Inaccuracy, but
    // Lichess remains below its 0.1 winning-chance threshold. It must stay
    // non-negative in the combined policy.
    expect(assess(-0.5).classification, 'Good');
    expect(assess(-0.5).level, EngineScoreMapLevel.good);
    expect(assess(-0.6).classification, 'Inaccuracy');
    expect(assess(-1.2).classification, 'Mistake');
    expect(assess(-1.8).classification, 'Blunder');
    expect(assess(1.8, whiteMoved: false).classification, 'Blunder');
  });

  test('does not let saturated WDL hide a large evaluation loss', () {
    final whiteMistake = StockfishGameAnalysisService.assessMove(
      whiteMoved: true,
      actualMoveUci: 'f3g5',
      bestMoveUci: 'd2e4',
      before: -2.2,
      after: -4.0,
      beforeWhiteOutcomeExpectation: 0.03,
      afterWhiteOutcomeExpectation: 0.028,
    );
    final blackMistake = StockfishGameAnalysisService.assessMove(
      whiteMoved: false,
      actualMoveUci: 'f6g4',
      bestMoveUci: 'd7e5',
      before: 2.2,
      after: 4.0,
      beforeWhiteOutcomeExpectation: 0.97,
      afterWhiteOutcomeExpectation: 0.972,
    );

    expect(whiteMistake.classification, 'Mistake');
    expect(whiteMistake.level, EngineScoreMapLevel.mistake);
    expect(whiteMistake.accuracyPercent, lessThan(60));
    expect(blackMistake.classification, 'Mistake');
    expect(blackMistake.level, EngineScoreMapLevel.mistake);
  });

  test('does not let historical signals create errors rejected by Lichess', () {
    final outsideTopThree = StockfishGameAnalysisService.assessMove(
      whiteMoved: false,
      actualMoveUci: 'f6g4',
      bestMoveUci: 'd7e5',
      before: 3.2,
      after: 3.6,
      beforeWhiteOutcomeExpectation: 0.97,
      afterWhiteOutcomeExpectation: 0.972,
      candidateRank: null,
      thirdCandidateExpectation: 0.08,
    );
    expect(outsideTopThree.classification, 'Great');
    expect(outsideTopThree.level, EngineScoreMapLevel.best);

    final largeRawLossOutsideTopThree = StockfishGameAnalysisService.assessMove(
      whiteMoved: false,
      actualMoveUci: 'f6g4',
      bestMoveUci: 'd7e5',
      before: 2.0,
      after: 2.9,
      candidateRank: null,
      thirdCandidateExpectation: 0.20,
    );
    expect(largeRawLossOutsideTopThree.classification, 'Inaccuracy');
    expect(
      largeRawLossOutsideTopThree.level,
      EngineScoreMapLevel.inaccuracy,
    );

    final thirdLineWithMaterialLoss = StockfishGameAnalysisService.assessMove(
      whiteMoved: false,
      actualMoveUci: 'e4c4',
      bestMoveUci: 'b5b2',
      before: 3.5,
      after: 3.9,
      beforeWhiteOutcomeExpectation: 0.97,
      afterWhiteOutcomeExpectation: 0.972,
      candidateRank: 3,
      topCandidateExpectation: 0.06,
      thirdCandidateExpectation: 0.03,
    );
    expect(thirdLineWithMaterialLoss.classification, 'Great');
    expect(thirdLineWithMaterialLoss.level, EngineScoreMapLevel.best);

    final equivalentOutsideTopThree = StockfishGameAnalysisService.assessMove(
      whiteMoved: true,
      actualMoveUci: 'g1f3',
      bestMoveUci: 'd2d4',
      before: 0.20,
      after: 0.21,
      beforeWhiteOutcomeExpectation: 0.55,
      afterWhiteOutcomeExpectation: 0.52,
      candidateRank: null,
      thirdCandidateExpectation: 0.53,
    );
    expect(equivalentOutsideTopThree.classification, 'Good');

    final topThreeMove = StockfishGameAnalysisService.assessMove(
      whiteMoved: true,
      actualMoveUci: 'g1f3',
      bestMoveUci: 'd2d4',
      before: 0.20,
      after: -0.20,
      beforeWhiteOutcomeExpectation: 0.55,
      afterWhiteOutcomeExpectation: 0.45,
      candidateRank: 2,
      thirdCandidateExpectation: 0.50,
    );
    expect(topThreeMove.classification, 'Good');
    expect(topThreeMove.level, EngineScoreMapLevel.good);
  });

  test('classifies an advantage reversal as a blunder', () {
    final reversal = StockfishGameAnalysisService.assessMove(
      whiteMoved: true,
      actualMoveUci: 'd1d3',
      bestMoveUci: 'd1a4',
      before: 1.1,
      after: -2.4,
      beforeWhiteOutcomeExpectation: 0.55,
      afterWhiteOutcomeExpectation: 0.54,
    );

    expect(reversal.classification, 'Blunder');
    expect(reversal.level, EngineScoreMapLevel.blunder);
  });

  test('uses FEN side to move when a custom game starts with black', () async {
    const pgn = '''
[Event "Black first analysis"]
[SetUp "1"]
[FEN "4k3/8/8/8/8/8/4P3/4K3 b - - 0 17"]
[Result "*"]

17... Kd7 *
''';
    final game = GameNotationService.parsePgn(pgn);
    final engine = _FakePositionAnalyzer({
      game.snapshots[0].fen: PositionEngineAnalysis(
        fen: game.snapshots[0].fen,
        depth: 16,
        whiteEval: -0.5,
        whiteOutcomeExpectation: 0.30,
        bestMoveUci: 'e8f7',
        pv: const ['e8f7'],
        isEngineBacked: true,
      ),
      game.snapshots[1].fen: PositionEngineAnalysis(
        fen: game.snapshots[1].fen,
        depth: 16,
        whiteEval: 2.0,
        whiteOutcomeExpectation: 0.80,
        bestMoveUci: 'e2e4',
        pv: const ['e2e4'],
        isEngineBacked: true,
      ),
    });

    final insights =
        await StockfishGameAnalysisService(engine: engine).analyzeGame(game);

    expect(insights, hasLength(1));
    expect(insights.single.ply, 1);
    expect(insights.single.classification, 'Blunder');
    expect(insights.single.scoreMap?.level, EngineScoreMapLevel.blunder);
  });

  test('keeps forced mate and detects losing or escaping mate', () {
    final keepsMate = StockfishGameAnalysisService.assessMove(
      whiteMoved: true,
      actualMoveUci: 'h5f7',
      bestMoveUci: 'h5e2',
      before: 9.7,
      after: 9.8,
      beforeMate: 3,
      afterMate: 2,
    );
    final losesMate = StockfishGameAnalysisService.assessMove(
      whiteMoved: true,
      actualMoveUci: 'h5e2',
      bestMoveUci: 'h5f7',
      before: 9.7,
      after: 0.2,
      beforeMate: 3,
      beforeWhiteOutcomeExpectation: 1,
      afterWhiteOutcomeExpectation: 0.52,
    );
    final escapesMate = StockfishGameAnalysisService.assessMove(
      whiteMoved: true,
      actualMoveUci: 'g1h1',
      bestMoveUci: 'g1f1',
      before: -9.8,
      after: -0.2,
      beforeMate: -2,
    );

    expect(keepsMate.classification, 'Great');
    expect(keepsMate.accuracyPercent, 100);
    expect(losesMate.classification, 'Blunder');
    expect(losesMate.accuracyPercent, lessThan(15));
    expect(escapesMate.classification, 'Great');
    expect(escapesMate.accuracyPercent, 100);
  });

  test('calculates legacy score-map accuracy from candidate engine scores', () {
    const scoreMap = EngineScoreMap(
      actualMoveUci: 'd2d4',
      candidates: [
        EngineMoveCandidate(moveUci: 'e2e4', scoreCentipawns: 80),
        EngineMoveCandidate(moveUci: 'd2d4', scoreCentipawns: 75),
        EngineMoveCandidate(moveUci: 'g1f3', scoreCentipawns: 20),
      ],
    );

    expect(scoreMap.level, EngineScoreMapLevel.best);
    expect(scoreMap.legacyLevel, 1);
    expect(scoreMap.accuracyPercent, greaterThan(95));
  });

  test('calculates legacy score-map mate results without fake accuracy', () {
    const winningMate = EngineScoreMap(
      actualMoveUci: 'h5f7',
      candidates: [
        EngineMoveCandidate(moveUci: 'h5f7', scoreMate: 2),
        EngineMoveCandidate(moveUci: 'h5e2', scoreCentipawns: 120),
      ],
    );
    const losingMate = EngineScoreMap(
      actualMoveUci: 'h5e2',
      candidates: [
        EngineMoveCandidate(moveUci: 'h5f7', scoreMate: 2),
        EngineMoveCandidate(moveUci: 'h5e2', scoreMate: -3),
      ],
    );

    expect(winningMate.level, EngineScoreMapLevel.best);
    expect(winningMate.accuracyPercent, 100);
    expect(losingMate.level, EngineScoreMapLevel.blunder);
    expect(losingMate.accuracyPercent, 0);
  });

  test('analyzes a PGN timeline with score-map accuracy per move', () async {
    const pgn = '''
[Event "Chessnut Review"]
[Result "*"]

1. e4 e5 *
''';
    final game = GameNotationService.parsePgn(pgn);
    final engine = _FakePositionAnalyzer({
      game.snapshots[0].fen: PositionEngineAnalysis(
        fen: game.snapshots[0].fen,
        depth: 12,
        whiteEval: 0.20,
        bestMoveUci: 'e2e4',
        pv: const ['e2e4', 'e7e5'],
        isEngineBacked: true,
        candidateMoves: const [
          EngineMoveCandidate(
            moveUci: 'e2e4',
            scoreCentipawns: 80,
            pv: ['e2e4', 'e7e5'],
          ),
          EngineMoveCandidate(
            moveUci: 'd2d4',
            scoreCentipawns: 70,
            pv: ['d2d4', 'd7d5'],
          ),
          EngineMoveCandidate(
            moveUci: 'g1f3',
            scoreCentipawns: 20,
            pv: ['g1f3', 'g8f6'],
          ),
        ],
      ),
      game.snapshots[1].fen: PositionEngineAnalysis(
        fen: game.snapshots[1].fen,
        depth: 12,
        whiteEval: 0.30,
        bestMoveUci: 'c7c5',
        pv: const ['c7c5', 'g1f3'],
        isEngineBacked: true,
        candidateMoves: const [
          EngineMoveCandidate(
            moveUci: 'c7c5',
            scoreCentipawns: 35,
            pv: ['c7c5', 'g1f3'],
          ),
          EngineMoveCandidate(
            moveUci: 'e7e5',
            scoreCentipawns: 30,
            pv: ['e7e5', 'g1f3'],
          ),
          EngineMoveCandidate(
            moveUci: 'g8f6',
            scoreCentipawns: -20,
            pv: ['g8f6', 'g1f3'],
          ),
        ],
      ),
      game.snapshots[2].fen: PositionEngineAnalysis(
        fen: game.snapshots[2].fen,
        depth: 12,
        whiteEval: 0.25,
        bestMoveUci: 'g1f3',
        pv: const ['g1f3', 'b8c6'],
        isEngineBacked: true,
      ),
    });
    final service = StockfishGameAnalysisService(engine: engine);

    final insights = await service.analyzeGame(game);

    expect(insights, hasLength(2));
    expect(insights[0].scoreMap?.level, EngineScoreMapLevel.best);
    expect(insights[0].scoreMap?.accuracyPercent, 100);
    expect(insights[0].candidateVariations, hasLength(3));
    expect(insights[0].candidateVariations[0].line, 'e4 e5');
    expect(insights[0].candidateVariations[1].line, 'd4 d5');
    expect(insights[0].candidateVariations[2].line, 'Nf3 Nf6');
    expect(insights[0].candidateVariations[0].whiteEval, 0.8);
    expect(insights[1].scoreMap?.level, EngineScoreMapLevel.best);
    expect(insights[1].scoreMap?.accuracyPercent, 100);
    expect(insights[1].candidateVariations, hasLength(3));
    expect(insights[1].candidateVariations[0].whiteEval, -0.35);
  });

  test('applies engine insights to review moves for UI consumption', () {
    const pgn = '''
[Event "Chessnut Review"]
[Result "*"]

1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *
''';
    final game = GameNotationService.parsePgn(pgn);
    final moves = buildReviewMovesFromParsedGame(game);
    expect(
        moves.every((move) => move.classification == 'Not analyzed'), isTrue);
    expect(moves.every((move) => !move.hasBoardMarker), isTrue);

    final updated = applyEngineInsightsToReviewMoves(moves, const [
      MoveEngineInsight(
        ply: 5,
        evalBefore: 0.30,
        evalAfter: 0.95,
        depth: 14,
        bestMoveUci: 'f1b5',
        bestMoveSan: 'Bb5',
        engineLine: 'f1b5 a7a6',
        candidateVariations: [
          EngineVariationInsight(
            moveUci: 'f1b5',
            line: 'Bb5 a6',
            whiteEval: 0.9,
          ),
          EngineVariationInsight(
            moveUci: 'f1c4',
            line: 'Bc4 Nf6',
            whiteEval: 0.7,
          ),
        ],
        classification: 'Missed win',
        scoreMap: EngineScoreMap(
          actualMoveUci: 'f1b5',
          candidates: [
            EngineMoveCandidate(moveUci: 'g1f3', scoreCentipawns: 90),
            EngineMoveCandidate(moveUci: 'f1b5', scoreCentipawns: 20),
            EngineMoveCandidate(moveUci: 'a2a3', scoreCentipawns: -20),
          ],
        ),
        isEngineBacked: true,
      ),
    ]);

    final bb5 = updated.firstWhere((move) => move.ply == 5);
    expect(bb5.move, '3. Bb5');
    expect(bb5.evalDeltaLabel, '+0.3 -> +0.9');
    expect(bb5.classification, 'Missed win');
    expect(bb5.marker.symbol, '??');
    expect(bb5.engineLine, 'f1b5 a7a6');
    expect(bb5.candidateVariations, hasLength(2));
    expect(bb5.candidateVariations.last.line, 'Bc4 Nf6');
    expect(bb5.bestMove, 'Best: Bb5');
    expect(bb5.engineDepth, 14);
    expect(bb5.scoreMapLevel, 4);
    expect(bb5.scoreMapAccuracy, greaterThan(70));
    expect(bb5.isEngineBacked, isTrue);
    expect(bb5.isScoreMapBacked, isTrue);
    expect(bb5.isSeriousMistake, isTrue);
    expect(
      updated.where((move) => move.ply != 5).every(
            (move) => move.classification == 'Not analyzed',
          ),
      isTrue,
    );
  });

  test('keeps real move numbers and sides for a black-to-move PGN', () {
    const pgn = '''
[Event "Black to move"]
[SetUp "1"]
[FEN "4k3/8/8/8/8/8/4P3/4K3 b - - 0 17"]
[Result "*"]

17... Kd7 18. e4 *
''';

    final moves = buildReviewMovesFromPgn(pgn);

    expect(moves, hasLength(2));
    expect(moves[0].move, '17... Kd7');
    expect(moves[0].isWhiteMove, isFalse);
    expect(moves[0].moveNumber, 17);
    expect(moves[1].move, '18. e4');
    expect(moves[1].isWhiteMove, isTrue);
    expect(moves[1].moveNumber, 18);
  });

  test('Stockfish analysis resolves packaged executable beside the app',
      () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'stockfish-analysis-app-dir-',
    );
    try {
      final appDir = Directory('${tempDir.path}/app')..createSync();
      final currentDir = Directory('${tempDir.path}/current')..createSync();
      final stockfishDir = Directory('${appDir.path}/stockfish')..createSync();
      final executable = File('${stockfishDir.path}/stockfish.exe')
        ..writeAsStringSync('fake stockfish');

      final analyzer = StockfishPositionAnalyzer(
        workingDirectory: currentDir.path,
        executableDirectory: appDir.path,
      );

      expect(
        _samePath(
          analyzer.resolveExecutablePathForTest() ?? '',
          executable.absolute.path,
        ),
        isTrue,
      );
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test('Stockfish analysis resolves executable from macOS app resources',
      () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'stockfish-analysis-macos-bundle-',
    );
    try {
      final contentsDir = Directory('${tempDir.path}/Chessnut.app/Contents')
        ..createSync(recursive: true);
      final executableDir = Directory('${contentsDir.path}/MacOS')
        ..createSync();
      final resourcesDir = Directory('${contentsDir.path}/Resources/stockfish')
        ..createSync(recursive: true);
      final executable = File('${executableDir.path}/stockfish')
        ..writeAsStringSync('fake stockfish');
      File('${resourcesDir.path}/nn-c288c895ea92.nnue')
          .writeAsStringSync('fake big net');
      File('${resourcesDir.path}/nn-37f18f62d772.nnue')
          .writeAsStringSync('fake small net');

      final analyzer = StockfishPositionAnalyzer(
        workingDirectory: tempDir.path,
        executableDirectory: executableDir.path,
      );

      expect(
        _samePath(
          analyzer.resolveExecutablePathForTest() ?? '',
          executable.absolute.path,
        ),
        isTrue,
      );
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}

bool _samePath(String a, String b) {
  String normalize(String value) =>
      value.replaceAll('\\', Platform.pathSeparator).replaceAll(
            '/',
            Platform.pathSeparator,
          );
  return normalize(a) == normalize(b);
}

class _FakePositionAnalyzer implements PositionAnalyzer {
  const _FakePositionAnalyzer(this.results);

  final Map<String, PositionEngineAnalysis> results;

  @override
  Future<PositionEngineAnalysis?> analyzeFen(
    String fen, {
    int depth = 12,
    int multiPv = 1,
  }) async {
    return results[fen];
  }
}

class _RecordingFakePositionAnalyzer implements PositionAnalyzer {
  _RecordingFakePositionAnalyzer(this.results);

  final Map<String, PositionEngineAnalysis> results;
  final List<String> calls = [];

  @override
  Future<PositionEngineAnalysis?> analyzeFen(
    String fen, {
    int depth = 12,
    int multiPv = 1,
  }) async {
    calls.add(fen);
    return results[fen];
  }
}
