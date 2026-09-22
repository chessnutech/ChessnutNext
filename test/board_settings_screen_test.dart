import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chessnut_flutter_export/l10n/app_language.dart';
import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/screens/board_settings_screen.dart';
import 'package:chessnut_flutter_export/services/board_settings_service.dart';
import 'package:chessnut_flutter_export/services/board_storage_import_service.dart';
import 'package:chessnut_flutter_export/services/chessnut_api_client.dart';
import 'package:chessnut_flutter_export/services/physical_board_gateway.dart';
import 'package:chessnut_flutter_export/services/physical_board_protocol.dart';
import 'package:chessnut_flutter_export/services/screen_wake_lock_service.dart';
import 'package:chessnut_flutter_export/theme/chessnut_theme.dart';

void main() {
  testWidgets('shows piece management only for Chessnut Move', (tester) async {
    final moveNavigations = <String>[];
    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.move,
        onNavigate: moveNavigations.add,
      ),
    );

    expect(find.text('Pieces'), findsOneWidget);
    expect(find.text('Move restore'), findsOneWidget);
    expect(find.text('Allow flip board'), findsOneWidget);
    expect(find.text('Auto flip board'), findsOneWidget);
    expect(find.text('Allow takeback'), findsNothing);
    expect(find.text('Allow flip'), findsNothing);
    expect(find.text('Firmware'), findsOneWidget);
    expect(find.text('Buzzer'), findsNothing);
    expect(find.text('Buzzer master switch'), findsNothing);
    expect(find.text('Event sounds'), findsNothing);
    expect(find.text('Connect beep'), findsNothing);
    expect(find.text('Start game beep'), findsNothing);
    expect(find.text('Checkmate beep'), findsNothing);
    expect(find.text('Board Editor'), findsNothing);
    expect(find.text('Clock key'), findsNothing);
    expect(find.text('Clock Switch'), findsNothing);

    await tester.ensureVisible(find.text('Pieces'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pieces'));
    await tester.pumpAndSettle();
    expect(moveNavigations, contains('Pieces'));

    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.air,
        onNavigate: (_) {},
      ),
    );

    expect(find.text('Pieces'), findsNothing);
    expect(find.text('Move restore'), findsNothing);
    expect(find.text('Firmware'), findsNothing);
    expect(find.text('Buzzer'), findsOneWidget);
    expect(find.text('Buzzer master switch'), findsOneWidget);
    expect(find.text('Start game beep'), findsNothing);
    expect(find.text('Allow flip board'), findsOneWidget);
    expect(find.text('Auto flip board'), findsOneWidget);
    expect(find.text('Allow takeback'), findsNothing);
    expect(find.text('Board Editor'), findsNothing);
    expect(find.text('Move quality lights'), findsNothing);
    expect(find.text('Clock Switch'), findsNothing);
  });

  testWidgets('updates board flip settings and gates auto flip',
      (tester) async {
    final changes = <BoardSettingsState>[];
    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.air,
        onNavigate: (_) {},
        onSettingsChanged: changes.add,
      ),
    );

    await tester.ensureVisible(find.text('Allow flip board'));
    await tester.pumpAndSettle();
    final allowFlipTile = find.byTooltip('Allow flip board');
    final allowFlipSwitch = find.descendant(
      of: allowFlipTile,
      matching: find.byType(Switch),
    );
    await tester.tap(allowFlipSwitch);
    await tester.pumpAndSettle();

    expect(changes.last.allowFlip, isFalse);
    expect(changes.last.autoFlip, isTrue);
    final disabledAutoFlipTile =
        find.byTooltip('Enable Allow flip board first.');
    expect(disabledAutoFlipTile, findsOneWidget);
    final autoFlipSwitch = find.descendant(
      of: disabledAutoFlipTile,
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(autoFlipSwitch).onChanged, isNull);
  });

  testWidgets('Chessnut Clock switch cards expand for large system text',
      (tester) async {
    tester.view.physicalSize = const Size(854, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.air,
        onNavigate: (_) {},
        isChessnutClockDevice: true,
        textScaler: const TextScaler.linear(2),
      ),
    );

    await tester.ensureVisible(find.text('Auto flip board'));
    await tester.pumpAndSettle();

    final allowTile = find.byTooltip('Allow flip board');
    final autoTile = find.byTooltip('Auto flip board');
    final allowRect = tester.getRect(allowTile);
    final autoRect = tester.getRect(autoTile);
    final autoSubtitleRect = tester.getRect(
      find.text('Detect physical board orientation from the current FEN.'),
    );

    expect(autoRect.top, greaterThanOrEqualTo(allowRect.bottom + 7));
    expect(autoSubtitleRect.bottom, lessThanOrEqualTo(autoRect.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides physical board connection controls for EVO2',
      (tester) async {
    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.evo2,
        onNavigate: (_) {},
        hidePhysicalBoardConnectionUi: true,
      ),
    );

    expect(find.byKey(const ValueKey('board-settings-hero')), findsNothing);
    expect(find.text('Move restore'), findsNothing);
    expect(find.text('Disconnect board'), findsNothing);
    expect(find.text('Buzzer'), findsNothing);
    expect(find.text('Event sounds'), findsNothing);
    expect(find.text('Saved games'), findsNothing);
    expect(find.text('Move delay'), findsOneWidget);
    expect(find.text('LED brightness'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('EVO2 piece LED patterns'), findsOneWidget);
    expect(find.text('Analysis marker LED patterns'), findsOneWidget);
  });

  testWidgets('updates EVO2 LED brightness from Board settings',
      (tester) async {
    final updates = <BoardSettingsState>[];
    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.evo2,
        onNavigate: (_) {},
        onSettingsChanged: updates.add,
        hidePhysicalBoardConnectionUi: true,
      ),
    );

    final slider = find.descendant(
      of: find.byKey(const ValueKey('evo2-led-brightness-slider')),
      matching: find.byType(Slider),
    );
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    await tester.drag(slider, const Offset(-120, 0));
    await tester.pumpAndSettle();

    expect(updates, isNotEmpty);
    expect(updates.last.evo2LedBrightness, lessThan(100));
  });

  testWidgets('lays out EVO2 LED patterns by piece color', (tester) async {
    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.evo2,
        onNavigate: (_) {},
        hidePhysicalBoardConnectionUi: true,
      ),
    );

    final whiteGrid = find.byKey(const ValueKey(
      'evo2-led-pattern-white-grid',
    ));
    final blackGrid = find.byKey(const ValueKey(
      'evo2-led-pattern-black-grid',
    ));
    final blankTile = find.byKey(const ValueKey(
      'evo2-led-pattern-blank-tile',
    ));
    final analysisGrid = find.byKey(const ValueKey(
      'evo2-led-pattern-analysis-grid',
    ));

    expect(whiteGrid, findsOneWidget);
    expect(blackGrid, findsOneWidget);
    expect(blankTile, findsOneWidget);
    expect(analysisGrid, findsOneWidget);

    expect(
      find.descendant(of: whiteGrid, matching: find.byType(Tooltip)),
      findsNWidgets(6),
    );
    expect(
      find.descendant(of: blackGrid, matching: find.byType(Tooltip)),
      findsNWidgets(6),
    );
    expect(
      find.descendant(of: analysisGrid, matching: find.byType(Tooltip)),
      findsNWidgets(6),
    );

    final whiteGridBottom = tester.getBottomLeft(whiteGrid).dy;
    final blackGridTop = tester.getTopLeft(blackGrid).dy;
    final blackGridBottom = tester.getBottomLeft(blackGrid).dy;
    final blankTop = tester.getTopLeft(blankTile).dy;
    final blankBottom = tester.getBottomLeft(blankTile).dy;
    final analysisGridTop = tester.getTopLeft(analysisGrid).dy;
    expect(blackGridTop, greaterThan(whiteGridBottom));
    expect(blankTop, greaterThan(blackGridBottom));
    expect(analysisGridTop, greaterThan(blankBottom));

    final blankCenter = tester.getCenter(blankTile).dx;
    final screenCenter =
        tester.getSize(find.byType(BoardSettingsScreen)).width / 2;
    expect((blankCenter - screenCenter).abs(), lessThan(2));
  });

  testWidgets('edits EVO2 analysis marker pattern from Board settings',
      (tester) async {
    final updates = <BoardSettingsState>[];
    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.evo2,
        onNavigate: (_) {},
        onSettingsChanged: updates.add,
        hidePhysicalBoardConnectionUi: true,
      ),
    );

    final markerTile = find.byKey(const ValueKey(
      'evo2-led-pattern-analysis_best-tile',
    ));
    await tester.ensureVisible(markerTile);
    await tester.pumpAndSettle();
    await tester.tap(markerTile);
    await tester.pumpAndSettle();

    expect(find.text('Analysis !!'), findsOneWidget);

    await tester.tap(find.byTooltip('Off'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cell 1'));
    await tester.pumpAndSettle();
    final saveButton = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(updates, isNotEmpty);
    expect(
      updates.last.evo2LedPatterns.patternFor('analysis_best').colors.first,
      0,
    );
  });

  testWidgets('edits EVO2 LED pattern from Board settings', (tester) async {
    final updates = <BoardSettingsState>[];
    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.evo2,
        onNavigate: (_) {},
        onSettingsChanged: updates.add,
        hidePhysicalBoardConnectionUi: true,
      ),
    );

    await tester.ensureVisible(find.text('P'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('P').first);
    await tester.pumpAndSettle();

    expect(find.text('White pawn'), findsOneWidget);

    await tester.tap(find.byTooltip('Off'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cell 1'));
    await tester.pumpAndSettle();
    final saveButton = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(updates, isNotEmpty);
    expect(updates.last.evo2LedPatterns.patternFor('P').colors.first, 0);
  });

  testWidgets('resets EVO2 LED patterns after confirmation', (tester) async {
    final updates = <BoardSettingsState>[];
    final customPawn = Evo2LedPattern(
      colors: [
        0xff0000,
        ...List<int>.filled(evo2LedPatternCellCount - 1, 0),
      ],
    );
    final customAnalysisMarker = Evo2LedPattern(
      colors: List<int>.filled(evo2LedPatternCellCount, 0xff0000),
    );
    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.evo2,
        settings: BoardSettingsState(
          evo2LedPatterns: Evo2LedPatternSet.defaults
              .copyWithPattern('P', customPawn)
              .copyWithPattern('analysis_best', customAnalysisMarker),
        ),
        onNavigate: (_) {},
        onSettingsChanged: updates.add,
        hidePhysicalBoardConnectionUi: true,
      ),
    );

    await tester.ensureVisible(find.byKey(const ValueKey(
      'evo2-led-pattern-reset',
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('evo2-led-pattern-reset')));
    await tester.pumpAndSettle();

    expect(find.text('Reset EVO2 patterns?'), findsOneWidget);
    expect(updates, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
    await tester.pumpAndSettle();

    expect(updates, isNotEmpty);
    expect(
      updates.last.evo2LedPatterns.patternFor('P'),
      Evo2LedPatternSet.defaults.patternFor('P'),
    );
    expect(
      updates.last.evo2LedPatterns.patternFor('analysis_best'),
      Evo2LedPatternSet.defaults.patternFor('analysis_best'),
    );
  });

  testWidgets('uses Analyze PGN action card distribution', (tester) async {
    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.move,
        onNavigate: (_) {},
      ),
    );

    for (final label in [
      'Pieces',
      'Pair / battery',
      'Saved games',
      'Import OTB',
      'Firmware',
      'Version unavailable',
    ]) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.textAlign, isNull);
    }
  });

  testWidgets('does not fake a connected Move board when disconnected',
      (tester) async {
    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.move,
        boardConnected: false,
        batteryStatus: const BoardBatteryStatus(level: 82, isCharging: false),
        onNavigate: (_) {},
      ),
    );

    expect(find.text('Chessnut Move connected'), findsNothing);
    expect(find.text('Board disconnected'), findsOneWidget);
    expect(find.byKey(const ValueKey('board-battery-bars-5')), findsNothing);
  });

  testWidgets('hides live Move actions when board settings is disconnected',
      (tester) async {
    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.move,
        boardConnected: false,
        onNavigate: (_) {},
      ),
    );

    expect(find.text('Pieces'), findsNothing);
    expect(find.text('Firmware'), findsNothing);
    expect(find.text('Disconnect board'), findsNothing);
  });

  testWidgets('allows disconnected board settings subtitle to wrap',
      (tester) async {
    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.move,
        boardConnected: false,
        onNavigate: (_) {},
      ),
    );

    final subtitle = tester.widget<Text>(
      find.text('Connect a board to change live hardware settings.'),
    );
    expect(subtitle.maxLines, anyOf(isNull, greaterThanOrEqualTo(2)));
    expect(subtitle.overflow, isNot(TextOverflow.ellipsis));
  });

  testWidgets('shows fused voice move controls only for connected Move boards',
      (tester) async {
    final updates = <BoardSettingsState>[];
    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.move,
        settings: const BoardSettingsState(voiceMovesEnabled: false),
        onSettingsChanged: updates.add,
        onNavigate: (_) {},
      ),
    );

    expect(find.text('Voice moves'), findsOneWidget);
    expect(
      find.text('Use your voice to control piece movement on Chessnut Move.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Voice moves require a network connection. Choose the correct speech language to improve recognition success.',
      ),
      findsOneWidget,
    );
    expect(find.text('Speech recognition'), findsNothing);
    expect(find.text('Off'), findsNothing);
    expect(find.text('Online'), findsNothing);
    expect(find.text('Local'), findsNothing);
    expect(find.text('Speech language'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('voice-move-language-dropdown')));
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
    expect(find.text('Mandarin'), findsOneWidget);
    expect(find.text('Cantonese'), findsOneWidget);
    expect(find.text(AppLanguagePreference.zhHans.nativeLabel), findsNothing);
    expect(find.text(AppLanguagePreference.zhHant.nativeLabel), findsNothing);

    await tester.tap(find.text('Cantonese').last);
    await tester.pumpAndSettle();

    expect(updates.last.voiceMoveLanguage, AppLanguagePreference.zhHant);

    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.move,
        boardConnected: false,
        onNavigate: (_) {},
      ),
    );
    expect(find.text('Voice moves'), findsNothing);

    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.air,
        onNavigate: (_) {},
      ),
    );
    expect(find.text('Voice moves'), findsNothing);
  });

  testWidgets('shows current board firmware version in Board settings',
      (tester) async {
    final gateway = MemoryPhysicalBoardGateway();
    await gateway.connect();
    addTearDown(gateway.dispose);

    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.move,
        boardGateway: gateway,
        onNavigate: (_) {},
      ),
    );

    expect(find.text('Firmware'), findsOneWidget);
    expect(find.text('Reading version'), findsOneWidget);

    gateway.addBoardFirmwareVersions(
      const BoardFirmwareVersions(
        moveVersion: '2.1.8',
        bluetoothVersion: 'BLE-1.2',
      ),
    );
    await tester.pump();

    expect(find.text('Move 2.1.8\nBLE BLE-1.2'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Firmware'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Firmware'));
    await tester.pumpAndSettle();

    expect(find.text('Firmware update'), findsOneWidget);
    expect(find.textContaining('Move firmware: 2.1.8'), findsOneWidget);
    expect(find.textContaining('Bluetooth firmware: BLE-1.2'), findsOneWidget);
    expect(
      find.textContaining(
        'No firmware update is available from the connected board service right now.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('updates Move firmware over Bluetooth or Wi-Fi', (tester) async {
    final gateway = MemoryPhysicalBoardGateway();
    final wakeLock = _RecordingWakeLockService();
    final firmwareUri = Uri.parse('https://download.test/move.tar.gz');
    final apiClient = ChessnutApiClient(
      moveUpdateUri: Uri.parse('https://move.test/update.json'),
      httpClient: MockClient((request) async {
        if (request.url == firmwareUri) {
          return http.Response.bytes([1, 2, 3, 4], 200);
        }
        return http.Response(
          jsonEncode({
            'version': 'ChessMove_1.0.34',
            'download': firmwareUri.toString(),
          }),
          200,
        );
      }),
    );
    await gateway.connect();
    addTearDown(gateway.dispose);

    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.move,
        boardGateway: gateway,
        apiClient: apiClient,
        screenWakeLockService: wakeLock,
        onNavigate: (_) {},
      ),
    );
    gateway.addBoardFirmwareVersions(
      const BoardFirmwareVersions(moveVersion: 'ChessMove_1.0.33'),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Firmware'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Firmware'));
    await tester.pumpAndSettle();

    expect(find.text('Latest version: ChessMove_1.0.34'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('move-firmware-bluetooth-update')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('move-firmware-wifi-update')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('move-firmware-bluetooth-update')),
    );
    await tester.pumpAndSettle();

    expect(
        find.text('Firmware update completed successfully.'), findsOneWidget);
    expect(gateway.lastMoveFirmwareFile, [1, 2, 3, 4]);
    expect(wakeLock.values, [true, false]);

    await tester.tap(find.byKey(const ValueKey('move-firmware-wifi-update')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('move-firmware-wifi-ssid')),
      'Chessnut Lab',
    );
    await tester.enterText(
      find.byKey(const ValueKey('move-firmware-wifi-password')),
      'move-secret',
    );
    await tester.tap(
      find.byKey(const ValueKey('move-firmware-wifi-connect')),
    );
    await tester.pumpAndSettle();

    expect(
      gateway.lastMoveFirmwareWifiCredentials,
      ('Chessnut Lab', 'move-secret'),
    );
    expect(wakeLock.values, [true, false, true, false]);
  });

  testWidgets('shows clock switch settings only on Chessnut clock devices',
      (tester) async {
    final updates = <BoardSettingsState>[];
    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.air,
        isChessnutClockDevice: true,
        settings: const BoardSettingsState(
          clockSwitchAutomation: ClockSwitchAutomationMode.off,
        ),
        onSettingsChanged: updates.add,
        onNavigate: (_) {},
      ),
    );

    expect(find.text('Clock Switch'), findsOneWidget);
    expect(find.text('Automatic switch press'), findsOneWidget);
    expect(
      find.text('Choose when the clock hardware switch is pressed for you.'),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey('settings-subheader-detail-Automatic switch press'),
      ),
      findsOneWidget,
    );
    expect(find.text('Off'), findsWidgets);
    expect(find.text('Opponent move only'), findsOneWidget);
    expect(find.text('Both sides'), findsOneWidget);
    expect(find.text('Aggressive mode'), findsNothing);
    expect(find.text('Leisure mode'), findsNothing);
    expect(find.text('Confirm moves with switch'), findsOneWidget);
    final confirmTitle = tester.widget<Text>(
      find.text('Confirm moves with switch'),
    );
    expect(confirmTitle.maxLines, 1);
    expect(confirmTitle.overflow, isNull);

    final detailButton = find.byKey(
      const ValueKey('settings-subheader-detail-Automatic switch press'),
    );
    await tester.ensureVisible(detailButton);
    await tester.pumpAndSettle();
    await tester.tap(detailButton);
    await tester.pumpAndSettle();
    expect(
      find.text('Choose when the clock hardware switch is pressed for you.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    final confirmTileRect = tester.getRect(
      find
          .ancestor(
            of: find.text('Confirm moves with switch'),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    expect(confirmTileRect.height, greaterThanOrEqualTo(64));
    expect(confirmTileRect.width, greaterThanOrEqualTo(520));

    final opponentChip = find.widgetWithText(ChoiceChip, 'Opponent move only');
    await tester.ensureVisible(opponentChip);
    await tester.pumpAndSettle();
    await tester.tap(opponentChip);
    await tester.pumpAndSettle();

    expect(
      updates.last.clockSwitchAutomation,
      ClockSwitchAutomationMode.opponentMoveOnly,
    );
    expect(find.text('Aggressive mode'), findsOneWidget);
    expect(find.text('Leisure mode'), findsOneWidget);
    expect(
      find.text('Press as soon as the opponent move arrives.'),
      findsOneWidget,
    );
    expect(
      find.text('Wait until the board matches the opponent move.'),
      findsOneWidget,
    );

    final aggressiveCard = tester.getRect(
      find
          .ancestor(
            of: find.text('Aggressive mode'),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final leisureCard = tester.getRect(
      find
          .ancestor(
            of: find.text('Leisure mode'),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    expect(aggressiveCard.top, moreOrLessEquals(leisureCard.top));
    expect(aggressiveCard.height, moreOrLessEquals(leisureCard.height));

    final leisureMode = find.text('Leisure mode');
    await tester.ensureVisible(leisureMode);
    await tester.pumpAndSettle();
    await tester.tap(leisureMode);
    await tester.pumpAndSettle();

    expect(
      updates.last.clockSwitchOpponentTiming,
      ClockSwitchOpponentTiming.leisure,
    );

    final confirmTile = find.ancestor(
      of: find.text('Confirm moves with switch'),
      matching: find.byType(AnimatedContainer),
    );
    await tester.ensureVisible(find.text('Confirm moves with switch'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: confirmTile.first, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();

    expect(updates.last.submitMoveOnClockSwitch, isTrue);
  });

  testWidgets('confirm moves with switch disables both-sides automation',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final updates = <BoardSettingsState>[];
    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.air,
        isChessnutClockDevice: true,
        settings: const BoardSettingsState(
          clockSwitchAutomation: ClockSwitchAutomationMode.bothSides,
        ),
        onSettingsChanged: updates.add,
        onNavigate: (_) {},
      ),
    );

    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Both sides'))
          .selected,
      isTrue,
    );

    final confirmTile = find.ancestor(
      of: find.text('Confirm moves with switch'),
      matching: find.byType(AnimatedContainer),
    );
    await tester.tap(
      find.descendant(of: confirmTile.first, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();

    expect(updates.last.submitMoveOnClockSwitch, isTrue);
    expect(
      updates.last.clockSwitchAutomation,
      ClockSwitchAutomationMode.opponentMoveOnly,
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'Opponent move only'),
          )
          .selected,
      isTrue,
    );
    final bothSidesChip = tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Both sides'));
    expect(bothSidesChip.selected, isFalse);
    expect(bothSidesChip.onSelected, isNull);
  });

  testWidgets('does not show move quality lights in board settings',
      (tester) async {
    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.move,
        onNavigate: (_) {},
      ),
    );

    expect(find.text('Move quality lights'), findsNothing);
    expect(
      find.text(
        'Bot games only. Color LEDs rate moves when a piece is lifted.',
      ),
      findsNothing,
    );
    expect(find.text('Evaluation LEDs'), findsNothing);

    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.evo,
        onNavigate: (_) {},
      ),
    );

    expect(find.text('Move quality lights'), findsNothing);

    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.air,
        onNavigate: (_) {},
      ),
    );

    expect(find.text('Move quality lights'), findsNothing);
  });

  testWidgets('keeps Chess.com move control out of board settings',
      (tester) async {
    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.air,
        onNavigate: (_) {},
      ),
    );

    expect(find.text('Chess.com move control'), findsNothing);
    expect(find.text('Direct control'), findsNothing);
    expect(find.text('Web control'), findsNothing);
  });

  testWidgets('uses icon-only board battery and updates beep settings',
      (tester) async {
    final gateway =
        MemoryPhysicalBoardGateway(boardModel: PhysicalBoardModel.air);
    final updates = <BoardSettingsState>[];
    await gateway.connect();
    addTearDown(gateway.dispose);

    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.air,
        boardGateway: gateway,
        batteryStatus: const BoardBatteryStatus(level: 82, isCharging: false),
        onSettingsChanged: updates.add,
        onNavigate: (_) {},
      ),
    );

    expect(
      _commandCount(gateway.writes, ChessnutGeneralCommands.batteryStatus),
      1,
    );
    expect(find.text('82%'), findsNothing);
    expect(find.byKey(const ValueKey('board-battery-bars-5')), findsWidgets);
    expect(
      find.byKey(const ValueKey('board-battery-charging-icon')),
      findsNothing,
    );

    expect(find.text('Global beep'), findsNothing);
    expect(find.text('Buzzer master switch'), findsOneWidget);
    expect(find.text('Event sounds'), findsOneWidget);

    await tester.ensureVisible(find.text('Buzzer master switch'));
    await tester.pumpAndSettle();
    final globalTile = find.ancestor(
      of: find.text('Buzzer master switch'),
      matching: find.byType(AnimatedContainer),
    );
    await tester.tap(
      find.descendant(of: globalTile.first, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();

    expect(updates.last.globalBeep, isFalse);
    expect(gateway.commandLabels, contains('set-beep-off'));
  });

  testWidgets('shows charging icon beside board battery', (tester) async {
    final gateway =
        MemoryPhysicalBoardGateway(boardModel: PhysicalBoardModel.air);
    await gateway.connect();
    addTearDown(gateway.dispose);

    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.air,
        boardGateway: gateway,
        batteryStatus: const BoardBatteryStatus(level: 62, isCharging: true),
        onNavigate: (_) {},
      ),
    );

    expect(
      find.byKey(const ValueKey('board-battery-charging-icon')),
      findsOneWidget,
    );
  });

  testWidgets('master buzzer disables dependent beep switches', (tester) async {
    final updates = <BoardSettingsState>[];
    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.air,
        settings: const BoardSettingsState(globalBeep: false),
        onSettingsChanged: updates.add,
        onNavigate: (_) {},
      ),
    );

    await tester.ensureVisible(find.text('Connect beep'));
    await tester.pumpAndSettle();
    final connectTile = find.ancestor(
      of: find.text('Connect beep'),
      matching: find.byType(AnimatedContainer),
    );
    final switchWidget = tester.widget<Switch>(
      find.descendant(of: connectTile.first, matching: find.byType(Switch)),
    );

    expect(switchWidget.onChanged, isNull);

    await tester.tap(
      find.descendant(of: connectTile.first, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();

    expect(updates, isEmpty);
  });

  testWidgets('offers saved board game import from Board settings',
      (tester) async {
    var previewCalls = 0;
    var importCalls = 0;
    final gateway = MemoryPhysicalBoardGateway()
      ..storedGameImportSupported = true
      ..storedGameFiles.add(
        [
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
          'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR',
          'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR',
        ].join(';'),
      );
    await gateway.connect();

    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.air,
        boardGateway: gateway,
        onNavigate: (_) {},
        onPreviewStoredBoardGames: (raw) async {
          previewCalls += 1;
          return const BoardStorageImportPreview(items: []);
        },
        onImportStoredBoardGames: ({required deleteAfterImport}) async {
          importCalls += 1;
          return const BoardStorageImportResult(
            importedCount: 1,
            skippedCount: 0,
            failedCount: 0,
            importedKeys: {'board-storage:test'},
            errors: [],
          );
        },
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Saved games'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Saved games'), findsOneWidget);

    await tester.tap(find.text('Saved games'));
    await tester.pumpAndSettle();

    expect(find.text('Import saved board games'), findsOneWidget);
    expect(find.text('Saved games found'), findsOneWidget);
    expect(
      find.text('1 saved game will be imported after you tap Import.'),
      findsOneWidget,
    );
    expect(find.text('Import'), findsOneWidget);
    expect(previewCalls, 0);
    expect(importCalls, 0);
  });

  testWidgets('imports saved board games with board cleanup', (tester) async {
    var clearRequested = false;
    var previewCalls = 0;
    var importCalls = 0;
    final gateway = MemoryPhysicalBoardGateway()
      ..storedGameImportSupported = true
      ..storedGameFiles.add(
        [
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
          'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR',
        ].join(';'),
      );
    await gateway.connect();

    await tester.pumpWidget(
      _settingsHarness(
        boardModel: ChessnutBoardModel.air,
        boardGateway: gateway,
        onNavigate: (_) {},
        onPreviewStoredBoardGames: (raw) async {
          previewCalls += 1;
          return const BoardStorageImportPreview(items: []);
        },
        onImportStoredBoardGames: ({required deleteAfterImport}) async {
          importCalls += 1;
          clearRequested = deleteAfterImport;
          return const BoardStorageImportResult(
            importedCount: 0,
            skippedCount: 1,
            failedCount: 0,
            importedKeys: <String>{},
            errors: [],
          );
        },
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Saved games'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved games'));
    await tester.pumpAndSettle();

    expect(find.text('Saved games found'), findsOneWidget);
    expect(previewCalls, 0);
    expect(importCalls, 0);
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(clearRequested, isTrue);
    expect(importCalls, 1);
    expect(previewCalls, 0);
  });

  testWidgets('Move pieces page waits for real piece status data',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ChessnutTheme.light(),
        home: Scaffold(
          body: PieceManagementScreen(
            boardModel: ChessnutBoardModel.move,
            onNavigate: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Waiting for piece status'), findsOneWidget);
    expect(find.text('32 detected'), findsNothing);
    expect(find.byKey(const ValueKey('move-piece-board')), findsOneWidget);
    expect(find.byKey(const ValueKey('piece-battery-wK')), findsNothing);
  });

  testWidgets('Move pieces page shows board and real set list', (tester) async {
    final gateway = MemoryPhysicalBoardGateway()
      ..movePieceData = ['Chess Pieces 01', '', 'Practice set', '']
      ..moveChannel = 2;
    await gateway.connect();

    await tester.pumpWidget(
      MaterialApp(
        theme: ChessnutTheme.light(),
        home: Scaffold(
          body: PieceManagementScreen(
            boardModel: ChessnutBoardModel.move,
            boardGateway: gateway,
            onNavigate: (_) {},
            movePairingVerificationDelay: Duration.zero,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('move-piece-board')), findsOneWidget);
    expect(find.byKey(const ValueKey('move-piece-board-with-parking')),
        findsNothing);
    expect(find.byKey(const ValueKey('move-piece-parking-left')), findsNothing);
    expect(
        find.byKey(const ValueKey('move-piece-parking-right')), findsNothing);
    final board =
        tester.getSize(find.byKey(const ValueKey('move-piece-board')));
    expect(board.height, moreOrLessEquals(board.width * 0.815, epsilon: 1));
    expect(find.text('Realtime data'), findsNothing);
    expect(find.text('Show off-board'), findsNothing);
    expect(find.text('Auto-pairing'), findsNothing);
    expect(find.text('Battery levels'), findsOneWidget);
    expect(find.text('50-100%'), findsOneWidget);
    expect(find.text('20-49%'), findsOneWidget);
    expect(find.text('0-19%'), findsOneWidget);
    expect(find.text('Unknown'), findsOneWidget);

    expect(find.text('Chess Pieces 01'), findsOneWidget);
    expect(find.text('Practice set'), findsOneWidget);
    expect(find.text('Channel 0'), findsOneWidget);
    expect(find.text('Channel 2'), findsWidgets);
    expect(find.textContaining('Backup'), findsWidgets);
    expect(find.textContaining('/ Empty'), findsNothing);
    expect(find.textContaining('/ Connected'), findsNothing);
    expect(find.text('Auto-detect set'), findsOneWidget);

    await tester.ensureVisible(find.text('Chess Pieces 01'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chess Pieces 01'));
    await tester.pumpAndSettle();
    expect(find.textContaining('/ Connected'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pumpAndSettle();

    expect(gateway.moveChannel, 0);
    expect(_hasCommand(gateway.writes, ChessnutMoveCommands.setChannel(0)),
        isTrue);
  });

  testWidgets('Move pieces page maps raw piece coordinates onto board image',
      (tester) async {
    final gateway = MemoryPhysicalBoardGateway();
    await gateway.connect();

    await tester.pumpWidget(
      MaterialApp(
        theme: ChessnutTheme.light(),
        home: Scaffold(
          body: PieceManagementScreen(
            boardModel: ChessnutBoardModel.move,
            boardGateway: gateway,
            onNavigate: (_) {},
            movePairingVerificationDelay: Duration.zero,
          ),
        ),
      ),
    );

    expect(
      gateway.writes.where(_isMovePieceStatusCommand),
      hasLength(1),
    );
    await tester.pump(const Duration(milliseconds: 1100));
    expect(
      gateway.writes.where(_isMovePieceStatusCommand),
      hasLength(greaterThanOrEqualTo(3)),
    );

    gateway.addMovePieceStatus(const [
      ChessnutMovePieceStatus(
        index: 1,
        identity: 6,
        rawX: 128,
        rawY: 64,
        batteryLevel: 80,
      ),
      ChessnutMovePieceStatus(
        index: 2,
        identity: 12,
        rawX: 0,
        rawY: 0,
        batteryLevel: 35,
      ),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final boardRect =
        tester.getRect(find.byKey(const ValueKey('move-piece-board')));
    final kingRect =
        tester.getRect(find.byKey(const ValueKey('move-piece-position-1')));
    final offBoardRect =
        tester.getRect(find.byKey(const ValueKey('move-piece-position-2')));

    final pieceSize = boardRect.width * 0.75 / 8;
    final expectedKingTopLeft = Offset(
      boardRect.left + ((255 - 128) * 0.00360 - 0.008) * boardRect.width,
      boardRect.top + ((255 - 64) * 0.00282 - 0.005) * boardRect.width,
    );
    final expectedOffBoardTopLeft = Offset(
      boardRect.left + 0.05 * boardRect.width,
      boardRect.top + 0.815 * boardRect.width,
    );

    expect(kingRect.left, closeTo(expectedKingTopLeft.dx, 1));
    expect(kingRect.top, closeTo(expectedKingTopLeft.dy, 1));
    expect(kingRect.width, closeTo(pieceSize, 1));
    expect(offBoardRect.left, closeTo(expectedOffBoardTopLeft.dx, 1));
    expect(offBoardRect.top, closeTo(expectedOffBoardTopLeft.dy, 1));
    expect(offBoardRect.width, closeTo(pieceSize, 1));
    expect(boardRect.height, closeTo(boardRect.width * 1.22, 1));
    expect(find.byKey(const ValueKey('piece-outline-wK')), findsOneWidget);
    expect(find.byKey(const ValueKey('piece-battery-label-wK')), findsNothing);
    expect(find.text('80%'), findsNothing);
    expect(find.text('35%'), findsNothing);
    expect(
      find.image(
        const AssetImage('assets/images/boardpics/move_piece_positions.png'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Move pieces page uses the reference background only on Android',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final gateway = MemoryPhysicalBoardGateway();
      await gateway.connect();

      Widget buildHarness({bool isChessnutClockDevice = false}) {
        return MaterialApp(
          theme: ChessnutTheme.light(),
          home: Scaffold(
            body: PieceManagementScreen(
              boardModel: ChessnutBoardModel.move,
              boardGateway: gateway,
              onNavigate: (_) {},
              isChessnutClockDevice: isChessnutClockDevice,
              movePairingVerificationDelay: Duration.zero,
            ),
          ),
        );
      }

      await tester.pumpWidget(buildHarness());
      gateway.addMovePieceStatus(const [
        ChessnutMovePieceStatus(
          index: 1,
          identity: 6,
          rawX: 128,
          rawY: 64,
          batteryLevel: 80,
        ),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const ValueKey('android-piece-background-wK')),
        findsOneWidget,
      );
      final background = tester.widget<Container>(
        find.byKey(const ValueKey('piece-outline-wK')),
      );
      final decoration = background.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFFE9EDEC));
      expect(decoration.shape, BoxShape.circle);
      expect(
        (decoration.border! as Border).top.color,
        const Color(0xFF6B7673),
      );

      final androidBattery = tester.widget<Container>(
        find.byKey(const ValueKey('piece-battery-wK')),
      );
      expect(androidBattery.constraints?.hasBoundedWidth, isFalse);
      expect(androidBattery.constraints?.maxHeight, 3.5);

      await tester.pumpWidget(
        buildHarness(isChessnutClockDevice: true),
      );

      expect(
        find.byKey(const ValueKey('android-piece-background-wK')),
        findsNothing,
      );
      final clockBattery = tester.widget<Container>(
        find.byKey(const ValueKey('piece-battery-wK')),
      );
      expect(
        clockBattery.constraints,
        BoxConstraints.tight(const Size(12, 12)),
      );

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(buildHarness());

      expect(
        find.byKey(const ValueKey('android-piece-background-wK')),
        findsNothing,
      );
      final nonAndroidBattery = tester.widget<Container>(
        find.byKey(const ValueKey('piece-battery-wK')),
      );
      expect(
        nonAndroidBattery.constraints,
        BoxConstraints.tight(const Size(12, 12)),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Move pairing flow writes pairing commands and saves a set name',
      (tester) async {
    final gateway = MemoryPhysicalBoardGateway()
      ..movePieceData = ['Chess Pieces 01', '', '', '']
      ..moveChannel = 0
      ..movePairingWillSucceed = true;
    await gateway.connect();

    await tester.pumpWidget(
      MaterialApp(
        theme: ChessnutTheme.light(),
        home: Scaffold(
          body: PieceManagementScreen(
            boardModel: ChessnutBoardModel.move,
            boardGateway: gateway,
            onNavigate: (_) {},
            movePairingVerificationDelay: Duration.zero,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Pair new pieces'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pair new pieces'));
    await tester.pumpAndSettle();
    expect(find.text('Place pieces'), findsOneWidget);
    expect(find.text('Place all 34 pieces exactly as shown before pairing.'),
        findsOneWidget);
    final pairingDialog = find.byType(Dialog);
    expect(
      find.descendant(
        of: pairingDialog,
        matching: find.byKey(const ValueKey('move-pair-placement-board')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: pairingDialog,
        matching: find.byKey(const ValueKey('move-piece-parking-left')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: pairingDialog,
        matching: find.byKey(const ValueKey('move-piece-parking-right')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: pairingDialog,
        matching: find.byKey(const ValueKey('move-piece-board')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: pairingDialog,
        matching: find.byKey(const ValueKey('move-piece-glyph-a3-wR')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: pairingDialog,
        matching: find.byKey(const ValueKey('move-piece-glyph-h3-wQ')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: pairingDialog,
        matching: find.byKey(const ValueKey('move-piece-glyph-a6-bR')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: pairingDialog,
        matching: find.byKey(const ValueKey('move-piece-glyph-h6-bQ')),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Channel 1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start pairing'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
        _hasCommand(gateway.writes, ChessnutMoveCommands.startPiecePairing(1)),
        isTrue);
    expect(
        _hasCommand(gateway.writes, ChessnutMoveCommands.finishPiecePairing()),
        isTrue);
    expect(_hasCommand(gateway.writes, ChessnutMoveCommands.exitPiecePairing()),
        isFalse);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(_hasCommand(gateway.writes, ChessnutMoveCommands.exitPiecePairing()),
        isTrue);
    expect(gateway.movePieceData[1], 'Chess Pieces 02');
  });

  testWidgets('Move pairing waits for hardware without cancel action',
      (tester) async {
    final gateway = _PendingPairingGateway()
      ..movePieceData = ['Chess Pieces 01', '', '', '']
      ..moveChannel = 0;
    await gateway.connect();

    await tester.pumpWidget(
      MaterialApp(
        theme: ChessnutTheme.light(),
        home: Scaffold(
          body: PieceManagementScreen(
            boardModel: ChessnutBoardModel.move,
            boardGateway: gateway,
            onNavigate: (_) {},
            movePairingVerificationDelay: Duration.zero,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Pair new pieces'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pair new pieces'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Channel 1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start pairing'));
    await tester.pump();

    expect(find.text('Pairing pieces'), findsOneWidget);
    expect(find.text('Cancel pairing'), findsNothing);
    expect(find.text('Done'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byIcon(Icons.close_rounded),
      ),
      findsNothing,
    );

    gateway.completePairing(true);
    await tester.pumpAndSettle();

    expect(find.text('Pairing complete'), findsOneWidget);
    expect(_hasCommand(gateway.writes, ChessnutMoveCommands.exitPiecePairing()),
        isFalse);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(_hasCommand(gateway.writes, ChessnutMoveCommands.exitPiecePairing()),
        isTrue);
    expect(gateway.movePieceData[1], 'Chess Pieces 02');
  });

  testWidgets('Move pairing exits pairing mode when leaving failed result',
      (tester) async {
    final gateway = MemoryPhysicalBoardGateway()
      ..movePieceData = ['Chess Pieces 01', '', '', '']
      ..moveChannel = 0
      ..movePairingWillSucceed = false;
    await gateway.connect();

    await tester.pumpWidget(
      MaterialApp(
        theme: ChessnutTheme.light(),
        home: Scaffold(
          body: PieceManagementScreen(
            boardModel: ChessnutBoardModel.move,
            boardGateway: gateway,
            onNavigate: (_) {},
            movePairingVerificationDelay: Duration.zero,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Pair new pieces'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pair new pieces'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Channel 1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start pairing'));
    await tester.pump();
    await _advanceMovePairingVerification(tester);
    await _advanceMovePairingVerification(tester);
    await _advanceMovePairingVerification(tester);

    expect(find.text('Pairing failed'), findsOneWidget);
    expect(
      _commandCount(gateway.writes, ChessnutMoveCommands.startPiecePairing(1)),
      3,
    );
    expect(
      _commandCount(gateway.writes, ChessnutMoveCommands.finishPiecePairing()),
      3,
    );
    expect(
      _commandCount(gateway.writes, ChessnutMoveCommands.exitPiecePairing()),
      3,
    );

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(
      _commandCount(gateway.writes, ChessnutMoveCommands.exitPiecePairing()),
      3,
    );
    expect(find.text('Select channel'), findsOneWidget);
  });

  testWidgets('Move pairing lights mismatched squares after final failure',
      (tester) async {
    final gateway = MemoryPhysicalBoardGateway()
      ..movePieceData = ['Chess Pieces 01', '', '', '']
      ..moveChannel = 0
      ..movePairingWillSucceed = false;
    gateway.addBoardFen(
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
    );
    await gateway.connect();

    await tester.pumpWidget(
      MaterialApp(
        theme: ChessnutTheme.light(),
        home: Scaffold(
          body: PieceManagementScreen(
            boardModel: ChessnutBoardModel.move,
            boardGateway: gateway,
            onNavigate: (_) {},
            movePairingVerificationDelay: Duration.zero,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Pair new pieces'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pair new pieces'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Channel 1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start pairing'));
    await tester.pump();
    await _advanceMovePairingVerification(tester);
    await _advanceMovePairingVerification(tester);
    await _advanceMovePairingVerification(tester);

    expect(find.text('Pairing failed'), findsOneWidget);
    expect(
      _hasCommand(
        gateway.writes,
        ChessnutMoveLedCodec.commandFromSquares({
          'h3': ChessnutMoveLedColor.red,
          'h6': ChessnutMoveLedColor.red,
        }),
      ),
      isTrue,
    );
  });

  testWidgets('Move pairing treats verification FEN as success after failure',
      (tester) async {
    final gateway = MemoryPhysicalBoardGateway()
      ..movePieceData = ['Chess Pieces 01', '', '', '']
      ..moveChannel = 0
      ..movePairingWillSucceed = false;
    gateway.addBoardFen(
      'rnbqkbnr/pppppppp/7q/8/8/7Q/PPPPPPPP/RNBQKBNR',
    );
    await gateway.connect();

    await tester.pumpWidget(
      MaterialApp(
        theme: ChessnutTheme.light(),
        home: Scaffold(
          body: PieceManagementScreen(
            boardModel: ChessnutBoardModel.move,
            boardGateway: gateway,
            onNavigate: (_) {},
            movePairingVerificationDelay: Duration.zero,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Pair new pieces'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pair new pieces'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Channel 1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start pairing'));
    await tester.pump();
    await _advanceMovePairingVerification(tester);

    expect(find.text('Pairing complete'), findsOneWidget);
    expect(
      _commandCount(gateway.writes, ChessnutMoveCommands.startPiecePairing(1)),
      1,
    );
    expect(
      _commandCount(gateway.writes, ChessnutMoveCommands.finishPiecePairing()),
      1,
    );
    expect(
      _commandCount(gateway.writes, ChessnutMoveCommands.exitPiecePairing()),
      1,
    );

    await tester.tap(find.text('Done'));
    await tester.pump();

    expect(gateway.movePieceData[1], 'Chess Pieces 02');
  });
}

bool _hasCommand(List<List<int>> writes, List<int> expected) {
  return writes.any(
    (write) =>
        write.length == expected.length &&
        Iterable<int>.generate(write.length)
            .every((index) => write[index] == expected[index]),
  );
}

int _commandCount(List<List<int>> writes, List<int> expected) {
  return writes.where((write) {
    if (write.length != expected.length) return false;
    return Iterable<int>.generate(write.length)
        .every((index) => write[index] == expected[index]);
  }).length;
}

Future<void> _advanceMovePairingVerification(WidgetTester tester) async {
  for (var i = 0; i < 30; i += 1) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

Widget _settingsHarness({
  required ChessnutBoardModel boardModel,
  required ValueChanged<String> onNavigate,
  BoardSettingsState settings = const BoardSettingsState(),
  ValueChanged<BoardSettingsState>? onSettingsChanged,
  PhysicalBoardGateway? boardGateway,
  BoardBatteryStatus? batteryStatus,
  ChessnutApiClient? apiClient,
  ScreenWakeLockService screenWakeLockService =
      const SystemScreenWakeLockService(),
  bool boardConnected = true,
  bool isChessnutClockDevice = false,
  TextScaler? textScaler,
  bool hidePhysicalBoardConnectionUi = false,
  Future<BoardStorageImportPreview> Function(List<String> rawFenSequences)?
      onPreviewStoredBoardGames,
  Future<BoardStorageImportResult> Function({required bool deleteAfterImport})?
      onImportStoredBoardGames,
}) {
  return MaterialApp(
    theme: ChessnutTheme.light(),
    builder: textScaler == null
        ? null
        : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
    home: Scaffold(
      body: BoardSettingsScreen(
        boardModel: boardModel,
        boardConnected: boardConnected,
        onNavigate: onNavigate,
        settings: settings,
        onSettingsChanged: onSettingsChanged ?? (_) {},
        boardGateway: boardGateway,
        onPreviewStoredBoardGames: onPreviewStoredBoardGames,
        onImportStoredBoardGames: onImportStoredBoardGames,
        batteryStatus: batteryStatus,
        apiClient: apiClient,
        screenWakeLockService: screenWakeLockService,
        isChessnutClockDevice: isChessnutClockDevice,
        hidePhysicalBoardConnectionUi: hidePhysicalBoardConnectionUi,
      ),
    ),
  );
}

class _RecordingWakeLockService implements ScreenWakeLockService {
  final values = <bool>[];

  @override
  Future<void> setEnabled(bool enabled) async {
    values.add(enabled);
  }
}

bool _isMovePieceStatusCommand(List<int> command) {
  if (command.length != ChessnutMoveCommands.pieceStatus.length) return false;
  for (var i = 0; i < command.length; i++) {
    if (command[i] != ChessnutMoveCommands.pieceStatus[i]) return false;
  }
  return true;
}

class _PendingPairingGateway extends MemoryPhysicalBoardGateway {
  Completer<bool>? _pairingCompleter;

  @override
  Future<bool> finishMovePiecePairing() async {
    if (boardModel != PhysicalBoardModel.move) return false;
    final sent = await write(ChessnutMoveCommands.finishPiecePairing());
    if (!sent) return false;
    final completer = Completer<bool>();
    _pairingCompleter = completer;
    return completer.future;
  }

  void completePairing(bool success) {
    final completer = _pairingCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(success);
    }
  }
}
