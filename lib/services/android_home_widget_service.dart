import 'package:flutter/services.dart';

import '../models/app_models.dart';
import 'physical_board_gateway.dart';

enum ChessnutHomeWidgetAction {
  playNow,
  continueGame,
  connectBoard,
  boardSettings,
  records,
  openApp,
  toggleVision,
}

enum ChessnutHomeWidgetBoardState {
  offline,
  connected,
  lowBattery,
  charging,
}

class ChessnutHomeWidgetSnapshot {
  const ChessnutHomeWidgetSnapshot({
    required this.primaryLabel,
    required this.primaryAction,
    required this.boardLabel,
    required this.boardAction,
    required this.boardState,
    required this.batteryBars,
    required this.batteryLabel,
    required this.recentLabel,
    required this.visionEnabled,
  });

  final String primaryLabel;
  final ChessnutHomeWidgetAction primaryAction;
  final String boardLabel;
  final ChessnutHomeWidgetAction boardAction;
  final ChessnutHomeWidgetBoardState boardState;
  final int batteryBars;
  final String batteryLabel;
  final String recentLabel;
  final bool visionEnabled;

  factory ChessnutHomeWidgetSnapshot.fromAppState({
    required bool boardConnected,
    required ChessnutBoardModel boardModel,
    required BoardBatteryStatus? boardBatteryStatus,
    required GameRecord? continueRecord,
    required bool visionEnabled,
  }) {
    final hasContinue = continueRecord?.canContinueGame ?? false;
    final boardState = _boardState(boardConnected, boardBatteryStatus);
    return ChessnutHomeWidgetSnapshot(
      primaryLabel: 'Play Now',
      primaryAction: ChessnutHomeWidgetAction.playNow,
      boardLabel: boardConnected ? boardModel.displayName : 'Board offline',
      boardAction: boardConnected
          ? ChessnutHomeWidgetAction.boardSettings
          : ChessnutHomeWidgetAction.connectBoard,
      boardState: boardState,
      batteryBars: boardBatteryStatus?.bars ?? 0,
      batteryLabel: _batteryLabel(boardBatteryStatus),
      recentLabel: hasContinue ? continueRecord!.title : 'No active game',
      visionEnabled: visionEnabled,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'primaryLabel': primaryLabel,
      'primaryAction': primaryAction.name,
      'boardLabel': boardLabel,
      'boardAction': boardAction.name,
      'boardState': boardState.name,
      'batteryBars': batteryBars,
      'batteryLabel': batteryLabel,
      'recentLabel': recentLabel,
      'visionEnabled': visionEnabled,
    };
  }

  static ChessnutHomeWidgetBoardState _boardState(
    bool boardConnected,
    BoardBatteryStatus? battery,
  ) {
    if (!boardConnected) return ChessnutHomeWidgetBoardState.offline;
    if (battery?.isLow ?? false) return ChessnutHomeWidgetBoardState.lowBattery;
    if (battery?.isCharging ?? false) {
      return ChessnutHomeWidgetBoardState.charging;
    }
    return ChessnutHomeWidgetBoardState.connected;
  }

  static String _batteryLabel(BoardBatteryStatus? battery) {
    if (battery == null) return 'No battery';
    if (battery.isLow) return 'Low battery';
    if (battery.isCharging) return 'Charging ${battery.bars}/5';
    return 'Battery ${battery.bars}/5';
  }
}

class ChessnutHomeWidgetLaunchAction {
  const ChessnutHomeWidgetLaunchAction({
    required this.action,
    this.visionEnabled,
  });

  final ChessnutHomeWidgetAction action;
  final bool? visionEnabled;

  factory ChessnutHomeWidgetLaunchAction.fromJson(Map<dynamic, dynamic> json) {
    final action =
        _actionByName(json['action']) ?? ChessnutHomeWidgetAction.openApp;
    final vision = json['visionEnabled'];
    return ChessnutHomeWidgetLaunchAction(
      action: action,
      visionEnabled: vision is bool ? vision : null,
    );
  }
}

class AndroidHomeWidgetService {
  const AndroidHomeWidgetService();

  static const MethodChannel _channel = MethodChannel('chessnut/home_widget');

  Future<void> syncSnapshot(ChessnutHomeWidgetSnapshot snapshot) async {
    try {
      await _channel.invokeMethod<void>('syncSnapshot', snapshot.toJson());
    } on MissingPluginException {
      // Android home widgets are unavailable on desktop and test hosts.
    }
  }

  Future<ChessnutHomeWidgetLaunchAction?> consumeLaunchAction() async {
    try {
      final raw = await _channel.invokeMapMethod<dynamic, dynamic>(
        'consumeLaunchAction',
      );
      if (raw == null) return null;
      return ChessnutHomeWidgetLaunchAction.fromJson(raw);
    } on MissingPluginException {
      return null;
    }
  }

  Future<bool?> readVisionEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('readVisionEnabled');
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> setVisionEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setVisionEnabled', {
        'enabled': enabled,
      });
    } on MissingPluginException {
      // Android home widgets are unavailable on desktop and test hosts.
    }
  }
}

ChessnutHomeWidgetAction? _actionByName(Object? value) {
  final name = value?.toString();
  if (name == null) return null;
  for (final action in ChessnutHomeWidgetAction.values) {
    if (action.name == name) return action;
  }
  return null;
}
