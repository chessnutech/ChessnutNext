import 'package:chessnut_flutter_export/screens/board_analyzer_screen.dart';
import 'package:chessnut_flutter_export/services/stockfish_analysis_service.dart';
import 'package:chessnut_flutter_export/theme/chessnut_theme.dart';
import 'package:chessnut_flutter_export/widgets/chess_board.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Board analyzer depth settings support 6-20 and unlimited', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final analyzer = _DepthRecordingAnalyzer();
    await tester.pumpWidget(
      MaterialApp(
        theme: ChessnutTheme.light(),
        home: Scaffold(
          body: BoardAnalyzerScreen(
            onNavigate: (_) {},
            positionAnalyzer: analyzer,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(analyzer.depths, [12]);

    await tester.tap(
      find.byKey(const ValueKey('board-analyzer-depth-settings')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Unlimited'), findsWidgets);

    await tester.tap(find.byType(Switch).last);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Done'));
    await tester.pump(const Duration(milliseconds: 300));

    // Non-streaming injected analyzers use depth 20 as a bounded fallback.
    expect(analyzer.depths, [12, 20]);
  });

  testWidgets('Windows landscape keeps the full analyzer board visible', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: ChessnutTheme.light(),
          home: Scaffold(
            body: BoardAnalyzerScreen(
              onNavigate: (_) {},
              positionAnalyzer: const _StaticAnalyzer(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final layout = tester.getRect(
        find.byKey(const ValueKey('board-analyzer-windows-landscape')),
      );
      final board = tester.getRect(find.byType(InteractiveChessBoard));
      final rightPanel = tester.getRect(
        find.byKey(const ValueKey('board-analyzer-windows-right-scroll')),
      );

      expect(board.width, moreOrLessEquals(board.height, epsilon: 2));
      expect(board.top, greaterThanOrEqualTo(layout.top));
      expect(board.bottom, lessThanOrEqualTo(layout.bottom));
      expect(rightPanel.top, layout.top);
      expect(rightPanel.bottom, layout.bottom);
      expect(board.height, lessThan(700));
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

class _DepthRecordingAnalyzer implements PositionAnalyzer {
  final List<int> depths = <int>[];

  @override
  Future<PositionEngineAnalysis?> analyzeFen(
    String fen, {
    int depth = 12,
    int multiPv = 1,
  }) async {
    depths.add(depth);
    return PositionEngineAnalysis(
      fen: fen,
      depth: depth,
      whiteEval: 0,
      bestMoveUci: 'e2e4',
      pv: const ['e2e4'],
      isEngineBacked: true,
    );
  }
}

class _StaticAnalyzer implements PositionAnalyzer {
  const _StaticAnalyzer();

  @override
  Future<PositionEngineAnalysis?> analyzeFen(
    String fen, {
    int depth = 12,
    int multiPv = 1,
  }) async {
    return PositionEngineAnalysis(
      fen: fen,
      depth: depth,
      whiteEval: 0.35,
      bestMoveUci: 'e2e4',
      pv: const ['e2e4', 'e7e5'],
      isEngineBacked: true,
      candidateMoves: const [
        EngineMoveCandidate(moveUci: 'e2e4', scoreCentipawns: 35),
        EngineMoveCandidate(moveUci: 'd2d4', scoreCentipawns: 21),
        EngineMoveCandidate(moveUci: 'g1f3', scoreCentipawns: 20),
      ],
    );
  }
}
