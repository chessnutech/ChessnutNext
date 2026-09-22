import 'dart:async';
import 'dart:math' as math;

import 'package:dartchess/dartchess.dart' as dc;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../l10n/localized_material.dart';

import '../models/app_models.dart';
import '../services/chessnut_api_client.dart' as api;
import '../services/app_sound_service.dart';
import '../services/board_settings_service.dart';
import '../services/mistake_book_service.dart';
import '../services/physical_board_gateway.dart';
import '../services/physical_board_orientation.dart';
import '../services/physical_board_protocol.dart';
import '../services/voice_move_recognition_service.dart';
import '../services/voice_move_session_controller.dart';
import '../widgets/app_chrome.dart';
import '../widgets/chess_board.dart';
import '../widgets/chessnut_motion.dart';
import '../widgets/voice_moves_shortcut.dart';

bool _isDesktopPuzzlePlatform() {
  if (kIsWeb) return false;
  return switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
}

@visibleForTesting
bool usesMovePuzzleTransitionGuard({
  required PhysicalBoardGateway? gateway,
  required bool isChessnutClockDevice,
}) {
  if (kIsWeb || gateway?.boardModel != PhysicalBoardModel.move) {
    return false;
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.windows ||
    TargetPlatform.macOS =>
      true,
    _ => false,
  };
}

class PuzzleTheme {
  const PuzzleTheme({
    required this.tag,
    required this.name,
    required this.description,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String tag;
  final String name;
  final String description;
  final String count;
  final IconData icon;
  final Color color;
}

class PuzzleThemeGroup {
  const PuzzleThemeGroup({
    required this.title,
    required this.subtitle,
    required this.themes,
  });

  final String title;
  final String subtitle;
  final List<PuzzleTheme> themes;
}

const lichessPuzzleThemeGroups = [
  PuzzleThemeGroup(
    title: 'Tactical motifs',
    subtitle: 'Directly mapped from the Lichess Themes field',
    themes: [
      PuzzleTheme(
        tag: 'fork',
        name: 'Fork',
        description: 'Attack two targets at once.',
        count: '184k',
        icon: Icons.call_split_rounded,
        color: Color(0xFF38BDF8),
      ),
      PuzzleTheme(
        tag: 'pin',
        name: 'Pin',
        description: 'Freeze a piece against a higher-value target.',
        count: '142k',
        icon: Icons.push_pin_rounded,
        color: Color(0xFFA78BFA),
      ),
      PuzzleTheme(
        tag: 'skewer',
        name: 'Skewer',
        description: 'Drive the valuable piece away first.',
        count: '61k',
        icon: Icons.stacked_line_chart_rounded,
        color: Color(0xFFF59E0B),
      ),
      PuzzleTheme(
        tag: 'discoveredAttack',
        name: 'Discovered attack',
        description: 'Move one piece to reveal another threat.',
        count: '98k',
        icon: Icons.visibility_rounded,
        color: Color(0xFF22C55E),
      ),
    ],
  ),
  PuzzleThemeGroup(
    title: 'Checkmates',
    subtitle: 'Mate patterns and forced mate lengths',
    themes: [
      PuzzleTheme(
        tag: 'backRankMate',
        name: 'Back rank mate',
        description: 'Trap the king behind its own pawns.',
        count: '77k',
        icon: Icons.keyboard_double_arrow_up_rounded,
        color: Color(0xFFEF4444),
      ),
      PuzzleTheme(
        tag: 'mateIn1',
        name: 'Mate in 1',
        description: 'One forcing move ends the game.',
        count: '49k',
        icon: Icons.filter_1_rounded,
        color: Color(0xFF14B8A6),
      ),
      PuzzleTheme(
        tag: 'mateIn2',
        name: 'Mate in 2',
        description: 'Calculate the opponent response.',
        count: '92k',
        icon: Icons.filter_2_rounded,
        color: Color(0xFF8B5CF6),
      ),
      PuzzleTheme(
        tag: 'mateIn3',
        name: 'Mate in 3',
        description: 'Longer forcing sequence practice.',
        count: '55k',
        icon: Icons.filter_3_rounded,
        color: Color(0xFFF97316),
      ),
    ],
  ),
  PuzzleThemeGroup(
    title: 'Endgames',
    subtitle: 'Conversion, technique, and material-specific drills',
    themes: [
      PuzzleTheme(
        tag: 'rookEndgame',
        name: 'Rook endgame',
        description: 'Activity, checks, and passed pawns.',
        count: '36k',
        icon: Icons.crop_square_rounded,
        color: Color(0xFF60A5FA),
      ),
      PuzzleTheme(
        tag: 'pawnEndgame',
        name: 'Pawn endgame',
        description: 'Opposition, races, and promotion.',
        count: '44k',
        icon: Icons.grain_rounded,
        color: Color(0xFF84CC16),
      ),
      PuzzleTheme(
        tag: 'queenEndgame',
        name: 'Queen endgame',
        description: 'Checks, shelters, and perpetual threats.',
        count: '18k',
        icon: Icons.diamond_rounded,
        color: Color(0xFFE879F9),
      ),
      PuzzleTheme(
        tag: 'bishopEndgame',
        name: 'Bishop endgame',
        description: 'Color complexes and long diagonals.',
        count: '21k',
        icon: Icons.change_history_rounded,
        color: Color(0xFFFB7185),
      ),
    ],
  ),
  PuzzleThemeGroup(
    title: 'Game phase',
    subtitle: 'Use opening and middlegame tags for targeted sessions',
    themes: [
      PuzzleTheme(
        tag: 'opening',
        name: 'Opening',
        description: 'Tactics from known opening structures.',
        count: '133k',
        icon: Icons.rocket_launch_rounded,
        color: Color(0xFF22C55E),
      ),
      PuzzleTheme(
        tag: 'middlegame',
        name: 'Middlegame',
        description: 'Plans, tactics, and king safety.',
        count: '421k',
        icon: Icons.account_tree_rounded,
        color: Color(0xFF38BDF8),
      ),
      PuzzleTheme(
        tag: 'endgame',
        name: 'Endgame',
        description: 'Clean conversion from smaller material.',
        count: '189k',
        icon: Icons.flag_rounded,
        color: Color(0xFFF59E0B),
      ),
    ],
  ),
];

const _stormStartFen = '6k1/5ppp/8/8/8/8/5PPP/5RK1 w - - 0 1';
const _puzzleAdvanceDelay = Duration(milliseconds: 450);
const _puzzleMoveFeedbackDelay = Duration(milliseconds: 650);
const _physicalPuzzleAdvanceDelay = Duration(milliseconds: 30);
const _stormRunDuration = Duration(minutes: 3);
const _stormRatingBandStep = 200;
const _moveRestoreCheckInterval = Duration(milliseconds: 25);

class PuzzleStormScreen extends StatefulWidget {
  const PuzzleStormScreen({
    required this.onNavigate,
    required this.apiClient,
    this.boardGateway,
    this.boardSettings = const BoardSettingsState(),
    this.showBoardCoordinates = false,
    this.onPuzzleSolved,
    this.soundEffectsEnabled = true,
    this.soundEffects = const SoundEffectsSettings(),
    this.appSoundService = const SystemAppSoundService(),
    this.voiceMoveRecognitionService,
    this.isChessnutClockDevice = false,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final api.ChessnutApiClient apiClient;
  final PhysicalBoardGateway? boardGateway;
  final BoardSettingsState boardSettings;
  final bool showBoardCoordinates;
  final VoidCallback? onPuzzleSolved;
  final bool soundEffectsEnabled;
  final SoundEffectsSettings soundEffects;
  final AppSoundService appSoundService;
  final VoiceMoveRecognitionService? voiceMoveRecognitionService;
  final bool isChessnutClockDevice;

  @override
  State<PuzzleStormScreen> createState() => _PuzzleStormScreenState();
}

class _PuzzleStormScreenState extends State<PuzzleStormScreen> {
  api.Puzzle? livePuzzle;
  bool loading = true;
  bool puzzleSolved = false;
  String? puzzleFeedback;
  String? boardFenOverride;
  bool answerHintVisible = false;
  bool inputLocked = false;
  bool physicalSetupReady = false;
  bool physicalMoveArmed = false;
  bool boardFlipped = false;
  String? latestPhysicalBoardFen;
  List<String> lastMove = const [];
  int puzzleMoveIndex = 0;
  int boardResetSerial = 0;
  int _advanceGeneration = 0;
  int stormSolvedCount = 0;
  int stormCombo = 0;
  int stormRemainingSeconds = _stormRunDuration.inSeconds;
  bool stormTimerRunning = false;
  Timer? _advanceTimer;
  Timer? _feedbackTimer;
  Timer? _stormTimer;
  Timer? _pendingPhysicalMoveTimer;
  String? _pendingPhysicalMoveFen;
  Timer? _moveRestoreTimer;
  String? _pendingMoveRestoreFen;
  String? _pendingMoveRestoreObservedFen;
  int? _pendingMoveRestoreGeneration;
  Duration _pendingMoveRestoreElapsed = Duration.zero;
  String? _moveBoardTargetFen;
  String? _pendingVoiceAdvanceFen;
  int? _pendingVoiceAdvanceGeneration;
  StreamSubscription<String>? _boardFenSub;
  final _puzzleLedSync = _PuzzleLedSyncCache();
  late final PhysicalBoardOrientationResolver _boardOrientation;
  bool _movePuzzleOrientationLocked = false;
  late final VoiceMoveSessionController _voiceMoves;

  @override
  void initState() {
    super.initState();
    _boardOrientation = PhysicalBoardOrientationResolver(
      settings: widget.boardSettings,
    );
    _voiceMoves = VoiceMoveSessionController(
      service: widget.voiceMoveRecognitionService ??
          VoiceMoveRecognitionService(
              openAiKeyProvider: _openAiKeyForVoiceMove),
      ownsService: widget.voiceMoveRecognitionService == null,
      onChanged: _refreshVoiceMovesState,
      onMoveUci: _handleVoiceMoveUci,
      onMessage: _showVoiceMoveMessage,
      currentFenProvider: () {
        final puzzle = livePuzzle;
        return puzzle == null
            ? null
            : _currentPuzzleFen(puzzle, boardFenOverride);
      },
    );
    _subscribePhysicalBoard();
    _loadPuzzle();
  }

  @override
  void didUpdateWidget(covariant PuzzleStormScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final settingsChanged =
        _boardOrientation.updateSettings(widget.boardSettings);
    final puzzleOrientationChanged = _updateMovePuzzleOrientation(
      _currentPuzzleFen(livePuzzle, boardFenOverride),
    );
    if (settingsChanged || puzzleOrientationChanged) {
      _resetPhysicalBoardOrientationCache();
      unawaited(_syncPuzzleBoardAndLeds());
    }
    if (!identical(oldWidget.boardGateway, widget.boardGateway)) {
      _cancelPendingPhysicalMove();
      _cancelMoveRestore();
      _moveBoardTargetFen = null;
      _clearPendingVoiceAdvance();
      unawaited(_boardFenSub?.cancel());
      _puzzleLedSync.reset();
      if (!_canUseVoiceMoves) {
        unawaited(_voiceMoves.stop());
      }
      _subscribePhysicalBoard();
      unawaited(_syncPuzzleBoardAndLeds());
      _updateStormTimerForCurrentGate();
    }
    if (oldWidget.boardSettings.moveRestoreDelayMs !=
        widget.boardSettings.moveRestoreDelayMs) {
      _reschedulePendingMoveRestore();
    }
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _feedbackTimer?.cancel();
    _stormTimer?.cancel();
    _cancelPendingPhysicalMove();
    _moveRestoreTimer?.cancel();
    unawaited(_boardFenSub?.cancel());
    unawaited(_clearPuzzleLeds());
    unawaited(_voiceMoves.dispose());
    super.dispose();
  }

  Future<void> _loadPuzzle() async {
    _advanceTimer?.cancel();
    _advanceTimer = null;
    _feedbackTimer?.cancel();
    _feedbackTimer = null;
    _cancelPendingPhysicalMove();
    _cancelMoveRestore();
    final generation = ++_advanceGeneration;
    _moveBoardTargetFen = null;
    _clearPendingVoiceAdvance();
    _puzzleLedSync.reset();
    final resetExpiredRun = stormRemainingSeconds <= 0;
    setState(() {
      loading = true;
      if (resetExpiredRun) {
        stormSolvedCount = 0;
        stormCombo = 0;
        stormRemainingSeconds = _stormRunDuration.inSeconds;
      }
    });
    final puzzle = await widget.apiClient.puzzleRandom();
    if (!mounted || generation != _advanceGeneration) return;
    if (puzzle == null) {
      setState(() => loading = false);
      return;
    }
    final preparedStart = _preparePuzzleStart(puzzle);
    setState(() {
      livePuzzle = puzzle;
      puzzleSolved = false;
      puzzleFeedback = null;
      boardFenOverride = preparedStart?.fen;
      answerHintVisible = false;
      inputLocked = false;
      physicalSetupReady = false;
      physicalMoveArmed = false;
      boardFlipped = _puzzleBoardShouldFlip(
        preparedStart?.fen ?? puzzle.fen,
      );
      lastMove = preparedStart?.lastMove ?? const [];
      puzzleMoveIndex = preparedStart?.moveIndex ?? 0;
      loading = false;
      boardResetSerial += 1;
    });
    if (_updateMovePuzzleOrientation(
      preparedStart?.fen ?? puzzle.fen,
    )) {
      _resetPhysicalBoardOrientationCache();
    }
    _showPhysicalSetupPrompt(puzzle);
    _updateStormTimerForCurrentGate();
    unawaited(_syncPuzzleBoardAndLeds());
  }

  void _subscribePhysicalBoard() {
    final gateway = widget.boardGateway;
    if (gateway == null) return;
    _boardFenSub = gateway.boardFenStream.listen((fen) {
      final referenceFen = _currentPuzzleFen(livePuzzle, boardFenOverride);
      _handlePhysicalFen(
        _movePuzzleOrientationLocked
            ? _boardOrientation.normalizeWithLockedMapping(
                fen,
                referenceFens: [referenceFen],
              )
            : _boardOrientation.normalizeAndTrack(
                fen,
                referenceFens: [referenceFen],
                onMappingChanged: (_) => _resetPhysicalBoardOrientationCache(),
              ),
      );
    });
    if (gateway.currentState == PhysicalBoardConnectionState.connected) {
      unawaited(gateway.enableRealtimeFen());
    }
  }

  void _resetPhysicalBoardOrientationCache() {
    _moveBoardTargetFen = null;
    _puzzleLedSync.reset();
  }

  bool _updateMovePuzzleOrientation(String fen) {
    final shouldLock = _usesPuzzleMoveSideOrientation(
      gateway: widget.boardGateway,
      settings: widget.boardSettings,
    );
    if (!shouldLock) {
      if (!_movePuzzleOrientationLocked) return false;
      _movePuzzleOrientationLocked = false;
      _boardOrientation.reset();
      return true;
    }
    _movePuzzleOrientationLocked = true;
    return _boardOrientation.setManualMapping(
      _puzzleMoveSideMapping(fen),
    );
  }

  bool get _canUseVoiceMoves =>
      widget.boardGateway?.boardModel == PhysicalBoardModel.move &&
      widget.boardGateway?.currentState ==
          PhysicalBoardConnectionState.connected;

  bool get _useMoveTransitionGuard => usesMovePuzzleTransitionGuard(
        gateway: widget.boardGateway,
        isChessnutClockDevice: widget.isChessnutClockDevice,
      );

  Future<void> _toggleVoiceMoves() async {
    await _voiceMoves.toggle(
      context: context,
      canUse: _canUseVoiceMoves,
      settings: widget.boardSettings,
      unavailableMessage: 'Connect Chessnut Move first.',
    );
  }

  Future<String?> _openAiKeyForVoiceMove() async {
    final result = await widget.apiClient.getOpenaiKey();
    final key = result.data?.trim();
    if (result.isSuccess && key != null && key.isNotEmpty) return key;
    throw VoiceMoveOpenAiSessionException(
      result.status.errorMessage ??
          'Online voice recognition could not get an OpenAI session.',
    );
  }

  void _refreshVoiceMovesState() {
    if (mounted) setState(() {});
  }

  void _showVoiceMoveMessage(String message) {
    if (!mounted) return;
    setState(() => puzzleFeedback = message);
  }

  void _handleVoiceMoveUci(String uci) {
    final puzzle = livePuzzle;
    if (puzzle == null) return;
    final move = _puzzleMoveFromUci(
      _currentPuzzleFen(puzzle, boardFenOverride),
      uci,
    );
    if (move == null) {
      _showVoiceMoveMessage('Voice move $uci is not legal here.');
      return;
    }
    _handleSoftwareMove(move, initiatedByVoice: true);
  }

  void _handleSoftwareMove(
    ChessBoardMove move, {
    bool initiatedByVoice = false,
  }) {
    if (!_canStartPuzzleMove(livePuzzle)) {
      setState(() => boardResetSerial += 1);
      return;
    }
    _handlePuzzleMove(move, initiatedByVoice: initiatedByVoice);
  }

  void _handlePhysicalFen(String boardFen) {
    latestPhysicalBoardFen = _boardOnlyFen(boardFen);
    if (_useMoveTransitionGuard) {
      if (loading) return;
      final moveBoardTargetFen = _moveBoardTargetFen;
      if (moveBoardTargetFen != null) {
        if (latestPhysicalBoardFen == moveBoardTargetFen) {
          _moveBoardTargetFen = null;
        } else {
          return;
        }
      }
      final pendingVoiceAdvanceFen = _pendingVoiceAdvanceFen;
      if (pendingVoiceAdvanceFen != null) {
        if (latestPhysicalBoardFen != pendingVoiceAdvanceFen) return;
        final generation = _pendingVoiceAdvanceGeneration;
        _clearPendingVoiceAdvance();
        if (generation != null) {
          _scheduleAdvanceAfterSolved(generation, fromPhysical: true);
        }
        return;
      }
    }
    final pendingFen = _pendingPhysicalMoveFen;
    if (pendingFen != null && pendingFen != latestPhysicalBoardFen) {
      _cancelPendingPhysicalMove();
    }
    if (pendingFen == latestPhysicalBoardFen &&
        _pendingPhysicalMoveTimer?.isActive == true) {
      return;
    }
    final currentFen = _currentPuzzleFen(livePuzzle, boardFenOverride);
    if (physicalSetupReady || physicalMoveArmed) {
      final move = _resolvePuzzleBoardMove(
        livePuzzle,
        boardFen,
        currentFen: currentFen,
        moveIndex: puzzleMoveIndex,
      );
      if (move != null) {
        _cancelMoveRestore();
        _schedulePhysicalPuzzleMove(
          move,
          puzzle: livePuzzle!,
          sourceFen: currentFen,
          observedBoardFen: latestPhysicalBoardFen!,
        );
        return;
      }
    }
    if (!_refreshPhysicalSetupGate(livePuzzle)) {
      _scheduleMoveRestoreIfNeeded(currentFen, observedBoardFen: boardFen);
      return;
    }
    _cancelMoveRestore();
  }

  void _schedulePhysicalPuzzleMove(
    ChessBoardMove move, {
    required api.Puzzle puzzle,
    required String sourceFen,
    required String observedBoardFen,
  }) {
    final delay = widget.boardSettings.fenDelay;
    if (delay <= Duration.zero) {
      _cancelPendingPhysicalMove();
      _handlePuzzleMove(move, fromPhysical: true);
      return;
    }
    if (_pendingPhysicalMoveFen == observedBoardFen &&
        _pendingPhysicalMoveTimer?.isActive == true) {
      return;
    }
    _pendingPhysicalMoveTimer?.cancel();
    _pendingPhysicalMoveFen = observedBoardFen;
    final generation = _advanceGeneration;
    final moveIndex = puzzleMoveIndex;
    _pendingPhysicalMoveTimer = Timer(delay, () {
      _pendingPhysicalMoveTimer = null;
      _pendingPhysicalMoveFen = null;
      if (!mounted ||
          generation != _advanceGeneration ||
          !identical(livePuzzle, puzzle) ||
          puzzleSolved ||
          puzzleMoveIndex != moveIndex ||
          latestPhysicalBoardFen != observedBoardFen ||
          _boardOnlyFen(_currentPuzzleFen(puzzle, boardFenOverride)) !=
              _boardOnlyFen(sourceFen)) {
        return;
      }
      _handlePuzzleMove(move, fromPhysical: true);
    });
  }

  void _cancelPendingPhysicalMove() {
    _pendingPhysicalMoveTimer?.cancel();
    _pendingPhysicalMoveTimer = null;
    _pendingPhysicalMoveFen = null;
  }

  void _handlePuzzleMove(
    ChessBoardMove move, {
    bool fromPhysical = false,
    bool initiatedByVoice = false,
  }) {
    final puzzle = livePuzzle;
    if (puzzle == null || puzzleSolved || inputLocked) return;
    if (!fromPhysical && !_canStartPuzzleMove(puzzle)) return;
    final previousFen = _currentPuzzleFen(puzzle, boardFenOverride);
    final previousLastMove = lastMove;
    final expected = _puzzleExpectedMove(puzzle, puzzleMoveIndex);
    final correct =
        expected != null && _moveMatchesPuzzleAnswer(move.uci, expected);
    if (!correct) {
      _playPuzzleSound(AppSoundEvent.puzzleError);
      setState(() {
        stormCombo = 0;
        lastMove = [move.from, move.to];
        boardFenOverride = move.fen;
        inputLocked = true;
        physicalMoveArmed = false;
        puzzleFeedback = 'Try again: follow the highlighted board move.';
      });
      if (fromPhysical) {
        _scheduleMoveRestoreIfNeeded(previousFen, observedBoardFen: move.fen);
      }
      _scheduleRetryReset(
        _advanceGeneration,
        restoreFen: previousFen,
        restoreLastMove: previousLastMove,
      );
      unawaited(_syncPhysicalSetupLedsFor(puzzle, previousFen));
      return;
    }

    final answerMoves = _puzzleAnswerMoves(puzzle);
    final nextIndex = puzzleMoveIndex + 1;
    if (nextIndex >= answerMoves.length) {
      _completePuzzleMove(
        move,
        nextMoveIndex: nextIndex,
        fromPhysical: fromPhysical,
        initiatedByVoice: initiatedByVoice,
      );
      return;
    }
    final replyMove = _puzzleMoveAt(puzzle, nextIndex, move.fen);
    if (replyMove != null) {
      final followingIndex = nextIndex + 1;
      if (followingIndex >= answerMoves.length) {
        _completePuzzleMove(
          replyMove,
          nextMoveIndex: followingIndex,
          fromPhysical: fromPhysical,
          initiatedByVoice: initiatedByVoice,
        );
        return;
      }
      setState(() {
        puzzleMoveIndex = followingIndex;
        lastMove = [replyMove.from, replyMove.to];
        boardFenOverride = replyMove.fen;
        inputLocked = false;
        puzzleFeedback = null;
        answerHintVisible = false;
        physicalSetupReady = _isPuzzlePhysicalSetupReady(
          latestPhysicalBoardFen,
          puzzle,
          replyMove.fen,
        );
        physicalMoveArmed = physicalSetupReady;
        boardResetSerial += 1;
      });
      _updateStormTimerForCurrentGate();
      unawaited(_syncPuzzleBoardAndLeds());
      return;
    }

    setState(() {
      lastMove = [move.from, move.to];
      boardFenOverride = move.fen;
      inputLocked = false;
      puzzleFeedback = null;
      answerHintVisible = false;
      physicalSetupReady = _isPuzzlePhysicalSetupReady(
        latestPhysicalBoardFen,
        puzzle,
        move.fen,
      );
      physicalMoveArmed = physicalSetupReady;
      boardResetSerial += 1;
    });
    _updateStormTimerForCurrentGate();
    unawaited(_syncPuzzleBoardAndLeds());
  }

  void _completePuzzleMove(
    ChessBoardMove move, {
    required int nextMoveIndex,
    bool fromPhysical = false,
    bool initiatedByVoice = false,
  }) {
    setState(() {
      stormSolvedCount += 1;
      stormCombo += 1;
      puzzleMoveIndex = nextMoveIndex;
      lastMove = [move.from, move.to];
      boardFenOverride = move.fen;
      inputLocked = true;
      puzzleSolved = true;
      puzzleFeedback = 'Puzzle solved';
      answerHintVisible = false;
      physicalMoveArmed = false;
    });
    _playPuzzleSound(AppSoundEvent.puzzleSuccess);
    widget.onPuzzleSolved?.call();
    unawaited(_clearPuzzleLeds());
    if (!fromPhysical && _armVoiceAdvanceForMoveBoard(move.fen)) return;
    _scheduleAdvanceAfterSolved(
      _advanceGeneration,
      fromPhysical: fromPhysical,
    );
  }

  void _startStormTimerIfNeeded() {
    if (!mounted || stormTimerRunning || stormRemainingSeconds <= 0) return;
    setState(() => stormTimerRunning = true);
    _stormTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_stormCanRunTimer(livePuzzle)) {
        _pauseStormTimer();
        return;
      }
      if (stormRemainingSeconds <= 1) {
        setState(() {
          stormRemainingSeconds = 0;
          stormTimerRunning = false;
          inputLocked = true;
          puzzleFeedback = 'Time is up';
        });
        _stormTimer?.cancel();
        _stormTimer = null;
        unawaited(_clearPuzzleLeds());
        return;
      }
      setState(() => stormRemainingSeconds -= 1);
    });
  }

  void _playPuzzleSound(AppSoundEvent event) {
    if (!widget.soundEffectsEnabled) return;
    if (!widget.soundEffects.allows(event)) return;
    unawaited(widget.appSoundService.play(event));
  }

  void _pauseStormTimer() {
    _stormTimer?.cancel();
    _stormTimer = null;
    if (!mounted || !stormTimerRunning) return;
    setState(() => stormTimerRunning = false);
  }

  void _updateStormTimerForCurrentGate() {
    if (_stormCanRunTimer(livePuzzle)) {
      _startStormTimerIfNeeded();
    } else {
      _pauseStormTimer();
    }
  }

  bool _stormCanRunTimer(api.Puzzle? puzzle) {
    if (puzzle == null || loading || stormRemainingSeconds <= 0) return false;
    if (!_physicalSetupRequired(widget.boardGateway, puzzle)) return true;
    return physicalSetupReady;
  }

  void _showAnswerHint() {
    if (livePuzzle == null || puzzleSolved) return;
    if (stormRemainingSeconds <= 0) return;
    if (!_canStartPuzzleMove(livePuzzle)) return;
    setState(() => answerHintVisible = true);
    unawaited(_syncPuzzleLeds());
  }

  void _scheduleRetryReset(
    int generation, {
    required String restoreFen,
    required List<String> restoreLastMove,
  }) {
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(_puzzleMoveFeedbackDelay, () {
      _feedbackTimer = null;
      if (!mounted || generation != _advanceGeneration || puzzleSolved) return;
      setState(() {
        boardFenOverride = restoreFen;
        answerHintVisible = false;
        inputLocked = false;
        lastMove = restoreLastMove;
        physicalSetupReady = _isPuzzlePhysicalSetupReady(
          latestPhysicalBoardFen,
          livePuzzle,
          restoreFen,
        );
        physicalMoveArmed = physicalSetupReady;
        boardResetSerial += 1;
      });
      _updateStormTimerForCurrentGate();
      unawaited(_syncPuzzleBoardAndLeds());
    });
  }

  void _scheduleMoveRestoreIfNeeded(
    String restoreFen, {
    required String observedBoardFen,
  }) {
    final gateway = widget.boardGateway;
    if (gateway == null ||
        gateway.boardModel != PhysicalBoardModel.move ||
        gateway.currentState != PhysicalBoardConnectionState.connected ||
        livePuzzle == null ||
        _boardOnlyFen(observedBoardFen) == _boardOnlyFen(restoreFen)) {
      _cancelMoveRestore();
      return;
    }
    final generation = _advanceGeneration;
    final normalizedObservedFen = _boardOnlyFen(observedBoardFen);
    final samePendingRestore = _pendingMoveRestoreFen == restoreFen &&
        _pendingMoveRestoreObservedFen == normalizedObservedFen &&
        _pendingMoveRestoreGeneration == generation;
    if (!samePendingRestore) {
      _pendingMoveRestoreFen = restoreFen;
      _pendingMoveRestoreObservedFen = normalizedObservedFen;
      _pendingMoveRestoreGeneration = generation;
      _pendingMoveRestoreElapsed = Duration.zero;
    }
    _schedulePendingMoveRestoreTimer();
  }

  void _schedulePendingMoveRestoreTimer() {
    final restoreFen = _pendingMoveRestoreFen;
    final generation = _pendingMoveRestoreGeneration;
    if (restoreFen == null || generation == null) {
      return;
    }
    if (_pendingMoveRestoreElapsed >= widget.boardSettings.moveRestoreDelay) {
      _restorePendingMovePosition(restoreFen, generation);
      return;
    }
    if (_moveRestoreTimer?.isActive ?? false) return;
    _moveRestoreTimer = Timer.periodic(_moveRestoreCheckInterval, (timer) {
      _pendingMoveRestoreElapsed += _moveRestoreCheckInterval;
      if (_pendingMoveRestoreElapsed >= widget.boardSettings.moveRestoreDelay) {
        _restorePendingMovePosition(restoreFen, generation);
      }
    });
  }

  void _reschedulePendingMoveRestore() {
    if (_pendingMoveRestoreFen == null) return;
    _schedulePendingMoveRestoreTimer();
  }

  void _restorePendingMovePosition(String restoreFen, int generation) {
    final gateway = widget.boardGateway;
    if (!mounted ||
        generation != _advanceGeneration ||
        puzzleSolved ||
        gateway == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected ||
        _boardOnlyFen(latestPhysicalBoardFen ?? '') ==
            _boardOnlyFen(restoreFen)) {
      _cancelMoveRestore();
      return;
    }
    _cancelMoveRestore();
    unawaited(gateway.setMoveBoardFen(
      restoreFen,
      isReverse: _boardOrientation.isReversed,
    ));
  }

  void _cancelMoveRestore() {
    _moveRestoreTimer?.cancel();
    _moveRestoreTimer = null;
    _pendingMoveRestoreFen = null;
    _pendingMoveRestoreObservedFen = null;
    _pendingMoveRestoreGeneration = null;
    _pendingMoveRestoreElapsed = Duration.zero;
  }

  bool _armVoiceAdvanceForMoveBoard(String fen) {
    final gateway = widget.boardGateway;
    if (!_useMoveTransitionGuard ||
        gateway == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      return false;
    }
    final targetFen = _boardOnlyFen(fen);
    if (_boardOnlyFen(latestPhysicalBoardFen ?? '') == targetFen) return false;
    _pendingVoiceAdvanceFen = targetFen;
    _pendingVoiceAdvanceGeneration = _advanceGeneration;
    _moveBoardTargetFen = targetFen;
    unawaited(_sendSolvedVoicePositionToMoveBoard(
      fen,
      targetFen: targetFen,
      generation: _advanceGeneration,
    ));
    return true;
  }

  Future<void> _sendSolvedVoicePositionToMoveBoard(
    String fen, {
    required String targetFen,
    required int generation,
  }) async {
    final sent = await widget.boardGateway?.setMoveBoardFen(
          fen,
          isReverse: _boardOrientation.isReversed,
        ) ??
        false;
    if (sent ||
        !mounted ||
        generation != _advanceGeneration ||
        _pendingVoiceAdvanceFen != targetFen) {
      return;
    }
    _moveBoardTargetFen = null;
    _clearPendingVoiceAdvance();
    _scheduleAdvanceAfterSolved(generation);
  }

  void _clearPendingVoiceAdvance() {
    _pendingVoiceAdvanceFen = null;
    _pendingVoiceAdvanceGeneration = null;
  }

  void _scheduleAdvanceAfterSolved(
    int generation, {
    bool fromPhysical = false,
  }) {
    _feedbackTimer?.cancel();
    _advanceTimer?.cancel();
    if (fromPhysical) {
      if (!mounted || generation != _advanceGeneration || !puzzleSolved) {
        return;
      }
      _advanceTimer = Timer(_physicalPuzzleAdvanceDelay, () {
        _advanceTimer = null;
        if (!mounted || generation != _advanceGeneration || !puzzleSolved) {
          return;
        }
        unawaited(_loadPuzzle());
      });
      return;
    }
    _feedbackTimer = Timer(_puzzleMoveFeedbackDelay, () {
      _feedbackTimer = null;
      if (!mounted || generation != _advanceGeneration || !puzzleSolved) {
        return;
      }
      _advanceTimer = Timer(_puzzleAdvanceDelay, () {
        _advanceTimer = null;
        if (!mounted || generation != _advanceGeneration || !puzzleSolved) {
          return;
        }
        unawaited(_loadPuzzle());
      });
    });
  }

  Future<void> _syncPuzzleBoardAndLeds() async {
    final fen = _currentPuzzleFen(livePuzzle, boardFenOverride);
    if (_useMoveTransitionGuard) {
      await _sendStormPositionToMoveBoard(fen);
      await _syncPuzzleLeds();
      return;
    }
    await _syncPuzzleLeds();
    await _sendPuzzlePositionToBoard(
      gateway: widget.boardGateway,
      puzzle: livePuzzle,
      fen: fen,
      orientation: _boardOrientation,
    );
  }

  Future<void> _sendStormPositionToMoveBoard(String fen) async {
    final gateway = widget.boardGateway;
    final puzzle = livePuzzle;
    if (gateway == null ||
        puzzle == null ||
        gateway.boardModel != PhysicalBoardModel.move ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      return;
    }
    final targetFen = _boardOnlyFen(fen);
    if (_boardOnlyFen(latestPhysicalBoardFen ?? '') == targetFen) {
      _moveBoardTargetFen = null;
      return;
    }
    if (_moveBoardTargetFen == targetFen) return;
    _cancelMoveRestore();
    // Set the guard before writing: the board emits intermediate FENs while
    // the motor is moving, and those must not be interpreted as user moves.
    _moveBoardTargetFen = targetFen;
    final sent = await gateway.setMoveBoardFen(
      fen,
      isReverse: _boardOrientation.isReversed,
    );
    if (!sent && _moveBoardTargetFen == targetFen) {
      _moveBoardTargetFen = null;
    }
  }

  Future<void> _syncPuzzleLeds() async {
    final setupPlan = _physicalSetupLedPlan(
      gateway: widget.boardGateway,
      puzzle: livePuzzle,
      currentFen: _currentPuzzleFen(livePuzzle, boardFenOverride),
      latestPhysicalBoardFen: latestPhysicalBoardFen,
      solved: puzzleSolved,
      answerVisible: answerHintVisible,
      orientation: _boardOrientation,
    );
    await _puzzleLedSync.send(widget.boardGateway, setupPlan.request);
    if (setupPlan.setupActive) {
      return;
    }
    await _puzzleLedSync.send(
      widget.boardGateway,
      _answerLedRequest(
        gateway: widget.boardGateway,
        puzzle: livePuzzle,
        solved: puzzleSolved,
        visible: answerHintVisible,
        currentFen: _currentPuzzleFen(livePuzzle, boardFenOverride),
        moveIndex: puzzleMoveIndex,
        orientation: _boardOrientation,
      ),
    );
  }

  Future<void> _clearPuzzleLeds() async {
    await _puzzleLedSync.send(
      widget.boardGateway,
      _clearLedRequest(widget.boardGateway),
    );
  }

  Future<void> _syncPhysicalSetupLedsFor(
    api.Puzzle puzzle,
    String currentFen,
  ) async {
    final setupPlan = _physicalSetupLedPlan(
      gateway: widget.boardGateway,
      puzzle: puzzle,
      currentFen: currentFen,
      latestPhysicalBoardFen: latestPhysicalBoardFen,
      solved: false,
      orientation: _boardOrientation,
    );
    await _puzzleLedSync.send(widget.boardGateway, setupPlan.request);
  }

  bool _canStartPuzzleMove(api.Puzzle? puzzle) {
    if (stormRemainingSeconds <= 0) return false;
    if (!_physicalSetupRequired(widget.boardGateway, puzzle)) return true;
    if (physicalSetupReady) return true;
    return _refreshPhysicalSetupGate(puzzle);
  }

  bool _refreshPhysicalSetupGate(api.Puzzle? puzzle) {
    if (!_physicalSetupRequired(widget.boardGateway, puzzle)) {
      if (!physicalSetupReady) {
        setState(() {
          physicalSetupReady = true;
          physicalMoveArmed = true;
        });
      }
      _updateStormTimerForCurrentGate();
      return true;
    }
    final ready = _isPuzzlePhysicalSetupReady(
      latestPhysicalBoardFen,
      puzzle,
      _currentPuzzleFen(puzzle, boardFenOverride),
    );
    if (ready) {
      _cancelMoveRestore();
      if (!physicalSetupReady || puzzleFeedback == _physicalSetupPromptText) {
        setState(() {
          physicalSetupReady = true;
          physicalMoveArmed = true;
          if (puzzleFeedback == _physicalSetupPromptText) {
            puzzleFeedback = null;
          }
        });
      }
      _updateStormTimerForCurrentGate();
      unawaited(_syncPuzzleLeds());
      return true;
    }
    if (physicalSetupReady) {
      setState(() {
        physicalSetupReady = false;
        puzzleFeedback ??= _physicalSetupPromptText;
        answerHintVisible = false;
      });
      _pauseStormTimer();
      unawaited(_syncPuzzleLeds());
      return false;
    }
    _showPhysicalSetupPrompt(puzzle);
    return false;
  }

  void _showPhysicalSetupPrompt(api.Puzzle? puzzle) {
    if (!_physicalSetupRequired(widget.boardGateway, puzzle)) return;
    if (physicalSetupReady || puzzleFeedback == _physicalSetupPromptText) {
      unawaited(_syncPuzzleLeds());
      return;
    }
    setState(() {
      physicalSetupReady = false;
      puzzleFeedback = _physicalSetupPromptText;
      answerHintVisible = false;
    });
    _pauseStormTimer();
    unawaited(_syncPuzzleLeds());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final boardFen = _currentPuzzleFen(livePuzzle, boardFenOverride);
    final viewport = MediaQuery.sizeOf(context);
    final narrowPhonePortrait = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS) &&
        viewport.width < 480 &&
        viewport.width < viewport.height;
    final androidPhoneLandscape = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !widget.isChessnutClockDevice &&
        viewport.width > viewport.height &&
        viewport.longestSide < 1000 &&
        viewport.shortestSide < 600;
    return ResponsivePage(
      compactLandscapeOverride: androidPhoneLandscape,
      children: (context, spec) {
        final desktopSplit = _isDesktopPuzzlePlatform() && spec.width >= 900;
        final boardOnlyLeft = spec.compactLandscape || desktopSplit;
        final board = ResponsiveBoardFrame(
          maxSize: spec.compactLandscape
              ? (spec.heightAfterHeader() - spec.gutter - 8)
                  .clamp(220.0, 384.0)
                  .toDouble()
              : (spec.canSplit ? 510 : 292),
          padding: EdgeInsets.all(spec.compactLandscape ? 4 : 10),
          builder: (size) => livePuzzle == null
              ? _EmptyPuzzleBoard(size: size)
              : inputLocked && boardFenOverride != null
                  ? _SolvedPuzzleBoard(
                      size: size,
                      fen: boardFenOverride!,
                      lastMove: lastMove,
                      flipped: boardFlipped,
                      showCoordinates: widget.showBoardCoordinates,
                    )
                  : AbsorbPointer(
                      absorbing: inputLocked,
                      child: InteractiveChessBoard(
                        key: ValueKey(
                          'storm-board-${livePuzzle?.id}-$boardResetSerial',
                        ),
                        size: size,
                        initialFen: boardFen,
                        flipped: boardFlipped,
                        lastMove: lastMove,
                        showCoordinates: widget.showBoardCoordinates,
                        tapSquaresWithOverlay: true,
                        hintMove: answerHintVisible
                            ? _hintMoveForPuzzle(
                                livePuzzle,
                                solved: puzzleSolved,
                                currentFen: boardFen,
                                moveIndex: puzzleMoveIndex,
                              )
                            : null,
                        onMove: _handleSoftwareMove,
                      ),
                    ),
        );
        final compactFeedback = spec.compactLandscape && puzzleFeedback != null;
        final voiceMovesShortcut = _canUseVoiceMoves
            ? VoiceMovesShortcutButton(
                enabled: _voiceMoves.enabled,
                listening: _voiceMoves.listening,
                onPressed: _toggleVoiceMoves,
                valueKey: const ValueKey('puzzle-storm-voice-moves-toggle'),
              )
            : null;
        final keepNarrowActionsInHeader =
            narrowPhonePortrait && voiceMovesShortcut == null;
        Widget puzzleActions({required bool narrowPortrait}) {
          final buttonStyle = narrowPortrait
              ? const ButtonStyle(
                  fixedSize: WidgetStatePropertyAll(Size.square(44)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )
              : null;
          final primaryButtonStyle = narrowPortrait
              ? ButtonStyle(
                  fixedSize: const WidgetStatePropertyAll(Size.square(44)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: WidgetStatePropertyAll(scheme.primary),
                  foregroundColor: WidgetStatePropertyAll(scheme.onPrimary),
                )
              : null;
          return Row(
            key: narrowPortrait
                ? const ValueKey('puzzle-storm-narrow-toolbar')
                : null,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (voiceMovesShortcut != null) ...[
                voiceMovesShortcut,
                SizedBox(width: narrowPortrait ? 4 : 8),
              ],
              if (narrowPortrait)
                IconButton.filled(
                  key: const ValueKey('puzzle-storm-flip-board'),
                  tooltip: 'Flip board',
                  style: primaryButtonStyle,
                  onPressed: () => setState(() => boardFlipped = !boardFlipped),
                  icon: const Icon(Icons.flip_camera_android_rounded),
                )
              else
                IconButton.filledTonal(
                  key: const ValueKey('puzzle-storm-flip-board'),
                  tooltip: 'Flip board',
                  onPressed: () => setState(() => boardFlipped = !boardFlipped),
                  icon: const Icon(Icons.flip_camera_android_rounded),
                ),
              SizedBox(width: narrowPortrait ? 4 : 8),
              IconButton.filledTonal(
                tooltip: 'Hint',
                style: buttonStyle,
                onPressed:
                    livePuzzle == null || puzzleSolved ? null : _showAnswerHint,
                icon: const Icon(Icons.lightbulb_rounded),
              ),
              SizedBox(width: narrowPortrait ? 4 : 8),
              IconButton.filledTonal(
                tooltip: 'Next puzzle',
                style: buttonStyle,
                onPressed: _loadPuzzle,
                icon: const Icon(Icons.play_arrow_rounded),
              ),
            ],
          );
        }

        return [
          ScreenHeader(
            title: 'Puzzle Storm',
            titleKey: const ValueKey('puzzle-storm-title'),
            scaleTitleToFit: keepNarrowActionsInHeader,
            trailingMaxWidth: keepNarrowActionsInHeader ? 140 : null,
            leading: IconButton.filledTonal(
              onPressed: () => widget.onNavigate('Back'),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            trailing: narrowPhonePortrait
                ? keepNarrowActionsInHeader
                    ? puzzleActions(narrowPortrait: true)
                    : null
                : puzzleActions(narrowPortrait: false),
          ),
          if (narrowPhonePortrait && !keepNarrowActionsInHeader) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: puzzleActions(narrowPortrait: true),
            ),
          ],
          SizedBox(height: spec.gutter),
          ResponsiveSplit(
            key: androidPhoneLandscape
                ? const ValueKey('puzzle-storm-android-phone-landscape')
                : desktopSplit
                    ? const ValueKey('puzzle-storm-horizontal-layout')
                    : null,
            breakpoint: androidPhoneLandscape ? 600 : 900,
            spacing: spec.gutter,
            leadingFlex: spec.compactLandscape ? 6 : 6,
            trailingFlex: spec.compactLandscape ? 5 : 5,
            leading: SectionColumn(
              spacing: spec.compactLandscape ? 8 : 12,
              children: boardOnlyLeft
                  ? [board]
                  : [
                      _StormHero(
                        scheme: scheme,
                        puzzle: livePuzzle,
                        loading: loading,
                        remainingSeconds: stormRemainingSeconds,
                        solvedCount: stormSolvedCount,
                        combo: stormCombo,
                        compactLandscapeOverride: androidPhoneLandscape,
                      ),
                      board,
                    ],
            ),
            trailing: SectionColumn(
              spacing: spec.compactLandscape ? 8 : 12,
              children: [
                if (compactFeedback)
                  _PuzzleResultCard(
                    solved: puzzleSolved,
                    text: puzzleFeedback!,
                    compact: true,
                  ),
                if (boardOnlyLeft)
                  _StormHero(
                    scheme: scheme,
                    puzzle: livePuzzle,
                    loading: loading,
                    remainingSeconds: stormRemainingSeconds,
                    solvedCount: stormSolvedCount,
                    combo: stormCombo,
                    compactLandscapeOverride: androidPhoneLandscape,
                  ),
                _PuzzleTurnCard(
                  fen: boardFen,
                  compactLandscapeOverride: androidPhoneLandscape,
                ),
                _StormQueueCard(puzzle: livePuzzle),
                if (!compactFeedback && puzzleFeedback != null)
                  _PuzzleResultCard(
                    solved: puzzleSolved,
                    text: puzzleFeedback!,
                  ),
                if (!spec.compactLandscape) const _StormRulesCard(),
              ],
            ),
          ),
        ];
      },
    );
  }
}

class PuzzleThemesScreen extends StatefulWidget {
  const PuzzleThemesScreen({
    required this.onNavigate,
    required this.apiClient,
    this.boardGateway,
    this.boardSettings = const BoardSettingsState(),
    this.showBoardCoordinates = false,
    this.onPuzzleSolved,
    this.soundEffectsEnabled = true,
    this.soundEffects = const SoundEffectsSettings(),
    this.appSoundService = const SystemAppSoundService(),
    this.voiceMoveRecognitionService,
    this.isChessnutClockDevice = false,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final api.ChessnutApiClient apiClient;
  final PhysicalBoardGateway? boardGateway;
  final BoardSettingsState boardSettings;
  final bool showBoardCoordinates;
  final VoidCallback? onPuzzleSolved;
  final bool soundEffectsEnabled;
  final SoundEffectsSettings soundEffects;
  final AppSoundService appSoundService;
  final VoiceMoveRecognitionService? voiceMoveRecognitionService;
  final bool isChessnutClockDevice;

  @override
  State<PuzzleThemesScreen> createState() => _PuzzleThemesScreenState();
}

class _PuzzleThemesScreenState extends State<PuzzleThemesScreen> {
  api.PuzzleInfo? info;
  bool infoLoading = true;
  String? infoError;
  api.PuzzleTag? selectedTag;
  PuzzleTheme? selectedTheme;
  api.Puzzle? themePuzzle;
  bool puzzleLoading = false;
  String? puzzleError;
  bool puzzleSolved = false;
  String? puzzleFeedback;
  String? boardFenOverride;
  bool answerHintVisible = false;
  bool inputLocked = false;
  bool physicalSetupReady = false;
  bool physicalMoveArmed = false;
  bool boardFlipped = false;
  String? latestPhysicalBoardFen;
  List<String> lastMove = const [];
  int puzzleMoveIndex = 0;
  int boardResetSerial = 0;
  int _advanceGeneration = 0;
  Timer? _advanceTimer;
  Timer? _feedbackTimer;
  Timer? _pendingPhysicalMoveTimer;
  String? _pendingPhysicalMoveFen;
  Timer? _moveRestoreTimer;
  String? _pendingMoveRestoreFen;
  String? _pendingMoveRestoreObservedFen;
  int? _pendingMoveRestoreGeneration;
  Duration _pendingMoveRestoreElapsed = Duration.zero;
  String? _moveBoardTargetFen;
  String? _pendingVoiceAdvanceFen;
  int? _pendingVoiceAdvanceGeneration;
  StreamSubscription<String>? _boardFenSub;
  final _puzzleLedSync = _PuzzleLedSyncCache();
  late final PhysicalBoardOrientationResolver _boardOrientation;
  bool _movePuzzleOrientationLocked = false;
  late final VoiceMoveSessionController _voiceMoves;

  @override
  void initState() {
    super.initState();
    _boardOrientation = PhysicalBoardOrientationResolver(
      settings: widget.boardSettings,
    );
    _voiceMoves = VoiceMoveSessionController(
      service: widget.voiceMoveRecognitionService ??
          VoiceMoveRecognitionService(
              openAiKeyProvider: _openAiKeyForVoiceMove),
      ownsService: widget.voiceMoveRecognitionService == null,
      onChanged: _refreshVoiceMovesState,
      onMoveUci: _handleVoiceMoveUci,
      onMessage: _showVoiceMoveMessage,
      currentFenProvider: () {
        final puzzle = themePuzzle;
        return puzzle == null
            ? null
            : _currentPuzzleFen(puzzle, boardFenOverride);
      },
    );
    _subscribePhysicalBoard();
    _loadInfo();
  }

  @override
  void didUpdateWidget(covariant PuzzleThemesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final settingsChanged =
        _boardOrientation.updateSettings(widget.boardSettings);
    final puzzleOrientationChanged = _updateMovePuzzleOrientation(
      _currentPuzzleFen(themePuzzle, boardFenOverride),
    );
    if (settingsChanged || puzzleOrientationChanged) {
      _resetPhysicalBoardOrientationCache();
      unawaited(_syncPuzzleBoardAndLeds());
    }
    if (!identical(oldWidget.boardGateway, widget.boardGateway)) {
      _cancelPendingPhysicalMove();
      _cancelMoveRestore();
      _moveBoardTargetFen = null;
      _clearPendingVoiceAdvance();
      unawaited(_boardFenSub?.cancel());
      _puzzleLedSync.reset();
      if (!_canUseVoiceMoves) {
        unawaited(_voiceMoves.stop());
      }
      _subscribePhysicalBoard();
      unawaited(_syncPuzzleBoardAndLeds());
    }
    if (oldWidget.boardSettings.moveRestoreDelayMs !=
        widget.boardSettings.moveRestoreDelayMs) {
      _reschedulePendingMoveRestore();
    }
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _feedbackTimer?.cancel();
    _cancelPendingPhysicalMove();
    _moveRestoreTimer?.cancel();
    unawaited(_boardFenSub?.cancel());
    unawaited(_clearPuzzleLeds());
    unawaited(_voiceMoves.dispose());
    super.dispose();
  }

  Future<void> _loadInfo() async {
    setState(() {
      infoLoading = true;
      infoError = null;
    });
    final nextInfo = await widget.apiClient.puzzleInfo();
    if (!mounted) return;
    setState(() {
      info = nextInfo;
      infoLoading = false;
      infoError = nextInfo == null ? 'Puzzle themes could not load.' : null;
    });
    if (nextInfo != null &&
        selectedTag == null &&
        themePuzzle == null &&
        !puzzleLoading) {
      unawaited(_openRandomTheme(nextInfo));
    }
  }

  Future<void> _openRandomTheme(api.PuzzleInfo nextInfo) async {
    final tags = nextInfo.tags;
    if (tags.isEmpty) return;
    final tag = tags[math.Random().nextInt(tags.length)];
    await _openTheme(_themeForLiveTag(tag), tag);
  }

  Future<void> _openTheme(PuzzleTheme theme, api.PuzzleTag? liveTag) async {
    _advanceTimer?.cancel();
    _advanceTimer = null;
    _feedbackTimer?.cancel();
    _feedbackTimer = null;
    _cancelPendingPhysicalMove();
    _cancelMoveRestore();
    _clearPendingVoiceAdvance();
    if (liveTag == null) {
      _advanceGeneration += 1;
      _puzzleLedSync.reset();
      setState(() {
        selectedTheme = theme;
        selectedTag = null;
        themePuzzle = null;
        puzzleError = 'This theme is not available yet. Try another theme.';
        puzzleSolved = false;
        puzzleFeedback = null;
        boardFenOverride = null;
        answerHintVisible = false;
        inputLocked = false;
        physicalSetupReady = false;
        physicalMoveArmed = false;
        lastMove = const [];
        puzzleMoveIndex = 0;
      });
      unawaited(_clearPuzzleLeds());
      return;
    }
    final generation = ++_advanceGeneration;
    _puzzleLedSync.reset();
    setState(() {
      selectedTheme = theme;
      selectedTag = liveTag;
      puzzleLoading = true;
      puzzleError = null;
    });
    final nextPuzzle = await widget.apiClient.puzzleTagRandom(liveTag.id);
    if (!mounted || generation != _advanceGeneration) return;
    if (nextPuzzle == null) {
      setState(() {
        puzzleLoading = false;
        puzzleError =
            'No puzzle was returned for this theme. Try another theme.';
      });
      return;
    }
    _cancelMoveRestore();
    final preparedStart = _preparePuzzleStart(nextPuzzle);
    setState(() {
      themePuzzle = nextPuzzle;
      puzzleSolved = false;
      puzzleFeedback = null;
      boardFenOverride = preparedStart?.fen;
      answerHintVisible = false;
      inputLocked = false;
      physicalSetupReady = false;
      physicalMoveArmed = false;
      boardFlipped = _puzzleBoardShouldFlip(
        preparedStart?.fen ?? nextPuzzle.fen,
      );
      lastMove = preparedStart?.lastMove ?? const [];
      puzzleMoveIndex = preparedStart?.moveIndex ?? 0;
      puzzleLoading = false;
      puzzleError = null;
      boardResetSerial += 1;
    });
    if (_updateMovePuzzleOrientation(
      preparedStart?.fen ?? nextPuzzle.fen,
    )) {
      _resetPhysicalBoardOrientationCache();
    }
    _showPhysicalSetupPrompt(nextPuzzle);
    unawaited(_syncPuzzleBoardAndLeds());
  }

  Future<void> _loadNextThemePuzzle() async {
    final tag = selectedTag;
    final theme = selectedTheme;
    if (tag == null || theme == null) {
      final nextInfo = info;
      if (nextInfo != null) await _openRandomTheme(nextInfo);
      return;
    }
    await _openTheme(theme, tag);
  }

  Future<void> _openPuzzleById(int puzzleId) async {
    _advanceTimer?.cancel();
    _advanceTimer = null;
    _feedbackTimer?.cancel();
    _feedbackTimer = null;
    _cancelMoveRestore();
    final generation = ++_advanceGeneration;
    _puzzleLedSync.reset();
    setState(() {
      puzzleLoading = true;
      puzzleError = null;
    });
    final nextPuzzle = await widget.apiClient.puzzle(puzzleId);
    if (!mounted || generation != _advanceGeneration) return;
    if (nextPuzzle == null) {
      setState(() {
        puzzleLoading = false;
        puzzleError = 'Puzzle not found.';
      });
      return;
    }
    _cancelMoveRestore();
    final matchingTag = _tagForPuzzle(nextPuzzle);
    final preparedStart = _preparePuzzleStart(nextPuzzle);
    setState(() {
      selectedTag = matchingTag;
      selectedTheme =
          matchingTag == null ? null : _themeForLiveTag(matchingTag);
      themePuzzle = nextPuzzle;
      puzzleSolved = false;
      puzzleFeedback = null;
      boardFenOverride = preparedStart?.fen;
      answerHintVisible = false;
      inputLocked = false;
      physicalSetupReady = false;
      physicalMoveArmed = false;
      boardFlipped = _puzzleBoardShouldFlip(
        preparedStart?.fen ?? nextPuzzle.fen,
      );
      lastMove = preparedStart?.lastMove ?? const [];
      puzzleMoveIndex = preparedStart?.moveIndex ?? 0;
      puzzleLoading = false;
      puzzleError = null;
      boardResetSerial += 1;
    });
    if (_updateMovePuzzleOrientation(
      preparedStart?.fen ?? nextPuzzle.fen,
    )) {
      _resetPhysicalBoardOrientationCache();
    }
    _showPhysicalSetupPrompt(nextPuzzle);
    unawaited(_syncPuzzleBoardAndLeds());
  }

  api.PuzzleTag? _tagForPuzzle(api.Puzzle? puzzle) {
    if (puzzle == null) return null;
    final puzzleTags = puzzle.tags.split(RegExp(r'\s+')).toSet();
    for (final tag in info?.tags ?? const <api.PuzzleTag>[]) {
      if (puzzleTags.contains(tag.key)) return tag;
    }
    return null;
  }

  List<api.PuzzleTag> _extraLiveTags() {
    final tags = info?.tags ?? const <api.PuzzleTag>[];
    final curatedKeys = {
      for (final group in lichessPuzzleThemeGroups)
        for (final theme in group.themes) theme.tag,
    };
    return tags.where((tag) => !curatedKeys.contains(tag.key)).toList();
  }

  void _subscribePhysicalBoard() {
    final gateway = widget.boardGateway;
    if (gateway == null) return;
    _boardFenSub = gateway.boardFenStream.listen((fen) {
      final referenceFen = _currentPuzzleFen(themePuzzle, boardFenOverride);
      _handlePhysicalFen(
        _movePuzzleOrientationLocked
            ? _boardOrientation.normalizeWithLockedMapping(
                fen,
                referenceFens: [referenceFen],
              )
            : _boardOrientation.normalizeAndTrack(
                fen,
                referenceFens: [referenceFen],
                onMappingChanged: (_) => _resetPhysicalBoardOrientationCache(),
              ),
      );
    });
    if (gateway.currentState == PhysicalBoardConnectionState.connected) {
      unawaited(gateway.enableRealtimeFen());
    }
  }

  void _resetPhysicalBoardOrientationCache() {
    _moveBoardTargetFen = null;
    _puzzleLedSync.reset();
  }

  bool _updateMovePuzzleOrientation(String fen) {
    final shouldLock = _usesPuzzleMoveSideOrientation(
      gateway: widget.boardGateway,
      settings: widget.boardSettings,
    );
    if (!shouldLock) {
      if (!_movePuzzleOrientationLocked) return false;
      _movePuzzleOrientationLocked = false;
      _boardOrientation.reset();
      return true;
    }
    _movePuzzleOrientationLocked = true;
    return _boardOrientation.setManualMapping(
      _puzzleMoveSideMapping(fen),
    );
  }

  bool get _canUseVoiceMoves =>
      widget.boardGateway?.boardModel == PhysicalBoardModel.move &&
      widget.boardGateway?.currentState ==
          PhysicalBoardConnectionState.connected;

  bool get _useMoveTransitionGuard => usesMovePuzzleTransitionGuard(
        gateway: widget.boardGateway,
        isChessnutClockDevice: widget.isChessnutClockDevice,
      );

  Future<void> _toggleVoiceMoves() async {
    await _voiceMoves.toggle(
      context: context,
      canUse: _canUseVoiceMoves,
      settings: widget.boardSettings,
      unavailableMessage: 'Connect Chessnut Move first.',
    );
  }

  Future<String?> _openAiKeyForVoiceMove() async {
    final result = await widget.apiClient.getOpenaiKey();
    final key = result.data?.trim();
    if (result.isSuccess && key != null && key.isNotEmpty) return key;
    throw VoiceMoveOpenAiSessionException(
      result.status.errorMessage ??
          'Online voice recognition could not get an OpenAI session.',
    );
  }

  void _refreshVoiceMovesState() {
    if (mounted) setState(() {});
  }

  void _showVoiceMoveMessage(String message) {
    if (!mounted) return;
    setState(() => puzzleFeedback = message);
  }

  void _handleVoiceMoveUci(String uci) {
    final puzzle = themePuzzle;
    if (puzzle == null) return;
    final move = _puzzleMoveFromUci(
      _currentPuzzleFen(puzzle, boardFenOverride),
      uci,
    );
    if (move == null) {
      _showVoiceMoveMessage('Voice move $uci is not legal here.');
      return;
    }
    _handleSoftwareMove(move, initiatedByVoice: true);
  }

  void _handleSoftwareMove(
    ChessBoardMove move, {
    bool initiatedByVoice = false,
  }) {
    if (!_canStartPuzzleMove(themePuzzle)) {
      setState(() => boardResetSerial += 1);
      return;
    }
    _handlePuzzleMove(move, initiatedByVoice: initiatedByVoice);
  }

  void _handlePhysicalFen(String boardFen) {
    latestPhysicalBoardFen = _boardOnlyFen(boardFen);
    if (_useMoveTransitionGuard) {
      if (puzzleLoading) return;
      final moveBoardTargetFen = _moveBoardTargetFen;
      if (moveBoardTargetFen != null) {
        if (latestPhysicalBoardFen == moveBoardTargetFen) {
          _moveBoardTargetFen = null;
        } else {
          return;
        }
      }
      final pendingVoiceAdvanceFen = _pendingVoiceAdvanceFen;
      if (pendingVoiceAdvanceFen != null) {
        if (latestPhysicalBoardFen != pendingVoiceAdvanceFen) return;
        final generation = _pendingVoiceAdvanceGeneration;
        _clearPendingVoiceAdvance();
        if (generation != null) {
          _scheduleAdvanceAfterSolved(generation, fromPhysical: true);
        }
        return;
      }
    }
    final currentFen = _currentPuzzleFen(themePuzzle, boardFenOverride);
    final pendingFen = _pendingPhysicalMoveFen;
    if (pendingFen != null && pendingFen != latestPhysicalBoardFen) {
      _cancelPendingPhysicalMove();
    }
    if (pendingFen == latestPhysicalBoardFen &&
        _pendingPhysicalMoveTimer?.isActive == true) {
      return;
    }
    if (physicalSetupReady || physicalMoveArmed) {
      final move = _resolvePuzzleBoardMove(
        themePuzzle,
        boardFen,
        currentFen: currentFen,
        moveIndex: puzzleMoveIndex,
      );
      if (move != null) {
        _cancelMoveRestore();
        _schedulePhysicalPuzzleMove(
          move,
          puzzle: themePuzzle!,
          sourceFen: currentFen,
          observedBoardFen: latestPhysicalBoardFen!,
        );
        return;
      }
    }
    if (!_refreshPhysicalSetupGate(themePuzzle)) {
      _scheduleMoveRestoreIfNeeded(currentFen, observedBoardFen: boardFen);
      return;
    }
    _cancelMoveRestore();
  }

  void _schedulePhysicalPuzzleMove(
    ChessBoardMove move, {
    required api.Puzzle puzzle,
    required String sourceFen,
    required String observedBoardFen,
  }) {
    final delay = widget.boardSettings.fenDelay;
    if (delay <= Duration.zero) {
      _cancelPendingPhysicalMove();
      _handlePuzzleMove(move, fromPhysical: true);
      return;
    }
    if (_pendingPhysicalMoveFen == observedBoardFen &&
        _pendingPhysicalMoveTimer?.isActive == true) {
      return;
    }
    _pendingPhysicalMoveTimer?.cancel();
    _pendingPhysicalMoveFen = observedBoardFen;
    final generation = _advanceGeneration;
    final moveIndex = puzzleMoveIndex;
    _pendingPhysicalMoveTimer = Timer(delay, () {
      _pendingPhysicalMoveTimer = null;
      _pendingPhysicalMoveFen = null;
      if (!mounted ||
          generation != _advanceGeneration ||
          !identical(themePuzzle, puzzle) ||
          puzzleSolved ||
          puzzleMoveIndex != moveIndex ||
          latestPhysicalBoardFen != observedBoardFen ||
          _boardOnlyFen(_currentPuzzleFen(puzzle, boardFenOverride)) !=
              _boardOnlyFen(sourceFen)) {
        return;
      }
      _handlePuzzleMove(move, fromPhysical: true);
    });
  }

  void _cancelPendingPhysicalMove() {
    _pendingPhysicalMoveTimer?.cancel();
    _pendingPhysicalMoveTimer = null;
    _pendingPhysicalMoveFen = null;
  }

  void _handlePuzzleMove(
    ChessBoardMove move, {
    bool fromPhysical = false,
    bool initiatedByVoice = false,
  }) {
    final puzzle = themePuzzle;
    if (puzzle == null || puzzleSolved || inputLocked) return;
    if (!fromPhysical && !_canStartPuzzleMove(puzzle)) return;
    final previousFen = _currentPuzzleFen(puzzle, boardFenOverride);
    final previousLastMove = lastMove;
    final expected = _puzzleExpectedMove(puzzle, puzzleMoveIndex);
    final correct =
        expected != null && _moveMatchesPuzzleAnswer(move.uci, expected);
    if (!correct) {
      _playPuzzleSound(AppSoundEvent.puzzleError);
      setState(() {
        lastMove = [move.from, move.to];
        boardFenOverride = move.fen;
        inputLocked = true;
        physicalMoveArmed = false;
        puzzleFeedback = 'Try again: follow the highlighted board move.';
      });
      if (fromPhysical) {
        _scheduleMoveRestoreIfNeeded(previousFen, observedBoardFen: move.fen);
      }
      _scheduleRetryReset(
        _advanceGeneration,
        restoreFen: previousFen,
        restoreLastMove: previousLastMove,
      );
      unawaited(_syncPhysicalSetupLedsFor(puzzle, previousFen));
      return;
    }

    final answerMoves = _puzzleAnswerMoves(puzzle);
    final nextIndex = puzzleMoveIndex + 1;
    if (nextIndex >= answerMoves.length) {
      _completePuzzleMove(
        move,
        nextMoveIndex: nextIndex,
        fromPhysical: fromPhysical,
        initiatedByVoice: initiatedByVoice,
      );
      return;
    }
    final replyMove = _puzzleMoveAt(puzzle, nextIndex, move.fen);
    if (replyMove != null) {
      final followingIndex = nextIndex + 1;
      if (followingIndex >= answerMoves.length) {
        _completePuzzleMove(
          replyMove,
          nextMoveIndex: followingIndex,
          fromPhysical: fromPhysical,
          initiatedByVoice: initiatedByVoice,
        );
        return;
      }
      setState(() {
        puzzleMoveIndex = followingIndex;
        lastMove = [replyMove.from, replyMove.to];
        boardFenOverride = replyMove.fen;
        inputLocked = false;
        puzzleFeedback = null;
        answerHintVisible = false;
        physicalSetupReady = _isPuzzlePhysicalSetupReady(
          latestPhysicalBoardFen,
          puzzle,
          replyMove.fen,
        );
        physicalMoveArmed = physicalSetupReady;
        boardResetSerial += 1;
      });
      unawaited(_syncPuzzleBoardAndLeds());
      return;
    }

    setState(() {
      lastMove = [move.from, move.to];
      boardFenOverride = move.fen;
      inputLocked = false;
      puzzleFeedback = null;
      answerHintVisible = false;
      physicalSetupReady = _isPuzzlePhysicalSetupReady(
        latestPhysicalBoardFen,
        puzzle,
        move.fen,
      );
      physicalMoveArmed = physicalSetupReady;
      boardResetSerial += 1;
    });
    unawaited(_syncPuzzleBoardAndLeds());
  }

  void _completePuzzleMove(
    ChessBoardMove move, {
    required int nextMoveIndex,
    bool fromPhysical = false,
    bool initiatedByVoice = false,
  }) {
    _cancelMoveRestore();
    setState(() {
      puzzleMoveIndex = nextMoveIndex;
      lastMove = [move.from, move.to];
      boardFenOverride = move.fen;
      inputLocked = true;
      puzzleSolved = true;
      puzzleFeedback = 'Puzzle solved';
      answerHintVisible = false;
      physicalMoveArmed = false;
    });
    _playPuzzleSound(AppSoundEvent.puzzleSuccess);
    widget.onPuzzleSolved?.call();
    unawaited(_clearPuzzleLeds());
    if (!fromPhysical && _armVoiceAdvanceForMoveBoard(move.fen)) return;
    _scheduleAdvanceAfterSolved(
      _advanceGeneration,
      fromPhysical: fromPhysical,
    );
  }

  void _showAnswerHint() {
    if (themePuzzle == null || puzzleSolved) return;
    if (!_canStartPuzzleMove(themePuzzle)) return;
    setState(() => answerHintVisible = true);
    unawaited(_syncPuzzleLeds());
  }

  void _scheduleRetryReset(
    int generation, {
    required String restoreFen,
    required List<String> restoreLastMove,
  }) {
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(_puzzleMoveFeedbackDelay, () {
      _feedbackTimer = null;
      if (!mounted || generation != _advanceGeneration || puzzleSolved) return;
      setState(() {
        boardFenOverride = restoreFen;
        answerHintVisible = false;
        inputLocked = false;
        lastMove = restoreLastMove;
        physicalSetupReady = _isPuzzlePhysicalSetupReady(
          latestPhysicalBoardFen,
          themePuzzle,
          restoreFen,
        );
        physicalMoveArmed = physicalSetupReady;
        boardResetSerial += 1;
      });
      unawaited(_syncPuzzleBoardAndLeds());
    });
  }

  void _scheduleMoveRestoreIfNeeded(
    String restoreFen, {
    required String observedBoardFen,
  }) {
    final gateway = widget.boardGateway;
    if (gateway == null ||
        gateway.boardModel != PhysicalBoardModel.move ||
        gateway.currentState != PhysicalBoardConnectionState.connected ||
        themePuzzle == null ||
        _boardOnlyFen(observedBoardFen) == _boardOnlyFen(restoreFen)) {
      _cancelMoveRestore();
      return;
    }
    final generation = _advanceGeneration;
    final normalizedObservedFen = _boardOnlyFen(observedBoardFen);
    final samePendingRestore = _pendingMoveRestoreFen == restoreFen &&
        _pendingMoveRestoreObservedFen == normalizedObservedFen &&
        _pendingMoveRestoreGeneration == generation;
    if (!samePendingRestore) {
      _pendingMoveRestoreFen = restoreFen;
      _pendingMoveRestoreObservedFen = normalizedObservedFen;
      _pendingMoveRestoreGeneration = generation;
      _pendingMoveRestoreElapsed = Duration.zero;
    }
    _schedulePendingMoveRestoreTimer();
  }

  void _schedulePendingMoveRestoreTimer() {
    final restoreFen = _pendingMoveRestoreFen;
    final generation = _pendingMoveRestoreGeneration;
    if (restoreFen == null || generation == null) {
      return;
    }
    if (_pendingMoveRestoreElapsed >= widget.boardSettings.moveRestoreDelay) {
      _restorePendingMovePosition(restoreFen, generation);
      return;
    }
    if (_moveRestoreTimer?.isActive ?? false) return;
    _moveRestoreTimer = Timer.periodic(_moveRestoreCheckInterval, (timer) {
      _pendingMoveRestoreElapsed += _moveRestoreCheckInterval;
      if (_pendingMoveRestoreElapsed >= widget.boardSettings.moveRestoreDelay) {
        _restorePendingMovePosition(restoreFen, generation);
      }
    });
  }

  void _reschedulePendingMoveRestore() {
    if (_pendingMoveRestoreFen == null) return;
    _schedulePendingMoveRestoreTimer();
  }

  void _restorePendingMovePosition(String restoreFen, int generation) {
    final gateway = widget.boardGateway;
    if (!mounted ||
        generation != _advanceGeneration ||
        puzzleSolved ||
        gateway == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected ||
        _boardOnlyFen(latestPhysicalBoardFen ?? '') ==
            _boardOnlyFen(restoreFen)) {
      _cancelMoveRestore();
      return;
    }
    _cancelMoveRestore();
    unawaited(gateway.setMoveBoardFen(
      restoreFen,
      isReverse: _boardOrientation.isReversed,
    ));
  }

  void _cancelMoveRestore() {
    _moveRestoreTimer?.cancel();
    _moveRestoreTimer = null;
    _pendingMoveRestoreFen = null;
    _pendingMoveRestoreObservedFen = null;
    _pendingMoveRestoreGeneration = null;
    _pendingMoveRestoreElapsed = Duration.zero;
  }

  bool _armVoiceAdvanceForMoveBoard(String fen) {
    final gateway = widget.boardGateway;
    if (!_useMoveTransitionGuard ||
        gateway == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      return false;
    }
    final targetFen = _boardOnlyFen(fen);
    if (_boardOnlyFen(latestPhysicalBoardFen ?? '') == targetFen) return false;
    _pendingVoiceAdvanceFen = targetFen;
    _pendingVoiceAdvanceGeneration = _advanceGeneration;
    _moveBoardTargetFen = targetFen;
    unawaited(_sendSolvedVoicePositionToMoveBoard(
      fen,
      targetFen: targetFen,
      generation: _advanceGeneration,
    ));
    return true;
  }

  Future<void> _sendSolvedVoicePositionToMoveBoard(
    String fen, {
    required String targetFen,
    required int generation,
  }) async {
    final sent = await widget.boardGateway?.setMoveBoardFen(
          fen,
          isReverse: _boardOrientation.isReversed,
        ) ??
        false;
    if (sent ||
        !mounted ||
        generation != _advanceGeneration ||
        _pendingVoiceAdvanceFen != targetFen) {
      return;
    }
    _moveBoardTargetFen = null;
    _clearPendingVoiceAdvance();
    _scheduleAdvanceAfterSolved(generation);
  }

  void _clearPendingVoiceAdvance() {
    _pendingVoiceAdvanceFen = null;
    _pendingVoiceAdvanceGeneration = null;
  }

  void _scheduleAdvanceAfterSolved(
    int generation, {
    bool fromPhysical = false,
  }) {
    _feedbackTimer?.cancel();
    _advanceTimer?.cancel();
    if (fromPhysical) {
      if (!mounted || generation != _advanceGeneration || !puzzleSolved) {
        return;
      }
      _advanceTimer = Timer(_physicalPuzzleAdvanceDelay, () {
        _advanceTimer = null;
        if (!mounted || generation != _advanceGeneration || !puzzleSolved) {
          return;
        }
        unawaited(_loadNextThemePuzzle());
      });
      return;
    }
    _feedbackTimer = Timer(_puzzleMoveFeedbackDelay, () {
      _feedbackTimer = null;
      if (!mounted || generation != _advanceGeneration || !puzzleSolved) {
        return;
      }
      _advanceTimer = Timer(_puzzleAdvanceDelay, () {
        _advanceTimer = null;
        if (!mounted || generation != _advanceGeneration || !puzzleSolved) {
          return;
        }
        unawaited(_loadNextThemePuzzle());
      });
    });
  }

  Future<void> _syncPuzzleBoardAndLeds() async {
    final fen = _currentPuzzleFen(themePuzzle, boardFenOverride);
    if (_useMoveTransitionGuard) {
      await _sendThemePositionToMoveBoard(fen);
      await _syncPuzzleLeds();
      return;
    }
    await _syncPuzzleLeds();
    await _sendPuzzlePositionToBoard(
      gateway: widget.boardGateway,
      puzzle: themePuzzle,
      fen: fen,
      orientation: _boardOrientation,
    );
  }

  Future<void> _sendThemePositionToMoveBoard(String fen) async {
    final gateway = widget.boardGateway;
    final puzzle = themePuzzle;
    if (gateway == null ||
        puzzle == null ||
        gateway.boardModel != PhysicalBoardModel.move ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      return;
    }
    final targetFen = _boardOnlyFen(fen);
    if (_boardOnlyFen(latestPhysicalBoardFen ?? '') == targetFen) {
      _moveBoardTargetFen = null;
      return;
    }
    if (_moveBoardTargetFen == targetFen) return;
    _cancelMoveRestore();
    _moveBoardTargetFen = targetFen;
    final sent = await gateway.setMoveBoardFen(
      fen,
      isReverse: _boardOrientation.isReversed,
    );
    if (!sent && _moveBoardTargetFen == targetFen) {
      _moveBoardTargetFen = null;
    }
  }

  Future<void> _syncPuzzleLeds() async {
    final setupPlan = _physicalSetupLedPlan(
      gateway: widget.boardGateway,
      puzzle: themePuzzle,
      currentFen: _currentPuzzleFen(themePuzzle, boardFenOverride),
      latestPhysicalBoardFen: latestPhysicalBoardFen,
      solved: puzzleSolved,
      answerVisible: answerHintVisible,
      orientation: _boardOrientation,
    );
    await _puzzleLedSync.send(widget.boardGateway, setupPlan.request);
    if (setupPlan.setupActive) {
      return;
    }
    await _puzzleLedSync.send(
      widget.boardGateway,
      _answerLedRequest(
        gateway: widget.boardGateway,
        puzzle: themePuzzle,
        solved: puzzleSolved,
        visible: answerHintVisible,
        currentFen: _currentPuzzleFen(themePuzzle, boardFenOverride),
        moveIndex: puzzleMoveIndex,
        orientation: _boardOrientation,
      ),
    );
  }

  Future<void> _clearPuzzleLeds() async {
    await _puzzleLedSync.send(
      widget.boardGateway,
      _clearLedRequest(widget.boardGateway),
    );
  }

  Future<void> _syncPhysicalSetupLedsFor(
    api.Puzzle puzzle,
    String currentFen,
  ) async {
    final setupPlan = _physicalSetupLedPlan(
      gateway: widget.boardGateway,
      puzzle: puzzle,
      currentFen: currentFen,
      latestPhysicalBoardFen: latestPhysicalBoardFen,
      solved: false,
      orientation: _boardOrientation,
    );
    await _puzzleLedSync.send(widget.boardGateway, setupPlan.request);
  }

  bool _canStartPuzzleMove(api.Puzzle? puzzle) {
    if (!_physicalSetupRequired(widget.boardGateway, puzzle)) return true;
    if (physicalSetupReady) return true;
    return _refreshPhysicalSetupGate(puzzle);
  }

  bool _refreshPhysicalSetupGate(api.Puzzle? puzzle) {
    if (!_physicalSetupRequired(widget.boardGateway, puzzle)) {
      if (!physicalSetupReady) {
        setState(() {
          physicalSetupReady = true;
          physicalMoveArmed = true;
        });
      }
      return true;
    }
    final ready = _isPuzzlePhysicalSetupReady(
      latestPhysicalBoardFen,
      puzzle,
      _currentPuzzleFen(puzzle, boardFenOverride),
    );
    if (ready) {
      if (!physicalSetupReady || puzzleFeedback == _physicalSetupPromptText) {
        setState(() {
          physicalSetupReady = true;
          physicalMoveArmed = true;
          if (puzzleFeedback == _physicalSetupPromptText) {
            puzzleFeedback = null;
          }
        });
      }
      unawaited(_syncPuzzleLeds());
      return true;
    }
    if (physicalSetupReady) {
      setState(() {
        physicalSetupReady = false;
        puzzleFeedback ??= _physicalSetupPromptText;
        answerHintVisible = false;
      });
      unawaited(_syncPuzzleLeds());
      return false;
    }
    _showPhysicalSetupPrompt(puzzle);
    return false;
  }

  void _showPhysicalSetupPrompt(api.Puzzle? puzzle) {
    if (!_physicalSetupRequired(widget.boardGateway, puzzle)) return;
    if (physicalSetupReady || puzzleFeedback == _physicalSetupPromptText) {
      unawaited(_syncPuzzleLeds());
      return;
    }
    setState(() {
      physicalSetupReady = false;
      puzzleFeedback = _physicalSetupPromptText;
      answerHintVisible = false;
    });
    unawaited(_syncPuzzleLeds());
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final androidPhoneLandscape = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !widget.isChessnutClockDevice &&
        viewport.width > viewport.height &&
        viewport.longestSide < 1000 &&
        viewport.shortestSide < 600;
    final availableThemeCount = lichessPuzzleThemeGroups.fold<int>(
          0,
          (total, group) => total + group.themes.length,
        ) +
        _extraLiveTags().length;
    return ResponsivePage(
      compactLandscapeOverride: androidPhoneLandscape,
      children: (context, spec) {
        final windowsPuzzleLayout = !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.windows &&
            spec.canSplit;
        final horizontalLayout = spec.compactLandscape ||
            (_isDesktopPuzzlePlatform() && spec.canSplit);
        final windowsBoardMaxSize =
            (spec.heightAfterHeader() - 20).clamp(300.0, 640.0).toDouble();
        final board = SizedBox(
          key: const ValueKey('puzzle-theme-board-area'),
          child: ResponsiveBoardFrame(
            maxSize: spec.compactLandscape
                ? (spec.heightAfterHeader() - spec.gutter - 8)
                    .clamp(220.0, 384.0)
                    .toDouble()
                : windowsPuzzleLayout
                    ? windowsBoardMaxSize
                    : (spec.compact ? 300 : 430),
            padding: EdgeInsets.all(spec.compactLandscape ? 4 : 10),
            builder: (size) => themePuzzle == null
                ? _EmptyPuzzleBoard(size: size)
                : inputLocked && boardFenOverride != null
                    ? _SolvedPuzzleBoard(
                        size: size,
                        fen: boardFenOverride!,
                        lastMove: lastMove,
                        flipped: boardFlipped,
                        showCoordinates: widget.showBoardCoordinates,
                      )
                    : AbsorbPointer(
                        absorbing: inputLocked,
                        child: InteractiveChessBoard(
                          key: ValueKey(
                            'theme-board-${themePuzzle?.id}-$boardResetSerial',
                          ),
                          size: size,
                          initialFen:
                              _currentPuzzleFen(themePuzzle, boardFenOverride),
                          flipped: boardFlipped,
                          lastMove: lastMove,
                          showCoordinates: widget.showBoardCoordinates,
                          tapSquaresWithOverlay: true,
                          hintMove: answerHintVisible
                              ? _hintMoveForPuzzle(
                                  themePuzzle,
                                  solved: puzzleSolved,
                                  currentFen: _currentPuzzleFen(
                                    themePuzzle,
                                    boardFenOverride,
                                  ),
                                  moveIndex: puzzleMoveIndex,
                                )
                              : null,
                          onMove: _handleSoftwareMove,
                        ),
                      ),
          ),
        );
        final compactFeedback = spec.compactLandscape && puzzleFeedback != null;
        final boardFen = _currentPuzzleFen(themePuzzle, boardFenOverride);
        final voiceMovesShortcut = _canUseVoiceMoves
            ? VoiceMovesShortcutButton(
                enabled: _voiceMoves.enabled,
                listening: _voiceMoves.listening,
                onPressed: _toggleVoiceMoves,
                valueKey: const ValueKey('puzzle-themes-voice-moves-toggle'),
              )
            : null;
        final chooser = SizedBox(
          key: const ValueKey('puzzle-theme-chooser-card'),
          width: double.infinity,
          child: _ThemeChooserCard(
            info: info,
            loading: infoLoading,
            error: infoError,
            selectedTheme: selectedTheme,
            selectedTag: selectedTag,
            puzzle: themePuzzle,
            puzzleLoading: puzzleLoading,
            puzzleError: puzzleError,
            puzzleSolved: puzzleSolved,
            puzzleFeedback: compactFeedback ? null : puzzleFeedback,
            availableThemeCount: availableThemeCount,
            compact: spec.compactLandscape,
            onChooseTheme: _showThemePicker,
            onChoosePuzzleNumber: _showPuzzleNumberDialog,
            onNext: _loadNextThemePuzzle,
          ),
        );
        return [
          ScreenHeader(
            title: 'Puzzle Themes',
            leading: IconButton.filledTonal(
              onPressed: () => widget.onNavigate('Back'),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (voiceMovesShortcut != null) ...[
                  voiceMovesShortcut,
                  const SizedBox(width: 8),
                ],
                IconButton.filledTonal(
                  key: const ValueKey('puzzle-themes-flip-board'),
                  tooltip: 'Flip board',
                  onPressed: () => setState(() => boardFlipped = !boardFlipped),
                  icon: const Icon(Icons.flip_camera_android_rounded),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Hint',
                  onPressed: themePuzzle == null || puzzleSolved
                      ? null
                      : _showAnswerHint,
                  icon: const Icon(Icons.lightbulb_rounded),
                ),
              ],
            ),
          ),
          SizedBox(height: spec.gutter),
          if (horizontalLayout)
            ResponsiveSplit(
              key: androidPhoneLandscape
                  ? const ValueKey('puzzle-themes-android-phone-landscape')
                  : const ValueKey('puzzle-themes-horizontal-layout'),
              breakpoint: androidPhoneLandscape ? 600 : 900,
              spacing: spec.gutter,
              leadingFlex:
                  windowsPuzzleLayout ? 7 : (spec.compactLandscape ? 6 : 5),
              trailingFlex:
                  windowsPuzzleLayout ? 5 : (spec.compactLandscape ? 5 : 7),
              leading: board,
              trailing: SectionColumn(
                spacing: 8,
                children: [
                  if (compactFeedback)
                    _PuzzleResultCard(
                      solved: puzzleSolved,
                      text: puzzleFeedback!,
                      compact: true,
                    ),
                  _PuzzleTurnCard(
                    fen: boardFen,
                    compactLandscapeOverride: androidPhoneLandscape,
                  ),
                  chooser,
                ],
              ),
            )
          else ...[
            board,
            const SizedBox(height: 12),
            _PuzzleTurnCard(fen: boardFen),
            const SizedBox(height: 12),
            chooser,
          ],
        ];
      },
    );
  }

  Future<void> _showThemePicker() async {
    final selection = await showModalBottomSheet<_ThemeSelection>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxWidth:
            MediaQuery.sizeOf(context).width >= 720 ? 680 : double.infinity,
      ),
      builder: (context) => _ThemePickerSheet(
        groups: lichessPuzzleThemeGroups,
        liveTags: info?.tags ?? const [],
        extraLiveTags: _extraLiveTags(),
        selectedKey: selectedTag?.key,
      ),
    );
    if (selection == null) return;
    await _openTheme(selection.theme, selection.liveTag);
  }

  Future<void> _showPuzzleNumberDialog() async {
    var puzzleNumber = '';
    String? errorText;
    final puzzleId = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialogShell(
          icon: Icons.numbers_rounded,
          title: 'Puzzle number',
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('puzzle-number-open-button'),
              onPressed: () {
                final id = int.tryParse(puzzleNumber.trim());
                if (id != null && id > 0) {
                  Navigator.of(dialogContext).pop(id);
                  return;
                }
                setDialogState(
                  () => errorText = 'Enter a valid puzzle number.',
                );
              },
              child: const Text('Open'),
            ),
          ],
          child: TextField(
            key: const ValueKey('puzzle-number-field'),
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.go,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Puzzle ID',
              errorText: errorText,
            ),
            onChanged: (value) => puzzleNumber = value,
            onSubmitted: (value) {
              final id = int.tryParse(value.trim());
              if (id != null && id > 0) {
                Navigator.of(dialogContext).pop(id);
                return;
              }
              setDialogState(
                () => errorText = 'Enter a valid puzzle number.',
              );
            },
          ),
        ),
      ),
    );
    if (!mounted || puzzleId == null) return;
    await _openPuzzleById(puzzleId);
  }

  void _playPuzzleSound(AppSoundEvent event) {
    if (!widget.soundEffectsEnabled) return;
    if (!widget.soundEffects.allows(event)) return;
    unawaited(widget.appSoundService.play(event));
  }
}

class MistakeBookScreen extends StatefulWidget {
  const MistakeBookScreen({
    required this.onNavigate,
    this.refreshToken = 0,
    this.store,
    this.onOpenReportMove,
    this.showBoardCoordinates = false,
    this.isChessnutClockDevice = false,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final int refreshToken;
  final MistakeBookStore? store;
  final ValueChanged<MistakeBookEntry>? onOpenReportMove;
  final bool showBoardCoordinates;
  final bool isChessnutClockDevice;

  @override
  State<MistakeBookScreen> createState() => _MistakeBookScreenState();
}

class _MistakeBookScreenState extends State<MistakeBookScreen> {
  late Future<MistakeBookState> _stateFuture;
  MistakeBookState? _state;
  final TextEditingController _mistakeSearchController =
      TextEditingController();
  MistakeBookEntry? _selected;
  String _classificationFilter = _mistakeAllClassifications;
  String _sourceFilter = _mistakeAllSources;
  String _themeFilter = _mistakeAllThemes;
  _MistakeStatusFilter _statusFilter = _MistakeStatusFilter.active;
  int _pageIndex = 0;
  bool _bulkDeleteMode = false;
  final Set<String> _bulkDeleteIds = {};

  @override
  void initState() {
    super.initState();
    _stateFuture = _readState();
  }

  @override
  void didUpdateWidget(covariant MistakeBookScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.store, widget.store) ||
        oldWidget.refreshToken != widget.refreshToken) {
      _stateFuture = _readState();
      _selected = null;
    }
  }

  @override
  void dispose() {
    _mistakeSearchController.dispose();
    super.dispose();
  }

  Future<MistakeBookState> _readState() async {
    final store = widget.store;
    final state = store == null ? const MistakeBookState() : await store.read();
    _state = state;
    return state;
  }

  void _selectMistake(MistakeBookEntry entry) {
    if (_bulkDeleteMode) {
      setState(() {
        if (!_bulkDeleteIds.add(entry.id)) {
          _bulkDeleteIds.remove(entry.id);
        }
      });
      return;
    }
    setState(() {
      _selected = entry;
    });
  }

  void _startBulkDelete() {
    setState(() {
      _bulkDeleteMode = true;
      _bulkDeleteIds.clear();
    });
  }

  void _selectAllForBulkDelete(
    Iterable<MistakeBookEntry> entries, {
    required bool showAll,
  }) {
    setState(() {
      _bulkDeleteIds
        ..clear()
        ..addAll(entries.map((entry) => entry.id));
      if (showAll) {
        _statusFilter = _MistakeStatusFilter.all;
        _pageIndex = 0;
      }
    });
  }

  void _cancelBulkDelete() {
    setState(() {
      _bulkDeleteMode = false;
      _bulkDeleteIds.clear();
    });
  }

  void _adoptVisibleMistake(MistakeBookEntry entry) {
    _selected = entry;
  }

  void _resetMistakePage() {
    if (!mounted) return;
    setState(() {
      _pageIndex = 0;
    });
  }

  void _setClassificationFilter(String classification) {
    setState(() {
      _classificationFilter = classification;
      _pageIndex = 0;
    });
  }

  void _setSourceFilter(String source) {
    setState(() {
      _sourceFilter = source;
      _pageIndex = 0;
    });
  }

  void _setStatusFilter(_MistakeStatusFilter status) {
    setState(() {
      _statusFilter = status;
      _pageIndex = 0;
    });
  }

  void _setThemeFilter(String theme) {
    setState(() {
      _themeFilter = theme;
      _pageIndex = 0;
    });
  }

  Future<void> _toggleMastered(
    MistakeBookEntry entry, {
    required int pageSize,
  }) async {
    final currentState = _state ?? await _stateFuture;
    final mastered = !entry.mastered;
    await widget.store?.setMastered(entry.id, mastered: mastered);
    if (!mounted) return;
    final nextState = _setMistakeMastered(
      currentState,
      entry.id,
      mastered: mastered,
    );
    final nextSelection = _selectionAfterMastering(
      oldState: currentState,
      nextState: nextState,
      entry: entry,
      pageSize: pageSize,
    );
    setState(() {
      _state = nextState;
      _selected = nextSelection.entry;
      _pageIndex = nextSelection.pageIndex;
    });
  }

  Future<void> _deleteMistake(
    MistakeBookEntry entry, {
    required int pageSize,
  }) async {
    final confirmed = await _confirmMistakeDeletion(1);
    if (!confirmed) return;
    await _removeMistakes({entry.id}, pageSize: pageSize);
  }

  Future<void> _deleteSelectedMistakes({required int pageSize}) async {
    if (_bulkDeleteIds.isEmpty) return;
    final ids = Set<String>.from(_bulkDeleteIds);
    final confirmed = await _confirmMistakeDeletion(ids.length);
    if (!confirmed) return;
    await _removeMistakes(ids, pageSize: pageSize);
  }

  Future<bool> _confirmMistakeDeletion(int count) async {
    final multiple = count > 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialogShell(
        icon: Icons.delete_outline_rounded,
        title: multiple ? 'Delete $count mistakes?' : 'Delete mistake?',
        subtitle: multiple
            ? 'This removes the selected mistakes from your Mistake Book. The original games and reports will remain saved.'
            : 'This removes it from your Mistake Book. The original game and report will remain saved.',
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
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ),
        ],
        child: const SizedBox.shrink(),
      ),
    );
    return confirmed == true;
  }

  Future<void> _removeMistakes(
    Set<String> ids, {
    required int pageSize,
  }) async {
    await widget.store?.deleteMany(ids);
    if (!mounted) return;
    final currentState = _state ?? await _stateFuture;
    final nextEntries = Map<String, MistakeBookEntry>.from(currentState.entries)
      ..removeWhere((id, _) => ids.contains(id));
    final nextState = MistakeBookState(
      entries: Map.unmodifiable(nextEntries),
      deletedIds: Set.unmodifiable({...currentState.deletedIds, ...ids}),
    );
    final filtered = _filterMistakes(
      entries: nextState.entries.values,
      now: DateTime.now(),
      search: _mistakeSearchController.text,
      classification: _classificationFilter,
      source: _sourceFilter,
      theme: _themeFilter,
      status: _statusFilter,
    );
    final nextPage = filtered.isEmpty
        ? 0
        : math.min(_pageIndex, (filtered.length - 1) ~/ math.max(1, pageSize));
    setState(() {
      _state = nextState;
      _pageIndex = nextPage;
      _selected = filtered.isEmpty ? null : filtered.first;
      _bulkDeleteMode = false;
      _bulkDeleteIds.clear();
    });
  }

  MistakeBookState _setMistakeMastered(
    MistakeBookState state,
    String id, {
    required bool mastered,
  }) {
    final entry = state.entries[id];
    if (entry == null) return state;
    return MistakeBookState(
      entries: Map.unmodifiable({
        ...state.entries,
        id: entry.copyWith(mastered: mastered, updatedAt: DateTime.now()),
      }),
      deletedIds: state.deletedIds,
    );
  }

  ({MistakeBookEntry? entry, int pageIndex}) _selectionAfterMastering({
    required MistakeBookState oldState,
    required MistakeBookState nextState,
    required MistakeBookEntry entry,
    required int pageSize,
  }) {
    final effectivePageSize = math.max(1, pageSize);
    final now = DateTime.now();
    final oldFiltered = _filterMistakes(
      entries: oldState.entries.values,
      now: now,
      search: _mistakeSearchController.text,
      classification: _classificationFilter,
      source: _sourceFilter,
      theme: _themeFilter,
      status: _statusFilter,
    );
    final nextFiltered = _filterMistakes(
      entries: nextState.entries.values,
      now: now,
      search: _mistakeSearchController.text,
      classification: _classificationFilter,
      source: _sourceFilter,
      theme: _themeFilter,
      status: _statusFilter,
    );
    if (nextFiltered.isEmpty) return (entry: null, pageIndex: 0);

    final oldIndex = oldFiltered.indexWhere((item) => item.id == entry.id);
    final entryStillVisible =
        nextFiltered.indexWhere((item) => item.id == entry.id);
    final fallbackIndex = (_pageIndex * effectivePageSize)
        .clamp(0, nextFiltered.length - 1)
        .toInt();
    final targetIndex = oldIndex < 0
        ? fallbackIndex
        : entryStillVisible >= 0
            ? math.min(entryStillVisible + 1, nextFiltered.length - 1)
            : oldIndex.clamp(0, nextFiltered.length - 1).toInt();
    return (
      entry: nextFiltered[targetIndex],
      pageIndex: targetIndex ~/ effectivePageSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final windowsDesktop =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    final androidApp = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !widget.isChessnutClockDevice;
    final sharedMistakeFilters = windowsDesktop ||
        androidApp ||
        widget.isChessnutClockDevice ||
        (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS));
    final appMistakeDeletion = !kIsWeb &&
        switch (defaultTargetPlatform) {
          TargetPlatform.android ||
          TargetPlatform.iOS ||
          TargetPlatform.windows ||
          TargetPlatform.macOS =>
            true,
          TargetPlatform.linux || TargetPlatform.fuchsia => false,
        };
    final androidPhoneLandscape = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !widget.isChessnutClockDevice &&
        viewport.width > viewport.height &&
        viewport.longestSide < 1000 &&
        viewport.shortestSide < 600;
    final iosLandscape = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        viewport.width > viewport.height;
    final windowsLikeLandscape = androidPhoneLandscape ||
        iosLandscape ||
        (!kIsWeb &&
            defaultTargetPlatform == TargetPlatform.android &&
            widget.isChessnutClockDevice &&
            viewport.width > viewport.height);
    return FutureBuilder<MistakeBookState>(
      future: _stateFuture,
      builder: (context, snapshot) {
        final state = _state ?? snapshot.data ?? const MistakeBookState();
        final now = DateTime.now();
        final dueEntries = state.due(now);
        final allEntries = state.entries.values.toList(growable: false);
        return ResponsivePage(
          compactLandscapeOverride: windowsLikeLandscape,
          children: (context, spec) {
            final pageSize = spec.compactLandscape ? 6 : 10;
            final filteredEntries = _filterMistakes(
              entries: allEntries,
              now: now,
              search: _mistakeSearchController.text,
              classification: _classificationFilter,
              source: _sourceFilter,
              theme: _themeFilter,
              status: _statusFilter,
            );
            final pageCount = filteredEntries.isEmpty
                ? 1
                : (filteredEntries.length / pageSize).ceil();
            final safePageIndex =
                _pageIndex.clamp(0, math.max(0, pageCount - 1)).toInt();
            final visibleEntries = filteredEntries
                .skip(safePageIndex * pageSize)
                .take(pageSize)
                .toList(growable: false);
            final selectedFromVisible = _selected == null ||
                    !visibleEntries.any((entry) => entry.id == _selected!.id)
                ? null
                : _selected;
            final fallbackSelected = selectedFromVisible ??
                (visibleEntries.isNotEmpty
                    ? visibleEntries.first
                    : filteredEntries.isEmpty
                        ? null
                        : filteredEntries.first);
            final selected = spec.canSplit || androidPhoneLandscape
                ? fallbackSelected
                : selectedFromVisible;
            final filtersActive =
                _mistakeSearchController.text.trim().isNotEmpty ||
                    _classificationFilter != _mistakeAllClassifications ||
                    _sourceFilter != _mistakeAllSources ||
                    _themeFilter != _mistakeAllThemes ||
                    _statusFilter != _MistakeStatusFilter.active;

            if (safePageIndex != _pageIndex) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  _pageIndex = safePageIndex;
                });
              });
            }
            if (selected != null && _selected?.id != selected.id) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _selected?.id == selected.id) return;
                setState(() => _adoptVisibleMistake(selected));
              });
            }

            Widget reviewPanel(MistakeBookEntry selectedEntry) {
              final compactWindowsLayout = windowsLikeLandscape;
              final compactBoardSize =
                  spec.heightAfterHeader(min: 0).clamp(220.0, 340.0).toDouble();
              return _MistakeReviewPanel(
                entry: selectedEntry,
                maxBoardSize: compactWindowsLayout
                    ? compactBoardSize
                    : spec.compactLandscape
                        ? 366
                        : (spec.canSplit ? 500 : 292),
                minBoardSize: compactWindowsLayout
                    ? math.min(280.0, compactBoardSize)
                    : 320,
                compactLandscape: spec.compactLandscape,
                stackDetails: windowsLikeLandscape,
                showCoordinates: widget.showBoardCoordinates,
                onOpenReport: widget.onOpenReportMove == null
                    ? null
                    : () => widget.onOpenReportMove!(selectedEntry),
                onMarkMastered: () => _toggleMastered(
                  selectedEntry,
                  pageSize: pageSize,
                ),
                onDelete: appMistakeDeletion
                    ? () => _deleteMistake(
                          selectedEntry,
                          pageSize: pageSize,
                        )
                    : null,
              );
            }

            Widget mistakeList({required bool inlineReview}) {
              if (spec.compactLandscape && !windowsLikeLandscape) {
                return _MistakeClockListPane(
                  toolbar: _MistakeClockToolbar(
                    notMasteredCount: state.entries.values
                        .where((entry) => !entry.mastered)
                        .length,
                    totalCount: state.total,
                    masteredCount: state.masteredCount,
                    searchController: _mistakeSearchController,
                    classificationFilter: _classificationFilter,
                    sourceFilter: _sourceFilter,
                    statusFilter: _statusFilter,
                    themeCounts: state.themeCounts(),
                    selectedTheme: _themeFilter,
                    pageIndex: safePageIndex,
                    pageSize: pageSize,
                    totalFilteredCount: filteredEntries.length,
                    onSearchChanged: (_) => _resetMistakePage(),
                    onClassificationChanged: _setClassificationFilter,
                    onSourceChanged: _setSourceFilter,
                    onStatusChanged: _setStatusFilter,
                    onThemeSelected: _setThemeFilter,
                    onNotMastered: () =>
                        _setStatusFilter(_MistakeStatusFilter.active),
                    onTotalSaved: () =>
                        _setStatusFilter(_MistakeStatusFilter.all),
                    onMastered: () =>
                        _setStatusFilter(_MistakeStatusFilter.mastered),
                    onPrevious: safePageIndex == 0
                        ? null
                        : () => setState(() {
                              _pageIndex = safePageIndex - 1;
                            }),
                    onNext: safePageIndex >= pageCount - 1
                        ? null
                        : () => setState(() {
                              _pageIndex = safePageIndex + 1;
                            }),
                    androidPhoneLandscape: androidPhoneLandscape,
                    bulkDeleteActive: appMistakeDeletion && _bulkDeleteMode,
                    bulkDeleteCount: _bulkDeleteIds.length,
                    onStartBulkDelete:
                        appMistakeDeletion ? _startBulkDelete : null,
                    onSelectAllBulkDelete: appMistakeDeletion
                        ? () => _selectAllForBulkDelete(
                              filtersActive ? filteredEntries : allEntries,
                              showAll: !filtersActive,
                            )
                        : null,
                    selectAllBulkDeleteTooltip: filtersActive
                        ? 'Select all filtered mistakes'
                        : 'Select all saved mistakes',
                    onConfirmBulkDelete: appMistakeDeletion
                        ? () => _deleteSelectedMistakes(pageSize: pageSize)
                        : null,
                    onCancelBulkDelete:
                        appMistakeDeletion ? _cancelBulkDelete : null,
                  ),
                  empty: filteredEntries.isEmpty
                      ? (filtersActive
                          ? const _MistakeNoMatchesCard()
                          : const _MistakeAllCaughtUpCard())
                      : null,
                  entries: visibleEntries
                      .map(
                        (entry) => _MistakeListEntry(
                          entry: entry,
                          compact: true,
                          selected: selected?.id == entry.id,
                          onTap: () => _selectMistake(entry),
                          selectionMode: appMistakeDeletion && _bulkDeleteMode,
                          selectedForBulkDelete:
                              _bulkDeleteIds.contains(entry.id),
                        ),
                      )
                      .toList(growable: false),
                );
              }

              final windowsStyleList = SectionColumn(
                spacing: 12,
                children: [
                  _MistakeBookHero(
                    dueCount: dueEntries.length,
                    notMasteredCount: state.entries.values
                        .where((entry) => !entry.mastered)
                        .length,
                    totalCount: state.total,
                    masteredCount: state.masteredCount,
                    selectedStatus: _statusFilter,
                    onNotMastered: () =>
                        _setStatusFilter(_MistakeStatusFilter.active),
                    onTotalSaved: () =>
                        _setStatusFilter(_MistakeStatusFilter.all),
                    onMastered: () =>
                        _setStatusFilter(_MistakeStatusFilter.mastered),
                  ),
                  if (sharedMistakeFilters)
                    _MistakeBookWindowsFiltersCard(
                      searchController: _mistakeSearchController,
                      sourceFilter: _sourceFilter,
                      themeCounts: state.themeCounts(),
                      selectedTheme: _themeFilter,
                      onSearchChanged: (_) => _resetMistakePage(),
                      onSourceChanged: _setSourceFilter,
                      onThemeSelected: _setThemeFilter,
                    )
                  else ...[
                    _MistakeBookFilterBar(
                      searchController: _mistakeSearchController,
                      classificationFilter: _classificationFilter,
                      sourceFilter: _sourceFilter,
                      statusFilter: _statusFilter,
                      onSearchChanged: (_) => _resetMistakePage(),
                      onClassificationChanged: _setClassificationFilter,
                      onSourceChanged: _setSourceFilter,
                      onStatusChanged: _setStatusFilter,
                    ),
                    _MistakeThemeCard(
                      themeCounts: state.themeCounts(),
                      selectedTheme: _themeFilter,
                      onThemeSelected: _setThemeFilter,
                    ),
                  ],
                  if (filteredEntries.isNotEmpty)
                    _MistakeBookPager(
                      pageIndex: safePageIndex,
                      pageSize: pageSize,
                      totalCount: filteredEntries.length,
                      onPrevious: safePageIndex == 0
                          ? null
                          : () => setState(() {
                                _pageIndex = safePageIndex - 1;
                              }),
                      onNext: safePageIndex >= pageCount - 1
                          ? null
                          : () => setState(() {
                                _pageIndex = safePageIndex + 1;
                              }),
                      bulkDeleteActive: appMistakeDeletion && _bulkDeleteMode,
                      bulkDeleteCount: _bulkDeleteIds.length,
                      chessClockLayout: widget.isChessnutClockDevice,
                      onStartBulkDelete:
                          appMistakeDeletion ? _startBulkDelete : null,
                      onSelectAllBulkDelete: appMistakeDeletion
                          ? () => _selectAllForBulkDelete(
                                filtersActive ? filteredEntries : allEntries,
                                showAll: !filtersActive,
                              )
                          : null,
                      selectAllBulkDeleteTooltip: filtersActive
                          ? 'Select all filtered mistakes'
                          : 'Select all saved mistakes',
                      onConfirmBulkDelete: appMistakeDeletion
                          ? () => _deleteSelectedMistakes(pageSize: pageSize)
                          : null,
                      onCancelBulkDelete:
                          appMistakeDeletion ? _cancelBulkDelete : null,
                    ),
                  for (final entry in visibleEntries) ...[
                    _MistakeListEntry(
                      entry: entry,
                      selected: selected?.id == entry.id,
                      onTap: () => _selectMistake(entry),
                      selectionMode: appMistakeDeletion && _bulkDeleteMode,
                      selectedForBulkDelete: _bulkDeleteIds.contains(entry.id),
                    ),
                    if (inlineReview && selected?.id == entry.id)
                      reviewPanel(entry),
                  ],
                  if (filteredEntries.isEmpty)
                    filtersActive
                        ? const _MistakeNoMatchesCard()
                        : const _MistakeAllCaughtUpCard(),
                ],
              );
              if (!windowsLikeLandscape) return windowsStyleList;
              return SingleChildScrollView(
                key: const ValueKey('mistake-book-clock-windows-list'),
                padding: const EdgeInsets.only(bottom: 4),
                child: windowsStyleList,
              );
            }

            return [
              ScreenHeader(
                title: 'Mistake Book',
                subtitle: 'From your game reviews',
                leading: IconButton.filledTonal(
                  onPressed: () => widget.onNavigate('Back'),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                trailing: IconButton.filledTonal(
                  onPressed: () => widget.onNavigate('Analysis'),
                  icon: const Icon(Icons.analytics_rounded),
                ),
              ),
              SizedBox(height: spec.gutter),
              if (snapshot.connectionState != ConnectionState.done)
                const _MistakeLoadingCard()
              else if (state.entries.isEmpty)
                _MistakeEmptyCard(
                  onAnalyze: () => widget.onNavigate('Analysis'),
                )
              else if ((spec.canSplit || windowsLikeLandscape) &&
                  selected != null)
                SizedBox(
                  key: androidPhoneLandscape
                      ? const ValueKey(
                          'mistake-book-android-phone-landscape',
                        )
                      : windowsLikeLandscape
                          ? const ValueKey(
                              'mistake-book-clock-windows-layout',
                            )
                          : null,
                  height: spec.compactLandscape
                      ? spec.heightAfterHeader(
                          min: windowsLikeLandscape ? 0 : 360,
                        )
                      : null,
                  child: ResponsiveSplit(
                    breakpoint: windowsLikeLandscape ? 600 : 900,
                    spacing: spec.gutter,
                    leadingFlex: androidPhoneLandscape
                        ? 6
                        : windowsLikeLandscape
                            ? 6
                            : spec.compactLandscape
                                ? 5
                                : 6,
                    trailingFlex: androidPhoneLandscape
                        ? 6
                        : windowsLikeLandscape
                            ? 5
                            : spec.compactLandscape
                                ? 7
                                : 5,
                    leading: mistakeList(inlineReview: false),
                    trailing: reviewPanel(selected),
                  ),
                )
              else
                mistakeList(inlineReview: selected != null),
            ];
          },
        );
      },
    );
  }
}

class _MistakeLoadingCard extends StatelessWidget {
  const _MistakeLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const GlassPanel(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Loading mistakes from your saved reviews...',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _MistakeEmptyCard extends StatelessWidget {
  const _MistakeEmptyCard({required this.onAnalyze});

  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      key: const ValueKey('mistake-book-empty-card'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'No review mistakes yet',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            'Run a Standard report from Game Review. Mistakes and blunders will appear here automatically.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            key: const ValueKey('mistake-book-empty-analyze-button'),
            label: 'Analyze a game',
            icon: Icons.analytics_rounded,
            onPressed: onAnalyze,
          ),
        ],
      ),
    );
  }
}

const _mistakeAllClassifications = 'All';
const _mistakeAllThemes = 'All themes';
const _mistakeAllSources = 'All sources';
const _mistakeSources = ['Bot', 'OTB', 'Career', 'Online'];
const _mistakeClassifications = [
  _mistakeAllClassifications,
  'Blunder',
  'Missed win',
  'Critical swing',
  'Mistake',
  'Inaccuracy',
];

enum _MistakeStatusFilter {
  all('All'),
  due('Not mastered'),
  active('Active'),
  mastered('Mastered');

  const _MistakeStatusFilter(this.label);

  final String label;
}

List<MistakeBookEntry> _filterMistakes({
  required Iterable<MistakeBookEntry> entries,
  required DateTime now,
  required String search,
  required String classification,
  String source = _mistakeAllSources,
  required String theme,
  required _MistakeStatusFilter status,
}) {
  final normalizedSearch = search.trim().toLowerCase();
  final filtered = entries.where((entry) {
    if (classification != _mistakeAllClassifications &&
        entry.classification != classification) {
      return false;
    }
    if (source != _mistakeAllSources &&
        _mistakeSourceForEntry(entry) != source) {
      return false;
    }
    if (theme != _mistakeAllThemes && entry.theme != theme) return false;
    final matchesStatus = switch (status) {
      _MistakeStatusFilter.all => true,
      _MistakeStatusFilter.due => entry.isDue(now),
      _MistakeStatusFilter.active => !entry.mastered,
      _MistakeStatusFilter.mastered => entry.mastered,
    };
    if (!matchesStatus) return false;
    if (normalizedSearch.isEmpty) return true;
    return [
      entry.sourceTitle,
      entry.moveSan,
      entry.bestMoveSan,
      entry.classification,
      entry.summary,
      entry.theme,
      entry.engineLine,
    ].any((value) => value.toLowerCase().contains(normalizedSearch));
  }).toList(growable: true);
  filtered.sort((a, b) {
    if (status != _MistakeStatusFilter.due) {
      final updatedCompare = b.updatedAt.compareTo(a.updatedAt);
      if (updatedCompare != 0) return updatedCompare;
    }
    final dueCompare = a.dueAt.compareTo(b.dueAt);
    if (dueCompare != 0) return dueCompare;
    final severityCompare = _mistakeSeverity(b.classification)
        .compareTo(_mistakeSeverity(a.classification));
    if (severityCompare != 0) return severityCompare;
    return b.updatedAt.compareTo(a.updatedAt);
  });
  return filtered;
}

String _mistakeSourceForEntry(MistakeBookEntry entry) {
  final pgn = entry.pgn.toLowerCase();
  if (pgn.contains('[playmode "career"') ||
      pgn.contains('[event "career') ||
      pgn.contains('career challenge')) {
    return 'Career';
  }
  if (pgn.contains('[playmode "otb"') ||
      pgn.contains('[event "otb') ||
      pgn.contains('move otb') ||
      pgn.contains('chessnut move')) {
    return 'OTB';
  }
  if (pgn.contains('lichess') || pgn.contains('chess.com')) {
    return 'Online';
  }
  return 'Bot';
}

int _mistakeSeverity(String classification) {
  return switch (classification) {
    'Blunder' => 5,
    'Missed win' => 4,
    'Critical swing' => 4,
    'Mistake' => 3,
    'Inaccuracy' => 2,
    _ => 1,
  };
}

class _MistakeBookFilterBar extends StatelessWidget {
  const _MistakeBookFilterBar({
    required this.searchController,
    required this.classificationFilter,
    required this.sourceFilter,
    required this.statusFilter,
    required this.onClassificationChanged,
    required this.onSourceChanged,
    required this.onStatusChanged,
    required this.onSearchChanged,
  });

  final TextEditingController searchController;
  final String classificationFilter;
  final String sourceFilter;
  final _MistakeStatusFilter statusFilter;
  final ValueChanged<String> onClassificationChanged;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<_MistakeStatusFilter> onStatusChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compactLandscape = isCompactLandscapeDevice(context);
    return RepaintBoundary(
      key: const ValueKey('mistake-book-filter-section'),
      child: GlassPanel(
        padding: EdgeInsets.all(compactLandscape ? 10 : 12),
        borderRadius: 14,
        tint: scheme.secondary.withValues(alpha: 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RepaintBoundary(
              key: const ValueKey('mistake-book-search-section'),
              child: _MistakeSearchField(
                controller: searchController,
                onChanged: onSearchChanged,
              ),
            ),
            const SizedBox(height: 10),
            if (!(!kIsWeb && defaultTargetPlatform == TargetPlatform.windows))
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final classification in _mistakeClassifications)
                    FilterChip(
                      key: ValueKey('mistake-classification-$classification'),
                      label: Text(classification),
                      selected: classificationFilter == classification,
                      onSelected: (_) =>
                          onClassificationChanged(classification),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      selectedColor:
                          _mistakeColor(classification).withValues(alpha: 0.14),
                    ),
                ],
              ),
            if (!(!kIsWeb && defaultTargetPlatform == TargetPlatform.windows))
              const SizedBox(height: 10),
            if (!(!kIsWeb && defaultTargetPlatform == TargetPlatform.windows))
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final status in _MistakeStatusFilter.values.where(
                    (status) => status != _MistakeStatusFilter.all,
                  ))
                    ChoiceChip(
                      label: Text(
                        _localizedMistakeText(context, status.label),
                      ),
                      selected: statusFilter == status,
                      onSelected: (_) => onStatusChanged(status),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final source in _mistakeSources)
                  FilterChip(
                    key: ValueKey('mistake-source-$source'),
                    label: Text(source),
                    selected: sourceFilter == source,
                    onSelected: (_) => onSourceChanged(
                      sourceFilter == source ? _mistakeAllSources : source,
                    ),
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MistakeClockToolbar extends StatelessWidget {
  const _MistakeClockToolbar({
    required this.notMasteredCount,
    required this.totalCount,
    required this.masteredCount,
    required this.searchController,
    required this.classificationFilter,
    required this.sourceFilter,
    required this.statusFilter,
    required this.themeCounts,
    required this.selectedTheme,
    required this.pageIndex,
    required this.pageSize,
    required this.totalFilteredCount,
    required this.onSearchChanged,
    required this.onClassificationChanged,
    required this.onSourceChanged,
    required this.onStatusChanged,
    required this.onThemeSelected,
    required this.onNotMastered,
    required this.onTotalSaved,
    required this.onMastered,
    required this.onPrevious,
    required this.onNext,
    this.androidPhoneLandscape = false,
    this.bulkDeleteActive = false,
    this.bulkDeleteCount = 0,
    this.onStartBulkDelete,
    this.onSelectAllBulkDelete,
    this.selectAllBulkDeleteTooltip = 'Select all mistakes',
    this.onConfirmBulkDelete,
    this.onCancelBulkDelete,
  });

  final int notMasteredCount;
  final int totalCount;
  final int masteredCount;
  final TextEditingController searchController;
  final String classificationFilter;
  final String sourceFilter;
  final _MistakeStatusFilter statusFilter;
  final Map<String, int> themeCounts;
  final String selectedTheme;
  final int pageIndex;
  final int pageSize;
  final int totalFilteredCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onClassificationChanged;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<_MistakeStatusFilter> onStatusChanged;
  final ValueChanged<String> onThemeSelected;
  final VoidCallback onNotMastered;
  final VoidCallback onTotalSaved;
  final VoidCallback onMastered;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool androidPhoneLandscape;
  final bool bulkDeleteActive;
  final int bulkDeleteCount;
  final VoidCallback? onStartBulkDelete;
  final VoidCallback? onSelectAllBulkDelete;
  final String selectAllBulkDeleteTooltip;
  final VoidCallback? onConfirmBulkDelete;
  final VoidCallback? onCancelBulkDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compactButtonStyle = androidPhoneLandscape
        ? const ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(36, 36)),
            maximumSize: WidgetStatePropertyAll(Size(36, 36)),
            padding: WidgetStatePropertyAll(EdgeInsets.zero),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          )
        : null;
    final topThemes = themeCounts.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    final start = totalFilteredCount == 0 ? 0 : pageIndex * pageSize + 1;
    final end = math.min(totalFilteredCount, (pageIndex + 1) * pageSize);
    return RepaintBoundary(
      key: const ValueKey('mistake-book-filter-section'),
      child: GlassPanel(
        key: const ValueKey('mistake-book-clock-toolbar'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        borderRadius: 14,
        tint: scheme.primary.withValues(alpha: 0.06),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RepaintBoundary(
              key: const ValueKey('mistake-book-pager-section'),
              child: Row(
                children: [
                  _MistakeClockStat(
                    key: const ValueKey('mistake-clock-stat-not-mastered'),
                    label: 'Not mastered',
                    value: notMasteredCount.toString(),
                    compact: androidPhoneLandscape,
                    selected: statusFilter == _MistakeStatusFilter.active,
                    onTap: onNotMastered,
                  ),
                  SizedBox(width: androidPhoneLandscape ? 4 : 8),
                  _MistakeClockStat(
                    key: const ValueKey('mistake-clock-stat-total-saved'),
                    label: 'Saved',
                    value: totalCount.toString(),
                    compact: androidPhoneLandscape,
                    selected: statusFilter == _MistakeStatusFilter.all,
                    onTap: onTotalSaved,
                  ),
                  SizedBox(width: androidPhoneLandscape ? 4 : 8),
                  _MistakeClockStat(
                    key: const ValueKey('mistake-clock-stat-mastered'),
                    label: androidPhoneLandscape ? 'Master' : 'Mastered',
                    value: masteredCount.toString(),
                    compact: androidPhoneLandscape,
                    selected: statusFilter == _MistakeStatusFilter.mastered,
                    onTap: onMastered,
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    tooltip: 'Previous page',
                    onPressed: onPrevious,
                    icon: const Icon(Icons.chevron_left_rounded),
                    style: androidPhoneLandscape
                        ? const ButtonStyle(
                            minimumSize: WidgetStatePropertyAll(Size(36, 36)),
                            maximumSize: WidgetStatePropertyAll(Size(36, 36)),
                            padding: WidgetStatePropertyAll(EdgeInsets.zero),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          )
                        : null,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$start-$end/$totalFilteredCount',
                    style: TextStyle(
                      fontSize: androidPhoneLandscape ? 12 : null,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    tooltip: 'Next page',
                    onPressed: onNext,
                    icon: const Icon(Icons.chevron_right_rounded),
                    style: androidPhoneLandscape
                        ? const ButtonStyle(
                            minimumSize: WidgetStatePropertyAll(Size(36, 36)),
                            maximumSize: WidgetStatePropertyAll(Size(36, 36)),
                            padding: WidgetStatePropertyAll(EdgeInsets.zero),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          )
                        : null,
                  ),
                  if (onStartBulkDelete != null && !bulkDeleteActive) ...[
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      key: const ValueKey('mistake-bulk-delete-start'),
                      tooltip: 'Batch delete',
                      onPressed: onStartBulkDelete,
                      icon: const Icon(Icons.delete_sweep_outlined),
                      style: compactButtonStyle,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (bulkDeleteActive) ...[
                    Tooltip(
                      message: selectAllBulkDeleteTooltip,
                      child: FilledButton.tonalIcon(
                        key: const ValueKey('mistake-bulk-select-all'),
                        onPressed: onSelectAllBulkDelete,
                        icon: const Icon(Icons.select_all_rounded),
                        label: const Text('Select all'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      key: const ValueKey('mistake-bulk-delete-cancel'),
                      tooltip: 'Cancel batch delete',
                      onPressed: onCancelBulkDelete,
                      icon: const Icon(Icons.close_rounded),
                      style: compactButtonStyle,
                    ),
                    const SizedBox(width: 4),
                    FilledButton.icon(
                      key: const ValueKey('mistake-bulk-delete-confirm'),
                      onPressed:
                          bulkDeleteCount == 0 ? null : onConfirmBulkDelete,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text('Delete ($bulkDeleteCount)'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  RepaintBoundary(
                    key: const ValueKey('mistake-book-search-section'),
                    child: SizedBox(
                      width: 152,
                      child: _MistakeSearchField(
                        controller: searchController,
                        onChanged: onSearchChanged,
                        compact: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  for (final source in _mistakeSources) ...[
                    FilterChip(
                      key: ValueKey('mistake-source-$source-clock'),
                      label: Text(source),
                      selected: sourceFilter == source,
                      onSelected: (_) => onSourceChanged(
                        sourceFilter == source ? _mistakeAllSources : source,
                      ),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (selectedTheme != _mistakeAllThemes) ...[
                    _MistakeChip(
                      label: 'All themes',
                      color: scheme.primary,
                      selected: true,
                      onTap: () => onThemeSelected(_mistakeAllThemes),
                    ),
                    const SizedBox(width: 6),
                  ],
                  for (var index = 0;
                      index < topThemes.length && index < 4;
                      index++) ...[
                    _MistakeChip(
                      label: topThemes[index].key,
                      color: _mistakeThemeColor(topThemes[index].key),
                      selected: selectedTheme == topThemes[index].key,
                      onTap: () => onThemeSelected(topThemes[index].key),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MistakeBookWindowsFiltersCard extends StatelessWidget {
  const _MistakeBookWindowsFiltersCard({
    required this.searchController,
    required this.sourceFilter,
    required this.themeCounts,
    required this.selectedTheme,
    required this.onSearchChanged,
    required this.onSourceChanged,
    required this.onThemeSelected,
  });

  final TextEditingController searchController;
  final String sourceFilter;
  final Map<String, int> themeCounts;
  final String selectedTheme;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<String> onThemeSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final themes = themeCounts.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    return GlassPanel(
      key: const ValueKey('mistake-book-windows-filters-card'),
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      tint: scheme.secondary.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MistakeSearchField(
            controller: searchController,
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final source in _mistakeSources)
                FilterChip(
                  key: ValueKey('mistake-source-$source'),
                  label: Text(source),
                  selected: sourceFilter == source,
                  onSelected: (_) => onSourceChanged(
                    sourceFilter == source ? _mistakeAllSources : source,
                  ),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 2),
          Text(
            'Recurring mistake themes',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            'Built from repeated Game Review classifications.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (selectedTheme != _mistakeAllThemes)
                _MistakeChip(
                  label: 'All themes',
                  color: scheme.primary,
                  selected: true,
                  onTap: () => onThemeSelected(_mistakeAllThemes),
                ),
              if (themes.isEmpty)
                const _MistakeChip(
                  label: 'No active themes',
                  color: Color(0xFF64748B),
                )
              else
                for (var index = 0; index < themes.length && index < 4; index++)
                  _MistakeChip(
                    label: themes[index].key,
                    color: _mistakeThemeColor(themes[index].key),
                    selected: selectedTheme == themes[index].key,
                    onTap: () => onThemeSelected(themes[index].key),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MistakeClockListPane extends StatelessWidget {
  const _MistakeClockListPane({
    required this.toolbar,
    required this.entries,
    this.empty,
  });

  final Widget toolbar;
  final List<Widget> entries;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    if (empty != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          toolbar,
          const SizedBox(height: 8),
          Expanded(child: empty!),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        toolbar,
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            key: const ValueKey('mistake-book-clock-list'),
            padding: const EdgeInsets.only(bottom: 4),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => entries[index],
          ),
        ),
      ],
    );
  }
}

class _MistakeClockStat extends StatelessWidget {
  const _MistakeClockStat({
    required this.label,
    required this.value,
    this.compact = false,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final bool compact;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: compact ? 48 : 78,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: selected ? 0.22 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: selected ? 0.95 : 0.12),
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _localizedMistakeText(context, label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected ? color : null,
                        fontSize: compact ? 9 : null,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  key: const ValueKey('mistake-clock-stat-selected'),
                  size: compact ? 11 : 14,
                  color: color,
                ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: compact ? 15 : 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class _MistakeSearchField extends StatelessWidget {
  const _MistakeSearchField({
    required this.controller,
    required this.onChanged,
    this.compact = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('mistake-book-search-field'),
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: compact ? const TextStyle(fontSize: 13) : null,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.search_rounded),
        hintText: 'Search mistakes',
        suffixIcon: controller.text.trim().isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(Icons.close_rounded),
              ),
        contentPadding: compact
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

Color _mistakeThemeColor(String theme) {
  return switch (theme) {
    'Blunder' => _mistakeColor('Blunder'),
    'Missed tactic' || 'Missed win' => _mistakeColor('Missed win'),
    'Critical swing' => _mistakeColor('Critical swing'),
    'Mistake' => _mistakeColor('Mistake'),
    'Inaccuracy' => _mistakeColor('Inaccuracy'),
    _ => const Color(0xFF38BDF8),
  };
}

class _MistakeBookPager extends StatelessWidget {
  const _MistakeBookPager({
    required this.pageIndex,
    required this.pageSize,
    required this.totalCount,
    required this.onPrevious,
    required this.onNext,
    this.bulkDeleteActive = false,
    this.bulkDeleteCount = 0,
    this.chessClockLayout = false,
    this.onStartBulkDelete,
    this.onSelectAllBulkDelete,
    this.selectAllBulkDeleteTooltip = 'Select all mistakes',
    this.onConfirmBulkDelete,
    this.onCancelBulkDelete,
  });

  final int pageIndex;
  final int pageSize;
  final int totalCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool bulkDeleteActive;
  final int bulkDeleteCount;
  final bool chessClockLayout;
  final VoidCallback? onStartBulkDelete;
  final VoidCallback? onSelectAllBulkDelete;
  final String selectAllBulkDeleteTooltip;
  final VoidCallback? onConfirmBulkDelete;
  final VoidCallback? onCancelBulkDelete;

  @override
  Widget build(BuildContext context) {
    final start = totalCount == 0 ? 0 : pageIndex * pageSize + 1;
    final end = math.min(totalCount, (pageIndex + 1) * pageSize);
    final compactControls = MediaQuery.sizeOf(context).width < 1100;
    final pagerRow = Row(
      children: [
        Expanded(
          child: Text(
            'Showing $start-$end of $totalCount',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Previous page',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        const SizedBox(width: 6),
        IconButton.filledTonal(
          tooltip: 'Next page',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        if (onStartBulkDelete != null) ...[
          const SizedBox(width: 8),
          if (bulkDeleteActive) ...[
            if (!chessClockLayout && compactControls)
              IconButton.filledTonal(
                key: const ValueKey('mistake-bulk-select-all'),
                tooltip: selectAllBulkDeleteTooltip,
                onPressed: onSelectAllBulkDelete,
                icon: const Icon(Icons.select_all_rounded),
              )
            else if (!chessClockLayout)
              Tooltip(
                message: selectAllBulkDeleteTooltip,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('mistake-bulk-select-all'),
                  onPressed: onSelectAllBulkDelete,
                  icon: const Icon(Icons.select_all_rounded),
                  label: const Text('Select all'),
                ),
              ),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              key: const ValueKey('mistake-bulk-delete-cancel'),
              tooltip: 'Cancel batch delete',
              onPressed: onCancelBulkDelete,
              icon: const Icon(Icons.close_rounded),
            ),
            const SizedBox(width: 6),
            if (compactControls)
              IconButton.filled(
                key: const ValueKey('mistake-bulk-delete-confirm'),
                tooltip: bulkDeleteCount == 0
                    ? 'Select mistakes to delete'
                    : 'Delete selected mistakes',
                onPressed: bulkDeleteCount == 0 ? null : onConfirmBulkDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              )
            else
              FilledButton.icon(
                key: const ValueKey('mistake-bulk-delete-confirm'),
                onPressed: bulkDeleteCount == 0 ? null : onConfirmBulkDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text('Delete ($bulkDeleteCount)'),
              ),
          ] else
            IconButton.filledTonal(
              key: const ValueKey('mistake-bulk-delete-start'),
              tooltip: 'Batch delete',
              onPressed: onStartBulkDelete,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ],
    );
    return RepaintBoundary(
      key: const ValueKey('mistake-book-pager-section'),
      child: chessClockLayout && bulkDeleteActive
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                pagerRow,
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Semantics(
                    button: true,
                    label: selectAllBulkDeleteTooltip,
                    child: InkWell(
                      key: const ValueKey('mistake-bulk-select-all'),
                      borderRadius: BorderRadius.circular(4),
                      onTap: onSelectAllBulkDelete,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 2,
                        ),
                        child: Text(
                          'Select all',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : pagerRow,
    );
  }
}

class _StormHero extends StatelessWidget {
  const _StormHero({
    required this.scheme,
    required this.puzzle,
    required this.loading,
    required this.remainingSeconds,
    required this.solvedCount,
    required this.combo,
    this.compactLandscapeOverride = false,
  });

  final ColorScheme scheme;
  final api.Puzzle? puzzle;
  final bool loading;
  final int remainingSeconds;
  final int solvedCount;
  final int combo;
  final bool compactLandscapeOverride;

  @override
  Widget build(BuildContext context) {
    final compactLandscape =
        compactLandscapeOverride || isCompactLandscapeDevice(context);
    return GlassPanel(
      padding: EdgeInsets.all(compactLandscape ? 10 : 14),
      tint: scheme.primary.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: compactLandscape ? 44 : 58,
                height: compactLandscape ? 44 : 58,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(
                    compactLandscape ? 12 : 16,
                  ),
                ),
                child: Icon(Icons.bolt_rounded, color: scheme.primary),
              ),
              SizedBox(width: compactLandscape ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatStormClock(remainingSeconds),
                      key: const ValueKey('puzzle-storm-clock'),
                      style: TextStyle(
                        fontSize: compactLandscape ? 28 : 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: compactLandscape ? 1 : 2),
                    Text(
                      loading
                          ? 'Loading live Lichess puzzle...'
                          : puzzle == null
                              ? 'Solve as many Lichess puzzles as you can.'
                              : 'Live puzzle #${puzzle!.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compactLandscape ? 8 : 14),
          ResponsiveGrid(
            minTileWidth: compactLandscape ? 86 : 100,
            maxColumns: 3,
            spacing: compactLandscape ? 6 : 8,
            childAspectRatio: compactLandscapeOverride
                ? 2.1
                : compactLandscape
                    ? 2.4
                    : 1.45,
            children: [
              _StormStat(
                label: 'Solved',
                value: solvedCount.toString(),
                compact: compactLandscape,
                valueKey: const ValueKey('puzzle-storm-solved-count'),
              ),
              _StormStat(
                label: 'Combo',
                value: '${combo}x',
                compact: compactLandscape,
                valueKey: const ValueKey('puzzle-storm-combo'),
              ),
              _StormStat(
                label: 'Rating band',
                value: _stormRatingBandLabel(
                  puzzle,
                  solvedCount: solvedCount,
                  combo: combo,
                ),
                compact: compactLandscape,
                valueKey: const ValueKey('puzzle-storm-rating-band'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MistakeBookHero extends StatelessWidget {
  const _MistakeBookHero({
    required this.dueCount,
    this.notMasteredCount,
    required this.totalCount,
    required this.masteredCount,
    required this.selectedStatus,
    this.onNotMastered,
    this.onTotalSaved,
    this.onMastered,
  });

  final int dueCount;
  final int? notMasteredCount;
  final int totalCount;
  final int masteredCount;
  final _MistakeStatusFilter selectedStatus;
  final VoidCallback? onNotMastered;
  final VoidCallback? onTotalSaved;
  final VoidCallback? onMastered;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      tint: scheme.primary.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.menu_book_rounded, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personal mistake training',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'From your game reviews',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      dueCount == 0
                          ? 'No due reviews right now. New analysis mistakes will appear here.'
                          : 'Replay the position before the mistake and find the better move.',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ResponsiveGrid(
            minTileWidth: 100,
            maxColumns: 3,
            spacing: 8,
            childAspectRatio: 1.45,
            children: [
              _MistakeStat(
                key: const ValueKey('mistake-stat-not-mastered'),
                label: 'Not mastered',
                value: '${notMasteredCount ?? dueCount}',
                selected: selectedStatus == _MistakeStatusFilter.active,
                onTap: onNotMastered,
              ),
              _MistakeStat(
                key: const ValueKey('mistake-stat-total-saved'),
                label: 'Total saved',
                value: '$totalCount',
                selected: selectedStatus == _MistakeStatusFilter.all,
                onTap: onTotalSaved,
              ),
              _MistakeStat(
                key: const ValueKey('mistake-stat-mastered'),
                label: 'Mastered',
                value: '$masteredCount',
                selected: selectedStatus == _MistakeStatusFilter.mastered,
                onTap: onMastered,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MistakeStat extends StatelessWidget {
  const _MistakeStat({
    required this.label,
    required this.value,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: selected ? 0.95 : 0.12),
          width: selected ? 2 : 1,
        ),
      ),
      child: GlassPanel(
        padding: const EdgeInsets.all(8),
        borderRadius: 11,
        tint: color.withValues(alpha: selected ? 0.22 : 0.08),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    key: const ValueKey('mistake-stat-selected'),
                    size: 18,
                    color: color,
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _localizedMistakeText(context, label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: selected ? color : null,
                    fontWeight: selected ? FontWeight.w800 : null,
                  ),
            ),
          ],
        ),
      ),
    );
    return onTap == null
        ? card
        : Semantics(
            button: true,
            selected: selected,
            label: label,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: card,
            ),
          );
  }
}

class _MistakeThemeCard extends StatelessWidget {
  const _MistakeThemeCard({
    required this.themeCounts,
    required this.selectedTheme,
    required this.onThemeSelected,
  });

  final Map<String, int> themeCounts;
  final String selectedTheme;
  final ValueChanged<String> onThemeSelected;

  @override
  Widget build(BuildContext context) {
    final entries = themeCounts.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recurring mistake themes',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            'Built from repeated Game Review classifications.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (selectedTheme != _mistakeAllThemes)
                _MistakeChip(
                  label: 'All themes',
                  color: Theme.of(context).colorScheme.primary,
                  selected: true,
                  onTap: () => onThemeSelected(_mistakeAllThemes),
                ),
              if (entries.isEmpty)
                const _MistakeChip(
                  label: 'No active themes',
                  color: Color(0xFF64748B),
                )
              else
                for (var index = 0;
                    index < entries.length && index < 4;
                    index++)
                  _MistakeChip(
                    label: entries[index].key,
                    color: _mistakeThemeColor(entries[index].key),
                    selected: selectedTheme == entries[index].key,
                    onTap: () => onThemeSelected(entries[index].key),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MistakeChip extends StatelessWidget {
  const _MistakeChip({
    required this.label,
    required this.color,
    this.maxWidth,
    this.selected = false,
    this.compact = false,
    this.onTap,
  });

  final String label;
  final Color color;
  final double? maxWidth;
  final bool selected;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: selected ? 0.18 : 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: selected ? 0.50 : 0.18),
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    final constrained = maxWidth == null
        ? chip
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth!),
            child: chip,
          );
    if (onTap == null) return constrained;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: constrained,
    );
  }
}

class _MistakeListEntry extends StatelessWidget {
  const _MistakeListEntry({
    required this.entry,
    required this.selected,
    required this.onTap,
    this.compact = false,
    this.selectionMode = false,
    this.selectedForBulkDelete = false,
  });

  final MistakeBookEntry entry;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;
  final bool selectionMode;
  final bool selectedForBulkDelete;

  @override
  Widget build(BuildContext context) {
    final color = _mistakeColor(entry.classification);
    final scheme = Theme.of(context).colorScheme;
    final themeLabel = _localizedMistakeText(context, entry.theme);
    final statusLabel = _localizedMistakeText(
      context,
      entry.mastered ? 'Mastered' : 'Not mastered',
    );
    return GlassPanel(
      key: ValueKey('mistake-list-entry-${entry.id}'),
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 7 : 12,
      ),
      borderRadius: compact ? 12 : 14,
      tint: color.withValues(
        alpha: selected || selectedForBulkDelete ? 0.12 : 0.06,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact) ...[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.error_outline_rounded, color: color, size: 21),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final chipWidth = (constraints.maxWidth * 0.46)
                        .clamp(72.0, 124.0)
                        .toDouble();
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.moveSan,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _MistakeChip(
                          label: entry.classification,
                          color: color,
                          maxWidth: chipWidth,
                          compact: compact,
                        ),
                      ],
                    );
                  },
                ),
                SizedBox(height: compact ? 3 : 5),
                Text(
                  'Best move: ${entry.bestMoveSan}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 13 : null,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${entry.sourceTitle} / $themeLabel / $statusLabel',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else ...[
                  const SizedBox(height: 2),
                  Text(
                    '$themeLabel / $statusLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          height: 1.0,
                        ),
                  ),
                ],
                if (!compact) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.visibility_rounded
                            : Icons.open_in_new_rounded,
                        size: 16,
                        color: selected ? scheme.primary : color,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        selected ? 'Viewing' : 'Open',
                        style: TextStyle(
                          color: selected ? scheme.primary : color,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (selectionMode)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Checkbox(
                key: ValueKey('mistake-bulk-select-${entry.id}'),
                value: selectedForBulkDelete,
                onChanged: (_) => onTap(),
              ),
            ),
        ],
      ),
    );
  }
}

class _MistakeReviewPanel extends StatelessWidget {
  const _MistakeReviewPanel({
    required this.entry,
    required this.maxBoardSize,
    required this.onMarkMastered,
    this.onOpenReport,
    this.minBoardSize = 320,
    this.compactLandscape = false,
    this.stackDetails = false,
    this.showCoordinates = false,
    this.onDelete,
  });

  final MistakeBookEntry entry;
  final double maxBoardSize;
  final VoidCallback onMarkMastered;
  final VoidCallback? onOpenReport;
  final double minBoardSize;
  final bool compactLandscape;
  final bool stackDetails;
  final bool showCoordinates;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final annotations = _mistakeMoveAnnotations(entry);
    if (compactLandscape && stackDetails) {
      return SingleChildScrollView(
        key: const ValueKey('mistake-book-android-review-scroll'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ResponsiveBoardFrame(
              maxSize: maxBoardSize,
              padding: const EdgeInsets.all(4),
              borderRadius: 12,
              builder: (size) => InteractiveChessBoard(
                key: ValueKey(
                  'mistake-review-board-${entry.id}-${entry.fenBefore}',
                ),
                size: size,
                initialFen: entry.fenBefore,
                showCoordinates: showCoordinates,
                moveAnnotations: annotations,
                interactionEnabled: false,
                showLegalTargets: false,
              ),
            ),
            const SizedBox(height: 8),
            _MistakeDetailCard(
              entry: entry,
              compact: true,
              onOpenReport: onOpenReport,
              onMarkMastered: onMarkMastered,
              onDelete: onDelete,
            ),
          ],
        ),
      );
    }
    if (compactLandscape) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final boardSize = math
              .min(maxBoardSize, constraints.maxWidth * 0.58)
              .clamp(minBoardSize, maxBoardSize)
              .toDouble();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: boardSize,
                child: ResponsiveBoardFrame(
                  maxSize: boardSize,
                  padding: const EdgeInsets.all(4),
                  borderRadius: 12,
                  builder: (size) => InteractiveChessBoard(
                    key: ValueKey(
                      'mistake-review-board-${entry.id}-${entry.fenBefore}',
                    ),
                    size: size,
                    initialFen: entry.fenBefore,
                    showCoordinates: showCoordinates,
                    moveAnnotations: annotations,
                    interactionEnabled: false,
                    showLegalTargets: false,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MistakeDetailCard(
                  entry: entry,
                  compact: true,
                  onOpenReport: onOpenReport,
                  onMarkMastered: onMarkMastered,
                  onDelete: onDelete,
                ),
              ),
            ],
          );
        },
      );
    }

    return SectionColumn(
      spacing: 12,
      children: [
        ResponsiveBoardFrame(
          maxSize: maxBoardSize,
          builder: (size) => InteractiveChessBoard(
            key: ValueKey(
              'mistake-review-board-${entry.id}-${entry.fenBefore}',
            ),
            size: size,
            initialFen: entry.fenBefore,
            showCoordinates: showCoordinates,
            moveAnnotations: annotations,
            interactionEnabled: false,
            showLegalTargets: false,
          ),
        ),
        _MistakeDetailCard(
          entry: entry,
          onOpenReport: onOpenReport,
          onMarkMastered: onMarkMastered,
          onDelete: onDelete,
        ),
      ],
    );
  }
}

class _MistakeAllCaughtUpCard extends StatelessWidget {
  const _MistakeAllCaughtUpCard();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'All caught up. New review mistakes will appear when they are due.',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _MistakeNoMatchesCard extends StatelessWidget {
  const _MistakeNoMatchesCard();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      child: Row(
        children: [
          Icon(
            Icons.filter_alt_off_rounded,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'No matching mistakes. Try another search or filter.',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _MistakeDetailCard extends StatelessWidget {
  const _MistakeDetailCard({
    required this.entry,
    required this.onMarkMastered,
    this.onOpenReport,
    this.onDelete,
    this.compact = false,
  });

  final MistakeBookEntry entry;
  final VoidCallback onMarkMastered;
  final VoidCallback? onOpenReport;
  final VoidCallback? onDelete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      key: ValueKey('mistake-detail-${entry.id}'),
      padding: EdgeInsets.all(compact ? 8 : 12),
      borderRadius: compact ? 12 : 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.moveSan,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              if (onOpenReport != null) ...[
                const SizedBox(width: 6),
                TextButton.icon(
                  key: ValueKey('mistake-open-report-${entry.id}'),
                  onPressed: onOpenReport,
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  label: Text(_localizedMistakeText(context, 'Open report')),
                ),
              ],
            ],
          ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            'Best move: ${entry.bestMoveSan}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                TextStyle(color: scheme.primary, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: compact ? 5 : 8),
          Text(
            entry.summary,
            maxLines: compact ? 3 : null,
            overflow: compact ? TextOverflow.ellipsis : null,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SizedBox(height: compact ? 8 : 12),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: ValueKey('mistake-toggle-mastered-${entry.id}'),
                    onPressed: onMarkMastered,
                    icon: Icon(
                      entry.mastered
                          ? Icons.check_circle_rounded
                          : Icons.check_rounded,
                    ),
                    label: Text(
                      entry.mastered
                          ? 'Mastered'
                          : compact
                              ? 'Mastered'
                              : 'Mark mastered',
                    ),
                  ),
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: ValueKey('mistake-delete-${entry.id}'),
                  tooltip: 'Delete mistake',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  style: ButtonStyle(
                    foregroundColor: WidgetStatePropertyAll(scheme.error),
                    backgroundColor: WidgetStatePropertyAll(
                      scheme.error.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

Color _mistakeColor(String classification) {
  return switch (classification) {
    'Blunder' => const Color(0xFFEF4444),
    'Missed win' => const Color(0xFFF97316),
    'Critical swing' => const Color(0xFFF59E0B),
    'Inaccuracy' => const Color(0xFFEAB308),
    _ => const Color(0xFF38BDF8),
  };
}

String _localizedMistakeText(BuildContext context, String text) {
  return AppStrings.maybeOf(context)?.t(text) ?? text;
}

class _StormStat extends StatelessWidget {
  const _StormStat({
    required this.label,
    required this.value,
    this.compact = false,
    this.valueKey,
  });

  final String label;
  final String value;
  final bool compact;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return GlassPanel(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 5 : 8,
      ),
      borderRadius: 12,
      tint: color.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              key: valueKey,
              style: TextStyle(
                color: color,
                fontSize: compact ? 15 : 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(height: compact ? 0 : 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: compact ? 11 : null,
                ),
          ),
        ],
      ),
    );
  }
}

class _PuzzleTurnCard extends StatelessWidget {
  const _PuzzleTurnCard({
    required this.fen,
    this.compactLandscapeOverride = false,
  });

  final String fen;
  final bool compactLandscapeOverride;

  @override
  Widget build(BuildContext context) {
    final compactLandscape =
        compactLandscapeOverride || isCompactLandscapeDevice(context);
    final whiteToMove = _whiteToMoveFromFen(fen);
    final color = whiteToMove
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.secondary;
    return GlassPanel(
      key: const ValueKey('puzzle-side-to-move-card'),
      padding: EdgeInsets.symmetric(
        horizontal: compactLandscape ? 10 : 12,
        vertical: compactLandscape ? 7 : 10,
      ),
      borderRadius: 14,
      tint: color.withValues(alpha: 0.09),
      child: Row(
        children: [
          Container(
            width: compactLandscape ? 28 : 34,
            height: compactLandscape ? 28 : 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(compactLandscape ? 8 : 10),
            ),
            child: Icon(
              whiteToMove ? Icons.circle_outlined : Icons.circle,
              color: color,
              size: compactLandscape ? 16 : 18,
            ),
          ),
          SizedBox(width: compactLandscape ? 8 : 10),
          Expanded(
            child: Text(
              whiteToMove ? 'White to move' : 'Black to move',
              key: const ValueKey('puzzle-side-to-move-label'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: compactLandscape ? 14 : 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StormQueueCard extends StatelessWidget {
  const _StormQueueCard({required this.puzzle});

  final api.Puzzle? puzzle;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current run',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _StormPuzzleRow(
            title: puzzle == null
                ? 'Loading puzzle...'
                : 'Live puzzle #${puzzle!.id}',
            tag: puzzle == null
                ? 'Waiting for the next tactic'
                : puzzle!.tags.split(RegExp(r'\s+')).join(' / '),
            rating: puzzle == null ? null : _stormPuzzleRatingLabel(puzzle!),
          ),
        ],
      ),
    );
  }
}

class _StormPuzzleRow extends StatelessWidget {
  const _StormPuzzleRow({
    required this.title,
    required this.tag,
    this.rating,
  });

  final String title;
  final String tag;
  final String? rating;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final detail = rating == null ? tag : '$tag / $rating';
    return GlassPanel(
      padding: const EdgeInsets.all(10),
      borderRadius: 12,
      tint: color.withValues(alpha: 0.09),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              rating == null
                  ? Icons.hourglass_top_rounded
                  : Icons.play_arrow_rounded,
              color: color,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                  detail,
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

class _StormRulesCard extends StatelessWidget {
  const _StormRulesCard();

  @override
  Widget build(BuildContext context) {
    return const GlassPanel(
      padding: EdgeInsets.all(12),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Storm rules',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          SizedBox(height: 10),
          _InfoLine(icon: Icons.timer_rounded, text: '3 minutes per run'),
          SizedBox(height: 8),
          _InfoLine(
              icon: Icons.local_fire_department_rounded,
              text: 'Combo grows while answers stay correct'),
          SizedBox(height: 8),
          _InfoLine(
              icon: Icons.add_circle_outline_rounded,
              text: 'Solved puzzles add points after sync'),
        ],
      ),
    );
  }
}

class _PuzzleResultCard extends StatelessWidget {
  const _PuzzleResultCard({
    required this.solved,
    required this.text,
    this.compact = false,
  });

  final bool solved;
  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = solved ? const Color(0xFF22C55E) : const Color(0xFFF59E0B);
    return GlassPanel(
      key: const ValueKey('puzzle-status-card'),
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 9)
          : const EdgeInsets.all(12),
      borderRadius: 14,
      tint: color.withValues(alpha: compact ? 0.14 : 0.08),
      child: Row(
        children: [
          Icon(
            solved ? Icons.check_circle_rounded : Icons.lightbulb_rounded,
            color: color,
            size: compact ? 28 : 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: compact ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: compact ? 16 : null,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPuzzleBoard extends StatelessWidget {
  const _EmptyPuzzleBoard({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final light = scheme.surfaceContainerHighest.withValues(alpha: 0.72);
    final dark = scheme.primary.withValues(alpha: 0.18);
    return SizedBox.square(
      key: const ValueKey('puzzle-empty-board'),
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
          ),
          itemCount: 64,
          itemBuilder: (context, index) {
            final row = index ~/ 8;
            final column = index % 8;
            return ColoredBox(
              color: (row + column).isEven ? light : dark,
            );
          },
        ),
      ),
    );
  }
}

class _SolvedPuzzleBoard extends StatelessWidget {
  const _SolvedPuzzleBoard({
    required this.size,
    required this.fen,
    required this.lastMove,
    this.flipped = false,
    this.showCoordinates = false,
  });

  final double size;
  final String fen;
  final List<String> lastMove;
  final bool flipped;
  final bool showCoordinates;

  @override
  Widget build(BuildContext context) {
    return ChessBoard(
      size: size,
      pieces: _puzzlePiecesFromFen(fen),
      lastMove: lastMove,
      flipped: flipped,
      showCoordinates: showCoordinates,
    );
  }
}

List<BoardPiece> _puzzlePiecesFromFen(String fen) {
  return ChessBoardState.fromFen(fen)
      .pieces
      .entries
      .map((entry) => BoardPiece(entry.key, entry.value))
      .toList(growable: false);
}

class _ThemeChooserCard extends StatelessWidget {
  const _ThemeChooserCard({
    required this.info,
    required this.loading,
    required this.error,
    required this.selectedTheme,
    required this.selectedTag,
    required this.puzzle,
    required this.puzzleLoading,
    required this.puzzleError,
    required this.puzzleSolved,
    required this.puzzleFeedback,
    required this.availableThemeCount,
    this.compact = false,
    required this.onChooseTheme,
    required this.onChoosePuzzleNumber,
    required this.onNext,
  });

  final api.PuzzleInfo? info;
  final bool loading;
  final String? error;
  final PuzzleTheme? selectedTheme;
  final api.PuzzleTag? selectedTag;
  final api.Puzzle? puzzle;
  final bool puzzleLoading;
  final String? puzzleError;
  final bool puzzleSolved;
  final String? puzzleFeedback;
  final int availableThemeCount;
  final bool compact;
  final VoidCallback onChooseTheme;
  final VoidCallback onChoosePuzzleNumber;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = selectedTheme;
    final tag = selectedTag;
    final activePuzzle = puzzle;
    final accent = theme?.color ?? scheme.secondary;
    final themePuzzleCount =
        tag == null ? null : '${_formatInt(tag.total)} puzzles';
    final databaseSummary = loading
        ? 'Loading puzzle database...'
        : info == null
            ? 'From Lichess Themes field'
            : '${_formatInt(info!.total)} in Lichess database';
    return GlassPanel(
      padding: EdgeInsets.all(compact ? 10 : 14),
      tint: accent.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 42 : 52,
                height: compact ? 42 : 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(compact ? 12 : 15),
                ),
                child: Icon(
                  theme?.icon ?? Icons.tune_rounded,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      theme == null ? 'Theme practice' : theme.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tag == null
                          ? databaseSummary
                          : '${_formatInt(tag.total)} puzzles',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tag == null ? null : accent,
                        fontSize: compact ? 15 : (tag == null ? 14 : 21),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 3),
                      Text(
                        tag == null
                            ? 'Choose one theme below the board.'
                            : databaseSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (loading)
                const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            _InlineStatus(
              icon: Icons.cloud_off_rounded,
              text: error!,
              color: scheme.error,
            ),
          ],
          if (puzzleError != null) ...[
            const SizedBox(height: 12),
            _InlineStatus(
              icon: Icons.error_outline_rounded,
              text: puzzleError!,
              color: scheme.error,
            ),
          ],
          if (puzzleFeedback != null) ...[
            const SizedBox(height: 12),
            _InlineStatus(
              icon: puzzleSolved
                  ? Icons.check_circle_rounded
                  : Icons.lightbulb_rounded,
              text: puzzleFeedback!,
              color: puzzleSolved
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFF59E0B),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('puzzle-theme-choose-button'),
                  onPressed: onChooseTheme,
                  icon: const Icon(Icons.category_rounded),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child:
                        Text(theme == null ? 'Choose theme' : 'Change theme'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('puzzle-number-button'),
                  onPressed: onChoosePuzzleNumber,
                  icon: const Icon(Icons.numbers_rounded),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Puzzle number'),
                  ),
                ),
              ),
            ],
          ),
          if (puzzleLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text(
              'Loading themed puzzle...',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
          if (!puzzleLoading && activePuzzle != null) ...[
            const SizedBox(height: 12),
            Text(
              'Theme puzzle #${activePuzzle.id}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 15 : 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ThemePill(
                    icon: Icons.tag_rounded,
                    text: activePuzzle.tags.split(RegExp(r'\s+')).join(' / '),
                    color: accent,
                  ),
                  _ThemePill(
                    icon: Icons.open_in_new_rounded,
                    text: activePuzzle.lichessId,
                    color: scheme.secondary,
                  ),
                ],
              ),
            ],
          ],
          if (!compact) ...[
            const SizedBox(height: 8),
            ResponsiveGrid(
              minTileWidth: 110,
              maxColumns: 3,
              spacing: 8,
              childAspectRatio: 1.65,
              children: [
                _ThemeMetric(
                  label: 'Themes',
                  value: _formatInt(availableThemeCount),
                  color: scheme.secondary,
                ),
                if (themePuzzleCount != null)
                  _ThemeMetric(
                    label: '${tag!.name} puzzles',
                    value: _formatInt(tag.total),
                    color: accent,
                  ),
                _ThemeMetric(
                  label: 'Source',
                  value: 'Lichess',
                  color: scheme.primary,
                ),
                const _ThemeMetric(
                  label: 'Mode',
                  value: 'One theme',
                  color: Color(0xFF22C55E),
                ),
              ],
            ),
          ],
          if (!puzzleLoading && activePuzzle != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('puzzle-theme-next-button'),
              onPressed: onNext,
              icon: const Icon(Icons.skip_next_rounded),
              label: const Text('Next puzzle'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThemeSelection {
  const _ThemeSelection({required this.theme, required this.liveTag});

  final PuzzleTheme theme;
  final api.PuzzleTag? liveTag;
}

class _ThemePickerSheet extends StatelessWidget {
  const _ThemePickerSheet({
    required this.groups,
    required this.liveTags,
    required this.extraLiveTags,
    required this.selectedKey,
  });

  final List<PuzzleThemeGroup> groups;
  final List<api.PuzzleTag> liveTags;
  final List<api.PuzzleTag> extraLiveTags;
  final String? selectedKey;

  @override
  Widget build(BuildContext context) {
    final compactLandscape = isCompactLandscapeDevice(context);
    return FractionallySizedBox(
      heightFactor: compactLandscape ? 0.96 : 0.86,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumn = compactLandscape && constraints.maxWidth >= 820;
          final sections = <Widget>[
            for (final group in groups)
              _ThemeGroupSection(
                group: group,
                liveTags: liveTags,
                selectedKey: selectedKey,
                compactLandscape: compactLandscape,
                onSelected: (theme, liveTag) => Navigator.pop(
                  context,
                  _ThemeSelection(theme: theme, liveTag: liveTag),
                ),
              ),
            if (extraLiveTags.isNotEmpty)
              _LiveThemeSection(
                liveTags: extraLiveTags,
                selectedKey: selectedKey,
                compactLandscape: compactLandscape,
                onSelected: (theme, liveTag) => Navigator.pop(
                  context,
                  _ThemeSelection(theme: theme, liveTag: liveTag),
                ),
              ),
          ];
          return ListView(
            key: const ValueKey('puzzle-theme-picker-list'),
            padding: EdgeInsets.fromLTRB(
              compactLandscape ? 12 : 16,
              0,
              compactLandscape ? 12 : 16,
              compactLandscape ? 12 : 24,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choose theme',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              SizedBox(height: compactLandscape ? 6 : 10),
              if (twoColumn)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final section in sections)
                      SizedBox(
                        width: (constraints.maxWidth - 32) / 2,
                        child: section,
                      ),
                  ],
                )
              else
                for (final section in sections) ...[
                  section,
                  SizedBox(height: compactLandscape ? 8 : 12),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _ThemeGroupSection extends StatelessWidget {
  const _ThemeGroupSection({
    required this.group,
    required this.liveTags,
    required this.selectedKey,
    required this.onSelected,
    this.compactLandscape = false,
  });

  final PuzzleThemeGroup group;
  final List<api.PuzzleTag> liveTags;
  final String? selectedKey;
  final void Function(PuzzleTheme theme, api.PuzzleTag? liveTag) onSelected;
  final bool compactLandscape;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.all(compactLandscape ? 10 : 12),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (!compactLandscape) ...[
            const SizedBox(height: 3),
            Text(group.subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
          SizedBox(height: compactLandscape ? 8 : 12),
          ResponsiveGrid(
            minTileWidth: compactLandscape ? 156 : 142,
            maxColumns: compactLandscape ? 2 : 3,
            spacing: compactLandscape ? 8 : 10,
            childAspectRatio: compactLandscape ? 2.85 : 1.02,
            children: [
              for (final theme in group.themes)
                _ThemeTile(
                  theme: theme,
                  liveTag: _liveTagFor(theme.tag),
                  selected: selectedKey == theme.tag,
                  compactLandscape: compactLandscape,
                  onTap: () => onSelected(theme, _liveTagFor(theme.tag)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  api.PuzzleTag? _liveTagFor(String key) {
    for (final tag in liveTags) {
      if (tag.key == key) return tag;
    }
    return null;
  }
}

class _LiveThemeSection extends StatelessWidget {
  const _LiveThemeSection({
    required this.liveTags,
    required this.selectedKey,
    required this.onSelected,
    this.compactLandscape = false,
  });

  final List<api.PuzzleTag> liveTags;
  final String? selectedKey;
  final void Function(PuzzleTheme theme, api.PuzzleTag? liveTag) onSelected;
  final bool compactLandscape;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.all(compactLandscape ? 10 : 12),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'More themes',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (!compactLandscape) ...[
            const SizedBox(height: 3),
            Text(
              'More puzzle themes available for this session',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          SizedBox(height: compactLandscape ? 8 : 12),
          ResponsiveGrid(
            minTileWidth: compactLandscape ? 156 : 142,
            maxColumns: compactLandscape ? 2 : 3,
            spacing: compactLandscape ? 8 : 10,
            childAspectRatio: compactLandscape ? 2.85 : 1.02,
            children: [
              for (var index = 0; index < liveTags.length; index++)
                _ThemeTile(
                  theme: _themeFromLiveTag(liveTags[index], index),
                  liveTag: liveTags[index],
                  selected: selectedKey == liveTags[index].key,
                  compactLandscape: compactLandscape,
                  onTap: () => onSelected(
                    _themeFromLiveTag(liveTags[index], index),
                    liveTags[index],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.theme,
    required this.liveTag,
    required this.selected,
    required this.onTap,
    this.compactLandscape = false,
  });

  final PuzzleTheme theme;
  final api.PuzzleTag? liveTag;
  final bool selected;
  final VoidCallback onTap;
  final bool compactLandscape;

  @override
  Widget build(BuildContext context) {
    final enabled = liveTag != null;
    final countLabel =
        liveTag == null ? theme.count : _formatInt(liveTag!.total);
    final tile = GlassPanel(
      key: ValueKey('puzzle-theme-tile-${theme.tag}'),
      padding: EdgeInsets.all(compactLandscape ? 8 : 10),
      borderRadius: 13,
      tint: theme.color.withValues(alpha: selected ? 0.15 : 0.06),
      onTap: onTap,
      child: compactLandscape
          ? Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: theme.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(theme.icon, color: theme.color, size: 17),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        liveTag?.name ?? theme.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        countLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                              enabled ? theme.color : const Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  ChessnutPulseBadge(
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: theme.color,
                      size: 18,
                    ),
                  ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: theme.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(theme.icon, color: theme.color, size: 18),
                    ),
                    const Spacer(),
                    if (selected)
                      ChessnutPulseBadge(
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: theme.color,
                          size: 19,
                        ),
                      )
                    else
                      Text(
                        countLabel,
                        style: TextStyle(
                          color:
                              enabled ? theme.color : const Color(0xFF64748B),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  theme.tag,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  liveTag?.name ?? theme.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  liveTag?.description ?? theme.description,
                  maxLines: enabled ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                if (!enabled) ...[
                  const SizedBox(height: 5),
                  const Text(
                    'Theme not available yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ],
              ],
            ),
    );
    return ChessnutAttentionBorder(
      active: selected,
      color: theme.color,
      borderRadius: 13,
      child: tile,
    );
  }
}

class _ThemeMetric extends StatelessWidget {
  const _ThemeMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(9),
      borderRadius: 12,
      tint: color.withValues(alpha: 0.08),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ThemePill extends StatelessWidget {
  const _ThemePill({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineStatus extends StatelessWidget {
  const _InlineStatus({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

PuzzleTheme _themeFromLiveTag(api.PuzzleTag tag, int index) {
  const icons = [
    Icons.extension_rounded,
    Icons.call_split_rounded,
    Icons.visibility_rounded,
    Icons.account_tree_rounded,
    Icons.center_focus_strong_rounded,
    Icons.route_rounded,
  ];
  const colors = [
    Color(0xFF38BDF8),
    Color(0xFFA78BFA),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF14B8A6),
  ];
  return PuzzleTheme(
    tag: tag.key,
    name: tag.name.isEmpty ? tag.key : tag.name,
    description: tag.description.isEmpty
        ? 'Fresh puzzle theme from the live library.'
        : tag.description,
    count: _formatInt(tag.total),
    icon: icons[index % icons.length],
    color: colors[index % colors.length],
  );
}

PuzzleTheme _themeForLiveTag(api.PuzzleTag tag) {
  for (final group in lichessPuzzleThemeGroups) {
    for (final theme in group.themes) {
      if (theme.tag == tag.key) return theme;
    }
  }
  return _themeFromLiveTag(tag, tag.id);
}

String _formatInt(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final remaining = text.length - i;
    buffer.write(text[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

String _formatStormClock(int seconds) {
  final clamped = seconds.clamp(0, _stormRunDuration.inSeconds).toInt();
  final minutes = clamped ~/ Duration.secondsPerMinute;
  final remainder = clamped % Duration.secondsPerMinute;
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}

bool _whiteToMoveFromFen(String fen) {
  final fields = fen.trim().split(RegExp(r'\s+'));
  if (fields.length < 2) return true;
  return fields[1] != 'b';
}

String _stormRatingBandLabel(
  api.Puzzle? puzzle, {
  required int solvedCount,
  required int combo,
}) {
  if (puzzle != null) {
    final puzzleBand = _stormPuzzleRatingBandLabel(puzzle);
    if (puzzleBand != null) return puzzleBand;
  }
  final base = 1000 + (solvedCount * 80) + (combo * 40);
  final lower = (base ~/ _stormRatingBandStep) * _stormRatingBandStep;
  return '$lower-${lower + _stormRatingBandStep}';
}

String _stormPuzzleRatingLabel(api.Puzzle puzzle) {
  final band = _stormPuzzleRatingBandLabel(puzzle);
  if (band != null) return band;
  return puzzle.lichessId;
}

String? _stormPuzzleRatingBandLabel(api.Puzzle puzzle) {
  final min = puzzle.ratingMin;
  final max = puzzle.ratingMax;
  if (min != null && max != null) {
    return min == max ? min.toString() : '$min-$max';
  }
  final rating = puzzle.rating;
  if (rating == null) return null;
  final lower = (rating ~/ _stormRatingBandStep) * _stormRatingBandStep;
  return '$lower-${lower + _stormRatingBandStep}';
}

ChessBoardMove? _hintMoveForPuzzle(
  api.Puzzle? puzzle, {
  required bool solved,
  required String currentFen,
  required int moveIndex,
}) {
  if (puzzle == null || solved) return null;
  return _puzzleMoveAt(puzzle, moveIndex, currentFen);
}

ChessBoardMove? _puzzleMoveAt(api.Puzzle puzzle, int index, String fen) {
  final expected = _puzzleExpectedMove(puzzle, index);
  if (expected == null) return null;
  return _puzzleMoveFromUci(fen, expected);
}

ChessBoardMove? _puzzleMoveFromUci(String fen, String uci) {
  final normalized = _normalizePuzzleMove(uci);
  if (normalized.length < 4) return null;
  try {
    final position = loadDartChessPosition(fen);
    final move = dc.NormalMove.fromUci(normalized);
    return _puzzleChessBoardMove(position, move);
  } catch (_) {
    return null;
  }
}

ChessBoardMove? _resolvePuzzleBoardMove(
  api.Puzzle? puzzle,
  String boardFen, {
  required String currentFen,
  required int moveIndex,
}) {
  if (puzzle == null) return null;
  if (_puzzleExpectedMove(puzzle, moveIndex) == null) return null;
  try {
    final position = loadDartChessPosition(currentFen);
    final boardOnlyFen = _boardOnlyFen(boardFen);
    for (final move in _legalPuzzleMoves(position)) {
      final resolved = _puzzleChessBoardMove(position, move);
      if (resolved == null) continue;
      if (_boardOnlyFen(resolved.fen) != boardOnlyFen) continue;
      return resolved;
    }
  } catch (_) {
    return null;
  }
  return null;
}

ChessBoardMove? _resolveMistakeBoardMove({
  required String currentFen,
  required String boardFen,
}) {
  try {
    final position = loadDartChessPosition(currentFen);
    final boardOnlyFen = _boardOnlyFen(boardFen);
    for (final move in _legalPuzzleMoves(position)) {
      final resolved = _puzzleChessBoardMove(position, move);
      if (resolved == null) continue;
      if (_boardOnlyFen(resolved.fen) != boardOnlyFen) continue;
      return resolved;
    }
  } catch (_) {
    return null;
  }
  return null;
}

List<ChessBoardMoveAnnotation> _mistakeMoveAnnotations(
  MistakeBookEntry entry,
) {
  final wrongMove = _mistakeMoveFromText(entry.fenBefore, entry.moveSan) ??
      _resolveMistakeBoardMove(
        currentFen: entry.fenBefore,
        boardFen: entry.fenAfter,
      );
  final bestMove = _mistakeMoveFromText(entry.fenBefore, entry.bestMoveSan);
  final annotations = <ChessBoardMoveAnnotation>[];
  if (wrongMove != null) {
    annotations.add(
      ChessBoardMoveAnnotation(
        move: wrongMove,
        color: const Color(0xFFEF4444),
        label: 'Mistake',
        keyPrefix: 'mistake-wrong',
      ),
    );
  }
  if (bestMove != null && bestMove.uci != wrongMove?.uci) {
    annotations.add(
      ChessBoardMoveAnnotation(
        move: bestMove,
        color: const Color(0xFF16A34A),
        label: 'Best',
        keyPrefix: 'mistake-best',
      ),
    );
  }
  return List.unmodifiable(annotations);
}

ChessBoardMove? _mistakeMoveFromText(String fen, String moveText) {
  final normalizedText = _normalizeMistakeMoveText(moveText);
  if (normalizedText.isEmpty) return null;
  try {
    final position = loadDartChessPosition(fen);
    for (final move in _legalPuzzleMoves(position)) {
      final resolved = _puzzleChessBoardMove(position, move);
      if (resolved == null) continue;
      if (_normalizeMistakeMoveText(resolved.san) == normalizedText ||
          _normalizeMistakeMoveText(resolved.uci) == normalizedText) {
        return resolved;
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}

ChessBoardMove? _puzzleChessBoardMove(
  dc.Position position,
  dc.NormalMove move,
) {
  if (!position.isLegal(move)) return null;
  try {
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

List<dc.NormalMove> _legalPuzzleMoves(dc.Position position) {
  final moves = <dc.NormalMove>[];
  for (final entry in dc.makeLegalMoves(position).entries) {
    final from = entry.key;
    final piece = position.board.pieceAt(from);
    if (piece == null) continue;
    for (final to in entry.value) {
      final promotions = _promotionRolesForPuzzle(piece, to);
      if (promotions.isEmpty) {
        final move = position.normalizeMove(dc.NormalMove(from: from, to: to));
        if (move is dc.NormalMove) moves.add(move);
        continue;
      }
      for (final role in promotions) {
        moves.add(dc.NormalMove(from: from, to: to, promotion: role));
      }
    }
  }
  return moves.where(position.isLegal).toList(growable: false);
}

List<dc.Role> _promotionRolesForPuzzle(dc.Piece piece, dc.Square to) {
  if (piece.role != dc.Role.pawn ||
      (to.rank != dc.Rank.first && to.rank != dc.Rank.eighth)) {
    return const [];
  }
  return const [dc.Role.queen, dc.Role.rook, dc.Role.bishop, dc.Role.knight];
}

bool _moveMatchesPuzzleAnswer(String actual, String expected) {
  final normalizedActual = _normalizePuzzleMove(actual);
  if (normalizedActual == expected) return true;
  if (expected.length == 4) {
    return normalizedActual.length >= 4 &&
        normalizedActual.substring(0, 4) == expected;
  }
  return false;
}

List<String> _puzzleAnswerMoves(api.Puzzle puzzle) {
  return puzzle.move
      .trim()
      .split(RegExp(r'[\s,;]+'))
      .map(_normalizePuzzleMove)
      .where((move) => move.length >= 4)
      .toList(growable: false);
}

_PreparedPuzzleStart? _preparePuzzleStart(api.Puzzle? puzzle) {
  if (puzzle == null) return null;
  final moves = _puzzleAnswerMoves(puzzle);
  // Lichess stores the opponent's preceding move first; the solver starts
  // from the resulting position. Keep malformed one-move responses usable.
  if (moves.length < 2) return null;
  final firstMove = _puzzleMoveAt(puzzle, 0, puzzle.fen);
  if (firstMove == null) return null;
  return _PreparedPuzzleStart(
    fen: firstMove.fen,
    lastMove: [firstMove.from, firstMove.to],
    moveIndex: 1,
  );
}

class _PreparedPuzzleStart {
  const _PreparedPuzzleStart({
    required this.fen,
    required this.lastMove,
    required this.moveIndex,
  });

  final String fen;
  final List<String> lastMove;
  final int moveIndex;
}

String? _puzzleExpectedMove(api.Puzzle puzzle, int index) {
  final moves = _puzzleAnswerMoves(puzzle);
  if (index < 0 || index >= moves.length) return null;
  return moves[index];
}

String _normalizePuzzleMove(String move) {
  return move.trim().toLowerCase();
}

const _physicalSetupPromptText =
    'Set up the physical board to match this puzzle position.';

bool _physicalSetupRequired(PhysicalBoardGateway? gateway, api.Puzzle? puzzle) {
  return gateway != null &&
      puzzle != null &&
      gateway.currentState == PhysicalBoardConnectionState.connected;
}

bool _isPuzzlePhysicalSetupReady(
  String? physicalBoardFen,
  api.Puzzle? puzzle,
  String currentFen,
) {
  if (physicalBoardFen == null || puzzle == null) return false;
  return _boardOnlyFen(physicalBoardFen) == _boardOnlyFen(currentFen);
}

Set<String> _puzzleSetupDiffSquares(
  String? physicalBoardFen,
  api.Puzzle? puzzle,
  String currentFen,
) {
  if (puzzle == null) return const {};
  final target = _expandedPuzzleBoard(_boardOnlyFen(currentFen));
  if (target == null) return const {};
  final source = _expandedPuzzleBoard(physicalBoardFen);
  final squares = <String>{};
  for (var index = 0; index < 64; index += 1) {
    final shouldLight = source == null
        ? target[index].isNotEmpty
        : source[index] != target[index];
    if (shouldLight) {
      final rankIndex = index ~/ 8;
      final fileIndex = index % 8;
      squares.add(
        '${ChessBoard.files[fileIndex]}${ChessBoard.ranks[rankIndex]}',
      );
    }
  }
  return squares;
}

List<String>? _expandedPuzzleBoard(String? boardFen) {
  if (boardFen == null || boardFen.trim().isEmpty) return null;
  final ranks = boardFen.trim().split(RegExp(r'\s+')).first.split('/');
  if (ranks.length != 8) return null;
  final board = <String>[];
  for (final rank in ranks) {
    var rankLength = 0;
    for (var i = 0; i < rank.length; i += 1) {
      final char = rank[i];
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

String _boardOnlyFen(String fen) {
  return fen.trim().split(RegExp(r'\s+')).first;
}

Future<void> _sendPuzzlePositionToBoard({
  required PhysicalBoardGateway? gateway,
  required api.Puzzle? puzzle,
  required String fen,
  required PhysicalBoardOrientationResolver orientation,
}) async {
  if (gateway == null || puzzle == null) return;
  if (gateway.currentState != PhysicalBoardConnectionState.connected) return;
  if (gateway.boardModel == PhysicalBoardModel.move) {
    await gateway.setMoveBoardFen(fen, isReverse: orientation.isReversed);
  }
}

_PuzzleLedRequest? _answerLedRequest({
  required PhysicalBoardGateway? gateway,
  required api.Puzzle? puzzle,
  required bool solved,
  required bool visible,
  required String currentFen,
  required int moveIndex,
  required PhysicalBoardOrientationResolver orientation,
}) {
  if (gateway == null) return null;
  if (gateway.currentState != PhysicalBoardConnectionState.connected) {
    return null;
  }
  if (puzzle == null || solved || !visible) {
    return _clearLedRequest(gateway);
  }
  final hint = _puzzleMoveAt(puzzle, moveIndex, currentFen);
  if (hint == null) return null;
  final squares = orientation.toPhysicalSquares({hint.from, hint.to});
  if (gateway.boardModel.canSendColorLedCommands) {
    return _PuzzleLedRequest.move({
      for (final square in squares) square: ChessnutMoveLedColor.green,
    });
  }
  return _PuzzleLedRequest.general(squares);
}

_PuzzleLedSetupPlan _physicalSetupLedPlan({
  required PhysicalBoardGateway? gateway,
  required api.Puzzle? puzzle,
  required String currentFen,
  required String? latestPhysicalBoardFen,
  required bool solved,
  required PhysicalBoardOrientationResolver orientation,
  bool answerVisible = false,
}) {
  if (!_physicalSetupRequired(gateway, puzzle)) {
    return const _PuzzleLedSetupPlan(null, false);
  }
  if (solved || answerVisible) {
    return const _PuzzleLedSetupPlan(null, false);
  }
  final squares = orientation.toPhysicalSquares(
    _puzzleSetupDiffSquares(
      latestPhysicalBoardFen,
      puzzle,
      currentFen,
    ),
  );
  if (squares.isEmpty) {
    return _PuzzleLedSetupPlan(_clearLedRequest(gateway), false);
  }
  if (gateway!.boardModel.canSendColorLedCommands) {
    return _PuzzleLedSetupPlan(
      _PuzzleLedRequest.move({
        for (final square in squares) square: ChessnutMoveLedColor.red,
      }),
      true,
    );
  }
  return _PuzzleLedSetupPlan(_PuzzleLedRequest.general(squares), true);
}

_PuzzleLedRequest? _clearLedRequest(PhysicalBoardGateway? gateway) {
  if (gateway == null) return null;
  if (gateway.currentState != PhysicalBoardConnectionState.connected) {
    return null;
  }
  if (gateway.boardModel.canSendColorLedCommands) {
    return _PuzzleLedRequest.move({});
  }
  return _PuzzleLedRequest.general({});
}

String _normalizeMistakeMoveText(String text) {
  return text
      .trim()
      .replaceFirst(RegExp(r'^(Best|Better|Cleaner|Tactic):\s*'), '')
      .replaceAll(RegExp(r'^\d+\.(\.\.)?\s*'), '')
      .replaceAll(RegExp(r'[+#?!]+$'), '')
      .replaceAll(RegExp(r'\s+'), '')
      .toLowerCase();
}

class _PuzzleLedSetupPlan {
  const _PuzzleLedSetupPlan(this.request, this.setupActive);

  final _PuzzleLedRequest? request;
  final bool setupActive;
}

class _PuzzleLedRequest {
  const _PuzzleLedRequest._(this.identity, this._send);

  factory _PuzzleLedRequest.general(Set<String> squares) {
    final normalized = _normalizedSquares(squares);
    return _PuzzleLedRequest._(
      'general:${normalized.join(',')}',
      (gateway) => gateway.setGeneralLedSquares(normalized.toSet()),
    );
  }

  factory _PuzzleLedRequest.move(Map<String, ChessnutMoveLedColor> colors) {
    final entries = colors.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final normalized = {
      for (final entry in entries) entry.key: entry.value,
    };
    return _PuzzleLedRequest._(
      'move:${entries.map((entry) => '${entry.key}:${entry.value.code}').join(',')}',
      (gateway) => gateway.setMoveLedSquares(normalized),
    );
  }

  final String identity;
  final Future<bool> Function(PhysicalBoardGateway gateway) _send;

  Future<bool> send(PhysicalBoardGateway gateway) => _send(gateway);
}

class _PuzzleLedSyncCache {
  String? _lastIdentity;

  Future<void> send(
    PhysicalBoardGateway? gateway,
    _PuzzleLedRequest? request,
  ) async {
    if (gateway == null || request == null) return;
    if (gateway.currentState != PhysicalBoardConnectionState.connected) {
      _lastIdentity = null;
      return;
    }
    if (_lastIdentity == request.identity) return;
    final sent = await request.send(gateway);
    if (sent) {
      _lastIdentity = request.identity;
    }
  }

  void reset() {
    _lastIdentity = null;
  }
}

List<String> _normalizedSquares(Set<String> squares) {
  final normalized = squares.toList()..sort();
  return normalized;
}

String _currentPuzzleFen(api.Puzzle? puzzle, String? boardFenOverride) {
  return boardFenOverride ?? puzzle?.fen ?? _stormStartFen;
}

bool _puzzleBoardShouldFlip(String? fen) {
  final fields = fen?.trim().split(RegExp(r'\s+'));
  return fields != null && fields.length > 1 && fields[1].toLowerCase() == 'b';
}

bool _usesPuzzleMoveSideOrientation({
  required PhysicalBoardGateway? gateway,
  required BoardSettingsState settings,
}) {
  return gateway?.boardModel == PhysicalBoardModel.move &&
      settings.allowFlip &&
      settings.autoFlip;
}

PhysicalBoardFenMapping _puzzleMoveSideMapping(String fen) {
  return _puzzleBoardShouldFlip(fen)
      ? PhysicalBoardFenMapping.reversed
      : PhysicalBoardFenMapping.identity;
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
