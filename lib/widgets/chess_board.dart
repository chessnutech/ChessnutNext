import 'package:chessground/chessground.dart' as ground;
import 'package:dartchess/dartchess.dart' as dc;
import '../l10n/localized_material.dart';

import '../models/app_models.dart';
import '../services/move_quality_lights_service.dart';
import '../services/screen_wake_lock_service.dart';

const standardStartFen = chessnutStandardStartFen;

class ChessBoardState {
  const ChessBoardState({
    required this.fen,
    required this.pieces,
    this.whiteToMove = true,
    this.selected,
    this.targets = const [],
    this.lastMove = const [],
    this.inCheck = false,
    this.inCheckmate = false,
    this.inStalemate = false,
    this.inDraw = false,
    this.gameOver = false,
  });

  factory ChessBoardState.fromFen(
    String fen, {
    String? selected,
    List<String> targets = const [],
    List<String> lastMove = const [],
  }) {
    final position = loadDartChessPosition(fen);
    return ChessBoardState.fromPosition(
      position,
      selected: selected,
      targets: targets,
      lastMove: lastMove,
    );
  }

  factory ChessBoardState.fromPosition(
    dc.Position position, {
    String? selected,
    List<String> targets = const [],
    List<String> lastMove = const [],
  }) {
    return ChessBoardState(
      fen: position.fen,
      pieces: piecesFromPosition(position),
      whiteToMove: position.turn == dc.Side.white,
      selected: selected,
      targets: List.unmodifiable(targets),
      lastMove: List.unmodifiable(lastMove),
      inCheck: position.isCheck,
      inCheckmate: position.isCheckmate,
      inStalemate: position.isStalemate,
      inDraw: position.outcome == dc.Outcome.draw,
      gameOver: position.isGameOver,
    );
  }

  final String fen;
  final Map<String, String> pieces;
  final bool whiteToMove;
  final String? selected;
  final List<String> targets;
  final List<String> lastMove;
  final bool inCheck;
  final bool inCheckmate;
  final bool inStalemate;
  final bool inDraw;
  final bool gameOver;

  ChessBoardState copyWith({
    String? fen,
    Map<String, String>? pieces,
    bool? whiteToMove,
    String? selected,
    bool clearSelected = false,
    List<String>? targets,
    List<String>? lastMove,
    bool? inCheck,
    bool? inCheckmate,
    bool? inStalemate,
    bool? inDraw,
    bool? gameOver,
  }) {
    return ChessBoardState(
      fen: fen ?? this.fen,
      pieces: pieces ?? this.pieces,
      whiteToMove: whiteToMove ?? this.whiteToMove,
      selected: clearSelected ? null : selected ?? this.selected,
      targets: targets ?? this.targets,
      lastMove: lastMove ?? this.lastMove,
      inCheck: inCheck ?? this.inCheck,
      inCheckmate: inCheckmate ?? this.inCheckmate,
      inStalemate: inStalemate ?? this.inStalemate,
      inDraw: inDraw ?? this.inDraw,
      gameOver: gameOver ?? this.gameOver,
    );
  }
}

class ChessBoardMove {
  const ChessBoardMove({
    required this.from,
    required this.to,
    required this.san,
    required this.fen,
    required this.state,
    this.promotion,
  });

  final String from;
  final String to;
  final String? promotion;
  final String san;
  final String fen;
  final ChessBoardState state;

  String get uci => '$from$to${promotion ?? ''}';
}

class ChessBoardMoveAnnotation {
  const ChessBoardMoveAnnotation({
    required this.move,
    required this.color,
    this.label,
    this.keyPrefix,
  });

  final ChessBoardMove move;
  final Color color;
  final String? label;
  final String? keyPrefix;
}

dc.Position loadDartChessPosition(String fen) {
  try {
    return dc.Chess.fromSetup(dc.Setup.parseFen(normalizeFenInput(fen)));
  } catch (_) {
    return dc.Chess.initial;
  }
}

String normalizeFenInput(String input) {
  var normalized = input.trim().replaceAll(RegExp(r'\s+'), ' ');
  normalized = normalized.replaceFirst(
    RegExp(r'^position\s+fen\s+', caseSensitive: false),
    '',
  );
  normalized = normalized.replaceFirst(
    RegExp(r'^fen\s*:\s*', caseSensitive: false),
    '',
  );

  final movesIndex = normalized.indexOf(
    RegExp(r'(^|\s)moves(\s|$)', caseSensitive: false),
  );
  if (movesIndex != -1) {
    normalized = normalized.substring(0, movesIndex).trim();
  }
  return normalized;
}

Map<String, String> piecesFromPosition(dc.Position position) {
  final pieces = <String, String>{};
  for (final square in dc.Square.values) {
    final piece = position.board.pieceAt(square);
    if (piece == null) continue;
    final color = piece.color == dc.Side.white ? 'w' : 'b';
    pieces[square.name] = '$color${piece.role.letter}';
  }
  return Map.unmodifiable(pieces);
}

String? checkedKingSquare(dc.Position position) {
  if (!position.isCheck) return null;
  for (final square in dc.Square.values) {
    final piece = position.board.pieceAt(square);
    if (piece?.role == dc.Role.king && piece?.color == position.turn) {
      return square.name;
    }
  }
  return null;
}

String? checkedKingSquareFromFen(String fen) {
  return checkedKingSquare(loadDartChessPosition(fen));
}

List<BoardPiece> piecesFromBoardOnlyFen(String fen) {
  final pieces = <BoardPiece>[];
  final ranks = normalizeFenInput(fen).split(RegExp(r'\s+')).first.split('/');
  if (ranks.length != 8) return pieces;

  for (var rankIndex = 0; rankIndex < ranks.length; rankIndex += 1) {
    var fileIndex = 0;
    for (final char in ranks[rankIndex].characters) {
      final emptySquares = int.tryParse(char);
      if (emptySquares != null) {
        fileIndex += emptySquares;
        continue;
      }
      if (!RegExp(r'^[prnbqkPRNBQK]$').hasMatch(char) ||
          fileIndex >= ChessBoard.files.length) {
        return const [];
      }
      final square =
          '${ChessBoard.files[fileIndex]}${ChessBoard.ranks[rankIndex]}';
      final color = char == char.toUpperCase() ? 'w' : 'b';
      pieces.add(BoardPiece(square, '$color${char.toLowerCase()}'));
      fileIndex += 1;
    }
    if (fileIndex != 8) return const [];
  }

  return List.unmodifiable(pieces);
}

String? rotateFenPieces180(String fen) {
  final fields = normalizeFenInput(fen).split(RegExp(r'\s+'));
  if (fields.isEmpty || fields.first.isEmpty) return null;

  final squares = <String>[];
  final ranks = fields.first.split('/');
  if (ranks.length != 8) return null;
  for (final rank in ranks) {
    var rankLength = 0;
    for (final char in rank.characters) {
      final emptySquares = int.tryParse(char);
      if (emptySquares != null) {
        if (emptySquares < 1 || emptySquares > 8) return null;
        squares.addAll(List<String>.filled(emptySquares, ''));
        rankLength += emptySquares;
      } else {
        if (!RegExp(r'^[prnbqkPRNBQK]$').hasMatch(char)) return null;
        squares.add(char);
        rankLength += 1;
      }
    }
    if (rankLength != 8) return null;
  }
  if (squares.length != 64) return null;

  final rotated = squares.reversed.toList(growable: false);
  final encodedRanks = <String>[];
  for (var rank = 0; rank < 8; rank += 1) {
    final encoded = StringBuffer();
    var emptyCount = 0;
    for (var file = 0; file < 8; file += 1) {
      final piece = rotated[rank * 8 + file];
      if (piece.isEmpty) {
        emptyCount += 1;
        continue;
      }
      if (emptyCount > 0) {
        encoded.write(emptyCount);
        emptyCount = 0;
      }
      encoded.write(piece);
    }
    if (emptyCount > 0) encoded.write(emptyCount);
    encodedRanks.add(encoded.toString());
  }

  final boardOnly = encodedRanks.join('/');
  return fields.length == 1
      ? boardOnly
      : '$boardOnly ${fields.skip(1).join(' ')}';
}

class InteractiveChessBoard extends StatefulWidget {
  const InteractiveChessBoard({
    this.size,
    this.initialFen = standardStartFen,
    this.flipped = false,
    this.lastMove = const [],
    this.enabledColors,
    this.showLegalTargets = true,
    this.externalSelectedSquare,
    this.externalSelectionVersion = 0,
    this.externalLegalTargets = const [],
    this.legalTargetQualities = const {},
    this.showCoordinates = false,
    this.showCheckHighlight = false,
    this.hintMove,
    this.moveAnnotations = const [],
    this.tapSquaresWithOverlay = false,
    this.interactionEnabled = true,
    this.onChanged,
    this.onMove,
    super.key,
  });

  final double? size;
  final String initialFen;
  final bool flipped;
  final List<String> lastMove;
  final Set<dc.Side>? enabledColors;
  final bool showLegalTargets;
  final String? externalSelectedSquare;
  final int externalSelectionVersion;
  final List<String> externalLegalTargets;
  final Map<String, MoveQualityLight> legalTargetQualities;
  final bool showCoordinates;
  final bool showCheckHighlight;
  final ChessBoardMove? hintMove;
  final List<ChessBoardMoveAnnotation> moveAnnotations;
  final bool tapSquaresWithOverlay;
  final bool interactionEnabled;
  final ValueChanged<ChessBoardState>? onChanged;
  final ValueChanged<ChessBoardMove>? onMove;

  @override
  State<InteractiveChessBoard> createState() => _InteractiveChessBoardState();
}

class _InteractiveChessBoardState extends State<InteractiveChessBoard> {
  late dc.Position _position;
  dc.NormalMove? _promotionMove;
  dc.Square? _selectedSquare;

  @override
  void initState() {
    super.initState();
    _position = loadDartChessPosition(widget.initialFen);
  }

  @override
  void didUpdateWidget(covariant InteractiveChessBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFen != widget.initialFen) {
      _position = loadDartChessPosition(widget.initialFen);
      _promotionMove = null;
      _selectedSquare = null;
      _emitState();
      return;
    }
    if (oldWidget.externalSelectedSquare != widget.externalSelectedSquare ||
        oldWidget.externalSelectionVersion != widget.externalSelectionVersion) {
      _syncExternalSelection();
    }
  }

  void _syncExternalSelection() {
    final externalSelected = widget.externalSelectedSquare;
    if (externalSelected == null) {
      _selectedSquare = null;
      return;
    }
    final square = dc.Square.parse(externalSelected);
    if (square == null) return;
    _selectedSquare = square;
  }

  void _emitState() {
    widget.onChanged?.call(
      ChessBoardState.fromPosition(
        _position,
        targets: const [],
        lastMove: widget.lastMove,
      ),
    );
  }

  void _handleMove(dc.Move move, {bool? viaDragAndDrop}) {
    if (move is! dc.NormalMove) return;
    if (_isPromotionWithoutRole(move)) {
      setState(() => _promotionMove = move);
      return;
    }
    _applyMove(move);
  }

  bool _isPromotionWithoutRole(dc.NormalMove move) {
    final piece = _position.board.pieceAt(move.from);
    return move.promotion == null &&
        piece?.role == dc.Role.pawn &&
        (move.to.rank == dc.Rank.first || move.to.rank == dc.Rank.eighth);
  }

  void _handlePromotion(dc.Role? role) {
    final move = _promotionMove;
    setState(() => _promotionMove = null);
    if (role == null || move == null) return;
    _applyMove(move.withPromotion(role));
  }

  void _handleSquareTap(dc.Square square) {
    if (_promotionMove != null) return;
    if (!_canTouchTurnPiece(square)) {
      final selected = _selectedSquare;
      if (selected == null) return;
      final move = dc.NormalMove(from: selected, to: square);
      if (_isPromotionWithoutRole(move)) {
        setState(() => _selectedSquare = null);
        _handleMove(move);
        return;
      }
      if (!_position.isLegal(move)) {
        setState(() => _selectedSquare = null);
        _emitState();
        return;
      }
      setState(() => _selectedSquare = null);
      _applyMove(move);
      return;
    }

    final selected = _selectedSquare;
    if (selected == square) {
      setState(() => _selectedSquare = null);
    } else {
      setState(() => _selectedSquare = square);
    }
    _emitSelectionState();
  }

  void _handleTouchedSquare(dc.Square square) {
    if (_promotionMove != null) return;
    if (!_canTouchTurnPiece(square)) {
      if (_selectedSquare != null) {
        setState(() => _selectedSquare = null);
        _emitState();
      }
      return;
    }

    final selected = _selectedSquare;
    setState(() => _selectedSquare = selected == square ? null : square);
    _emitSelectionState();
  }

  bool _canTouchTurnPiece(dc.Square square) {
    if (_playerSide() == ground.PlayerSide.none) return false;
    final piece = _position.board.pieceAt(square);
    if (piece == null || piece.color != _position.turn) return false;
    final enabled = widget.enabledColors;
    return enabled == null || enabled.contains(piece.color);
  }

  void _emitSelectionState() {
    final selected = _selectedSquare;
    widget.onChanged?.call(
      ChessBoardState.fromPosition(
        _position,
        selected: selected?.name,
        targets: _legalTargetNames(),
        lastMove: widget.lastMove,
      ),
    );
  }

  List<String> _legalTargetNames() {
    final selected = _selectedSquare;
    if (!widget.showLegalTargets || selected == null) return const [];
    return dc
            .makeLegalMoves(_position)[selected]
            ?.map((square) => square.name)
            .toList(growable: false) ??
        const [];
  }

  void _applyMove(dc.NormalMove move) {
    try {
      final (nextPosition, san) = _position.makeSan(move);
      final lastMove = [move.from.name, move.to.name];
      setState(() {
        _position = nextPosition;
        _promotionMove = null;
        _selectedSquare = null;
      });
      final state = ChessBoardState.fromPosition(
        _position,
        lastMove: lastMove,
      );
      widget.onChanged?.call(state);
      widget.onMove?.call(
        ChessBoardMove(
          from: move.from.name,
          to: move.to.name,
          promotion: move.promotion?.letter,
          san: san,
          fen: _position.fen,
          state: state,
        ),
      );
    } catch (_) {
      setState(() => _promotionMove = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final boardSize = widget.size ??
        (MediaQuery.sizeOf(context).width - 56).clamp(244.0, 326.0);
    final pieces = piecesFromPosition(_position);
    final targets = _legalTargetNames();
    final overlaySelected =
        _selectedSquare?.name ?? widget.externalSelectedSquare;
    final overlayTargets =
        targets.isNotEmpty ? targets : widget.externalLegalTargets;
    final settings =
        _settings.copyWith(showValidMoves: widget.showLegalTargets);
    final gameData = ground.GameData(
      playerSide: _playerSide(),
      sideToMove: _position.turn,
      validMoves: dc.makeLegalMoves(_position),
      isCheck: _position.isCheck,
      promotionMove: _promotionMove,
      onMove: _handleMove,
      onPromotionSelection: _handlePromotion,
    );
    return ScreenWakeFenActivityReporter(
      fen: _position.fen,
      child: SizedBox.square(
        dimension: boardSize.toDouble(),
        child: Stack(
          children: [
            IgnorePointer(
              ignoring: !widget.interactionEnabled,
              child: ground.Chessboard(
                key: ValueKey(
                  'ground-selection-${widget.externalSelectionVersion}',
                ),
                size: boardSize.toDouble(),
                settings: settings,
                orientation: widget.flipped ? dc.Side.black : dc.Side.white,
                fen: _position.fen,
                lastMove: _lastMove(),
                game: gameData,
                onTouchedSquare: _handleTouchedSquare,
              ),
            ),
            if (widget.showCheckHighlight)
              _CheckedKingOverlay(
                size: boardSize.toDouble(),
                flipped: widget.flipped,
                squareName: checkedKingSquare(_position),
              ),
            if (widget.showLegalTargets &&
                overlaySelected != null &&
                overlayTargets.isNotEmpty)
              _LegalTargetOverlay(
                size: boardSize.toDouble(),
                flipped: widget.flipped,
                selected: overlaySelected,
                targets: overlayTargets,
                targetQualities: widget.legalTargetQualities,
                pieces: pieces,
              ),
            if (widget.hintMove != null)
              _HintMoveOverlay(
                size: boardSize.toDouble(),
                flipped: widget.flipped,
                move: widget.hintMove!,
              ),
            for (final annotation in widget.moveAnnotations)
              _HintMoveOverlay(
                size: boardSize.toDouble(),
                flipped: widget.flipped,
                move: annotation.move,
                color: annotation.color,
                label: annotation.label,
                keyPrefix: annotation.keyPrefix,
              ),
            if (widget.showCoordinates)
              _BoardCoordinatesOverlay(
                size: boardSize.toDouble(),
                flipped: widget.flipped,
              ),
            if (_promotionMove == null)
              _BoardSquareSemanticsOverlay(
                size: boardSize.toDouble(),
                flipped: widget.flipped,
                pieces: pieces,
                handlePointerTaps:
                    widget.interactionEnabled && widget.tapSquaresWithOverlay,
                onSquareTap:
                    widget.interactionEnabled ? _handleSquareTap : null,
              ),
          ],
        ),
      ),
    );
  }

  ground.PlayerSide _playerSide() {
    final enabled = widget.enabledColors;
    if (enabled == null) return ground.PlayerSide.both;
    final white = enabled.contains(dc.Side.white);
    final black = enabled.contains(dc.Side.black);
    if (white && black) return ground.PlayerSide.both;
    if (white) return ground.PlayerSide.white;
    if (black) return ground.PlayerSide.black;
    return ground.PlayerSide.none;
  }

  dc.Move? _lastMove() {
    if (widget.lastMove.length != 2) return null;
    final from = dc.Square.parse(widget.lastMove[0]);
    final to = dc.Square.parse(widget.lastMove[1]);
    if (from == null || to == null) return null;
    return dc.NormalMove(from: from, to: to);
  }
}

class _CheckedKingOverlay extends StatelessWidget {
  const _CheckedKingOverlay({
    required this.size,
    required this.flipped,
    required this.squareName,
  });

  final double size;
  final bool flipped;
  final String? squareName;

  @override
  Widget build(BuildContext context) {
    final square = dc.Square.parse(squareName ?? '');
    if (square == null) return const SizedBox.shrink();
    final squareSize = size / 8;
    const red = Color(0xFFEF4444);
    return Positioned(
      key: ValueKey('check-king-${square.name}'),
      left: _squareLeft(square, squareSize, flipped),
      top: _squareTop(square, squareSize, flipped),
      width: squareSize,
      height: squareSize,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: red.withValues(alpha: 0.42),
            border: Border.all(
              color: red.withValues(alpha: 0.92),
              width: (squareSize * 0.06).clamp(2.0, 4.0),
            ),
            boxShadow: [
              BoxShadow(
                color: red.withValues(alpha: 0.48),
                blurRadius: squareSize * 0.18,
                spreadRadius: -squareSize * 0.04,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChessBoard extends StatelessWidget {
  const ChessBoard({
    required this.pieces,
    this.size,
    this.selected,
    this.targets = const [],
    this.lastMove = const [],
    this.flipped = false,
    this.showCoordinates = false,
    this.interactive = false,
    this.onSquareTap,
    super.key,
  });

  final List<BoardPiece> pieces;
  final double? size;
  final String? selected;
  final List<String> targets;
  final List<String> lastMove;
  final bool flipped;
  final bool showCoordinates;
  final bool interactive;
  final ValueChanged<String>? onSquareTap;

  static const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
  static const ranks = ['8', '7', '6', '5', '4', '3', '2', '1'];

  @override
  Widget build(BuildContext context) {
    final boardSize =
        size ?? (MediaQuery.sizeOf(context).width - 56).clamp(244.0, 326.0);
    final fen = _fenFromPieces(pieces);
    return ScreenWakeFenActivityReporter(
      fen: fen,
      child: SizedBox.square(
        dimension: boardSize.toDouble(),
        child: Stack(
          children: [
            ground.Chessboard.fixed(
              size: boardSize.toDouble(),
              settings: _settings,
              orientation: flipped ? dc.Side.black : dc.Side.white,
              fen: fen,
              lastMove: _lastMoveFromSquares(lastMove),
              onTouchedSquare: onSquareTap == null
                  ? null
                  : (square) => onSquareTap!(square.name),
            ),
            _BoardSquareSemanticsOverlay(
              size: boardSize.toDouble(),
              flipped: flipped,
              pieces: {
                for (final piece in pieces) piece.square: piece.code,
              },
              onSquareTap: (square) => onSquareTap?.call(square.name),
            ),
            if (showCoordinates)
              _BoardCoordinatesOverlay(
                size: boardSize.toDouble(),
                flipped: flipped,
              ),
          ],
        ),
      ),
    );
  }
}

class _BoardSquareSemanticsOverlay extends StatefulWidget {
  const _BoardSquareSemanticsOverlay({
    required this.size,
    required this.flipped,
    required this.pieces,
    this.handlePointerTaps = false,
    this.onSquareTap,
  });

  final double size;
  final bool flipped;
  final Map<String, String> pieces;
  final bool handlePointerTaps;
  final ValueChanged<dc.Square>? onSquareTap;

  @override
  State<_BoardSquareSemanticsOverlay> createState() =>
      _BoardSquareSemanticsOverlayState();
}

class _BoardSquareSemanticsOverlayState
    extends State<_BoardSquareSemanticsOverlay> {
  dc.Square? _dragSource;
  dc.Square? _dragTarget;

  @override
  Widget build(BuildContext context) {
    final squareSize = widget.size / 8;
    return Stack(
      children: [
        for (final square in dc.Square.values)
          Positioned(
            left: _left(square, squareSize),
            top: _top(square, squareSize),
            width: squareSize,
            height: squareSize,
            child: Semantics(
              key: ValueKey('square-${square.name}'),
              label: '${square.name} ${widget.pieces[square.name] ?? 'empty'}',
              button: widget.onSquareTap != null,
              onTap: widget.onSquareTap == null
                  ? null
                  : () => widget.onSquareTap!(square),
              child: const SizedBox.expand(),
            ),
          ),
        if (widget.handlePointerTaps && widget.onSquareTap != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (details) {
                final square = _squareFromBoardOffset(
                  details.localPosition,
                  squareSize,
                );
                if (square != null) widget.onSquareTap!(square);
              },
              onPanStart: (details) {
                _dragSource = _squareFromBoardOffset(
                  details.localPosition,
                  squareSize,
                );
                _dragTarget = _dragSource;
              },
              onPanUpdate: (details) {
                _dragTarget = _squareFromBoardOffset(
                  details.localPosition,
                  squareSize,
                );
              },
              onPanEnd: (_) {
                final source = _dragSource;
                final target = _dragTarget;
                _dragSource = null;
                _dragTarget = null;
                if (source == null || target == null || source == target) {
                  return;
                }
                widget.onSquareTap!(source);
                widget.onSquareTap!(target);
              },
              onPanCancel: () {
                _dragSource = null;
                _dragTarget = null;
              },
            ),
          ),
      ],
    );
  }

  double _left(dc.Square square, double squareSize) {
    return _squareLeft(square, squareSize, widget.flipped);
  }

  double _top(dc.Square square, double squareSize) {
    return _squareTop(square, squareSize, widget.flipped);
  }

  dc.Square? _squareFromBoardOffset(Offset offset, double squareSize) {
    final visualFile = (offset.dx / squareSize).floor();
    final visualRank = (offset.dy / squareSize).floor();
    if (visualFile < 0 || visualFile > 7 || visualRank < 0 || visualRank > 7) {
      return null;
    }
    final file = widget.flipped ? 7 - visualFile : visualFile;
    final rank = widget.flipped ? visualRank : 7 - visualRank;
    return dc.Square.values.firstWhere(
      (square) => square.file.value == file && square.rank.value == rank,
    );
  }
}

class _LegalTargetOverlay extends StatelessWidget {
  const _LegalTargetOverlay({
    required this.size,
    required this.flipped,
    required this.selected,
    required this.targets,
    required this.targetQualities,
    required this.pieces,
  });

  final double size;
  final bool flipped;
  final String selected;
  final List<String> targets;
  final Map<String, MoveQualityLight> targetQualities;
  final Map<String, String> pieces;

  @override
  Widget build(BuildContext context) {
    final squareSize = size / 8;
    final scheme = Theme.of(context).colorScheme;
    final color = scheme.primary;
    return IgnorePointer(
      child: Stack(
        children: [
          _squareMarker(
            key: ValueKey('legal-selected-$selected'),
            squareName: selected,
            squareSize: squareSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: color.withValues(alpha: 0.72),
                  width: (squareSize * 0.06).clamp(2.0, 4.0),
                ),
              ),
            ),
          ),
          for (final target in targets)
            _squareMarker(
              key: ValueKey('legal-target-$target'),
              squareName: target,
              squareSize: squareSize,
              child: KeyedSubtree(
                key: ValueKey(
                  'legal-target-$target-${_qualityKey(targetQualities[target])}',
                ),
                child: Center(
                  child: pieces.containsKey(target)
                      ? Container(
                          width: squareSize * 0.76,
                          height: squareSize * 0.76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _qualityColor(
                                context,
                                targetQualities[target],
                              ).withValues(alpha: 0.84),
                              width: (squareSize * 0.08).clamp(3.0, 5.0),
                            ),
                          ),
                        )
                      : Container(
                          width: squareSize * 0.26,
                          height: squareSize * 0.26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _qualityColor(
                              context,
                              targetQualities[target],
                            ).withValues(alpha: 0.84),
                            boxShadow: [
                              BoxShadow(
                                color: scheme.surface.withValues(alpha: 0.55),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _qualityKey(MoveQualityLight? quality) {
    return switch (quality) {
      MoveQualityLight.best => 'best',
      MoveQualityLight.great => 'great',
      MoveQualityLight.good => 'good',
      MoveQualityLight.inaccuracy => 'inaccuracy',
      MoveQualityLight.mistake => 'mistake',
      MoveQualityLight.blunder => 'blunder',
      null => 'normal',
    };
  }

  Color _qualityColor(BuildContext context, MoveQualityLight? quality) {
    if (quality == null) return Theme.of(context).colorScheme.primary;
    return switch (quality) {
      MoveQualityLight.best => const Color(0xFF166534),
      MoveQualityLight.great => const Color(0xFF22C55E),
      MoveQualityLight.good => const Color(0xFFFACC15),
      MoveQualityLight.inaccuracy => const Color(0xFFF97316),
      MoveQualityLight.mistake => const Color(0xFFEA580C),
      MoveQualityLight.blunder => const Color(0xFFEF4444),
    };
  }

  Widget _squareMarker({
    required Key key,
    required String squareName,
    required double squareSize,
    required Widget child,
  }) {
    final square = dc.Square.parse(squareName);
    if (square == null) return const SizedBox.shrink();
    return Positioned(
      key: key,
      left: _squareLeft(square, squareSize, flipped),
      top: _squareTop(square, squareSize, flipped),
      width: squareSize,
      height: squareSize,
      child: child,
    );
  }
}

class _BoardCoordinatesOverlay extends StatelessWidget {
  const _BoardCoordinatesOverlay({
    required this.size,
    required this.flipped,
  });

  final double size;
  final bool flipped;

  @override
  Widget build(BuildContext context) {
    final squareSize = size / 8;
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(
      color: scheme.onSurface.withValues(alpha: 0.72),
      fontSize: (squareSize * 0.18).clamp(9.0, 13.0),
      fontWeight: FontWeight.w900,
      shadows: [
        Shadow(
          color: scheme.surface.withValues(alpha: 0.74),
          blurRadius: 4,
        ),
      ],
    );
    return IgnorePointer(
      child: Stack(
        children: [
          for (var index = 0; index < ChessBoard.files.length; index += 1)
            Positioned(
              key: ValueKey(
                'board-coordinate-file-${ChessBoard.files[index]}',
              ),
              left: _coordinateLeft(index, squareSize),
              bottom: 2,
              width: squareSize,
              child: Text(
                ChessBoard.files[index],
                textAlign: TextAlign.left,
                style: style,
              ),
            ),
          for (var index = 0; index < 8; index += 1)
            Positioned(
              key: ValueKey('board-coordinate-rank-${index + 1}'),
              top: _coordinateTop(index, squareSize),
              right: 3,
              height: squareSize,
              child: Align(
                alignment: Alignment.topRight,
                child: Text('${index + 1}', style: style),
              ),
            ),
        ],
      ),
    );
  }

  double _coordinateLeft(int fileIndex, double squareSize) {
    return (flipped ? 7 - fileIndex : fileIndex) * squareSize + 3;
  }

  double _coordinateTop(int rankIndex, double squareSize) {
    return (flipped ? rankIndex : 7 - rankIndex) * squareSize + 2;
  }
}

class _HintMoveOverlay extends StatelessWidget {
  const _HintMoveOverlay({
    required this.size,
    required this.flipped,
    required this.move,
    this.color,
    this.label,
    this.keyPrefix,
  });

  final double size;
  final bool flipped;
  final ChessBoardMove move;
  final Color? color;
  final String? label;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    final from = dc.Square.parse(move.from);
    final to = dc.Square.parse(move.to);
    if (from == null || to == null) return const SizedBox.shrink();
    final squareSize = size / 8;
    final effectiveColor = color ?? Theme.of(context).colorScheme.tertiary;
    return IgnorePointer(
      child: Stack(
        children: [
          _hintSquare(
            key: _overlayKey('hint-square-${move.from}'),
            square: from,
            squareSize: squareSize,
            color: effectiveColor,
          ),
          _hintSquare(
            key: _overlayKey('hint-square-${move.to}'),
            square: to,
            squareSize: squareSize,
            color: effectiveColor,
          ),
          Positioned.fill(
            key: _overlayKey('hint-arrow-${move.from}-${move.to}'),
            child: CustomPaint(
              painter: _HintArrowPainter(
                from: _squareCenter(from, squareSize),
                to: _squareCenter(to, squareSize),
                color: effectiveColor.withValues(alpha: 0.58),
                strokeWidth: (squareSize * 0.12).clamp(5.0, 9.0),
              ),
            ),
          ),
          if (label != null)
            Positioned(
              key: _overlayKey('hint-label-${move.to}'),
              left: _squareLeft(to, squareSize, flipped) + squareSize * 0.08,
              top: _squareTop(to, squareSize, flipped) + squareSize * 0.08,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: (squareSize * 0.10).clamp(4.0, 7.0),
                  vertical: (squareSize * 0.04).clamp(2.0, 4.0),
                ),
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  label!,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: (squareSize * 0.20).clamp(9.0, 12.0),
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Key _overlayKey(String value) {
    final prefix = keyPrefix;
    return ValueKey(prefix == null ? value : '$prefix-$value');
  }

  Widget _hintSquare({
    required Key key,
    required dc.Square square,
    required double squareSize,
    required Color color,
  }) {
    return Positioned(
      key: key,
      left: _squareLeft(square, squareSize, flipped),
      top: _squareTop(square, squareSize, flipped),
      width: squareSize,
      height: squareSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.22),
          border: Border.all(
            color: color.withValues(alpha: 0.82),
            width: (squareSize * 0.045).clamp(2.0, 4.0),
          ),
        ),
      ),
    );
  }

  Offset _squareCenter(dc.Square square, double squareSize) {
    return Offset(
      _squareLeft(square, squareSize, flipped) + squareSize / 2,
      _squareTop(square, squareSize, flipped) + squareSize / 2,
    );
  }
}

class _HintArrowPainter extends CustomPainter {
  const _HintArrowPainter({
    required this.from,
    required this.to,
    required this.color,
    required this.strokeWidth,
  });

  final Offset from;
  final Offset to;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final vector = to - from;
    if (vector.distance <= 1) return;
    final direction = vector / vector.distance;
    final start = from + direction * strokeWidth;
    final end = to - direction * (strokeWidth * 1.65);
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, paint);

    final angle = direction.direction;
    final headLength = strokeWidth * 2.25;
    final left = end - Offset.fromDirection(angle - 0.62, headLength);
    final right = end - Offset.fromDirection(angle + 0.62, headLength);
    final path = Path()
      ..moveTo(to.dx - direction.dx * strokeWidth,
          to.dy - direction.dy * strokeWidth)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _HintArrowPainter oldDelegate) {
    return oldDelegate.from != from ||
        oldDelegate.to != to ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

double _squareLeft(dc.Square square, double squareSize, bool flipped) {
  final file = square.file.value;
  return (flipped ? 7 - file : file) * squareSize;
}

double _squareTop(dc.Square square, double squareSize, bool flipped) {
  final rank = square.rank.value;
  return (flipped ? rank : 7 - rank) * squareSize;
}

String _fenFromPieces(List<BoardPiece> pieces) {
  final mapped = <dc.Square, dc.Piece>{};
  for (final piece in pieces) {
    final square = dc.Square.parse(piece.square);
    if (square == null || piece.code.length < 2) continue;
    final color = piece.code[0] == 'w' ? dc.Side.white : dc.Side.black;
    final role = dc.Role.fromChar(piece.code[1]);
    if (role == null) continue;
    mapped[square] = dc.Piece(color: color, role: role);
  }
  return '${ground.writeFen(mapped)} w KQkq - 0 1';
}

dc.Move? _lastMoveFromSquares(List<String> lastMove) {
  if (lastMove.length != 2) return null;
  final from = dc.Square.parse(lastMove[0]);
  final to = dc.Square.parse(lastMove[1]);
  if (from == null || to == null) return null;
  return dc.NormalMove(from: from, to: to);
}

const _settings = ground.ChessboardSettings(
  pieceAssets: ground.PieceSet.cburnettAssets,
  colorScheme: ground.ChessboardColorScheme.brown,
  enableCoordinates: false,
  autoQueenPromotion: false,
  border: null,
);

final standardStartPieces = ChessBoardState.fromFen(standardStartFen)
    .pieces
    .entries
    .map((entry) => BoardPiece(entry.key, entry.value))
    .toList(growable: false);
