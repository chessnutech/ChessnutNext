import 'dart:async';

import 'package:flutter/foundation.dart';

import '../l10n/localized_material.dart';

import '../models/app_models.dart';
import '../services/chess_clock_switch_service.dart';
import '../widgets/app_chrome.dart';

const _clockTimeFontFamily = 'Leslie';

class ChessClockScreen extends StatefulWidget {
  const ChessClockScreen({
    required this.onNavigate,
    required this.config,
    this.clockSwitchService,
    this.isChessnutClockDevice = false,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final OtbGameConfig config;
  final ChessClockSwitchService? clockSwitchService;
  final bool isChessnutClockDevice;

  @override
  State<ChessClockScreen> createState() => _ChessClockScreenState();
}

class _ChessClockScreenState extends State<ChessClockScreen> {
  bool running = false;
  bool gameStarted = false;
  bool topDisplayFlipped = false;
  bool whiteActive = true;
  ChessClockSide whiteDisplaySide = ChessClockSide.right;
  late int whiteSeconds;
  late int blackSeconds;
  late String _whitePlayerName;
  late String _blackPlayerName;
  String? resultText;
  Timer? timer;
  late final ChessClockSwitchService _clockSwitchService;
  late final bool _ownsClockSwitchService;
  StreamSubscription<int>? _clockSwitchSub;

  int get _initialSeconds => widget.config.timeMinutes * 60;
  int get _increment => widget.config.incrementSeconds;
  bool get _unlimited => widget.config.timeMinutes <= 0;
  bool get _canChooseSides => !running && !gameStarted && resultText == null;
  bool get _canAdjustPausedSides =>
      !running && gameStarted && resultText == null;
  ChessClockSide get _activeDisplaySide =>
      whiteActive ? whiteDisplaySide : whiteDisplaySide.opposite;

  @override
  void initState() {
    super.initState();
    _ownsClockSwitchService = widget.clockSwitchService == null;
    _clockSwitchService =
        widget.clockSwitchService ?? ChessClockSwitchService();
    _clockSwitchService.initialize();
    _clockSwitchSub =
        _clockSwitchService.switchEvents.listen(_handleClockSwitchEvent);
    whiteSeconds = _initialSeconds;
    blackSeconds = _initialSeconds;
    _whitePlayerName = 'White';
    _blackPlayerName = 'Black';
    unawaited(_syncPreStartSidesFromHardware());
  }

  @override
  void dispose() {
    timer?.cancel();
    unawaited(_clockSwitchSub?.cancel());
    if (_ownsClockSwitchService) {
      unawaited(_clockSwitchService.dispose());
    }
    super.dispose();
  }

  void _toggleRunning() {
    if (resultText != null) return;
    setState(() {
      running = !running;
      if (running) gameStarted = true;
    });
    timer?.cancel();
    if (!running) return;
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !running) return;
      setState(() {
        if (_unlimited) {
          if (whiteActive) {
            whiteSeconds = (whiteSeconds + 1).clamp(0, 999999);
          } else {
            blackSeconds = (blackSeconds + 1).clamp(0, 999999);
          }
          return;
        }
        if (whiteActive) {
          whiteSeconds = (whiteSeconds - 1).clamp(0, 999999);
          if (whiteSeconds == 0) _finishOnClock(whiteFlagged: true);
        } else {
          blackSeconds = (blackSeconds - 1).clamp(0, 999999);
          if (blackSeconds == 0) _finishOnClock(whiteFlagged: false);
        }
      });
    });
  }

  void _switchClock({bool syncHardware = false}) {
    if (!running || resultText != null) return;
    final movedSide = _activeDisplaySide;
    setState(() {
      if (!_unlimited && whiteActive) {
        whiteSeconds += _increment;
      } else if (!_unlimited) {
        blackSeconds += _increment;
      }
      whiteActive = !whiteActive;
    });
    if (syncHardware) {
      unawaited(_clockSwitchService.switchTo(movedSide));
    }
  }

  void _handleClockFaceTap(ChessClockSide side) {
    if (_canChooseSides) {
      _toggleDisplaySides(syncHardware: true);
      return;
    }
    if (_canAdjustPausedSides) {
      _setActiveDisplaySide(side, syncHardware: true);
      return;
    }
    if (running && side == _activeDisplaySide) {
      _switchClock(syncHardware: true);
    }
  }

  void _handleClockSwitchEvent(int sideValue) {
    if (!mounted || resultText != null) return;
    final pressedSide = ChessClockSide.fromValue(sideValue);
    if (pressedSide == null) return;
    if (_canChooseSides) {
      _setPreStartDisplaySidesFromPressedClockSide(pressedSide);
      return;
    }
    if (_canAdjustPausedSides) {
      _setActiveDisplaySide(pressedSide.opposite);
      return;
    }
    if (pressedSide != _activeDisplaySide) return;
    _switchClock();
  }

  void _setPreStartDisplaySidesFromPressedClockSide(
    ChessClockSide pressedSide,
  ) {
    setState(() {
      whiteDisplaySide = pressedSide.opposite;
      whiteActive = true;
    });
  }

  void _setActiveDisplaySide(
    ChessClockSide side, {
    bool syncHardware = false,
  }) {
    setState(() {
      whiteDisplaySide = whiteActive ? side : side.opposite;
    });
    if (syncHardware) {
      unawaited(_clockSwitchService.switchTo(side.opposite));
    }
  }

  void _toggleDisplaySides({required bool syncHardware}) {
    setState(() {
      whiteDisplaySide = whiteDisplaySide.opposite;
      whiteActive = true;
    });
    if (syncHardware) {
      unawaited(_clockSwitchService.switchTo(whiteDisplaySide.opposite));
    }
  }

  void _resetClockState() {
    timer?.cancel();
    setState(() {
      running = false;
      gameStarted = false;
      topDisplayFlipped = false;
      whiteActive = true;
      whiteSeconds = _initialSeconds;
      blackSeconds = _initialSeconds;
      resultText = null;
    });
    unawaited(_syncPreStartSidesFromHardware());
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset clock?'),
        content: const Text('Reset both clocks and start over.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset clock'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      _resetClockState();
    }
  }

  void _toggleTopDisplayFlip() {
    setState(() {
      topDisplayFlipped = !topDisplayFlipped;
    });
  }

  Future<void> _syncPreStartSidesFromHardware() async {
    final pressedSide = await _clockSwitchService.readLastSide();
    if (!mounted || pressedSide == null || !_canChooseSides) return;
    _setPreStartDisplaySidesFromPressedClockSide(pressedSide);
  }

  void _finishOnClock({required bool whiteFlagged}) {
    running = false;
    timer?.cancel();
    resultText = whiteFlagged
        ? '$_blackPlayerName wins on time'
        : '$_whitePlayerName wins on time';
  }

  Future<void> _editPlayerName({required bool isWhite}) async {
    if (running || resultText != null) return;
    final fallback = isWhite ? 'White' : 'Black';
    final controller = TextEditingController(
      text: isWhite ? _whitePlayerName : _blackPlayerName,
    );
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
    final updatedName = await showDialog<String>(
      context: context,
      useSafeArea: false,
      builder: (context) => _PlayerNameDialog(
        isWhite: isWhite,
        controller: controller,
        autofocus: true,
      ),
    );
    controller.dispose();
    if (!mounted || updatedName == null) return;
    final normalizedName = _normalizedPlayerName(updatedName, fallback);
    setState(() {
      if (isWhite) {
        _whitePlayerName = normalizedName;
      } else {
        _blackPlayerName = normalizedName;
      }
    });
  }

  String _normalizedPlayerName(String value, String fallback) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return normalized.isEmpty ? fallback : normalized;
  }

  Widget _buildClockFace({
    required ChessClockSide side,
    required bool compactLandscape,
    bool flipped = false,
  }) {
    final isWhite = side == whiteDisplaySide;
    final seconds = isWhite ? whiteSeconds : blackSeconds;
    final active = isWhite == whiteActive;
    final competitionMode = gameStarted || resultText != null;
    return _ClockFace(
      key: ValueKey(isWhite ? 'clock-face-white' : 'clock-face-black'),
      player: isWhite ? _whitePlayerName : _blackPlayerName,
      time: _formatClock(seconds),
      active: active,
      lowTime: !_unlimited && seconds <= 30,
      competition: competitionMode,
      compactLandscape: compactLandscape,
      choosingSides: _canChooseSides,
      flipped: flipped,
      onEditPlayer: !running && resultText == null
          ? () => _editPlayerName(isWhite: isWhite)
          : null,
      onTap: _canChooseSides || _canAdjustPausedSides || (running && active)
          ? () => _handleClockFaceTap(side)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final androidPhoneLandscape = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !widget.isChessnutClockDevice &&
        size.width > size.height &&
        size.width < 1000 &&
        size.height < 600;
    final macDesktopLandscape = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.macOS &&
        size.width > size.height &&
        size.width >= 900;
    final hideAndroidAppStatusCard = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !widget.isChessnutClockDevice;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) widget.onNavigate('Back');
      },
      child: ResponsivePage(
        compactLandscapeOverride: androidPhoneLandscape || macDesktopLandscape,
        children: (context, spec) {
          final landscape = spec.compactLandscape;
          final horizontalBoard = landscape || !spec.compact;
          final competitionMode = gameStarted || resultText != null;
          final showStatusCard =
              !landscape && !competitionMode && !hideAndroidAppStatusCard;
          final availableBoardHeight = spec.contentHeight -
              (!competitionMode ? 54 + spec.gutter : 0) -
              (showStatusCard ? 58 + spec.gutter : 0) -
              (landscape && resultText != null ? 42 : 0);
          final boardHeight = macDesktopLandscape
              ? availableBoardHeight.clamp(
                  0.0,
                  (size.height * 0.52).clamp(320.0, 720.0),
                )
              : availableBoardHeight;
          final pageChildren = <Widget>[
            if (!competitionMode) ...[
              _ClockHeader(
                compact: landscape,
                onBack: () => widget.onNavigate('Back'),
              ),
              SizedBox(height: spec.gutter),
            ],
            if (showStatusCard) ...[
              _ClockStatusCard(
                config: widget.config,
                resultText: resultText,
              ),
              SizedBox(height: spec.gutter),
            ],
            _ClockBoard(
              compact: spec.compact,
              compactLandscape: horizontalBoard,
              desktop: !landscape && !spec.compact,
              competition: competitionMode,
              resultText: resultText,
              spacing: spec.gutter,
              targetHeight: boardHeight.clamp(0, spec.contentHeight).toDouble(),
              leading: _buildClockFace(
                side: ChessClockSide.left,
                compactLandscape: horizontalBoard,
                flipped: !landscape && competitionMode && topDisplayFlipped,
              ),
              trailing: _buildClockFace(
                side: ChessClockSide.right,
                compactLandscape: horizontalBoard,
              ),
              controls: _ClockControls(
                running: running,
                gameOver: resultText != null,
                compact: spec.compact,
                compactLandscape: horizontalBoard,
                showExit: competitionMode,
                showFlipDisplay: !landscape && competitionMode,
                onBack: () => widget.onNavigate('Back'),
                onStartPause: _toggleRunning,
                onReset: _confirmReset,
                onFlipDisplay: _toggleTopDisplayFlip,
              ),
            ),
            if (landscape && resultText != null) ...[
              const SizedBox(height: 6),
              _ClockResultBanner(resultText: resultText!),
            ],
          ];
          if (!macDesktopLandscape) return pageChildren;

          return [
            Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                key: const ValueKey('clock-macos-content-frame'),
                width: (size.width * 0.84).clamp(840.0, 1680.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: pageChildren,
                ),
              ),
            ),
          ];
        },
      ),
    );
  }
}

class _PlayerNameDialog extends StatelessWidget {
  const _PlayerNameDialog({
    required this.isWhite,
    required this.controller,
    required this.autofocus,
  });

  final bool isWhite;
  final TextEditingController controller;
  final bool autofocus;

  void _submit(BuildContext context, String value) {
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final compactLandscape = isCompactLandscapeDevice(context);
    final horizontalInset = compactLandscape ? 14.0 : 24.0;
    final verticalInset = compactLandscape ? 10.0 : 24.0;
    final minDialogHeight = compactLandscape ? 128.0 : 206.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final keyboardAllowance =
            constraints.maxHeight - minDialogHeight - verticalInset * 2;
        final cappedKeyboardInset = keyboardAllowance <= 0
            ? 0.0
            : viewInsets.bottom.clamp(0.0, keyboardAllowance).toDouble();
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(
            horizontalInset,
            verticalInset,
            horizontalInset,
            verticalInset + cappedKeyboardInset,
          ),
          child: Align(
            alignment:
                viewInsets.bottom > 0 ? Alignment.topCenter : Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: compactLandscape ? 760 : 420,
              ),
              child: Material(
                color: Colors.transparent,
                child: GlassPanel(
                  key: const ValueKey('clock-player-name-dialog'),
                  borderRadius: 18,
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minDialogHeight),
                    child: compactLandscape
                        ? Row(
                            children: [
                              _PlayerNameDialogIcon(
                                isWhite: isWhite,
                                color: scheme.primary,
                                size: 44,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildNameField(
                                  context: context,
                                  height: 62,
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 108,
                                height: 54,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text(
                                    'Cancel',
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 108,
                                height: 54,
                                child: FilledButton(
                                  onPressed: () =>
                                      _submit(context, controller.text),
                                  child: const Text(
                                    'Save',
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    _PlayerNameDialogIcon(
                                      isWhite: isWhite,
                                      color: scheme.primary,
                                      size: 42,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        isWhite
                                            ? 'Edit white name'
                                            : 'Edit black name',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _buildNameField(context: context, height: 64),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text('Cancel'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: () =>
                                            _submit(context, controller.text),
                                        child: const Text('Save'),
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
      },
    );
  }

  Widget _buildNameField({
    required BuildContext context,
    required double height,
  }) {
    return SizedBox(
      key: const ValueKey('clock-player-name-input-frame'),
      height: height,
      child: TextField(
        key: const ValueKey('clock-player-name-input'),
        controller: controller,
        autofocus: autofocus,
        maxLines: 1,
        textInputAction: TextInputAction.done,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          labelText: isWhite ? 'White name' : 'Black name',
          prefixIcon: const Icon(Icons.person_rounded),
        ),
        onSubmitted: (value) => _submit(context, value),
      ),
    );
  }
}

class _PlayerNameDialogIcon extends StatelessWidget {
  const _PlayerNameDialogIcon({
    required this.isWhite,
    required this.color,
    required this.size,
  });

  final bool isWhite;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isWhite ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
        color: color,
      ),
    );
  }
}

class _ClockHeader extends StatelessWidget {
  const _ClockHeader({required this.compact, required this.onBack});

  final bool compact;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    if (!compact) {
      return ScreenHeader(
        title: 'Chess Clock',
        subtitle: 'OTB mode',
        leading: IconButton.filledTonal(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      );
    }

    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Chess Clock',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _ClockStatusCard extends StatelessWidget {
  const _ClockStatusCard({
    required this.config,
    required this.resultText,
  });

  final OtbGameConfig config;
  final String? resultText;

  @override
  Widget build(BuildContext context) {
    final resultText = this.resultText;
    if (resultText != null) {
      return _ClockResultBanner(resultText: resultText);
    }
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      child: Row(
        children: [
          _StatusBadge(
            icon: Icons.timer_rounded,
            label: 'Standalone clock',
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          _StatusBadge(
            icon: Icons.touch_app_rounded,
            label: 'Tap to switch',
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          _StatusBadge(
            icon: Icons.timer_rounded,
            label: config.timeMinutes <= 0
                ? 'Unlimited'
                : '+${config.incrementSeconds} sec increment',
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              config.timeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClockResultBanner extends StatelessWidget {
  const _ClockResultBanner({required this.resultText});

  final String resultText;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 14,
      child: Row(
        children: [
          Icon(
            Icons.emoji_events_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              resultText,
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

class _ClockBoard extends StatelessWidget {
  const _ClockBoard({
    required this.compact,
    required this.compactLandscape,
    required this.desktop,
    required this.competition,
    required this.resultText,
    required this.spacing,
    required this.targetHeight,
    required this.leading,
    required this.trailing,
    required this.controls,
  });

  final bool compact;
  final bool compactLandscape;
  final bool desktop;
  final bool competition;
  final String? resultText;
  final double spacing;
  final double targetHeight;
  final Widget leading;
  final Widget trailing;
  final Widget controls;

  @override
  Widget build(BuildContext context) {
    final controlDock = KeyedSubtree(
      key: const ValueKey('clock-control-dock'),
      child: controls,
    );
    if (compactLandscape || !compact) {
      return KeyedSubtree(
        key: const ValueKey('clock-landscape-board'),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenHeight = MediaQuery.sizeOf(context).height;
            final desktopMaxHeight =
                (screenHeight * 0.32).clamp(360.0, 460.0).toDouble();
            final availableHeight = desktop
                ? targetHeight.clamp(360.0, desktopMaxHeight).toDouble()
                : targetHeight.clamp(282.0, screenHeight).toDouble();
            return SizedBox(
              height: availableHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: leading),
                  SizedBox(width: spacing),
                  SizedBox(
                    width: desktop
                        ? (competition ? 124 : 138)
                        : (competition ? 104 : 138),
                    child: controlDock,
                  ),
                  SizedBox(width: spacing),
                  Expanded(child: trailing),
                ],
              ),
            );
          },
        ),
      );
    }

    if (compact) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final size = MediaQuery.sizeOf(context);
          final minHeight =
              competition ? (size.height < 520 ? size.height : 520.0) : 0.0;
          final availableHeight = targetHeight.clamp(minHeight, size.height);
          return SizedBox(
            key: const ValueKey('clock-vertical-board'),
            height: availableHeight.toDouble(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: leading),
                SizedBox(height: spacing),
                Expanded(child: trailing),
                const SizedBox(height: 10),
                controlDock,
                if (competition && resultText != null) ...[
                  const SizedBox(height: 8),
                  _ClockResultBanner(resultText: resultText!),
                ],
              ],
            ),
          );
        },
      );
    }

    return const SizedBox.shrink();
  }
}

class _ClockFace extends StatelessWidget {
  const _ClockFace({
    required this.player,
    required this.time,
    required this.active,
    required this.lowTime,
    required this.competition,
    required this.compactLandscape,
    required this.choosingSides,
    required this.flipped,
    required this.onEditPlayer,
    required this.onTap,
    super.key,
  });

  final String player;
  final String time;
  final bool active;
  final bool lowTime;
  final bool competition;
  final bool compactLandscape;
  final bool choosingSides;
  final bool flipped;
  final VoidCallback? onEditPlayer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = lowTime ? const Color(0xFFEF4444) : scheme.primary;
    final userNameStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
          fontSize: compactLandscape ? 34 : (competition ? 36 : 34),
          height: 1.05,
        );
    final statusStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: compactLandscape ? 18 : 17,
          fontWeight: FontWeight.w800,
          height: 1.1,
        );
    final playerLabel = Stack(
      alignment: Alignment.center,
      children: [
        Text(
          player,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: userNameStyle,
        ),
        if (onEditPlayer != null)
          Align(
            alignment: Alignment.centerRight,
            child: Icon(
              Icons.edit_rounded,
              size: compactLandscape ? 22 : 20,
              color: Theme.of(context).disabledColor,
            ),
          ),
      ],
    );
    final content = SizedBox.expand(
      child: Transform.rotate(
        key: ValueKey('clock-face-transform-$player'),
        angle: flipped ? 3.141592653589793 : 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onEditPlayer,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compactLandscape ? 18 : 12,
                  compactLandscape ? 10 : 12,
                  compactLandscape ? 18 : 12,
                  compactLandscape ? 4 : 8,
                ),
                child: playerLabel,
              ),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.center,
                child: Text(
                  time,
                  style: TextStyle(
                    fontSize: compactLandscape
                        ? (competition ? 118 : 104)
                        : (competition ? 116 : 94),
                    height: 0.95,
                    fontWeight: FontWeight.w800,
                    color: active ? color : null,
                    letterSpacing: 0,
                    fontFamily: _clockTimeFontFamily,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: 10,
                right: 10,
                bottom: compactLandscape ? 12 : 14,
              ),
              child: Text(
                choosingSides
                    ? 'Tap to choose sides'
                    : active
                        ? (competition ? 'Tap after move' : 'Ready')
                        : 'Waiting',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: statusStyle,
              ),
            ),
          ],
        ),
      ),
    );
    return GlassPanel(
      onTap: onTap,
      borderRadius: 18,
      padding: compactLandscape
          ? const EdgeInsets.symmetric(horizontal: 18, vertical: 10)
          : const EdgeInsets.all(14),
      tint: active ? color.withValues(alpha: 0.13) : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: compactLandscape ? 260 : (competition ? 0 : 180),
        ),
        child: content,
      ),
    );
  }
}

class _ClockControls extends StatelessWidget {
  const _ClockControls({
    required this.running,
    required this.gameOver,
    required this.compact,
    required this.compactLandscape,
    required this.showExit,
    required this.showFlipDisplay,
    required this.onBack,
    required this.onStartPause,
    required this.onReset,
    required this.onFlipDisplay,
  });

  final bool running;
  final bool gameOver;
  final bool compact;
  final bool compactLandscape;
  final bool showExit;
  final bool showFlipDisplay;
  final VoidCallback onBack;
  final VoidCallback onStartPause;
  final VoidCallback onReset;
  final VoidCallback onFlipDisplay;

  @override
  Widget build(BuildContext context) {
    if (compactLandscape) {
      return GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        borderRadius: 14,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (showExit)
              _RailClockButton(
                tooltip: 'Exit clock',
                icon: Icons.logout_rounded,
                onPressed: onBack,
              ),
            _RailClockButton(
              tooltip: gameOver ? 'Clock ended' : (running ? 'Pause' : 'Start'),
              icon: running ? Icons.pause_rounded : Icons.play_arrow_rounded,
              primary: true,
              onPressed: gameOver ? null : onStartPause,
            ),
            _RailClockButton(
              tooltip: 'Reset clock',
              icon: Icons.restart_alt_rounded,
              onPressed: onReset,
            ),
          ],
        ),
      );
    }

    return GlassPanel(
      padding: const EdgeInsets.all(10),
      borderRadius: 14,
      child: compact
          ? Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _AuxClockButton(
                  icon:
                      running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  label: running ? 'Pause' : 'Start',
                  onPressed: gameOver ? null : onStartPause,
                ),
                _AuxClockButton(
                  icon: Icons.restart_alt_rounded,
                  label: 'Reset',
                  onPressed: onReset,
                ),
                if (showExit)
                  _AuxClockButton(
                    icon: Icons.logout_rounded,
                    label: 'Exit clock',
                    onPressed: onBack,
                  ),
                if (showFlipDisplay)
                  _AuxClockButton(
                    icon: Icons.screen_rotation_alt_rounded,
                    label: 'Flip',
                    tooltip: 'Flip top clock display',
                    onPressed: onFlipDisplay,
                  ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: gameOver ? null : onStartPause,
                      icon: Icon(
                        running
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 24,
                      ),
                      label: Text(
                        running ? 'Pause' : 'Start',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox.square(
                  dimension: 52,
                  child: IconButton.filledTonal(
                    tooltip: 'Reset clock',
                    iconSize: 26,
                    onPressed: onReset,
                    icon: const Icon(Icons.restart_alt_rounded),
                  ),
                ),
                if (showExit) ...[
                  const SizedBox(width: 10),
                  SizedBox.square(
                    dimension: 52,
                    child: IconButton.filledTonal(
                      tooltip: 'Exit clock',
                      iconSize: 26,
                      onPressed: onBack,
                      icon: const Icon(Icons.logout_rounded),
                    ),
                  ),
                ],
                if (showFlipDisplay) ...[
                  const SizedBox(width: 10),
                  SizedBox.square(
                    dimension: 52,
                    child: IconButton.filledTonal(
                      tooltip: 'Flip top clock display',
                      iconSize: 26,
                      onPressed: onFlipDisplay,
                      icon: const Icon(Icons.screen_rotation_alt_rounded),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _RailClockButton extends StatelessWidget {
  const _RailClockButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.primary = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = scheme.primary;
    final dimension = primary ? 62.0 : 54.0;
    final child = primary
        ? IconButton.filled(
            tooltip: tooltip,
            iconSize: 32,
            padding: EdgeInsets.zero,
            onPressed: onPressed,
            icon: Icon(icon),
          )
        : IconButton.filledTonal(
            tooltip: tooltip,
            iconSize: 28,
            padding: EdgeInsets.zero,
            color: color,
            onPressed: onPressed,
            icon: Icon(icon),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox.square(dimension: dimension, child: child),
    );
  }
}

class _AuxClockButton extends StatelessWidget {
  const _AuxClockButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final button = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 96, minHeight: 52),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: 22),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
    );
    final tooltip = this.tooltip;
    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.visible,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatClock(int seconds) {
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  return '$minutes:${rest.toString().padLeft(2, '0')}';
}
