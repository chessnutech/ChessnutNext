import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/app_models.dart';
import 'chessnut_api_client.dart';

const String maia3HumanReviewCacheVersion = 'maia3-human-review-policy-v3';
// Bump when move-quality classification changes so cached reports are
// regenerated with the current Lichess winning-chance scoring rules.
const int standardAnalysisAlgorithmVersion = 10;

class GameAnalysisReportStatus {
  const GameAnalysisReportStatus({
    this.standard = false,
    this.grandeur = false,
    this.maia3 = false,
    bool? grandeurReady,
  }) : grandeurReady = grandeurReady ?? grandeur;

  final bool standard;
  final bool grandeur;
  final bool grandeurReady;
  final bool maia3;

  bool get hasAny => standard || grandeur || maia3;
}

class CachedReviewMove {
  const CachedReviewMove({
    required this.ply,
    required this.move,
    required this.evalBefore,
    required this.evalAfter,
    required this.classification,
    required this.summary,
    required this.fen,
    required this.lastMove,
    required this.focusSquare,
    required this.engineLine,
    required this.bestMove,
    required this.keyMoment,
    this.engineDepth,
    this.scoreMapAccuracy,
    this.scoreMapLevel,
    this.isEngineBacked = false,
    this.candidateVariations = const [],
  });

  final int ply;
  final String move;
  final double evalBefore;
  final double evalAfter;
  final String classification;
  final String summary;
  final String fen;
  final List<String> lastMove;
  final String focusSquare;
  final String engineLine;
  final String bestMove;
  final bool keyMoment;
  final int? engineDepth;
  final double? scoreMapAccuracy;
  final int? scoreMapLevel;
  final bool isEngineBacked;
  final List<CachedEngineVariation> candidateVariations;

  Map<String, dynamic> toJson() {
    return {
      'ply': ply,
      'move': move,
      'eval_before': evalBefore,
      'eval_after': evalAfter,
      'classification': classification,
      'summary': summary,
      'fen': fen,
      'last_move': lastMove,
      'focus_square': focusSquare,
      'engine_line': engineLine,
      'best_move': bestMove,
      'key_moment': keyMoment,
      'engine_depth': engineDepth,
      'score_map_accuracy': scoreMapAccuracy,
      'score_map_level': scoreMapLevel,
      'is_engine_backed': isEngineBacked,
      'candidate_variations': candidateVariations
          .map((variation) => variation.toJson())
          .toList(growable: false),
    };
  }

  factory CachedReviewMove.fromJson(Map<String, dynamic> json) {
    final lastMove = _first(json, const ['last_move', 'lastMove']);
    return CachedReviewMove(
      ply: _firstInt(json, const ['ply', 'move_ply', 'movePly']),
      move: _firstString(json, const ['move', 'san']),
      evalBefore: _firstDouble(json, const ['eval_before', 'evalBefore']),
      evalAfter: _firstDouble(json, const ['eval_after', 'evalAfter']),
      classification: _firstString(json, const [
        'classification',
        'tag',
        'label',
        'quality',
      ]),
      summary: _firstString(json, const ['summary', 'commentary', 'comment']),
      fen: _firstString(json, const ['fen', 'fen_after', 'fenAfter']),
      lastMove: lastMove is List
          ? lastMove.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      focusSquare: _firstString(json, const ['focus_square', 'focusSquare']),
      engineLine: _firstString(json, const ['engine_line', 'engineLine', 'pv']),
      bestMove: _firstString(json, const [
        'best_move',
        'bestMove',
        'best_move_san',
        'bestMoveSan',
        'better_move',
        'betterMove',
      ]),
      keyMoment: _firstBool(json, const ['key_moment', 'keyMoment']),
      engineDepth: _firstNullableInt(
        json,
        const ['engine_depth', 'engineDepth'],
      ),
      scoreMapAccuracy: _firstNullableDouble(
        json,
        const ['score_map_accuracy', 'scoreMapAccuracy'],
      ),
      scoreMapLevel: _firstNullableInt(
        json,
        const ['score_map_level', 'scoreMapLevel'],
      ),
      isEngineBacked:
          _firstBool(json, const ['is_engine_backed', 'isEngineBacked']),
      candidateVariations: switch (json['candidate_variations']) {
        final List items => items
            .whereType<Map>()
            .map((item) => CachedEngineVariation.fromJson(
                  item.cast<String, dynamic>(),
                ))
            .toList(growable: false),
        _ => const [],
      },
    );
  }
}

class CachedEngineVariation {
  const CachedEngineVariation({
    required this.moveUci,
    required this.line,
    required this.whiteEval,
    this.whiteMate,
  });

  final String moveUci;
  final String line;
  final double whiteEval;
  final int? whiteMate;

  Map<String, dynamic> toJson() => {
        'move_uci': moveUci,
        'line': line,
        'white_eval': whiteEval,
        'white_mate': whiteMate,
      };

  factory CachedEngineVariation.fromJson(Map<String, dynamic> json) {
    return CachedEngineVariation(
      moveUci: _string(json['move_uci']),
      line: _string(json['line']),
      whiteEval: _double(json['white_eval']),
      whiteMate: json['white_mate'] == null ? null : _int(json['white_mate']),
    );
  }
}

class GameStandardAnalysisReport {
  const GameStandardAnalysisReport({
    required this.moves,
    required this.stockfishBacked,
    required this.stockfishStatus,
    required this.generatedAt,
    this.analysisDepth = 16,
    this.isComplete = true,
    this.algorithmVersion = standardAnalysisAlgorithmVersion,
  });

  final List<CachedReviewMove> moves;
  final bool stockfishBacked;
  final String stockfishStatus;
  final DateTime generatedAt;
  final int analysisDepth;
  final bool isComplete;
  final int algorithmVersion;

  bool get usesCurrentAlgorithm =>
      algorithmVersion == standardAnalysisAlgorithmVersion && isComplete;

  Map<String, dynamic> toJson() {
    return {
      'moves': moves.map((move) => move.toJson()).toList(growable: false),
      'stockfish_backed': stockfishBacked,
      'stockfish_status': stockfishStatus,
      'generated_at': generatedAt.toIso8601String(),
      'analysis_depth': analysisDepth,
      'is_complete': isComplete,
      'algorithm_version': algorithmVersion,
    };
  }

  factory GameStandardAnalysisReport.fromJson(Map<String, dynamic> json) {
    final rawMoves = json['moves'];
    return GameStandardAnalysisReport(
      moves: rawMoves is List
          ? rawMoves
              .whereType<Map>()
              .map((item) => CachedReviewMove.fromJson(
                    item.cast<String, dynamic>(),
                  ))
              .toList(growable: false)
          : const <CachedReviewMove>[],
      stockfishBacked: json['stockfish_backed'] == true,
      stockfishStatus: _string(json['stockfish_status']),
      generatedAt: DateTime.tryParse(_string(json['generated_at'])) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      analysisDepth: _standardAnalysisDepth(json['analysis_depth']),
      isComplete: json['is_complete'] == true,
      algorithmVersion: _int(json['algorithm_version']),
    );
  }
}

class GameAnalysisReportCacheEntry {
  const GameAnalysisReportCacheEntry({
    this.pgn = '',
    this.standardReport,
    this.grandeurReport,
    this.maia3Report,
    this.grandeurUnlocked = false,
    this.grandeurCommentId = 0,
    this.grandeurStyleId = '',
    this.serverPgnId = 0,
    this.updatedAt,
  });

  final String pgn;
  final GameStandardAnalysisReport? standardReport;
  final GrandeurAnalysisResult? grandeurReport;
  final Maia3HumanReviewReport? maia3Report;
  final bool grandeurUnlocked;
  final int grandeurCommentId;
  final String grandeurStyleId;
  final int serverPgnId;
  final DateTime? updatedAt;

  bool get hasStandard => standardReport != null;
  bool get hasGrandeur =>
      grandeurReport != null || grandeurUnlocked || grandeurCommentId > 0;
  bool get hasMaia3 => maia3Report != null;

  GameAnalysisReportStatus get status => GameAnalysisReportStatus(
        standard: hasStandard,
        grandeur: hasGrandeur,
        grandeurReady: grandeurReport != null,
        maia3: hasMaia3,
      );

  GameAnalysisReportCacheEntry copyWith({
    String? pgn,
    GameStandardAnalysisReport? standardReport,
    GrandeurAnalysisResult? grandeurReport,
    Maia3HumanReviewReport? maia3Report,
    bool? grandeurUnlocked,
    int? grandeurCommentId,
    String? grandeurStyleId,
    int? serverPgnId,
    DateTime? updatedAt,
  }) {
    return GameAnalysisReportCacheEntry(
      pgn: pgn ?? this.pgn,
      standardReport: standardReport ?? this.standardReport,
      grandeurReport: grandeurReport ?? this.grandeurReport,
      maia3Report: maia3Report ?? this.maia3Report,
      grandeurUnlocked: grandeurUnlocked ?? this.grandeurUnlocked,
      grandeurCommentId: grandeurCommentId ?? this.grandeurCommentId,
      grandeurStyleId: grandeurStyleId ?? this.grandeurStyleId,
      serverPgnId: serverPgnId ?? this.serverPgnId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pgn': pgn,
      'standard_report': standardReport?.toJson(),
      'grandeur_report': grandeurReport == null
          ? null
          : grandeurAnalysisResultToJson(grandeurReport!),
      'maia3_report': maia3Report == null
          ? null
          : maia3HumanReviewReportToJson(maia3Report!),
      'grandeur_unlocked': grandeurUnlocked,
      'grandeur_comment_id': grandeurCommentId,
      'grandeur_style_id': grandeurStyleId,
      'server_pgn_id': serverPgnId,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory GameAnalysisReportCacheEntry.fromJson(Map<String, dynamic> json) {
    final standard = json['standard_report'];
    final grandeur = json['grandeur_report'];
    final maia3 = json['maia3_report'];
    final parsedStandard = standard is Map
        ? GameStandardAnalysisReport.fromJson(
            standard.cast<String, dynamic>(),
          )
        : null;
    return GameAnalysisReportCacheEntry(
      pgn: _string(json['pgn']),
      standardReport:
          parsedStandard?.usesCurrentAlgorithm == true ? parsedStandard : null,
      grandeurReport: grandeur is Map
          ? GrandeurAnalysisResult.fromJson(grandeur.cast<String, dynamic>())
          : null,
      maia3Report: maia3 is Map
          ? Maia3HumanReviewReport.fromJson(maia3.cast<String, dynamic>())
          : null,
      grandeurUnlocked: json['grandeur_unlocked'] == true,
      grandeurCommentId: _int(json['grandeur_comment_id']),
      grandeurStyleId: _string(json['grandeur_style_id']),
      serverPgnId: _int(json['server_pgn_id']),
      updatedAt: DateTime.tryParse(_string(json['updated_at'])),
    );
  }
}

String gameAnalysisReportCacheKeyForRecord(GameRecord record) {
  final id = record.pgnId;
  if (id != null) return 'pgn:$id';
  final shareId = record.shareId?.trim();
  if (shareId != null && shareId.isNotEmpty) return 'share:$shareId';
  return gameAnalysisReportCacheKeyForPgn(record.pgn);
}

List<String> gameAnalysisReportCacheKeysForRecord(GameRecord record) {
  final keys = <String>[
    gameAnalysisReportCacheKeyForRecord(record),
    if (record.shareId?.trim().isNotEmpty == true)
      'share:${record.shareId!.trim()}',
    gameAnalysisReportCacheKeyForPgn(record.pgn),
  ];
  return List.unmodifiable(keys.toSet());
}

String gameAnalysisReportCacheKeyWithBestReport(
  GameRecord record,
  Map<String, GameAnalysisReportCacheEntry> reports,
) {
  final primaryKey = gameAnalysisReportCacheKeyForRecord(record);
  var bestKey = primaryKey;
  var bestScore = -1;
  for (final key in gameAnalysisReportCacheKeysForRecord(record)) {
    final report = reports[key];
    if (report == null) continue;
    final score = _analysisReportCompletenessScore(report);
    if (score > bestScore) {
      bestKey = key;
      bestScore = score;
    }
  }
  return bestKey;
}

int _analysisReportCompletenessScore(GameAnalysisReportCacheEntry report) {
  if (report.grandeurReport != null) return 500;
  if (report.grandeurCommentId > 0) return 400;
  if (report.grandeurUnlocked) return 300;
  if (report.maia3Report != null) return 200;
  if (report.standardReport != null) return 100;
  return 0;
}

String gameAnalysisReportCacheKeyForPgn(String pgn) {
  final normalized = pgn.trim().replaceAll(RegExp(r'\s+'), ' ');
  final digest = sha1.convert(utf8.encode(normalized));
  return 'pgnhash:$digest';
}

bool gameAnalysisReportCacheEntryMatchesPgn(
  GameAnalysisReportCacheEntry entry,
  String pgn,
) {
  final cachedPgn = entry.pgn.trim();
  final currentPgn = pgn.trim();
  if (cachedPgn.isEmpty || currentPgn.isEmpty) return false;
  return gameAnalysisReportCacheKeyForPgn(cachedPgn) ==
      gameAnalysisReportCacheKeyForPgn(currentPgn);
}

String maia3HumanReviewCacheKey(String baseKey) {
  return '$baseKey:$maia3HumanReviewCacheVersion';
}

String maia3HumanReviewSettingsCacheKey(
  String cacheKey, {
  int elo = 1500,
  String model = 'maia3-5m',
  int multiPv = 5,
}) {
  final normalizedModel = model.trim().isEmpty ? 'maia3-5m' : model.trim();
  final normalizedMultiPv = multiPv <= 0 ? 5 : multiPv;
  return '$cacheKey:elo-$elo:model-$normalizedModel:multipv-$normalizedMultiPv';
}

GameAnalysisReportStatus gameAnalysisReportStatusForRecord(
  GameRecord record,
  Map<String, GameAnalysisReportStatus> statuses,
) {
  final shareId = record.shareId?.trim();
  final primaryKey = gameAnalysisReportCacheKeyForRecord(record);
  final pgnKey = gameAnalysisReportCacheKeyForPgn(record.pgn);
  final primaryStatus = statuses[primaryKey];
  final shareStatus =
      shareId == null || shareId.isEmpty ? null : statuses['share:$shareId'];
  final pgnHashStatus = statuses[pgnKey];
  final hasBoundGrandeur = record.commentId > 0;
  return GameAnalysisReportStatus(
    standard: primaryStatus?.standard == true ||
        shareStatus?.standard == true ||
        pgnHashStatus?.standard == true,
    grandeur: hasBoundGrandeur,
    grandeurReady: hasBoundGrandeur,
    maia3: _hasMaia3StatusForKey(statuses, primaryKey) ||
        (shareId != null &&
            shareId.isNotEmpty &&
            _hasMaia3StatusForKey(statuses, 'share:$shareId')) ||
        _hasMaia3StatusForKey(statuses, pgnKey),
  );
}

bool _hasMaia3StatusForKey(
  Map<String, GameAnalysisReportStatus> statuses,
  String baseKey,
) {
  final maia3BaseKey = maia3HumanReviewCacheKey(baseKey);
  if (statuses[maia3BaseKey]?.maia3 == true) return true;
  final settingsPrefix = '$maia3BaseKey:';
  return statuses.entries.any(
    (entry) => entry.key.startsWith(settingsPrefix) && entry.value.maia3,
  );
}

List<GameRecord> gameAnalysisRecordsFromCache(
  Map<String, GameAnalysisReportCacheEntry> reports,
) {
  final entries = reports.entries
      .where((entry) =>
          entry.value.pgn.trim().isNotEmpty &&
          entry.value.serverPgnId <= 0 &&
          !entry.key.startsWith('pgn:') &&
          !entry.key.startsWith('share:'))
      .toList(growable: false)
    ..sort((a, b) {
      final aTime = a.value.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.value.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

  final records = <GameRecord>[];
  for (final entry in entries) {
    final cache = entry.value;
    final pgn = cache.pgn.trim();
    records.add(_gameRecordFromCachedAnalysis(entry.key, cache, pgn));
  }
  return List.unmodifiable(records);
}

GameRecord _gameRecordFromCachedAnalysis(
  String key,
  GameAnalysisReportCacheEntry cache,
  String pgn,
) {
  final headers = _pgnHeaders(pgn);
  final white = _fallbackHeader(headers, 'White', 'White');
  final black = _fallbackHeader(headers, 'Black', 'Black');
  final result = _fallbackHeader(headers, 'Result', '*');
  final source = cache.hasGrandeur
      ? 'Analysis / Grandeur'
      : cache.hasMaia3
          ? 'Analysis / Maia3'
          : cache.hasStandard
              ? 'Analysis'
              : 'Analysis / Draft';
  final updatedAt = cache.updatedAt;
  final title = '$white vs $black';
  final subtitle =
      updatedAt == null ? source : '$source / ${_dateLabel(updatedAt)}';
  return GameRecord(
    result: result,
    title: title,
    subtitle: subtitle,
    pgn: pgn,
    playMode: 'analysis',
    gameStatus: result == '*' ? 1 : 2,
    gameStep: _plyCount(pgn),
    winId: switch (result) {
      '1-0' => 1,
      '0-1' => 2,
      '1/2-1/2' => 3,
      _ => 0,
    },
    whiteName: white,
    blackName: black,
    sortAt: updatedAt,
  );
}

Map<String, String> _pgnHeaders(String pgn) {
  final headers = <String, String>{};
  final pattern = RegExp(r'^\[([A-Za-z0-9_]+)\s+"(.*)"\]$', multiLine: true);
  for (final match in pattern.allMatches(pgn)) {
    headers[match.group(1)!] = match.group(2)!.replaceAll(r'\"', '"');
  }
  return headers;
}

String _fallbackHeader(
    Map<String, String> headers, String key, String fallback) {
  final value = headers[key]?.trim();
  return value == null || value.isEmpty || value == '?' ? fallback : value;
}

int _plyCount(String pgn) {
  final withoutHeaders =
      pgn.replaceAll(RegExp(r'^\[.*\]$', multiLine: true), ' ');
  final withoutComments = withoutHeaders.replaceAll(RegExp(r'\{[^}]*\}'), ' ');
  final tokens = withoutComments.split(RegExp(r'\s+'));
  var count = 0;
  for (final token in tokens) {
    final clean = token.trim();
    if (clean.isEmpty ||
        clean == '1-0' ||
        clean == '0-1' ||
        clean == '1/2-1/2' ||
        clean == '*') {
      continue;
    }
    if (RegExp(r'^\d+\.(\.\.)?$').hasMatch(clean)) continue;
    if (clean.startsWith('\$')) continue;
    count++;
  }
  return count;
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

Map<String, dynamic> grandeurAnalysisResultToJson(
  GrandeurAnalysisResult result,
) {
  return {
    'analysis_id': result.analysisId,
    'language': result.language,
    'summary': result.summary,
    'statistics': result.statistics,
    'moves': result.moves
        .map(
          (move) => {
            'ply': move.ply,
            'san': move.san,
            'tag': move.tag,
            'commentary': move.commentary,
            'language': move.language,
            // Legacy fields for backward compatibility
            'purpose': move.purpose,
            'why': move.why,
            'better_move': move.betterMove,
            'classification': move.classification,
          },
        )
        .toList(growable: false),
  };
}

Map<String, dynamic> maia3HumanReviewReportToJson(
  Maia3HumanReviewReport result,
) {
  return {
    'version': result.version,
    'source': result.source,
    'model': result.model,
    'elo': result.elo,
    'generated_at': result.generatedAt.toIso8601String(),
    'summary': {
      'human_match_percent': result.summary.humanMatchPercent,
      'most_human_side': result.summary.mostHumanSide,
      'sharpest_moments': result.summary.sharpestMoments,
      'notes': result.summary.notes,
    },
    'moves': result.moves
        .map(
          (move) => {
            'ply': move.ply,
            'move': move.move,
            'move_uci': move.moveUci,
            'fen': move.fen,
            'last_move': move.lastMove,
            'played_probability': move.playedProbability,
            'typicality': move.typicality,
            'human_label': move.humanLabel,
            'candidates': move.candidates
                .map(
                  (candidate) => {
                    'move': candidate.move,
                    'san': candidate.san,
                    'probability': candidate.probability,
                    'wdl': candidate.wdl,
                    'centipawns': candidate.centipawns,
                  },
                )
                .toList(growable: false),
          },
        )
        .toList(growable: false),
  };
}

String _string(Object? value) => value?.toString() ?? '';

Object? _first(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key)) return json[key];
  }
  return null;
}

String _firstString(Map<String, dynamic> json, List<String> keys) {
  return _string(_first(json, keys));
}

int _firstInt(Map<String, dynamic> json, List<String> keys) {
  return _int(_first(json, keys));
}

int? _firstNullableInt(Map<String, dynamic> json, List<String> keys) {
  final value = _first(json, keys);
  return value == null ? null : _int(value);
}

double _firstDouble(Map<String, dynamic> json, List<String> keys) {
  return _double(_first(json, keys));
}

double? _firstNullableDouble(Map<String, dynamic> json, List<String> keys) {
  final value = _first(json, keys);
  return value == null ? null : _double(value);
}

bool _firstBool(Map<String, dynamic> json, List<String> keys) {
  final value = _first(json, keys);
  if (value is bool) return value;
  final text = value?.toString().toLowerCase();
  return text == 'true' || text == '1';
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _double(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _standardAnalysisDepth(Object? value) {
  final depth = _int(value);
  return depth >= 6 && depth <= 20 ? depth : 16;
}
