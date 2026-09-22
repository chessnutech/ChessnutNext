import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chessnut_flutter_export/l10n/app_language.dart';
import 'package:chessnut_flutter_export/l10n/app_strings.dart';
import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/screens/career_screen.dart';
import 'package:chessnut_flutter_export/screens/game_room_screen.dart';
import 'package:chessnut_flutter_export/services/chess_clock_switch_service.dart';
import 'package:chessnut_flutter_export/services/chessnut_api_client.dart';
import 'package:chessnut_flutter_export/services/physical_board_gateway.dart';
import 'package:chessnut_flutter_export/theme/chessnut_theme.dart';

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

Widget _testShell(Widget child, {TextScaler? textScaler}) {
  return MaterialApp(
    theme: ChessnutTheme.light(),
    supportedLocales: AppLanguagePreference.supportedLocales,
    localizationsDelegates: AppStrings.localizationsDelegates,
    builder: textScaler == null
        ? null
        : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
    home: Scaffold(body: child),
  );
}

class _TestClockSwitchService extends ChessClockSwitchService {
  _TestClockSwitchService() : super(enableUsbButtons: false);
}

ChessnutApiClient _careerClient({
  required List<String> requests,
  int elo = 1425,
}) {
  return ChessnutApiClient(
    session: _session,
    httpClient: MockClient((request) async {
      requests.add(request.url.path);
      if (request.url.path == '/api/getElo') {
        return http.Response(
          jsonEncode({
            'ret': 1,
            'code': 200,
            'info': 'ok',
            'data': {'elo': elo},
          }),
          200,
        );
      }
      return http.Response('not found', 404);
    }),
  );
}

void main() {
  testWidgets('Career hides fallback Elo until the first response arrives',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final response = Completer<http.Response>();
    final apiClient = ChessnutApiClient(
      session: _session,
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/getElo') return response.future;
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(
      _testShell(
        CareerScreen(
          onNavigate: (_) {},
          apiClient: apiClient,
          onLaunchCareerGame: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(
        find.byKey(const ValueKey('career-initial-loading')), findsOneWidget);
    expect(find.text('Career ELO 1200'), findsNothing);

    response.complete(
      http.Response(
        jsonEncode({
          'ret': 1,
          'code': 200,
          'info': 'ok',
          'data': {'elo': 1425},
        }),
        200,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('career-initial-loading')), findsNothing);
    expect(find.text('Career ELO 1425'), findsOneWidget);
  });

  testWidgets('Career keeps cached content while entry refresh is pending',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var requestCount = 0;
    final refreshResponse = Completer<http.Response>();
    final apiClient = ChessnutApiClient(
      session: _session,
      httpClient: MockClient((request) async {
        if (request.url.path != '/api/getElo') {
          return http.Response('not found', 404);
        }
        requestCount += 1;
        if (requestCount == 1) {
          return http.Response(
            jsonEncode({
              'ret': 1,
              'code': 200,
              'info': 'ok',
              'data': {'elo': 1425},
            }),
            200,
          );
        }
        return refreshResponse.future;
      }),
    );
    await apiClient.getElo();

    await tester.pumpWidget(
      _testShell(
        CareerScreen(
          onNavigate: (_) {},
          apiClient: apiClient,
          onLaunchCareerGame: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(requestCount, 2);
    expect(find.byKey(const ValueKey('career-initial-loading')), findsNothing);
    expect(find.text('Career ELO 1425'), findsOneWidget);
    expect(find.text('Find career opponent'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const ValueKey('career-hero-progress')),
          )
          .value,
      isNotNull,
    );

    refreshResponse.complete(
      http.Response(
        jsonEncode({
          'ret': 1,
          'code': 200,
          'info': 'ok',
          'data': {'elo': 1475},
        }),
        200,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Career ELO 1475'), findsOneWidget);
  });

  testWidgets(
    'Career screen loads Elo and launches a playable career bot config',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final requests = <String>[];
      BotGameConfig? launchedConfig;

      await tester.pumpWidget(
        _testShell(
          CareerScreen(
            onNavigate: (_) {},
            apiClient: _careerClient(requests: requests),
            onLaunchCareerGame: (config) => launchedConfig = config,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(requests, contains('/api/getElo'));
      expect(find.text('Career ELO 1425'), findsOneWidget);
      expect(find.text('Find career opponent'), findsOneWidget);

      await tester.tap(find.text('Find career opponent'));
      await tester.pump();
      expect(find.text('Matching opponent'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1900));
      await tester.pumpAndSettle();
      expect(find.text('Opponent found'), findsOneWidget);

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      final config = launchedConfig;
      expect(config, isNotNull);
      expect(config!.careerMode, isNotNull);
      expect(config.careerMode!.startElo, 1425);
      expect(config.careerMode!.winElo, 1475);
      expect(config.careerMode!.loseElo, 1375);
      expect(config.engineKind, BotEngineKind.maia3);
      expect(config.maiaElo, 1425);
      expect(config.title, contains('ELO 1425'));
      expect(config.opening, standardOpeningScenario);
      expect(config.startFen, chessnutStandardStartFen);
    },
  );

  testWidgets(
    'Career rematch starts automatically with a different opponent',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final requests = <String>[];
      BotGameConfig? launchedConfig;
      const previousOpponent = 'Mila Chen';

      await tester.pumpWidget(
        _testShell(
          CareerScreen(
            onNavigate: (_) {},
            apiClient: _careerClient(requests: requests),
            onLaunchCareerGame: (config) => launchedConfig = config,
            rematchRequest: 1,
            excludedOpponentName: previousOpponent,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Opponent found'), findsOneWidget);

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      expect(launchedConfig, isNotNull);
      expect(
        launchedConfig!.careerMode!.opponentName,
        isNot(previousOpponent),
      );
    },
  );

  testWidgets('Career shows Stockfish opponents at 2600 Elo', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requests = <String>[];
    BotGameConfig? launchedConfig;
    await tester.pumpWidget(
      _testShell(
        CareerScreen(
          onNavigate: (_) {},
          apiClient: _careerClient(requests: requests, elo: 2600),
          onLaunchCareerGame: (config) => launchedConfig = config,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stockfish'), findsOneWidget);

    await tester.tap(find.text('Find career opponent'));
    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pumpAndSettle();
    expect(find.textContaining('Stockfish'), findsWidgets);

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(launchedConfig, isNotNull);
    expect(launchedConfig!.engineKind, BotEngineKind.stockfish);
    expect(launchedConfig!.stockfishElo, 2600);
  });

  testWidgets(
    'Career screen shows a journey map and training recommendations without lessons',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final requests = <String>[];
      final navigations = <String>[];
      await tester.pumpWidget(
        _testShell(
          CareerScreen(
            onNavigate: navigations.add,
            apiClient: _careerClient(requests: requests),
            onLaunchCareerGame: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Career Journey'), findsOneWidget);
      expect(find.text('Stage 6'), findsOneWidget);
      expect(find.text('Boss threshold'), findsNothing);
      expect(find.text('Upcoming Opponent'), findsOneWidget);
      expect(find.textContaining('/ ELO 1425'), findsOneWidget);
      expect(find.text('Training recommendations'), findsOneWidget);
      expect(find.text('Puzzle Practice'), findsOneWidget);
      expect(find.text('Review Last Loss'), findsOneWidget);
      expect(find.text('Mistake book'), findsOneWidget);
      expect(find.text('If stuck'), findsOneWidget);
      expect(find.text('+8'), findsNothing);
      expect(find.text('+12'), findsNothing);
      expect(find.text('+10'), findsNothing);
      expect(find.text('Train for Boss'), findsNothing);
      expect(find.text('Build your career'), findsNothing);
      expect(
          find.byKey(const ValueKey('career-component-route')), findsOneWidget);
      expect(find.byKey(const ValueKey('career-route-progress-track')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('career-route-step-battle')), findsNothing);
      expect(
          find.byKey(const ValueKey('career-route-step-puzzle')), findsNothing);
      expect(
          find.byKey(const ValueKey('career-route-step-review')), findsNothing);
      expect(
          find.byKey(const ValueKey('career-route-step-boss')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('career-journey-board-art')), findsNothing);
      expect(find.byKey(const ValueKey('career-training-card-PuzzleThemes')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('career-training-card-Records')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('career-training-card-MistakeBook')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('career-boss-ready-footer')), findsNothing);
      expect(find.text('Lessons'), findsNothing);
      expect(find.text('Board course'), findsNothing);

      final puzzlePractice = find.byKey(
        const ValueKey('career-training-card-PuzzleThemes'),
      );
      await tester.ensureVisible(puzzlePractice);
      await tester.pumpAndSettle();
      await tester.tap(puzzlePractice);
      expect(navigations, contains('PuzzleThemes'));

      final mistakeBook = find.byKey(
        const ValueKey('career-training-card-MistakeBook'),
      );
      await tester.ensureVisible(mistakeBook);
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(of: mistakeBook, matching: find.byType(InkWell)).first,
      );
      expect(navigations, contains('MistakeBook'));
    },
  );

  testWidgets('Career screen balances content on chess clock landscape',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requests = <String>[];
    await tester.pumpWidget(
      _testShell(
        CareerScreen(
          onNavigate: (_) {},
          apiClient: _careerClient(requests: requests),
          onLaunchCareerGame: (_) {},
          isChessnutClockDevice: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final midpoint = tester.view.physicalSize.width / 2;
    final screenBottom = tester.view.physicalSize.height;
    final upcomingOpponent = tester.getRect(find.text('Upcoming Opponent'));
    final heroCard =
        tester.getRect(find.byKey(const ValueKey('career-hero-card')));
    final findOpponentButton = tester.getRect(
      find.byKey(const ValueKey('career-find-opponent-button')),
    );
    final findOpponentLabel = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('career-find-opponent-button')),
        matching: find.text('Find career opponent'),
      ),
    );
    final route = tester.getRect(
      find.byKey(const ValueKey('career-component-route')),
    );
    final journeyDetail = tester.getRect(
      find.text(
        'Gain 75 more ELO through battles and training to unlock the boss.',
      ),
    );
    final journeyFocus = tester.getRect(
      find.text(
        'Win career games for +50 ELO. Use training below if this stage gets stuck.',
      ),
    );
    final lastTrainingCard = tester.getRect(
      find.byKey(const ValueKey('career-training-card-MistakeBook')),
    );

    expect(upcomingOpponent.center.dx, lessThan(midpoint));
    expect(find.text('Find career opponent'), findsOneWidget);
    expect(findOpponentButton.left, greaterThan(heroCard.left));
    expect(findOpponentButton.right, lessThan(heroCard.right));
    expect(findOpponentButton.center.dx, greaterThan(heroCard.center.dx));
    expect(findOpponentButton.center.dx, lessThan(midpoint));
    expect(findOpponentButton.width, greaterThanOrEqualTo(224));
    expect(findOpponentLabel.left, greaterThan(findOpponentButton.left));
    expect(findOpponentLabel.right, lessThan(findOpponentButton.right));
    expect(findOpponentButton.top, greaterThanOrEqualTo(0));
    expect(findOpponentButton.bottom, lessThanOrEqualTo(screenBottom));
    expect(route.center.dx, greaterThan(midpoint));
    expect(journeyDetail.right, lessThanOrEqualTo(route.right));
    expect(journeyDetail.bottom, lessThanOrEqualTo(screenBottom));
    expect(journeyFocus.right, lessThanOrEqualTo(route.right));
    expect(journeyFocus.bottom, lessThanOrEqualTo(screenBottom));
    expect(route.height, lessThan(260));
    expect(lastTrainingCard.center.dx, greaterThan(midpoint));
    expect(lastTrainingCard.bottom, lessThanOrEqualTo(screenBottom));

    expect(
        find.byKey(const ValueKey('career-find-opponent-button')).hitTestable(),
        findsOneWidget);
  });

  testWidgets('Career keeps complete maximum text with limited clock scrolling',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requests = <String>[];
    await tester.pumpWidget(
      _testShell(
        CareerScreen(
          onNavigate: (_) {},
          apiClient: _careerClient(requests: requests),
          onLaunchCareerGame: (_) {},
          isChessnutClockDevice: true,
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final cards = [
      find.byKey(const ValueKey('career-training-card-PuzzleThemes')),
      find.byKey(const ValueKey('career-training-card-Records')),
      find.byKey(const ValueKey('career-training-card-MistakeBook')),
    ];
    final titles = [
      find.text('Puzzle Practice'),
      find.text('Review Last Loss'),
      find.text('Mistake book'),
    ];
    final details = [
      find.text('Train tactics linked to recent mistakes'),
      find.text('Review the game that blocked this node'),
      find.text('From your games'),
    ];

    expect(
      MediaQuery.textScalerOf(tester.element(titles.first)).scale(1),
      2,
    );
    expect(find.text('ELO JOURNEY'), findsOneWidget);
    expect(
      find.text(
        'Gain 75 more ELO through battles and training to unlock the boss.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Win career games for +50 ELO. Use training below if this stage gets stuck.',
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(cards.last);
    await tester.pumpAndSettle();

    for (var i = 0; i < cards.length; i += 1) {
      final cardRect = tester.getRect(cards[i]);
      final titleRect = tester.getRect(titles[i]);
      final detailRect = tester.getRect(details[i]);

      expect(titleRect.left, greaterThanOrEqualTo(cardRect.left));
      expect(titleRect.right, lessThanOrEqualTo(cardRect.right));
      expect(detailRect.left, greaterThanOrEqualTo(cardRect.left));
      expect(detailRect.right, lessThanOrEqualTo(cardRect.right));
      expect(detailRect.bottom, lessThanOrEqualTo(cardRect.bottom));
      expect(find.ancestor(of: titles[i], matching: find.byType(FittedBox)),
          findsNothing);
      expect(find.ancestor(of: details[i], matching: find.byType(FittedBox)),
          findsNothing);
    }

    final journey = tester.getRect(
      find.byKey(const ValueKey('career-component-route')),
    );
    final hero = tester.getRect(
      find.byKey(const ValueKey('career-hero-card')),
    );
    final upcomingOpponent = tester.getRect(find.text('Upcoming Opponent'));
    final trainingTop = tester.getRect(cards.first).top;
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );

    expect(journey.bottom, lessThan(trainingTop));
    expect(hero.bottom, lessThan(trainingTop));
    expect(upcomingOpponent.bottom, lessThan(trainingTop));
    expect(scrollable.position.maxScrollExtent, lessThan(300));
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(960, 540), const Size(1920, 1080)]) {
    testWidgets('Windows Career keeps the landscape dashboard at $size',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      try {
        final requests = <String>[];
        await tester.pumpWidget(
          _testShell(
            CareerScreen(
              onNavigate: (_) {},
              apiClient: _careerClient(requests: requests),
              onLaunchCareerGame: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final layout = tester.getRect(
          find.byKey(const ValueKey('career-windows-landscape')),
        );
        final hero = tester.getRect(
          find.byKey(const ValueKey('career-hero-card')),
        );
        final opponent = tester.getRect(find.text('Upcoming Opponent'));
        final journey = tester.getRect(
          find.byKey(const ValueKey('career-component-route')),
        );
        final puzzle = tester.getRect(
          find.byKey(const ValueKey('career-training-card-PuzzleThemes')),
        );
        final records = tester.getRect(
          find.byKey(const ValueKey('career-training-card-Records')),
        );
        final mistakes = tester.getRect(
          find.byKey(const ValueKey('career-training-card-MistakeBook')),
        );
        final puzzleTitle = tester.getRect(find.text('Puzzle Practice'));
        final puzzleDetail = tester.getRect(
          find.text('Train tactics linked to recent mistakes'),
        );
        final recordsTitle = tester.getRect(find.text('Review Last Loss'));
        final recordsDetail = tester.getRect(
          find.text('Review the game that blocked this node'),
        );
        final mistakesTitle = tester.getRect(find.text('Mistake book'));
        final mistakesDetail = tester.getRect(find.text('From your games'));

        expect(hero.right, lessThan(journey.left));
        expect(opponent.center.dx, lessThan(journey.left));
        expect(opponent.top, greaterThan(hero.top));
        expect(puzzle.top, greaterThan(hero.bottom));
        expect(records.center.dy, moreOrLessEquals(puzzle.center.dy));
        expect(mistakes.center.dy, moreOrLessEquals(puzzle.center.dy));
        expect(puzzle.height, greaterThanOrEqualTo(70));
        expect(
          (puzzleTitle.top + puzzleDetail.bottom) / 2,
          moreOrLessEquals(puzzle.center.dy, epsilon: 2),
        );
        expect(
          (recordsTitle.top + recordsDetail.bottom) / 2,
          moreOrLessEquals(records.center.dy, epsilon: 2),
        );
        expect(
          (mistakesTitle.top + mistakesDetail.bottom) / 2,
          moreOrLessEquals(mistakes.center.dy, epsilon: 2),
        );
        expect(journey.height, lessThan(layout.height * 0.82));
        expect(layout.bottom, lessThanOrEqualTo(size.height));
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('Android phone Career uses the compact landscape dashboard', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(right: 48);
    tester.view.viewPadding = const FakeViewPadding(right: 48);
    try {
      final requests = <String>[];
      await tester.pumpWidget(
        _testShell(
          SafeArea(
            top: false,
            bottom: false,
            child: CareerScreen(
              onNavigate: (_) {},
              apiClient: _careerClient(requests: requests),
              onLaunchCareerGame: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final layout = find.byKey(
        const ValueKey('career-android-phone-landscape'),
      );
      expect(layout, findsOneWidget);
      expect(find.text('Career'), findsOneWidget);
      expect(find.text('Career Journey'), findsOneWidget);
      expect(find.text('Upcoming Opponent'), findsOneWidget);
      expect(find.text('Find career opponent'), findsOneWidget);
      expect(find.text('Career ELO 1425'), findsOneWidget);

      final hero = tester.getRect(
        find.byKey(const ValueKey('career-hero-card')),
      );
      final heroProgress = tester.getRect(
        find.byKey(const ValueKey('career-hero-progress')),
      );
      final startButton = tester.getRect(
        find.byKey(const ValueKey('career-find-opponent-button')),
      );
      final opponent = tester.getRect(find.text('Upcoming Opponent'));
      final journey = tester.getRect(
        find.byKey(const ValueKey('career-component-route')),
      );
      final puzzle = tester.getRect(
        find.byKey(const ValueKey('career-training-card-PuzzleThemes')),
      );
      final records = tester.getRect(
        find.byKey(const ValueKey('career-training-card-Records')),
      );
      final mistakes = tester.getRect(
        find.byKey(const ValueKey('career-training-card-MistakeBook')),
      );

      expect(hero.center.dx, lessThan(journey.center.dx));
      expect(hero.height, greaterThanOrEqualTo(54));
      expect(heroProgress.top, greaterThanOrEqualTo(hero.top));
      expect(heroProgress.bottom, lessThanOrEqualTo(hero.bottom));
      expect(startButton.top, greaterThanOrEqualTo(hero.top));
      expect(startButton.bottom, lessThanOrEqualTo(hero.bottom));
      expect(opponent.center.dx, lessThan(journey.center.dx));
      expect(puzzle.center.dy, greaterThan(hero.center.dy));
      expect(records.center.dy, moreOrLessEquals(puzzle.center.dy));
      expect(mistakes.center.dy, moreOrLessEquals(puzzle.center.dy));
      expect(tester.getRect(layout).bottom, lessThanOrEqualTo(390));
      expect(
        find.byKey(const ValueKey('career-find-opponent-button')).hitTestable(),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    }
  });

  testWidgets('Android phone landscape keeps Rookie I and journey complete', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(780, 360);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(right: 48);
    tester.view.viewPadding = const FakeViewPadding(right: 48);
    try {
      final requests = <String>[];
      await tester.pumpWidget(
        _testShell(
          SafeArea(
            top: false,
            bottom: false,
            child: CareerScreen(
              onNavigate: (_) {},
              apiClient: _careerClient(requests: requests, elo: 900),
              onLaunchCareerGame: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rookie I'), findsOneWidget);
      expect(find.text('Career Journey'), findsOneWidget);
      expect(find.text('Career ELO 900'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('career-android-phone-landscape-scroll')),
        findsOneWidget,
      );

      final rookie = tester.renderObject<RenderParagraph>(
        find.text('Rookie I'),
      );
      final journey = tester.renderObject<RenderParagraph>(
        find.text('Career Journey'),
      );
      final careerElo = tester.renderObject<RenderParagraph>(
        find.text('Career ELO 900'),
      );
      expect(rookie.didExceedMaxLines, isFalse);
      expect(journey.didExceedMaxLines, isFalse);
      expect(careerElo.didExceedMaxLines, isFalse);
      expect(find.text('Rookie I').hitTestable(), findsOneWidget);
      expect(find.text('Career ELO 900').hitTestable(), findsOneWidget);
      expect(find.text('Career Journey').hitTestable(), findsOneWidget);
      expect(
        find
            .byKey(const ValueKey('career-training-card-MistakeBook'))
            .hitTestable(),
        findsOneWidget,
      );

      final scrollable = find.descendant(
        of: find.byKey(
          const ValueKey('career-android-phone-landscape-scroll'),
        ),
        matching: find.byType(Scrollable),
      );
      expect(scrollable, findsOneWidget);
      expect(
        tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
        0,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    }
  });

  testWidgets('Android clock Career keeps the existing landscape layout', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    try {
      final requests = <String>[];
      await tester.pumpWidget(
        _testShell(
          CareerScreen(
            onNavigate: (_) {},
            apiClient: _careerClient(requests: requests),
            onLaunchCareerGame: (_) {},
            isChessnutClockDevice: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('career-android-phone-landscape')),
        findsNothing,
      );
      expect(find.text('Career'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets('Career screen uses the next stage as the boss rating',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requests = <String>[];
    await tester.pumpWidget(
      _testShell(
        CareerScreen(
          onNavigate: (_) {},
          apiClient: _careerClient(requests: requests, elo: 600),
          onLaunchCareerGame: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Boss threshold'), findsNothing);
    expect(find.text('Stage 1'), findsOneWidget);
    expect(find.text('825'), findsOneWidget);
    expect(find.text('200 ELO to unlock the boss challenge.'), findsNothing);
    expect(find.text('Train for Boss'), findsNothing);
    expect(find.text('Challenge Boss'), findsNothing);
    expect(find.text('Upcoming Opponent'), findsOneWidget);
  });

  testWidgets(
    'Career screen animates rating changes after refresh',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var elo = 1425;
      final apiClient = ChessnutApiClient(
        session: _session,
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/getElo') {
            return http.Response(
              jsonEncode({
                'ret': 1,
                'code': 200,
                'info': 'ok',
                'data': {'elo': elo},
              }),
              200,
            );
          }
          return http.Response('not found', 404);
        }),
      );

      await tester.pumpWidget(
        _testShell(
          CareerScreen(
            onNavigate: (_) {},
            apiClient: apiClient,
            onLaunchCareerGame: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Career ELO 1425'), findsOneWidget);
      expect(find.byKey(const ValueKey('career-rating-delta-feedback')),
          findsNothing);

      elo = 1475;
      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byKey(const ValueKey('career-rating-delta-feedback')),
          findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('career-rating-delta-feedback')),
          matching: find.text('+50 ELO'),
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      expect(find.text('Career ELO 1475'), findsOneWidget);
    },
  );

  testWidgets(
    'Career bot game asks the backend to settle account Elo when the game ends',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final gateway = MemoryPhysicalBoardGateway();
      addTearDown(gateway.dispose);
      final requests = <http.Request>[];
      final apiClient = ChessnutApiClient(
        session: _session,
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({'ret': 1, 'code': 200, 'info': 'ok', 'data': {}}),
            200,
          );
        }),
      );
      const career = CareerModeConfig(
        startElo: 960,
        winElo: 1035,
        loseElo: 885,
        opponentName: 'Mila Chen',
        opponentAvatarAsset: 'assets/avatars/avatar-03.png',
      );

      await tester.pumpWidget(
        _testShell(
          GameRoomScreen(
            onNavigate: (_) {},
            mode: GameLaunchMode.bot,
            apiClient: apiClient,
            boardGateway: gateway,
            clockSwitchService: _TestClockSwitchService(),
            botConfig: const BotGameConfig.defaultConfig().copyWith(
              playerSide: BotPlayerSide.black,
              careerMode: career,
              startFen:
                  'rnbqkbnr/pppp1ppp/8/4p3/6P1/5P2/PPPPP2P/RNBQKBNR b KQkq - 0 2',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      gateway.addBoardFen(
        'rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR',
      );
      gateway.addBoardFen(
        'rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR',
      );
      await tester.pump(const Duration(milliseconds: 850));
      await tester.pumpAndSettle();

      expect(find.text('Black wins by checkmate'), findsWidgets);
      expect(find.text('+75 ELO'), findsOneWidget);
      final updateRequest = requests.singleWhere(
        (request) => request.url.path == '/api/updateElo',
      );
      expect(updateRequest.bodyFields['career_result'], 'victory');
      expect(updateRequest.bodyFields.containsKey('elo'), isFalse);
    },
  );
}
