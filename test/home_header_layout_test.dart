import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chessnut_flutter_export/l10n/app_language.dart';
import 'package:chessnut_flutter_export/l10n/app_strings.dart';
import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/screens/home_screen.dart';
import 'package:chessnut_flutter_export/services/android_accessibility_vision_service.dart';
import 'package:chessnut_flutter_export/services/chessnut_api_client.dart';
import 'package:chessnut_flutter_export/services/daily_claim_service.dart';
import 'package:chessnut_flutter_export/theme/chessnut_theme.dart';
import 'package:chessnut_flutter_export/widgets/app_chrome.dart';

const _session = ChessnutLoginSession(
  userId: 7,
  token: '12345678901234567890123456789012',
  refreshToken: 'refresh-token',
  avatarUrl: '',
  bindApple: false,
  bindChess: false,
  bindGoogle: false,
  bindLichess: false,
  chessName: '',
  email: 'player@example.com',
  lichessName: '',
  noPassword: false,
  phone: '',
  region: 'US',
  username: 'Chessnut Player',
);

Widget _testShell(
  Widget child, {
  Locale? locale,
}) {
  return MaterialApp(
    locale: locale,
    theme: ChessnutTheme.light(),
    supportedLocales: AppLanguagePreference.supportedLocales,
    localizationsDelegates: AppStrings.localizationsDelegates,
    home: Scaffold(body: child),
  );
}

ChessnutApiClient _walletClient({int balance = 1376}) {
  return ChessnutApiClient(
    session: _session,
    httpClient: MockClient((request) async {
      if (request.url.path == '/api/wallet/balance') {
        return http.Response(
          jsonEncode({
            'ret': 1,
            'code': 200,
            'info': 'ok',
            'data': {
              'balance': balance,
              'claimed_today': false,
              'claimed_task_keys': <String>[],
            },
          }),
          200,
        );
      }
      return http.Response('not found', 404);
    }),
  );
}

Future<void> _openContinueGamesDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('home-continue-notice')));
  await tester.pumpAndSettle();
}

void main() {
  const botRecord = GameRecord(
    result: '*',
    title: 'kyle vs Maia 3 1200',
    subtitle: '10+5',
    pgn: '''
[Event "Bot game room"]
[Site "Chessnut App"]
[White "kyle"]
[Black "Maia 3 1200"]
[Result "*"]

1. e4 e5 *
''',
    pgnId: 42,
    playMode: 'bot',
    gameStatus: 1,
    winId: 0,
    whiteName: 'kyle',
    blackName: 'Maia 3 1200',
  );

  const onlineRecord = GameRecord(
    result: '*',
    title: 'kyle vs nightbishop',
    subtitle: '5+3',
    pgn: '''
[Event "Native game room"]
[Site "Chessnut App"]
[White "kyle"]
[Black "nightbishop"]
[Result "*"]
[LichessGameId "lichess-game-1"]

1. e4 e5 *
''',
    pgnId: 43,
    playMode: 'lichess',
    gameStatus: 1,
    winId: 0,
    whiteName: 'kyle',
    blackName: 'nightbishop',
  );

  testWidgets('home exposes balanced core entries for signed-in users',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final navigations = <String>[];
    await tester.pumpWidget(
      _testShell(
        HomeScreen(
          onNavigate: navigations.add,
          boardConnected: false,
          boardModel: ChessnutBoardModel.unknown,
          dailyClaimService: DailyClaimService(
            store: InMemoryDailyClaimStore(),
          ),
          apiClient: _walletClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chessnut'), findsOneWidget);
    expect(find.text('BOARD NOT CONNECTED'), findsOneWidget);
    expect(find.text('Connect board'), findsNothing);

    for (final key in [
      'home-action-play',
      'home-action-career',
      'home-action-analysis',
      'home-action-training',
      'home-action-records',
      'home-action-engine',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
    expect(find.text('Career'), findsOneWidget);
    expect(find.text('Records'), findsOneWidget);
    expect(find.text('Game review'), findsOneWidget);
    expect(find.text('Game history'), findsOneWidget);
    expect(find.text('PGN / Grandeur'), findsNothing);
    expect(find.text('Review games'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('home-action-career')));
    await tester.pump();

    expect(navigations, contains('Career'));

    await tester.tap(find.byKey(const ValueKey('home-action-records')));
    await tester.pump();

    expect(navigations, contains('Records'));
  });

  testWidgets('Android phone home uses the compact landscape split',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(right: 48);
    tester.view.viewPadding = const FakeViewPadding(right: 48);
    try {
      await tester.pumpWidget(
        _testShell(
          SafeArea(
            top: false,
            bottom: false,
            child: HomeScreen(
              onNavigate: (_) {},
              boardConnected: false,
              boardModel: ChessnutBoardModel.unknown,
              dailyClaimService: DailyClaimService(
                store: InMemoryDailyClaimStore(),
              ),
              apiClient: _walletClient(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final layout = find.byKey(
        const ValueKey('home-android-phone-landscape'),
      );
      final hero = find.byKey(const ValueKey('home-board-hero'));
      final play = find.byKey(const ValueKey('home-action-play'));

      expect(layout, findsOneWidget);
      expect(hero, findsOneWidget);
      expect(
        find.byKey(const ValueKey('home-companion-actions-scroll')),
        findsOneWidget,
      );
      for (final key in [
        'home-action-play',
        'home-action-career',
        'home-action-analysis',
        'home-action-training',
        'home-action-records',
        'home-action-engine',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }

      expect(tester.getRect(hero).center.dx,
          lessThan(tester.getRect(play).center.dx));
      expect(tester.getRect(layout).bottom, lessThanOrEqualTo(390));
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    }
  });

  testWidgets('home title uses Companion branding on chess clocks',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testShell(
        HomeScreen(
          onNavigate: (_) {},
          boardConnected: true,
          boardModel: ChessnutBoardModel.air,
          dailyClaimService: DailyClaimService(
            store: InMemoryDailyClaimStore(),
          ),
          apiClient: _walletClient(),
          isChessnutClockDevice: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chessnut Companion'), findsOneWidget);
    expect(find.text('Chessnut'), findsNothing);
  });

  testWidgets('home title uses EVO2 branding on EVO2 hardware', (tester) async {
    tester.view.physicalSize = const Size(1280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testShell(
        HomeScreen(
          onNavigate: (_) {},
          boardConnected: true,
          boardModel: ChessnutBoardModel.evo2,
          dailyClaimService: DailyClaimService(
            store: InMemoryDailyClaimStore(),
          ),
          apiClient: _walletClient(),
          isChessnutEvo2Device: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chessnut EVO2'), findsOneWidget);
    expect(find.text('Chessnut'), findsNothing);
  });

  testWidgets('home hides physical board connection UI on EVO2 hardware',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testShell(
        HomeScreen(
          onNavigate: (_) {},
          boardConnected: false,
          boardModel: ChessnutBoardModel.evo2,
          dailyClaimService: DailyClaimService(
            store: InMemoryDailyClaimStore(),
          ),
          apiClient: _walletClient(),
          isChessnutEvo2Device: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chessnut EVO2'), findsOneWidget);
    expect(find.text('BOARD NOT CONNECTED'), findsNothing);
    expect(find.text('Pair your physical board'), findsNothing);
    expect(find.text('Connect before play'), findsNothing);
    expect(find.byKey(const ValueKey('home-action-play')), findsOneWidget);
  });

  testWidgets('home does not show a fake continue card without a saved game',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testShell(
        HomeScreen(
          onNavigate: (_) {},
          boardConnected: true,
          boardModel: ChessnutBoardModel.air,
          dailyClaimService: DailyClaimService(
            store: InMemoryDailyClaimStore(),
          ),
          apiClient: _walletClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue Rapid 10+5'), findsNothing);
    expect(find.text('White to move / board synced'), findsNothing);
    expect(find.text('Continue online game'), findsNothing);
    expect(find.text('Continue bot game'), findsNothing);
  });

  testWidgets('home header hides the points pill', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testShell(
        HomeScreen(
          onNavigate: (_) {},
          boardConnected: false,
          boardModel: ChessnutBoardModel.unknown,
          dailyClaimService: DailyClaimService(
            store: InMemoryDailyClaimStore(),
          ),
          apiClient: _walletClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ScreenHeader), findsOneWidget);
    expect(find.byKey(const ValueKey('home-points-pill')), findsNothing);
    expect(
        find.byKey(const ValueKey('home-points-guest-locked')), findsNothing);
    expect(find.text('pts'), findsNothing);
  });

  testWidgets('home title has enough room beside header actions',
      (tester) async {
    Future<void> pumpHome(Size size, {bool vision = false}) async {
      debugDefaultTargetPlatformOverride =
          vision ? TargetPlatform.android : null;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        _testShell(
          HomeScreen(
            onNavigate: (_) {},
            boardConnected: false,
            boardModel: ChessnutBoardModel.unknown,
            dailyClaimService: DailyClaimService(
              store: InMemoryDailyClaimStore(),
            ),
            apiClient: _walletClient(),
            visionEnabled: false,
            onVisionEnabledChanged: vision ? (_) {} : null,
            accessibilityVisionService:
                vision ? _FakeAccessibilityVisionBridge(running: true) : null,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await pumpHome(const Size(390, 844), vision: true);

    final titleFinder = find.byKey(const ValueKey('home-header-title'));
    final titleWidget = tester.widget(titleFinder) as dynamic;
    final titleHeight = tester.getSize(titleFinder).height;
    final style = (titleWidget.style as TextStyle?) ??
        ThemeData().textTheme.headlineSmall!;
    final lineHeight = (style.fontSize ?? 24) * (style.height ?? 1.35);
    final titlePainter = TextPainter(
      text: TextSpan(text: 'Chessnut', style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    expect(find.text('Chessnut'), findsOneWidget);
    expect(titleWidget.maxLines, 1);
    expect(titleWidget.overflow, TextOverflow.visible);
    expect(titleHeight, lessThan(lineHeight * 1.25));
    expect(tester.getSize(titleFinder).width,
        greaterThanOrEqualTo(titlePainter.width));
    expect(find.text('Vision'), findsOneWidget);
    expect(find.text('pts'), findsNothing);

    await pumpHome(const Size(844, 390));
    final landscapeTitleHeight = tester.getSize(titleFinder).height;
    expect(landscapeTitleHeight, lessThan(lineHeight * 1.25));
  });

  testWidgets('home header shows the Android system Vision toggle',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final visionChanges = <bool>[];
      final accessibilityService = _FakeAccessibilityVisionBridge(
        running: true,
      );
      await tester.pumpWidget(
        _testShell(
          HomeScreen(
            onNavigate: (_) {},
            boardConnected: false,
            boardModel: ChessnutBoardModel.unknown,
            dailyClaimService: DailyClaimService(
              store: InMemoryDailyClaimStore(),
            ),
            apiClient: _walletClient(),
            visionEnabled: false,
            onVisionEnabledChanged: visionChanges.add,
            accessibilityVisionService: accessibilityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('home-vision-toggle')), findsOneWidget);
      expect(find.byTooltip('Chessnut Vision is off'), findsOneWidget);
      expect(find.byKey(const ValueKey('home-points-pill')), findsNothing);

      await tester.tap(find.text('Vision'));
      await tester.pumpAndSettle();

      expect(find.text('Enable Chessnut Vision?'), findsOneWidget);
      await tester.tap(find.text('Enable Vision'));
      await tester.pumpAndSettle();

      expect(accessibilityService.checks, 1);
      expect(visionChanges, [true]);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('home Vision toggle opens accessibility settings before enabling',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final visionChanges = <bool>[];
      final accessibilityService = _FakeAccessibilityVisionBridge(
        running: false,
      );
      await tester.pumpWidget(
        _testShell(
          HomeScreen(
            onNavigate: (_) {},
            boardConnected: false,
            boardModel: ChessnutBoardModel.unknown,
            dailyClaimService: DailyClaimService(
              store: InMemoryDailyClaimStore(),
            ),
            apiClient: _walletClient(),
            visionEnabled: false,
            onVisionEnabledChanged: visionChanges.add,
            accessibilityVisionService: accessibilityService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Vision'));
      await tester.pumpAndSettle();

      expect(accessibilityService.checks, 1);
      expect(find.text('Enable Chessnut Vision?'), findsNothing);
      expect(
        find.text('Turn on Chessnut Vision in Accessibility'),
        findsOneWidget,
      );
      expect(visionChanges, isEmpty);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(accessibilityService.openSettingsCalls, 1);
      expect(visionChanges, isEmpty);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('home hides the system Vision toggle off Android',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final visionChanges = <bool>[];
      await tester.pumpWidget(
        _testShell(
          HomeScreen(
            onNavigate: (_) {},
            boardConnected: false,
            boardModel: ChessnutBoardModel.unknown,
            dailyClaimService: DailyClaimService(
              store: InMemoryDailyClaimStore(),
            ),
            apiClient: _walletClient(),
            visionEnabled: true,
            onVisionEnabledChanged: visionChanges.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('home-vision-toggle')), findsNothing);
      expect(visionChanges, isEmpty);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('home continue card localizes and fits on narrow Chinese screens',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        _testShell(
          HomeScreen(
            onNavigate: (_) {},
            boardConnected: false,
            boardModel: ChessnutBoardModel.unknown,
            dailyClaimService: DailyClaimService(
              store: InMemoryDailyClaimStore(),
            ),
            apiClient: _walletClient(balance: 150),
            continueBotRecord: botRecord,
            onContinueRecord: (_) async {},
            onDismissContinueRecord: (_) {},
          ),
          locale: const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hans',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openContinueGamesDialog(tester);

      expect(find.text('继续机器人对局'), findsOneWidget);
      expect(find.text('Continue bot game'), findsNothing);
      expect(find.byKey(const ValueKey('home-continue-action-bot')),
          findsOneWidget);
      expect(find.text('继续'), findsOneWidget);
      expect(find.text('Resume'), findsNothing);

      final titleFinder = find.byKey(const ValueKey('home-continue-title-bot'));
      final title = tester.widget(titleFinder) as dynamic;
      final titleRect = tester.getRect(titleFinder);
      final subtitleRect = tester
          .getRect(find.byKey(const ValueKey('home-continue-subtitle-bot')));
      final actionRect = tester
          .getRect(find.byKey(const ValueKey('home-continue-action-bot')));
      final dismissRect = tester
          .getRect(find.byKey(const ValueKey('home-continue-dismiss-bot')));
      expect(title.maxLines, 2);
      expect(actionRect.size, const Size(96, 40));
      expect(dismissRect.size, const Size(40, 40));
      expect(titleRect.right, lessThanOrEqualTo(actionRect.left));
      expect(subtitleRect.right, lessThanOrEqualTo(actionRect.left));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('home continue card uses the readable compact action size on iOS',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        _testShell(
          HomeScreen(
            onNavigate: (_) {},
            boardConnected: false,
            boardModel: ChessnutBoardModel.unknown,
            dailyClaimService: DailyClaimService(
              store: InMemoryDailyClaimStore(),
            ),
            apiClient: _walletClient(balance: 150),
            continueBotRecord: botRecord,
            onContinueRecord: (_) async {},
            onDismissContinueRecord: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openContinueGamesDialog(tester);

      final title = tester.widget(
        find.byKey(const ValueKey('home-continue-title-bot')),
      ) as dynamic;
      final actionSize = tester.getSize(
        find.byKey(const ValueKey('home-continue-action-bot')),
      );
      final dismissSize = tester.getSize(
        find.byKey(const ValueKey('home-continue-dismiss-bot')),
      );
      expect(title.maxLines, 2);
      expect(actionSize, const Size(96, 40));
      expect(dismissSize, const Size(40, 40));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('home Android Resume label stays on one line', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        _testShell(
          HomeScreen(
            onNavigate: (_) {},
            boardConnected: false,
            boardModel: ChessnutBoardModel.unknown,
            dailyClaimService: DailyClaimService(
              store: InMemoryDailyClaimStore(),
            ),
            apiClient: _walletClient(balance: 150),
            continueBotRecord: botRecord,
            onContinueRecord: (_) async {},
            onDismissContinueRecord: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openContinueGamesDialog(tester);

      final labelFinder = find.byKey(const ValueKey('home-continue-label-bot'));
      final label = tester.widget(labelFinder) as dynamic;
      expect(find.text('Resume'), findsOneWidget);
      expect(label.maxLines, 1);
      expect(label.softWrap, isFalse);
      expect(
        find.ancestor(of: labelFinder, matching: find.byType(FittedBox)),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('home-continue-action-bot'))),
        const Size(96, 40),
      );
      final actionRect = tester
          .getRect(find.byKey(const ValueKey('home-continue-action-bot')));
      final labelCenterRect = tester.getRect(
        find.byKey(const ValueKey('home-continue-label-center-bot')),
      );
      final iconRect =
          tester.getRect(find.byKey(const ValueKey('home-continue-icon-bot')));
      final labelRect = tester.getRect(labelFinder);
      final labelStyle = label.style as TextStyle;
      expect(iconRect.size, const Size(16, 16));
      expect(labelStyle.fontSize, 16);
      expect(labelStyle.fontWeight, FontWeight.w800);
      expect(
        labelCenterRect.center.dx,
        closeTo(actionRect.center.dx, 0.1),
      );
      expect(
        labelCenterRect.center.dy,
        closeTo(actionRect.center.dy, 0.1),
      );
      expect(labelRect.left - iconRect.right, greaterThanOrEqualTo(5));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('home chess clock uses the readable Resume action',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        _testShell(
          HomeScreen(
            onNavigate: (_) {},
            boardConnected: false,
            boardModel: ChessnutBoardModel.unknown,
            dailyClaimService: DailyClaimService(
              store: InMemoryDailyClaimStore(),
            ),
            apiClient: _walletClient(balance: 150),
            continueBotRecord: botRecord,
            onContinueRecord: (_) async {},
            onDismissContinueRecord: (_) {},
            isChessnutClockDevice: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openContinueGamesDialog(tester);

      final title = tester.widget(
        find.byKey(const ValueKey('home-continue-title-bot')),
      ) as dynamic;
      final actionSize = tester.getSize(
        find.byKey(const ValueKey('home-continue-action-bot')),
      );
      expect(title.maxLines, 2);
      expect(actionSize, const Size(96, 40));
      expect(find.byKey(const ValueKey('home-continue-label-bot')),
          findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('home shows continue cards on chess clock landscape screens',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testShell(
        HomeScreen(
          onNavigate: (_) {},
          boardConnected: true,
          boardModel: ChessnutBoardModel.air,
          dailyClaimService: DailyClaimService(
            store: InMemoryDailyClaimStore(),
          ),
          apiClient: _walletClient(balance: 150),
          continueBotRecord: botRecord,
          continueOnlineRecord: onlineRecord,
          onContinueRecord: (_) async {},
          onDismissContinueRecord: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openContinueGamesDialog(tester);

    expect(find.text('Continue online game'), findsOneWidget);
    expect(find.text('Continue bot game'), findsOneWidget);
    expect(
        find.byKey(
            const ValueKey('home-continue-action-online-lichess-game-1')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('home-continue-action-bot')), findsOneWidget);
  });

  testWidgets('home shows every ongoing Lichess game', (tester) async {
    const secondOnlineRecord = GameRecord(
      result: '*',
      title: 'Chessnut Player vs second-player',
      subtitle: 'Lichess',
      pgn: '''
[Event "Lichess"]
[Site "https://lichess.org/second-game"]
[White "Chessnut Player"]
[Black "second-player"]
[Result "*"]
[LichessGameId "second-game"]
[GameStatus "1"]

*''',
      playMode: 'lichess',
      gameStatus: 1,
      winId: 0,
      whiteName: 'Chessnut Player',
      blackName: 'second-player',
      lichessGameIdOverride: 'second-game',
      opponentNameOverride: 'second-player',
      speedOverride: 'rapid',
    );

    String? continuedGameId;
    await tester.pumpWidget(
      _testShell(
        HomeScreen(
          onNavigate: (_) {},
          boardConnected: true,
          boardModel: ChessnutBoardModel.air,
          dailyClaimService: DailyClaimService(
            store: InMemoryDailyClaimStore(),
          ),
          apiClient: _walletClient(balance: 150),
          continueOnlineRecords: const [onlineRecord, secondOnlineRecord],
          onContinueRecord: (record) async {
            continuedGameId = record.lichessGameId;
          },
          onDismissContinueRecord: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openContinueGamesDialog(tester);

    expect(find.text('Continue online game'), findsNWidgets(2));
    expect(
      find.byKey(
        const ValueKey('home-continue-card-online-lichess-game-1'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-continue-card-online-second-game')),
      findsOneWidget,
    );
    expect(find.text('second-player · Lichess rapid'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey('home-continue-action-online-second-game'),
      ),
    );
    await tester.pump();
    expect(continuedGameId, 'second-game');
  });

  testWidgets('home action tiles are denser on chess clock landscape screens',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testShell(
        HomeScreen(
          onNavigate: (_) {},
          boardConnected: true,
          boardModel: ChessnutBoardModel.air,
          dailyClaimService: DailyClaimService(
            store: InMemoryDailyClaimStore(),
          ),
          apiClient: _walletClient(balance: 150),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final playTile = tester.getRect(
      find.byKey(const ValueKey('home-action-play')),
    );
    final icon = tester.widget<Icon>(
      find
          .descendant(
            of: find.byKey(const ValueKey('home-action-play')),
            matching: find.byIcon(Icons.play_arrow_rounded),
          )
          .first,
    );
    final title = tester.widget<Text>(find.text('Play').first);

    expect(playTile.height, lessThanOrEqualTo(76));
    expect(icon.size, greaterThanOrEqualTo(23));
    expect(title.style?.fontSize, greaterThanOrEqualTo(16));
  });

  testWidgets('Windows maximized home uses a balanced three-column action grid',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        _testShell(
          HomeScreen(
            onNavigate: (_) {},
            boardConnected: false,
            boardModel: ChessnutBoardModel.unknown,
            dailyClaimService: DailyClaimService(
              store: InMemoryDailyClaimStore(),
            ),
            apiClient: _walletClient(balance: 150),
            continueBotRecord: botRecord,
            onContinueRecord: (_) async {},
            onDismissContinueRecord: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openContinueGamesDialog(tester);

      final hero = tester.getRect(
        find.byKey(const ValueKey('home-board-hero')),
      );
      final play = tester.getRect(
        find.byKey(const ValueKey('home-action-play')),
      );
      final career = tester.getRect(
        find.byKey(const ValueKey('home-action-career')),
      );
      final analysis = tester.getRect(
        find.byKey(const ValueKey('home-action-analysis')),
      );
      final practice = tester.getRect(
        find.byKey(const ValueKey('home-action-training')),
      );
      final records = tester.getRect(
        find.byKey(const ValueKey('home-action-records')),
      );
      final engine = tester.getRect(
        find.byKey(const ValueKey('home-action-engine')),
      );

      expect(play.top, career.top);
      expect(career.top, analysis.top);
      expect(practice.top, records.top);
      expect(records.top, engine.top);
      expect(practice.top, greaterThan(play.top));
      expect(play.left, lessThan(career.left));
      expect(career.left, lessThan(analysis.left));
      expect(hero.width, lessThan(analysis.right - play.left));
      expect(hero.height, greaterThan(400));
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Windows 16:9 resize keeps the desktop home composition',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        _testShell(
          HomeScreen(
            onNavigate: (_) {},
            boardConnected: false,
            boardModel: ChessnutBoardModel.unknown,
            dailyClaimService: DailyClaimService(
              store: InMemoryDailyClaimStore(),
            ),
            apiClient: _walletClient(balance: 150),
            continueBotRecord: botRecord,
            onContinueRecord: (_) async {},
            onDismissContinueRecord: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openContinueGamesDialog(tester);

      final hero = tester.getRect(
        find.byKey(const ValueKey('home-board-hero')),
      );
      final play = tester.getRect(
        find.byKey(const ValueKey('home-action-play')),
      );
      final career = tester.getRect(
        find.byKey(const ValueKey('home-action-career')),
      );
      final analysis = tester.getRect(
        find.byKey(const ValueKey('home-action-analysis')),
      );
      final practice = tester.getRect(
        find.byKey(const ValueKey('home-action-training')),
      );
      final records = tester.getRect(
        find.byKey(const ValueKey('home-action-records')),
      );
      final engine = tester.getRect(
        find.byKey(const ValueKey('home-action-engine')),
      );

      expect(hero.right, lessThan(play.left));
      final continueCard = tester.getRect(
        find.text('Continue bot game'),
      );
      expect(continueCard.left, lessThan(play.left));
      expect(continueCard.top, greaterThan(hero.top));
      expect(find.text('Online / bot'), findsOneWidget);
      expect(play.top, career.top);
      expect(career.top, analysis.top);
      expect(practice.top, records.top);
      expect(records.top, engine.top);
      expect(practice.top, greaterThan(play.top));
      expect(play.left, lessThan(career.left));
      expect(career.left, lessThan(analysis.left));
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('home daily tasks and settings use one scrolling column on clock',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testShell(
        HomeScreen(
          onNavigate: (_) {},
          boardConnected: true,
          boardModel: ChessnutBoardModel.air,
          dailyClaimService: DailyClaimService(
            store: InMemoryDailyClaimStore(),
          ),
          apiClient: _walletClient(balance: 150),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-companion-actions')), findsNothing);
    expect(find.byKey(const ValueKey('home-continue-slot')), findsNothing);

    final dailyRect = tester.getRect(find.text('Daily tasks'));
    final accountRect = tester.getRect(find.text('Account settings').first);
    final appSettingsRect = tester.getRect(find.text('App settings').first);

    expect(accountRect.top, greaterThanOrEqualTo(dailyRect.bottom));
    expect((accountRect.center.dy - appSettingsRect.center.dy).abs(),
        lessThanOrEqualTo(1));
  });

  testWidgets('home clock landscape actions can scroll to bottom content',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testShell(
        HomeScreen(
          onNavigate: (_) {},
          boardConnected: true,
          boardModel: ChessnutBoardModel.air,
          dailyClaimService: DailyClaimService(
            store: InMemoryDailyClaimStore(),
          ),
          apiClient: _walletClient(balance: 150),
          continueBotRecord: botRecord,
          continueOnlineRecord: onlineRecord,
          onContinueRecord: (_) async {},
          onDismissContinueRecord: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('home-companion-actions-scroll')),
      findsOneWidget,
    );
    expect(
      tester.getRect(find.text('App settings').first).bottom,
      greaterThan(tester.view.physicalSize.height),
    );

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('home-companion-actions-scroll')),
    );
    expect(scrollView.controller!.position.maxScrollExtent, greaterThan(0));

    await tester.drag(
      find.byKey(const ValueKey('home-companion-actions-scroll')),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.text('App settings').first).bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height),
    );
  });
}

class _FakeAccessibilityVisionBridge implements AccessibilityVisionBridge {
  _FakeAccessibilityVisionBridge({required this.running});

  final bool running;
  int checks = 0;
  int openSettingsCalls = 0;

  @override
  Future<void> setRecognitionStatus({
    required bool enabled,
    required bool recognizing,
    required bool boardConnected,
    required String languageTag,
  }) async {}

  @override
  Future<bool> isAccessibilityRunning() async {
    checks += 1;
    return running;
  }

  @override
  Future<void> openAccessibilitySettings() async {
    openSettingsCalls += 1;
  }

  @override
  Future<String?> recognizeScreenshot() async => null;

  @override
  Future<bool> dispatchMoveGesture({
    required Rect from,
    Rect? to,
  }) async {
    return false;
  }
}
