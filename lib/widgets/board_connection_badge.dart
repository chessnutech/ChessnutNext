import 'dart:async';

import '../l10n/localized_material.dart';

import '../services/network_latency_service.dart';
import '../services/physical_board_gateway.dart';
import '../theme/chessnut_theme.dart';
import 'app_chrome.dart';

class BoardConnectionBadge extends StatelessWidget {
  const BoardConnectionBadge({
    required this.state,
    this.batteryStatus,
    this.compact = false,
    this.fontSize,
    this.indicatorSize,
    this.horizontalPadding,
    this.verticalPadding,
    super.key,
  });

  final PhysicalBoardConnectionState state;
  final BoardBatteryStatus? batteryStatus;
  final bool compact;
  final double? fontSize;
  final double? indicatorSize;
  final double? horizontalPadding;
  final double? verticalPadding;

  bool get _connected => state == PhysicalBoardConnectionState.connected;

  @override
  Widget build(BuildContext context) {
    final battery = batteryStatus;
    final lowBattery = _connected && (battery?.isLow ?? false);
    final tokens = ChessnutTheme.tokensOf(context);
    final color = lowBattery
        ? tokens.warning
        : _connected
            ? Theme.of(context).colorScheme.primary
            : tokens.danger;
    return Material(
      color: Colors.transparent,
      child: GlassPanel(
        key: ValueKey(
          lowBattery
              ? 'board-status-low-battery'
              : _connected
                  ? 'board-status-connected'
                  : 'board-status-disconnected',
        ),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding ?? (compact ? 8 : 10),
          vertical: verticalPadding ?? 7,
        ),
        borderRadius: 999,
        tint: color.withValues(alpha: 0.12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact || battery == null || !_connected) ...[
              Container(
                width: indicatorSize ?? 8,
                height: indicatorSize ?? 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.34),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
            ],
            if (_connected && battery != null) ...[
              BoardBatteryIcon(status: battery, color: color),
              const SizedBox(width: 6),
            ],
            Text(
              lowBattery
                  ? compact
                      ? 'Low battery'
                      : 'Board battery low'
                  : _connected
                      ? compact
                          ? 'Connected'
                          : 'Board connected'
                      : compact
                          ? 'Disconnected'
                          : 'Board disconnected',
              style: TextStyle(
                fontSize: fontSize ?? 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BoardBatteryIcon extends StatefulWidget {
  const BoardBatteryIcon({
    required this.status,
    this.color,
    super.key,
  });

  final BoardBatteryStatus status;
  final Color? color;

  @override
  State<BoardBatteryIcon> createState() => _BoardBatteryIconState();
}

class _BoardBatteryIconState extends State<BoardBatteryIcon> {
  static const _stepDuration = Duration(milliseconds: 600);
  int _chargeFrame = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant BoardBatteryIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status.isCharging != widget.status.isCharging ||
        oldWidget.status.bars != widget.status.bars) {
      _chargeFrame = 0;
      _syncTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (!widget.status.isCharging || widget.status.bars >= 5) return;
    _timer = Timer.periodic(_stepDuration, (_) {
      if (!mounted) return;
      setState(() {
        _chargeFrame = (_chargeFrame + 1) % (widget.status.bars + 1);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final bars = widget.status.isCharging && widget.status.bars < 5
        ? _chargeFrame
        : widget.status.bars;
    return CustomPaint(
      key: ValueKey('board-battery-bars-$bars'),
      size: const Size(24, 13),
      painter: _BoardBatteryPainter(
        bars: bars,
        color: color,
        backgroundColor: color.withValues(alpha: 0.16),
      ),
    );
  }
}

class _BoardBatteryPainter extends CustomPainter {
  const _BoardBatteryPainter({
    required this.bars,
    required this.color,
    required this.backgroundColor,
  });

  final int bars;
  final Color color;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 1.5, size.width - 4.5, size.height - 3),
      const Radius.circular(2.8),
    );
    canvas.drawRRect(body, stroke);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width - 3.3, 4.3, 2.3, size.height - 8.6),
        const Radius.circular(1),
      ),
      Paint()..color = color.withValues(alpha: 0.72),
    );

    final slotWidth = (size.width - 8.5) / 5;
    for (var i = 0; i < 5; i++) {
      final left = 3 + i * slotWidth;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 4, slotWidth - 1.6, size.height - 8),
        const Radius.circular(1.2),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = i < bars ? color : backgroundColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BoardBatteryPainter oldDelegate) {
    return bars != oldDelegate.bars ||
        color != oldDelegate.color ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}

class NetworkLatencyBadge extends StatelessWidget {
  const NetworkLatencyBadge({
    required this.snapshot,
    this.fontSize,
    this.iconSize,
    this.horizontalPadding,
    this.verticalPadding,
    this.showPlatform = true,
    super.key,
  });

  final NetworkLatencySnapshot? snapshot;
  final double? fontSize;
  final double? iconSize;
  final double? horizontalPadding;
  final double? verticalPadding;
  final bool showPlatform;

  @override
  Widget build(BuildContext context) {
    final current = snapshot;
    final tone = current?.tone ?? NetworkLatencyTone.danger;
    final color = switch (tone) {
      NetworkLatencyTone.stable => Theme.of(context).colorScheme.primary,
      NetworkLatencyTone.warning => const Color(0xFFF59E0B),
      NetworkLatencyTone.danger => const Color(0xFFEF4444),
    };
    final keyName = switch (tone) {
      NetworkLatencyTone.stable => 'network-latency-stable',
      NetworkLatencyTone.warning => 'network-latency-warning',
      NetworkLatencyTone.danger => 'network-latency-danger',
    };
    final platform = current?.platform ?? 'Network';
    final value =
        current?.milliseconds == null ? '--' : '${current!.milliseconds}ms';
    final label = showPlatform ? '$platform $value' : value;
    return Material(
      color: Colors.transparent,
      child: GlassPanel(
        key: ValueKey(keyName),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding ?? 10,
          vertical: verticalPadding ?? 7,
        ),
        borderRadius: 999,
        tint: color.withValues(alpha: 0.12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.network_ping_rounded,
                size: iconSize ?? 15, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize ?? 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
