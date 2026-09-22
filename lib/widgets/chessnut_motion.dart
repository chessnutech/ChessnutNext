import 'dart:math' as math;

import 'package:flutter_animate/flutter_animate.dart';

import '../l10n/localized_material.dart';
import '../theme/chessnut_theme.dart';

bool chessnutMotionEnabled(BuildContext context) {
  final tokens = ChessnutTheme.tokensOf(context);
  return tokens.visualEffectsEnabled && !MediaQuery.disableAnimationsOf(context);
}

class ChessnutFadeSlide extends StatelessWidget {
  const ChessnutFadeSlide({
    required this.child,
    this.enabled = true,
    this.delay = Duration.zero,
    this.offsetY = 0.035,
    this.duration = const Duration(milliseconds: 260),
    super.key,
  });

  final Widget child;
  final bool enabled;
  final Duration delay;
  final double offsetY;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (!enabled || !chessnutMotionEnabled(context)) return child;
    return child
        .animate(delay: delay)
        .fadeIn(duration: duration, curve: Curves.easeOutCubic)
        .slideY(
          begin: offsetY,
          end: 0,
          duration: duration,
          curve: Curves.easeOutCubic,
        );
  }
}

class ChessnutPulseBadge extends StatelessWidget {
  const ChessnutPulseBadge({
    required this.child,
    this.active = true,
    this.duration = const Duration(milliseconds: 520),
    super.key,
  });

  final Widget child;
  final bool active;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    Widget content = child;
    if (active && chessnutMotionEnabled(context)) {
      content = content
          .animate()
          .scale(
            begin: const Offset(0.92, 0.92),
            end: const Offset(1, 1),
            duration: duration,
            curve: Curves.easeOutBack,
          )
          .fadeIn(duration: duration ~/ 2);
    }
    return KeyedSubtree(
      key: const ValueKey('chessnut-pulse-badge'),
      child: content,
    );
  }
}

class ChessnutAttentionBorder extends StatelessWidget {
  const ChessnutAttentionBorder({
    required this.child,
    this.active = true,
    this.color,
    this.secondaryColor,
    this.borderRadius = 14,
    this.borderWidth = 1.6,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final bool active;
  final Color? color;
  final Color? secondaryColor;
  final double borderRadius;
  final double borderWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = color ?? scheme.primary;
    final secondary = secondaryColor ?? scheme.secondary;
    final effects = active && chessnutMotionEnabled(context);
    return TweenAnimationBuilder<double>(
      key: const ValueKey('chessnut-attention-border'),
      tween: Tween(begin: 0, end: effects ? 1 : 0),
      duration: effects ? const Duration(milliseconds: 900) : Duration.zero,
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) {
        return CustomPaint(
          foregroundPainter: active
              ? _AttentionBorderPainter(
                  progress: progress,
                  color: primary,
                  secondaryColor: secondary,
                  radius: borderRadius,
                  width: borderWidth,
                )
              : null,
          child: Padding(padding: padding, child: child),
        );
      },
    );
  }
}

class ChessnutShimmerAction extends StatelessWidget {
  const ChessnutShimmerAction({
    required this.child,
    this.active = true,
    this.color,
    super.key,
  });

  final Widget child;
  final bool active;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    return ChessnutAttentionBorder(
      active: active,
      color: color,
      borderRadius: ChessnutTheme.tokensOf(context).controlRadius,
      child: child,
    );
  }
}

class _AttentionBorderPainter extends CustomPainter {
  const _AttentionBorderPainter({
    required this.progress,
    required this.color,
    required this.secondaryColor,
    required this.radius,
    required this.width,
  });

  final double progress;
  final Color color;
  final Color secondaryColor;
  final double radius;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(width / 2),
      Radius.circular(radius),
    );
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color.withValues(alpha: 0.24 + progress * 0.10);
    canvas.drawRRect(rrect, basePaint);

    final path = Path()..addRRect(rrect);
    final metric = path.computeMetrics().first;
    final length = metric.length;
    final head = (progress * length * 1.18) % length;
    final tail = math.max(0.0, head - length * 0.26);
    final beam = metric.extractPath(tail, head);
    final beamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width + 0.4
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          secondaryColor.withValues(alpha: 0),
          secondaryColor.withValues(alpha: 0.92),
          color.withValues(alpha: 0.92),
        ],
      ).createShader(rect);
    canvas.drawPath(beam, beamPaint);
  }

  @override
  bool shouldRepaint(covariant _AttentionBorderPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        color != oldDelegate.color ||
        secondaryColor != oldDelegate.secondaryColor ||
        radius != oldDelegate.radius ||
        width != oldDelegate.width;
  }
}
