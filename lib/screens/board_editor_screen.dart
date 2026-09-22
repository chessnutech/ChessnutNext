import 'dart:async';

import 'package:dartchess/dartchess.dart' as dc;

import '../l10n/localized_material.dart';

import '../models/app_models.dart';
import '../services/board_editor_led_feedback.dart';
import '../services/board_settings_service.dart';
import '../services/board_vision_service.dart';
import '../services/physical_board_gateway.dart';
import '../services/physical_board_orientation.dart';
import '../widgets/app_chrome.dart';
import '../widgets/board_editor_en_passant.dart';
import '../widgets/chess_board.dart';

class BoardEditorScreen extends StatefulWidget {
  const BoardEditorScreen({
    required this.onNavigate,
    this.boardSettings = const BoardSettingsState(),
    this.boardGateway,
    this.imagePicker,
    this.fenRecognizer,
    this.showBoardCoordinates = false,
    this.isChessnutClockDevice = false,
    this.hidePhysicalBoardConnectionUi = false,
    this.onFenChanged,
    this.onStartBotFromFen,
    this.onAnalyzeFen,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final BoardSettingsState boardSettings;
  final PhysicalBoardGateway? boardGateway;
  final BoardVisionImagePicker? imagePicker;
  final BoardVisionFenRecognizer? fenRecognizer;
  final bool showBoardCoordinates;
  final bool isChessnutClockDevice;
  final bool hidePhysicalBoardConnectionUi;
  final ValueChanged<String>? onFenChanged;
  final ValueChanged<String>? onStartBotFromFen;
  final ValueChanged<String>? onAnalyzeFen;

  @override
  State<BoardEditorScreen> createState() => _BoardEditorScreenState();
}

class _BoardEditorScreenState extends State<BoardEditorScreen> {
  int mode = 0;
  bool physicalPositionRotated = false;
  bool whiteKingSide = true;
  bool whiteQueenSide = true;
  bool blackKingSide = true;
  bool blackQueenSide = true;
  bool whiteToMove = true;
  String? enPassantSquare;
  String boardFen = standardStartFen;
  String? physicalBoardFen;
  String? targetBoardFen;
  bool visionBusy = false;
  double? _lastUnobscuredHeight;
  String? visionMessage;
  BoardVisionFenResult? visionResult;
  List<BoardPiece>? physicalBoardPieces;
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
    _fenController = TextEditingController(text: boardFen);
    _imagePicker = widget.imagePicker ?? PlatformBoardVisionImagePicker();
    _fenRecognizer = widget.fenRecognizer ?? PlatformBoardVisionFenRecognizer();
    _boardFenStabilityBuffer = BoardFenStabilityBuffer(
      onStableFen: _applyPhysicalBoardFen,
    );
    _startPhysicalBoardSync();
  }

  @override
  void didUpdateWidget(covariant BoardEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _boardOrientation.updateSettings(widget.boardSettings);
    if (oldWidget.boardGateway != widget.boardGateway) {
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

  void _applyPhysicalBoardFen(String fen) {
    if (!mounted) return;
    final physicalBoardOnly = fen.trim().split(RegExp(r'\s+')).first;
    if (_expandedBoard(physicalBoardOnly) == null) return;
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
    });
    _rememberFenForBot(nextFen);
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

  void _selectEnPassantSquare(String? square) {
    final sourceFen = mode == 0 ? boardFen : _fenController.text.trim();
    final fullFen = boardEditorFenWithEnPassant(
      _fullFenFromFen(sourceFen),
      square,
    );
    setState(() {
      enPassantSquare = boardEditorEnPassantSquareFromFen(fullFen);
      boardFen = fullFen;
      _fenController.text = fullFen;
    });
    _rememberFenForBot(fullFen);
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
    return ResponsivePage(
      children: (context, spec) {
        final compactLandscape = spec.compactLandscape;
        final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
        if (keyboardInset <= 0 && spec.height.isFinite) {
          _lastUnobscuredHeight = spec.height;
        }
        final stableHeight = keyboardInset > 0
            ? (_lastUnobscuredHeight ?? spec.height)
            : spec.height;
        final layoutSpec = ResponsiveSpec(spec.width, height: stableHeight);
        final landscapeMinHeight =
            stableHeight.isFinite && stableHeight < 386 ? stableHeight : 386.0;
        final modeSwitcher = GlassPanel(
          padding: const EdgeInsets.all(6),
          borderRadius: 16,
          child: Row(
            children: [
              Expanded(
                child: _EditorModeButton(
                  label: 'Board to app',
                  icon: Icons.sync_rounded,
                  selected: mode == 0,
                  onTap: _selectBoardToAppMode,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _EditorModeButton(
                  label: 'FEN to board',
                  icon: Icons.lightbulb_outline_rounded,
                  selected: mode == 1,
                  onTap: _selectFenToBoardMode,
                ),
              ),
            ],
          ),
        );
        final boardStatus = RepaintBoundary(
          key: const ValueKey('board-editor-status-section'),
          child: widget.hidePhysicalBoardConnectionUi
              ? const SizedBox.shrink()
              : mode == 0
                  ? const _SyncStatus()
                  : const _FenStatus(),
        );
        final boardPreview = ResponsiveBoardFrame(
          maxSize: compactLandscape ? 436 : (spec.canSplit ? 520 : 292),
          padding: EdgeInsets.all(compactLandscape ? 2 : 8),
          builder: _buildBoardPreview,
        );
        final boardSection = RepaintBoundary(
          key: const ValueKey('board-editor-board-section'),
          child: compactLandscape
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    boardPreview,
                    if (!widget.hidePhysicalBoardConnectionUi)
                      const SizedBox(width: 8),
                    if (!widget.hidePhysicalBoardConnectionUi)
                      BoardEditorBoardTools(
                        statusKey:
                            const ValueKey('board-editor-board-status-button'),
                        connected: widget.boardGateway?.currentState ==
                            PhysicalBoardConnectionState.connected,
                        onStatusTap: () => _showBoardStatusDialog(context),
                      ),
                  ],
                )
              : boardPreview,
        );
        final controlsPane = _BoardEditorControlsPane(
          modeSwitcher: modeSwitcher,
          status: boardStatus,
          editorControls: SectionColumn(
            spacing: compactLandscape ? 6 : 12,
            children: [
              if (mode == 1)
                _FenPanel(
                  controller: _fenController,
                  onChanged: _applyFenInput,
                  compact: compactLandscape,
                ),
              _BoardToAppPanel(
                whiteKingSide: whiteKingSide,
                whiteQueenSide: whiteQueenSide,
                blackKingSide: blackKingSide,
                blackQueenSide: blackQueenSide,
                whiteToMove: whiteToMove,
                onWhiteKingSideChanged: (value) => setState(() {
                  whiteKingSide = value;
                  boardFen = _replaceFenMetadata(boardFen);
                }),
                onWhiteQueenSideChanged: (value) => setState(() {
                  whiteQueenSide = value;
                  boardFen = _replaceFenMetadata(boardFen);
                }),
                onBlackKingSideChanged: (value) => setState(() {
                  blackKingSide = value;
                  boardFen = _replaceFenMetadata(boardFen);
                }),
                onBlackQueenSideChanged: (value) => setState(() {
                  blackQueenSide = value;
                  boardFen = _replaceFenMetadata(boardFen);
                }),
                onSideChanged: (value) => setState(() {
                  whiteToMove = value;
                  boardFen = _replaceFenMetadata(boardFen);
                }),
                compact: compactLandscape,
              ),
              BoardEditorEnPassantControl(
                fieldKey: const ValueKey('board-editor-en-passant-field'),
                availableSquares: legalBoardEditorEnPassantSquares(
                  mode == 0 ? boardFen : _fenController.text,
                ),
                selectedSquare: enPassantSquare,
                onChanged: _selectEnPassantSquare,
                compact: compactLandscape,
              ),
            ],
          ),
          vision: mode == 1 &&
                  _imagePicker
                      .availability(
                        isChessnutClock: widget.isChessnutClockDevice,
                      )
                      .any
              ? _VisionImportPanel(
                  busy: visionBusy,
                  result: visionResult,
                  message: visionMessage,
                  availability: _imagePicker.availability(
                    isChessnutClock: widget.isChessnutClockDevice,
                  ),
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
                  compact: compactLandscape,
                )
              : const SizedBox.shrink(),
          primaryAction: mode == 1
              ? PrimaryButton(
                  label: 'Send FEN to board',
                  icon: Icons.lightbulb_outline_rounded,
                  onPressed: () => _sendFenToBoard(context),
                )
              : PrimaryButton(
                  label: 'Analyze this position',
                  icon: Icons.analytics_rounded,
                  onPressed: () => _analyzeCurrentFen(context),
                ),
          startBotAction: PrimaryButton(
            key: const ValueKey('board-editor-start-bot-button'),
            label: compactLandscape
                ? 'Start bot game'
                : 'Start bot game from this position',
            icon: Icons.smart_toy_rounded,
            onPressed: () => _startBotFromCurrentFen(context),
          ),
          compact: compactLandscape,
          showModeAndStatus: compactLandscape,
        );

        return [
          ScreenHeader(
            title: 'Live position',
            subtitle: 'Board editor',
            leading: IconButton.filledTonal(
              onPressed: () => widget.onNavigate('Back'),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            trailing: Wrap(
              spacing: 8,
              children: [
                IconButton.filledTonal(
                  onPressed: _rotatePieces,
                  icon: const Icon(Icons.swap_vert_rounded),
                  tooltip: 'Flip board',
                ),
              ],
            ),
          ),
          SizedBox(height: spec.gutter),
          if (compactLandscape)
            _BoardEditorLandscapeLayout(
              height: layoutSpec.heightAfterHeader(min: landscapeMinHeight),
              spacing: spec.gutter,
              boardPreview: boardSection,
              controlsPane: controlsPane,
            )
          else
            ResponsiveSplit(
              breakpoint: 900,
              spacing: spec.gutter,
              leadingFlex: 6,
              trailingFlex: 5,
              leading: SectionColumn(
                spacing: 12,
                children: [
                  modeSwitcher,
                  boardStatus,
                  boardSection,
                ],
              ),
              trailing: controlsPane,
            ),
        ];
      },
    );
  }

  Widget _buildBoardPreview(double size) {
    final pieces = physicalBoardPieces;
    if (pieces != null) {
      return ChessBoard(
        key: ValueKey('board-editor-physical-${size.round()}'),
        size: size,
        pieces: pieces,
        showCoordinates: widget.showBoardCoordinates,
      );
    }
    return InteractiveChessBoard(
      key: ValueKey('board-editor-interactive-${size.round()}'),
      size: size,
      initialFen: boardFen,
      showCoordinates: widget.showBoardCoordinates,
    );
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
    _rememberFenForBot(rotatedFen);
  }

  Future<void> _recognizeFromSource(BoardVisionImageSource source) async {
    setState(() {
      visionBusy = true;
      visionMessage = 'Recognizing board image...';
      visionResult = null;
    });
    try {
      final image = await _imagePicker.pick(source);
      if (!mounted) return;
      if (image == null) {
        setState(() {
          visionBusy = false;
          visionMessage = 'No image selected.';
        });
        return;
      }

      final fen = await _fenRecognizer.recognizeFen(image.bytes);
      if (!mounted) return;
      if (fen == null || fen.trim().isEmpty) {
        setState(() {
          visionBusy = false;
          visionMessage = 'Chessnut Vision could not recognize this position.';
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
      });
    }
  }

  void _applyVisionFen(BoardVisionFenResult result) {
    final fullFen = _fullFenFromFen(result.fen);
    final boardOnly = fullFen.split(RegExp(r'\s+')).first;
    if (_expandedBoard(boardOnly) == null) {
      setState(() {
        visionBusy = false;
        visionMessage =
            'Chessnut Vision returned a position the board could not read.';
        visionResult = result;
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
    });
    final gateway = widget.boardGateway;
    if (gateway?.currentState == PhysicalBoardConnectionState.connected) {
      unawaited(gateway!.enableRealtimeFen());
    }
    _rememberFenForBot(fullFen);
  }

  Future<void> _sendFenToBoard(BuildContext context) async {
    final fen = _fenController.text.trim();
    final boardOnly = fen.split(RegExp(r'\s+')).first;
    if (_expandedBoard(boardOnly) == null) {
      _showFenSendResult(
        context,
        title: 'Invalid FEN',
        subtitle: 'Paste a valid board FEN before sending.',
      );
      return;
    }
    final fullFen = _fullFenFromFen(fen);
    final castlingError = _castlingRightsValidationError(fullFen);
    if (castlingError != null) {
      _showFenSendResult(
        context,
        title: 'Invalid castling rights',
        subtitle: castlingError,
      );
      return;
    }
    final pieces = _piecesFromBoardOnlyFen(boardOnly);

    setState(() {
      boardFen = fullFen;
      _applyControlsFromFen(fullFen);
      targetBoardFen = boardOnly;
      physicalBoardPieces = pieces;
    });
    _rememberFenForBot(boardFen);

    final gateway = widget.boardGateway;
    if (gateway == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      _showFenSendResult(
        context,
        title: 'Board not connected',
        subtitle: 'Connect a physical board before sending FEN.',
      );
      return;
    }

    await _placementLedFeedback.cancel(gateway);
    final ok = gateway.boardModel == PhysicalBoardModel.move
        ? await gateway.setMoveBoardFen(
            boardFen,
            isReverse: _boardOrientation.isReversed,
          )
        : await _lightFenDiffOnGeneralBoard(gateway, boardOnly);
    if (!context.mounted) return;
    _showFenSendResult(
      context,
      title: ok ? 'FEN sent to board' : 'FEN send failed',
      subtitle: ok
          ? 'The app preview updated and the physical board now guides the setup.'
          : 'The physical board did not accept the FEN command.',
    );
  }

  String _replaceFenMetadata(String fen) {
    final boardOnly = fen.trim().split(RegExp(r'\s+')).first;
    final fullFen = _fullFenFromBoardOnly(boardOnly);
    enPassantSquare = boardEditorEnPassantSquareFromFen(fullFen);
    _fenController.text = fullFen;
    return fullFen;
  }

  String _fullFenFromFen(String fen) {
    final fields = fen.trim().split(RegExp(r'\s+'));
    final boardOnly = fields.isEmpty ? '' : fields.first;
    if (fields.length >= 6) return fields.take(6).join(' ');
    return _fullFenFromBoardOnly(boardOnly);
  }

  void _applyFenInput(String value) {
    final boardOnly = value.trim().split(RegExp(r'\s+')).first;
    if (_expandedBoard(boardOnly) == null) return;
    final sourceFen = _fullFenFromFen(value);
    final selectedSquare = boardEditorEnPassantSquareFromFen(sourceFen);
    final fullFen = boardEditorFenWithEnPassant(sourceFen, selectedSquare);
    setState(() {
      boardFen = fullFen;
      _applyControlsFromFen(fullFen);
      physicalBoardPieces = _piecesFromBoardOnlyFen(boardOnly);
    });
    _rememberFenForBot(fullFen);
  }

  void _rememberFenForBot(String fen) {
    final boardOnly = fen.trim().split(RegExp(r'\s+')).first;
    if (_expandedBoard(boardOnly) == null) return;
    final fullFen = _fullFenFromFen(fen);
    try {
      dc.Chess.fromSetup(dc.Setup.parseFen(fullFen));
    } catch (_) {
      return;
    }
    widget.onFenChanged?.call(fullFen);
  }

  void _startBotFromCurrentFen(BuildContext context) {
    final sourceFen = mode == 0 ? boardFen : _fenController.text.trim();
    final boardOnly = sourceFen.split(RegExp(r'\s+')).first;
    if (_expandedBoard(boardOnly) == null) {
      _showFenSendResult(
        context,
        title: 'Invalid FEN',
        subtitle: 'Use a valid board position before starting a bot game.',
      );
      return;
    }
    final fullFen = _fullFenFromFen(sourceFen);
    final castlingError = _castlingRightsValidationError(fullFen);
    if (castlingError != null) {
      _showFenSendResult(
        context,
        title: 'Invalid castling rights',
        subtitle: castlingError,
      );
      return;
    }
    try {
      dc.Chess.fromSetup(dc.Setup.parseFen(fullFen));
    } catch (_) {
      _showFenSendResult(
        context,
        title: 'Invalid FEN',
        subtitle: 'Use a legal chess position before starting a bot game.',
      );
      return;
    }
    setState(() {
      boardFen = fullFen;
      if (mode == 1) {
        _fenController.text = fullFen;
        physicalBoardPieces = _piecesFromBoardOnlyFen(boardOnly);
      }
    });
    widget.onFenChanged?.call(fullFen);
    widget.onStartBotFromFen?.call(fullFen);
  }

  void _analyzeCurrentFen(BuildContext context) {
    final fullFen = _validatedCurrentFen(context);
    if (fullFen == null) return;
    widget.onFenChanged?.call(fullFen);
    final onAnalyzeFen = widget.onAnalyzeFen;
    if (onAnalyzeFen != null) {
      onAnalyzeFen(fullFen);
    } else {
      widget.onNavigate('BoardAnalyzer');
    }
  }

  String? _validatedCurrentFen(BuildContext context) {
    final sourceFen = mode == 0 ? boardFen : _fenController.text.trim();
    final boardOnly = sourceFen.split(RegExp(r'\s+')).first;
    if (_expandedBoard(boardOnly) == null) {
      _showFenSendResult(
        context,
        title: 'Invalid FEN',
        subtitle: 'Use a valid board position before analyzing it.',
      );
      return null;
    }
    final fullFen = _fullFenFromFen(sourceFen);
    final castlingError = _castlingRightsValidationError(fullFen);
    if (castlingError != null) {
      _showFenSendResult(
        context,
        title: 'Invalid castling rights',
        subtitle: castlingError,
      );
      return null;
    }
    try {
      return dc.Chess.fromSetup(dc.Setup.parseFen(fullFen)).fen;
    } catch (_) {
      _showFenSendResult(
        context,
        title: 'Invalid FEN',
        subtitle: 'Use a legal chess position before analyzing it.',
      );
      return null;
    }
  }

  String? _castlingRightsValidationError(String fen) {
    final board = _expandedBoard(fen);
    if (board == null) return null;
    final fields = fen.trim().split(RegExp(r'\s+'));
    final rights = fields.length > 2 ? fields[2] : '-';

    String pieceAt(String square) {
      if (square.length != 2) return '';
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
      if (!enabled) return;
      if (pieceAt(kingSquare) != king || pieceAt(rookSquare) != rook) {
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

  Future<bool> _lightFenDiffOnGeneralBoard(
    PhysicalBoardGateway gateway,
    String targetBoardFen,
  ) async {
    final current = physicalBoardFen;
    final squares = _differentSquares(current, targetBoardFen);
    if (squares.isEmpty) return gateway.clearGeneralLeds();
    return gateway.setGeneralLedSquares(
      _boardOrientation.toPhysicalSquares(squares),
    );
  }

  void _showFenSendResult(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => AppDialogShell(
        icon: Icons.lightbulb_outline_rounded,
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

  void _showBoardStatusDialog(BuildContext context) {
    final connected = widget.boardGateway?.currentState ==
        PhysicalBoardConnectionState.connected;
    final title = mode == 0 && connected
        ? 'Physical board sync is live'
        : mode == 1
            ? 'FEN guides the physical board'
            : 'Board sync';
    final subtitle = mode == 0
        ? connected
            ? 'Pieces placed on board update this position automatically.'
            : 'Connect a physical board or switch to FEN to board.'
        : 'Paste a FEN, preview it, and optionally send it to the board.';
    _showFenSendResult(
      context,
      title: title,
      subtitle: subtitle,
    );
  }
}

class _BoardEditorLandscapeLayout extends StatelessWidget {
  const _BoardEditorLandscapeLayout({
    required this.height,
    required this.spacing,
    required this.boardPreview,
    required this.controlsPane,
  });

  final double height;
  final double spacing;
  final Widget boardPreview;
  final Widget controlsPane;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('board-editor-landscape-layout'),
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 6,
            child: Align(
              alignment: Alignment.topCenter,
              child: boardPreview,
            ),
          ),
          SizedBox(width: spacing),
          Expanded(flex: 6, child: controlsPane),
        ],
      ),
    );
  }
}

class _BoardEditorControlsPane extends StatelessWidget {
  const _BoardEditorControlsPane({
    required this.modeSwitcher,
    required this.status,
    required this.editorControls,
    required this.vision,
    required this.primaryAction,
    required this.startBotAction,
    this.compact = false,
    this.showModeAndStatus = false,
  });

  final Widget modeSwitcher;
  final Widget status;
  final Widget editorControls;
  final Widget vision;
  final Widget primaryAction;
  final Widget startBotAction;
  final bool compact;
  final bool showModeAndStatus;

  @override
  Widget build(BuildContext context) {
    final spacing = compact ? 6.0 : 12.0;
    final content = SectionColumn(
      spacing: spacing,
      children: [
        if (showModeAndStatus) ...[
          modeSwitcher,
          if (!compact) status,
        ],
        RepaintBoundary(
          key: const ValueKey('board-editor-edit-controls-section'),
          child: editorControls,
        ),
        vision,
        RepaintBoundary(
          key: const ValueKey('board-editor-actions-section'),
          child: SizedBox(
            height: compact ? 54 : 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: primaryAction),
                SizedBox(width: spacing),
                Expanded(child: startBotAction),
              ],
            ),
          ),
        ),
      ],
    );
    final keyedContent = RepaintBoundary(
      key: const ValueKey('board-editor-controls-section'),
      child: content,
    );
    if (!compact) return keyedContent;
    return SingleChildScrollView(
        key: const ValueKey('board-editor-controls-pane'), child: keyedContent);
  }
}

Set<String> _differentSquares(String? sourceBoardFen, String targetBoardFen) {
  final source = _expandedBoard(sourceBoardFen);
  final target = _expandedBoard(targetBoardFen);
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

class _EditorModeButton extends StatelessWidget {
  const _EditorModeButton({
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
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 10),
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

class _BoardToAppPanel extends StatelessWidget {
  const _BoardToAppPanel({
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
    this.compact = false,
  });

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
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SectionColumn(
      spacing: compact ? 6 : 12,
      children: [
        GlassPanel(
          padding: EdgeInsets.all(compact ? 8 : 12),
          child: compact
              ? Row(
                  children: [
                    const SizedBox(
                      width: 104,
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
                      child: _SideButton(
                        label: 'White',
                        icon: Icons.circle_outlined,
                        selected: whiteToMove,
                        height: 36,
                        onTap: () => onSideChanged(true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SideButton(
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
                    const Text('Side to move',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 17)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _SideButton(
                            label: 'White',
                            icon: Icons.circle_outlined,
                            selected: whiteToMove,
                            onTap: () => onSideChanged(true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SideButton(
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
          padding: EdgeInsets.all(compact ? 9 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Castling rights',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              SizedBox(height: compact ? 4 : 8),
              _CastlingRightsRows(
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

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.height = 42,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.secondary;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.16 : 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: color.withValues(alpha: selected ? 0.40 : 0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 7),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _FenPanel extends StatelessWidget {
  const _FenPanel({
    required this.controller,
    required this.onChanged,
    this.compact = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.all(compact ? 9 : 12),
      borderRadius: 13,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FEN to board',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          if (!compact) ...[
            const SizedBox(height: 8),
            Text(
              'Paste a FEN and the physical board LEDs guide the setup.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          SizedBox(height: compact ? 6 : 10),
          TextField(
            controller: controller,
            onChanged: onChanged,
            minLines: compact ? 1 : 2,
            maxLines: compact ? 2 : 3,
            decoration: const InputDecoration(
              labelText: 'FEN',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisionImportPanel extends StatelessWidget {
  const _VisionImportPanel({
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
      borderRadius: 13,
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
                child:
                    Icon(Icons.document_scanner_rounded, color: scheme.primary),
              ),
              SizedBox(width: compact ? 8 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chessnut Vision',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: compact ? 15 : 17,
                        )),
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
                _VisionConfidencePill(label: confidence),
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

class _VisionConfidencePill extends StatelessWidget {
  const _VisionConfidencePill({required this.label});

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

class _FenStatus extends StatelessWidget {
  const _FenStatus();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.lightbulb_outline_rounded,
                color: Theme.of(context).colorScheme.secondary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FEN guides the physical board',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                SizedBox(height: 2),
                Text(
                    'LED guidance updates after the imported position is sent.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncStatus extends StatelessWidget {
  const _SyncStatus();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.sensors_rounded,
                color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Physical board sync is live',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                SizedBox(height: 2),
                Text(
                    'Pieces placed on board update this position automatically.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CastlingRightsRows extends StatelessWidget {
  const _CastlingRightsRows({
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
        _CastlingRightsRow(
          sideLabel: 'White',
          kingSide: whiteKingSide,
          queenSide: whiteQueenSide,
          onKingSideChanged: onWhiteKingSideChanged,
          onQueenSideChanged: onWhiteQueenSideChanged,
        ),
        _CastlingRightsRow(
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

class _CastlingRightsRow extends StatelessWidget {
  const _CastlingRightsRow({
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
          child: _CastlingButton(
            label: 'O-O',
            value: kingSide,
            onChanged: onKingSideChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CastlingButton(
            label: 'O-O-O',
            value: queenSide,
            onChanged: onQueenSideChanged,
          ),
        ),
      ],
    );
  }
}

class _CastlingButton extends StatelessWidget {
  const _CastlingButton({
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
