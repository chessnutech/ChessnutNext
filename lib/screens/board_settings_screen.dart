import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' as material;
import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import '../l10n/localized_material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/app_models.dart';
import '../services/board_storage_import_service.dart';
import '../services/board_settings_service.dart';
import '../services/chessnut_api_client.dart';
import '../services/physical_board_gateway.dart';
import '../services/physical_board_protocol.dart';
import '../services/screen_wake_lock_service.dart';
import '../theme/chessnut_theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/board_connection_badge.dart';

class BoardSettingsScreen extends StatefulWidget {
  const BoardSettingsScreen({
    required this.onNavigate,
    required this.boardModel,
    required this.boardConnected,
    required this.settings,
    required this.onSettingsChanged,
    this.boardGateway,
    this.onPreviewStoredBoardGames,
    this.onImportStoredBoardGames,
    this.batteryStatus,
    this.apiClient,
    this.screenWakeLockService = const SystemScreenWakeLockService(),
    this.isChessnutClockDevice = false,
    this.hidePhysicalBoardConnectionUi = false,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final ChessnutBoardModel boardModel;
  final bool boardConnected;
  final BoardSettingsState settings;
  final ValueChanged<BoardSettingsState> onSettingsChanged;
  final PhysicalBoardGateway? boardGateway;
  final Future<BoardStorageImportPreview> Function(
      List<String> rawFenSequences)? onPreviewStoredBoardGames;
  final Future<BoardStorageImportResult> Function({
    required bool deleteAfterImport,
  })? onImportStoredBoardGames;
  final BoardBatteryStatus? batteryStatus;
  final ChessnutApiClient? apiClient;
  final ScreenWakeLockService screenWakeLockService;
  final bool isChessnutClockDevice;
  final bool hidePhysicalBoardConnectionUi;

  @override
  State<BoardSettingsScreen> createState() => _BoardSettingsScreenState();
}

class _BoardSettingsScreenState extends State<BoardSettingsScreen> {
  late BoardSettingsState settings = widget.settings;
  StreamSubscription<BoardFirmwareVersions>? _firmwareVersionSub;
  Timer? _firmwareQueryTimer;
  BoardFirmwareVersions? _firmwareVersions;
  bool _firmwareQuerying = false;

  bool get _isMoveBoard => widget.boardModel == ChessnutBoardModel.move;
  bool get _isEvo2BoardSettings => widget.hidePhysicalBoardConnectionUi;

  String get _firmwareSubtitle {
    final lines = _firmwareSummaryLines();
    if (lines.isNotEmpty) return lines.join('\n');
    if (_firmwareQuerying) return 'Reading version';
    return 'Version unavailable';
  }

  @override
  void initState() {
    super.initState();
    settings = _normalizeClockSwitchSettings(settings);
    _bindFirmwareVersionStream(resetVersion: false);
    _queryBoardBatteryStatus();
  }

  @override
  void didUpdateWidget(covariant BoardSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      settings = _normalizeClockSwitchSettings(widget.settings);
    }
    if (!identical(oldWidget.boardGateway, widget.boardGateway) ||
        oldWidget.boardConnected != widget.boardConnected ||
        oldWidget.boardModel != widget.boardModel) {
      _bindFirmwareVersionStream(resetVersion: true);
      _queryBoardBatteryStatus();
    }
  }

  @override
  void dispose() {
    _firmwareQueryTimer?.cancel();
    unawaited(_firmwareVersionSub?.cancel());
    super.dispose();
  }

  void _queryBoardBatteryStatus() {
    final gateway = widget.boardGateway;
    if (!widget.boardConnected || gateway == null) return;
    unawaited(gateway.queryBoardBatteryStatus());
  }

  void _bindFirmwareVersionStream({required bool resetVersion}) {
    unawaited(_firmwareVersionSub?.cancel());
    _firmwareVersionSub = null;
    _firmwareQueryTimer?.cancel();
    _firmwareQueryTimer = null;
    if (resetVersion) {
      _firmwareVersions = null;
      _firmwareQuerying = false;
    }
    final gateway = widget.boardGateway;
    if (!widget.boardConnected || gateway == null) return;
    _firmwareVersionSub =
        gateway.boardFirmwareVersionsStream.listen((versions) {
      if (!versions.hasAnyVersion || !mounted) return;
      _firmwareQueryTimer?.cancel();
      _firmwareQueryTimer = null;
      setState(() {
        _firmwareVersions = versions;
        _firmwareQuerying = false;
      });
    });
    _queryFirmwareVersion(notify: false);
  }

  void _queryFirmwareVersion({required bool notify}) {
    final gateway = widget.boardGateway;
    if (!widget.boardConnected ||
        gateway == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      return;
    }
    if (notify && mounted) {
      setState(() => _firmwareQuerying = true);
    } else {
      _firmwareQuerying = true;
    }
    unawaited(() async {
      final sent = await gateway.queryBoardFirmwareVersion();
      if (!mounted) return;
      if (!sent) {
        _firmwareQueryTimer?.cancel();
        _firmwareQueryTimer = null;
        setState(() => _firmwareQuerying = false);
        return;
      }
      _firmwareQueryTimer?.cancel();
      _firmwareQueryTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted || !_firmwareQuerying) return;
        _firmwareQueryTimer = null;
        setState(() => _firmwareQuerying = false);
      });
    }());
  }

  void _update(BoardSettingsState next) {
    final normalized = _normalizeClockSwitchSettings(next);
    setState(() => settings = normalized);
    widget.onSettingsChanged(normalized);
  }

  Future<void> _editEvo2LedPattern(String patternKey) async {
    final nextPattern = await showDialog<Evo2LedPattern>(
      context: context,
      builder: (dialogContext) => _Evo2LedPatternDialog(
        patternKey: patternKey,
        initialPattern: settings.evo2LedPatterns.patternFor(patternKey),
      ),
    );
    if (nextPattern == null || !mounted) return;
    _update(
      settings.copyWith(
        evo2LedPatterns:
            settings.evo2LedPatterns.copyWithPattern(patternKey, nextPattern),
      ),
    );
  }

  Future<void> _confirmResetEvo2LedPatterns() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => AppDialogShell(
        icon: Icons.restart_alt_rounded,
        title: 'Reset EVO2 patterns?',
        subtitle:
            'Restore all EVO2 piece, empty-square, and analysis marker LED patterns to the defaults.',
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reset'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _update(
      settings.copyWith(evo2LedPatterns: Evo2LedPatternSet.defaults),
    );
  }

  BoardSettingsState _normalizeClockSwitchSettings(BoardSettingsState value) {
    if (value.submitMoveOnClockSwitch &&
        value.clockSwitchAutomation == ClockSwitchAutomationMode.bothSides) {
      return value.copyWith(
        clockSwitchAutomation: ClockSwitchAutomationMode.opponentMoveOnly,
      );
    }
    return value;
  }

  void _updateGlobalBeep(bool value) {
    _update(settings.copyWith(globalBeep: value));
    final gateway = widget.boardGateway;
    if (gateway != null &&
        gateway.currentState == PhysicalBoardConnectionState.connected) {
      unawaited(gateway.setBoardBeepEnabled(value));
    }
  }

  Future<void> _showStoredGamesDialog() async {
    final gateway = widget.boardGateway;
    final importer = widget.onImportStoredBoardGames;
    if (!widget.boardConnected ||
        gateway == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      _showStoredGamesMessage(
        title: 'Import saved board games',
        message: 'Connect a Chessnut board before importing saved games.',
      );
      return;
    }
    if (!gateway.supportsStoredGameImport || importer == null) {
      _showStoredGamesMessage(
        title: 'Import saved board games',
        message: 'Connect a board that supports saved game import.',
      );
      return;
    }

    final result = await showDialog<BoardStorageImportResult>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => _StoredGameImportDialog(
        gateway: gateway,
        importer: importer,
      ),
    );
    if (!mounted || result == null) return;
    _showStoredGamesResult(result);
  }

  void _showStoredGamesMessage({
    required String title,
    required String message,
  }) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => AppDialogShell(
        icon: Icons.inventory_2_rounded,
        title: title,
        subtitle: message,
        actions: [
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  void _showStoredGamesResult(BoardStorageImportResult result) {
    final hasErrors = result.errors.isNotEmpty || result.failedCount > 0;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => AppDialogShell(
        icon: hasErrors
            ? Icons.warning_amber_rounded
            : Icons.check_circle_rounded,
        title: 'Board games imported',
        subtitle:
            '${result.importedCount} game${result.importedCount == 1 ? '' : 's'} imported. ${result.skippedCount} skipped, ${result.failedCount} failed.',
        actions: [
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ),
        ],
        child: result.errors.isEmpty
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final error in result.errors.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              error,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hidePhysicalBoardConnectionUi = widget.hidePhysicalBoardConnectionUi;
    final Widget? boardHero = hidePhysicalBoardConnectionUi
        ? null
        : _BoardSettingsHero(
            key: const ValueKey('board-settings-hero'),
            boardModel: widget.boardModel,
            boardConnected: widget.boardConnected,
            batteryStatus: widget.boardConnected ? widget.batteryStatus : null,
          );
    final isEvo2BoardSettings = _isEvo2BoardSettings;
    final Widget? buzzerSection = _isMoveBoard || isEvo2BoardSettings
        ? null
        : _SettingsSection(
            title: 'Buzzer',
            status: settings.globalBeep ? 'Enabled' : 'Muted',
            children: [
              _MasterSwitchTile(
                label: 'Buzzer master switch',
                subtitle: 'Turns all board beeps on or off.',
                icon: Icons.volume_up_rounded,
                value: settings.globalBeep,
                onChanged: _updateGlobalBeep,
              ),
              _SettingsSubheader(
                title: 'Event sounds',
                detail: settings.globalBeep
                    ? 'Choose which moments can beep.'
                    : 'Muted until the master switch is on.',
              ),
              _SwitchGrid(
                adaptToTextScale: widget.isChessnutClockDevice,
                items: [
                  _SwitchItem(
                    label: 'Connect beep',
                    icon: Icons.bluetooth_connected_rounded,
                    value: settings.connectBeep,
                    enabled: settings.globalBeep,
                    onChanged: (value) =>
                        _update(settings.copyWith(connectBeep: value)),
                  ),
                  _SwitchItem(
                    label: 'Checkmate beep',
                    icon: Icons.emoji_events_rounded,
                    value: settings.checkmateBeep,
                    enabled: settings.globalBeep,
                    onChanged: (value) =>
                        _update(settings.copyWith(checkmateBeep: value)),
                  ),
                ],
              ),
            ],
          );
    final boardLightsSection = _SettingsSection(
      sectionKey: const ValueKey('board-settings-lights-section'),
      title: 'Board lights',
      status: 'LED',
      children: [
        _SwitchList(
          items: [
            _SwitchItem(
              label: 'Piece position LEDs',
              icon: Icons.lightbulb_outline_rounded,
              value: settings.piecePositionLed,
              onChanged: (value) =>
                  _update(settings.copyWith(piecePositionLed: value)),
            ),
          ],
        ),
        if (isEvo2BoardSettings)
          _SettingsSlider(
            key: const ValueKey('evo2-led-brightness-slider'),
            label: 'LED brightness',
            value: settings.evo2LedBrightness.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            valueFormatter: (value) => '${value.round()}%',
            onChanged: (value) {
              setState(() {
                settings = settings.copyWith(
                  evo2LedBrightness: value.round(),
                );
              });
            },
            onChangeEnd: (value) => _update(
              settings.copyWith(evo2LedBrightness: value.round()),
            ),
          ),
        if (isEvo2BoardSettings)
          _Evo2LedPatternSettings(
            patterns: settings.evo2LedPatterns,
            onEditPattern: _editEvo2LedPattern,
            onResetPatterns: _confirmResetEvo2LedPatterns,
          ),
      ],
    );
    final moveLogicSection = _SettingsSection(
      sectionKey: const ValueKey('board-settings-move-logic-section'),
      title: 'Move logic',
      status: '${settings.fenDelayMs}ms',
      children: [
        _SettingsSlider(
          label: 'Move delay',
          value: settings.fenDelayMs.toDouble(),
          min: 0,
          max: 3000,
          divisions: 60,
          onChanged: (value) => _update(
            settings.copyWith(fenDelayMs: value.round()),
          ),
        ),
        if (_isMoveBoard && !hidePhysicalBoardConnectionUi)
          _SettingsSlider(
            label: 'Move restore',
            value: settings.moveRestoreDelayMs.toDouble(),
            min: 250,
            max: 5000,
            divisions: 19,
            onChanged: (value) => _update(
              settings.copyWith(moveRestoreDelayMs: value.round()),
            ),
          ),
        if (_isMoveBoard && widget.boardConnected)
          _VoiceMoveSettings(
            settings: settings,
            onChanged: _update,
          ),
        _SwitchGrid(
          adaptToTextScale: widget.isChessnutClockDevice,
          items: [
            _SwitchItem(
              label: 'Allow flip board',
              subtitle: 'Allow normal and reversed board orientations.',
              icon: Icons.swap_vert_rounded,
              value: settings.allowFlip,
              onChanged: (value) => _update(
                settings.copyWith(allowFlip: value),
              ),
            ),
            _SwitchItem(
              label: 'Auto flip board',
              subtitle:
                  'Detect physical board orientation from the current FEN.',
              icon: Icons.screen_rotation_alt_rounded,
              value: settings.autoFlip,
              enabled: settings.allowFlip,
              disabledReason: 'Enable Allow flip board first.',
              onChanged: (value) => _update(
                settings.copyWith(autoFlip: value),
              ),
            ),
          ],
        ),
      ],
    );
    final Widget? clockSwitchSection = widget.isChessnutClockDevice
        ? _SettingsSection(
            sectionKey: const ValueKey('board-settings-clock-switch-section'),
            title: 'Clock Switch',
            status: _clockSwitchStatusLabel(
              settings.clockSwitchAutomation,
              settings.clockSwitchOpponentTiming,
            ),
            children: [
              const _SettingsSubheader(
                title: 'Automatic switch press',
                detail:
                    'Choose when the clock hardware switch is pressed for you.',
              ),
              _ClockSwitchAutomationPills(
                selected: settings.clockSwitchAutomation,
                confirmMovesWithSwitch: settings.submitMoveOnClockSwitch,
                onSelected: (value) => _update(
                  settings.copyWith(clockSwitchAutomation: value),
                ),
              ),
              if (settings.clockSwitchAutomation !=
                  ClockSwitchAutomationMode.off) ...[
                const SizedBox(height: 12),
                const _SettingsSubheader(
                  title: 'Opponent move mode',
                  detail: 'Controls AI and online opponent clock presses.',
                ),
                _ClockSwitchOpponentTimingPills(
                  selected: settings.clockSwitchOpponentTiming,
                  onSelected: (value) => _update(
                    settings.copyWith(clockSwitchOpponentTiming: value),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              _SwitchList(
                items: [
                  _SwitchItem(
                    label: 'Confirm moves with switch',
                    subtitle:
                        'Hold board moves until the clock switch is pressed.',
                    icon: Icons.touch_app_rounded,
                    value: settings.submitMoveOnClockSwitch,
                    onChanged: (value) => _update(
                      settings.copyWith(
                        submitMoveOnClockSwitch: value,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          )
        : null;
    final boardActions = _BoardSettingsActions(
      key: const ValueKey('board-settings-actions-section'),
      onNavigate: widget.onNavigate,
      onFirmwareTap: () => _showFirmwareDialog(context),
      onStoredGamesTap: _showStoredGamesDialog,
      boardModel: widget.boardModel,
      boardConnected: widget.boardConnected,
      firmwareSubtitle: _firmwareSubtitle,
      showStoredGames: !isEvo2BoardSettings,
    );
    final Widget? disconnectButton =
        widget.boardConnected && !hidePhysicalBoardConnectionUi
            ? _DisconnectBoardButton(
                onPressed: () => widget.onNavigate('DisconnectBoard'),
              )
            : null;
    final useMoveConnectedSplit = _isMoveBoard &&
        widget.boardConnected &&
        !hidePhysicalBoardConnectionUi &&
        boardHero != null;
    final leadingSections = useMoveConnectedSplit
        ? <Widget>[
            moveLogicSection,
            if (clockSwitchSection != null) boardLightsSection,
          ]
        : <Widget>[
            if (boardHero != null) boardHero,
            moveLogicSection,
            if (clockSwitchSection != null) clockSwitchSection,
          ];
    final trailingSections = useMoveConnectedSplit
        ? <Widget>[
            if (clockSwitchSection != null) clockSwitchSection,
            if (clockSwitchSection == null) boardLightsSection,
            boardActions,
            if (disconnectButton != null) disconnectButton,
          ]
        : <Widget>[
            if (buzzerSection != null) buzzerSection,
            boardLightsSection,
            boardActions,
            if (disconnectButton != null) disconnectButton,
          ];
    final leadingFlex = useMoveConnectedSplit ? 1 : 6;
    final trailingFlex = useMoveConnectedSplit ? 1 : 5;

    return ResponsivePage(
      children: (context, spec) => [
        ScreenHeader(
          title: 'Board settings',
          subtitle: 'Board',
          leading: IconButton.filledTonal(
            onPressed: () => widget.onNavigate('Back'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        SizedBox(height: spec.gutter),
        if (useMoveConnectedSplit) ...[
          boardHero,
          const SizedBox(height: 12),
        ],
        ResponsiveSplit(
          breakpoint: 900,
          spacing: spec.gutter,
          leadingFlex: leadingFlex,
          trailingFlex: trailingFlex,
          leading: SectionColumn(
            spacing: 12,
            children: leadingSections,
          ),
          trailing: SectionColumn(
            spacing: 12,
            children: trailingSections,
          ),
        ),
      ],
    );
  }

  void _showFirmwareDialog(BuildContext context) {
    final lines = _firmwareDetailLines();
    final gateway = widget.boardGateway;
    final apiClient = widget.apiClient;
    if (_isMoveBoard &&
        widget.boardConnected &&
        gateway != null &&
        apiClient != null) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.62),
        builder: (_) => _MoveFirmwareUpdateDialog(
          gateway: gateway,
          apiClient: apiClient,
          currentVersion: _firmwareVersions?.moveVersion,
          screenWakeLockService: widget.screenWakeLockService,
          onVersionRefresh: () => _queryFirmwareVersion(notify: false),
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => AppDialogShell(
        icon: Icons.system_update_alt_rounded,
        title: 'Firmware update',
        subtitle: lines.isEmpty
            ? 'Firmware version is not available from the connected board right now.'
            : '${lines.join('\n')}\nNo firmware update is available from the connected board service right now.',
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                _queryFirmwareVersion(notify: true);
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Refresh'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _firmwareSummaryLines() {
    final versions = _firmwareVersions;
    if (versions == null || !versions.hasAnyVersion) return const [];
    final lines = <String>[];
    final moveVersion = versions.moveVersion?.trim();
    final bluetoothVersion = versions.bluetoothVersion?.trim();
    final mcuVersion = versions.mcuVersion?.trim();
    if (_isMoveBoard && moveVersion != null && moveVersion.isNotEmpty) {
      lines.add('Move $moveVersion');
    }
    if (bluetoothVersion != null && bluetoothVersion.isNotEmpty) {
      lines.add('BLE $bluetoothVersion');
    }
    if (mcuVersion != null && mcuVersion.isNotEmpty) {
      lines.add('MCU $mcuVersion');
    }
    if (lines.isEmpty) {
      final primary = versions.primaryVersion;
      if (primary != null) lines.add('Version $primary');
    }
    return lines;
  }

  List<String> _firmwareDetailLines() {
    final versions = _firmwareVersions;
    if (versions == null || !versions.hasAnyVersion) return const [];
    final lines = <String>[];
    final moveVersion = versions.moveVersion?.trim();
    final bluetoothVersion = versions.bluetoothVersion?.trim();
    final mcuVersion = versions.mcuVersion?.trim();
    if (_isMoveBoard && moveVersion != null && moveVersion.isNotEmpty) {
      lines.add('Move firmware: $moveVersion');
    }
    if (bluetoothVersion != null && bluetoothVersion.isNotEmpty) {
      lines.add('Bluetooth firmware: $bluetoothVersion');
    }
    if (mcuVersion != null && mcuVersion.isNotEmpty) {
      lines.add('MCU firmware: $mcuVersion');
    }
    return lines;
  }
}

class _MoveFirmwareUpdateDialog extends StatefulWidget {
  const _MoveFirmwareUpdateDialog({
    required this.gateway,
    required this.apiClient,
    required this.currentVersion,
    required this.screenWakeLockService,
    required this.onVersionRefresh,
  });

  final PhysicalBoardGateway gateway;
  final ChessnutApiClient apiClient;
  final String? currentVersion;
  final ScreenWakeLockService screenWakeLockService;
  final VoidCallback onVersionRefresh;

  @override
  State<_MoveFirmwareUpdateDialog> createState() =>
      _MoveFirmwareUpdateDialogState();
}

class _MoveFirmwareUpdateDialogState extends State<_MoveFirmwareUpdateDialog> {
  MoveFirmwareRelease? _release;
  bool _loading = true;
  bool _bluetoothSupported = false;
  bool _busy = false;
  bool? _succeeded;
  double? _progress;
  String _status = 'Checking for firmware updates…';

  bool get _hasUpdate {
    final current = widget.currentVersion?.trim();
    final latest = _release?.version.trim();
    return latest != null && latest.isNotEmpty && current != latest;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadUpdate());
  }

  @override
  void dispose() {
    if (_busy) {
      unawaited(widget.screenWakeLockService.setEnabled(false));
    }
    super.dispose();
  }

  Future<void> _loadUpdate() async {
    if (!_loading && mounted) {
      setState(() {
        _loading = true;
        _status = 'Checking for firmware updates…';
      });
    }
    final release = await widget.apiClient.moveFirmwareRelease();
    final supported = await widget.gateway.checkMoveFirmwareUpdateSupport();
    if (!mounted) return;
    setState(() {
      _release = release;
      _bluetoothSupported = supported;
      _loading = false;
      _status = release == null
          ? 'Could not retrieve the latest Move firmware.'
          : _hasUpdate
              ? 'Choose how to install the update.'
              : 'Your Chessnut Move firmware is up to date.';
    });
  }

  Future<void> _startWifiUpdate() async {
    final credentials = await _requestWifiCredentials();
    if (credentials == null || !mounted) return;
    await _runUpdate(() async {
      setState(() => _status = 'Connecting Chessnut Move to Wi-Fi…');
      final connected = await widget.gateway.configureMoveFirmwareWifi(
        ssid: credentials.$1,
        password: credentials.$2,
      );
      if (!connected) return false;
      if (mounted) {
        setState(() => _status = 'Downloading and installing firmware…');
      }
      return widget.gateway.startMoveWifiFirmwareUpdate();
    });
  }

  Future<void> _startBluetoothUpdate() async {
    final release = _release;
    if (release == null) return;
    await _runUpdate(() async {
      setState(() => _status = 'Downloading firmware package…');
      final firmware = await widget.apiClient.downloadMoveFirmware(
        release.downloadUri,
      );
      if (firmware == null || firmware.isEmpty) return false;
      if (mounted) {
        setState(() {
          _status = 'Sending firmware to Chessnut Move…';
          _progress = 0;
        });
      }
      return widget.gateway.sendMoveFirmwareUpdateFile(
        firmware,
        onProgress: (transferred, total) {
          if (!mounted || total <= 0) return;
          setState(() => _progress = (transferred / total).clamp(0, 1));
        },
      );
    });
  }

  Future<void> _runUpdate(Future<bool> Function() update) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _succeeded = null;
      _progress = null;
    });
    await widget.screenWakeLockService.setEnabled(true);
    bool succeeded;
    try {
      succeeded = await update();
    } catch (_) {
      succeeded = false;
    } finally {
      await widget.screenWakeLockService.setEnabled(false);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _succeeded = succeeded;
      _progress = succeeded ? 1 : null;
      _status = succeeded
          ? 'Firmware update completed successfully.'
          : 'Firmware update failed. Keep the board connected and try again.';
    });
    if (succeeded) widget.onVersionRefresh();
  }

  Future<(String, String)?> _requestWifiCredentials() async {
    return showDialog<(String, String)>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (_) => const _MoveWifiCredentialsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.currentVersion?.trim();
    final latest = _release?.version.trim();
    final statusIcon = switch (_succeeded) {
      true => Icons.check_circle_rounded,
      false => Icons.error_rounded,
      null =>
        _busy ? Icons.system_update_alt_rounded : Icons.info_outline_rounded,
    };
    final statusColor = switch (_succeeded) {
      true => Colors.green,
      false => Theme.of(context).colorScheme.error,
      null => Theme.of(context).colorScheme.primary,
    };

    return PopScope(
      canPop: !_busy,
      child: AppDialogShell(
        icon: Icons.system_update_alt_rounded,
        title: 'Chessnut Move firmware',
        subtitle: 'Keep the board connected and powered during the update.',
        actions: [
          OutlinedButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (!_loading && _hasUpdate && !_busy)
            FilledButton.tonalIcon(
              key: const ValueKey('move-firmware-wifi-update'),
              onPressed: _startWifiUpdate,
              icon: const Icon(Icons.wifi_rounded),
              label: const Text('Wi-Fi update'),
            ),
          if (!_loading && _hasUpdate && _bluetoothSupported && !_busy)
            FilledButton.icon(
              key: const ValueKey('move-firmware-bluetooth-update'),
              onPressed: _startBluetoothUpdate,
              icon: const Icon(Icons.bluetooth_rounded),
              label: const Text('Bluetooth update'),
            ),
          if (!_loading && _release == null && !_busy)
            FilledButton(
              onPressed: _loadUpdate,
              child: const Text('Retry'),
            ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (current != null && current.isNotEmpty)
              Text('Current version: $current'),
            if (latest != null && latest.isNotEmpty)
              Text('Latest version: $latest'),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_loading)
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(statusIcon, color: statusColor, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(_status)),
              ],
            ),
            if (_progress != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 5),
              Text(
                '${(_progress! * 100).round()}%',
                textAlign: TextAlign.end,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MoveWifiCredentialsDialog extends StatefulWidget {
  const _MoveWifiCredentialsDialog();

  @override
  State<_MoveWifiCredentialsDialog> createState() =>
      _MoveWifiCredentialsDialogState();
}

class _MoveWifiCredentialsDialogState
    extends State<_MoveWifiCredentialsDialog> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final ssid = _ssidController.text.trim();
    if (ssid.isEmpty) return;
    Navigator.of(context).pop((ssid, _passwordController.text));
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      icon: Icons.wifi_rounded,
      title: 'Connect Move to Wi-Fi',
      subtitle:
          'Enter the Wi-Fi network Chessnut Move should use to download its firmware.',
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('move-firmware-wifi-connect'),
          onPressed: _submit,
          child: const Text('Connect and update'),
        ),
      ],
      child: Column(
        children: [
          TextField(
            key: const ValueKey('move-firmware-wifi-ssid'),
            controller: _ssidController,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Wi-Fi name'),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('move-firmware-wifi-password'),
            controller: _passwordController,
            obscureText: true,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'Password'),
          ),
        ],
      ),
    );
  }
}

class PieceManagementScreen extends StatefulWidget {
  const PieceManagementScreen({
    required this.onNavigate,
    required this.boardModel,
    this.boardGateway,
    this.isChessnutClockDevice = false,
    this.movePairingVerificationDelay = _movePairingVerificationDelay,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final ChessnutBoardModel boardModel;
  final PhysicalBoardGateway? boardGateway;
  final bool isChessnutClockDevice;
  final Duration movePairingVerificationDelay;

  @override
  State<PieceManagementScreen> createState() => _PieceManagementScreenState();
}

class _PieceManagementScreenState extends State<PieceManagementScreen> {
  int channel = 0;
  bool loadingSets = true;
  bool working = false;
  List<String> pieceSetNames = const ['', '', '', ''];
  List<MovePieceStatus> pieces = const [];
  StreamSubscription<List<ChessnutMovePieceStatus>>? _pieceSub;
  Timer? _pieceStatusTimer;

  @override
  void initState() {
    super.initState();
    _syncGateway();
  }

  @override
  void didUpdateWidget(covariant PieceManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.boardGateway != widget.boardGateway ||
        oldWidget.boardModel != widget.boardModel) {
      _syncGateway(updateState: true);
    }
  }

  @override
  void dispose() {
    _pieceStatusTimer?.cancel();
    unawaited(_pieceSub?.cancel());
    super.dispose();
  }

  void _syncGateway({bool updateState = false}) {
    _pieceStatusTimer?.cancel();
    _pieceStatusTimer = null;
    unawaited(_pieceSub?.cancel());
    _pieceSub = null;
    if (updateState) {
      setState(() => pieces = const []);
    } else {
      pieces = const [];
    }
    final gateway = widget.boardGateway;
    if (!widget.boardModel.hasPieceManagement ||
        gateway == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      return;
    }
    _pieceSub = gateway.movePieceStatusStream.listen((next) {
      if (!mounted) return;
      setState(() => pieces = _movePieceStatusesFromHardware(next));
    });
    unawaited(gateway.queryMovePieceStatus());
    _pieceStatusTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => unawaited(gateway.queryMovePieceStatus()),
    );
    unawaited(_refreshMovePieceSets());
  }

  Future<void> _refreshMovePieceSets() async {
    final gateway = widget.boardGateway;
    if (!widget.boardModel.hasPieceManagement ||
        gateway == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      if (mounted) setState(() => loadingSets = false);
      return;
    }
    setState(() => loadingSets = true);
    final results = await Future.wait<dynamic>([
      gateway.queryMovePieceData(),
      gateway.queryMoveChannel(),
    ]);
    if (!mounted) return;
    final names = _normalizePieceSetNames(results[0] as List<String>?);
    final current = results[1] as int?;
    setState(() {
      pieceSetNames = names;
      if (current != null && current >= 0 && current <= 3) {
        channel = current;
        if (pieceSetNames[channel].isEmpty) {
          pieceSetNames = [
            ...pieceSetNames.take(channel),
            _defaultPieceSetName(channel),
            ...pieceSetNames.skip(channel + 1),
          ];
          unawaited(gateway.setMovePieceData(pieceSetNames));
        }
      }
      loadingSets = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.boardModel.hasPieceManagement) {
      return ResponsivePage(
        children: (context, spec) => [
          ScreenHeader(
            title: 'Pieces',
            subtitle: 'Move only',
            leading: IconButton.filledTonal(
              onPressed: () => widget.onNavigate('Back'),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          SizedBox(height: spec.gutter),
          GlassPanel(
            child: Text(
              'Piece management is only available when Chessnut Move is connected.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );
    }

    return ResponsivePage(
      children: (context, spec) => [
        ScreenHeader(
          title: 'Piece management',
          subtitle: 'Chessnut Move',
          leading: IconButton.filledTonal(
            onPressed: () => widget.onNavigate('Back'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          trailing: _SmallPill(label: _channelLabel(channel)),
        ),
        SizedBox(height: spec.gutter),
        ResponsiveSplit(
          breakpoint: 860,
          spacing: spec.gutter,
          leadingFlex: 7,
          trailingFlex: 5,
          leading: SectionColumn(
            spacing: 12,
            children: [
              _MovePieceBatteryBoard(
                pieces: pieces,
                compactLandscape: spec.compactLandscape,
                isChessnutClockDevice: widget.isChessnutClockDevice,
              ),
            ],
          ),
          trailing: SectionColumn(
            spacing: 12,
            children: [
              _MoveBatteryLegend(pieces: pieces),
              _MovePieceSetManager(
                names: pieceSetNames,
                selectedChannel: channel,
                loading: loadingSets,
                working: working,
                onSelect: _selectPieceSet,
                onOpen: _showPieceSetDetails,
                onAutoDetect: _autoDetectPieceSet,
                onPairNew: _showPairDialog,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _selectPieceSet(int nextChannel) async {
    if (nextChannel == channel || working) return;
    final gateway = widget.boardGateway;
    if (gateway == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      _showSnack('Connect Chessnut Move first.');
      return;
    }
    setState(() => working = true);
    final ok = await gateway.setMoveChannel(nextChannel);
    if (!mounted) return;
    setState(() {
      if (ok) channel = nextChannel;
      working = false;
    });
    _showSnack(ok ? 'Piece set connected.' : 'Unable to switch piece set.');
  }

  Future<void> _showPieceSetDetails(int setChannel) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.66),
      builder: (sheetContext) => _MovePieceSetDetailSheet(
        set: MovePieceSet(
          channel: setChannel,
          name: pieceSetNames[setChannel].isEmpty
              ? _defaultPieceSetName(setChannel)
              : pieceSetNames[setChannel],
          selected: setChannel == channel,
          exists: pieceSetNames[setChannel].isNotEmpty || setChannel == channel,
        ),
        onRename: (name) => _renamePieceSet(setChannel, name),
        onConnect: () => _selectPieceSet(setChannel),
        onRemove: () => _removePieceSet(setChannel),
        onShutdown: () => _shutdownPieceSet(setChannel),
      ),
    );
    if (changed == true && mounted) {
      await _refreshMovePieceSets();
    }
  }

  Future<bool> _renamePieceSet(int setChannel, String name) async {
    final gateway = widget.boardGateway;
    if (gateway == null) return false;
    final next = [...pieceSetNames];
    next[setChannel] =
        name.trim().isEmpty ? _defaultPieceSetName(setChannel) : name.trim();
    final ok = await gateway.setMovePieceData(next);
    if (ok && mounted) setState(() => pieceSetNames = next);
    return ok;
  }

  Future<bool> _removePieceSet(int setChannel) async {
    final gateway = widget.boardGateway;
    if (gateway == null) return false;
    final next = [...pieceSetNames];
    next[setChannel] = '';
    final ok = await gateway.setMovePieceData(next);
    if (ok && mounted) setState(() => pieceSetNames = next);
    return ok;
  }

  Future<bool> _shutdownPieceSet(int setChannel) async {
    final gateway = widget.boardGateway;
    if (gateway == null) return false;
    await gateway.setMoveChannel(setChannel);
    return gateway.setMovePieceAutoPoweroff(true);
  }

  Future<void> _autoDetectPieceSet() async {
    final gateway = widget.boardGateway;
    if (gateway == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected ||
        working) {
      _showSnack('Connect Chessnut Move first.');
      return;
    }
    setState(() => working = true);
    final detected = await gateway.discoverMovePieceChannel();
    if (!mounted) return;
    if (detected != null &&
        detected >= 0 &&
        detected <= 3 &&
        pieceSetNames[detected].isNotEmpty) {
      final ok = await gateway.setMoveChannel(detected);
      if (!mounted) return;
      setState(() {
        if (ok) channel = detected;
        working = false;
      });
      _showSnack(ok
          ? 'Piece set detected and connected.'
          : 'Unable to switch piece set.');
      return;
    }
    setState(() => working = false);
    _showSnack(_autoDetectFailureMessage(detected));
  }

  Future<void> _showPairDialog() async {
    final gateway = widget.boardGateway;
    if (gateway == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      _showSnack('Connect Chessnut Move first.');
      return;
    }
    final freeChannels = [
      for (var i = 0; i < 4; i++)
        if (pieceSetNames[i].isEmpty && i != channel) i,
    ];
    if (freeChannels.isEmpty) {
      _showSnack('You can add at most four sets of pieces.');
      return;
    }
    final pairedChannel = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => _MovePiecePairingDialog(
        freeChannels: freeChannels,
        gateway: gateway,
        verificationDelay: widget.movePairingVerificationDelay,
      ),
    );
    if (pairedChannel == null || !mounted) return;
    final next = [...pieceSetNames];
    next[pairedChannel] = _defaultPieceSetName(pairedChannel);
    final saved = await gateway.setMovePieceData(next);
    if (!mounted) return;
    if (saved) {
      setState(() {
        pieceSetNames = next;
        channel = pairedChannel;
      });
      await gateway.setMoveChannel(pairedChannel);
      _showSnack('New pieces paired.');
    } else {
      _showSnack('Paired, but the set name could not be saved.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BoardSettingsHero extends StatelessWidget {
  const _BoardSettingsHero({
    required this.boardModel,
    required this.boardConnected,
    this.batteryStatus,
    super.key,
  });

  final ChessnutBoardModel boardModel;
  final bool boardConnected;
  final BoardBatteryStatus? batteryStatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = ChessnutTheme.tokensOf(context);
    final color = boardConnected ? scheme.primary : tokens.danger;
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            width: 112,
            height: 74,
            decoration: BoxDecoration(
              color: scheme.secondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(4),
            child: Image.asset(
              boardModel.imageAsset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => Image.asset(
                boardModel.fallbackImageAsset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        boardConnected
                            ? '${boardModel.displayName} connected'
                            : 'Board disconnected',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _BoardHeroMeta(
                  boardConnected: boardConnected,
                  batteryStatus: batteryStatus,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardSettingsActions extends StatelessWidget {
  const _BoardSettingsActions({
    required this.onNavigate,
    required this.onFirmwareTap,
    required this.onStoredGamesTap,
    required this.boardModel,
    required this.boardConnected,
    required this.firmwareSubtitle,
    required this.showStoredGames,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final VoidCallback onFirmwareTap;
  final VoidCallback onStoredGamesTap;
  final ChessnutBoardModel boardModel;
  final bool boardConnected;
  final String firmwareSubtitle;
  final bool showStoredGames;

  @override
  Widget build(BuildContext context) {
    if (!boardConnected) return const SizedBox.shrink();
    return ResponsiveGrid(
      minTileWidth: 118,
      maxColumns: 3,
      childAspectRatio: 0.95,
      children: [
        if (boardModel.hasPieceManagement)
          ActionTile(
            icon: Icons.view_module_rounded,
            title: 'Pieces',
            subtitle: 'Pair / battery',
            onTap: () => onNavigate('Pieces'),
          ),
        if (showStoredGames)
          ActionTile(
            icon: Icons.inventory_2_rounded,
            title: 'Saved games',
            subtitle: 'Import OTB',
            onTap: onStoredGamesTap,
          ),
        if (boardModel == ChessnutBoardModel.move)
          ActionTile(
            icon: Icons.system_update_alt_rounded,
            title: 'Firmware',
            subtitle: firmwareSubtitle,
            onTap: onFirmwareTap,
          ),
      ],
    );
  }
}

class _StoredGameImportDialog extends StatefulWidget {
  const _StoredGameImportDialog({
    required this.gateway,
    required this.importer,
  });

  final PhysicalBoardGateway gateway;
  final Future<BoardStorageImportResult> Function({
    required bool deleteAfterImport,
  }) importer;

  @override
  State<_StoredGameImportDialog> createState() =>
      _StoredGameImportDialogState();
}

class _StoredGameImportDialogState extends State<_StoredGameImportDialog> {
  int? _storedGameCount;
  bool _loadingCount = true;
  bool _importing = false;

  bool get _hasStoredGames =>
      !_loadingCount && _storedGameCount != null && _storedGameCount! > 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadStoredGameCount());
    });
  }

  Future<void> _loadStoredGameCount() async {
    int? count;
    try {
      count = await widget.gateway.queryStoredGameCount();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _storedGameCount = count;
      _loadingCount = false;
    });
  }

  Future<void> _importStoredGames() async {
    if (_importing || !_hasStoredGames) return;
    setState(() => _importing = true);
    BoardStorageImportResult? result;
    try {
      result = await widget.importer(deleteAfterImport: true);
    } catch (_) {
      result = const BoardStorageImportResult(
        importedCount: 0,
        skippedCount: 0,
        failedCount: 1,
        importedKeys: <String>{},
        errors: ['A board game could not be imported.'],
      );
    }
    final resolvedResult = result;
    if (!mounted) return;
    Navigator.of(context).pop(resolvedResult);
  }

  @override
  Widget build(BuildContext context) {
    final count = _storedGameCount;
    return PopScope(
      canPop: !_importing,
      child: AppDialogShell(
        icon: Icons.inventory_2_rounded,
        title: 'Import saved board games',
        subtitle: _loadingCount
            ? 'Reading board storage count.'
            : count == null
                ? 'Chessnut could not read the board storage count.'
                : count == 0
                    ? 'No saved games were found on the connected board.'
                    : 'Found $count saved game${count == 1 ? '' : 's'} on the board. Chessnut will import every readable game.',
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: _importing ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
          Expanded(
            child: FilledButton.icon(
              onPressed:
                  _importing || !_hasStoredGames ? null : _importStoredGames,
              icon: _importing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_done_rounded),
              label: Text(_importing ? 'Importing' : 'Import'),
            ),
          ),
        ],
        child: _StoredGameCountSummary(
          count: count,
          loading: _loadingCount,
        ),
      ),
    );
  }
}

class _StoredGameCountSummary extends StatelessWidget {
  const _StoredGameCountSummary({
    required this.count,
    required this.loading,
  });

  final int? count;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = loading
        ? scheme.secondary
        : count == null
            ? scheme.error
            : count! > 0
                ? scheme.primary
                : scheme.secondary;
    final title = loading
        ? 'Checking board storage'
        : count == null
            ? 'Cannot read storage count'
            : count! > 0
                ? 'Saved games found'
                : 'No saved games found';
    final detail = loading
        ? 'Chessnut is checking how many games are saved on the board.'
        : count == null
            ? 'Try again after confirming the board is still connected.'
            : count! > 0
                ? '$count saved game${count == 1 ? '' : 's'} will be imported after you tap Import.'
                : 'The connected board does not report any saved games.';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: loading
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: statusColor,
                    ),
                  )
                : Icon(
                    count != null && count! > 0
                        ? Icons.inventory_2_rounded
                        : Icons.info_outline_rounded,
                    size: 18,
                    color: statusColor,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardHeroMeta extends StatelessWidget {
  const _BoardHeroMeta({
    required this.boardConnected,
    this.batteryStatus,
  });

  final bool boardConnected;
  final BoardBatteryStatus? batteryStatus;

  @override
  Widget build(BuildContext context) {
    final battery = batteryStatus;
    final color = Theme.of(context).colorScheme.secondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            boardConnected
                ? 'Board link ready'
                : 'Connect a board to change live hardware settings.',
            softWrap: true,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (boardConnected && battery != null) ...[
          const SizedBox(width: 8),
          if (battery.isCharging) ...[
            Icon(
              Icons.bolt_rounded,
              key: const ValueKey('board-battery-charging-icon'),
              size: 16,
              color: color,
            ),
            const SizedBox(width: 3),
          ],
          BoardBatteryIcon(status: battery, color: color),
        ],
      ],
    );
  }
}

class _DisconnectBoardButton extends StatelessWidget {
  const _DisconnectBoardButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.bluetooth_disabled_rounded),
      label: const Text('Disconnect board'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: scheme.error,
        side: BorderSide(color: scheme.error.withValues(alpha: 0.45)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.status,
    required this.children,
    this.sectionKey,
  });

  final String title;
  final String status;
  final List<Widget> children;
  final Key? sectionKey;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: sectionKey,
      child: GlassPanel(
        padding: const EdgeInsets.all(12),
        borderRadius: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  status,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

String _voiceMoveLanguageLabel(
  AppLanguagePreference language,
  AppStrings? strings,
) {
  return switch (language) {
    AppLanguagePreference.system => strings?.t('Auto') ?? 'Auto',
    AppLanguagePreference.zhHans => strings?.t('Mandarin') ?? 'Mandarin',
    AppLanguagePreference.zhHant => strings?.t('Cantonese') ?? 'Cantonese',
    _ => language.nativeLabel,
  };
}

class _VoiceMoveSettings extends StatelessWidget {
  const _VoiceMoveSettings({
    required this.settings,
    required this.onChanged,
  });

  final BoardSettingsState settings;
  final ValueChanged<BoardSettingsState> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = AppStrings.maybeOf(context);
    final color = scheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.mic_rounded, size: 20, color: color),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Voice moves',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Use your voice to control piece movement on Chessnut Move.',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Voice moves require a network connection. Choose the correct speech language to improve recognition success.',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Speech language',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 7),
          DropdownButtonFormField<AppLanguagePreference>(
            key: const ValueKey('voice-move-language-dropdown'),
            initialValue: settings.voiceMoveLanguage,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: AppLanguagePreference.values
                .map(
                  (item) => DropdownMenuItem<AppLanguagePreference>(
                    value: item,
                    child: material.Text(
                      _voiceMoveLanguageLabel(item, strings),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              onChanged(settings.copyWith(voiceMoveLanguage: value));
            },
          ),
        ],
      ),
    );
  }
}

class _SwitchItem {
  const _SwitchItem({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
    this.disabledReason,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final String? disabledReason;
}

class _Evo2LedPatternSettings extends StatelessWidget {
  const _Evo2LedPatternSettings({
    required this.patterns,
    required this.onEditPattern,
    required this.onResetPatterns,
  });

  final Evo2LedPatternSet patterns;
  final ValueChanged<String> onEditPattern;
  final VoidCallback onResetPatterns;

  static const _whiteKeys = ['P', 'N', 'B', 'R', 'Q', 'K'];
  static const _blackKeys = ['p', 'n', 'b', 'r', 'q', 'k'];
  static const _analysisKeys = [
    'analysis_best',
    'analysis_great',
    'analysis_inaccuracy',
    'analysis_mistake',
    'analysis_blunder',
    'analysis_other',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Evo2LedPatternHeader(
          onResetPatterns: onResetPatterns,
        ),
        const SizedBox(height: 10),
        _Evo2LedPatternGrid(
          key: const ValueKey('evo2-led-pattern-white-grid'),
          patternKeys: _whiteKeys,
          patterns: patterns,
          onEditPattern: onEditPattern,
        ),
        const SizedBox(height: 10),
        _Evo2LedPatternGrid(
          key: const ValueKey('evo2-led-pattern-black-grid'),
          patternKeys: _blackKeys,
          patterns: patterns,
          onEditPattern: onEditPattern,
        ),
        const SizedBox(height: 10),
        Center(
          child: SizedBox(
            width: 136,
            height: 136 / 1.02,
            child: _Evo2LedPatternTile(
              key: const ValueKey('evo2-led-pattern-blank-tile'),
              patternKey: 'empty',
              pattern: patterns.patternFor('empty'),
              onTap: () => onEditPattern('empty'),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const _Evo2LedPatternSubheader(
          title: 'Analysis marker LED patterns',
        ),
        const SizedBox(height: 10),
        _Evo2LedPatternGrid(
          key: const ValueKey('evo2-led-pattern-analysis-grid'),
          patternKeys: _analysisKeys,
          patterns: patterns,
          onEditPattern: onEditPattern,
        ),
      ],
    );
  }
}

class _Evo2LedPatternSubheader extends StatelessWidget {
  const _Evo2LedPatternSubheader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      title,
      style: TextStyle(
        color: scheme.onSurface,
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _Evo2LedPatternGrid extends StatelessWidget {
  const _Evo2LedPatternGrid({
    required this.patternKeys,
    required this.patterns,
    required this.onEditPattern,
    super.key,
  });

  final List<String> patternKeys;
  final Evo2LedPatternSet patterns;
  final ValueChanged<String> onEditPattern;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.02,
      children: [
        for (final key in patternKeys)
          _Evo2LedPatternTile(
            key: ValueKey('evo2-led-pattern-$key-tile'),
            patternKey: key,
            pattern: patterns.patternFor(key),
            onTap: () => onEditPattern(key),
          ),
      ],
    );
  }
}

class _Evo2LedPatternHeader extends StatelessWidget {
  const _Evo2LedPatternHeader({
    required this.onResetPatterns,
  });

  final VoidCallback onResetPatterns;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            'EVO2 piece LED patterns',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          key: const ValueKey('evo2-led-pattern-reset'),
          onPressed: onResetPatterns,
          icon: const Icon(Icons.restart_alt_rounded, size: 18),
          label: const Text('Reset'),
        ),
      ],
    );
  }
}

class _Evo2LedPatternTile extends StatelessWidget {
  const _Evo2LedPatternTile({
    required this.patternKey,
    required this.pattern,
    required this.onTap,
    super.key,
  });

  final String patternKey;
  final Evo2LedPattern pattern;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: evo2LedPatternLabel(patternKey),
      child: GlassPanel(
        onTap: onTap,
        padding: const EdgeInsets.all(8),
        borderRadius: 12,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: _Evo2LedPatternPreview(
                  pattern: pattern,
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              evo2LedPatternShortLabel(patternKey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Evo2LedPatternDialog extends StatefulWidget {
  const _Evo2LedPatternDialog({
    required this.patternKey,
    required this.initialPattern,
  });

  final String patternKey;
  final Evo2LedPattern initialPattern;

  @override
  State<_Evo2LedPatternDialog> createState() => _Evo2LedPatternDialogState();
}

class _Evo2LedPatternDialogState extends State<_Evo2LedPatternDialog> {
  static const _palette = [
    0x000000,
    0xffffff,
    0xff3b30,
    0xff9500,
    0xffcc00,
    0x34c759,
    0x00c7be,
    0x007aff,
    0x5856d6,
    0xaf52de,
    0xff2d55,
  ];

  late Evo2LedPattern _pattern = widget.initialPattern;
  int _selectedColor = 0xffffff;

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      icon: Icons.grid_view_rounded,
      title: evo2LedPatternLabel(widget.patternKey),
      subtitle: 'EVO2 LED pattern',
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(_pattern),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Save'),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: _Evo2LedPatternEditorGrid(
              pattern: _pattern,
              selectedColor: _selectedColor,
              onCellTap: (index) {
                setState(() {
                  _pattern = _pattern.copyWithCell(index, _selectedColor);
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          _Evo2LedPalette(
            colors: _palette,
            selectedColor: _selectedColor,
            onSelected: (color) => setState(() => _selectedColor = color),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _pattern = _pattern.fill(_selectedColor);
                  }),
                  icon: const Icon(Icons.format_color_fill_rounded),
                  label: const Text('Fill'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _pattern = Evo2LedPattern.empty;
                  }),
                  icon: const Icon(Icons.backspace_outlined),
                  label: const Text('Clear'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Evo2LedPatternEditorGrid extends StatelessWidget {
  const _Evo2LedPatternEditorGrid({
    required this.pattern,
    required this.selectedColor,
    required this.onCellTap,
  });

  final Evo2LedPattern pattern;
  final int selectedColor;
  final ValueChanged<int> onCellTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 266,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: evo2LedPatternSize,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: evo2LedPatternCellCount,
            itemBuilder: (context, index) {
              final color = pattern.colors[index];
              return Tooltip(
                message: 'Cell ${index + 1}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(5),
                  onTap: () => onCellTap(index),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _evo2Color(color),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: color == selectedColor
                            ? scheme.primary
                            : scheme.outlineVariant,
                        width: color == selectedColor ? 2 : 1,
                      ),
                    ),
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

class _Evo2LedPalette extends StatelessWidget {
  const _Evo2LedPalette({
    required this.colors,
    required this.selectedColor,
    required this.onSelected,
  });

  final List<int> colors;
  final int selectedColor;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final color in colors)
          Tooltip(
            message: color == 0 ? 'Off' : '#${_hexColor(color)}',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSelected(color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _evo2Color(color),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selectedColor == color
                          ? scheme.primary
                          : scheme.outlineVariant,
                      width: selectedColor == color ? 3 : 1,
                    ),
                  ),
                  child: color == 0
                      ? Icon(
                          Icons.close_rounded,
                          size: 17,
                          color: scheme.onSurface.withValues(alpha: 0.7),
                        )
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Evo2LedPatternPreview extends StatelessWidget {
  const _Evo2LedPatternPreview({
    required this.pattern,
    required this.size,
  });

  final Evo2LedPattern pattern;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: evo2LedPatternSize,
              mainAxisSpacing: 1,
              crossAxisSpacing: 1,
            ),
            itemCount: evo2LedPatternCellCount,
            itemBuilder: (context, index) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: _evo2Color(pattern.colors[index]),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

Color _evo2Color(int rgb) {
  return Color(0xff000000 | (rgb & 0xffffff));
}

String _hexColor(int rgb) {
  return (rgb & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase();
}

String _clockSwitchStatusLabel(
  ClockSwitchAutomationMode mode,
  ClockSwitchOpponentTiming timing,
) {
  final modeLabel = switch (mode) {
    ClockSwitchAutomationMode.off => 'Off',
    ClockSwitchAutomationMode.opponentMoveOnly => 'Opponent move only',
    ClockSwitchAutomationMode.bothSides => 'Both sides',
  };
  if (mode == ClockSwitchAutomationMode.off) return modeLabel;
  final timingLabel = switch (timing) {
    ClockSwitchOpponentTiming.aggressive => 'Aggressive',
    ClockSwitchOpponentTiming.leisure => 'Leisure',
  };
  return '$modeLabel / $timingLabel';
}

class _ClockSwitchAutomationPills extends StatelessWidget {
  const _ClockSwitchAutomationPills({
    required this.selected,
    required this.confirmMovesWithSwitch,
    required this.onSelected,
  });

  final ClockSwitchAutomationMode selected;
  final bool confirmMovesWithSwitch;
  final ValueChanged<ClockSwitchAutomationMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      (ClockSwitchAutomationMode.off, 'Off'),
      (ClockSwitchAutomationMode.opponentMoveOnly, 'Opponent move only'),
      (ClockSwitchAutomationMode.bothSides, 'Both sides'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              Builder(
                builder: (context) {
                  final disabled = confirmMovesWithSwitch &&
                      item.$1 == ClockSwitchAutomationMode.bothSides;
                  final selectedItem = selected == item.$1 && !disabled;
                  return ChoiceChip(
                    label: Text(item.$2),
                    selected: selectedItem,
                    onSelected: disabled ? null : (_) => onSelected(item.$1),
                    showCheckmark: false,
                    avatar: Icon(
                      item.$1 == ClockSwitchAutomationMode.off
                          ? Icons.block_rounded
                          : item.$1 ==
                                  ClockSwitchAutomationMode.opponentMoveOnly
                              ? Icons.person_outline_rounded
                              : Icons.groups_rounded,
                      size: 17,
                      color: selectedItem
                          ? scheme.primary
                          : scheme.onSurface.withValues(
                              alpha: disabled ? 0.34 : 0.62,
                            ),
                    ),
                    labelStyle: TextStyle(
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w900,
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _ClockSwitchOpponentTimingPills extends StatelessWidget {
  const _ClockSwitchOpponentTimingPills({
    required this.selected,
    required this.onSelected,
  });

  final ClockSwitchOpponentTiming selected;
  final ValueChanged<ClockSwitchOpponentTiming> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        ClockSwitchOpponentTiming.aggressive,
        'Aggressive mode',
        'Press as soon as the opponent move arrives.',
        Icons.flash_on_rounded,
      ),
      (
        ClockSwitchOpponentTiming.leisure,
        'Leisure mode',
        'Wait until the board matches the opponent move.',
        Icons.hourglass_empty_rounded,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 2 : 1;
        const spacing = 8.0;
        final tileWidth =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;
        if (columns == 2) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: spacing),
                  Expanded(
                    child: _ClockSwitchOpponentTimingTile(
                      title: items[i].$2,
                      detail: items[i].$3,
                      icon: items[i].$4,
                      selected: selected == items[i].$1,
                      onTap: () => onSelected(items[i].$1),
                    ),
                  ),
                ],
              ],
            ),
          );
        }
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items)
              SizedBox(
                width: tileWidth,
                child: _ClockSwitchOpponentTimingTile(
                  title: item.$2,
                  detail: item.$3,
                  icon: item.$4,
                  selected: selected == item.$1,
                  onTap: () => onSelected(item.$1),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ClockSwitchOpponentTimingTile extends StatelessWidget {
  const _ClockSwitchOpponentTimingTile({
    required this.title,
    required this.detail,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String detail;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.secondary;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $detail',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: selected ? 0.13 : 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: color.withValues(alpha: selected ? 0.36 : 0.16),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.66),
                          fontSize: 11,
                          height: 1.18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSubheader extends StatelessWidget {
  const _SettingsSubheader({
    required this.title,
    this.detail,
  });

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final detail = this.detail;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (detail != null) ...[
          const SizedBox(width: 8),
          IconButton.filledTonal(
            key: ValueKey('settings-subheader-detail-$title'),
            tooltip: 'Clock switch details',
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Automatic switch press'),
                  content: Text(detail),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
            icon: Icon(
              Icons.info_outline_rounded,
              color: scheme.secondary,
            ),
            constraints: const BoxConstraints.tightFor(
              width: 34,
              height: 34,
            ),
            padding: EdgeInsets.zero,
          ),
        ],
      ],
    );
  }
}

class _MasterSwitchTile extends StatelessWidget {
  const _MasterSwitchTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = value ? scheme.primary : scheme.secondary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.only(left: 12, right: 6, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: value ? 0.13 : 0.07),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: value ? 0.38 : 0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 21, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SwitchGrid extends StatelessWidget {
  const _SwitchGrid({
    required this.items,
    this.adaptToTextScale = false,
  });

  final List<_SwitchItem> items;
  final bool adaptToTextScale;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (adaptToTextScale) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final columns = items.length == 1
              ? 1
              : constraints.maxWidth >= 420 && textScale <= 1.15
                  ? 2
                  : 1;
          const spacing = 8.0;
          final itemWidth = columns == 1
              ? constraints.maxWidth
              : (constraints.maxWidth - spacing) / 2;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final item in items)
                SizedBox(
                  width: itemWidth,
                  child: _SwitchTile(item: item),
                ),
            ],
          );
        }
        final columns =
            items.length == 1 ? 1 : (constraints.maxWidth >= 420 ? 2 : 1);
        final aspectRatio =
            columns == 1 ? (constraints.maxWidth >= 560 ? 7.0 : 4.2) : 3.25;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: aspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: items.map((item) => _SwitchTile(item: item)).toList(),
        );
      },
    );
  }
}

class _SwitchList extends StatelessWidget {
  const _SwitchList({required this.items});

  final List<_SwitchItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _SwitchTile(item: items[i]),
        ],
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({required this.item});

  final _SwitchItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = item.enabled
        ? (item.value ? scheme.primary : scheme.secondary)
        : scheme.outline;
    return Tooltip(
      message: item.enabled
          ? item.label
          : item.disabledReason ?? '${item.label} is currently disabled',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: item.enabled ? 1 : 0.55,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.only(left: 10, right: 8, top: 6, bottom: 6),
          decoration: BoxDecoration(
            color: color.withValues(
                alpha: item.value && item.enabled ? 0.12 : 0.06),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: color.withValues(
                  alpha: item.value && item.enabled ? 0.34 : 0.13),
            ),
          ),
          child: Row(
            children: [
              Icon(item.icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (item.subtitle != null)
                      Text(
                        item.subtitle!,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.92,
                child: Switch(
                  value: item.value,
                  onChanged: item.enabled ? item.onChanged : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSlider extends StatelessWidget {
  const _SettingsSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.onChangeEnd,
    this.valueFormatter,
    super.key,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String Function(double value)? valueFormatter;

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(min, max).toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                valueFormatter?.call(clampedValue) ??
                    '${clampedValue.round()} ms',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            value: clampedValue,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ],
      ),
    );
  }
}

class MovePieceSet {
  const MovePieceSet({
    required this.channel,
    required this.name,
    required this.selected,
    required this.exists,
  });

  final int channel;
  final String name;
  final bool selected;
  final bool exists;
}

List<String> _normalizePieceSetNames(List<String>? names) {
  return [
    for (var i = 0; i < 4; i++)
      if (names != null && i < names.length) names[i].trim() else '',
  ];
}

String _defaultPieceSetName(int channel) {
  return 'Chess Pieces ${(channel + 1).toString().padLeft(2, '0')}';
}

String _channelLabel(int channel) {
  return channel == 3 ? 'Backup' : 'Channel $channel';
}

String _shortChannelLabel(int channel) {
  return channel == 3 ? 'B' : '$channel';
}

String _autoDetectFailureMessage(int? code) {
  return switch (code) {
    11 => 'No pieces were detected on the board.',
    12 => 'Pieces from multiple channels were detected.',
    null => 'Unable to detect the piece set.',
    _ => 'Detected an unknown piece channel.',
  };
}

class _MovePieceSetManager extends StatelessWidget {
  const _MovePieceSetManager({
    required this.names,
    required this.selectedChannel,
    required this.loading,
    required this.working,
    required this.onSelect,
    required this.onOpen,
    required this.onAutoDetect,
    required this.onPairNew,
  });

  final List<String> names;
  final int selectedChannel;
  final bool loading;
  final bool working;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onOpen;
  final VoidCallback onAutoDetect;
  final VoidCallback onPairNew;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: 'Piece sets',
      status: loading ? 'Loading' : _channelLabel(selectedChannel),
      children: [
        for (var i = 0; i < 4; i++)
          _MovePieceSetCard(
            set: MovePieceSet(
              channel: i,
              name: names[i].isEmpty ? _defaultPieceSetName(i) : names[i],
              selected: i == selectedChannel,
              exists: names[i].isNotEmpty || i == selectedChannel,
            ),
            disabled: working,
            onTap: () => onOpen(i),
            onConnect: () => onSelect(i),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: working ? null : onAutoDetect,
                icon: const Icon(Icons.sensors_rounded),
                label: const Text('Auto-detect set'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: working ? null : onPairNew,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Pair new pieces'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MovePieceSetCard extends StatelessWidget {
  const _MovePieceSetCard({
    required this.set,
    required this.disabled,
    required this.onTap,
    required this.onConnect,
  });

  final MovePieceSet set;
  final bool disabled;
  final VoidCallback onTap;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = set.selected;
    final color = active ? scheme.primary : scheme.secondary;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.14)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: active ? 0.42 : 0.12),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: active ? 0.18 : 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                _shortChannelLabel(set.channel),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    set.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: set.exists ? null : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _channelLabel(set.channel),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!active)
              TextButton(
                onPressed: disabled ? null : onConnect,
                child: const Text('Connect'),
              )
            else
              const _SmallPill(label: 'Connected'),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _MovePieceSetDetailSheet extends StatefulWidget {
  const _MovePieceSetDetailSheet({
    required this.set,
    required this.onRename,
    required this.onConnect,
    required this.onRemove,
    required this.onShutdown,
  });

  final MovePieceSet set;
  final Future<bool> Function(String name) onRename;
  final Future<void> Function() onConnect;
  final Future<bool> Function() onRemove;
  final Future<bool> Function() onShutdown;

  @override
  State<_MovePieceSetDetailSheet> createState() =>
      _MovePieceSetDetailSheetState();
}

class _MovePieceSetDetailSheetState extends State<_MovePieceSetDetailSheet> {
  late final TextEditingController controller =
      TextEditingController(text: widget.set.name);
  bool busy = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          14,
          8,
          14,
          MediaQuery.viewInsetsOf(context).bottom + 14,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Material(
              color: scheme.surface,
              elevation: 24,
              shadowColor: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.62),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color:
                                scheme.outlineVariant.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.set.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _channelLabel(widget.set.channel),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: scheme.secondary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        maxLength: 20,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          filled: true,
                          fillColor: scheme.surfaceContainerHighest
                              .withValues(alpha: 0.58),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _DetailRow(
                          label: 'Channel',
                          value: _channelLabel(widget.set.channel)),
                      const SizedBox(height: 8),
                      _ShutdownModeCard(
                        busy: busy,
                        onPressed: _shutdown,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: busy ? null : _remove,
                              icon: Icon(Icons.delete_outline_rounded,
                                  color: scheme.error),
                              label: Text('Remove',
                                  style: TextStyle(color: scheme.error)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: busy ? null : _saveAndConnect,
                              child: Text(
                                  widget.set.selected ? 'Save' : 'Connect'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveAndConnect() async {
    setState(() => busy = true);
    final renamed = await widget.onRename(controller.text);
    if (!mounted) return;
    if (renamed && !widget.set.selected) {
      await widget.onConnect();
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _remove() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove piece set?'),
        content: const Text(
          'Removed pieces need to be paired again before they can be used.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => busy = true);
    final removed = await widget.onRemove();
    if (!mounted) return;
    Navigator.of(context).pop(removed);
  }

  Future<void> _shutdown() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Turn on shutdown mode?'),
        content: const Text(
          'Use this for long-term storage. Pieces must be placed on the charging board before they can be used again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => busy = true);
    final ok = await widget.onShutdown();
    if (!mounted) return;
    setState(() => busy = false);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
          content:
              Text(ok ? 'Shutdown mode sent.' : 'Unable to send command.')),
    );
  }
}

class _ShutdownModeCard extends StatelessWidget {
  const _ShutdownModeCard({
    required this.busy,
    required this.onPressed,
  });

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.secondary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.power_settings_new_rounded,
              size: 19,
              color: scheme.secondary,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Shutdown mode',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  'Use for long storage.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: busy ? null : onPressed,
            child: const Text('Turn on'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

enum _MovePairingStep { placement, channel, pairing, success, failed, help }

const _movePairingMaxAttempts = 3;
const _movePairingVerificationDelay = Duration(seconds: 5);
const _movePairingSuccessVerificationFen =
    'rnbqkbnr/pppppppp/7q/8/8/7Q/PPPPPPPP/RNBQKBNR';

class _MovePiecePairingDialog extends StatefulWidget {
  const _MovePiecePairingDialog({
    required this.freeChannels,
    required this.gateway,
    required this.verificationDelay,
  });

  final List<int> freeChannels;
  final PhysicalBoardGateway gateway;
  final Duration verificationDelay;

  @override
  State<_MovePiecePairingDialog> createState() =>
      _MovePiecePairingDialogState();
}

class _MovePiecePairingDialogState extends State<_MovePiecePairingDialog> {
  late int selectedChannel = widget.freeChannels.first;
  _MovePairingStep step = _MovePairingStep.placement;
  bool busy = false;
  bool _pairingModeActive = false;
  String? _lastPairingVerificationFen;

  @override
  Widget build(BuildContext context) {
    final title = switch (step) {
      _MovePairingStep.placement => 'Place pieces',
      _MovePairingStep.channel => 'Select channel',
      _MovePairingStep.pairing => 'Pairing pieces',
      _MovePairingStep.success => 'Pairing complete',
      _MovePairingStep.failed => 'Pairing failed',
      _MovePairingStep.help => 'Troubleshooting',
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !busy) unawaited(_closeDialog());
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (!busy)
                      IconButton(
                        onPressed: _closeDialog,
                        icon: const Icon(Icons.close_rounded),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(child: SingleChildScrollView(child: _body(context))),
                const SizedBox(height: 16),
                _actions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    switch (step) {
      case _MovePairingStep.placement:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              key: const ValueKey('move-pair-placement-board'),
              aspectRatio: 1,
              child: _MovePieceBoardCanvas(
                key: const ValueKey('move-piece-board'),
                pieces: _pairingBoardPieces(),
                waiting: false,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Place all 34 pieces exactly as shown before pairing.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Keep nearby Move sets away during pairing. The process usually takes 3-5 minutes.',
            ),
          ],
        );
      case _MovePairingStep.channel:
        return Column(
          children: [
            for (final channel in [0, 1, 2, 3])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PairingChannelTile(
                  channel: channel,
                  enabled: widget.freeChannels.contains(channel),
                  selected: channel == selectedChannel,
                  onTap: () => setState(() => selectedChannel = channel),
                ),
              ),
          ],
        );
      case _MovePairingStep.pairing:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 34),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 18),
              Text('Pairing...'),
            ],
          ),
        );
      case _MovePairingStep.success:
        return const _PairingResult(
          icon: Icons.check_circle_rounded,
          title: 'Pieces are ready',
          body: 'The new set has been paired and saved to this channel.',
        );
      case _MovePairingStep.failed:
        return const _PairingResult(
          icon: Icons.error_rounded,
          title: 'Unable to pair pieces',
          body:
              'Check placement, battery, and nearby interference, then try again.',
        );
      case _MovePairingStep.help:
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Make sure every piece is on the correct square.'),
            SizedBox(height: 8),
            Text('2. Charge pieces that may be powered off.'),
            SizedBox(height: 8),
            Text(
                '3. Keep other Move sets at least 20 meters away while pairing.'),
            SizedBox(height: 8),
            Text('4. Try another free channel if pairing still fails.'),
          ],
        );
    }
  }

  Widget _actions(BuildContext context) {
    switch (step) {
      case _MovePairingStep.placement:
        return FilledButton(
          onPressed: () => setState(() => step = _MovePairingStep.channel),
          child: const Text('Next'),
        );
      case _MovePairingStep.channel:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () =>
                    setState(() => step = _MovePairingStep.placement),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _startPairing,
                child: const Text('Start pairing'),
              ),
            ),
          ],
        );
      case _MovePairingStep.pairing:
        return const SizedBox.shrink();
      case _MovePairingStep.success:
        return FilledButton(
          onPressed: () => _closeDialog(selectedChannel),
          child: const Text('Done'),
        );
      case _MovePairingStep.failed:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _leavePairingResult(_MovePairingStep.help),
                child: const Text('Help'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => _leavePairingResult(_MovePairingStep.channel),
                child: const Text('Try again'),
              ),
            ),
          ],
        );
      case _MovePairingStep.help:
        return FilledButton(
          onPressed: () => setState(() => step = _MovePairingStep.channel),
          child: const Text('Back to channels'),
        );
    }
  }

  Future<void> _startPairing() async {
    setState(() {
      busy = true;
      step = _MovePairingStep.pairing;
      _pairingModeActive = false;
    });

    var success = false;
    _lastPairingVerificationFen = null;
    for (var attempt = 0; attempt < _movePairingMaxAttempts; attempt += 1) {
      final started =
          await widget.gateway.startMovePiecePairing(selectedChannel);
      if (!mounted) return;
      if (!started) {
        success = await _verifyPairingFenAfterFailure();
        if (!mounted || success) break;
        continue;
      }

      _pairingModeActive = true;
      final pairingSucceeded = await widget.gateway.finishMovePiecePairing();
      if (!mounted) return;
      if (pairingSucceeded) {
        success = true;
        break;
      }

      success = await _verifyPairingFenAfterFailure();
      if (!mounted || success) break;
    }

    if (!mounted) return;
    if (!success) {
      await _showPairingFenDifferences();
      if (!mounted) return;
    }
    setState(() {
      busy = false;
      step = success ? _MovePairingStep.success : _MovePairingStep.failed;
    });
  }

  Future<bool> _verifyPairingFenAfterFailure() async {
    await _exitPairingModeBeforeFenRead();
    if (!mounted) return false;
    final fen = await _readCurrentBoardFenAfterDelay();
    _lastPairingVerificationFen = fen;
    return fen == _movePairingSuccessVerificationFen;
  }

  Future<void> _showPairingFenDifferences() async {
    final diffSquares = _differentSquaresFromBoardFen(
      _lastPairingVerificationFen,
      _movePairingSuccessVerificationFen,
    );
    if (diffSquares.isEmpty) return;
    await widget.gateway.setMoveLedSquares({
      for (final square in diffSquares) square: ChessnutMoveLedColor.red,
    });
  }

  Future<void> _exitPairingModeBeforeFenRead() async {
    _pairingModeActive = false;
    await widget.gateway.exitMovePiecePairing();
  }

  Future<String?> _readCurrentBoardFenAfterDelay() async {
    String? observedFen;
    final sub = widget.gateway.boardFenStream.listen((fen) {
      observedFen = _boardOnlyFen(fen);
    });
    unawaited(widget.gateway.enableRealtimeFen());
    try {
      if (widget.verificationDelay > Duration.zero) {
        await Future<void>.delayed(widget.verificationDelay);
      }
    } finally {
      unawaited(sub.cancel());
    }
    return _boardOnlyFen(observedFen ?? widget.gateway.latestBoardFen);
  }

  String? _boardOnlyFen(String? fen) {
    final trimmed = fen?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.split(RegExp(r'\s+')).first;
  }

  Future<void> _leavePairingResult(_MovePairingStep nextStep) async {
    await _exitPairingModeIfNeeded();
    if (!mounted) return;
    setState(() => step = nextStep);
  }

  Future<void> _closeDialog([int? result]) async {
    await _exitPairingModeIfNeeded();
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  Future<void> _exitPairingModeIfNeeded() async {
    if (!_pairingModeActive) return;
    _pairingModeActive = false;
    await widget.gateway.exitMovePiecePairing();
  }
}

Set<String> _differentSquaresFromBoardFen(
    String? observedFen, String targetFen) {
  final observed = _expandBoardOnlyFen(observedFen);
  final target = _expandBoardOnlyFen(targetFen);
  if (observed == null || target == null) return const {};
  final diff = <String>{};
  for (var index = 0; index < 64; index += 1) {
    if (observed[index] == target[index]) continue;
    final file = String.fromCharCode('a'.codeUnitAt(0) + (index % 8));
    final rank = 8 - (index ~/ 8);
    diff.add('$file$rank');
  }
  return diff;
}

List<String>? _expandBoardOnlyFen(String? fen) {
  final boardOnlyFen = fen?.trim().split(RegExp(r'\s+')).first;
  if (boardOnlyFen == null || boardOnlyFen.isEmpty) return null;
  final rows = boardOnlyFen.split('/');
  if (rows.length != 8) return null;
  final squares = <String>[];
  for (final row in rows) {
    var rowSquareCount = 0;
    for (final char in row.split('')) {
      final empty = int.tryParse(char);
      if (empty != null) {
        if (empty < 1 || empty > 8) return null;
        squares.addAll(List<String>.filled(empty, ''));
        rowSquareCount += empty;
      } else if (_fenPieceChars.contains(char)) {
        squares.add(char);
        rowSquareCount += 1;
      } else {
        return null;
      }
    }
    if (rowSquareCount != 8) return null;
  }
  return squares.length == 64 ? List<String>.unmodifiable(squares) : null;
}

const _fenPieceChars = {
  'p',
  'n',
  'b',
  'r',
  'q',
  'k',
  'P',
  'N',
  'B',
  'R',
  'Q',
  'K',
};

class _PairingChannelTile extends StatelessWidget {
  const _PairingChannelTile({
    required this.channel,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final int channel;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.secondary;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled
              ? color.withValues(alpha: selected ? 0.14 : 0.06)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: color.withValues(alpha: selected ? 0.4 : 0.1)),
        ),
        child: Text(
          _channelLabel(channel),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: enabled
                ? null
                : scheme.onSurfaceVariant.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

class _PairingResult extends StatelessWidget {
  const _PairingResult({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(icon, size: 58, color: scheme.primary),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class MovePieceStatus {
  const MovePieceStatus({
    required this.index,
    required this.position,
    required this.rawX,
    required this.rawY,
    required this.code,
    required this.label,
    required this.battery,
    this.square,
    this.inBoard = true,
  });

  final int index;
  final Offset position;
  final int rawX;
  final int rawY;
  final String code;
  final String label;
  final int? battery;
  final String? square;
  final bool inBoard;

  String get assetName => '${code[0]}${code[1].toUpperCase()}.svg';

  String get batteryLabel => battery == null ? 'Unknown' : '$battery%';

  String get positionLabel {
    final squareName = square;
    if (squareName != null) return squareName;
    return inBoard ? 'x $rawX / y $rawY' : 'off-board slot $index';
  }

  MovePieceBatteryLevel get level {
    final value = battery;
    if (value == null) return MovePieceBatteryLevel.unknown;
    if (value >= 50) return MovePieceBatteryLevel.high;
    if (value >= 20) return MovePieceBatteryLevel.medium;
    return MovePieceBatteryLevel.low;
  }
}

enum MovePieceBatteryLevel { high, medium, low, unknown }

const _movePieceBoardImage = 'assets/images/boardpics/move_piece_positions.png';
const _movePieceViewHeightFactor = 1.22;
const _movePieceBackgroundHeightFactor = 0.815;

List<MovePieceStatus> _movePieceStatusesFromHardware(
  List<ChessnutMovePieceStatus> pieces,
) {
  var outOfBoardCount = 0;
  final statuses = <MovePieceStatus>[];
  for (final piece in pieces) {
    final position = _movePiecePositionFromHardware(
      piece,
      outOfBoardCount: outOfBoardCount,
    );
    if (piece.isOutOfBoard) {
      outOfBoardCount++;
    }
    statuses.add(
      MovePieceStatus(
        index: piece.index,
        position: position,
        rawX: piece.rawX,
        rawY: piece.rawY,
        code: _movePieceCode(piece.fenChar),
        label: _movePieceLabel(piece.fenChar),
        battery: piece.batteryLevel,
        inBoard: piece.isOnBoard,
      ),
    );
  }
  return statuses;
}

Offset _movePiecePositionFromHardware(
  ChessnutMovePieceStatus piece, {
  required int outOfBoardCount,
}) {
  if (piece.isOnBoard) {
    return Offset(
      (255 - piece.rawX) * 0.00360 - 0.008,
      (255 - piece.rawY) * 0.00282 - 0.005,
    );
  }
  return Offset(
    (outOfBoardCount % 9) * 0.1 + 0.05,
    0.815 + (outOfBoardCount ~/ 9) * 0.1,
  );
}

List<MovePieceStatus> _pairingBoardPieces() {
  const placement = {
    'a8': 'r',
    'b8': 'n',
    'c8': 'b',
    'd8': 'q',
    'e8': 'k',
    'f8': 'b',
    'g8': 'n',
    'h8': 'r',
    'a7': 'p',
    'b7': 'p',
    'c7': 'p',
    'd7': 'p',
    'e7': 'p',
    'f7': 'p',
    'g7': 'p',
    'h7': 'p',
    'h6': 'q',
    'h3': 'Q',
    'a2': 'P',
    'b2': 'P',
    'c2': 'P',
    'd2': 'P',
    'e2': 'P',
    'f2': 'P',
    'g2': 'P',
    'h2': 'P',
    'a1': 'R',
    'b1': 'N',
    'c1': 'B',
    'd1': 'Q',
    'e1': 'K',
    'f1': 'B',
    'g1': 'N',
    'h1': 'R',
  };
  var index = 0;
  return [
    for (final entry in placement.entries)
      MovePieceStatus(
        index: index++,
        position: _movePiecePositionFromSquare(entry.key),
        rawX: 0,
        rawY: 0,
        code: _movePieceCode(entry.value),
        label: _movePieceLabel(entry.value),
        battery: 100,
        square: entry.key,
      ),
  ];
}

Offset _movePiecePositionFromSquare(String square) {
  final point = _squarePoint(square);
  if (point == null) return Offset.zero;
  return Offset(0.125 + point.dx * 0.75 / 8, 0.04 + point.dy * 0.75 / 8);
}

String _movePieceCode(String fenChar) {
  final color = fenChar == fenChar.toUpperCase() ? 'w' : 'b';
  final role = fenChar.toUpperCase();
  const roles = {'P', 'R', 'N', 'B', 'Q', 'K'};
  return '$color${roles.contains(role) ? role : 'P'}';
}

String _movePieceLabel(String fenChar) {
  final color = fenChar == fenChar.toUpperCase() ? 'White' : 'Black';
  final role = switch (fenChar.toUpperCase()) {
    'P' => 'pawn',
    'R' => 'rook',
    'N' => 'knight',
    'B' => 'bishop',
    'Q' => 'queen',
    'K' => 'king',
    _ => 'piece',
  };
  return '$color $role';
}

class _MovePieceBatteryBoard extends StatelessWidget {
  const _MovePieceBatteryBoard({
    required this.pieces,
    required this.compactLandscape,
    required this.isChessnutClockDevice,
  });

  final List<MovePieceStatus> pieces;
  final bool compactLandscape;
  final bool isChessnutClockDevice;

  @override
  Widget build(BuildContext context) {
    final hasPieces = pieces.isNotEmpty;
    final hasOutOfBoardPieces = pieces.any((piece) => !piece.inBoard);
    final useAndroidPieceBackground = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !isChessnutClockDevice;
    final heightFactor = hasOutOfBoardPieces
        ? _movePieceViewHeightFactor
        : _movePieceBackgroundHeightFactor;
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Piece positions',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _SmallPill(
                label: hasPieces ? '${pieces.length} detected' : 'Waiting',
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = compactLandscape ? 520.0 : 680.0;
              final boardWidth =
                  constraints.maxWidth.clamp(252.0, maxWidth).toDouble();
              return Center(
                child: SizedBox(
                  key: const ValueKey('move-piece-board'),
                  width: boardWidth,
                  child: AspectRatio(
                    aspectRatio: 1 / heightFactor,
                    child: _MovePieceBoardCanvas(
                      pieces: pieces,
                      waiting: !hasPieces,
                      useAndroidPieceBackground: useAndroidPieceBackground,
                    ),
                  ),
                ),
              );
            },
          ),
          if (!hasPieces) ...[
            const SizedBox(height: 12),
            const Text(
              'Waiting for piece status',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Keep Chessnut Move connected. Piece positions and batteries will appear when the board reports them.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _MovePieceBoardCanvas extends StatelessWidget {
  const _MovePieceBoardCanvas({
    super.key,
    required this.pieces,
    required this.waiting,
    this.useAndroidPieceBackground = false,
  });

  final List<MovePieceStatus> pieces;
  final bool waiting;
  final bool useAndroidPieceBackground;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: dark ? Colors.white12 : const Color(0x220F172A),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final canvasSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                final pieceSize = constraints.maxWidth * 0.75 / 8;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      right: 0,
                      height:
                          canvasSize.width * _movePieceBackgroundHeightFactor,
                      child: Image.asset(
                        _movePieceBoardImage,
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    for (final piece in pieces)
                      _PositionedMovePiece(
                        piece: piece,
                        canvasSize: canvasSize,
                        pieceSize: pieceSize.toDouble(),
                        useAndroidPieceBackground: useAndroidPieceBackground,
                      ),
                    if (waiting)
                      Center(
                        child: Icon(
                          Icons.sensors_rounded,
                          size: 42,
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withValues(alpha: 0.72),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PositionedMovePiece extends StatelessWidget {
  const _PositionedMovePiece({
    required this.piece,
    required this.canvasSize,
    required this.pieceSize,
    required this.useAndroidPieceBackground,
  });

  final MovePieceStatus piece;
  final Size canvasSize;
  final double pieceSize;
  final bool useAndroidPieceBackground;

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      left: piece.position.dx * canvasSize.width,
      top: piece.position.dy * canvasSize.width,
      width: pieceSize,
      height: pieceSize,
      child: SizedBox(
        key: ValueKey('move-piece-position-${piece.index}'),
        child: _MovePieceGlyph(
          piece: piece,
          useAndroidPieceBackground: useAndroidPieceBackground,
        ),
      ),
    );
  }
}

class _MovePieceGlyph extends StatelessWidget {
  const _MovePieceGlyph({
    required this.piece,
    required this.useAndroidPieceBackground,
  });

  final MovePieceStatus piece;
  final bool useAndroidPieceBackground;

  @override
  Widget build(BuildContext context) {
    final color = _batteryColor(context, piece.level);
    final outlineColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF0F172A);
    final glyphKey = piece.square == null
        ? null
        : ValueKey('move-piece-glyph-${piece.square}-${piece.code}');
    final pieceBackgroundDecoration = BoxDecoration(
      color: useAndroidPieceBackground
          ? const Color(0xFFE9EDEC)
          : Colors.white.withValues(alpha: 0.78),
      shape: BoxShape.circle,
      border: Border.all(
        color: useAndroidPieceBackground
            ? const Color(0xFF6B7673)
            : outlineColor.withValues(alpha: 0.88),
        width: useAndroidPieceBackground ? 1.2 : 1.6,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: useAndroidPieceBackground ? 0.2 : 0.24,
          ),
          blurRadius: useAndroidPieceBackground ? 4 : 8,
          offset: Offset(0, useAndroidPieceBackground ? 1 : 2),
        ),
      ],
    );
    return Tooltip(
      message: '${piece.label} ${piece.positionLabel} ${piece.batteryLabel}',
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (useAndroidPieceBackground)
            KeyedSubtree(
              key: ValueKey('android-piece-background-${piece.code}'),
              child: Container(
                key: ValueKey('piece-outline-${piece.code}'),
                margin: const EdgeInsets.all(2),
                decoration: pieceBackgroundDecoration,
              ),
            )
          else
            Container(
              key: ValueKey('piece-outline-${piece.code}'),
              margin: const EdgeInsets.all(3),
              decoration: pieceBackgroundDecoration,
            ),
          if (!useAndroidPieceBackground)
            Container(
              key: ValueKey('piece-battery-${piece.code}'),
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(bottom: 3),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.36),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          Padding(
            key: glyphKey,
            padding: useAndroidPieceBackground
                ? const EdgeInsets.fromLTRB(4, 3, 4, 7)
                : const EdgeInsets.all(5),
            child: SvgPicture.asset(
              'assets/pieces/cburnett/${piece.assetName}',
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            left: 5,
            right: 5,
            bottom: useAndroidPieceBackground ? 2 : 4,
            child: Container(
              key: useAndroidPieceBackground
                  ? ValueKey('piece-battery-${piece.code}')
                  : null,
              height: useAndroidPieceBackground ? 3.5 : 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Offset? _squarePoint(String square) {
  if (square.length != 2) return null;
  const files = 'abcdefgh';
  final file = files.indexOf(square[0]);
  final rank = int.tryParse(square[1]);
  if (file < 0 || rank == null || rank < 1 || rank > 8) return null;
  return Offset(file.toDouble(), (8 - rank).toDouble());
}

Color _batteryColor(BuildContext context, MovePieceBatteryLevel level) {
  switch (level) {
    case MovePieceBatteryLevel.high:
      return Theme.of(context).colorScheme.primary;
    case MovePieceBatteryLevel.medium:
      return const Color(0xFFF59E0B);
    case MovePieceBatteryLevel.low:
      return const Color(0xFFEF4444);
    case MovePieceBatteryLevel.unknown:
      return const Color(0xFF8A94A6);
  }
}

class _MoveBatteryLegend extends StatelessWidget {
  const _MoveBatteryLegend({required this.pieces});

  final List<MovePieceStatus> pieces;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: 'Battery levels',
      status: pieces.isEmpty ? 'Waiting' : 'Live',
      children: [
        _BatteryLegendRow(
          color: _batteryColor(context, MovePieceBatteryLevel.high),
          label: '50-100%',
          detail: 'Sufficient power',
          count: _countLevel(MovePieceBatteryLevel.high),
        ),
        _BatteryLegendRow(
          color: _batteryColor(context, MovePieceBatteryLevel.medium),
          label: '20-49%',
          detail: 'Medium power',
          count: _countLevel(MovePieceBatteryLevel.medium),
        ),
        _BatteryLegendRow(
          color: _batteryColor(context, MovePieceBatteryLevel.low),
          label: '0-19%',
          detail: 'Emergency power',
          count: _countLevel(MovePieceBatteryLevel.low),
        ),
        _BatteryLegendRow(
          color: _batteryColor(context, MovePieceBatteryLevel.unknown),
          label: 'Unknown',
          detail: 'Powered off or not acquired',
          count: _countLevel(MovePieceBatteryLevel.unknown),
        ),
      ],
    );
  }

  int _countLevel(MovePieceBatteryLevel level) {
    return pieces.where((piece) => piece.level == level).length;
  }
}

class _BatteryLegendRow extends StatelessWidget {
  const _BatteryLegendRow({
    required this.color,
    required this.label,
    required this.detail,
    this.count,
  });

  final Color color;
  final String label;
  final String detail;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${count ?? 0}',
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      borderRadius: 999,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}
