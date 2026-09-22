import '../l10n/localized_material.dart';
import '../theme/chessnut_theme.dart';
import 'chessnut_motion.dart';

class ChessnutBoardScanLoader extends StatelessWidget {
  const ChessnutBoardScanLoader({
    required this.active,
    required this.label,
    this.size = 92,
    super.key,
  });

  final bool active;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effects = active && chessnutMotionEnabled(context);
    return KeyedSubtree(
      key: const ValueKey('chessnut-board-scan-loader'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: effects ? 1 : 0),
            duration: effects ? const Duration(milliseconds: 820) : Duration.zero,
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return SizedBox.square(
                dimension: size,
                child: CustomPaint(
                  painter: _BoardScanPainter(
                    progress: value,
                    primary: scheme.primary,
                    secondary: scheme.secondary,
                    dark: Theme.of(context).brightness == Brightness.dark,
                  ),
                  child: Center(
                    child: Icon(
                      active
                          ? Icons.bluetooth_searching_rounded
                          : Icons.bluetooth_connected_rounded,
                      color: active ? scheme.primary : ChessnutTheme.tokensOf(context).success,
                      size: size * 0.28,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class ChessnutEngineTrainingProgress extends StatelessWidget {
  const ChessnutEngineTrainingProgress({
    required this.value,
    required this.color,
    this.active = true,
    super.key,
  });

  final double value;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    return TweenAnimationBuilder<double>(
      key: const ValueKey('chessnut-engine-training-progress'),
      tween: Tween(begin: 0, end: normalized),
      duration: active && chessnutMotionEnabled(context)
          ? const Duration(milliseconds: 520)
          : Duration.zero,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: animatedValue,
            minHeight: 7,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        );
      },
    );
  }
}

class _BoardScanPainter extends CustomPainter {
  const _BoardScanPainter({
    required this.progress,
    required this.primary,
    required this.secondary,
    required this.dark,
  });

  final double progress;
  final Color primary;
  final Color secondary;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    for (var i = 0; i < 3; i++) {
      final phase = ((progress + i * 0.22) % 1.0);
      final ringRadius = radius * (0.42 + phase * 0.42);
      final opacity = (1 - phase).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        ringRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = (i.isEven ? primary : secondary)
              .withValues(alpha: (dark ? 0.30 : 0.24) * opacity),
      );
    }
    canvas.drawCircle(
      center,
      radius * 0.34,
      Paint()
        ..color = dark
            ? const Color(0xE6020617)
            : const Color(0xF7FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant _BoardScanPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        primary != oldDelegate.primary ||
        secondary != oldDelegate.secondary ||
        dark != oldDelegate.dark;
  }
}
