import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chessnut_flutter_export/screens/analysis_screen.dart';
import 'package:chessnut_flutter_export/screens/training_screen.dart';
import 'package:chessnut_flutter_export/services/chessnut_api_client.dart';
import 'package:chessnut_flutter_export/theme/chessnut_theme.dart';

void main() {
  testWidgets(
      'Android portrait training modes leave space inside the panel border',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(_harness(
        TrainingScreen(onNavigate: (_) {}),
      ));
      await tester.pumpAndSettle();
      final trainingSize = tester.getSize(
        find.byKey(const ValueKey('practice-mode-board-analyzer')),
      );
      final panelRect = tester.getRect(
        find.byKey(const ValueKey('training-modes-panel')),
      );
      final firstCardRect = tester.getRect(
        find.byKey(const ValueKey('practice-mode-board-analyzer')),
      );
      final secondCardRect = tester.getRect(
        find.byKey(const ValueKey('practice-mode-puzzle-storm')),
      );
      for (final key in const [
        'practice-mode-puzzle-storm',
        'practice-mode-puzzle-themes',
        'practice-mode-mistake-book',
      ]) {
        expect(tester.getSize(find.byKey(ValueKey(key))), trainingSize);
      }
      expect(firstCardRect.left - panelRect.left, greaterThanOrEqualTo(14));
      expect(panelRect.right - secondCardRect.right, greaterThanOrEqualTo(14));

      await tester.pumpWidget(_harness(
        AnalysisScreen(
          onNavigate: (_) {},
          apiClient: ChessnutApiClient(),
          attachedPgn: null,
          onStartReview: (_) {},
          onOpenLastGame: () {},
        ),
      ));
      await tester.pumpAndSettle();
      final gameRecordSize = tester.getSize(
        find.byKey(const ValueKey('analysis-game-record-entry')),
      );

      expect(trainingSize.width, lessThan(gameRecordSize.width));
      expect(trainingSize.height, lessThan(gameRecordSize.height));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('non-Android portrait keeps the existing training card size',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(_harness(
        TrainingScreen(onNavigate: (_) {}),
      ));
      await tester.pumpAndSettle();

      final trainingSize = tester.getSize(
        find.byKey(const ValueKey('practice-mode-board-analyzer')),
      );
      expect(trainingSize.width, lessThan(170));
      expect(trainingSize.width / trainingSize.height, closeTo(1.05, 0.01));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android landscape keeps the existing training card size',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(1024, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(_harness(
        TrainingScreen(onNavigate: (_) {}),
      ));
      await tester.pumpAndSettle();

      final trainingSize = tester.getSize(
        find.byKey(const ValueKey('practice-mode-board-analyzer')),
      );

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(_harness(
        TrainingScreen(onNavigate: (_) {}),
      ));
      await tester.pumpAndSettle();
      final nonAndroidSize = tester.getSize(
        find.byKey(const ValueKey('practice-mode-board-analyzer')),
      );

      expect(trainingSize, nonAndroidSize);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android chess clock keeps the existing training card size',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(_harness(
        TrainingScreen(
          onNavigate: (_) {},
          isChessnutClockDevice: true,
        ),
      ));
      await tester.pumpAndSettle();

      final trainingSize = tester.getSize(
        find.byKey(const ValueKey('practice-mode-board-analyzer')),
      );
      expect(trainingSize.width, lessThan(170));
      expect(trainingSize.width / trainingSize.height, closeTo(1.05, 0.01));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('macOS fullscreen shows all four training modes completely',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(_harness(
        TrainingScreen(onNavigate: (_) {}),
      ));
      await tester.pumpAndSettle();

      final coursePanel = tester.getRect(
        find.byKey(const ValueKey('interactive-course-panel')),
      );
      final modesPanel = tester.getRect(
        find.byKey(const ValueKey('training-modes-panel')),
      );
      expect(coursePanel.height, closeTo(320, 0.01));
      expect(modesPanel.height, closeTo(320, 0.01));

      for (final item in const [
        (
          key: 'practice-mode-board-analyzer',
          title: 'Board analyzer',
          subtitle: 'Live Stockfish board',
        ),
        (
          key: 'practice-mode-puzzle-storm',
          title: 'Puzzle storm',
          subtitle: 'Fast pattern training',
        ),
        (
          key: 'practice-mode-puzzle-themes',
          title: 'Puzzle themes',
          subtitle: 'Practice by motif',
        ),
        (
          key: 'practice-mode-mistake-book',
          title: 'Mistake book',
          subtitle: 'From your games',
        ),
      ]) {
        final cardFinder = find.byKey(ValueKey(item.key));
        final card = tester.getRect(cardFinder);
        final title = tester.getRect(
          find.descendant(of: cardFinder, matching: find.text(item.title)),
        );
        final subtitle = tester.getRect(
          find.descendant(of: cardFinder, matching: find.text(item.subtitle)),
        );
        expect(card.height, greaterThanOrEqualTo(100));
        expect(card.contains(title.topLeft), isTrue);
        expect(card.contains(title.bottomRight), isTrue);
        expect(card.contains(subtitle.topLeft), isTrue);
        expect(card.contains(subtitle.bottomRight), isTrue);
        expect(modesPanel.contains(card.center), isTrue);
      }
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Windows fullscreen shows all four training modes completely',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1400, 675);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(_harness(
        TrainingScreen(onNavigate: (_) {}),
      ));
      await tester.pumpAndSettle();

      final panel = tester.getRect(
        find.byKey(const ValueKey('training-modes-panel')),
      );
      expect(panel.height, closeTo(320, 0.01));
      for (final item in const [
        (
          key: 'practice-mode-board-analyzer',
          title: 'Board analyzer',
          subtitle: 'Live Stockfish board',
        ),
        (
          key: 'practice-mode-puzzle-storm',
          title: 'Puzzle storm',
          subtitle: 'Fast pattern training',
        ),
        (
          key: 'practice-mode-puzzle-themes',
          title: 'Puzzle themes',
          subtitle: 'Practice by motif',
        ),
        (
          key: 'practice-mode-mistake-book',
          title: 'Mistake book',
          subtitle: 'From your games',
        ),
      ]) {
        final cardFinder = find.byKey(ValueKey(item.key));
        final card = tester.getRect(cardFinder);
        final title = tester.getRect(
          find.descendant(of: cardFinder, matching: find.text(item.title)),
        );
        final subtitle = tester.getRect(
          find.descendant(of: cardFinder, matching: find.text(item.subtitle)),
        );
        expect(card.height, greaterThanOrEqualTo(100));
        expect(card.contains(title.topLeft), isTrue);
        expect(card.contains(title.bottomRight), isTrue);
        expect(card.contains(subtitle.topLeft), isTrue);
        expect(card.contains(subtitle.bottomRight), isTrue);
        expect(panel.contains(card.center), isTrue);
      }
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Widget _harness(Widget child) {
  return MaterialApp(
    theme: ChessnutTheme.light(),
    home: Scaffold(body: child),
  );
}
