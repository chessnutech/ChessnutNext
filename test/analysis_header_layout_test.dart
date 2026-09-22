import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chessnut_flutter_export/screens/analysis_screen.dart';
import 'package:chessnut_flutter_export/services/chessnut_api_client.dart';
import 'package:chessnut_flutter_export/theme/chessnut_theme.dart';

void main() {
  testWidgets('Android Analyze PGN title stays on one line', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      final titleFinder = find.byKey(const ValueKey('analysis-header-title'));
      final title = tester.widget(titleFinder) as dynamic;
      final titleRect = tester.getRect(titleFinder);
      final recordsRect =
          tester.getRect(find.byKey(const ValueKey('analysis-records-action')));

      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(titleRect.right, lessThanOrEqualTo(recordsRect.left));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('non-Android Analyze PGN keeps the existing compact title layout',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      final title = tester.widget(
        find.byKey(const ValueKey('analysis-header-title')),
      ) as dynamic;
      expect(title.maxLines, 2);
      expect(title.overflow, TextOverflow.visible);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android chess clock keeps the existing compact title layout',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(_harness(isChessnutClockDevice: true));
      await tester.pumpAndSettle();

      final title = tester.widget(
        find.byKey(const ValueKey('analysis-header-title')),
      ) as dynamic;
      expect(title.maxLines, 2);
      expect(title.overflow, TextOverflow.visible);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Widget _harness({bool isChessnutClockDevice = false}) {
  return MaterialApp(
    theme: ChessnutTheme.light(),
    home: Scaffold(
      body: AnalysisScreen(
        onNavigate: (_) {},
        apiClient: ChessnutApiClient(),
        isChessnutClockDevice: isChessnutClockDevice,
        attachedPgn: null,
        onStartReview: (_) {},
        onOpenLastGame: () {},
      ),
    ),
  );
}
