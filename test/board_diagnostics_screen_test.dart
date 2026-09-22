import 'dart:async';

import 'package:chessnut_flutter_export/screens/board_diagnostics_screen.dart';
import 'package:chessnut_flutter_export/services/physical_board_gateway.dart';
import 'package:chessnut_flutter_export/services/physical_board_protocol.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('diagnostics page can connect and run general board commands',
      (tester) async {
    tester.view.physicalSize = const Size(1180, 980);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final transport = FakePhysicalBoardTransport(
      model: PhysicalBoardModel.general,
    );
    final gateway = ChessnutBoardGateway(transport: transport);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardDiagnosticsScreen(
            onNavigate: (_) {},
            gateway: gateway,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Connect'));
    await tester.pump();
    await tester.tap(find.text('Realtime FEN'));
    await tester.tap(find.text('Battery'));
    await tester.tap(find.text('BLE version'));
    await tester.tap(find.text('LED e4'));
    await tester.pump();

    expect(transport.writes[0], ChessnutGeneralCommands.enableRealtimeFen);
    expect(transport.writes[1], ChessnutGeneralCommands.batteryStatus);
    expect(transport.writes[2], ChessnutGeneralCommands.bleVersion);
    expect(transport.writes[3].first, 0x0a);
  });

  testWidgets('diagnostics page exposes Move-specific commands',
      (tester) async {
    tester.view.physicalSize = const Size(1180, 980);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final transport =
        FakePhysicalBoardTransport(model: PhysicalBoardModel.move);
    final gateway = ChessnutBoardGateway(transport: transport);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardDiagnosticsScreen(
            onNavigate: (_) {},
            gateway: gateway,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Connect'));
    await tester.pump();
    await tester.ensureVisible(find.text('Move piece status'));
    await tester.tap(find.text('Move piece status'));
    await tester.ensureVisible(find.text('Move RGB e4'));
    await tester.tap(find.text('Move RGB e4'));
    final sendFen = find.byKey(const ValueKey('diagnostics-send-fen'));
    await tester.ensureVisible(sendFen);
    await tester.tap(sendFen);
    await tester.pump();

    expect(transport.writes[0], ChessnutMoveCommands.pieceStatus);
    expect(transport.writes[1].first, 0x43);
    expect(transport.writes[2].first, 0x42);
  });
}

class FakePhysicalBoardTransport implements PhysicalBoardTransport {
  FakePhysicalBoardTransport({required this.model});

  final PhysicalBoardModel model;
  final stateController =
      StreamController<PhysicalBoardConnectionState>.broadcast();
  final fenController = StreamController<List<int>>.broadcast();
  final responseController = StreamController<List<int>>.broadcast();
  final writes = <List<int>>[];

  @override
  PhysicalBoardModel get boardModel => model;

  @override
  PhysicalBoardConnectionState currentState =
      PhysicalBoardConnectionState.disconnected;

  @override
  Stream<PhysicalBoardConnectionState> get stateStream =>
      stateController.stream;

  @override
  Stream<List<int>> get fenPayloadStream => fenController.stream;

  @override
  Stream<List<int>> get filePayloadStream => const Stream.empty();

  @override
  Stream<List<int>> get responseStream => responseController.stream;

  @override
  Future<bool> connect() async {
    currentState = PhysicalBoardConnectionState.connected;
    stateController.add(PhysicalBoardConnectionState.connected);
    return true;
  }

  @override
  Future<void> disconnect() async {
    currentState = PhysicalBoardConnectionState.disconnected;
    stateController.add(PhysicalBoardConnectionState.disconnected);
  }

  @override
  Future<bool> write(List<int> command, {bool withoutResponse = false}) async {
    writes.add(List<int>.unmodifiable(command));
    return true;
  }
}
