import 'dart:async';

import '../l10n/localized_material.dart';

import '../models/app_models.dart';
import '../services/physical_board_gateway.dart';
import '../services/physical_board_protocol.dart';
import '../services/universal_ble_board_transport.dart';
import '../widgets/app_chrome.dart';

class BoardDiagnosticsScreen extends StatefulWidget {
  const BoardDiagnosticsScreen({
    required this.onNavigate,
    this.gateway,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final ChessnutBoardGateway? gateway;

  @override
  State<BoardDiagnosticsScreen> createState() => _BoardDiagnosticsScreenState();
}

class _BoardDiagnosticsScreenState extends State<BoardDiagnosticsScreen> {
  late final ChessnutBoardGateway gateway;
  late final bool ownsGateway;
  final fenController = TextEditingController(text: chessnutStandardStartFen);
  final log = <String>[];
  PhysicalBoardConnectionState state =
      PhysicalBoardConnectionState.disconnected;
  String latestFen = 'Waiting for board FEN';
  String generalBattery = 'Not queried';
  String generalVersion = 'Not queried';
  String generalFileCount = 'Not queried';
  String moveBattery = 'Not queried';
  String movePieces = 'Not queried';
  final subscriptions = <StreamSubscription>[];

  @override
  void initState() {
    super.initState();
    ownsGateway = widget.gateway == null;
    gateway = widget.gateway ??
        ChessnutBoardGateway(
          transport: UniversalBleBoardTransport(),
        );
    subscriptions.addAll([
      gateway.stateStream.listen((value) {
        setState(() {
          state = value;
          _addLog('State: ${value.name}');
        });
      }),
      gateway.boardFenStream.listen((fen) {
        setState(() {
          latestFen = fen;
          _addLog('FEN: $fen');
        });
      }),
      gateway.generalBatteryStatusStream.listen((battery) {
        setState(() {
          generalBattery =
              '${battery.level}%${battery.isCharging ? ' / charging' : ''}';
          _addLog('General battery: $generalBattery');
        });
      }),
      gateway.generalVersionStream.listen((version) {
        setState(() {
          generalVersion = version;
          _addLog('Version: $version');
        });
      }),
      gateway.generalFileCountStream.listen((count) {
        setState(() {
          generalFileCount = '$count files';
          _addLog('OTG file count: $count');
        });
      }),
      gateway.moveBatteryStatusStream.listen((battery) {
        setState(() {
          moveBattery =
              '${battery.level}%${battery.isCharging ? ' / charging' : ''}';
          _addLog('Move battery: $moveBattery');
        });
      }),
      gateway.movePieceStatusStream.listen((pieces) {
        setState(() {
          movePieces =
              '${pieces.where((piece) => piece.isOnBoard).length}/${pieces.length} pieces on board';
          _addLog('Move pieces: $movePieces');
        });
      }),
    ]);
  }

  @override
  void dispose() {
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
    fenController.dispose();
    if (ownsGateway) {
      gateway.dispose();
    }
    super.dispose();
  }

  Future<void> _connect() async {
    _addLog('Connect requested');
    final ok = await gateway.connect();
    if (!mounted) return;
    setState(() {
      _addLog(ok ? 'Connect success' : 'Connect failed');
    });
  }

  Future<void> _disconnect() async {
    await gateway.disconnect();
    if (!mounted) return;
    setState(() => _addLog('Disconnect requested'));
  }

  Future<void> _send(String label, Future<bool> Function() action) async {
    final ok = await action();
    if (!mounted) return;
    setState(() => _addLog('$label: ${ok ? 'sent' : 'failed'}'));
  }

  void _addLog(String message) {
    log.insert(
        0, '${DateTime.now().toIso8601String().substring(11, 19)} $message');
    if (log.length > 20) {
      log.removeRange(20, log.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      children: (context, spec) => [
        ScreenHeader(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => widget.onNavigate('Back'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: 'Board diagnostics',
          subtitle: 'Real hardware test',
          trailing: _StatePill(state: state),
        ),
        SizedBox(height: spec.gutter),
        ResponsiveSplit(
          breakpoint: 900,
          spacing: spec.gutter,
          leadingFlex: 6,
          trailingFlex: 5,
          leading: SectionColumn(
            spacing: 10,
            children: [
              GlassPanel(
                borderRadius: 13,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Connection',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    _InfoLine(
                      label: 'Detected model',
                      value: gateway.boardModel.name,
                    ),
                    _InfoLine(label: 'Latest FEN', value: latestFen),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _connect,
                            icon: const Icon(Icons.bluetooth_searching_rounded),
                            label: const Text('Connect'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _disconnect,
                            icon: const Icon(Icons.bluetooth_disabled_rounded),
                            label: const Text('Disconnect'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GlassPanel(
                borderRadius: 13,
                padding: const EdgeInsets.all(12),
                child: _CommandGroup(
                  title: 'Air / Pro / Go commands',
                  children: [
                    _CommandButton(
                      label: 'Realtime FEN',
                      icon: Icons.sensors_rounded,
                      onTap: () => _send(
                        'General realtime',
                        gateway.enableRealtimeFen,
                      ),
                    ),
                    _CommandButton(
                      label: 'Battery',
                      icon: Icons.battery_5_bar_rounded,
                      onTap: () => _send(
                        'General battery',
                        gateway.queryGeneralBatteryStatus,
                      ),
                    ),
                    _CommandButton(
                      label: 'BLE version',
                      icon: Icons.info_outline_rounded,
                      onTap: () => _send(
                        'BLE version',
                        gateway.queryGeneralBleVersion,
                      ),
                    ),
                    _CommandButton(
                      label: 'OTG files',
                      icon: Icons.folder_copy_rounded,
                      onTap: () => _send(
                        'OTG file count',
                        gateway.queryGeneralFileCount,
                      ),
                    ),
                    _CommandButton(
                      label: 'LED e4',
                      icon: Icons.light_mode_rounded,
                      onTap: () => _send(
                        'General LED e4',
                        () => gateway.setGeneralLedSquares({'e4'}),
                      ),
                    ),
                    _CommandButton(
                      label: 'Clear LEDs',
                      icon: Icons.lightbulb_outline_rounded,
                      onTap: () => _send(
                        'General LED off',
                        gateway.clearGeneralLeds,
                      ),
                    ),
                  ],
                ),
              ),
              GlassPanel(
                borderRadius: 13,
                padding: const EdgeInsets.all(12),
                child: _CommandGroup(
                  title: 'Move commands',
                  children: [
                    _CommandButton(
                      label: 'Move battery',
                      icon: Icons.battery_charging_full_rounded,
                      onTap: () => _send(
                        'Move battery',
                        () => gateway.write(ChessnutMoveCommands.batteryStatus),
                      ),
                    ),
                    _CommandButton(
                      label: 'Move piece status',
                      icon: Icons.grid_view_rounded,
                      onTap: () => _send(
                        'Move piece status',
                        () => gateway.write(ChessnutMoveCommands.pieceStatus),
                      ),
                    ),
                    _CommandButton(
                      label: 'Move RGB e4',
                      icon: Icons.palette_rounded,
                      onTap: () => _send(
                        'Move RGB e4',
                        () => gateway.setMoveLedSquares({
                          'e4': ChessnutMoveLedColor.green,
                        }),
                      ),
                    ),
                    _CommandButton(
                      label: 'Clear RGB',
                      icon: Icons.invert_colors_off_rounded,
                      onTap: () => _send('Move RGB off', gateway.clearMoveLeds),
                    ),
                  ],
                ),
              ),
            ],
          ),
          trailing: SectionColumn(
            spacing: 10,
            children: [
              GlassPanel(
                borderRadius: 13,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Live values',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    _InfoLine(label: 'General battery', value: generalBattery),
                    _InfoLine(label: 'General version', value: generalVersion),
                    _InfoLine(label: 'OTG count', value: generalFileCount),
                    _InfoLine(label: 'Move battery', value: moveBattery),
                    _InfoLine(label: 'Move pieces', value: movePieces),
                  ],
                ),
              ),
              GlassPanel(
                borderRadius: 13,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FEN to board',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    TextField(
                      controller: fenController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Target FEN',
                      ),
                    ),
                    const SizedBox(height: 10),
                    PrimaryButton(
                      key: const ValueKey('diagnostics-send-fen'),
                      label: 'Send FEN',
                      icon: Icons.upload_rounded,
                      onPressed: () => _send(
                        'Move FEN to board',
                        () => gateway.setMoveBoardFen(fenController.text),
                      ),
                    ),
                  ],
                ),
              ),
              GlassPanel(
                borderRadius: 13,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Log', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final line in log)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    if (log.isEmpty)
                      Text(
                        'No hardware events yet.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.state});

  final PhysicalBoardConnectionState state;

  @override
  Widget build(BuildContext context) {
    final connected = state == PhysicalBoardConnectionState.connected;
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderRadius: 999,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            connected
                ? Icons.bluetooth_connected_rounded
                : Icons.bluetooth_rounded,
            size: 16,
            color: connected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 6),
          Text(
            state.name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandGroup extends StatelessWidget {
  const _CommandGroup({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: children,
        ),
      ],
    );
  }
}

class _CommandButton extends StatelessWidget {
  const _CommandButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
