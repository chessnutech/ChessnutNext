import 'board_settings_service.dart';

enum PhysicalBoardFenMapping { identity, reversed }

class PhysicalBoardOrientationResolver {
  PhysicalBoardOrientationResolver({
    BoardSettingsState settings = const BoardSettingsState(),
  }) : _settings = settings;

  BoardSettingsState _settings;
  PhysicalBoardFenMapping _mapping = PhysicalBoardFenMapping.identity;
  bool _resolved = false;

  PhysicalBoardFenMapping get mapping => _mapping;
  bool get isReversed => _mapping == PhysicalBoardFenMapping.reversed;

  bool updateSettings(BoardSettingsState settings) {
    final previousMapping = _mapping;
    _settings = settings;
    if (!settings.allowFlip) {
      _mapping = PhysicalBoardFenMapping.identity;
      _resolved = true;
    }
    return previousMapping != _mapping;
  }

  void reset() {
    _mapping = PhysicalBoardFenMapping.identity;
    _resolved = false;
  }

  bool setManualMapping(PhysicalBoardFenMapping mapping) {
    final changed = _mapping != mapping;
    _mapping = mapping;
    _resolved = true;
    return changed;
  }

  String normalize(
    String physicalFen, {
    required Iterable<String> referenceFens,
  }) {
    final boardFen = physicalBoardOnlyFen(physicalFen);
    if (boardFen.isEmpty || (!_settings.allowFlip && !_resolved)) {
      return boardFen;
    }
    final references = referenceFens
        .map(physicalBoardOnlyFen)
        .where((fen) => fen.isNotEmpty)
        .toList(growable: false);
    if (_settings.autoFlip && references.isNotEmpty) {
      final resolved = closestPhysicalBoardFenMapping(
        physicalFen: boardFen,
        referenceFens: references,
      );
      if (resolved != null) {
        _mapping = resolved;
        _resolved = true;
      }
    }
    if (_resolved && isReversed && references.contains(boardFen)) {
      return boardFen;
    }
    return mapPhysicalBoardFen(boardFen, _mapping);
  }

  String normalizeWithLockedMapping(
    String physicalFen, {
    required Iterable<String> referenceFens,
  }) {
    final boardFen = physicalBoardOnlyFen(physicalFen);
    if (boardFen.isEmpty) return boardFen;
    final references = referenceFens
        .map(physicalBoardOnlyFen)
        .where((fen) => fen.isNotEmpty)
        .toList(growable: false);
    if (_resolved && isReversed && references.contains(boardFen)) {
      return boardFen;
    }
    return mapPhysicalBoardFen(boardFen, _mapping);
  }

  String normalizeAndTrack(
    String physicalFen, {
    required Iterable<String> referenceFens,
    void Function(PhysicalBoardFenMapping mapping)? onMappingChanged,
  }) {
    final previousMapping = _mapping;
    final normalized = normalize(
      physicalFen,
      referenceFens: referenceFens,
    );
    if (previousMapping != _mapping) onMappingChanged?.call(_mapping);
    return normalized;
  }

  String toPhysicalFen(String logicalFen) {
    return mapPhysicalBoardFen(logicalFen, _mapping);
  }

  Set<String> toPhysicalSquares(Iterable<String> logicalSquares) {
    return {
      for (final square in logicalSquares)
        mapPhysicalBoardSquare(square, _mapping),
    };
  }
}

PhysicalBoardFenMapping? closestPhysicalBoardFenMapping({
  required String physicalFen,
  required Iterable<String> referenceFens,
}) {
  final references = referenceFens
      .map(physicalBoardOnlyFen)
      .where((fen) => fen.isNotEmpty)
      .toList(growable: false);
  if (references.isEmpty) return null;
  final identityFen = mapPhysicalBoardFen(
    physicalFen,
    PhysicalBoardFenMapping.identity,
  );
  final reversedFen = mapPhysicalBoardFen(
    physicalFen,
    PhysicalBoardFenMapping.reversed,
  );
  int? closestIdentity;
  int? closestReversed;
  for (final reference in references) {
    final identityDifference = physicalBoardFenDifferenceCount(
      identityFen,
      reference,
    );
    final reversedDifference = physicalBoardFenDifferenceCount(
      reversedFen,
      reference,
    );
    if (identityDifference != null &&
        (closestIdentity == null || identityDifference < closestIdentity)) {
      closestIdentity = identityDifference;
    }
    if (reversedDifference != null &&
        (closestReversed == null || reversedDifference < closestReversed)) {
      closestReversed = reversedDifference;
    }
  }
  if (closestIdentity == null || closestReversed == null) return null;
  if (closestIdentity < closestReversed) {
    return PhysicalBoardFenMapping.identity;
  }
  if (closestReversed < closestIdentity) {
    return PhysicalBoardFenMapping.reversed;
  }
  return null;
}

String mapPhysicalBoardFen(
  String fen,
  PhysicalBoardFenMapping mapping,
) {
  final board = expandPhysicalBoardFen(fen);
  if (board == null) return physicalBoardOnlyFen(fen);
  if (mapping == PhysicalBoardFenMapping.identity) {
    return compressPhysicalBoardFen(board);
  }
  return compressPhysicalBoardFen(board.reversed.toList(growable: false));
}

String mapPhysicalBoardSquare(
  String square,
  PhysicalBoardFenMapping mapping,
) {
  if (mapping == PhysicalBoardFenMapping.identity ||
      !RegExp(r'^[a-h][1-8]$').hasMatch(square)) {
    return square;
  }
  final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
  final rank = int.parse(square[1]);
  return '${String.fromCharCode('h'.codeUnitAt(0) - file)}${9 - rank}';
}

int? physicalBoardFenDifferenceCount(String firstFen, String secondFen) {
  final first = expandPhysicalBoardFen(firstFen);
  final second = expandPhysicalBoardFen(secondFen);
  if (first == null || second == null) return null;
  var difference = 0;
  for (var index = 0; index < first.length; index += 1) {
    if (first[index] != second[index]) difference += 1;
  }
  return difference;
}

String physicalBoardOnlyFen(String fen) {
  return fen.trim().split(RegExp(r'\s+')).first;
}

List<String>? expandPhysicalBoardFen(String fen) {
  final expanded = <String>[];
  for (final rank in physicalBoardOnlyFen(fen).split('/')) {
    for (final codeUnit in rank.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      final empty = int.tryParse(char);
      if (empty != null) {
        expanded.addAll(List<String>.filled(empty, ''));
      } else if (RegExp(r'^[prnbqkPRNBQK]$').hasMatch(char)) {
        expanded.add(char);
      } else {
        return null;
      }
    }
  }
  return expanded.length == 64 ? expanded : null;
}

String compressPhysicalBoardFen(List<String> pieces) {
  final ranks = <String>[];
  for (var rank = 0; rank < 8; rank += 1) {
    var empty = 0;
    final row = StringBuffer();
    for (var file = 0; file < 8; file += 1) {
      final piece = pieces[rank * 8 + file];
      if (piece.isEmpty) {
        empty += 1;
      } else {
        if (empty > 0) row.write(empty);
        empty = 0;
        row.write(piece);
      }
    }
    if (empty > 0) row.write(empty);
    ranks.add(row.toString());
  }
  return ranks.join('/');
}
