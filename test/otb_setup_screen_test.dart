import 'package:dartchess/dartchess.dart' as dc;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/screens/otb_setup_screen.dart';
import 'package:chessnut_flutter_export/services/app_shared_preferences.dart';
import 'package:chessnut_flutter_export/theme/chessnut_theme.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppSharedPreferences.useInstanceForTesting(
      await SharedPreferences.getInstance(),
    );
  });

  testWidgets('Android phone landscape scrolls the OTB header with the page', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(_harness(onLaunch: (_) {}));
      await tester.pumpAndSettle();

      final header = find.text('OTB setup');
      final before = tester.getTopLeft(header).dy;
      await tester.drag(
        find.byKey(const ValueKey('otb-setup-scroll')),
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(header).dy, lessThan(before));
      expect(find.byKey(const ValueKey('otb-clock-mode-card')), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Chessnut Clock keeps the OTB header fixed in landscape', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        _harness(onLaunch: (_) {}, isChessnutClockDevice: true),
      );
      await tester.pumpAndSettle();

      final header = find.text('OTB setup');
      final before = tester.getTopLeft(header).dy;
      await tester.drag(
        find.byKey(const ValueKey('otb-setup-scroll')),
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(header).dy, before);
      expect(find.byKey(const ValueKey('otb-clock-mode-card')), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Native OTB setup restores the previous user choices', (
    tester,
  ) async {
    AppSharedPreferences.set(AppSettingKeys.otbTimeMinutes, 30);
    AppSharedPreferences.set(AppSettingKeys.otbIncrementSeconds, 20);
    AppSharedPreferences.set(AppSettingKeys.otbCustomTimeSelected, false);
    AppSharedPreferences.set(AppSettingKeys.otbStartingPosition, 'opening');
    AppSharedPreferences.set(AppSettingKeys.otbOpeningId, 'ruy-lopez');
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      for (final platform in const [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.windows,
        TargetPlatform.macOS,
      ]) {
        OtbGameConfig? launchedConfig;
        debugDefaultTargetPlatformOverride = platform;
        await tester.pumpWidget(
          _harness(
            key: ValueKey(platform),
            onLaunch: (config) => launchedConfig = config,
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const ValueKey('otb-record-mode-card')),
        );
        await tester.tap(find.byKey(const ValueKey('otb-record-mode-card')));

        expect(launchedConfig, isNotNull);
        expect(launchedConfig!.timeMinutes, 30);
        expect(launchedConfig!.incrementSeconds, 20);
        expect(launchedConfig!.opening.id, 'ruy-lopez');
        expect(launchedConfig!.chess960, isFalse);
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Native OTB setup saves time and starting position choices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      for (final platform in const [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.windows,
        TargetPlatform.macOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        await tester.pumpWidget(
          _harness(key: ValueKey(platform), onLaunch: (_) {}),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('30+20'));
        await tester.tap(find.text('30+20'));
        await tester.ensureVisible(
          find.byKey(const ValueKey('otb-starting-chess960')),
        );
        await tester.tap(
          find.byKey(const ValueKey('otb-starting-chess960')),
        );
        await tester.pumpAndSettle();

        expect(
            AppSharedPreferences.get<int>(AppSettingKeys.otbTimeMinutes), 30);
        expect(
          AppSharedPreferences.get<int>(AppSettingKeys.otbIncrementSeconds),
          20,
        );
        expect(
          AppSharedPreferences.get<String>(
            AppSettingKeys.otbStartingPosition,
          ),
          'chess960',
        );
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Chessnut Clock restores the previous OTB setup choices', (
    tester,
  ) async {
    OtbGameConfig? launchedConfig;
    AppSharedPreferences.set(AppSettingKeys.otbShowPgnList, false);
    AppSharedPreferences.set(AppSettingKeys.otbTimeMinutes, 30);
    AppSharedPreferences.set(AppSettingKeys.otbIncrementSeconds, 20);
    AppSharedPreferences.set(AppSettingKeys.otbCustomTimeSelected, false);
    AppSharedPreferences.set(AppSettingKeys.otbStartingPosition, 'opening');
    AppSharedPreferences.set(AppSettingKeys.otbOpeningId, 'ruy-lopez');

    await tester.pumpWidget(
      _harness(
        onLaunch: (config) => launchedConfig = config,
        isChessnutClockDevice: true,
      ),
    );
    await tester.pumpAndSettle();

    final toggle = find.byKey(const ValueKey('otb-show-pgn-list-toggle'));
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(find.text('Ruy Lopez'), findsOneWidget);

    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(
      AppSharedPreferences.get<bool>(AppSettingKeys.otbShowPgnList),
      isTrue,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('otb-record-mode-card')),
    );
    await tester.tap(find.byKey(const ValueKey('otb-record-mode-card')));

    expect(launchedConfig, isNotNull);
    expect(launchedConfig!.timeMinutes, 30);
    expect(launchedConfig!.incrementSeconds, 20);
    expect(launchedConfig!.opening.id, 'ruy-lopez');
  });

  testWidgets('Chessnut Clock saves changed OTB time and starting position', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(onLaunch: (_) {}, isChessnutClockDevice: true),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('30+20'));
    await tester.tap(find.text('30+20'));
    await tester.ensureVisible(
      find.byKey(const ValueKey('otb-starting-chess960')),
    );
    await tester.tap(find.byKey(const ValueKey('otb-starting-chess960')));
    await tester.pumpAndSettle();

    expect(AppSharedPreferences.get<int>(AppSettingKeys.otbTimeMinutes), 30);
    expect(
      AppSharedPreferences.get<int>(AppSettingKeys.otbIncrementSeconds),
      20,
    );
    expect(
      AppSharedPreferences.get<String>(AppSettingKeys.otbStartingPosition),
      'chess960',
    );
  });

  testWidgets('OTB setup launches a standard starting position by default', (
    tester,
  ) async {
    OtbGameConfig? launchedConfig;
    await tester.pumpWidget(
      _harness(onLaunch: (config) => launchedConfig = config),
    );
    await tester.pumpAndSettle();

    expect(find.text('Starting position'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Opening'), findsOneWidget);
    expect(find.text('Chess960'), findsOneWidget);
    expect(find.text('Board editor'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('otb-record-mode-card')),
    );
    await tester.tap(find.byKey(const ValueKey('otb-record-mode-card')));

    expect(launchedConfig, isNotNull);
    expect(launchedConfig!.opening, standardOpeningScenario);
    expect(launchedConfig!.startFen, chessnutStandardStartFen);
    expect(launchedConfig!.chess960, isFalse);
  });

  testWidgets('Windows record game card does not span the full setup width', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(_harness(onLaunch: (_) {}));
      await tester.pumpAndSettle();

      final card = tester.getRect(
        find.byKey(const ValueKey('otb-record-mode-card')),
      );
      expect(card.width, lessThan(800));
      expect(card.width, greaterThan(500));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Standalone wide OTB layouts constrain the record card', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(_harness(onLaunch: (_) {}));
      await tester.pumpAndSettle();

      final card = tester.getRect(
        find.byKey(const ValueKey('otb-record-mode-card')),
      );
      expect(card.width, lessThan(800));
      expect(card.width, greaterThan(500));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('OTB setup launches the selected opening position', (
    tester,
  ) async {
    OtbGameConfig? launchedConfig;
    await tester.pumpWidget(
      _harness(onLaunch: (config) => launchedConfig = config),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('otb-starting-opening')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('otb-choose-opening')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('otb-opening-ruy-lopez')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('otb-record-mode-card')),
    );
    await tester.tap(find.byKey(const ValueKey('otb-record-mode-card')));

    final ruyLopez = botOpeningScenarios.firstWhere(
      (opening) => opening.id == 'ruy-lopez',
    );
    expect(launchedConfig, isNotNull);
    expect(launchedConfig!.opening.id, ruyLopez.id);
    expect(launchedConfig!.startFen, ruyLopez.fen);
    expect(launchedConfig!.chess960, isFalse);
  });

  testWidgets('OTB opening picker searches detailed opening variations', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(onLaunch: (_) {}));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('otb-starting-opening')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('otb-choose-opening')));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('otb-opening-search-field')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('otb-opening-search-field')),
      'Najdorf',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Najdorf'), findsWidgets);
  });

  testWidgets('Opening library is available on mobile and macOS app targets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final platform in <TargetPlatform>[
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      await tester.pumpWidget(_harness(onLaunch: (_) {}));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('otb-starting-opening')),
      );
      await tester.tap(find.byKey(const ValueKey('otb-starting-opening')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('otb-choose-opening')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('otb-opening-search-field')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('otb-opening-search-field')),
        'Najdorf',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Najdorf'), findsWidgets);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('OTB setup creates a legal Chess960 starting position', (
    tester,
  ) async {
    OtbGameConfig? launchedConfig;
    await tester.pumpWidget(
      _harness(onLaunch: (config) => launchedConfig = config),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('otb-starting-chess960')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('otb-record-mode-card')),
    );
    await tester.tap(find.byKey(const ValueKey('otb-record-mode-card')));

    expect(launchedConfig, isNotNull);
    expect(launchedConfig!.chess960, isTrue);
    expect(launchedConfig!.opening.id, startsWith('chess960-'));
    expect(
      () => dc.Chess.fromSetup(dc.Setup.parseFen(launchedConfig!.startFen)),
      returnsNormally,
    );
    final backRank = launchedConfig!.startFen.split('/').last.split(' ').first;
    final bishops = <int>[
      for (var index = 0; index < backRank.length; index += 1)
        if (backRank[index] == 'B') index,
    ];
    final rooks = <int>[
      for (var index = 0; index < backRank.length; index += 1)
        if (backRank[index] == 'R') index,
    ];
    expect(bishops.length, 2);
    expect(bishops[0].isEven, isNot(bishops[1].isEven));
    expect(rooks.length, 2);
    expect(backRank.indexOf('K'), greaterThan(rooks.first));
    expect(backRank.indexOf('K'), lessThan(rooks.last));
  });

  testWidgets('OTB setup launches a position selected in Board editor', (
    tester,
  ) async {
    OtbGameConfig? launchedConfig;
    await tester.pumpWidget(
      _harness(onLaunch: (config) => launchedConfig = config),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('otb-starting-board-editor')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Use this position'), findsOneWidget);
    await tester.tap(find.text('Use this position'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('otb-record-mode-card')),
    );
    await tester.tap(find.byKey(const ValueKey('otb-record-mode-card')));

    expect(launchedConfig, isNotNull);
    expect(launchedConfig!.opening.id, 'board-editor-fen');
    expect(launchedConfig!.opening.eco, 'FEN');
    expect(launchedConfig!.startFen, chessnutStandardStartFen);
    expect(launchedConfig!.chess960, isFalse);
  });
}

Widget _harness({
  required ValueChanged<OtbGameConfig> onLaunch,
  bool isChessnutClockDevice = false,
  Key? key,
}) {
  return MaterialApp(
    key: key,
    theme: ChessnutTheme.light(),
    home: Scaffold(
      body: OtbSetupScreen(
        onNavigate: (_) {},
        isChessnutClockDevice: isChessnutClockDevice,
        onLaunchGame: (mode, {botConfig, otbConfig, lichessConfig}) {
          if (mode == GameLaunchMode.otb && otbConfig != null) {
            onLaunch(otbConfig);
          }
        },
      ),
    ),
  );
}
