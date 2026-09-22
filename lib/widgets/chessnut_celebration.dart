import 'dart:math' as math;

import '../l10n/localized_material.dart';
import '../theme/chessnut_theme.dart';
import 'chessnut_motion.dart';

enum ChessnutCelebrationResult {
  victory,
  defeat,
  draw;

  String get keyName => switch (this) {
        ChessnutCelebrationResult.victory => 'victory',
        ChessnutCelebrationResult.defeat => 'defeat',
        ChessnutCelebrationResult.draw => 'draw',
      };

  IconData get icon => switch (this) {
        ChessnutCelebrationResult.victory => Icons.emoji_events_rounded,
        ChessnutCelebrationResult.defeat => Icons.flag_rounded,
        ChessnutCelebrationResult.draw => Icons.handshake_rounded,
      };

  String get semanticLabel => switch (this) {
        ChessnutCelebrationResult.victory => 'Victory result animation',
        ChessnutCelebrationResult.defeat => 'Defeat result animation',
        ChessnutCelebrationResult.draw => 'Draw result animation',
      };
}

class ChessnutGameResultCelebration extends StatelessWidget {
  const ChessnutGameResultCelebration({
    required this.result,
    this.height = 86,
    super.key,
  });

  final ChessnutCelebrationResult result;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = ChessnutTheme.tokensOf(context);
    final accent = switch (result) {
      ChessnutCelebrationResult.victory => tokens.success,
      ChessnutCelebrationResult.defeat => tokens.danger,
      ChessnutCelebrationResult.draw => tokens.info,
    };
    final effects = chessnutMotionEnabled(context);
    return KeyedSubtree(
      key: ValueKey('chessnut-game-result-celebration-${result.keyName}'),
      child: Semantics(
        label: result.semanticLabel,
        image: true,
        child: SizedBox(
          height: height,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: effects ? 1 : 0.82),
            duration:
                effects ? const Duration(milliseconds: 900) : Duration.zero,
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return CustomPaint(
                painter: _ResultCelebrationPainter(
                  progress: value,
                  result: result,
                  accent: accent,
                  secondary: Theme.of(context).colorScheme.secondary,
                  dark: Theme.of(context).brightness == Brightness.dark,
                ),
                child: Center(
                  child: _ResultCelebrationSymbol(
                    progress: value,
                    result: result,
                    accent: accent,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ResultCelebrationSymbol extends StatelessWidget {
  const _ResultCelebrationSymbol({
    required this.progress,
    required this.result,
    required this.accent,
  });

  final double progress;
  final ChessnutCelebrationResult result;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final background = switch (result) {
      ChessnutCelebrationResult.victory => 0.18,
      ChessnutCelebrationResult.defeat => 0.12,
      ChessnutCelebrationResult.draw => 0.14,
    };
    final rotation = result == ChessnutCelebrationResult.defeat
        ? -0.18 * progress
        : 0.0;
    final verticalOffset = switch (result) {
      ChessnutCelebrationResult.victory => -4.0 * progress,
      ChessnutCelebrationResult.defeat => 4.0 * progress,
      ChessnutCelebrationResult.draw => 0.0,
    };
    return Transform.translate(
      offset: Offset(0, verticalOffset),
      child: Transform.rotate(
        angle: rotation,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: background),
                shape: BoxShape.circle,
                border: Border.all(
                  color: accent.withValues(alpha: 0.36),
                  width: 1.4,
                ),
              ),
            ),
            Icon(result.icon, color: accent, size: 35),
            if (result == ChessnutCelebrationResult.victory) ...[
              Positioned(
                top: -4,
                right: 2,
                child: Icon(Icons.star_rounded, color: accent, size: 18),
              ),
              Positioned(
                left: -2,
                bottom: 6,
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: accent.withValues(alpha: 0.82),
                  size: 16,
                ),
              ),
            ],
            if (result == ChessnutCelebrationResult.defeat)
              Positioned(
                right: -2,
                bottom: 2,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withValues(alpha: 0.32)),
                  ),
                  child: Icon(Icons.close_rounded, color: accent, size: 16),
                ),
              ),
            if (result == ChessnutCelebrationResult.draw)
              Positioned(
                right: -3,
                top: 1,
                child: Icon(
                  Icons.balance_rounded,
                  color: accent.withValues(alpha: 0.92),
                  size: 19,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ChessnutClaimCelebration extends StatelessWidget {
  const ChessnutClaimCelebration({
    required this.label,
    super.key,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = ChessnutTheme.tokensOf(context).success;
    return ChessnutPulseBadge(
      child: Container(
        key: const ValueKey('chessnut-claim-celebration'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _ResultCelebrationPainter extends CustomPainter {
  const _ResultCelebrationPainter({
    required this.progress,
    required this.result,
    required this.accent,
    required this.secondary,
    required this.dark,
  });

  final double progress;
  final ChessnutCelebrationResult result;
  final Color accent;
  final Color secondary;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    switch (result) {
      case ChessnutCelebrationResult.victory:
        _paintVictory(canvas, size, center);
      case ChessnutCelebrationResult.defeat:
        _paintDefeat(canvas, size, center);
      case ChessnutCelebrationResult.draw:
        _paintDraw(canvas, size, center);
    }
  }

  void _paintVictory(Canvas canvas, Size size, Offset center) {
    final rayPaint = Paint()
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.22 + progress * 0.18);
    for (var i = 0; i < 9; i++) {
      final angle = -math.pi * 0.86 + i * math.pi * 0.215;
      final start = center + Offset(math.cos(angle), math.sin(angle)) * 36;
      final end = center + Offset(math.cos(angle), math.sin(angle)) * (46 + 8 * progress);
      canvas.drawLine(start, end, rayPaint);
    }

    final podiumPaint = Paint()..color = accent.withValues(alpha: 0.18);
    final baseY = size.height - 11;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx, baseY), width: 86, height: 7),
        const Radius.circular(999),
      ),
      podiumPaint,
    );

    for (var i = 0; i < 10; i++) {
      final angle = (math.pi * 2 / 10) * i - math.pi / 2;
      final distance = 36 + progress * 17;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * distance;
      final particleColor = i.isEven ? accent : secondary;
      canvas.drawCircle(
        point,
        2.2 * (1 - progress * 0.18),
        Paint()..color = particleColor.withValues(alpha: 0.66 - progress * 0.18),
      );
    }
  }

  void _paintDefeat(Canvas canvas, Size size, Offset center) {
    final groundPaint = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: dark ? 0.36 : 0.28);
    final groundY = center.dy + 31;
    canvas.drawLine(
      Offset(center.dx - 45, groundY),
      Offset(center.dx + 45, groundY),
      groundPaint,
    );
    final crackPaint = Paint()
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.32);
    canvas.drawLine(
      Offset(center.dx - 12, groundY),
      Offset(center.dx - 3, groundY + 7 * progress),
      crackPaint,
    );
    canvas.drawLine(
      Offset(center.dx + 10, groundY),
      Offset(center.dx + 1, groundY + 6 * progress),
      crackPaint,
    );
    canvas.drawLine(
      Offset(center.dx - 48, center.dy - 28),
      Offset(center.dx - 32, center.dy - 12),
      crackPaint,
    );
    canvas.drawLine(
      Offset(center.dx - 32, center.dy - 28),
      Offset(center.dx - 48, center.dy - 12),
      crackPaint,
    );
  }

  void _paintDraw(Canvas canvas, Size size, Offset center) {
    final linePaint = Paint()
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.32 + progress * 0.14);
    final y = center.dy + 30;
    canvas.drawLine(Offset(center.dx - 48, y), Offset(center.dx + 48, y), linePaint);
    canvas.drawLine(Offset(center.dx, y), Offset(center.dx, y - 18), linePaint);
    canvas.drawLine(Offset(center.dx - 34, y - 18), Offset(center.dx + 34, y - 18), linePaint);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(center.dx - 34, y - 9), width: 25, height: 14),
      0,
      math.pi,
      false,
      linePaint,
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(center.dx + 34, y - 9), width: 25, height: 14),
      0,
      math.pi,
      false,
      linePaint,
    );
    final equalPaint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = secondary.withValues(alpha: 0.68);
    canvas.drawLine(
      Offset(center.dx - 9, center.dy - 35),
      Offset(center.dx + 9, center.dy - 35),
      equalPaint,
    );
    canvas.drawLine(
      Offset(center.dx - 9, center.dy - 29),
      Offset(center.dx + 9, center.dy - 29),
      equalPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ResultCelebrationPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        result != oldDelegate.result ||
        accent != oldDelegate.accent ||
        secondary != oldDelegate.secondary ||
        dark != oldDelegate.dark;
  }
}
