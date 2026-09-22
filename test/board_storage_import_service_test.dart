import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/services/board_storage_import_service.dart';
import 'package:chessnut_flutter_export/services/chessnut_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses EasyLink board storage FEN sequence into PGN', () {
    final record = BoardStorageImportService.parseStoredGame(
      rawFenSequence: [
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
        'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR',
        'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR',
      ].join(';'),
      importedAt: DateTime(2026, 6, 13),
    );

    expect(record.isImportable, isTrue);
    expect(record.pgn, contains('[Event "Chessnut Board Storage"]'));
    expect(record.pgn, contains('[Source "Board storage"]'));
    expect(record.pgn, contains('1. e4 e5 *'));
    expect(record.gameStep, 2);
    expect(record.whiteName, 'White');
    expect(record.blackName, 'Black');
    expect(record.importKey, startsWith('board-storage:'));
  });

  test('parses board storage FEN sequence when black moved first', () {
    final record = BoardStorageImportService.parseStoredGame(
      rawFenSequence: [
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
        'rnbqkbnr/pppp1ppp/8/4p3/8/8/PPPPPPPP/RNBQKBNR',
        'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR',
      ].join(';'),
      importedAt: DateTime(2026, 6, 13),
    );

    expect(record.isImportable, isTrue);
    expect(record.pgn, contains('[FEN "'));
    expect(record.pgn, contains('1. e5 e4 *'));
    expect(record.gameStep, 2);
  });

  test('parses board storage FEN sequence when board orientation is reversed',
      () {
    final record = BoardStorageImportService.parseStoredGame(
      rawFenSequence: [
        'RNBKQBNR/PPPPPPPP/8/8/8/8/pppppppp/rnbkqbnr',
        'RNBKQBNR/PPP1PPPP/8/3P4/8/8/pppppppp/rnbkqbnr',
        'RNBKQBNR/PPP1PPPP/8/3P4/3p4/8/ppp1pppp/rnbkqbnr',
      ].join(';'),
      importedAt: DateTime(2026, 6, 13),
    );

    expect(record.isImportable, isTrue);
    expect(record.pgn, contains('1. e4 e5 *'));
    expect(record.gameStep, 2);
  });

  test('rejects storage sequence when a FEN transition is not legal', () {
    final record = BoardStorageImportService.parseStoredGame(
      rawFenSequence: [
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
      ].join(';'),
    );

    expect(record.isImportable, isFalse);
    expect(record.errorMessage, contains('no positions'));
  });

  test('parses Move board storage PGN into importable OTB record', () {
    final record = BoardStorageImportService.parseStoredGame(
      rawFenSequence: '''
[Event "Move OTB"]
[Site "Chessnut Move"]
[Date "2026.06.13"]
[Round "-"]
[White "Kyle"]
[Black "Board"]
[Result "*"]

1. e4 e5 *
''',
      importedAt: DateTime(2026, 6, 13),
    );

    expect(record.isImportable, isTrue);
    expect(record.pgn, contains('[Event "Move OTB"]'));
    expect(record.pgn, contains('[Source "Board storage"]'));
    expect(record.pgn, contains('[BoardStorageHash "'));
    expect(record.pgn, contains('1. e4 e5 *'));
    expect(record.whiteName, 'Kyle');
    expect(record.blackName, 'Board');
    expect(record.gameStep, 2);
  });

  test('marks stored games that already exist in Game Record as duplicates',
      () async {
    final parsed = BoardStorageImportService.parseStoredGame(
      rawFenSequence: [
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
        'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR',
        'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR',
      ].join(';'),
    );
    final service = BoardStorageImportService(
      apiClient: _FakeApiClient(),
      recordsProvider: () async => [
        GameRecord(
          result: '*',
          title: 'Existing',
          subtitle: 'OTB',
          pgn: parsed.pgn,
          playMode: 'otb',
        ),
      ],
    );

    final preview = await service.previewStoredGames(
      [parsed.rawFenSequence],
    );

    expect(preview.items.single.duplicate, isTrue);
    expect(preview.importableCount, 0);
  });

  test('imports only non-duplicate board storage games as OTB records',
      () async {
    final uploaded = <_UploadCall>[];
    final parsed = BoardStorageImportService.parseStoredGame(
      rawFenSequence: [
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
        'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR',
        'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR',
      ].join(';'),
      importedAt: DateTime(2026, 6, 13),
    );
    final service = BoardStorageImportService(
      apiClient: _FakeApiClient(
        onUpload: uploaded.add,
      ),
      recordsProvider: () async => const [],
    );

    final result = await service.importParsed([parsed]);

    expect(result.importedCount, 1);
    expect(result.skippedCount, 0);
    expect(uploaded.single.playMode, 'otb');
    expect(uploaded.single.gameStatus, 2);
    expect(uploaded.single.gameStep, 2);
    expect(uploaded.single.pgn, contains('[BoardStorageHash "'));
  });

  test('imports every non-duplicate parsed board storage game', () async {
    final uploaded = <_UploadCall>[];
    final first = BoardStorageImportService.parseStoredGame(
      rawFenSequence: [
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
        'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR',
      ].join(';'),
    );
    final second = BoardStorageImportService.parseStoredGame(
      rawFenSequence: [
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
        'rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR',
      ].join(';'),
    );
    final service = BoardStorageImportService(
      apiClient: _FakeApiClient(onUpload: uploaded.add),
      recordsProvider: () async => const [],
    );

    final result = await service.importParsed([first, second]);

    expect(result.importedCount, 2);
    expect(result.skippedCount, 0);
    expect(uploaded, hasLength(2));
  });
}

class _UploadCall {
  const _UploadCall({
    required this.pgn,
    required this.playMode,
    required this.gameStatus,
    required this.gameStep,
  });

  final String pgn;
  final String playMode;
  final int gameStatus;
  final int gameStep;
}

class _FakeApiClient extends ChessnutApiClient {
  _FakeApiClient({this.onUpload});

  final void Function(_UploadCall call)? onUpload;

  @override
  Future<ApiResult<UploadPgnResult>> uploadPgn({
    required String pgn,
    required String whiteName,
    required String blackName,
    required String playTime,
    required String playMode,
    int winId = 0,
    int gameStatus = 1,
    int gameStep = 0,
    PgnSaveMetadata metadata = const PgnSaveMetadata(),
  }) async {
    onUpload?.call(
      _UploadCall(
        pgn: pgn,
        playMode: playMode,
        gameStatus: gameStatus,
        gameStep: gameStep,
      ),
    );
    return const ApiResult(
      ApiStatus.success(),
      data: UploadPgnResult(pgnId: 42, shareId: 'board-storage-share'),
    );
  }
}
