import 'package:chessnut_flutter_export/l10n/localized_material.dart'
    as localized;
import 'package:chessnut_flutter_export/screens/board_editor_screen.dart';
import 'package:chessnut_flutter_export/screens/setup_screen.dart';
import 'package:chessnut_flutter_export/widgets/board_editor_en_passant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('board editor en passant options', () {
    test('finds a legal white en passant target', () {
      const fen = '4k3/8/8/3pP3/8/8/8/4K3 w - - 0 1';

      expect(legalBoardEditorEnPassantSquares(fen), ['d6']);
    });

    test('finds a legal black en passant target', () {
      const fen = '4k3/8/8/8/3pP3/8/8/4K3 b - - 0 1';

      expect(legalBoardEditorEnPassantSquares(fen), ['e3']);
    });

    test('offers both adjacent targets when both captures are legal', () {
      const fen = '4k3/8/8/3pPp2/8/8/8/4K3 w - - 0 1';

      expect(legalBoardEditorEnPassantSquares(fen), ['d6', 'f6']);
    });

    test('does not offer an en passant move from a pinned pawn', () {
      const fen = '4r1k1/8/8/3pP3/8/8/8/4K3 w - - 0 1';

      expect(legalBoardEditorEnPassantSquares(fen), isEmpty);
    });

    test('reads and replaces the FEN en passant field', () {
      const fen = '4k3/8/8/3pPp2/8/8/8/4K3 w - d6 7 12';

      expect(boardEditorEnPassantSquareFromFen(fen), 'd6');
      expect(
        boardEditorFenWithEnPassant(fen, 'f6'),
        '4k3/8/8/3pPp2/8/8/8/4K3 w - f6 7 12',
      );
      expect(
        boardEditorFenWithEnPassant(fen, 'a6'),
        '4k3/8/8/3pPp2/8/8/8/4K3 w - - 7 12',
      );
    });
  });

  testWidgets('standalone board editor exposes the en passant control', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardEditorScreen(onNavigate: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('board-editor-en-passant-field')),
      findsOneWidget,
    );
  });

  testWidgets('bot and OTB editor imports and changes en passant target', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BotBoardEditorSheet(
            initialFen: '4k3/8/8/3pPp2/8/8/8/4K3 w - d6 0 1',
            openInFenMode: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byKey(
      const ValueKey('bot-board-editor-en-passant-field'),
    );
    expect(field, findsOneWidget);
    expect(
      tester.widget<localized.DropdownButtonFormField<String>>(field).value,
      'd6',
    );

    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text('f6').last);
    await tester.pumpAndSettle();

    final fenField = tester.widget<localized.TextField>(
      find.byKey(const ValueKey('bot-board-editor-fen-field')),
    );
    expect(fenField.controller?.text.split(RegExp(r'\s+'))[3], 'f6');
  });
}
