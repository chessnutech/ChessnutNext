import 'physical_board_gateway.dart';
import 'physical_board_protocol.dart';

class BoardEditorPlacementLedFeedback {
  bool _ledsActive = false;

  Future<void> showPosition({
    required PhysicalBoardGateway gateway,
    required String boardFen,
  }) async {
    final squares = boardEditorOccupiedSquares(boardFen);
    if (squares == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      return;
    }

    final bool updated;
    if (squares.isEmpty) {
      updated = await _clear(gateway);
    } else if (gateway.boardModel == PhysicalBoardModel.move) {
      updated = await gateway.setMoveLedSquares({
        for (final square in squares) square: ChessnutMoveLedColor.green,
      });
    } else {
      updated = await gateway.setGeneralLedSquares(squares);
    }
    if (updated) _ledsActive = squares.isNotEmpty;
  }

  Future<void> cancel(PhysicalBoardGateway? gateway) async {
    if (_ledsActive &&
        gateway != null &&
        gateway.currentState == PhysicalBoardConnectionState.connected) {
      _ledsActive = false;
      await _clear(gateway);
    }
  }

  Future<bool> _clear(PhysicalBoardGateway gateway) {
    return gateway.boardModel == PhysicalBoardModel.move
        ? gateway.clearMoveLeds()
        : gateway.clearGeneralLeds();
  }
}

Set<String>? boardEditorOccupiedSquares(String boardFen) {
  final board = _expandedBoard(boardFen);
  if (board == null) return null;

  const files = 'abcdefgh';
  const ranks = '87654321';
  final squares = <String>{};
  for (var index = 0; index < 64; index += 1) {
    if (board[index].isNotEmpty) {
      squares.add('${files[index % 8]}${ranks[index ~/ 8]}');
    }
  }
  return squares;
}

List<String>? _expandedBoard(String fen) {
  final ranks = fen.trim().split(RegExp(r'\s+')).first.split('/');
  if (ranks.length != 8) return null;
  final board = <String>[];
  for (final rank in ranks) {
    var rankLength = 0;
    for (final char in rank.split('')) {
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
