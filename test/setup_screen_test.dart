import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chessnut_flutter_export/screens/setup_screen.dart';
import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/services/physical_board_gateway.dart';
import 'package:chessnut_flutter_export/services/app_shared_preferences.dart';
import 'package:chessnut_flutter_export/theme/chessnut_theme.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppSharedPreferences.useInstanceForTesting(
      await SharedPreferences.getInstance(),
    );
  });

  testWidgets('Android Move setup resets the physical board', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _SetupBoardGateway(PhysicalBoardModel.move);

    await tester.pumpWidget(
      MaterialApp(
        theme: ChessnutTheme.light(),
        home: Scaffold(
          body: SetupScreen(
            onNavigate: (_) {},
            onLaunchGame: (mode, {botConfig, otbConfig, lichessConfig}) {},
            boardGateway: gateway,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('Ready'), findsNothing);
    expect(find.byIcon(Icons.restart_alt_rounded), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('setup-move-board-reset-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Are you sure?'), findsOneWidget);
    expect(
      find.text(
        "This action will initiate the pieces' movement and cannot be interrupted once started.",
      ),
      findsOneWidget,
    );
    expect(gateway.clearedMoveLeds, isFalse);
    expect(gateway.lastMoveBoardFen, isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(gateway.lastMoveBoardFen, isNull);

    await tester.tap(
      find.byKey(const ValueKey('setup-move-board-reset-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(gateway.clearedMoveLeds, isTrue);
    expect(gateway.lastMoveBoardFen, chessnutStandardStartFen);
    expect(
      find.text('Move board reset to the standard starting position.'),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Move setup reset preserves direction on every native platform', (
    tester,
  ) async {
    for (final platform in const [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.windows,
      TargetPlatform.macOS,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      final gateway = _SetupBoardGateway(PhysicalBoardModel.move)
        ..latestFen = 'RNBKQBNR/PPP1PPPP/8/3P4/8/8/pppppppp/rnbkqbnr';
      await tester.pumpWidget(
        MaterialApp(
          theme: ChessnutTheme.light(),
          home: Scaffold(
            body: SetupScreen(
              onNavigate: (_) {},
              onLaunchGame: (mode, {botConfig, otbConfig, lichessConfig}) {},
              boardGateway: gateway,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('setup-move-board-reset-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(gateway.lastMoveBoardFen, chessnutStandardStartFen);
      expect(gateway.lastMoveBoardFenReversed, isTrue, reason: '$platform');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android non-Move setup does not show Reset', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(
      MaterialApp(
        theme: ChessnutTheme.light(),
        home: Scaffold(
          body: SetupScreen(
            onNavigate: (_) {},
            onLaunchGame: (mode, {botConfig, otbConfig, lichessConfig}) {},
            boardGateway: _SetupBoardGateway(PhysicalBoardModel.air),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Reset'), findsNothing);
    expect(
      find.byKey(const ValueKey('setup-move-board-reset-button')),
      findsNothing,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Move reset is available on every native app platform', (
    tester,
  ) async {
    for (final platform in const [
      TargetPlatform.iOS,
      TargetPlatform.windows,
      TargetPlatform.macOS,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      await tester.pumpWidget(
        MaterialApp(
          theme: ChessnutTheme.light(),
          home: Scaffold(
            body: SetupScreen(
              onNavigate: (_) {},
              onLaunchGame: (mode, {botConfig, otbConfig, lichessConfig}) {},
              boardGateway: _SetupBoardGateway(PhysicalBoardModel.move),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ready'), findsNothing);
      expect(
        find.byKey(const ValueKey('setup-move-board-reset-button')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android clock device shows Move reset', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(
      MaterialApp(
        theme: ChessnutTheme.light(),
        home: Scaffold(
          body: SetupScreen(
            onNavigate: (_) {},
            onLaunchGame: (mode, {botConfig, otbConfig, lichessConfig}) {},
            boardGateway: _SetupBoardGateway(PhysicalBoardModel.move),
            isChessnutClockDevice: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ready'), findsNothing);
    expect(
      find.byKey(const ValueKey('setup-move-board-reset-button')),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('online path title is complete and has no trailing arrow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ChessnutTheme.light(),
        home: Scaffold(
          body: SetupScreen(
            onNavigate: (_) {},
            onLaunchGame: (mode, {botConfig, otbConfig, lichessConfig}) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final title = find.text('Find an online match');
    expect(title, findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
      isFalse,
    );
    expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
  });

  testWidgets('Windows wide layout matches the iOS landscape path structure', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: ChessnutTheme.light(),
          home: Scaffold(
            body: SetupScreen(
              onNavigate: (_) {},
              onLaunchGame: (
                mode, {
                botConfig,
                otbConfig,
                lichessConfig,
              }) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('setup-windows-landscape-layout')),
        findsOneWidget,
      );
      final layout = tester.getRect(
        find.byKey(const ValueKey('setup-windows-landscape-layout')),
      );
      final online = tester.getRect(find.byKey(const ValueKey('path-online')));
      final bot = tester.getRect(find.byKey(const ValueKey('path-bot')));
      final otb = tester.getRect(find.byKey(const ValueKey('path-otb')));
      final editor = tester.getRect(find.byKey(const ValueKey('path-editor')));

      expect(online.left, lessThan(bot.left));
      expect(bot.top, otb.top);
      expect(bot.bottom, otb.bottom);
      expect(editor.top, greaterThan(bot.bottom));
      expect(editor.left, bot.left);
      expect(editor.right, otb.right);
      expect(online.top, bot.top);
      expect(online.bottom, editor.bottom);
      expect(layout.height, lessThanOrEqualTo(540));
      expect(layout.height, greaterThanOrEqualTo(450));
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Windows narrow layout keeps the regular responsive flow', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: ChessnutTheme.light(),
          home: Scaffold(
            body: SetupScreen(
              onNavigate: (_) {},
              onLaunchGame: (
                mode, {
                botConfig,
                otbConfig,
                lichessConfig,
              }) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('setup-windows-landscape-layout')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Windows wide bot setup reuses the landscape pane layout', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: ChessnutTheme.light(),
          home: Scaffold(
            body: BotSetupScreen(
              onNavigate: (_) {},
              onLaunchGame: (
                mode, {
                botConfig,
                otbConfig,
                lichessConfig,
              }) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('bot-setup-landscape-layout')),
        findsOneWidget,
      );
      final engine = tester.getRect(
        find.byKey(const ValueKey('bot-setup-engine-panel')),
      );
      final starting = tester.getRect(
        find.byKey(const ValueKey('bot-setup-starting-panel')),
      );
      final playSettings = tester.getRect(
        find.byKey(const ValueKey('bot-setup-play-settings-panel')),
      );
      final time = tester.getRect(
        find.byKey(const ValueKey('bot-setup-time-control-panel')),
      );

      expect(engine.left, lessThan(starting.left));
      expect(starting.left, lessThan(time.left));
      expect(engine.top, starting.top);
      expect(starting.top, time.top);
      expect((engine.bottom - playSettings.bottom).abs(), lessThan(40));
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

class _SetupBoardGateway extends PhysicalBoardGateway {
  _SetupBoardGateway(this.model);

  final PhysicalBoardModel model;
  String? lastMoveBoardFen;
  String? latestFen;
  bool? lastMoveBoardFenReversed;
  bool clearedMoveLeds = false;

  @override
  PhysicalBoardModel get boardModel => model;

  @override
  PhysicalBoardConnectionState get currentState =>
      PhysicalBoardConnectionState.connected;

  @override
  String? get latestBoardFen => latestFen;

  @override
  Stream<PhysicalBoardConnectionState> get stateStream => const Stream.empty();

  @override
  Stream<String> get boardFenStream => const Stream.empty();

  @override
  Future<bool> connect() async => true;

  @override
  Future<void> disconnect() async {}

  @override
  Future<bool> write(List<int> command, {bool withoutResponse = false}) async =>
      true;

  @override
  Future<bool> clearMoveLeds() async {
    clearedMoveLeds = true;
    return true;
  }

  @override
  Future<bool> setMoveBoardFen(
    String fen, {
    bool strictMode = false,
    bool isReverse = false,
  }) async {
    lastMoveBoardFen = fen;
    lastMoveBoardFenReversed = isReverse;
    return true;
  }
}
