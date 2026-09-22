import 'dart:async';

import 'package:dartchess/dartchess.dart' as dc;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

import '../l10n/localized_material.dart';
import '../models/app_models.dart';
import '../services/bot_engine_adapter.dart';
import '../services/board_settings_service.dart';
import '../services/chessnut_api_client.dart';
import '../services/physical_board_gateway.dart';
import '../services/physical_board_orientation.dart';
import '../services/physical_board_protocol.dart';
import '../services/stockfish_analysis_service.dart';
import '../services/voice_move_recognition_service.dart';
import '../services/voice_move_session_controller.dart';
import '../theme/chessnut_theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/chess_board.dart';
import '../widgets/voice_moves_shortcut.dart';

const _analyzerScoreBarWidth = 30.0;
const _boardAnalyzerHelpText =
    'Move pieces on the board or paste a FEN, then let Stockfish refresh the score.';

class BoardAnalyzerScreen extends StatefulWidget {
  const BoardAnalyzerScreen({
    required this.onNavigate,
    this.apiClient,
    this.positionAnalyzer,
    this.boardGateway,
    this.boardSettings = const BoardSettingsState(),
    this.initialFen = chessnutStandardStartFen,
    this.showBoardCoordinates = false,
    this.isChessnutClockDevice = false,
    this.voiceMoveRecognitionService,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final ChessnutApiClient? apiClient;
  final PositionAnalyzer? positionAnalyzer;
  final PhysicalBoardGateway? boardGateway;
  final BoardSettingsState boardSettings;
  final String initialFen;
  final bool showBoardCoordinates;
  final bool isChessnutClockDevice;
  final VoiceMoveRecognitionService? voiceMoveRecognitionService;

  @override
  State<BoardAnalyzerScreen> createState() => _BoardAnalyzerScreenState();
}

class _BoardAnalyzerScreenState extends State<BoardAnalyzerScreen> {
  static const _defaultAnalysisDepth = 12;
  static const _analysisMultiPv = 3;

  late final TextEditingController fenController;
  final fenFocusNode = FocusNode();
  final history = <_AnalyzerSnapshot>[];
  StreamSubscription<PhysicalBoardConnectionState>? _boardStateSub;
  StreamSubscription<String>? _boardFenSub;
  late final BoardFenStabilityBuffer _boardFenStabilityBuffer;
  late final PhysicalBoardOrientationResolver _boardOrientation;
  Timer? _analysisDebounce;
  var _analysisRequest = 0;
  var boardKey = 0;
  double? _lastUnobscuredHeight;
  late String currentFen;
  String? _physicalBoardFen;
  String? _lastAnalyzerLedSignature;
  String? _lastMoveBoardTargetFen;
  List<String> lastMove = const [];
  bool flipped = false;
  bool analyzing = false;
  String? statusText = 'Position ready.';
  String? inputError;
  PositionEngineAnalysis? analysis;
  late final VoiceMoveSessionController _voiceMoves;
  late final PositionAnalyzer _localAnalyzer;
  StockfishAnalysisSession? _liveAnalysisSession;
  int? _analysisDepth = _defaultAnalysisDepth;

  PositionAnalyzer get analyzer => widget.positionAnalyzer ?? _localAnalyzer;

  bool get _canUseVoiceMoves =>
      widget.boardGateway?.boardModel == PhysicalBoardModel.move &&
      widget.boardGateway?.currentState ==
          PhysicalBoardConnectionState.connected;

  @override
  void initState() {
    super.initState();
    _localAnalyzer =
        widget.positionAnalyzer ?? const StockfishPositionAnalyzer();
    final positionAnalyzer = analyzer;
    if (positionAnalyzer is LivePositionAnalyzer) {
      _liveAnalysisSession =
          (positionAnalyzer as LivePositionAnalyzer).createLiveSession();
    }
    currentFen = _validatedInitialFen(widget.initialFen);
    fenController = TextEditingController(text: currentFen);
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
      currentFenProvider: () => currentFen,
    );
    _boardFenStabilityBuffer = BoardFenStabilityBuffer(
      onStableFen: _handlePhysicalBoardFen,
    );
    _subscribePhysicalBoard();
    _queueAnalysis(immediate: true);
  }

  @override
  void didUpdateWidget(covariant BoardAnalyzerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFen != widget.initialFen) {
      _applyInitialFen(widget.initialFen);
    }
    if (_boardOrientation.updateSettings(widget.boardSettings)) {
      _resetPhysicalBoardOrientationCache();
      unawaited(_syncAnalyzerBoardToCurrentFen());
    }
    if (!identical(oldWidget.boardGateway, widget.boardGateway)) {
      _unsubscribePhysicalBoard();
      _subscribePhysicalBoard();
      if (!_canUseVoiceMoves) {
        unawaited(_voiceMoves.stop());
      }
    }
  }

  String _validatedInitialFen(String fen) {
    try {
      return dc.Chess.fromSetup(
        dc.Setup.parseFen(_normalizeAnalyzerFenInput(fen)),
      ).fen;
    } catch (_) {
      return chessnutStandardStartFen;
    }
  }

  void _applyInitialFen(String fen) {
    final nextFen = _validatedInitialFen(fen);
    if (nextFen == currentFen) return;
    history.clear();
    setState(() {
      boardKey++;
      currentFen = nextFen;
      lastMove = const [];
      _setFenInputText(nextFen, force: true);
      analysis = null;
      inputError = null;
      statusText = 'Position ready.';
    });
    unawaited(_syncAnalyzerBoardToCurrentFen());
    _queueAnalysis(immediate: true);
  }

  @override
  void dispose() {
    _unsubscribePhysicalBoard();
    _boardFenStabilityBuffer.dispose();
    _analysisDebounce?.cancel();
    _analysisRequest++;
    unawaited(_liveAnalysisSession?.dispose());
    fenFocusNode.dispose();
    fenController.dispose();
    unawaited(_voiceMoves.dispose());
    super.dispose();
  }

  void _onMove(ChessBoardMove move) {
    final legalMove = _moveFromUci(currentFen, move.uci);
    if (legalMove == null) {
      setState(() {
        boardKey++;
        statusText = 'Illegal move ignored.';
      });
      return;
    }
    fenFocusNode.unfocus();
    history.add(_AnalyzerSnapshot(fen: currentFen, lastMove: lastMove));
    setState(() {
      boardKey++;
      currentFen = legalMove.fen;
      lastMove = [legalMove.from, legalMove.to];
      _setFenInputText(legalMove.fen, force: true);
      inputError = null;
      statusText = '${legalMove.san} played. Stockfish is updating.';
    });
    unawaited(_syncAnalyzerBoardToCurrentFen());
    _queueAnalysis();
  }

  void _subscribePhysicalBoard() {
    final gateway = widget.boardGateway;
    if (gateway == null) return;
    _boardStateSub = gateway.stateStream.listen((state) {
      if (!mounted) return;
      if (state == PhysicalBoardConnectionState.connected) {
        _lastAnalyzerLedSignature = null;
        _lastMoveBoardTargetFen = null;
        unawaited(gateway.enableRealtimeFen());
        _syncFromLatestPhysicalBoardFen();
        unawaited(_syncAnalyzerBoardToCurrentFen());
      }
      setState(() {});
    });
    _boardFenSub = gateway.boardFenStream.listen((fen) {
      final normalizedFen = _normalizePhysicalBoardFen(fen);
      _physicalBoardFen = normalizedFen;
      _boardFenStabilityBuffer.add(normalizedFen);
      unawaited(_syncAnalyzerBoardLeds());
    });
    if (gateway.currentState == PhysicalBoardConnectionState.connected) {
      unawaited(gateway.enableRealtimeFen());
      _syncFromLatestPhysicalBoardFen();
      unawaited(_syncAnalyzerBoardToCurrentFen());
    }
  }

  void _unsubscribePhysicalBoard() {
    unawaited(_boardStateSub?.cancel());
    unawaited(_boardFenSub?.cancel());
    _boardStateSub = null;
    _boardFenSub = null;
    _physicalBoardFen = null;
    _lastAnalyzerLedSignature = null;
    _lastMoveBoardTargetFen = null;
  }

  void _syncFromLatestPhysicalBoardFen() {
    final latestFen = widget.boardGateway?.latestBoardFen;
    if (latestFen == null || latestFen.trim().isEmpty) return;
    final normalizedFen = _normalizePhysicalBoardFen(latestFen);
    _physicalBoardFen = normalizedFen;
    _boardFenStabilityBuffer.add(normalizedFen);
  }

  String _normalizePhysicalBoardFen(String fen) {
    return _boardOrientation.normalizeAndTrack(
      fen,
      referenceFens: [currentFen],
      onMappingChanged: (_) => _resetPhysicalBoardOrientationCache(),
    );
  }

  void _resetPhysicalBoardOrientationCache() {
    _lastAnalyzerLedSignature = null;
    _lastMoveBoardTargetFen = null;
  }

  void _handlePhysicalBoardFen(String boardFen) {
    if (!mounted) return;
    _physicalBoardFen = _boardOnlyFen(boardFen);
    final move = _resolveAnalyzerBoardFenMove(
      currentFen: currentFen,
      boardFen: boardFen,
    );
    if (move == null) {
      if (_boardOnlyFen(boardFen) != _boardOnlyFen(currentFen)) {
        setState(() {
          statusText = 'Physical board differs from the legal position.';
        });
        unawaited(_syncAnalyzerBoardToCurrentFen(forceMoveBoardFen: true));
      } else {
        unawaited(_syncAnalyzerBoardLeds());
      }
      return;
    }
    history.add(_AnalyzerSnapshot(fen: currentFen, lastMove: lastMove));
    setState(() {
      boardKey++;
      currentFen = move.fen;
      lastMove = [move.from, move.to];
      _setFenInputText(move.fen);
      analysis = null;
      inputError = null;
      statusText =
          '${move.san} played from physical board. Stockfish is updating.';
    });
    unawaited(_syncAnalyzerBoardToCurrentFen(sendMoveBoardFen: false));
    _queueAnalysis();
  }

  void _queueAnalysis({bool immediate = false}) {
    _analysisDebounce?.cancel();
    if (immediate) {
      unawaited(_runAnalysis());
      return;
    }
    _analysisDebounce = Timer(
      const Duration(milliseconds: 180),
      () => unawaited(_runAnalysis()),
    );
  }

  Future<void> _runAnalysis() async {
    final request = ++_analysisRequest;
    final fen = currentFen;
    final depth = _analysisDepth;
    final limit = depth == null
        ? const StockfishAnalysisLimit.unlimited()
        : StockfishAnalysisLimit.fixed(depth);
    setState(() {
      analyzing = true;
      statusText = depth == null
          ? 'Stockfish is analyzing without a depth limit.'
          : 'Stockfish is evaluating the current board.';
    });
    PositionEngineAnalysis? result;
    final liveSession = _liveAnalysisSession;
    if (liveSession != null) {
      try {
        result = await liveSession.start(
          fen,
          limit: limit,
          multiPv: _analysisMultiPv,
          onUpdate: (update) {
            if (depth != null ||
                !mounted ||
                request != _analysisRequest ||
                fen != currentFen) {
              return;
            }
            setState(() {
              analyzing = true;
              analysis = update;
              statusText =
                  'Stockfish is still thinking at depth ${update.depth}.';
            });
          },
        );
      } catch (_) {
        result = null;
      }
    } else {
      result = await analyzer.analyzeFen(
        fen,
        depth: depth ?? 20,
        multiPv: _analysisMultiPv,
      );
    }
    if (!mounted || request != _analysisRequest || fen != currentFen) return;
    setState(() {
      analyzing = depth == null && result != null;
      analysis = result;
      statusText = result == null
          ? 'Stockfish is not available here. Check engine files or try another platform.'
          : depth == null
              ? 'Stockfish is analyzing without a depth limit.'
              : result.isEngineBacked
                  ? 'Stockfish live analysis ready.'
                  : 'Lightweight analysis ready.';
    });
  }

  Future<void> _showAnalysisDepthSettings() async {
    var unlimited = _analysisDepth == null;
    var draftDepth = (_analysisDepth ?? _defaultAnalysisDepth).toDouble();
    final selected = await showDialog<StockfishAnalysisLimit>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Depth'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Unlimited'),
                  value: unlimited,
                  onChanged: (value) => setDialogState(() => unlimited = value),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Depth'),
                    const Spacer(),
                    Text(
                      unlimited ? 'Unlimited' : '${draftDepth.round()}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                Slider(
                  value: draftDepth,
                  min: 6,
                  max: 20,
                  divisions: 14,
                  label: '${draftDepth.round()}',
                  onChanged: unlimited
                      ? null
                      : (value) => setDialogState(() => draftDepth = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                unlimited
                    ? const StockfishAnalysisLimit.unlimited()
                    : StockfishAnalysisLimit.fixed(draftDepth.round()),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    final selectedDepth = selected.depth;
    if (_analysisDepth == selectedDepth) return;
    setState(() {
      _analysisDepth = selectedDepth;
      analysis = null;
      statusText = selected.isUnlimited
          ? 'Unlimited analysis selected.'
          : 'Analysis depth ${selected.depth} selected.';
    });
    _queueAnalysis(immediate: true);
  }

  void _resetBoard() {
    fenFocusNode.unfocus();
    history.clear();
    setState(() {
      boardKey++;
      currentFen = chessnutStandardStartFen;
      lastMove = const [];
      _setFenInputText(chessnutStandardStartFen, force: true);
      analysis = null;
      inputError = null;
      statusText = 'Board reset.';
    });
    unawaited(_syncAnalyzerBoardToCurrentFen(forceMoveBoardFen: true));
    _queueAnalysis(immediate: true);
  }

  void _undoMove() {
    if (history.isEmpty) return;
    fenFocusNode.unfocus();
    final previous = history.removeLast();
    setState(() {
      boardKey++;
      currentFen = previous.fen;
      lastMove = previous.lastMove;
      _setFenInputText(previous.fen, force: true);
      analysis = null;
      inputError = null;
      statusText = 'Move undone.';
    });
    unawaited(_syncAnalyzerBoardToCurrentFen());
    _queueAnalysis(immediate: true);
  }

  void _loadFenFromInput() {
    final entered = _normalizeAnalyzerFenInput(fenController.text);
    try {
      final position = dc.Chess.fromSetup(dc.Setup.parseFen(entered));
      history.clear();
      fenFocusNode.unfocus();
      setState(() {
        boardKey++;
        currentFen = position.fen;
        lastMove = const [];
        _setFenInputText(position.fen, force: true);
        analysis = null;
        inputError = null;
        statusText = 'FEN loaded.';
      });
      unawaited(_syncAnalyzerBoardToCurrentFen());
      _queueAnalysis(immediate: true);
    } catch (_) {
      setState(() {
        inputError = 'This FEN is not legal.';
        statusText = 'FEN load failed.';
      });
    }
  }

  void _applyCandidateMove(EngineMoveCandidate candidate, int pvIndex) {
    final pv = candidate.pv.isEmpty ? [candidate.moveUci] : candidate.pv;
    if (pvIndex < 0 || pvIndex >= pv.length) return;
    var fen = currentFen;
    ChessBoardMove? selectedMove;
    for (var i = 0; i <= pvIndex; i++) {
      selectedMove = _moveFromCandidate(fen, pv[i]);
      if (selectedMove == null) break;
      fen = selectedMove.fen;
    }
    if (selectedMove == null || fen == currentFen) {
      setState(() {
        statusText = 'Candidate move is not legal in this position.';
      });
      return;
    }
    history.add(_AnalyzerSnapshot(fen: currentFen, lastMove: lastMove));
    setState(() {
      boardKey++;
      currentFen = fen;
      lastMove = [selectedMove!.from, selectedMove.to];
      _setFenInputText(fen);
      analysis = null;
      inputError = null;
      statusText = '${selectedMove.san} candidate position loaded.';
    });
    unawaited(_syncAnalyzerBoardToCurrentFen());
    _queueAnalysis();
  }

  Future<void> _syncAnalyzerBoardToCurrentFen({
    bool sendMoveBoardFen = true,
    bool forceMoveBoardFen = false,
  }) async {
    if (sendMoveBoardFen) {
      await _sendCurrentFenToMoveBoardIfNeeded(force: forceMoveBoardFen);
    }
    await _syncAnalyzerBoardLeds();
  }

  Future<void> _sendCurrentFenToMoveBoardIfNeeded({bool force = false}) async {
    final gateway = widget.boardGateway;
    if (gateway == null ||
        gateway.boardModel != PhysicalBoardModel.move ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      return;
    }
    if (!force && _lastMoveBoardTargetFen == currentFen) return;
    final sent = await gateway.setMoveBoardFen(
      currentFen,
      isReverse: _boardOrientation.isReversed,
    );
    if (sent) _lastMoveBoardTargetFen = currentFen;
  }

  Future<void> _syncAnalyzerBoardLeds() async {
    final gateway = widget.boardGateway;
    if (gateway == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      return;
    }
    final sourceBoardFen = _physicalBoardFen ?? gateway.latestBoardFen;
    final diff = _differentSquares(sourceBoardFen, _boardOnlyFen(currentFen));
    if (diff == null) return;
    final physicalDiff = _boardOrientation.toPhysicalSquares(diff);
    final signature = _analyzerLedSignature(gateway.boardModel, physicalDiff);
    if (signature == _lastAnalyzerLedSignature) return;
    bool ok;
    if (gateway.boardModel == PhysicalBoardModel.move) {
      ok = physicalDiff.isEmpty
          ? await gateway.clearMoveLeds()
          : await gateway.setMoveLedSquares({
              for (final square in physicalDiff)
                square: ChessnutMoveLedColor.red,
            });
    } else if (gateway.boardModel.usesGeneralProtocol) {
      ok = physicalDiff.isEmpty
          ? await gateway.clearGeneralLeds()
          : await gateway.setGeneralLedSquares(physicalDiff);
    } else {
      return;
    }
    if (ok) _lastAnalyzerLedSignature = signature;
  }

  void _setFenInputText(String fen, {bool force = false}) {
    if (!force && fenFocusNode.hasFocus) return;
    if (fenController.text == fen) return;
    fenController.value = TextEditingValue(
      text: fen,
      selection: TextSelection.collapsed(offset: fen.length),
    );
  }

  Future<void> _toggleVoiceMoves() async {
    await _voiceMoves.toggle(
      context: context,
      canUse: _canUseVoiceMoves,
      settings: widget.boardSettings,
      unavailableMessage: 'Connect Chessnut Move first.',
    );
  }

  Future<String?> _openAiKeyForVoiceMove() async {
    final apiClient = widget.apiClient;
    if (apiClient == null) {
      throw const VoiceMoveOpenAiSessionException(
        'Online voice recognition could not get an OpenAI session.',
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

  void _refreshVoiceMovesState() {
    if (mounted) setState(() {});
  }

  void _showVoiceMoveMessage(String message) {
    if (!mounted) return;
    setState(() => statusText = message);
  }

  void _handleVoiceMoveUci(String uci) {
    final move = _moveFromUci(currentFen, uci);
    if (move == null) {
      _showVoiceMoveMessage('Voice move $uci is not legal here.');
      return;
    }
    _onMove(move);
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final androidPhoneLandscape = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !widget.isChessnutClockDevice &&
        viewport.width > viewport.height &&
        viewport.width < 1000 &&
        viewport.height < 600;
    return ResponsivePage(
      compactLandscapeOverride: androidPhoneLandscape,
      children: (context, spec) {
        final compactLandscape = spec.compactLandscape || androidPhoneLandscape;
        final windowsLandscape = !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.windows &&
            spec.canSplit &&
            spec.width > spec.height;
        final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
        if (keyboardInset <= 0 && spec.height.isFinite) {
          _lastUnobscuredHeight = spec.height;
        }
        final stableHeight = keyboardInset > 0
            ? (_lastUnobscuredHeight ?? spec.height)
            : spec.height;
        final layoutSpec = ResponsiveSpec(
          spec.width,
          height: stableHeight,
          compactLandscapeOverride: androidPhoneLandscape,
        );
        final contentMinHeight = androidPhoneLandscape
            ? 0.0
            : stableHeight.isFinite && stableHeight < 360
                ? stableHeight
                : 360.0;
        final contentHeight = layoutSpec.heightAfterHeader(
          min: contentMinHeight,
        );
        final boardSection = ResponsiveBoardFrame(
          maxSize: androidPhoneLandscape
              ? (contentHeight - 4).clamp(180.0, 280.0).toDouble()
              : compactLandscape
                  ? 332
                  : windowsLandscape
                      ? contentHeight
                      : (spec.canSplit ? 780 : 760),
          extraWidth: _analyzerScoreBarWidth,
          padding: EdgeInsets.all(compactLandscape ? 0 : 2),
          builder: (size) => _AnalyzerBoardWithEval(
            size: size,
            boardKey: boardKey,
            fen: currentFen,
            lastMove: lastMove,
            flipped: flipped,
            analysis: analysis,
            showCoordinates: widget.showBoardCoordinates,
            onMove: _onMove,
          ),
        );
        final controlsSection = _AnalyzerControls(
          canUndo: history.isNotEmpty,
          onUndo: _undoMove,
          onReset: _resetBoard,
          onFlip: () => setState(() => flipped = !flipped),
          compact: compactLandscape,
        );
        final liveSection = _LiveEnginePanel(
          fen: currentFen,
          analyzing: analyzing,
          statusText: statusText,
          analysis: analysis,
          compact: compactLandscape,
        );
        final candidatesSection = _CandidateLinesCard(
          fen: currentFen,
          analysis: analysis,
          compact: compactLandscape,
          onCandidateSelected: _applyCandidateMove,
        );
        final fenSection = _FenInputCard(
          controller: fenController,
          focusNode: fenFocusNode,
          errorText: inputError,
          onLoad: _loadFenFromInput,
          compact: compactLandscape,
        );
        final voiceMovesShortcut = _canUseVoiceMoves
            ? VoiceMovesShortcutButton(
                enabled: _voiceMoves.enabled,
                listening: _voiceMoves.listening,
                onPressed: _toggleVoiceMoves,
                valueKey: const ValueKey('board-analyzer-voice-moves-toggle'),
              )
            : null;
        final leading = SectionColumn(
          spacing: compactLandscape ? 8 : 12,
          children: [
            boardSection,
            controlsSection,
          ],
        );
        final trailing = SectionColumn(
          spacing: compactLandscape ? 8 : 12,
          children: [
            liveSection,
            candidatesSection,
            fenSection,
          ],
        );
        return [
          ScreenHeader(
            title: 'Board analyzer',
            subtitle: 'Practice',
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
                  key: const ValueKey('board-analyzer-depth-settings'),
                  tooltip: 'Depth',
                  onPressed: _showAnalysisDepthSettings,
                  icon: const Icon(Icons.tune_rounded),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Flip board',
                  onPressed: () => setState(() => flipped = !flipped),
                  icon: const Icon(Icons.flip_camera_android_rounded),
                ),
              ],
            ),
          ),
          SizedBox(height: spec.gutter),
          if (compactLandscape)
            SizedBox(
              key: androidPhoneLandscape
                  ? const ValueKey(
                      'board-analyzer-android-phone-landscape',
                    )
                  : null,
              height: contentHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 8,
                    child: SingleChildScrollView(
                      key: androidPhoneLandscape
                          ? const ValueKey('board-analyzer-left-scroll')
                          : null,
                      primary: false,
                      child: leading,
                    ),
                  ),
                  SizedBox(width: spec.gutter),
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(
                      key: const ValueKey('board-analyzer-right-scroll'),
                      primary: false,
                      child: trailing,
                    ),
                  ),
                ],
              ),
            )
          else if (windowsLandscape)
            SizedBox(
              key: const ValueKey('board-analyzer-windows-landscape'),
              height: contentHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: boardSection),
                        SizedBox(height: spec.gutter),
                        controlsSection,
                      ],
                    ),
                  ),
                  SizedBox(width: spec.gutter),
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(
                      key: const ValueKey(
                        'board-analyzer-windows-right-scroll',
                      ),
                      primary: false,
                      child: trailing,
                    ),
                  ),
                ],
              ),
            )
          else if (spec.canSplit)
            ResponsiveSplit(
              breakpoint: 900,
              spacing: spec.gutter,
              leadingFlex: 8,
              trailingFlex: 4,
              leading: leading,
              trailing: trailing,
            )
          else
            SectionColumn(
              spacing: 12,
              children: [
                boardSection,
                controlsSection,
                liveSection,
                candidatesSection,
                fenSection,
              ],
            ),
        ];
      },
    );
  }
}

class _AnalyzerSnapshot {
  const _AnalyzerSnapshot({required this.fen, required this.lastMove});

  final String fen;
  final List<String> lastMove;
}

String _boardOnlyFen(String fen) => fen.trim().split(RegExp(r'\s+')).first;

Set<String>? _differentSquares(String? sourceBoardFen, String targetBoardFen) {
  final source = _expandedBoard(sourceBoardFen);
  final target = _expandedBoard(targetBoardFen);
  if (source == null || target == null) return null;
  final squares = <String>{};
  for (var index = 0; index < 64; index += 1) {
    if (source[index] == target[index]) continue;
    final file = index % 8;
    final rank = index ~/ 8;
    squares.add('${ChessBoard.files[file]}${8 - rank}');
  }
  return squares;
}

List<String>? _expandedBoard(String? boardFen) {
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

String _analyzerLedSignature(PhysicalBoardModel model, Set<String> squares) {
  final normalized = squares.toList()..sort();
  return '${model.name}:${normalized.join(',')}';
}

ChessBoardMove? _resolveAnalyzerBoardFenMove({
  required String currentFen,
  required String boardFen,
}) {
  final position = loadDartChessPosition(currentFen);
  final normalizedBoardFen = _boardOnlyFen(boardFen);
  if (position.board.fen == normalizedBoardFen) return null;
  for (final move in legalNormalMoves(position)) {
    try {
      final (nextPosition, san) = position.makeSan(move);
      if (nextPosition.board.fen != normalizedBoardFen) continue;
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
      continue;
    }
  }
  return null;
}

ChessBoardMove? _moveFromCandidate(String fen, String? uci) {
  if (uci == null || uci.trim().isEmpty) return null;
  return _moveFromUci(fen, uci);
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

String _normalizeAnalyzerFenInput(String input) {
  final normalized = normalizeFenInput(input);
  if (normalized.isEmpty) return normalized;
  final parts = normalized.split(RegExp(r'\s+'));
  if (parts.length >= 2) return normalized;
  return '$normalized w - - 0 1';
}

class _AnalyzerBoardWithEval extends StatelessWidget {
  const _AnalyzerBoardWithEval({
    required this.size,
    required this.boardKey,
    required this.fen,
    required this.lastMove,
    required this.flipped,
    required this.analysis,
    required this.showCoordinates,
    required this.onMove,
  });

  final double size;
  final int boardKey;
  final String fen;
  final List<String> lastMove;
  final bool flipped;
  final PositionEngineAnalysis? analysis;
  final bool showCoordinates;
  final ValueChanged<ChessBoardMove> onMove;

  @override
  Widget build(BuildContext context) {
    final boardSize = size.clamp(180.0, 760.0).toDouble();
    return SizedBox(
      width: boardSize + _analyzerScoreBarWidth,
      height: boardSize,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            key: const ValueKey('board-analyzer-score-bar'),
            width: _analyzerScoreBarWidth,
            child: _LiveEvalBar(analysis: analysis),
          ),
          SizedBox.square(
            dimension: boardSize,
            child: InteractiveChessBoard(
              key: ValueKey('board-analyzer-board-$boardKey'),
              size: boardSize,
              initialFen: fen,
              flipped: flipped,
              lastMove: lastMove,
              showCoordinates: showCoordinates,
              onMove: onMove,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveEvalBar extends StatelessWidget {
  const _LiveEvalBar({required this.analysis});

  final PositionEngineAnalysis? analysis;

  @override
  Widget build(BuildContext context) {
    final eval = analysis?.whiteEval ?? 0;
    final normalized = ((eval + 4) / 8).clamp(0.06, 0.94).toDouble();
    final scheme = Theme.of(context).colorScheme;
    const labelHeight = 58.0;
    return Tooltip(
      message: 'Live evaluation',
      child: Semantics(
        label: 'Live evaluation',
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
                            tween: Tween<double>(
                              begin: 0.5,
                              end: normalized,
                            ),
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
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
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
                    key: const ValueKey('board-analyzer-score-label'),
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
                          key: const ValueKey(
                            'board-analyzer-score-label-vertical',
                          ),
                          quarterTurns: 3,
                          child: Text(
                            _formatLiveEval(eval),
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
      ),
    );
  }
}

class _AnalyzerControls extends StatelessWidget {
  const _AnalyzerControls({
    required this.canUndo,
    required this.onUndo,
    required this.onReset,
    required this.onFlip,
    this.compact = false,
  });

  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onReset;
  final VoidCallback onFlip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 8,
      ),
      borderRadius: 13,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton.filledTonal(
            tooltip: 'Undo move',
            onPressed: canUndo ? onUndo : null,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton.filledTonal(
            tooltip: 'Reset board',
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
          IconButton.filledTonal(
            tooltip: 'Flip board',
            onPressed: onFlip,
            icon: const Icon(Icons.flip_camera_android_rounded),
          ),
        ],
      ),
    );
  }
}

class _FenInputCard extends StatelessWidget {
  const _FenInputCard({
    required this.controller,
    required this.focusNode,
    required this.errorText,
    required this.onLoad,
    this.compact = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? errorText;
  final VoidCallback onLoad;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.all(compact ? 10 : 12),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Load FEN',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: compact ? 14 : null,
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          TextField(
            key: const ValueKey('board-analyzer-fen-input'),
            controller: controller,
            focusNode: focusNode,
            minLines: compact ? 1 : 2,
            maxLines: compact ? 2 : 3,
            scrollPadding: EdgeInsets.zero,
            decoration: InputDecoration(
              hintText: chessnutStandardStartFen,
              errorText: errorText,
              border: const OutlineInputBorder(),
              isDense: compact,
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          FilledButton.icon(
            onPressed: onLoad,
            icon: const Icon(Icons.upload_rounded),
            label: const Text('Analyze FEN'),
          ),
        ],
      ),
    );
  }
}

class _LiveEnginePanel extends StatelessWidget {
  const _LiveEnginePanel({
    required this.fen,
    required this.analyzing,
    required this.statusText,
    required this.analysis,
    this.compact = false,
  });

  final String fen;
  final bool analyzing;
  final String? statusText;
  final PositionEngineAnalysis? analysis;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = ChessnutTheme.tokensOf(context);
    final primary = Theme.of(context).colorScheme.primary;
    final score =
        analysis == null ? '--' : _formatLiveEval(analysis!.whiteEval);
    return GlassPanel(
      padding: EdgeInsets.all(compact ? 10 : 14),
      borderRadius: 14,
      tint: primary.withValues(alpha: 0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 36 : 42,
                height: compact ? 36 : 42,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(tokens.controlRadius),
                ),
                child: analyzing
                    ? Padding(
                        padding: EdgeInsets.all(compact ? 9 : 11),
                        child:
                            const CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : Icon(
                        Icons.analytics_rounded,
                        color: primary,
                        size: compact ? 20 : 24,
                      ),
              ),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stockfish live',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 15 : 17,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 2),
                      const Text('Realtime score for the current FEN'),
                    ],
                  ],
                ),
              ),
              IconButton.filledTonal(
                key: const ValueKey('board-analyzer-stockfish-help'),
                tooltip: 'How to use',
                onPressed: () => _showBoardAnalyzerHelp(context),
                icon: const Icon(Icons.info_outline_rounded),
                constraints: const BoxConstraints.tightFor(
                  width: 34,
                  height: 34,
                ),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 16),
          Text(
            score,
            style: (compact
                    ? Theme.of(context).textTheme.headlineMedium
                    : Theme.of(context).textTheme.displaySmall)
                ?.copyWith(
              fontWeight: FontWeight.w900,
              color: primary,
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            statusText ?? '',
            maxLines: compact ? 2 : null,
            overflow: compact ? TextOverflow.ellipsis : null,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SizedBox(height: compact ? 8 : 14),
          _EngineFactRow(
            label: 'Best move',
            value: _moveLabel(fen: fen, uci: analysis?.bestMoveUci),
          ),
          SizedBox(height: compact ? 6 : 8),
          _EngineFactRow(
            label: 'Depth',
            value: analysis == null ? '--' : '${analysis!.depth}',
          ),
        ],
      ),
    );
  }
}

void _showBoardAnalyzerHelp(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Stockfish live'),
      content: const Text(_boardAnalyzerHelpText),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

class _EngineFactRow extends StatelessWidget {
  const _EngineFactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _CandidateLinesCard extends StatelessWidget {
  const _CandidateLinesCard({
    required this.fen,
    required this.analysis,
    required this.onCandidateSelected,
    this.compact = false,
  });

  final String fen;
  final PositionEngineAnalysis? analysis;
  final void Function(EngineMoveCandidate candidate, int pvIndex)
      onCandidateSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final candidates =
        analysis?.candidateMoves ?? const <EngineMoveCandidate>[];
    final pv = analysis?.pv ?? const <String>[];
    return GlassPanel(
      padding: EdgeInsets.all(compact ? 10 : 12),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Candidate lines',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: compact ? 14 : null,
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          if (candidates.isEmpty)
            Text(
              pv.isEmpty ? 'Move the pieces to start analysis.' : pv.join(' '),
              maxLines: compact ? 3 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (var i = 0; i < candidates.length; i++) ...[
              if (i > 0) SizedBox(height: compact ? 6 : 8),
              _CandidateLine(
                fen: fen,
                index: i + 1,
                candidate: candidates[i],
                compact: compact,
                onMoveSelected: (pvIndex) =>
                    onCandidateSelected(candidates[i], pvIndex),
              ),
            ],
        ],
      ),
    );
  }
}

class _CandidateLine extends StatelessWidget {
  const _CandidateLine({
    required this.fen,
    required this.index,
    required this.candidate,
    required this.onMoveSelected,
    this.compact = false,
  });

  final String fen;
  final int index;
  final EngineMoveCandidate candidate;
  final ValueChanged<int> onMoveSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final groups = _candidateLineGroups(fen: fen, candidate: candidate);
    final lineChildren = <Widget>[];
    for (var i = 0; i < groups.length; i++) {
      if (i > 0) {
        lineChildren.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.chevron_right_rounded,
              size: compact ? 15 : 17,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
      }
      lineChildren.add(
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 8,
            vertical: compact ? 3 : 4,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var j = 0; j < groups[i].length; j++) ...[
                if (j > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Text(
                      '·',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                InkWell(
                  key: ValueKey(
                    'board-analyzer-candidate-$index-san-${groups[i][j].pvIndex}',
                  ),
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => onMoveSelected(groups[i][j].pvIndex),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 1,
                    ),
                    child: Text(
                      groups[i][j].san,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    final sideToMove = _sideToMoveFromFen(fen);
    final whiteMate = candidate.whiteMate(sideToMove: sideToMove);
    final score = candidate.scoreMate != null
        ? 'M$whiteMate'
        : candidate.scoreCentipawns == null
            ? '--'
            : _formatLiveEval(
                candidate.whitePawnScore(sideToMove: sideToMove),
              );
    return Material(
      color: Colors.transparent,
      child: Padding(
        key: ValueKey('board-analyzer-candidate-$index'),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 6,
          vertical: compact ? 4 : 6,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '#$index',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: ValueKey('board-analyzer-candidate-line-$index'),
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: lineChildren,
                ),
              ),
            ),
            SizedBox(width: compact ? 8 : 12),
            Text(score),
          ],
        ),
      ),
    );
  }
}

String _formatLiveEval(double value) {
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(2)}';
}

String _sideToMoveFromFen(String fen) {
  final parts = fen.trim().split(RegExp(r'\s+'));
  return parts.length > 1 && parts[1] == 'b' ? 'b' : 'w';
}

String _moveLabel({required String fen, required String? uci}) {
  if (uci == null || uci.isEmpty) return 'Waiting';
  try {
    final position = dc.Chess.fromSetup(
      dc.Setup.parseFen(normalizeFenInput(fen)),
    );
    final move = dc.NormalMove.fromUci(uci);
    if (!position.isLegal(move)) return uci;
    final (_, san) = position.makeSan(move);
    return '$san / $uci';
  } catch (_) {
    return uci;
  }
}

class _CandidateSanMove {
  const _CandidateSanMove({required this.pvIndex, required this.san});

  final int pvIndex;
  final String san;
}

List<List<_CandidateSanMove>> _candidateLineGroups({
  required String fen,
  required EngineMoveCandidate candidate,
}) {
  final pv = candidate.pv.isEmpty ? [candidate.moveUci] : candidate.pv;
  try {
    dc.Position position = dc.Chess.fromSetup(
      dc.Setup.parseFen(normalizeFenInput(fen)),
    );
    final fenFields = normalizeFenInput(fen).split(RegExp(r'\s+'));
    var whiteToMove = fenFields.elementAtOrNull(1) != 'b';
    final groups = <List<_CandidateSanMove>>[];
    final currentRound = <_CandidateSanMove>[];
    for (var i = 0; i < pv.length; i++) {
      final uci = pv[i];
      final move = dc.NormalMove.fromUci(uci);
      if (!position.isLegal(move)) return _fallbackCandidateGroups(pv);
      final (nextPosition, san) = position.makeSan(move);
      if (whiteToMove && currentRound.isNotEmpty) {
        groups.add(List.unmodifiable(currentRound));
        currentRound.clear();
      }
      currentRound.add(_CandidateSanMove(pvIndex: i, san: san));
      if (!whiteToMove) {
        groups.add(List.unmodifiable(currentRound));
        currentRound.clear();
      }
      whiteToMove = !whiteToMove;
      position = nextPosition;
    }
    if (currentRound.isNotEmpty) {
      groups.add(List.unmodifiable(currentRound));
    }
    return groups;
  } catch (_) {
    return _fallbackCandidateGroups(pv);
  }
}

List<List<_CandidateSanMove>> _fallbackCandidateGroups(List<String> pv) => [
      for (var i = 0; i < pv.length; i += 2)
        [
          _CandidateSanMove(pvIndex: i, san: pv[i]),
          if (i + 1 < pv.length)
            _CandidateSanMove(pvIndex: i + 1, san: pv[i + 1]),
        ],
    ];
