import 'package:flutter/foundation.dart';

@immutable
class GrandeurHtmlMove {
  const GrandeurHtmlMove({
    required this.ply,
    required this.san,
    this.fen = '',
    this.tag = '',
    this.commentary = '',
    this.purpose = '',
    this.why = '',
    this.betterMove = '',
    this.classification = '',
  });

  final int ply;
  final String san;
  final String fen;
  final String tag;
  final String commentary;
  final String purpose;
  final String why;
  final String betterMove;
  final String classification;
}

@immutable
class GrandeurHtmlReportData {
  const GrandeurHtmlReportData({
    required this.title,
    required this.whiteName,
    required this.blackName,
    required this.language,
    required this.summary,
    required this.coachName,
    required this.coachRole,
    required this.coachAvatarDataUri,
    required this.accentColor,
    required this.pieceImageDataUris,
    required this.whiteAccuracy,
    required this.blackAccuracy,
    this.whiteAccuracyText,
    this.blackAccuracyText,
    required this.hasWhiteAccuracy,
    required this.hasBlackAccuracy,
    required this.whiteCounts,
    required this.blackCounts,
    required this.moves,
    required this.generatedAt,
  });

  final String title;
  final String whiteName;
  final String blackName;
  final String language;
  final String summary;
  final String coachName;
  final String coachRole;
  final String coachAvatarDataUri;
  final String accentColor;
  final Map<String, String> pieceImageDataUris;
  final double whiteAccuracy;
  final double blackAccuracy;
  final String? whiteAccuracyText;
  final String? blackAccuracyText;
  final bool hasWhiteAccuracy;
  final bool hasBlackAccuracy;
  final Map<String, int> whiteCounts;
  final Map<String, int> blackCounts;
  final List<GrandeurHtmlMove> moves;
  final DateTime generatedAt;
}

String buildGrandeurReportHtml(GrandeurHtmlReportData data) {
  final accent = _cssColor(data.accentColor);
  final accentSoft = _rgba(accent, 0.16);
  final accentBorder = _rgba(accent, 0.42);
  final whiteAccuracy = data.hasWhiteAccuracy
      ? '${data.whiteAccuracyText ?? data.whiteAccuracy.toString()}%'
      : '--';
  final blackAccuracy = data.hasBlackAccuracy
      ? '${data.blackAccuracyText ?? data.blackAccuracy.toString()}%'
      : '--';
  final summary = data.summary.trim().isEmpty
      ? 'No summary was returned.'
      : data.summary.trim();
  final generatedAt = data.generatedAt.toLocal().toString().split('.').first;
  final avatar = data.coachAvatarDataUri.trim().isEmpty
      ? '<div class="coach-fallback" aria-hidden="true">&#9822;</div>'
      : '<img class="coach-avatar" src="${_escape(data.coachAvatarDataUri)}" alt="${_escape(data.coachName)}">';
  final moveCards =
      data.moves.map((move) => _moveCard(move, data.pieceImageDataUris)).join();

  return '''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${_escape(data.title)}</title>
  <style>
    :root {
      color-scheme: light dark;
      --accent: $accent;
      --accent-soft: $accentSoft;
      --accent-border: $accentBorder;
      --page: #f4f3f8;
      --surface: #ffffff;
      --surface-soft: #f8f7fb;
      --text: #20202a;
      --muted: #6f6d7c;
      --border: #dedbe7;
      --shadow: 0 14px 40px rgba(35, 27, 60, 0.10);
      --board-light: #f0d9b6;
      --board-dark: #b58863;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: var(--page);
      color: var(--text);
      font-family: Inter, "Segoe UI", system-ui, -apple-system, sans-serif;
      line-height: 1.55;
    }
    main { width: min(1120px, calc(100% - 32px)); margin: 28px auto 56px; }
    .hero {
      position: relative;
      overflow: hidden;
      padding: 30px;
      border: 1px solid var(--accent-border);
      border-radius: 22px;
      background: linear-gradient(135deg, var(--accent-soft), var(--surface) 62%);
      box-shadow: var(--shadow);
    }
    .hero::after {
      content: "";
      position: absolute;
      width: 240px;
      height: 240px;
      right: -90px;
      top: -120px;
      border-radius: 50%;
      background: var(--accent-soft);
    }
    .eyebrow { color: var(--accent); font-size: 12px; font-weight: 900; letter-spacing: .14em; text-transform: uppercase; }
    h1 { margin: 5px 0 4px; font-size: clamp(27px, 4vw, 42px); line-height: 1.08; }
    h2 { margin: 0; font-size: 20px; }
    .meta { color: var(--muted); font-size: 13px; }
    .matchup { display: grid; grid-template-columns: 1fr auto 1fr; gap: 16px; align-items: center; margin-top: 24px; }
    .player {
      padding: 16px;
      border: 1px solid var(--border);
      border-radius: 14px;
      background: var(--surface);
    }
    .player.black { text-align: right; }
    .player-name { display: block; font-size: 17px; font-weight: 850; overflow-wrap: anywhere; }
    .accuracy { color: var(--accent); font-size: 26px; font-weight: 900; line-height: 1.2; }
    .versus { color: var(--muted); font-size: 12px; font-weight: 900; letter-spacing: .12em; }
    .section { margin-top: 22px; }
    .card {
      border: 1px solid var(--border);
      border-radius: 18px;
      background: var(--surface);
      box-shadow: 0 8px 24px rgba(35, 27, 60, 0.06);
    }
    .summary-card { display: grid; grid-template-columns: 92px 1fr; gap: 20px; padding: 20px; border-color: var(--accent-border); }
    .coach-avatar, .coach-fallback {
      width: 92px;
      height: 92px;
      border: 2px solid var(--accent-border);
      border-radius: 18px;
      object-fit: cover;
      background: var(--surface-soft);
      box-shadow: 0 8px 20px rgba(35, 27, 60, 0.12);
    }
    .coach-fallback { display: grid; place-items: center; color: var(--accent); font-size: 48px; }
    .coach-name { font-weight: 900; }
    .coach-role { color: var(--muted); font-size: 13px; }
    .speech {
      position: relative;
      margin-top: 10px;
      padding: 14px 16px;
      border-radius: 8px 14px 14px 14px;
      background: var(--accent-soft);
      border: 1px solid var(--accent-border);
      white-space: normal;
    }
    .stats-card { padding: 20px; }
    .section-heading { display: flex; align-items: center; gap: 9px; margin-bottom: 15px; }
    .section-icon { color: var(--accent); font-size: 22px; }
    .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(145px, 1fr)); gap: 10px; }
    .stat {
      display: grid;
      grid-template-columns: 12px 1fr auto auto;
      align-items: center;
      gap: 8px;
      padding: 10px 12px;
      border: 1px solid var(--border);
      border-radius: 10px;
      background: var(--surface-soft);
    }
    .dot { width: 9px; height: 9px; border-radius: 50%; background: var(--quality); }
    .stat-label { font-size: 13px; font-weight: 750; }
    .side-count { min-width: 22px; text-align: center; font-weight: 900; }
    .side-count.black { color: var(--muted); }
    .moves-heading { margin: 28px 0 12px; }
    .move-list { display: grid; gap: 14px; }
    .move-card {
      --quality: #64748b;
      display: grid;
      grid-template-columns: 220px minmax(0, 1fr);
      gap: 20px;
      padding: 16px;
      border-left: 5px solid var(--quality);
    }
    .board {
      display: grid;
      grid-template-columns: repeat(8, 1fr);
      width: 100%;
      aspect-ratio: 1;
      overflow: hidden;
      border: 1px solid var(--border);
      border-radius: 9px;
      box-shadow: 0 5px 14px rgba(23, 20, 35, 0.12);
    }
    .square { display: grid; place-items: center; width: 100%; aspect-ratio: 1; overflow: hidden; }
    .square.light { background: var(--board-light); }
    .square.dark { background: var(--board-dark); }
    .piece-image { display: block; width: 88%; height: 88%; object-fit: contain; filter: drop-shadow(0 1px 1px rgba(0, 0, 0, .24)); }
    .move-top { display: flex; flex-wrap: wrap; align-items: center; gap: 9px; }
    .move-name { font-size: 22px; font-weight: 900; }
    .badge { padding: 3px 9px; border: 1px solid color-mix(in srgb, var(--quality) 55%, transparent); border-radius: 999px; color: var(--quality); background: color-mix(in srgb, var(--quality) 13%, transparent); font-size: 12px; font-weight: 850; }
    .commentary { margin: 12px 0; font-size: 15px; }
    .details { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 9px; }
    .detail { padding: 10px 12px; border-radius: 10px; background: var(--surface-soft); border: 1px solid var(--border); }
    .detail-label { display: block; margin-bottom: 3px; color: var(--accent); font-size: 11px; font-weight: 900; letter-spacing: .06em; text-transform: uppercase; }
    .empty-board { display: grid; place-items: center; width: 100%; aspect-ratio: 1; border-radius: 9px; background: var(--surface-soft); color: var(--muted); font-size: 13px; text-align: center; }
    footer { margin-top: 24px; color: var(--muted); font-size: 12px; text-align: center; }
    @media (prefers-color-scheme: dark) {
      :root {
        --page: #111016;
        --surface: #1b1921;
        --surface-soft: #24212c;
        --text: #f3eff8;
        --muted: #b4adbd;
        --border: #393441;
        --shadow: 0 14px 42px rgba(0, 0, 0, .28);
      }
    }
    @media (max-width: 720px) {
      main { width: min(100% - 20px, 620px); margin-top: 10px; }
      .hero { padding: 20px 16px; border-radius: 16px; }
      .matchup { grid-template-columns: 1fr; gap: 8px; }
      .player.black { text-align: left; }
      .versus { display: none; }
      .summary-card { grid-template-columns: 68px 1fr; gap: 13px; padding: 14px; }
      .coach-avatar, .coach-fallback { width: 68px; height: 68px; border-radius: 14px; }
      .move-card { grid-template-columns: 1fr; padding: 12px; }
      .board { width: min(100%, 360px); margin: 0 auto; }
    }
    @media print {
      :root { color-scheme: light; --page: #fff; --surface: #fff; --surface-soft: #f8f7fb; --text: #20202a; --muted: #6f6d7c; --border: #dedbe7; }
      body { background: #fff; }
      main { width: 100%; margin: 0; }
      .hero, .card { box-shadow: none; }
      .move-card { break-inside: avoid; }
    }
  </style>
</head>
<body>
<main>
  <header class="hero">
    <div class="eyebrow">Chessnut Grandeur</div>
    <h1>${_escape(data.title)}</h1>
    <div class="meta">${_escape(data.language.isEmpty ? 'Default language' : data.language)} &middot; $generatedAt</div>
    <div class="matchup">
      <div class="player"><span class="player-name">${_escape(data.whiteName)}</span><span class="accuracy">${_escape(whiteAccuracy)}</span><div class="meta">White accuracy</div></div>
      <div class="versus">VS</div>
      <div class="player black"><span class="player-name">${_escape(data.blackName)}</span><span class="accuracy">${_escape(blackAccuracy)}</span><div class="meta">Black accuracy</div></div>
    </div>
  </header>

  <section class="section card summary-card">
    $avatar
    <div>
      <div class="coach-name">${_escape(data.coachName)}</div>
      <div class="coach-role">${_escape(data.coachRole)}</div>
      <div class="speech">${_multiline(summary)}</div>
    </div>
  </section>

  <section class="section card stats-card">
    <div class="section-heading"><span class="section-icon">&#9638;</span><h2>Statistics List</h2></div>
    <div class="stats-grid">${_statCards(data)}</div>
  </section>

  <section class="moves-heading">
    <div class="eyebrow">Move by move</div>
    <h2>Grandeur Analysis</h2>
  </section>
  <div class="move-list">$moveCards</div>
  <footer>Generated by Chessnut Grandeur &middot; ${_escape(data.whiteName)} vs ${_escape(data.blackName)}</footer>
</main>
</body>
</html>''';
}

String _moveCard(
  GrandeurHtmlMove move,
  Map<String, String> pieceImageDataUris,
) {
  final moveNumber = (move.ply + 1) ~/ 2;
  final moveLabel = move.ply.isOdd ? '$moveNumber.' : '$moveNumber...';
  final classification = move.classification.trim().isEmpty
      ? 'Unclassified'
      : move.classification.trim();
  final qualityColor = _classificationColor(classification);
  final badges = [
    '<span class="badge">${_escape(classification)}</span>',
    if (move.tag.trim().isNotEmpty && move.tag.trim() != classification)
      '<span class="badge">${_escape(move.tag.trim())}</span>',
  ].join();
  final details = [
    if (move.betterMove.trim().isNotEmpty)
      _detail('Better move', move.betterMove),
    if (move.purpose.trim().isNotEmpty) _detail('Purpose', move.purpose),
    if (move.why.trim().isNotEmpty) _detail('Why', move.why),
  ].join();
  final commentary = move.commentary.trim().isEmpty
      ? 'No commentary is available for this move.'
      : move.commentary.trim();
  return '''<article class="card move-card" style="--quality: $qualityColor">
    ${_board(move.fen, pieceImageDataUris)}
    <div>
      <div class="move-top"><span class="move-name">${_escape(moveLabel)} ${_escape(move.san)}</span>$badges</div>
      <div class="commentary">${_multiline(commentary)}</div>
      ${details.isEmpty ? '' : '<div class="details">$details</div>'}
    </div>
  </article>''';
}

String _board(String fen, Map<String, String> pieceImageDataUris) {
  final placement = fen.trim().split(RegExp(r'\s+')).first;
  final ranks = placement.split('/');
  if (ranks.length != 8) {
    return '<div class="empty-board">Board position unavailable</div>';
  }

  final squares = <String>[];
  for (var rank = 0; rank < 8; rank++) {
    final pieces = <String>[];
    for (final character in ranks[rank].split('')) {
      final empty = int.tryParse(character);
      if (empty != null) {
        pieces.addAll(List<String>.filled(empty, ''));
      } else {
        pieces.add(character);
      }
    }
    if (pieces.length != 8) {
      return '<div class="empty-board">Board position unavailable</div>';
    }
    for (var file = 0; file < 8; file++) {
      final shade = (rank + file).isEven ? 'light' : 'dark';
      final piece = pieces[file];
      final imageDataUri = pieceImageDataUris[_pieceAssetName(piece)] ?? '';
      final image = imageDataUri.isEmpty
          ? ''
          : '<img class="piece-image" src="${_escape(imageDataUri)}" alt="${_escape(piece)}">';
      squares.add('<span class="square $shade">$image</span>');
    }
  }
  return '<div class="board" role="img" aria-label="Position after move">${squares.join()}</div>';
}

String _pieceAssetName(String piece) {
  if (!RegExp(r'^[kqrbnpKQRBNP]$').hasMatch(piece)) return '';
  final color = piece == piece.toUpperCase() ? 'w' : 'b';
  return '$color${piece.toUpperCase()}.svg';
}

String _statCards(GrandeurHtmlReportData data) {
  // `whiteCounts` and `blackCounts` contain the raw tag keys from
  // statistics.{white,black}.tags.  Render only keys that actually occur in
  // the JSON and map them according to the Grandeur response PDF.
  final present = <String>{
    ...data.whiteCounts.keys.map(_normalizeGrandeurTag),
    ...data.blackCounts.keys.map(_normalizeGrandeurTag),
  }.where((key) => key.isNotEmpty).toSet();
  final ordered = <String>[
    ...const ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'].where(present.contains),
    ...present
        .where((key) =>
            !const {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'}.contains(key))
        .toList()
      ..sort(),
  ];
  if (ordered.isEmpty) {
    return '<div class="meta">No move statistics are available.</div>';
  }
  return ordered.map((key) {
    final label = _grandeurTagLabel(key);
    final color = _grandeurTagColor(key);
    final whiteCount = _countForTag(data.whiteCounts, key);
    final blackCount = _countForTag(data.blackCounts, key);
    return '<div class="stat" style="--quality: $color"><span class="dot"></span><span class="stat-label">${_escape(label)}</span><span class="side-count" title="White">$whiteCount</span><span class="side-count black" title="Black">$blackCount</span></div>';
  }).join();
}

String _grandeurTagLabel(String key) {
  return switch (key) {
    'a' => 'Brilliant',
    'b' => 'Great',
    'c' => 'Best',
    'd' => 'Accurate',
    'e' => 'Normal',
    'f' => 'Inaccuracy',
    'g' => 'Mistake',
    'h' => 'Blunder',
    _ => key,
  };
}

String _grandeurTagColor(String key) {
  return switch (key) {
    'a' => '#34d399',
    'b' => '#22d3ee',
    'c' => '#a3e635',
    'd' => '#84cc16',
    'e' => '#64748b',
    'f' => '#eac84a',
    'g' => '#f0a252',
    'h' => '#e2574c',
    _ => '#64748b',
  };
}

int _countForTag(Map<String, int> counts, String key) {
  for (final entry in counts.entries) {
    if (_normalizeGrandeurTag(entry.key) == key) return entry.value;
  }
  return 0;
}

String _normalizeGrandeurTag(String value) {
  final key = value.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');
  return switch (key) {
    'a' || 'brilliant' => 'a',
    'b' || 'great' => 'b',
    'c' || 'best' => 'c',
    'd' || 'accurate' || 'excellent' => 'd',
    'e' || 'normal' || 'good' => 'e',
    'f' || 'inaccuracy' || 'inaccurate' || '不准确' || '不準確' => 'f',
    'g' || 'mistake' || '错误' || '錯誤' => 'g',
    'h' || 'blunder' || '失误' || '失誤' => 'h',
    _ => key,
  };
}

String _detail(String label, String value) =>
    '<div class="detail"><span class="detail-label">${_escape(label)}</span>${_multiline(value.trim())}</div>';

String _classificationColor(String classification) {
  switch (_classificationKey(classification)) {
    case 'brilliant':
      return '#34d399';
    case 'great':
      return '#22d3ee';
    case 'best':
      return '#a3e635';
    case 'excellent':
      return '#84cc16';
    case 'good':
      return '#2dd4bf';
    case 'inaccuracy':
      return '#eac84a';
    case 'mistake':
      return '#f0a252';
    case 'missed win':
      return '#fb923c';
    case 'blunder':
      return '#e2574c';
    case 'book':
      return '#a855f7';
    default:
      return '#64748b';
  }
}

String _classificationKey(String classification) {
  final value =
      classification.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');
  if (_containsAny(value, const [
    'brilliant',
    '精彩',
    '神来之笔',
    '神來之筆',
    'brillante',
    'brillant',
  ])) {
    return 'brilliant';
  }
  if (_containsAny(value, const [
    'great',
    '很棒',
    '出色',
    'genial',
    'super',
    'ottimo',
    'отлично',
    '훌륭',
  ])) {
    return 'great';
  }
  if (_containsAny(value, const [
    'missedwin',
    '错失胜机',
    '錯過勝機',
    'gewinnverpasst',
    'victoriaperdida',
    'gemistewinst',
    'упущеннаяпобеда',
  ])) {
    return 'missed win';
  }
  if (_containsAny(value, const [
    'blunder',
    '失误',
    '失誤',
    '重大失误',
    '重大失誤',
    '严重失误',
    '嚴重失誤',
    'patzer',
    'gaf',
    'errograve',
    'грубаяошибка',
  ])) {
    return 'blunder';
  }
  if (_containsAny(value, const [
    'inaccuracy',
    '不准确',
    '不準確',
    '不精确',
    '不精確',
    '不正確',
    'imprecision',
    'imprecis',
    'ungena',
    'inexact',
    'неточ',
    '부정확',
  ])) {
    return 'inaccuracy';
  }
  if (_containsAny(value, const [
    'mistake',
    '错误',
    '錯誤',
    'erreur',
    'erro',
    'fehler',
    'greșeală',
    'błąd',
    'ошибка',
    '실수',
  ])) {
    return 'mistake';
  }
  if (_containsAny(value, const [
    'excellent',
    '优秀',
    '優秀',
    'ausgezeichnet',
    'excelente',
    'eccellente',
    'uitstekend',
    'отличный',
    '우수',
  ])) {
    return 'excellent';
  }
  if (_containsAny(value, const [
    'best',
    '最佳',
    '最善',
    'meilleur',
    'mejor',
    'migliore',
    'лучший',
  ])) {
    return 'best';
  }
  if (_containsAny(value, const [
    'book',
    '开局书',
    '開局書',
    '理论',
    '理論',
    'öffnung',
    'apertura',
    'ouverture',
  ])) {
    return 'book';
  }
  if (_containsAny(value, const [
    'good',
    '正常',
    '准确',
    '準確',
    '良好',
    '精确',
    '精確',
    'accurate',
    'gut',
    'buono',
    'bon',
    'goed',
    'хорошо',
    '良い',
    '좋음',
  ])) {
    return 'good';
  }
  return value;
}

bool _containsAny(String value, List<String> candidates) {
  return candidates.any(value.contains);
}

String _cssColor(String value) {
  final normalized = value.trim().toLowerCase();
  return RegExp(r'^#[0-9a-f]{6}$').hasMatch(normalized)
      ? normalized
      : '#8b6dff';
}

String _rgba(String hex, double opacity) {
  final value = int.parse(hex.substring(1), radix: 16);
  final red = (value >> 16) & 0xff;
  final green = (value >> 8) & 0xff;
  final blue = value & 0xff;
  return 'rgba($red, $green, $blue, $opacity)';
}

String _multiline(String value) => _escape(value).replaceAll('\n', '<br>');

String _escape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
