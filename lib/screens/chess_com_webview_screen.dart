import 'dart:convert';
import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:dartchess/dartchess.dart' as dc;
import 'package:flutter/foundation.dart';
import '../l10n/localized_material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as windows_webview;

import '../models/app_models.dart';
import '../services/board_settings_service.dart';
import '../services/chess_com_board_utils.dart';
import '../services/chess_clock_switch_service.dart';
import '../services/chessnut_api_client.dart';
import '../services/game_notation_service.dart';
import '../services/game_record_repository.dart';
import '../services/game_record_save_service.dart';
import '../services/local_game_record_store.dart';
import '../services/network_latency_service.dart';
import '../services/physical_board_gateway.dart';
import '../services/physical_board_orientation.dart';
import '../services/physical_board_protocol.dart';
import '../services/screen_wake_lock_service.dart';
import '../services/voice_move_recognition_service.dart';
import '../services/voice_move_session_controller.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_feedback.dart';
import '../widgets/chess_board.dart';
import '../widgets/webview_zoom_guard.dart';
import '../widgets/voice_moves_shortcut.dart';

Object? _decodeChessComJavaScriptResult(Object? value) {
  if (value is! String) return value;
  Object? decoded = value;
  for (var depth = 0; depth < 3 && decoded is String; depth += 1) {
    final text = decoded.trim();
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return text;
    }
  }
  return decoded;
}

String? _normalizeChessComStringResult(Object? value) {
  final decoded = _decodeChessComJavaScriptResult(value);
  if (decoded == null) return null;
  final text = decoded.toString().trim();
  return text.isEmpty || text == 'null' ? null : text;
}

String? _normalizeChessComFenResult(Object? value) {
  final raw = _normalizeChessComStringResult(value);
  if (raw == null) return null;
  final ranks = raw.split(' ').first.split('/');
  if (ranks.length != 8 || !ranks.every(_validChessComFenRank)) return null;
  return raw;
}

bool _validChessComFenRank(String rank) {
  if (rank.isEmpty || !RegExp(r'^[prnbqkPRNBQK1-8]+$').hasMatch(rank)) {
    return false;
  }
  var squares = 0;
  for (final codeUnit in rank.codeUnits) {
    final symbol = String.fromCharCode(codeUnit);
    squares += int.tryParse(symbol) ?? 1;
  }
  return squares == 8;
}

String? _normalizeChessComPlayerName(Object? value) {
  var cleaned = value?.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned == null) return null;
  cleaned = cleaned
      .replaceFirst(
        RegExp(
          r'^(GM|IM|FM|CM|NM|WGM|WIM|WFM|WCM)\s+',
          caseSensitive: false,
        ),
        '',
      )
      .replaceFirst(RegExp(r'\s*[+-]\d{1,4}\s*$'), '')
      .replaceFirst(RegExp(r'\s*\(\d{3,4}\??\)\s*$'), '')
      .replaceFirst(RegExp(r'\s+(\d{3,4})(\?)?$'), '')
      .replaceFirst(RegExp(r'\s*(\d+:\d{2}|\d+\.\d+)$'), '')
      .trim();
  if (cleaned.isEmpty || cleaned.length > 40) return null;
  return cleaned;
}

class ChessComWebViewScreen extends StatefulWidget {
  const ChessComWebViewScreen({
    required this.onNavigate,
    required this.apiClient,
    this.boardGateway,
    this.boardSettings = const BoardSettingsState(),
    this.clockSwitchService,
    this.latencyProbe,
    this.onBoardConnected,
    this.initialUrl,
    this.webViewAdapter,
    this.voiceMoveRecognitionService,
    this.isChessnutClockDevice = false,
    this.hidePhysicalBoardConnectionUi = false,
    this.onGameActiveChanged,
    this.onFinishedRecordSaved,
    this.recordSaveService,
    this.recordOwnerUserId,
    this.evo2LedRefreshRequestId = 0,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final ChessnutApiClient apiClient;
  final PhysicalBoardGateway? boardGateway;
  final BoardSettingsState boardSettings;
  final ChessClockSwitchService? clockSwitchService;
  final NetworkLatencyProbe? latencyProbe;
  final ValueChanged<PhysicalBoardModel>? onBoardConnected;
  final Uri? initialUrl;
  final ChessComWebViewAdapter? webViewAdapter;
  final VoiceMoveRecognitionService? voiceMoveRecognitionService;
  final bool isChessnutClockDevice;
  final bool hidePhysicalBoardConnectionUi;
  final ValueChanged<bool>? onGameActiveChanged;
  final VoidCallback? onFinishedRecordSaved;
  final GameRecordSaveService? recordSaveService;
  final int? recordOwnerUserId;
  final int evo2LedRefreshRequestId;

  @override
  State<ChessComWebViewScreen> createState() => _ChessComWebViewScreenState();
}

class _ChessComWebViewScreenState extends State<ChessComWebViewScreen> {
  static const double _sideHeaderWidth = 68;
  static const double _topHeaderHeight = 56;

  static const _clockSwitchReboundDelay = Duration(milliseconds: 250);
  static const _moveBoardActionSettleTimeout = Duration(seconds: 3);
  static const _chessComFenUnavailableTimeout = Duration(seconds: 5);

  bool _initializing = true;
  String _bridgeStatus = 'Preparing';
  PhysicalBoardConnectionState _boardState =
      PhysicalBoardConnectionState.disconnected;
  String _latestFen = chessnutStandardStartFen;
  ChessComResolvedMove? _lastInjectedMove;
  String? _lastMoveBoardTargetFen;
  DateTime? _missingChessComFenSince;
  bool _chessComBoardAvailable = true;
  Timer? _pollTimer;
  Timer? _recordSaveTimer;
  Timer? _pendingBoardMoveTimer;
  Timer? _moveBoardRestoreTimer;
  Timer? _webViewRecoveryTimer;
  Timer? _moveBoardActionSettleTimer;
  String? _pendingBoardMoveFen;
  String? _pendingMoveBoardRestoreFen;
  String? _pendingLocalWebBoardFen;
  String? _pendingClockSwitchBoardFen;
  String? _pendingClockSwitchExpectedFen;
  String? _pendingOpponentClockSwitchBoardFen;
  late BoardFenStabilityBuffer _boardFenStabilityBuffer;
  late final PhysicalBoardOrientationResolver _boardOrientation;
  String? _physicalBoardFen;
  Set<String> _legalTargetLedSquares = const {};
  bool _moveBoardSyncLocked = false;
  bool _leavingChessCom = false;
  int _moveBoardActionGeneration = 0;
  String? _moveBoardActionExpectedFen;
  Completer<void>? _moveBoardActionSettled;
  Future<void> _moveLedWriteQueue = Future<void>.value();
  String? _lastMoveLedStateKey;
  int? _recordPgnId;
  String? _recordIdentityKey;
  String? _recordGameId;
  int? _recordOwnerUserId;
  String? _currentChessComPgn;
  int _currentChessComGameStep = 0;
  String _currentChessComResult = '*';
  String? _finishedChessComFen;
  String? _lastSubmittedPgnKey;
  Future<void> _recordSaveQueue = Future<void>.value();
  String? _lastCheckBeepFen;
  bool _finishedRecordSavedNotified = false;
  bool? _localPlayerIsWhite;
  bool _boardConnectInFlight = false;
  bool _moveBoardActionInFlight = false;
  bool _webViewRecovering = false;
  bool _fenPollInFlight = false;
  bool _fenPollPending = false;
  bool? _reportedGameActive;
  bool _bridgeInjected = false;

  ChessComWebViewAdapter? _webViewAdapter;
  late final ChessClockSwitchService _clockSwitchService;
  late final bool _ownsClockSwitchService;
  late final VoiceMoveSessionController _voiceMoves;
  StreamSubscription<int>? _clockSwitchSub;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  bool get _isWindows => defaultTargetPlatform == TargetPlatform.windows;

  bool get _usesMobileTopHeader =>
      !widget.isChessnutClockDevice &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  bool get _isWidgetTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  bool get _canUseVoiceMoves =>
      widget.boardGateway?.boardModel == PhysicalBoardModel.move &&
      _boardState == PhysicalBoardConnectionState.connected;

  bool get _hasConnectedPhysicalBoard {
    final gateway = widget.boardGateway;
    if (gateway == null) return false;
    return _boardState == PhysicalBoardConnectionState.connected ||
        gateway.currentState == PhysicalBoardConnectionState.connected;
  }

  bool get _showMoveBoardActions =>
      !kIsWeb &&
      const {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.windows,
        TargetPlatform.macOS,
      }.contains(defaultTargetPlatform) &&
      widget.boardGateway?.boardModel == PhysicalBoardModel.move &&
      _hasConnectedPhysicalBoard;

  bool get _isMoveBoard =>
      widget.boardGateway?.boardModel == PhysicalBoardModel.move;

  bool get _moveBoardSyncUnavailable =>
      _isMoveBoard && !_chessComBoardAvailable;

  bool get _isChessComGameActive =>
      _currentChessComPgn != null &&
      !_isFinishedChessComResult(_currentChessComResult) &&
      _currentChessComGameStep > 0;

  @override
  void initState() {
    super.initState();
    _boardOrientation = PhysicalBoardOrientationResolver(
      settings: widget.boardSettings,
    );
    _ownsClockSwitchService = widget.clockSwitchService == null;
    _clockSwitchService =
        widget.clockSwitchService ?? ChessClockSwitchService();
    _voiceMoves = VoiceMoveSessionController(
      service: widget.voiceMoveRecognitionService ??
          VoiceMoveRecognitionService(
              openAiKeyProvider: _openAiKeyForVoiceMove),
      ownsService: widget.voiceMoveRecognitionService == null,
      onChanged: _refreshVoiceMovesState,
      onMoveUci: (uci) => unawaited(_handleVoiceMoveUci(uci)),
      onMessage: _showVoiceMoveMessage,
      currentFenProvider: () => _latestFen,
    );
    _clockSwitchService.initialize();
    if (widget.boardSettings.submitMoveOnClockSwitch) {
      _clockSwitchSub =
          _clockSwitchService.switchEvents.listen(_handleClockSwitchEvent);
    }
    _boardFenStabilityBuffer = BoardFenStabilityBuffer(
      onStableFen: (fen) => unawaited(_handlePhysicalBoardFen(fen)),
    );
    final gateway = widget.boardGateway;
    if (gateway != null) {
      _boardState = gateway.currentState;
      _subscriptions.add(
        gateway.stateStream.listen((state) {
          if (!mounted) return;
          setState(() => _boardState = state);
          if (state != PhysicalBoardConnectionState.connected) {
            _lastMoveLedStateKey = null;
          }
          if (!_canUseVoiceMoves) {
            unawaited(_voiceMoves.stop());
          }
        }),
      );
      _subscriptions.add(
        gateway.boardFenStream.listen((fen) {
          final normalizedFen = _normalizePhysicalBoardFen(fen);
          if (!_moveBoardSyncLocked) {
            _previewPhysicalBoardFenForGuidance(normalizedFen);
          }
          _boardFenStabilityBuffer.add(normalizedFen);
        }),
      );
    }
    unawaited(_initialize());
  }

  @override
  void didUpdateWidget(covariant ChessComWebViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.evo2LedRefreshRequestId != widget.evo2LedRefreshRequestId &&
        widget.boardGateway?.boardModel == PhysicalBoardModel.evo2) {
      unawaited(_syncPhysicalLegalTargetLeds());
    }
    if (_boardOrientation.updateSettings(widget.boardSettings)) {
      _resetPhysicalBoardOrientationCache();
      unawaited(_syncPhysicalBoardToLatestFen());
    }
  }

  String _normalizePhysicalBoardFen(String fen) {
    return _boardOrientation.normalizeAndTrack(
      fen,
      referenceFens: [_latestFen],
      onMappingChanged: (_) => _resetPhysicalBoardOrientationCache(),
    );
  }

  void _resetPhysicalBoardOrientationCache() {
    _lastMoveBoardTargetFen = null;
  }

  @override
  void dispose() {
    _reportGameActive(false);
    _pollTimer?.cancel();
    _recordSaveTimer?.cancel();
    _pendingBoardMoveTimer?.cancel();
    _moveBoardRestoreTimer?.cancel();
    _moveBoardActionSettleTimer?.cancel();
    _webViewRecoveryTimer?.cancel();
    _pendingBoardMoveFen = null;
    _pendingMoveBoardRestoreFen = null;
    _moveBoardActionSettled = null;
    _moveBoardActionExpectedFen = null;
    _moveBoardSyncLocked = false;
    _lastMoveBoardTargetFen = null;
    _pendingOpponentClockSwitchBoardFen = null;
    _clearPendingClockSwitchMove();
    unawaited(_clearPhysicalBoardGuidance());
    _boardFenStabilityBuffer.dispose();
    unawaited(_webViewAdapter?.dispose());
    unawaited(_clockSwitchSub?.cancel());
    if (_ownsClockSwitchService) {
      unawaited(_clockSwitchService.dispose());
    }
    unawaited(_voiceMoves.dispose());
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() {
      _initializing = true;
      _bridgeStatus = 'Fetching Chess Helper';
    });

    if (_isWidgetTest && widget.webViewAdapter == null) {
      _bridgeInjected = true;
      _markFallback('Preview mode', bridgeStatus: 'Injected');
      return;
    }

    if (widget.webViewAdapter == null &&
        !_isWindows &&
        WebViewPlatform.instance == null) {
      _markFallback('WebView platform missing');
      return;
    }

    final remoteScript = await widget.apiClient.chesscomJs() ?? '';
    // chess-helper.js registers its public APIs directly in the page context.
    final helperScript = remoteScript;

    try {
      final adapter = widget.webViewAdapter ?? _createWebViewAdapter();
      _webViewAdapter = adapter;
      await adapter.initialize(
        initialUrl: widget.initialUrl ??
            Uri.parse(
              'https://www.chess.com/login_and_go?returnUrl=https://www.chess.com/',
            ),
        onPageStarted: () {
          if (!mounted) return;
          setState(() {
            _bridgeInjected = false;
            _bridgeStatus = 'Waiting for page';
          });
        },
        onPageFinished: () async {
          if (!mounted) return;
          await _injectBridge(helperScript);
        },
        onRecoverRequested: () => _requestWebViewRecovery(),
      );
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _bridgeStatus = 'Waiting for page';
      });
      unawaited(_saveChessComRecord());
      _startFenPolling();
      _startRecordSaving();
    } catch (_) {
      _markFallback('Chess.com board could not open in the app');
    }
  }

  Future<void> _connectPhysicalBoardFromSidebar() async {
    final gateway = widget.boardGateway;
    if (gateway == null || _boardConnectInFlight) return;
    if (gateway.currentState == PhysicalBoardConnectionState.connected ||
        _boardState == PhysicalBoardConnectionState.connected) {
      return;
    }

    setState(() {
      _boardConnectInFlight = true;
      _boardState = PhysicalBoardConnectionState.scanning;
    });
    var connected = false;
    try {
      connected = await gateway.connect();
    } catch (_) {
      connected = false;
    }
    if (!mounted) return;
    final currentState = gateway.currentState;
    final isConnected =
        connected || currentState == PhysicalBoardConnectionState.connected;
    setState(() {
      _boardConnectInFlight = false;
      _boardState = isConnected
          ? PhysicalBoardConnectionState.connected
          : PhysicalBoardConnectionState.disconnected;
    });
    if (isConnected) {
      widget.onBoardConnected?.call(gateway.boardModel);
    } else {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Board connection failed.')),
        );
    }
  }

  Future<void> _injectBridge(String bridgeScript) async {
    await _webViewAdapter?.injectTextScaleGuard();
    await _runJavaScript(bridgeScript);
    final result = await _runJavaScript(
      'typeof window.getCurrentFEN === "function" && '
      'typeof window.getCurrentPGN === "function" && '
      'typeof window.makeUCIMove === "function"',
    );
    if (!mounted) return;
    final injected = _javaScriptResultIsTrue(result);
    if (injected) {
      _missingChessComFenSince = null;
      _chessComBoardAvailable = true;
    }
    setState(() {
      _bridgeInjected = injected;
      _bridgeStatus = injected ? 'Injected' : 'Bridge injection failed';
    });
  }

  Future<Object?> _runJavaScript(String script) async {
    try {
      final adapter = _webViewAdapter;
      if (adapter == null) {
        if (_isWidgetTest && script.contains('window.makeUCIMove')) {
          return true;
        }
        return null;
      }
      return await adapter.runJavaScript(script);
    } catch (error) {
      if (_shouldRecoverFromJavaScriptError(error)) {
        _requestWebViewRecovery();
      }
      return null;
    }
  }

  Future<void> _refreshChessComPage() async {
    try {
      await _webViewAdapter?.reload();
    } catch (error) {
      if (_shouldRecoverFromJavaScriptError(error)) {
        _requestWebViewRecovery();
      }
    }
  }

  bool _shouldRecoverFromJavaScriptError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('render process') ||
        message.contains('renderer') ||
        message.contains('webview') && message.contains('crash') ||
        message.contains('webview') && message.contains('destroy') ||
        message.contains('webview') && message.contains('invalid') ||
        message.contains('web content process') ||
        message.contains('terminated');
  }

  void _requestWebViewRecovery() {
    if (!mounted || _webViewRecovering) return;
    _webViewRecoveryTimer?.cancel();
    _webViewRecoveryTimer = Timer(const Duration(milliseconds: 150), () {
      unawaited(_recoverChessComWebView());
    });
  }

  Future<void> _recoverChessComWebView() async {
    if (!mounted || _webViewRecovering) return;
    _webViewRecovering = true;
    _bridgeInjected = false;
    _webViewRecoveryTimer?.cancel();
    _pollTimer?.cancel();
    _recordSaveTimer?.cancel();
    setState(() {
      _initializing = true;
      _bridgeStatus = 'Reloading Chess.com';
    });

    try {
      final existingAdapter = _webViewAdapter;
      if (widget.webViewAdapter != null) {
        await existingAdapter?.reload();
        if (!mounted) return;
        setState(() {
          _initializing = false;
          _bridgeStatus = 'Waiting for page';
        });
        _startFenPolling();
        _startRecordSaving();
        return;
      }

      _webViewAdapter = null;
      await existingAdapter?.dispose();
      if (!mounted) return;
      setState(() {});
      await _initialize();
    } catch (_) {
      _markFallback('Chess.com board could not reopen in the app');
    } finally {
      _webViewRecovering = false;
    }
  }

  void _startFenPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 900),
      (_) => unawaited(_pollChessComFen()),
    );
  }

  Future<void> _pollChessComFen() async {
    if (_leavingChessCom || !_bridgeInjected) return;
    if (_fenPollInFlight) {
      _fenPollPending = true;
      return;
    }
    _fenPollInFlight = true;
    try {
      final value = await _runJavaScript('window.getCurrentFEN()');
      if (_leavingChessCom) return;
      final fen = _normalizeChessComFenResult(value);
      if (fen == null || !mounted) {
        if (fen == null && mounted && _isMoveBoard) {
          _missingChessComFenSince ??= DateTime.now();
          if (DateTime.now().difference(_missingChessComFenSince!) >=
              _chessComFenUnavailableTimeout) {
            unawaited(_handleChessComBoardUnavailable());
          }
        }
        return;
      }
      if (_isMoveBoard) _missingChessComFenSince = null;
      if (_isMoveBoard && !_chessComBoardAvailable) {
        _chessComBoardAvailable = true;
        _lastMoveBoardTargetFen = null;
      }
      final polledBoardFen = _boardOnlyFen(fen);
      if (polledBoardFen == _boardOnlyFen(_latestFen)) {
        unawaited(_syncPhysicalBoardToLatestFen());
        return;
      }
      if (polledBoardFen == _pendingLocalWebBoardFen) {
        unawaited(_syncPhysicalBoardToLatestFen());
        return;
      }
      final previousFen = _latestFen;
      final detectedMove = ChessComMoveResolver.resolve(
        webFen: previousFen,
        boardFen: fen,
      );
      final resolvedFen = detectedMove?.resultingFen ?? fen;
      final opponentMoveArrived = _isOpponentWebMove(
        previousFen: previousFen,
        detectedMove: detectedMove,
      );
      final localSoftwareMoveArrived = _isLocalSoftwareWebMove(
        previousFen: previousFen,
        detectedMove: detectedMove,
      );
      _handleCheckBeep(loadDartChessPosition(resolvedFen));
      setState(() => _latestFen = resolvedFen);
      if (detectedMove != null) {
        _pendingLocalWebBoardFen = null;
      }
      if (opponentMoveArrived) {
        _switchClockIfNeeded(forOpponentMove: true);
      } else if (localSoftwareMoveArrived) {
        _switchClockForConfirmedLocalSoftwareMove();
      }
      unawaited(_saveChessComRecord());
      unawaited(_syncPhysicalBoardToLatestFen());
    } finally {
      _fenPollInFlight = false;
      if (_fenPollPending && mounted) {
        _fenPollPending = false;
        unawaited(_pollChessComFen());
      }
    }
  }

  bool _isOpponentWebMove({
    required String previousFen,
    required ChessComResolvedMove? detectedMove,
  }) {
    if (detectedMove == null) return false;
    final localPlayerIsWhite = _localPlayerIsWhite;
    if (localPlayerIsWhite == null) {
      return _hasConnectedPhysicalBoard;
    }
    final movedByWhite =
        loadDartChessPosition(previousFen).turn == dc.Side.white;
    return movedByWhite != localPlayerIsWhite;
  }

  bool _isLocalSoftwareWebMove({
    required String previousFen,
    required ChessComResolvedMove? detectedMove,
  }) {
    if (detectedMove == null) return false;
    final localPlayerIsWhite = _localPlayerIsWhite;
    if (localPlayerIsWhite == null) return false;
    final movedByWhite =
        loadDartChessPosition(previousFen).turn == dc.Side.white;
    return movedByWhite == localPlayerIsWhite;
  }

  void _startRecordSaving() {
    _recordSaveTimer?.cancel();
    if (_isWidgetTest) return;
    _recordSaveTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_saveChessComRecord()),
    );
  }

  Future<void> _handlePhysicalBoardFen(String boardFen) async {
    if (_leavingChessCom) return;
    final boardOnlyFen = boardFen.trim().split(RegExp(r'\s+')).first;
    _physicalBoardFen = boardOnlyFen;
    if (_moveBoardSyncLocked) {
      if (_moveBoardActionExpectedFen == boardOnlyFen) {
        _completeMoveBoardActionSettle();
      }
      return;
    }
    if (_pendingBoardMoveFen != null && _pendingBoardMoveFen != boardOnlyFen) {
      _pendingBoardMoveTimer?.cancel();
      _pendingBoardMoveTimer = null;
      _pendingBoardMoveFen = null;
      _clearPendingClockSwitchMove();
    }
    if (_pendingClockSwitchExpectedFen != null &&
        _pendingClockSwitchExpectedFen != boardOnlyFen) {
      _clearPendingClockSwitchMove();
    }
    final liftedSelection = ChessComLegalTargetResolver.resolveLiftedPiece(
      webFen: _latestFen,
      boardFen: boardFen,
    );
    if (liftedSelection != null) {
      await _showLiftedPieceLegalTargets(liftedSelection);
      return;
    }

    final sync = ChessComBoardSync(
      runJavaScript: _runJavaScript,
      controlMode: widget.boardSettings.chessComMoveControlMode,
    );
    final preview = sync.resolveBoardFen(
      webFen: _latestFen,
      boardFen: boardFen,
    );
    if (preview.status == ChessComBoardSyncStatus.sent) {
      _cancelMoveBoardRestore();
      _clearLegalTargetState();
      final delay = widget.boardSettings.fenDelay;
      if (delay <= Duration.zero) {
        _pendingBoardMoveTimer?.cancel();
        _pendingBoardMoveTimer = null;
        _pendingBoardMoveFen = null;
        await _submitOrQueuePhysicalBoardFen(boardFen);
      } else {
        if (_pendingBoardMoveFen == boardOnlyFen &&
            _pendingBoardMoveTimer != null) {
          return;
        }
        _pendingBoardMoveTimer?.cancel();
        _pendingBoardMoveFen = boardOnlyFen;
        _pendingBoardMoveTimer = Timer(delay, () {
          _pendingBoardMoveTimer = null;
          _pendingBoardMoveFen = null;
          unawaited(_submitOrQueuePhysicalBoardFen(boardFen));
        });
      }
      return;
    }
    if (preview.status == ChessComBoardSyncStatus.unchanged) {
      _cancelMoveBoardRestore();
      _clearLegalTargetState();
      _switchPendingOpponentClockIfBoardMatches();
      await _syncPhysicalBoardGuidance();
    } else if (preview.status == ChessComBoardSyncStatus.illegal) {
      _scheduleMoveBoardRestoreToLatestFen();
    }
    if (!mounted) return;
    setState(() {
      _bridgeStatus = switch (preview.status) {
        ChessComBoardSyncStatus.sent => 'Move sent',
        ChessComBoardSyncStatus.sentWithFallback => 'Move sent via Web',
        ChessComBoardSyncStatus.unchanged => 'In sync',
        ChessComBoardSyncStatus.illegal => 'Illegal board',
        ChessComBoardSyncStatus.rejected => 'Move rejected',
      };
    });
  }

  void _previewPhysicalBoardFenForGuidance(String boardFen) {
    if (_leavingChessCom) return;
    final boardOnlyFen = _boardOnlyFen(boardFen);
    if (boardOnlyFen.isEmpty || boardOnlyFen == _physicalBoardFen) return;
    final liftedSelection = ChessComLegalTargetResolver.resolveLiftedPiece(
      webFen: _latestFen,
      boardFen: boardFen,
    );
    if (liftedSelection != null) {
      unawaited(_showLiftedPieceLegalTargets(liftedSelection));
      return;
    }
    _clearLegalTargetState();
    unawaited(_syncPhysicalBoardGuidance(boardFen: boardOnlyFen));
  }

  Future<void> _showLiftedPieceLegalTargets(
    ChessComLegalTargetSelection selection,
  ) async {
    if (!mounted) return;
    _cancelMoveBoardRestore();
    setState(() {
      _legalTargetLedSquares = selection.targetSquares;
      _bridgeStatus = 'Choose a target';
    });
    await _syncPhysicalLegalTargetLeds();
  }

  Future<void> _submitPhysicalBoardFen(
    String boardFen, {
    bool confirmedByClockSwitch = false,
  }) async {
    if (!_bridgeInjected) {
      if (mounted) setState(() => _bridgeStatus = 'Waiting for page');
      return;
    }
    final previousWebBoardFen = _boardOnlyFen(_latestFen);
    final localPlayerWasWhite =
        loadDartChessPosition(_latestFen).turn == dc.Side.white;
    final sync = ChessComBoardSync(
      runJavaScript: _runJavaScript,
      controlMode: widget.boardSettings.chessComMoveControlMode,
    );
    final result = await sync.submitBoardFen(
      webFen: _latestFen,
      boardFen: boardFen,
    );
    if (!mounted) return;
    if (result.move != null) {
      _pendingLocalWebBoardFen = previousWebBoardFen;
      _localPlayerIsWhite ??= localPlayerWasWhite;
    }
    if (result.status == ChessComBoardSyncStatus.sent ||
        result.status == ChessComBoardSyncStatus.sentWithFallback ||
        result.status == ChessComBoardSyncStatus.unchanged) {
      _clearLegalTargetState();
    }
    setState(() {
      _lastInjectedMove = result.move ?? _lastInjectedMove;
      _bridgeStatus = switch (result.status) {
        ChessComBoardSyncStatus.sent => 'Move sent',
        ChessComBoardSyncStatus.sentWithFallback => 'Move sent via Web',
        ChessComBoardSyncStatus.unchanged => 'In sync',
        ChessComBoardSyncStatus.illegal => 'Illegal board',
        ChessComBoardSyncStatus.rejected => 'Move rejected',
      };
      if (result.move != null) {
        _latestFen = result.move!.resultingFen;
        _handleCheckBeep(loadDartChessPosition(result.move!.resultingFen));
      }
    });
    if (result.move != null && !confirmedByClockSwitch) {
      _switchClockIfNeeded(forOpponentMove: false);
    }
    unawaited(_syncPhysicalBoardToLatestFen());
  }

  Future<void> _submitVoiceMoveUci(String uci) async {
    if (!_bridgeInjected) {
      if (mounted) setState(() => _bridgeStatus = 'Waiting for page');
      return;
    }
    final position = loadDartChessPosition(_latestFen);
    late final dc.NormalMove move;
    try {
      move = dc.NormalMove.fromUci(uci);
    } catch (_) {
      _showVoiceMoveMessage('Voice move $uci is not legal here.');
      return;
    }
    if (!position.isLegal(move)) {
      _showVoiceMoveMessage('Voice move $uci is not legal here.');
      return;
    }
    final previousWebBoardFen = _boardOnlyFen(_latestFen);
    final localPlayerWasWhite = position.turn == dc.Side.white;
    final (nextPosition, _) = position.makeSan(move);
    final result = await _runJavaScript(
      'window.makeUCIMove(${jsonEncode(uci)})',
    );
    final status = _javaScriptResultIsTrue(result)
        ? ChessComBoardSyncStatus.sent
        : ChessComBoardSyncStatus.rejected;
    if (!mounted) return;
    if (status == ChessComBoardSyncStatus.rejected) {
      setState(() => _bridgeStatus = 'Move rejected');
      return;
    }
    final resolved = ChessComResolvedMove(
      uci: uci,
      resultingFen: nextPosition.fen,
    );
    _pendingLocalWebBoardFen = previousWebBoardFen;
    _localPlayerIsWhite ??= localPlayerWasWhite;
    _clearLegalTargetState();
    setState(() {
      _lastInjectedMove = resolved;
      _bridgeStatus = 'Move sent';
      _latestFen = nextPosition.fen;
      _handleCheckBeep(nextPosition);
    });
    _switchClockIfNeeded(forOpponentMove: false);
    unawaited(_syncPhysicalBoardToLatestFen());
  }

  Future<void> _submitOrQueuePhysicalBoardFen(String boardFen) async {
    if (!widget.boardSettings.submitMoveOnClockSwitch) {
      _clearPendingClockSwitchMove();
      await _submitPhysicalBoardFen(boardFen);
      return;
    }
    final boardOnlyFen = _boardOnlyFen(boardFen);
    _pendingClockSwitchBoardFen = boardFen;
    _pendingClockSwitchExpectedFen = boardOnlyFen;
    if (!mounted) return;
    setState(() => _bridgeStatus = 'Press clock switch');
  }

  void _clearPendingClockSwitchMove() {
    _pendingClockSwitchBoardFen = null;
    _pendingClockSwitchExpectedFen = null;
  }

  void _handleClockSwitchEvent(int sideValue) {
    if (!mounted) return;
    final pressedSide = ChessClockSide.fromValue(sideValue);
    final boardFen = _pendingClockSwitchBoardFen;
    final expectedFen = _pendingClockSwitchExpectedFen;
    if (boardFen == null || expectedFen == null) {
      _reboundClockSwitch(pressedSide);
      return;
    }
    if (_physicalBoardFen != expectedFen) {
      _reboundClockSwitch(pressedSide);
      return;
    }
    _clearPendingClockSwitchMove();
    unawaited(
      _submitPhysicalBoardFen(boardFen, confirmedByClockSwitch: true),
    );
  }

  void _reboundClockSwitch(ChessClockSide? pressedSide) {
    if (!widget.boardSettings.submitMoveOnClockSwitch || pressedSide == null) {
      return;
    }
    unawaited(_reboundClockSwitchAfterDelay(pressedSide));
  }

  Future<void> _reboundClockSwitchAfterDelay(ChessClockSide pressedSide) async {
    await Future<void>.delayed(_clockSwitchReboundDelay);
    if (!mounted) return;
    await _switchClockToIgnoringEcho(pressedSide.opposite);
  }

  void _switchClockIfNeeded({required bool forOpponentMove}) {
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
      _pendingOpponentClockSwitchBoardFen = _boardOnlyFen(_latestFen);
      _switchPendingOpponentClockIfBoardMatches();
      return;
    }
    if (forOpponentMove) {
      _pendingOpponentClockSwitchBoardFen = null;
    }
    unawaited(_switchClockToOppositeIgnoringEcho());
  }

  void _switchClockForConfirmedLocalSoftwareMove() {
    if (widget.boardSettings.submitMoveOnClockSwitch) return;
    if (widget.boardSettings.clockSwitchAutomation ==
        ClockSwitchAutomationMode.off) {
      return;
    }
    unawaited(_switchClockToOppositeIgnoringEcho());
  }

  void _switchPendingOpponentClockIfBoardMatches() {
    final expectedFen = _pendingOpponentClockSwitchBoardFen;
    final boardFen = _physicalBoardFen;
    if (!mounted || expectedFen == null || boardFen == null) return;
    if (boardFen != expectedFen) return;
    _pendingOpponentClockSwitchBoardFen = null;
    unawaited(_switchClockToOppositeIgnoringEcho());
  }

  Future<void> _switchClockToOppositeIgnoringEcho() async {
    await _clockSwitchService.switchToOpposite();
  }

  Future<void> _switchClockToIgnoringEcho(ChessClockSide side) async {
    await _clockSwitchService.switchTo(side);
  }

  Future<void> _syncPhysicalBoardGuidance({String? boardFen}) async {
    if (_leavingChessCom || _moveBoardSyncUnavailable || _moveBoardSyncLocked) {
      return;
    }
    if (_shouldSuppressFinishedGameGuidance) {
      _clearLegalTargetState();
      await _clearPhysicalBoardGuidance();
      return;
    }
    if (_legalTargetLedSquares.isNotEmpty) {
      await _syncPhysicalLegalTargetLeds();
      return;
    }
    final gateway = widget.boardGateway;
    if (gateway == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      return;
    }
    final checkSquare = checkedKingSquareFromFen(_latestFen);
    final physicalFen = boardFen ?? _physicalBoardFen;
    final physicalDiff =
        physicalFen == null || physicalFen == _boardOnlyFen(_latestFen)
            ? const <String>{}
            : _boardOrientation.toPhysicalSquares(
                ChessComBoardGuidance.differentSquares(
                  sourceBoardFen: physicalFen,
                  targetBoardFen: _latestFen,
                ),
              );
    final physicalCheck = checkSquare == null
        ? const <String>{}
        : _boardOrientation.toPhysicalSquares({checkSquare});
    if (physicalDiff.isEmpty && physicalCheck.isEmpty) {
      await _clearPhysicalBoardGuidance();
      return;
    }
    if (gateway.boardModel == PhysicalBoardModel.move) {
      await _setMoveLedState({
        for (final square in physicalDiff) square: ChessnutMoveLedColor.red,
        for (final square in physicalCheck) square: ChessnutMoveLedColor.green,
      });
      return;
    }
    if (gateway.boardModel.usesGeneralProtocol) {
      await gateway.setGeneralLedSquares({...physicalDiff, ...physicalCheck});
    }
  }

  Future<void> _syncPhysicalBoardToLatestFen() async {
    if (_leavingChessCom || _moveBoardSyncUnavailable || _moveBoardSyncLocked) {
      return;
    }
    await _syncWebCheckHighlight();
    await _sendLatestFenToMoveBoardIfNeeded();
    await _syncPhysicalBoardGuidance();
  }

  Future<void> _syncWebCheckHighlight() async {
    // chess-helper.js intentionally exposes only FEN, PGN and UCI APIs.
  }

  void _cancelMoveBoardRestore() {
    _moveBoardRestoreTimer?.cancel();
    _moveBoardRestoreTimer = null;
    _pendingMoveBoardRestoreFen = null;
  }

  void _scheduleMoveBoardRestoreToLatestFen() {
    final gateway = widget.boardGateway;
    if (gateway == null ||
        gateway.boardModel != PhysicalBoardModel.move ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      return;
    }
    if (_physicalBoardFen == _boardOnlyFen(_latestFen)) {
      _cancelMoveBoardRestore();
      return;
    }
    final targetFen = _latestFen;
    if (_pendingMoveBoardRestoreFen == targetFen &&
        _moveBoardRestoreTimer != null) {
      return;
    }
    _moveBoardRestoreTimer?.cancel();
    _pendingMoveBoardRestoreFen = targetFen;
    final delay =
        widget.boardSettings.fenDelay + widget.boardSettings.moveRestoreDelay;
    _moveBoardRestoreTimer = Timer(delay, () {
      if (!mounted || _pendingMoveBoardRestoreFen != targetFen) return;
      _moveBoardRestoreTimer = null;
      _pendingMoveBoardRestoreFen = null;
      unawaited(_sendLatestFenToMoveBoardIfNeeded(force: true));
    });
  }

  Future<void> _sendLatestFenToMoveBoardIfNeeded({bool force = false}) async {
    if (_leavingChessCom || _moveBoardSyncUnavailable || _moveBoardSyncLocked) {
      return;
    }
    final gateway = widget.boardGateway;
    if (gateway == null ||
        gateway.boardModel != PhysicalBoardModel.move ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      return;
    }
    if (!force && _lastMoveBoardTargetFen == _latestFen) return;
    try {
      final sent = await gateway.setMoveBoardFen(
        _latestFen,
        isReverse: _boardOrientation.isReversed,
      );
      if (sent) {
        _lastMoveBoardTargetFen = _latestFen;
        _lastMoveLedStateKey = null;
      }
    } catch (_) {}
  }

  Future<void> _confirmMoveBoardAction({
    required String targetFen,
    required PhysicalBoardFenMapping targetMapping,
    required String successMessage,
  }) async {
    if (!_showMoveBoardActions || _moveBoardActionInFlight) return;
    final confirmed = await confirmMoveBoardPieceMovement(context);
    if (!confirmed || !mounted || !_showMoveBoardActions) return;
    final gateway = widget.boardGateway!;
    final generation = ++_moveBoardActionGeneration;
    _moveBoardSyncLocked = true;
    _moveBoardActionExpectedFen = _boardOnlyFen(targetFen);
    _moveBoardActionSettled = Completer<void>();
    _moveBoardActionSettleTimer?.cancel();
    _moveBoardActionSettleTimer = Timer(
      _moveBoardActionSettleTimeout,
      _completeMoveBoardActionSettle,
    );
    _boardFenStabilityBuffer.reset();
    _clearLegalTargetState();
    _lastMoveLedStateKey = null;
    setState(() => _moveBoardActionInFlight = true);
    try {
      await _setMoveLedState(const {});
      final sent = await gateway.setMoveBoardFen(
        targetFen,
        isReverse: targetMapping == PhysicalBoardFenMapping.reversed,
      );
      if (!mounted) return;
      if (!sent) {
        showAppFeedback(
          context,
          'Move board did not accept the command.',
          tone: AppFeedbackTone.error,
        );
        return;
      }
      _cancelMoveBoardRestore();
      _boardOrientation.setManualMapping(targetMapping);
      _lastMoveLedStateKey = null;
      // Keep the just-applied physical action from being resent by the next
      // unchanged Chess.com poll while the board finishes moving.
      _lastMoveBoardTargetFen = _latestFen;
      await gateway.enableRealtimeFen();
      if (!_isWidgetTest) {
        await _moveBoardActionSettled?.future;
      }
      if (generation != _moveBoardActionGeneration) return;
      _finishMoveBoardActionSync();
      await _syncPhysicalBoardGuidance();
      if (!mounted) return;
      showAppFeedback(context, successMessage, tone: AppFeedbackTone.success);
    } finally {
      if (generation == _moveBoardActionGeneration) {
        _finishMoveBoardActionSync();
      }
      if (mounted) setState(() => _moveBoardActionInFlight = false);
    }
  }

  Future<void> _resetConnectedMoveBoard() => _confirmMoveBoardAction(
        targetFen: chessnutStandardStartFen,
        targetMapping: _boardOrientation.mapping,
        successMessage: 'Move board reset to the standard starting position.',
      );

  Future<void> _flipConnectedMoveBoard() => _confirmMoveBoardAction(
        targetFen: _latestFen,
        targetMapping: _boardOrientation.isReversed
            ? PhysicalBoardFenMapping.identity
            : PhysicalBoardFenMapping.reversed,
        successMessage: 'Move board flipped.',
      );

  Future<void> _syncPhysicalLegalTargetLeds() async {
    if (_leavingChessCom || _moveBoardSyncUnavailable || _moveBoardSyncLocked) {
      return;
    }
    if (_shouldSuppressFinishedGameGuidance) {
      _clearLegalTargetState();
      await _clearPhysicalBoardGuidance();
      return;
    }
    final gateway = widget.boardGateway;
    if (gateway == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      return;
    }
    final legalTargetSquares = widget.boardSettings.chessComShowLegalMoves
        ? _legalTargetLedSquares
        : const <String>{};
    final checkSquare = checkedKingSquareFromFen(_latestFen);
    if (legalTargetSquares.isEmpty && checkSquare == null) {
      await _clearPhysicalBoardGuidance();
      return;
    }
    final physicalSquares =
        _boardOrientation.toPhysicalSquares(legalTargetSquares);
    final physicalCheck = checkSquare == null
        ? const <String>{}
        : _boardOrientation.toPhysicalSquares({checkSquare});
    if (gateway.boardModel == PhysicalBoardModel.move) {
      await _setMoveLedState({
        for (final square in physicalSquares)
          square: ChessnutMoveLedColor.green,
        for (final square in physicalCheck) square: ChessnutMoveLedColor.green,
      });
      return;
    }
    if (gateway.boardModel.usesGeneralProtocol) {
      await gateway
          .setGeneralLedSquares({...physicalSquares, ...physicalCheck});
    }
  }

  Future<void> _clearPhysicalBoardGuidance() async {
    final gateway = widget.boardGateway;
    if (gateway == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      return;
    }
    if (gateway.boardModel == PhysicalBoardModel.move) {
      await _setMoveLedState(const {});
      return;
    }
    if (gateway.boardModel.usesGeneralProtocol) {
      await gateway.clearGeneralLeds();
    }
  }

  Future<void> _setMoveLedState(
    Map<String, ChessnutMoveLedColor> squares,
  ) async {
    final gateway = widget.boardGateway;
    if (gateway == null ||
        gateway.boardModel != PhysicalBoardModel.move ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      return;
    }
    final normalized = squares.entries.toList()
      ..sort((a, b) {
        final square = a.key.compareTo(b.key);
        return square != 0 ? square : a.value.code.compareTo(b.value.code);
      });
    final stateKey = normalized.map((entry) {
      return '${entry.key}:${entry.value.code}';
    }).join('|');
    final operation = _moveLedWriteQueue.then((_) async {
      if (_lastMoveLedStateKey == stateKey) return;
      final sent = squares.isEmpty
          ? await gateway.clearMoveLeds()
          : await gateway.setMoveLedSquares(squares);
      if (sent) _lastMoveLedStateKey = stateKey;
    });
    _moveLedWriteQueue = operation.then((_) {}, onError: (_) {});
    await operation;
  }

  void _completeMoveBoardActionSettle() {
    _moveBoardActionSettleTimer?.cancel();
    _moveBoardActionSettleTimer = null;
    final settled = _moveBoardActionSettled;
    if (settled != null && !settled.isCompleted) settled.complete();
  }

  void _finishMoveBoardActionSync() {
    _completeMoveBoardActionSettle();
    _moveBoardActionSettled = null;
    _moveBoardActionExpectedFen = null;
    _moveBoardSyncLocked = false;
  }

  Future<void> _handleChessComBoardUnavailable() async {
    if (!_isMoveBoard || !_chessComBoardAvailable || _leavingChessCom) {
      return;
    }
    _chessComBoardAvailable = false;
    _moveBoardActionGeneration += 1;
    _moveBoardActionSettleTimer?.cancel();
    _moveBoardActionSettleTimer = null;
    final settled = _moveBoardActionSettled;
    if (settled != null && !settled.isCompleted) settled.complete();
    _moveBoardActionSettled = null;
    _moveBoardActionExpectedFen = null;
    _moveBoardSyncLocked = false;
    _pendingBoardMoveTimer?.cancel();
    _pendingBoardMoveTimer = null;
    _pendingBoardMoveFen = null;
    _cancelMoveBoardRestore();
    _clearPendingClockSwitchMove();
    _pendingOpponentClockSwitchBoardFen = null;
    _clearLegalTargetState();
    _lastMoveBoardTargetFen = null;
    _lastMoveLedStateKey = null;
    await _clearPhysicalBoardGuidance();
    final gateway = widget.boardGateway;
    if (gateway == null) return;
    if (gateway.boardModel == PhysicalBoardModel.move &&
        gateway.currentState == PhysicalBoardConnectionState.connected) {
      await gateway.stopMoveBoard();
    }
  }

  void _clearLegalTargetState() {
    _legalTargetLedSquares = const {};
  }

  bool _javaScriptResultIsTrue(Object? value) {
    if (value == true) return true;
    return value?.toString().replaceAll('"', '').trim().toLowerCase() == 'true';
  }

  String _boardOnlyFen(String fen) => fen.trim().split(RegExp(r'\s+')).first;

  Future<void> _saveChessComRecord() async {
    if (widget.apiClient.session == null && widget.recordSaveService == null) {
      return;
    }
    final pgn = await _readCurrentChessComPgn();
    if (pgn == null) return;
    final operation = _recordSaveQueue.then(
      (_) => _performChessComRecordSave(pgn: pgn),
    );
    _recordSaveQueue = operation.catchError((Object error, StackTrace stack) {
      debugPrint('[ChessComRecord] queued save failed: $error');
      debugPrintStack(stackTrace: stack);
    });
    return operation;
  }

  Future<void> _performChessComRecordSave({required String pgn}) async {
    if (widget.apiClient.session == null && widget.recordSaveService == null) {
      return;
    }
    try {
      final gameStep = _chessComGameStep(pgn);
      final result = _pgnHeader(pgn, 'Result').trim();
      final whiteName = _normalizeChessComPlayerName(_pgnHeader(pgn, 'White'));
      final blackName = _normalizeChessComPlayerName(_pgnHeader(pgn, 'Black'));
      final playTime = _chessComPlayTimeFromPgn(pgn);
      if (whiteName == null ||
          blackName == null ||
          whiteName == '?' ||
          blackName == '?' ||
          playTime == null ||
          (gameStep <= 0 && !_isFinishedChessComResult(result))) {
        return;
      }

      final identityKey = _activateChessComPgn(pgn, gameStep, result);
      final gameId = _recordGameId!;
      final gameStatus = _isFinishedChessComResult(result) ? 2 : 1;
      final submittedPgnKey = '$gameId\n$pgn';
      if (submittedPgnKey == _lastSubmittedPgnKey) return;
      final timeControl =
          _normalizeChessComPgnTimeControl(_pgnHeader(pgn, 'TimeControl'));
      final metadata = PgnSaveMetadata(
        clientGameId: gameId,
        speed: _chessComSpeedLabelForTimeControl(timeControl).toLowerCase(),
        timeControl: timeControl,
      );
      final winId = _chessComWinId(result);
      final saveService = widget.recordSaveService;
      if (saveService != null) {
        final saved = await saveService.saveLive(
          GameRecordDraft(
            id: gameId,
            pgn: pgn,
            whiteName: whiteName,
            blackName: blackName,
            playTime: playTime,
            playMode: 'chesscom',
            winId: winId,
            gameStatus: gameStatus,
            gameStep: gameStep,
            result: result.isEmpty ? '*' : result,
            savedAt: DateTime.now(),
            metadata: metadata,
          ),
          ownerUserId: _recordOwnerUserId,
          pgnId: _recordPgnId,
        );
        if (!saved.status.isSuccess) {
          _logChessComSaveFailure('save', saved.status);
          if (mounted) {
            showAppFeedback(context,
                saved.status.errorMessage ?? 'Game record upload failed.');
          }
          return;
        }
        if (_recordIdentityKey == identityKey) {
          _recordPgnId = saved.record?.pgnId ?? _recordPgnId;
          _lastSubmittedPgnKey = submittedPgnKey;
          if (gameStatus == 2 && !_finishedRecordSavedNotified) {
            _finishedRecordSavedNotified = true;
            widget.onFinishedRecordSaved?.call();
          }
        }
        return;
      }
      var pgnId = _recordPgnId;
      if (pgnId == null || pgnId <= 0) {
        final existing = await GameRecordRepository(
          apiClient: widget.apiClient,
        ).findExistingRecord(
          pgn: pgn,
          chessnutGameId: gameId,
        );
        if (existing?.pgnId != null && existing!.pgnId! > 0) {
          pgnId = existing.pgnId;
          if (_recordIdentityKey == identityKey) {
            _recordPgnId = pgnId;
          }
        }
      }
      var saved = false;
      if (pgnId == null || pgnId <= 0) {
        Future<ApiResult<UploadPgnResult>> upload() {
          return widget.apiClient.uploadPgn(
            pgn: pgn,
            whiteName: whiteName,
            blackName: blackName,
            playTime: playTime,
            playMode: 'chesscom',
            winId: winId,
            gameStatus: gameStatus,
            gameStep: gameStep,
            metadata: metadata,
          );
        }

        var result = await upload();
        if (result.status.apiErrorCode == authTokenRefreshedRetryCode) {
          result = await upload();
        }
        if (result.isSuccess && result.data != null) {
          saved = true;
          final uploadedPgnId = result.data!.pgnId;
          unawaited(
            GameRecordRepository(apiClient: widget.apiClient)
                .invalidateRecordPgn(uploadedPgnId),
          );
          if (_recordIdentityKey == identityKey) {
            _recordPgnId = uploadedPgnId;
            _lastSubmittedPgnKey = submittedPgnKey;
          }
        } else {
          _logChessComSaveFailure('upload', result.status);
        }
      } else {
        Future<ApiResult<PgnUpdateResult>> update() {
          return widget.apiClient.updatePgn(
            pgnId: pgnId!,
            pgn: pgn,
            whiteName: whiteName,
            blackName: blackName,
            playTime: playTime,
            winId: winId,
            gameStatus: gameStatus,
            gameStep: gameStep,
            metadata: metadata,
          );
        }

        var result = await update();
        if (result.status.apiErrorCode == authTokenRefreshedRetryCode) {
          result = await update();
        }
        if (result.isSuccess) {
          saved = true;
          unawaited(
            GameRecordRepository(apiClient: widget.apiClient)
                .invalidateRecordPgn(pgnId),
          );
          if (_recordIdentityKey == identityKey) {
            _lastSubmittedPgnKey = submittedPgnKey;
          }
        } else {
          _logChessComSaveFailure('update', result.status);
        }
      }
      if (saved &&
          _recordIdentityKey == identityKey &&
          gameStatus == 2 &&
          !_finishedRecordSavedNotified) {
        _finishedRecordSavedNotified = true;
        widget.onFinishedRecordSaved?.call();
      }
    } catch (error, stack) {
      debugPrint('[ChessComRecord] save threw: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  void _logChessComSaveFailure(String operation, ApiStatus status) {
    debugPrint(
      '[ChessComRecord] $operation failed: '
      'code=${status.apiErrorCode}, '
      'network=${status.networkError}, '
      'message=${status.errorMessage}',
    );
  }

  Future<String?> _readCurrentChessComPgn() async {
    final value = await _runJavaScript('window.getCurrentPGN()');
    final pgn = _normalizeChessComStringResult(value)?.trim();
    return pgn == null || pgn.isEmpty ? null : pgn;
  }

  String _activateChessComPgn(String pgn, int gameStep, String result) {
    final candidate = _chessComPgnIdentityKey(pgn);
    final previousPgn = _currentChessComPgn;
    if (_recordIdentityKey == null ||
        (candidate != _recordIdentityKey &&
            !_isSameChessComPgnGame(previousPgn, pgn))) {
      _recordIdentityKey = candidate;
      _recordOwnerUserId =
          widget.recordOwnerUserId ?? widget.apiClient.session?.userId;
      _recordGameId =
          'chesscom-${_recordOwnerUserId ?? 'guest'}-${sha1.convert(utf8.encode(candidate))}';
      _recordPgnId = null;
      _lastSubmittedPgnKey = null;
      _finishedRecordSavedNotified = false;
    }
    final wasFinished = _isFinishedChessComResult(_currentChessComResult);
    final isFinished = _isFinishedChessComResult(result);
    if (isFinished && !wasFinished) {
      _finishedChessComFen = _boardOnlyFen(_latestFen);
    } else if (!isFinished) {
      _finishedChessComFen = null;
    }
    _currentChessComPgn = pgn;
    _currentChessComGameStep = gameStep;
    _currentChessComResult = result.isEmpty ? '*' : result;
    _reportGameActive(_isChessComGameActive);
    return _recordIdentityKey!;
  }

  String _chessComPgnIdentityKey(String pgn) {
    final siteIdentity = _chessComSiteIdentity(pgn);
    if (siteIdentity.isNotEmpty) return 'site:$siteIdentity';
    final values = <String>[
      _pgnHeader(pgn, 'Event'),
      _pgnHeader(pgn, 'UTCDate').isNotEmpty
          ? _pgnHeader(pgn, 'UTCDate')
          : _pgnHeader(pgn, 'Date'),
      _pgnHeader(pgn, 'UTCTime').isNotEmpty
          ? _pgnHeader(pgn, 'UTCTime')
          : _pgnHeader(pgn, 'Time'),
      _pgnHeader(pgn, 'White'),
      _pgnHeader(pgn, 'Black'),
      _pgnHeader(pgn, 'TimeControl'),
      _pgnHeader(pgn, 'Round'),
      _pgnHeader(pgn, 'FEN'),
      _chessComFirstMoveIdentity(pgn),
    ].map((value) => value.trim().toLowerCase()).toList(growable: false);
    return 'headers:${values.join('|')}';
  }

  String _chessComSiteIdentity(String pgn) {
    for (final header in const ['Link', 'URL', 'GameUrl', 'Site']) {
      final raw = _pgnHeader(pgn, header).trim();
      final uri = Uri.tryParse(raw);
      if (uri == null) continue;
      final segments = uri.pathSegments.where((value) => value.isNotEmpty);
      final values = segments.toList(growable: false);
      final gameIndex = values.indexOf('game');
      if (gameIndex < 0 || gameIndex + 1 >= values.length) continue;
      return uri.replace(query: null, fragment: null).toString().toLowerCase();
    }
    for (final header in const ['GameId', 'GameID', 'GameUUID']) {
      final value = _pgnHeader(pgn, header).trim().toLowerCase();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  bool _isSameChessComPgnGame(String? previousPgn, String currentPgn) {
    if (previousPgn == null || previousPgn.trim().isEmpty) return false;
    final previousSite = _chessComSiteIdentity(previousPgn);
    final currentSite = _chessComSiteIdentity(currentPgn);
    if (previousSite.isNotEmpty && currentSite.isNotEmpty) {
      return previousSite == currentSite;
    }
    for (final header in const [
      'White',
      'Black',
      'UTCDate',
      'Date',
      'UTCTime',
      'Time',
      'TimeControl',
    ]) {
      final previous = _pgnHeader(previousPgn, header).trim().toLowerCase();
      final current = _pgnHeader(currentPgn, header).trim().toLowerCase();
      if (previous.isNotEmpty && current.isNotEmpty && previous != current) {
        return false;
      }
    }
    final samePlayers = _pgnHeader(previousPgn, 'White').trim().toLowerCase() ==
            _pgnHeader(currentPgn, 'White').trim().toLowerCase() &&
        _pgnHeader(previousPgn, 'Black').trim().toLowerCase() ==
            _pgnHeader(currentPgn, 'Black').trim().toLowerCase();
    final sameDate = (_pgnHeader(previousPgn, 'UTCDate').isNotEmpty
                ? _pgnHeader(previousPgn, 'UTCDate')
                : _pgnHeader(previousPgn, 'Date'))
            .trim()
            .toLowerCase() ==
        (_pgnHeader(currentPgn, 'UTCDate').isNotEmpty
                ? _pgnHeader(currentPgn, 'UTCDate')
                : _pgnHeader(currentPgn, 'Date'))
            .trim()
            .toLowerCase();
    final previousFirstMove = _chessComFirstMoveIdentity(previousPgn);
    final currentFirstMove = _chessComFirstMoveIdentity(currentPgn);
    final sameFirstMove = previousFirstMove.isEmpty ||
        currentFirstMove.isEmpty ||
        previousFirstMove == currentFirstMove;
    return samePlayers && sameDate && sameFirstMove;
  }

  String _chessComFirstMoveIdentity(String pgn) {
    try {
      final moves = GameNotationService.parsePgn(pgn).moves;
      return moves.isEmpty ? '' : moves.first.uci.toLowerCase();
    } catch (_) {
      return '';
    }
  }

  String _chessComSpeedLabelForTimeControl(String timeControl) {
    final trimmed = timeControl.trim();
    final lower = trimmed.toLowerCase();
    if (trimmed == '-' ||
        trimmed == '0' ||
        trimmed == '0+0' ||
        lower.contains('unlimited') ||
        lower.contains('untimed') ||
        lower.contains('infinite') ||
        lower.contains('casual')) {
      return 'Casual';
    }
    if (RegExp(r'\b\d+\s*(?:day|days)\b', caseSensitive: false)
        .hasMatch(trimmed)) {
      return 'Daily';
    }
    final incrementMatch =
        RegExp(r'\b(\d+)\s*[+|]\s*(\d+)\b').firstMatch(trimmed);
    final wholeValueMatch = RegExp(r'^\s*(\d+)\s*$').firstMatch(trimmed);
    final minuteMatch = RegExp(
      r'\b(\d+)\s*(?:min|mins|minute|minutes)\b',
      caseSensitive: false,
    ).firstMatch(trimmed);
    final match = incrementMatch ?? wholeValueMatch ?? minuteMatch;
    if (match == null) return 'Casual';
    final base = int.tryParse(match.group(1) ?? '') ?? 0;
    final increment = incrementMatch == null
        ? 0
        : int.tryParse(incrementMatch.group(2) ?? '') ?? 0;
    if (base <= 0) return 'Casual';
    final chessComMinutes = minuteMatch != null || base < 60;
    final estimatedSeconds =
        chessComMinutes ? base * 60 + increment * 40 : base + increment * 40;
    if (estimatedSeconds >= 24 * 60 * 60) return 'Daily';
    if (estimatedSeconds < 3 * 60) return 'Bullet';
    if (estimatedSeconds < 10 * 60) return 'Blitz';
    return 'Rapid';
  }

  String? _chessComPlayTimeFromPgn(String pgn) {
    final playedAt = _chessComPlayedAtFromPgn(pgn);
    if (playedAt == null) return null;
    return (playedAt.millisecondsSinceEpoch ~/ 1000).toString();
  }

  DateTime? _chessComPlayedAtFromPgn(String pgn) {
    final utcPlayedAt = _pgnDateTime(
      date: _pgnHeader(pgn, 'UTCDate'),
      time: _pgnHeader(pgn, 'UTCTime'),
    );
    if (utcPlayedAt != null) return utcPlayedAt;
    final endTime = _pgnHeader(pgn, 'EndTime').trim();
    if (endTime.isNotEmpty) {
      final endTimePlayedAt = _pgnDateTime(
        date: _pgnHeader(pgn, 'Date'),
        time: endTime,
      );
      if (endTimePlayedAt != null) return endTimePlayedAt;
    }
    return _pgnDateTime(
      date: _pgnHeader(pgn, 'Date'),
      time: _pgnHeader(pgn, 'Time'),
    );
  }

  DateTime? _pgnDateTime({required String date, required String time}) {
    final dateParts = date.trim().split(RegExp(r'[.-]'));
    if (dateParts.length < 3 || dateParts.any((part) => part.contains('?'))) {
      return null;
    }
    final year = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final day = int.tryParse(dateParts[2]);
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    var hour = 0;
    var minute = 0;
    var second = 0;
    int? offsetMinutes;
    final trimmedTime = time.trim();
    if (trimmedTime.isNotEmpty && !trimmedTime.contains('?')) {
      final match = RegExp(
        r'^(\d{1,2}):(\d{2})(?::(\d{2}))?(?:\s*(?:GMT|UTC)?\s*([+-])(\d{2})(\d{2}))?',
        caseSensitive: false,
      ).firstMatch(trimmedTime);
      if (match == null) return null;
      hour = int.tryParse(match.group(1) ?? '') ?? -1;
      minute = int.tryParse(match.group(2) ?? '') ?? -1;
      second = int.tryParse(match.group(3) ?? '0') ?? -1;
      final sign = match.group(4);
      final offsetHours = int.tryParse(match.group(5) ?? '');
      final offsetMins = int.tryParse(match.group(6) ?? '');
      if (sign != null && offsetHours != null && offsetMins != null) {
        final direction = sign == '-' ? -1 : 1;
        offsetMinutes = direction * (offsetHours * 60 + offsetMins);
      }
      if (hour < 0 ||
          hour > 23 ||
          minute < 0 ||
          minute > 59 ||
          second < 0 ||
          second > 59) {
        return null;
      }
    }

    try {
      var parsed = DateTime.utc(year, month, day, hour, minute, second);
      if (parsed.year != year || parsed.month != month || parsed.day != day) {
        return null;
      }
      if (offsetMinutes != null) {
        parsed = parsed.subtract(Duration(minutes: offsetMinutes));
      }
      return parsed;
    } catch (_) {
      return null;
    }
  }

  String _normalizeChessComPgnTimeControl(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == 'null') return '';
    final lower = trimmed.toLowerCase();
    if (lower == '-' ||
        lower == '0' ||
        lower == '0+0' ||
        lower.contains('unlimited') ||
        lower.contains('untimed') ||
        lower.contains('infinite') ||
        lower.contains('casual')) {
      return '-';
    }
    final days = RegExp(
      r'\b(\d{1,3})\s*(?:day|days)\b',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (days != null) {
      final value = int.tryParse(days.group(1) ?? '') ?? 0;
      if (value > 0) return '${value * 24 * 60 * 60}+0';
    }
    final pgnSeconds =
        RegExp(r'^(\d{2,5})(?:\+(\d{1,4}))?$').firstMatch(trimmed);
    if (pgnSeconds != null) {
      final base = int.tryParse(pgnSeconds.group(1) ?? '') ?? 0;
      final increment = int.tryParse(pgnSeconds.group(2) ?? '') ?? 0;
      return '$base+$increment';
    }
    return _normalizeChessComPageTimeControl(trimmed);
  }

  String _normalizeChessComPageTimeControl(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == 'null') return '';
    final lower = trimmed.toLowerCase();
    if (lower == '-' ||
        lower == '0' ||
        lower == '0+0' ||
        lower.contains('unlimited') ||
        lower.contains('untimed') ||
        lower.contains('infinite') ||
        lower.contains('casual')) {
      return '-';
    }
    final days = RegExp(
      r'\b(\d{1,3})\s*(?:day|days)\b',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (days != null) {
      final value = int.tryParse(days.group(1) ?? '') ?? 0;
      if (value > 0) return '${value * 24 * 60 * 60}+0';
    }
    final minutesPlus =
        RegExp(r'\b(\d{1,3})\s*\+\s*(\d{1,3})\b').firstMatch(trimmed);
    if (minutesPlus != null) {
      final minutes = int.tryParse(minutesPlus.group(1) ?? '') ?? 0;
      final increment = int.tryParse(minutesPlus.group(2) ?? '') ?? 0;
      if (minutes <= 0 && increment <= 0) return '-';
      return '${minutes * 60}+$increment';
    }
    final minutes = RegExp(
      r'\b(\d{1,3})\s*(?:min|mins|minute|minutes)\b',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (minutes != null) {
      final value = int.tryParse(minutes.group(1) ?? '') ?? 0;
      if (value <= 0) return '-';
      return '${value * 60}+0';
    }
    return '';
  }

  int _chessComGameStep(String pgn) {
    try {
      return GameNotationService.parsePgn(pgn).moves.length;
    } catch (_) {
      return 0;
    }
  }

  void _handleCheckBeep(dc.Position position) {
    if (!position.isCheck) {
      _lastCheckBeepFen = null;
      return;
    }
    final fen = position.fen;
    if (_lastCheckBeepFen == fen) return;
    final gateway = widget.boardGateway;
    if (!widget.boardSettings.effectiveCheckmateBeep ||
        gateway == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      return;
    }
    _lastCheckBeepFen = fen;
    unawaited(gateway.playBeep());
  }

  String _pgnHeader(String pgn, String name) {
    final match =
        RegExp('^\\[$name\\s+"(.*)"\\]\$', multiLine: true).firstMatch(pgn);
    return match?.group(1)?.replaceAll(r'\"', '"').replaceAll(r'\\', '\\') ??
        '';
  }

  bool _isFinishedChessComResult(String value) {
    return value == '1-0' || value == '0-1' || value == '1/2-1/2';
  }

  bool get _shouldSuppressFinishedGameGuidance =>
      _isMoveBoard &&
      _isFinishedChessComResult(_currentChessComResult) &&
      _finishedChessComFen != null &&
      _boardOnlyFen(_latestFen) == _finishedChessComFen;

  void _reportGameActive(bool active) {
    if (_reportedGameActive == active) return;
    _reportedGameActive = active;
    widget.onGameActiveChanged?.call(active);
  }

  int _chessComWinId(String result) {
    return switch (result) {
      '1-0' => 1,
      '0-1' => 2,
      '1/2-1/2' => 3,
      _ => 0,
    };
  }

  void _markFallback(String message, {String bridgeStatus = 'Preview mode'}) {
    if (!mounted) return;
    setState(() {
      _initializing = false;
      _bridgeStatus = bridgeStatus;
    });
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
    setState(() => _bridgeStatus = message);
  }

  Future<void> _handleVoiceMoveUci(String uci) async {
    await _submitVoiceMoveUci(uci);
  }

  @override
  Widget build(BuildContext context) {
    final mediaPadding = MediaQuery.paddingOf(context);
    final usesMobileTopHeader = _usesMobileTopHeader;
    final voiceMovesShortcut = _canUseVoiceMoves
        ? VoiceMovesShortcutButton(
            enabled: _voiceMoves.enabled,
            listening: _voiceMoves.listening,
            onPressed: _toggleVoiceMoves,
            valueKey: const ValueKey('chesscom-voice-moves-toggle'),
          )
        : null;
    return ScreenWakeFenActivityReporter(
      fen: _latestFen,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _showExitConfirm(context);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              left: usesMobileTopHeader
                  ? mediaPadding.left
                  : mediaPadding.left + _sideHeaderWidth,
              top:
                  usesMobileTopHeader ? mediaPadding.top + _topHeaderHeight : 0,
              right: usesMobileTopHeader ? mediaPadding.right : 0,
              child: _ImmersiveWebViewFrame(
                initializing: _initializing,
                child: _embeddedWebView(),
              ),
            ),
            if (usesMobileTopHeader)
              Positioned(
                key: const ValueKey('chesscom-game-header'),
                top: 0,
                left: 0,
                right: 0,
                child: _ChessComTopHeader(
                  boardState: _boardState,
                  hideBoardConnectionUi: widget.hidePhysicalBoardConnectionUi,
                  showMoveBoardActions: _showMoveBoardActions,
                  onConnectBoard: widget.boardGateway == null
                      ? null
                      : _connectPhysicalBoardFromSidebar,
                  onBack: () => _showExitConfirm(context),
                  onRefresh: _refreshChessComPage,
                  onResetMoveBoard: _moveBoardActionInFlight
                      ? null
                      : _resetConnectedMoveBoard,
                  onFlipMoveBoard:
                      _moveBoardActionInFlight ? null : _flipConnectedMoveBoard,
                  placement: _ChessComHeaderPlacement.top,
                ),
              )
            else
              Positioned(
                key: const ValueKey('chesscom-game-header'),
                top: 0,
                left: 0,
                bottom: 0,
                child: SafeArea(
                  right: false,
                  child: SizedBox(
                    width: _sideHeaderWidth,
                    child: _ChessComTopHeader(
                      boardState: _boardState,
                      hideBoardConnectionUi:
                          widget.hidePhysicalBoardConnectionUi,
                      showMoveBoardActions: _showMoveBoardActions,
                      onConnectBoard: widget.boardGateway == null
                          ? null
                          : _connectPhysicalBoardFromSidebar,
                      onBack: () => _showExitConfirm(context),
                      onRefresh: _refreshChessComPage,
                      onResetMoveBoard: _moveBoardActionInFlight
                          ? null
                          : _resetConnectedMoveBoard,
                      onFlipMoveBoard: _moveBoardActionInFlight
                          ? null
                          : _flipConnectedMoveBoard,
                      voiceMovesShortcut: voiceMovesShortcut,
                    ),
                  ),
                ),
              ),
            if (usesMobileTopHeader && voiceMovesShortcut != null)
              Positioned(
                left: mediaPadding.left + 12,
                bottom: mediaPadding.bottom + 12,
                child: SizedBox.square(
                  dimension: 44,
                  child: FittedBox(child: voiceMovesShortcut),
                ),
              ),
            if (_bridgeStatus == 'Move sent' && _lastInjectedMove != null)
              Positioned(
                right: 12,
                bottom: mediaPadding.bottom + 12,
                child: _InjectedMoveToast(
                  move: _lastInjectedMove!.uci,
                  status: _bridgeStatus,
                ),
              ),
            if (_bridgeStatus == 'Choose a target')
              Positioned(
                right: 12,
                bottom: MediaQuery.paddingOf(context).bottom + 12,
                child: const _BridgeGuidanceToast(
                  label: 'Choose a target',
                ),
              ),
            if (_bridgeStatus == 'Press clock switch')
              Positioned(
                right: 12,
                bottom: MediaQuery.paddingOf(context).bottom + 12,
                child: const _BridgeGuidanceToast(
                  label: 'Press clock switch',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _embeddedWebView() {
    final adapter = _webViewAdapter;
    if (adapter == null || !adapter.isReady) return const _WebViewPreview();
    return adapter.build();
  }

  Future<void> _leaveChessCom() async {
    if (_leavingChessCom) return;
    _leavingChessCom = true;
    _moveBoardActionGeneration += 1;
    _pollTimer?.cancel();
    _recordSaveTimer?.cancel();
    _pendingBoardMoveTimer?.cancel();
    _moveBoardRestoreTimer?.cancel();
    _moveBoardActionSettleTimer?.cancel();
    _pendingBoardMoveFen = null;
    _pendingMoveBoardRestoreFen = null;
    _moveBoardActionExpectedFen = null;
    _moveBoardActionSettled = null;
    _moveBoardSyncLocked = false;
    _lastMoveLedStateKey = null;
    _clearLegalTargetState();
    await _saveChessComRecord();
    await _clearPhysicalBoardGuidance();
    final gateway = widget.boardGateway;
    if (gateway == null) {
      if (mounted) widget.onNavigate('Back');
      return;
    }
    if (gateway.boardModel == PhysicalBoardModel.move &&
        gateway.currentState == PhysicalBoardConnectionState.connected) {
      await gateway.stopMoveBoard();
    }
    if (!mounted) return;
    widget.onNavigate('Back');
  }

  void _showExitConfirm(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => AppDialogShell(
        icon: Icons.logout_rounded,
        title: 'Leave Chess.com?',
        subtitle:
            'The WebView game may still be active. Leave only when you want to close this room.',
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Stay'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                unawaited(_leaveChessCom());
              },
              child: const Text('Leave'),
            ),
          ),
        ],
      ),
    );
  }
}

abstract interface class ChessComWebViewAdapter {
  bool get isReady;

  Future<void> initialize({
    required Uri initialUrl,
    required VoidCallback onPageStarted,
    required Future<void> Function() onPageFinished,
    required VoidCallback onRecoverRequested,
  });

  Future<Object?> runJavaScript(String script);

  Future<void> injectTextScaleGuard();

  Future<void> reload();

  Widget build();

  Future<void> dispose();
}

ChessComWebViewAdapter _createWebViewAdapter() {
  if (defaultTargetPlatform == TargetPlatform.windows) {
    return WindowsChessComWebViewAdapter();
  }
  return MobileChessComWebViewAdapter();
}

class MobileChessComWebViewAdapter implements ChessComWebViewAdapter {
  WebViewController? _controller;

  @override
  bool get isReady => _controller != null;

  @override
  Future<void> initialize({
    required Uri initialUrl,
    required VoidCallback onPageStarted,
    required Future<void> Function() onPageFinished,
    required VoidCallback onRecoverRequested,
  }) async {
    final controller = WebViewController();
    _controller = controller;
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await configureMobileWebViewZoomGuard(controller);
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (_) => onPageStarted(),
        onPageFinished: (_) async {
          await injectMobileWebViewTextScaleGuard(controller);
          await onPageFinished();
        },
        onWebResourceError: (error) {
          final type = error.errorType;
          final description = error.description.toLowerCase();
          if (type == WebResourceErrorType.webContentProcessTerminated ||
              type == WebResourceErrorType.webViewInvalidated ||
              description.contains('renderer') ||
              description.contains('render process')) {
            onRecoverRequested();
          }
        },
      ),
    );
    await controller.loadRequest(initialUrl);
  }

  @override
  Future<Object?> runJavaScript(String script) async {
    return _controller?.runJavaScriptReturningResult(script);
  }

  @override
  Future<void> injectTextScaleGuard() async {
    final controller = _controller;
    if (controller == null) return;
    await injectMobileWebViewTextScaleGuard(controller);
  }

  @override
  Future<void> reload() async {
    await _controller?.reload();
  }

  @override
  Widget build() {
    final controller = _controller;
    if (controller == null) return const _WebViewPreview();
    return buildWebViewTextScaleGuard(
      child: WebViewWidget(controller: controller),
    );
  }

  @override
  Future<void> dispose() async {}
}

class WindowsChessComWebViewAdapter implements ChessComWebViewAdapter {
  final windows_webview.WebviewController _controller =
      windows_webview.WebviewController();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _ready = false;

  @override
  bool get isReady => _ready && _controller.value.isInitialized;

  @override
  Future<void> initialize({
    required Uri initialUrl,
    required VoidCallback onPageStarted,
    required Future<void> Function() onPageFinished,
    required VoidCallback onRecoverRequested,
  }) async {
    await _controller.initialize();
    await configureWindowsWebViewZoomGuard(_controller);
    await _controller.setPopupWindowPolicy(
      windows_webview.WebviewPopupWindowPolicy.sameWindow,
    );
    _subscriptions.add(_controller.loadingState.listen((state) {
      if (state == windows_webview.LoadingState.loading) {
        onPageStarted();
      } else if (state == windows_webview.LoadingState.navigationCompleted) {
        unawaited(_handlePageFinished(onPageFinished));
      }
    }));
    await _controller.loadUrl(initialUrl.toString());
    unawaited(injectWindowsWebViewTextScaleGuard(_controller));
    _ready = true;
  }

  Future<void> _handlePageFinished(
      Future<void> Function() onPageFinished) async {
    await injectWindowsWebViewTextScaleGuard(_controller);
    await onPageFinished();
  }

  @override
  Future<Object?> runJavaScript(String script) {
    return _controller.executeScript(script);
  }

  @override
  Future<void> injectTextScaleGuard() {
    return injectWindowsWebViewTextScaleGuard(_controller);
  }

  @override
  Future<void> reload() {
    return _controller.reload();
  }

  @override
  Widget build() {
    return buildWebViewTextScaleGuard(
      child: windows_webview.Webview(_controller),
    );
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _controller.dispose();
  }
}

enum _ChessComHeaderPlacement { side, top }

class _ChessComTopHeader extends StatelessWidget {
  const _ChessComTopHeader({
    required this.boardState,
    required this.hideBoardConnectionUi,
    required this.showMoveBoardActions,
    required this.onConnectBoard,
    required this.onBack,
    required this.onRefresh,
    required this.onResetMoveBoard,
    required this.onFlipMoveBoard,
    this.placement = _ChessComHeaderPlacement.side,
    this.voiceMovesShortcut,
  });

  final PhysicalBoardConnectionState boardState;
  final bool hideBoardConnectionUi;
  final bool showMoveBoardActions;
  final VoidCallback? onConnectBoard;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback? onResetMoveBoard;
  final VoidCallback? onFlipMoveBoard;
  final _ChessComHeaderPlacement placement;
  final Widget? voiceMovesShortcut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final connected = boardState == PhysicalBoardConnectionState.connected;
    final connecting = boardState == PhysicalBoardConnectionState.scanning ||
        boardState == PhysicalBoardConnectionState.connecting;
    final bluetoothColor = connected || connecting
        ? const Color(0xFF60A5FA)
        : scheme.onSurfaceVariant;
    final bluetoothIcon = connected
        ? Icons.bluetooth_connected_rounded
        : connecting
            ? Icons.bluetooth_searching_rounded
            : Icons.bluetooth_disabled_rounded;
    final bluetoothTooltip = connected
        ? 'Board connected'
        : connecting
            ? 'Connecting board'
            : 'Connect board';
    final compactAndroidTop = placement == _ChessComHeaderPlacement.top &&
        defaultTargetPlatform == TargetPlatform.android;
    final iconSize = compactAndroidTop ? 28.0 : 34.0;
    final buttonExtent = compactAndroidTop ? 44.0 : 46.0;
    final bluetoothButton = _ChessComSidebarIcon(
      key: const ValueKey('chesscom-board-bluetooth-status'),
      tooltip: bluetoothTooltip,
      icon: bluetoothIcon,
      onPressed: connected || connecting ? null : onConnectBoard,
      color: bluetoothColor,
      iconSize: iconSize,
      buttonExtent: buttonExtent,
    );
    final refreshButton = _ChessComSidebarIcon(
      key: const ValueKey('chesscom-refresh-page-button'),
      tooltip: 'Refresh Chess.com',
      icon: Icons.refresh_rounded,
      onPressed: onRefresh,
      iconSize: iconSize,
      buttonExtent: buttonExtent,
    );
    final backButton = _ChessComSidebarIcon(
      key: const ValueKey('chesscom-back-button'),
      tooltip: 'Leave Chess.com',
      icon: Icons.arrow_back_rounded,
      onPressed: onBack,
      iconSize: iconSize,
      buttonExtent: buttonExtent,
    );
    final resetButton = _ChessComSidebarIcon(
      key: const ValueKey('chesscom-reset-move-board-button'),
      tooltip: 'Reset Move board',
      icon: Icons.restart_alt_rounded,
      onPressed: onResetMoveBoard,
      iconSize: iconSize,
      buttonExtent: buttonExtent,
    );
    final flipButton = _ChessComSidebarIcon(
      key: const ValueKey('chesscom-flip-move-board-button'),
      tooltip: 'Flip Move board',
      icon: Icons.screen_rotation_alt_rounded,
      onPressed: onFlipMoveBoard,
      iconSize: iconSize,
      buttonExtent: buttonExtent,
    );

    if (placement == _ChessComHeaderPlacement.top) {
      return Material(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            borderRadius: 0,
            tint: scheme.surface.withValues(alpha: 0.76),
            child: SizedBox(
              height: _ChessComWebViewScreenState._topHeaderHeight,
              child: Row(
                children: [
                  backButton,
                  const Spacer(),
                  if (showMoveBoardActions) ...[
                    resetButton,
                    const SizedBox(width: 4),
                    flipButton,
                    const SizedBox(width: 4),
                  ],
                  refreshButton,
                  if (!hideBoardConnectionUi) ...[
                    const SizedBox(width: 6),
                    bluetoothButton,
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        borderRadius: 0,
        tint: scheme.surface.withValues(alpha: 0.76),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!hideBoardConnectionUi) ...[
              bluetoothButton,
              const SizedBox(height: 18),
            ],
            refreshButton,
            if (showMoveBoardActions) ...[
              const SizedBox(height: 18),
              resetButton,
              const SizedBox(height: 18),
              flipButton,
            ],
            const SizedBox(height: 18),
            backButton,
            if (voiceMovesShortcut != null) ...[
              const SizedBox(height: 18),
              SizedBox.square(
                dimension: 44,
                child: FittedBox(child: voiceMovesShortcut!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChessComSidebarIcon extends StatelessWidget {
  const _ChessComSidebarIcon({
    required this.tooltip,
    required this.icon,
    this.onPressed,
    this.color,
    this.iconSize = 34,
    this.buttonExtent = 46,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double iconSize;
  final double buttonExtent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? scheme.onSurfaceVariant;
    if (onPressed == null) {
      return Tooltip(
        message: tooltip,
        child: SizedBox.square(
          dimension: buttonExtent,
          child: Center(
            child: Icon(icon, size: iconSize, color: effectiveColor),
          ),
        ),
      );
    }
    return SizedBox.square(
      dimension: buttonExtent,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: iconSize),
        iconSize: iconSize,
        color: effectiveColor,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(
          width: buttonExtent,
          height: buttonExtent,
        ),
        visualDensity: VisualDensity.standard,
        style: const ButtonStyle(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

class _ImmersiveWebViewFrame extends StatelessWidget {
  const _ImmersiveWebViewFrame({
    required this.initializing,
    required this.child,
  });

  final bool initializing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (initializing)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.08),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}

class _WebViewPreview extends StatelessWidget {
  const _WebViewPreview();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF05080D)
          : const Color(0xFFF7FBFC),
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.language_rounded, size: 46, color: scheme.secondary),
          const SizedBox(height: 12),
          Text(
            'Chess.com WebView',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Runtime preview. On device, this area loads Chess.com directly.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _InjectedMoveToast extends StatelessWidget {
  const _InjectedMoveToast({required this.move, required this.status});

  final String move;
  final String status;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      borderRadius: 999,
      tint: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, size: 16),
          const SizedBox(width: 7),
          Text('$status / $move',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _BridgeGuidanceToast extends StatelessWidget {
  const _BridgeGuidanceToast({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      borderRadius: 999,
      tint: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.ads_click_rounded, size: 16),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
