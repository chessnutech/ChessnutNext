import 'model_build_policy.dart';

const int _modelBuildPreviewPgnSampleLimit = 20;

class ModelBuildPreview {
  const ModelBuildPreview({
    required this.gameCount,
    required this.pgn,
    required this.sourceLabel,
  });

  factory ModelBuildPreview.fromJson(Map<String, dynamic> json) {
    final pgn = _previewPgn(json);
    final gameCount = _previewGameCount(json, pgn);
    return ModelBuildPreview(
      gameCount: gameCount,
      pgn: pgn,
      sourceLabel: _string(
        json['source_label'] ??
            json['sourceLabel'] ??
            json['player_id'] ??
            json['playerId'] ??
            json['message'],
      ),
    );
  }

  final int gameCount;
  final String pgn;
  final String sourceLabel;
}

int _previewGameCount(Map<String, dynamic> json, String pgn) {
  final explicit = _int(
    json['usable_count'] ??
        json['usableCount'] ??
        json['matched_count'] ??
        json['matchedCount'] ??
        json['processed_count'] ??
        json['processedCount'] ??
        json['requested_count'] ??
        json['requestedCount'] ??
        json['total_count'] ??
        json['totalCount'] ??
        json['total'] ??
        json['game_count'] ??
        json['gameCount'] ??
        json['count'],
  );
  if (explicit > 0) return explicit;
  final games = _previewGameList(json);
  if (games.isNotEmpty) return games.length;
  return countModelBuildPgnGames(pgn);
}

String _previewPgn(Map<String, dynamic> json) {
  final direct = _string(
    json['pgn'] ??
        json['raw_pgn'] ??
        json['rawPgn'] ??
        json['preview_pgn'] ??
        json['previewPgn'] ??
        json['sample_pgn'] ??
        json['samplePgn'],
  );
  if (direct.trim().isNotEmpty) return direct;
  final games = _previewGameList(json);
  if (games.isEmpty) return '';
  final samples = <String>[];
  for (final item in games) {
    final pgn = _pgnFromPreviewItem(item);
    if (pgn.isEmpty) continue;
    samples.add(pgn);
    if (samples.length >= _modelBuildPreviewPgnSampleLimit) break;
  }
  return samples.join('\n\n\n');
}

List<Object?> _previewGameList(Map<String, dynamic> json) {
  return _list(
    json['pgn_list'] ??
        json['pgnList'] ??
        json['preview_games'] ??
        json['previewGames'] ??
        json['sample_games'] ??
        json['sampleGames'] ??
        json['games'],
  );
}

String _pgnFromPreviewItem(Object? item) {
  if (item is String) return item.trim();
  if (item is Map) {
    return _string(
      item['pgn'] ??
          item['raw_pgn'] ??
          item['rawPgn'] ??
          item['content'] ??
          item['text'],
    ).trim();
  }
  return '';
}

int countModelBuildPgnGames(String pgn) {
  final eventHeaders =
      RegExp(r'^\[Event\s+"', multiLine: true).allMatches(pgn).length;
  if (eventHeaders > 0) return eventHeaders;
  return RegExp(r'\s(1-0|0-1|1/2-1/2|\*)\s').allMatches(' $pgn ').length;
}

String mergeModelBuildPgnFiles(Iterable<String> pgnFiles) {
  return pgnFiles
      .map((pgn) => pgn.trim())
      .where((pgn) => pgn.isNotEmpty)
      .join('\n\n\n');
}

String addModelBuildTrainTag(
  String pgn, {
  required String playerName,
  String? whiteName,
  String? blackName,
}) {
  final player = _normalizedPlayerName(playerName);
  if (player.isEmpty || pgn.trim().isEmpty) return pgn;

  final white = _normalizedPlayerName(
    _resolvedPlayerName(pgn, 'White', whiteName),
  );
  final black = _normalizedPlayerName(
    _resolvedPlayerName(pgn, 'Black', blackName),
  );
  final trainSide = white == player
      ? 'w'
      : black == player
          ? 'b'
          : null;
  if (trainSide == null) return pgn;

  final trainTag = '[Train "$trainSide"]';
  final existingTrainTag = RegExp(
    r'^\[Train[ \t]+"[^"]*"\][ \t]*',
    multiLine: true,
    caseSensitive: false,
  ).firstMatch(pgn);
  if (existingTrainTag != null) {
    return pgn.replaceRange(
      existingTrainTag.start,
      existingTrainTag.end,
      trainTag,
    );
  }

  final headerMatches = RegExp(
    r'^\[[A-Za-z0-9_]+[ \t]+"[^"]*"\][ \t]*',
    multiLine: true,
  ).allMatches(pgn).toList(growable: false);
  if (headerMatches.isEmpty) return pgn;
  final newline = pgn.contains('\r\n') ? '\r\n' : '\n';
  final insertAt = headerMatches.last.end;
  return pgn.replaceRange(insertAt, insertAt, '$newline$trainTag');
}

bool isModelBuildGameCountSubmittable(int gameCount) {
  return gameCount >= modelBuildMinimumGameCount &&
      gameCount <= modelBuildMaximumGameCount;
}

bool isModelBuildGameCountRecommended(int gameCount) {
  return gameCount >= modelBuildRecommendedGameCount;
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _string(Object? value) => value?.toString() ?? '';

List<Object?> _list(Object? value) {
  if (value is List) return value;
  return const [];
}

String _resolvedPlayerName(String pgn, String header, String? fallback) {
  final value = _pgnHeaderValue(pgn, header);
  return value.isEmpty ? fallback?.trim() ?? '' : value;
}

String _normalizedPlayerName(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String _pgnHeaderValue(String pgn, String header) {
  final match = RegExp(
    '^\\[${RegExp.escape(header)}[ \\t]+"([^"]*)"\\]',
    multiLine: true,
    caseSensitive: false,
  ).firstMatch(pgn);
  return match?.group(1)?.trim() ?? '';
}
