import 'package:chessnut_flutter_export/l10n/app_language.dart';
import 'package:chessnut_flutter_export/l10n/app_strings.dart';
import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/screens/game_room_screen.dart';
import 'package:chessnut_flutter_export/theme/chessnut_theme.dart';
import 'package:chessnut_flutter_export/widgets/chess_board.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Android Lichess landscape fits short phone screens without going blank',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.physicalSize = const Size(780, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: ChessnutTheme.light(),
          supportedLocales: AppLanguagePreference.supportedLocales,
          localizationsDelegates: AppStrings.localizationsDelegates,
          home: Scaffold(
            body: GameRoomScreen(
              onNavigate: (_) {},
              mode: GameLaunchMode.lichess,
            ),
          ),
        ),
      );
      await tester.pump();

      final board = find.byType(InteractiveChessBoard);
      expect(board, findsOneWidget);
      final boardRect = tester.getRect(board);
      expect(boardRect.width, lessThanOrEqualTo(306.5));
      expect(boardRect.height, lessThanOrEqualTo(306.5));
      expect(boardRect.bottom, lessThanOrEqualTo(360));
      final info = find.byKey(const ValueKey('lichess-game-info'));
      expect(info, findsOneWidget);
      expect(
        find.descendant(of: info, matching: find.text('10+5')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: info, matching: find.text('Casual')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
