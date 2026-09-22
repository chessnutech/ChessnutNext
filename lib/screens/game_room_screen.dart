import 'dart:async';
import 'dart:convert';

import 'package:dartchess/dartchess.dart' as dc;
import '../l10n/localized_material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

import '../l10n/app_strings.dart';
import '../models/app_models.dart';
import '../services/board_settings_service.dart';
import '../services/bot_engine_adapter.dart';
import '../services/chess_clock_switch_service.dart';
import '../services/cloud_maia3_bot_engine_adapter.dart';
import '../services/chessnut_api_client.dart';
import '../services/game_notation_service.dart';
import '../services/game_record_repository.dart';
import '../services/game_record_save_service.dart';
import '../services/local_game_record_store.dart';
import '../services/lichess_board_service.dart';
import '../services/move_quality_lights_service.dart';
import '../services/network_latency_service.dart';
import '../services/physical_board_gateway.dart';
import '../services/physical_board_orientation.dart';
import '../services/physical_board_protocol.dart';
import '../services/review_prompt_service.dart';
import '../services/app_sound_service.dart';
import '../services/stockfish_analysis_service.dart';
import '../services/uci_engine_adapter.dart';
import '../services/voice_move_parser.dart';
import '../services/voice_move_recognition_service.dart';
import '../theme/chessnut_theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_feedback.dart';
import '../widgets/board_connection_badge.dart';
import '../widgets/chess_board.dart';
import '../widgets/chessnut_celebration.dart';
import '../widgets/voice_moves_shortcut.dart';
import 'spectator_screen.dart';

const _clockStartHalfMoveCount = 2;

class GameRoomScreen extends StatefulWidget {
  const GameRoomScreen({
    required this.onNavigate,
    required this.mode,
    this.botConfig = const BotGameConfig.defaultConfig(),
    this.otbConfig = const OtbGameConfig(),
    this.lichessConfig = const LichessGameConfig.empty(),
    this.apiClient,
    this.recordSaveService,
    this.initialLocalRecord,
    this.recordOwnerUserId,
    this.boardGateway,
    this.boardSettings = const BoardSettingsState(),
    this.onBoardSettingsChanged,
    this.showBoardCoordinates = false,
    this.latencyProbe,
    this.positionAnalyzer,
    this.onAnalyzePgn,
    this.reviewPromptService,
    this.onGameCompleted,
    this.onGameActiveChanged,
    this.evo2LedRefreshRequestId = 0,
    this.onGameShared,
    this.onGameRecordSaved,
    this.onCareerRematch,
    this.onLichessTemporaryContinueRecord,
    this.onBotTemporaryContinueRecord,
    this.onPostGameBotSettings,
    this.initialPgnId,
    this.initialShareId,
    this.isChessnutClockDevice = false,
    this.hidePhysicalBoardConnectionUi = false,
    this.soundEffectsEnabled = true,
    this.soundEffects = const SoundEffectsSettings(),
    this.appSoundService = const SystemAppSoundService(),
    this.botEngine,
    this.clockSwitchService,
    this.voiceMoveRecognitionService,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final GameLaunchMode mode;
  final BotGameConfig botConfig;
  final OtbGameConfig otbConfig;
  final LichessGameConfig lichessConfig;
  final ChessnutApiClient? apiClient;
  final GameRecordSaveService? recordSaveService;
  final LocalGameRecord? initialLocalRecord;
  final int? recordOwnerUserId;
  final PhysicalBoardGateway? boardGateway;
  final BoardSettingsState boardSettings;
  final ValueChanged<BoardSettingsState>? onBoardSettingsChanged;
  final bool showBoardCoordinates;
  final NetworkLatencyProbe? latencyProbe;
  final PositionAnalyzer? positionAnalyzer;
  final ValueChanged<String>? onAnalyzePgn;
  final ReviewPromptService? reviewPromptService;
  final ValueChanged<GameCompletionContext>? onGameCompleted;
  final ValueChanged<bool>? onGameActiveChanged;
  final int evo2LedRefreshRequestId;
  final ValueChanged<SpectatorGameSnapshot>? onGameShared;
  final FutureOr<void> Function(GameRecord record)? onGameRecordSaved;
  final VoidCallback? onCareerRematch;
  final ValueChanged<GameRecord>? onLichessTemporaryContinueRecord;
  final ValueChanged<GameRecord>? onBotTemporaryContinueRecord;
  final VoidCallback? onPostGameBotSettings;
  final int? initialPgnId;
  final String? initialShareId;
  final bool isChessnutClockDevice;
  final bool hidePhysicalBoardConnectionUi;
  final bool soundEffectsEnabled;
  final SoundEffectsSettings soundEffects;
  final AppSoundService appSoundService;
  final BotEngineAdapter? botEngine;
  final ChessClockSwitchService? clockSwitchService;
  final VoiceMoveRecognitionService? voiceMoveRecognitionService;

  @override
  State<GameRoomScreen> createState() => _GameRoomScreenState();
}

class GameCompletionContext {
  const GameCompletionContext({
    required this.mode,
    required this.isCareerGame,
    this.careerDailyTaskReward,
  });

  final GameLaunchMode mode;
  final bool isCareerGame;
  final DailyClaimResult? careerDailyTaskReward;
}

class _GameRoomScreenState extends State<GameRoomScreen>
    with WidgetsBindingObserver {
  late BotEngineAdapter _defaultBotEngine;

  BotEngineAdapter get _botEngine => widget.botEngine ?? _defaultBotEngine;
  static const _physicalLedInterval = Duration(milliseconds: 150);
  static const _clockSwitchReboundDelay = Duration(milliseconds: 250);
  static const _hintStockfishElo = 2200;
  static const _hintStockfishThinkingTime = Duration(milliseconds: 30);
  final List<String> _sanMoves = [];
  final List<_MoveSnapshot> _snapshots = [];

  late String _fen;
  late bool _flipped;
  List<String> _lastMove = const [];
  int _currentPly = 0;
  bool _botThinking = false;
  bool _clockOnlyNamesFlipped = false;
  bool _gameOver = false;
  bool _gameOverSideEffectsHandled = false;
  bool _careerEloSettled = false;
  String _resultText = '';
  String _finalResultText = '';
  String _lichessResultToken = '*';
  bool _resignInFlight = false;
  int _whiteSeconds = 10 * 60;
  int _blackSeconds = 10 * 60;
  DateTime? _clockLastAlignedAt;
  Timer? _clockTimer;
  StreamSubscription<LichessBoardEvent>? _lichessSub;
  StreamSubscription<String>? _boardFenSub;
  StreamSubscription<PhysicalBoardConnectionState>? _boardStateSub;
  StreamSubscription<int>? _clockSwitchSub;
  StreamSubscription<VoiceMoveRecognitionEvent>? _voiceMoveSub;
  LichessBoardService? _lichessService;
  Timer? _lichessReconnectTimer;
  int _lichessStreamGeneration = 0;
  int _lichessReconnectAttempts = 0;
  Timer? _latencyTimer;
  NetworkLatencySnapshot? _latency;
  PhysicalBoardConnectionState _boardState =
      PhysicalBoardConnectionState.disconnected;
  String? _physicalBoardFen;
  // For non-standard OTB starting positions, the clock must remain stopped
  // until the connected physical board reports the requested setup.
  String? _otbPhysicalSetupTargetFen;
  Set<String> _fenDifferenceLedSquares = const {};
  Set<String> _hintLedSquares = const {};
  Set<String> _legalMovesLedSquares = const {};
  Set<String> _opponentMoveLedSquares = const {};
  Set<String> _checkKingLedSquares = const {};
  Timer? _physicalLedTimer;
  bool _physicalLedFlushPending = false;
  bool _physicalLedCommandInFlight = false;
  String? _lastPhysicalLedSignature;
  Set<String> _legalTargetSquares = const {};
  Map<String, MoveQualityLight> _legalTargetLightQualities = const {};
  String? _legalTargetSourceSquare;
  int _externalBoardSelectionVersion = 0;
  bool _legalTargetsFromPhysicalLift = false;
  _GameRecordSaveCoordinator? _recordSaveCoordinator;
  bool _shareLiveUrlInFlight = false;
  int? _recordPgnId;
  String? _recordShareId;
  String _recordGameId = '';
  DateTime _recordStartedAt = DateTime.now();
  LocalGameRecordStore? _ownedLocalRecordStore;
  bool _localSaveNoticeShown = false;
  String? _lastRecordSaveKey;
  bool _showBotEvaluation = true;
  bool _showLegalTargets = true;
  bool? _moveQualityLightsOverride;
  bool? _clockOtbWhiteQualityLightsOverride;
  bool? _clockOtbBlackQualityLightsOverride;
  ChessBoardMove? _hintMove;
  String? _engineEvalLabel;
  int _engineEvalRequestId = 0;
  String? _moveQualityAnalysisFen;
  String? _moveQualityAnalysisInFlightFen;
  String? _moveQualityAnalysisEvalLabel;
  int? _moveQualityAnalysisEngineEvalRequestId;
  int _moveQualityAnalysisRequestId = 0;
  Map<String, Map<String, MoveQualityLight>> _moveQualityTargetsBySource =
      const {};
  _BoardFenMapping _boardFenMapping = _BoardFenMapping.identity;
  bool _reviewPromptRecorded = false;
  bool? _reportedGameActive;
  late BoardFenStabilityBuffer _boardFenStabilityBuffer;
  Timer? _pendingPhysicalMoveTimer;
  Timer? _moveBoardRestoreTimer;
  String? _pendingPhysicalMoveBoardFen;
  String? _pendingMoveBoardRestoreFen;
  String? _lastMoveBoardSetMoveSignature;
  bool _moveBoardSetMoveInFlight = false;
  bool _moveBoardOpeningSyncPending = false;
  bool _moveBoardOpeningSyncChecked = false;
  ChessBoardMove? _pendingClockSwitchMove;
  String? _pendingClockSwitchExpectedFen;
  String? _pendingOpponentClockSwitchBoardFen;
  int? _pendingLichessLocalPly;
  LichessPlayerSide? _pendingLichessDrawOfferFrom;
  LichessPlayerSide? _handledLichessDrawOfferFrom;
  bool _lichessDrawDialogInFlight = false;
  bool _lichessPositionInitialized = false;
  bool _lichessServerStateReceived = false;
  String? _lichessInitialFen;
  bool _startGameBeepPlayed = false;
  bool _physicalBoardOrientationResolved = false;
  String _lichessWhiteName = '';
  String _lichessBlackName = '';
  int? _lichessWhiteRating;
  int? _lichessBlackRating;
  LichessPlayerSide _lichessPlayerSide = LichessPlayerSide.none;
  int? _lichessTimeMinutesOverride;
  int? _lichessIncrementSecondsOverride;
  int? _lichessUnlimitedClockInitialMs;
  bool? _lichessRatedOverride;
  late final ChessClockSwitchService _clockSwitchService;
  late final bool _ownsClockSwitchService;
  late final VoiceMoveRecognitionService _voiceMoveRecognitionService;
  late final bool _ownsVoiceMoveRecognitionService;
  bool _voiceMovesEnabled = false;
  bool _voiceMovesListening = false;
  String? _lastOpponentMoveUci;
  bool _boardHidden = false;
  String _otbWhiteName = 'White';
  String _otbBlackName = 'Black';

  bool get _isBotGame => widget.mode == GameLaunchMode.bot;

  bool get _isLichessGame => widget.mode == GameLaunchMode.lichess;

  bool get _isOtbRecordGame => widget.mode == GameLaunchMode.otb;

  bool get _isOtbFenPosition =>
      _isOtbRecordGame &&
      (widget.otbConfig.opening.id == 'board-editor-fen' ||
          widget.otbConfig.opening.eco == 'FEN');

  bool get _isClockOnlyOtb =>
      widget.isChessnutClockDevice &&
      _isOtbRecordGame &&
      !widget.otbConfig.showPgnList;

  bool get _isClockOnlyBot =>
      widget.isChessnutClockDevice &&
      _isBotGame &&
      !widget.botConfig.showPgnList;

  bool get _isChessnutClockBot =>
      widget.isChessnutClockDevice &&
      _isBotGame &&
      widget.botConfig.careerMode == null;

  bool get _supportsBoardHiding =>
      !kIsWeb &&
      (_isChessnutClockBot ||
          (!widget.isChessnutClockDevice &&
              (_isOtbRecordGame ||
                  (_isBotGame && widget.botConfig.careerMode == null)) &&
              const {
                TargetPlatform.windows,
                TargetPlatform.android,
                TargetPlatform.iOS,
                TargetPlatform.macOS,
              }.contains(defaultTargetPlatform)));

  _DisplayClock _hiddenOtbClock({
    required dc.Position game,
    required dc.Side side,
  }) {
    return _DisplayClock(
      name: side == dc.Side.white ? _otbWhiteName : _otbBlackName,
      source: '',
      seconds: side == dc.Side.white ? _whiteSeconds : _blackSeconds,
      active: !_gameOver && game.turn == side,
    );
  }

  void _toggleBoardVisibility() {
    if (!_supportsBoardHiding) return;
    setState(() => _boardHidden = !_boardHidden);
  }

  Future<void> _editWindowsOtbPlayerName({required dc.Side side}) async {
    final clockOnlyOtb = widget.isChessnutClockDevice &&
        _isOtbRecordGame &&
        !widget.otbConfig.showPgnList;
    if ((!_supportsBoardHiding && !clockOnlyOtb) ||
        !_isOtbRecordGame ||
        _gameConcluded) {
      return;
    }
    final fallback = side == dc.Side.white ? 'White' : 'Black';
    final current = side == dc.Side.white ? _otbWhiteName : _otbBlackName;
    final controller = TextEditingController(text: current);
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
    final updated = await showDialog<String>(
      context: context,
      useSafeArea: false,
      builder: (dialogContext) => _ClockOnlyPlayerNameDialog(
        isWhite: side == dc.Side.white,
        controller: controller,
        autofocus: true,
      ),
    );
    controller.dispose();
    if (!mounted || updated == null) return;
    final normalized = _normalizedOtbPlayerName(updated, fallback);
    setState(() {
      if (side == dc.Side.white) {
        _otbWhiteName = normalized;
      } else {
        _otbBlackName = normalized;
      }
    });
    _lastRecordSaveKey = null;
    unawaited(_saveGameRecordIfNeeded());
  }

  String _normalizedOtbPlayerName(String value, String fallback) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return normalized.isEmpty ? fallback : normalized;
  }

  bool get _allowsScoreBar => _isBotGame || _isOtbRecordGame;

  bool get _allowsEngineAssistance => _isBotGame || _isOtbRecordGame;

  bool get _allowsHintAssistance =>
      _allowsEngineAssistance &&
      (!_isBotGame || widget.botConfig.careerMode == null);

  bool get _allowsMoveQualityLights => _allowsEngineAssistance;

  bool get _moveQualityLightsEnabled {
    if (_isClockOnlyOtb || _isClockOnlyBot) {
      return _clockOtbQualityLightsEnabledForSide(_liveGame.turn);
    }
    return _moveQualityLightsOverride ?? widget.boardSettings.moveQualityLights;
  }

  bool _clockOtbQualityLightsEnabledForSide(dc.Side side) {
    final override = side == dc.Side.white
        ? _clockOtbWhiteQualityLightsOverride
        : _clockOtbBlackQualityLightsOverride;
    return override ?? widget.boardSettings.moveQualityLights;
  }

  bool get _canShowVirtualMoveQuality =>
      _allowsMoveQualityLights && _moveQualityLightsEnabled;

  bool get _allowsLegalTargetDisplay =>
      widget.mode == GameLaunchMode.bot ||
      widget.mode == GameLaunchMode.lichess ||
      widget.mode == GameLaunchMode.otb;

  bool get _supportsPhysicalBoardMoves =>
      widget.mode == GameLaunchMode.bot ||
      widget.mode == GameLaunchMode.lichess ||
      widget.mode == GameLaunchMode.otb;

  bool get _canSubmitPhysicalBoardFenMoves =>
      _supportsPhysicalBoardMoves && widget.boardGateway != null;

  bool get _canAutoSetMoveBoard {
    final gateway = widget.boardGateway;
    return _supportsPhysicalBoardMoves &&
        gateway?.boardModel == PhysicalBoardModel.move &&
        gateway?.currentState == PhysicalBoardConnectionState.connected;
  }

  bool get _isConnectedMoveBoard {
    final gateway = widget.boardGateway;
    return gateway?.boardModel == PhysicalBoardModel.move &&
        (gateway?.currentState == PhysicalBoardConnectionState.connected ||
            _boardState == PhysicalBoardConnectionState.connected);
  }

  bool get _hasConnectedPhysicalBoard {
    final gateway = widget.boardGateway;
    return gateway != null &&
        (gateway.currentState == PhysicalBoardConnectionState.connected ||
            _boardState == PhysicalBoardConnectionState.connected);
  }

  bool get _canFlipConnectedMoveBoard =>
      !kIsWeb &&
      const {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.windows,
        TargetPlatform.macOS,
      }.contains(defaultTargetPlatform) &&
      _boardFlipAllowed &&
      _isConnectedMoveBoard;

  bool get _canUseVoiceMoves =>
      _supportsPhysicalBoardMoves && _isConnectedMoveBoard;

  bool get _canShowVirtualLegalTargetGuidance =>
      _allowsLegalTargetDisplay &&
      (_showLegalTargets || _canShowVirtualMoveQuality) &&
      _atLatest &&
      !_gameOver;

  bool get _isWidgetTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  bool get _atLatest => _currentPly == _snapshots.length - 1;

  dc.Position get _liveGame => loadDartChessPosition(_snapshots.last.fen);

  bool get _gameConcluded => _gameOver || _finalResultText.isNotEmpty;

  bool get _otbPhysicalSetupReady {
    final targetFen = _otbPhysicalSetupTargetFen;
    if (targetFen == null || !_hasConnectedPhysicalBoard) return true;
    return _boardOnlyFen(_physicalBoardFen ?? '') == targetFen;
  }

  bool get _gameOfficiallyStarted =>
      (!_isLichessGame &&
          (!_isBotGame || _sanMoves.length >= _clockStartHalfMoveCount) &&
          _otbPhysicalSetupReady) ||
      (_isLichessGame && _lichessServerStateReceived);

  bool get _gameRecordSaveStarted =>
      _gameOfficiallyStarted || (_isBotGame && _sanMoves.isNotEmpty);

  bool get _isBoardEditorBotGame =>
      _isBotGame &&
      (widget.botConfig.opening.id == 'board-editor-fen' ||
          widget.botConfig.opening.eco == 'FEN');

  bool get _botGameNeedsExitConfirm =>
      !_isBotGame || _sanMoves.isNotEmpty || _isBoardEditorBotGame;

  bool get _gameNeedsExitConfirm {
    if (_isOtbRecordGame) return _sanMoves.length > 4;
    return _botGameNeedsExitConfirm;
  }

  bool get _clockOfficiallyStarted =>
      _gameOfficiallyStarted &&
      (!_isClockOnlyOtb || _sanMoves.length >= _clockStartHalfMoveCount);

  bool get _needsClockSwitchEvents =>
      widget.boardSettings.clockSwitch ||
      widget.boardSettings.submitMoveOnClockSwitch;

  bool get _shouldAutoSwitchClock =>
      widget.boardSettings.clockSwitchAutomation !=
      ClockSwitchAutomationMode.off;

  bool get _boardFlipAllowed => widget.boardSettings.allowFlip;

  bool get _physicalBoardAutoFlipEnabled =>
      _boardFlipAllowed && widget.boardSettings.autoFlip;

  List<_BoardFenMapping> get _physicalBoardResolutionMappings {
    if (!_boardFlipAllowed) {
      return const [_BoardFenMapping.identity];
    }
    if (!_physicalBoardAutoFlipEnabled) {
      return [_boardFenMapping];
    }
    return _orderedSupportedPhysicalBoardMappings(_boardFenMapping);
  }

  bool get _playerIsWhite => _isLichessGame
      ? _lichessPlayerSide != LichessPlayerSide.black
      : !_isBotGame || widget.botConfig.playerSide != BotPlayerSide.black;

  bool get _isPlayerTurn {
    if (!_atLatest) return false;
    if (_gameConcluded || _botThinking) return false;
    if (_isLichessGame && !_lichessServerStateReceived) return false;
    if (!_isBotGame) return true;
    final game = loadDartChessPosition(_fen);
    final whiteTurn = game.turn == dc.Side.white;
    return whiteTurn == _playerIsWhite;
  }

  BotGameConfig get _hintBotConfig => widget.botConfig.copyWith(
        engineKind: BotEngineKind.stockfish,
        stockfishElo: _hintStockfishElo,
        stockfishThinkingTime: _hintStockfishThinkingTime,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _showBotEvaluation = widget.boardSettings.showScorebar;
    _showLegalTargets = widget.boardSettings.showLegalMoves;
    _defaultBotEngine = DefaultBotEngineAdapter(
      cloud: CloudMaia3BotEngineAdapter(apiClient: widget.apiClient),
    );
    _botEngine.setEvaluationListener(_handleBotEngineEvaluation);
    _boardFenStabilityBuffer = BoardFenStabilityBuffer(
      onStableFen: _applyPhysicalBoardFen,
    );
    _ownsClockSwitchService = widget.clockSwitchService == null;
    _clockSwitchService =
        widget.clockSwitchService ?? ChessClockSwitchService();
    // 初始化 USB 按钮监听
    _ownsVoiceMoveRecognitionService =
        widget.voiceMoveRecognitionService == null;
    _voiceMoveRecognitionService = widget.voiceMoveRecognitionService ??
        VoiceMoveRecognitionService(openAiKeyProvider: _openAiKeyForVoiceMove);
    _voiceMoveSub =
        _voiceMoveRecognitionService.events.listen(_handleVoiceMoveEvent);
    _clockSwitchService.initialize();

    // 监听棋钟切换事件（包括 USB 按钮）
    if (_needsClockSwitchEvents) {
      _clockSwitchSub =
          _clockSwitchService.switchEvents.listen(_handleClockSwitchEvent);
    }

    _resetGame();
  }

  @override
  void didUpdateWidget(covariant GameRoomScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.botEngine != widget.botEngine) {
      oldWidget.botEngine?.setEvaluationListener(null);
    }
    if (oldWidget.botEngine == null && widget.botEngine != null) {
      _defaultBotEngine.setEvaluationListener(null);
      unawaited(_defaultBotEngine.dispose());
    }
    if (oldWidget.botEngine != null && widget.botEngine == null) {
      _defaultBotEngine = DefaultBotEngineAdapter(
        cloud: CloudMaia3BotEngineAdapter(apiClient: widget.apiClient),
      );
    }
    if (oldWidget.botEngine == null &&
        widget.botEngine == null &&
        oldWidget.apiClient != widget.apiClient) {
      _defaultBotEngine.setEvaluationListener(null);
      unawaited(_defaultBotEngine.dispose());
      _defaultBotEngine = DefaultBotEngineAdapter(
        cloud: CloudMaia3BotEngineAdapter(apiClient: widget.apiClient),
      );
    }
    _botEngine.setEvaluationListener(_handleBotEngineEvaluation);
    if (oldWidget.mode != widget.mode ||
        oldWidget.botConfig != widget.botConfig ||
        oldWidget.otbConfig != widget.otbConfig ||
        oldWidget.lichessConfig != widget.lichessConfig) {
      _resetGame();
    }
    if (oldWidget.boardSettings.allowFlip != widget.boardSettings.allowFlip) {
      _applyBoardFlipPermission();
      if (!widget.boardSettings.allowFlip) {
        _applyResolvedBoardFenMapping(_BoardFenMapping.identity);
      }
    }
    if (!identical(oldWidget.boardGateway, widget.boardGateway)) {
      _startPhysicalBoardStreamIfNeeded();
      if (!_canUseVoiceMoves && _voiceMovesEnabled) {
        unawaited(_stopVoiceMoves());
      }
    }
    if (oldWidget.boardSettings.showScorebar !=
            widget.boardSettings.showScorebar ||
        oldWidget.boardSettings.showLegalMoves !=
            widget.boardSettings.showLegalMoves) {
      _showBotEvaluation = widget.boardSettings.showScorebar;
      _showLegalTargets = widget.boardSettings.showLegalMoves;
      if (!_showLegalTargets) {
        _legalTargetSquares = const {};
        _legalTargetLightQualities = const {};
        _legalTargetSourceSquare = null;
        _legalTargetsFromPhysicalLift = false;
        _externalBoardSelectionVersion += 1;
      }
      _refreshLegalMoveLeds();
    }
    if (oldWidget.boardSettings.piecePositionLed !=
        widget.boardSettings.piecePositionLed) {
      _lastPhysicalLedSignature = null;
      _refreshPhysicalLedStates(immediate: true);
    }
    if (oldWidget.evo2LedRefreshRequestId != widget.evo2LedRefreshRequestId &&
        widget.boardGateway?.boardModel == PhysicalBoardModel.evo2) {
      _lastPhysicalLedSignature = null;
      _refreshPhysicalLedStates(immediate: true);
    }
  }

  Future<void> _closeOwnedLocalStore() async {
    final store = _ownedLocalRecordStore;
    if (store == null) return;
    try {
      await _recordSaveCoordinator?.idle;
      await store.close();
    } catch (_) {}
  }

  @override
  void dispose() {
    _reportGameActive(false);
    unawaited(_closeOwnedLocalStore());
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _latencyTimer?.cancel();
    _pendingPhysicalMoveTimer?.cancel();
    _moveBoardRestoreTimer?.cancel();
    _physicalLedTimer?.cancel();
    _lichessReconnectTimer?.cancel();
    _lichessStreamGeneration += 1;
    _stopMoveBoardOnExit();
    unawaited(_clearPhysicalBoardLeds(immediate: true));
    _boardFenStabilityBuffer.dispose();
    if (_ownsClockSwitchService) {
      unawaited(_clockSwitchService.dispose());
    }
    _botEngine.setEvaluationListener(null);
    if (widget.botEngine == null) {
      unawaited(_defaultBotEngine.dispose());
    }
    unawaited(_lichessSub?.cancel());
    unawaited(_boardFenSub?.cancel());
    unawaited(_boardStateSub?.cancel());
    unawaited(_clockSwitchSub?.cancel());
    unawaited(_voiceMoveSub?.cancel());
    if (_ownsVoiceMoveRecognitionService) {
      unawaited(_voiceMoveRecognitionService.dispose());
    } else {
      unawaited(_voiceMoveRecognitionService.stop());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(
          _saveGameRecordIfNeeded(force: true, allowPreOfficialBotDraft: true));
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (widget.boardGateway?.boardModel != PhysicalBoardModel.evo2) return;
    _lastPhysicalLedSignature = null;
    _schedulePhysicalLedSync(immediate: true);
  }

  void _resetGame({
    bool freshBotRematch = false,
    bool freshOtbRematch = false,
  }) {
    _clockTimer?.cancel();
    _lichessStreamGeneration += 1;
    unawaited(_lichessSub?.cancel());
    _lichessReconnectTimer?.cancel();
    _lichessSub = null;
    _lichessService = null;
    _lichessReconnectTimer = null;
    _lichessReconnectAttempts = 0;
    final startsFreshBotGame = freshBotRematch && _isBotGame;
    final startsFreshOtbGame = freshOtbRematch && _isOtbRecordGame;
    final startsFreshRematch = startsFreshBotGame || startsFreshOtbGame;
    final rematchBoardFenMapping = _boardFenMapping;
    final rematchOrientationResolved = _physicalBoardOrientationResolved;
    _fen = switch (widget.mode) {
      // A rematch is a fresh game, but it must retain the position selected
      // in setup (opening, Chess960, or Board Editor).  The old branch used
      // the standard position for every Bot rematch, silently discarding that
      // selection and leaving a connected Move board out of sync.
      GameLaunchMode.bot => widget.botConfig.startFen,
      GameLaunchMode.otb => widget.otbConfig.startFen,
      GameLaunchMode.lichess => LichessBoardService.startposFen,
      _ => standardStartFen,
    };
    // Lichess is synchronized exclusively from the official Board API stream.
    // A locally stored PGN can be stale (or belong to a different snapshot),
    // so never restore it while entering an online Lichess game.  Keep the
    // start position only as a non-interactive placeholder until gameFull /
    // gameState supplies the authoritative initialFen and moves.
    final resumed =
        !startsFreshRematch && (_isBotGame || widget.mode == GameLaunchMode.otb)
            ? _resumeGameFromPgn()
            : null;
    if (resumed != null) {
      _fen = resumed.history.snapshots.last.fen;
    }
    _recordGameId = startsFreshRematch
        ? _newGameRecordId()
        : resumed?.recordId ?? _newGameRecordId();
    if (_isLichessGame && widget.lichessConfig.gameId.isNotEmpty) {
      final owner =
          widget.recordOwnerUserId ?? widget.apiClient?.session?.userId;
      _recordGameId =
          'lichess-${owner ?? 'guest'}-${widget.lichessConfig.gameId}';
    }
    _recordStartedAt = !startsFreshRematch && widget.initialLocalRecord != null
        ? DateTime.fromMillisecondsSinceEpoch(
            (int.tryParse(widget.initialLocalRecord!.draft.playTime) ??
                    DateTime.now().millisecondsSinceEpoch ~/ 1000) *
                1000,
          )
        : DateTime.now();
    _localSaveNoticeShown = false;
    _flipped = _boardFlipAllowed &&
        _isBotGame &&
        widget.botConfig.playerSide == BotPlayerSide.black;
    _lastMove = const [];
    _lastOpponentMoveUci = null;
    _physicalBoardFen = null;
    _clearAllPhysicalLedStates();
    _legalTargetSquares = const {};
    _legalTargetLightQualities = const {};
    _legalTargetSourceSquare = null;
    _externalBoardSelectionVersion += 1;
    _sanMoves
      ..clear()
      ..addAll(resumed?.history.sanMoves ?? const []);
    _snapshots.clear();
    if (resumed == null) {
      _snapshots.add(_MoveSnapshot(fen: _fen, lastMove: const []));
    } else {
      _snapshots.addAll(
        resumed.history.snapshots.map(
          (item) => _MoveSnapshot(fen: item.fen, lastMove: item.lastMove),
        ),
      );
      _lastMove = _snapshots.last.lastMove;
    }
    _currentPly = _snapshots.length - 1;
    // Every new OTB game must confirm the physical board's initial position
    // before the clock starts, including the standard starting position.
    // Resumed games already have recorded moves and must continue normally.
    _otbPhysicalSetupTargetFen =
        _isOtbRecordGame && _currentPly == 0 ? _boardOnlyFen(_fen) : null;
    _gameOver = false;
    _gameOverSideEffectsHandled = false;
    _careerEloSettled = false;
    _resignInFlight = false;
    _botThinking = false;
    _shareLiveUrlInFlight = false;
    _reviewPromptRecorded = false;
    _startGameBeepPlayed = false;
    _pendingPhysicalMoveTimer?.cancel();
    _pendingPhysicalMoveTimer = null;
    _moveBoardRestoreTimer?.cancel();
    _moveBoardRestoreTimer = null;
    _pendingPhysicalMoveBoardFen = null;
    _pendingMoveBoardRestoreFen = null;
    _lastMoveBoardSetMoveSignature = null;
    _moveBoardSetMoveInFlight = false;
    _moveBoardOpeningSyncPending = false;
    _moveBoardOpeningSyncChecked = false;
    _clearPendingClockSwitchMove();
    _pendingOpponentClockSwitchBoardFen = null;
    _boardFenMapping = startsFreshRematch && _boardFlipAllowed
        ? rematchBoardFenMapping
        : _BoardFenMapping.identity;
    _physicalBoardOrientationResolved = startsFreshRematch && _boardFlipAllowed
        ? rematchOrientationResolved
        : false;
    _lastPhysicalLedSignature = null;
    _lichessWhiteName = '';
    _lichessBlackName = '';
    _lichessWhiteRating = null;
    _lichessBlackRating = null;
    _lichessPlayerSide = LichessPlayerSide.none;
    _lichessTimeMinutesOverride = null;
    _lichessIncrementSecondsOverride = null;
    _lichessUnlimitedClockInitialMs = null;
    _lichessRatedOverride = null;
    _otbWhiteName = startsFreshRematch
        ? 'White'
        : widget.initialLocalRecord?.draft.whiteName ?? 'White';
    _otbBlackName = startsFreshRematch
        ? 'Black'
        : widget.initialLocalRecord?.draft.blackName ?? 'Black';
    _lichessPositionInitialized = false;
    _lichessServerStateReceived = false;
    _lichessInitialFen = null;
    _pendingLichessDrawOfferFrom = null;
    _handledLichessDrawOfferFrom = null;
    _lichessDrawDialogInFlight = false;
    _hintMove = null;
    _engineEvalLabel = null;
    _engineEvalRequestId += 1;
    _clearMoveQualityAnalysisCache();
    _showBotEvaluation = widget.boardSettings.showScorebar;
    _showLegalTargets = widget.boardSettings.showLegalMoves;
    _recordPgnId = startsFreshRematch ? null : widget.initialPgnId;
    _recordShareId = startsFreshRematch ? null : widget.initialShareId;
    _lastRecordSaveKey = null;
    final apiClient = widget.apiClient;
    final saveService = widget.recordSaveService ??
        (apiClient == null
            ? null
            : GameRecordSaveService(
                apiClient: apiClient,
                localStore: _ownedLocalRecordStore ??= LocalGameRecordStore(),
              ));
    _recordSaveCoordinator = saveService == null
        ? null
        : _GameRecordSaveCoordinator(
            service: saveService,
            ownerUserId: widget.recordOwnerUserId ?? apiClient?.session?.userId,
            initialPgnId: _recordPgnId,
            initialShareId: _recordShareId,
            onSaved: widget.onGameRecordSaved,
          );
    _resultText = '';
    _finalResultText = '';
    _lichessResultToken = '*';
    final baseSeconds =
        _isLichessGame && !_lichessServerStateReceived ? 0 : _timeMinutes * 60;
    _whiteSeconds = resumed?.whiteSeconds ?? baseSeconds;
    _blackSeconds = resumed?.blackSeconds ?? baseSeconds;
    _clockLastAlignedAt = DateTime.now();
    _restoreLatestGameState();
    if (mounted) setState(() {});
    _refreshPhysicalLedStates(immediate: true);
    _startClock();
    _startLichessStreamIfNeeded();
    _startPhysicalBoardStreamIfNeeded();
    _syncMoveBoardOpeningPositionFromLatestFen();
    _startLatencyProbeIfNeeded();
    _prepareBotEngineIfNeeded();
    _schedulePositionEvaluation();
    if (resumed == null) {
      _playSound(AppSoundEvent.gameStart);
    }
    if (!_isWidgetTest || widget.botEngine != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBotMove());
    }
    _scheduleMoveQualityAnalysis();
    _reportGameActive(!_gameOver);
  }

  void _reportGameActive(bool active) {
    if (_reportedGameActive == active) return;
    _reportedGameActive = active;
    widget.onGameActiveChanged?.call(active);
  }

  _ResumedGameState? _resumeGameFromPgn() {
    final pgn = _isLichessGame
        ? widget.lichessConfig.resumePgn
        : widget.mode == GameLaunchMode.otb
            ? widget.otbConfig.resumePgn
            : widget.botConfig.resumePgn;
    if (pgn == null || pgn.trim().isEmpty) return null;
    try {
      final parsed = GameNotationService.parsePgn(pgn);
      return _ResumedGameState(
        history: GameMoveHistory(
          sanMoves:
              parsed.moves.map((move) => move.san).toList(growable: false),
          snapshots: parsed.snapshots,
        ),
        whiteSeconds: _clockSecondsFromHeader(parsed.headers['WhiteTime']),
        blackSeconds: _clockSecondsFromHeader(parsed.headers['BlackTime']),
        recordId: parsed.headers['ChessnutGameId']?.trim(),
      );
    } catch (_) {
      return null;
    }
  }

  int? _clockSecondsFromHeader(String? value) {
    final seconds = int.tryParse(value?.trim() ?? '');
    if (seconds == null) return null;
    return seconds.clamp(0, 999999);
  }

  String _newGameRecordId() {
    return 'chessnut-${DateTime.now().microsecondsSinceEpoch}-'
        '${identityHashCode(this)}';
  }

  int? _clockSecondsFromMillis(int? value) {
    if (value == null) return null;
    final unlimitedInitialMs = _lichessUnlimitedClockInitialMs;
    if (_isLichessGame && unlimitedInitialMs != null) {
      final elapsedMs = (unlimitedInitialMs - value).clamp(0, 999999000);
      return elapsedMs ~/ 1000;
    }
    // Lichess uses a large sentinel for games without a normal countdown.
    // If the game stream did not include clock.initial, do not render that
    // sentinel as 16666:39 (999999 seconds).
    if (_isLichessGame &&
        value >= LichessBoardService.unlimitedClockThresholdMs) {
      return null;
    }
    final seconds = (value / 1000).ceil();
    final rejectLichessSentinel =
        _isLichessGame && _timeMinutes > 0 && seconds >= 999999;
    if (rejectLichessSentinel) return null;
    return seconds.clamp(0, 999999);
  }

  Future<String?> _openAiKeyForVoiceMove() async {
    final apiClient = widget.apiClient;
    if (apiClient == null || apiClient.session == null) {
      throw const VoiceMoveOpenAiSessionException(
        'Sign in to use voice moves.',
      );
    }
    final result = await apiClient.getOpenaiKey();
    final key = result.data?.trim();
    if (result.isSuccess && key != null && key.isNotEmpty) return key;
    throw VoiceMoveOpenAiSessionException(
      result.status.errorMessage ??
          'Online voice recognition could not get an OpenAI session.',
    );
  }

  Future<void> _toggleVoiceMoves() async {
    if (_voiceMovesEnabled) {
      await _stopVoiceMoves();
      return;
    }
    if (!_canUseVoiceMoves) {
      _showMessage('Connect Chessnut Move first.');
      return;
    }
    if (!await ensureVoiceMovesOnlineReady(context)) return;
    if (!mounted) return;
    final systemLocale = Localizations.maybeLocaleOf(context);
    setState(() => _voiceMovesEnabled = true);
    final started = await _voiceMoveRecognitionService.start(
      mode: widget.boardSettings.voiceMoveRecognitionMode,
      language: widget.boardSettings.voiceMoveLanguage,
      systemLocale: systemLocale,
    );
    if (!mounted) return;
    if (!started) {
      setState(() {
        _voiceMovesEnabled = false;
        _voiceMovesListening = false;
      });
      return;
    }
    unawaited(showVoiceMovesMicPrompt(context));
  }

  Future<void> _stopVoiceMoves() async {
    await _voiceMoveRecognitionService.stop();
    if (!mounted) return;
    setState(() {
      _voiceMovesEnabled = false;
      _voiceMovesListening = false;
    });
  }

  void _handleVoiceMoveEvent(VoiceMoveRecognitionEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case VoiceMoveEventType.ready:
        if (!_voiceMovesEnabled) setState(() => _voiceMovesEnabled = true);
      case VoiceMoveEventType.listening:
        setState(() {
          _voiceMovesEnabled = true;
          _voiceMovesListening = true;
        });
      case VoiceMoveEventType.ended:
        setState(() {
          _voiceMovesEnabled = false;
          _voiceMovesListening = false;
        });
      case VoiceMoveEventType.result:
        _handleVoiceMoveText(event.text ?? '');
      case VoiceMoveEventType.error:
        setState(() {
          _voiceMovesEnabled = false;
          _voiceMovesListening = false;
        });
        final message = event.message ?? 'Voice recognition failed.';
        _showMessage(message);
    }
  }

  void _handleVoiceMoveText(String text) {
    if (!_isOtbRecordGame && !_isPlayerTurn) return;
    final uci = parseVoiceMoveText(text, fen: _fen);
    if (uci == null) return;
    final move = _moveFromUci(_fen, uci);
    if (move == null) {
      if (uci == _lastOpponentMoveUci) return;
      _showMessage('Voice move $uci is not legal here.');
      return;
    }
    _onPlayerMove(move);
  }

  int get _timeMinutes => widget.mode == GameLaunchMode.otb
      ? widget.otbConfig.timeMinutes
      : _isLichessGame
          ? (!_lichessServerStateReceived
              ? 0
              : _lichessTimeMinutesOverride ?? 0)
          : widget.botConfig.timeMinutes;

  int get _incrementSeconds => widget.mode == GameLaunchMode.otb
      ? widget.otbConfig.incrementSeconds
      : _isLichessGame
          ? (!_lichessServerStateReceived
              ? 0
              : _lichessIncrementSecondsOverride ?? 0)
          : widget.botConfig.incrementSeconds;

  String get _timeLabel {
    if (_isLichessGame && !_lichessServerStateReceived) return 'Loading';
    return _timeMinutes <= 0 ? 'Unlimited' : '$_timeMinutes+$_incrementSeconds';
  }

  bool get _lichessRated => _lichessRatedOverride ?? widget.lichessConfig.rated;

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _gameOver || !_clockOfficiallyStarted) {
        _clockLastAlignedAt = DateTime.now();
        return;
      }
      final game = _liveGame;
      var flagged = false;
      setState(() {
        _clockLastAlignedAt = DateTime.now();
        if (_timeMinutes <= 0) {
          if (game.turn == dc.Side.white) {
            _whiteSeconds = (_whiteSeconds + 1).clamp(0, 999999);
          } else {
            _blackSeconds = (_blackSeconds + 1).clamp(0, 999999);
          }
          return;
        }
        if (game.turn == dc.Side.white) {
          _whiteSeconds = (_whiteSeconds - 1).clamp(0, 999999);
          if (_whiteSeconds == 0) {
            flagged = true;
            _finishOnClock(whiteFlagged: true);
          }
        } else {
          _blackSeconds = (_blackSeconds - 1).clamp(0, 999999);
          if (_blackSeconds == 0) {
            flagged = true;
            _finishOnClock(whiteFlagged: false);
          }
        }
      });
      if (flagged) _handleGameOverSideEffects();
    });
  }

  void _alignClockToNow() {
    if (_gameOver || !_clockOfficiallyStarted) {
      _clockLastAlignedAt = DateTime.now();
      return;
    }
    final now = DateTime.now();
    final lastAlignedAt = _clockLastAlignedAt;
    if (lastAlignedAt == null) {
      _clockLastAlignedAt = now;
      return;
    }
    final elapsedSeconds = now.difference(lastAlignedAt).inSeconds;
    if (elapsedSeconds <= 0) return;
    final game = _liveGame;
    if (_timeMinutes <= 0) {
      if (game.turn == dc.Side.white) {
        _whiteSeconds = (_whiteSeconds + elapsedSeconds).clamp(0, 999999);
      } else {
        _blackSeconds = (_blackSeconds + elapsedSeconds).clamp(0, 999999);
      }
    } else if (game.turn == dc.Side.white) {
      _whiteSeconds = (_whiteSeconds - elapsedSeconds).clamp(0, 999999);
    } else {
      _blackSeconds = (_blackSeconds - elapsedSeconds).clamp(0, 999999);
    }
    _clockLastAlignedAt = now;
  }

  void _finishOnClock({required bool whiteFlagged}) {
    if (_gameOver) return;
    // Lichess 游戏的超时由服务器判定，本地时钟仅用于显示
    if (_isLichessGame) return;
    _gameOver = true;
    _clockTimer?.cancel();
    _resultText = whiteFlagged ? 'Black wins on time' : 'White wins on time';
    _finalResultText = _resultText;
  }

  void _handleGameOverSideEffects() {
    if (!_gameOver || _gameOverSideEffectsHandled) return;
    _gameOverSideEffectsHandled = true;
    _reportGameActive(false);
    _playSound(_soundForGameResult());
    widget.onGameCompleted?.call(
      GameCompletionContext(
        mode: widget.mode,
        isCareerGame: widget.mode == GameLaunchMode.bot &&
            widget.botConfig.careerMode != null,
      ),
    );
    unawaited(_settleCareerEloIfNeeded());
    unawaited(_saveGameRecordIfNeeded());
    unawaited(_recordReviewPromptOutcomeIfNeeded());
    _showGameOverDialog();
  }

  Future<void> _settleCareerEloIfNeeded() async {
    final career = widget.botConfig.careerMode;
    final apiClient = widget.apiClient;
    if (_careerEloSettled ||
        career == null ||
        widget.mode != GameLaunchMode.bot ||
        apiClient == null ||
        apiClient.session == null) {
      return;
    }
    final result = _gameOverResult();
    _careerEloSettled = true;
    final update = await apiClient.settleCareerElo(_careerResultToken(result));
    if (!mounted) return;
    if (update.isSuccess) {
      final reward = update.data?.dailyTaskReward;
      if (reward != null) {
        widget.onGameCompleted?.call(
          GameCompletionContext(
            mode: widget.mode,
            isCareerGame: true,
            careerDailyTaskReward: reward,
          ),
        );
      }
      return;
    }
    _careerEloSettled = false;
    _showMessage(
      update.status.errorMessage ??
          'Career rating could not sync. Please check your connection.',
    );
  }

  String _careerResultToken(_GameOverResult result) {
    return switch (result) {
      _GameOverResult.victory => 'victory',
      _GameOverResult.defeat => 'defeat',
      _GameOverResult.draw => 'draw',
    };
  }

  AppSoundEvent _soundForGameResult() {
    return switch (_gameOverResult()) {
      _GameOverResult.victory => AppSoundEvent.victory,
      _GameOverResult.defeat => AppSoundEvent.defeat,
      _GameOverResult.draw => AppSoundEvent.draw,
    };
  }

  Future<void> _recordReviewPromptOutcomeIfNeeded() async {
    final service = widget.reviewPromptService;
    if (service == null || _reviewPromptRecorded) return;
    final mode = _reviewMode();
    if (mode == null) return;
    _reviewPromptRecorded = true;
    await service.recordOutcome(
      ReviewPromptOutcome(mode: mode, result: _reviewResult()),
    );
  }

  ReviewPromptGameMode? _reviewMode() {
    return switch (widget.mode) {
      GameLaunchMode.bot => ReviewPromptGameMode.bot,
      GameLaunchMode.lichess => ReviewPromptGameMode.lichess,
      GameLaunchMode.otb => ReviewPromptGameMode.otb,
      GameLaunchMode.chesscom => ReviewPromptGameMode.chesscom,
      GameLaunchMode.clock => ReviewPromptGameMode.clock,
    };
  }

  ReviewPromptGameResult _reviewResult() {
    return switch (_gameOverResult()) {
      _GameOverResult.victory => ReviewPromptGameResult.victory,
      _GameOverResult.defeat => ReviewPromptGameResult.defeat,
      _GameOverResult.draw => ReviewPromptGameResult.draw,
    };
  }

  _GameRoomCopy _copyForCurrentGame() {
    if (_isBotGame) {
      final saved = _resumedLocalDraft;
      return _GameRoomCopy.fromBotConfig(
        widget.botConfig,
        opponentName: saved == null
            ? null
            : (_playerIsWhite ? saved.blackName : saved.whiteName),
      );
    }
    if (_isLichessGame) {
      return _GameRoomCopy(
        title: 'Lichess game',
        subtitle: 'Native board room / $_timeLabel',
        opponent: _lichessOpponentName(),
        opponentSource: 'Lichess / live board stream',
        playerSource: 'Online game / clock keeps running',
        turn: 'White to move',
        eval: '+0.4',
      );
    }
    return _GameRoomCopy.fromMode(widget.mode, otbConfig: widget.otbConfig);
  }

  @override
  Widget build(BuildContext context) {
    final copy = _copyForCurrentGame();
    final game = loadDartChessPosition(_fen);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _showExitConfirm(context);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final height = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height;
          final spec = ResponsiveSpec(width, height: height);
          final androidPhoneLandscape = !kIsWeb &&
              defaultTargetPlatform == TargetPlatform.android &&
              !widget.isChessnutClockDevice &&
              width > height &&
              width < 1000 &&
              height < 600;
          final compactLandscape =
              spec.compactLandscape || androidPhoneLandscape;
          final boardHidingAvailable = _supportsBoardHiding;
          final compactSpacing = androidPhoneLandscape ? 8.0 : spec.gutter;
          final compactHorizontalPadding =
              androidPhoneLandscape ? 8.0 : spec.horizontalPadding;
          final compactVerticalPadding =
              androidPhoneLandscape ? 8.0 : spec.topPadding;
          final usesAndroidPortraitPhoneHeader = !kIsWeb &&
              defaultTargetPlatform == TargetPlatform.android &&
              !widget.isChessnutClockDevice &&
              height > width &&
              width < 600;
          final usesPortraitPhoneOtbTitle = !kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS) &&
              !widget.isChessnutClockDevice &&
              height > width &&
              width < 600 &&
              _isOtbRecordGame;
          final usesIosPortraitPhoneOtbTitle = usesPortraitPhoneOtbTitle &&
              defaultTargetPlatform == TargetPlatform.iOS;
          final usesAndroidPortraitPhoneOtbTitle = usesPortraitPhoneOtbTitle &&
              defaultTargetPlatform == TargetPlatform.android;
          final compactLichessHeader = _isLichessGame &&
              !kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.windows ||
                  (defaultTargetPlatform == TargetPlatform.iOS &&
                      spec.compact) ||
                  usesAndroidPortraitPhoneHeader);
          final usesCompactBotHeader = _usesIosBotHeader ||
              (!kIsWeb &&
                  defaultTargetPlatform == TargetPlatform.macOS &&
                  _isBotGame &&
                  compactLandscape) ||
              (usesAndroidPortraitPhoneHeader && _isBotGame);
          final voiceMovesShortcut = _canUseVoiceMoves
              ? VoiceMovesShortcutButton(
                  enabled: _voiceMovesEnabled,
                  listening: _voiceMovesListening,
                  onPressed: _toggleVoiceMoves,
                  valueKey: const ValueKey('game-room-voice-moves-toggle'),
                  size: compactLichessHeader ? 38 : 44,
                )
              : null;
          final stacksAndroidOtbStatusAboveTitle =
              usesAndroidPortraitPhoneOtbTitle && voiceMovesShortcut == null;
          final showOnlineLatencyBadge =
              widget.mode == GameLaunchMode.lichess ||
                  widget.mode == GameLaunchMode.chesscom;
          final usesMacDesktopHeader = !kIsWeb &&
              defaultTargetPlatform == TargetPlatform.macOS &&
              width >= 1000;
          final headerStatusCapsules = Row(
            key: const ValueKey('game-room-status-capsules'),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showOnlineLatencyBadge) ...[
                NetworkLatencyBadge(
                  snapshot: _latency,
                  showPlatform: !compactLichessHeader,
                  fontSize: compactLichessHeader ? 12 : null,
                  iconSize: compactLichessHeader ? 14 : null,
                  horizontalPadding: compactLichessHeader ? 8 : null,
                ),
                if (!widget.hidePhysicalBoardConnectionUi)
                  SizedBox(width: compactLichessHeader ? 4 : 6),
              ],
              if (!widget.hidePhysicalBoardConnectionUi)
                BoardConnectionBadge(
                  state: _boardState,
                  compact: compactLichessHeader ||
                      (spec.compact && !_isOnlineBoardRoom),
                  fontSize: compactLichessHeader ? 12 : null,
                  indicatorSize: compactLichessHeader ? 7 : null,
                  horizontalPadding: compactLichessHeader ? 8 : null,
                ),
              if (voiceMovesShortcut != null) ...[
                SizedBox(width: compactLichessHeader ? 4 : 6),
                voiceMovesShortcut,
              ],
            ],
          );
          final compactHeaderTrailingMaxWidth =
              ((width - spec.horizontalPadding * 2) * 0.56)
                  .clamp(0.0, 220.0)
                  .toDouble();
          void leaveGame() {
            if (_botGameNeedsExitConfirm) {
              _showExitConfirm(context);
            } else {
              _returnFromGameRoom();
            }
          }

          final header = usesCompactBotHeader
              ? _IosBotGameHeader(
                  title: _iosBotHeaderTitle,
                  onBack: leaveGame,
                  trailing: headerStatusCapsules,
                )
              : ScreenHeader(
                  title: compactLichessHeader ? 'Lichess' : copy.title,
                  subtitle: compactLichessHeader ? _timeLabel : copy.subtitle,
                  titleMaxLines: 1,
                  titleOverflow: TextOverflow.ellipsis,
                  scaleTitleToFit:
                      (usesAndroidPortraitPhoneHeader && _isLichessGame) ||
                          (usesPortraitPhoneOtbTitle &&
                              !stacksAndroidOtbStatusAboveTitle),
                  leading: IconButton.filledTonal(
                    tooltip: _isLichessGame ? 'Leave Lichess' : 'Leave game',
                    onPressed: leaveGame,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  compactTrailingFraction:
                      usesIosPortraitPhoneOtbTitle ? 0.4 : 0.56,
                  trailingMaxWidth: usesMacDesktopHeader
                      ? (width * 0.5).clamp(520.0, 620.0).toDouble()
                      : null,
                  trailingPinnedToRight: true,
                  reservePinnedTrailingWidth: !stacksAndroidOtbStatusAboveTitle,
                  trailing: stacksAndroidOtbStatusAboveTitle
                      ? Transform.translate(
                          offset: const Offset(0, -28),
                          child: headerStatusCapsules,
                        )
                      : compactLichessHeader
                          ? SizedBox(
                              width: compactHeaderTrailingMaxWidth,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: headerStatusCapsules,
                              ),
                            )
                          : headerStatusCapsules,
                );

          final showScoreBar = _allowsScoreBar && _showBotEvaluation;
          final scoreBarWidth = showScoreBar ? 30.0 : 0.0;
          final topClock = _displayClock(
            game: _liveGame,
            copy: copy,
            top: true,
          );
          final bottomClock = _displayClock(
            game: _liveGame,
            copy: copy,
            top: false,
          );
          if (boardHidingAvailable && _boardHidden) {
            final followsPortraitPhoneFlip =
                usesPortraitPhoneOtbTitle && _flipped;
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spec.horizontalPadding,
                vertical: spec.topPadding,
              ),
              child: _HiddenBoardGameRoom(
                topClock: _isOtbRecordGame
                    ? _hiddenOtbClock(
                        game: game,
                        side: followsPortraitPhoneFlip
                            ? dc.Side.white
                            : dc.Side.black,
                      )
                    : topClock,
                bottomClock: _isOtbRecordGame
                    ? _hiddenOtbClock(
                        game: game,
                        side: followsPortraitPhoneFlip
                            ? dc.Side.black
                            : dc.Side.white,
                      )
                    : bottomClock,
                onEditTopName: _isOtbRecordGame
                    ? () => _editWindowsOtbPlayerName(
                          side: followsPortraitPhoneFlip
                              ? dc.Side.white
                              : dc.Side.black,
                        )
                    : null,
                onEditBottomName: _isOtbRecordGame
                    ? () => _editWindowsOtbPlayerName(
                          side: followsPortraitPhoneFlip
                              ? dc.Side.black
                              : dc.Side.white,
                        )
                    : null,
                onShowBoard: () => setState(() => _boardHidden = false),
                onMore: _isChessnutClockBot ? null : () => _showMore(context),
                onHint: _isChessnutClockBot ? _showHint : null,
                hintEnabled:
                    _isChessnutClockBot && !_gameConcluded && _isPlayerTurn,
                onSettings:
                    _isChessnutClockBot ? () => _showMore(context) : null,
                isBotGame: _isBotGame,
              ),
            );
          }
          final enlargeClockOtbBoard = widget.isChessnutClockDevice &&
              _isOtbRecordGame &&
              !_isOtbFenPosition;
          final clockOnlyGame = _isClockOnlyOtb || _isClockOnlyBot;
          final board = ResponsiveBoardFrame(
            key: const ValueKey('game-board-frame'),
            maxSize: androidPhoneLandscape
                ? (height - 40).clamp(220.0, 300.0).toDouble()
                : compactLandscape
                    ? (clockOnlyGame ? 500 : 430)
                    : (spec.canSplit ? 560 : 720) +
                        (enlargeClockOtbBoard ? 76 : 0),
            extraWidth: scoreBarWidth,
            padding: enlargeClockOtbBoard
                ? EdgeInsets.zero
                : const EdgeInsets.all(6),
            tint: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xAA050608)
                : const Color(0xE8FFFFFF),
            builder: (size) => _GameBoardStage(
              size: size,
              showScoreBar: showScoreBar,
              scoreBarWidth: scoreBarWidth,
              evalLabel: _evalLabel(copy),
              child: RepaintBoundary(
                child: InteractiveChessBoard(
                  key: ValueKey(_fen),
                  size: size,
                  initialFen: _fen,
                  flipped: _flipped,
                  lastMove: _lastMove,
                  enabledColors: _enabledColors(game),
                  showLegalTargets: _canShowVirtualLegalTargetGuidance,
                  externalSelectedSquare: _legalTargetSourceSquare,
                  externalSelectionVersion: _externalBoardSelectionVersion,
                  externalLegalTargets: _legalTargetSquares.toList(
                    growable: false,
                  ),
                  legalTargetQualities: _canShowVirtualMoveQuality
                      ? _legalTargetLightQualities
                      : const {},
                  showCoordinates: widget.showBoardCoordinates,
                  showCheckHighlight: true,
                  hintMove: _hintMove,
                  onChanged: _onBoardStateChanged,
                  onMove: _onPlayerMove,
                ),
              ),
            ),
          );

          if (_isClockOnlyOtb || _isClockOnlyBot) {
            return _ClockOnlyGameRoom(
              board: board,
              blackClock: _flipped ? bottomClock : topClock,
              whiteClock: _flipped ? topClock : bottomClock,
              sideToMove: game.turn,
              gameOver: _gameConcluded,
              onBack: () => _showExitConfirm(context),
              onResign: _isClockOnlyOtb
                  ? _showClockOtbResignConfirm
                  : (side) =>
                      side == (_playerIsWhite ? dc.Side.white : dc.Side.black)
                          ? _showResignExitConfirm()
                          : null,
              onDraw: _isClockOnlyOtb
                  ? _showClockOtbDrawConfirm
                  : (side) =>
                      side == (_playerIsWhite ? dc.Side.white : dc.Side.black)
                          ? _showBotDrawConfirm()
                          : null,
              onHint: _isClockOnlyOtb
                  ? _showClockOtbHint
                  : (side) =>
                      side == (_playerIsWhite ? dc.Side.white : dc.Side.black)
                          ? _showHint()
                          : null,
              onSettings: () => _isClockOnlyOtb
                  ? _showClockOtbSettings(context)
                  : _showMore(context),
              voiceMovesShortcut: voiceMovesShortcut,
              onEditBlackName: _isClockOnlyOtb
                  ? () => _editWindowsOtbPlayerName(side: dc.Side.black)
                  : null,
              onEditWhiteName: _isClockOnlyOtb
                  ? () => _editWindowsOtbPlayerName(side: dc.Side.white)
                  : null,
              showControls: _isClockOnlyOtb,
              showBotControls: _isClockOnlyBot,
              botPlayerSide: _playerIsWhite ? dc.Side.white : dc.Side.black,
              onFlip: _boardFlipAllowed ? _toggleBoardFlip : null,
              onNamesFlip: _toggleClockOnlyNamesFlip,
              namesFlipped: _clockOnlyNamesFlipped,
              onHideBoard: _isClockOnlyBot ? _toggleBoardVisibility : null,
              playerNameFontSize: _isClockOnlyBot ? 52 : 84,
              turnLabelForSide: _isClockOnlyBot
                  ? (side) =>
                      side == (_playerIsWhite ? dc.Side.white : dc.Side.black)
                          ? 'Your turn'
                          : 'Bot turn'
                  : (side) =>
                      '${side == dc.Side.white ? 'White' : 'Black'} to move',
              qualityLightsForSide: _clockOtbQualityLightsEnabledForSide,
              onQualityLightsChanged: (side, value) {
                setState(() {
                  if (side == dc.Side.white) {
                    _clockOtbWhiteQualityLightsOverride = value;
                  } else {
                    _clockOtbBlackQualityLightsOverride = value;
                  }
                  if (!value && game.turn == side) {
                    _legalTargetLightQualities = const {};
                    _clearMoveQualityAnalysisCache();
                  }
                });
                if (value && game.turn == side) {
                  _scheduleMoveQualityAnalysis();
                }
              },
            );
          }

          if (_isLichessGame && compactLandscape) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                compactHorizontalPadding,
                compactVerticalPadding,
                compactHorizontalPadding,
                compactVerticalPadding,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: _CompactLandscapeLichessRoom(
                  spacing: compactSpacing,
                  title: _compactTitle(copy),
                  onBack: () => _showExitConfirm(context),
                  board: board,
                  statusCapsules: _GameStatusCapsules(
                    mode: widget.mode,
                    boardState: _boardState,
                    latency: _latency,
                    compact: true,
                    trailing: voiceMovesShortcut,
                    hidePhysicalBoardConnectionUi:
                        widget.hidePhysicalBoardConnectionUi,
                  ),
                  topClock: _PlayerClock(
                    key: const ValueKey('game-clock-top'),
                    name: topClock.name,
                    rating: topClock.rating,
                    source: topClock.source,
                    time: _formatClock(topClock.seconds),
                    active: topClock.active,
                    compactLandscape: true,
                  ),
                  bottomClock: _PlayerClock(
                    key: const ValueKey('game-clock-bottom'),
                    name: bottomClock.name,
                    rating: bottomClock.rating,
                    source: bottomClock.source,
                    time: _formatClock(bottomClock.seconds),
                    active: bottomClock.active,
                    compactLandscape: true,
                  ),
                  sanStrip: _buildLichessMovePanel(compactLandscape: true),
                  actions: _GameActions(
                    showHint: false,
                    enabled: !_gameConcluded,
                    onHint: _showHint,
                    onFlip: _boardFlipAllowed ? _toggleBoardFlip : null,
                    onPrevious: _goPrevious,
                    onNext: _goNext,
                    onMore: () => _showMore(context),
                    compactLandscape: true,
                    showBoardVisibilityToggle: boardHidingAvailable,
                    boardHidden: _boardHidden,
                    onToggleBoardVisibility: _toggleBoardVisibility,
                  ),
                ),
              ),
            );
          }

          if (_isLichessGame) {
            return ResponsivePage(
              children: (context, spec) => [
                header,
                SizedBox(height: spec.gutter),
                ResponsiveSplit(
                  breakpoint: 900,
                  spacing: spec.gutter,
                  leadingFlex: 7,
                  trailingFlex: 4,
                  leading: SectionColumn(
                    spacing: 10,
                    children: [
                      _PlayerClock(
                        key: const ValueKey('game-clock-opponent'),
                        name: topClock.name,
                        rating: topClock.rating,
                        source: topClock.source,
                        time: _formatClock(topClock.seconds),
                        active: topClock.active,
                        alignRight: true,
                      ),
                      board,
                      _PlayerClock(
                        key: const ValueKey('game-clock-player'),
                        name: bottomClock.name,
                        rating: bottomClock.rating,
                        source: bottomClock.source,
                        time: _formatClock(bottomClock.seconds),
                        active: bottomClock.active,
                      ),
                    ],
                  ),
                  trailing: SectionColumn(
                    spacing: 10,
                    children: [
                      _buildLichessMovePanel(),
                      _GameActions(
                        showHint: false,
                        enabled: !_gameConcluded,
                        onHint: _showHint,
                        onFlip: _boardFlipAllowed ? _toggleBoardFlip : null,
                        onPrevious: _goPrevious,
                        onNext: _goNext,
                        onMore: () => _showMore(context),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          if (compactLandscape) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                compactHorizontalPadding,
                compactVerticalPadding,
                compactHorizontalPadding,
                compactVerticalPadding,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: _CompactLandscapeGameRoom(
                  key: androidPhoneLandscape
                      ? const ValueKey('game-room-android-phone-landscape')
                      : null,
                  spacing: compactSpacing,
                  title:
                      androidPhoneLandscape ? copy.title : _compactTitle(copy),
                  onBack: () => _showExitConfirm(context),
                  board: board,
                  statusCapsules: _GameStatusCapsules(
                    mode: widget.mode,
                    boardState: _boardState,
                    latency: _latency,
                    compact: true,
                    trailing: voiceMovesShortcut,
                    hidePhysicalBoardConnectionUi:
                        widget.hidePhysicalBoardConnectionUi,
                  ),
                  statusPinnedTopRight: usesCompactBotHeader,
                  phoneCompact: androidPhoneLandscape,
                  opponentClock: _PlayerClock(
                    key: const ValueKey('game-clock-top'),
                    name: topClock.name,
                    rating: topClock.rating,
                    source: topClock.source,
                    time: _formatClock(topClock.seconds),
                    active: topClock.active,
                    alignRight: true,
                    compactLandscape: true,
                  ),
                  playerClock: _PlayerClock(
                    key: const ValueKey('game-clock-bottom'),
                    name: bottomClock.name,
                    rating: bottomClock.rating,
                    source: bottomClock.source,
                    time: _formatClock(bottomClock.seconds),
                    active: bottomClock.active,
                    compactLandscape: true,
                  ),
                  sanStrip: _SanStrip(
                    moves: _sanMoves,
                    startFen: _snapshots.first.fen,
                    currentPly: _currentPly,
                    onSelectPly: _goToPly,
                    compactLandscape: true,
                  ),
                  actions: _GameActions(
                    showHint: _allowsHintAssistance,
                    enabled: !_gameConcluded,
                    onHint: _showHint,
                    onFlip: _boardFlipAllowed ? _toggleBoardFlip : null,
                    onPrevious: _goPrevious,
                    onNext: _goNext,
                    onMore: () => _showMore(context),
                    compactLandscape: true,
                    showBoardVisibilityToggle: boardHidingAvailable,
                    boardHidden: _boardHidden,
                    onToggleBoardVisibility: _toggleBoardVisibility,
                  ),
                ),
              ),
            );
          }

          return ResponsivePage(
            children: (context, spec) => [
              header,
              SizedBox(height: spec.gutter),
              ResponsiveSplit(
                breakpoint: 900,
                spacing: spec.gutter,
                leadingFlex: 7,
                trailingFlex: 4,
                leading: SectionColumn(
                  spacing: 10,
                  children: [
                    _PlayerClock(
                      key: const ValueKey('game-clock-top'),
                      name: topClock.name,
                      rating: topClock.rating,
                      source: topClock.source,
                      time: _formatClock(topClock.seconds),
                      active: topClock.active,
                      alignRight: true,
                    ),
                    board,
                    _PlayerClock(
                      key: const ValueKey('game-clock-bottom'),
                      name: bottomClock.name,
                      rating: bottomClock.rating,
                      source: bottomClock.source,
                      time: _formatClock(bottomClock.seconds),
                      active: bottomClock.active,
                    ),
                  ],
                ),
                trailing: SectionColumn(
                  spacing: 10,
                  children: spec.compact
                      ? [
                          _SanStrip(
                            moves: _sanMoves,
                            startFen: _snapshots.first.fen,
                            currentPly: _currentPly,
                            onSelectPly: _goToPly,
                          ),
                          _GameActions(
                            showHint: _allowsHintAssistance,
                            enabled: !_gameConcluded,
                            onHint: _showHint,
                            onFlip: _boardFlipAllowed ? _toggleBoardFlip : null,
                            onPrevious: _goPrevious,
                            onNext: _goNext,
                            onMore: () => _showMore(context),
                            showBoardVisibilityToggle: boardHidingAvailable,
                            boardHidden: _boardHidden,
                            onToggleBoardVisibility: _toggleBoardVisibility,
                          ),
                        ]
                      : [
                          _SanStrip(
                            moves: _sanMoves,
                            startFen: _snapshots.first.fen,
                            currentPly: _currentPly,
                            onSelectPly: _goToPly,
                          ),
                          _GameActions(
                            showHint: _allowsHintAssistance,
                            enabled: !_gameConcluded,
                            onHint: _showHint,
                            onFlip: _boardFlipAllowed ? _toggleBoardFlip : null,
                            onPrevious: _goPrevious,
                            onNext: _goNext,
                            onMore: () => _showMore(context),
                            showBoardVisibilityToggle: boardHidingAvailable,
                            boardHidden: _boardHidden,
                            onToggleBoardVisibility: _toggleBoardVisibility,
                          ),
                        ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Set<dc.Side>? _enabledColors(dc.Position game) {
    if (_isOtbRecordGame) return {game.turn};
    if (!_isBotGame && !_isLichessGame) return null;
    if (_isLichessGame && !_lichessServerStateReceived) return const {};
    if (!_isPlayerTurn) return const {};
    return {_playerIsWhite ? dc.Side.white : dc.Side.black};
  }

  Widget _buildLichessMovePanel({bool compactLandscape = false}) {
    final moveList = _SanStrip(
      moves: _sanMoves,
      startFen: _snapshots.first.fen,
      currentPly: _currentPly,
      onSelectPly: _goToPly,
      compactLandscape: compactLandscape,
    );
    final children = <Widget>[
      if (compactLandscape) Expanded(child: moveList) else moveList,
      SizedBox(height: compactLandscape ? 4 : 6),
      _LichessGameInfoLine(
        timeLabel: _timeLabel,
        rated: _lichessRated,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  _DisplayClock _displayClock({
    required dc.Position game,
    required _GameRoomCopy copy,
    required bool top,
  }) {
    final localSide = _playerIsWhite ? dc.Side.white : dc.Side.black;
    final side = _isLichessGame
        ? (top
            ? (_flipped ? dc.Side.white : dc.Side.black)
            : (_flipped ? dc.Side.black : dc.Side.white))
        : (top
            ? (_flipped ? dc.Side.white : dc.Side.black)
            : (_flipped ? dc.Side.black : dc.Side.white));
    final isLocal = side == localSide;
    if (_isOtbRecordGame) {
      return _DisplayClock(
        name: side == dc.Side.white ? _otbWhiteName : _otbBlackName,
        source: !_gameOver && _atLatest && game.turn == side
            ? 'Your turn / legal moves only'
            : '',
        seconds: side == dc.Side.white ? _whiteSeconds : _blackSeconds,
        active: !_gameOver && game.turn == side,
      );
    }
    return _DisplayClock(
      name: isLocal ? _localPlayerName() : copy.opponent,
      rating: _lichessRatingLabel(side),
      source: isLocal
          ? _playerSource(game)
          : (_botThinking ? 'Thinking...' : copy.opponentSource),
      seconds: side == dc.Side.white ? _whiteSeconds : _blackSeconds,
      active: !_gameOver && game.turn == side,
    );
  }

  String? _lichessRatingLabel(dc.Side side) {
    if (!_isLichessGame) return null;
    final rating =
        side == dc.Side.white ? _lichessWhiteRating : _lichessBlackRating;
    if (rating == null || rating <= 0) return null;
    return 'Elo $rating';
  }

  bool get _isOnlineBoardRoom =>
      widget.mode == GameLaunchMode.lichess ||
      widget.mode == GameLaunchMode.chesscom;

  String _localPlayerName() {
    final saved = _resumedLocalDraft;
    if (_isBotGame && saved != null) {
      return _playerIsWhite ? saved.whiteName : saved.blackName;
    }
    if (!_isLichessGame) return _chessnutPlayerName();
    final fromStream =
        _playerIsWhite ? _lichessWhiteName.trim() : _lichessBlackName.trim();
    if (fromStream.isNotEmpty) return fromStream;
    final configured = widget.lichessConfig.lichessName.trim();
    return configured.isEmpty ? 'Lichess player' : configured;
  }

  GameRecordDraft? get _resumedLocalDraft {
    final saved = widget.initialLocalRecord?.draft;
    return saved?.id == _recordGameId ? saved : null;
  }

  String _chessnutPlayerName() {
    final session = widget.apiClient?.session;
    if (session is ChessnutLoginSession) {
      final username = session.username.trim();
      if (username.isNotEmpty) return username;
      final email = session.email.trim();
      if (email.isNotEmpty) return email;
    }
    return 'Chessnut Player';
  }

  String _lichessOpponentName() {
    if (!_lichessServerStateReceived) return 'Loading';
    final fromStream =
        _playerIsWhite ? _lichessBlackName.trim() : _lichessWhiteName.trim();
    if (fromStream.isNotEmpty) return fromStream;
    return 'Lichess opponent';
  }

  String _compactTitle(_GameRoomCopy copy) {
    if (_usesIosBotHeader ||
        (!kIsWeb &&
            defaultTargetPlatform == TargetPlatform.macOS &&
            widget.mode == GameLaunchMode.bot)) {
      return _iosBotHeaderTitle;
    }
    if (widget.mode == GameLaunchMode.bot) return 'Bot game';
    return copy.title;
  }

  bool get _usesIosBotHeader =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS &&
      widget.mode == GameLaunchMode.bot;

  String get _iosBotHeaderTitle =>
      widget.botConfig.careerMode == null ? 'Robot battle' : 'Career challenge';

  void _onPlayerMove(
    ChessBoardMove move, {
    String? confirmedPhysicalBoardFen,
    bool confirmedByClockSwitch = false,
  }) {
    if (!_isPlayerTurn) return;
    _alignClockToNow();
    final previousFen = _fen;
    final shouldQueueBotMove =
        _isBotGame && !(_isWidgetTest && widget.botEngine == null);
    setState(() {
      _trimFutureIfNeeded();
      _fen = move.fen;
      if (confirmedPhysicalBoardFen != null) {
        _physicalBoardFen = confirmedPhysicalBoardFen;
      }
      _lastMove = [move.from, move.to];
      _hintMove = null;
      _legalTargetSquares = const {};
      _legalTargetLightQualities = const {};
      _legalTargetSourceSquare = null;
      _clearMoveQualityAnalysisCache();
      _sanMoves.add(move.san);
      _snapshots.add(_MoveSnapshot(fen: _fen, lastMove: _lastMove));
      _currentPly = _snapshots.length - 1;
      _clockLastAlignedAt = DateTime.now();
      _applyIncrement(move.state.whiteToMove ? dc.Side.black : dc.Side.white);
      _updateGameOver(move.state);
      if (shouldQueueBotMove && !_gameOver) {
        _botThinking = true;
      }
    });
    _clearOpponentMoveLeds();
    _refreshPhysicalLedStates();
    if (confirmedPhysicalBoardFen == null) {
      _syncMoveBoardAfterVirtualFenChange();
    }
    _handleMoveBeep(move.state);
    if (!confirmedByClockSwitch) {
      _switchClockIfNeeded(forOpponentMove: false);
    }
    _schedulePositionEvaluation();
    if (_isLichessGame) {
      _pendingLichessLocalPly = _sanMoves.length;
      unawaited(_submitLichessMove(
        move.uci,
        previousFen,
      ));
    }
    unawaited(_saveGameRecordIfNeeded());
    if (_gameOver) {
      _handleGameOverSideEffects();
      return;
    }
    _maybeBotMove(alreadyThinking: shouldQueueBotMove);
  }

  Future<void> _submitLichessMove(String uci, String previousFen) async {
    final service = _lichessService;
    final gameId = widget.lichessConfig.gameId;
    if (service == null || gameId.isEmpty) return;
    final ok = await service.makeMove(gameId: gameId, uci: uci);
    if (!mounted) return;
    if (ok) {
      _switchClockForConfirmedLocalSoftwareMove();
      return;
    }
    setState(() {
      _pendingLichessLocalPly = null;
      _fen = previousFen;
      if (_snapshots.length > 1 && _currentPly == _snapshots.length - 1) {
        _snapshots.removeLast();
        if (_sanMoves.isNotEmpty) _sanMoves.removeLast();
        _currentPly = _snapshots.length - 1;
        _lastMove = _snapshots.last.lastMove;
      }
    });
    _refreshPhysicalLedStates();
    _syncMoveBoardAfterVirtualFenChange();
    _showMessage(_lichessMoveRejectedMessage(service.lastErrorMessage));
  }

  void _switchClockForConfirmedLocalSoftwareMove() {
    if (!_isLichessGame) return;
    if (widget.boardSettings.submitMoveOnClockSwitch) return;
    if (widget.boardSettings.clockSwitchAutomation !=
        ClockSwitchAutomationMode.opponentMoveOnly) {
      return;
    }
    unawaited(_switchClockToOppositeIgnoringEcho());
  }

  void _onBoardStateChanged(ChessBoardState state) {
    final shouldShowTargets = _shouldShowVirtualLegalTargets(state);
    final nextSquares = shouldShowTargets
        ? Set<String>.unmodifiable(state.targets)
        : const <String>{};
    final nextSource = shouldShowTargets ? state.selected : null;
    if (nextSource == null) {
      if (_legalTargetSourceSquare == null &&
          _legalTargetSquares.isEmpty &&
          _legalTargetLightQualities.isEmpty &&
          !_legalTargetsFromPhysicalLift) {
        return;
      }
      setState(_clearLegalTargetGuidance);
      _refreshLegalMoveLeds();
      return;
    }
    if (!_legalTargetsFromPhysicalLift &&
        _legalTargetSourceSquare == nextSource &&
        _stringSetsEqual(_legalTargetSquares, nextSquares)) {
      return;
    }
    setState(() {
      _legalTargetSourceSquare = nextSource;
      _legalTargetSquares = nextSquares;
      _legalTargetLightQualities = const {};
      _legalTargetsFromPhysicalLift = false;
    });
    _refreshLegalMoveLeds();
    if (_canShowVirtualMoveQuality && nextSquares.isNotEmpty) {
      _applyMoveQualityForSelection(
        _LegalTargetSelection(
          sourceSquare: nextSource,
          targetSquares: nextSquares,
        ),
      );
    }
  }

  bool _shouldShowVirtualLegalTargets(ChessBoardState state) {
    return _canShowVirtualLegalTargetGuidance &&
        _isPlayerTurn &&
        state.selected != null &&
        state.targets.isNotEmpty;
  }

  void _clearLegalTargetGuidance() {
    _legalTargetSquares = const {};
    _legalTargetLightQualities = const {};
    _legalTargetSourceSquare = null;
    _legalTargetsFromPhysicalLift = false;
  }

  void _clearAllPhysicalLedStates() {
    _fenDifferenceLedSquares = const {};
    _hintLedSquares = const {};
    _legalMovesLedSquares = const {};
    _opponentMoveLedSquares = const {};
    _checkKingLedSquares = const {};
  }

  void _refreshFenDifferenceLeds() {
    final nextSquares = _fenDifferenceSquaresForCurrentBoards();
    if (_stringSetsEqual(_fenDifferenceLedSquares, nextSquares)) return;
    _fenDifferenceLedSquares = nextSquares;
    _schedulePhysicalLedSync();
  }

  void _refreshHintLeds() {
    final hint = _hintMove;
    final nextSquares = hint == null
        ? const <String>{}
        : Set<String>.unmodifiable({hint.from, hint.to});
    if (_stringSetsEqual(_hintLedSquares, nextSquares)) return;
    _hintLedSquares = nextSquares;
    _schedulePhysicalLedSync();
  }

  void _refreshLegalMoveLeds() {
    final enabled = widget.boardSettings.piecePositionLed && _showLegalTargets;
    final nextSquares = enabled
        ? Set<String>.unmodifiable(_legalTargetSquares)
        : const <String>{};
    if (_stringSetsEqual(_legalMovesLedSquares, nextSquares)) return;
    _legalMovesLedSquares = nextSquares;
    _schedulePhysicalLedSync();
  }

  void _clearOpponentMoveLeds() {
    if (_opponentMoveLedSquares.isEmpty) return;
    _opponentMoveLedSquares = const {};
    _schedulePhysicalLedSync();
  }

  void _setOpponentMoveLeds(Iterable<String> squares) {
    final boardModel = widget.boardGateway?.boardModel;
    if (boardModel != PhysicalBoardModel.move &&
        boardModel != PhysicalBoardModel.evo2) {
      return;
    }
    final nextSquares = Set<String>.unmodifiable(squares);
    if (_stringSetsEqual(_opponentMoveLedSquares, nextSquares)) return;
    _opponentMoveLedSquares = nextSquares;
    _schedulePhysicalLedSync();
  }

  Set<String> _fenDifferenceSquaresForCurrentBoards() {
    final physicalFen = _physicalBoardFen;
    if (physicalFen == null || physicalFen.isEmpty) return const {};
    return _differentSquares(_boardOnlyFen(physicalFen), _boardOnlyFen(_fen));
  }

  bool _physicalBoardFenMatchesVirtualOnSquares(Set<String> squares) {
    final physicalFen = _physicalBoardFen;
    if (physicalFen == null || squares.isEmpty) return false;
    final physicalBoard = _expandBoardFen(physicalFen);
    final appBoard = _expandBoardFen(_fen);
    if (physicalBoard == null || appBoard == null) return false;
    for (final square in squares) {
      final index = _boardFenIndexForSquareName(square);
      if (index == null || physicalBoard[index] != appBoard[index]) {
        return false;
      }
    }
    return true;
  }

  void _refreshPhysicalLedStates({bool immediate = false}) {
    _fenDifferenceLedSquares = _fenDifferenceSquaresForCurrentBoards();
    _hintLedSquares = _hintMove == null
        ? const {}
        : Set<String>.unmodifiable({_hintMove!.from, _hintMove!.to});
    _legalMovesLedSquares =
        widget.boardSettings.piecePositionLed && _showLegalTargets
            ? Set<String>.unmodifiable(_legalTargetSquares)
            : const {};
    final checkKingSquare = checkedKingSquareFromFen(_fen);
    _checkKingLedSquares = checkKingSquare == null
        ? const {}
        : Set<String>.unmodifiable({checkKingSquare});
    _schedulePhysicalLedSync(immediate: immediate);
  }

  void _schedulePhysicalLedSync({bool immediate = false}) {
    if (!mounted && !immediate) return;
    if (immediate) {
      _physicalLedTimer?.cancel();
      _physicalLedTimer = null;
      unawaited(_flushPhysicalLeds());
      return;
    }
    _physicalLedFlushPending = true;
    _physicalLedTimer ??= Timer(_physicalLedInterval, () {
      _physicalLedTimer = null;
      unawaited(_flushPhysicalLeds());
    });
  }

  Future<void> _flushPhysicalLeds() async {
    if (_physicalLedCommandInFlight) {
      _schedulePhysicalLedSync();
      return;
    }
    _physicalLedFlushPending = false;
    _physicalLedCommandInFlight = true;
    try {
      await _sendComposedPhysicalLeds();
    } finally {
      _physicalLedCommandInFlight = false;
      if (_physicalLedFlushPending) {
        _schedulePhysicalLedSync();
      }
    }
  }

  Future<void> _sendComposedPhysicalLeds() async {
    final gateway = widget.boardGateway;
    final signature = _physicalLedSignature();
    if (signature == _lastPhysicalLedSignature) return;
    if (gateway == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      _lastPhysicalLedSignature = signature;
      return;
    }
    if (!widget.boardSettings.piecePositionLed) {
      final ok = await _sendPhysicalLedClear(gateway);
      if (ok) _lastPhysicalLedSignature = signature;
      return;
    }
    final ok = switch (gateway.boardModel) {
      PhysicalBoardModel.move => await _sendMoveComposedLeds(gateway),
      PhysicalBoardModel.evo2 => await _sendEvo2ComposedLeds(gateway),
      _ when gateway.boardModel.usesGeneralProtocol =>
        await _sendGeneralComposedLeds(gateway),
      _ => false,
    };
    if (ok) _lastPhysicalLedSignature = signature;
  }

  Future<bool> _sendPhysicalLedClear(PhysicalBoardGateway gateway) {
    if (gateway.boardModel == PhysicalBoardModel.move) {
      return gateway.clearMoveLeds();
    }
    if (gateway.boardModel.usesGeneralProtocol) {
      return gateway.clearGeneralLeds();
    }
    return Future.value(false);
  }

  Future<bool> _sendMoveComposedLeds(PhysicalBoardGateway gateway) {
    final colors = <String, ChessnutMoveLedColor>{};
    for (final square in _fenDifferenceLedSquares) {
      colors[_mapSquareNameToPhysicalBoard(square)] = ChessnutMoveLedColor.red;
    }
    for (final square in _hintLedSquares) {
      colors[_mapSquareNameToPhysicalBoard(square)] = ChessnutMoveLedColor.blue;
    }
    for (final square in _legalMovesLedSquares) {
      colors[_mapSquareNameToPhysicalBoard(square)] =
          ChessnutMoveLedColor.green;
    }
    for (final square in _opponentMoveLedSquares) {
      colors[_mapSquareNameToPhysicalBoard(square)] = ChessnutMoveLedColor.blue;
    }
    for (final square in _checkKingLedSquares) {
      colors[_mapSquareNameToPhysicalBoard(square)] =
          ChessnutMoveLedColor.green;
    }
    if (colors.isEmpty) return gateway.clearMoveLeds();
    return gateway.setMoveLedSquares(colors);
  }

  Future<bool> _sendGeneralComposedLeds(PhysicalBoardGateway gateway) {
    final squares = <String>{
      ..._mapLedSquaresToPhysicalBoard(_fenDifferenceLedSquares),
      ..._mapLedSquaresToPhysicalBoard(_hintLedSquares),
      ..._mapLedSquaresToPhysicalBoard(_legalMovesLedSquares),
      ..._mapLedSquaresToPhysicalBoard(_opponentMoveLedSquares),
      ..._mapLedSquaresToPhysicalBoard(_checkKingLedSquares),
    };
    if (squares.isEmpty) return gateway.clearGeneralLeds();
    return gateway.setGeneralLedSquares(squares);
  }

  Future<bool> _sendEvo2ComposedLeds(PhysicalBoardGateway gateway) {
    final keys = _evo2FenDifferenceLedPatternKeys();
    if (keys.every((key) => key == null)) return gateway.clearGeneralLeds();
    return gateway.setEvo2LedPatternKeys(
      keys,
      widget.boardSettings.evo2LedPatterns,
    );
  }

  List<String?> _evo2FenDifferenceLedPatternKeys() {
    final physicalBoard =
        _expandBoardFen(_boardOnlyFen(_physicalBoardFen ?? ''));
    final appBoard = _expandBoardFen(_boardOnlyFen(_fen));
    if (physicalBoard == null || appBoard == null) {
      return List<String?>.filled(64, null, growable: false);
    }
    final keys = List<String?>.filled(64, null, growable: false);
    for (var index = 0; index < keys.length; index += 1) {
      if (physicalBoard[index] == appBoard[index]) continue;
      final appFile = index % 8;
      final appRank = index ~/ 8;
      final appSquare = '${ChessBoard.files[appFile]}${8 - appRank}';
      final physicalIndex =
          _boardFenIndexForSquareName(_mapSquareNameToPhysicalBoard(appSquare));
      if (physicalIndex == null) continue;
      keys[physicalIndex] = appBoard[index].isEmpty ? 'empty' : appBoard[index];
    }
    for (final square in _checkKingLedSquares) {
      final physicalIndex =
          _boardFenIndexForSquareName(_mapSquareNameToPhysicalBoard(square));
      if (physicalIndex != null) keys[physicalIndex] = 'analysis_other';
    }
    return keys;
  }

  Set<String> _mapLedSquaresToPhysicalBoard(Set<String> squares) {
    if (_boardFenMapping == _BoardFenMapping.identity || squares.isEmpty) {
      return squares;
    }
    return {
      for (final square in squares) _mapSquareNameToPhysicalBoard(square),
    };
  }

  String _mapSquareNameToPhysicalBoard(String squareName) {
    return mapPhysicalBoardSquare(squareName, _boardFenMapping);
  }

  Future<void> _clearPhysicalBoardLeds({bool immediate = false}) async {
    _clearAllPhysicalLedStates();
    _lastPhysicalLedSignature = null;
    final gateway = widget.boardGateway;
    if (gateway == null) return;
    if (gateway.boardModel == PhysicalBoardModel.move) {
      await gateway.clearMoveLeds();
      return;
    }
    if (gateway.boardModel.usesGeneralProtocol) {
      await gateway.clearGeneralLeds();
    }
  }

  String _physicalLedSignature() {
    if (!widget.boardSettings.piecePositionLed) return 'disabled';
    final gateway = widget.boardGateway;
    final model = gateway?.boardModel.name ?? 'none';
    String join(Set<String> squares) {
      final sorted = squares.toList()..sort();
      return sorted.join(',');
    }

    return [
      model,
      _boardFenMapping.name,
      widget.boardSettings.evo2LedPatterns.hashCode.toString(),
      join(_fenDifferenceLedSquares),
      join(_hintLedSquares),
      join(_legalMovesLedSquares),
      join(_opponentMoveLedSquares),
      join(_checkKingLedSquares),
    ].join('|');
  }

  void _toggleBoardFlip() {
    if (!_boardFlipAllowed) return;
    setState(() {
      _flipped = !_flipped;
    });
  }

  void _toggleClockOnlyNamesFlip() {
    if (!_isClockOnlyBot) return;
    setState(() => _clockOnlyNamesFlipped = !_clockOnlyNamesFlipped);
  }

  void _applyBoardFlipPermission() {
    if (!_boardFlipAllowed) {
      _flipped = false;
      return;
    }
    if (_isBotGame) {
      _flipped = widget.botConfig.playerSide == BotPlayerSide.black;
      return;
    }
    _flipped = false;
  }

  Future<void> _maybeBotMove({bool alreadyThinking = false}) async {
    if (_isWidgetTest && widget.botEngine == null) return;
    if (!_isBotGame || !mounted || _gameOver || _isPlayerTurn) {
      return;
    }
    if (_botThinking && !alreadyThinking) return;
    final thinkFen = _fen;
    if (!_botThinking) {
      setState(() => _botThinking = true);
    }
    final engineResult = await _botEngine.bestMove(
      fen: thinkFen,
      config: widget.botConfig,
      moveHistory: _uciHistory(),
    );
    if (!mounted) return;
    if (engineResult == null || _fen != thinkFen) {
      setState(() => _botThinking = false);
      if (_fen == thinkFen) {
        final engineError = _botEngine.lastErrorMessage?.trim();
        final message = engineError != null && engineError.isNotEmpty
            ? '${widget.botConfig.opponent} failed: $engineError'
            : widget.botConfig.engineKind == BotEngineKind.maia3
                ? 'Maia 3 requires an internet connection. Disable airplane mode and try again.'
                : '${widget.botConfig.opponent} failed without an engine error. '
                    'Check engine assets and try again.';
        _showMessage(message);
      }
      return;
    }
    final result = _avoidThreefoldRepetitionIfPossible(
      fen: thinkFen,
      engineResult: engineResult,
    );
    final state = ChessBoardState.fromFen(
      result.fen,
      lastMove: [result.move.from.name, result.move.to.name],
    );
    _alignClockToNow();
    setState(() {
      _trimFutureIfNeeded();
      _fen = result.fen;
      _lastMove = [result.move.from.name, result.move.to.name];
      _lastOpponentMoveUci = result.move.uci;
      _hintMove = null;
      _legalTargetSquares = const {};
      _legalTargetLightQualities = const {};
      _legalTargetSourceSquare = null;
      _clearMoveQualityAnalysisCache();
      _sanMoves.add(result.san);
      _snapshots.add(_MoveSnapshot(fen: _fen, lastMove: _lastMove));
      _currentPly = _snapshots.length - 1;
      _clockLastAlignedAt = DateTime.now();
      _applyIncrement(state.whiteToMove ? dc.Side.black : dc.Side.white);
      _botThinking = false;
      _updateGameOver(state);
    });
    _refreshPhysicalLedStates();
    _syncMoveBoardAfterVirtualFenChange();
    _handleMoveBeep(state);
    if (!_gameOver) {
      _playMoveSound(ChessBoardMove(
        from: result.move.from.name,
        to: result.move.to.name,
        promotion: result.move.promotion?.letter,
        san: result.san,
        fen: result.fen,
        state: state,
      ));
    }
    _switchClockIfNeeded(forOpponentMove: true);
    _schedulePositionEvaluation();
    unawaited(_saveGameRecordIfNeeded());
    if (_gameOver) {
      _handleGameOverSideEffects();
    } else {
      _setOpponentMoveLeds([result.move.from.name, result.move.to.name]);
    }
  }

  void _prepareBotEngineIfNeeded() {
    if (!_isBotGame || _gameOver) return;
    unawaited(_botEngine.prepare(config: widget.botConfig));
  }

  void _schedulePositionEvaluation() {
    final requestId = ++_engineEvalRequestId;
    if (!_allowsScoreBar || !_showBotEvaluation || _gameOver) {
      setState(() => _engineEvalLabel = null);
      _scheduleMoveQualityAnalysis();
      return;
    }
    final reviewingHistory = !_atLatest;
    if (!reviewingHistory && (_botThinking || !_isPlayerTurn)) return;
    final fen = _fen;
    if (reviewingHistory) {
      setState(() => _engineEvalLabel = null);
    }
    if (_scheduleMoveQualityAnalysis(engineEvalRequestId: requestId)) {
      return;
    }
    if (_isWidgetTest &&
        widget.positionAnalyzer == null &&
        widget.botEngine == null) {
      return;
    }
    unawaited(_analyzePositionEvaluation(fen, requestId));
  }

  bool _scheduleMoveQualityAnalysis({int? engineEvalRequestId}) {
    if (!_canShowVirtualMoveQuality || !_isPlayerTurn || _gameOver) {
      _clearMoveQualityAnalysisCache();
      return false;
    }
    final fen = _fen;
    if (_moveQualityAnalysisFen == fen) {
      if (engineEvalRequestId != null &&
          _showBotEvaluation &&
          _moveQualityAnalysisEvalLabel != null) {
        setState(() => _engineEvalLabel = _moveQualityAnalysisEvalLabel);
      }
      return engineEvalRequestId != null &&
          _moveQualityAnalysisEvalLabel != null;
    }
    if (_moveQualityAnalysisInFlightFen == fen) {
      if (engineEvalRequestId != null) {
        _moveQualityAnalysisEngineEvalRequestId = engineEvalRequestId;
      }
      return engineEvalRequestId != null;
    }
    if (_isWidgetTest &&
        widget.positionAnalyzer == null &&
        widget.botEngine == null) {
      return false;
    }
    final requestId = ++_moveQualityAnalysisRequestId;
    _moveQualityAnalysisEngineEvalRequestId = engineEvalRequestId;
    _moveQualityAnalysisInFlightFen = fen;
    unawaited(_analyzeMoveQualityForTurn(fen, requestId));
    return engineEvalRequestId != null;
  }

  Future<void> _analyzeMoveQualityForTurn(
    String fen,
    int requestId,
  ) async {
    PositionEngineAnalysis? analysis;
    if (widget.positionAnalyzer != null) {
      analysis = await widget.positionAnalyzer!.analyzeFen(
        fen,
        depth: 10,
        multiPv: 256,
      );
    } else {
      analysis = await _botEngine.analyzeFen(
        fen: fen,
        config: _hintBotConfig,
        depth: 10,
        multiPv: 256,
      );
      if (analysis == null &&
          defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS) {
        analysis = await const StockfishPositionAnalyzer()
            .analyzeFen(fen, depth: 10, multiPv: 256);
      }
    }

    if (!mounted) return;
    if (requestId != _moveQualityAnalysisRequestId ||
        fen != _fen ||
        !_canShowVirtualMoveQuality ||
        !_isPlayerTurn ||
        analysis == null) {
      if (_moveQualityAnalysisInFlightFen == fen) {
        _moveQualityAnalysisInFlightFen = null;
        _moveQualityAnalysisEngineEvalRequestId = null;
      }
      return;
    }

    final evalLabel = _formatAnalysisEval(analysis);
    final engineEvalRequestId = _moveQualityAnalysisEngineEvalRequestId;
    final targetsBySource =
        MoveQualityLightsService.classifyLegalTargetsBySource(
      position: loadDartChessPosition(fen),
      candidateMoves: analysis.candidateMoves,
    );
    setState(() {
      _moveQualityAnalysisInFlightFen = null;
      _moveQualityAnalysisEngineEvalRequestId = null;
      _moveQualityAnalysisEvalLabel = evalLabel;
      _moveQualityAnalysisFen = fen;
      _moveQualityTargetsBySource = targetsBySource;
      if (_showBotEvaluation &&
          engineEvalRequestId != null &&
          engineEvalRequestId == _engineEvalRequestId) {
        _engineEvalLabel = evalLabel;
      }
      _legalTargetLightQualities = _cachedMoveQualityForCurrentSelection();
    });
  }

  void _clearMoveQualityAnalysisCache() {
    _moveQualityAnalysisRequestId += 1;
    _moveQualityAnalysisFen = null;
    _moveQualityAnalysisInFlightFen = null;
    _moveQualityAnalysisEvalLabel = null;
    _moveQualityAnalysisEngineEvalRequestId = null;
    _moveQualityTargetsBySource = const {};
  }

  Future<void> _analyzePositionEvaluation(String fen, int requestId) async {
    PositionEngineAnalysis? analysis;
    if (widget.positionAnalyzer != null) {
      analysis = await widget.positionAnalyzer!.analyzeFen(
        fen,
        depth: 10,
        multiPv: 1,
      );
    } else if (_isOtbRecordGame) {
      analysis = await _botEngine.analyzeFen(
        fen: fen,
        config: _hintBotConfig,
        depth: 10,
        multiPv: 1,
      );
      analysis ??= await const StockfishPositionAnalyzer()
          .analyzeFen(fen, depth: 10, multiPv: 1);
    } else {
      analysis = await _botEngine.analyzeFen(
        fen: fen,
        config: widget.botConfig,
        depth: 10,
        multiPv: 1,
      );
      if (analysis == null && !_usesReusableStockfishBotSession) {
        analysis = await const StockfishPositionAnalyzer()
            .analyzeFen(fen, depth: 10, multiPv: 1);
      }
    }
    if (!mounted ||
        !_allowsScoreBar ||
        requestId != _engineEvalRequestId ||
        fen != _fen) {
      return;
    }
    if (analysis == null) return;
    final evalLabel = _formatAnalysisEval(analysis);
    setState(() => _engineEvalLabel = evalLabel);
  }

  bool get _usesReusableStockfishBotSession =>
      widget.botEngine == null &&
      widget.botConfig.engineKind == BotEngineKind.stockfish &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  void _handleBotEngineEvaluation(PositionEngineAnalysis analysis) {
    if (!mounted ||
        !_allowsScoreBar ||
        !_showBotEvaluation ||
        _gameOver ||
        analysis.fen != _fen) {
      return;
    }
    setState(() => _engineEvalLabel = _formatAnalysisEval(analysis));
  }

  String _formatAnalysisEval(PositionEngineAnalysis analysis) {
    final mate = analysis.whiteMate;
    if (mate != null) return mate > 0 ? '#+$mate' : '#$mate';
    return _formatEval(analysis.whiteEval);
  }

  String _formatEval(double value) {
    if (value.abs() >= 99) return value.isNegative ? '#-' : '#+';
    final rounded = value.toStringAsFixed(2);
    return value > 0 ? '+$rounded' : rounded;
  }

  void _startPhysicalBoardStreamIfNeeded() {
    unawaited(_boardFenSub?.cancel());
    unawaited(_boardStateSub?.cancel());
    final gateway = widget.boardGateway;
    if (gateway == null) {
      _boardState = PhysicalBoardConnectionState.disconnected;
      _physicalBoardFen = null;
      _boardFenStabilityBuffer.cancelPending();
      if (_voiceMovesEnabled) unawaited(_stopVoiceMoves());
      return;
    }
    _boardState = gateway.currentState;
    _boardStateSub = gateway.stateStream.listen((state) {
      if (!mounted) return;
      setState(() => _boardState = state);
      if (state != PhysicalBoardConnectionState.connected) {
        _pendingOpponentClockSwitchBoardFen = null;
      }
      if (state != PhysicalBoardConnectionState.connected &&
          _voiceMovesEnabled) {
        unawaited(_stopVoiceMoves());
      }
      if (state == PhysicalBoardConnectionState.connected) {
        if (gateway.boardModel == PhysicalBoardModel.move) {
          unawaited(gateway.enableRealtimeFen());
        }
        _syncMoveBoardOpeningPositionFromLatestFen();
      }
    });
    _boardFenSub = gateway.boardFenStream.listen(_boardFenStabilityBuffer.add);
    if (_boardState == PhysicalBoardConnectionState.connected &&
        gateway.boardModel == PhysicalBoardModel.move) {
      unawaited(gateway.enableRealtimeFen());
    }
  }

  void _applyPhysicalBoardFen(String boardFen) {
    if (!mounted || !_supportsPhysicalBoardMoves) return;
    final normalizedBoardFen = _boardOnlyFen(boardFen);
    if (normalizedBoardFen.isEmpty) return;
    if (_pendingPhysicalMoveBoardFen != null &&
        _pendingPhysicalMoveBoardFen != normalizedBoardFen) {
      _pendingPhysicalMoveTimer?.cancel();
      _pendingPhysicalMoveTimer = null;
      _pendingPhysicalMoveBoardFen = null;
      _clearPendingClockSwitchMove();
    }
    final currentBoardFen = _boardOnlyFen(_fen);
    final recentAppBoardFens = _recentAppBoardFens(
      currentBoardFen: currentBoardFen,
    );
    final streamFenAlreadyNormalized = _streamFenAlreadyNormalized(
      normalizedBoardFen,
      appBoardFens: recentAppBoardFens,
    );
    final resolvedMapping =
        streamFenAlreadyNormalized || !_physicalBoardAutoFlipEnabled
            ? null
            : _mappingForPhysicalBoardFen(
                physicalBoardFen: normalizedBoardFen,
                appBoardFens: [currentBoardFen],
              );
    if (resolvedMapping != null) {
      _applyResolvedBoardFenMapping(resolvedMapping);
    }
    final setupWasReady = _otbPhysicalSetupReady;
    _physicalBoardFen = streamFenAlreadyNormalized
        ? normalizedBoardFen
        : _applyBoardFenMapping(normalizedBoardFen, _boardFenMapping);
    // The first FEN can arrive asynchronously after realtime mode is
    // enabled. Retry the opening sync when that stable FEN is received,
    // rather than relying only on the initial latestBoardFen snapshot.
    if (_canAutoSetMoveBoard &&
        _currentPly == 0 &&
        !_moveBoardOpeningSyncChecked) {
      _syncMoveBoardOpeningPositionFromLatestFen();
    }
    final setupIsReady = _otbPhysicalSetupReady;
    if (!setupWasReady && setupIsReady) {
      // The opening setup gate is one-shot. Once the requested position has
      // been confirmed, later FEN changes are real game moves and must flow
      // through the normal physical-move resolver.
      _otbPhysicalSetupTargetFen = null;
      setState(() {});
    }
    // While an OTB custom position is being arranged, do not interpret any
    // intermediate board state as a playable move.
    if (_otbPhysicalSetupTargetFen != null && !setupIsReady) {
      // Keep the same FEN-difference guidance used by bot openings. This is
      // intentionally board-model agnostic: Move receives RGB LEDs and
      // general boards receive their regular LED command.
      _refreshFenDifferenceLeds();
      if (_canAutoSetMoveBoard && _currentPly == 0) {
        _syncMoveBoardOpeningPositionIfNeeded(normalizedBoardFen);
      }
      return;
    }
    _switchPendingOpponentClockIfBoardMatches();
    if (_physicalBoardFen == currentBoardFen) {
      _cancelMoveBoardRestore();
      _moveBoardOpeningSyncPending = false;
      _lastMoveBoardSetMoveSignature = null;
      _refreshPhysicalLedsForBoardMatch();
      return;
    }
    _refreshFenDifferenceLeds();
    if (_tryApplyPhysicalLiftSelection(normalizedBoardFen)) {
      _cancelMoveBoardRestore();
      return;
    }
    if (!_isPlayerTurn || !_atLatest || _gameOver) {
      _scheduleMoveBoardRestoreToVirtualFen(normalizedBoardFen);
      return;
    }
    if (!_canSubmitPhysicalBoardFenMoves) {
      return;
    }
    final move = _resolvePhysicalBoardFenMove(
      currentFen: _fen,
      physicalBoardFen: normalizedBoardFen,
      mappings: _physicalBoardResolutionMappings,
      onMappingResolved: _applyResolvedBoardFenMapping,
    );
    if (move == null) {
      _scheduleMoveBoardRestoreToVirtualFen(normalizedBoardFen);
      return;
    }
    _physicalBoardFen = _applyBoardFenMapping(
      normalizedBoardFen,
      _boardFenMapping,
    );
    _cancelMoveBoardRestore();
    _schedulePhysicalBoardMove(move, normalizedBoardFen);
  }

  void _refreshPhysicalLedsForBoardMatch() {
    _refreshFenDifferenceLeds();
    if (_opponentMoveLedSquares.isNotEmpty &&
        _physicalBoardFenMatchesVirtualOnSquares(_opponentMoveLedSquares)) {
      _clearOpponentMoveLeds();
    }
    if (_legalTargetsFromPhysicalLift) {
      setState(() {
        _clearLegalTargetGuidance();
        _externalBoardSelectionVersion += 1;
      });
      _refreshLegalMoveLeds();
    }
  }

  Future<void> _setMoveBoardToVirtualFen({
    String? fen,
    bool force = false,
  }) async {
    final gateway = widget.boardGateway;
    if (gateway == null ||
        gateway.boardModel != PhysicalBoardModel.move ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      return;
    }
    final targetFen = fen ?? _fen;
    final targetBoardFen = _boardOnlyFen(targetFen);
    if (!force && _moveBoardPhysicalFenMatches(targetBoardFen)) {
      _cancelMoveBoardRestore();
      return;
    }
    final signature = [
      targetFen,
      _boardFenMapping.name,
    ].join('|');
    if (!force &&
        (_moveBoardSetMoveInFlight ||
            signature == _lastMoveBoardSetMoveSignature)) {
      return;
    }
    _moveBoardSetMoveInFlight = true;
    try {
      final sent = await gateway.setMoveBoardFen(
        targetFen,
        isReverse: _boardFenMapping == _BoardFenMapping.reversed,
      );
      if (sent) {
        _lastMoveBoardSetMoveSignature = signature;
        await gateway.enableRealtimeFen();
      }
    } finally {
      _moveBoardSetMoveInFlight = false;
    }
  }

  void _syncMoveBoardAfterVirtualFenChange() {
    _cancelMoveBoardRestore();
    _lastMoveBoardSetMoveSignature = null;
    unawaited(_setMoveBoardToVirtualFen(force: true));
  }

  Future<void> _flipConnectedMoveBoard() async {
    final gateway = widget.boardGateway;
    if (!_canFlipConnectedMoveBoard ||
        gateway == null ||
        _moveBoardSetMoveInFlight) {
      return;
    }
    final nextMapping = _boardFenMapping == _BoardFenMapping.identity
        ? _BoardFenMapping.reversed
        : _BoardFenMapping.identity;
    _cancelMoveBoardRestore();
    _lastMoveBoardSetMoveSignature = null;
    _moveBoardSetMoveInFlight = true;
    try {
      await gateway.clearMoveLeds();
      final sent = await gateway.setMoveBoardFen(
        _fen,
        isReverse: nextMapping == _BoardFenMapping.reversed,
      );
      if (!mounted) return;
      if (!sent) {
        _showMessage('Move board could not be flipped.');
        return;
      }
      setState(() {
        _boardFenMapping = nextMapping;
        _physicalBoardOrientationResolved = true;
        _physicalBoardFen = _boardOnlyFen(_fen);
        _lastPhysicalLedSignature = null;
      });
      _lastMoveBoardSetMoveSignature = [
        _fen,
        nextMapping.name,
      ].join('|');
      await gateway.enableRealtimeFen();
      if (!mounted) return;
      _refreshPhysicalLedsForBoardMatch();
      _showMessage('Move board flipped.');
    } finally {
      _moveBoardSetMoveInFlight = false;
    }
  }

  Future<void> _confirmAndFlipConnectedMoveBoard() async {
    if (!_canFlipConnectedMoveBoard) return;
    final confirmed = await confirmMoveBoardPieceMovement(context);
    if (!confirmed || !mounted) return;
    await _flipConnectedMoveBoard();
  }

  void _cancelMoveBoardRestore() {
    _moveBoardRestoreTimer?.cancel();
    _moveBoardRestoreTimer = null;
    _pendingMoveBoardRestoreFen = null;
  }

  void _scheduleMoveBoardRestoreToVirtualFen(String physicalBoardFen) {
    if (!_canAutoSetMoveBoard || _gameOver || !_atLatest) return;
    if (_isMoveBoardThinkingLiftFen(physicalBoardFen)) {
      _cancelMoveBoardRestore();
      return;
    }
    final targetFen = _fen;
    if (_pendingMoveBoardRestoreFen == targetFen &&
        _moveBoardRestoreTimer != null) {
      return;
    }
    _moveBoardRestoreTimer?.cancel();
    _pendingMoveBoardRestoreFen = targetFen;
    final delay =
        widget.boardSettings.fenDelay + widget.boardSettings.moveRestoreDelay;
    _moveBoardRestoreTimer = Timer(delay, () {
      if (!mounted ||
          _gameOver ||
          !_atLatest ||
          _pendingMoveBoardRestoreFen != targetFen) {
        return;
      }
      _moveBoardRestoreTimer = null;
      _pendingMoveBoardRestoreFen = null;
      unawaited(_setMoveBoardToVirtualFen(fen: targetFen));
    });
  }

  bool _isMoveBoardThinkingLiftFen(String physicalBoardFen) {
    if (!_isPlayerTurn || !_atLatest || _gameOver) return false;
    final position = loadDartChessPosition(_fen);
    final mapped = _applyBoardFenMapping(physicalBoardFen, _boardFenMapping);
    final liftedSquare = _selectedSquareLiftedFromPhysicalFen(
      position: position,
      mappedPhysicalBoardFen: mapped,
    );
    if (liftedSquare == null) return false;
    return dc.makeLegalMoves(position)[liftedSquare]?.isNotEmpty ?? false;
  }

  bool _moveBoardPhysicalFenMatches(String targetBoardFen) {
    final physicalFen = _physicalBoardFen;
    if (physicalFen != null && _boardOnlyFen(physicalFen) == targetBoardFen) {
      return true;
    }
    final rawFen = widget.boardGateway?.latestBoardFen;
    if (rawFen == null || rawFen.trim().isEmpty) return false;
    final rawBoardFen = _boardOnlyFen(rawFen);
    if (rawBoardFen == targetBoardFen) return true;
    return _applyBoardFenMapping(rawBoardFen, _boardFenMapping) ==
        targetBoardFen;
  }

  void _syncMoveBoardOpeningPositionIfNeeded(String physicalBoardFen) {
    if (!_canAutoSetMoveBoard || _moveBoardOpeningSyncPending) return;
    final targetBoardFen = _boardOnlyFen(_fen);
    final mapping = _physicalBoardAutoFlipEnabled
        ? _mappingForPhysicalBoardFen(
            physicalBoardFen: physicalBoardFen,
            appBoardFens: [targetBoardFen],
          )
        : null;
    if (mapping != null &&
        _applyBoardFenMapping(physicalBoardFen, mapping) == targetBoardFen) {
      _applyResolvedBoardFenMapping(mapping);
      return;
    }
    if (_applyBoardFenMapping(physicalBoardFen, _boardFenMapping) ==
        targetBoardFen) {
      return;
    }
    _moveBoardOpeningSyncPending = true;
    unawaited(_setMoveBoardToVirtualFen(force: true));
  }

  void _syncMoveBoardOpeningPositionFromLatestFen() {
    if (!_canAutoSetMoveBoard ||
        _moveBoardOpeningSyncChecked ||
        _moveBoardOpeningSyncPending ||
        _currentPly != 0) {
      return;
    }
    final latestFen = widget.boardGateway?.latestBoardFen;
    if (latestFen == null || latestFen.trim().isEmpty) return;
    _moveBoardOpeningSyncChecked = true;
    final latestBoardFen = _boardOnlyFen(latestFen);
    final targetBoardFen = _otbPhysicalSetupTargetFen;
    if (targetBoardFen != null &&
        _applyBoardFenMapping(latestBoardFen, _boardFenMapping) ==
            targetBoardFen) {
      // The gateway may already have the correct stable position before this
      // screen subscribes to its FEN stream. Treat it as ready immediately.
      _physicalBoardFen = targetBoardFen;
      _otbPhysicalSetupTargetFen = null;
      if (mounted) setState(() {});
      _refreshFenDifferenceLeds();
      return;
    }
    _syncMoveBoardOpeningPositionIfNeeded(latestBoardFen);
  }

  bool _tryApplyPhysicalLiftSelection(String normalizedBoardFen) {
    if (!_isPlayerTurn || !_atLatest || _gameOver) return false;
    final position = loadDartChessPosition(_fen);
    final selection = _physicalLiftLegalTargetSelection(
      position: position,
      physicalBoardFen: normalizedBoardFen,
      mappings: _physicalBoardResolutionMappings,
    );
    if (selection == null) {
      if (_legalTargetsFromPhysicalLift) {
        setState(() {
          _clearLegalTargetGuidance();
          _externalBoardSelectionVersion += 1;
        });
        _refreshLegalMoveLeds();
      }
      return false;
    }
    setState(() {
      _applyResolvedBoardFenMapping(selection.mapping);
      _physicalBoardFen =
          _applyBoardFenMapping(normalizedBoardFen, _boardFenMapping);
      _legalTargetSourceSquare = selection.sourceSquare;
      _legalTargetSquares = selection.targetSquares;
      _legalTargetLightQualities = const {};
      _legalTargetsFromPhysicalLift = true;
      _externalBoardSelectionVersion += 1;
    });
    _refreshLegalMoveLeds();
    if (_canShowVirtualMoveQuality) {
      _applyMoveQualityForSelection(
        _LegalTargetSelection(
          sourceSquare: selection.sourceSquare,
          targetSquares: selection.targetSquares,
        ),
      );
    }
    return true;
  }

  bool _streamFenAlreadyNormalized(
    String boardFen, {
    required List<String> appBoardFens,
  }) {
    return _physicalBoardOrientationResolved &&
        _boardFenMapping != _BoardFenMapping.identity &&
        appBoardFens.contains(_boardOnlyFen(boardFen));
  }

  List<String> _recentAppBoardFens({String? currentBoardFen}) {
    final fens = <String>[];
    void addFen(String fen) {
      final boardFen = _boardOnlyFen(fen);
      if (boardFen.isEmpty || fens.contains(boardFen)) return;
      fens.add(boardFen);
    }

    if (currentBoardFen != null) addFen(currentBoardFen);
    addFen(_fen);
    for (final snapshot in _snapshots.reversed) {
      addFen(snapshot.fen);
    }
    return fens;
  }

  void _schedulePhysicalBoardMove(
    ChessBoardMove move,
    String normalizedBoardFen,
  ) {
    final expectedFen = _applyBoardFenMapping(
      normalizedBoardFen,
      _boardFenMapping,
    );
    final shouldConfirmWithClockSwitch =
        widget.boardSettings.submitMoveOnClockSwitch;
    final delay = shouldConfirmWithClockSwitch
        ? Duration.zero
        : widget.boardSettings.fenDelay;
    if (delay <= Duration.zero) {
      _pendingPhysicalMoveTimer?.cancel();
      _pendingPhysicalMoveTimer = null;
      _pendingPhysicalMoveBoardFen = null;
      _registerOrQueuePhysicalBoardMove(move, expectedFen);
      return;
    }
    if (_pendingPhysicalMoveBoardFen == normalizedBoardFen &&
        _pendingPhysicalMoveTimer != null) {
      return;
    }
    _pendingPhysicalMoveTimer?.cancel();
    _pendingPhysicalMoveBoardFen = normalizedBoardFen;
    _pendingPhysicalMoveTimer = Timer(delay, () {
      if (!mounted ||
          _gameOver ||
          !_atLatest ||
          !_isPlayerTurn ||
          _physicalBoardFen != expectedFen) {
        return;
      }
      _pendingPhysicalMoveTimer = null;
      _pendingPhysicalMoveBoardFen = null;
      _registerOrQueuePhysicalBoardMove(move, expectedFen);
    });
  }

  void _registerOrQueuePhysicalBoardMove(
    ChessBoardMove move,
    String expectedFen,
  ) {
    if (!widget.boardSettings.submitMoveOnClockSwitch) {
      _clearPendingClockSwitchMove();
      _onPlayerMove(move, confirmedPhysicalBoardFen: expectedFen);
      return;
    }
    _pendingClockSwitchMove = move;
    _pendingClockSwitchExpectedFen = expectedFen;
  }

  void _clearPendingClockSwitchMove() {
    _pendingClockSwitchMove = null;
    _pendingClockSwitchExpectedFen = null;
  }

  void _applyResolvedBoardFenMapping(_BoardFenMapping mapping) {
    if (mapping == _BoardFenMapping.reversed && !_boardFlipAllowed) return;
    final changed = _boardFenMapping != mapping;
    _boardFenMapping = mapping;
    if (!changed && _physicalBoardOrientationResolved) return;
    _physicalBoardOrientationResolved = true;
  }

  void _startLatencyProbeIfNeeded() {
    _latencyTimer?.cancel();
    _latency = null;
    final target = switch (widget.mode) {
      GameLaunchMode.lichess => NetworkLatencyTarget.lichess,
      GameLaunchMode.chesscom => NetworkLatencyTarget.chesscom,
      _ => null,
    };
    if (target == null) return;
    Future<void> ping() async {
      final probe = widget.latencyProbe ??
          HttpNetworkLatencyProbe(
            httpClient: widget.apiClient?.httpClient ?? http.Client(),
          );
      final snapshot = await probe.ping(target);
      if (!mounted || _gameOver) return;
      setState(() => _latency = snapshot);
    }

    unawaited(ping());
    if (!_isWidgetTest) {
      _latencyTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => unawaited(ping()),
      );
    }
  }

  void _applyMoveQualityForSelection(
    _LegalTargetSelection selection,
  ) {
    if (!_canShowVirtualMoveQuality || selection.targetSquares.isEmpty) {
      return;
    }
    _scheduleMoveQualityAnalysis();
    final qualities = _cachedMoveQualityForSelection(selection);
    if (mapEquals(_legalTargetLightQualities, qualities)) return;
    setState(() => _legalTargetLightQualities = qualities);
  }

  Map<String, MoveQualityLight> _cachedMoveQualityForCurrentSelection() {
    final sourceSquare = _legalTargetSourceSquare;
    if (sourceSquare == null || _legalTargetSquares.isEmpty) {
      return const {};
    }
    return _cachedMoveQualityForSelection(
      _LegalTargetSelection(
        sourceSquare: sourceSquare,
        targetSquares: _legalTargetSquares,
      ),
    );
  }

  Map<String, MoveQualityLight> _cachedMoveQualityForSelection(
    _LegalTargetSelection selection,
  ) {
    if (_moveQualityAnalysisFen != _fen) return const {};
    final qualities = _moveQualityTargetsBySource[selection.sourceSquare];
    if (qualities == null || qualities.isEmpty) return const {};
    return Map.unmodifiable({
      for (final target in selection.targetSquares)
        if (qualities[target] case final quality?) target: quality,
    });
  }

  void _applyIncrement(dc.Side movedColor) {
    final increment = _incrementSeconds;
    if (_timeMinutes <= 0 || increment <= 0 || !_clockOfficiallyStarted) {
      return;
    }
    if (movedColor == dc.Side.white) {
      _whiteSeconds += increment;
    } else {
      _blackSeconds += increment;
    }
  }

  void _playSound(AppSoundEvent event) {
    if (!widget.soundEffectsEnabled) return;
    if (!widget.soundEffects.allows(event)) return;
    unawaited(widget.appSoundService.play(event));
  }

  void _playMoveSound(ChessBoardMove move) {
    if (!widget.soundEffectsEnabled) return;
    final sound = AppMoveSound(
      from: move.from,
      to: move.to,
      san: move.san,
      inCheck: move.state.inCheck,
      inCheckmate: move.state.inCheckmate,
      inStalemate: move.state.inStalemate,
    );
    unawaited(_playOpponentMoveAudio(sound));
  }

  Future<void> _playOpponentMoveAudio(AppMoveSound sound) async {
    await widget.appSoundService.playMoveAudio(
      sound,
      announceSquares: widget.soundEffects.fromTo,
      playEffect: widget.soundEffects.allows(sound.fallbackEvent),
    );
  }

  void _handleMoveBeep(ChessBoardState state) {
    if (!_startGameBeepPlayed && _gameOfficiallyStarted) {
      _startGameBeepPlayed = true;
    }
    if (state.inCheck && widget.boardSettings.effectiveCheckmateBeep) {
      unawaited(widget.boardGateway?.playBeep());
    }
  }

  void _switchClockIfNeeded({required bool forOpponentMove}) {
    if (_isOtbRecordGame) {
      if (widget.boardSettings.submitMoveOnClockSwitch ||
          !_shouldAutoSwitchClock) {
        return;
      }
      unawaited(_switchClockToOppositeIgnoringEcho());
      return;
    }
    final mode = widget.boardSettings.clockSwitchAutomation;
    final shouldSwitch = switch (mode) {
      ClockSwitchAutomationMode.off => false,
      ClockSwitchAutomationMode.opponentMoveOnly => forOpponentMove,
      ClockSwitchAutomationMode.bothSides => true,
    };
    if (!shouldSwitch) return;
    if (forOpponentMove &&
        _hasConnectedPhysicalBoard &&
        widget.boardSettings.clockSwitchOpponentTiming ==
            ClockSwitchOpponentTiming.leisure) {
      _pendingOpponentClockSwitchBoardFen = _boardOnlyFen(_fen);
      _switchPendingOpponentClockIfBoardMatches();
      return;
    }
    if (forOpponentMove) {
      _pendingOpponentClockSwitchBoardFen = null;
    }
    unawaited(_switchClockToOppositeIgnoringEcho());
  }

  void _switchPendingOpponentClockIfBoardMatches() {
    final expectedFen = _pendingOpponentClockSwitchBoardFen;
    final boardFen = _physicalBoardFen;
    if (!mounted || expectedFen == null || boardFen == null) return;
    if (_boardOnlyFen(boardFen) != expectedFen) return;
    _pendingOpponentClockSwitchBoardFen = null;
    unawaited(_switchClockToOppositeIgnoringEcho());
  }

  void _handleClockSwitchEvent(int sideValue) {
    if (_gameOver || !mounted) return;
    final pressedSide = ChessClockSide.fromValue(sideValue);
    final pendingMove = _pendingClockSwitchMove;
    final expectedFen = _pendingClockSwitchExpectedFen;
    if (pendingMove != null && expectedFen != null) {
      if (!_atLatest || !_isPlayerTurn || _physicalBoardFen != expectedFen) {
        if (widget.boardSettings.submitMoveOnClockSwitch) {
          _syncMoveBoardAfterVirtualFenChange();
        }
        _reboundClockSwitch(pressedSide);
        return;
      }
      _clearPendingClockSwitchMove();
      _pendingPhysicalMoveTimer?.cancel();
      _pendingPhysicalMoveTimer = null;
      _pendingPhysicalMoveBoardFen = null;
      _onPlayerMove(
        pendingMove,
        confirmedPhysicalBoardFen: expectedFen,
        confirmedByClockSwitch: true,
      );
      return;
    }
    if (widget.boardSettings.submitMoveOnClockSwitch &&
        !_moveBoardPhysicalFenMatches(_boardOnlyFen(_fen))) {
      _syncMoveBoardAfterVirtualFenChange();
    }
    _reboundClockSwitch(pressedSide);
  }

  void _reboundClockSwitch(ChessClockSide? pressedSide) {
    if (!widget.boardSettings.submitMoveOnClockSwitch || pressedSide == null) {
      return;
    }
    unawaited(_reboundClockSwitchAfterDelay(pressedSide));
  }

  Future<void> _reboundClockSwitchAfterDelay(ChessClockSide pressedSide) async {
    await Future<void>.delayed(_clockSwitchReboundDelay);
    if (!mounted || _gameOver) return;
    await _switchClockToIgnoringEcho(pressedSide.opposite);
  }

  Future<void> _switchClockToOppositeIgnoringEcho() async {
    await _clockSwitchService.switchToOpposite();
  }

  Future<void> _switchClockToIgnoringEcho(ChessClockSide side) async {
    await _clockSwitchService.switchTo(side);
  }

  void _updateGameOver(ChessBoardState state) {
    // Lichess 游戏的结局由服务器判定，不在本地判断
    if (_isLichessGame) return;

    final drawByThreefold = _isThreefoldRepetitionDraw();
    if (!state.gameOver && !drawByThreefold) return;
    _gameOver = true;
    _clockTimer?.cancel();
    if (state.inCheckmate) {
      _resultText = state.whiteToMove
          ? 'Black wins by checkmate'
          : 'White wins by checkmate';
    } else if (state.inStalemate) {
      _resultText = 'Draw by stalemate';
    } else if (drawByThreefold) {
      _resultText = 'Draw by threefold repetition';
    } else {
      _resultText = 'Game drawn';
    }
    _finalResultText = _resultText;
  }

  void _showGameOverDialog() {
    if (!mounted || _resultText.isEmpty) return;
    final result = _gameOverResult();
    final careerRatingDelta = _careerRatingDeltaFor(result);
    final viewport = MediaQuery.sizeOf(context);
    final androidPhoneDevice = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !widget.isChessnutClockDevice &&
        viewport.longestSide < 1000 &&
        viewport.shortestSide < 600;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => _GameOverResultDialog(
        result: result,
        resultText: _resultText,
        careerRatingDelta: careerRatingDelta,
        onPlayAgain: () {
          Navigator.of(dialogContext).pop();
          unawaited(_playAgain());
        },
        onAnalyze: () async {
          Navigator.of(dialogContext).pop();
          if (!await _saveGameRecordIfNeeded(force: true, showFailure: true) ||
              !mounted) {
            return;
          }
          final pgn = _currentPgn();
          final onAnalyzePgn = widget.onAnalyzePgn;
          if (onAnalyzePgn != null) {
            onAnalyzePgn(pgn);
          } else {
            widget.onNavigate('Analysis');
          }
        },
        onBotSettings: () async {
          Navigator.of(dialogContext).pop();
          if (!await _saveGameRecordIfNeeded(force: true, showFailure: true) ||
              !mounted) {
            return;
          }
          if (widget.botConfig.careerMode != null || _isLichessGame) {
            widget.onPostGameBotSettings?.call();
          }
          widget.onNavigate(_isOtbRecordGame ? 'Back' : 'Bot');
        },
        settingsLabel:
            _isOtbRecordGame ? 'OTB game settings' : 'Bot game settings',
        androidPhoneDevice: androidPhoneDevice,
        onMainMenu: () async {
          Navigator.of(dialogContext).pop();
          if (!await _saveGameRecordIfNeeded(force: true, showFailure: true) ||
              !mounted) {
            return;
          }
          _stopMoveBoardOnExit();
          widget.onNavigate('Home');
        },
      ),
    );
  }

  Future<void> _playAgain() async {
    if (!await _saveGameRecordIfNeeded(force: true, showFailure: true) ||
        !mounted) {
      return;
    }
    if (_isLichessGame) {
      widget.onNavigate('Online');
      return;
    }
    if (widget.botConfig.careerMode != null) {
      await _saveGameRecordIfNeeded(force: true, showFailure: true);
      if (!mounted) return;
      final onCareerRematch = widget.onCareerRematch;
      if (onCareerRematch != null) {
        onCareerRematch();
      } else {
        widget.onNavigate('Career');
      }
      return;
    }
    if (_isBotGame) {
      await _saveGameRecordIfNeeded(force: true, showFailure: true);
      if (!mounted) return;
      _resetGame(freshBotRematch: true);
      return;
    }
    _resetGame(freshOtbRematch: true);
  }

  _GameOverResult _gameOverResult() {
    final token = _resultToken();
    if (token == '1/2-1/2') return _GameOverResult.draw;
    if (token == '1-0') {
      return _playerIsWhite ? _GameOverResult.victory : _GameOverResult.defeat;
    }
    if (token == '0-1') {
      return _playerIsWhite ? _GameOverResult.defeat : _GameOverResult.victory;
    }
    return _GameOverResult.draw;
  }

  CareerRatingDelta? _careerRatingDeltaFor(_GameOverResult result) {
    final career = widget.botConfig.careerMode;
    if (career == null || widget.mode != GameLaunchMode.bot) return null;
    final newElo = switch (result) {
      _GameOverResult.victory => career.winElo,
      _GameOverResult.defeat => career.loseElo,
      _GameOverResult.draw => career.startElo,
    };
    return CareerRatingDelta(before: career.startElo, after: newElo);
  }

  Future<void> _returnFromGameRoom() async {
    if (!await _saveGameRecordIfNeeded(
            force: true, showFailure: true, allowPreOfficialBotDraft: true) ||
        !mounted) {
      return;
    }
    _stopMoveBoardOnExit();
    widget.onNavigate(_gameConcluded ? 'Home' : 'Back');
  }

  void _stopMoveBoardOnExit() {
    _moveBoardRestoreTimer?.cancel();
    _moveBoardRestoreTimer = null;
    _pendingMoveBoardRestoreFen = null;
    _moveBoardSetMoveInFlight = false;
    _lastMoveBoardSetMoveSignature = null;
    final gateway = widget.boardGateway;
    if (gateway == null ||
        gateway.boardModel != PhysicalBoardModel.move ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      return;
    }
    unawaited(gateway.clearMoveLeds());
    unawaited(gateway.stopMoveBoard());
  }

  void _saveLocalLichessContinueRecord() {
    if (!_isLichessGame ||
        _gameOver ||
        widget.lichessConfig.gameId.trim().isEmpty) {
      return;
    }
    final callback = widget.onLichessTemporaryContinueRecord;
    if (callback == null) return;
    final copy = _copyForCurrentGame();
    final localName = _localPlayerName();
    final whiteName = _playerIsWhite ? localName : copy.opponent;
    final blackName = _playerIsWhite ? copy.opponent : localName;
    callback(GameRecord(
      result: '*',
      title: '$whiteName vs $blackName',
      subtitle: 'Lichess / ${_sanMoves.length} moves',
      pgn: _currentPgn(),
      playMode: 'lichess',
      gameStatus: 1,
      gameStep: _sanMoves.length,
      winId: 0,
      whiteName: whiteName,
      blackName: blackName,
      lichessGameIdOverride: widget.lichessConfig.gameId,
      lichessTokenOverride: widget.lichessConfig.token,
      lichessNameOverride: widget.lichessConfig.lichessName,
    ));
  }

  void _saveLocalBotContinueRecord() {
    if (!_isBotGame || _gameOver || _sanMoves.isEmpty) return;
    final callback = widget.onBotTemporaryContinueRecord;
    if (callback == null) return;
    final copy = _copyForCurrentGame();
    final localName = _localPlayerName();
    final whiteName = _playerIsWhite ? localName : copy.opponent;
    final blackName = _playerIsWhite ? copy.opponent : localName;
    callback(GameRecord(
      result: '*',
      title: '$whiteName vs $blackName',
      subtitle: 'Bot / ${_sanMoves.length} moves',
      pgn: _currentPgn(),
      pgnId: _recordPgnId,
      shareId: _recordShareId,
      playMode: 'bot',
      gameStatus: 1,
      gameStep: _sanMoves.length,
      winId: 0,
      whiteName: whiteName,
      blackName: blackName,
      sortAt: DateTime.now(),
      chessnutGameIdOverride: _recordGameId,
    ));
  }

  void _showExitConfirm(BuildContext context) {
    if (_gameConcluded || !_gameNeedsExitConfirm) {
      _returnFromGameRoom();
      return;
    }
    final isOnlineLichess = _isLichessGame && !_gameOver;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => AppDialogShell(
        icon: Icons.logout_rounded,
        title: 'Game still in progress',
        subtitle: isOnlineLichess
            ? 'Leave for now. The online clock may keep running, and only the completed final game will be saved to Game Records.'
            : 'Leave for now and continue later from Game Record, or resign to end the game as a loss.',
        actions: [
          Expanded(
            child: _ExitConfirmActions(
              onContinue: () => Navigator.of(dialogContext).pop(),
              onLeave: () async {
                Navigator.of(dialogContext).pop();
                _alignClockToNow();
                _saveLocalLichessContinueRecord();
                _saveLocalBotContinueRecord();
                final saved = await _saveGameRecordIfNeeded(
                  force: true,
                  showFailure: true,
                  allowPreOfficialBotDraft: true,
                );
                if (!saved || !mounted) return;
                _stopMoveBoardOnExit();
                widget.onNavigate('Home');
              },
              onResignAndExit: () {
                Navigator.of(dialogContext).pop();
                _showResignExitConfirm();
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showResignExitConfirm() async {
    if (!mounted || _gameConcluded || _resignInFlight) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AppDialogShell(
          icon: Icons.flag_rounded,
          title: 'Confirm resignation?',
          subtitle:
              'This will end the game immediately and record it as a loss. You cannot continue this game after resigning.',
          actions: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Cancel',
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                ),
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _resignCurrentGame();
                },
                child: const Text(
                  'Confirm resign',
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showClockOtbResignConfirm(dc.Side side) async {
    if (!mounted || _gameConcluded || _resignInFlight) return;
    final sideLabel = side == dc.Side.white ? 'White' : 'Black';
    final winnerLabel = side == dc.Side.white ? 'Black' : 'White';
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AppDialogShell(
          icon: Icons.flag_rounded,
          title: 'Confirm $sideLabel resignation?',
          subtitle:
              '$sideLabel will resign and $winnerLabel will win this OTB game.',
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
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _resignClockOtbSide(side);
                },
                child: Text('Resign $sideLabel'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _resignClockOtbSide(dc.Side side) {
    if (_gameConcluded || _resignInFlight) return;
    _resignInFlight = true;
    setState(() {
      _gameOver = true;
      _resultText = side == dc.Side.white
          ? 'Black wins by resignation'
          : 'White wins by resignation';
      _finalResultText = _resultText;
      _hintMove = null;
    });
    _clearOpponentMoveLeds();
    _refreshHintLeds();
    _refreshLegalMoveLeds();
    _clockTimer?.cancel();
    _handleGameOverSideEffects();
    unawaited(_saveGameRecordIfNeeded(force: true, showFailure: true));
  }

  void _showMore(BuildContext context) {
    if (_gameConcluded) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialogShell(
          icon: Icons.more_horiz_rounded,
          title: 'Game options',
          subtitle: 'Share, export, or request actions.',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_allowsScoreBar)
                _SheetSwitch(
                  icon: Icons.stacked_line_chart_rounded,
                  label: 'Show scorebar',
                  subtitle: _isOtbRecordGame
                      ? 'Display the live Stockfish scorebar during OTB games.'
                      : 'Display the live Stockfish scorebar during bot games.',
                  value: _showBotEvaluation,
                  onChanged: (value) {
                    final nextSettings = widget.boardSettings.copyWith(
                      showScorebar: value,
                      showLegalMoves: _showLegalTargets,
                    );
                    widget.onBoardSettingsChanged?.call(nextSettings);
                    setState(() => _showBotEvaluation = value);
                    _schedulePositionEvaluation();
                    setDialogState(() {});
                  },
                ),
              if (_allowsLegalTargetDisplay)
                _SheetSwitch(
                  icon: Icons.ads_click_rounded,
                  label: 'Show legal moves',
                  subtitle: 'Highlight allowed target squares',
                  value: _showLegalTargets,
                  onChanged: (value) {
                    final nextSettings = widget.boardSettings.copyWith(
                      showScorebar: _showBotEvaluation,
                      showLegalMoves: value,
                    );
                    widget.onBoardSettingsChanged?.call(nextSettings);
                    setState(() {
                      _showLegalTargets = value;
                      if (!value) {
                        _legalTargetSquares = const {};
                        _legalTargetLightQualities = const {};
                        _legalTargetSourceSquare = null;
                      }
                    });
                    setDialogState(() {});
                  },
                ),
              if (_allowsMoveQualityLights)
                _SheetSwitch(
                  icon: Icons.palette_rounded,
                  label: 'Move quality lights',
                  subtitle: 'Use color LEDs when a piece is lifted',
                  value: _moveQualityLightsEnabled,
                  onChanged: (value) {
                    final nextSettings = widget.boardSettings.copyWith(
                      evaluateLed: value,
                      showScorebar: _showBotEvaluation,
                      showLegalMoves: _showLegalTargets,
                    );
                    widget.onBoardSettingsChanged?.call(nextSettings);
                    setState(() {
                      _moveQualityLightsOverride = value;
                      if (!value) {
                        _legalTargetLightQualities = const {};
                        _clearMoveQualityAnalysisCache();
                      }
                    });
                    if (value) {
                      _scheduleMoveQualityAnalysis();
                    }
                    setDialogState(() {});
                  },
                ),
              if (_canFlipConnectedMoveBoard)
                _SheetAction(
                  icon: Icons.screen_rotation_alt_rounded,
                  label: 'Flip board',
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    unawaited(_confirmAndFlipConnectedMoveBoard());
                  },
                ),
              if (_isBotGame || _gameOfficiallyStarted)
                _SheetAction(
                  icon: Icons.ios_share_rounded,
                  label: 'Share live URL',
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    if (_isBotGame || _isOtbRecordGame) {
                      unawaited(_shareLiveUrl());
                    } else {
                      widget.onGameShared?.call(_currentSpectatorSnapshot());
                      widget.onNavigate('Spectator');
                    }
                  },
                ),
              _SheetAction(
                  icon: Icons.content_copy_rounded,
                  label: 'Copy PGN',
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _copyText(_currentPgn(), 'PGN copied');
                  }),
              _SheetAction(
                  icon: Icons.copy_all_rounded,
                  label: 'Copy FEN',
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _copyText(_fen, 'FEN copied');
                  }),
              _SheetAction(
                icon: Icons.undo_rounded,
                label: 'Request takeback',
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  if (_isOtbRecordGame) {
                    _showOtbTakebackConfirm();
                  } else {
                    _requestLichessTakeback();
                  }
                },
              ),
              _SheetAction(
                icon: Icons.handshake_rounded,
                label: 'Offer draw',
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  if (_isOtbRecordGame) {
                    _showOtbDrawConfirm();
                  } else {
                    _offerLichessDraw();
                  }
                },
              ),
              _SheetAction(
                icon: Icons.flag_rounded,
                label: 'Resign',
                danger: true,
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _resignCurrentGame();
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClockOtbSettings(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => AppDialogShell(
        icon: Icons.settings_rounded,
        title: 'Settings',
        subtitle: 'Copy or share this OTB game.',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetAction(
              icon: Icons.content_copy_rounded,
              label: 'Copy PGN',
              onTap: () {
                Navigator.of(dialogContext).pop();
                unawaited(_copyText(_currentPgn(), 'PGN copied'));
              },
            ),
            _SheetAction(
              icon: Icons.link_rounded,
              label: 'Copy URL',
              onTap: () {
                Navigator.of(dialogContext).pop();
                unawaited(_shareLiveUrl());
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHint() {
    if (!_canShowHint()) return;
    if (_hintMove != null) {
      setState(() => _hintMove = null);
      _refreshHintLeds();
      return;
    }
    unawaited(_showEngineHint());
  }

  void _showClockOtbHint(dc.Side side) {
    if (!_canShowHint(otbSide: side)) {
      final sideLabel = side == dc.Side.white ? 'White' : 'Black';
      if (_liveGame.turn != side) {
        _showMessage('It is not $sideLabel\'s turn.');
      }
      return;
    }
    if (_hintMove != null) {
      setState(() => _hintMove = null);
      _refreshHintLeds();
      return;
    }
    unawaited(_showEngineHint(otbSide: side));
  }

  bool _canShowHint({dc.Side? otbSide}) {
    if (!_allowsHintAssistance || _gameOver || !_atLatest) return false;
    if (otbSide != null) {
      return _isOtbRecordGame && _liveGame.turn == otbSide;
    }
    return _isPlayerTurn;
  }

  Future<void> _showEngineHint({dc.Side? otbSide}) async {
    if (!_canShowHint(otbSide: otbSide)) return;
    final hint = await _botEngine.bestMove(
      fen: _fen,
      config: _hintBotConfig,
      moveHistory: _uciHistory(),
    );
    if (!mounted) return;
    if (hint == null) {
      _showMessage('No legal engine hint in this position.');
      return;
    }
    final state = ChessBoardState.fromFen(
      hint.fen,
      lastMove: [hint.move.from.name, hint.move.to.name],
    );
    final hintMove = ChessBoardMove(
      from: hint.move.from.name,
      to: hint.move.to.name,
      promotion: hint.move.promotion?.letter,
      san: hint.san,
      fen: hint.fen,
      state: state,
    );
    setState(() => _hintMove = hintMove);
    _refreshHintLeds();
    _playSound(AppSoundEvent.hint);
  }

  List<String> _uciHistory() {
    try {
      final parsed = GameNotationService.parsePgn(_currentPgn());
      return parsed.moves.map((move) => move.uci).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  void _goPrevious() {
    if (_currentPly <= 0) return;
    _goToPly(_currentPly - 1);
  }

  void _goNext() {
    if (_currentPly >= _snapshots.length - 1) return;
    _goToPly(_currentPly + 1);
  }

  void _goToPly(int ply) {
    if (ply < 0 || ply >= _snapshots.length) return;
    setState(() {
      _currentPly = ply;
      final snapshot = _snapshots[ply];
      _fen = snapshot.fen;
      _lastMove = snapshot.lastMove;
      _hintMove = null;
      _legalTargetSquares = const {};
      _legalTargetLightQualities = const {};
      _legalTargetSourceSquare = null;
      _clearMoveQualityAnalysisCache();
    });
    _clearOpponentMoveLeds();
    _refreshPhysicalLedStates();
    _schedulePositionEvaluation();
  }

  void _trimFutureIfNeeded() {
    if (_atLatest) return;
    _snapshots.removeRange(_currentPly + 1, _snapshots.length);
    _sanMoves.removeRange(_currentPly, _sanMoves.length);
  }

  void _restoreLatestGameState() {
    final state = ChessBoardState.fromFen(_fen, lastMove: _lastMove);
    final drawByThreefold = _isThreefoldRepetitionDraw();
    if (state.gameOver || drawByThreefold) {
      _gameOver = true;
      if (state.inCheckmate) {
        _resultText = state.whiteToMove
            ? 'Black wins by checkmate'
            : 'White wins by checkmate';
      } else if (state.inStalemate) {
        _resultText = 'Draw by stalemate';
      } else if (drawByThreefold) {
        _resultText = 'Draw by threefold repetition';
      } else {
        _resultText = 'Game drawn';
      }
      _finalResultText = _resultText;
    } else if (_finalResultText.isNotEmpty) {
      _gameOver = true;
      _resultText = _finalResultText;
    } else {
      _gameOver = false;
      _resultText = '';
    }
  }

  String _formatClock(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }

  String _turnLabel(dc.Position game) {
    if (_gameOver) return 'Game over';
    if (_botThinking) return '${widget.botConfig.opponent} thinking';
    return game.turn == dc.Side.white ? 'White to move' : 'Black to move';
  }

  String _evalLabel(_GameRoomCopy copy) {
    if (_resultText.isNotEmpty) return '--';
    if (_isBotGame) return _engineEvalLabel ?? '--';
    return _engineEvalLabel ?? copy.eval;
  }

  String _playerSource(dc.Position game) {
    if (_gameOver) return _resultText;
    final playerTurn =
        game.turn == (_playerIsWhite ? dc.Side.white : dc.Side.black);
    if (playerTurn && !_botThinking) return 'Your turn / legal moves only';
    return _isBotGame ? 'Waiting for bot move' : _turnLabel(game);
  }

  void _startLichessStreamIfNeeded() {
    if (!_isLichessGame || !widget.lichessConfig.isReady) return;
    if (_lichessSub != null) return;
    _lichessReconnectTimer?.cancel();
    _lichessReconnectTimer = null;
    final service = _lichessService ??= LichessBoardService(
      token: widget.lichessConfig.token,
      localLichessName: widget.lichessConfig.lichessName,
      httpClient: widget.apiClient?.httpClient,
    );
    final generation = ++_lichessStreamGeneration;
    _lichessSub = service.streamGame(widget.lichessConfig.gameId).listen(
      (event) {
        if (!mounted || generation != _lichessStreamGeneration) return;
        _lichessReconnectAttempts = 0;
        _applyLichessEvent(event);
      },
      onError: (_) => _handleLichessStreamClosed(
        generation: generation,
        message: service.lastErrorMessage,
      ),
      onDone: () => _handleLichessStreamClosed(
        generation: generation,
        message: service.lastStreamErrorMessage,
      ),
    );
  }

  void _handleLichessStreamClosed({
    required int generation,
    String? message,
  }) {
    if (!mounted || generation != _lichessStreamGeneration) return;
    _lichessStreamGeneration += 1;
    final subscription = _lichessSub;
    _lichessSub = null;
    unawaited(subscription?.cancel());
    final reason = message?.trim();
    if (reason != null && reason.isNotEmpty) {
      _showMessage(_lichessFailureMessage(
        'Lichess connection failed',
        reason,
      ));
    }
    _scheduleLichessStreamReconnect();
  }

  void _scheduleLichessStreamReconnect() {
    if (!mounted ||
        !_isLichessGame ||
        _gameOver ||
        !widget.lichessConfig.isReady ||
        _lichessSub != null ||
        _lichessReconnectTimer?.isActive == true) {
      return;
    }
    const delays = <Duration>[
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 15),
    ];
    final delay = delays[_lichessReconnectAttempts.clamp(0, delays.length - 1)];
    _lichessReconnectAttempts += 1;
    late final Timer timer;
    timer = Timer(delay, () {
      if (!identical(_lichessReconnectTimer, timer)) return;
      _lichessReconnectTimer = null;
      _startLichessStreamIfNeeded();
    });
    _lichessReconnectTimer = timer;
  }

  void _applyLichessEvent(LichessBoardEvent event) {
    _applyLichessTimeControl(event);
    _applyLichessServerMetadata(event);
    _handleLichessDrawOffer(event);
    final eventInitialFen = event.initialFen?.trim();
    if (eventInitialFen != null && eventInitialFen.isNotEmpty) {
      _lichessInitialFen = eventInitialFen;
    }
    final moves = event.moves;
    if (moves == null) {
      _applyLichessStatusEvent(event);
      return;
    }
    try {
      // The official stream is the only source of truth for an online game.
      // Do not replay a gameState packet until gameFull has supplied its
      // initial position; in particular, never assume standard chess here as
      // Lichess can start games from a custom FEN.
      final initialFen = _lichessInitialFen;
      if (initialFen == null || initialFen.isEmpty) return;
      final streamPly = moves.trim().isEmpty
          ? 0
          : moves.split(RegExp(r'\s+')).where((move) => move.isNotEmpty).length;
      // Lichess state is authoritative. Process it before applying any local
      // optimistic-ply guard so terminal events can never be dropped.
      final hasLichessStatus = event.status?.trim().isNotEmpty == true ||
          event.winner?.trim().isNotEmpty == true;
      if (hasLichessStatus) {
        _applyLichessStatusEvent(event);
      }
      final pendingLocalPly = _pendingLichessLocalPly;
      if (pendingLocalPly != null && streamPly < pendingLocalPly) {
        return;
      }
      final previousPly = _sanMoves.length;
      final lichessPositionInitialized = _lichessPositionInitialized;
      final history = GameNotationService.replayUciMoves(
        initialFen: initialFen,
        movesText: moves,
      );
      if (!mounted) return;
      final whiteSeconds = _clockSecondsFromMillis(event.whiteTimeMs);
      final blackSeconds = _clockSecondsFromMillis(event.blackTimeMs);
      final nextLocalSide = event.localSide != LichessPlayerSide.none
          ? event.localSide
          : _lichessPlayerSide;
      final playerIsWhiteForEvent = nextLocalSide != LichessPlayerSide.black;
      final opponentMoveArrived = history.sanMoves.length > previousPly &&
          (lichessPositionInitialized || previousPly > 0) &&
          _isOpponentMovePly(
            history.sanMoves.length,
            playerIsWhite: playerIsWhiteForEvent,
          );
      final lastStreamMove = opponentMoveArrived
          ? moves.trim().split(RegExp(r'\s+')).last.toLowerCase()
          : null;
      final boardPositionChanged = history.sanMoves.length != previousPly;
      setState(() {
        _lichessServerStateReceived = true;
        final whiteName = event.whiteName?.trim();
        final blackName = event.blackName?.trim();
        if (whiteName != null && whiteName.isNotEmpty) {
          _lichessWhiteName = whiteName;
        }
        if (blackName != null && blackName.isNotEmpty) {
          _lichessBlackName = blackName;
        }
        if (event.whiteRating != null) {
          _lichessWhiteRating = event.whiteRating;
        }
        if (event.blackRating != null) {
          _lichessBlackRating = event.blackRating;
        }
        if (event.localSide != LichessPlayerSide.none) {
          _lichessPlayerSide = event.localSide;
        }
        _sanMoves
          ..clear()
          ..addAll(history.sanMoves);
        _snapshots
          ..clear()
          ..addAll(history.snapshots.map(
            (item) => _MoveSnapshot(fen: item.fen, lastMove: item.lastMove),
          ));
        _currentPly = _snapshots.length - 1;
        _fen = _snapshots.last.fen;
        _lastMove = _snapshots.last.lastMove;
        if (lastStreamMove != null) {
          _lastOpponentMoveUci = lastStreamMove;
        }
        _legalTargetSquares = const {};
        _legalTargetLightQualities = const {};
        _legalTargetSourceSquare = null;
        _legalTargetsFromPhysicalLift = false;
        _clearMoveQualityAnalysisCache();
        if (pendingLocalPly != null && streamPly >= pendingLocalPly) {
          _pendingLichessLocalPly = null;
        }
        _lichessPositionInitialized = true;
        if (whiteSeconds != null) {
          _whiteSeconds = whiteSeconds;
        } else if (_timeMinutes > 0 &&
            LichessBoardService.isUnlimitedClock(event.clockInitialMs) ==
                false) {
          _whiteSeconds = _timeMinutes * 60;
        }
        if (blackSeconds != null) {
          _blackSeconds = blackSeconds;
        } else if (_timeMinutes > 0 &&
            LichessBoardService.isUnlimitedClock(event.clockInitialMs) ==
                false) {
          _blackSeconds = _timeMinutes * 60;
        }
        // Lichess 游戏只通过服务器事件判定结局，不使用本地状态判断
        _updateLichessGameOver(event);
      });
      _refreshPhysicalLedStates();
      if (boardPositionChanged) {
        _syncMoveBoardAfterVirtualFenChange();
      }
      if (opponentMoveArrived) {
        _playMoveSound(_moveSoundFromHistory(history));
        _switchClockIfNeeded(forOpponentMove: true);
        _setOpponentMoveLeds(_lastMove);
      } else {
        _clearOpponentMoveLeds();
      }
      _scheduleMoveQualityAnalysis();
      if (_gameOver) {
        _clearOpponentMoveLeds();
        _handleGameOverSideEffects();
      }
    } catch (_) {
      return;
    }
  }

  void _handleLichessDrawOffer(LichessBoardEvent event) {
    final offerFrom = event.drawOfferFrom;
    // Lichess keeps the offer flag in subsequent state packets while the
    // offer is pending. Once it disappears, allow the same opponent to make
    // a later offer again.
    if (offerFrom == null) {
      _handledLichessDrawOfferFrom = null;
      if (!_lichessDrawDialogInFlight) {
        _pendingLichessDrawOfferFrom = null;
      }
      return;
    }
    final status = event.status?.trim().toLowerCase();
    final terminalStatus = {
      'draw',
      'stalemate',
      'outoftime',
      'mate',
      'resign',
      'timeout',
      'aborted',
    }.contains(status);
    final terminalByWinner = event.winner?.trim().isNotEmpty == true;
    if (!_isLichessGame || _gameOver || terminalStatus || terminalByWinner) {
      return;
    }
    final localSide = event.localSide != LichessPlayerSide.none
        ? event.localSide
        : _lichessPlayerSide;
    if (localSide == LichessPlayerSide.none || offerFrom == localSide) return;
    if (_pendingLichessDrawOfferFrom == offerFrom ||
        _handledLichessDrawOfferFrom == offerFrom ||
        _lichessDrawDialogInFlight) {
      return;
    }
    _pendingLichessDrawOfferFrom = offerFrom;
    unawaited(_showLichessDrawOffer(offerFrom));
  }

  Future<void> _showLichessDrawOffer(LichessPlayerSide offerFrom) async {
    if (!mounted || _gameOver) return;
    _lichessDrawDialogInFlight = true;
    final strings = AppStrings.maybeOf(context);
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AppDialogShell(
        icon: Icons.handshake_rounded,
        title: 'Draw offer',
        subtitle: offerFrom == LichessPlayerSide.white
            ? 'White offers a draw.'
            : 'Black offers a draw.',
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings?.t('Decline') ?? 'Decline'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings?.t('Accept') ?? 'Accept'),
          ),
        ],
      ),
    );
    _lichessDrawDialogInFlight = false;
    if (!mounted) return;
    final service = _lichessService;
    final gameId = widget.lichessConfig.gameId;
    if (service == null || gameId.isEmpty || accepted == null) {
      _pendingLichessDrawOfferFrom = null;
      return;
    }
    final ok = await service.offerOrAcceptDraw(
      gameId: gameId,
      accept: accepted,
    );
    if (!mounted) return;
    _pendingLichessDrawOfferFrom = null;
    if (ok) _handledLichessDrawOfferFrom = offerFrom;
    _showMessage(ok
        ? (accepted ? 'Draw accepted' : 'Draw declined')
        : _lichessFailureMessage(
            accepted ? 'Accept draw failed' : 'Decline draw failed',
            service.lastErrorMessage,
          ));
  }

  void _applyLichessTimeControl(LichessBoardEvent event) {
    if (event.rated != null) {
      _lichessRatedOverride = event.rated;
    }
    final initialMs = event.clockInitialMs;
    // The first gameFull event is the authoritative source of the time
    // control. If it has no clock, this is a correspondence/unlimited game;
    // never fall back to the setup screen's default value.
    if (initialMs == null) {
      if (event.type == LichessBoardEventType.gameFull) {
        _lichessTimeMinutesOverride = 0;
        _lichessIncrementSecondsOverride = 0;
        _lichessUnlimitedClockInitialMs = null;
      }
      return;
    }
    if (LichessBoardService.isUnlimitedClock(initialMs)) {
      _lichessTimeMinutesOverride = 0;
      _lichessIncrementSecondsOverride = 0;
      _lichessUnlimitedClockInitialMs = initialMs;
      return;
    }
    _lichessTimeMinutesOverride = initialMs ~/ Duration.millisecondsPerMinute;
    _lichessIncrementSecondsOverride =
        (event.clockIncrementMs ?? 0) ~/ Duration.millisecondsPerSecond;
    _lichessUnlimitedClockInitialMs = null;
  }

  void _applyLichessServerMetadata(LichessBoardEvent event) {
    if (!_isLichessGame ||
        (event.type != LichessBoardEventType.gameFull &&
            event.type != LichessBoardEventType.gameState) ||
        !mounted) {
      return;
    }
    setState(() {
      final whiteName = event.whiteName?.trim();
      final blackName = event.blackName?.trim();
      if (whiteName != null && whiteName.isNotEmpty) {
        _lichessWhiteName = whiteName;
      }
      if (blackName != null && blackName.isNotEmpty) {
        _lichessBlackName = blackName;
      }
      if (event.whiteRating != null) _lichessWhiteRating = event.whiteRating;
      if (event.blackRating != null) _lichessBlackRating = event.blackRating;
      if (event.localSide != LichessPlayerSide.none) {
        _lichessPlayerSide = event.localSide;
      }
    });
  }

  void _applyLichessStatusEvent(LichessBoardEvent event) {
    final status = event.status?.trim().toLowerCase();
    final hasWinner = event.winner?.trim().isNotEmpty == true;
    if ((status == null || status == 'started' || status == 'created') &&
        !hasWinner) {
      return;
    }
    // A terminal/status packet without a replayable position must not make
    // the placeholder board look like the real game.  The position event is
    // processed first and is the gate that enables all Lichess interaction.
    if (_isLichessGame && !_lichessPositionInitialized) return;
    final wasGameOver = _gameOver;
    setState(() {
      // A status packet alone does not contain the authoritative board
      // position.  Keep the room non-interactive until gameFull/gameState
      // has supplied and replayed the current FEN/move list.
      if (_lichessPositionInitialized) {
        _lichessServerStateReceived = true;
      }
      final whiteName = event.whiteName?.trim();
      final blackName = event.blackName?.trim();
      if (whiteName != null && whiteName.isNotEmpty) {
        _lichessWhiteName = whiteName;
      }
      if (blackName != null && blackName.isNotEmpty) {
        _lichessBlackName = blackName;
      }
      if (event.whiteRating != null) {
        _lichessWhiteRating = event.whiteRating;
      }
      if (event.blackRating != null) {
        _lichessBlackRating = event.blackRating;
      }
      if (event.localSide != LichessPlayerSide.none) {
        _lichessPlayerSide = event.localSide;
      }
      final whiteSeconds = _clockSecondsFromMillis(event.whiteTimeMs);
      final blackSeconds = _clockSecondsFromMillis(event.blackTimeMs);
      if (whiteSeconds != null) _whiteSeconds = whiteSeconds;
      if (blackSeconds != null) _blackSeconds = blackSeconds;
      _updateLichessGameOver(event);
    });
    if (!wasGameOver && _gameOver) {
      _clearOpponentMoveLeds();
      _refreshPhysicalLedStates();
      _handleGameOverSideEffects();
    }
  }

  ChessBoardMove _moveSoundFromHistory(GameMoveHistory history) {
    final snapshot = history.snapshots.last;
    final lastMove = snapshot.lastMove;
    final state = ChessBoardState.fromFen(snapshot.fen, lastMove: lastMove);
    return ChessBoardMove(
      from: lastMove.isNotEmpty ? lastMove.first : '',
      to: lastMove.length > 1 ? lastMove[1] : '',
      san: history.sanMoves.isNotEmpty ? history.sanMoves.last : '',
      fen: snapshot.fen,
      state: state,
    );
  }

  bool _isOpponentMovePly(int ply, {required bool playerIsWhite}) {
    if (ply <= 0) return false;
    final movedByWhite = ply.isOdd;
    return movedByWhite != playerIsWhite;
  }

  void _updateLichessGameOver(LichessBoardEvent event) {
    final status = event.status?.trim().toLowerCase();
    final winner = event.winner?.trim().toLowerCase();
    if ((status == null || status == 'started' || status == 'created') &&
        (winner == null || winner.isEmpty)) {
      return;
    }
    // 优先处理有明确获胜方的情况
    if (winner == 'white' || winner == 'black') {
      _gameOver = true;
      _clockTimer?.cancel();
      _lichessResultToken = winner == 'white' ? '1-0' : '0-1';
      final playerWon = winner == (_playerIsWhite ? 'white' : 'black');
      _resultText = _lichessGameOverText(
        status: status,
        playerWon: playerWon,
      );
      _finalResultText = _resultText;
      return;
    }
    // 只处理真正的和棋和中止状态
    if (status == 'draw' || status == 'stalemate' || status == 'aborted') {
      _gameOver = true;
      _clockTimer?.cancel();
      _lichessResultToken = status == 'aborted' ? '*' : '1/2-1/2';
      _resultText = switch (status) {
        'stalemate' => 'Draw by stalemate on Lichess',
        'aborted' => 'Game aborted on Lichess',
        _ => 'Draw on Lichess',
      };
      _finalResultText = _resultText;
    }
  }

  String _lichessGameOverText({
    required String? status,
    required bool playerWon,
  }) {
    return switch (status) {
      'resign' => playerWon
          ? 'Opponent resigned. You won on Lichess'
          : 'You resigned. You lost on Lichess',
      'timeout' || 'outoftime' => playerWon
          ? 'Opponent ran out of time. You won on Lichess'
          : 'You ran out of time. You lost on Lichess',
      'mate' => playerWon
          ? 'You won by checkmate on Lichess'
          : 'You lost by checkmate on Lichess',
      'cheat' => playerWon
          ? 'Opponent violated fair play rules. You won on Lichess'
          : 'You lost after a fair play violation on Lichess',
      'nostart' => playerWon
          ? 'Opponent did not make the first move. You won on Lichess'
          : 'You did not make the first move. You lost on Lichess',
      'variantend' => playerWon
          ? 'You won by the variant ending on Lichess'
          : 'You lost by the variant ending on Lichess',
      _ => playerWon ? 'You won on Lichess' : 'You lost on Lichess',
    };
  }

  Future<void> _requestLichessTakeback() async {
    if (_isBotGame) {
      _takeBackBotMove();
      return;
    }
    final service = _lichessService;
    if (service == null || widget.lichessConfig.gameId.isEmpty) {
      _showMessage('Takeback is available after a native Lichess game starts.');
      return;
    }
    final ok = await service.offerOrAcceptTakeback(
      gameId: widget.lichessConfig.gameId,
      accept: true,
    );
    if (!mounted) return;
    _showMessage(ok
        ? 'Takeback requested'
        : _lichessFailureMessage(
            'Takeback request failed',
            service.lastErrorMessage,
          ));
  }

  Future<void> _showOtbTakebackConfirm() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) {
        return AppDialogShell(
          icon: Icons.undo_rounded,
          title: 'Confirm takeback?',
          subtitle: 'Take back the last recorded move in this OTB game.',
          actions: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Cancel',
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _takeBackOtbMove();
                },
                child: const Text(
                  'Confirm takeback',
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _takeBackOtbMove() {
    if (_snapshots.length <= 1) {
      _showMessage('No move to take back.');
      return;
    }
    final targetPly = (_atLatest ? _currentPly - 1 : _currentPly)
        .clamp(0, _snapshots.length - 1)
        .toInt();
    setState(() {
      _currentPly = targetPly;
      _trimFutureIfNeeded();
      final snapshot = _snapshots.last;
      _fen = snapshot.fen;
      _lastMove = snapshot.lastMove;
      _gameOver = false;
      _finalResultText = '';
      _resultText = '';
      _hintMove = null;
      _legalTargetSquares = const {};
      _legalTargetLightQualities = const {};
      _legalTargetSourceSquare = null;
      _legalTargetsFromPhysicalLift = false;
      _clearMoveQualityAnalysisCache();
      _lastRecordSaveKey = null;
    });
    _clearOpponentMoveLeds();
    _syncMoveBoardAfterVirtualFenChange();
    _refreshPhysicalLedStates();
    _schedulePositionEvaluation();
    unawaited(_saveGameRecordIfNeeded(allowPreOfficialBotDraft: true));
    _showMessage('Move taken back.');
  }

  void _takeBackBotMove() {
    if (!widget.boardSettings.allowTakeback) {
      _showMessage('Takeback is disabled in board settings.');
      return;
    }
    if (_snapshots.length <= 1) {
      _showMessage('No move to take back.');
      return;
    }
    final latestPly = _snapshots.length - 1;
    final targetPly = !_atLatest
        ? _currentPly
        : (_botThinking ? latestPly - 1 : latestPly - 2).clamp(0, latestPly);
    setState(() {
      _currentPly = targetPly.toInt();
      _trimFutureIfNeeded();
      final snapshot = _snapshots.last;
      _fen = snapshot.fen;
      _lastMove = snapshot.lastMove;
      _gameOver = false;
      _finalResultText = '';
      _botThinking = false;
      _resultText = '';
      _hintMove = null;
      _legalTargetSquares = const {};
      _legalTargetLightQualities = const {};
      _legalTargetSourceSquare = null;
      _legalTargetsFromPhysicalLift = false;
      _clearMoveQualityAnalysisCache();
      _lastRecordSaveKey = null;
    });
    _clearOpponentMoveLeds();
    _syncMoveBoardAfterVirtualFenChange();
    _refreshPhysicalLedStates();
    _schedulePositionEvaluation();
    unawaited(_saveGameRecordIfNeeded(allowPreOfficialBotDraft: true));
    _showMessage('Move taken back.');
    _maybeBotMove();
  }

  Future<void> _offerLichessDraw() async {
    if (_isBotGame) {
      await _offerBotDraw();
      return;
    }
    final service = _lichessService;
    if (service == null || widget.lichessConfig.gameId.isEmpty) {
      _showMessage('Draw offer is available in native Lichess games.');
      return;
    }
    final ok = await service.offerOrAcceptDraw(
      gameId: widget.lichessConfig.gameId,
      accept: true,
    );
    if (!mounted) return;
    if (ok) _playSound(AppSoundEvent.confirm);
    _showMessage(ok
        ? 'Draw offered'
        : _lichessFailureMessage(
            'Draw offer failed',
            service.lastErrorMessage,
          ));
  }

  Future<void> _showClockOtbDrawConfirm(dc.Side side) {
    return _showOtbDrawConfirm(offeredBy: side);
  }

  Future<void> _showBotDrawConfirm() async {
    if (!mounted || _gameConcluded) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => AppDialogShell(
        icon: Icons.handshake_rounded,
        title: 'Offer draw?',
        subtitle: 'Ask the bot to accept a draw in this game.',
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
                Navigator.of(dialogContext).pop();
                unawaited(_offerBotDraw());
              },
              child: const Text('Offer draw'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showOtbDrawConfirm({dc.Side? offeredBy}) async {
    if (!mounted) return;
    final offeredByLabel = switch (offeredBy) {
      dc.Side.white => 'White',
      dc.Side.black => 'Black',
      null => null,
    };
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) {
        return AppDialogShell(
          icon: Icons.handshake_rounded,
          title: 'Confirm draw?',
          subtitle: offeredByLabel == null
              ? 'End this OTB record game as a draw by agreement.'
              : '$offeredByLabel offers a draw. Confirm to end this OTB game as a draw by agreement.',
          actions: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Cancel',
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _drawOtbGame();
                },
                child: const Text(
                  'Confirm draw',
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _drawOtbGame() {
    setState(() {
      _gameOver = true;
      _resultText = 'Game drawn by agreement';
      _finalResultText = _resultText;
      _hintMove = null;
    });
    _clearOpponentMoveLeds();
    _refreshHintLeds();
    _refreshLegalMoveLeds();
    _clockTimer?.cancel();
    _handleGameOverSideEffects();
  }

  Future<void> _offerBotDraw() async {
    final position = loadDartChessPosition(_fen);
    if (!position.isGameOver && !await _botAcceptsDrawOffer()) {
      if (!mounted) return;
      _showMessage('Bot declined the draw offer.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _gameOver = true;
      _resultText = 'Game drawn by agreement';
      _finalResultText = _resultText;
      _hintMove = null;
    });
    _clearOpponentMoveLeds();
    _refreshHintLeds();
    _refreshLegalMoveLeds();
    _clockTimer?.cancel();
    _handleGameOverSideEffects();
  }

  Future<bool> _botAcceptsDrawOffer() async {
    if (_sanMoves.length < 20) return false;
    final cached = _numericEval(_engineEvalLabel);
    if (cached != null) return cached.abs() <= 0.25;
    final analysis =
        await (widget.positionAnalyzer ?? const StockfishPositionAnalyzer())
            .analyzeFen(_fen, depth: 10, multiPv: 1);
    if (analysis == null) return false;
    return analysis.whiteEval.abs() <= 0.25;
  }

  double? _numericEval(String? label) {
    if (label == null || label.startsWith('#')) return null;
    return double.tryParse(label.replaceFirst('+', ''));
  }

  Future<void> _resignCurrentGame() async {
    if (_gameConcluded || _resignInFlight) return;
    _resignInFlight = true;
    if (!_isLichessGame) {
      setState(() {
        _gameOver = true;
        _resultText = _playerIsWhite
            ? 'Black wins by resignation'
            : 'White wins by resignation';
        _finalResultText = _resultText;
        _hintMove = null;
      });
      _clearOpponentMoveLeds();
      _refreshHintLeds();
      _refreshLegalMoveLeds();
      _clockTimer?.cancel();
      _handleGameOverSideEffects();
      unawaited(_saveGameRecordIfNeeded(force: true, showFailure: true));
      return;
    }
    final service = _lichessService;
    if (service == null || widget.lichessConfig.gameId.isEmpty) {
      _resignInFlight = false;
      _showMessage('Resign is available in native Lichess games.');
      return;
    }
    final ok = await service.resign(widget.lichessConfig.gameId);
    if (!mounted) return;
    if (!ok) {
      _resignInFlight = false;
      _showMessage(_lichessFailureMessage(
        'Resign failed',
        service.lastErrorMessage,
      ));
      return;
    }
    setState(() {
      _gameOver = true;
      _resultText = _playerIsWhite
          ? 'Black wins by resignation'
          : 'White wins by resignation';
      _finalResultText = _resultText;
      _hintMove = null;
    });
    _clearOpponentMoveLeds();
    _refreshHintLeds();
    _refreshLegalMoveLeds();
    _clockTimer?.cancel();
    _lichessReconnectTimer?.cancel();
    _handleGameOverSideEffects();
  }

  String _currentPgn() {
    final copy = _copyForCurrentGame();
    final extraHeaders = <String, String>{
      'ChessnutGameId': _recordGameId,
    };
    if (_isBotGame) {
      extraHeaders['PlayerSide'] = _playerIsWhite ? 'White' : 'Black';
      extraHeaders['EngineKind'] = widget.botConfig.engineKind.name;
      extraHeaders['MaiaElo'] = widget.botConfig.maiaElo.toString();
      extraHeaders['StockfishElo'] = widget.botConfig.stockfishElo.toString();
      extraHeaders['GameStatus'] = _recordGameStatus().toString();
      extraHeaders['WhiteTime'] = _whiteSeconds.toString();
      extraHeaders['BlackTime'] = _blackSeconds.toString();
      if (widget.isChessnutClockDevice) {
        extraHeaders['ShowPgnList'] = widget.botConfig.showPgnList.toString();
      }
      final shareId = _recordShareId;
      if (shareId != null && shareId.isNotEmpty) {
        extraHeaders['ShareId'] = shareId;
      }
      final career = widget.botConfig.careerMode;
      if (career != null) {
        extraHeaders['GameMode'] = 'Career';
        extraHeaders['CareerMode'] = _encodedCareerMode(career);
        extraHeaders['CareerStartElo'] = career.startElo.toString();
        extraHeaders['CareerWinElo'] = career.winElo.toString();
        extraHeaders['CareerLoseElo'] = career.loseElo.toString();
        extraHeaders['CareerOpponentName'] = career.opponentName;
        extraHeaders['CareerOpponentAvatar'] = career.opponentAvatarAsset;
      }
      extraHeaders['ChessnutGameId'] = _recordGameId;
    }
    if (_isLichessGame || widget.mode == GameLaunchMode.otb) {
      if (_isLichessGame) {
        extraHeaders['LichessGameId'] = widget.lichessConfig.gameId;
        extraHeaders['LichessToken'] = widget.lichessConfig.token;
        extraHeaders['LichessName'] = widget.lichessConfig.lichessName;
        extraHeaders['PlayerSide'] = _playerIsWhite ? 'White' : 'Black';
      }
      extraHeaders['GameStatus'] = _recordGameStatus().toString();
      extraHeaders['WhiteTime'] = _whiteSeconds.toString();
      extraHeaders['BlackTime'] = _blackSeconds.toString();
      if (widget.isChessnutClockDevice && widget.mode == GameLaunchMode.otb) {
        extraHeaders['ShowPgnList'] = widget.otbConfig.showPgnList.toString();
        if (widget.otbConfig.chess960) {
          extraHeaders['Variant'] = 'Chess960';
        }
      }
    }
    extraHeaders['Speed'] = _recordSpeedLabel();
    final localName = _localPlayerName();
    final opponentName = copy.opponent;
    return GameNotationService.buildPgn(
      sanMoves: _sanMoves,
      event: copy.subtitle,
      site: 'Chessnut App',
      white: _isOtbRecordGame
          ? _otbWhiteName
          : (_playerIsWhite ? localName : opponentName),
      black: _isOtbRecordGame
          ? _otbBlackName
          : (_playerIsWhite ? opponentName : localName),
      result: _resultToken(),
      timeControl: '$_timeMinutes+$_incrementSeconds',
      startFen: _snapshots.first.fen,
      date: _recordStartedAt,
      extraHeaders: extraHeaders,
    );
  }

  SpectatorGameSnapshot _currentSpectatorSnapshot({String liveUrl = ''}) {
    final copy = _copyForCurrentGame();
    final game = loadDartChessPosition(_fen);
    final localName = _localPlayerName();
    final opponentName =
        copy.opponent.trim().isEmpty ? 'Opponent' : copy.opponent;
    final whiteName = _isOtbRecordGame
        ? _otbWhiteName
        : (_playerIsWhite ? localName : opponentName);
    final blackName = _isOtbRecordGame
        ? _otbBlackName
        : (_playerIsWhite ? opponentName : localName);
    final gameId = widget.lichessConfig.gameId.trim();
    final resolvedLiveUrl = liveUrl.trim().isNotEmpty
        ? liveUrl.trim()
        : _isLichessGame && gameId.isNotEmpty
            ? Uri.https('lichess.org', gameId).toString()
            : '';
    return SpectatorGameSnapshot(
      pgn: _currentPgn(),
      fen: _fen,
      sanMoves: List.unmodifiable(_sanMoves),
      lastMove: List.unmodifiable(_lastMove),
      whiteName: whiteName.trim().isEmpty ? 'White' : whiteName,
      blackName: blackName.trim().isEmpty ? 'Black' : blackName,
      whiteTime: _formatClock(_whiteSeconds),
      blackTime: _formatClock(_blackSeconds),
      whiteActive: !_gameOver && game.turn == dc.Side.white,
      blackActive: !_gameOver && game.turn == dc.Side.black,
      liveUrl: resolvedLiveUrl,
    );
  }

  String _encodedCareerMode(CareerModeConfig career) {
    return base64Encode(utf8.encode(jsonEncode(career.toJson())));
  }

  String _recordSpeedLabel() {
    if (_timeMinutes <= 0) return 'Casual';
    final estimatedSeconds = _timeMinutes * 60 + _incrementSeconds * 40;
    if (estimatedSeconds < 3 * 60) return 'Bullet';
    if (estimatedSeconds < 8 * 60) return 'Blitz';
    if (estimatedSeconds < 25 * 60) return 'Rapid';
    return 'Classical';
  }

  Future<bool> _saveGameRecordIfNeeded({
    bool force = false,
    bool showFailure = false,
    bool allowPreOfficialBotDraft = false,
  }) async {
    if (_sanMoves.isEmpty && !(allowPreOfficialBotDraft && _isBotGame)) {
      return true;
    }
    if (!_isBotGame &&
        !_isLichessGame &&
        widget.mode != GameLaunchMode.otb &&
        !_gameOver) {
      return true;
    }
    if (!_gameRecordSaveStarted && !allowPreOfficialBotDraft) return true;
    if (_isLichessGame && !_gameOver) return true;
    final coordinator = _recordSaveCoordinator;
    if (coordinator == null) return true;
    _alignClockToNow();
    final pgn = _currentPgn();
    final saveKey = pgn;
    if (_lastRecordSaveKey == saveKey) return true;
    final copy = _copyForCurrentGame();
    final localName = _localPlayerName();
    final whiteName = _isOtbRecordGame
        ? _otbWhiteName
        : (_playerIsWhite ? localName : copy.opponent);
    final blackName = _isOtbRecordGame
        ? _otbBlackName
        : (_playerIsWhite ? copy.opponent : localName);
    final recordIsFinished = _gameOver;
    final winId = recordIsFinished ? _winId() : 0;
    final gameStatus = _recordGameStatus();
    final gameStep = _sanMoves.length;
    final resultToken = _resultToken();
    final savedAt = DateTime.now();
    final metadata = PgnSaveMetadata(
      lichessGameId: _isLichessGame ? widget.lichessConfig.gameId : null,
      lichessToken: _isLichessGame ? widget.lichessConfig.token : null,
      lichessName: _isLichessGame ? widget.lichessConfig.lichessName : null,
      clientGameId: _recordGameId,
      playerColor: _isBotGame || _isLichessGame
          ? (_playerIsWhite ? 'white' : 'black')
          : '',
      speed: _recordSpeedLabel().toLowerCase(),
      timeControl: '$_timeMinutes+$_incrementSeconds',
      opponentName: _isBotGame || _isLichessGame ? copy.opponent : '',
    );
    final outcome = await coordinator.save(_GameRecordSaveSnapshot(
      saveKey: saveKey,
      pgn: pgn,
      whiteName: whiteName,
      blackName: blackName,
      playTime: (_recordStartedAt.millisecondsSinceEpoch ~/ 1000).toString(),
      playMode: _playModeApiValue(),
      winId: winId,
      gameStatus: gameStatus,
      gameStep: gameStep,
      resultToken: resultToken,
      savedAt: savedAt,
      metadata: metadata,
    ));
    _recordPgnId = outcome.pgnId ?? _recordPgnId;
    _recordShareId = outcome.shareId ?? _recordShareId;
    if (!outcome.status.isSuccess) {
      if (mounted) {
        _showMessage(
          outcome.status.errorMessage ?? 'Game record upload failed.',
        );
      }
      return false;
    }
    if (outcome.savedLocally && !_localSaveNoticeShown && mounted) {
      _localSaveNoticeShown = true;
      _showMessage('Saved on this device. Upload it later from Local games.');
    }
    _lastRecordSaveKey = outcome.saveKey;
    return true;
  }

  Future<void> _shareLiveUrl() async {
    final apiClient = widget.apiClient;
    if (apiClient == null || apiClient.session == null) {
      _showMessage('Sign in to share a live game URL.');
      return;
    }
    if (_shareLiveUrlInFlight) return;
    if (mounted) {
      setState(() => _shareLiveUrlInFlight = true);
    } else {
      _shareLiveUrlInFlight = true;
    }
    try {
      final saved = await _saveGameRecordIfNeeded(
        force: true,
        showFailure: true,
        allowPreOfficialBotDraft: true,
      );
      if (!mounted || !saved) return;
      final shareId = _recordShareId?.trim();
      if (shareId == null || shareId.isEmpty) {
        _showMessage('Live URL is not available yet.');
        return;
      }
      final liveUrl = apiClient.shareUrl(shareId).toString();
      await _copyText(liveUrl, 'Live game URL copied');
      widget.onGameShared?.call(_currentSpectatorSnapshot(liveUrl: liveUrl));
    } catch (_) {
      if (mounted) {
        _showMessage('Live URL share failed.');
      }
    } finally {
      if (mounted) {
        setState(() => _shareLiveUrlInFlight = false);
      } else {
        _shareLiveUrlInFlight = false;
      }
    }
  }

  int _recordGameStatus() => _gameOver ? 2 : 1;

  String _playModeApiValue() {
    return switch (widget.mode) {
      GameLaunchMode.bot => 'bot',
      GameLaunchMode.otb => 'otb',
      GameLaunchMode.lichess => 'lichess',
      GameLaunchMode.chesscom => 'chesscom',
      GameLaunchMode.clock => 'clock',
    };
  }

  int _winId() {
    return switch (_resultToken()) {
      '1-0' => 1,
      '0-1' => 2,
      '1/2-1/2' => 3,
      _ => 0,
    };
  }

  String _resultToken() {
    if (_isLichessGame && _lichessResultToken != '*') {
      return _lichessResultToken;
    }
    if (_resultText.startsWith('White wins')) return '1-0';
    if (_resultText.startsWith('Black wins')) return '0-1';
    // 改用 contains 而不是精确匹配，以支持详细的结果文本
    if (_resultText.contains('You won on Lichess')) {
      return _playerIsWhite ? '1-0' : '0-1';
    }
    if (_resultText.contains('You lost on Lichess')) {
      return _playerIsWhite ? '0-1' : '1-0';
    }
    if (_resultText.startsWith('Draw') || _resultText.contains('draw')) {
      return '1/2-1/2';
    }
    return '*';
  }

  BotMoveResult _avoidThreefoldRepetitionIfPossible({
    required String fen,
    required BotMoveResult engineResult,
  }) {
    if (!_wouldCompleteThreefoldRepetition(engineResult.fen)) {
      return engineResult;
    }
    final position = loadDartChessPosition(fen);
    BotMoveResult? bestAlternative;
    var bestScore = -1 << 30;
    for (final move in legalNormalMoves(position)) {
      try {
        final (nextPosition, san) = position.makeSan(move);
        if (_wouldCompleteThreefoldRepetition(nextPosition.fen)) continue;
        final score = _botAntiRepetitionMoveScore(position, move);
        if (bestAlternative == null || score > bestScore) {
          bestAlternative = BotMoveResult(
            move: move,
            san: san,
            fen: nextPosition.fen,
            isFallback: true,
          );
          bestScore = score;
        }
      } catch (_) {
        continue;
      }
    }
    return bestAlternative ?? engineResult;
  }

  int _botAntiRepetitionMoveScore(dc.Position position, dc.NormalMove move) {
    var score = 0;
    final movingPiece = position.board.pieceAt(move.from);
    final capturedPiece = position.board.pieceAt(move.to);
    if (capturedPiece != null) {
      score += _pieceValueForAntiRepetition(capturedPiece.role);
      if (movingPiece != null) {
        score -= _pieceValueForAntiRepetition(movingPiece.role) ~/ 10;
      }
    }
    if (move.promotion != null) {
      score += _pieceValueForAntiRepetition(move.promotion!);
    }
    try {
      final nextPosition = position.play(move);
      if (nextPosition.isCheckmate) return 100000;
      if (nextPosition.isCheck) score += 50;
    } catch (_) {
      return -100000;
    }
    score += switch (move.to.name) {
      'd4' || 'e4' || 'd5' || 'e5' => 20,
      'c3' || 'd3' || 'e3' || 'f3' || 'c6' || 'd6' || 'e6' || 'f6' => 8,
      _ => 0,
    };
    return score;
  }

  int _pieceValueForAntiRepetition(dc.Role role) {
    return switch (role) {
      dc.Role.pawn => 100,
      dc.Role.knight => 320,
      dc.Role.bishop => 330,
      dc.Role.rook => 500,
      dc.Role.queen => 900,
      dc.Role.king => 0,
    };
  }

  bool _isThreefoldRepetitionDraw() {
    if (_snapshots.length < 9) return false;
    final currentKey = _threefoldPositionKey(_fen);
    if (currentKey == null) return false;
    var occurrences = 0;
    for (final snapshot in _snapshots) {
      if (_threefoldPositionKey(snapshot.fen) == currentKey) {
        occurrences++;
        if (occurrences >= 3) return true;
      }
    }
    return false;
  }

  bool _wouldCompleteThreefoldRepetition(String nextFen) {
    final key = _threefoldPositionKey(nextFen);
    if (key == null) return false;
    var occurrences = 1;
    for (final snapshot in _snapshots) {
      if (_threefoldPositionKey(snapshot.fen) == key) {
        occurrences++;
        if (occurrences >= 3) return true;
      }
    }
    return false;
  }

  Future<void> _copyText(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _showMessage(message);
  }

  void _showMessage(String message) {
    showAppFeedback(context, message, tone: _feedbackToneFor(message));
  }
}

String? _threefoldPositionKey(String fen) {
  final parts = normalizeFenInput(fen).trim().split(RegExp(r'\s+'));
  if (parts.length < 4) return null;
  return parts.take(4).join(' ');
}

AppFeedbackTone _feedbackToneFor(String message) {
  final normalized = message.toLowerCase();
  if (normalized.contains('failed') ||
      normalized.contains('rejected') ||
      normalized.contains('unavailable') ||
      normalized.contains('no legal')) {
    return AppFeedbackTone.error;
  }
  if (normalized.contains('copied') ||
      normalized.contains('requested') ||
      normalized.contains('offered')) {
    return AppFeedbackTone.success;
  }
  return AppFeedbackTone.info;
}

String _lichessMoveRejectedMessage(String? reason) {
  final detail = _cleanLichessFailureReason(reason);
  if (detail == null) return 'Lichess rejected that move. Board restored.';
  return 'Lichess rejected that move: $detail. Board restored.';
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

bool _stringSetsEqual(Set<String> a, Set<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final item in a) {
    if (!b.contains(item)) return false;
  }
  return true;
}

String _boardOnlyFen(String fen) => fen.trim().split(RegExp(r'\s+')).first;

ChessBoardMove? _resolveBoardFenMove({
  required String currentFen,
  required String boardFen,
}) {
  final position = loadDartChessPosition(currentFen);
  final normalizedBoardFen = _boardOnlyFen(boardFen);
  if (position.board.fen == normalizedBoardFen) return null;
  for (final move in _boardFenMoveCandidates(position)) {
    try {
      final (nextPosition, san) = position.makeSan(move);
      if (nextPosition.board.fen != normalizedBoardFen) continue;
      final state = ChessBoardState.fromPosition(
        nextPosition,
        lastMove: [move.from.name, move.to.name],
      );
      return ChessBoardMove(
        from: move.from.name,
        to: move.to.name,
        promotion: move.promotion?.letter,
        san: san,
        fen: nextPosition.fen,
        state: state,
      );
    } catch (_) {
      continue;
    }
  }
  return null;
}

ChessBoardMove? _moveFromUci(String fen, String uci) {
  try {
    final position = loadDartChessPosition(fen);
    final move = dc.NormalMove.fromUci(uci.trim());
    if (!position.isLegal(move)) return null;
    final (nextPosition, san) = position.makeSan(move);
    return ChessBoardMove(
      from: move.from.name,
      to: move.to.name,
      promotion: move.promotion?.letter,
      san: san,
      fen: nextPosition.fen,
      state: ChessBoardState.fromPosition(
        nextPosition,
        lastMove: [move.from.name, move.to.name],
      ),
    );
  } catch (_) {
    return null;
  }
}

List<dc.NormalMove> _boardFenMoveCandidates(dc.Position position) {
  final moves = <dc.NormalMove>[];
  final seen = <String>{};
  void add(dc.NormalMove move) {
    if (!seen.add(move.uci)) return;
    if (position.isLegal(move)) moves.add(move);
  }

  for (final move in legalNormalMoves(position)) {
    add(move);
  }
  for (final entry in dc.makeLegalMoves(position).entries) {
    final from = entry.key;
    final piece = position.board.pieceAt(from);
    if (piece == null) continue;
    for (final to in entry.value) {
      final promotionRoles = _boardFenPromotionRolesFor(piece, to);
      if (promotionRoles.isEmpty) {
        add(dc.NormalMove(from: from, to: to));
      } else {
        for (final role in promotionRoles) {
          add(dc.NormalMove(from: from, to: to, promotion: role));
        }
      }
    }
  }
  return moves;
}

List<dc.Role> _boardFenPromotionRolesFor(dc.Piece piece, dc.Square to) {
  if (piece.role != dc.Role.pawn ||
      (to.rank != dc.Rank.first && to.rank != dc.Rank.eighth)) {
    return const [];
  }
  return const [dc.Role.queen, dc.Role.rook, dc.Role.bishop, dc.Role.knight];
}

ChessBoardMove? _resolvePhysicalBoardFenMove({
  required String currentFen,
  required String physicalBoardFen,
  required List<_BoardFenMapping> mappings,
  required ValueChanged<_BoardFenMapping> onMappingResolved,
}) {
  for (final mapping in mappings) {
    final mappedFen = _applyBoardFenMapping(physicalBoardFen, mapping);
    final move =
        _resolveBoardFenMove(currentFen: currentFen, boardFen: mappedFen);
    if (move != null) {
      onMappingResolved(mapping);
      return move;
    }
  }
  return null;
}

_BoardFenMapping? _mappingForPhysicalBoardFen({
  required String physicalBoardFen,
  required List<String> appBoardFens,
}) {
  return closestPhysicalBoardFenMapping(
    physicalFen: physicalBoardFen,
    referenceFens: appBoardFens,
  );
}

_PhysicalLiftLegalTargetSelection? _physicalLiftLegalTargetSelection({
  required dc.Position position,
  required String physicalBoardFen,
  required List<_BoardFenMapping> mappings,
}) {
  for (final mapping in mappings) {
    final mappedPhysicalFen = _applyBoardFenMapping(physicalBoardFen, mapping);
    final source = _selectedSquareLiftedFromPhysicalFen(
      position: position,
      mappedPhysicalBoardFen: mappedPhysicalFen,
    );
    if (source == null) continue;
    final targets = dc
            .makeLegalMoves(position)[source]
            ?.map((square) => square.name)
            .toSet() ??
        const <String>{};
    if (targets.isEmpty) continue;
    return _PhysicalLiftLegalTargetSelection(
      mapping: mapping,
      sourceSquare: source.name,
      targetSquares: Set<String>.unmodifiable(targets),
    );
  }
  return null;
}

dc.Square? _selectedSquareLiftedFromPhysicalFen({
  required dc.Position position,
  required String mappedPhysicalBoardFen,
}) {
  final appBoard = _expandBoardFen(position.board.fen);
  final physicalBoard = _expandBoardFen(mappedPhysicalBoardFen);
  if (appBoard == null || physicalBoard == null) return null;
  dc.Square? liftedSquare;
  for (final square in dc.Square.values) {
    final piece = position.board.pieceAt(square);
    if (piece == null || piece.color != position.turn) continue;
    final index = _boardFenIndexForSquare(square);
    if (index == null) continue;
    if (appBoard[index].isEmpty ||
        physicalBoard[index].isNotEmpty ||
        appBoard[index] == physicalBoard[index]) {
      continue;
    }
    for (var otherIndex = 0; otherIndex < appBoard.length; otherIndex += 1) {
      if (otherIndex == index) continue;
      if (appBoard[otherIndex] != physicalBoard[otherIndex]) return null;
    }
    if (liftedSquare != null) return null;
    liftedSquare = square;
  }
  return liftedSquare;
}

int? _boardFenIndexForSquare(dc.Square square) {
  return (7 - square.rank.value) * 8 + square.file.value;
}

int? _boardFenIndexForSquareName(String squareName) {
  final square = dc.Square.parse(squareName);
  if (square == null) return null;
  return _boardFenIndexForSquare(square);
}

Set<String> _differentSquares(String sourceBoardFen, String targetBoardFen) {
  final source = _expandBoardFen(sourceBoardFen);
  final target = _expandBoardFen(targetBoardFen);
  if (source == null || target == null) return const {};
  final squares = <String>{};
  for (var index = 0; index < source.length; index += 1) {
    if (source[index] == target[index]) continue;
    final file = index % 8;
    final rank = index ~/ 8;
    squares.add('${ChessBoard.files[file]}${8 - rank}');
  }
  return Set<String>.unmodifiable(squares);
}

typedef _BoardFenMapping = PhysicalBoardFenMapping;

const _supportedPhysicalBoardMappings = [
  _BoardFenMapping.identity,
  _BoardFenMapping.reversed,
];

bool _isSupportedPhysicalBoardMapping(_BoardFenMapping mapping) {
  return mapping == _BoardFenMapping.identity ||
      mapping == _BoardFenMapping.reversed;
}

List<_BoardFenMapping> _orderedSupportedPhysicalBoardMappings(
  _BoardFenMapping preferredMapping,
) {
  return <_BoardFenMapping>{
    if (_isSupportedPhysicalBoardMapping(preferredMapping)) preferredMapping,
    ..._supportedPhysicalBoardMappings,
  }.toList(growable: false);
}

String _applyBoardFenMapping(String boardFen, _BoardFenMapping mapping) {
  return mapPhysicalBoardFen(boardFen, mapping);
}

List<String>? _expandBoardFen(String boardFen) {
  final expanded = <String>[];
  final ranks = _boardOnlyFen(boardFen).split('/');
  if (ranks.length != 8) return null;
  for (final rank in ranks) {
    for (final char in rank.characters) {
      final empty = int.tryParse(char);
      if (empty != null) {
        expanded.addAll(List<String>.filled(empty, ''));
      } else {
        expanded.add(char);
      }
    }
  }
  return expanded.length == 64 ? expanded : null;
}

class _GameRecordSaveSnapshot {
  const _GameRecordSaveSnapshot({
    required this.saveKey,
    required this.pgn,
    required this.whiteName,
    required this.blackName,
    required this.playTime,
    required this.playMode,
    required this.winId,
    required this.gameStatus,
    required this.gameStep,
    required this.resultToken,
    required this.savedAt,
    required this.metadata,
  });

  final String saveKey;
  final String pgn;
  final String whiteName;
  final String blackName;
  final String playTime;
  final String playMode;
  final int winId;
  final int gameStatus;
  final int gameStep;
  final String resultToken;
  final DateTime savedAt;
  final PgnSaveMetadata metadata;
}

class _GameRecordSaveOutcome {
  const _GameRecordSaveOutcome({
    required this.status,
    required this.saveKey,
    this.pgnId,
    this.shareId,
    this.savedLocally = false,
  });

  final ApiStatus status;
  final String saveKey;
  final int? pgnId;
  final String? shareId;
  final bool savedLocally;
}

class _QueuedGameRecordSave {
  _QueuedGameRecordSave(
    this.snapshot,
    Completer<_GameRecordSaveOutcome> completer,
  ) : completers = [completer];

  _GameRecordSaveSnapshot snapshot;
  final List<Completer<_GameRecordSaveOutcome>> completers;
}

class _GameRecordSaveCoordinator {
  _GameRecordSaveCoordinator({
    required this.service,
    required this.ownerUserId,
    required int? initialPgnId,
    required String? initialShareId,
    required this.onSaved,
  })  : _pgnId = initialPgnId,
        _shareId = initialShareId;

  final GameRecordSaveService service;
  final int? ownerUserId;
  final FutureOr<void> Function(GameRecord record)? onSaved;
  int? _pgnId;
  String? _shareId;
  String? _lastSavedSaveKey;
  _QueuedGameRecordSave? _active;
  _QueuedGameRecordSave? _pending;

  Future<void> get idle async {
    while (_active != null) {
      await _active!.completers.last.future;
    }
  }

  Future<_GameRecordSaveOutcome> save(_GameRecordSaveSnapshot snapshot) {
    if (_lastSavedSaveKey == snapshot.saveKey) {
      return Future.value(_GameRecordSaveOutcome(
        status: const ApiStatus.success(),
        saveKey: snapshot.saveKey,
        pgnId: _pgnId,
        shareId: _shareId,
      ));
    }
    final completer = Completer<_GameRecordSaveOutcome>();
    final active = _active;
    if (active == null) {
      final queued = _QueuedGameRecordSave(snapshot, completer);
      _active = queued;
      unawaited(_drain(queued));
      return completer.future;
    }
    if (active.snapshot.saveKey == snapshot.saveKey) {
      active.completers.add(completer);
      return completer.future;
    }
    final pending = _pending;
    if (pending == null) {
      _pending = _QueuedGameRecordSave(snapshot, completer);
    } else {
      pending.snapshot = snapshot;
      pending.completers.add(completer);
    }
    return completer.future;
  }

  Future<void> _drain(_QueuedGameRecordSave queued) async {
    var current = queued;
    while (true) {
      _GameRecordSaveOutcome outcome;
      try {
        outcome = await _persist(current.snapshot);
      } catch (_) {
        outcome = _GameRecordSaveOutcome(
          status: const ApiStatus.network('Game record upload failed.'),
          saveKey: current.snapshot.saveKey,
          pgnId: _pgnId,
          shareId: _shareId,
        );
      }
      if (outcome.status.isSuccess) {
        _lastSavedSaveKey = outcome.saveKey;
      }
      for (final completer in current.completers) {
        if (!completer.isCompleted) completer.complete(outcome);
      }
      final next = _pending;
      if (next == null) {
        _active = null;
        return;
      }
      _pending = null;
      _active = next;
      current = next;
    }
  }

  Future<_GameRecordSaveOutcome> _persist(
    _GameRecordSaveSnapshot snapshot,
  ) async {
    final result = await service.saveLive(
      GameRecordDraft(
        id: snapshot.metadata.clientGameId!,
        pgn: snapshot.pgn,
        whiteName: snapshot.whiteName,
        blackName: snapshot.blackName,
        playTime: snapshot.playTime,
        playMode: snapshot.playMode,
        winId: snapshot.winId,
        gameStatus: snapshot.gameStatus,
        gameStep: snapshot.gameStep,
        result: snapshot.resultToken,
        savedAt: snapshot.savedAt,
        metadata: snapshot.metadata,
      ),
      ownerUserId: ownerUserId,
      pgnId: _pgnId,
      shareId: _shareId,
    );
    final record = result.record;
    if (record != null) {
      _pgnId = record.pgnId ?? _pgnId;
      _shareId = record.shareId ?? _shareId;
      if (!result.savedLocally && record.pgnId != null) {
        unawaited(GameRecordRepository(apiClient: service.apiClient)
            .invalidateRecordPgn(record.pgnId!));
      }
      // Persistence does not depend on the old game screen remaining mounted.
      unawaited(_notify(record));
    }
    return _GameRecordSaveOutcome(
      status: result.status,
      saveKey: snapshot.saveKey,
      pgnId: _pgnId,
      shareId: _shareId,
      savedLocally: result.savedLocally,
    );
  }

  Future<void> _notify(GameRecord record) async {
    try {
      await onSaved?.call(record);
    } catch (_) {}
  }
}

class _ExitConfirmActions extends StatelessWidget {
  const _ExitConfirmActions({
    required this.onContinue,
    required this.onLeave,
    required this.onResignAndExit,
  });

  final VoidCallback onContinue;
  final VoidCallback onLeave;
  final VoidCallback onResignAndExit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final continueButton = OutlinedButton(
      onPressed: onContinue,
      child: const Text(
        'Continue game',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        softWrap: true,
        textAlign: TextAlign.center,
      ),
    );
    final leaveButton = OutlinedButton(
      onPressed: onLeave,
      child: const Text(
        'Leave for now',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        softWrap: true,
        textAlign: TextAlign.center,
      ),
    );
    final resignButton = FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.error,
        foregroundColor: scheme.onError,
      ),
      onPressed: onResignAndExit,
      child: const Text(
        'Resign and exit',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        softWrap: true,
        textAlign: TextAlign.center,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 430) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              continueButton,
              const SizedBox(height: 8),
              leaveButton,
              const SizedBox(height: 8),
              resignButton,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: continueButton),
            const SizedBox(width: 10),
            Expanded(child: leaveButton),
            const SizedBox(width: 10),
            Expanded(child: resignButton),
          ],
        );
      },
    );
  }
}

enum _GameOverResult {
  victory,
  defeat,
  draw;

  String get keyName => switch (this) {
        _GameOverResult.victory => 'victory',
        _GameOverResult.defeat => 'defeat',
        _GameOverResult.draw => 'draw',
      };

  String get label => switch (this) {
        _GameOverResult.victory => 'Victory',
        _GameOverResult.defeat => 'Defeat',
        _GameOverResult.draw => 'Draw',
      };

  String get asset => switch (this) {
        _GameOverResult.victory => 'assets/images/game_over_victory.svg',
        _GameOverResult.defeat => 'assets/images/game_over_defeat.svg',
        _GameOverResult.draw => 'assets/images/game_over_draw.svg',
      };

  IconData get icon => switch (this) {
        _GameOverResult.victory => Icons.emoji_events_rounded,
        _GameOverResult.defeat => Icons.flag_rounded,
        _GameOverResult.draw => Icons.balance_rounded,
      };

  Color color(ChessnutThemeTokens tokens) => switch (this) {
        _GameOverResult.victory => tokens.success,
        _GameOverResult.defeat => tokens.danger,
        _GameOverResult.draw => tokens.info,
      };

  ChessnutCelebrationResult get celebration => switch (this) {
        _GameOverResult.victory => ChessnutCelebrationResult.victory,
        _GameOverResult.defeat => ChessnutCelebrationResult.defeat,
        _GameOverResult.draw => ChessnutCelebrationResult.draw,
      };
}

class _GameOverResultDialog extends StatefulWidget {
  const _GameOverResultDialog({
    required this.result,
    required this.resultText,
    required this.careerRatingDelta,
    required this.onPlayAgain,
    required this.onAnalyze,
    required this.onBotSettings,
    required this.settingsLabel,
    required this.onMainMenu,
    this.androidPhoneDevice = false,
  });

  final _GameOverResult result;
  final String resultText;
  final CareerRatingDelta? careerRatingDelta;
  final VoidCallback onPlayAgain;
  final VoidCallback onAnalyze;
  final VoidCallback onBotSettings;
  final String settingsLabel;
  final VoidCallback onMainMenu;
  final bool androidPhoneDevice;

  @override
  State<_GameOverResultDialog> createState() => _GameOverResultDialogState();
}

class _GameOverResultDialogState extends State<_GameOverResultDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tokens = ChessnutTheme.tokensOf(context);
      final viewport = MediaQuery.sizeOf(context);
      final androidPhoneLandscape =
          widget.androidPhoneDevice && viewport.width > viewport.height;
      if (MediaQuery.disableAnimationsOf(context) ||
          !tokens.visualEffectsEnabled ||
          androidPhoneLandscape ||
          isCompactLandscapeDevice(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ChessnutTheme.tokensOf(context);
    final accent = widget.result.color(tokens);
    final viewport = MediaQuery.sizeOf(context);
    final androidPhoneLandscape =
        widget.androidPhoneDevice && viewport.width > viewport.height;
    final compactLandscape =
        androidPhoneLandscape || isCompactLandscapeDevice(context);
    final resultImage = ScaleTransition(
      scale: _scale,
      child: _GameOverResultImage(
        key: ValueKey('game-over-result-${widget.result.keyName}'),
        result: widget.result,
        accent: accent,
        height: compactLandscape ? 118 : 142,
      ),
    );
    final celebration = ChessnutGameResultCelebration(
      result: widget.result.celebration,
      height: compactLandscape ? 48 : 70,
    );
    final resultLabel = Text(
      widget.result.label,
      textAlign: compactLandscape ? TextAlign.left : TextAlign.center,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: accent,
          ),
    );
    final careerDelta = widget.careerRatingDelta == null
        ? null
        : _CareerRatingDeltaBadge(delta: widget.careerRatingDelta!);
    final actions = _GameOverResultActions(
      onPlayAgain: widget.onPlayAgain,
      onAnalyze: widget.onAnalyze,
      onBotSettings: widget.onBotSettings,
      settingsLabel: widget.settingsLabel,
      onMainMenu: widget.onMainMenu,
      compactLandscape: compactLandscape,
    );
    return AppDialogShell(
      icon: widget.result.icon,
      title: 'Game over',
      subtitle: widget.resultText,
      compactLandscapeOverride: androidPhoneLandscape,
      child: FadeTransition(
        opacity: _fade,
        child: compactLandscape
            ? Row(
                key: const ValueKey('game-over-compact-landscape'),
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        resultImage,
                        const SizedBox(height: 6),
                        celebration,
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        resultLabel,
                        if (careerDelta != null) ...[
                          const SizedBox(height: 10),
                          careerDelta,
                        ],
                        const SizedBox(height: 10),
                        actions,
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  resultImage,
                  const SizedBox(height: 8),
                  celebration,
                  const SizedBox(height: 8),
                  resultLabel,
                  if (careerDelta != null) ...[
                    const SizedBox(height: 10),
                    Center(child: careerDelta),
                  ],
                  const SizedBox(height: 14),
                  actions,
                ],
              ),
      ),
    );
  }
}

class _CareerRatingDeltaBadge extends StatelessWidget {
  const _CareerRatingDeltaBadge({required this.delta});

  final CareerRatingDelta delta;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = ChessnutTheme.tokensOf(context);
    final color = delta.isGain
        ? tokens.success
        : delta.isLoss
            ? tokens.danger
            : tokens.info;
    final icon = delta.isGain
        ? Icons.trending_up_rounded
        : delta.isLoss
            ? Icons.trending_down_rounded
            : Icons.remove_rounded;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: Transform.scale(
              scale: 0.92 + value * 0.08,
              child: child,
            ),
          ),
        );
      },
      child: Container(
        key: const ValueKey('career-game-over-rating-delta'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.32)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.16),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 7),
            Text(
              delta.label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${delta.after}',
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.72),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameOverResultActions extends StatelessWidget {
  const _GameOverResultActions({
    required this.onPlayAgain,
    required this.onAnalyze,
    required this.onBotSettings,
    required this.settingsLabel,
    required this.onMainMenu,
    required this.compactLandscape,
  });

  final VoidCallback onPlayAgain;
  final VoidCallback onAnalyze;
  final VoidCallback onBotSettings;
  final String settingsLabel;
  final VoidCallback onMainMenu;
  final bool compactLandscape;

  @override
  Widget build(BuildContext context) {
    final compactActionStyle = compactLandscape
        ? const ButtonStyle(
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            minimumSize: WidgetStatePropertyAll(Size.zero),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          )
        : null;
    final playAgain = FilledButton.icon(
      onPressed: onPlayAgain,
      style: compactActionStyle,
      icon: const Icon(Icons.replay_rounded),
      label: const _AdaptiveActionLabel('Play again'),
    );
    final analyze = OutlinedButton.icon(
      onPressed: onAnalyze,
      style: compactActionStyle,
      icon: const Icon(Icons.analytics_rounded),
      label: const _AdaptiveActionLabel('Analyze game'),
    );
    final mainMenu = OutlinedButton.icon(
      onPressed: onMainMenu,
      style: compactActionStyle,
      icon: const Icon(Icons.home_rounded),
      label: const _AdaptiveActionLabel('Main menu'),
    );
    final botSettings = OutlinedButton.icon(
      onPressed: onBotSettings,
      style: compactActionStyle,
      icon: const Icon(Icons.tune_rounded),
      label: _AdaptiveActionLabel(settingsLabel),
    );
    if (compactLandscape) {
      return LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 8.0;
          final maxWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final columns = maxWidth >= 360 ? 2 : 1;
          final buttonWidth = (maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final button in [playAgain, analyze, mainMenu, botSettings])
                SizedBox(width: buttonWidth, height: 58, child: button),
            ],
          );
        },
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        playAgain,
        const SizedBox(height: 8),
        analyze,
        const SizedBox(height: 8),
        mainMenu,
        const SizedBox(height: 8),
        botSettings,
      ],
    );
  }
}

class _AdaptiveActionLabel extends StatelessWidget {
  const _AdaptiveActionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _GameOverResultImage extends StatelessWidget {
  const _GameOverResultImage({
    required this.result,
    required this.accent,
    this.height = 142,
    super.key,
  });

  final _GameOverResult result;
  final Color accent;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${result.label} result image',
      image: true,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.30)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SvgPicture.asset(result.asset, fit: BoxFit.cover),
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(result.icon, color: accent, size: 30),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalTargetSelection {
  const _LegalTargetSelection({
    required this.sourceSquare,
    required this.targetSquares,
  });

  final String sourceSquare;
  final Set<String> targetSquares;
}

class _PhysicalLiftLegalTargetSelection {
  const _PhysicalLiftLegalTargetSelection({
    required this.mapping,
    required this.sourceSquare,
    required this.targetSquares,
  });

  final _BoardFenMapping mapping;
  final String sourceSquare;
  final Set<String> targetSquares;
}

class _MoveSnapshot {
  const _MoveSnapshot({required this.fen, required this.lastMove});

  final String fen;
  final List<String> lastMove;
}

class _DisplayClock {
  const _DisplayClock({
    required this.name,
    required this.source,
    required this.seconds,
    required this.active,
    this.rating,
  });

  final String name;
  final String? rating;
  final String source;
  final int seconds;
  final bool active;
}

class _ResumedGameState {
  const _ResumedGameState({
    required this.history,
    this.whiteSeconds,
    this.blackSeconds,
    this.recordId,
  });

  final GameMoveHistory history;
  final int? whiteSeconds;
  final int? blackSeconds;
  final String? recordId;
}

class _GameBoardStage extends StatelessWidget {
  const _GameBoardStage({
    required this.size,
    required this.child,
    required this.showScoreBar,
    required this.scoreBarWidth,
    required this.evalLabel,
  });

  final double size;
  final Widget child;
  final bool showScoreBar;
  final double scoreBarWidth;
  final String evalLabel;

  @override
  Widget build(BuildContext context) {
    if (!showScoreBar) {
      return SizedBox.square(dimension: size, child: child);
    }

    return SizedBox(
      width: size + scoreBarWidth,
      height: size,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            key: const ValueKey('game-score-bar'),
            width: scoreBarWidth,
            child: _GameScoreBar(evalLabel: evalLabel),
          ),
          SizedBox.square(dimension: size, child: child),
        ],
      ),
    );
  }
}

class _GameScoreBar extends StatelessWidget {
  const _GameScoreBar({required this.evalLabel});

  final String evalLabel;

  @override
  Widget build(BuildContext context) {
    final normalized = _normalizedEval(evalLabel);
    final scheme = Theme.of(context).colorScheme;
    const labelHeight = 58.0;
    return Tooltip(
      message: 'Bot evaluation',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final boundaryY = height.isFinite ? height * (1 - normalized) : 0.0;
          final labelTop = height.isFinite
              ? (boundaryY - labelHeight / 2)
                  .clamp(0.0, (height - labelHeight).clamp(0.0, height))
                  .toDouble()
              : 0.0;
          return Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: 14,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(color: const Color(0xFF101827)),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.5, end: normalized),
                          duration: const Duration(milliseconds: 360),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) => Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: value,
                              widthFactor: 1,
                              child: child,
                            ),
                          ),
                          child: Container(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.92)
                                    : const Color(0xFFF8FAFC),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutCubic,
                top: labelTop,
                left: 6,
                right: 6,
                height: labelHeight,
                child: SizedBox(
                  key: const ValueKey('game-score-label'),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.66),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: RotatedBox(
                        key: const ValueKey('game-score-label-vertical'),
                        quarterTurns: 3,
                        child: Text(
                          evalLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: 10,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

double _normalizedEval(String label) {
  if (label.startsWith('#+')) return 1.0;
  if (label.startsWith('#-')) return 0.0;
  final cleaned = label.replaceAll('+', '').trim();
  final value = double.tryParse(cleaned);
  if (value == null) return 0.5;
  return ((value + 4) / 8).clamp(0.06, 0.94).toDouble();
}

class _CompactLandscapeGameRoom extends StatelessWidget {
  const _CompactLandscapeGameRoom({
    super.key,
    required this.spacing,
    required this.title,
    required this.onBack,
    required this.board,
    required this.statusCapsules,
    required this.opponentClock,
    required this.playerClock,
    required this.sanStrip,
    required this.actions,
    this.statusPinnedTopRight = false,
    this.phoneCompact = false,
  });

  final double spacing;
  final String title;
  final VoidCallback onBack;
  final Widget board;
  final Widget statusCapsules;
  final Widget opponentClock;
  final Widget playerClock;
  final Widget sanStrip;
  final Widget actions;
  final bool statusPinnedTopRight;
  final bool phoneCompact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fallbackHeight = MediaQuery.sizeOf(context).height -
            MediaQuery.paddingOf(context).vertical;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : fallbackHeight;
        final height = phoneCompact
            ? availableHeight.clamp(0.0, 480.0).toDouble()
            : (availableHeight - spacing * 2).clamp(390.0, 480.0).toDouble();
        final layoutWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final boardWidth = phoneCompact
            ? (layoutWidth * 0.40).clamp(0.0, height + 30).toDouble()
            : height + 30;
        final playerWidth = phoneCompact
            ? (layoutWidth * 0.24).clamp(150.0, 190.0).toDouble()
            : 262.0;
        final touchTarget = _gameRoomTouchTarget(context);
        final content = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: playerWidth,
              child: SectionColumn(
                spacing: spacing,
                children: [
                  _CompactGameHeader(
                    title: title,
                    onBack: onBack,
                    scaleTitleToFit: statusPinnedTopRight,
                  ),
                  Expanded(child: opponentClock),
                  Expanded(child: playerClock),
                ],
              ),
            ),
            SizedBox(width: spacing * 1.5),
            SizedBox(width: boardWidth, child: board),
            SizedBox(width: spacing),
            Expanded(
              flex: 4,
              child: SectionColumn(
                spacing: spacing,
                children: [
                  if (statusPinnedTopRight)
                    SizedBox(height: touchTarget)
                  else
                    Align(
                      alignment: Alignment.centerRight,
                      child: statusCapsules,
                    ),
                  Expanded(child: sanStrip),
                  actions,
                ],
              ),
            ),
          ],
        );
        return SizedBox(
          height: height,
          child: statusPinnedTopRight
              ? Stack(
                  children: [
                    Positioned.fill(child: content),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: SizedBox(
                        key: const ValueKey(
                          'ios-bot-board-status-top-right',
                        ),
                        height: touchTarget,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: statusCapsules,
                        ),
                      ),
                    ),
                  ],
                )
              : content,
        );
      },
    );
  }
}

class _ClockOnlyGameRoom extends StatelessWidget {
  const _ClockOnlyGameRoom({
    required this.board,
    required this.blackClock,
    required this.whiteClock,
    required this.sideToMove,
    required this.gameOver,
    required this.onBack,
    required this.onSettings,
    required this.voiceMovesShortcut,
    this.onEditBlackName,
    this.onEditWhiteName,
    this.onResign,
    this.onDraw,
    this.onHint,
    this.showControls = true,
    this.showBotControls = false,
    this.botPlayerSide,
    this.onFlip,
    this.onNamesFlip,
    this.namesFlipped = false,
    this.onHideBoard,
    this.playerNameFontSize = 84,
    required this.turnLabelForSide,
    required this.qualityLightsForSide,
    required this.onQualityLightsChanged,
  });

  final Widget board;
  final _DisplayClock blackClock;
  final _DisplayClock whiteClock;
  final dc.Side sideToMove;
  final bool gameOver;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final Widget? voiceMovesShortcut;
  final VoidCallback? onEditBlackName;
  final VoidCallback? onEditWhiteName;
  final ValueChanged<dc.Side>? onResign;
  final ValueChanged<dc.Side>? onDraw;
  final ValueChanged<dc.Side>? onHint;
  final bool showControls;
  final bool showBotControls;
  final dc.Side? botPlayerSide;
  final VoidCallback? onFlip;
  final VoidCallback? onNamesFlip;
  final bool namesFlipped;
  final VoidCallback? onHideBoard;
  final double playerNameFontSize;
  final String Function(dc.Side side) turnLabelForSide;
  final bool Function(dc.Side side) qualityLightsForSide;
  final void Function(dc.Side side, bool value) onQualityLightsChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Keep the board flush with the information panels so it can use
          // the maximum available width on the Chessnut Clock.
          // The clock-only OTB layout has no PGN panel, so give the board the
          // space that panel would otherwise consume while keeping the side
          // information panels anchored to its edges.
          final clockBoardSize =
              (constraints.maxHeight + 70).clamp(180.0, 500.0).toDouble();
          final disabled = gameOver;
          Widget controls({required dc.Side side}) {
            final sideKey = side.name;
            Widget actionButton({
              required String keyName,
              required String tooltip,
              required IconData icon,
              required VoidCallback? onPressed,
            }) {
              return IconButton.filledTonal(
                key: ValueKey('clock-only-$sideKey-$keyName'),
                tooltip: tooltip,
                onPressed: onPressed,
                iconSize: 36,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 72,
                  height: 72,
                ),
                icon: Icon(icon),
              );
            }

            if (!showControls) {
              if (!showBotControls || botPlayerSide != side) {
                return const SizedBox.shrink();
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  actionButton(
                    keyName: 'flip',
                    tooltip: 'Flip board',
                    icon: Icons.screen_rotation_alt_rounded,
                    onPressed: disabled ? null : onFlip,
                  ),
                  const SizedBox(width: 8),
                  actionButton(
                    keyName: 'flip-names',
                    tooltip: 'Swap player sides',
                    icon: Icons.swap_horiz_rounded,
                    onPressed: disabled ? null : onNamesFlip,
                  ),
                  const SizedBox(width: 8),
                  actionButton(
                    keyName: 'hint',
                    tooltip: 'Hint',
                    icon: Icons.lightbulb_outline_rounded,
                    onPressed: disabled || sideToMove != side || onHint == null
                        ? null
                        : () => onHint!(side),
                  ),
                ],
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      actionButton(
                        keyName: 'draw',
                        tooltip: 'Offer draw',
                        icon: Icons.handshake_rounded,
                        onPressed: disabled || onDraw == null
                            ? null
                            : () => onDraw!(side),
                      ),
                      const SizedBox(width: 4),
                      actionButton(
                        keyName: 'resign',
                        tooltip: 'Resign',
                        icon: Icons.flag_rounded,
                        onPressed: disabled || onResign == null
                            ? null
                            : () => onResign!(side),
                      ),
                      const SizedBox(width: 4),
                      actionButton(
                        keyName: 'hint',
                        tooltip: 'Hint',
                        icon: Icons.lightbulb_outline_rounded,
                        onPressed:
                            disabled || sideToMove != side || onHint == null
                                ? null
                                : () => onHint!(side),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Evaluate',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Move quality lights',
                        child: SizedBox(
                          width: 78,
                          height: 60,
                          child: Transform.scale(
                            scale: 1.23,
                            child: Switch.adaptive(
                              key: ValueKey(
                                'clock-only-$sideKey-quality-lights',
                              ),
                              value: qualityLightsForSide(side),
                              onChanged: disabled
                                  ? null
                                  : (value) =>
                                      onQualityLightsChanged(side, value),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          Widget sidePanel({
            required _DisplayClock clock,
            required dc.Side side,
          }) {
            final sideKey = side.name;
            return Expanded(
              // Keep each side wide enough for its controls while giving the
              // center board most of the available Chessnut Clock width.
              flex: 3,
              child: LayoutBuilder(
                builder: (context, panelConstraints) {
                  final content = AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: clock.active
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: clock.active
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.72)
                            : Colors.transparent,
                        width: clock.active ? 2 : 0,
                      ),
                    ),
                    height: panelConstraints.maxHeight,
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: _ClockOnlyPlayerLabel(
                            label: clock.name,
                            active: clock.active,
                            onEdit: side == dc.Side.black
                                ? onEditBlackName
                                : onEditWhiteName,
                            fontSize: playerNameFontSize,
                            showTurnMarker: true,
                            turnLabel: turnLabelForSide(side),
                          ),
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: _ClockOnlyTime(
                            key: ValueKey('clock-only-$sideKey-clock'),
                            time: _formatClockValue(clock.seconds),
                          ),
                        ),
                        if (showControls ||
                            (showBotControls && botPlayerSide == side))
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: controls(side: side),
                          ),
                      ],
                    ),
                  );
                  return Align(
                    alignment: side == dc.Side.black
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: OverflowBox(
                      alignment: side == dc.Side.black
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      minWidth: 340,
                      maxWidth: 340,
                      minHeight: panelConstraints.maxHeight,
                      maxHeight: panelConstraints.maxHeight,
                      child: content,
                    ),
                  );
                },
              ),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 96,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        IconButton.filledTonal(
                          key: const ValueKey('clock-only-settings'),
                          tooltip: showBotControls ? 'More' : 'Settings',
                          onPressed: onSettings,
                          icon: Icon(showBotControls
                              ? Icons.more_horiz_rounded
                              : Icons.settings_rounded),
                        ),
                        if (voiceMovesShortcut != null) ...[
                          const SizedBox(height: 8),
                          voiceMovesShortcut!,
                        ],
                        if (onHideBoard != null) ...[
                          const SizedBox(height: 8),
                          IconButton.filledTonal(
                            key: const ValueKey('clock-only-hide-board'),
                            tooltip: 'Hide board',
                            onPressed: onHideBoard,
                            icon: const Icon(Icons.visibility_off_rounded),
                          ),
                        ],
                        const Spacer(),
                        IconButton.filledTonal(
                          key: const ValueKey('clock-only-back'),
                          tooltip: 'Back',
                          onPressed: onBack,
                          iconSize: 30,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (namesFlipped)
                sidePanel(clock: whiteClock, side: dc.Side.white)
              else
                sidePanel(clock: blackClock, side: dc.Side.black),
              SizedBox(
                width: clockBoardSize,
                child: OverflowBox(
                  minWidth: clockBoardSize,
                  maxWidth: clockBoardSize,
                  minHeight: clockBoardSize,
                  maxHeight: clockBoardSize,
                  child: board,
                ),
              ),
              if (namesFlipped)
                sidePanel(clock: blackClock, side: dc.Side.black)
              else
                sidePanel(clock: whiteClock, side: dc.Side.white),
            ],
          );
        },
      ),
    );
  }
}

class _ClockOnlyTime extends StatelessWidget {
  const _ClockOnlyTime({required this.time, this.color, super.key});

  final String time;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text(
          time,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 520,
            height: 0.95,
            fontWeight: FontWeight.w800,
            fontFamily: 'Leslie',
            color: color,
          ),
        ),
      ),
    );
  }
}

class _ClockOnlyPlayerLabel extends StatelessWidget {
  const _ClockOnlyPlayerLabel({
    required this.label,
    required this.active,
    required this.onEdit,
    this.fontSize = 84,
    this.showTurnMarker = false,
    this.turnLabel,
  });

  final String label;
  final bool active;
  final VoidCallback? onEdit;
  final double fontSize;
  final bool showTurnMarker;
  final String? turnLabel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showTurnMarker && active) ...[
                  Icon(
                    Icons.play_arrow_rounded,
                    key: const ValueKey('clock-only-turn-marker'),
                    size: (fontSize * 0.45).clamp(20.0, 38.0),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                      color: active
                          ? null
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            if (showTurnMarker && active && turnLabel != null) ...[
              const SizedBox(height: 2),
              Text(
                turnLabel!,
                key: const ValueKey('clock-only-turn-label'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: (fontSize * 0.28).clamp(16.0, 24.0),
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClockOnlyPlayerNameDialog extends StatelessWidget {
  const _ClockOnlyPlayerNameDialog({
    required this.isWhite,
    required this.controller,
    required this.autofocus,
  });

  final bool isWhite;
  final TextEditingController controller;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final compactLandscape = isCompactLandscapeDevice(context);
    final horizontalInset = compactLandscape ? 14.0 : 24.0;
    final verticalInset = compactLandscape ? 10.0 : 24.0;
    // Keep the dialog route's layout independent of the on-screen keyboard.
    // The keyboard should overlay the page instead of resizing the chess-clock
    // background behind this name editor.
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: CustomSingleChildLayout(
        delegate: _ClockOnlyPlayerNameDialogLayoutDelegate(
          keyboardInset: keyboardInset,
          horizontalInset: horizontalInset,
          verticalInset: verticalInset,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: compactLandscape ? 760 : 420,
          ),
          child: Material(
            color: Colors.transparent,
            child: GlassPanel(
              key: const ValueKey('clock-only-player-name-dialog'),
              borderRadius: 18,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isWhite
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 30,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isWhite ? 'Edit white name' : 'Edit black name',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: compactLandscape ? 62 : 64,
                      child: TextField(
                        key: ValueKey(
                          'clock-only-player-name-input-${isWhite ? 'White' : 'Black'}',
                        ),
                        controller: controller,
                        autofocus: autofocus,
                        maxLines: 1,
                        textInputAction: TextInputAction.done,
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          labelText: isWhite ? 'White name' : 'Black name',
                          prefixIcon: const Icon(Icons.person_rounded),
                        ),
                        onSubmitted: (value) =>
                            Navigator.of(context).pop(value),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.of(context).pop(controller.text),
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
    );
  }
}

class _ClockOnlyPlayerNameDialogLayoutDelegate
    extends SingleChildLayoutDelegate {
  const _ClockOnlyPlayerNameDialogLayoutDelegate({
    required this.keyboardInset,
    required this.horizontalInset,
    required this.verticalInset,
  });

  final double keyboardInset;
  final double horizontalInset;
  final double verticalInset;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxWidth = constraints.maxWidth.isFinite
        ? (constraints.maxWidth - horizontalInset * 2)
            .clamp(0.0, constraints.maxWidth)
            .toDouble()
        : constraints.maxWidth;
    final maxHeight = keyboardInset > 0
        ? (constraints.maxHeight - keyboardInset - verticalInset)
            .clamp(0.0, constraints.maxHeight)
            .toDouble()
        : (constraints.maxHeight - verticalInset * 2)
            .clamp(0.0, constraints.maxHeight)
            .toDouble();
    return constraints.loosen().copyWith(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final centeredY = (size.height - childSize.height) / 2;
    final keyboardLimitedY =
        size.height - keyboardInset - verticalInset - childSize.height;
    final targetY = keyboardInset > 0 && keyboardLimitedY < centeredY
        ? keyboardLimitedY
        : centeredY;
    final maxY = (size.height - childSize.height).clamp(0.0, size.height);
    return Offset(
      (size.width - childSize.width) / 2,
      targetY.clamp(0.0, maxY).toDouble(),
    );
  }

  @override
  bool shouldRelayout(_ClockOnlyPlayerNameDialogLayoutDelegate oldDelegate) {
    return keyboardInset != oldDelegate.keyboardInset ||
        horizontalInset != oldDelegate.horizontalInset ||
        verticalInset != oldDelegate.verticalInset;
  }
}

String _formatClockValue(int seconds) {
  final safe = seconds.clamp(0, 999999);
  final minutes = safe ~/ 60;
  final remainder = safe % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}

class _HiddenBoardGameRoom extends StatelessWidget {
  const _HiddenBoardGameRoom({
    required this.topClock,
    required this.bottomClock,
    required this.onEditTopName,
    required this.onEditBottomName,
    required this.onShowBoard,
    this.onMore,
    this.onHint,
    this.hintEnabled = false,
    this.onSettings,
    required this.isBotGame,
  });

  final _DisplayClock topClock;
  final _DisplayClock bottomClock;
  final VoidCallback? onEditTopName;
  final VoidCallback? onEditBottomName;
  final VoidCallback onShowBoard;
  final VoidCallback? onMore;
  final VoidCallback? onHint;
  final bool hintEnabled;
  final VoidCallback? onSettings;
  final bool isBotGame;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = constraints.maxWidth < 700;
        final topClockFacesOutward = vertical &&
            constraints.maxWidth < 600 &&
            !isBotGame &&
            !kIsWeb &&
            const {
              TargetPlatform.android,
              TargetPlatform.iOS,
            }.contains(defaultTargetPlatform);
        Widget clockCard({
          required _DisplayClock clock,
          required Color accent,
          required VoidCallback? onEdit,
          bool facesOutward = false,
        }) {
          return _HiddenBoardClockCard(
            clock: clock,
            // Bot turns use the same green accent for either side so the
            // active-turn indicator is consistent when the board is hidden.
            accent: isBotGame ? Theme.of(context).colorScheme.primary : accent,
            label: clock.name,
            onEdit: onEdit,
            facesOutward: facesOutward,
            enlarged: isBotGame,
            keyPrefix:
                isBotGame ? 'hidden-bot-clock' : 'windows-hidden-otb-clock',
          );
        }

        Widget actionButton({
          required Key key,
          required String tooltip,
          required IconData icon,
          required VoidCallback? onPressed,
        }) {
          return IconButton.filledTonal(
            key: key,
            tooltip: tooltip,
            onPressed: onPressed,
            iconSize: isBotGame ? 48 : null,
            constraints: isBotGame
                ? const BoxConstraints.tightFor(width: 96, height: 96)
                : null,
            icon: Icon(icon),
          );
        }

        final controls = isBotGame
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  actionButton(
                    key: const ValueKey('hidden-bot-show-board'),
                    tooltip: 'Show board',
                    onPressed: onShowBoard,
                    icon: Icons.visibility_rounded,
                  ),
                  if (onHint != null) ...[
                    const SizedBox(height: 16),
                    actionButton(
                      key: const ValueKey('hidden-bot-hint'),
                      tooltip: 'Hint',
                      onPressed: hintEnabled ? onHint : null,
                      icon: Icons.lightbulb_outline_rounded,
                    ),
                  ],
                  if (onSettings != null) ...[
                    const SizedBox(height: 16),
                    actionButton(
                      key: const ValueKey('hidden-bot-settings'),
                      tooltip: 'More',
                      onPressed: onSettings,
                      icon: Icons.more_horiz_rounded,
                    ),
                  ],
                ],
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    actionButton(
                      key: const ValueKey('windows-hidden-otb-show-board'),
                      tooltip: 'Show board',
                      onPressed: onShowBoard,
                      icon: Icons.visibility_rounded,
                    ),
                    if (onMore != null) ...[
                      const SizedBox(width: 16),
                      actionButton(
                        key: const ValueKey('windows-hidden-otb-more'),
                        tooltip: 'More',
                        onPressed: onMore,
                        icon: Icons.more_horiz_rounded,
                      ),
                    ],
                  ],
                ),
              );
        if (vertical) {
          return Column(
            key: ValueKey(
                isBotGame ? 'hidden-bot-room' : 'windows-hidden-otb-room'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: clockCard(
                  clock: topClock,
                  accent: Theme.of(context).colorScheme.onSurface,
                  onEdit: onEditTopName,
                  facesOutward: topClockFacesOutward,
                ),
              ),
              const SizedBox(height: 12),
              controls,
              const SizedBox(height: 12),
              Expanded(
                child: clockCard(
                  clock: bottomClock,
                  accent: Theme.of(context).colorScheme.primary,
                  onEdit: onEditBottomName,
                ),
              ),
            ],
          );
        }
        return Row(
          key: ValueKey(
              isBotGame ? 'hidden-bot-room' : 'windows-hidden-otb-room'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: clockCard(
                clock: topClock,
                accent: Theme.of(context).colorScheme.onSurface,
                onEdit: onEditTopName,
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(width: 116, child: Center(child: controls)),
            const SizedBox(width: 16),
            Expanded(
              child: clockCard(
                clock: bottomClock,
                accent: Theme.of(context).colorScheme.primary,
                onEdit: onEditBottomName,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HiddenBoardClockCard extends StatelessWidget {
  const _HiddenBoardClockCard({
    required this.clock,
    required this.accent,
    required this.label,
    required this.onEdit,
    required this.facesOutward,
    this.enlarged = false,
    required this.keyPrefix,
  });

  final _DisplayClock clock;
  final Color accent;
  final String label;
  final VoidCallback? onEdit;
  final bool facesOutward;
  final bool enlarged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      key: ValueKey('$keyPrefix-$label'),
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
      borderRadius: 18,
      tint: clock.active ? accent.withValues(alpha: 0.14) : null,
      child: RotatedBox(
        key: ValueKey('$keyPrefix-$label-orientation'),
        quarterTurns: facesOutward ? 2 : 0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: enlarged ? 56 : null,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                if (onEdit != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    key: ValueKey('windows-hidden-otb-edit-$label'),
                    tooltip: 'Edit $label name',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            enlarged
                ? _ClockOnlyTime(
                    key: ValueKey('$keyPrefix-$label-time'),
                    time: _formatClockValue(clock.seconds),
                    color: clock.active
                        ? Theme.of(context).colorScheme.primary
                        : scheme.onSurface,
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _formatHiddenClock(clock.seconds),
                      maxLines: 1,
                      style: TextStyle(
                        color: clock.active ? accent : scheme.onSurface,
                        fontSize: 112,
                        height: 0.9,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

String _formatHiddenClock(int seconds) {
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  return '$minutes:${rest.toString().padLeft(2, '0')}';
}

class _CompactLandscapeLichessRoom extends StatelessWidget {
  const _CompactLandscapeLichessRoom({
    required this.spacing,
    required this.title,
    required this.onBack,
    required this.board,
    required this.statusCapsules,
    required this.topClock,
    required this.bottomClock,
    required this.sanStrip,
    required this.actions,
  });

  final double spacing;
  final String title;
  final VoidCallback onBack;
  final Widget board;
  final Widget statusCapsules;
  final Widget topClock;
  final Widget bottomClock;
  final Widget sanStrip;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fallbackHeight = MediaQuery.sizeOf(context).height -
            MediaQuery.paddingOf(context).vertical;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : fallbackHeight;
        final height = availableHeight.clamp(0.0, 480.0).toDouble();
        final headerHeight = _gameRoomTouchTarget(context);
        final bodyHeight =
            (height - headerHeight - spacing).clamp(180.0, 430.0).toDouble();
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final maxBoardWidth = bodyHeight + 18;
        final minBoardWidth = maxBoardWidth < 320.0 ? maxBoardWidth : 320.0;
        final boardWidth =
            (width * 0.40).clamp(minBoardWidth, maxBoardWidth).toDouble();
        final playerWidth = (width * 0.22).clamp(180.0, 240.0).toDouble();
        return SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CompactGameHeader(
                title: title,
                onBack: onBack,
                trailing: statusCapsules,
              ),
              SizedBox(height: spacing),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: boardWidth, child: board),
                    SizedBox(width: spacing),
                    SizedBox(
                      width: playerWidth,
                      child: SectionColumn(
                        spacing: spacing,
                        children: [
                          Expanded(child: topClock),
                          Expanded(child: bottomClock),
                        ],
                      ),
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      child: SectionColumn(
                        spacing: spacing,
                        children: [
                          Expanded(child: sanStrip),
                          actions,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GameStatusCapsules extends StatelessWidget {
  const _GameStatusCapsules({
    required this.mode,
    required this.boardState,
    required this.latency,
    this.compact = false,
    this.trailing,
    this.hidePhysicalBoardConnectionUi = false,
  });

  final GameLaunchMode mode;
  final PhysicalBoardConnectionState boardState;
  final NetworkLatencySnapshot? latency;
  final bool compact;
  final Widget? trailing;
  final bool hidePhysicalBoardConnectionUi;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('game-room-status-capsules'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (mode == GameLaunchMode.lichess ||
            mode == GameLaunchMode.chesscom) ...[
          NetworkLatencyBadge(snapshot: latency),
          if (!hidePhysicalBoardConnectionUi) SizedBox(width: compact ? 4 : 6),
        ],
        if (!hidePhysicalBoardConnectionUi)
          BoardConnectionBadge(
            state: boardState,
            compact: compact,
          ),
        if (trailing != null) ...[
          SizedBox(width: compact ? 4 : 6),
          trailing!,
        ],
      ],
    );
  }
}

class _IosBotGameHeader extends StatelessWidget {
  const _IosBotGameHeader({
    required this.title,
    required this.onBack,
    required this.trailing,
  });

  final String title;
  final VoidCallback onBack;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final touchTarget = _gameRoomTouchTarget(context);
    final width = MediaQuery.sizeOf(context).width;
    final trailingWidth = (width * 0.4).clamp(120.0, 180.0).toDouble();
    return SizedBox(
      key: const ValueKey('ios-bot-game-header'),
      height: touchTarget,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: SizedBox(
              width: touchTarget,
              height: touchTarget,
              child: IconButton.filledTonal(
                tooltip: 'Leave game',
                padding: EdgeInsets.zero,
                iconSize: 23,
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
          ),
          Positioned(
            left: touchTarget + 10,
            right: trailingWidth + 8,
            top: 0,
            bottom: 0,
            child: FittedBox(
              key: const ValueKey('ios-bot-game-title-fit'),
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: SizedBox(
              key: const ValueKey('ios-bot-board-status-top-right'),
              width: trailingWidth,
              height: touchTarget,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: trailing,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactGameHeader extends StatelessWidget {
  const _CompactGameHeader({
    required this.title,
    required this.onBack,
    this.trailing,
    this.scaleTitleToFit = false,
  });

  final String title;
  final VoidCallback onBack;
  final Widget? trailing;
  final bool scaleTitleToFit;

  @override
  Widget build(BuildContext context) {
    final touchTarget = _gameRoomTouchTarget(context);
    return SizedBox(
      key: const ValueKey('game-compact-header'),
      height: touchTarget,
      child: Row(
        children: [
          SizedBox(
            width: touchTarget,
            height: touchTarget,
            child: IconButton.filledTonal(
              key: const ValueKey('game-compact-back-button'),
              padding: EdgeInsets.zero,
              iconSize: 23,
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: scaleTitleToFit
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  )
                : Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.48,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: trailing!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GameRoomCopy {
  const _GameRoomCopy({
    required this.title,
    required this.subtitle,
    required this.opponent,
    required this.opponentSource,
    required this.playerSource,
    required this.turn,
    required this.eval,
  });

  final String title;
  final String subtitle;
  final String opponent;
  final String opponentSource;
  final String playerSource;
  final String turn;
  final String eval;

  factory _GameRoomCopy.fromMode(
    GameLaunchMode mode, {
    OtbGameConfig otbConfig = const OtbGameConfig(),
  }) {
    switch (mode) {
      case GameLaunchMode.bot:
        return const _GameRoomCopy(
          title: 'Maia 1500 / 10+5',
          subtitle: 'Bot game room',
          opponent: 'Maia 1500',
          opponentSource: 'Human-like engine / +0.4',
          playerSource: 'White to move / coach available',
          turn: 'White to move',
          eval: '+0.4',
        );
      case GameLaunchMode.chesscom:
        return const _GameRoomCopy(
          title: 'Chess.com 10+5',
          subtitle: 'WebView mirrored room',
          opponent: 'Chess.com player',
          opponentSource: 'WebView control / +0.4',
          playerSource: 'White to move / board synced',
          turn: 'White to move',
          eval: '+0.4',
        );
      case GameLaunchMode.otb:
        return _GameRoomCopy(
          title: 'OTB Game ${otbConfig.timeLabel}',
          subtitle: 'Physical board room',
          opponent: 'Opponent',
          opponentSource:
              'Face-to-face / ${otbConfig.timeLabel} / +${otbConfig.incrementSeconds}',
          playerSource: 'White to move / pieces detected',
          turn: 'White to move',
          eval: '--',
        );
      case GameLaunchMode.lichess:
        return const _GameRoomCopy(
          title: 'Lichess 10+5',
          subtitle: 'Native game room',
          opponent: 'nightbishop',
          opponentSource: 'Lichess / +0.4',
          playerSource: 'White to move / board synced',
          turn: 'White to move',
          eval: '+0.4',
        );
      case GameLaunchMode.clock:
        return const _GameRoomCopy(
          title: 'Chess Clock',
          subtitle: 'OTB clock mode',
          opponent: 'Black',
          opponentSource: 'Board connected / PGN recording',
          playerSource: 'White to move / clock mode',
          turn: 'White to move',
          eval: '--',
        );
    }
  }

  factory _GameRoomCopy.fromBotConfig(BotGameConfig config,
      {String? opponentName}) {
    return _GameRoomCopy(
      title: config.title,
      subtitle: config.subtitle,
      opponent: opponentName ?? config.opponent,
      opponentSource: config.opponentSource,
      playerSource: config.playerSource,
      turn: config.turn,
      eval: config.eval,
    );
  }
}

class _LichessGameInfoLine extends StatelessWidget {
  const _LichessGameInfoLine({
    required this.timeLabel,
    required this.rated,
  });

  final String timeLabel;
  final bool rated;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        );

    Widget detail({
      required Key key,
      required IconData icon,
      required String label,
    }) {
      return Row(
        key: key,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.secondary),
          const SizedBox(width: 4),
          Text(label, maxLines: 1, style: style),
        ],
      );
    }

    final ratingLabel = rated ? 'Rated' : 'Casual';
    return Semantics(
      key: const ValueKey('lichess-game-info'),
      label: '$timeLabel, $ratingLabel',
      child: SizedBox(
        height: 24,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            detail(
              key: const ValueKey('lichess-game-time-control'),
              icon: Icons.schedule_rounded,
              label: timeLabel,
            ),
            const SizedBox(width: 10),
            Container(
              width: 1,
              height: 13,
              color: scheme.outlineVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 10),
            detail(
              key: const ValueKey('lichess-game-rating-mode'),
              icon:
                  rated ? Icons.leaderboard_rounded : Icons.handshake_outlined,
              label: ratingLabel,
            ),
          ],
        ),
      ),
    );
  }
}

class _SanStrip extends StatefulWidget {
  const _SanStrip({
    required this.moves,
    required this.startFen,
    required this.currentPly,
    required this.onSelectPly,
    this.compactLandscape = false,
  });

  final List<String> moves;
  final String startFen;
  final int currentPly;
  final ValueChanged<int> onSelectPly;
  final bool compactLandscape;

  @override
  State<_SanStrip> createState() => _SanStripState();
}

class _SanStripState extends State<_SanStrip> {
  final ScrollController _scrollController = ScrollController();

  bool get _startsWithBlack {
    final fields = widget.startFen.trim().split(RegExp(r'\s+'));
    return fields.length > 1 && fields[1] == 'b';
  }

  int get _startMoveNumber {
    final fields = widget.startFen.trim().split(RegExp(r'\s+'));
    if (fields.length <= 5) return 1;
    return (int.tryParse(fields[5]) ?? 1).clamp(1, 999999);
  }

  @override
  void initState() {
    super.initState();
    _scheduleScrollToCurrent();
  }

  @override
  void didUpdateWidget(covariant _SanStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPly != widget.currentPly ||
        oldWidget.moves.length != widget.moves.length) {
      _scheduleScrollToCurrent();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleScrollToCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_scrollController.hasClients ||
          widget.moves.isEmpty ||
          widget.currentPly != widget.moves.length) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final textColor =
        Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.76);
    if (widget.moves.isEmpty && !widget.compactLandscape) {
      return GlassPanel(
        key: const ValueKey('game-pgn-strip'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        borderRadius: 12,
        child: Row(
          children: [
            Icon(
              Icons.notes_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Start position',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
              ),
            ),
          ],
        ),
      );
    }
    return GlassPanel(
      key: const ValueKey('game-pgn-strip'),
      padding: EdgeInsets.symmetric(
        horizontal: widget.compactLandscape ? 9 : 12,
        vertical: widget.compactLandscape ? 6 : 8,
      ),
      borderRadius: 12,
      child: !widget.compactLandscape && widget.moves.isNotEmpty
          ? SizedBox(
              height: 46,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _buildMoveWidgets(context),
                ),
              ),
            )
          : widget.compactLandscape
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notes_rounded,
                            size: 16,
                            color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 8),
                        Text(
                          'PGN',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: textColor,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: widget.moves.isEmpty
                          ? Text(
                              'Start position',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                            )
                          : SingleChildScrollView(
                              controller: _scrollController,
                              child: _buildMoveTable(context),
                            ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
    );
  }

  List<Widget> _buildMoveWidgets(BuildContext context) {
    final widgets = <Widget>[];
    var whiteToMove = !_startsWithBlack;
    var moveNumber = _startMoveNumber;
    for (var ply = 1; ply <= widget.moves.length; ply++) {
      final move = widget.moves[ply - 1];
      if (whiteToMove || (ply == 1 && _startsWithBlack)) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              whiteToMove ? '$moveNumber.' : '$moveNumber...',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(alpha: 0.52),
                  ),
            ),
          ),
        );
      }
      widgets.add(
        Padding(
          padding: EdgeInsets.only(right: widget.compactLandscape ? 3 : 6),
          child: _SanMoveButton(
            key: ValueKey('san-ply-$ply'),
            label: move,
            selected: widget.currentPly == ply,
            onTap: () => widget.onSelectPly(ply),
            compactLandscape: widget.compactLandscape,
          ),
        ),
      );
      if (whiteToMove) {
        whiteToMove = false;
      } else {
        whiteToMove = true;
        moveNumber += 1;
      }
    }
    return widgets;
  }

  Widget _buildMoveTable(BuildContext context) {
    final rows = <Widget>[];
    var index = 0;
    var moveNumber = _startMoveNumber;
    if (_startsWithBlack && widget.moves.isNotEmpty) {
      rows.add(_buildMoveTableRow(
        context,
        moveNumber: moveNumber,
        blackMove: widget.moves.first,
        blackPly: 1,
      ));
      index = 1;
      moveNumber += 1;
    }
    while (index < widget.moves.length) {
      final whitePly = index + 1;
      final blackPly = index + 2;
      final whiteMove = widget.moves[index];
      final blackMove =
          index + 1 < widget.moves.length ? widget.moves[index + 1] : '';
      rows.add(
        _buildMoveTableRow(
          context,
          moveNumber: moveNumber,
          whiteMove: whiteMove,
          whitePly: whitePly,
          blackMove: blackMove,
          blackPly: blackPly,
        ),
      );
      index += 2;
      moveNumber += 1;
    }

    return Column(
      key: const ValueKey('game-pgn-table'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Widget _buildMoveTableRow(
    BuildContext context, {
    required int moveNumber,
    String whiteMove = '',
    int? whitePly,
    String blackMove = '',
    int? blackPly,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        key: ValueKey('game-pgn-row-$moveNumber'),
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '$moveNumber.',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(alpha: 0.52),
                  ),
            ),
          ),
          Expanded(
            child: whiteMove.isEmpty || whitePly == null
                ? const SizedBox.shrink()
                : _SanMoveButton(
                    key: ValueKey('game-pgn-white-$moveNumber'),
                    label: whiteMove,
                    selected: widget.currentPly == whitePly,
                    onTap: () => widget.onSelectPly(whitePly),
                    compactLandscape: true,
                    tableCell: true,
                  ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: blackMove.isEmpty || blackPly == null
                ? const SizedBox.shrink()
                : _SanMoveButton(
                    key: ValueKey('game-pgn-black-$moveNumber'),
                    label: blackMove,
                    selected: widget.currentPly == blackPly,
                    onTap: () => widget.onSelectPly(blackPly),
                    compactLandscape: true,
                    tableCell: true,
                  ),
          ),
        ],
      ),
    );
  }
}

class _SanMoveButton extends StatelessWidget {
  const _SanMoveButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compactLandscape = false,
    this.tableCell = false,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compactLandscape;
  final bool tableCell;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final tokens = ChessnutTheme.tokensOf(context);
    return Material(
      color: selected ? primary.withValues(alpha: 0.16) : Colors.transparent,
      borderRadius: BorderRadius.circular(tokens.controlRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.controlRadius),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight:
                compactLandscape ? (tableCell ? 30 : 34) : tokens.touchTarget,
            minWidth:
                compactLandscape ? (tableCell ? 44 : 34) : tokens.touchTarget,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compactLandscape ? (tableCell ? 8 : 7) : 9,
              vertical: compactLandscape ? (tableCell ? 3 : 4) : 6,
            ),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: selected
                          ? primary
                          : Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withValues(alpha: 0.76),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerClock extends StatelessWidget {
  const _PlayerClock({
    required this.name,
    required this.source,
    required this.time,
    this.rating,
    this.active = false,
    this.alignRight = false,
    this.compactLandscape = false,
    super.key,
  });

  final String name;
  final String? rating;
  final String source;
  final String time;
  final bool active;
  final bool alignRight;
  final bool compactLandscape;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final keyPrefix = key is ValueKey<String>
        ? (key as ValueKey<String>).value
        : (alignRight ? 'game-clock-opponent' : 'game-clock-player');
    final clock = Container(
      key: compactLandscape ? ValueKey('$keyPrefix-time') : null,
      width: compactLandscape ? double.infinity : 96,
      height: compactLandscape ? 76 : 47,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? primary.withValues(alpha: 0.18)
            : (dark ? const Color(0xFF050608) : const Color(0xFFE7EDF2)),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: active
              ? primary.withValues(alpha: 0.32)
              : Theme.of(context).dividerColor.withValues(alpha: 0.18),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compactLandscape ? 8 : 5),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            time,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: compactLandscape ? 42 : 31,
              height: 1,
              fontWeight: FontWeight.w500,
              fontFeatures: const [],
            ),
          ),
        ),
      ),
    );

    if (compactLandscape) {
      return GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        borderRadius: 10,
        tint: active ? primary.withValues(alpha: 0.10) : null,
        child: Column(
          crossAxisAlignment:
              alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!alignRight) ...[
                  _PresenceDot(active: active),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: alignRight
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        key: ValueKey('$keyPrefix-name'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (rating != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          rating!,
                          key: ValueKey('$keyPrefix-rating'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    height: 1.1,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                      if (source.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          source,
                          key: ValueKey('$keyPrefix-source'),
                          maxLines: rating == null ? 2 : 1,
                          overflow: rating == null
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    height: 1.1,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (alignRight) ...[
                  const SizedBox(width: 9),
                  _PresenceDot(active: active),
                ],
              ],
            ),
            const Spacer(),
            clock,
          ],
        ),
      );
    }

    final info = Expanded(
      child: Row(
        children: [
          if (!alignRight) ...[
            _PresenceDot(active: active),
            const SizedBox(width: 9),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: alignRight
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compactLandscape ? 14 : 18,
                      fontWeight: FontWeight.w700,
                    )),
                if (rating != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    rating!,
                    key: ValueKey('$keyPrefix-rating'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
                if (source.isNotEmpty) ...[
                  if (!compactLandscape) const SizedBox(height: 2),
                  Text(source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (alignRight) ...[
            const SizedBox(width: 9),
            _PresenceDot(active: active),
          ],
        ],
      ),
    );

    return GlassPanel(
      padding: EdgeInsets.symmetric(
        horizontal: compactLandscape ? 8 : 10,
        vertical: compactLandscape ? 6 : 8,
      ),
      borderRadius: 10,
      tint: active ? primary.withValues(alpha: 0.10) : null,
      child: Row(
        children: alignRight
            ? [clock, const SizedBox(width: 10), info]
            : [info, const SizedBox(width: 10), clock],
      ),
    );
  }
}

class _PresenceDot extends StatelessWidget {
  const _PresenceDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFF64748B);
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: active ? 0.34 : 0.16),
            blurRadius: 12,
            spreadRadius: 3,
          ),
        ],
      ),
    );
  }
}

class _GameActions extends StatelessWidget {
  const _GameActions({
    required this.onMore,
    required this.onFlip,
    required this.onPrevious,
    required this.onNext,
    required this.onHint,
    this.showHint = false,
    this.enabled = true,
    this.compactLandscape = false,
    this.showBoardVisibilityToggle = false,
    this.boardHidden = false,
    this.onToggleBoardVisibility,
  });

  final VoidCallback onMore;
  final VoidCallback? onFlip;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onHint;
  final bool showHint;
  final bool enabled;
  final bool compactLandscape;
  final bool showBoardVisibilityToggle;
  final bool boardHidden;
  final VoidCallback? onToggleBoardVisibility;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      key: const ValueKey('game-actions'),
      padding: EdgeInsets.symmetric(
        horizontal: compactLandscape ? 4 : 6,
        vertical: compactLandscape ? 4 : 6,
      ),
      borderRadius: 12,
      child: Row(
        children: [
          _ActionIcon(
              icon: Icons.keyboard_double_arrow_left_rounded,
              label: 'Prev',
              onTap: enabled ? onPrevious : null,
              compactLandscape: compactLandscape),
          _ActionIcon(
              icon: Icons.keyboard_double_arrow_right_rounded,
              label: 'Next',
              onTap: enabled ? onNext : null,
              compactLandscape: compactLandscape),
          _ActionIcon(
              icon: Icons.swap_vert_rounded,
              label: 'Flip',
              onTap: enabled ? onFlip : null,
              compactLandscape: compactLandscape),
          if (showHint)
            _ActionIcon(
                icon: Icons.lightbulb_outline_rounded,
                label: 'Hint',
                onTap: enabled ? onHint : null,
                compactLandscape: compactLandscape),
          if (showBoardVisibilityToggle)
            _ActionIcon(
              icon: boardHidden
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              label: boardHidden ? 'Show board' : 'Hide board',
              onTap: enabled ? onToggleBoardVisibility : null,
              compactLandscape: compactLandscape,
            ),
          _ActionIcon(
              icon: Icons.more_horiz_rounded,
              label: 'More',
              onTap: enabled ? onMore : null,
              compactLandscape: compactLandscape),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.label,
    this.onTap,
    this.compactLandscape = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool compactLandscape;

  @override
  Widget build(BuildContext context) {
    final tokens = ChessnutTheme.tokensOf(context);
    final touchTarget = _gameRoomTouchTarget(context);
    return Expanded(
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.controlRadius),
          onTap: onTap ?? () {},
          child: SizedBox(
            height: touchTarget,
            child: Icon(icon, size: 23),
          ),
        ),
      ),
    );
  }
}

double _gameRoomTouchTarget(BuildContext context) {
  final touchTarget = ChessnutTheme.tokensOf(context).touchTarget;
  return touchTarget < 48 ? 48 : touchTarget;
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    this.danger = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dangerColor = ChessnutTheme.tokensOf(context).danger;
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        minLeadingWidth: 28,
        leading: Icon(icon, color: danger ? dangerColor : null),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: danger ? dangerColor : null,
          ),
        ),
        onTap: onTap ?? () {},
      ),
    );
  }
}

class _SheetSwitch extends StatelessWidget {
  const _SheetSwitch({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        dense: true,
        secondary: SizedBox(
          width: 40,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Icon(
              icon,
              color: value
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
