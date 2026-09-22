import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

import 'package:chessnut_flutter_export/l10n/app_language.dart';
import 'package:chessnut_flutter_export/l10n/app_strings.dart';
import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/screens/game_record_screen.dart';
import 'package:chessnut_flutter_export/services/game_record_filter.dart';
import 'package:chessnut_flutter_export/services/analysis_report_cache_service.dart';
import 'package:chessnut_flutter_export/services/app_preferences_store.dart';
import 'package:chessnut_flutter_export/services/chessnut_api_client.dart';
import 'package:chessnut_flutter_export/services/game_record_repository.dart';
import 'package:chessnut_flutter_export/theme/chessnut_theme.dart';
import 'package:chessnut_flutter_export/widgets/chess_board.dart';

void main() {
  test('game record status recognizes versioned Maia3 review cache', () {
    const pgn = '[Event "Maia3"]\n[Result "*"]\n\n1. e4 *';
    const record = GameRecord(
      result: '*',
      title: 'Maia3',
      subtitle: 'Analysis',
      pgn: pgn,
      playMode: 'analysis',
    );
    final key = gameAnalysisReportCacheKeyForPgn(pgn);
    final status = gameAnalysisReportStatusForRecord(record, {
      maia3HumanReviewCacheKey(key): const GameAnalysisReportStatus(
        maia3: true,
      ),
    });

    expect(status.maia3, isTrue);
  });

  testWidgets('game records refresh automatically while page is open',
      (tester) async {
    var refreshCount = 0;
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        onAutoRefreshCurrentPage: () async => refreshCount += 1,
      ),
    );
    await tester.pump();
    expect(refreshCount, 1);

    await tester.pump(const Duration(seconds: 10));
    expect(refreshCount, 2);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    expect(refreshCount, 2);
  });

  test('record review opens the cache entry with the completed Grandeur report',
      () {
    const pgn = '[White "Cache White"]\n'
        '[Black "Cache Black"]\n'
        '[Result "1-0"]\n\n'
        '1. e4 e5 1-0';
    const record = GameRecord(
      pgnId: 42,
      shareId: 'shared-42',
      result: '1-0',
      title: 'Cache White vs Cache Black',
      subtitle: 'Bot',
      pgn: pgn,
      hasGrandeurReport: true,
    );
    final pgnHashKey = gameAnalysisReportCacheKeyForPgn(pgn);
    final selected = gameAnalysisReportCacheKeyWithBestReport(record, {
      'pgn:42': GameAnalysisReportCacheEntry(
        pgn: pgn,
        standardReport: GameStandardAnalysisReport(
          moves: const [],
          stockfishBacked: true,
          stockfishStatus: 'Report ready',
          generatedAt: DateTime(2026, 7, 16),
        ),
      ),
      'share:shared-42': const GameAnalysisReportCacheEntry(
        pgn: pgn,
        grandeurUnlocked: true,
        grandeurCommentId: 91,
      ),
      pgnHashKey: const GameAnalysisReportCacheEntry(
        pgn: pgn,
        grandeurReport: GrandeurAnalysisResult(
          analysisId: 'complete-42',
          moves: [],
        ),
      ),
    });

    expect(selected, pgnHashKey);
  });

  test('bound Grandeur job marks its game record as having commentary', () {
    const pgn = '[Result "1-0"]\n\n1. e4 e5 1-0';
    const record = GameRecord(
      pgnId: 43,
      result: '1-0',
      title: 'Pending vs Report',
      subtitle: 'Bot',
      pgn: pgn,
      commentId: 92,
    );
    final status = gameAnalysisReportStatusForRecord(record, const {});

    expect(status.grandeur, isTrue);
    expect(status.grandeurReady, isTrue);

    const pendingCache = GameAnalysisReportCacheEntry(
      pgn: pgn,
      grandeurUnlocked: true,
      grandeurCommentId: 92,
    );
    expect(pendingCache.status.grandeur, isTrue);
    expect(pendingCache.status.grandeurReady, isFalse);
  });

  test('record Grandeur status ignores matching PGN cache without binding', () {
    const pgn = '[Result "1-0"]\n\n1. e4 e5 1-0';
    const record = GameRecord(
      pgnId: 44,
      result: '1-0',
      title: 'Unbound vs Report',
      subtitle: 'Bot',
      pgn: pgn,
    );
    final status = gameAnalysisReportStatusForRecord(record, {
      gameAnalysisReportCacheKeyForPgn(pgn):
          const GameAnalysisReportStatus(grandeur: true),
    });

    expect(status.grandeur, isFalse);
    expect(status.grandeurReady, isFalse);
  });

  test('analysis report cache persists PGN for local game records', () async {
    const pgn = '[White "Cache White"]\n'
        '[Black "Cache Black"]\n'
        '[Result "1-0"]\n\n'
        '1. e4 e5 1-0';
    final store = MemoryAppPreferencesStore();
    final cacheStore = AppPreferencesAnalysisReportCacheStore(store);
    final key = gameAnalysisReportCacheKeyForPgn(pgn);

    await cacheStore.writeStandard(
      key,
      pgn,
      GameStandardAnalysisReport(
        moves: const [],
        stockfishBacked: true,
        stockfishStatus: 'Report ready',
        generatedAt: DateTime(2026, 5, 27),
      ),
    );
    await cacheStore.writeGrandeur(
      key,
      pgn,
      const GrandeurAnalysisResult(analysisId: 'g-cache', moves: []),
    );

    final preferences = await store.read();
    expect(preferences.analysisReports[key]?.pgn, pgn);
    final records = gameAnalysisRecordsFromCache(preferences.analysisReports);
    expect(records.single.title, 'Cache White vs Cache Black');
    expect(records.single.shareId, isNull);
    expect((await cacheStore.readStatuses())[key]?.grandeur, isTrue);
  });

  test('analysis report cache preserves Grandeur backend summary', () async {
    const pgn = '[White "Summary White"]\n'
        '[Black "Summary Black"]\n'
        '[Result "1-0"]\n\n'
        '1. e4 e5 1-0';
    final store = MemoryAppPreferencesStore();
    final cacheStore = AppPreferencesAnalysisReportCacheStore(store);
    final key = gameAnalysisReportCacheKeyForPgn(pgn);

    await cacheStore.writeGrandeur(
      key,
      pgn,
      const GrandeurAnalysisResult(
        analysisId: 'g-summary',
        summary: ['Backend summary survives cache reload.'],
        moves: <GrandeurMoveExplanation>[],
      ),
    );

    final encoded = (await store.read()).toJson();
    final restored = StoredAppPreferences.fromJson(encoded);

    expect(
      restored.analysisReports[key]?.grandeurReport?.summaryText,
      'Backend summary survives cache reload.',
    );
  });

  test('Grandeur cache serialization omits embedded audio', () {
    const report = GrandeurAnalysisResult(
      analysisId: 'g-commentary-only',
      language: 'it',
      moves: <GrandeurMoveExplanation>[
        GrandeurMoveExplanation(
          ply: 1,
          san: 'e4',
          tag: 'Best',
          commentary: 'White claims space in the center.',
          language: 'it',
        ),
      ],
    );

    final encoded = grandeurAnalysisResultToJson(report);
    final move =
        (encoded['moves'] as List<dynamic>).single as Map<String, dynamic>;

    expect(move['commentary'], 'White claims space in the center.');
    expect(encoded['language'], 'it');
    expect(move['language'], 'it');
    expect(move, isNot(contains('audio_base64')));
  });

  test('analysis PGN cache appears as a local record before reports finish',
      () async {
    const pgn = '[White "Draft White"]\n'
        '[Black "Draft Black"]\n'
        '[Result "*"]\n\n'
        '1. e4 e5 2. Nf3 Nc6 *';
    final key = gameAnalysisReportCacheKeyForPgn(pgn);

    final records = gameAnalysisRecordsFromCache({
      key: const GameAnalysisReportCacheEntry(pgn: pgn),
    });

    expect(records, hasLength(1));
    expect(records.single.title, 'Draft White vs Draft Black');
    expect(records.single.playMode, 'analysis');
    expect(records.single.result, '*');
    expect(records.single.pgn, pgn);
  });

  testWidgets('shows login prompt before user signs in', (tester) async {
    await tester.pumpWidget(_recordHarness(signedIn: false));

    expect(find.text('Sign in to view records'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('shows empty record state after login without backend data',
      (tester) async {
    await tester.pumpWidget(_recordHarness(signedIn: true));

    expect(find.text('No games yet'), findsOneWidget);
    expect(find.text('Start a game'), findsOneWidget);
  });

  testWidgets('offers PGN import from the compact import menu', (tester) async {
    var importCalls = 0;
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        onImportPgnFile: () => importCalls += 1,
      ),
    );

    expect(find.byKey(const ValueKey('game-record-import-pgn')), findsNothing);

    await _expandRecordFilters(tester);
    await tester.tap(find.byKey(const ValueKey('game-record-import-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-record-import-pgn-menu')));
    await tester.pumpAndSettle();

    expect(importCalls, 1);
  });

  testWidgets('separates local, Lichess, and Chess.com game records',
      (tester) async {
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: [
          _sampleRecord(1, 'Local Player', 'Maia', 'bot', 'rapid'),
          _sampleRecord(2, 'Lichess Player', 'nightbishop', 'lichess', 'blitz'),
          _sampleRecord(
              3, 'ChessCom Player', 'daily_opponent', 'chesscom', 'rapid'),
          const GameRecord(
            pgnId: 4,
            result: '1-0',
            title: 'Imported White vs Imported Black',
            subtitle: 'Analysis / 12 moves',
            pgn:
                '[White "Imported White"]\n[Black "Imported Black"]\n\n1. e4 e5 1-0',
            playMode: 'analysis',
            gameStatus: 2,
            gameStep: 12,
          ),
        ],
      ),
    );

    expect(
        find.byKey(const ValueKey('game-record-source-local')), findsOneWidget);
    expect(find.text('Chessnut'), findsOneWidget);
    expect(find.text('Local'), findsNothing);
    expect(find.byKey(const ValueKey('game-record-source-lichess')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('game-record-source-chesscom')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('game-record-source-local')));
    await tester.pumpAndSettle();
    expect(find.text('White: Local Player / Black: Maia'), findsOneWidget);
    expect(find.text('White: Imported White / Black: Imported Black'),
        findsOneWidget);
    expect(
        find.text('White: Lichess Player / Black: nightbishop'), findsNothing);
    expect(find.text('White: ChessCom Player / Black: daily_opponent'),
        findsNothing);

    await tester.tap(find.byKey(const ValueKey('game-record-source-lichess')));
    await tester.pumpAndSettle();
    expect(find.text('White: Lichess Player / Black: nightbishop'),
        findsOneWidget);
    expect(find.text('White: Local Player / Black: Maia'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('game-record-source-chesscom')));
    await tester.pumpAndSettle();
    expect(find.text('White: ChessCom Player / Black: daily_opponent'),
        findsOneWidget);
    expect(find.text('White: Imported White / Black: Imported Black'),
        findsNothing);
  });

  testWidgets('offers Chess.com history import from the compact import menu',
      (tester) async {
    LichessHistoryImportOptions? importedOptions;
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        onStartChessComHistoryImport: (options) async {
          importedOptions = options;
          return const ApiResult(
            ApiStatus.success(),
            data: LichessImportJob(
              jobId: 'cc_job',
              playerId: 'hikaru',
              status: 'queued',
              maxGames: 50,
              inserted: 0,
              skipped: 0,
              failed: 0,
              processed: 0,
              total: 0,
              progressPercent: 0,
            ),
          );
        },
      ),
    );

    await _expandRecordFilters(tester);
    await tester.tap(find.byKey(const ValueKey('game-record-import-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-record-import-chesscom')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('chesscom-import-player-id')),
      'hikaru',
    );
    await tester.enterText(
      find.byKey(const ValueKey('chesscom-import-max-games')),
      '50',
    );
    await tester.tap(find.text('Start import'));
    await tester.pumpAndSettle();

    expect(importedOptions?.playerId, 'hikaru');
    expect(importedOptions?.maxGames, 50);
  });

  testWidgets('fetches games in the app and imports only selected PGNs',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const firstPgn = '''[Event "First"]
[Date "2026.08.17"]
[White "Alice"]
[Black "Bob"]
[Result "1-0"]

1. e4 e5 1-0''';
    const secondPgn = '''[Event "Second"]
[Date "2026.08.16"]
[White "Carol"]
[Black "Dave"]
[Result "0-1"]

1. d4 d5 0-1''';
    String? submittedPgn;
    String? submittedSource;
    LichessHistoryImportOptions? fetchedOptions;

    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        onFetchLichessGames: (options) async {
          fetchedOptions = options;
          return const [firstPgn, secondPgn];
        },
        onImportHistoryPgnBatch: (pgnList, source) async {
          submittedPgn = pgnList;
          submittedSource = source;
          return const ApiResult(ApiStatus.success(), data: 1);
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey('game-record-import-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-record-import-lichess')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('lichess-import-player-id')),
      'alice',
    );
    final playerFocusNode =
        tester.widget<EditableText>(find.byType(EditableText).first).focusNode;
    expect(playerFocusNode.hasFocus, isTrue);
    await tester.tap(find.text('Fetch games'));
    await tester.pumpAndSettle();

    expect(playerFocusNode.hasFocus, isFalse);
    expect(fetchedOptions?.maxGames, 500);
    expect(find.text('Selected 2 of 2'), findsOneWidget);
    final firstPreviewBoard = find.descendant(
      of: find.byKey(const ValueKey('history-import-game-0')),
      matching: find.byType(ChessBoard),
    );
    expect(firstPreviewBoard, findsOneWidget);
    final previewPieces = tester.widget<ChessBoard>(firstPreviewBoard).pieces;
    expect(
      previewPieces.any((piece) => piece.square == 'e4' && piece.code == 'wp'),
      isTrue,
    );
    expect(
      previewPieces.any((piece) => piece.square == 'e5' && piece.code == 'bp'),
      isTrue,
    );
    expect(
      tester
          .widget<Checkbox>(
            find.descendant(
              of: find.byKey(const ValueKey('history-import-game-0')),
              matching: find.byType(Checkbox),
            ),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<Checkbox>(
            find.descendant(
              of: find.byKey(const ValueKey('history-import-game-1')),
              matching: find.byType(Checkbox),
            ),
          )
          .value,
      isTrue,
    );
    expect(find.text('White: Alice / Black: Bob'), findsOneWidget);
    expect(find.text('Lichess / Time: Unknown'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('history-import-game-1')));
    await tester.pump();
    await tester.tap(find.text('Import selected games'));
    await tester.pumpAndSettle();

    expect(submittedSource, 'lichess');
    expect(submittedPgn, contains('[Event "First"]'));
    expect(submittedPgn, isNot(contains('[Event "Second"]')));
    expect(find.text('Imported 1 games.'), findsOneWidget);
  });

  testWidgets(
      'keeps game record history tools inside filters on compact screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: [
          _sampleRecord(
              1, 'Chessnut Player', 'Compact Opponent', 'bot', 'rapid'),
        ],
        onSearchRemoteRecords: (_, __, ___) async =>
            const GameRecordRemoteSearchResult(
          status: ApiStatus.success(),
          records: [],
          page: 1,
          count: 10,
          total: 0,
          totalPage: 1,
        ),
        onStartLichessHistoryImport: (_) async => const ApiResult(
          ApiStatus.success(),
          data: LichessImportJob(
            jobId: 'layout',
            playerId: 'tester',
            status: 'queued',
            maxGames: 20,
            inserted: 0,
            skipped: 0,
            failed: 0,
            processed: 0,
            total: 0,
            progressPercent: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final importHeaderSize = tester.getSize(
      find.byKey(const ValueKey('game-record-import-menu')),
    );
    expect(importHeaderSize, const Size.square(44));
    expect(find.byKey(const ValueKey('game-record-refresh')), findsNothing);

    final sourceRect = tester.getRect(
      find.byKey(const ValueKey('game-record-source-tabs')),
    );
    final filterRect = tester.getRect(
      find.byKey(const ValueKey('game-record-filter-panel')),
    );
    expect(sourceRect.height, lessThanOrEqualTo(64));
    expect(filterRect.height, lessThanOrEqualTo(54));
    expect(
      find.byKey(const ValueKey('game-record-model-build-bar')),
      findsNothing,
    );
    for (final key in [
      'game-record-source-all',
      'game-record-source-local',
      'game-record-source-lichess',
      'game-record-source-chesscom',
    ]) {
      final rect = tester.getRect(find.byKey(ValueKey(key)));
      expect(rect.left, greaterThanOrEqualTo(sourceRect.left));
      expect(rect.right, lessThanOrEqualTo(sourceRect.right));
    }
    expect(find.text('Chess.com'), findsOneWidget);
    expect(find.text('History'), findsNothing);
    expect(find.text('Import'), findsNothing);
    expect(find.text('Filters'), findsWidgets);
    expect(find.text('Select visible (1)'), findsNothing);
    expect(find.text('Select records to delete'), findsNothing);
    expect(find.byKey(const ValueKey('game-record-select-mode')), findsNothing);
    expect(find.text('Clear'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('game-record-filter-toggle')));
    await tester.pumpAndSettle();

    final importMenuSize = tester.getSize(
      find.byKey(const ValueKey('game-record-import-menu')),
    );
    final historyRect =
        tester.getRect(find.byKey(const ValueKey('game-record-search-all')));
    final searchFieldRect = tester.getRect(find.byType(TextField).first);
    final expandedFilterRect = tester.getRect(
      find.byKey(const ValueKey('game-record-filter-panel')),
    );
    expect(historyRect.width, lessThanOrEqualTo(144));
    expect(historyRect.bottom, lessThan(searchFieldRect.top));
    expect(importMenuSize.width, const Size.square(44).width);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Import'), findsNothing);
    for (final key in [
      'game-record-search-all',
    ]) {
      final rect = tester.getRect(find.byKey(ValueKey(key)));
      expect(rect.left, greaterThanOrEqualTo(expandedFilterRect.left));
      expect(rect.right, lessThanOrEqualTo(expandedFilterRect.right));
    }
  });

  testWidgets('Android portrait keeps expanded filter title on one line',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        _recordHarness(
          signedIn: true,
          records: [
            _sampleRecord(
                1, 'Chessnut Player', 'Compact Opponent', 'bot', 'rapid'),
          ],
          onSearchRemoteRecords: (_, __, count) async =>
              GameRecordRemoteSearchResult(
            status: const ApiStatus.success(),
            records: [
              _sampleRecord(
                  2, 'Remote Player', 'Remote Opponent', 'bot', 'rapid'),
            ],
            page: 1,
            count: count,
            total: 40,
            totalPage: 4,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('game-record-filter-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('game-record-search-all')));
      await tester.pumpAndSettle();

      final titleFinder =
          find.byKey(const ValueKey('game-record-filter-title'));
      final title = tester.renderObject<RenderParagraph>(titleFinder);
      final titleRect = tester.getRect(titleFinder);
      final searchRect =
          tester.getRect(find.byKey(const ValueKey('game-record-search-all')));

      expect(title.didExceedMaxLines, isFalse);
      expect(titleRect.height, lessThanOrEqualTo(24));
      expect(searchRect.top, greaterThan(titleRect.bottom));
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Local list'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('renders backend records when available', (tester) async {
    GameRecord? analyzedRecord;
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: [
          GameRecord(
            result: '1-0',
            title: 'Alice vs Bob',
            subtitle: 'Lichess Rapid / 32 moves',
            pgn: '[White "Alice"]\n'
                '[Black "Bob"]\n'
                '[Result "1-0"]\n'
                '[Date "2026.06.18"]\n'
                '[Site "Shanghai"]\n'
                '[TimeControl "5+3"]\n\n'
                '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 1-0',
            whiteName: 'Alice',
            blackName: 'Bob',
            sortAt: DateTime(2026, 6, 18, 9, 30),
            gameStatus: 2,
            winId: 1,
          ),
        ],
        onAnalyzeRecord: (record) => analyzedRecord = record,
      ),
    );

    expect(find.text('White: Alice / Black: Bob'), findsOneWidget);
    expect(find.text('Lichess Rapid / Time: 5+3'), findsOneWidget);
    expect(find.text('Date: 2026-06-18'), findsOneWidget);
    expect(find.text('Location: Shanghai'), findsOneWidget);
    expect(find.text('Result: Alice wins'), findsOneWidget);
    expect(find.text('No games yet'), findsNothing);

    await _scrollRecordListIntoView(tester);
    final recordTitle = find.text('White: Alice / Black: Bob');
    await tester.tap(recordTitle);
    await tester.pumpAndSettle();

    expect(analyzedRecord?.pgn, contains('3. Bb5'));
  });

  testWidgets('Chess.com record time display uses PGN speed', (tester) async {
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: const [
          GameRecord(
            result: '1-0',
            title: 'Alice vs Bob',
            subtitle: 'Chess.com / 2 moves',
            playMode: 'chesscom',
            pgn: '[Event "Live Chess"]\n'
                '[Site "https://www.chess.com/game/live/123"]\n'
                '[White "Alice"]\n'
                '[Black "Bob"]\n'
                '[Result "1-0"]\n'
                '[Speed "Blitz"]\n'
                '[TimeControl "300+0"]\n\n'
                '1. e4 e5 1-0',
            whiteName: 'Alice',
            blackName: 'Bob',
            gameStatus: 2,
            winId: 1,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('White: Alice / Black: Bob'), findsOneWidget);
    expect(find.textContaining('Time: Blitz'), findsOneWidget);
    expect(find.textContaining('Time: 300+0'), findsNothing);
  });

  testWidgets('Rapid filter includes 10 and 10+5 time controls',
      (tester) async {
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: const [
          GameRecord(
            result: '1-0',
            title: 'Rapid Ten vs Opponent',
            subtitle: 'Chess.com / 2 moves',
            playMode: 'chesscom',
            pgn: '[Site "https://www.chess.com/game/live/10"]\n'
                '[White "Rapid Ten"]\n'
                '[Black "Opponent"]\n'
                '[Result "1-0"]\n'
                '[TimeControl "10"]\n\n'
                '1. e4 e5 1-0',
            whiteName: 'Rapid Ten',
            blackName: 'Opponent',
            gameStatus: 2,
            winId: 1,
          ),
          GameRecord(
            result: '1-0',
            title: 'Rapid Inc vs Opponent',
            subtitle: 'Chess.com / 2 moves',
            playMode: 'chesscom',
            pgn: '[Site "https://www.chess.com/game/live/10-5"]\n'
                '[White "Rapid Inc"]\n'
                '[Black "Opponent"]\n'
                '[Result "1-0"]\n'
                '[TimeControl "10+5"]\n\n'
                '1. d4 d5 1-0',
            whiteName: 'Rapid Inc',
            blackName: 'Opponent',
            gameStatus: 2,
            winId: 1,
          ),
          GameRecord(
            result: '1-0',
            title: 'Blitz Five vs Opponent',
            subtitle: 'Chess.com / 2 moves',
            playMode: 'chesscom',
            pgn: '[Site "https://www.chess.com/game/live/5"]\n'
                '[White "Blitz Five"]\n'
                '[Black "Opponent"]\n'
                '[Result "1-0"]\n'
                '[TimeControl "5+0"]\n\n'
                '1. c4 e5 1-0',
            whiteName: 'Blitz Five',
            blackName: 'Opponent',
            gameStatus: 2,
            winId: 1,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _expandRecordFilters(tester);
    await _chooseRecordFilter<RecordSpeedFilter>(
      tester,
      const ValueKey('game-record-filter-speed'),
      'Rapid',
    );

    expect(find.text('White: Rapid Ten / Black: Opponent'), findsOneWidget);
    expect(find.text('White: Rapid Inc / Black: Opponent'), findsOneWidget);
    expect(find.text('White: Blitz Five / Black: Opponent'), findsNothing);
  });

  testWidgets('record text follows the selected Chinese language', (
    tester,
  ) async {
    await tester.pumpWidget(
      _recordHarness(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        signedIn: true,
        records: [
          GameRecord(
            result: '1-0',
            title: 'Alice vs Bob',
            subtitle: 'Lichess Rapid / 32 moves',
            pgn: '[White "Alice"]\n'
                '[Black "Bob"]\n'
                '[Result "1-0"]\n'
                '[Date "2026.06.18"]\n'
                '[Site "Shanghai"]\n'
                '[TimeControl "5+3"]\n\n'
                '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 1-0',
            whiteName: 'Alice',
            blackName: 'Bob',
            sortAt: DateTime(2026, 6, 18, 9, 30),
            gameStatus: 2,
            winId: 1,
          ),
          const GameRecord(
            result: '1/2-1/2',
            title: 'Carol vs Dana',
            subtitle: 'Bot / 12 moves',
            pgn: '[White "Carol"]\n'
                '[Black "Dana"]\n'
                '[Result "1/2-1/2"]\n'
                '[TimeControl "10+5"]\n\n'
                '1. e4 e5 1/2-1/2',
            playMode: 'bot',
            whiteName: 'Carol',
            blackName: 'Dana',
            gameStatus: 2,
            winId: 3,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('白方: Alice / 黑方: Bob'), findsOneWidget);
    expect(find.text('Lichess 快棋 / 时间: 5+3'), findsOneWidget);
    expect(find.text('日期: 2026-06-18'), findsOneWidget);
    expect(find.text('地点: Shanghai'), findsOneWidget);
    expect(find.text('结果: Alice 获胜'), findsOneWidget);
    expect(find.text('白方: Carol / 黑方: Dana'), findsOneWidget);
    expect(find.text('电脑 / 时间: 10+5'), findsOneWidget);
    expect(find.text('地点: 未知'), findsOneWidget);
    expect(find.text('结果: 平局'), findsOneWidget);
    expect(find.text('White: Alice / Black: Bob'), findsNothing);
    expect(find.text('Result: Alice wins'), findsNothing);

    await _expandRecordFilters(tester);
    expect(find.text('全部'), findsWidgets);
    expect(find.text('任意速度'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('game-record-filter-result')));
    await tester.pumpAndSettle();
    expect(find.text('胜'), findsOneWidget);
    expect(find.text('负'), findsOneWidget);
  });

  testWidgets('record date and unknown location fit clock landscape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: [
          GameRecord(
            result: '1-0',
            title: 'Clock Player vs Maia',
            subtitle: 'Bot / 18 moves',
            pgn: '[White "Clock Player"]\n'
                '[Black "Maia"]\n'
                '[Result "1-0"]\n'
                '[Site "Chessnut Clock Tournament Hall East Wing"]\n'
                '[TimeControl "10+5"]\n\n'
                '1. e4 e5 1-0',
            whiteName: 'Clock Player',
            blackName: 'Maia',
            sortAt: DateTime(2026, 6, 18, 16, 30),
            gameStatus: 2,
            winId: 1,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Date: 2026-06-18'), findsOneWidget);
    const fullLocation = 'Location: Chessnut Clock Tournament Hall East Wing';
    expect(find.text(fullLocation), findsOneWidget);
    final dateRect = tester.getRect(find.text('Date: 2026-06-18'));
    final locationRect = tester.getRect(find.text(fullLocation));
    expect(dateRect.right, lessThanOrEqualTo(1280));
    expect(locationRect.right, lessThanOrEqualTo(1280));
    expect(dateRect.bottom, lessThanOrEqualTo(480));
    expect(locationRect.bottom, lessThanOrEqualTo(480));
  });

  testWidgets('shows continue action for unfinished bot records', (
    tester,
  ) async {
    GameRecord? continuedRecord;
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: const [
          GameRecord(
            pgnId: 333,
            shareId: 'live-bot-share',
            result: '*',
            title: 'Chessnut Player vs Maia 1500',
            subtitle: 'Bot / 2 moves',
            pgn: '[Event "Bot game room"]\n\n1. e4 Nf6 *',
            playMode: 'bot',
            gameStatus: 1,
            gameStep: 2,
            winId: 0,
          ),
        ],
        onContinueRecord: (record) => continuedRecord = record,
      ),
    );

    expect(find.text('Continue'), findsOneWidget);

    await _scrollRecordListIntoView(tester);
    final continueButton = find.text('Continue');
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(continuedRecord?.pgnId, 333);
    expect(continuedRecord?.shareId, 'live-bot-share');
  });

  testWidgets('shows continue action for unfinished lichess records', (
    tester,
  ) async {
    GameRecord? continuedRecord;
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: const [
          GameRecord(
            pgnId: 444,
            shareId: 'live-lichess-share',
            result: '*',
            title: 'ChessnutPlayer vs nightbishop',
            subtitle: 'Lichess / 2 moves',
            pgn: '[Event "Native game room"]\n'
                '[LichessGameId "lichess-game-1"]\n'
                '[Result "*"]\n\n'
                '1. e4 e5 *',
            playMode: 'lichess',
            gameStatus: 1,
            gameStep: 2,
            winId: 0,
          ),
        ],
        onContinueRecord: (record) => continuedRecord = record,
      ),
    );

    expect(find.text('Continue'), findsOneWidget);

    await _scrollRecordListIntoView(tester);
    final continueButton = find.text('Continue');
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(continuedRecord?.pgnId, 444);
    expect(continuedRecord?.shareId, 'live-lichess-share');
  });

  testWidgets(
      'portrait phones hide the outside continue button but keep the menu action',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    GameRecord? continuedRecord;
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: const [
          GameRecord(
            pgnId: 445,
            result: '*',
            title: 'Chessnut Player vs Maia 1500',
            subtitle: 'Bot / 2 moves',
            pgn: '[Event "Bot game room"]\n\n1. e4 Nf6 *',
            playMode: 'bot',
            gameStatus: 1,
            gameStep: 2,
            winId: 0,
          ),
        ],
        onContinueRecord: (record) => continuedRecord = record,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('game-record-continue')),
      findsNothing,
    );
    expect(find.text('Continue'), findsNothing);

    await _scrollRecordListIntoView(tester);
    await tester.tap(find.byKey(const ValueKey('game-record-more-pgn:445')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('game-record-context-menu')), findsOne);
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(continuedRecord?.pgnId, 445);
  });

  testWidgets('record context menu can refresh a remotely loaded PGN',
      (tester) async {
    GameRecord? refreshed;
    const record = GameRecord(
      pgnId: 447,
      result: '1-0',
      title: 'White vs Black',
      subtitle: 'OTB / 2 moves',
      pgn: '[Result "1-0"]\n\n1. e4 e5 1-0',
      pgnSource: 'https://records.test/447.pgn',
      playMode: 'otb',
      gameStatus: 2,
      gameStep: 2,
      winId: 1,
    );
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: const [record],
        onRefreshRecordPgn: (value) async {
          refreshed = value;
          return const ApiResult(
            ApiStatus.success(),
            data: record,
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await _scrollRecordListIntoView(tester);
    await tester.tap(find.byKey(const ValueKey('game-record-more-pgn:447')));
    await tester.pumpAndSettle();
    expect(find.text('Refresh PGN'), findsOneWidget);

    await tester.tap(find.text('Refresh PGN'));
    await tester.pumpAndSettle();
    expect(refreshed?.pgnId, 447);
    expect(find.text('PGN refreshed.'), findsOneWidget);
  });

  testWidgets('refresh PGN action follows the selected language',
      (tester) async {
    const record = GameRecord(
      pgnId: 448,
      result: '1-0',
      title: 'White vs Black',
      subtitle: 'OTB / 2 moves',
      pgn: '[Result "1-0"]\n\n1. e4 e5 1-0',
      pgnSource: 'https://records.test/448.pgn',
      playMode: 'otb',
      gameStatus: 2,
      gameStep: 2,
      winId: 1,
    );
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        records: const [record],
        onRefreshRecordPgn: (_) async => const ApiResult(
          ApiStatus.success(),
          data: record,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollRecordListIntoView(tester);
    await tester.tap(find.byKey(const ValueKey('game-record-more-pgn:448')));
    await tester.pumpAndSettle();
    expect(find.text('刷新 PGN'), findsOneWidget);

    await tester.tap(find.text('刷新 PGN'));
    await tester.pumpAndSettle();
    expect(find.text('PGN 已刷新。'), findsOneWidget);
  });

  testWidgets('Android portrait shows white and black names on two lines each',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        _recordHarness(
          signedIn: true,
          records: [
            _sampleRecord(
              446,
              'White Player With A Long Portrait Name',
              'Black Player With A Long Portrait Name',
              'bot',
              'rapid',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final white = tester.widget(
        find.byKey(const ValueKey('game-record-white-player-pgn:446')),
      ) as dynamic;
      final black = tester.widget(
        find.byKey(const ValueKey('game-record-black-player-pgn:446')),
      ) as dynamic;
      expect(white.maxLines, 2);
      expect(black.maxLines, 2);
      expect(
        find.byKey(const ValueKey('game-record-player-summary-pgn:446')),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android landscape keeps the existing player summary layout',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        _recordHarness(
          signedIn: true,
          records: [
            _sampleRecord(447, 'White Player', 'Black Player', 'bot', 'rapid'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final summary = tester.widget(
        find.byKey(const ValueKey('game-record-player-summary-pgn:447')),
      ) as dynamic;
      expect(summary.maxLines, 1);
      expect(
        find.byKey(const ValueKey('game-record-white-player-pgn:447')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('game-record-black-player-pgn:447')),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iOS portrait shows white and black names on separate lines',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        _recordHarness(
          signedIn: true,
          records: [
            _sampleRecord(448, 'White Player', 'Black Player', 'bot', 'rapid'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final white = tester.widget(
        find.byKey(const ValueKey('game-record-white-player-pgn:448')),
      ) as dynamic;
      final black = tester.widget(
        find.byKey(const ValueKey('game-record-black-player-pgn:448')),
      ) as dynamic;
      expect(white.data, 'White: White Player');
      expect(black.data, 'Black: Black Player');
      expect(white.maxLines, 2);
      expect(black.maxLines, 2);
      expect(
        find.byKey(const ValueKey('game-record-player-summary-pgn:448')),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iOS landscape keeps the existing player summary layout',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        _recordHarness(
          signedIn: true,
          records: [
            _sampleRecord(450, 'White Player', 'Black Player', 'bot', 'rapid'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final summary = tester.widget(
        find.byKey(const ValueKey('game-record-player-summary-pgn:450')),
      ) as dynamic;
      expect(summary.maxLines, 1);
      expect(
        find.byKey(const ValueKey('game-record-white-player-pgn:450')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('game-record-black-player-pgn:450')),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android chess clock keeps the existing player summary layout',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        _recordHarness(
          signedIn: true,
          isChessnutClockDevice: true,
          records: [
            _sampleRecord(449, 'White Player', 'Black Player', 'bot', 'rapid'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final summary = tester.widget(
        find.byKey(const ValueKey('game-record-player-summary-pgn:449')),
      ) as dynamic;
      expect(summary.maxLines, 1);
      expect(
        find.byKey(const ValueKey('game-record-white-player-pgn:449')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('game-record-black-player-pgn:449')),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('record actions move copy into a long-press menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(854, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: const [
          GameRecord(
            pgnId: 445,
            shareId: 'live-bot-share',
            result: '*',
            title: 'Chessnut Player vs Maia 1500',
            subtitle: 'Bot / 2 moves',
            pgn: '[Event "Bot game room"]\n\n1. e4 Nf6 *',
            playMode: 'bot',
            gameStatus: 1,
            gameStep: 2,
            winId: 0,
          ),
        ],
        onContinueRecord: (_) {},
        onEndRecord: (_) async {
          return const ApiResult<bool>(ApiStatus.success(), data: true);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Copy PGN'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.byKey(const ValueKey('game-record-more-pgn:445')), findsOne);
    final continueRect = tester.getRect(find.byKey(const ValueKey(
      'game-record-continue',
    )));
    final moreRect = tester.getRect(
      find.byKey(const ValueKey('game-record-more-pgn:445')),
    );
    expect(continueRect.width, greaterThanOrEqualTo(150));
    expect(continueRect.right, lessThanOrEqualTo(854));
    expect(continueRect.center.dy, closeTo(moreRect.center.dy, 1));
    expect(moreRect.left - continueRect.right, inInclusiveRange(0, 8));

    await tester.longPress(
      find.byKey(const ValueKey('game-record-context-target-pgn:445')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('game-record-context-menu')), findsOne);
    expect(find.text('Copy PGN'), findsOneWidget);
    expect(find.text('End game'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('record overflow menu can delete one record', (tester) async {
    final deletedRecords = <GameRecord>[];
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: [
          _sampleRecord(91, 'Chessnut Player', 'Rapid Bot', 'bot', 'rapid'),
        ],
        onDeleteRecord: (record) async {
          deletedRecords.add(record);
          return const ApiResult<bool>(ApiStatus.success(), data: true);
        },
      ),
    );

    await _scrollRecordListIntoView(tester);
    await tester.tap(find.byKey(const ValueKey('game-record-more-pgn:91')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('game-record-context-menu')), findsOne);
    expect(find.text('Copy PGN'), findsOneWidget);
    expect(find.text('Delete record'), findsOneWidget);

    await tester.tap(find.text('Delete record'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('delete-records-dialog-confirm')),
    );
    await tester.pumpAndSettle();

    expect(deletedRecords.single.pgnId, 91);
    expect(
        find.text('White: Chessnut Player / Black: Rapid Bot'), findsNothing);
    expect(find.text('Game record deleted.'), findsOneWidget);
  });

  testWidgets('single-record actions no longer use swipe delete',
      (tester) async {
    final deletedRecords = <GameRecord>[];
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: [
          _sampleRecord(91, 'Chessnut Player', 'Rapid Bot', 'bot', 'rapid'),
        ],
        onDeleteRecord: (record) async {
          deletedRecords.add(record);
          return const ApiResult<bool>(ApiStatus.success(), data: true);
        },
      ),
    );

    expect(
        find.byKey(const ValueKey('game-record-swipe-delete')), findsNothing);
    expect(find.text('Delete'), findsNothing);

    await _scrollRecordListIntoView(tester);
    await tester.drag(
      find.byKey(const ValueKey('game-record-context-target-pgn:91')),
      const Offset(-130, 0),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('game-record-swipe-delete')), findsNothing);
    expect(find.text('Delete'), findsNothing);
    expect(deletedRecords, isEmpty);
  });

  testWidgets('record menu can end an unfinished game', (tester) async {
    final endedRecords = <GameRecord>[];
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: const [
          GameRecord(
            pgnId: 445,
            shareId: 'live-bot-share',
            result: '*',
            title: 'Chessnut Player vs Maia 1500',
            subtitle: 'Bot / 2 moves',
            pgn: '[Event "Bot game room"]\n\n1. e4 Nf6 *',
            playMode: 'bot',
            gameStatus: 1,
            gameStep: 2,
            winId: 0,
          ),
        ],
        onContinueRecord: (_) {},
        onEndRecord: (record) async {
          endedRecords.add(record);
          return const ApiResult<bool>(ApiStatus.success(), data: true);
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey('game-record-more-pgn:445')));
    await tester.pumpAndSettle();

    expect(find.text('End game'), findsOneWidget);
    await tester.tap(find.text('End game'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('end-record-dialog-confirm')));
    await tester.pumpAndSettle();

    expect(endedRecords.single.pgnId, 445);
    expect(
      find.text('Game marked as ended.'),
      findsOneWidget,
    );
  });

  testWidgets('batch deletes selected game records after confirmation',
      (tester) async {
    final deletedRecords = <GameRecord>[];
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: [
          _sampleRecord(91, 'Chessnut Player', 'Rapid Bot', 'bot', 'rapid'),
          _sampleRecord(92, 'Chessnut Player', 'Practice Bot', 'bot', 'rapid'),
        ],
        onDeleteRecord: (record) async {
          deletedRecords.add(record);
          return const ApiResult<bool>(ApiStatus.success(), data: true);
        },
      ),
    );

    expect(
        find.text('White: Chessnut Player / Black: Rapid Bot'), findsOneWidget);
    expect(find.text('White: Chessnut Player / Black: Practice Bot'),
        findsOneWidget);
    expect(find.byTooltip('Delete record'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('game-record-select-mode')));
    await tester.pumpAndSettle();

    await _scrollRecordListIntoView(tester);
    await tester.tap(find.byKey(const ValueKey('game-record-select-pgn:91')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-record-select-pgn:92')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('game-record-batch-delete')));
    await tester.pumpAndSettle();

    expect(find.text('Delete selected records?'), findsOneWidget);
    expect(find.text('2 selected'), findsAtLeastNWidgets(1));
    expect(find.text('Delete 2 records'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('delete-records-dialog-confirm')),
    );
    await tester.pumpAndSettle();

    expect(deletedRecords.map((record) => record.pgnId), containsAll([91, 92]));
    expect(
        find.text('White: Chessnut Player / Black: Rapid Bot'), findsNothing);
    expect(find.text('White: Chessnut Player / Black: Practice Bot'),
        findsNothing);
    expect(find.text('2 game records deleted.'), findsOneWidget);
  });

  testWidgets('batch delete hides selected records while delete is pending',
      (tester) async {
    final firstDelete = Completer<ApiResult<bool>>();
    final deletedRecords = <GameRecord>[];
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: [
          _sampleRecord(91, 'Chessnut Player', 'Rapid Bot', 'bot', 'rapid'),
          _sampleRecord(92, 'Chessnut Player', 'Practice Bot', 'bot', 'rapid'),
        ],
        onDeleteRecord: (record) {
          deletedRecords.add(record);
          if (deletedRecords.length == 1) return firstDelete.future;
          return Future.value(
            const ApiResult<bool>(ApiStatus.success(), data: true),
          );
        },
      ),
    );

    await tester.tap(find.byTooltip('Select records'));
    await tester.pumpAndSettle();

    await _scrollRecordListIntoView(tester);
    await tester.tap(find.byKey(const ValueKey('game-record-select-pgn:91')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-record-select-pgn:92')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('game-record-batch-delete')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('delete-records-dialog-confirm')),
    );
    await tester.pump();

    expect(deletedRecords, hasLength(1));
    expect(deletedRecords.single.pgnId, isIn(<int>[91, 92]));
    expect(
        find.text('White: Chessnut Player / Black: Rapid Bot'), findsNothing);
    expect(find.text('White: Chessnut Player / Black: Practice Bot'),
        findsNothing);

    firstDelete.complete(
      const ApiResult<bool>(ApiStatus.success(), data: true),
    );
    await tester.pumpAndSettle();

    expect(deletedRecords.map((record) => record.pgnId), containsAll([91, 92]));
    expect(find.text('2 game records deleted.'), findsOneWidget);
  });

  testWidgets('batch delete keeps records hidden after parent reload',
      (tester) async {
    final deletedRecords = <GameRecord>[];
    final records = [
      _sampleRecord(91, 'Chessnut Player', 'Rapid Bot', 'bot', 'rapid'),
      _sampleRecord(92, 'Chessnut Player', 'Practice Bot', 'bot', 'rapid'),
    ];

    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: records,
        onDeleteRecord: (record) async {
          deletedRecords.add(record);
          return const ApiResult<bool>(ApiStatus.success(), data: true);
        },
      ),
    );

    await tester.tap(find.byTooltip('Select records'));
    await tester.pumpAndSettle();

    await _scrollRecordListIntoView(tester);
    await tester.tap(find.byKey(const ValueKey('game-record-select-pgn:91')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('game-record-batch-delete')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('delete-records-dialog-confirm')),
    );
    await tester.pumpAndSettle();

    expect(deletedRecords.single.pgnId, 91);
    expect(
        find.text('White: Chessnut Player / Black: Rapid Bot'), findsNothing);

    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: records,
        onDeleteRecord: (record) async {
          deletedRecords.add(record);
          return const ApiResult<bool>(ApiStatus.success(), data: true);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.text('White: Chessnut Player / Black: Rapid Bot'), findsNothing);
    expect(find.text('White: Chessnut Player / Black: Practice Bot'),
        findsOneWidget);
  });

  testWidgets('batch delete does not show full loading card during refresh',
      (tester) async {
    final deletedRecords = <GameRecord>[];
    final records = [
      _sampleRecord(91, 'Chessnut Player', 'Rapid Bot', 'bot', 'rapid'),
      _sampleRecord(92, 'Chessnut Player', 'Practice Bot', 'bot', 'rapid'),
    ];

    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: records,
        onDeleteRecord: (record) async {
          deletedRecords.add(record);
          return const ApiResult<bool>(ApiStatus.success(), data: true);
        },
      ),
    );

    await tester.tap(find.byTooltip('Select records'));
    await tester.pumpAndSettle();

    await _scrollRecordListIntoView(tester);
    await tester.tap(find.byKey(const ValueKey('game-record-select-pgn:91')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-record-select-pgn:92')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('game-record-batch-delete')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('delete-records-dialog-confirm')),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        loading: true,
        records: records,
        onDeleteRecord: (record) async {
          deletedRecords.add(record);
          return const ApiResult<bool>(ApiStatus.success(), data: true);
        },
      ),
    );
    await tester.pump();

    expect(find.text('Loading records'), findsNothing);
    expect(
        find.text('White: Chessnut Player / Black: Rapid Bot'), findsNothing);
    expect(find.text('White: Chessnut Player / Black: Practice Bot'),
        findsNothing);
  });

  testWidgets('speed filter classifies backend labels and time controls',
      (tester) async {
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: const [
          GameRecord(
            pgnId: 200,
            result: '1-0',
            title: 'Bullet White vs Bullet Black',
            subtitle: 'Imported / 4 moves',
            playMode: 'analysis',
            gameStep: 8,
            winId: 1,
            whiteName: 'Bullet White',
            blackName: 'Bullet Black',
            pgn: '[White "Bullet White"]\n'
                '[Black "Bullet Black"]\n'
                '[TimeControl "60+0"]\n\n'
                '1. e4 e5 1-0',
          ),
          GameRecord(
            pgnId: 204,
            result: '1-0',
            title: 'Career White vs Career Black',
            subtitle: 'Career challenge / 4 moves',
            playMode: 'career',
            gameStep: 8,
            winId: 1,
            whiteName: 'Career White',
            blackName: 'Career Black',
            pgn: '[White "Career White"]\n'
                '[Black "Career Black"]\n'
                '[TimeControl "-"]\n\n'
                '1. e4 e5 1-0',
          ),
          GameRecord(
            pgnId: 201,
            result: '1-0',
            title: 'Blitz White vs Blitz Black',
            subtitle: 'Lichess Blitz / 8 moves',
            playMode: 'lichess_blitz',
            gameStep: 16,
            winId: 1,
            whiteName: 'Blitz White',
            blackName: 'Blitz Black',
            pgn: '[White "Blitz White"]\n'
                '[Black "Blitz Black"]\n'
                '[TimeControl "5+3"]\n\n'
                '1. e4 e5 1-0',
          ),
          GameRecord(
            pgnId: 202,
            result: '1-0',
            title: 'Rapid White vs Rapid Black',
            subtitle: 'Bot / 10 moves',
            playMode: 'bot',
            gameStep: 20,
            winId: 1,
            whiteName: 'Rapid White',
            blackName: 'Rapid Black',
            pgn: '[White "Rapid White"]\n'
                '[Black "Rapid Black"]\n'
                '[Site "Chessnut App"]\n'
                '[TimeControl "10+5"]\n\n'
                '1. d4 d5 1-0',
          ),
          GameRecord(
            pgnId: 203,
            result: '1-0',
            title: 'Classical White vs Classical Black',
            subtitle: 'OTB / 12 moves',
            playMode: 'otb',
            gameStep: 24,
            winId: 1,
            whiteName: 'Classical White',
            blackName: 'Classical Black',
            pgn: '[White "Classical White"]\n'
                '[Black "Classical Black"]\n'
                '[Site "Chessnut App"]\n'
                '[TimeControl "30+0"]\n\n'
                '1. c4 e5 1-0',
          ),
        ],
      ),
    );

    await _expandRecordFilters(tester);
    await tester.tap(find.byKey(const ValueKey('game-record-filter-speed')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bullet').last);
    await tester.pumpAndSettle();

    expect(
        find.text('White: Bullet White / Black: Bullet Black'), findsOneWidget);
    expect(
        find.text('White: Career White / Black: Career Black'), findsNothing);
    expect(find.text('White: Blitz White / Black: Blitz Black'), findsNothing);
    expect(find.text('White: Rapid White / Black: Rapid Black'), findsNothing);
    expect(
      find.text('White: Classical White / Black: Classical Black'),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('game-record-filter-speed')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blitz').last);
    await tester.pumpAndSettle();

    expect(
        find.text('White: Bullet White / Black: Bullet Black'), findsNothing);
    expect(
        find.text('White: Career White / Black: Career Black'), findsNothing);
    expect(
        find.text('White: Blitz White / Black: Blitz Black'), findsOneWidget);
    expect(find.text('White: Rapid White / Black: Rapid Black'), findsNothing);
    expect(
      find.text('White: Classical White / Black: Classical Black'),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('game-record-filter-speed')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rapid').last);
    await tester.pumpAndSettle();

    expect(
        find.text('White: Bullet White / Black: Bullet Black'), findsNothing);
    expect(
        find.text('White: Career White / Black: Career Black'), findsNothing);
    expect(find.text('White: Blitz White / Black: Blitz Black'), findsNothing);
    expect(
        find.text('White: Rapid White / Black: Rapid Black'), findsOneWidget);
    expect(
      find.text('White: Classical White / Black: Classical Black'),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('game-record-filter-speed')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Classical').last);
    await tester.pumpAndSettle();

    expect(
        find.text('White: Bullet White / Black: Bullet Black'), findsNothing);
    expect(
        find.text('White: Career White / Black: Career Black'), findsNothing);
    expect(find.text('White: Blitz White / Black: Blitz Black'), findsNothing);
    expect(find.text('White: Rapid White / Black: Rapid Black'), findsNothing);
    expect(
      find.text('White: Classical White / Black: Classical Black'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('game-record-filter-speed')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Casual').last);
    await tester.pumpAndSettle();

    expect(
        find.text('White: Bullet White / Black: Bullet Black'), findsNothing);
    expect(
        find.text('White: Career White / Black: Career Black'), findsOneWidget);
    expect(find.text('White: Blitz White / Black: Blitz Black'), findsNothing);
    expect(find.text('White: Rapid White / Black: Rapid Black'), findsNothing);
    expect(
      find.text('White: Classical White / Black: Classical Black'),
      findsNothing,
    );
  });

  testWidgets(
      'record filters use player-side result, speed, and color reliably',
      (tester) async {
    const session = ChessnutLoginSession(
      avatarUrl: '',
      bindApple: false,
      bindChess: true,
      bindGoogle: false,
      bindLichess: true,
      chessName: 'ChessComHero',
      email: 'knight@example.com',
      lichessName: 'KnightOnLichess',
      noPassword: false,
      phone: '15500001111',
      region: '',
      token: 'token',
      userId: 7,
      username: 'Knight Rider',
    );
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        currentSession: session,
        records: const [
          GameRecord(
            pgnId: 301,
            result: '*',
            title: 'Knight Rider vs Blitz Rival',
            subtitle: 'Chess.com / 10 moves',
            playMode: 'chesscom',
            gameStep: 20,
            winId: 0,
            whiteName: 'Knight Rider',
            blackName: 'Blitz Rival',
            pgn: '[White "Knight Rider"]\n'
                '[Black "Blitz Rival"]\n'
                '[Result "0-1"]\n'
                '[TimeControl "300+0"]\n\n'
                '1. e4 e5 0-1',
          ),
          GameRecord(
            pgnId: 302,
            result: '*',
            title: 'Bullet Rival vs Knight Rider',
            subtitle: 'Lichess / 8 moves',
            playMode: 'lichess',
            gameStep: 16,
            winId: 2,
            whiteName: 'Bullet Rival',
            blackName: 'Knight Rider',
            pgn: '[White "Bullet Rival"]\n'
                '[Black "Knight Rider"]\n'
                '[TimeControl "60+0"]\n\n'
                '1. e4 c5 0-1',
          ),
          GameRecord(
            pgnId: 303,
            result: '*',
            title: 'ChessComHero vs Rapid Rival',
            subtitle: 'Chess.com / 12 moves',
            playMode: 'chesscom',
            gameStep: 24,
            winId: 3,
            whiteName: 'ChessComHero',
            blackName: 'Rapid Rival',
            pgn: '[White "ChessComHero"]\n'
                '[Black "Rapid Rival"]\n'
                '[Result "1/2-1/2"]\n'
                '[TimeControl "600+5"]\n\n'
                '1. d4 d5 1/2-1/2',
          ),
          GameRecord(
            pgnId: 304,
            result: '1-0',
            title: 'Classic Rival vs knight',
            subtitle: 'OTB / 20 moves',
            playMode: 'otb',
            gameStep: 40,
            winId: 1,
            whiteName: 'Classic Rival',
            blackName: 'knight',
            pgn: '[White "Classic Rival"]\n'
                '[Black "knight"]\n'
                '[TimeControl "45+45"]\n\n'
                '1. c4 e5 1-0',
          ),
        ],
      ),
    );

    await _expandRecordFilters(tester);

    await _chooseRecordFilter<RecordResultFilter>(
      tester,
      const ValueKey('game-record-filter-result'),
      'Win',
    );
    expect(
        find.text('White: Bullet Rival / Black: Knight Rider'), findsOneWidget);
    expect(find.text('White: Knight Rider / Black: Blitz Rival'), findsNothing);
    expect(find.text('White: ChessComHero / Black: Rapid Rival'), findsNothing);
    expect(find.text('White: Classic Rival / Black: knight'), findsNothing);

    await _chooseRecordFilter<RecordResultFilter>(
      tester,
      const ValueKey('game-record-filter-result'),
      'Loss',
    );
    expect(
        find.text('White: Knight Rider / Black: Blitz Rival'), findsOneWidget);
    expect(
        find.text('White: Bullet Rival / Black: Knight Rider'), findsNothing);

    await _chooseRecordFilter<RecordResultFilter>(
      tester,
      const ValueKey('game-record-filter-result'),
      'Draw',
    );
    expect(
        find.text('White: ChessComHero / Black: Rapid Rival'), findsOneWidget);
    expect(find.text('White: Knight Rider / Black: Blitz Rival'), findsNothing);

    await _chooseRecordFilter<RecordResultFilter>(
      tester,
      const ValueKey('game-record-filter-result'),
      'All',
    );
    await _chooseRecordFilter<RecordColorFilter>(
      tester,
      const ValueKey('game-record-filter-color'),
      'White',
    );
    expect(
        find.text('White: Knight Rider / Black: Blitz Rival'), findsOneWidget);
    expect(
        find.text('White: ChessComHero / Black: Rapid Rival'), findsOneWidget);
    expect(
        find.text('White: Bullet Rival / Black: Knight Rider'), findsNothing);
    expect(find.text('White: Classic Rival / Black: knight'), findsNothing);

    await _chooseRecordFilter<RecordColorFilter>(
      tester,
      const ValueKey('game-record-filter-color'),
      'Black',
    );
    expect(
        find.text('White: Bullet Rival / Black: Knight Rider'), findsOneWidget);
    expect(find.text('White: Classic Rival / Black: knight'), findsOneWidget);
    expect(find.text('White: Knight Rider / Black: Blitz Rival'), findsNothing);

    await _chooseRecordFilter<RecordColorFilter>(
      tester,
      const ValueKey('game-record-filter-color'),
      'Any color',
    );
    await _chooseRecordFilter<RecordSpeedFilter>(
      tester,
      const ValueKey('game-record-filter-speed'),
      'Bullet',
    );
    expect(
        find.text('White: Bullet Rival / Black: Knight Rider'), findsOneWidget);
    expect(find.text('White: Knight Rider / Black: Blitz Rival'), findsNothing);

    await _chooseRecordFilter<RecordSpeedFilter>(
      tester,
      const ValueKey('game-record-filter-speed'),
      'Blitz',
    );
    expect(
        find.text('White: Knight Rider / Black: Blitz Rival'), findsOneWidget);
    expect(
        find.text('White: Bullet Rival / Black: Knight Rider'), findsNothing);

    await _chooseRecordFilter<RecordSpeedFilter>(
      tester,
      const ValueKey('game-record-filter-speed'),
      'Rapid',
    );
    expect(
        find.text('White: ChessComHero / Black: Rapid Rival'), findsOneWidget);
    expect(find.text('White: Knight Rider / Black: Blitz Rival'), findsNothing);

    await _chooseRecordFilter<RecordSpeedFilter>(
      tester,
      const ValueKey('game-record-filter-speed'),
      'Classical',
    );
    expect(find.text('White: Classic Rival / Black: knight'), findsOneWidget);
    expect(find.text('White: ChessComHero / Black: Rapid Rival'), findsNothing);
  });

  testWidgets('batch deletes local analysis records without a backend pgn id',
      (tester) async {
    const pgn = '[White "Local White"]\n'
        '[Black "Local Black"]\n'
        '[Result "1-0"]\n\n'
        '1. e4 e5 1-0';
    final deletedRecords = <GameRecord>[];
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: const [
          GameRecord(
            result: '1-0',
            title: 'Local White vs Local Black',
            subtitle: 'Analysis / Grandeur / 2026-06-13',
            pgn: pgn,
            playMode: 'analysis',
            gameStatus: 2,
            gameStep: 2,
          ),
        ],
        onDeleteRecord: (record) async {
          deletedRecords.add(record);
          return const ApiResult<bool>(ApiStatus.success(), data: true);
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey('game-record-select-mode')));
    await tester.pumpAndSettle();

    final recordKey = gameAnalysisReportCacheKeyForPgn(pgn);
    await tester.tap(find.byKey(ValueKey('game-record-select-$recordKey')));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('game-record-batch-delete')));
    await tester.pumpAndSettle();
    expect(find.text('Delete selected records?'), findsOneWidget);
    expect(find.text('Delete 1 record'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('delete-records-dialog-confirm')),
    );
    await tester.pumpAndSettle();

    expect(deletedRecords.single.pgn, pgn);
    expect(find.text('Game record deleted.'), findsOneWidget);
  });

  testWidgets('does not continue finished bot records', (
    tester,
  ) async {
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: const [
          GameRecord(
            pgnId: 334,
            result: '*',
            title: 'Chessnut Player vs Maia 1500',
            subtitle: 'Bot / 2 moves',
            pgn: '[Event "Bot game room"]\n\n1. e4 Nf6 *',
            playMode: 'bot',
            gameStatus: 2,
            gameStep: 2,
            winId: 0,
          ),
        ],
        onContinueRecord: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue'), findsNothing);
    expect(find.textContaining('Result:'), findsNothing);
    expect(find.text('*'), findsNothing);
  });

  testWidgets('marks records that already have cached reports', (
    tester,
  ) async {
    const pgn = '1. e4 e5 2. Nf3 Nc6 1-0';
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: [
          const GameRecord(
            pgnId: 10,
            result: '1-0',
            title: 'Alice vs Bob',
            subtitle: 'Bot / 24 moves',
            pgn: '1. e4 e5 2. Nf3 Nc6 1-0',
          ),
          const GameRecord(
            pgnId: 11,
            shareId: 'grandeur-share',
            result: '0-1',
            title: 'Carol vs Dana',
            subtitle: 'Lichess / 30 moves',
            pgn: '1. d4 Nf6 2. c4 e6 0-1',
          ),
        ],
        reportStatuses: {
          'pgn:10': const GameAnalysisReportStatus(standard: true),
          gameAnalysisReportCacheKeyForPgn(pgn):
              const GameAnalysisReportStatus(grandeur: true),
          'share:grandeur-share': const GameAnalysisReportStatus(
            standard: true,
            grandeur: true,
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('game-record-standard-report-chip')),
      findsNWidgets(2),
    );
    expect(
      find.byKey(const ValueKey('game-record-grandeur-report-chip')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('game-record-grandeur-premium-badge')),
      findsNothing,
    );
    expect(find.text('Premium'), findsNothing);
    expect(
        find.byKey(const ValueKey('game-record-reviewed-count')), findsNothing);
  });

  testWidgets('filters by analysis report type', (tester) async {
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: const [
          GameRecord(
            pgnId: 20,
            result: '1-0',
            title: 'No Report vs Player',
            subtitle: 'Bot / 20 moves',
            pgn: '1. e4 e5 1-0',
          ),
          GameRecord(
            pgnId: 21,
            result: '1-0',
            title: 'Standard Report vs Player',
            subtitle: 'Bot / 30 moves',
            pgn: '1. d4 d5 1-0',
          ),
          GameRecord(
            pgnId: 22,
            result: '1-0',
            title: 'Grandeur Report vs Player',
            subtitle: 'Bot / 40 moves',
            pgn: '1. c4 e5 1-0',
            commentId: 92,
          ),
        ],
        reportStatuses: const {
          'pgn:21': GameAnalysisReportStatus(standard: true),
          'pgn:22': GameAnalysisReportStatus(
            standard: true,
            grandeur: true,
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    await _expandRecordFilters(tester);
    await tester.tap(find.byType(DropdownButtonFormField<RecordReportFilter>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No analysis').last);
    await tester.pumpAndSettle();

    expect(find.text('White: No Report / Black: Player'), findsOneWidget);
    expect(find.text('White: Standard Report / Black: Player'), findsNothing);
    expect(find.text('White: Grandeur Report / Black: Player'), findsNothing);

    await _expandRecordFilters(tester);
    await tester.tap(find.byType(DropdownButtonFormField<RecordReportFilter>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard analysis').last);
    await tester.pumpAndSettle();

    expect(find.text('White: No Report / Black: Player'), findsNothing);
    expect(find.text('White: Standard Report / Black: Player'), findsOneWidget);
    expect(find.text('White: Grandeur Report / Black: Player'), findsOneWidget);

    await _expandRecordFilters(tester);
    await tester.tap(find.byType(DropdownButtonFormField<RecordReportFilter>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grandeur analysis').last);
    await tester.pumpAndSettle();

    expect(find.text('White: No Report / Black: Player'), findsNothing);
    expect(find.text('White: Standard Report / Black: Player'), findsNothing);
    expect(find.text('White: Grandeur Report / Black: Player'), findsOneWidget);
  });

  testWidgets('Grandeur filter includes every record bound to commentary',
      (tester) async {
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: const [
          GameRecord(
            pgnId: 23,
            result: '1-0',
            title: 'Ready Grandeur vs Player',
            subtitle: 'Bot / 40 moves',
            pgn: '1. c4 e5 1-0',
            commentId: 92,
            hasGrandeurReport: true,
          ),
          GameRecord(
            pgnId: 24,
            result: '1-0',
            title: 'Pending Grandeur vs Player',
            subtitle: 'Bot / 40 moves',
            pgn: '1. Nf3 d5 1-0',
            commentId: 93,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _expandRecordFilters(tester);
    await tester.tap(find.byType(DropdownButtonFormField<RecordReportFilter>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grandeur analysis').last);
    await tester.pumpAndSettle();

    expect(find.text('White: Ready Grandeur / Black: Player'), findsOneWidget);
    expect(
        find.text('White: Pending Grandeur / Black: Player'), findsOneWidget);
  });

  testWidgets('cached analysis PGNs can appear as local game records', (
    tester,
  ) async {
    const pgn = '[White "Analysis White"]\n'
        '[Black "Analysis Black"]\n'
        '[Result "1-0"]\n\n'
        '1. e4 e5 2. Nf3 Nc6 1-0';
    final key = gameAnalysisReportCacheKeyForPgn(pgn);
    final cachedRecords = gameAnalysisRecordsFromCache({
      key: GameAnalysisReportCacheEntry(
        pgn: pgn,
        standardReport: GameStandardAnalysisReport(
          moves: const [],
          stockfishBacked: true,
          stockfishStatus: 'Report ready',
          generatedAt: DateTime(2026, 5, 27),
        ),
        grandeurReport: const GrandeurAnalysisResult(
          analysisId: 'g-local',
          moves: [],
        ),
        updatedAt: DateTime(2026, 5, 27),
      ),
    });

    expect(cachedRecords, hasLength(1));
    expect(cachedRecords.single.pgnId, isNull);
    expect(cachedRecords.single.shareId, isNull);

    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: cachedRecords,
        reportStatuses: {
          key: const GameAnalysisReportStatus(
            standard: true,
            grandeur: true,
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('White: Analysis White / Black: Analysis Black'),
        findsOneWidget);
    expect(
      find.byKey(const ValueKey('game-record-standard-report-chip')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('game-record-grandeur-report-chip')),
      findsNothing,
    );
  });

  testWidgets('orders cached analysis and backend records by record time', (
    tester,
  ) async {
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: [
          GameRecord(
            result: '1-0',
            title: 'Old Analysis vs Player',
            subtitle: 'Analysis / 2026-05-30',
            pgn: '1. e4 e5 1-0',
            playMode: 'analysis',
            sortAt: DateTime(2026, 5, 30),
          ),
          GameRecord(
            pgnId: 900,
            result: '0-1',
            title: 'New Backend vs Player',
            subtitle: 'Bot / 2026-06-02',
            pgn: '1. d4 d5 0-1',
            playMode: 'bot',
            sortAt: DateTime(2026, 6, 2),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final oldRect =
        tester.getRect(find.text('White: Old Analysis / Black: Player'));
    final newRect =
        tester.getRect(find.text('White: New Backend / Black: Player'));
    expect(newRect.top, lessThan(oldRect.top));
  });

  testWidgets('record filter panel wraps compact controls without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: [
          _sampleRecord(
              31, 'Chessnut Player', 'Compact Opponent', 'bot', 'rapid'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _expandRecordFilters(tester);
    expect(find.text('Color'), findsOneWidget);
    final filterPanel = tester.getRect(find.byKey(
      const ValueKey('game-record-filter-panel'),
    ));
    final colorMenu = tester.getRect(
      find.byKey(const ValueKey('game-record-filter-color')),
    );
    expect(colorMenu.left, greaterThanOrEqualTo(filterPanel.left));
    expect(colorMenu.right, lessThanOrEqualTo(filterPanel.right));
  });

  testWidgets('blocks analysis for unfinished records until the game ends', (
    tester,
  ) async {
    var analyzeCount = 0;
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: const [
          GameRecord(
            pgnId: 12,
            result: '*',
            title: 'Chessnut Player vs Maia 1500',
            subtitle: 'Bot / 2 moves',
            pgn: '[Event "Bot"]\n\n1. e4 Nf6 *',
            playMode: 'bot',
            gameStatus: 1,
            gameStep: 2,
            winId: 0,
          ),
        ],
        onAnalyzeRecord: (_) => analyzeCount++,
      ),
    );

    await _scrollRecordListIntoView(tester);
    final recordTitle = find.text('White: Chessnut Player / Black: Maia 1500');
    await tester.tap(recordTitle);
    await tester.pump();

    expect(analyzeCount, 0);
    expect(
      find.text('Finish this game before generating an analysis report.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('blocks analysis for finished records with no playable moves', (
    tester,
  ) async {
    var analyzeCount = 0;
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: const [
          GameRecord(
            pgnId: 13,
            result: '1-0',
            title: 'Alice vs Bob',
            subtitle: 'Chesscom / 0 moves',
            pgn: '''
[Event "Live Chess"]
[White "Alice"]
[Black "Bob"]
[Result "1-0"]

1-0
''',
            playMode: 'chesscom',
            gameStatus: 2,
            gameStep: 0,
            winId: 1,
            whiteName: 'Alice',
            blackName: 'Bob',
          ),
        ],
        onAnalyzeRecord: (_) => analyzeCount++,
      ),
    );

    await _scrollRecordListIntoView(tester);
    await tester.tap(find.text('White: Alice / Black: Bob'));
    await tester.pump();

    expect(analyzeCount, 0);
    expect(
      find.text(
        'This game ended before any playable moves, so there is no position to analyze.',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('does not show Model Build controls inside Game Record', (
    tester,
  ) async {
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: [
          _sampleRecord(1, 'Chessnut Player', 'Rapid Bot', 'bot', 'rapid'),
          _sampleRecord(
              2, 'Chessnut Player', 'Lichess Blitz', 'lichess', 'blitz'),
          _sampleRecord(3, 'OTB White', 'Chessnut Player', 'otb', 'classical'),
        ],
      ),
    );

    expect(
        find.text('White: Chessnut Player / Black: Rapid Bot'), findsOneWidget);
    expect(find.text('White: Chessnut Player / Black: Lichess Blitz'),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('game-record-source-lichess')));
    await tester.pumpAndSettle();

    expect(find.text('White: Chessnut Player / Black: Lichess Blitz'),
        findsOneWidget);
    expect(
        find.text('White: Chessnut Player / Black: Rapid Bot'), findsNothing);
    expect(find.byKey(const ValueKey('game-record-model-build-bar')),
        findsNothing);
    expect(
        find.byKey(const ValueKey('model-build-filter-start')), findsNothing);
  });

  testWidgets('searches the full server archive from game records', (
    tester,
  ) async {
    GameRecordFilter? capturedFilter;
    int? capturedPage;
    int? capturedCount;
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: [
          _sampleRecord(1, 'Chessnut Player', 'Local Bot', 'bot', 'rapid'),
        ],
        onSearchRemoteRecords: (filter, page, count) async {
          capturedFilter = filter;
          capturedPage = page;
          capturedCount = count;
          return const GameRecordRemoteSearchResult(
            status: ApiStatus.success(),
            records: [
              GameRecord(
                pgnId: 90,
                result: '*',
                title: 'Server Alice vs Chessnut Player',
                subtitle: 'Server result / 42 moves',
                pgn: '',
                playMode: 'bot',
                gameStatus: 1,
                gameStep: 84,
                winId: 0,
                whiteName: 'Server Alice',
                blackName: 'Chessnut Player',
              ),
            ],
            page: 1,
            count: 10,
            total: 41,
            totalPage: 3,
          );
        },
      ),
    );

    await _expandRecordFilters(tester);
    await _chooseRecordFilter<RecordResultFilter>(
      tester,
      const ValueKey('game-record-filter-result'),
      'Loss',
    );
    await _chooseRecordFilter<RecordColorFilter>(
      tester,
      const ValueKey('game-record-filter-color'),
      'Black',
    );
    await _chooseRecordFilter<RecordSpeedFilter>(
      tester,
      const ValueKey('game-record-filter-speed'),
      'Blitz',
    );
    await tester.tap(find.byKey(const ValueKey('game-record-search-all')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(capturedFilter, isNotNull);
    expect(capturedFilter?.result, RecordResultFilter.loss);
    expect(capturedFilter?.color, RecordColorFilter.black);
    expect(capturedFilter?.speed, RecordSpeedFilter.blitz);
    expect(capturedPage, 1);
    expect(capturedCount, 10);
    expect(find.text('White: Server Alice / Black: Chessnut Player'),
        findsOneWidget);
    expect(
        find.text('White: Chessnut Player / Black: Local Bot'), findsNothing);
    expect(find.text('41 games found'), findsOneWidget);
    expect(
        find.text(
            'Page 1 of 3. Analysis filters use reports already saved on this device.'),
        findsOneWidget);
  });

  testWidgets('each filter change searches the full archive again', (
    tester,
  ) async {
    final searchedResults = <RecordResultFilter>[];
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: [
          _sampleRecord(1, 'Local Player', 'Local Opponent', 'bot', 'rapid'),
        ],
        onSearchRemoteRecords: (filter, page, count) async {
          searchedResults.add(filter.result);
          final isLoss = filter.result == RecordResultFilter.loss;
          return GameRecordRemoteSearchResult(
            status: const ApiStatus.success(),
            records: [
              GameRecord(
                pgnId: isLoss ? 92 : 91,
                result: isLoss ? '0-1' : '1-0',
                title: isLoss
                    ? 'Chessnut Player vs Server Loss'
                    : 'Chessnut Player vs Server Win',
                subtitle: 'Bot / 20 moves',
                pgn: isLoss
                    ? '[White "Chessnut Player"]\n'
                        '[Black "Server Loss"]\n\n1. e4 e5 0-1'
                    : '[White "Chessnut Player"]\n'
                        '[Black "Server Win"]\n\n1. e4 e5 1-0',
                playMode: 'bot',
                gameStatus: 2,
                gameStep: 40,
                winId: isLoss ? 2 : 1,
                whiteName: 'Chessnut Player',
                blackName: isLoss ? 'Server Loss' : 'Server Win',
              ),
            ],
            page: page,
            count: count,
            total: 1,
            totalPage: 1,
          );
        },
      ),
    );

    await _expandRecordFilters(tester);
    await _chooseRecordFilter<RecordResultFilter>(
      tester,
      const ValueKey('game-record-filter-result'),
      'Win',
    );
    expect(find.text('White: Chessnut Player / Black: Server Win'),
        findsOneWidget);

    await _chooseRecordFilter<RecordResultFilter>(
      tester,
      const ValueKey('game-record-filter-result'),
      'Loss',
    );

    expect(searchedResults, [RecordResultFilter.win, RecordResultFilter.loss]);
    expect(find.text('White: Chessnut Player / Black: Server Loss'),
        findsOneWidget);
    expect(
        find.text('White: Chessnut Player / Black: Server Win'), findsNothing);
  });

  testWidgets('loads record pages from pager controls', (
    tester,
  ) async {
    final loadedPages = <int>[];
    var records = [
      for (var i = 1; i <= 10; i++)
        _sampleRecord(i, 'Player $i', 'Opponent $i', 'bot', 'rapid'),
    ];
    var currentPage = 1;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => _recordHarness(
          signedIn: true,
          records: records,
          currentPage: currentPage,
          totalPage: 2,
          totalCount: 20,
          hasMoreRecords: currentPage < 2,
          loadingMoreRecords: false,
          onLoadRecordPage: (page) async {
            loadedPages.add(page);
            setState(() {
              currentPage = page;
              records = [
                for (var i = 11; i <= 20; i++)
                  _sampleRecord(i, 'Player $i', 'Opponent $i', 'bot', 'rapid'),
              ];
            });
          },
        ),
      ),
    );

    expect(loadedPages, isEmpty);
    expect(find.text('Page 1 of 2'), findsOneWidget);
    expect(find.textContaining('10 per page'), findsNothing);
    expect(find.text('White: Player 11 / Black: Opponent 11'), findsNothing);

    await tester
        .ensureVisible(find.byKey(const ValueKey('game-record-page-controls')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next records page'));
    await tester.pumpAndSettle();

    expect(loadedPages, [2]);
    expect(find.text('Page 2 of 2'), findsOneWidget);
    expect(find.text('White: Player 1 / Black: Opponent 1'), findsNothing);
    expect(find.text('White: Player 11 / Black: Opponent 11'), findsOneWidget);
  });

  testWidgets('source tab totals stay fixed while local pages change', (
    tester,
  ) async {
    final loadedPages = <int>[];
    var records = [
      for (var i = 1; i <= 10; i++)
        _sampleRecord(i, 'Player $i', 'Opponent $i', 'bot', 'rapid'),
    ];
    var currentPage = 1;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => _recordHarness(
          signedIn: true,
          records: records,
          currentPage: currentPage,
          totalPage: 4,
          totalCount: 32,
          sourceCounts: const {
            RecordSourceTab.all: 32,
            RecordSourceTab.local: 32,
            RecordSourceTab.lichess: 0,
            RecordSourceTab.chesscom: 0,
          },
          hasMoreRecords: currentPage < 4,
          onLoadRecordPage: (page) async {
            loadedPages.add(page);
            setState(() {
              currentPage = page;
              records = [
                for (var i = 11; i <= 20; i++)
                  _sampleRecord(i, 'Player $i', 'Opponent $i', 'bot', 'rapid'),
              ];
            });
          },
        ),
      ),
    );

    expect(find.byTooltip('All 32'), findsOneWidget);
    expect(find.byTooltip('Chessnut 32'), findsOneWidget);
    expect(find.byTooltip('All 20'), findsNothing);
    expect(find.byTooltip('Chessnut 20'), findsNothing);

    await tester
        .ensureVisible(find.byKey(const ValueKey('game-record-page-controls')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next records page'));
    await tester.pumpAndSettle();

    expect(loadedPages, [2]);
    expect(find.text('White: Player 20 / Black: Opponent 20'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(find.byTooltip('All 32'), findsOneWidget);
    expect(find.byTooltip('Chessnut 32'), findsOneWidget);
    expect(find.byTooltip('All 20'), findsNothing);
    expect(find.byTooltip('Chessnut 20'), findsNothing);
  });

  testWidgets('source tabs keep platform totals after remote selection', (
    tester,
  ) async {
    final requestedPages = <String>[];
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: [
          _sampleRecord(1, 'Local Player', 'Maia', 'bot', 'rapid'),
        ],
        sourceCounts: const {
          RecordSourceTab.all: 120,
          RecordSourceTab.local: 10,
          RecordSourceTab.lichess: 70,
          RecordSourceTab.chesscom: 40,
        },
        onSearchRemoteRecords: (filter, page, count) async {
          final chessCom = filter.mode == RecordModeFilter.chesscom;
          requestedPages.add('${chessCom ? 'chesscom' : 'lichess'}:$page');
          return GameRecordRemoteSearchResult(
            status: const ApiStatus.success(),
            records: [
              _sampleRecord(
                chessCom ? 2 : 3,
                chessCom ? 'ChessCom Player' : 'Lichess Player',
                'Opponent',
                chessCom ? 'chesscom' : 'lichess',
                'rapid',
              ),
            ],
            page: page,
            count: count,
            total: chessCom ? 43 : 76,
            totalPage: chessCom ? 5 : 8,
          );
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey('game-record-source-lichess')));
    await tester.pumpAndSettle();

    expect(find.byTooltip('All 120'), findsOneWidget);
    expect(find.byTooltip('Chessnut 10'), findsOneWidget);
    expect(find.byTooltip('Lichess 76'), findsOneWidget);
    expect(find.byTooltip('Chess.com 40'), findsOneWidget);
    expect(find.text('Page 1 of 8'), findsOneWidget);
    expect(find.byTooltip('Next records page'), findsOneWidget);
    expect(find.byTooltip('Next page'), findsNothing);

    await tester.tap(find.byTooltip('Next records page'));
    await tester.pumpAndSettle();

    expect(requestedPages, containsAllInOrder(['lichess:1', 'lichess:2']));
    expect(find.text('Page 2 of 8'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('game-record-source-chesscom')));
    await tester.pumpAndSettle();

    expect(find.byTooltip('All 120'), findsOneWidget);
    expect(find.byTooltip('Chessnut 10'), findsOneWidget);
    expect(find.byTooltip('Lichess 70'), findsOneWidget);
    expect(find.byTooltip('Chess.com 43'), findsOneWidget);
    expect(find.text('Page 1 of 5'), findsOneWidget);

    await tester.tap(find.byTooltip('Next records page'));
    await tester.pumpAndSettle();

    expect(requestedPages, containsAllInOrder(['chesscom:1', 'chesscom:2']));
    expect(find.text('Page 2 of 5'), findsOneWidget);
  });

  testWidgets(
      'Chessnut source tab searches the full archive when current page is remote-only',
      (
    tester,
  ) async {
    GameRecordFilter? capturedFilter;
    int? capturedPage;
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: [
          _sampleRecord(
              1, 'Lichess White', 'Lichess Black', 'lichess', 'rapid'),
          _sampleRecord(
              2, 'ChessCom White', 'ChessCom Black', 'chesscom', 'rapid'),
        ],
        sourceCounts: const {
          RecordSourceTab.all: 12,
          RecordSourceTab.local: 10,
          RecordSourceTab.lichess: 1,
          RecordSourceTab.chesscom: 1,
        },
        onSearchRemoteRecords: (filter, page, count) async {
          capturedFilter = filter;
          capturedPage = page;
          return GameRecordRemoteSearchResult(
            status: const ApiStatus.success(),
            records: [
              _sampleRecord(
                90,
                'Chessnut Player',
                'Stockfish',
                'bot',
                'rapid',
              ),
            ],
            page: 1,
            count: count,
            total: 10,
            totalPage: 1,
          );
        },
      ),
    );

    expect(find.byTooltip('Chessnut 10'), findsOneWidget);
    expect(
        find.text('White: Chessnut Player / Black: Stockfish'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('game-record-source-local')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(capturedFilter?.mode, RecordModeFilter.local);
    expect(capturedPage, 1);
    expect(
        find.text('White: Chessnut Player / Black: Stockfish'), findsOneWidget);
    expect(
        find.text('White: Lichess White / Black: Lichess Black'), findsNothing);
    expect(find.text('White: ChessCom White / Black: ChessCom Black'),
        findsNothing);
  });

  testWidgets('starts a Lichess history import job from game records', (
    tester,
  ) async {
    LichessHistoryImportOptions? capturedOptions;
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: [
          _sampleRecord(1, 'Chessnut Player', 'Rapid Bot', 'bot', 'rapid'),
        ],
        onStartLichessHistoryImport: (options) async {
          capturedOptions = options;
          return const ApiResult(
            ApiStatus.success(),
            data: LichessImportJob(
              jobId: 'li_test',
              playerId: 'storm123',
              status: 'completed',
              maxGames: 50,
              inserted: 48,
              skipped: 2,
              failed: 0,
              processed: 50,
              total: 50,
              progressPercent: 100,
            ),
          );
        },
      ),
    );

    await _expandRecordFilters(tester);
    await tester.tap(find.byKey(const ValueKey('game-record-import-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-record-import-lichess')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('lichess-import-player-id')),
      'storm123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('lichess-import-max-games')),
      '50',
    );
    await tester.tap(find.text('Start import'));
    await tester.pumpAndSettle();

    expect(capturedOptions?.playerId, 'storm123');
    expect(capturedOptions?.maxGames, 50);
    expect(find.text('Lichess import completed'), findsOneWidget);
    expect(
      find.text(
          '50/50 processed / 48 new / 2 skipped / 0 failed Records have been refreshed.'),
      findsOneWidget,
    );
  });

  testWidgets('shows background-friendly Lichess import progress copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: [
          _sampleRecord(1, 'Chessnut Player', 'Rapid Bot', 'bot', 'rapid'),
        ],
        onStartLichessHistoryImport: (_) async => const ApiResult(
          ApiStatus.success(),
          data: LichessImportJob(
            jobId: 'li_running',
            playerId: 'storm123',
            status: 'running',
            maxGames: 100,
            inserted: 18,
            skipped: 4,
            failed: 1,
            processed: 23,
            total: 100,
            progressPercent: 23,
          ),
        ),
      ),
    );

    await _expandRecordFilters(tester);
    await tester.tap(find.byKey(const ValueKey('game-record-import-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-record-import-lichess')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('lichess-import-player-id')),
      'storm123',
    );
    await tester.tap(find.text('Start import'));
    await tester.pumpAndSettle();

    expect(find.text('Importing Lichess history'), findsOneWidget);
    expect(
      find.text(
        '23/100 processed / 18 new / 4 skipped / 1 failed You can leave this page and refresh records later.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('result filters use the player color, not only raw PGN result', (
    tester,
  ) async {
    await tester.pumpWidget(
      _recordHarness(
        signedIn: true,
        records: const [
          GameRecord(
            pgnId: 10,
            result: '0-1',
            title: 'Opponent vs Chessnut Player',
            subtitle: 'Bot / 32 moves',
            playMode: 'bot',
            gameStep: 64,
            whiteName: 'Opponent',
            blackName: 'Chessnut Player',
            pgn: '[White "Opponent"]\n'
                '[Black "Chessnut Player"]\n'
                '[Speed "rapid"]\n\n'
                '1. e4 c5 2. Nf3 d6 0-1',
          ),
          GameRecord(
            pgnId: 11,
            result: '1-0',
            title: 'Chessnut Player vs Opponent',
            subtitle: 'Bot / 32 moves',
            playMode: 'bot',
            gameStep: 64,
            whiteName: 'Chessnut Player',
            blackName: 'Opponent',
            pgn: '[White "Chessnut Player"]\n'
                '[Black "Opponent"]\n'
                '[Speed "rapid"]\n\n'
                '1. d4 d5 2. c4 e6 1-0',
          ),
        ],
      ),
    );

    await _expandRecordFilters(tester);
    await tester.tap(find.byType(DropdownButtonFormField<RecordResultFilter>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Win').last);
    await tester.pumpAndSettle();

    expect(
        find.text('White: Opponent / Black: Chessnut Player'), findsOneWidget);
    expect(
        find.text('White: Chessnut Player / Black: Opponent'), findsOneWidget);
  });
}

Widget _recordHarness({
  required bool signedIn,
  Locale? locale = const Locale('en'),
  ChessnutLoginSession? currentSession,
  List<GameRecord> records = const [],
  bool loading = false,
  bool hasMoreRecords = false,
  bool loadingMoreRecords = false,
  int currentPage = 1,
  int totalPage = 1,
  int totalCount = 0,
  Map<RecordSourceTab, int>? sourceCounts,
  ValueChanged<String>? onNavigate,
  AnalyzeRecordCallback? onAnalyzeRecord,
  ContinueRecordCallback? onContinueRecord,
  DeleteRecordCallback? onDeleteRecord,
  EndRecordCallback? onEndRecord,
  RefreshRecordPgnCallback? onRefreshRecordPgn,
  FutureOr<void> Function()? onImportPgnFile,
  Future<void> Function()? onAutoRefreshCurrentPage,
  LoadRecordPageCallback? onLoadRecordPage,
  GameRecordRemoteSearchCallback? onSearchRemoteRecords,
  HistoryPgnFetchCallback? onFetchLichessGames,
  HistoryPgnFetchCallback? onFetchChessComGames,
  HistoryPgnBatchImportCallback? onImportHistoryPgnBatch,
  LichessHistoryImportStartCallback? onStartLichessHistoryImport,
  LichessHistoryImportStatusCallback? onCheckLichessHistoryImport,
  LichessHistoryImportCancelCallback? onCancelLichessHistoryImport,
  LichessHistoryImportStartCallback? onStartChessComHistoryImport,
  LichessHistoryImportStatusCallback? onCheckChessComHistoryImport,
  LichessHistoryImportCancelCallback? onCancelChessComHistoryImport,
  Map<String, GameAnalysisReportStatus> reportStatuses = const {},
  bool isChessnutClockDevice = false,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLanguagePreference.supportedLocales,
    localizationsDelegates: AppStrings.localizationsDelegates,
    theme: ChessnutTheme.light(),
    home: Scaffold(
      body: GameRecordScreen(
        signedIn: signedIn,
        currentSession: currentSession,
        records: records,
        sourceCounts: sourceCounts,
        loading: loading,
        hasMoreRecords: hasMoreRecords,
        loadingMoreRecords: loadingMoreRecords,
        currentPage: currentPage,
        totalPage: totalPage,
        totalCount: totalCount,
        onLoadRecordPage: onLoadRecordPage,
        onNavigate: onNavigate ?? (_) {},
        onAnalyzeRecord: onAnalyzeRecord ?? (_) {},
        onContinueRecord: onContinueRecord,
        onDeleteRecord: onDeleteRecord,
        onEndRecord: onEndRecord,
        onRefreshRecordPgn: onRefreshRecordPgn,
        onImportPgnFile: onImportPgnFile,
        onAutoRefreshCurrentPage: onAutoRefreshCurrentPage,
        onSearchRemoteRecords: onSearchRemoteRecords,
        onFetchLichessGames: onFetchLichessGames,
        onFetchChessComGames: onFetchChessComGames,
        onImportHistoryPgnBatch: onImportHistoryPgnBatch,
        onStartLichessHistoryImport: onStartLichessHistoryImport,
        onCheckLichessHistoryImport: onCheckLichessHistoryImport,
        onCancelLichessHistoryImport: onCancelLichessHistoryImport,
        onStartChessComHistoryImport: onStartChessComHistoryImport,
        onCheckChessComHistoryImport: onCheckChessComHistoryImport,
        onCancelChessComHistoryImport: onCancelChessComHistoryImport,
        reportStatuses: reportStatuses,
        isChessnutClockDevice: isChessnutClockDevice,
      ),
    ),
  );
}

Future<void> _scrollRecordListIntoView(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, -180));
  await tester.pumpAndSettle();
}

Future<void> _expandRecordFilters(WidgetTester tester) async {
  if (find
      .byType(DropdownButtonFormField<RecordResultFilter>)
      .evaluate()
      .isNotEmpty) {
    return;
  }
  await tester.tap(find.byKey(const ValueKey('game-record-filter-toggle')));
  await tester.pumpAndSettle();
}

Future<void> _chooseRecordFilter<T>(
  WidgetTester tester,
  ValueKey<String> key,
  String label,
) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

GameRecord _sampleRecord(
  int id,
  String white,
  String black,
  String mode,
  String speed,
) {
  return GameRecord(
    pgnId: id,
    result: '1-0',
    title: '$black vs $white',
    subtitle: '$mode / 32 moves',
    playMode: mode,
    gameStep: 64,
    winId: 1,
    whiteName: white,
    blackName: black,
    pgn: '[White "$white"]\n'
        '[Black "$black"]\n'
        '[Speed "$speed"]\n'
        '[ECO "C50"]\n'
        '[Opening "Italian Game"]\n\n'
        '1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 1-0',
  );
}
