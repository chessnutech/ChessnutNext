import 'package:chessnut_flutter_export/l10n/app_language.dart';
import 'package:chessnut_flutter_export/l10n/app_strings.dart';
import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/screens/game_room_screen.dart';
import 'package:chessnut_flutter_export/services/physical_board_gateway.dart';
import 'package:chessnut_flutter_export/theme/chessnut_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Android portrait robot game uses the iOS title', (tester) async {
    await _pumpAndroidGame(tester);

    expect(find.text('Robot battle'), findsOneWidget);
    expect(find.text('BOT GAME ROOM'), findsNothing);
    _expectTitleBeforeStatus(tester, 'Robot battle');
  });

  testWidgets('Android portrait career game uses the iOS title',
      (tester) async {
    await _pumpAndroidGame(tester, career: true);

    expect(find.text('Career challenge'), findsOneWidget);
    expect(find.text('BOT GAME ROOM'), findsNothing);
    _expectTitleBeforeStatus(tester, 'Career challenge');
  });

  testWidgets('Android portrait Lichess game uses the compact iOS title',
      (tester) async {
    await _pumpAndroidGame(
      tester,
      mode: GameLaunchMode.lichess,
      size: const Size(360, 800),
    );

    final titleFinder = find.text('Lichess');
    final title = tester.getRect(titleFinder);
    final time = tester.getRect(find.text('10+5'));
    final status = tester.getRect(
      find.byKey(const ValueKey('game-room-status-capsules')),
    );
    expect(title.right, lessThanOrEqualTo(status.left));
    expect(time.right, lessThanOrEqualTo(status.left));
    expect(
      tester.renderObject<RenderParagraph>(titleFinder).didExceedMaxLines,
      isFalse,
    );
    expect(find.text('Lichess game'), findsNothing);
  });

  testWidgets('Android portrait OTB title fits beside Move board controls',
      (tester) async {
    await _pumpAndroidGame(
      tester,
      mode: GameLaunchMode.otb,
      boardModel: PhysicalBoardModel.move,
      size: const Size(360, 800),
    );

    final titleFinder = find.text('OTB Game 10+5');
    final title = tester.getRect(titleFinder);
    final status = tester.getRect(
      find.byKey(const ValueKey('game-room-status-capsules')),
    );
    expect(title.right, lessThanOrEqualTo(status.left));
    expect(
      tester.renderObject<RenderParagraph>(titleFinder).didExceedMaxLines,
      isFalse,
    );
  });

  testWidgets('Android portrait disconnected OTB title stays prominent',
      (tester) async {
    await _pumpAndroidGame(
      tester,
      mode: GameLaunchMode.otb,
      boardModel: PhysicalBoardModel.move,
      connectBoard: false,
    );

    final titleFinder = find.text('OTB Game 10+5');
    final title = tester.getRect(titleFinder);
    final status = tester.getRect(
      find.byKey(const ValueKey('game-room-status-capsules')),
    );
    expect(title.height, greaterThanOrEqualTo(20));
    expect(title.overlaps(status), isFalse);
  });

  testWidgets('Android landscape keeps the existing bot title', (tester) async {
    await _pumpAndroidGame(tester, size: const Size(844, 390));

    expect(find.text('Maia 1500 / 10+5'), findsOneWidget);
    expect(find.text('BOT GAME ROOM'), findsOneWidget);
    expect(find.text('Robot battle'), findsNothing);
  });

  testWidgets('Chessnut Clock keeps the existing bot title in portrait',
      (tester) async {
    await _pumpAndroidGame(tester, isChessnutClockDevice: true);

    expect(find.text('Maia 1500 / 10+5'), findsOneWidget);
    expect(find.text('BOT GAME ROOM'), findsOneWidget);
    expect(find.text('Robot battle'), findsNothing);
  });
}

Future<void> _pumpAndroidGame(
  WidgetTester tester, {
  GameLaunchMode mode = GameLaunchMode.bot,
  Size size = const Size(390, 844),
  bool career = false,
  bool isChessnutClockDevice = false,
  PhysicalBoardModel boardModel = PhysicalBoardModel.air,
  bool connectBoard = true,
}) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final gateway = MemoryPhysicalBoardGateway(
    boardModel: boardModel,
  );
  if (connectBoard) await gateway.connect();
  addTearDown(gateway.dispose);
  final careerMode = career
      ? const CareerModeConfig(
          startElo: 1500,
          winElo: 1525,
          loseElo: 1475,
          opponentName: 'Career opponent',
          opponentAvatarAsset: '',
        )
      : null;

  try {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        theme: ChessnutTheme.light(),
        supportedLocales: AppLanguagePreference.supportedLocales,
        localizationsDelegates: AppStrings.localizationsDelegates,
        home: Scaffold(
          body: GameRoomScreen(
            onNavigate: (_) {},
            mode: mode,
            boardGateway: gateway,
            botConfig: const BotGameConfig.defaultConfig().copyWith(
              careerMode: careerMode,
            ),
            lichessConfig: const LichessGameConfig(
              gameId: 'lichess-game-1',
              token: 'lichess-token',
              lichessName: 'ChessnutPlayer',
            ),
            isChessnutClockDevice: isChessnutClockDevice,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void _expectTitleBeforeStatus(WidgetTester tester, String titleText) {
  final title = tester.getRect(find.text(titleText));
  final status = tester.getRect(
    find.byKey(const ValueKey('game-room-status-capsules')),
  );
  expect(title.right, lessThanOrEqualTo(status.left));
}
