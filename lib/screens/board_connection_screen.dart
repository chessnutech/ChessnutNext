import 'dart:async';
import 'dart:io';

import '../l10n/localized_material.dart';

import '../services/physical_board_gateway.dart';
import '../theme/chessnut_theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/chessnut_loading.dart';

typedef BoardConnectedCallback = void Function(
  PhysicalBoardModel model, {
  PhysicalBoardGateway? gateway,
});
typedef BoardGatewayFactory = PhysicalBoardGateway Function();

class BoardConnectionScreen extends StatefulWidget {
  const BoardConnectionScreen({
    required this.onNavigate,
    required this.onConnected,
    required this.gateway,
    this.usbGateway,
    this.usbGatewayFactory,
    this.enableUsbConnection = true,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final BoardConnectedCallback onConnected;
  final PhysicalBoardGateway gateway;
  final PhysicalBoardGateway? usbGateway;
  final BoardGatewayFactory? usbGatewayFactory;
  final bool enableUsbConnection;

  @override
  State<BoardConnectionScreen> createState() => _BoardConnectionScreenState();
}

class _BoardConnectionScreenState extends State<BoardConnectionScreen> {
  late final StreamSubscription<PhysicalBoardConnectionState> stateSub;
  PhysicalBoardConnectionState state =
      PhysicalBoardConnectionState.disconnected;
  String statusMessage = 'Starting Bluetooth scan automatically.';
  String usbStatusMessage =
      'Use USB only if Bluetooth is not your preferred path.';
  bool connectionFailed = false;
  bool usbConnecting = false;
  bool usbConnectionFailed = false;
  PhysicalBoardGateway? _activeUsbGateway;

  bool get connecting =>
      state == PhysicalBoardConnectionState.scanning ||
      state == PhysicalBoardConnectionState.connecting;

  bool get _canUseUsbConnection =>
      widget.enableUsbConnection &&
      _supportsUsbConnection &&
      (widget.usbGateway != null || widget.usbGatewayFactory != null);

  @override
  void initState() {
    super.initState();
    stateSub = widget.gateway.stateStream.listen((value) {
      if (!mounted) return;
      setState(() {
        state = value;
        statusMessage = _messageForState(value);
        if (value != PhysicalBoardConnectionState.disconnected) {
          connectionFailed = false;
        }
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_connect());
    });
  }

  @override
  void dispose() {
    unawaited(stateSub.cancel());
    super.dispose();
  }

  Future<void> _connect() async {
    if (connecting) return;
    setState(() {
      connectionFailed = false;
      state = PhysicalBoardConnectionState.scanning;
      statusMessage = _messageForState(state);
    });
    final connected = await widget.gateway.connect();
    if (!mounted) return;
    if (!connected) {
      setState(() {
        state = PhysicalBoardConnectionState.disconnected;
        connectionFailed = true;
        statusMessage =
            'No Chessnut board was found. Check Bluetooth permissions and pairing mode, then try again.';
      });
      return;
    }
    await widget.gateway.enableRealtimeFen();
    if (!mounted) return;
    widget.onConnected(widget.gateway.boardModel, gateway: widget.gateway);
  }

  Future<void> _connectUsb() async {
    if (usbConnecting || !_canUseUsbConnection) return;
    setState(() {
      usbConnecting = true;
      usbConnectionFailed = false;
      usbStatusMessage = 'Looking for a USB HID Chessnut board.';
    });
    final usbGateway = _usbGatewayForConnection();
    if (usbGateway == null) {
      if (!mounted) return;
      setState(() {
        usbConnecting = false;
        usbConnectionFailed = true;
        usbStatusMessage =
            'USB support is not available in this build. Add the EasyLinkSDK runtime library, then restart the app.';
      });
      return;
    }
    final connected = await usbGateway.connect();
    if (!mounted) return;
    if (!connected) {
      setState(() {
        usbConnecting = false;
        usbConnectionFailed = true;
        usbStatusMessage =
            'No USB board was found. Check the cable and reconnect the board, then try again.';
      });
      return;
    }
    await usbGateway.enableRealtimeFen();
    if (!mounted) return;
    setState(() {
      usbConnecting = false;
      usbStatusMessage = 'USB board connected.';
    });
    widget.onConnected(usbGateway.boardModel, gateway: usbGateway);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ResponsivePage(
      children: (context, spec) => [
        ScreenHeader(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => widget.onNavigate('Back'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: 'Connect board',
          subtitle: 'Bluetooth',
          trailing: _ConnectionStatePill(state: state),
        ),
        SizedBox(height: spec.gutter),
        ResponsiveSplit(
          breakpoint: 860,
          spacing: spec.gutter,
          leadingFlex: 6,
          trailingFlex: 5,
          leading: SectionColumn(
            spacing: 10,
            children: [
              GlassPanel(
                padding: EdgeInsets.zero,
                child: _BluetoothHero(scanning: connecting),
              ),
              if (connectionFailed) _ConnectionHelpPanel(),
            ],
          ),
          trailing: SectionColumn(
            spacing: 10,
            children: [
              if (connectionFailed) _PermissionPanel(),
              GlassPanel(
                padding: const EdgeInsets.all(12),
                borderRadius: 13,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connecting ? 'Scanning nearby' : 'Nearby board',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    _BoardDeviceTile(
                      state: state,
                      boardModel: widget.gateway.boardModel,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      statusMessage,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (connectionFailed)
                PrimaryButton(
                  label: 'Retry connection',
                  icon: Icons.refresh_rounded,
                  onPressed: _connect,
                ),
              Text(
                connectionFailed
                    ? 'Review the checklist, then retry from this screen.'
                    : 'Scanning starts automatically. Keep the board nearby while Chessnut connects.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.58),
                    ),
              ),
              if (_canUseUsbConnection)
                _UsbConnectionCard(
                  connecting: usbConnecting,
                  failed: usbConnectionFailed,
                  message: usbStatusMessage,
                  onConnect: _connectUsb,
                ),
            ],
          ),
        ),
      ],
    );
  }

  PhysicalBoardGateway? _usbGatewayForConnection() {
    final existing = widget.usbGateway ?? _activeUsbGateway;
    if (existing != null) return existing;
    final factory = widget.usbGatewayFactory;
    if (factory == null) return null;
    try {
      _activeUsbGateway = factory();
      return _activeUsbGateway;
    } catch (_) {
      return null;
    }
  }
}

bool get _supportsUsbConnection {
  return Platform.isWindows || Platform.isMacOS || Platform.isAndroid;
}

class _ConnectionStatePill extends StatelessWidget {
  const _ConnectionStatePill({required this.state});

  final PhysicalBoardConnectionState state;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderRadius: 999,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            state == PhysicalBoardConnectionState.connected
                ? Icons.bluetooth_connected_rounded
                : state == PhysicalBoardConnectionState.disconnected
                    ? Icons.bluetooth_disabled_rounded
                    : Icons.bluetooth_searching_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 6),
          Text(
            state == PhysicalBoardConnectionState.connected
                ? 'Online'
                : state == PhysicalBoardConnectionState.disconnected
                    ? 'Offline'
                    : 'Scanning',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _UsbConnectionCard extends StatelessWidget {
  const _UsbConnectionCard({
    required this.connecting,
    required this.failed,
    required this.message,
    required this.onConnect,
  });

  final bool connecting;
  final bool failed;
  final String message;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color =
        failed ? ChessnutTheme.tokensOf(context).danger : scheme.secondary;
    return GlassPanel(
      key: const ValueKey('connect-usb-card'),
      padding: const EdgeInsets.all(12),
      borderRadius: 13,
      tint: color.withValues(alpha: 0.055),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.usb_rounded, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'USB connection',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const ValueKey('connect-usb-button'),
            onPressed: connecting ? null : onConnect,
            icon: connecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.usb_rounded),
            label: Text(connecting ? 'Connecting USB' : 'Connect USB board'),
          ),
        ],
      ),
    );
  }
}

class _BluetoothHero extends StatelessWidget {
  const _BluetoothHero({required this.scanning});

  final bool scanning;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final tokens = ChessnutTheme.tokensOf(context);
    final classic = tokens.visualTheme == ChessnutVisualTheme.classic;
    final lowCost = isCompactLandscapeDevice(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.panelRadius),
      child: SizedBox(
        height: lowCost ? 190 : 278,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: classic
                    ? (dark ? const Color(0xFF211811) : const Color(0xFFFFFCF4))
                    : (dark
                        ? const Color(0xFF0B1220)
                        : const Color(0xFFF7FBFD)),
              ),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _BluetoothHeroPainter(
                    primary: scheme.primary,
                    secondary: scheme.secondary,
                    dark: dark,
                    scanning: scanning,
                    lowCost: lowCost,
                  ),
                ),
              ),
            ),
            Positioned(
              top: lowCost ? 18 : 28,
              left: 0,
              right: 0,
              child: Center(
                child: ChessnutBoardScanLoader(
                  active: scanning,
                  size: lowCost ? 78 : 96,
                  label: scanning ? 'Scanning nearby' : 'Ready to retry',
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: lowCost ? 10 : 16,
              child: Text(
                scanning
                    ? 'Looking for boards with an active Bluetooth signal.'
                    : 'If the first scan misses the board, check pairing mode and retry.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BluetoothHeroPainter extends CustomPainter {
  const _BluetoothHeroPainter({
    required this.primary,
    required this.secondary,
    required this.dark,
    required this.scanning,
    this.lowCost = false,
  });

  final Color primary;
  final Color secondary;
  final bool dark;
  final bool scanning;
  final bool lowCost;

  @override
  void paint(Canvas canvas, Size size) {
    final classic = primary == ChessnutTheme.classicGreen ||
        primary == ChessnutTheme.classicGold;
    final board = Rect.fromCenter(
      center: Offset(size.width * 0.50, size.height * 0.43),
      width: size.shortestSide * 0.66,
      height: size.shortestSide * 0.38,
    );
    if (!lowCost) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            board.translate(0, 12), const Radius.circular(22)),
        Paint()
          ..color = Colors.black.withValues(alpha: dark ? 0.32 : 0.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(board, const Radius.circular(22)),
      Paint()
        ..color = classic
            ? (dark ? const Color(0xFF2A2117) : const Color(0xFFFFF8EA))
            : (dark ? const Color(0xFF111827) : Colors.white),
    );
    final inset = board.deflate(16);
    final tile = inset.width / 8;
    for (var rank = 0; rank < 4; rank++) {
      for (var file = 0; file < 8; file++) {
        canvas.drawRect(
          Rect.fromLTWH(
            inset.left + file * tile,
            inset.top + rank * tile,
            tile,
            tile,
          ),
          Paint()
            ..color = (rank + file).isEven
                ? (classic
                    ? (dark ? const Color(0xFFBFA46E) : const Color(0xFFF1D9A9))
                    : (dark
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFFF8FAFC)))
                : (classic
                    ? (dark ? const Color(0xFF6E4B2A) : const Color(0xFF9B6B3D))
                    : (dark
                        ? const Color(0xFF334155)
                        : const Color(0xFFD7E1EA))),
        );
      }
    }

    final center = Offset(size.width * 0.50, size.height * 0.38);
    for (var i = 0; i < 3; i++) {
      final radius = 44.0 + i * 26;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = (scanning ? primary : secondary)
              .withValues(alpha: (0.12 - i * 0.03).clamp(0.02, 0.12))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.drawCircle(
      center,
      34,
      Paint()..color = dark ? const Color(0xE6020617) : const Color(0xEFFFFFFF),
    );

    const markSize = 13.0;
    final markPaint = Paint()
      ..color = scanning ? primary : secondary
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(center.dx, center.dy - markSize * 1.4)
      ..lineTo(center.dx, center.dy + markSize * 1.4)
      ..lineTo(center.dx + markSize, center.dy + markSize * 0.7)
      ..lineTo(center.dx - markSize, center.dy)
      ..lineTo(center.dx + markSize, center.dy - markSize * 0.7)
      ..close();
    canvas.drawPath(path, markPaint);
  }

  @override
  bool shouldRepaint(covariant _BluetoothHeroPainter oldDelegate) {
    return primary != oldDelegate.primary ||
        secondary != oldDelegate.secondary ||
        dark != oldDelegate.dark ||
        scanning != oldDelegate.scanning ||
        lowCost != oldDelegate.lowCost;
  }
}

class _ConnectionHelpPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 13,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Before retrying',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          const _GuidanceRow(
            icon: Icons.bluetooth_rounded,
            title: 'Do not pair in system settings',
            body:
                'Connect from Chessnut. If the board was paired in system Bluetooth before, unpair it and try again.',
          ),
          const _GuidanceRow(
            icon: Icons.sensors_rounded,
            title: 'Check pairing mode',
            body:
                'The board is ready when its Bluetooth light is blinking. A solid light usually means it is already connected.',
          ),
          const _GuidanceRow(
            icon: Icons.social_distance_rounded,
            title: 'Stay close',
            body:
                'Keep your phone or tablet close to the board and avoid connecting the same board from another device.',
          ),
        ],
      ),
    );
  }
}

class _PermissionPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 13,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('App permissions',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          const _PermissionLine(
            icon: Icons.bluetooth_audio_rounded,
            title: 'Bluetooth',
            body: 'Required to scan and connect to the board.',
          ),
          const _PermissionLine(
            icon: Icons.radar_rounded,
            title: 'Nearby devices',
            body: 'Required on Android 12 and newer.',
          ),
          const _PermissionLine(
            icon: Icons.location_on_rounded,
            title: 'Location on older Android',
            body:
                'Android 11 and below may ask for location during BLE scan. Chessnut does not use it for positioning.',
          ),
        ],
      ),
    );
  }
}

class _PermissionLine extends StatelessWidget {
  const _PermissionLine({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(body, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidanceRow extends StatelessWidget {
  const _GuidanceRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(body, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardDeviceTile extends StatelessWidget {
  const _BoardDeviceTile({
    required this.state,
    required this.boardModel,
  });

  final PhysicalBoardConnectionState state;
  final PhysicalBoardModel boardModel;

  @override
  Widget build(BuildContext context) {
    final scanning = state == PhysicalBoardConnectionState.scanning ||
        state == PhysicalBoardConnectionState.connecting;
    final connected = state == PhysicalBoardConnectionState.connected;
    final scheme = Theme.of(context).colorScheme;
    final compactLandscape = isCompactLandscapeDevice(context);
    return AnimatedContainer(
      duration:
          compactLandscape ? Duration.zero : const Duration(milliseconds: 220),
      padding: EdgeInsets.all(compactLandscape ? 9 : 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: scheme.secondary.withValues(alpha: scanning ? 0.13 : 0.08),
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: compactLandscape ? 34 : 42,
            height: compactLandscape ? 34 : 42,
            decoration: BoxDecoration(
              color: scheme.secondary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              scanning
                  ? Icons.bluetooth_searching_rounded
                  : connected
                      ? Icons.bluetooth_connected_rounded
                      : Icons.memory_rounded,
              color: scheme.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scanning
                      ? 'Searching for Chessnut'
                      : connected
                          ? _boardModelName(boardModel)
                          : 'Ready to scan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  scanning
                      ? 'Keep the board close and blinking'
                      : connected
                          ? 'Realtime FEN is being enabled'
                          : 'Tap Connect to scan nearby boards',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (scanning)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: scheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

String _messageForState(PhysicalBoardConnectionState state) {
  return switch (state) {
    PhysicalBoardConnectionState.scanning =>
      'Scanning for nearby Chessnut boards. Keep the board close and make sure the Bluetooth light is blinking.',
    PhysicalBoardConnectionState.connecting =>
      'Board found. Connecting and subscribing to realtime FEN.',
    PhysicalBoardConnectionState.connected =>
      'Connected. Realtime FEN will be enabled before entering the home screen.',
    PhysicalBoardConnectionState.disconnected =>
      'Ready to scan nearby Chessnut boards.',
  };
}

String _boardModelName(PhysicalBoardModel model) {
  return switch (model) {
    PhysicalBoardModel.air => 'Chessnut Air',
    PhysicalBoardModel.airPlus => 'Chessnut Air Plus',
    PhysicalBoardModel.pro => 'Chessnut Pro',
    PhysicalBoardModel.go => 'Chessnut Go',
    PhysicalBoardModel.evo => 'Chessnut Evo',
    PhysicalBoardModel.evo2 => 'Chessnut EVO2',
    PhysicalBoardModel.move => 'Chessnut Move',
    PhysicalBoardModel.pi => 'Chessnut Pi',
    PhysicalBoardModel.general => 'Chessnut board',
    PhysicalBoardModel.unknown => 'Chessnut board',
  };
}
