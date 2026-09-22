import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chessnut_flutter_export/theme/chessnut_theme.dart';
import 'package:chessnut_flutter_export/widgets/chessnut_celebration.dart';
import 'package:chessnut_flutter_export/widgets/chessnut_loading.dart';
import 'package:chessnut_flutter_export/widgets/chessnut_motion.dart';

Widget _host(Widget child, {bool effectsEnabled = true}) {
  return MaterialApp(
    theme: ChessnutTheme.light(ChessnutVisualTheme.modern, effectsEnabled),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('attention border keeps child and exposes motion boundary',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const ChessnutAttentionBorder(
          active: true,
          child: Text('Ready'),
        ),
      ),
    );

    expect(find.text('Ready'), findsOneWidget);
    expect(find.byKey(const ValueKey('chessnut-attention-border')), findsOneWidget);
  });

  testWidgets('pulse badge keeps child when visual effects are disabled',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const ChessnutPulseBadge(
          active: true,
          child: Icon(Icons.check_rounded),
        ),
        effectsEnabled: false,
      ),
    );

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byKey(const ValueKey('chessnut-pulse-badge')), findsOneWidget);
  });

  testWidgets('board scan loader exposes scanning status', (tester) async {
    await tester.pumpWidget(
      _host(
        const ChessnutBoardScanLoader(
          active: true,
          label: 'Scanning nearby',
        ),
      ),
    );

    expect(find.byKey(const ValueKey('chessnut-board-scan-loader')), findsOneWidget);
    expect(find.text('Scanning nearby'), findsOneWidget);
  });

  testWidgets('game result celebration renders by result type', (tester) async {
    await tester.pumpWidget(
      _host(
        const ChessnutGameResultCelebration(
          result: ChessnutCelebrationResult.victory,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('chessnut-game-result-celebration-victory')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Victory result animation'), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
  });

  testWidgets('game result celebration exposes clear defeat and draw symbols',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChessnutGameResultCelebration(
              result: ChessnutCelebrationResult.defeat,
            ),
            ChessnutGameResultCelebration(
              result: ChessnutCelebrationResult.draw,
            ),
          ],
        ),
      ),
    );

    expect(find.bySemanticsLabel('Defeat result animation'), findsOneWidget);
    expect(find.bySemanticsLabel('Draw result animation'), findsOneWidget);
    expect(find.byIcon(Icons.flag_rounded), findsOneWidget);
    expect(find.byIcon(Icons.handshake_rounded), findsOneWidget);
    expect(find.byIcon(Icons.balance_rounded), findsOneWidget);
  });
}
