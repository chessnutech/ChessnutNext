import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chessnut_flutter_export/l10n/app_language.dart';
import 'package:chessnut_flutter_export/l10n/app_strings.dart';
import 'package:chessnut_flutter_export/screens/analysis_screen.dart';
import 'package:chessnut_flutter_export/services/board_settings_service.dart';
import 'package:chessnut_flutter_export/services/chessnut_api_client.dart';
import 'package:chessnut_flutter_export/services/game_notation_service.dart';
import 'package:chessnut_flutter_export/services/physical_board_gateway.dart';
import 'package:chessnut_flutter_export/services/physical_board_protocol.dart';
import 'package:chessnut_flutter_export/services/stockfish_analysis_service.dart';
import 'package:chessnut_flutter_export/theme/chessnut_theme.dart';

const _analysisSyncPgn = '''
[Event "Analysis Sync"]
[Site "Chessnut App"]
[White "White"]
[Black "Black"]
[Result "*"]

1. e4 e5 *
''';

const _analysisSampleReviewPgn = '''
[Event "Chessnut Review"]
[Site "Chessnut App"]
[White "Chessnut Player"]
[Black "Opponent"]
[Result "*"]

1. e4 c5 2. Nf3 *
''';

void main() {
  testWidgets('Analysis board disables UI piece moves', (tester) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = MemoryPhysicalBoardGateway();
    await gateway.connect();
    addTearDown(gateway.dispose);
    final parsed = GameNotationService.parsePgn(_analysisSyncPgn);
    final e5Fen = parsed.moves[1].fenAfter;

    await tester.pumpWidget(_analysisTestApp(gateway));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    gateway.writes.clear();

    await tester.tap(
      find.byKey(const ValueKey('square-e7')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('square-e5')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final e5Square = tester.widget<Semantics>(
      find.byKey(const ValueKey('square-e5')),
    );
    final e7Square = tester.widget<Semantics>(
      find.byKey(const ValueKey('square-e7')),
    );
    expect(e5Square.properties.label, contains('empty'));
    expect(e7Square.properties.label, contains('bp'));

    expect(
      gateway.writes.any(
        (write) =>
            listEquals(write, ChessnutMoveBoardCodec.setBoardCommand(e5Fen)),
      ),
      isFalse,
    );
  });

  testWidgets('Analysis board restores mismatched Move board positions',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = MemoryPhysicalBoardGateway();
    await gateway.connect();
    addTearDown(gateway.dispose);
    final parsed = GameNotationService.parsePgn(_analysisSyncPgn);
    final e4Fen = parsed.moves[0].fenAfter;
    final startFen = parsed.initialFen;

    await tester.pumpWidget(_analysisTestApp(gateway));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    gateway.writes.clear();

    gateway.addBoardFen(_boardOnlyFen(startFen));
    gateway.addBoardFen(_boardOnlyFen(startFen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final redMismatchCommand = ChessnutMoveLedCodec.commandFromSquares({
      'e2': ChessnutMoveLedColor.red,
      'e4': ChessnutMoveLedColor.red,
    });
    expect(
      gateway.writes.any((write) => listEquals(write, redMismatchCommand)),
      isTrue,
    );
    expect(
      gateway.writes.any(
        (write) =>
            listEquals(write, ChessnutMoveBoardCodec.setBoardCommand(e4Fen)),
      ),
      isTrue,
    );
  });

  testWidgets('Analysis board ignores physical board attempts to advance ply',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = MemoryPhysicalBoardGateway();
    await gateway.connect();
    addTearDown(gateway.dispose);
    final parsed = GameNotationService.parsePgn(_analysisSyncPgn);
    final e4Fen = parsed.moves[0].fenAfter;
    final e5Fen = parsed.moves[1].fenAfter;

    await tester.pumpWidget(_analysisTestApp(gateway));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    gateway.writes.clear();

    gateway.addBoardFen(_boardOnlyFen(e5Fen));
    gateway.addBoardFen(_boardOnlyFen(e5Fen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final e5Square = tester.widget<Semantics>(
      find.byKey(const ValueKey('square-e5')),
    );
    expect(e5Square.properties.label, contains('empty'));
    expect(
      gateway.writes.any(
        (write) =>
            listEquals(write, ChessnutMoveBoardCodec.setBoardCommand(e4Fen)),
      ),
      isTrue,
    );
  });

  testWidgets('Analysis board clears Move LEDs when board matches UI',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = MemoryPhysicalBoardGateway();
    await gateway.connect();
    addTearDown(gateway.dispose);
    final parsed = GameNotationService.parsePgn(_analysisSyncPgn);
    final e4Fen = parsed.moves[0].fenAfter;
    final startFen = parsed.initialFen;

    await tester.pumpWidget(_analysisTestApp(gateway));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    gateway.writes.clear();

    gateway.addBoardFen(_boardOnlyFen(startFen));
    gateway.addBoardFen(_boardOnlyFen(startFen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    gateway.writes.clear();

    gateway.addBoardFen(_boardOnlyFen(e4Fen));
    gateway.addBoardFen(_boardOnlyFen(e4Fen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      gateway.writes.any(
        (write) => listEquals(write, ChessnutMoveLedCodec.offCommand()),
      ),
      isTrue,
    );
  });

  testWidgets('Analysis board lights non-Move board mismatches',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.air,
    );
    await gateway.connect();
    addTearDown(gateway.dispose);
    final parsed = GameNotationService.parsePgn(_analysisSyncPgn);
    final startFen = parsed.initialFen;

    await tester.pumpWidget(_analysisTestApp(gateway));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    gateway.writes.clear();

    gateway.addBoardFen(_boardOnlyFen(startFen));
    gateway.addBoardFen(_boardOnlyFen(startFen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final expectedLedCommand =
        ChessnutLedCodec.ledCommandFromSquares({'e2', 'e4'});
    expect(
      gateway.writes.any((write) => listEquals(write, expectedLedCommand)),
      isTrue,
    );
  });

  testWidgets('Analysis board clears non-Move LEDs when board matches UI',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.air,
    );
    await gateway.connect();
    addTearDown(gateway.dispose);
    final parsed = GameNotationService.parsePgn(_analysisSyncPgn);
    final e4Fen = parsed.moves[0].fenAfter;
    final startFen = parsed.initialFen;

    await tester.pumpWidget(_analysisTestApp(gateway));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    gateway.writes.clear();

    gateway.addBoardFen(_boardOnlyFen(startFen));
    gateway.addBoardFen(_boardOnlyFen(startFen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    gateway.writes.clear();

    gateway.addBoardFen(_boardOnlyFen(e4Fen));
    gateway.addBoardFen(_boardOnlyFen(e4Fen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final clearCommand = ChessnutLedCodec.ledCommandFromSquares(const {});
    expect(
      gateway.writes.any((write) => listEquals(write, clearCommand)),
      isTrue,
    );
  });

  testWidgets('Analysis board sends EVO2 marker patterns for review markers',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.evo2,
    );
    await gateway.connect();
    addTearDown(gateway.dispose);
    await tester.pumpWidget(
      _analysisTestApp(gateway, pgn: _analysisSampleReviewPgn),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    gateway.writes.clear();
    gateway.evo2PatternKeyWrites.clear();

    final moveFinder = find.byKey(const ValueKey('analysis-san-ply-12'));
    expect(moveFinder, findsOneWidget);
    await tester.ensureVisible(moveFinder);
    await tester.pumpAndSettle();
    await tester.tap(moveFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('review-board-marker-Mistake')),
      findsOneWidget,
    );
    expect(gateway.writes, isEmpty);
    expect(gateway.evo2PatternKeyWrites, isNotEmpty);
    final keys = gateway.evo2PatternKeyWrites.last;
    expect(keys[_squareIndex('c7')], 'analysis_mistake');
    expect(
      keys.where((key) => key != null),
      hasLength(1),
    );
  });
}

Widget _analysisTestApp(
  PhysicalBoardGateway gateway, {
  String pgn = _analysisSyncPgn,
}) {
  return MaterialApp(
    theme: ChessnutTheme.light(),
    supportedLocales: AppLanguagePreference.supportedLocales,
    localizationsDelegates: AppStrings.localizationsDelegates,
    home: Scaffold(
      body: AnalysisScreen(
        onNavigate: (_) {},
        apiClient: ChessnutApiClient(
          httpClient: MockClient((request) async {
            return http.Response('not found', 404);
          }),
        ),
        positionAnalyzer: const _FastAnalyzer(),
        boardGateway: gateway,
        boardSettings: const BoardSettingsState(),
        attachedPgn: pgn,
        onStartReview: (_) {},
        onOpenLastGame: () {},
      ),
    ),
  );
}

String _boardOnlyFen(String fen) => fen.trim().split(RegExp(r'\s+')).first;

int _squareIndex(String square) {
  final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
  final rank = int.parse(square[1]);
  return (8 - rank) * 8 + file;
}

class _FastAnalyzer implements PositionAnalyzer {
  const _FastAnalyzer();

  @override
  Future<PositionEngineAnalysis?> analyzeFen(
    String fen, {
    int depth = 12,
    int multiPv = 1,
  }) async {
    return PositionEngineAnalysis(
      fen: fen,
      depth: 1,
      whiteEval: 0,
      bestMoveUci: null,
      pv: const [],
      isEngineBacked: false,
    );
  }
}
