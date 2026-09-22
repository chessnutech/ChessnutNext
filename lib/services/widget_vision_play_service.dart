import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:dartchess/dartchess.dart' as dc;
import 'package:flutter/foundation.dart';

import 'android_accessibility_vision_service.dart';
import 'board_settings_service.dart';
import 'physical_board_gateway.dart';
import 'physical_board_protocol.dart';

class WidgetVisionPlayService {
  static const int _screenSyncTimeoutsBeforeRestore = 3;
  static const int _screenMoveAttemptLimit = 3;

  WidgetVisionPlayService({
    required PhysicalBoardGateway Function() boardGatewayProvider,
    BoardSettingsState Function()? boardSettingsProvider,
    AccessibilityVisionBridge? accessibilityService,
    Duration interval = const Duration(milliseconds: 500),
  })  : _boardGatewayProvider = boardGatewayProvider,
        _boardSettingsProvider = boardSettingsProvider,
        _accessibilityService =
            accessibilityService ?? const AndroidAccessibilityVisionService(),
        _interval = interval;

  final PhysicalBoardGateway Function() _boardGatewayProvider;
  final BoardSettingsState Function()? _boardSettingsProvider;
  final AccessibilityVisionBridge _accessibilityService;
  final Duration _interval;

  bool _enabled = false;
  bool _recognitionOnly = false;
  bool _boardConnected = false;
  String _languageTag = 'system';
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  Timer? _timer;
  Timer? _pendingPhysicalFenTimer;
  StreamSubscription<String>? _boardFenSub;
  PhysicalBoardGateway? _subscribedGateway;
  String? _physicalBoardFen;
  String? _pendingPhysicalBoardFen;
  String? _visionFen;
  String? _lastVisionCandidateFen;
  VisionRecognitionResult? _visionResult;
  bool _isTicking = false;
  bool _isDispatching = false;
  bool _isNewVision = false;
  bool _accessibilityRunning = false;
  int _recognitionLoopGeneration = 0;
  bool _disposed = false;
  (bool, bool, bool, String)? _notificationStatus;
  String _lastDispatchKey = '';
  String _lastGeneralGuidanceKey = '';
  String _lastMoveLedGuidanceKey = '';
  String? _latestPhysicalChangeFen;
  String? _pendingScreenSyncTargetFen;
  String? _pendingScreenSyncVisionFen;
  DateTime? _pendingScreenSyncDeadline;
  int _pendingScreenSyncTimeoutCount = 0;
  String? _pendingPhysicalRestorePhysicalFen;
  String? _pendingPhysicalRestoreVisionFen;
  DateTime? _pendingPhysicalRestoreDeadline;
  dc.Role? _promotionRole;
  _VisionScreenMoveAttempt? _screenMoveAttempt;
  String? _failedScreenMoveKey;

  void update({
    required bool enabled,
    required bool boardConnected,
    required AppLifecycleState lifecycleState,
    bool recognitionOnly = false,
    String languageTag = 'system',
  }) {
    if (_disposed) return;
    final recognitionModeChanged = _recognitionOnly != recognitionOnly;
    _enabled = enabled;
    _recognitionOnly = recognitionOnly;
    _boardConnected = boardConnected;
    _languageTag = languageTag;
    _lifecycleState = lifecycleState;
    if (recognitionModeChanged) {
      _lastDispatchKey = '';
      _clearScreenMoveAttempt();
      _failedScreenMoveKey = null;
      _clearPendingScreenSync();
    }
    if (_enabled) {
      _syncBoardSubscription();
    } else {
      unawaited(_boardFenSub?.cancel());
      _boardFenSub = null;
      _subscribedGateway = null;
      _physicalBoardFen = null;
      _pendingPhysicalBoardFen = null;
      _pendingPhysicalFenTimer?.cancel();
      _pendingPhysicalFenTimer = null;
      _latestPhysicalChangeFen = null;
      _clearPendingPhysicalRestore();
    }
    final shouldRun = _shouldRun;
    unawaited(_syncRecognitionStatus());
    if (shouldRun) {
      if (_timer == null) {
        _startRecognitionLoop();
      }
      unawaited(_processBoardChange());
    } else {
      _clearScreenMoveAttempt();
      _failedScreenMoveKey = null;
      _stopRecognitionLoop();
      _pendingPhysicalFenTimer?.cancel();
      _pendingPhysicalFenTimer = null;
      _pendingPhysicalBoardFen = null;
      _lastVisionCandidateFen = null;
      _visionResult = null;
      _visionFen = null;
      _isNewVision = false;
      _lastDispatchKey = '';
      _latestPhysicalChangeFen = null;
      _clearPendingScreenSync();
      _clearPendingPhysicalRestore();
      _accessibilityRunning = false;
      unawaited(_clearGuidance());
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _enabled = false;
    _clearScreenMoveAttempt();
    _stopRecognitionLoop();
    _pendingPhysicalFenTimer?.cancel();
    await _syncRecognitionStatus();
    await _boardFenSub?.cancel();
  }

  Future<void> _syncRecognitionStatus() async {
    final status = (
      _enabled,
      _shouldRun,
      _enabled &&
          _boardConnected &&
          _gateway.currentState == PhysicalBoardConnectionState.connected,
      _languageTag,
    );
    if (_notificationStatus == status) return;
    _notificationStatus = status;
    await _accessibilityService.setRecognitionStatus(
      enabled: status.$1,
      recognizing: status.$2,
      boardConnected: status.$3,
      languageTag: status.$4,
    );
  }

  void _startRecognitionLoop() {
    final generation = ++_recognitionLoopGeneration;
    _scheduleRecognition(Duration.zero, generation);
  }

  void _stopRecognitionLoop() {
    _recognitionLoopGeneration++;
    _timer?.cancel();
    _timer = null;
  }

  void _scheduleRecognition(Duration delay, int generation) {
    if (_disposed || generation != _recognitionLoopGeneration || !_shouldRun) {
      return;
    }
    _timer = Timer(delay, () {
      unawaited(_runRecognitionCycle(generation));
    });
  }

  Future<void> _runRecognitionCycle(int generation) async {
    if (_disposed || generation != _recognitionLoopGeneration || !_shouldRun) {
      if (generation == _recognitionLoopGeneration) {
        _timer = null;
      }
      return;
    }

    final cycleTimer = Stopwatch()..start();
    await _tick();
    cycleTimer.stop();

    if (_disposed || generation != _recognitionLoopGeneration || !_shouldRun) {
      if (generation == _recognitionLoopGeneration) {
        _timer = null;
      }
      return;
    }

    final remainingMicroseconds =
        _interval.inMicroseconds - cycleTimer.elapsedMicroseconds;
    final delay = remainingMicroseconds > 0
        ? Duration(microseconds: remainingMicroseconds)
        : Duration.zero;
    _scheduleRecognition(delay, generation);
  }

  @visibleForTesting
  Future<void> debugTickForTest() => _tick();

  bool get _shouldRun =>
      _enabled &&
      _boardConnected &&
      _lifecycleState != AppLifecycleState.resumed &&
      _gateway.currentState == PhysicalBoardConnectionState.connected;

  PhysicalBoardGateway get _gateway => _boardGatewayProvider();

  BoardSettingsState get _boardSettings =>
      _boardSettingsProvider?.call() ?? const BoardSettingsState();

  void _syncBoardSubscription() {
    final gateway = _gateway;
    if (identical(_subscribedGateway, gateway) && _boardFenSub != null) {
      return;
    }
    unawaited(_boardFenSub?.cancel());
    _clearScreenMoveAttempt();
    _failedScreenMoveKey = null;
    _subscribedGateway = gateway;
    _lastGeneralGuidanceKey = '';
    _lastMoveLedGuidanceKey = '';
    _physicalBoardFen = null;
    _pendingPhysicalBoardFen = null;
    _pendingPhysicalFenTimer?.cancel();
    _pendingPhysicalFenTimer = null;
    _latestPhysicalChangeFen = null;
    _clearPendingPhysicalRestore();
    _boardFenSub = gateway.boardFenStream.listen((fen) {
      _handlePhysicalFen(_boardOnlyFen(fen));
    });
    final latestFen = gateway.latestBoardFen;
    if (latestFen != null && latestFen.trim().isNotEmpty) {
      _physicalBoardFen = _boardOnlyFen(latestFen);
    }
    if (gateway.currentState == PhysicalBoardConnectionState.connected) {
      unawaited(gateway.enableRealtimeFen());
    }
  }

  void _handlePhysicalFen(String fen) {
    final normalizedFen = _boardOnlyFen(fen);
    if (_pendingPhysicalBoardFen == normalizedFen &&
        _pendingPhysicalFenTimer != null) {
      return;
    }
    if (_physicalBoardFen == normalizedFen &&
        _pendingPhysicalFenTimer == null) {
      return;
    }

    _clearScreenMoveAttempt();
    _failedScreenMoveKey = null;

    final delay = _boardSettings.fenDelay;
    if (delay <= Duration.zero) {
      _pendingPhysicalFenTimer?.cancel();
      _pendingPhysicalFenTimer = null;
      _pendingPhysicalBoardFen = null;
      _acceptStablePhysicalFen(normalizedFen);
      return;
    }
    _pendingPhysicalFenTimer?.cancel();
    _pendingPhysicalBoardFen = normalizedFen;
    _pendingPhysicalFenTimer = Timer(delay, () {
      _pendingPhysicalFenTimer = null;
      final pendingFen = _pendingPhysicalBoardFen;
      _pendingPhysicalBoardFen = null;
      if (pendingFen == null) return;
      _acceptStablePhysicalFen(pendingFen);
    });
  }

  void _acceptStablePhysicalFen(String fen) {
    if (_physicalBoardFen == fen) return;
    _physicalBoardFen = fen;
    _latestPhysicalChangeFen = _boardOnlyFen(fen);
    _clearPendingPhysicalRestore();
    if (_shouldRun) {
      unawaited(_processBoardChange(fromPhysicalBoard: true));
    }
  }

  Future<void> _tick() async {
    if (_isTicking || _isDispatching || !_shouldRun) return;
    _isTicking = true;
    try {
      if (!_accessibilityRunning) {
        _accessibilityRunning = await _accessibilityService
            .isAccessibilityRunning()
            .timeout(const Duration(milliseconds: 500), onTimeout: () => false);
        if (!_accessibilityRunning) return;
      }
      final json = await _accessibilityService.recognizeScreenshot();
      if (json == null || json.isEmpty) return;
      final result = VisionRecognitionResult.tryParse(json);
      if (result == null || result.fen.isEmpty) return;
      if (result.fen != _lastVisionCandidateFen) {
        _lastVisionCandidateFen = result.fen;
        return;
      }
      if (result.positions.isEmpty) return;
      if (result.fen != _visionFen) {
        final hadStableVision = _visionFen != null;
        _visionFen = result.fen;
        if (hadStableVision) {
          _isNewVision = true;
        }
      }
      _visionResult = result;
      await _processBoardChange(freshRecognition: true);
    } on AccessibilityVisionException catch (error) {
      if (error.code == 'accessibility_not_running' ||
          error.code == 'vision_service_not_running') {
        _accessibilityRunning = false;
      }
    } catch (_) {
    } finally {
      _isTicking = false;
    }
  }

  Future<void> _processBoardChange({
    bool fromPhysicalBoard = false,
    bool freshRecognition = false,
  }) async {
    if (!_shouldRun) return;
    final physicalFen = _physicalBoardFen;
    final visionFen = _visionFen;
    if (physicalFen == null || physicalFen.isEmpty || visionFen == null) return;
    final stableVisionChanged = _isNewVision;
    if (stableVisionChanged) {
      _isNewVision = false;
    }
    if (_physicalFenMatchesVision(physicalFen, visionFen)) {
      _clearScreenMoveAttempt();
      _failedScreenMoveKey = null;
      _lastDispatchKey = '';
      _latestPhysicalChangeFen = null;
      _clearPendingScreenSync();
      _clearPendingPhysicalRestore();
      await _clearGuidance();
      return;
    }
    final activeAttempt = _screenMoveAttempt;
    if (activeAttempt != null) {
      if (activeAttempt.physicalFen != physicalFen ||
          activeAttempt.visionFen != visionFen) {
        _clearScreenMoveAttempt();
      } else if (freshRecognition) {
        final result = _visionResult;
        if (result != null &&
            result.positions.length != activeAttempt.positionCount) {
          _clearScreenMoveAttempt();
        } else {
          if (result != null) {
            await _continueScreenMoveAttempt(activeAttempt, result);
          }
          return;
        }
      } else {
        return;
      }
    }
    final pendingState = _consumePendingScreenSyncState(
      visionFen: visionFen,
    );
    final canRestoreMoveBoard = _gateway.boardModel == PhysicalBoardModel.move;
    if (pendingState == _PendingScreenSyncState.synced) {
      _lastDispatchKey = '';
      _latestPhysicalChangeFen = null;
      _clearPendingPhysicalRestore();
      await _clearGuidance();
      return;
    }
    if (stableVisionChanged && canRestoreMoveBoard) {
      _failedScreenMoveKey = null;
      _clearPendingScreenSync();
      _clearPendingPhysicalRestore();
      await _guideBoardToVisionFen(visionFen, physicalFen);
      await _setMoveBoardFen(
        visionFen,
        physicalFen: physicalFen,
      );
      _latestPhysicalChangeFen = null;
      return;
    }
    if (pendingState == _PendingScreenSyncState.waiting) {
      await _guideBoardToVisionFen(visionFen, physicalFen);
      return;
    }

    var needsBoardGuidance = fromPhysicalBoard ||
        pendingState == _PendingScreenSyncState.expired ||
        pendingState == _PendingScreenSyncState.visionChanged;
    var shouldRestoreMoveBoard = canRestoreMoveBoard &&
        (pendingState == _PendingScreenSyncState.expired ||
            pendingState == _PendingScreenSyncState.visionChanged);
    final result = _visionResult;
    final pendingPhysicalRestoreState = _consumePendingPhysicalRestoreState(
      visionFen: visionFen,
      physicalFen: physicalFen,
    );
    if (result != null &&
        pendingState != _PendingScreenSyncState.expired &&
        pendingState != _PendingScreenSyncState.visionChanged) {
      final move = _speculateMove(result, physicalFen);
      if (move == null) {
        if (canRestoreMoveBoard) {
          final physicalChangePending =
              fromPhysicalBoard || _latestPhysicalChangeFen == physicalFen;
          if (stableVisionChanged) {
            shouldRestoreMoveBoard = true;
            _clearPendingPhysicalRestore();
          } else if (pendingPhysicalRestoreState ==
              _PendingPhysicalRestoreState.expired) {
            shouldRestoreMoveBoard = true;
          } else if (pendingPhysicalRestoreState ==
              _PendingPhysicalRestoreState.waiting) {
            shouldRestoreMoveBoard = false;
          } else if (physicalChangePending) {
            final startedState = _startPendingPhysicalRestore(
              visionFen: visionFen,
              physicalFen: physicalFen,
            );
            shouldRestoreMoveBoard =
                startedState == _PendingPhysicalRestoreState.expired;
          } else {
            shouldRestoreMoveBoard = true;
          }
        }
      }
      final dispatchKey = '$physicalFen+$visionFen+${result.positions.length}';
      final firstDispatchForState = dispatchKey != _lastDispatchKey;
      if (firstDispatchForState) {
        _lastDispatchKey = dispatchKey;
      }

      if (move != null) {
        needsBoardGuidance = true;
        await _guideBoardToVisionFen(visionFen, physicalFen);
        if (_recognitionOnly) return;
        if (_failedScreenMoveKey == dispatchKey) return;
        if (!firstDispatchForState) return;
        await _startScreenMoveAttempt(
          dispatchKey: dispatchKey,
          move: move,
          result: result,
          visionFen: visionFen,
          physicalFen: physicalFen,
        );
        return;
      }
      needsBoardGuidance = true;
    }

    if (!needsBoardGuidance) return;
    await _guideBoardToVisionFen(visionFen, physicalFen);
    if (shouldRestoreMoveBoard && canRestoreMoveBoard) {
      await _setMoveBoardFen(
        visionFen,
        physicalFen: physicalFen,
      );
      _latestPhysicalChangeFen = null;
      _clearPendingPhysicalRestore();
    }
  }

  Future<void> _startScreenMoveAttempt({
    required String dispatchKey,
    required VisionScreenMove move,
    required VisionRecognitionResult result,
    required String visionFen,
    required String physicalFen,
  }) async {
    final attempt = _VisionScreenMoveAttempt(
      dispatchKey: dispatchKey,
      move: move,
      visionFen: visionFen,
      physicalFen: physicalFen,
      positionCount: result.positions.length,
    );
    _screenMoveAttempt = attempt;
    _failedScreenMoveKey = null;
    _clearPendingScreenSync();
    _clearPendingPhysicalRestore();
    await _dispatchScreenMoveGesture(attempt, result);
  }

  Future<void> _continueScreenMoveAttempt(
    _VisionScreenMoveAttempt attempt,
    VisionRecognitionResult result,
  ) async {
    if (!identical(_screenMoveAttempt, attempt) ||
        DateTime.now().isBefore(attempt.nextActionAt)) {
      return;
    }

    if (attempt.kind == VisionScreenMoveKind.castling &&
        attempt.castlingPhase == _CastlingGesturePhase.kingToRook) {
      attempt.castlingPhase = _CastlingGesturePhase.kingToDestination;
      await _dispatchScreenMoveGesture(attempt, result);
      return;
    }

    if (attempt.attemptCount >= _screenMoveAttemptLimit) {
      await _finishScreenMoveFailure(attempt);
      return;
    }

    attempt.attemptCount++;
    attempt.castlingPhase = _CastlingGesturePhase.kingToRook;
    await _dispatchScreenMoveGesture(attempt, result);
  }

  Future<void> _dispatchScreenMoveGesture(
    _VisionScreenMoveAttempt attempt,
    VisionRecognitionResult result,
  ) async {
    final fromIndex = attempt.move.fromIndex;
    final toIndex = switch (attempt.kind) {
      VisionScreenMoveKind.normal => attempt.move.toIndex,
      VisionScreenMoveKind.castling =>
        attempt.castlingPhase == _CastlingGesturePhase.kingToRook
            ? attempt.move.toIndex
            : attempt.move.castlingKingToIndex!,
    };
    if (fromIndex < 0 ||
        fromIndex >= result.positions.length ||
        toIndex < 0 ||
        toIndex >= result.positions.length) {
      await _finishScreenMoveFailure(attempt);
      return;
    }

    var dispatched = false;
    try {
      _isDispatching = true;
      dispatched = await _accessibilityService.dispatchMoveGesture(
        from: result.positions[fromIndex].rect,
        to: fromIndex == toIndex ? null : result.positions[toIndex].rect,
      );
    } catch (_) {
      dispatched = false;
    } finally {
      _isDispatching = false;
    }
    if (!identical(_screenMoveAttempt, attempt)) return;
    final retryDelay =
        dispatched ? _boardSettings.moveRestoreDelay : Duration.zero;
    attempt.nextActionAt = DateTime.now().add(retryDelay);
  }

  Future<void> _finishScreenMoveFailure(
    _VisionScreenMoveAttempt attempt,
  ) async {
    if (!identical(_screenMoveAttempt, attempt)) return;
    _screenMoveAttempt = null;
    _failedScreenMoveKey = attempt.dispatchKey;
    _lastDispatchKey = attempt.dispatchKey;
    await _guideBoardToVisionFen(attempt.visionFen, attempt.physicalFen);
    if (_gateway.boardModel == PhysicalBoardModel.move) {
      await _setMoveBoardFen(
        attempt.visionFen,
        physicalFen: attempt.physicalFen,
      );
      _latestPhysicalChangeFen = null;
      _clearPendingPhysicalRestore();
    }
  }

  void _clearScreenMoveAttempt() {
    _screenMoveAttempt = null;
  }

  _PendingScreenSyncState _consumePendingScreenSyncState({
    required String visionFen,
  }) {
    final targetFen = _pendingScreenSyncTargetFen;
    if (targetFen == null) return _PendingScreenSyncState.none;

    final normalizedVisionFen = _boardOnlyFen(visionFen);
    final sourceFen = _pendingScreenSyncVisionFen;
    if (normalizedVisionFen == targetFen) {
      _clearPendingScreenSync();
      return _PendingScreenSyncState.synced;
    }

    if (sourceFen != null && normalizedVisionFen != sourceFen) {
      _clearPendingScreenSync();
      return _PendingScreenSyncState.visionChanged;
    }

    final deadline = _pendingScreenSyncDeadline;
    if (deadline == null) return _PendingScreenSyncState.none;
    final now = DateTime.now();
    if (now.isBefore(deadline)) {
      return _PendingScreenSyncState.waiting;
    }

    _pendingScreenSyncTimeoutCount++;
    if (_pendingScreenSyncTimeoutCount < _screenSyncTimeoutsBeforeRestore) {
      _pendingScreenSyncDeadline = now.add(_boardSettings.moveRestoreDelay);
      return _PendingScreenSyncState.waiting;
    }

    _clearPendingScreenSync();
    return _PendingScreenSyncState.expired;
  }

  void _clearPendingScreenSync() {
    _pendingScreenSyncTargetFen = null;
    _pendingScreenSyncVisionFen = null;
    _pendingScreenSyncDeadline = null;
    _pendingScreenSyncTimeoutCount = 0;
  }

  _PendingPhysicalRestoreState _consumePendingPhysicalRestoreState({
    required String visionFen,
    required String physicalFen,
  }) {
    final pendingPhysicalFen = _pendingPhysicalRestorePhysicalFen;
    final pendingVisionFen = _pendingPhysicalRestoreVisionFen;
    final deadline = _pendingPhysicalRestoreDeadline;
    if (pendingPhysicalFen == null ||
        pendingVisionFen == null ||
        deadline == null) {
      return _PendingPhysicalRestoreState.none;
    }

    final normalizedPhysicalFen = _boardOnlyFen(physicalFen);
    final normalizedVisionFen = _boardOnlyFen(visionFen);
    if (pendingPhysicalFen != normalizedPhysicalFen ||
        pendingVisionFen != normalizedVisionFen) {
      _clearPendingPhysicalRestore();
      return _PendingPhysicalRestoreState.none;
    }

    final now = DateTime.now();
    if (now.isBefore(deadline)) {
      return _PendingPhysicalRestoreState.waiting;
    }

    _clearPendingPhysicalRestore();
    return _PendingPhysicalRestoreState.expired;
  }

  _PendingPhysicalRestoreState _startPendingPhysicalRestore({
    required String visionFen,
    required String physicalFen,
  }) {
    final timeout = _boardSettings.moveRestoreDelay;
    final normalizedPhysicalFen = _boardOnlyFen(physicalFen);
    final normalizedVisionFen = _boardOnlyFen(visionFen);
    if (timeout <= Duration.zero) {
      return _PendingPhysicalRestoreState.expired;
    }
    _pendingPhysicalRestorePhysicalFen = normalizedPhysicalFen;
    _pendingPhysicalRestoreVisionFen = normalizedVisionFen;
    _pendingPhysicalRestoreDeadline = DateTime.now().add(timeout);
    return _PendingPhysicalRestoreState.waiting;
  }

  void _clearPendingPhysicalRestore() {
    _pendingPhysicalRestorePhysicalFen = null;
    _pendingPhysicalRestoreVisionFen = null;
    _pendingPhysicalRestoreDeadline = null;
  }

  VisionScreenMove? _speculateMove(
    VisionRecognitionResult result,
    String physicalFen,
  ) {
    if (_boardOnlyFen(physicalFen) == _emptyBoardFen) return null;
    final visionFen = _boardOnlyFen(result.fen);

    if (result.positions.length == 64) {
      final possiblePositions = <_VisionPositionCandidate>[];
      for (final candidateFen in [visionFen, _reverseBoardFen(visionFen)]) {
        for (final turn in ['w', 'b']) {
          final position = _tryLoadPosition('$candidateFen $turn KQkq - 0 1');
          if (position != null) {
            possiblePositions.add(
              _VisionPositionCandidate(
                position: position,
                boardFenWasNotReversed: visionFen == position.board.fen,
              ),
            );
          }
        }
      }

      for (final candidate in possiblePositions) {
        final physicalCandidateFen =
            _shouldReversePhysicalFen(physicalFen, candidate.position.board.fen)
                ? _reverseBoardFen(physicalFen)
                : physicalFen;
        final diffCount = _differentSquares(
                candidate.position.board.fen, physicalCandidateFen)
            .length;
        if (diffCount <= 1 || diffCount >= 5) continue;
        final move = _normalMoveFromFen(
          candidate.position.fen,
          physicalCandidateFen,
        );
        if (move == null) continue;
        final targetFen = candidate.boardFenWasNotReversed
            ? physicalCandidateFen
            : _reverseBoardFen(physicalCandidateFen);
        if (move.promotion != null) {
          _promotionRole = move.promotion;
        }
        final indices = _visionIndicesForMove(
          move,
          boardFenWasNotReversed: candidate.boardFenWasNotReversed,
        );
        int? castlingKingToIndex;
        final movingPiece = candidate.position.board.pieceAt(move.from);
        final destinationPiece = candidate.position.board.pieceAt(move.to);
        if (movingPiece?.role == dc.Role.king &&
            destinationPiece?.role == dc.Role.rook &&
            destinationPiece?.color == movingPiece?.color) {
          final kingTo = candidate.position
              .playUnchecked(move)
              .board
              .kingOf(movingPiece!.color);
          if (kingTo != null && kingTo != move.from && kingTo != move.to) {
            castlingKingToIndex = _visionIndicesForMove(
              dc.NormalMove(from: move.from, to: kingTo),
              boardFenWasNotReversed: candidate.boardFenWasNotReversed,
            ).$2;
          }
        }
        return VisionScreenMove(
          fromIndex: indices.$1,
          toIndex: indices.$2,
          uci: move.uci,
          targetFen: targetFen,
          kind: castlingKingToIndex == null
              ? VisionScreenMoveKind.normal
              : VisionScreenMoveKind.castling,
          castlingKingToIndex: castlingKingToIndex,
        );
      }

      for (final candidate in possiblePositions) {
        final move = _speculateEnPassantMove(candidate.position, physicalFen);
        if (move == null) continue;
        final physicalCandidateFen =
            _shouldReversePhysicalFen(physicalFen, candidate.position.board.fen)
                ? _reverseBoardFen(physicalFen)
                : physicalFen;
        final targetFen = candidate.boardFenWasNotReversed
            ? physicalCandidateFen
            : _reverseBoardFen(physicalCandidateFen);
        final indices = _visionIndicesForMove(
          move,
          boardFenWasNotReversed: candidate.boardFenWasNotReversed,
        );
        return VisionScreenMove(
          fromIndex: indices.$1,
          toIndex: indices.$2,
          uci: move.uci,
          targetFen: targetFen,
        );
      }
    }

    if (result.positions.length == 4 && _promotionRole != null) {
      final role = _promotionRole!.letter;
      for (final entry in result.positions.asMap().entries) {
        if (entry.value.label.toLowerCase().contains(role)) {
          return VisionScreenMove(
            fromIndex: entry.key,
            toIndex: entry.key,
            uci: '',
            targetFen: visionFen,
          );
        }
      }
    }
    return null;
  }

  Future<bool> _guideBoardToVisionFen(
    String visionFen,
    String physicalFen,
  ) async {
    if (!_boardSettings.piecePositionLed) return false;
    final gateway = _gateway;
    if (gateway.currentState != PhysicalBoardConnectionState.connected) {
      return false;
    }
    final reversePhysical = _shouldReversePhysicalFen(physicalFen, visionFen);
    final normalizedPhysicalFen =
        reversePhysical ? _reverseBoardFen(physicalFen) : physicalFen;
    final visionSquares = _differentSquares(visionFen, normalizedPhysicalFen);
    final physicalSquares =
        _physicalLedSquaresForVisionSquares(visionSquares, reversePhysical);
    if (gateway.boardModel == PhysicalBoardModel.move) {
      if (visionSquares.isEmpty) {
        if (_lastMoveLedGuidanceKey == 'clear') return false;
        _lastMoveLedGuidanceKey = 'clear';
        await gateway.clearMoveLeds();
      } else {
        final guidanceKey = _generalGuidanceKey(physicalSquares);
        if (guidanceKey == _lastMoveLedGuidanceKey) return false;
        _lastMoveLedGuidanceKey = guidanceKey;
        await gateway.setMoveLedSquares({
          for (final square in physicalSquares)
            square: ChessnutMoveLedColor.red,
        });
      }
      return false;
    }
    if (visionSquares.isEmpty) {
      if (_lastGeneralGuidanceKey == 'clear') return false;
      _lastGeneralGuidanceKey = 'clear';
      await gateway.clearGeneralLeds();
    } else {
      final guidanceKey = _generalGuidanceKey(physicalSquares);
      if (guidanceKey == _lastGeneralGuidanceKey) return false;
      _lastGeneralGuidanceKey = guidanceKey;
      await gateway.setGeneralLedSquares(physicalSquares);
    }
    return false;
  }

  Future<void> _clearGuidance() async {
    final gateway = _gateway;
    if (gateway.currentState != PhysicalBoardConnectionState.connected) {
      return;
    }
    if (gateway.boardModel == PhysicalBoardModel.move) {
      if (_lastMoveLedGuidanceKey == 'clear') return;
      _lastMoveLedGuidanceKey = 'clear';
      await gateway.clearMoveLeds();
    } else {
      if (_lastGeneralGuidanceKey == 'clear') return;
      _lastGeneralGuidanceKey = 'clear';
      await gateway.clearGeneralLeds();
    }
  }

  Future<bool> _setMoveBoardFen(
    String fen, {
    String? physicalFen,
  }) async {
    final gateway = _gateway;
    if (gateway.boardModel != PhysicalBoardModel.move) return false;
    if (gateway.currentState != PhysicalBoardConnectionState.connected) {
      return false;
    }
    try {
      dc.Setup.parseFen(_fullFen(fen));
    } catch (_) {
      return false;
    }
    final reverse = physicalFen == null
        ? false
        : _shouldReversePhysicalFen(physicalFen, fen);
    return gateway.setMoveBoardFen(
      fen,
      strictMode: true,
      isReverse: reverse,
    );
  }
}

class VisionRecognitionResult {
  const VisionRecognitionResult({
    required this.fen,
    required this.positions,
  });

  final String fen;
  final List<VisionBoardPosition> positions;

  static VisionRecognitionResult? tryParse(String source) {
    try {
      final value = jsonDecode(source);
      if (value is! Map<String, dynamic>) return null;
      final rawFen = value['fen'];
      final rawPositions = value['position'];
      if (rawFen is! String || rawPositions is! List) return null;
      final positions = rawPositions
          .whereType<Map>()
          .map((entry) => VisionBoardPosition.tryParse(entry))
          .whereType<VisionBoardPosition>()
          .toList(growable: false);
      return VisionRecognitionResult(
        fen: _boardOnlyFen(rawFen),
        positions: positions,
      );
    } catch (_) {
      return null;
    }
  }
}

class VisionBoardPosition {
  const VisionBoardPosition({
    required this.rect,
    required this.label,
    required this.probability,
  });

  final Rect rect;
  final String label;
  final double probability;

  static VisionBoardPosition? tryParse(Map<dynamic, dynamic> json) {
    final x = _number(json['x']);
    final y = _number(json['y']);
    final w = _number(json['w']);
    final h = _number(json['h']);
    if (x == null || y == null || w == null || h == null || w <= 0 || h <= 0) {
      return null;
    }
    return VisionBoardPosition(
      rect: Rect.fromLTWH(x, y, w, h),
      label: json['label']?.toString() ?? '',
      probability: _number(json['prob']) ?? 0,
    );
  }
}

class VisionScreenMove {
  const VisionScreenMove({
    required this.fromIndex,
    required this.toIndex,
    required this.uci,
    required this.targetFen,
    this.kind = VisionScreenMoveKind.normal,
    this.castlingKingToIndex,
  });

  final int fromIndex;
  final int toIndex;
  final String uci;
  final String targetFen;
  final VisionScreenMoveKind kind;
  final int? castlingKingToIndex;
}

enum VisionScreenMoveKind {
  normal,
  castling,
}

enum _CastlingGesturePhase {
  kingToRook,
  kingToDestination,
}

class _VisionScreenMoveAttempt {
  _VisionScreenMoveAttempt({
    required this.dispatchKey,
    required this.move,
    required this.visionFen,
    required this.physicalFen,
    required this.positionCount,
  }) : kind = move.kind;

  final String dispatchKey;
  final VisionScreenMove move;
  final VisionScreenMoveKind kind;
  final String visionFen;
  final String physicalFen;
  final int positionCount;
  int attemptCount = 1;
  _CastlingGesturePhase castlingPhase = _CastlingGesturePhase.kingToRook;
  DateTime nextActionAt = DateTime.fromMillisecondsSinceEpoch(0);
}

enum _PendingScreenSyncState {
  none,
  waiting,
  synced,
  expired,
  visionChanged,
}

enum _PendingPhysicalRestoreState {
  none,
  waiting,
  expired,
}

class _VisionPositionCandidate {
  const _VisionPositionCandidate({
    required this.position,
    required this.boardFenWasNotReversed,
  });

  final dc.Position position;
  final bool boardFenWasNotReversed;
}

dc.Position? _tryLoadPosition(String fen) {
  try {
    final position = dc.Chess.fromSetup(dc.Setup.parseFen(fen));
    position.validate(ignoreImpossibleCheck: false);
    return position;
  } catch (_) {
    return null;
  }
}

dc.NormalMove? _normalMoveFromFen(String fromFen, String toBoardFen) {
  try {
    final position = dc.Chess.fromSetup(dc.Setup.parseFen(_fullFen(fromFen)));
    for (final move in _legalNormalMoves(position)) {
      final next = position.playUnchecked(move);
      if (next.board.fen.contains(_boardOnlyFen(toBoardFen))) {
        return move;
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}

dc.NormalMove? _speculateEnPassantMove(
  dc.Position position,
  String nextFen,
) {
  try {
    final nextBoard = dc.Board.parseFen(_boardOnlyFen(nextFen));
    final removed = <dc.Square>[];
    final added = <dc.Square>[];

    for (final square in dc.Square.values) {
      final fromPiece = position.board.pieceAt(square);
      final toPiece = nextBoard.pieceAt(square);
      if (fromPiece == toPiece) continue;
      if (fromPiece != null && toPiece == null) {
        removed.add(square);
      } else if (fromPiece == null && toPiece != null) {
        added.add(square);
      } else {
        return null;
      }
    }

    if (removed.length != 2 || added.length != 1) return null;
    final to = added.single;
    if (position.turn == dc.Side.white && to.rank != dc.Rank.sixth) {
      return null;
    }
    if (position.turn == dc.Side.black && to.rank != dc.Rank.third) {
      return null;
    }

    final toPiece = nextBoard.pieceAt(to);
    if (toPiece == null ||
        toPiece.role != dc.Role.pawn ||
        toPiece.color != position.turn) {
      return null;
    }

    final captured = dc.Square(to + (position.turn == dc.Side.white ? -8 : 8));
    final capturedPiece = position.board.pieceAt(captured);
    if (!removed.contains(captured) ||
        capturedPiece == null ||
        capturedPiece.role != dc.Role.pawn ||
        capturedPiece.color != position.turn.opposite) {
      return null;
    }

    dc.Square? from;
    for (final square in removed) {
      if (square == captured) continue;
      final piece = position.board.pieceAt(square);
      if (piece == null ||
          piece.role != dc.Role.pawn ||
          piece.color != position.turn) {
        continue;
      }
      if (position.turn == dc.Side.white && square.rank != dc.Rank.fifth) {
        continue;
      }
      if (position.turn == dc.Side.black && square.rank != dc.Rank.fourth) {
        continue;
      }
      final delta = to - square;
      final legalDelta = position.turn == dc.Side.white
          ? delta == 7 || delta == 9
          : delta == -7 || delta == -9;
      if (legalDelta) {
        from = square;
        break;
      }
    }
    if (from == null || from.rank != captured.rank) return null;

    final move = dc.NormalMove(from: from, to: to);
    final epPosition = position.copyWith(epSquare: to);
    if (!epPosition.isLegal(move)) return null;
    if (epPosition.playUnchecked(move).board.fen != nextBoard.fen) {
      return null;
    }
    return move;
  } catch (_) {
    return null;
  }
}

List<dc.NormalMove> _legalNormalMoves(dc.Position position) {
  final moves = <dc.NormalMove>[];
  for (final entry in dc.makeLegalMoves(position).entries) {
    final from = entry.key;
    for (final to in entry.value) {
      final piece = position.board.pieceAt(from);
      if (piece?.role == dc.Role.pawn &&
          (to.rank == dc.Rank.first || to.rank == dc.Rank.eighth)) {
        for (final role in const [
          dc.Role.queen,
          dc.Role.rook,
          dc.Role.bishop,
          dc.Role.knight,
        ]) {
          final move = dc.NormalMove(from: from, to: to, promotion: role);
          if (position.isLegal(move)) moves.add(move);
        }
      } else {
        final normalized = position.normalizeMove(dc.NormalMove(
          from: from,
          to: to,
        ));
        if (normalized is dc.NormalMove && position.isLegal(normalized)) {
          moves.add(normalized);
        }
      }
    }
  }
  return moves;
}

(int, int) _visionIndicesForMove(
  dc.NormalMove move, {
  required bool boardFenWasNotReversed,
}) {
  if (boardFenWasNotReversed) {
    return (_visionIndexForSquare(move.from), _visionIndexForSquare(move.to));
  }
  return (
    _visionIndexForSquare(dc.Square(63 - move.from.value)),
    _visionIndexForSquare(dc.Square(63 - move.to.value)),
  );
}

int _visionIndexForSquare(dc.Square square) {
  return (7 - square.rank.value) * 8 + square.file.value;
}

bool _shouldReversePhysicalFen(String physicalFen, String visionFen) {
  return _differentSquares(physicalFen, visionFen).length >
      _differentSquares(_reverseBoardFen(physicalFen), visionFen).length;
}

bool _physicalFenMatchesVision(String physicalFen, String visionFen) {
  final normalizedPhysicalFen = _boardOnlyFen(physicalFen);
  final normalizedVisionFen = _boardOnlyFen(visionFen);
  return normalizedPhysicalFen == normalizedVisionFen ||
      _reverseBoardFen(normalizedPhysicalFen) == normalizedVisionFen;
}

Set<String> _physicalLedSquaresForVisionSquares(
  Set<String> visionSquares,
  bool reversePhysical,
) {
  if (!reversePhysical) return visionSquares;
  final physicalSquares = <String>{};
  for (final squareName in visionSquares) {
    dc.Square? square;
    for (final candidate in dc.Square.values) {
      if (candidate.name == squareName) {
        square = candidate;
        break;
      }
    }
    if (square == null) continue;
    physicalSquares.add(dc.Square(63 - square.value).name);
  }
  return physicalSquares;
}

String _generalGuidanceKey(Set<String> squares) {
  final sorted = squares.toList()..sort();
  return sorted.join(',');
}

Set<String> _differentSquares(String from, String to) {
  final fromBoard = _expandBoardFen(_boardOnlyFen(from));
  final toBoard = _expandBoardFen(_boardOnlyFen(to));
  if (fromBoard == null || toBoard == null) return const {};
  final squares = <String>{};
  for (final square in dc.Square.values) {
    final index = _boardFenIndexForSquare(square);
    if (fromBoard[index] != toBoard[index]) {
      squares.add(square.name);
    }
  }
  return squares;
}

int _boardFenIndexForSquare(dc.Square square) {
  return (7 - square.rank.value) * 8 + square.file.value;
}

List<String>? _expandBoardFen(String fen) {
  final boardOnly = _boardOnlyFen(fen);
  final result = <String>[];
  for (final char in boardOnly.split('')) {
    if (char == '/') continue;
    final digit = int.tryParse(char);
    if (digit != null) {
      result.addAll(List<String>.filled(digit, ''));
    } else {
      result.add(char);
    }
  }
  return result.length == 64 ? result : null;
}

String _reverseBoardFen(String fen) {
  return _boardOnlyFen(fen).split('').reversed.join();
}

String _boardOnlyFen(String fen) => fen.trim().split(RegExp(r'\s+')).first;

String _fullFen(String fen) {
  final trimmed = fen.trim();
  if (trimmed.split(RegExp(r'\s+')).length >= 4) return trimmed;
  return '${_boardOnlyFen(trimmed)} w KQkq - 0 1';
}

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

const _emptyBoardFen = '8/8/8/8/8/8/8/8';
