import 'package:dartchess/dartchess.dart' as dc;

import '../l10n/localized_material.dart';
import 'app_chrome.dart';

List<String> legalBoardEditorEnPassantSquares(String fen) {
  final fields = fen.trim().split(RegExp(r'\s+'));
  if (fields.length < 2 || (fields[1] != 'w' && fields[1] != 'b')) {
    return const [];
  }

  final board = fields.first;
  final turn = fields[1];
  final targetRank = turn == 'w' ? '6' : '3';
  final squares = <String>[];
  for (final file in 'abcdefgh'.split('')) {
    final square = '$file$targetRank';
    try {
      final position = dc.Chess.fromSetup(
        dc.Setup.parseFen('$board $turn - $square 0 1'),
      );
      if (position.fen.split(RegExp(r'\s+'))[3] == square) {
        squares.add(square);
      }
    } catch (_) {
      // An editor position can be incomplete while pieces are being arranged.
    }
  }
  return List.unmodifiable(squares);
}

String? boardEditorEnPassantSquareFromFen(String fen) {
  final fields = fen.trim().split(RegExp(r'\s+'));
  if (fields.length < 4 || fields[3] == '-') return null;
  final square = fields[3].toLowerCase();
  return legalBoardEditorEnPassantSquares(fen).contains(square) ? square : null;
}

String boardEditorFenWithEnPassant(String fen, String? square) {
  final source = fen.trim().split(RegExp(r'\s+'));
  if (source.isEmpty || source.first.isEmpty) return fen;
  final fields = <String>[
    source[0],
    source.length > 1 ? source[1] : 'w',
    source.length > 2 ? source[2] : '-',
    source.length > 3 ? source[3] : '-',
    source.length > 4 ? source[4] : '0',
    source.length > 5 ? source[5] : '1',
  ];
  final normalizedSquare = square?.toLowerCase();
  final available = legalBoardEditorEnPassantSquares(fields.join(' '));
  fields[3] = normalizedSquare != null && available.contains(normalizedSquare)
      ? normalizedSquare
      : '-';
  return fields.join(' ');
}

class BoardEditorEnPassantControl extends StatelessWidget {
  const BoardEditorEnPassantControl({
    required this.availableSquares,
    required this.selectedSquare,
    required this.onChanged,
    this.compact = false,
    this.fieldKey,
    super.key,
  });

  final List<String> availableSquares;
  final String? selectedSquare;
  final ValueChanged<String?> onChanged;
  final bool compact;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final value = availableSquares.contains(selectedSquare)
        ? selectedSquare!
        : '';
    final dropdown = DropdownButtonFormField<String>(
      key: fieldKey,
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'En Passant',
        prefixIcon: Icon(Icons.swap_horiz_rounded),
      ),
      items: [
        const DropdownMenuItem(value: '', child: Text('-')),
        for (final square in availableSquares)
          DropdownMenuItem(value: square, child: Text(square)),
      ],
      onChanged: availableSquares.isEmpty
          ? null
          : (next) => onChanged(next == null || next.isEmpty ? null : next),
    );

    return GlassPanel(
      padding: EdgeInsets.all(compact ? 8 : 12),
      child: compact
          ? Row(
              children: [
                const SizedBox(
                  width: 104,
                  child: Text(
                    'En Passant',
                    maxLines: 1,
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: dropdown),
              ],
            )
          : dropdown,
    );
  }
}
