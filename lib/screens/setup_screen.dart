import 'dart:async';

import 'dart:math' as math;

import 'package:dartchess/dartchess.dart' as dc;
import 'package:flutter/foundation.dart';
import '../l10n/app_strings.dart';
import '../l10n/localized_material.dart';

import '../models/app_models.dart';
import '../services/board_vision_service.dart';
import '../services/board_settings_service.dart';
import '../services/board_editor_led_feedback.dart';
import '../services/chessnut_api_client.dart';
import '../services/lichess_board_service.dart';
import '../services/lc0_weight_library_service.dart';
import '../services/physical_board_gateway.dart';
import '../services/physical_board_orientation.dart';
import '../services/app_shared_preferences.dart';
import '../theme/chessnut_theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_feedback.dart';
import '../widgets/board_editor_en_passant.dart';
import '../widgets/chess_board.dart';
import '../widgets/lichess_authorization_dialog.dart';

class _TimeControlOption {
  const _TimeControlOption({
    required this.label,
    required this.minutes,
    required this.increment,
    required this.speed,
    this.custom = false,
  });

  final String label;
  final int minutes;
  final int increment;
  final String speed;
  final bool custom;

  String get apiPayload => 'time=$minutes, increment=$increment';
}

const List<_TimeControlOption> _lichessTimeControls = [
  _TimeControlOption(label: '10+0', minutes: 10, increment: 0, speed: 'Rapid'),
  _TimeControlOption(label: '10+5', minutes: 10, increment: 5, speed: 'Rapid'),
  _TimeControlOption(
      label: '15+10', minutes: 15, increment: 10, speed: 'Rapid'),
  _TimeControlOption(
      label: '30+0', minutes: 30, increment: 0, speed: 'Classical'),
  _TimeControlOption(
      label: '30+20', minutes: 30, increment: 20, speed: 'Classical'),
  _TimeControlOption(
      label: '45+45', minutes: 45, increment: 45, speed: 'Classical'),
];

const List<_TimeControlOption> _lichessFriendTimeControls = [
  _TimeControlOption(label: '3+0', minutes: 3, increment: 0, speed: 'Blitz'),
  _TimeControlOption(label: '3+2', minutes: 3, increment: 2, speed: 'Blitz'),
  _TimeControlOption(label: '5+0', minutes: 5, increment: 0, speed: 'Blitz'),
  _TimeControlOption(label: '5+3', minutes: 5, increment: 3, speed: 'Blitz'),
  ..._lichessTimeControls,
];

const _defaultTimeControl = _TimeControlOption(
    label: '10+5', minutes: 10, increment: 5, speed: 'Rapid');

enum _LichessMatchMode { random, friend }

// Temporary integration-test game. Remove this entry after the Lichess flow
// has been verified with the special game.
const _showTemporaryLichessGameEntry = false;
const _temporaryLichessGameId = 'nqHlzfMR';

const List<_TimeControlOption> _botTimeControls = [
  _TimeControlOption(
      label: 'Unlimited', minutes: 0, increment: 0, speed: 'Casual'),
  _TimeControlOption(label: '1+0', minutes: 1, increment: 0, speed: 'Bullet'),
  _TimeControlOption(label: '2+1', minutes: 2, increment: 1, speed: 'Bullet'),
  _TimeControlOption(label: '3+0', minutes: 3, increment: 0, speed: 'Blitz'),
  _TimeControlOption(label: '3+2', minutes: 3, increment: 2, speed: 'Blitz'),
  _TimeControlOption(label: '5+0', minutes: 5, increment: 0, speed: 'Blitz'),
  _TimeControlOption(label: '5+3', minutes: 5, increment: 3, speed: 'Blitz'),
  _TimeControlOption(label: '10+0', minutes: 10, increment: 0, speed: 'Rapid'),
  _TimeControlOption(label: '10+5', minutes: 10, increment: 5, speed: 'Rapid'),
  _TimeControlOption(
      label: '15+10', minutes: 15, increment: 10, speed: 'Rapid'),
  _TimeControlOption(
      label: '30+0', minutes: 30, increment: 0, speed: 'Classical'),
  _TimeControlOption(
      label: '30+20', minutes: 30, increment: 20, speed: 'Classical'),
];

enum _BotEngineOption { maia, maia3, stockfish, lc0 }

enum _BotStartingPositionOption { standard, opening, chess960, boardEditor }

enum _BotSideOption { random, white, black }

class _Lc0WeightOption {
  const _Lc0WeightOption({
    required this.key,
    required this.label,
    required this.path,
    required this.source,
    required this.ready,
  });

  final String key;
  final String label;
  final String path;
  final String source;
  final bool ready;

  String get fileName => path.split(RegExp(r'[\\/]')).last;
}

const _defaultLc0WeightOption = _Lc0WeightOption(
  key: defaultLc0WeightKey,
  label: defaultLc0WeightLabel,
  path: defaultLc0WeightPath,
  source: 'Built-in',
  ready: true,
);

const List<_Lc0WeightOption> _availableLc0Weights = [
  _defaultLc0WeightOption,
];

class _MaiaLevelOption {
  const _MaiaLevelOption(this.level, this.elo);

  final int level;
  final int elo;

  static const List<_MaiaLevelOption> levels = [
    _MaiaLevelOption(1, 1100),
    _MaiaLevelOption(2, 1200),
    _MaiaLevelOption(3, 1300),
    _MaiaLevelOption(4, 1400),
    _MaiaLevelOption(5, 1500),
    _MaiaLevelOption(6, 1600),
    _MaiaLevelOption(7, 1700),
    _MaiaLevelOption(8, 1800),
    _MaiaLevelOption(9, 1900),
  ];
}

const int _stockfishMinElo = 600;
const int _stockfishMaxElo = 3190;

const List<Duration> _stockfishThinkingTimes = [
  Duration(milliseconds: 100),
  Duration(milliseconds: 200),
  Duration(milliseconds: 300),
  Duration(milliseconds: 400),
  Duration(milliseconds: 500),
  Duration(milliseconds: 600),
  Duration(milliseconds: 700),
  Duration(milliseconds: 800),
  Duration(milliseconds: 900),
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 3),
  Duration(seconds: 4),
  Duration(seconds: 5),
  Duration(seconds: 6),
  Duration(seconds: 7),
  Duration(seconds: 8),
  Duration(seconds: 9),
  Duration(seconds: 10),
  Duration(seconds: 15),
  Duration(seconds: 20),
  Duration(seconds: 25),
  Duration(seconds: 30),
  Duration(seconds: 35),
  Duration(seconds: 40),
  Duration(seconds: 45),
  Duration(seconds: 50),
  Duration(seconds: 55),
  Duration(seconds: 60),
];

Future<void> _showTimeSelectionDialog({
  required BuildContext context,
  required _TimeControlOption initial,
  required String subtitle,
  required ValueChanged<_TimeControlOption> onSave,
}) async {
  final minutesController =
      TextEditingController(text: initial.minutes.toString());
  final incrementController =
      TextEditingController(text: initial.increment.toString());

  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (dialogContext) {
      return AppDialogShell(
        icon: Icons.timer_rounded,
        title: 'Custom time',
        subtitle: subtitle,
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () {
                final minutes = (int.tryParse(minutesController.text.trim()) ??
                        initial.minutes)
                    .clamp(1, 180);
                final increment =
                    (int.tryParse(incrementController.text.trim()) ??
                            initial.increment)
                        .clamp(0, 180);
                onSave(
                  _TimeControlOption(
                    label: 'Custom $minutes+$increment',
                    minutes: minutes,
                    increment: increment,
                    speed: _speedForTime(minutes, increment),
                    custom: true,
                  ),
                );
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Save'),
            ),
          ),
        ],
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: minutesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minutes',
                      prefixIcon: Icon(Icons.schedule_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: incrementController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Increment',
                      suffixText: 'sec',
                      prefixIcon: Icon(Icons.add_rounded),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Allowed range: 1-180 minutes and 0-180 seconds increment.',
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
          ],
        ),
      );
    },
  );
}

String _speedForTime(int minutes, int increment) {
  final estimatedSeconds = minutes * 60 + increment * 40;
  if (estimatedSeconds < 3 * 60) return 'Bullet';
  if (estimatedSeconds < 8 * 60) return 'Blitz';
  if (estimatedSeconds < 25 * 60) return 'Rapid';
  return 'Classical';
}

class SetupScreen extends StatelessWidget {
  const SetupScreen({
    required this.onNavigate,
    required this.onLaunchGame,
    this.boardGateway,
    this.isChessnutClockDevice = false,
    this.hidePhysicalBoardConnectionUi = false,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final LaunchGameCallback onLaunchGame;
  final PhysicalBoardGateway? boardGateway;
  final bool isChessnutClockDevice;
  final bool hidePhysicalBoardConnectionUi;

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      children: (context, spec) {
        final moveBoardResetAvailable = !kIsWeb &&
            const {
              TargetPlatform.android,
              TargetPlatform.iOS,
              TargetPlatform.windows,
              TargetPlatform.macOS,
            }.contains(defaultTargetPlatform) &&
            boardGateway?.boardModel == PhysicalBoardModel.move &&
            boardGateway?.currentState ==
                PhysicalBoardConnectionState.connected;
        final compactLandscape = spec.compactLandscape;
        final windowsLandscape = !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.windows &&
            spec.width >= 1200 &&
            spec.width > spec.height;
        final landscapeLayout = compactLandscape || windowsLandscape;
        final landscapeHeight = windowsLandscape
            ? (spec.heightAfterHeader() * 0.5).clamp(372.0, 520.0).toDouble()
            : spec.heightAfterHeader(min: 372);
        final pathCards = <Widget>[
          _PathCard(
            key: const ValueKey('path-online'),
            icon: Icons.wifi_rounded,
            label: landscapeLayout ? null : 'RECOMMENDED',
            title: 'Find an online match',
            subtitle: 'Lichess native seek or Chess.com WebView.',
            badge: 'Online',
            selected: true,
            large: !landscapeLayout,
            compactLandscape: landscapeLayout,
            desktopLandscape: windowsLandscape,
            onTap: () => onNavigate('Online'),
          ),
          _PathCard(
            key: const ValueKey('path-bot'),
            icon: Icons.smart_toy_rounded,
            title: 'Bot game',
            subtitle: 'Engine practice and openings.',
            badge: 'Engine',
            compactLandscape: landscapeLayout,
            desktopLandscape: windowsLandscape,
            onTap: () => onNavigate('Bot'),
          ),
          _PathCard(
            key: const ValueKey('path-otb'),
            icon: Icons.people_alt_rounded,
            title: 'OTB Game',
            subtitle: 'Record game or use board clock.',
            badge: 'OTB',
            compactLandscape: landscapeLayout,
            desktopLandscape: windowsLandscape,
            onTap: () => onNavigate('OtbSetup'),
          ),
          _PathCard(
            key: const ValueKey('path-editor'),
            icon: Icons.dashboard_customize_rounded,
            title: 'Board Editor',
            subtitle: 'Sync board or import FEN.',
            badge: 'FEN',
            compactLandscape: landscapeLayout,
            desktopLandscape: windowsLandscape,
            onTap: () => onNavigate('Editor'),
          ),
        ];

        return [
          ScreenHeader(
            title: 'Choose path',
            subtitle: 'New game',
            leading: IconButton.filledTonal(
              onPressed: () => onNavigate('Back'),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            trailing: hidePhysicalBoardConnectionUi
                ? null
                : moveBoardResetAvailable
                    ? _MoveBoardResetBadge(gateway: boardGateway!)
                    : _StatusBadge(
                        icon: Icons.sensors_rounded,
                        label: 'Ready',
                        color: Theme.of(context).colorScheme.primary,
                      ),
          ),
          SizedBox(height: spec.gutter),
          if (landscapeLayout)
            _CompanionLandscapePathLayout(
              key: windowsLandscape
                  ? const ValueKey('setup-windows-landscape-layout')
                  : null,
              spacing: spec.gutter,
              height: landscapeHeight,
              cards: pathCards,
            )
          else
            SectionColumn(
              spacing: 12,
              children: [
                pathCards.first,
                ResponsiveGrid(
                  minTileWidth: spec.compact ? 300 : 220,
                  maxColumns: spec.expanded ? 3 : 3,
                  childAspectRatio: spec.compact ? 3.15 : 1.55,
                  children: pathCards.skip(1).toList(growable: false),
                ),
              ],
            ),
        ];
      },
    );
  }
}

class _CompanionLandscapePathLayout extends StatelessWidget {
  const _CompanionLandscapePathLayout({
    required this.spacing,
    required this.height,
    required this.cards,
    super.key,
  });

  final double spacing;
  final double height;
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 5, child: cards.first),
          SizedBox(width: spacing),
          Expanded(
            flex: 7,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: cards[1]),
                      SizedBox(width: spacing),
                      Expanded(child: cards[2]),
                    ],
                  ),
                ),
                SizedBox(height: spacing),
                Expanded(child: cards[3]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BotSetupScreen extends StatefulWidget {
  const BotSetupScreen({
    required this.onNavigate,
    required this.onLaunchGame,
    this.initialConfig,
    this.boardEditorFen = chessnutStandardStartFen,
    this.boardEditorRequestId = 0,
    this.boardGateway,
    this.boardSettings = const BoardSettingsState(),
    this.apiClient,
    this.lc0WeightLibraryStore,
    this.imagePicker,
    this.showBoardCoordinates = false,
    this.isChessnutClockDevice = false,
    this.hidePhysicalBoardConnectionUi = false,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final LaunchGameCallback onLaunchGame;
  final BotGameConfig? initialConfig;
  final String boardEditorFen;
  final int boardEditorRequestId;
  final PhysicalBoardGateway? boardGateway;
  final BoardSettingsState boardSettings;
  final ChessnutApiClient? apiClient;
  final Lc0WeightLibraryStore? lc0WeightLibraryStore;
  final BoardVisionImagePicker? imagePicker;
  final bool showBoardCoordinates;
  final bool isChessnutClockDevice;
  final bool hidePhysicalBoardConnectionUi;

  @override
  State<BotSetupScreen> createState() => _BotSetupScreenState();
}

class _BotSetupScreenState extends State<BotSetupScreen> {
  _BotEngineOption engine = _BotEngineOption.maia;
  _BotStartingPositionOption startingPosition =
      _BotStartingPositionOption.standard;
  _BotSideOption side = _BotSideOption.random;
  _MaiaLevelOption maiaLevel = _MaiaLevelOption.levels[4];
  int maia3Elo = 1500;
  MaiaSearchStyle maiaSearchStyle = MaiaSearchStyle.balanced;
  int maiaSearchDepth = 1;
  int stockfishElo = 1320;
  Duration stockfishThinkingTime = Duration.zero;
  _Lc0WeightOption selectedLc0Weight = _defaultLc0WeightOption;
  List<_Lc0WeightOption> availableLc0Weights = _availableLc0Weights;
  _TimeControlOption selectedTime = _defaultTimeControl;
  bool useOpeningTraining = false;
  OpeningScenario selectedOpening = botOpeningScenarios[1];
  String boardEditorFen = chessnutStandardStartFen;
  Set<String> favoriteOpeningIds = const {};
  int _handledBoardEditorRequestId = 0;
  bool showPgnList = true;

  @override
  void initState() {
    super.initState();
    boardEditorFen =
        _normalizeBotFen(widget.boardEditorFen) ?? chessnutStandardStartFen;
    _handledBoardEditorRequestId = widget.boardEditorRequestId;
    _applyInitialConfig(widget.initialConfig);
    _loadLc0Weights();
    if (widget.boardEditorRequestId > 0) {
      _applyBoardEditorRequest();
    }
    favoriteOpeningIds = AppSharedPreferences.get<List<String>>(
      AppSettingKeys.favoriteOpeningIds,
    ).toSet();
  }

  Future<void> _toggleFavoriteOpening(String id) async {
    final next = Set<String>.from(favoriteOpeningIds);
    if (!next.add(id)) next.remove(id);
    setState(() => favoriteOpeningIds = next);
    AppSharedPreferences.set<List<String>>(
      AppSettingKeys.favoriteOpeningIds,
      next.toList(growable: false),
    );
  }

  Future<void> _loadLc0Weights() async {
    final store = widget.lc0WeightLibraryStore;
    if (store == null) return;
    final entries = await store.list();
    if (!mounted) return;
    setState(() {
      availableLc0Weights = entries.map(_lc0WeightFromLibraryEntry).toList();
      selectedLc0Weight = _lc0WeightFromConfig(
        widget.initialConfig ?? _configFromCurrentState(),
      );
    });
  }

  @override
  void didUpdateWidget(covariant BotSetupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final initialConfigChanged =
        oldWidget.initialConfig != widget.initialConfig;
    final editorFenChanged = oldWidget.boardEditorFen != widget.boardEditorFen;
    final editorRequestChanged =
        widget.boardEditorRequestId != _handledBoardEditorRequestId;
    if (initialConfigChanged) {
      _applyInitialConfig(widget.initialConfig);
    }
    if (editorFenChanged) {
      boardEditorFen =
          _normalizeBotFen(widget.boardEditorFen) ?? boardEditorFen;
    }
    if (editorRequestChanged) {
      _handledBoardEditorRequestId = widget.boardEditorRequestId;
      boardEditorFen =
          _normalizeBotFen(widget.boardEditorFen) ?? boardEditorFen;
    }
    if (widget.boardEditorRequestId > 0 &&
        (initialConfigChanged || editorFenChanged || editorRequestChanged)) {
      _applyBoardEditorRequest();
    }
  }

  void _applyBoardEditorRequest() {
    _applySideFromBoardEditorFen(boardEditorFen);
    startingPosition = _BotStartingPositionOption.boardEditor;
    useOpeningTraining = false;
    if (selectedTime.minutes == 0 && selectedTime.increment == 0) {
      selectedTime = _defaultTimeControl;
    }
  }

  void _applyInitialConfig(BotGameConfig? config) {
    if (config == null) return;
    engine = switch (config.engineKind) {
      BotEngineKind.maia => _BotEngineOption.maia,
      BotEngineKind.maia3 => _BotEngineOption.maia3,
      BotEngineKind.stockfish => _BotEngineOption.stockfish,
      BotEngineKind.lc0 => _BotEngineOption.lc0,
    };
    side = switch (config.playerSidePreference ?? config.playerSide) {
      BotPlayerSide.random => _BotSideOption.random,
      BotPlayerSide.white => _BotSideOption.white,
      BotPlayerSide.black => _BotSideOption.black,
    };
    final maiaIndex = _MaiaLevelOption.levels.indexWhere(
      (level) => level.elo == config.maiaElo,
    );
    maiaLevel = maiaIndex < 0
        ? _MaiaLevelOption.levels[4]
        : _MaiaLevelOption.levels[maiaIndex];
    maia3Elo = config.maiaElo.clamp(maia3MinElo, maia3MaxElo).toInt();
    maiaSearchStyle = config.maiaSearchStyle;
    maiaSearchDepth = config.maiaSearchDepth.clamp(1, 4).toInt();
    stockfishElo = config.stockfishElo.clamp(600, 3190).toInt();
    stockfishThinkingTime = config.stockfishThinkingTime;
    selectedLc0Weight = _lc0WeightFromConfig(config);
    selectedTime = _timeControlFromConfig(config);
    startingPosition = config.chess960
        ? _BotStartingPositionOption.chess960
        : _isBoardEditorOpeningScenario(config.opening)
            ? _BotStartingPositionOption.boardEditor
            : _BotStartingPositionOption.standard;
    if (_isBoardEditorOpeningScenario(config.opening)) {
      boardEditorFen = config.startFen;
    }
    selectedOpening = _isChess960OpeningScenario(config.opening)
        ? botOpeningScenarios[1]
        : config.opening;
    useOpeningTraining = !config.chess960 &&
        !_isBoardEditorOpeningScenario(config.opening) &&
        !selectedOpening.isStandard;
    if (useOpeningTraining) {
      startingPosition = _BotStartingPositionOption.opening;
    }
    showPgnList = config.showPgnList;
  }

  void _applySideFromBoardEditorFen(String fen) {
    final fields = fen.trim().split(RegExp(r'\s+'));
    if (fields.length < 2) return;
    side = fields[1] == 'b' ? _BotSideOption.black : _BotSideOption.white;
  }

  _TimeControlOption _timeControlFromConfig(BotGameConfig config) {
    for (final option in _botTimeControls) {
      if (option.minutes == config.timeMinutes &&
          option.increment == config.incrementSeconds) {
        return option;
      }
    }
    return _TimeControlOption(
      label: 'Custom ${config.timeMinutes}+${config.incrementSeconds}',
      minutes: config.timeMinutes,
      increment: config.incrementSeconds,
      speed: 'Custom',
      custom: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      preserveLayoutWhenKeyboardVisible: true,
      children: (context, spec) {
        final compactLandscape = spec.compactLandscape;
        final windowsLandscape = !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.windows &&
            spec.width >= 1200 &&
            spec.width > spec.height;
        final macosLandscape = !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.macOS &&
            spec.width > spec.height &&
            spec.height > 560;
        final landscapeLayout = compactLandscape || windowsLandscape;
        return [
          ScreenHeader(
            title: 'Choose bot',
            subtitle: 'Bot game',
            leading: IconButton.filledTonal(
              onPressed: () => widget.onNavigate('Back'),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          SizedBox(height: spec.gutter),
          if (landscapeLayout)
            _CompanionLandscapeBotSetupLayout(
              key: const ValueKey('bot-setup-landscape-layout'),
              spacing: spec.gutter,
              height: spec.heightAfterHeader(min: 372),
              stretchEngine: !windowsLandscape,
              matchRightContentHeight: macosLandscape,
              engine: _BotEngineSection(
                key: const ValueKey('bot-setup-engine-panel'),
                selected: engine,
                onSelect: _selectEngine,
                compactLandscape: compactLandscape,
              ),
              startingPosition: _StartingPositionSection(
                key: const ValueKey('bot-setup-starting-panel'),
                selected: startingPosition,
                selectedOpening: selectedOpening,
                onSelectStandard: () => _selectStartingPosition(
                  _BotStartingPositionOption.standard,
                ),
                onSelectOpening: () => _selectStartingPosition(
                  _BotStartingPositionOption.opening,
                ),
                onSelectChess960: () => _selectStartingPosition(
                  _BotStartingPositionOption.chess960,
                ),
                onSelectBoardEditor: _showBoardEditorModal,
                onChooseOpening: _showOpeningPicker,
              ),
              playSettings: _BotPlaySettingsCard(
                key: const ValueKey('bot-setup-play-settings-panel'),
                side: side,
                onSideChanged: (value) => setState(() => side = value),
              ),
              pgnListSetting: widget.isChessnutClockDevice
                  ? _BotPgnListSetting(
                      value: showPgnList,
                      onChanged: (value) => setState(() => showPgnList = value),
                    )
                  : const SizedBox.shrink(),
              timeControl: _TimeControlCard(
                key: const ValueKey('bot-setup-time-control-panel'),
                selected: selectedTime,
                options: _botTimeControls,
                onSelected: (option) => setState(() {
                  selectedTime = option;
                  if (option.minutes == 0) {
                    stockfishThinkingTime = Duration.zero;
                  }
                }),
                onCustom: () => _showTimeSelectionDialog(
                  context: context,
                  initial: selectedTime,
                  subtitle:
                      'Bot game time uses minutes plus increment seconds.',
                  onSave: (value) => setState(() => selectedTime = value),
                ),
                footerBuilder: null,
              ),
              startButton: PrimaryButton(
                label: 'Start bot game',
                icon: Icons.play_arrow_rounded,
                onPressed: () => widget.onLaunchGame(
                  GameLaunchMode.bot,
                  botConfig: _buildBotConfig(),
                ),
              ),
            )
          else
            ResponsiveSplit(
              breakpoint: 880,
              spacing: spec.gutter,
              leadingFlex: 6,
              trailingFlex: 5,
              leading: SectionColumn(
                spacing: 12,
                children: [
                  _BotEngineSection(
                    key: const ValueKey('bot-setup-engine-panel'),
                    selected: engine,
                    onSelect: _selectEngine,
                  ),
                  _StartingPositionSection(
                    key: const ValueKey('bot-setup-starting-panel'),
                    selected: startingPosition,
                    selectedOpening: selectedOpening,
                    onSelectStandard: () => _selectStartingPosition(
                      _BotStartingPositionOption.standard,
                    ),
                    onSelectOpening: () => _selectStartingPosition(
                      _BotStartingPositionOption.opening,
                    ),
                    onSelectChess960: () => _selectStartingPosition(
                      _BotStartingPositionOption.chess960,
                    ),
                    onSelectBoardEditor: _showBoardEditorModal,
                    onChooseOpening: _showOpeningPicker,
                  ),
                  _BotPlaySettingsCard(
                    key: const ValueKey('bot-setup-play-settings-panel'),
                    side: side,
                    onSideChanged: (value) => setState(() => side = value),
                  ),
                  if (widget.isChessnutClockDevice)
                    _BotPgnListSetting(
                      value: showPgnList,
                      onChanged: (value) => setState(() => showPgnList = value),
                    ),
                ],
              ),
              trailing: SectionColumn(
                spacing: 12,
                children: [
                  _TimeControlCard(
                    key: const ValueKey('bot-setup-time-control-panel'),
                    selected: selectedTime,
                    options: _botTimeControls,
                    onSelected: (option) => setState(() {
                      selectedTime = option;
                      if (option.minutes == 0) {
                        stockfishThinkingTime = Duration.zero;
                      }
                    }),
                    onCustom: () => _showTimeSelectionDialog(
                      context: context,
                      initial: selectedTime,
                      subtitle:
                          'Bot game time uses minutes plus increment seconds.',
                      onSave: (value) => setState(() => selectedTime = value),
                    ),
                    footerBuilder: null,
                  ),
                  PrimaryButton(
                    label: 'Start bot game',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () => widget.onLaunchGame(
                      GameLaunchMode.bot,
                      botConfig: _buildBotConfig(),
                    ),
                  ),
                ],
              ),
            ),
        ];
      },
    );
  }

  BotGameConfig _buildBotConfig() {
    final selectedMaiaElo =
        engine == _BotEngineOption.maia3 ? maia3Elo : maiaLevel.elo;
    final engineLabel = switch (engine) {
      _BotEngineOption.maia => 'Maia ${maiaLevel.elo}',
      _BotEngineOption.maia3 => 'Maia 3 $maia3Elo',
      _BotEngineOption.stockfish => 'Stockfish $stockfishElo',
      _BotEngineOption.lc0 => 'LC0 ${selectedLc0Weight.label}',
    };
    final timeLabel =
        selectedTime.label == 'Unlimited' ? 'Unlimited' : selectedTime.label;
    final openingScenario = _buildOpeningScenario();
    final sideLabel = switch (side) {
      _BotSideOption.random => 'Random side',
      _BotSideOption.white => 'White side',
      _BotSideOption.black => 'Black side',
    };
    final turnLabel = switch (side) {
      _BotSideOption.random => 'Random to move',
      _BotSideOption.white => 'White to move',
      _BotSideOption.black => 'Black to move',
    };
    final evalText = switch (engine) {
      _BotEngineOption.maia => '+0.4',
      _BotEngineOption.maia3 => '+0.4',
      _BotEngineOption.stockfish => stockfishElo >= 2000 ? '+0.1' : '+0.4',
      _BotEngineOption.lc0 => '+0.2',
    };
    return BotGameConfig(
      title: '$engineLabel / $timeLabel',
      subtitle: '${openingScenario.name} / $sideLabel',
      opponent: engineLabel,
      opponentSource: switch (engine) {
        _BotEngineOption.maia =>
          '${openingScenario.focus} / ELO ${maiaLevel.elo}',
        _BotEngineOption.maia3 => 'Cloud human model / ELO $maia3Elo',
        _BotEngineOption.stockfish =>
          '${openingScenario.moves} / thinking ${_formatThinking(stockfishThinkingTime)}',
        _BotEngineOption.lc0 =>
          '${openingScenario.eco} / ${selectedLc0Weight.label}',
      },
      playerSource:
          '$sideLabel / ${openingScenario.eco} / coach ${engine == _BotEngineOption.stockfish ? 'off' : 'on'}',
      turn: turnLabel,
      eval: evalText,
      engineKind: switch (engine) {
        _BotEngineOption.maia => BotEngineKind.maia,
        _BotEngineOption.maia3 => BotEngineKind.maia3,
        _BotEngineOption.stockfish => BotEngineKind.stockfish,
        _BotEngineOption.lc0 => BotEngineKind.lc0,
      },
      playerSide: switch (side) {
        _BotSideOption.random => DateTime.now().millisecond.isEven
            ? BotPlayerSide.white
            : BotPlayerSide.black,
        _BotSideOption.white => BotPlayerSide.white,
        _BotSideOption.black => BotPlayerSide.black,
      },
      playerSidePreference: switch (side) {
        _BotSideOption.random => BotPlayerSide.random,
        _BotSideOption.white => BotPlayerSide.white,
        _BotSideOption.black => BotPlayerSide.black,
      },
      timeMinutes: selectedTime.minutes,
      incrementSeconds: selectedTime.increment,
      stockfishElo: stockfishElo,
      stockfishThinkingTime: stockfishThinkingTime,
      maiaElo: selectedMaiaElo,
      maiaSearchStyle: maiaSearchStyle,
      maiaSearchDepth: maiaSearchDepth,
      lc0WeightKey: selectedLc0Weight.key,
      lc0WeightLabel: selectedLc0Weight.label,
      lc0WeightPath: selectedLc0Weight.path,
      opening: openingScenario,
      startFen: openingScenario.fen,
      chess960: startingPosition == _BotStartingPositionOption.chess960,
      showPgnList: showPgnList,
    );
  }

  OpeningScenario _buildOpeningScenario() {
    if (startingPosition == _BotStartingPositionOption.boardEditor) {
      return OpeningScenario(
        id: 'board-editor-fen',
        name: 'FEN position',
        eco: 'FEN',
        moves: 'Board editor',
        fen: boardEditorFen,
        focus: 'Custom position',
      );
    }
    if (startingPosition == _BotStartingPositionOption.chess960) {
      return _randomChess960OpeningScenario();
    }
    if (startingPosition == _BotStartingPositionOption.opening &&
        !_isChess960OpeningScenario(selectedOpening)) {
      return selectedOpening;
    }
    return standardOpeningScenario;
  }

  void _selectStartingPosition(_BotStartingPositionOption value) {
    setState(() {
      startingPosition = value;
      useOpeningTraining = value == _BotStartingPositionOption.opening;
      if (value == _BotStartingPositionOption.standard ||
          value == _BotStartingPositionOption.chess960) {
        if (_isChess960OpeningScenario(selectedOpening)) {
          selectedOpening = botOpeningScenarios[1];
        }
        useOpeningTraining = false;
      }
      if (value == _BotStartingPositionOption.opening &&
          _isChess960OpeningScenario(selectedOpening)) {
        selectedOpening = botOpeningScenarios[1];
      }
    });
  }

  void _selectEngine(_BotEngineOption value) {
    setState(() => engine = value);
    _showEngineStrengthDialog(value);
  }

  Future<void> _showEngineStrengthDialog(_BotEngineOption selectedEngine) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void update(VoidCallback change) {
              setState(change);
              setDialogState(() {});
            }

            return AppDialogShell(
              icon: _engineIcon(selectedEngine),
              title: _engineStrengthTitle(selectedEngine),
              actions: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Done'),
                  ),
                ),
              ],
              child: _BotEngineDetailContent(
                engine: selectedEngine,
                maiaLevel: maiaLevel,
                maia3Elo: maia3Elo,
                maiaSearchStyle: maiaSearchStyle,
                maiaSearchDepth: maiaSearchDepth,
                stockfishElo: stockfishElo,
                stockfishThinkingTime: stockfishThinkingTime,
                selectedLc0Weight: selectedLc0Weight,
                availableLc0Weights: availableLc0Weights,
                onMaiaLevelChange: (value) => update(() => maiaLevel = value),
                onMaia3EloChange: (value) => update(() => maia3Elo = value),
                onMaiaSearchStyleChange: (value) =>
                    update(() => maiaSearchStyle = value),
                onMaiaSearchDepthChange: (value) =>
                    update(() => maiaSearchDepth = value),
                onStockfishEloChange: (value) =>
                    update(() => stockfishElo = value),
                onStockfishThinkingTimeChange: (value) =>
                    update(() => stockfishThinkingTime = value),
                onLc0WeightChange: (value) =>
                    update(() => selectedLc0Weight = value),
                onManageEngineLab: () {
                  Navigator.of(dialogContext).pop();
                  widget.onNavigate('Engine');
                },
              ),
            );
          },
        );
      },
    );
  }

  IconData _engineIcon(_BotEngineOption option) {
    return switch (option) {
      _BotEngineOption.maia => Icons.psychology_rounded,
      _BotEngineOption.maia3 => Icons.cloud_queue_rounded,
      _BotEngineOption.stockfish => Icons.memory_rounded,
      _BotEngineOption.lc0 => Icons.bolt_rounded,
    };
  }

  String _engineStrengthTitle(_BotEngineOption option) {
    return switch (option) {
      _BotEngineOption.maia => 'Maia strength',
      _BotEngineOption.maia3 => 'Maia 3 strength',
      _BotEngineOption.stockfish => 'Stockfish strength',
      _BotEngineOption.lc0 => 'LC0 profile',
    };
  }

  Future<void> _showBoardEditorModal({bool openInFenMode = false}) async {
    final mediaSize = MediaQuery.sizeOf(context);
    final landscape = mediaSize.width > mediaSize.height &&
        mediaSize.height <= 620 &&
        mediaSize.width >= 700;
    final fen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      constraints:
          landscape ? BoxConstraints(maxWidth: mediaSize.width - 32) : null,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        BotBoardEditorSheet editor(ScrollController? scrollController) {
          return BotBoardEditorSheet(
            initialFen: boardEditorFen,
            boardGateway: widget.boardGateway,
            boardSettings: widget.boardSettings,
            imagePicker: widget.imagePicker,
            isChessnutClockDevice: widget.isChessnutClockDevice,
            showBoardCoordinates: widget.showBoardCoordinates,
            hidePhysicalBoardConnectionUi: widget.hidePhysicalBoardConnectionUi,
            openInFenMode: openInFenMode,
            scrollController: scrollController,
          );
        }

        if (landscape) return editor(null);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          minChildSize: 0.6,
          maxChildSize: 0.98,
          builder: (context, scrollController) => editor(scrollController),
        );
      },
    );
    if (!mounted || fen == null) return;
    setState(() {
      boardEditorFen = fen;
      _applySideFromBoardEditorFen(fen);
      startingPosition = _BotStartingPositionOption.boardEditor;
      useOpeningTraining = false;
      if (_isChess960OpeningScenario(selectedOpening)) {
        selectedOpening = botOpeningScenarios[1];
      }
    });
  }

  Future<void> _showOpeningPicker() async {
    final selected = await showDialog<OpeningScenario>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => _OpeningPickerDialog(
        selected: selectedOpening,
        favoriteOpeningIds: favoriteOpeningIds,
        onToggleFavorite: _toggleFavoriteOpening,
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      selectedOpening = selected;
      useOpeningTraining = true;
      startingPosition = _BotStartingPositionOption.opening;
    });
  }

  String _formatThinking(Duration duration) {
    if (duration == Duration.zero) return 'auto';
    if (duration.inMilliseconds < 1000) return '${duration.inMilliseconds}ms';
    final seconds = duration.inSeconds;
    if (seconds < 60) return '${seconds}s';
    return '${seconds ~/ 60}m';
  }

  _Lc0WeightOption _lc0WeightFromConfig(BotGameConfig config) {
    for (final weight in availableLc0Weights) {
      if (weight.key == config.lc0WeightKey ||
          weight.path == config.lc0WeightPath) {
        return weight;
      }
    }
    if (config.lc0WeightPath.isEmpty) return _defaultLc0WeightOption;
    return _Lc0WeightOption(
      key: config.lc0WeightKey,
      label: config.lc0WeightLabel,
      path: config.lc0WeightPath,
      source: 'Local file',
      ready: true,
    );
  }

  BotGameConfig _configFromCurrentState() {
    return const BotGameConfig.defaultConfig().copyWith(
      engineKind: switch (engine) {
        _BotEngineOption.maia => BotEngineKind.maia,
        _BotEngineOption.maia3 => BotEngineKind.maia3,
        _BotEngineOption.stockfish => BotEngineKind.stockfish,
        _BotEngineOption.lc0 => BotEngineKind.lc0,
      },
      lc0WeightKey: selectedLc0Weight.key,
      lc0WeightLabel: selectedLc0Weight.label,
      lc0WeightPath: selectedLc0Weight.path,
    );
  }
}

_Lc0WeightOption _lc0WeightFromLibraryEntry(Lc0WeightLibraryEntry entry) {
  return _Lc0WeightOption(
    key: entry.key,
    label: entry.label,
    path: entry.path,
    source: entry.source,
    ready: true,
  );
}

OpeningScenario _randomChess960OpeningScenario({math.Random? random}) {
  final rng = random ?? math.Random();
  final pieces = List<String>.filled(8, '');
  final darkSquares = [0, 2, 4, 6];
  final lightSquares = [1, 3, 5, 7];
  final firstBishop = darkSquares[rng.nextInt(darkSquares.length)];
  final secondBishop = lightSquares[rng.nextInt(lightSquares.length)];
  pieces[firstBishop] = 'B';
  pieces[secondBishop] = 'B';

  final emptyAfterBishops = _emptyIndexes(pieces);
  pieces[emptyAfterBishops[rng.nextInt(emptyAfterBishops.length)]] = 'Q';

  final emptyAfterQueen = _emptyIndexes(pieces);
  final firstKnightIndex = rng.nextInt(emptyAfterQueen.length);
  pieces[emptyAfterQueen[firstKnightIndex]] = 'N';
  final emptyAfterFirstKnight = _emptyIndexes(pieces);
  pieces[emptyAfterFirstKnight[rng.nextInt(emptyAfterFirstKnight.length)]] =
      'N';

  final remaining = _emptyIndexes(pieces)..sort();
  pieces[remaining[0]] = 'R';
  pieces[remaining[1]] = 'K';
  pieces[remaining[2]] = 'R';
  return _chess960OpeningScenarioFromBackRank(pieces.join());
}

List<int> _emptyIndexes(List<String> pieces) {
  return [
    for (var index = 0; index < pieces.length; index += 1)
      if (pieces[index].isEmpty) index,
  ];
}

OpeningScenario _chess960OpeningScenarioFromBackRank(String backRank) {
  final whiteBackRank = backRank.toUpperCase();
  final blackBackRank = backRank.toLowerCase();
  final queenSideRook = whiteBackRank.indexOf('R');
  final kingSideRook = whiteBackRank.lastIndexOf('R');
  const files = 'abcdefgh';
  final castlingRights = '${files[kingSideRook].toUpperCase()}'
      '${files[queenSideRook].toUpperCase()}'
      '${files[kingSideRook]}'
      '${files[queenSideRook]}';
  return OpeningScenario(
    id: 'chess960-$whiteBackRank',
    name: 'Chess960',
    eco: '960',
    moves: 'Randomized back rank $whiteBackRank',
    fen:
        '$blackBackRank/pppppppp/8/8/8/8/PPPPPPPP/$whiteBackRank w $castlingRights - 0 1',
    focus: 'Fischer random start',
  );
}

bool _isChess960OpeningScenario(OpeningScenario opening) {
  return opening.id.startsWith('chess960-') ||
      opening.eco == '960' ||
      opening.name == 'Chess960';
}

bool _isBoardEditorOpeningScenario(OpeningScenario opening) {
  return opening.id == 'board-editor-fen' || opening.eco == 'FEN';
}

String? _normalizeBotFen(String fen) {
  final fields = fen.trim().split(RegExp(r'\s+'));
  if (fields.isEmpty || fields.first.isEmpty) return null;
  final boardOnly = fields.first;
  if (_expandedBotBoard(boardOnly) == null) return null;
  final fullFen =
      fields.length >= 6 ? fields.take(6).join(' ') : '$boardOnly w KQkq - 0 1';
  try {
    final position = dc.Chess.fromSetup(dc.Setup.parseFen(fullFen));
    return position.fen;
  } catch (_) {
    return null;
  }
}

String? _normalizeBotEditorFen(String fen) {
  final fields = fen.trim().split(RegExp(r'\s+'));
  if (fields.isEmpty || fields.first.isEmpty) return null;
  final boardOnly = fields.first;
  if (_expandedBotBoard(boardOnly) == null) return null;
  final fullFen =
      fields.length >= 6 ? fields.take(6).join(' ') : '$boardOnly w KQkq - 0 1';
  if (_castlingRightsValidationErrorForBotEditor(fullFen) != null) {
    return fullFen;
  }
  try {
    return dc.Chess.fromSetup(dc.Setup.parseFen(fullFen)).fen;
  } catch (_) {
    return null;
  }
}

String? _castlingRightsValidationErrorForBotEditor(String fen) {
  final board = _expandedBotBoard(fen);
  if (board == null) return null;
  final fields = fen.trim().split(RegExp(r'\s+'));
  final rights = fields.length > 2 ? fields[2] : '-';

  String pieceAt(String square) {
    const files = 'abcdefgh';
    final file = files.indexOf(square[0]);
    final rank = int.tryParse(square[1]);
    if (file < 0 || rank == null || rank < 1 || rank > 8) return '';
    return board[(8 - rank) * 8 + file];
  }

  final invalidRights = <String>[];
  void requirePieces({
    required bool enabled,
    required String label,
    required String kingSquare,
    required String king,
    required String rookSquare,
    required String rook,
  }) {
    if (enabled &&
        (pieceAt(kingSquare) != king || pieceAt(rookSquare) != rook)) {
      invalidRights.add(label);
    }
  }

  requirePieces(
    enabled: rights.contains('K'),
    label: 'White O-O',
    kingSquare: 'e1',
    king: 'K',
    rookSquare: 'h1',
    rook: 'R',
  );
  requirePieces(
    enabled: rights.contains('Q'),
    label: 'White O-O-O',
    kingSquare: 'e1',
    king: 'K',
    rookSquare: 'a1',
    rook: 'R',
  );
  requirePieces(
    enabled: rights.contains('k'),
    label: 'Black O-O',
    kingSquare: 'e8',
    king: 'k',
    rookSquare: 'h8',
    rook: 'r',
  );
  requirePieces(
    enabled: rights.contains('q'),
    label: 'Black O-O-O',
    kingSquare: 'e8',
    king: 'k',
    rookSquare: 'a8',
    rook: 'r',
  );

  if (invalidRights.isEmpty) return null;
  return 'Uncheck ${invalidRights.join(', ')}. The required king and rook '
      'must be on the board before continuing.';
}

Set<String> _differentBotSquares(
    String? sourceBoardFen, String targetBoardFen) {
  final source = _expandedBotBoard(sourceBoardFen);
  final target = _expandedBotBoard(targetBoardFen);
  if (source == null || target == null) return const {};
  final squares = <String>{};
  for (var index = 0; index < 64; index += 1) {
    if (source[index] != target[index]) {
      final rankIndex = index ~/ 8;
      final fileIndex = index % 8;
      squares
          .add('${ChessBoard.files[fileIndex]}${ChessBoard.ranks[rankIndex]}');
    }
  }
  return squares;
}

List<String>? _expandedBotBoard(String? boardFen) {
  if (boardFen == null || boardFen.trim().isEmpty) return null;
  final ranks = boardFen.trim().split(RegExp(r'\s+')).first.split('/');
  if (ranks.length != 8) return null;
  final board = <String>[];
  for (final rank in ranks) {
    var rankLength = 0;
    for (final char in rank.characters) {
      final empty = int.tryParse(char);
      if (empty != null) {
        if (empty < 1 || empty > 8) return null;
        board.addAll(List<String>.filled(empty, ''));
        rankLength += empty;
      } else {
        if (!RegExp(r'^[prnbqkPRNBQK]$').hasMatch(char)) return null;
        board.add(char);
        rankLength += 1;
      }
    }
    if (rankLength != 8) return null;
  }
  return board.length == 64 ? board : null;
}

List<BoardPiece> _piecesFromBoardOnlyFen(String boardOnlyFen) {
  final pieces = <BoardPiece>[];
  final ranks = boardOnlyFen.split('/');
  if (ranks.length != 8) return pieces;

  for (var rankIndex = 0; rankIndex < ranks.length; rankIndex += 1) {
    var fileIndex = 0;
    for (final char in ranks[rankIndex].characters) {
      final emptySquares = int.tryParse(char);
      if (emptySquares != null) {
        fileIndex += emptySquares;
        continue;
      }
      if (fileIndex >= ChessBoard.files.length) continue;
      final square =
          '${ChessBoard.files[fileIndex]}${ChessBoard.ranks[rankIndex]}';
      final color = char == char.toUpperCase() ? 'w' : 'b';
      pieces.add(BoardPiece(square, '$color${char.toLowerCase()}'));
      fileIndex += 1;
    }
  }

  return pieces;
}

class OnlineSetupScreen extends StatefulWidget {
  const OnlineSetupScreen({
    required this.onNavigate,
    required this.onLaunchGame,
    required this.apiClient,
    required this.onSessionUpdated,
    required this.boardSettings,
    required this.onBoardSettingsChanged,
    this.lichessAuthorizationPresenter = showLichessAuthorization,
    this.isChessnutClockDevice = false,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final LaunchGameCallback onLaunchGame;
  final ChessnutApiClient apiClient;
  final ValueChanged<ChessnutLoginSession> onSessionUpdated;
  final BoardSettingsState boardSettings;
  final ValueChanged<BoardSettingsState> onBoardSettingsChanged;
  final LichessAuthorizationPresenter lichessAuthorizationPresenter;
  final bool isChessnutClockDevice;

  @override
  State<OnlineSetupScreen> createState() => _OnlineSetupScreenState();
}

class _OnlineSetupScreenState extends State<OnlineSetupScreen> {
  bool chesscom = false;
  bool lichessAuthorized = false;
  bool lichessTokenExpired = false;
  bool lichessCheckingAuth = false;
  bool lichessSeeking = false;
  String? lichessName;
  String? lichessMessage;
  bool rated = false;
  bool autoSubmit = true;
  bool moveLeds = true;
  _TimeControlOption selectedTime = _defaultTimeControl;
  String? lichessToken;
  _LichessMatchMode lichessMatchMode = _LichessMatchMode.random;
  bool lichessFriendChecking = false;
  bool lichessFriendAccessGranted = false;
  bool lichessFriendNeedsReauthorization = false;
  List<LichessFriend> lichessFriends = const [];
  List<LichessChallenge> lichessIncomingChallenges = const [];
  LichessFriend? selectedLichessFriend;
  late final TextEditingController _lichessPlayerController;
  String lichessFriendQuery = '';
  String lichessFriendColor = 'random';
  bool lichessFriendChallengePending = false;
  String? lichessFriendChallengeId;
  String? lichessFriendChallengeMessage;
  bool _lichessChallengeStatusDialogShown = false;
  StreamSubscription<LichessChallengeProgress>? _friendChallengeSubscription;
  LichessBoardService? _friendChallengeService;

  bool get canSeekLichess => lichessAuthorized && !lichessTokenExpired;

  String? get _lichessChallengeUsername {
    final username = lichessFriendQuery.trim();
    if (username.isEmpty || RegExp(r'\s').hasMatch(username)) return null;
    return username;
  }

  @override
  void initState() {
    super.initState();
    _lichessPlayerController = TextEditingController();
    final session = widget.apiClient.session;
    if (session is ChessnutLoginSession) {
      final linkedName = session.lichessName.trim();
      if (session.bindLichess || linkedName.isNotEmpty) {
        lichessAuthorized = true;
        if (linkedName.isNotEmpty) lichessName = linkedName;
      }
    }
    unawaited(_refreshLichessToken());
  }

  @override
  void dispose() {
    final challengeId = lichessFriendChallengeId;
    final service = _friendChallengeService;
    _friendChallengeSubscription?.cancel();
    if (challengeId != null && service != null) {
      unawaited(service.cancelChallenge(challengeId));
    }
    _lichessPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canStart = chesscom || canSeekLichess;
    return ResponsivePage(
      children: (context, spec) => [
        ScreenHeader(
          title: 'Find match',
          subtitle: 'Online',
          leading: IconButton.filledTonal(
            onPressed: () => widget.onNavigate('Back'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          trailing:
              _OnlinePlatformPill(label: chesscom ? 'Chess.com' : 'Lichess'),
        ),
        SizedBox(height: spec.gutter),
        ResponsiveSplit(
          breakpoint: 880,
          spacing: spec.gutter,
          leadingFlex: 6,
          trailingFlex: 5,
          leading: SectionColumn(
            spacing: 12,
            children: [
              SectionColumn(
                key: const ValueKey('online-platform-panel'),
                spacing: 12,
                children: [
                  _PlatformCard(
                    title: 'Lichess',
                    subtitle: 'Find opponents and sync board moves',
                    badge: 'Native',
                    selected: !chesscom,
                    onTap: () => setState(() {
                      chesscom = false;
                      if (lichessAuthorized) lichessTokenExpired = false;
                    }),
                  ),
                  _PlatformCard(
                    title: 'Chess.com',
                    subtitle: 'Opens the existing WebView flow',
                    badge: 'WebView',
                    selected: chesscom,
                    onTap: () => setState(() => chesscom = true),
                  ),
                ],
              ),
              GlassPanel(
                padding: const EdgeInsets.all(12),
                borderRadius: 13,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Selected',
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Text(
                      chesscom
                          ? 'Chess.com WebView mirror'
                          : 'Lichess online game',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chesscom
                          ? 'Use the existing WebView login and control layer. Game moves still mirror into the Chessnut board.'
                          : canSeekLichess
                              ? 'Lichess is authorized. Once a ${selectedTime.label} game is matched, Chessnut will sync moves to your board.'
                              : 'Authorize Lichess first so Chessnut can start online games and sync moves to your board.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    _ConnectionSteps(
                      chesscom: chesscom,
                      authorized: canSeekLichess,
                    ),
                  ],
                ),
              ),
              if (!chesscom)
                _LichessAuthorizationPanel(
                  key: const ValueKey('online-lichess-auth-panel'),
                  authorized: lichessAuthorized,
                  expired: lichessTokenExpired,
                  checking: lichessCheckingAuth,
                  lichessName: lichessName,
                  message: lichessMessage,
                  onAuthorize: _authorizeLichess,
                ),
            ],
          ),
          trailing: SectionColumn(
            spacing: 12,
            children: chesscom
                ? [
                    GlassPanel(
                      key: const ValueKey(
                        'chesscom-show-legal-moves-setting',
                      ),
                      padding: const EdgeInsets.all(12),
                      borderRadius: 13,
                      child: Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          value: widget.boardSettings.chessComShowLegalMoves,
                          onChanged: (value) {
                            widget.onBoardSettingsChanged(
                              widget.boardSettings.copyWith(
                                chessComShowLegalMoves: value,
                              ),
                            );
                          },
                          secondary: const Icon(Icons.alt_route_rounded),
                          title: const Text('Show Legal Moves'),
                        ),
                      ),
                    ),
                    const _ChessComGuidePanel(),
                    PrimaryButton(
                      label: 'Open Chess.com',
                      icon: Icons.open_in_new_rounded,
                      onPressed: () => widget.onLaunchGame(
                        GameLaunchMode.chesscom,
                      ),
                    ),
                  ]
                : [
                    _LichessMatchModeCard(
                      selected: lichessMatchMode,
                      onChanged: (mode) {
                        setState(() => lichessMatchMode = mode);
                        if (mode == _LichessMatchMode.friend &&
                            lichessAuthorized &&
                            !lichessFriendChecking &&
                            !lichessFriendAccessGranted &&
                            !lichessFriendNeedsReauthorization) {
                          unawaited(_checkLichessFriendAccess());
                        }
                      },
                    ),
                    if (lichessMatchMode == _LichessMatchMode.friend)
                      _buildLichessFriendPanel(),
                    SectionColumn(
                      key: const ValueKey('online-match-settings-panel'),
                      spacing: 12,
                      children: [
                        _TimeControlCard(
                          selected: selectedTime,
                          options: lichessMatchMode == _LichessMatchMode.friend
                              ? _lichessFriendTimeControls
                              : _lichessTimeControls,
                          onSelected: (option) =>
                              setState(() => selectedTime = option),
                          onCustom: () => _showTimeSelectionDialog(
                            context: context,
                            initial: selectedTime,
                            subtitle:
                                'Lichess seek uses minutes plus increment seconds.',
                            onSave: (value) =>
                                setState(() => selectedTime = value),
                          ),
                          footerBuilder: (option) =>
                              'Online search: ${option.label}',
                        ),
                        GlassPanel(
                          padding: const EdgeInsets.all(12),
                          borderRadius: 13,
                          child: Material(
                            color: Colors.transparent,
                            child: Column(
                              children: [
                                SwitchListTile(
                                  value: rated,
                                  onChanged: (value) =>
                                      setState(() => rated = value),
                                  title: const Text('Rated'),
                                ),
                                SwitchListTile(
                                  value: autoSubmit,
                                  onChanged: (value) =>
                                      setState(() => autoSubmit = value),
                                  title: const Text('Auto submit'),
                                ),
                                SwitchListTile(
                                  value: moveLeds,
                                  onChanged: (value) =>
                                      setState(() => moveLeds = value),
                                  title: const Text('Move LEDs'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    PrimaryButton(
                      label: lichessMatchMode == _LichessMatchMode.random
                          ? lichessSeeking
                              ? 'Finding game...'
                              : 'Find ${selectedTime.label} game'
                          : lichessCheckingAuth
                              ? 'Checking Lichess authorization...'
                              : lichessFriendChallengePending
                                  ? 'Cancel challenge'
                                  : 'Challenge player',
                      icon: lichessMatchMode == _LichessMatchMode.random
                          ? Icons.travel_explore_rounded
                          : lichessFriendChallengePending
                              ? Icons.close_rounded
                              : Icons.person_add_alt_1_rounded,
                      onPressed: lichessSeeking ||
                              lichessCheckingAuth ||
                              (!canStart &&
                                  !(lichessMatchMode ==
                                          _LichessMatchMode.friend &&
                                      lichessFriendNeedsReauthorization))
                          ? null
                          : lichessMatchMode == _LichessMatchMode.random
                              ? _createLichessSeek
                              : lichessFriendChallengePending
                                  ? _cancelLichessFriendChallenge
                                  : _lichessChallengeUsername == null
                                      ? null
                                      : _createLichessPlayerChallenge,
                    ),
                    if (lichessMatchMode == _LichessMatchMode.random &&
                        _showTemporaryLichessGameEntry)
                      PrimaryButton(
                        label: 'Open test game ($_temporaryLichessGameId)',
                        icon: Icons.science_rounded,
                        onPressed: canSeekLichess && !lichessSeeking
                            ? _openTemporaryLichessGame
                            : null,
                      ),
                    if (!canSeekLichess)
                      Text(
                        lichessTokenExpired
                            ? 'Authorization expired. Re-authorize before seeking.'
                            : 'Authorize Lichess before starting an online game.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                  ],
          ),
        ),
      ],
    );
  }

  Widget _buildLichessFriendPanel() {
    final query = lichessFriendQuery.trim().toLowerCase();
    final visibleFriends = lichessFriends
        .where((friend) =>
            query.isEmpty ||
            friend.username.toLowerCase().contains(query) ||
            friend.title.toLowerCase().contains(query))
        .toList(growable: false);
    return GlassPanel(
      key: const ValueKey('lichess-friend-panel'),
      padding: const EdgeInsets.all(12),
      borderRadius: 13,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Challenge a Lichess player',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              IconButton(
                tooltip: 'Refresh friends',
                onPressed:
                    lichessFriendChecking || lichessFriendChallengePending
                        ? null
                        : _checkLichessFriendAccess,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('lichess-player-username-field'),
            controller: _lichessPlayerController,
            enabled: !lichessFriendChallengePending,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onChanged: (value) => setState(() {
              lichessFriendQuery = value;
              if (selectedLichessFriend?.username.toLowerCase() !=
                  value.trim().toLowerCase()) {
                selectedLichessFriend = null;
              }
              lichessFriendChallengeMessage = null;
            }),
            onSubmitted: (_) {
              if (_lichessChallengeUsername != null &&
                  !lichessFriendChallengePending) {
                _createLichessPlayerChallenge();
              }
            },
            decoration: const InputDecoration(
              labelText: 'Lichess username',
              helperText:
                  'Enter any Lichess username or select a followed user.',
              prefixIcon: Icon(Icons.person_search_rounded),
            ),
          ),
          if (lichessFriendChecking) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text(
                'Checking whether this authorization can access your followed users...'),
          ] else if (lichessFriendNeedsReauthorization) ...[
            const SizedBox(height: 8),
            Text(
              'This Lichess authorization does not include friend-list access. Re-authorize Lichess to play with followed users.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed:
                    lichessCheckingAuth ? null : _reauthorizeLichessForFriends,
                icon: const Icon(Icons.lock_reset_rounded),
                label: const Text('Re-authorize Lichess'),
              ),
            ),
          ] else if (lichessFriendAccessGranted) ...[
            if (lichessIncomingChallenges.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Incoming challenges',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              for (final challenge in lichessIncomingChallenges)
                _LichessIncomingChallengeTile(
                  challenge: challenge,
                  busy: lichessFriendChallengePending,
                  onAccept: () => _acceptLichessChallenge(challenge),
                  onDecline: () => _declineLichessChallenge(challenge),
                ),
              const Divider(height: 22),
            ],
            const SizedBox(height: 8),
            if (lichessFriends.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('You are not following any Lichess users yet.'),
              )
            else if (visibleFriends.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('No followed users match this search.'),
              )
            else
              SizedBox(
                height: math.min(260, visibleFriends.length * 58).toDouble(),
                child: ListView.builder(
                  itemCount: visibleFriends.length,
                  itemBuilder: (context, index) {
                    final friend = visibleFriends[index];
                    final selected = selectedLichessFriend?.id == friend.id;
                    return _LichessFriendTile(
                      friend: friend,
                      selected: selected,
                      rating: friend.ratingFor(selectedTime.speed),
                      enabled: !lichessFriendChallengePending,
                      onTap: () => setState(() {
                        _lichessPlayerController.text = friend.username;
                        _lichessPlayerController.selection =
                            TextSelection.collapsed(
                          offset: friend.username.length,
                        );
                        lichessFriendQuery = friend.username;
                        selectedLichessFriend = friend;
                        lichessFriendChallengeMessage = null;
                      }),
                    );
                  },
                ),
              ),
          ] else ...[
            const SizedBox(height: 8),
            const Text(
                'Friend access could not be checked. Check the network and try again.'),
          ],
          const SizedBox(height: 8),
          _LichessChallengeColorSelector(
            value: lichessFriendColor,
            enabled: !lichessFriendChallengePending,
            onChanged: (value) => setState(() => lichessFriendColor = value),
          ),
          if (lichessFriendChallengePending) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('lichess-cancel-challenge-button'),
                onPressed: _cancelLichessFriendChallenge,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Cancel challenge'),
              ),
            ),
          ],
          if (lichessFriendChallengeMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              lichessFriendChallengeMessage!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _checkLichessFriendAccess() async {
    if (lichessFriendChecking) return;
    final token = lichessToken;
    if (token == null || token.isEmpty) return;
    setState(() {
      lichessFriendChecking = true;
      lichessFriendChallengeMessage = null;
    });
    final service = LichessBoardService(
      token: token,
      localLichessName: lichessName ?? '',
      httpClient: widget.apiClient.httpClient,
    );
    final friends = await service.getFollowing();
    if (!mounted || token != lichessToken) return;
    if (friends == null) {
      final needsAuthorization =
          service.lastStatusCode == 401 || service.lastStatusCode == 403;
      setState(() {
        lichessFriendChecking = false;
        lichessFriendAccessGranted = false;
        lichessFriendNeedsReauthorization = needsAuthorization;
        lichessFriendChallengeMessage = needsAuthorization
            ? null
            : service.lastErrorMessage ??
                'Friend access could not be checked. Check the network and try again.';
      });
      return;
    }
    final challenges = await service.getChallenges();
    if (!mounted || token != lichessToken) return;
    final selectedId = selectedLichessFriend?.id;
    setState(() {
      lichessFriendChecking = false;
      lichessFriendAccessGranted = true;
      lichessFriendNeedsReauthorization = false;
      lichessFriends = friends.where((friend) => !friend.disabled).toList();
      selectedLichessFriend = selectedId == null
          ? null
          : lichessFriends
              .where((friend) => friend.id == selectedId)
              .firstOrNull;
      lichessIncomingChallenges = (challenges ?? const [])
          .where((challenge) => challenge.direction == 'in')
          .toList(growable: false);
      if (challenges == null) {
        lichessFriendChallengeMessage = service.lastErrorMessage;
      }
    });
  }

  Future<void> _reauthorizeLichessForFriends() async {
    if (lichessCheckingAuth) return;
    setState(() {
      lichessCheckingAuth = true;
      lichessFriendChallengeMessage = null;
    });
    final unlinkResult = await widget.apiClient.freeUserBind('lichess');
    if (!mounted) return;
    if (!unlinkResult.isSuccess) {
      setState(() {
        lichessCheckingAuth = false;
        lichessFriendChallengeMessage = unlinkResult.status.errorMessage ??
            'Linked account update failed. Please try again.';
      });
      return;
    }
    setState(() {
      lichessAuthorized = false;
      lichessTokenExpired = false;
      lichessToken = null;
      lichessName = null;
      lichessFriendAccessGranted = false;
      lichessFriendNeedsReauthorization = true;
      lichessFriends = const [];
      lichessIncomingChallenges = const [];
      selectedLichessFriend = null;
    });
    _syncSessionLichess(linked: false, lichessName: '');

    final result = await widget.apiClient.bindLichess();
    if (!mounted) return;
    if (!result.isSuccess) {
      setState(() {
        lichessCheckingAuth = false;
        lichessFriendChallengeMessage = result.status.errorMessage ??
            'Lichess authorization is not available right now. Please try again later.';
      });
      return;
    }
    final authorizationUri = Uri.tryParse(result.data ?? '');
    if (authorizationUri == null || !authorizationUri.hasScheme) {
      setState(() {
        lichessCheckingAuth = false;
        lichessFriendChallengeMessage =
            'Lichess authorization could not open. Try again later.';
      });
      return;
    }
    final completed = await widget.lichessAuthorizationPresenter(
      context,
      authorizationUri: authorizationUri,
    );
    if (!mounted) return;
    if (!completed) {
      setState(() {
        lichessCheckingAuth = false;
        lichessFriendChallengeMessage =
            'Lichess authorization was not completed. Try again when the Lichess page finishes.';
      });
      return;
    }
    LichessTokenResult? updated;
    for (var attempt = 0; attempt < 10; attempt += 1) {
      final tokenResult = await widget.apiClient.getLichessToken();
      if (tokenResult.isSuccess && tokenResult.data != null) {
        updated = tokenResult.data;
        break;
      }
      if (attempt < 9) {
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
    }
    if (!mounted) return;
    if (updated == null) {
      setState(() {
        lichessCheckingAuth = false;
        lichessFriendChallengeMessage =
            'The new Lichess authorization is not ready yet. Please try again.';
      });
      return;
    }
    setState(() {
      lichessCheckingAuth = false;
      lichessAuthorized = true;
      lichessTokenExpired = false;
      lichessToken = updated!.token;
      lichessName = updated.lichessName;
    });
    _syncSessionLichess(linked: true, lichessName: updated.lichessName);
    await _checkLichessFriendAccess();
  }

  Future<void> _createLichessPlayerChallenge() async {
    if (lichessFriendChallengePending) return;
    final username = _lichessChallengeUsername;
    final token = lichessToken;
    if (username == null || token == null || token.isEmpty) return;
    final service = LichessBoardService(
      token: token,
      localLichessName: lichessName ?? '',
      httpClient: widget.apiClient.httpClient,
    );
    _friendChallengeService = service;
    setState(() {
      lichessFriendChallengePending = true;
      lichessFriendChallengeId = null;
      lichessFriendChallengeMessage = 'Sending Lichess challenge...';
      _lichessChallengeStatusDialogShown = false;
    });
    final stream = service.createChallenge(
      LichessChallengeRequest(
        username: username,
        timeMinutes: selectedTime.minutes,
        incrementSeconds: selectedTime.increment,
        rated: rated,
        color: lichessFriendColor,
      ),
    );
    await _friendChallengeSubscription?.cancel();
    _friendChallengeSubscription = stream.listen(
      _handleLichessChallengeProgress,
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          lichessFriendChallengePending = false;
          lichessFriendChallengeMessage = 'Lichess challenge failed: $error';
        });
        _showLichessChallengeStatusDialog(
          icon: Icons.error_outline_rounded,
          title: 'Lichess could not create this challenge.',
          detail: '$error',
        );
      },
    );
  }

  void _handleLichessChallengeProgress(LichessChallengeProgress progress) {
    if (!mounted) return;
    final challengeId = progress.challenge?.id;
    if (challengeId != null && challengeId.isNotEmpty) {
      lichessFriendChallengeId = challengeId;
    }
    switch (progress.state) {
      case LichessChallengeProgressState.created:
        setState(() {
          lichessFriendChallengeMessage =
              'Waiting for the player to accept the challenge...';
        });
      case LichessChallengeProgressState.accepted:
        final gameId = lichessFriendChallengeId;
        setState(() {
          lichessFriendChallengePending = false;
          lichessFriendChallengeMessage = 'Challenge accepted.';
        });
        if (gameId != null && gameId.isNotEmpty) {
          _launchLichessChallengeGame(
            gameId: gameId,
            timeMinutes: selectedTime.minutes,
            incrementSeconds: selectedTime.increment,
            challengeRated: rated,
          );
        }
      case LichessChallengeProgressState.declined:
        setState(() {
          lichessFriendChallengePending = false;
          lichessFriendChallengeId = null;
          lichessFriendChallengeMessage = 'The player declined the challenge.';
        });
        _showLichessChallengeStatusDialog(
          icon: Icons.person_off_rounded,
          title: 'The player declined the challenge.',
        );
      case LichessChallengeProgressState.canceled:
        setState(() {
          lichessFriendChallengePending = false;
          lichessFriendChallengeId = null;
          lichessFriendChallengeMessage = 'Challenge canceled.';
        });
        _showLichessChallengeStatusDialog(
          icon: Icons.cancel_outlined,
          title: 'Challenge canceled.',
        );
      case LichessChallengeProgressState.expired:
        setState(() {
          lichessFriendChallengePending = false;
          lichessFriendChallengeId = null;
          lichessFriendChallengeMessage = 'The challenge expired.';
        });
        _showLichessChallengeStatusDialog(
          icon: Icons.timer_off_outlined,
          title: 'The challenge expired.',
        );
      case LichessChallengeProgressState.failed:
        final message =
            progress.message ?? 'Lichess could not create this challenge.';
        setState(() {
          lichessFriendChallengePending = false;
          lichessFriendChallengeId = null;
          lichessFriendChallengeMessage = message;
        });
        _showLichessChallengeStatusDialog(
          icon: Icons.error_outline_rounded,
          title: 'Lichess could not create this challenge.',
          detail: message,
        );
    }
  }

  void _showLichessChallengeStatusDialog({
    required IconData icon,
    required String title,
    String? detail,
  }) {
    if (!mounted || _lichessChallengeStatusDialogShown) return;
    _lichessChallengeStatusDialogShown = true;
    final subtitle = detail == null || detail == title ? null : detail;
    unawaited(
      showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.62),
        builder: (dialogContext) => AppDialogShell(
          key: const ValueKey('lichess-challenge-status-dialog'),
          icon: icon,
          title: title,
          subtitle: subtitle,
          actions: [
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelLichessFriendChallenge() async {
    final service = _friendChallengeService;
    final challengeId = lichessFriendChallengeId;
    if (service == null || challengeId == null) {
      final subscription = _friendChallengeSubscription;
      _friendChallengeSubscription = null;
      unawaited(subscription?.cancel());
      if (!mounted) return;
      setState(() {
        lichessFriendChallengePending = false;
        lichessFriendChallengeMessage = 'Challenge canceled.';
      });
      _showLichessChallengeStatusDialog(
        icon: Icons.cancel_outlined,
        title: 'Challenge canceled.',
      );
      return;
    }
    final ok = await service.cancelChallenge(challengeId);
    final subscription = _friendChallengeSubscription;
    _friendChallengeSubscription = null;
    unawaited(subscription?.cancel());
    if (!mounted) return;
    setState(() {
      lichessFriendChallengePending = false;
      lichessFriendChallengeId = null;
      lichessFriendChallengeMessage = ok
          ? 'Challenge canceled.'
          : service.lastErrorMessage ??
              'Lichess could not cancel the challenge.';
    });
    _showLichessChallengeStatusDialog(
      icon: ok ? Icons.cancel_outlined : Icons.error_outline_rounded,
      title: ok
          ? 'Challenge canceled.'
          : 'Lichess could not cancel the challenge.',
      detail: ok ? null : service.lastErrorMessage,
    );
  }

  Future<void> _acceptLichessChallenge(LichessChallenge challenge) async {
    if (lichessFriendChallengePending) return;
    if (!challenge.supportsBoardApi) {
      setState(() {
        lichessFriendChallengeMessage =
            'This challenge is not compatible with Board API play.';
      });
      return;
    }
    final token = lichessToken;
    if (token == null || token.isEmpty) return;
    final service = LichessBoardService(
      token: token,
      localLichessName: lichessName ?? '',
      httpClient: widget.apiClient.httpClient,
    );
    setState(() => lichessFriendChallengePending = true);
    final ok = await service.acceptChallenge(challenge.id);
    if (!mounted) return;
    setState(() => lichessFriendChallengePending = false);
    if (!ok) {
      setState(() {
        lichessFriendChallengeMessage = service.lastErrorMessage ??
            'Lichess could not accept the challenge.';
      });
      return;
    }
    _launchLichessChallengeGame(
      gameId: challenge.id,
      timeMinutes: challenge.timeMinutes,
      incrementSeconds: challenge.incrementSeconds,
      challengeRated: challenge.rated,
    );
  }

  Future<void> _declineLichessChallenge(LichessChallenge challenge) async {
    if (lichessFriendChallengePending) return;
    final token = lichessToken;
    if (token == null || token.isEmpty) return;
    final service = LichessBoardService(
      token: token,
      httpClient: widget.apiClient.httpClient,
    );
    setState(() => lichessFriendChallengePending = true);
    final ok = await service.declineChallenge(challenge.id);
    if (!mounted) return;
    setState(() {
      lichessFriendChallengePending = false;
      if (ok) {
        lichessIncomingChallenges = lichessIncomingChallenges
            .where((item) => item.id != challenge.id)
            .toList(growable: false);
        lichessFriendChallengeMessage = 'Challenge declined.';
      } else {
        lichessFriendChallengeMessage = service.lastErrorMessage ??
            'Lichess could not decline the challenge.';
      }
    });
  }

  void _launchLichessChallengeGame({
    required String gameId,
    required int timeMinutes,
    required int incrementSeconds,
    required bool challengeRated,
  }) {
    final token = lichessToken;
    if (token == null || token.isEmpty) return;
    _friendChallengeSubscription?.cancel();
    lichessFriendChallengeId = null;
    widget.onLaunchGame(
      GameLaunchMode.lichess,
      lichessConfig: LichessGameConfig(
        gameId: gameId,
        token: token,
        lichessName: lichessName ?? '',
        timeMinutes: timeMinutes,
        incrementSeconds: incrementSeconds,
        rated: challengeRated,
        moveLeds: moveLeds,
      ),
    );
  }

  Future<bool> _refreshLichessToken({bool waitForCallback = false}) async {
    if (widget.apiClient.session == null) return false;
    setState(() {
      lichessCheckingAuth = true;
      lichessMessage = null;
    });
    final result = waitForCallback
        ? await widget.apiClient.waitForLichessToken()
        : await widget.apiClient.getLichessToken();
    if (!mounted) return false;
    final success = result.isSuccess && result.data != null;
    String? linkedName;
    final lichessExpired = isLichessAuthorizationExpiredStatus(result.status);
    final shouldClearLichessSession =
        !success && result.status.apiErrorCode != null && lichessExpired;
    setState(() {
      lichessCheckingAuth = false;
      if (success) {
        lichessAuthorized = true;
        lichessTokenExpired = false;
        lichessName = result.data!.lichessName;
        lichessToken = result.data!.token;
        lichessMessage = null;
        linkedName = result.data!.lichessName;
      } else {
        lichessAuthorized = false;
        lichessToken = null;
        lichessTokenExpired = lichessExpired;
        lichessMessage = result.status.errorMessage ??
            'Lichess sign-in status could not be checked. Please try again later.';
      }
    });
    if (linkedName != null) {
      _syncSessionLichess(linked: true, lichessName: linkedName!);
      unawaited(_checkLichessFriendAccess());
    } else if (shouldClearLichessSession) {
      _syncSessionLichess(linked: false, lichessName: '');
    }
    return success;
  }

  Future<void> _openTemporaryLichessGame() async {
    if (lichessSeeking) return;
    var token = lichessToken;
    if (token == null || token.isEmpty) {
      final refreshed = await _refreshLichessToken();
      if (!refreshed || !mounted) return;
      token = lichessToken;
    }
    if (!mounted || token == null || token.isEmpty) return;

    setState(() {
      lichessSeeking = true;
      lichessMessage = 'Checking test Lichess game $_temporaryLichessGameId...';
    });
    final service = LichessBoardService(
      token: token,
      httpClient: widget.apiClient.httpClient,
    );
    final snapshot = await service.checkGame(_temporaryLichessGameId);
    if (!mounted) return;
    setState(() => lichessSeeking = false);
    if (!snapshot.canContinue) {
      setState(() {
        lichessMessage = _lichessFailureMessage(
          'The test Lichess game cannot be opened',
          snapshot.errorMessage ?? service.lastErrorMessage,
        );
      });
      return;
    }
    widget.onLaunchGame(
      GameLaunchMode.lichess,
      lichessConfig: LichessGameConfig(
        gameId: _temporaryLichessGameId,
        token: token,
        lichessName: lichessName ?? '',
        timeMinutes: selectedTime.minutes,
        incrementSeconds: selectedTime.increment,
        rated: false,
        moveLeds: moveLeds,
      ),
    );
  }

  Future<bool> _refreshLichessBinding() async {
    final result = await widget.apiClient.waitForLichessToken();
    if (!mounted) return false;
    if (result.isSuccess && result.data != null) {
      final linkedName = result.data!.lichessName;
      setState(() {
        lichessAuthorized = true;
        lichessTokenExpired = false;
        lichessName = linkedName;
        lichessToken = result.data!.token;
        lichessMessage = null;
      });
      _syncSessionLichess(linked: true, lichessName: linkedName);
      return true;
    }
    return false;
  }

  void _syncSessionLichess({
    required bool linked,
    required String lichessName,
  }) {
    final session = widget.apiClient.session;
    if (session is! ChessnutLoginSession) return;
    if (session.bindLichess == linked &&
        session.lichessName.trim() == lichessName.trim()) {
      return;
    }
    widget.apiClient.session = session.copyWith(
      bindLichess: linked,
      lichessName: lichessName,
    );
    widget.onSessionUpdated(widget.apiClient.session as ChessnutLoginSession);
  }

  Future<void> _authorizeLichess() async {
    if (widget.apiClient.session == null) {
      setState(() {
        lichessAuthorized = false;
        lichessMessage = 'Sign in before authorizing Lichess.';
      });
      return;
    }
    setState(() {
      lichessCheckingAuth = true;
      lichessMessage = null;
    });
    if (lichessTokenExpired) {
      final unlinkResult = await widget.apiClient.freeUserBind('lichess');
      if (!mounted) return;
      if (!unlinkResult.isSuccess) {
        setState(() {
          lichessCheckingAuth = false;
          lichessMessage = unlinkResult.status.errorMessage ??
              'Linked account update failed. Please try again.';
        });
        return;
      }
      setState(() {
        lichessAuthorized = false;
        lichessTokenExpired = false;
        lichessToken = null;
        lichessName = null;
      });
      _syncSessionLichess(linked: false, lichessName: '');
    }
    final result = await widget.apiClient.bindLichess();
    if (!mounted) return;
    if (!result.isSuccess) {
      final refreshed = await _refreshLichessBinding();
      if (!mounted) return;
      setState(() {
        lichessCheckingAuth = false;
        if (refreshed) {
          lichessMessage = 'Lichess authorized.';
        } else {
          lichessAuthorized = false;
          lichessMessage = result.status.errorMessage ??
              'Lichess authorization is not available right now. Please try again later.';
        }
      });
      return;
    }
    final authorizationUri = Uri.tryParse(result.data ?? '');
    if (authorizationUri == null || !authorizationUri.hasScheme) {
      setState(() {
        lichessCheckingAuth = false;
        lichessAuthorized = false;
        lichessMessage =
            'Lichess authorization could not open. Try again later.';
      });
      return;
    }
    setState(() {
      lichessCheckingAuth = false;
      lichessMessage = 'Complete authorization in Lichess, then return here.';
    });
    final completed = await widget.lichessAuthorizationPresenter(
      context,
      authorizationUri: authorizationUri,
    );
    if (!mounted) return;
    final refreshed = await _refreshLichessToken(waitForCallback: completed);
    if (!mounted) return;
    if (refreshed) {
      setState(() => lichessMessage = null);
      return;
    }
    if (!completed && !lichessAuthorized) {
      setState(() {
        lichessMessage =
            'Lichess authorization was not completed. Try again when the Lichess page finishes.';
      });
      return;
    }
  }

  Future<void> _createLichessSeek() async {
    if (lichessSeeking) return;
    setState(() {
      lichessSeeking = true;
      lichessMessage = 'Looking for a Lichess game...';
    });
    final token = lichessToken;
    if (token == null || token.isEmpty) {
      await _refreshLichessToken();
      if (lichessToken == null || lichessToken!.isEmpty) {
        if (!mounted) return;
        setState(() => lichessSeeking = false);
        return;
      }
    }

    final service = LichessBoardService(
      token: lichessToken!,
      httpClient: widget.apiClient.httpClient,
    );
    final requestedTime = selectedTime;
    final eventStreamReady = Completer<bool>();
    final gameStart = service.waitForGameStart(
      expectedInitialTimeMs: requestedTime.minutes * 60 * 1000,
      expectedIncrementMs: requestedTime.increment * 1000,
      onConnectionReady: (ready) {
        if (!eventStreamReady.isCompleted) {
          eventStreamReady.complete(ready);
        }
      },
    );
    final streamReadyBeforeSeek = await eventStreamReady.future.timeout(
      const Duration(milliseconds: 500),
      onTimeout: () => true,
    );
    if (!mounted) return;
    if (!streamReadyBeforeSeek) {
      setState(() {
        lichessSeeking = false;
        lichessMessage = _lichessFailureMessage(
          'Could not open the Lichess event stream. Check your network and try again.',
          service.lastStreamErrorMessage,
        );
      });
      return;
    }
    final ok = await service.createSeek(
      LichessSeekRequest(
        rated: rated,
        timeMinutes: requestedTime.minutes,
        incrementSeconds: requestedTime.increment,
        variant: 'standard',
        color: 'random',
      ),
    );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        lichessSeeking = false;
        lichessMessage = _lichessFailureMessage(
          'Could not start the Lichess game search. Check your connection and authorize Lichess again.',
          service.lastErrorMessage,
        );
      });
      return;
    }

    String? gameId;
    try {
      gameId = await gameStart;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        lichessSeeking = false;
        lichessMessage = _lichessFailureMessage(
          'Could not open the Lichess event stream. Check your network and try again.',
          service.lastStreamErrorMessage ?? service.lastErrorMessage,
        );
      });
      return;
    }
    if (!mounted) return;
    setState(() => lichessSeeking = false);
    if (gameId == null) {
      setState(() {
        final streamError =
            service.lastStreamErrorMessage ?? service.lastErrorMessage;
        lichessMessage = streamError == null || streamError.trim().isEmpty
            ? 'Still looking for a game. You can wait a little longer or try again.'
            : _lichessFailureMessage(
                'Could not open the Lichess event stream. Check your network and try again.',
                streamError,
              );
      });
      return;
    }

    widget.onLaunchGame(
      GameLaunchMode.lichess,
      lichessConfig: LichessGameConfig(
        gameId: gameId,
        token: lichessToken!,
        lichessName: lichessName ?? '',
        timeMinutes: requestedTime.minutes,
        incrementSeconds: requestedTime.increment,
        rated: rated,
        moveLeds: moveLeds,
      ),
    );
  }
}

String _lichessFailureMessage(String fallback, String? reason) {
  final detail = _cleanLichessFailureReason(reason);
  if (detail == null) return fallback;
  return '$fallback: $detail';
}

String? _cleanLichessFailureReason(String? reason) {
  final trimmed = reason?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed.endsWith('.')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
}

class _LichessMatchModeCard extends StatelessWidget {
  const _LichessMatchModeCard({
    required this.selected,
    required this.onChanged,
  });

  final _LichessMatchMode selected;
  final ValueChanged<_LichessMatchMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(10),
      borderRadius: 13,
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<_LichessMatchMode>(
          segments: const [
            ButtonSegment(
              value: _LichessMatchMode.random,
              icon: Icon(Icons.travel_explore_rounded),
              label: Text('Random match'),
            ),
            ButtonSegment(
              value: _LichessMatchMode.friend,
              icon: Icon(Icons.group_rounded),
              label: Text('Friend match'),
            ),
          ],
          selected: {selected},
          onSelectionChanged: (value) => onChanged(value.first),
        ),
      ),
    );
  }
}

class _LichessFriendTile extends StatelessWidget {
  const _LichessFriendTile({
    required this.friend,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.rating,
  });

  final LichessFriend friend;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final int? rating;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final displayName = friend.title.isEmpty
        ? friend.username
        : '${friend.title} ${friend.username}';
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
                child: Text(
                  friend.username.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  rating == null ? displayName : '$displayName · $rating',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? scheme.primary : scheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LichessChallengeColorSelector extends StatelessWidget {
  const _LichessChallengeColorSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Your color', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        Expanded(
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'random', label: Text('Random')),
              ButtonSegment(value: 'white', label: Text('White')),
              ButtonSegment(value: 'black', label: Text('Black')),
            ],
            selected: {value},
            onSelectionChanged:
                enabled ? (selection) => onChanged(selection.first) : null,
            showSelectedIcon: false,
          ),
        ),
      ],
    );
  }
}

class _LichessIncomingChallengeTile extends StatelessWidget {
  const _LichessIncomingChallengeTile({
    required this.challenge,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final LichessChallenge challenge;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final opponent = challenge.opponentTitle.isEmpty
        ? challenge.opponentName
        : '${challenge.opponentTitle} ${challenge.opponentName}';
    final time = challenge.timeMinutes <= 0
        ? 'Unlimited'
        : '${challenge.timeMinutes}+${challenge.incrementSeconds}';
    final category = AppStrings.of(context).t(
      challenge.rated ? 'Rated' : 'Casual',
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(opponent,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  '$time · $category',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Decline challenge',
            onPressed: busy ? null : onDecline,
            icon: const Icon(Icons.close_rounded),
          ),
          IconButton.filledTonal(
            tooltip: 'Accept challenge',
            onPressed: busy || !challenge.supportsBoardApi ? null : onAccept,
            icon: const Icon(Icons.check_rounded),
          ),
        ],
      ),
    );
  }
}

class _EngineCard extends StatelessWidget {
  const _EngineCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badge,
    this.selected = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String badge;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = selected ? scheme.primary : scheme.secondary;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: dark ? 0.16 : 0.11)
                : Theme.of(context).colorScheme.surface.withValues(
                      alpha: dark ? 0.20 : 0.54,
                    ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.48)
                  : Theme.of(context).dividerColor.withValues(alpha: 0.26),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: selected ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _EngineBadge(label: badge, color: accent),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: selected
                    ? Icon(
                        Icons.check_circle_rounded,
                        key: const ValueKey('selected'),
                        color: accent,
                        size: 21,
                      )
                    : Icon(
                        Icons.chevron_right_rounded,
                        key: const ValueKey('idle'),
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        size: 21,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EngineBadge extends StatelessWidget {
  const _EngineBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CompanionLandscapeBotSetupLayout extends StatefulWidget {
  const _CompanionLandscapeBotSetupLayout({
    required this.spacing,
    required this.height,
    required this.stretchEngine,
    required this.matchRightContentHeight,
    required this.engine,
    required this.startingPosition,
    required this.playSettings,
    required this.pgnListSetting,
    required this.timeControl,
    required this.startButton,
    super.key,
  });

  final double spacing;
  final double height;
  final bool stretchEngine;
  final bool matchRightContentHeight;
  final Widget engine;
  final Widget startingPosition;
  final Widget playSettings;
  final Widget pgnListSetting;
  final Widget timeControl;
  final Widget startButton;

  @override
  State<_CompanionLandscapeBotSetupLayout> createState() =>
      _CompanionLandscapeBotSetupLayoutState();
}

class _CompanionLandscapeBotSetupLayoutState
    extends State<_CompanionLandscapeBotSetupLayout> {
  final GlobalKey _rightContentKey = GlobalKey();
  double? _rightContentHeight;

  void _measureRightContent() {
    if (!widget.matchRightContentHeight) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderBox =
          _rightContentKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) return;
      final nextHeight = renderBox.size.height;
      if ((_rightContentHeight ?? -1) == nextHeight) return;
      setState(() => _rightContentHeight = nextHeight);
    });
  }

  @override
  Widget build(BuildContext context) {
    _measureRightContent();
    final matchedHeight = widget.matchRightContentHeight
        ? ((_rightContentHeight ?? widget.height) +
                (_rightContentHeight == null ? 0 : 8))
            .clamp(0.0, widget.height)
            .toDouble()
        : widget.height;
    return SizedBox(
      height: matchedHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: _CompanionLandscapeScroll(
              stretchChild: widget.stretchEngine,
              child: widget.engine,
            ),
          ),
          SizedBox(width: widget.spacing),
          Expanded(
            flex: 5,
            child: _CompanionLandscapeNaturalScroll(
              fillAvailableHeight: !widget.matchRightContentHeight,
              spacing: widget.spacing,
              children: [
                widget.startingPosition,
                widget.playSettings,
                widget.pgnListSetting,
              ],
            ),
          ),
          SizedBox(width: widget.spacing),
          Expanded(
            flex: 4,
            child: KeyedSubtree(
              key: const ValueKey('bot-setup-time-column'),
              child: _CompanionLandscapeNaturalScroll(
                contentKey: _rightContentKey,
                fillAvailableHeight: !widget.matchRightContentHeight,
                spacing: widget.spacing,
                children: [
                  widget.timeControl,
                  SizedBox(
                    width: double.infinity,
                    child: widget.startButton,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanionLandscapeScroll extends StatelessWidget {
  const _CompanionLandscapeScroll({
    required this.stretchChild,
    required this.child,
  });

  final bool stretchChild;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 386.0;
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            child: stretchChild
                ? SizedBox(height: height, child: SizedBox.expand(child: child))
                : child,
          ),
        );
      },
    );
  }
}

class _CompanionLandscapeNaturalScroll extends StatelessWidget {
  const _CompanionLandscapeNaturalScroll({
    required this.spacing,
    required this.children,
    this.contentKey,
    this.fillAvailableHeight = true,
  });

  final double spacing;
  final List<Widget> children;
  final Key? contentKey;
  final bool fillAvailableHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = fillAvailableHeight && constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 0.0;
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: KeyedSubtree(
                key: contentKey,
                child: SectionColumn(
                  spacing: spacing,
                  children: children,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BotPlaySettingsCard extends StatelessWidget {
  const _BotPlaySettingsCard({
    required this.side,
    required this.onSideChanged,
    super.key,
  });

  final _BotSideOption side;
  final ValueChanged<_BotSideOption> onSideChanged;

  @override
  Widget build(BuildContext context) {
    final compactLandscape = isCompactLandscapeDevice(context);
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 13,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Play settings',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          SizedBox(height: compactLandscape ? 8 : 10),
          if (compactLandscape)
            SizedBox(
              height: 38,
              child: _BotSidePickerTiles(
                side: side,
                onSideChanged: onSideChanged,
              ),
            )
          else
            SegmentedButton<_BotSideOption>(
              key: const ValueKey('bot-side-segment'),
              expandedInsets: EdgeInsets.zero,
              segments: const [
                ButtonSegment(
                  value: _BotSideOption.random,
                  icon: Icon(Icons.casino_rounded),
                  label: Text('Random'),
                ),
                ButtonSegment(
                  value: _BotSideOption.white,
                  icon: Icon(Icons.circle_outlined),
                  label: Text('White'),
                ),
                ButtonSegment(
                  value: _BotSideOption.black,
                  icon: Icon(Icons.circle),
                  label: Text('Black'),
                ),
              ],
              selected: {side},
              onSelectionChanged: (value) => onSideChanged(value.first),
            ),
        ],
      ),
    );
  }
}

class _BotPgnListSetting extends StatelessWidget {
  const _BotPgnListSetting({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      borderRadius: 13,
      child: SwitchListTile.adaptive(
        key: const ValueKey('bot-show-pgn-list-toggle'),
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'Show PGN move list',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        subtitle: const Text(
          'Keep the move list visible during bot games.',
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _BotSidePickerTiles extends StatelessWidget {
  const _BotSidePickerTiles({
    required this.side,
    required this.onSideChanged,
  });

  final _BotSideOption side;
  final ValueChanged<_BotSideOption> onSideChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('bot-side-segment'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in _BotSideOption.values) ...[
          Expanded(
            child: _BotSideTile(
              key: ValueKey('bot-side-${option.name}'),
              option: option,
              selected: side == option,
              onTap: () => onSideChanged(option),
            ),
          ),
          if (option != _BotSideOption.black) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _BotSideTile extends StatelessWidget {
  const _BotSideTile({
    required this.option,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final _BotSideOption option;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (option) {
        _BotSideOption.random => Icons.casino_rounded,
        _BotSideOption.white => Icons.circle_outlined,
        _BotSideOption.black => Icons.circle,
      };

  String get _label => switch (option) {
        _BotSideOption.random => 'Random',
        _BotSideOption.white => 'White',
        _BotSideOption.black => 'Black',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.secondary;
    final compactLandscape = isCompactLandscapeDevice(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: EdgeInsets.symmetric(
              horizontal: compactLandscape ? 7 : 8,
              vertical: compactLandscape ? 6 : 9,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: selected ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: color.withValues(alpha: selected ? 0.48 : 0.18),
              ),
            ),
            child: compactLandscape
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_icon, color: color, size: 16),
                      const SizedBox(width: 4),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _label,
                            maxLines: 1,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_icon, color: color, size: 22),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _label,
                          maxLines: 1,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
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

class _TimeControlCard extends StatelessWidget {
  const _TimeControlCard({
    required this.selected,
    this.options = const [
      _TimeControlOption(
          label: '3+0', minutes: 3, increment: 0, speed: 'Blitz'),
      _TimeControlOption(
          label: '5+3', minutes: 5, increment: 3, speed: 'Blitz'),
      _TimeControlOption(
          label: '10+5', minutes: 10, increment: 5, speed: 'Rapid'),
      _TimeControlOption(
          label: '15+10', minutes: 15, increment: 10, speed: 'Rapid'),
    ],
    this.onSelected,
    this.onCustom,
    this.footerBuilder,
    super.key,
  });

  final _TimeControlOption selected;
  final List<_TimeControlOption> options;
  final ValueChanged<_TimeControlOption>? onSelected;
  final VoidCallback? onCustom;
  final String Function(_TimeControlOption selected)? footerBuilder;

  @override
  Widget build(BuildContext context) {
    final selectedPreset = options.any((option) =>
        option.minutes == selected.minutes &&
        option.increment == selected.increment &&
        !selected.custom);
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 13,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Time control',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(selected.speed),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: onCustom,
                icon: const Icon(Icons.tune_rounded, size: 17),
                label: const Text('Custom'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                _TimeChip(
                  label: option.label,
                  selected: selectedPreset &&
                      option.minutes == selected.minutes &&
                      option.increment == selected.increment,
                  onTap: onSelected == null ? null : () => onSelected!(option),
                ),
              if (selected.custom)
                _TimeChip(label: selected.label, selected: true),
            ],
          ),
          const SizedBox(height: 10),
          if (footerBuilder != null) ...[
            _ApiHint(text: footerBuilder!(selected)),
          ],
        ],
      ),
    );
  }
}

class _BotEngineSection extends StatelessWidget {
  const _BotEngineSection({
    required this.selected,
    required this.onSelect,
    this.compactLandscape = false,
    super.key,
  });

  final _BotEngineOption selected;
  final ValueChanged<_BotEngineOption> onSelect;
  final bool compactLandscape;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 13,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Engine',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 10),
          SectionColumn(
            spacing: 8,
            children: [
              _EngineCard(
                title: 'Maia',
                subtitle: 'Local Maia weights, 1100-1900 strength',
                badge: 'Local',
                icon: Icons.psychology_rounded,
                selected: selected == _BotEngineOption.maia,
                onTap: () => onSelect(_BotEngineOption.maia),
              ),
              _EngineCard(
                title: 'Maia 3',
                subtitle: 'Cloud human model, official 600-2600 Elo range',
                badge: 'Cloud',
                icon: Icons.cloud_queue_rounded,
                selected: selected == _BotEngineOption.maia3,
                onTap: () => onSelect(_BotEngineOption.maia3),
              ),
              _EngineCard(
                title: 'Stockfish',
                subtitle: 'Classic engine with Elo tuning',
                badge: 'UCI',
                icon: Icons.memory_rounded,
                selected: selected == _BotEngineOption.stockfish,
                onTap: () => onSelect(_BotEngineOption.stockfish),
              ),
              _EngineCard(
                title: 'LC0',
                subtitle: 'Custom trained Chessnut weights',
                badge: 'Lab',
                icon: Icons.bolt_rounded,
                selected: selected == _BotEngineOption.lc0,
                onTap: () => onSelect(_BotEngineOption.lc0),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StartingPositionSection extends StatelessWidget {
  const _StartingPositionSection({
    required this.selected,
    required this.selectedOpening,
    required this.onSelectStandard,
    required this.onSelectOpening,
    required this.onSelectChess960,
    required this.onSelectBoardEditor,
    required this.onChooseOpening,
    super.key,
  });

  final _BotStartingPositionOption selected;
  final OpeningScenario selectedOpening;
  final VoidCallback onSelectStandard;
  final VoidCallback onSelectOpening;
  final VoidCallback onSelectChess960;
  final VoidCallback onSelectBoardEditor;
  final VoidCallback onChooseOpening;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compactLandscape = isCompactLandscapeDevice(context);
    return GlassPanel(
      padding: EdgeInsets.all(compactLandscape ? 8 : 12),
      borderRadius: 13,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!compactLandscape) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.flag_rounded,
                    color: scheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Starting position',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: compactLandscape ? 16 : 17,
                      ),
                    ),
                    if (!compactLandscape) ...[
                      const SizedBox(height: 2),
                      const Text(
                        'Choose the initial board before engine settings.',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compactLandscape ? 5 : 8),
          GlassPanel(
            padding: EdgeInsets.all(compactLandscape ? 3 : 5),
            borderRadius: 12,
            tint: Theme.of(context).brightness == Brightness.dark
                ? const Color(0x8A020617)
                : const Color(0xD9FFFFFF),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 300 ? 2 : 1;
                const spacing = 7.0;
                const selectedAccent = ChessnutTheme.green;
                final tileWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                final tiles = [
                  _StartModeSegment(
                    key: const ValueKey('starting-standard'),
                    width: tileWidth,
                    label: 'Standard',
                    icon: Icons.grid_4x4_rounded,
                    selected: selected == _BotStartingPositionOption.standard,
                    accent: selectedAccent,
                    onTap: onSelectStandard,
                    compact: compactLandscape,
                  ),
                  _StartModeSegment(
                    key: const ValueKey('starting-opening'),
                    width: tileWidth,
                    label: 'Opening',
                    icon: Icons.route_rounded,
                    selected: selected == _BotStartingPositionOption.opening,
                    accent: selectedAccent,
                    onTap: onSelectOpening,
                    compact: compactLandscape,
                  ),
                  _StartModeSegment(
                    key: const ValueKey('starting-chess960'),
                    width: tileWidth,
                    label: 'Chess960',
                    icon: Icons.shuffle_rounded,
                    selected: selected == _BotStartingPositionOption.chess960,
                    accent: selectedAccent,
                    onTap: onSelectChess960,
                    compact: compactLandscape,
                  ),
                  _StartModeSegment(
                    key: const ValueKey('starting-board-editor'),
                    width: tileWidth,
                    label: 'Board editor',
                    icon: Icons.dashboard_customize_rounded,
                    selected:
                        selected == _BotStartingPositionOption.boardEditor,
                    accent: selectedAccent,
                    onTap: onSelectBoardEditor,
                    compact: compactLandscape,
                  ),
                ];
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: tiles,
                );
              },
            ),
          ),
          if (selected == _BotStartingPositionOption.opening) ...[
            SizedBox(height: compactLandscape ? 5 : 6),
            _SelectedOpeningRow(
              scenario: selectedOpening,
              onChooseOpening: onChooseOpening,
              compactLandscape: compactLandscape,
            ),
          ],
        ],
      ),
    );
  }
}

class _StartModeSegment extends StatelessWidget {
  const _StartModeSegment({
    super.key,
    required this.width,
    required this.label,
    required this.selected,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.compact = false,
  });

  final double width;
  final String label;
  final bool selected;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: BoxConstraints(minHeight: compact ? 42 : 56),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 7 : 10,
              vertical: compact ? 5 : 8,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.50)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: compact ? 26 : 32,
                  height: compact ? 26 : 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: selected ? 0.16 : 0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    icon,
                    size: compact ? 15 : 18,
                    color: selected
                        ? accent
                        : Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                SizedBox(width: compact ? 6 : 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          color: selected ? accent : null,
                          fontWeight: FontWeight.w900,
                          fontSize: compact ? 13 : 16,
                        ),
                      ),
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 5),
                  Icon(
                    Icons.check_circle_rounded,
                    color: accent,
                    size: compact ? 15 : 18,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedOpeningRow extends StatelessWidget {
  const _SelectedOpeningRow({
    required this.scenario,
    required this.onChooseOpening,
    this.compactLandscape = false,
  });

  final OpeningScenario scenario;
  final VoidCallback onChooseOpening;
  final bool compactLandscape;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final metaText = '${scenario.eco} - ${scenario.moves}';
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = compactLandscape || constraints.maxWidth < 380;
        return Container(
          key: const ValueKey('selected-opening-row'),
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: compactLandscape ? 8 : 10,
            vertical: compactLandscape ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.16)),
          ),
          child: compact
              ? Row(
                  children: [
                    Expanded(
                      child: _OpeningSummaryText(
                        scenario: scenario,
                        metaText: metaText,
                        dense: compactLandscape,
                      ),
                    ),
                    SizedBox(width: compactLandscape ? 6 : 8),
                    SizedBox(
                      width: compactLandscape ? 104 : 136,
                      child: OutlinedButton(
                        key: const ValueKey('choose-opening-button'),
                        onPressed: onChooseOpening,
                        child: Text(
                            compactLandscape ? 'Choose' : 'Choose opening'),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _OpeningSummaryText(
                        scenario: scenario,
                        metaText: metaText,
                        dense: compactLandscape,
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      key: const ValueKey('choose-opening-button'),
                      onPressed: onChooseOpening,
                      child: const Text('Choose'),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class BotBoardEditorSheet extends StatefulWidget {
  const BotBoardEditorSheet({
    required this.initialFen,
    required this.openInFenMode,
    this.boardGateway,
    this.boardSettings = const BoardSettingsState(),
    this.imagePicker,
    this.fenRecognizer,
    this.isChessnutClockDevice = false,
    this.showBoardCoordinates = false,
    this.hidePhysicalBoardConnectionUi = false,
    this.scrollController,
    super.key,
  });

  final String initialFen;
  final bool openInFenMode;
  final PhysicalBoardGateway? boardGateway;
  final BoardSettingsState boardSettings;
  final BoardVisionImagePicker? imagePicker;
  final BoardVisionFenRecognizer? fenRecognizer;
  final bool isChessnutClockDevice;
  final bool showBoardCoordinates;
  final bool hidePhysicalBoardConnectionUi;
  final ScrollController? scrollController;

  @override
  State<BotBoardEditorSheet> createState() => _BotBoardEditorSheetState();
}

class _BotBoardEditorSheetState extends State<BotBoardEditorSheet> {
  late int mode;
  bool physicalPositionRotated = false;
  bool whiteKingSide = true;
  bool whiteQueenSide = true;
  bool blackKingSide = true;
  bool blackQueenSide = true;
  bool whiteToMove = true;
  String? enPassantSquare;
  late String boardFen;
  String? physicalBoardFen;
  String? targetBoardFen;
  List<BoardPiece>? physicalBoardPieces;
  bool visionBusy = false;
  String? visionMessage;
  BoardVisionFenResult? visionResult;
  String? message;
  double? _lastUnobscuredHeight;
  StreamSubscription<String>? _boardFenSub;
  final BoardEditorPlacementLedFeedback _placementLedFeedback =
      BoardEditorPlacementLedFeedback();
  late final BoardFenStabilityBuffer _boardFenStabilityBuffer;
  late final PhysicalBoardOrientationResolver _boardOrientation;
  late final TextEditingController _fenController;
  late final BoardVisionImagePicker _imagePicker;
  late final BoardVisionFenRecognizer _fenRecognizer;

  @override
  void initState() {
    super.initState();
    _boardOrientation = PhysicalBoardOrientationResolver(
      settings: widget.boardSettings,
    );
    mode = widget.openInFenMode ? 1 : 0;
    boardFen =
        _normalizeBotEditorFen(widget.initialFen) ?? chessnutStandardStartFen;
    _applyControlsFromFen(boardFen);
    _fenController = TextEditingController(text: boardFen);
    _imagePicker = widget.imagePicker ?? PlatformBoardVisionImagePicker();
    _fenRecognizer = widget.fenRecognizer ?? PlatformBoardVisionFenRecognizer();
    _boardFenStabilityBuffer = BoardFenStabilityBuffer(
      onStableFen: _applyPhysicalBoardFen,
    );
    _startPhysicalBoardSync();
  }

  @override
  void didUpdateWidget(covariant BotBoardEditorSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    _boardOrientation.updateSettings(widget.boardSettings);
    if (!identical(oldWidget.boardGateway, widget.boardGateway)) {
      _startPhysicalBoardSync();
    }
  }

  @override
  void dispose() {
    unawaited(_placementLedFeedback.cancel(widget.boardGateway));
    unawaited(_boardFenSub?.cancel());
    _boardFenStabilityBuffer.dispose();
    _fenController.dispose();
    super.dispose();
  }

  void _startPhysicalBoardSync() {
    unawaited(_boardFenSub?.cancel());
    final gateway = widget.boardGateway;
    if (gateway == null) return;
    _boardFenSub = gateway.boardFenStream.listen((fen) {
      final boardOnly = physicalBoardOnlyFen(fen);
      _boardFenStabilityBuffer.add(
        mode == 0
            ? boardOnly
            : _boardOrientation.normalize(
                boardOnly,
                referenceFens: [boardFen],
              ),
      );
    });
    if (mode == 0 &&
        gateway.currentState == PhysicalBoardConnectionState.connected) {
      unawaited(gateway.enableRealtimeFen());
    }
  }

  void _applyControlsFromFen(String fen) {
    final fields = fen.trim().split(RegExp(r'\s+'));
    if (fields.length >= 2) {
      whiteToMove = fields[1] != 'b';
    }
    if (fields.length >= 3) {
      final castling = fields[2];
      whiteKingSide = castling.contains('K');
      whiteQueenSide = castling.contains('Q');
      blackKingSide = castling.contains('k');
      blackQueenSide = castling.contains('q');
    }
    enPassantSquare = boardEditorEnPassantSquareFromFen(fen);
  }

  void _applyPhysicalBoardFen(String fen) {
    if (!mounted) return;
    final physicalBoardOnly = fen.trim().split(RegExp(r'\s+')).first;
    if (_expandedBotBoard(physicalBoardOnly) == null) return;
    physicalBoardFen = physicalBoardOnly;
    if (mode != 0) {
      final target = targetBoardFen;
      final gateway = widget.boardGateway;
      if (target != null &&
          gateway != null &&
          gateway.boardModel != PhysicalBoardModel.move &&
          gateway.currentState == PhysicalBoardConnectionState.connected) {
        unawaited(_lightFenDiffOnGeneralBoard(gateway, target));
      }
      return;
    }
    final boardOnly = physicalPositionRotated
        ? rotateFenPieces180(physicalBoardOnly)
        : physicalBoardOnly;
    if (boardOnly == null) return;
    final gateway = widget.boardGateway;
    if (gateway != null) {
      unawaited(
        _placementLedFeedback.showPosition(
          gateway: gateway,
          boardFen: physicalBoardOnly,
        ),
      );
    }
    final nextFen = _fullFenFromBoardOnly(boardOnly);
    setState(() {
      boardFen = nextFen;
      enPassantSquare = boardEditorEnPassantSquareFromFen(nextFen);
      _fenController.text = nextFen;
      physicalBoardPieces = _piecesFromBoardOnlyFen(boardOnly);
      message = 'Physical board position captured.';
    });
  }

  String _fullFenFromBoardOnly(String boardOnly) {
    return boardEditorFenWithEnPassant(
      '$boardOnly ${whiteToMove ? 'w' : 'b'} ${_castlingFen()} - 0 1',
      enPassantSquare,
    );
  }

  String _castlingFen() {
    final rights = StringBuffer();
    if (whiteKingSide) rights.write('K');
    if (whiteQueenSide) rights.write('Q');
    if (blackKingSide) rights.write('k');
    if (blackQueenSide) rights.write('q');
    return rights.isEmpty ? '-' : rights.toString();
  }

  void _selectEnPassantSquare(String? square) {
    final sourceFen = mode == 0 ? boardFen : _fenController.text.trim();
    final fields = sourceFen.split(RegExp(r'\s+'));
    final fullFen = boardEditorFenWithEnPassant(
      fields.length >= 6
          ? fields.take(6).join(' ')
          : _fullFenFromBoardOnly(fields.first),
      square,
    );
    setState(() {
      enPassantSquare = boardEditorEnPassantSquareFromFen(fullFen);
      boardFen = fullFen;
      _fenController.text = fullFen;
    });
  }

  void _selectBoardToAppMode() {
    _boardFenStabilityBuffer.reset();
    setState(() => mode = 0);
    final gateway = widget.boardGateway;
    if (gateway?.currentState == PhysicalBoardConnectionState.connected) {
      unawaited(gateway!.enableRealtimeFen());
    }
  }

  Future<void> _selectFenToBoardMode() async {
    await _placementLedFeedback.cancel(widget.boardGateway);
    if (!mounted) return;
    _boardFenStabilityBuffer.reset();
    setState(() {
      mode = 1;
      physicalBoardFen = null;
    });
    final gateway = widget.boardGateway;
    if (gateway?.currentState == PhysicalBoardConnectionState.connected) {
      unawaited(gateway!.enableRealtimeFen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final mediaSize = MediaQuery.sizeOf(context);
    // Keep the editor surface and the page background at their pre-keyboard
    // size. The keyboard is handled by the editor's own scroll view instead
    // of resizing the modal route behind it.
    return MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : mediaSize.height;
          if (keyboardInset <= 0 && availableHeight.isFinite) {
            _lastUnobscuredHeight = availableHeight;
          }
          final stableHeight = keyboardInset > 0
              ? (_lastUnobscuredHeight ?? availableHeight)
              : availableHeight;
          final bottomInset = math.max(
            keyboardInset,
            MediaQuery.viewPaddingOf(context).bottom,
          );
          final landscape = mediaSize.width > stableHeight &&
              stableHeight <= 620 &&
              mediaSize.width >= 700;
          final maxHeight = landscape
              ? stableHeight * 0.98
              : widget.scrollController == null
                  ? stableHeight * 0.88
                  : double.infinity;
          final scheme = Theme.of(context).colorScheme;
          return Material(
            key: const ValueKey('bot-board-editor-sheet-surface'),
            color: scheme.surface,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                0,
                14,
                (landscape ? 8 : 14) + bottomInset,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: landscape
                    ? _buildLandscapeSheet(context)
                    : _buildPortraitSheet(context),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPortraitSheet(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            child: SectionColumn(
              spacing: 12,
              children: [
                _buildModeSwitcher(context),
                if (!widget.hidePhysicalBoardConnectionUi)
                  _BotBoardEditorStatus(
                    mode: mode,
                    connected: widget.boardGateway?.currentState ==
                        PhysicalBoardConnectionState.connected,
                    message: message,
                  ),
                _buildBoardPreview(286),
                _buildControlsPane(context, compact: false),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildActions(context),
      ],
    );
  }

  Widget _buildLandscapeSheet(BuildContext context) {
    return Column(
      key: const ValueKey('bot-board-editor-landscape-layout'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context),
        const SizedBox(height: 6),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boardSize = math.min(
                      360.0,
                      math.max(120.0, constraints.maxWidth - 56),
                    );
                    return Center(
                      child: _buildBoardPreview(
                        boardSize,
                        tight: true,
                        compactTools: true,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 8,
                child: SingleChildScrollView(
                  key: const ValueKey('bot-board-editor-controls-pane'),
                  child: SectionColumn(
                    spacing: 8,
                    children: [
                      _buildModeSwitcher(context),
                      _buildControlsPane(context, compact: true),
                      _buildActions(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.dashboard_customize_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Board editor',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 2),
              Text('Choose the FEN before returning to bot setup.'),
            ],
          ),
        ),
        IconButton(
          onPressed: _rotatePieces,
          icon: const Icon(Icons.swap_vert_rounded),
          tooltip: 'Flip board',
        ),
      ],
    );
  }

  Widget _buildModeSwitcher(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(6),
      borderRadius: 16,
      tint: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Expanded(
            child: _BotBoardEditorModeButton(
              label: 'Board to app',
              icon: Icons.sync_rounded,
              selected: mode == 0,
              onTap: _selectBoardToAppMode,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _BotBoardEditorModeButton(
              label: 'FEN to board',
              icon: Icons.lightbulb_outline_rounded,
              selected: mode == 1,
              onTap: _selectFenToBoardMode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardPreview(
    double maxSize, {
    bool tight = false,
    bool compactTools = false,
  }) {
    final board = ResponsiveBoardFrame(
      maxSize: maxSize,
      padding: EdgeInsets.all(tight ? 2 : 10),
      builder: _buildBoardWidget,
    );
    if (!compactTools || widget.hidePhysicalBoardConnectionUi) return board;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        board,
        const SizedBox(width: 8),
        BoardEditorBoardTools(
          statusKey: const ValueKey('bot-board-editor-board-status-button'),
          connected: widget.boardGateway?.currentState ==
              PhysicalBoardConnectionState.connected,
          onStatusTap: _showBoardStatusDialog,
        ),
      ],
    );
  }

  Widget _buildBoardWidget(double size) {
    final pieces = physicalBoardPieces;
    if (pieces != null) {
      return ChessBoard(
        size: size,
        pieces: pieces,
        showCoordinates: widget.showBoardCoordinates,
      );
    }
    return InteractiveChessBoard(
      size: size,
      initialFen: boardFen,
      showCoordinates: widget.showBoardCoordinates,
      onMove: _handleInteractiveBoardMove,
    );
  }

  void _handleInteractiveBoardMove(ChessBoardMove move) {
    final fullFen = move.fen.trim();
    if (_expandedBotBoard(fullFen) == null) return;
    setState(() {
      boardFen = fullFen;
      _applyControlsFromFen(fullFen);
      _fenController.text = fullFen;
      physicalBoardPieces = null;
      targetBoardFen = null;
      message = null;
    });
  }

  void _rotatePieces() {
    final sourceFen = mode == 0 ? boardFen : _fenController.text.trim();
    final rawRotatedFen = rotateFenPieces180(sourceFen);
    if (rawRotatedFen == null) return;
    final rotatedFen = boardEditorFenWithEnPassant(rawRotatedFen, null);
    final boardOnly = rotatedFen.split(RegExp(r'\s+')).first;
    setState(() {
      if (mode == 0) {
        physicalPositionRotated = !physicalPositionRotated;
      }
      boardFen = rotatedFen;
      _applyControlsFromFen(rotatedFen);
      _fenController.text = rotatedFen;
      if (physicalBoardPieces != null) {
        physicalBoardPieces = _piecesFromBoardOnlyFen(boardOnly);
      }
      if (targetBoardFen != null) {
        targetBoardFen = boardOnly;
      }
    });
  }

  Widget _buildControlsPane(BuildContext context, {required bool compact}) {
    final visionAvailability = _imagePicker.availability(
      isChessnutClock: widget.isChessnutClockDevice,
    );
    return SectionColumn(
      spacing: compact ? 8 : 12,
      children: [
        if (mode == 0) ...[
          _buildBoardToAppControls(compact: compact),
        ] else ...[
          _BotFenPanel(
            compact: compact,
            controller: _fenController,
            onChanged: _applyFenInput,
          ),
          _buildBoardToAppControls(compact: compact),
          BoardEditorEnPassantControl(
            fieldKey: const ValueKey('bot-board-editor-en-passant-field'),
            availableSquares: legalBoardEditorEnPassantSquares(
              _fenController.text,
            ),
            selectedSquare: enPassantSquare,
            onChanged: _selectEnPassantSquare,
            compact: compact,
          ),
          if (visionAvailability.any)
            _BotVisionImportPanel(
              compact: compact,
              busy: visionBusy,
              result: visionResult,
              message: visionMessage,
              availability: visionAvailability,
              onGallery: visionBusy
                  ? null
                  : () => _recognizeFromSource(
                        BoardVisionImageSource.gallery,
                      ),
              onCamera: visionBusy
                  ? null
                  : () => _recognizeFromSource(
                        BoardVisionImageSource.camera,
                      ),
            ),
        ],
        if (mode == 0)
          BoardEditorEnPassantControl(
            fieldKey: const ValueKey('bot-board-editor-en-passant-field'),
            availableSquares: legalBoardEditorEnPassantSquares(boardFen),
            selectedSquare: enPassantSquare,
            onChanged: _selectEnPassantSquare,
            compact: compact,
          ),
        if (mode == 1)
          PrimaryButton(
            label: 'Send FEN to board',
            icon: Icons.lightbulb_outline_rounded,
            onPressed: _sendFenToBoard,
          ),
      ],
    );
  }

  Widget _buildBoardToAppControls({required bool compact}) {
    return _BotBoardToAppControls(
      compact: compact,
      whiteKingSide: whiteKingSide,
      whiteQueenSide: whiteQueenSide,
      blackKingSide: blackKingSide,
      blackQueenSide: blackQueenSide,
      whiteToMove: whiteToMove,
      onWhiteKingSideChanged: (value) => _updateEditorControl(
        () => whiteKingSide = value,
      ),
      onWhiteQueenSideChanged: (value) => _updateEditorControl(
        () => whiteQueenSide = value,
      ),
      onBlackKingSideChanged: (value) => _updateEditorControl(
        () => blackKingSide = value,
      ),
      onBlackQueenSideChanged: (value) => _updateEditorControl(
        () => blackQueenSide = value,
      ),
      onSideChanged: (value) => _updateEditorControl(
        () => whiteToMove = value,
      ),
    );
  }

  void _updateEditorControl(VoidCallback update) {
    setState(() {
      update();
      final sourceFen = mode == 0 ? boardFen : _fenController.text.trim();
      final fullFen = _replaceFenMetadata(sourceFen);
      boardFen = fullFen;
      _fenController.text = fullFen;
      if (mode == 1) {
        final boardOnly = fullFen.split(RegExp(r'\s+')).first;
        physicalBoardPieces = _piecesFromBoardOnlyFen(boardOnly);
      }
    });
  }

  Widget _buildActions(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: _usePosition,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Use this position'),
            ),
          ),
        ],
      ),
    );
  }

  String _replaceFenMetadata(String fen) {
    final boardOnly = fen.trim().split(RegExp(r'\s+')).first;
    final fullFen = _fullFenFromBoardOnly(boardOnly);
    enPassantSquare = boardEditorEnPassantSquareFromFen(fullFen);
    return fullFen;
  }

  void _applyFenInput(String value) {
    final fullFen = _normalizeBotEditorFen(value);
    final boardOnly = value.trim().split(RegExp(r'\s+')).first;
    if (_expandedBotBoard(boardOnly) == null) {
      setState(() => message = 'Paste a valid board FEN.');
      return;
    }
    setState(() {
      final normalized = fullFen ?? _fullFenFromBoardOnly(boardOnly);
      final selectedSquare = boardEditorEnPassantSquareFromFen(normalized);
      boardFen = boardEditorFenWithEnPassant(normalized, selectedSquare);
      _applyControlsFromFen(boardFen);
      physicalBoardPieces = _piecesFromBoardOnlyFen(boardOnly);
      message = null;
    });
  }

  Future<void> _sendFenToBoard() async {
    final sourceFen = _fenController.text.trim();
    final boardOnly = sourceFen.split(RegExp(r'\s+')).first;
    final fullFen = _normalizeBotEditorFen(sourceFen);
    if (fullFen == null || _expandedBotBoard(boardOnly) == null) {
      setState(() => message = 'Paste a valid FEN before sending.');
      return;
    }
    final castlingError = _castlingRightsValidationErrorForBotEditor(fullFen);
    if (castlingError != null) {
      setState(() => message = castlingError);
      return;
    }

    setState(() {
      boardFen = fullFen;
      targetBoardFen = boardOnly;
      physicalBoardPieces = _piecesFromBoardOnlyFen(boardOnly);
      message = 'Board preview updated.';
    });

    final gateway = widget.boardGateway;
    if (gateway == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      setState(() => message = 'Connect a physical board before sending FEN.');
      return;
    }

    await _placementLedFeedback.cancel(gateway);
    final ok = gateway.boardModel == PhysicalBoardModel.move
        ? await gateway.setMoveBoardFen(
            fullFen,
            isReverse: _boardOrientation.isReversed,
          )
        : await _lightFenDiffOnGeneralBoard(gateway, boardOnly);
    if (!mounted) return;
    setState(() {
      message = ok
          ? 'FEN sent to board.'
          : 'The physical board did not accept the FEN command.';
    });
  }

  Future<void> _recognizeFromSource(BoardVisionImageSource source) async {
    setState(() {
      visionBusy = true;
      visionMessage = 'Recognizing board image...';
      visionResult = null;
      message = visionMessage;
    });
    try {
      final image = await _imagePicker.pick(source);
      if (!mounted) return;
      if (image == null) {
        setState(() {
          visionBusy = false;
          visionMessage = 'No image selected.';
          message = visionMessage;
        });
        return;
      }

      final fen = await _fenRecognizer.recognizeFen(image.bytes);
      if (!mounted) return;
      if (fen == null || fen.trim().isEmpty) {
        setState(() {
          visionBusy = false;
          visionMessage = 'Chessnut Vision could not recognize this position.';
          message = visionMessage;
        });
        return;
      }
      _applyVisionFen(
        BoardVisionFenResult(
          fen: fen,
          confidence: 1,
          source: 'local_yolov5vision',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        visionBusy = false;
        visionMessage =
            'Chessnut Vision could not read this image. Try a clearer photo.';
        message = visionMessage;
      });
    }
  }

  void _applyVisionFen(BoardVisionFenResult result) {
    final fullFen = _normalizeBotEditorFen(result.fen);
    final boardOnly = (fullFen ?? result.fen).split(RegExp(r'\s+')).first;
    if (fullFen == null || _expandedBotBoard(boardOnly) == null) {
      setState(() {
        visionBusy = false;
        visionMessage =
            'Chessnut Vision returned a position the board could not read.';
        visionResult = result;
        message = visionMessage;
      });
      return;
    }

    _boardFenStabilityBuffer.reset();
    setState(() {
      mode = 1;
      boardFen = fullFen;
      _applyControlsFromFen(fullFen);
      _fenController.text = fullFen;
      targetBoardFen = null;
      physicalBoardFen = null;
      physicalBoardPieces = _piecesFromBoardOnlyFen(boardOnly);
      visionBusy = false;
      visionResult = result;
      visionMessage = 'Position imported from image.';
      message = visionMessage;
    });
    final gateway = widget.boardGateway;
    if (gateway?.currentState == PhysicalBoardConnectionState.connected) {
      unawaited(gateway!.enableRealtimeFen());
    }
  }

  void _showBoardStatusDialog() {
    final connected = widget.boardGateway?.currentState ==
        PhysicalBoardConnectionState.connected;
    final title = mode == 0 && connected
        ? 'Physical board sync is live'
        : mode == 1
            ? 'FEN guides the physical board'
            : 'Board sync';
    final subtitle = message ??
        (mode == 0
            ? connected
                ? 'Pieces placed on board update this position automatically.'
                : 'Connect a physical board or switch to FEN to board.'
            : 'Paste a FEN, preview it, and optionally send it to the board.');
    _showBotEditorInfoDialog(
      title: title,
      subtitle: subtitle,
      icon: connected ? Icons.sensors_rounded : Icons.sensors_off_rounded,
    );
  }

  void _showBotEditorInfoDialog({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => AppDialogShell(
        icon: icon,
        title: title,
        subtitle: subtitle,
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

  Future<bool> _lightFenDiffOnGeneralBoard(
    PhysicalBoardGateway gateway,
    String targetBoardFen,
  ) async {
    final current = physicalBoardFen;
    final squares = _differentBotSquares(current, targetBoardFen);
    if (squares.isEmpty) return gateway.clearGeneralLeds();
    return gateway.setGeneralLedSquares(
      _boardOrientation.toPhysicalSquares(squares),
    );
  }

  void _usePosition() {
    final sourceFen = mode == 0 ? boardFen : _fenController.text.trim();
    final fullFen = _normalizeBotEditorFen(sourceFen);
    if (fullFen == null) {
      setState(() => message = 'Use a legal chess position before continuing.');
      return;
    }
    final castlingError = _castlingRightsValidationErrorForBotEditor(fullFen);
    if (castlingError != null) {
      setState(() => message = castlingError);
      return;
    }
    Navigator.of(context).pop(fullFen);
  }
}

class _BotBoardEditorModeButton extends StatelessWidget {
  const _BotBoardEditorModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.secondary;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.16 : 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.40)
                : Theme.of(context).dividerColor.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? color : null,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotBoardEditorStatus extends StatelessWidget {
  const _BotBoardEditorStatus({
    required this.mode,
    required this.connected,
    this.message,
  });

  final int mode;
  final bool connected;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveMessage = message ??
        (mode == 0
            ? connected
                ? 'Set up pieces on the physical board, then use the captured FEN.'
                : 'Connect a physical board or switch to FEN to board.'
            : 'Paste a FEN, preview it, and optionally send it to the board.');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.16)),
      ),
      child: Text(
        effectiveMessage,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _BotBoardToAppControls extends StatelessWidget {
  const _BotBoardToAppControls({
    this.compact = false,
    required this.whiteKingSide,
    required this.whiteQueenSide,
    required this.blackKingSide,
    required this.blackQueenSide,
    required this.whiteToMove,
    required this.onWhiteKingSideChanged,
    required this.onWhiteQueenSideChanged,
    required this.onBlackKingSideChanged,
    required this.onBlackQueenSideChanged,
    required this.onSideChanged,
  });

  final bool compact;
  final bool whiteKingSide;
  final bool whiteQueenSide;
  final bool blackKingSide;
  final bool blackQueenSide;
  final bool whiteToMove;
  final ValueChanged<bool> onWhiteKingSideChanged;
  final ValueChanged<bool> onWhiteQueenSideChanged;
  final ValueChanged<bool> onBlackKingSideChanged;
  final ValueChanged<bool> onBlackQueenSideChanged;
  final ValueChanged<bool> onSideChanged;

  @override
  Widget build(BuildContext context) {
    return SectionColumn(
      spacing: compact ? 8 : 10,
      children: [
        GlassPanel(
          padding: EdgeInsets.all(compact ? 8 : 12),
          tint: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: compact
              ? Row(
                  children: [
                    const SizedBox(
                      width: 102,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Side to move',
                          maxLines: 1,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BotSideButton(
                        label: 'White',
                        icon: Icons.circle_outlined,
                        selected: whiteToMove,
                        height: 36,
                        onTap: () => onSideChanged(true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BotSideButton(
                        label: 'Black',
                        icon: Icons.circle,
                        selected: !whiteToMove,
                        height: 36,
                        onTap: () => onSideChanged(false),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Side to move',
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _BotSideButton(
                            label: 'White',
                            icon: Icons.circle_outlined,
                            selected: whiteToMove,
                            onTap: () => onSideChanged(true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _BotSideButton(
                            label: 'Black',
                            icon: Icons.circle,
                            selected: !whiteToMove,
                            onTap: () => onSideChanged(false),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        GlassPanel(
          padding: EdgeInsets.all(compact ? 10 : 12),
          tint: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Castling rights',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 4),
              _BotCastlingRightsRows(
                whiteKingSide: whiteKingSide,
                whiteQueenSide: whiteQueenSide,
                blackKingSide: blackKingSide,
                blackQueenSide: blackQueenSide,
                onWhiteKingSideChanged: onWhiteKingSideChanged,
                onWhiteQueenSideChanged: onWhiteQueenSideChanged,
                onBlackKingSideChanged: onBlackKingSideChanged,
                onBlackQueenSideChanged: onBlackQueenSideChanged,
                compact: compact,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BotFenPanel extends StatelessWidget {
  const _BotFenPanel({
    this.compact = false,
    required this.controller,
    required this.onChanged,
  });

  final bool compact;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.all(compact ? 10 : 12),
      tint: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FEN position',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('bot-board-editor-fen-field'),
            controller: controller,
            minLines: compact ? 1 : 2,
            maxLines: compact ? 2 : 3,
            onChanged: onChanged,
            decoration: const InputDecoration(
              labelText: 'FEN',
              prefixIcon: Icon(Icons.text_fields_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotVisionImportPanel extends StatelessWidget {
  const _BotVisionImportPanel({
    required this.busy,
    required this.availability,
    required this.onGallery,
    required this.onCamera,
    this.result,
    this.message,
    this.compact = false,
  });

  final bool busy;
  final BoardVisionSourceAvailability availability;
  final VoidCallback? onGallery;
  final VoidCallback? onCamera;
  final BoardVisionFenResult? result;
  final String? message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final confidence = result == null
        ? ''
        : '${(result!.confidence * 100).clamp(0, 100).round()}%';
    return GlassPanel(
      padding: EdgeInsets.all(compact ? 9 : 12),
      tint: scheme.primary.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 32 : 38,
                height: compact ? 32 : 38,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.document_scanner_rounded,
                  color: scheme.primary,
                ),
              ),
              SizedBox(width: compact ? 8 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chessnut Vision',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 15 : 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Import a board position from a photo.',
                      maxLines: compact ? 1 : null,
                      overflow: compact ? TextOverflow.ellipsis : null,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (confidence.isNotEmpty)
                _BotVisionConfidencePill(label: confidence),
            ],
          ),
          SizedBox(height: compact ? 7 : 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (availability.gallery)
                FilledButton.icon(
                  onPressed: onGallery,
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Choose image'),
                ),
              if (availability.camera)
                OutlinedButton.icon(
                  onPressed: onCamera,
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: const Text('Camera'),
                ),
            ],
          ),
          if ((message ?? '').trim().isNotEmpty) ...[
            SizedBox(height: compact ? 5 : 8),
            Text(
              message!,
              maxLines: compact ? 1 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: result == null ? scheme.onSurfaceVariant : null,
                    fontWeight: result == null ? null : FontWeight.w700,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BotVisionConfidencePill extends StatelessWidget {
  const _BotVisionConfidencePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _BotCastlingRightsRows extends StatelessWidget {
  const _BotCastlingRightsRows({
    required this.whiteKingSide,
    required this.whiteQueenSide,
    required this.blackKingSide,
    required this.blackQueenSide,
    required this.onWhiteKingSideChanged,
    required this.onWhiteQueenSideChanged,
    required this.onBlackKingSideChanged,
    required this.onBlackQueenSideChanged,
    required this.compact,
  });

  final bool whiteKingSide;
  final bool whiteQueenSide;
  final bool blackKingSide;
  final bool blackQueenSide;
  final ValueChanged<bool> onWhiteKingSideChanged;
  final ValueChanged<bool> onWhiteQueenSideChanged;
  final ValueChanged<bool> onBlackKingSideChanged;
  final ValueChanged<bool> onBlackQueenSideChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SectionColumn(
      spacing: compact ? 4 : 8,
      children: [
        _BotCastlingRightsRow(
          sideLabel: 'White',
          kingSide: whiteKingSide,
          queenSide: whiteQueenSide,
          onKingSideChanged: onWhiteKingSideChanged,
          onQueenSideChanged: onWhiteQueenSideChanged,
        ),
        _BotCastlingRightsRow(
          sideLabel: 'Black',
          kingSide: blackKingSide,
          queenSide: blackQueenSide,
          onKingSideChanged: onBlackKingSideChanged,
          onQueenSideChanged: onBlackQueenSideChanged,
        ),
      ],
    );
  }
}

class _BotCastlingRightsRow extends StatelessWidget {
  const _BotCastlingRightsRow({
    required this.sideLabel,
    required this.kingSide,
    required this.queenSide,
    required this.onKingSideChanged,
    required this.onQueenSideChanged,
  });

  final String sideLabel;
  final bool kingSide;
  final bool queenSide;
  final ValueChanged<bool> onKingSideChanged;
  final ValueChanged<bool> onQueenSideChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              sideLabel,
              maxLines: 1,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _BotCastlingButton(
            label: 'O-O',
            value: kingSide,
            onChanged: onKingSideChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _BotCastlingButton(
            label: 'O-O-O',
            value: queenSide,
            onChanged: onQueenSideChanged,
          ),
        ),
      ],
    );
  }
}

class _BotCastlingButton extends StatelessWidget {
  const _BotCastlingButton({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: value
          ? scheme.primary.withValues(alpha: 0.14)
          : scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onChanged(!value),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: value
                  ? scheme.primary.withValues(alpha: 0.42)
                  : scheme.outlineVariant.withValues(alpha: 0.42),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                value
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 18,
                color: value ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotSideButton extends StatelessWidget {
  const _BotSideButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.height = 46,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.secondary;
    return Material(
      color: color.withValues(alpha: selected ? 0.13 : 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: selected ? 0.42 : 0.12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? color : null,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpeningSummaryText extends StatelessWidget {
  const _OpeningSummaryText({
    required this.scenario,
    required this.metaText,
    this.dense = false,
  });

  final OpeningScenario scenario;
  final String metaText;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: dense ? 24 : 28,
          height: dense ? 24 : 28,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            Icons.menu_book_rounded,
            color: scheme.primary,
            size: dense ? 15 : 17,
          ),
        ),
        SizedBox(width: dense ? 6 : 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                scenario.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: dense ? 13 : null,
                ),
              ),
              Text(
                metaText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OpeningPickerDialog extends StatefulWidget {
  const _OpeningPickerDialog({
    required this.selected,
    required this.favoriteOpeningIds,
    required this.onToggleFavorite,
  });

  final OpeningScenario selected;
  final Set<String> favoriteOpeningIds;
  final ValueChanged<String> onToggleFavorite;

  @override
  State<_OpeningPickerDialog> createState() => _OpeningPickerDialogState();
}

class _OpeningPickerDialogState extends State<_OpeningPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  late Set<String> _favoriteOpeningIds;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _favoriteOpeningIds = Set<String>.from(widget.favoriteOpeningIds);
  }

  void _toggleFavorite(String id) {
    setState(() {
      if (!_favoriteOpeningIds.add(id)) _favoriteOpeningIds.remove(id);
    });
    widget.onToggleFavorite(id);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<OpeningScenario> get _results {
    final query = _query.trim().toLowerCase();
    final openings =
        botOpeningScenarios.where((scenario) => !scenario.isStandard);
    final filtered = query.isEmpty
        ? openings
        : openings.where((scenario) {
            return scenario.name.toLowerCase().contains(query) ||
                scenario.eco.toLowerCase().contains(query) ||
                scenario.moves.toLowerCase().contains(query) ||
                scenario.focus.toLowerCase().contains(query);
          });
    final result = filtered.toList(growable: false);
    return [
      ...result.where((opening) => _favoriteOpeningIds.contains(opening.id)),
      ...result.where((opening) => !_favoriteOpeningIds.contains(opening.id)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final showFavoriteSection =
        _query.trim().isEmpty && _favoriteOpeningIds.isNotEmpty;
    final favoriteResults = results
        .where((opening) => _favoriteOpeningIds.contains(opening.id))
        .toList(growable: false);
    final size = MediaQuery.sizeOf(context);
    final compactLandscape = isCompactLandscapeDevice(context);
    final listHeight = (size.height * (compactLandscape ? 0.30 : 0.42))
        .clamp(
            compactLandscape ? 112.0 : 220.0, compactLandscape ? 156.0 : 360.0)
        .toDouble();
    return AppDialogShell(
      icon: Icons.search_rounded,
      title: 'Opening library',
      subtitle: compactLandscape ? null : 'Search classic training positions',
      actions: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('opening-search-field'),
            controller: _searchController,
            autofocus: !compactLandscape,
            textInputAction: TextInputAction.search,
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              labelText: 'Search opening',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          if (_favoriteOpeningIds.isNotEmpty && _query.trim().isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Favorites',
              key: const ValueKey('opening-favorites-header'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 380;
              final countText = Text(
                '${results.length} openings',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              );
              final hintText = Text(
                'Tap one to use it',
                style: Theme.of(context).textTheme.bodySmall,
              );
              return compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        countText,
                        const SizedBox(height: 2),
                        hintText,
                      ],
                    )
                  : Row(
                      children: [
                        countText,
                        const Spacer(),
                        hintText,
                      ],
                    );
            },
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: listHeight,
            child: results.isEmpty
                ? Center(
                    child: Text(
                      'No openings match "$_query"',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    itemCount: showFavoriteSection
                        ? favoriteResults.length + results.length + 1
                        : results.length,
                    itemBuilder: (context, index) {
                      if (!showFavoriteSection) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildOpeningResultTile(
                              context, results[index], compactLandscape),
                        );
                      }
                      if (index < favoriteResults.length) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildOpeningResultTile(
                            context,
                            favoriteResults[index],
                            compactLandscape,
                            keyPrefix: 'opening-favorite-result',
                          ),
                        );
                      }
                      if (index == favoriteResults.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          child: Text(
                            'All openings',
                            key: const ValueKey('opening-all-header'),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildOpeningResultTile(
                          context,
                          results[index - favoriteResults.length - 1],
                          compactLandscape,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpeningResultTile(
    BuildContext context,
    OpeningScenario scenario,
    bool compactLandscape, {
    String keyPrefix = 'opening-result',
  }) {
    final selected = scenario.id == widget.selected.id;
    return _OpeningSearchResultTile(
      key: ValueKey('$keyPrefix-${scenario.id}'),
      scenario: scenario,
      selected: selected,
      dense: compactLandscape,
      favorite: _favoriteOpeningIds.contains(scenario.id),
      onToggleFavorite: () => _toggleFavorite(scenario.id),
      onTap: () => Navigator.of(context).pop(scenario),
    );
  }
}

class _OpeningSearchResultTile extends StatelessWidget {
  const _OpeningSearchResultTile({
    super.key,
    required this.scenario,
    required this.selected,
    this.dense = false,
    required this.favorite,
    required this.onToggleFavorite,
    required this.onTap,
  });

  final OpeningScenario scenario;
  final bool selected;
  final bool dense;
  final bool favorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = selected ? scheme.primary : scheme.secondary;
    final metaText = '${scenario.eco} - ${scenario.moves}';
    return Material(
      color: selected
          ? accent.withValues(alpha: 0.10)
          : Theme.of(context).colorScheme.surface.withValues(alpha: 0.20),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(dense ? 8 : 11),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = dense || constraints.maxWidth < 380;
              final leading = Container(
                width: dense ? 34 : 42,
                height: dense ? 34 : 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  selected ? Icons.check_circle_rounded : Icons.route_rounded,
                  color: accent,
                  size: 20,
                ),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        leading,
                        SizedBox(width: dense ? 8 : 10),
                        Expanded(
                          child: _OpeningTileTitle(
                            scenario: scenario,
                            selected: selected,
                            accent: accent,
                            dense: dense,
                          ),
                        ),
                        IconButton(
                          key: ValueKey('opening-favorite-${scenario.id}'),
                          tooltip:
                              favorite ? 'Remove favorite' : 'Add favorite',
                          onPressed: onToggleFavorite,
                          icon: Icon(
                            favorite
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: favorite ? scheme.tertiary : scheme.outline,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: dense ? 5 : 8),
                    Text(
                      metaText,
                      maxLines: dense ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (!dense) ...[
                      const SizedBox(height: 5),
                      Text(
                        scenario.focus,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  leading,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _OpeningTileTitle(
                          scenario: scenario,
                          selected: selected,
                          accent: accent,
                          dense: dense,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          scenario.moves,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 96,
                    child: Text(
                      scenario.focus,
                      maxLines: 2,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OpeningTileTitle extends StatelessWidget {
  const _OpeningTileTitle({
    required this.scenario,
    required this.selected,
    required this.accent,
    this.dense = false,
  });

  final OpeningScenario scenario;
  final bool selected;
  final Color accent;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ecoBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: selected ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        scenario.eco,
        style: TextStyle(
          color: accent,
          fontSize: dense ? 10 : 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    final title = Text(
      scenario.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: dense ? 14 : 15,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 220) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 4),
              ecoBadge,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 8),
            ecoBadge,
          ],
        );
      },
    );
  }
}

class _BotEngineDetailContent extends StatelessWidget {
  const _BotEngineDetailContent({
    required this.engine,
    required this.maiaLevel,
    required this.maia3Elo,
    required this.maiaSearchStyle,
    required this.maiaSearchDepth,
    required this.stockfishElo,
    required this.stockfishThinkingTime,
    required this.selectedLc0Weight,
    required this.availableLc0Weights,
    required this.onMaiaLevelChange,
    required this.onMaia3EloChange,
    required this.onMaiaSearchStyleChange,
    required this.onMaiaSearchDepthChange,
    required this.onStockfishEloChange,
    required this.onStockfishThinkingTimeChange,
    required this.onLc0WeightChange,
    required this.onManageEngineLab,
  });

  final _BotEngineOption engine;
  final _MaiaLevelOption maiaLevel;
  final int maia3Elo;
  final MaiaSearchStyle maiaSearchStyle;
  final int maiaSearchDepth;
  final int stockfishElo;
  final Duration stockfishThinkingTime;
  final _Lc0WeightOption selectedLc0Weight;
  final List<_Lc0WeightOption> availableLc0Weights;
  final ValueChanged<_MaiaLevelOption> onMaiaLevelChange;
  final ValueChanged<int> onMaia3EloChange;
  final ValueChanged<MaiaSearchStyle> onMaiaSearchStyleChange;
  final ValueChanged<int> onMaiaSearchDepthChange;
  final ValueChanged<int> onStockfishEloChange;
  final ValueChanged<Duration> onStockfishThinkingTimeChange;
  final ValueChanged<_Lc0WeightOption> onLc0WeightChange;
  final VoidCallback onManageEngineLab;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (engine == _BotEngineOption.maia) ...[
          _MaiaEloControl(
            selected: maiaLevel,
            onSelect: onMaiaLevelChange,
          ),
          const SizedBox(height: 12),
          _MaiaSearchControl(
            style: maiaSearchStyle,
            depth: maiaSearchDepth,
            onStyleChanged: onMaiaSearchStyleChange,
            onDepthChanged: onMaiaSearchDepthChange,
          ),
        ] else if (engine == _BotEngineOption.maia3) ...[
          _Maia3EloControl(
            value: maia3Elo,
            onChanged: onMaia3EloChange,
          ),
          const SizedBox(height: 12),
          const _EngineParameterNote(
            icon: Icons.cloud_done_rounded,
            title: 'Cloud Maia 3',
            subtitle:
                'Maia 3 predicts likely human moves from 600 to 2600 Elo. Sign in and stay online to use it.',
          ),
        ] else if (engine == _BotEngineOption.stockfish) ...[
          _StockfishEloControl(
            value: stockfishElo,
            onChanged: onStockfishEloChange,
          ),
          const SizedBox(height: 12),
          _StockfishThinkingTimeControl(
            value: stockfishThinkingTime,
            onChanged: onStockfishThinkingTimeChange,
          ),
        ] else ...[
          _Lc0ModelSelect(
            selected: selectedLc0Weight,
            weights: availableLc0Weights,
            onChanged: onLc0WeightChange,
            onManageEngineLab: onManageEngineLab,
          ),
        ],
      ],
    );
  }
}

class _EngineParameterNote extends StatelessWidget {
  const _EngineParameterNote({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(10),
      borderRadius: 12,
      tint: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ],
        ],
      ),
    );
  }
}

class _Lc0ModelSelect extends StatelessWidget {
  const _Lc0ModelSelect({
    required this.selected,
    required this.weights,
    required this.onChanged,
    required this.onManageEngineLab,
  });

  final _Lc0WeightOption selected;
  final List<_Lc0WeightOption> weights;
  final ValueChanged<_Lc0WeightOption> onChanged;
  final VoidCallback onManageEngineLab;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Engine weight',
            style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        GlassPanel(
          padding: const EdgeInsets.all(10),
          borderRadius: 12,
          tint: scheme.primary.withValues(alpha: 0.07),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.bolt_rounded, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _Lc0WeightMetaLine(
                      source: selected.source,
                      fileName: selected.fileName,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPillMini(label: 'Ready', color: scheme.primary),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final weight in weights) ...[
          _Lc0WeightRow(
            weight: weight,
            selected: selected.key == weight.key,
            onTap: weight.ready ? () => onChanged(weight) : null,
          ),
          const SizedBox(height: 8),
        ],
        GlassPanel(
          padding: const EdgeInsets.all(10),
          borderRadius: 12,
          tint: scheme.secondary.withValues(alpha: 0.08),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.science_rounded, size: 20, color: scheme.secondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Playable engine library',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'No playable personal engines yet. Finished builds will appear here once they are ready for Bot game.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPillMini(label: 'Empty', color: scheme.secondary),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _EngineParameterNote(
          icon: Icons.manage_search_rounded,
          title: 'Manage in Engine Lab',
          subtitle:
              'Training, reports, and playable personal engines live in Engine Lab.',
          onTap: onManageEngineLab,
        ),
      ],
    );
  }
}

class _Lc0WeightRow extends StatelessWidget {
  const _Lc0WeightRow({
    required this.weight,
    required this.selected,
    required this.onTap,
  });

  final _Lc0WeightOption weight;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        borderRadius: 12,
        tint: selected
            ? scheme.primary.withValues(alpha: 0.10)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.18),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: color,
              size: 21,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weight.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  _Lc0WeightMetaLine(
                    source: weight.source,
                    fileName: weight.fileName,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusPillMini(
              label: weight.ready ? 'Ready' : 'Unavailable',
              color: weight.ready ? scheme.primary : scheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPillMini extends StatelessWidget {
  const _StatusPillMini({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _Lc0WeightMetaLine extends StatelessWidget {
  const _Lc0WeightMetaLine({
    required this.source,
    required this.fileName,
  });

  final String source;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Row(
      children: [
        Flexible(
          child: Text(
            source,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        Text(
          ' / ',
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: style,
        ),
        Expanded(
          child: Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

class _MaiaEloControl extends StatelessWidget {
  const _MaiaEloControl({
    required this.selected,
    required this.onSelect,
  });

  final _MaiaLevelOption selected;
  final ValueChanged<_MaiaLevelOption> onSelect;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final index = _MaiaLevelOption.levels.indexWhere(
      (level) => level.level == selected.level,
    );
    final activeIndex = index < 0 ? 4 : index;
    final canLower = activeIndex > 0;
    final canRaise = activeIndex < _MaiaLevelOption.levels.length - 1;
    return GlassPanel(
      padding: const EdgeInsets.all(10),
      borderRadius: 12,
      tint: color.withValues(alpha: 0.06),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${selected.level}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
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
                        const Text('Level',
                            style: TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(width: 8),
                        Text(
                          '${selected.elo}',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Human-like Maia weights from 1100 to 1900.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Lower ELO',
                onPressed: canLower
                    ? () => onSelect(_MaiaLevelOption.levels[activeIndex - 1])
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: Slider(
                  key: const ValueKey('maia-elo-slider'),
                  value: activeIndex.toDouble(),
                  min: 0,
                  max: (_MaiaLevelOption.levels.length - 1).toDouble(),
                  divisions: _MaiaLevelOption.levels.length - 1,
                  label: '${selected.elo}',
                  onChanged: (value) =>
                      onSelect(_MaiaLevelOption.levels[value.round()]),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Raise ELO',
                onPressed: canRaise
                    ? () => onSelect(_MaiaLevelOption.levels[activeIndex + 1])
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                '${_MaiaLevelOption.levels.first.elo}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const Spacer(),
              Text(
                '${_MaiaLevelOption.levels.last.elo}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Maia3EloControl extends StatelessWidget {
  const _Maia3EloControl({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final normalized = (value / maia3EloStep).round() * maia3EloStep;
    final clamped = normalized.clamp(maia3MinElo, maia3MaxElo).toInt();
    final canLower = clamped > maia3MinElo;
    final canRaise = clamped < maia3MaxElo;
    return GlassPanel(
      padding: const EdgeInsets.all(10),
      borderRadius: 12,
      tint: color.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Target Elo',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 8),
              Text(
                '$clamped',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Official Maia 3 range, 600 to 2600.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Lower ELO',
                onPressed: canLower
                    ? () => onChanged(
                          (clamped - maia3EloStep)
                              .clamp(maia3MinElo, maia3MaxElo)
                              .toInt(),
                        )
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: Slider(
                  key: const ValueKey('maia3-elo-slider'),
                  value: clamped.toDouble(),
                  min: maia3MinElo.toDouble(),
                  max: maia3MaxElo.toDouble(),
                  divisions: (maia3MaxElo - maia3MinElo) ~/ maia3EloStep,
                  label: '$clamped',
                  onChanged: (value) => onChanged(
                    ((value / maia3EloStep).round() * maia3EloStep)
                        .clamp(maia3MinElo, maia3MaxElo)
                        .toInt(),
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Raise ELO',
                onPressed: canRaise
                    ? () => onChanged(
                          (clamped + maia3EloStep)
                              .clamp(maia3MinElo, maia3MaxElo)
                              .toInt(),
                        )
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          Row(
            children: [
              Text('$maia3MinElo',
                  style: Theme.of(context).textTheme.labelSmall),
              const Spacer(),
              Text('$maia3MaxElo',
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _MaiaSearchControl extends StatelessWidget {
  const _MaiaSearchControl({
    required this.style,
    required this.depth,
    required this.onStyleChanged,
    required this.onDepthChanged,
  });

  final MaiaSearchStyle style;
  final int depth;
  final ValueChanged<MaiaSearchStyle> onStyleChanged;
  final ValueChanged<int> onDepthChanged;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return GlassPanel(
      padding: const EdgeInsets.all(10),
      borderRadius: 12,
      tint: color.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Play style',
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallChoiceChip(
                label: 'Balanced',
                selected: style == MaiaSearchStyle.balanced,
                onTap: () => onStyleChanged(MaiaSearchStyle.balanced),
              ),
              _SmallChoiceChip(
                label: 'Pure Maia',
                selected: style == MaiaSearchStyle.pure,
                onTap: () => onStyleChanged(MaiaSearchStyle.pure),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            style == MaiaSearchStyle.pure
                ? 'Official no-search Maia. More human-distribution faithful, but may allow obvious mistakes.'
                : 'More stable Maia play with a small search to reduce obvious blunders.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (style == MaiaSearchStyle.balanced) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Tactical depth',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                const Spacer(),
                Text(
                  '$depth',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            Slider(
              key: const ValueKey('maia-depth-slider'),
              value: depth.toDouble(),
              min: 1,
              max: 4,
              divisions: 3,
              label: '$depth',
              onChanged: (value) => onDepthChanged(value.round()),
            ),
            Text(
              'Higher depth feels stronger, but less like raw Maia Elo.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _StockfishEloControl extends StatelessWidget {
  const _StockfishEloControl({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  int _normalizeValue(int value) {
    final snapped = ((value / 10).round() * 10).clamp(
      _stockfishMinElo,
      _stockfishMaxElo,
    );
    return snapped.toInt();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final clamped = _normalizeValue(value);
    final canLower = clamped > _stockfishMinElo;
    final canRaise = clamped < _stockfishMaxElo;
    return GlassPanel(
      padding: const EdgeInsets.all(10),
      borderRadius: 12,
      tint: color.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Target Elo',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 8),
              Text(
                '$clamped',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Stockfish skill range, 600 to 3190.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Row(
            children: [
              IconButton.filledTonal(
                key: const ValueKey('stockfish-elo-decrease'),
                tooltip: 'Lower ELO',
                onPressed: canLower
                    ? () => onChanged(
                          (clamped - 10)
                              .clamp(_stockfishMinElo, _stockfishMaxElo)
                              .toInt(),
                        )
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: Slider(
                  key: const ValueKey('stockfish-elo-slider'),
                  value: clamped.toDouble(),
                  min: _stockfishMinElo.toDouble(),
                  max: _stockfishMaxElo.toDouble(),
                  divisions: (_stockfishMaxElo - _stockfishMinElo) ~/ 10,
                  label: '$clamped',
                  onChanged: (value) =>
                      onChanged(_normalizeValue(value.round())),
                ),
              ),
              IconButton.filledTonal(
                key: const ValueKey('stockfish-elo-increase'),
                tooltip: 'Raise ELO',
                onPressed: canRaise
                    ? () => onChanged(
                          (clamped + 10)
                              .clamp(_stockfishMinElo, _stockfishMaxElo)
                              .toInt(),
                        )
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          Row(
            children: [
              Text('$_stockfishMinElo',
                  style: Theme.of(context).textTheme.labelSmall),
              const Spacer(),
              Text('$_stockfishMaxElo',
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _StockfishThinkingTimeControl extends StatelessWidget {
  const _StockfishThinkingTimeControl({
    required this.value,
    required this.onChanged,
  });

  final Duration value;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final index = _timeIndex(value);
    final label = _formatBotThinkingTime(value);
    final canLower = value != Duration.zero && index > 0;
    final canRaise =
        value == Duration.zero || index < _stockfishThinkingTimes.length - 1;
    return GlassPanel(
      padding: const EdgeInsets.all(10),
      borderRadius: 12,
      tint: color.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Thinking time',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SmallChoiceChip(
            label: 'Auto',
            selected: value == Duration.zero,
            onTap: () => onChanged(Duration.zero),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              IconButton.filledTonal(
                key: const ValueKey('stockfish-thinking-decrease'),
                tooltip: 'Shorter thinking time',
                onPressed: canLower
                    ? () => onChanged(_stockfishThinkingTimes[index - 1])
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: Slider(
                  key: const ValueKey('stockfish-thinking-slider'),
                  value: index.toDouble(),
                  min: 0,
                  max: _stockfishThinkingTimes.length - 1.0,
                  divisions: _stockfishThinkingTimes.length - 1,
                  label: label,
                  onChanged: (v) =>
                      onChanged(_stockfishThinkingTimes[v.round()]),
                ),
              ),
              IconButton.filledTonal(
                key: const ValueKey('stockfish-thinking-increase'),
                tooltip: 'Longer thinking time',
                onPressed: canRaise
                    ? () => onChanged(
                          value == Duration.zero
                              ? _stockfishThinkingTimes.first
                              : _stockfishThinkingTimes[index + 1],
                        )
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                _formatBotThinkingTime(_stockfishThinkingTimes.first),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const Spacer(),
              Text(
                _formatBotThinkingTime(_stockfishThinkingTimes.last),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          Text(
            'Choose from 100ms to 60s. Auto adapts when clocks are active.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  int _timeIndex(Duration duration) {
    if (duration == Duration.zero) return 0;
    final index = _stockfishThinkingTimes.indexOf(duration);
    return index < 0 ? 0 : index.clamp(0, _stockfishThinkingTimes.length - 1);
  }
}

String _formatBotThinkingTime(Duration duration) {
  if (duration == Duration.zero) return 'Auto';
  if (duration.inMilliseconds < 1000) return '${duration.inMilliseconds}ms';
  if (duration.inSeconds < 60) return '${duration.inSeconds}s';
  return '${duration.inMinutes}m';
}

class _SmallChoiceChip extends StatelessWidget {
  const _SmallChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : null,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.42)
                : Theme.of(context).dividerColor.withValues(alpha: 0.34),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : null,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, this.selected = false, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.16)
              : Theme.of(context).colorScheme.surface.withValues(alpha: 0.36),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.46)
                : Theme.of(context).dividerColor.withValues(alpha: 0.38),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : null,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ApiHint extends StatelessWidget {
  const _ApiHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.api_rounded, size: 16, color: scheme.secondary),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChessComGuidePanel extends StatelessWidget {
  const _ChessComGuidePanel();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 13,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.secondary.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.web_asset_rounded, color: scheme.secondary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Use Chess.com inside WebView',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16)),
                    SizedBox(height: 2),
                    Text('Sign in and choose games on Chess.com.'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _GuideStep(
            icon: Icons.login_rounded,
            title: 'Sign in on Chess.com',
            subtitle:
                'The app opens Chess.com directly, so account and match settings stay on the website.',
          ),
          const SizedBox(height: 8),
          const _GuideStep(
            icon: Icons.sports_esports_rounded,
            title: 'Start any game there',
            subtitle:
                'Choose blitz, rapid, rated, casual, or another mode in the WebView.',
          ),
          const SizedBox(height: 8),
          const _GuideStep(
            icon: Icons.sensors_rounded,
            title: 'Chessnut mirrors the board',
            subtitle:
                'The app reads the live FEN and sends supported board moves back into the page.',
          ),
          const SizedBox(height: 8),
          const _GuideStep(
            icon: Icons.tune_rounded,
            title: 'Move control can be changed',
            subtitle:
                'Board Settings lets you choose Direct control or Web control for physical board moves.',
          ),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.secondary;
    return GlassPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      borderRadius: 13,
      tint: selected ? color.withValues(alpha: 0.09) : null,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.public_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(badge,
              style: TextStyle(color: color, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _LichessAuthorizationPanel extends StatelessWidget {
  const _LichessAuthorizationPanel({
    required this.authorized,
    required this.expired,
    required this.checking,
    required this.onAuthorize,
    this.lichessName,
    this.message,
    super.key,
  });

  final bool authorized;
  final bool expired;
  final bool checking;
  final Future<void> Function() onAuthorize;
  final String? lichessName;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ready = authorized && !expired;
    final color = ready
        ? scheme.primary
        : expired
            ? scheme.error
            : scheme.secondary;
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 13,
      tint: color.withValues(alpha: ready ? 0.08 : 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  ready ? Icons.verified_user_rounded : Icons.lock_open_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ready
                          ? 'Lichess authorized'
                          : expired
                              ? 'Authorization expired'
                              : 'Lichess authorization required',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      checking
                          ? 'Checking Lichess authorization...'
                          : message ??
                              (ready
                                  ? 'Signed in as ${lichessName ?? 'Lichess'}. Ready to play on Lichess.'
                                  : expired
                                      ? 'Your Lichess sign-in expired. Authorize again before playing.'
                                      : 'Authorize Lichess so Chessnut can start online games and sync your board moves.'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusBadge(
                icon: Icons.key_rounded,
                label: checking
                    ? 'Checking'
                    : ready
                        ? 'Authorized'
                        : 'Sign-in needed',
                color: color,
              ),
              _StatusBadge(
                icon: Icons.extension_rounded,
                label: 'Play permission',
                color: scheme.secondary,
              ),
              _StatusBadge(
                icon: Icons.monitor_heart_rounded,
                label: ready ? 'Ready to play' : 'Sign-in needed',
                color: ready ? scheme.primary : scheme.error,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!ready)
            PrimaryButton(
              label: expired ? 'Re-authorize Lichess' : 'Authorize Lichess',
              icon: Icons.login_rounded,
              onPressed: onAuthorize,
            ),
        ],
      ),
    );
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoveBoardResetBadge extends StatefulWidget {
  const _MoveBoardResetBadge({required this.gateway});

  final PhysicalBoardGateway gateway;

  @override
  State<_MoveBoardResetBadge> createState() => _MoveBoardResetBadgeState();
}

class _MoveBoardResetBadgeState extends State<_MoveBoardResetBadge> {
  bool _resetting = false;

  Future<void> _resetBoard() async {
    if (_resetting) return;
    setState(() => _resetting = true);
    await widget.gateway.clearMoveLeds();
    final isReverse = _inferReverseMapping(widget.gateway.latestBoardFen);
    final sent = await widget.gateway.setMoveBoardFen(
      chessnutStandardStartFen,
      isReverse: isReverse,
    );
    if (!mounted) return;
    setState(() => _resetting = false);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            sent
                ? 'Move board reset to the standard starting position.'
                : 'Move board did not accept the reset command.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: 'Reset Move board',
      child: Semantics(
        button: true,
        enabled: !_resetting,
        label: 'Reset Move board',
        child: InkWell(
          key: const ValueKey('setup-move-board-reset-button'),
          onTap: _resetting
              ? null
              : () async {
                  final confirmed =
                      await confirmMoveBoardPieceMovement(context);
                  if (confirmed && mounted) await _resetBoard();
                },
          borderRadius: BorderRadius.circular(999),
          child: _StatusBadge(
            icon: _resetting
                ? Icons.hourglass_top_rounded
                : Icons.restart_alt_rounded,
            label: _resetting ? 'Resetting' : 'Reset',
            color: color,
          ),
        ),
      ),
    );
  }

  bool _inferReverseMapping(String? fen) {
    final board = fen?.trim().split(RegExp(r'\s+')).first;
    if (board == null || board.isEmpty) return false;
    final ranks = board.split('/');
    if (ranks.length != 8) return false;
    final top = _pieceColorCounts(ranks.first);
    final bottom = _pieceColorCounts(ranks.last);
    // A reversed physical board has White's home rank at the physical top
    // and Black's home rank at the physical bottom. If the position is too
    // sparse to identify this confidently, retain the standard orientation.
    return top.white > top.black && bottom.black > bottom.white;
  }

  ({int white, int black}) _pieceColorCounts(String rank) {
    var white = 0;
    var black = 0;
    for (final codeUnit in rank.codeUnits) {
      final piece = String.fromCharCode(codeUnit);
      if ('PRNBQK'.contains(piece)) white += 1;
      if ('prnbqk'.contains(piece)) black += 1;
    }
    return (white: white, black: black);
  }
}

class _OnlinePlatformPill extends StatelessWidget {
  const _OnlinePlatformPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      borderRadius: 999,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _ConnectionSteps extends StatelessWidget {
  const _ConnectionSteps({
    required this.chesscom,
    required this.authorized,
  });

  final bool chesscom;
  final bool authorized;

  @override
  Widget build(BuildContext context) {
    if (chesscom) {
      return const Row(
        children: [
          Expanded(
            child: _ConnectionStepInfo(
              number: '1',
              label: 'WebView',
              done: true,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _ConnectionStepInfo(
              number: '2',
              label: 'Mirror',
              active: true,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _ConnectionStepInfo(number: '3', label: 'Board'),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: _ConnectionStepInfo(
            number: '1',
            label: 'Authorize',
            done: authorized,
            active: !authorized,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ConnectionStepInfo(
            number: '2',
            label: 'Seek',
            active: authorized,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: _ConnectionStepInfo(number: '3', label: 'Stream'),
        ),
      ],
    );
  }
}

class _ConnectionStepInfo extends StatelessWidget {
  const _ConnectionStepInfo({
    required this.number,
    required this.label,
    this.done = false,
    this.active = false,
  });

  final String number;
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active || done
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.secondary;
    return Semantics(
      container: true,
      label: 'Step $number, $label',
      child: Padding(
        key: ValueKey('online-connection-step-$number'),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            CircleAvatar(
              radius: 11,
              backgroundColor: color.withValues(alpha: 0.14),
              child: Text(
                number,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active || done ? color : null,
                  fontWeight: FontWeight.w800,
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

class _PathCard extends StatelessWidget {
  const _PathCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
    this.label,
    this.selected = false,
    this.large = false,
    this.compactLandscape = false,
    this.desktopLandscape = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final String? label;
  final VoidCallback onTap;
  final bool selected;
  final bool large;
  final bool compactLandscape;
  final bool desktopLandscape;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.secondary;
    return GlassPanel(
      onTap: onTap,
      padding: EdgeInsets.all(
        desktopLandscape ? 20 : (compactLandscape ? 10 : (large ? 16 : 12)),
      ),
      borderRadius: large ? 16 : 13,
      tint: selected ? color.withValues(alpha: 0.08) : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: desktopLandscape
              ? 160
              : (compactLandscape ? 118 : (large ? 116 : 70)),
        ),
        child: compactLandscape
            ? Row(
                children: [
                  Container(
                    width: desktopLandscape ? 58 : 42,
                    height: desktopLandscape ? 58 : 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.11),
                      borderRadius:
                          BorderRadius.circular(desktopLandscape ? 16 : 12),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: desktopLandscape ? 30 : 23,
                    ),
                  ),
                  SizedBox(width: desktopLandscape ? 16 : 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: desktopLandscape ? 22 : 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: desktopLandscape ? 8 : 5),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: desktopLandscape
                              ? Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontSize: 15)
                              : Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: desktopLandscape ? 14 : 8),
                  _PathBadge(
                    label: badge,
                    color: color,
                    large: desktopLandscape,
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: large ? 48 : 38,
                    height: large ? 48 : 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: large ? 0.14 : 0.10),
                      borderRadius: BorderRadius.circular(large ? 14 : 10),
                    ),
                    child: Icon(icon, color: color, size: large ? 27 : 23),
                  ),
                  SizedBox(width: large ? 14 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (label != null) ...[
                          if (large)
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    label!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color
                                              ?.withValues(alpha: 0.62),
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _PathBadge(
                                  label: badge,
                                  color: color,
                                  large: true,
                                ),
                              ],
                            )
                          else
                            Text(
                              label!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color
                                        ?.withValues(alpha: 0.62),
                                  ),
                            ),
                          const SizedBox(height: 3),
                        ],
                        Text(
                          title,
                          maxLines: large ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: large ? 5 : 4),
                        Text(
                          subtitle,
                          maxLines: large ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (!large) ...[
                    const SizedBox(width: 8),
                    _PathBadge(label: badge, color: color),
                  ],
                ],
              ),
      ),
    );
  }
}

class _PathBadge extends StatelessWidget {
  const _PathBadge({
    required this.label,
    required this.color,
    this.large = false,
  });

  final String label;
  final Color color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 10 : 8,
        vertical: large ? 6 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
