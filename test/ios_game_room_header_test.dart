import 'package:chessnut_flutter_export/l10n/app_language.dart';
import 'package:chessnut_flutter_export/l10n/app_strings.dart';
import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/screens/game_room_screen.dart';
import 'package:chessnut_flutter_export/services/physical_board_gateway.dart';
import 'package:chessnut_flutter_export/theme/chessnut_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final titleTranslations = <(Locale, String, String)>[
    (const Locale('en'), 'Robot battle', 'Career challenge'),
    (
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      '机器人对战',
      '生涯挑战',
    ),
    (
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      '機器人對戰',
      '生涯挑戰',
    ),
    (const Locale('de'), 'Roboterduell', 'Karriere-Herausforderung'),
    (const Locale('es'), 'Partida contra robot', 'Desafío de carrera'),
    (const Locale('fr'), 'Partie contre un robot', 'Défi de carrière'),
    (const Locale('it'), 'Partita contro un robot', 'Sfida carriera'),
    (const Locale('ja'), 'ロボット対戦', 'キャリアチャレンジ'),
    (const Locale('ko'), '로봇 대국', '커리어 도전'),
    (const Locale('nl'), 'Partij tegen robot', 'Carrière-uitdaging'),
    (const Locale('ru'), 'Игра с роботом', 'Карьерное испытание'),
  ];

  test('iOS game header titles are localized in every app language', () {
    for (final (locale, robotTitle, careerTitle) in titleTranslations) {
      final strings = AppStrings(locale);
      expect(strings.t('Robot battle'), robotTitle);
      expect(strings.t('Career challenge'), careerTitle);
    }
  });

  testWidgets('iOS robot header pins board status to the top right',
      (tester) async {
    await _pumpIosGame(
      tester,
      locale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
      ),
    );

    expect(find.text('机器人对战'), findsOneWidget);
    expect(find.text('Bot game room'), findsNothing);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    _expectBoardStatusPinnedToHeaderTopRight(tester, '机器人对战');
  });

  testWidgets('iOS career header uses the localized career title',
      (tester) async {
    await _pumpIosGame(
      tester,
      locale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
      ),
      career: true,
    );

    expect(find.text('生涯挑战'), findsOneWidget);
    expect(find.text('Bot game room'), findsNothing);
    _expectBoardStatusPinnedToHeaderTopRight(tester, '生涯挑战');
  });

  testWidgets('iOS robot title scales down instead of using an ellipsis',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpIosGame(tester, locale: const Locale('it'));

    final title = tester.widget<Text>(find.text('Partita contro un robot'));
    expect(title.overflow, TextOverflow.visible);
    expect(title.maxLines, 1);
    expect(title.softWrap, isFalse);
    expect(
      find.byKey(const ValueKey('ios-bot-game-title-fit')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS landscape pins board status to the page top right',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpIosGame(tester, locale: const Locale('de'));

    final statusHost = tester.getRect(
      find.byKey(const ValueKey('ios-bot-board-status-top-right')),
    );
    final status = tester.getRect(
      find.byKey(const ValueKey('game-room-status-capsules')),
    );
    final header = tester.getRect(
      find.byKey(const ValueKey('game-compact-header')),
    );
    final title = tester.getRect(find.text('Roboterduell'));
    expect(header.contains(title.center), isTrue);
    expect(statusHost.right, closeTo(1024 - 10, 0.01));
    expect(statusHost.top, closeTo(8, 0.01));
    expect(status.right, closeTo(statusHost.right, 0.01));
    expect(status.center.dx, greaterThan(header.right));
  });

  testWidgets('non-iOS bot header keeps the existing game copy',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final gateway = MemoryPhysicalBoardGateway();
    await gateway.connect();
    addTearDown(gateway.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        theme: ChessnutTheme.light(),
        supportedLocales: AppLanguagePreference.supportedLocales,
        localizationsDelegates: AppStrings.localizationsDelegates,
        home: Scaffold(
          body: GameRoomScreen(
            onNavigate: (_) {},
            mode: GameLaunchMode.bot,
            boardGateway: gateway,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;

    expect(find.text('Maia 1500 / 10+5'), findsOneWidget);
    expect(find.text('BOT GAME ROOM'), findsOneWidget);
    expect(find.text('Robot battle'), findsNothing);
  });
}

Future<void> _pumpIosGame(
  WidgetTester tester, {
  required Locale locale,
  bool career = false,
}) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  if (tester.view.physicalSize == const Size(800, 600)) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  final gateway = MemoryPhysicalBoardGateway(
    boardModel: PhysicalBoardModel.air,
  );
  await gateway.connect();
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

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: ChessnutTheme.light(),
      supportedLocales: AppLanguagePreference.supportedLocales,
      localizationsDelegates: AppStrings.localizationsDelegates,
      home: Scaffold(
        body: GameRoomScreen(
          onNavigate: (_) {},
          mode: GameLaunchMode.bot,
          boardGateway: gateway,
          botConfig: const BotGameConfig.defaultConfig().copyWith(
            careerMode: careerMode,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  debugDefaultTargetPlatformOverride = null;
}

void _expectBoardStatusPinnedToHeaderTopRight(
  WidgetTester tester,
  String titleText,
) {
  final header = tester.getRect(
    find.byKey(const ValueKey('ios-bot-game-header')),
  );
  final title = tester.getRect(find.text(titleText));
  final statusHost = tester.getRect(
    find.byKey(const ValueKey('ios-bot-board-status-top-right')),
  );
  final status = tester.getRect(
    find.byKey(const ValueKey('game-room-status-capsules')),
  );
  expect(title.bottom, greaterThan(status.top));
  expect(status.bottom, greaterThan(title.top));
  expect(title.right, lessThanOrEqualTo(status.left));
  expect(statusHost.top, closeTo(header.top, 0.01));
  expect(statusHost.right, closeTo(header.right, 0.01));
  expect(status.right, closeTo(header.right, 0.01));
}
