import 'package:chessnut_flutter_export/screens/setup_screen.dart';
import 'package:chessnut_flutter_export/services/board_editor_led_feedback.dart';
import 'package:chessnut_flutter_export/services/physical_board_gateway.dart';
import 'package:chessnut_flutter_export/services/physical_board_protocol.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const emptyBoard = '8/8/8/8/8/8/8/8';
  const pawnOnE4 = '8/8/8/8/4P3/8/8/8';

  test('finds every occupied board editor square', () {
    expect(
      boardEditorOccupiedSquares('8/8/8/8/4P3/8/8/4K3'),
      {'e4', 'e1'},
    );
    expect(
      boardEditorOccupiedSquares(pawnOnE4),
      {'e4'},
    );
    expect(boardEditorOccupiedSquares('invalid'), isNull);
  });

  testWidgets('general board keeps occupied squares lit until position changes',
      (
    WidgetTester tester,
  ) async {
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.air,
    );
    addTearDown(gateway.dispose);
    await gateway.connect();
    gateway.writes.clear();
    final feedback = BoardEditorPlacementLedFeedback();

    await feedback.showPosition(
      gateway: gateway,
      boardFen: pawnOnE4,
    );

    expect(
      gateway.writes.last,
      ChessnutLedCodec.ledCommandFromSquares({'e4'}),
    );
    final writeCount = gateway.writes.length;
    await tester.pump(const Duration(seconds: 2));
    expect(gateway.writes.length, writeCount);

    await feedback.showPosition(gateway: gateway, boardFen: emptyBoard);
    expect(
      gateway.writes.last,
      ChessnutLedCodec.ledCommand(List<int>.filled(64, 0)),
    );
  });

  testWidgets('cancel does not clear LEDs the controller did not light', (
    WidgetTester tester,
  ) async {
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.air,
    );
    addTearDown(gateway.dispose);
    await gateway.connect();
    gateway.writes.clear();
    final feedback = BoardEditorPlacementLedFeedback();

    await feedback.cancel(gateway);

    expect(gateway.writes, isEmpty);
  });

  testWidgets('Chessnut Move keeps occupied squares lit green until canceled', (
    WidgetTester tester,
  ) async {
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.move,
    );
    addTearDown(gateway.dispose);
    await gateway.connect();
    gateway.writes.clear();
    final feedback = BoardEditorPlacementLedFeedback();

    await feedback.showPosition(
      gateway: gateway,
      boardFen: pawnOnE4,
    );

    expect(
      gateway.writes.last,
      ChessnutMoveLedCodec.commandFromSquares({
        'e4': ChessnutMoveLedColor.green,
      }),
    );
    final writeCount = gateway.writes.length;
    await tester.pump(const Duration(seconds: 2));
    expect(gateway.writes.length, writeCount);

    await feedback.cancel(gateway);
    expect(
      listEquals(gateway.writes.last, ChessnutMoveLedCodec.offCommand()),
      isTrue,
    );
  });

  testWidgets('bot and OTB editor confirms a physical piece placement', (
    WidgetTester tester,
  ) async {
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.air,
    );
    addTearDown(gateway.dispose);
    await gateway.connect();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BotBoardEditorSheet(
            initialFen: '$emptyBoard w - - 0 1',
            openInFenMode: false,
            boardGateway: gateway,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    gateway.writes.clear();

    gateway.addBoardFen(emptyBoard);
    gateway.addBoardFen(emptyBoard);
    await tester.pump();
    gateway.addBoardFen(pawnOnE4);
    gateway.addBoardFen(pawnOnE4);
    await tester.pump();

    expect(
      gateway.writes.any(
        (write) => listEquals(
          write,
          ChessnutLedCodec.ledCommandFromSquares({'e4'}),
        ),
      ),
      isTrue,
    );
  });

  testWidgets('bot and OTB editor waits for a fresh FEN before setup LEDs', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = MemoryPhysicalBoardGateway(
      boardModel: PhysicalBoardModel.air,
    );
    addTearDown(gateway.dispose);
    await gateway.connect();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BotBoardEditorSheet(
            initialFen: '4k3/8/8/8/4P3/8/8/4K3 w - - 0 1',
            openInFenMode: true,
            boardGateway: gateway,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    gateway.writes.clear();

    final sendButton = find.text('Send FEN to board');
    await tester.ensureVisible(sendButton);
    await tester.tap(sendButton);
    await tester.pumpAndSettle();

    expect(
      gateway.writes.last,
      ChessnutLedCodec.ledCommand(List<int>.filled(64, 0)),
    );

    gateway.addBoardFen('4k3/8/8/8/8/8/8/4K3');
    gateway.addBoardFen('4k3/8/8/8/8/8/8/4K3');
    await tester.pump();

    expect(gateway.writes.last, ChessnutLedCodec.ledCommandFromSquares({'e4'}));
  });
}
