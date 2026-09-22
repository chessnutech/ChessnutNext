import 'package:chessnut_flutter_export/services/analysis_report_cache_service.dart';
import 'package:chessnut_flutter_export/services/app_preferences_store.dart';
import 'package:chessnut_flutter_export/services/game_notation_service.dart';
import 'package:chessnut_flutter_export/services/mistake_book_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts serious mistakes from a standard analysis report', () {
    const pgn = '[Event "Mistake Source"]\n'
        '[White "Player"]\n'
        '[Black "Opponent"]\n'
        '[Result "*"]\n\n'
        '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *';
    final parsed = GameNotationService.parsePgn(pgn);
    final report = GameStandardAnalysisReport(
      generatedAt: DateTime.utc(2026, 5, 30, 10),
      stockfishBacked: true,
      stockfishStatus: 'Report ready',
      moves: [
        CachedReviewMove(
          ply: 1,
          move: '1. e4',
          evalBefore: 0,
          evalAfter: 0.1,
          classification: 'Best',
          summary: 'Good opening move.',
          fen: parsed.moves[0].fenAfter,
          lastMove: const ['e2', 'e4'],
          focusSquare: 'e4',
          engineLine: 'e4 e5',
          bestMove: 'Best: e4',
          keyMoment: false,
        ),
        CachedReviewMove(
          ply: 5,
          move: '3. Bb5?',
          evalBefore: 0.3,
          evalAfter: -1.2,
          classification: 'Mistake',
          summary: 'This missed a cleaner developing move.',
          fen: parsed.moves[4].fenAfter,
          lastMove: const ['f1', 'b5'],
          focusSquare: 'b5',
          engineLine: 'Bc4 Nf6',
          bestMove: 'Best: Bc4',
          keyMoment: true,
          scoreMapAccuracy: 34,
        ),
      ],
    );

    final entries = MistakeBookExtractor.extractFromStandardReport(
      reportKey: 'pgnhash:test',
      pgn: pgn,
      report: report,
      now: DateTime.utc(2026, 5, 30, 12),
    );

    expect(entries, hasLength(1));
    final entry = entries.single;
    expect(entry.id, 'pgnhash:test:5');
    expect(entry.ply, 5);
    expect(entry.moveSan, '3. Bb5?');
    expect(entry.bestMoveSan, 'Bc4');
    expect(entry.fenBefore, parsed.moves[4].fenBefore);
    expect(entry.fenAfter, parsed.moves[4].fenAfter);
    expect(entry.sourceTitle, 'Player vs Opponent');
    expect(entry.dueAt, DateTime.utc(2026, 5, 30, 12));
  });

  test('extracts mistakes from server reports with alternate field names', () {
    const pgn = '[Event "Server Mistake"]\n'
        '[White "Server Player"]\n'
        '[Black "Server Bot"]\n'
        '[Result "*"]\n\n'
        '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *';
    final parsed = GameNotationService.parsePgn(pgn);
    final report = GameStandardAnalysisReport.fromJson({
      'generated_at': '2026-05-30T10:00:00.000Z',
      'stockfish_backed': true,
      'stockfish_status': 'Report ready',
      'moves': [
        {
          'move_ply': 5,
          'san': '3. Bb5?',
          'evalBefore': 0.3,
          'evalAfter': -1.2,
          'label': 'mistake',
          'comment': 'This missed a cleaner developing move.',
          'fenAfter': parsed.moves[4].fenAfter,
          'lastMove': ['f1', 'b5'],
          'focusSquare': 'b5',
          'engineLine': 'Bc4 Nf6',
          'bestMoveSan': 'Bc4',
          'keyMoment': true,
        },
      ],
    });

    final entries = MistakeBookExtractor.extractFromStandardReport(
      reportKey: 'pgnhash:server',
      pgn: pgn,
      report: report,
      now: DateTime.utc(2026, 5, 30, 12),
    );

    expect(entries, hasLength(1));
    expect(entries.single.id, 'pgnhash:server:5');
    expect(entries.single.classification, 'Mistake');
    expect(entries.single.bestMoveSan, 'Bc4');
    expect(entries.single.fenBefore, parsed.moves[4].fenBefore);
  });

  test('extracts mistakes from score-map severity when classification is empty',
      () {
    const pgn = '[Event "Score Map Mistake"]\n\n'
        '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *';
    final parsed = GameNotationService.parsePgn(pgn);
    final report = GameStandardAnalysisReport(
      generatedAt: DateTime.utc(2026, 5, 30, 10),
      stockfishBacked: true,
      stockfishStatus: 'Report ready',
      moves: [
        CachedReviewMove(
          ply: 5,
          move: '3. Bb5?',
          evalBefore: 0.3,
          evalAfter: -1.2,
          classification: '',
          summary: 'Low score-map accuracy.',
          fen: parsed.moves[4].fenAfter,
          lastMove: const ['f1', 'b5'],
          focusSquare: 'b5',
          engineLine: 'Bc4 Nf6',
          bestMove: 'Best: Bc4',
          keyMoment: true,
          scoreMapAccuracy: 34,
          scoreMapLevel: 5,
        ),
      ],
    );

    final entries = MistakeBookExtractor.extractFromStandardReport(
      reportKey: 'pgnhash:scoremap',
      pgn: pgn,
      report: report,
      now: DateTime.utc(2026, 5, 30, 12),
    );

    expect(entries, hasLength(1));
    expect(entries.single.classification, 'Mistake');
    expect(entries.single.theme, 'Mistake');
  });

  test('extracts an inaccuracy when the report has no score-map accuracy', () {
    const pgn = '[Event "Inaccuracy without score map"]\n'
        '[White "Player"]\n'
        '[Black "Opponent"]\n'
        '[Result "*"]\n\n'
        '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *';
    final parsed = GameNotationService.parsePgn(pgn);
    final report = GameStandardAnalysisReport(
      generatedAt: DateTime.utc(2026, 8, 13, 10),
      stockfishBacked: true,
      stockfishStatus: 'Report ready',
      moves: [
        CachedReviewMove(
          ply: 5,
          move: '3. Bb5',
          evalBefore: 0.3,
          evalAfter: 0.05,
          classification: 'Inaccuracy',
          summary: 'A small evaluation loss.',
          fen: parsed.moves[4].fenAfter,
          lastMove: const ['f1', 'b5'],
          focusSquare: 'b5',
          engineLine: 'Bc4 Nf6',
          bestMove: 'Best: Bc4',
          keyMoment: false,
        ),
      ],
    );

    final entries = MistakeBookExtractor.extractFromStandardReport(
      reportKey: 'pgnhash:inaccuracy-no-score-map',
      pgn: pgn,
      report: report,
    );

    expect(entries, hasLength(1));
    expect(entries.single.classification, 'Inaccuracy');
  });

  test('does not extract a mistake when the position has one legal move', () {
    const pgn = '[Event "Forced Move"]\n'
        '[SetUp "1"]\n'
        '[FEN "7k/8/8/8/8/8/5r2/7K w - - 0 1"]\n'
        '[Result "*"]\n\n'
        '1. Kg1 *';
    final parsed = GameNotationService.parsePgn(pgn);
    final report = GameStandardAnalysisReport(
      generatedAt: DateTime.utc(2026, 8, 4, 8),
      stockfishBacked: true,
      stockfishStatus: 'Report ready',
      moves: [
        CachedReviewMove(
          ply: 1,
          move: '1. Kg1?',
          evalBefore: -3,
          evalAfter: -3,
          classification: 'Mistake',
          summary: 'The only legal move was incorrectly classified.',
          fen: parsed.moves.single.fenAfter,
          lastMove: const ['h1', 'g1'],
          focusSquare: 'g1',
          engineLine: 'Kg1',
          bestMove: 'Best: Kg1',
          keyMoment: true,
        ),
      ],
    );

    final entries = MistakeBookExtractor.extractFromStandardReport(
      reportKey: 'pgnhash:forced',
      pgn: pgn,
      report: report,
      now: DateTime.utc(2026, 8, 4, 9),
    );

    expect(entries, isEmpty);
  });

  test('does not extract a mistake when actual and best move are the same', () {
    const pgn = '[Event "Same Move"]\n'
        '[White "Player"]\n'
        '[Black "Opponent"]\n'
        '[Result "*"]\n\n'
        '1. e4 *';
    final parsed = GameNotationService.parsePgn(pgn);
    final report = GameStandardAnalysisReport(
      generatedAt: DateTime.utc(2026, 8, 4, 8),
      stockfishBacked: true,
      stockfishStatus: 'Report ready',
      moves: [
        CachedReviewMove(
          ply: 1,
          move: '1. e4?!',
          evalBefore: 0,
          evalAfter: -1,
          classification: 'Mistake',
          summary: 'The report repeated the played move as the best move.',
          fen: parsed.moves.single.fenAfter,
          lastMove: const ['e2', 'e4'],
          focusSquare: 'e4',
          engineLine: 'e4',
          bestMove: 'Best: e4+',
          keyMoment: true,
        ),
      ],
    );

    final entries = MistakeBookExtractor.extractFromStandardReport(
      reportKey: 'pgnhash:same-move',
      pgn: pgn,
      report: report,
      now: DateTime.utc(2026, 8, 4, 9),
    );

    expect(entries, isEmpty);
  });

  test('store removes a saved mistake whose actual and best move match',
      () async {
    const reportKey = 'pgnhash:same-move-existing';
    const pgn = '[Event "Same Move"]\n'
        '[White "Player"]\n'
        '[Black "Opponent"]\n'
        '[Result "*"]\n\n'
        '1. e4 *';
    final parsed = GameNotationService.parsePgn(pgn);
    final now = DateTime.utc(2026, 8, 4, 9);
    final report = GameStandardAnalysisReport(
      generatedAt: now,
      stockfishBacked: true,
      stockfishStatus: 'Report ready',
      moves: [
        CachedReviewMove(
          ply: 1,
          move: '1. e4?!',
          evalBefore: 0,
          evalAfter: -1,
          classification: 'Mistake',
          summary: 'The report repeated the played move as the best move.',
          fen: parsed.moves.single.fenAfter,
          lastMove: const ['e2', 'e4'],
          focusSquare: 'e4',
          engineLine: 'e4',
          bestMove: 'Best: e4',
          keyMoment: true,
        ),
      ],
    );
    final staleEntry = MistakeBookEntry(
      id: '$reportKey:1',
      reportKey: reportKey,
      pgn: pgn,
      sourceTitle: 'Player vs Opponent',
      ply: 1,
      moveSan: '1. e4?!',
      bestMoveSan: 'e4',
      classification: 'Mistake',
      summary: 'The report repeated the played move as the best move.',
      theme: 'Mistake',
      fenBefore: parsed.moves.single.fenBefore,
      fenAfter: parsed.moves.single.fenAfter,
      engineLine: 'e4',
      createdAt: now,
      updatedAt: now,
      dueAt: now,
    );
    final preferencesStore = MemoryAppPreferencesStore(
      StoredAppPreferences(
        analysisReports: {
          reportKey: GameAnalysisReportCacheEntry(
            pgn: pgn,
            standardReport: report,
            updatedAt: now,
          ),
        },
        mistakeBook: MistakeBookState(entries: {staleEntry.id: staleEntry}),
      ),
    );
    final store = AppPreferencesMistakeBookStore(preferencesStore);

    final state = await store.read();

    expect(state.entries, isEmpty);
    expect((await preferencesStore.read()).mistakeBook.entries, isEmpty);
  });

  test('store removes a saved forced-move mistake when reports resync',
      () async {
    const reportKey = 'pgnhash:forced-existing';
    const pgn = '[Event "Forced Move"]\n'
        '[SetUp "1"]\n'
        '[FEN "7k/8/8/8/8/8/5r2/7K w - - 0 1"]\n'
        '[Result "*"]\n\n'
        '1. Kg1 *';
    final parsed = GameNotationService.parsePgn(pgn);
    final now = DateTime.utc(2026, 8, 4, 9);
    final report = GameStandardAnalysisReport(
      generatedAt: now,
      stockfishBacked: true,
      stockfishStatus: 'Report ready',
      moves: [
        CachedReviewMove(
          ply: 1,
          move: '1. Kg1?',
          evalBefore: -3,
          evalAfter: -3,
          classification: 'Mistake',
          summary: 'The only legal move was incorrectly classified.',
          fen: parsed.moves.single.fenAfter,
          lastMove: const ['h1', 'g1'],
          focusSquare: 'g1',
          engineLine: 'Kg1',
          bestMove: 'Best: Kg1',
          keyMoment: true,
        ),
      ],
    );
    final staleEntry = MistakeBookEntry(
      id: '$reportKey:1',
      reportKey: reportKey,
      pgn: pgn,
      sourceTitle: 'White vs Black',
      ply: 1,
      moveSan: '1. Kg1?',
      bestMoveSan: 'Kg1',
      classification: 'Mistake',
      summary: 'The only legal move was incorrectly classified.',
      theme: 'Mistake',
      fenBefore: parsed.moves.single.fenBefore,
      fenAfter: parsed.moves.single.fenAfter,
      engineLine: 'Kg1',
      createdAt: now,
      updatedAt: now,
      dueAt: now,
    );
    final preferencesStore = MemoryAppPreferencesStore(
      StoredAppPreferences(
        analysisReports: {
          reportKey: GameAnalysisReportCacheEntry(
            pgn: pgn,
            standardReport: report,
            updatedAt: now,
          ),
        },
        mistakeBook: MistakeBookState(entries: {staleEntry.id: staleEntry}),
      ),
    );
    final store = AppPreferencesMistakeBookStore(preferencesStore);

    final state = await store.read();

    expect(state.entries, isEmpty);
    expect((await preferencesStore.read()).mistakeBook.entries, isEmpty);
  });

  test('bot reports only extract mistakes made by the white-side user', () {
    const pgn = '[Event "Bot game room"]\n'
        '[White "Chessnut Player"]\n'
        '[Black "Maia 1500"]\n'
        '[PlayerSide "White"]\n'
        '[EngineKind "maia"]\n'
        '[Result "*"]\n\n'
        '1. e4 e5 *';
    final parsed = GameNotationService.parsePgn(pgn);
    final report = _botMistakeReport(parsed);

    final entries = MistakeBookExtractor.extractFromStandardReport(
      reportKey: 'pgnhash:bot-white',
      pgn: pgn,
      report: report,
      now: DateTime.utc(2026, 8, 4, 9),
    );

    expect(entries.map((entry) => entry.ply), [1]);
  });

  test('bot reports only extract mistakes made by the black-side user', () {
    const pgn = '[Event "Bot game room"]\n'
        '[White "Maia 1500"]\n'
        '[Black "Chessnut Player"]\n'
        '[PlayerSide "Black"]\n'
        '[EngineKind "maia"]\n'
        '[Result "*"]\n\n'
        '1. e4 e5 *';
    final parsed = GameNotationService.parsePgn(pgn);
    final report = _botMistakeReport(parsed);

    final entries = MistakeBookExtractor.extractFromStandardReport(
      reportKey: 'pgnhash:bot-black',
      pgn: pgn,
      report: report,
      now: DateTime.utc(2026, 8, 4, 9),
    );

    expect(entries.map((entry) => entry.ply), [2]);
  });

  test('Lichess reports only extract mistakes made by the named user', () {
    const pgn = '[Event "Lichess game"]\n'
        '[Site "https://lichess.org/game"]\n'
        '[White "Opponent"]\n'
        '[Black "ChessnutUser"]\n'
        '[LichessName "chessnutuser"]\n'
        '[Result "*"]\n\n'
        '1. e4 e5 *';
    final parsed = GameNotationService.parsePgn(pgn);

    final entries = MistakeBookExtractor.extractFromStandardReport(
      reportKey: 'pgnhash:lichess-user',
      pgn: pgn,
      report: _botMistakeReport(parsed),
      now: DateTime.utc(2026, 8, 4, 9),
    );

    expect(entries.map((entry) => entry.ply), [2]);
  });

  test('Chess.com reports only extract mistakes made by the named user', () {
    const pgn = '[Event "Chess.com WebView Game"]\n'
        '[Site "https://www.chess.com/game"]\n'
        '[White "ChessnutUser"]\n'
        '[Black "Opponent"]\n'
        '[ChessComName "chessnutuser"]\n'
        '[Result "*"]\n\n'
        '1. e4 e5 *';
    final parsed = GameNotationService.parsePgn(pgn);

    final entries = MistakeBookExtractor.extractFromStandardReport(
      reportKey: 'pgnhash:chesscom-user',
      pgn: pgn,
      report: _botMistakeReport(parsed),
      now: DateTime.utc(2026, 8, 4, 9),
    );

    expect(entries.map((entry) => entry.ply), [1]);
  });

  test('online reports without a reliable user side do not create mistakes',
      () {
    const lichessPgn = '[Event "Lichess game"]\n'
        '[Site "https://lichess.org/game"]\n'
        '[White "Player A"]\n'
        '[Black "Player B"]\n'
        '[Result "*"]\n\n'
        '1. e4 e5 *';
    const chessComPgn = '[Event "Chess.com WebView Game"]\n'
        '[Site "https://www.chess.com/game"]\n'
        '[White "Player A"]\n'
        '[Black "Player B"]\n'
        '[Result "*"]\n\n'
        '1. e4 e5 *';

    for (final (key, pgn) in [
      ('lichess', lichessPgn),
      ('chesscom', chessComPgn),
    ]) {
      final parsed = GameNotationService.parsePgn(pgn);
      final entries = MistakeBookExtractor.extractFromStandardReport(
        reportKey: 'pgnhash:$key-unidentified',
        pgn: pgn,
        report: _botMistakeReport(parsed),
        now: DateTime.utc(2026, 8, 4, 9),
      );
      expect(entries, isEmpty, reason: key);
    }
  });

  test('store upserts extracted mistakes and schedules review attempts',
      () async {
    const pgn = '[Event "Mistake Store"]\n\n'
        '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *';
    final parsed = GameNotationService.parsePgn(pgn);
    final report = GameStandardAnalysisReport(
      generatedAt: DateTime.utc(2026, 5, 30, 10),
      stockfishBacked: true,
      stockfishStatus: 'Report ready',
      moves: [
        CachedReviewMove(
          ply: 5,
          move: '3. Bb5?',
          evalBefore: 0.3,
          evalAfter: -1.2,
          classification: 'Blunder',
          summary: 'A tactical resource was missed.',
          fen: parsed.moves[4].fenAfter,
          lastMove: const ['f1', 'b5'],
          focusSquare: 'b5',
          engineLine: 'Bc4 Nf6',
          bestMove: 'Best: Bc4',
          keyMoment: true,
        ),
      ],
    );
    final preferencesStore = MemoryAppPreferencesStore(
      StoredAppPreferences(
        analysisReports: {
          'pgnhash:test': GameAnalysisReportCacheEntry(
            pgn: pgn,
            standardReport: report,
            updatedAt: DateTime.utc(2026, 5, 30, 10),
          ),
        },
      ),
    );
    final store = AppPreferencesMistakeBookStore(preferencesStore);

    await store.syncFromAnalysisReports(
      (await preferencesStore.read()).analysisReports,
      now: DateTime.utc(2026, 5, 30, 12),
    );
    var state = await store.read();
    expect(state.entries, hasLength(1));
    expect(state.due(DateTime.utc(2026, 5, 30, 13)), hasLength(1));

    final id = state.entries.values.single.id;
    await store.recordReview(
      id,
      correct: true,
      now: DateTime.utc(2026, 5, 30, 13),
    );
    state = await store.read();
    expect(state.entries[id]?.correctStreak, 1);
    expect(state.entries[id]?.dueAt, DateTime.utc(2026, 6, 2, 13));

    await store.recordReview(
      id,
      correct: false,
      now: DateTime.utc(2026, 5, 31, 9),
    );
    state = await store.read();
    expect(state.entries[id]?.correctStreak, 0);
    expect(state.entries[id]?.dueAt, DateTime.utc(2026, 6, 1, 9));

    await store.setMastered(
      id,
      mastered: true,
      now: DateTime.utc(2026, 5, 31, 10),
    );
    state = await store.read();
    expect(state.entries[id]?.mastered, isTrue);
    expect(state.due(DateTime.utc(2026, 6, 2)), isEmpty);

    await store.setMastered(
      id,
      mastered: false,
      now: DateTime.utc(2026, 5, 31, 11),
    );
    state = await store.read();
    expect(state.entries[id]?.mastered, isFalse);
    expect(state.due(DateTime.utc(2026, 6, 2)), hasLength(1));

    await store.delete(id);
    state = await store.read();
    expect(state.entries, isEmpty);
    expect(state.deletedIds, contains(id));
    await store.syncFromAnalysisReports(
      (await preferencesStore.read()).analysisReports,
      now: DateTime.utc(2026, 6, 3),
    );
    expect((await store.read()).entries, isEmpty);
  });

  test('analysis report cache writes standard report into mistake book',
      () async {
    const pgn = '[Event "Cache Sync"]\n\n'
        '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *';
    final parsed = GameNotationService.parsePgn(pgn);
    final preferencesStore = MemoryAppPreferencesStore();
    final cacheStore = AppPreferencesAnalysisReportCacheStore(preferencesStore);

    await cacheStore.writeStandard(
      'pgnhash:cache-sync',
      pgn,
      GameStandardAnalysisReport(
        generatedAt: DateTime.utc(2026, 5, 30, 10),
        stockfishBacked: true,
        stockfishStatus: 'Report ready',
        moves: [
          CachedReviewMove(
            ply: 5,
            move: '3. Bb5?',
            evalBefore: 0.3,
            evalAfter: -1.2,
            classification: 'Mistake',
            summary: 'This missed a cleaner developing move.',
            fen: parsed.moves[4].fenAfter,
            lastMove: const ['f1', 'b5'],
            focusSquare: 'b5',
            engineLine: 'Bc4 Nf6',
            bestMove: 'Best: Bc4',
            keyMoment: true,
          ),
        ],
      ),
    );

    final preferences = await preferencesStore.read();

    expect(
        preferences.analysisReports['pgnhash:cache-sync']?.hasStandard, isTrue);
    expect(preferences.mistakeBook.entries, hasLength(1));
    expect(preferences.mistakeBook.entries.values.single.moveSan, '3. Bb5?');
  });

  test('batch deletion removes all entries and preserves deletion markers',
      () async {
    final now = DateTime.utc(2026, 9, 9);
    final entries = <String, MistakeBookEntry>{
      for (final id in ['one', 'two', 'three'])
        id: MistakeBookEntry(
          id: id,
          reportKey: 'report-$id',
          pgn: '[Event "Batch deletion"]\n\n1. e4 *',
          sourceTitle: 'Player vs Bot',
          ply: 1,
          moveSan: 'e4?',
          bestMoveSan: 'd4',
          classification: 'Mistake',
          summary: 'Saved mistake.',
          theme: 'Development',
          fenBefore: 'startpos',
          fenAfter: 'startpos',
          engineLine: 'd4 d5',
          createdAt: now,
          updatedAt: now,
          dueAt: now,
        ),
    };
    final preferencesStore = MemoryAppPreferencesStore(
      StoredAppPreferences(mistakeBook: MistakeBookState(entries: entries)),
    );
    final store = AppPreferencesMistakeBookStore(preferencesStore);

    await store.deleteMany(entries.keys.toSet());

    final state = await store.read();
    expect(state.entries, isEmpty);
    expect(state.deletedIds, containsAll(entries.keys));
  });

  test('store read rebuilds missing mistake book from saved reports', () async {
    const pgn = '[Event "Mistake Rebuild"]\n\n'
        '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *';
    final parsed = GameNotationService.parsePgn(pgn);
    final preferencesStore = MemoryAppPreferencesStore(
      StoredAppPreferences(
        analysisReports: {
          'pgnhash:rebuild': GameAnalysisReportCacheEntry(
            pgn: pgn,
            standardReport: GameStandardAnalysisReport(
              generatedAt: DateTime.utc(2026, 7, 1, 8),
              stockfishBacked: true,
              stockfishStatus: 'Report ready',
              moves: [
                CachedReviewMove(
                  ply: 5,
                  move: '3. Bb5?',
                  evalBefore: 0.3,
                  evalAfter: -1.2,
                  classification: 'Mistake',
                  summary: 'This missed a cleaner developing move.',
                  fen: parsed.moves[4].fenAfter,
                  lastMove: const ['f1', 'b5'],
                  focusSquare: 'b5',
                  engineLine: 'Bc4 Nf6',
                  bestMove: 'Best: Bc4',
                  keyMoment: true,
                ),
              ],
            ),
          ),
        },
      ),
    );
    final store = AppPreferencesMistakeBookStore(preferencesStore);

    final state = await store.read();
    final persisted = await preferencesStore.read();

    expect(state.entries, hasLength(1));
    expect(state.entries.values.single.moveSan, '3. Bb5?');
    expect(persisted.mistakeBook.entries, hasLength(1));
  });
}

GameStandardAnalysisReport _botMistakeReport(ParsedPgnGame parsed) {
  return GameStandardAnalysisReport(
    generatedAt: DateTime.utc(2026, 8, 4, 8),
    stockfishBacked: true,
    stockfishStatus: 'Report ready',
    moves: [
      for (final parsedMove in parsed.moves)
        CachedReviewMove(
          ply: parsedMove.ply,
          move: parsedMove.san,
          evalBefore: 0,
          evalAfter: -1,
          classification: 'Mistake',
          summary: 'A mistake in a bot game.',
          fen: parsedMove.fenAfter,
          lastMove: parsedMove.lastMove,
          focusSquare: parsedMove.lastMove.last,
          engineLine: parsedMove.san,
          bestMove: parsedMove.ply == 1 ? 'Best: d4' : 'Best: c5',
          keyMoment: true,
        ),
    ],
  );
}
