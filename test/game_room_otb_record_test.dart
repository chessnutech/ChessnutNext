import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/l10n/localized_material.dart'
    as localized;
import 'package:chessnut_flutter_export/screens/game_room_screen.dart';
import 'package:chessnut_flutter_export/services/bot_engine_adapter.dart';
import 'package:chessnut_flutter_export/services/chess_clock_switch_service.dart';
import 'package:chessnut_flutter_export/services/physical_board_gateway.dart';
import 'package:chessnut_flutter_export/services/physical_board_protocol.dart';
import 'package:chessnut_flutter_export/theme/chessnut_theme.dart';
import 'package:chessnut_flutter_export/widgets/chess_board.dart';

void main() {
  testWidgets('OTB record game starts from its configured position', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final opening = botOpeningScenarios.firstWhere(
      (scenario) => scenario.id == 'italian',
    );

    await tester.pumpWidget(
      _otbHarness(
        config: OtbGameConfig(
          opening: opening,
          startFen: opening.fen,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<InteractiveChessBoard>(
            find.byType(InteractiveChessBoard).first,
          )
          .initialFen,
      opening.fen,
    );
  });

  testWidgets('Clock OTB layout can hide the PGN move list', (tester) async {
    tester.view.physicalSize = const Size(1280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _otbHarness(
        isChessnutClockDevice: true,
        config: const OtbGameConfig(
          timeMinutes: 5,
          incrementSeconds: 0,
          showPgnList: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveChessBoard), findsOneWidget);
    expect(find.byKey(const ValueKey('game-pgn-strip')), findsNothing);
    final boardRect = tester.getRect(find.byType(InteractiveChessBoard));
    expect(boardRect.width, greaterThanOrEqualTo(460));
    expect(boardRect.height, greaterThanOrEqualTo(460));
    expect(
        find.byKey(const ValueKey('clock-only-black-clock')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('clock-only-white-clock')), findsOneWidget);
    expect(find.byKey(const ValueKey('clock-only-back')), findsOneWidget);
    for (final side in ['black', 'white']) {
      expect(
        find.byKey(ValueKey('clock-only-$side-quality-lights')),
        findsOneWidget,
      );
    }
    for (final side in ['black', 'white']) {
      expect(
        find.byKey(ValueKey('clock-only-$side-resign')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('clock-only-$side-draw')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('clock-only-$side-hint')),
        findsOneWidget,
      );
    }

    final blackHint = tester.widget<localized.IconButton>(
      find.byKey(const ValueKey('clock-only-black-hint')),
    );
    final whiteHint = tester.widget<localized.IconButton>(
      find.byKey(const ValueKey('clock-only-white-hint')),
    );
    expect(blackHint.onPressed, isNull);
    expect(whiteHint.onPressed, isNotNull);

    final blackQualityFinder =
        find.byKey(const ValueKey('clock-only-black-quality-lights'));
    final whiteQualityFinder =
        find.byKey(const ValueKey('clock-only-white-quality-lights'));
    expect(tester.widget<Switch>(blackQualityFinder).value, isTrue);
    expect(tester.widget<Switch>(whiteQualityFinder).value, isTrue);

    await tester.tap(blackQualityFinder);
    await tester.pump();

    expect(tester.widget<Switch>(blackQualityFinder).value, isFalse);
    expect(tester.widget<Switch>(whiteQualityFinder).value, isTrue);
  });

  testWidgets('Clock OTB side buttons act for their own side', (tester) async {
    tester.view.physicalSize = const Size(1280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _otbHarness(
        isChessnutClockDevice: true,
        config: const OtbGameConfig(
          timeMinutes: 5,
          incrementSeconds: 0,
          showPgnList: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('clock-only-black-draw')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Black offers a draw'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('clock-only-black-resign')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Confirm Black resignation?'), findsOneWidget);
    expect(find.textContaining('White will win'), findsOneWidget);

    await tester.tap(find.text('Resign Black'));
    await tester.pumpAndSettle();
    expect(find.text('White wins by resignation'), findsOneWidget);
  });

  testWidgets('OTB check highlights the king and uses a physical board light', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = MemoryPhysicalBoardGateway();
    await gateway.connect();
    addTearDown(gateway.dispose);
    const checkFen = '4k3/4R3/8/8/8/8/8/K7 b - - 0 1';
    final opening = botOpeningScenarios.first;

    await tester.pumpWidget(
      _otbHarness(
        boardGateway: gateway,
        config: OtbGameConfig(
          opening: opening,
          startFen: checkFen,
          timeMinutes: 1,
          incrementSeconds: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('check-king-e8')), findsOneWidget);
    expect(
      gateway.writes.any(
        (command) => listEquals(
          command,
          ChessnutMoveLedCodec.commandFromSquares({
            'e8': ChessnutMoveLedColor.green,
          }),
        ),
      ),
      isTrue,
    );
  });

  testWidgets('Windows OTB record game can hide the board while clocks remain',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(_otbHarness());
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveChessBoard), findsOneWidget);
      expect(find.byTooltip('Hide board'), findsOneWidget);

      await tester.tap(find.byTooltip('Hide board'));
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveChessBoard), findsNothing);
      expect(
        find.byKey(const ValueKey('windows-hidden-otb-room')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('windows-hidden-otb-clock-Black')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('windows-hidden-otb-clock-White')),
          findsOneWidget);
      expect(find.text('Black'), findsOneWidget);
      expect(find.text('White'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('windows-hidden-otb-clock-Black')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('windows-hidden-otb-clock-White')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('windows-hidden-otb-edit-Black')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('windows-otb-name-input-Black')),
        'Black Player',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Black Player'), findsOneWidget);

      await tester.tap(find.byTooltip('Show board'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveChessBoard), findsOneWidget);
      expect(find.byTooltip('Hide board'), findsOneWidget);
      expect(find.text('Black Player'), findsOneWidget);
      expect(find.text('Black'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Windows hidden OTB room keeps monitoring the physical board',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = MemoryPhysicalBoardGateway();
    await gateway.connect();
    addTearDown(gateway.dispose);

    try {
      await tester.pumpWidget(_otbHarness(boardGateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hide board'));
      await tester.pumpAndSettle();

      await _playPhysicalFens(tester, gateway, const [
        'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR',
      ]);

      expect(find.byKey(const ValueKey('windows-hidden-otb-room')),
          findsOneWidget);
      expect(
        find.byKey(const ValueKey('windows-hidden-otb-clock-Black')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('windows-hidden-otb-clock-White')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Show board'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveChessBoard), findsOneWidget);
      expect(
        tester
            .widget<Semantics>(find.byKey(const ValueKey('square-e4')))
            .properties
            .label,
        contains('wp'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Mobile and macOS OTB record games can hide the board',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      for (final platform in const [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        await tester.pumpWidget(_otbHarness(key: ValueKey(platform)));
        await tester.pumpAndSettle();

        expect(find.byTooltip('Hide board'), findsOneWidget);
        await tester.tap(find.byTooltip('Hide board'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('windows-hidden-otb-room')),
            findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('windows-hidden-otb-edit-White')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('windows-otb-name-input-White')),
          '$platform Player',
        );
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.text('$platform Player'), findsOneWidget);

        await tester.tap(find.byTooltip('Show board'));
        await tester.pumpAndSettle();
        expect(find.byType(InteractiveChessBoard), findsOneWidget);
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Chessnut clock OTB room does not expose board hiding',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(1280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    try {
      await tester.pumpWidget(
        _otbHarness(isChessnutClockDevice: true),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Hide board'), findsNothing);
      expect(find.byType(InteractiveChessBoard), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Bot game can hide and restore the board while clocks remain',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      for (final size in const [Size(390, 844), Size(1280, 480)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(_botHarness(key: ValueKey(size)));
        await tester.pumpAndSettle();

        expect(find.byType(InteractiveChessBoard), findsOneWidget);
        expect(find.byTooltip('Hide board'), findsOneWidget);

        await tester.tap(find.byTooltip('Hide board'));
        await tester.pumpAndSettle();

        expect(find.byType(InteractiveChessBoard), findsNothing);
        expect(find.byKey(const ValueKey('hidden-bot-room')), findsOneWidget);
        expect(find.text('Maia 1500'), findsOneWidget);
        expect(find.text('Chessnut Player'), findsOneWidget);
        expect(find.byIcon(Icons.edit_rounded), findsNothing);
        expect(find.byTooltip('Show board'), findsOneWidget);

        await tester.tap(find.byTooltip('Show board'));
        await tester.pumpAndSettle();

        expect(find.byType(InteractiveChessBoard), findsOneWidget);
        expect(find.byTooltip('Hide board'), findsOneWidget);
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Career bot room does not expose board hiding', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(1280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      const careerMode = CareerModeConfig(
        startElo: 1200,
        winElo: 1215,
        loseElo: 1190,
        opponentName: 'Career Bot',
        opponentAvatarAsset: '',
      );
      await tester.pumpWidget(
        _botHarness(
          key: const ValueKey('career-bot'),
          config: const BotGameConfig.defaultConfig().copyWith(
            careerMode: careerMode,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hide board'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('PGN Chessnut clock bot uses the same hidden-board room',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(1280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        _botHarness(isChessnutClockDevice: true),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveChessBoard), findsOneWidget);
      expect(find.byTooltip('Hide board'), findsOneWidget);

      await tester.tap(find.byTooltip('Hide board'));
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveChessBoard), findsNothing);
      expect(find.byKey(const ValueKey('hidden-bot-room')), findsOneWidget);
      expect(find.text('Maia 1500'), findsOneWidget);
      expect(find.text('Chessnut Player'), findsOneWidget);
      expect(find.byKey(const ValueKey('hidden-bot-hint')), findsOneWidget);
      expect(find.byKey(const ValueKey('hidden-bot-settings')), findsOneWidget);
      expect(find.byTooltip('Show board'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('PGN-free Chessnut clock bot can hide and restore the board',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(1280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        _botHarness(
          isChessnutClockDevice: true,
          config: const BotGameConfig.defaultConfig().copyWith(
            showPgnList: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveChessBoard), findsOneWidget);
      expect(
          find.byKey(const ValueKey('clock-only-hide-board')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('clock-only-hide-board')));
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveChessBoard), findsNothing);
      expect(find.byKey(const ValueKey('hidden-bot-room')), findsOneWidget);
      expect(find.text('Maia 1500'), findsOneWidget);
      expect(find.text('Chessnut Player'), findsOneWidget);
      expect(find.byTooltip('Show board'), findsOneWidget);
      expect(find.byKey(const ValueKey('hidden-bot-hint')), findsOneWidget);
      expect(find.byKey(const ValueKey('hidden-bot-settings')), findsOneWidget);
      expect(find.byTooltip('More'), findsOneWidget);

      final hintButton = tester.widget<localized.IconButton>(
        find.byKey(const ValueKey('hidden-bot-hint')),
      );
      expect(hintButton.onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey('hidden-bot-settings')));
      await tester.pumpAndSettle();
      expect(find.text('Game options'), findsOneWidget);
      Navigator.of(tester.element(find.text('Game options'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Show board'));
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveChessBoard), findsOneWidget);
      expect(
          find.byKey(const ValueKey('clock-only-hide-board')), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Portrait phone hidden OTB top clock faces the opponent',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      for (final platform in const [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        await tester.pumpWidget(_otbHarness(key: ValueKey(platform)));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Hide board'));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('windows-hidden-otb-room')),
            findsOneWidget);
        expect(
          tester
              .widget<RotatedBox>(
                find.byKey(
                  const ValueKey(
                    'windows-hidden-otb-clock-Black-orientation',
                  ),
                ),
              )
              .quarterTurns,
          2,
        );
        expect(
          tester
              .widget<RotatedBox>(
                find.byKey(
                  const ValueKey(
                    'windows-hidden-otb-clock-White-orientation',
                  ),
                ),
              )
              .quarterTurns,
          0,
        );
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Portrait phone hidden OTB keeps flipped players aligned',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      for (final platform in const [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        await tester.pumpWidget(_otbHarness(key: ValueKey(platform)));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Flip'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Hide board'));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<RotatedBox>(
                find.byKey(
                  const ValueKey(
                    'windows-hidden-otb-clock-White-orientation',
                  ),
                ),
              )
              .quarterTurns,
          2,
        );
        expect(
          tester
              .widget<RotatedBox>(
                find.byKey(
                  const ValueKey(
                    'windows-hidden-otb-clock-Black-orientation',
                  ),
                ),
              )
              .quarterTurns,
          0,
        );
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('OTB record game accepts app board moves', (tester) async {
    tester.view.physicalSize = const Size(1280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_otbHarness());
    await tester.pumpAndSettle();

    await tester.tapAt(_boardSquareCenter(tester, 'e2'));
    await tester.pump();
    await tester.tapAt(_boardSquareCenter(tester, 'e4'));
    await tester.pumpAndSettle();

    expect(find.text('e4'), findsOneWidget);

    await tester.tapAt(_boardSquareCenter(tester, 'e7'));
    await tester.pump();
    await tester.tapAt(_boardSquareCenter(tester, 'e5'));
    await tester.pumpAndSettle();

    expect(find.text('e5'), findsOneWidget);
  });

  testWidgets('OTB record game exits directly through move four',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = MemoryPhysicalBoardGateway();
    await gateway.connect();
    addTearDown(gateway.dispose);
    final navigations = <String>[];

    await tester.pumpWidget(_otbHarness(
      boardGateway: gateway,
      onNavigate: navigations.add,
    ));
    await tester.pumpAndSettle();

    await _playPhysicalFens(tester, gateway, const [
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR',
      'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR',
      'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R',
      'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R',
    ]);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Game still in progress'), findsNothing);
    expect(navigations, contains('Back'));
  });

  testWidgets('OTB game over settings returns to OTB setup', (tester) async {
    tester.view.physicalSize = const Size(1280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final navigations = <String>[];

    await tester.pumpWidget(_otbHarness(onNavigate: navigations.add));
    await tester.pump();

    await tester.pump(const Duration(seconds: 60));
    await tester.pumpAndSettle();

    expect(find.text('Game over'), findsOneWidget);
    expect(find.text('Bot game settings'), findsNothing);
    expect(find.text('OTB game settings'), findsOneWidget);

    await tester.tap(find.text('OTB game settings'));
    await tester.pumpAndSettle();

    expect(navigations, contains('Back'));
  });

  testWidgets('OTB offer draw asks for confirmation', (tester) async {
    tester.view.physicalSize = const Size(1280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = MemoryPhysicalBoardGateway();
    await gateway.connect();
    addTearDown(gateway.dispose);

    await tester.pumpWidget(_otbHarness(boardGateway: gateway));
    await tester.pumpAndSettle();
    await _playPhysicalFens(tester, gateway, const [
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR',
      'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR',
    ]);

    await _openGameOptions(tester);
    await tester.ensureVisible(find.text('Offer draw'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Offer draw'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm draw?'), findsOneWidget);
    await tester.tap(find.text('Confirm draw'));
    await tester.pumpAndSettle();

    expect(find.text('Game over'), findsOneWidget);
    expect(find.text('Game drawn by agreement'), findsWidgets);
  });

  testWidgets('OTB request takeback asks for confirmation', (tester) async {
    tester.view.physicalSize = const Size(1280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = MemoryPhysicalBoardGateway();
    await gateway.connect();
    addTearDown(gateway.dispose);

    await tester.pumpWidget(_otbHarness(boardGateway: gateway));
    await tester.pumpAndSettle();
    await _playPhysicalFens(tester, gateway, const [
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR',
      'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR',
    ]);

    await _openGameOptions(tester);
    await tester.ensureVisible(find.text('Request takeback'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request takeback'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm takeback?'), findsOneWidget);
    await tester.tap(find.text('Confirm takeback'));
    await tester.pumpAndSettle();

    expect(find.text('Move taken back.'), findsOneWidget);
    expect(find.text('e5'), findsNothing);
    expect(find.text('e4'), findsOneWidget);
  });

  testWidgets('OTB player cards only show turn detail for the active side',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = MemoryPhysicalBoardGateway();
    await gateway.connect();
    addTearDown(gateway.dispose);

    await tester.pumpWidget(_otbHarness(boardGateway: gateway));
    await tester.pumpAndSettle();

    expect(find.textContaining('Face-to-face'), findsNothing);
    expect(find.textContaining('pieces detected'), findsNothing);
    expect(find.text('Your turn / legal moves only'), findsOneWidget);

    await _playPhysicalFens(tester, gateway, const [
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR',
    ]);

    expect(find.text('Your turn / legal moves only'), findsOneWidget);
    expect(find.textContaining('Face-to-face'), findsNothing);
  });
}

Widget _otbHarness({
  Key? key,
  ValueChanged<String>? onNavigate,
  PhysicalBoardGateway? boardGateway,
  bool isChessnutClockDevice = false,
  OtbGameConfig config = const OtbGameConfig(
    timeMinutes: 1,
    incrementSeconds: 0,
  ),
}) {
  return MaterialApp(
    theme: ChessnutTheme.light(),
    home: Scaffold(
      body: GameRoomScreen(
        key: key,
        onNavigate: onNavigate ?? (_) {},
        mode: GameLaunchMode.otb,
        boardGateway: boardGateway,
        otbConfig: config,
        isChessnutClockDevice: isChessnutClockDevice,
        clockSwitchService: ChessClockSwitchService(enableUsbButtons: false),
      ),
    ),
  );
}

Widget _botHarness({
  Key? key,
  bool isChessnutClockDevice = false,
  BotGameConfig config = const BotGameConfig.defaultConfig(),
}) {
  return MaterialApp(
    theme: ChessnutTheme.light(),
    home: Scaffold(
      body: GameRoomScreen(
        key: key,
        onNavigate: (_) {},
        mode: GameLaunchMode.bot,
        botConfig: config,
        botEngine: const _NoopBotEngineAdapter(),
        isChessnutClockDevice: isChessnutClockDevice,
        clockSwitchService: ChessClockSwitchService(enableUsbButtons: false),
      ),
    ),
  );
}

class _NoopBotEngineAdapter extends BotEngineAdapter {
  const _NoopBotEngineAdapter();

  @override
  Future<BotMoveResult?> bestMove({
    required String fen,
    required BotGameConfig config,
    List<String> moveHistory = const [],
  }) async {
    return null;
  }
}

Future<void> _playPhysicalFens(
  WidgetTester tester,
  MemoryPhysicalBoardGateway gateway,
  List<String> fens,
) async {
  for (final fen in fens) {
    gateway.addBoardFen(fen);
    gateway.addBoardFen(fen);
    await tester.pump(const Duration(milliseconds: 850));
    await tester.pumpAndSettle();
  }
}

Future<void> _openGameOptions(WidgetTester tester) async {
  await tester.tap(find.byTooltip('More'));
  await tester.pumpAndSettle();
  expect(find.text('Game options'), findsOneWidget);
}

Offset _boardSquareCenter(WidgetTester tester, String square) {
  final boardRect = tester.getRect(find.byType(InteractiveChessBoard).first);
  final file = ChessBoard.files.indexOf(square[0]);
  final rank = int.parse(square.substring(1));
  final squareSize = boardRect.width / 8;
  return Offset(
    boardRect.left + (file + 0.5) * squareSize,
    boardRect.top + (8 - rank + 0.5) * squareSize,
  );
}
