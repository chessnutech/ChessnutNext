import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/screens/chess_clock_screen.dart';
import 'package:chessnut_flutter_export/services/chess_clock_switch_service.dart';
import 'package:chessnut_flutter_export/theme/chessnut_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Android phone Chess Clock uses the landscape clock board',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: ChessnutTheme.light(),
          home: Scaffold(
            body: ChessClockScreen(
              onNavigate: (_) {},
              config: const OtbGameConfig(
                timeMinutes: 10,
                incrementSeconds: 0,
              ),
              clockSwitchService: ChessClockSwitchService(
                enableUsbButtons: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('clock-vertical-board')),
        findsOneWidget,
      );
      expect(find.text('Standalone clock'), findsNothing);
      expect(find.text('Tap to switch'), findsNothing);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('clock-landscape-board')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('clock-vertical-board')),
        findsNothing,
      );
      final black = tester.getRect(
        find.byKey(const ValueKey('clock-face-black')),
      );
      final controls = tester.getRect(
        find.byKey(const ValueKey('clock-control-dock')),
      );
      final white = tester.getRect(
        find.byKey(const ValueKey('clock-face-white')),
      );
      expect(black.right, lessThanOrEqualTo(controls.left));
      expect(controls.right, lessThanOrEqualTo(white.left));
      expect(white.bottom, lessThanOrEqualTo(390));
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Chessnut Clock keeps its existing wide landscape board',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(1280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: ChessnutTheme.light(),
          home: Scaffold(
            body: ChessClockScreen(
              onNavigate: (_) {},
              config: const OtbGameConfig(
                timeMinutes: 10,
                incrementSeconds: 0,
              ),
              isChessnutClockDevice: true,
              clockSwitchService: ChessClockSwitchService(
                enableUsbButtons: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('clock-landscape-board')),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('clock-face-white'))).height,
        greaterThanOrEqualTo(340),
      );
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Windows Chess Clock uses the complete landscape clock board',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(2560, 1369);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: ChessnutTheme.light(),
          home: Scaffold(
            body: ChessClockScreen(
              onNavigate: (_) {},
              config: const OtbGameConfig(
                timeMinutes: 10,
                incrementSeconds: 5,
              ),
              clockSwitchService: ChessClockSwitchService(
                enableUsbButtons: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('clock-landscape-board')),
        findsOneWidget,
      );
      final board = tester.getRect(
        find.byKey(const ValueKey('clock-landscape-board')),
      );
      final black = tester.getRect(
        find.byKey(const ValueKey('clock-face-black')),
      );
      final controls = tester.getRect(
        find.byKey(const ValueKey('clock-control-dock')),
      );
      final white = tester.getRect(
        find.byKey(const ValueKey('clock-face-white')),
      );
      expect(black.width, greaterThan(400));
      expect(board.width, lessThanOrEqualTo(1260));
      expect(board.height, inInclusiveRange(360, 460));
      expect(black.right, lessThanOrEqualTo(controls.left));
      expect(controls.right, lessThanOrEqualTo(white.left));
      expect(white.width, greaterThan(400));
      expect(white.bottom, lessThanOrEqualTo(1369));
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Chessnut Clock keeps the portrait status card', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: ChessnutTheme.light(),
          home: Scaffold(
            body: ChessClockScreen(
              onNavigate: (_) {},
              config: const OtbGameConfig(
                timeMinutes: 10,
                incrementSeconds: 5,
              ),
              isChessnutClockDevice: true,
              clockSwitchService: ChessClockSwitchService(
                enableUsbButtons: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Standalone clock'), findsOneWidget);
      expect(find.text('Tap to switch'), findsOneWidget);
      expect(find.text('+5 sec increment'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
