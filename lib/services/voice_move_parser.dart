import 'package:dartchess/dartchess.dart' as dc;

String? parseVoiceMoveText(String text, {String? fen}) {
  final normalized = _normalizeVoiceMoveText(text);
  if (normalized.isEmpty) return null;

  final compactMove = RegExp(
    r'\b([a-h][1-8])\s*([a-h][1-8])\b',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (compactMove != null) {
    return _withPromotion(
      normalized,
      '${compactMove.group(1)!}${compactMove.group(2)!}'.toLowerCase(),
    );
  }

  final tokens = normalized
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
  final squares = <String>[];
  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    if (RegExp(r'^[a-h][1-8]$', caseSensitive: false).hasMatch(token)) {
      squares.add(token.toLowerCase());
      continue;
    }

    final file = _fileFromToken(token);
    if (file == null || i + 1 >= tokens.length) continue;
    final rank = _rankFromToken(tokens[i + 1]);
    if (rank == null) continue;
    squares.add('$file$rank');
    i++;
  }

  if (squares.length >= 2) {
    return _withPromotion(normalized, '${squares[0]}${squares[1]}');
  }

  if (fen == null || fen.trim().isEmpty) return null;
  final position = _positionFromFen(fen);
  if (position == null) return null;
  for (final san in _sanCandidates(normalized)) {
    final move = position.parseSan(san);
    if (move != null) return move.uci;
  }
  return null;
}

String _normalizeVoiceMoveText(String text) {
  var normalized = text.toLowerCase();
  const replacements = {
    '\u4e00': ' 1 ',
    '\u5e7a': ' 1 ',
    '\u4e8c': ' 2 ',
    '\u4e24': ' 2 ',
    '\u4e09': ' 3 ',
    '\u56db': ' 4 ',
    '\u4e94': ' 5 ',
    '\u516d': ' 6 ',
    '\u4e03': ' 7 ',
    '\u516b': ' 8 ',
    '\u5230': ' to ',
    '\u53bb': ' to ',
    '\u81f3': ' to ',
    '\u4ece': ' from ',
    '\u5347\u53d8': ' promote ',
    '\u53d8\u540e': ' promote queen ',
    '\u7687\u540e': ' queen ',
    '\u540e': ' queen ',
    '\u56fd\u738b': ' king ',
    '\u738b': ' king ',
    '\u8f66': ' rook ',
    '\u8c61': ' bishop ',
    '\u9a6c': ' knight ',
    '\u5175': ' pawn ',
    '\u5403': ' takes ',
  };
  for (final entry in replacements.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }
  return normalized
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

dc.Position? _positionFromFen(String fen) {
  try {
    return dc.Chess.fromSetup(dc.Setup.parseFen(fen.trim()));
  } catch (_) {
    return null;
  }
}

Iterable<String> _sanCandidates(String normalized) sync* {
  final lower = normalized.toLowerCase();
  if (lower.contains('castle')) {
    if (lower.contains('queen') || lower.contains('long')) {
      yield 'O-O-O';
    }
    if (lower.contains('king') || lower.contains('short')) {
      yield 'O-O';
    }
  }

  var compact = lower;
  const ranks = {
    'one': '1',
    'won': '1',
    'two': '2',
    'too': '2',
    'three': '3',
    'tree': '3',
    'four': '4',
    'for': '4',
    'fore': '4',
    'five': '5',
    'six': '6',
    'seven': '7',
    'eight': '8',
    'ate': '8',
  };
  for (final entry in ranks.entries) {
    compact = compact.replaceAll(
      RegExp('\\b${entry.key}\\b'),
      entry.value,
    );
  }
  const pieces = {
    'knight': 'N',
    'night': 'N',
    'horse': 'N',
    'bishop': 'B',
    'rook': 'R',
    'queen': 'Q',
    'king': 'K',
  };
  for (final entry in pieces.entries) {
    compact = compact.replaceAll(
      RegExp('\\b${entry.key}\\b'),
      entry.value,
    );
  }
  compact = compact
      .replaceAll(RegExp(r'\b(?:takes?|captures?)\b'), 'x')
      .replaceAll(RegExp(r'\b(?:pawn|move|please|to)\b'), '')
      .replaceAll(RegExp(r'\s+'), '');
  if (compact.isEmpty) return;

  yield compact;
  if (RegExp(r'^[nbrqk]').hasMatch(compact)) {
    yield '${compact[0].toUpperCase()}${compact.substring(1)}';
  }
}

String? _fileFromToken(String token) {
  return switch (token) {
    'a' || 'ay' || 'eh' => 'a',
    'b' || 'be' || 'bee' => 'b',
    'c' || 'see' || 'sea' => 'c',
    'd' || 'de' || 'dee' || 'the' || 't' => 'd',
    'e' || 'ee' => 'e',
    'f' || 'eff' || 'ef' => 'f',
    'g' || 'gee' || 'q' => 'g',
    'h' || 'aitch' || 'age' || 'each' => 'h',
    _ => null,
  };
}

String? _rankFromToken(String token) {
  return switch (token) {
    '1' || 'one' || 'won' => '1',
    '2' || 'two' || 'to' || 'too' => '2',
    '3' || 'three' || 'tree' => '3',
    '4' || 'four' || 'for' || 'fore' => '4',
    '5' || 'five' => '5',
    '6' || 'six' => '6',
    '7' || 'seven' => '7',
    '8' || 'eight' || 'ate' => '8',
    _ => null,
  };
}

String _withPromotion(String text, String uci) {
  final promotion = _promotionFromText(text);
  if (promotion == null || uci.length != 4) return uci;
  return '$uci$promotion';
}

String? _promotionFromText(String text) {
  final tokens = text.split(RegExp(r'\s+')).toSet();
  final hasPromotionHint = tokens.any(
    const {
      'promote',
      'promotes',
      'promoted',
      'promotion',
      'promoting',
      'underpromote',
      'underpromotion',
    }.contains,
  );
  if (!hasPromotionHint) return null;
  if (tokens.contains('queen')) return 'q';
  if (tokens.contains('rook')) return 'r';
  if (tokens.contains('bishop')) return 'b';
  if (tokens.contains('knight') || tokens.contains('night')) return 'n';
  return null;
}
