import 'package:flutter_test/flutter_test.dart';

import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/services/android_home_widget_service.dart';
import 'package:chessnut_flutter_export/services/physical_board_gateway.dart';

void main() {
  test('widget snapshot keeps play now primary while exposing recent game', () {
    const record = GameRecord(
      result: '*',
      title: 'Maia 1500',
      subtitle: '10+5',
      pgn: '''
[Event "Bot"]
[White "Player"]
[Black "Maia"]
[Result "*"]

1. e4 *
''',
      pgnId: 42,
      playMode: 'bot',
      gameStatus: 1,
      winId: 0,
    );

    final snapshot = ChessnutHomeWidgetSnapshot.fromAppState(
      boardConnected: true,
      boardModel: ChessnutBoardModel.airPlus,
      boardBatteryStatus: const BoardBatteryStatus(
        level: 41,
        isCharging: false,
      ),
      continueRecord: record,
      visionEnabled: true,
    );

    expect(snapshot.primaryLabel, 'Play Now');
    expect(snapshot.primaryAction, ChessnutHomeWidgetAction.playNow);
    expect(snapshot.boardLabel, 'Chessnut Air Plus');
    expect(snapshot.boardState, ChessnutHomeWidgetBoardState.connected);
    expect(snapshot.batteryBars, 3);
    expect(snapshot.batteryLabel, 'Battery 3/5');
    expect(snapshot.visionEnabled, isTrue);
    expect(snapshot.recentLabel, 'Maia 1500');
  });

  test('widget snapshot routes offline board status to connect board', () {
    final snapshot = ChessnutHomeWidgetSnapshot.fromAppState(
      boardConnected: false,
      boardModel: ChessnutBoardModel.unknown,
      boardBatteryStatus: null,
      continueRecord: null,
      visionEnabled: false,
    );

    expect(snapshot.primaryLabel, 'Play Now');
    expect(snapshot.primaryAction, ChessnutHomeWidgetAction.playNow);
    expect(snapshot.boardLabel, 'Board offline');
    expect(snapshot.boardAction, ChessnutHomeWidgetAction.connectBoard);
    expect(snapshot.boardState, ChessnutHomeWidgetBoardState.offline);
    expect(snapshot.batteryBars, 0);
    expect(snapshot.batteryLabel, 'No battery');
    expect(snapshot.recentLabel, 'No active game');
  });

  test('widget snapshot marks low battery without showing percentage', () {
    final snapshot = ChessnutHomeWidgetSnapshot.fromAppState(
      boardConnected: true,
      boardModel: ChessnutBoardModel.move,
      boardBatteryStatus: const BoardBatteryStatus(
        level: 7,
        isCharging: false,
      ),
      continueRecord: null,
      visionEnabled: false,
    );

    expect(snapshot.boardState, ChessnutHomeWidgetBoardState.lowBattery);
    expect(snapshot.batteryBars, 1);
    expect(snapshot.batteryLabel, 'Low battery');
    expect(snapshot.toJson()['batteryLabel'], isNot(contains('%')));
  });
}
