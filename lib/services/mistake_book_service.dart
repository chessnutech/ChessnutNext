import 'package:dartchess/dartchess.dart' as dc;

import 'analysis_report_cache_service.dart';
import 'app_preferences_store.dart';
import 'game_notation_service.dart';

class MistakeBookEntry {
  const MistakeBookEntry({
    required this.id,
    required this.reportKey,
    required this.pgn,
    required this.sourceTitle,
    required this.ply,
    required this.moveSan,
    required this.bestMoveSan,
    required this.classification,
    required this.summary,
    required this.theme,
    required this.fenBefore,
    required this.fenAfter,
    required this.engineLine,
    required this.createdAt,
    required this.updatedAt,
    required this.dueAt,
    this.correctStreak = 0,
    this.reviewCount = 0,
    this.mastered = false,
  });

  final String id;
  final String reportKey;
  final String pgn;
  final String sourceTitle;
  final int ply;
  final String moveSan;
  final String bestMoveSan;
  final String classification;
  final String summary;
  final String theme;
  final String fenBefore;
  final String fenAfter;
  final String engineLine;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime dueAt;
  final int correctStreak;
  final int reviewCount;
  final bool mastered;

  bool isDue(DateTime now) => !mastered && !dueAt.isAfter(now);

  MistakeBookEntry copyWith({
    String? pgn,
    String? sourceTitle,
    String? moveSan,
    String? bestMoveSan,
    String? classification,
    String? summary,
    String? theme,
    String? fenBefore,
    String? fenAfter,
    String? engineLine,
    DateTime? updatedAt,
    DateTime? dueAt,
    int? correctStreak,
    int? reviewCount,
    bool? mastered,
  }) {
    return MistakeBookEntry(
      id: id,
      reportKey: reportKey,
      pgn: pgn ?? this.pgn,
      sourceTitle: sourceTitle ?? this.sourceTitle,
      ply: ply,
      moveSan: moveSan ?? this.moveSan,
      bestMoveSan: bestMoveSan ?? this.bestMoveSan,
      classification: classification ?? this.classification,
      summary: summary ?? this.summary,
      theme: theme ?? this.theme,
      fenBefore: fenBefore ?? this.fenBefore,
      fenAfter: fenAfter ?? this.fenAfter,
      engineLine: engineLine ?? this.engineLine,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dueAt: dueAt ?? this.dueAt,
      correctStreak: correctStreak ?? this.correctStreak,
      reviewCount: reviewCount ?? this.reviewCount,
      mastered: mastered ?? this.mastered,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'report_key': reportKey,
      'pgn': pgn,
      'source_title': sourceTitle,
      'ply': ply,
      'move_san': moveSan,
      'best_move_san': bestMoveSan,
      'classification': classification,
      'summary': summary,
      'theme': theme,
      'fen_before': fenBefore,
      'fen_after': fenAfter,
      'engine_line': engineLine,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'due_at': dueAt.toIso8601String(),
      'correct_streak': correctStreak,
      'review_count': reviewCount,
      'mastered': mastered,
    };
  }

  factory MistakeBookEntry.fromJson(Map<String, dynamic> json) {
    return MistakeBookEntry(
      id: _string(json['id']),
      reportKey: _string(json['report_key']),
      pgn: _string(json['pgn']),
      sourceTitle: _string(json['source_title']),
      ply: _int(json['ply']),
      moveSan: _string(json['move_san']),
      bestMoveSan: _string(json['best_move_san']),
      classification: _string(json['classification']),
      summary: _string(json['summary']),
      theme: _string(json['theme']),
      fenBefore: _string(json['fen_before']),
      fenAfter: _string(json['fen_after']),
      engineLine: _string(json['engine_line']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      dueAt: _date(json['due_at']),
      correctStreak: _int(json['correct_streak']),
      reviewCount: _int(json['review_count']),
      mastered: json['mastered'] == true,
    );
  }
}

class MistakeBookState {
  const MistakeBookState({
    this.entries = const {},
    this.deletedIds = const {},
  });

  final Map<String, MistakeBookEntry> entries;
  final Set<String> deletedIds;

  int get total => entries.length;

  int get masteredCount =>
      entries.values.where((entry) => entry.mastered).length;

  List<MistakeBookEntry> due(DateTime now) {
    final dueEntries =
        entries.values.where((entry) => entry.isDue(now)).toList(growable: true)
          ..sort((a, b) {
            final dueCompare = a.dueAt.compareTo(b.dueAt);
            if (dueCompare != 0) return dueCompare;
            return _severity(b.classification)
                .compareTo(_severity(a.classification));
          });
    return List.unmodifiable(dueEntries);
  }

  Map<String, int> themeCounts() {
    final counts = <String, int>{};
    for (final entry in entries.values) {
      if (entry.mastered) continue;
      counts[entry.theme] = (counts[entry.theme] ?? 0) + 1;
    }
    return Map.unmodifiable(counts);
  }

  Map<String, dynamic> toJson() {
    return {
      'entries': {
        for (final entry in entries.entries) entry.key: entry.value.toJson(),
      },
      'deleted_ids': deletedIds.toList(growable: false),
    };
  }

  factory MistakeBookState.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    if (rawEntries is! Map) return const MistakeBookState();
    final entries = <String, MistakeBookEntry>{};
    for (final item in rawEntries.entries) {
      final value = item.value;
      if (value is! Map) continue;
      final entry = MistakeBookEntry.fromJson(
        value.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (entry.id.isNotEmpty) entries[entry.id] = entry;
    }
    final rawDeletedIds = json['deleted_ids'];
    final deletedIds = rawDeletedIds is List
        ? rawDeletedIds
            .map((value) => value.toString())
            .where((value) => value.isNotEmpty)
            .toSet()
        : <String>{};
    return MistakeBookState(
      entries: Map.unmodifiable(entries),
      deletedIds: Set.unmodifiable(deletedIds),
    );
  }
}

abstract interface class MistakeBookStore {
  Future<MistakeBookState> read();

  Future<void> syncFromAnalysisReports(
    Map<String, GameAnalysisReportCacheEntry> reports, {
    DateTime? now,
  });

  Future<void> recordReview(
    String id, {
    required bool correct,
    DateTime? now,
  });

  Future<void> setMastered(
    String id, {
    required bool mastered,
    DateTime? now,
  });

  Future<void> delete(String id);

  Future<void> deleteMany(Set<String> ids);
}

class AppPreferencesMistakeBookStore implements MistakeBookStore {
  AppPreferencesMistakeBookStore(this.store);

  final AppPreferencesStore store;
  Future<void> _writeQueue = Future.value();

  @override
  Future<MistakeBookState> read() async {
    var result = const MistakeBookState();
    final write = _writeQueue.then((_) async {
      final preferences = await store.read();
      final synced = _syncStateFromReports(
        preferences.mistakeBook,
        preferences.analysisReports,
        now: DateTime.now(),
      );
      result = synced.state;
      if (synced.changed) {
        await store.write(preferences.copyWith(mistakeBook: synced.state));
      }
    });
    _writeQueue = write.catchError((Object _) {});
    await write;
    return result;
  }

  @override
  Future<void> syncFromAnalysisReports(
    Map<String, GameAnalysisReportCacheEntry> reports, {
    DateTime? now,
  }) async {
    if (!_hasSyncableReports(reports)) return;
    final currentTime = now ?? DateTime.now();
    await _update((state) {
      final synced = _syncStateFromReports(state, reports, now: currentTime);
      return synced.changed ? synced.state : state;
    });
  }

  @override
  Future<void> recordReview(
    String id, {
    required bool correct,
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();
    await _update((state) {
      final entry = state.entries[id];
      if (entry == null) return state;
      final nextStreak = correct ? entry.correctStreak + 1 : 0;
      final nextDue = currentTime.add(
        correct ? _correctInterval(nextStreak) : const Duration(days: 1),
      );
      return MistakeBookState(
        entries: Map.unmodifiable({
          ...state.entries,
          id: entry.copyWith(
            correctStreak: nextStreak,
            reviewCount: entry.reviewCount + 1,
            dueAt: nextDue,
            updatedAt: currentTime,
          ),
        }),
        deletedIds: state.deletedIds,
      );
    });
  }

  @override
  Future<void> setMastered(
    String id, {
    required bool mastered,
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();
    await _update((state) {
      final entry = state.entries[id];
      if (entry == null) return state;
      return MistakeBookState(
        entries: Map.unmodifiable({
          ...state.entries,
          id: entry.copyWith(mastered: mastered, updatedAt: currentTime),
        }),
        deletedIds: state.deletedIds,
      );
    });
  }

  @override
  Future<void> delete(String id) => deleteMany({id});

  @override
  Future<void> deleteMany(Set<String> ids) async {
    final validIds = ids.where((id) => id.trim().isNotEmpty).toSet();
    if (validIds.isEmpty) return;
    await _update((state) {
      if (validIds.every(
        (id) => !state.entries.containsKey(id) && state.deletedIds.contains(id),
      )) {
        return state;
      }
      final entries = Map<String, MistakeBookEntry>.from(state.entries)
        ..removeWhere((id, _) => validIds.contains(id));
      return MistakeBookState(
        entries: Map.unmodifiable(entries),
        deletedIds: Set.unmodifiable({...state.deletedIds, ...validIds}),
      );
    });
  }

  Future<void> _update(
      MistakeBookState Function(MistakeBookState) update) async {
    final write = _writeQueue.then((_) async {
      final preferences = await store.read();
      await store.write(
        preferences.copyWith(mistakeBook: update(preferences.mistakeBook)),
      );
    });
    _writeQueue = write.catchError((Object _) {});
    await write;
  }
}

bool _hasSyncableReports(Map<String, GameAnalysisReportCacheEntry> reports) {
  return reports.values.any(
    (entry) => entry.standardReport != null && entry.pgn.trim().isNotEmpty,
  );
}

({MistakeBookState state, bool changed}) _syncStateFromReports(
  MistakeBookState state,
  Map<String, GameAnalysisReportCacheEntry> reports, {
  required DateTime now,
}) {
  final reportEntries = reports.entries
      .where((entry) =>
          entry.value.standardReport != null &&
          entry.value.pgn.trim().isNotEmpty)
      .toList(growable: false);
  if (reportEntries.isEmpty) return (state: state, changed: false);

  var changed = false;
  final entries = Map<String, MistakeBookEntry>.from(state.entries);
  for (final reportEntry in reportEntries) {
    final report = reportEntry.value.standardReport!;
    final pgn = reportEntry.value.pgn;
    final extracted = MistakeBookExtractor.extractFromStandardReport(
      reportKey: reportEntry.key,
      pgn: pgn,
      report: report,
      now: now,
    );
    final extractedIds = extracted.map((entry) => entry.id).toSet();
    final reportedPlies = report.moves.map((move) => move.ply).toSet();
    final obsoleteIds = entries.values
        .where((entry) =>
            entry.reportKey == reportEntry.key &&
            reportedPlies.contains(entry.ply) &&
            !extractedIds.contains(entry.id))
        .map((entry) => entry.id)
        .toList(growable: false);
    if (obsoleteIds.isNotEmpty) {
      for (final id in obsoleteIds) {
        entries.remove(id);
      }
      changed = true;
    }
    for (final entry in extracted) {
      if (state.deletedIds.contains(entry.id)) continue;
      final existing = entries[entry.id];
      if (existing == null) {
        entries[entry.id] = entry;
        changed = true;
        continue;
      }
      if (!_hasSameMistakeContent(existing, entry)) {
        entries[entry.id] = existing.copyWith(
          pgn: entry.pgn,
          sourceTitle: entry.sourceTitle,
          moveSan: entry.moveSan,
          bestMoveSan: entry.bestMoveSan,
          classification: entry.classification,
          summary: entry.summary,
          theme: entry.theme,
          fenBefore: entry.fenBefore,
          fenAfter: entry.fenAfter,
          engineLine: entry.engineLine,
          updatedAt: now,
        );
        changed = true;
      }
    }
  }
  if (!changed) return (state: state, changed: false);
  return (
    state: MistakeBookState(
      entries: Map.unmodifiable(entries),
      deletedIds: state.deletedIds,
    ),
    changed: true,
  );
}

bool _hasSameMistakeContent(
  MistakeBookEntry existing,
  MistakeBookEntry extracted,
) {
  return existing.pgn == extracted.pgn &&
      existing.sourceTitle == extracted.sourceTitle &&
      existing.moveSan == extracted.moveSan &&
      existing.bestMoveSan == extracted.bestMoveSan &&
      existing.classification == extracted.classification &&
      existing.summary == extracted.summary &&
      existing.theme == extracted.theme &&
      existing.fenBefore == extracted.fenBefore &&
      existing.fenAfter == extracted.fenAfter &&
      existing.engineLine == extracted.engineLine;
}

class MistakeBookExtractor {
  const MistakeBookExtractor._();

  static List<MistakeBookEntry> extractFromStandardReport({
    required String reportKey,
    required String pgn,
    required GameStandardAnalysisReport report,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final parsed = GameNotationService.parsePgn(pgn);
    final sourceTitle = _sourceTitle(parsed);
    final parsedByPly = {for (final move in parsed.moves) move.ply: move};
    final playerSide = _playerSide(parsed.headers);
    if (playerSide.isIdentifiedGame && playerSide.side == null) {
      return const [];
    }
    final entries = <MistakeBookEntry>[];
    for (final move in report.moves) {
      if (!_isMistake(move)) continue;
      if (playerSide.side != null &&
          !_isMoveBySide(move.ply, playerSide.side!)) {
        continue;
      }
      final parsedMove = parsedByPly[move.ply];
      if (parsedMove != null &&
          _isSameMove(
            fen: parsedMove.fenBefore,
            actualUci: parsedMove.uci,
            bestMoveText: move.bestMove,
          )) {
        continue;
      }
      if (parsedMove != null && _hasOnlyOneLegalMove(parsedMove.fenBefore)) {
        continue;
      }
      entries.add(
        MistakeBookEntry(
          id: '$reportKey:${move.ply}',
          reportKey: reportKey,
          pgn: pgn,
          sourceTitle: sourceTitle,
          ply: move.ply,
          moveSan: move.move,
          bestMoveSan: _cleanBestMove(move.bestMove),
          classification: _classificationFor(move),
          summary: move.summary,
          theme: _themeFor(move),
          fenBefore: parsedMove?.fenBefore ?? move.fen,
          fenAfter: move.fen,
          engineLine: move.engineLine,
          createdAt: currentTime,
          updatedAt: currentTime,
          dueAt: currentTime,
        ),
      );
    }
    return List.unmodifiable(entries);
  }

  static ({bool isIdentifiedGame, dc.Side? side}) _playerSide(
    Map<String, String> headers,
  ) {
    final declared = switch (headers['PlayerSide']?.trim().toLowerCase()) {
      'white' || 'w' => dc.Side.white,
      'black' || 'b' => dc.Side.black,
      _ => null,
    };
    final event = headers['Event']?.trim().toLowerCase() ?? '';
    final site = headers['Site']?.trim().toLowerCase() ?? '';
    final source = headers['Source']?.trim().toLowerCase() ?? '';
    final engineKind = headers['EngineKind']?.trim() ?? '';
    final isBot = engineKind.isNotEmpty || event.contains('bot game');
    final isLichess = headers['LichessGameId']?.trim().isNotEmpty == true ||
        event.contains('lichess') ||
        site.contains('lichess.org') ||
        source == 'lichess';
    final isChessCom = headers['ChessComSync']?.trim().isNotEmpty == true ||
        event.contains('chess.com') ||
        site.contains('chess.com') ||
        source == 'chess.com';
    final isIdentifiedGame = isBot || isLichess || isChessCom;
    if (!isIdentifiedGame) return (isIdentifiedGame: false, side: null);
    if (declared != null) {
      return (isIdentifiedGame: true, side: declared);
    }
    final accountName = isLichess
        ? headers['LichessName']?.trim() ?? ''
        : isChessCom
            ? headers['ChessComName']?.trim() ?? ''
            : '';
    return (
      isIdentifiedGame: true,
      side: _sideForPlayerName(headers, accountName),
    );
  }

  static dc.Side? _sideForPlayerName(
    Map<String, String> headers,
    String accountName,
  ) {
    final normalized = _normalizePlayerName(accountName);
    if (normalized.isEmpty) return null;
    final white = _normalizePlayerName(headers['White'] ?? '');
    final black = _normalizePlayerName(headers['Black'] ?? '');
    final matchesWhite = white == normalized;
    final matchesBlack = black == normalized;
    if (matchesWhite == matchesBlack) return null;
    return matchesWhite ? dc.Side.white : dc.Side.black;
  }

  static String _normalizePlayerName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool _isMoveBySide(int ply, dc.Side side) {
    return side == dc.Side.white ? ply.isOdd : ply.isEven;
  }

  static bool _isSameMove({
    required String fen,
    required String actualUci,
    required String bestMoveText,
  }) {
    try {
      final position = dc.Chess.fromSetup(dc.Setup.parseFen(fen));
      final expected = _normalizeMoveText(bestMoveText);
      if (expected.isEmpty) return false;
      for (final move in _legalNormalMoves(position)) {
        final (_, san) = position.makeSan(move);
        if (_normalizeMoveText(san) != expected &&
            _normalizeMoveText(move.uci) != expected) {
          continue;
        }
        return move.uci == actualUci;
      }
    } catch (_) {}
    return false;
  }

  static List<dc.NormalMove> _legalNormalMoves(dc.Position position) {
    final moves = <String, dc.NormalMove>{};
    for (final entry in position.legalMoves.entries) {
      final from = entry.key;
      final piece = position.board.pieceAt(from);
      if (piece == null) continue;
      for (final to in entry.value.squares) {
        final promotionRoles = piece.role == dc.Role.pawn &&
                (to.rank == dc.Rank.first || to.rank == dc.Rank.eighth)
            ? const [
                dc.Role.queen,
                dc.Role.rook,
                dc.Role.bishop,
                dc.Role.knight,
              ]
            : const <dc.Role?>[null];
        for (final promotion in promotionRoles) {
          final normalized = position.normalizeMove(
            dc.NormalMove(from: from, to: to, promotion: promotion),
          );
          if (normalized is dc.NormalMove && position.isLegal(normalized)) {
            moves[normalized.uci] = normalized;
          }
        }
      }
    }
    return List.unmodifiable(moves.values);
  }

  static String _normalizeMoveText(String value) {
    return value
        .trim()
        .replaceFirst(RegExp(r'^(Best|Better|Cleaner|Tactic):\s*'), '')
        .replaceAll(RegExp(r'^\d+\.(\.\.)?\s*'), '')
        .replaceAll(RegExp(r'[+#?!]+$'), '')
        .replaceAll(RegExp(r'\s+'), '')
        .toLowerCase();
  }

  static bool _hasOnlyOneLegalMove(String fen) {
    try {
      final position = dc.Chess.fromSetup(dc.Setup.parseFen(fen));
      var count = 0;
      for (final entry in position.legalMoves.entries) {
        final piece = position.board.pieceAt(entry.key);
        if (piece == null) continue;
        for (final to in entry.value.squares) {
          count += piece.role == dc.Role.pawn &&
                  (to.rank == dc.Rank.first || to.rank == dc.Rank.eighth)
              ? 4
              : 1;
          if (count > 1) return false;
        }
      }
      return count == 1;
    } catch (_) {
      return false;
    }
  }

  static bool _isMistake(CachedReviewMove move) {
    return switch (_classificationFor(move)) {
      'Mistake' || 'Blunder' || 'Missed win' || 'Critical swing' => true,
      // The standard report's classification is already the authoritative
      // review result. Score-map accuracy is optional on locally generated
      // reports, so an Inaccuracy must not disappear just because that
      // optional field is absent.
      'Inaccuracy' => true,
      _ => false,
    };
  }

  static String _themeFor(CachedReviewMove move) {
    return switch (_classificationFor(move)) {
      'Missed win' => 'Missed tactic',
      'Blunder' => 'Blunder',
      'Inaccuracy' => 'Inaccuracy',
      'Critical swing' => 'Critical swing',
      _ => 'Mistake',
    };
  }

  static String _classificationFor(CachedReviewMove move) {
    final normalized = _normalizeClassification(move.classification);
    if (normalized.isNotEmpty) return normalized;
    final level = move.scoreMapLevel;
    if (level != null) {
      if (level >= 6) return 'Blunder';
      if (level == 5) return 'Mistake';
      if (level == 4) return 'Inaccuracy';
    }
    final accuracy = move.scoreMapAccuracy;
    if (accuracy != null) {
      if (accuracy < 20) return 'Blunder';
      if (accuracy < 55) return 'Mistake';
      if (accuracy < 70) return 'Inaccuracy';
    }
    return '';
  }

  static String _normalizeClassification(String value) {
    final normalized =
        value.trim().toLowerCase().replaceAll(RegExp(r'[_-]+'), ' ');
    return switch (normalized) {
      'blunder' || 'blunders' || '??' => 'Blunder',
      'missed win' || 'missed tactic' || 'miss' => 'Missed win',
      'critical swing' || 'critical' => 'Critical swing',
      'mistake' || 'mistakes' || '?' => 'Mistake',
      'inaccuracy' || 'inaccuracies' => 'Inaccuracy',
      _ => '',
    };
  }

  static String _sourceTitle(ParsedPgnGame game) {
    final white = _header(game.headers, 'White', 'White');
    final black = _header(game.headers, 'Black', 'Black');
    return '$white vs $black';
  }

  static String _header(
      Map<String, String> headers, String key, String fallback) {
    final value = headers[key]?.trim();
    return value == null || value.isEmpty || value == '?' ? fallback : value;
  }

  static String _cleanBestMove(String value) {
    return value
        .replaceFirst(RegExp(r'^(Best|Better|Cleaner|Tactic):\s*'), '')
        .trim();
  }
}

Duration _correctInterval(int streak) {
  return switch (streak) {
    0 => const Duration(days: 1),
    1 => const Duration(days: 3),
    2 => const Duration(days: 7),
    _ => const Duration(days: 14),
  };
}

int _severity(String classification) {
  return switch (classification) {
    'Blunder' => 5,
    'Missed win' => 4,
    'Critical swing' => 4,
    'Mistake' => 3,
    'Inaccuracy' => 2,
    _ => 1,
  };
}

String _string(Object? value) => value?.toString() ?? '';

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _date(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}
