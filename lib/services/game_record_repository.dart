import 'dart:convert';
import 'dart:math' as math;

import '../models/app_models.dart';
import 'chessnut_api_client.dart';
import 'game_record_identity.dart';
import 'game_record_pgn_cache.dart';

class GameRecordLoadResult {
  const GameRecordLoadResult({
    required this.status,
    this.records = const [],
    this.page = 1,
    this.count = 20,
    this.total = 0,
    this.totalPage = 0,
    this.hydratedRecords,
  });

  final ApiStatus status;
  final List<GameRecord> records;
  final int page;
  final int count;
  final int total;
  final int totalPage;
  final List<Future<GameRecord>>? hydratedRecords;

  bool get isSuccess => status.isSuccess;
}

class GameRecordRemoteSearchResult {
  const GameRecordRemoteSearchResult({
    required this.status,
    this.records = const [],
    this.page = 1,
    this.count = 20,
    this.total = 0,
    this.totalPage = 0,
    this.hydratedRecords,
  });

  final ApiStatus status;
  final List<GameRecord> records;
  final int page;
  final int count;
  final int total;
  final int totalPage;
  final List<Future<GameRecord>>? hydratedRecords;

  bool get isSuccess => status.isSuccess;
}

class GameRecordRepository {
  const GameRecordRepository({
    required this.apiClient,
    this.pgnCache = const GameRecordPgnCache(),
  });

  final ChessnutApiClient apiClient;
  final GameRecordPgnCache pgnCache;

  Future<void> invalidateRecordPgn(int pgnId) => pgnCache.delete(pgnId);

  Future<GameRecordLoadResult> loadRecords({
    int page = 1,
    int count = 10,
    bool deferRemotePgn = false,
  }) async {
    final result = await apiClient.getPgnList(page: page, count: count);
    if (!result.isSuccess) {
      return GameRecordLoadResult(
        status: result.status,
        page: page,
        count: count,
      );
    }

    final data = result.data;
    final backendRecords = data?.records ?? const <PgnRecord>[];
    final records = deferRemotePgn
        ? _placeholderRecordsFromBackend(backendRecords)
        : await _recordsFromBackend(backendRecords);
    final reportedTotalPage = data?.totalPage ?? 0;
    final explicitTotal = data?.total ?? 0;
    final total = await _resolveTotal(
      explicitTotal: explicitTotal,
      totalPage: reportedTotalPage,
      page: page,
      count: count,
      pageRecordCount: records.length,
      loadPage: (lastPage) => apiClient.getPgnList(
        page: lastPage,
        count: count,
      ),
    );
    final totalPage = _resolveTotalPage(
      reportedTotalPage: reportedTotalPage,
      explicitTotal: explicitTotal,
      total: total,
      count: count,
      page: page,
      pageRecordCount: records.length,
    );

    return GameRecordLoadResult(
      status: const ApiStatus.success(),
      records: records,
      page: page,
      count: count,
      total: total,
      totalPage: totalPage,
      hydratedRecords:
          deferRemotePgn ? _hydrateRecordsFromBackend(backendRecords) : null,
    );
  }

  Future<GameRecordRemoteSearchResult> searchRecords(
    GameRecordSearchRequest request, {
    bool deferRemotePgn = false,
  }) async {
    final result = await apiClient.searchGameRecords(request);
    if (!result.isSuccess) {
      return GameRecordRemoteSearchResult(
        status: result.status,
        page: request.page,
        count: request.count,
      );
    }

    final data = result.data;
    final backendRecords = data?.records ?? const <PgnRecord>[];
    final records = deferRemotePgn
        ? _placeholderRecordsFromBackend(backendRecords)
        : await _recordsFromBackend(backendRecords);
    final reportedTotalPage = data?.totalPage ?? 0;
    final explicitTotal = data?.total ?? 0;
    final total = await _resolveTotal(
      explicitTotal: explicitTotal,
      totalPage: reportedTotalPage,
      page: request.page,
      count: request.count,
      pageRecordCount: records.length,
      loadPage: (lastPage) => apiClient.searchGameRecords(
        GameRecordSearchRequest(
          page: lastPage,
          count: request.count,
          query: request.query,
          mode: request.mode,
          result: request.result,
          speed: request.speed,
          color: request.color,
          report: request.report,
          minMoves: request.minMoves,
          sort: request.sort,
        ),
      ),
    );
    final totalPage = _resolveTotalPage(
      reportedTotalPage: reportedTotalPage,
      explicitTotal: explicitTotal,
      total: total,
      count: request.count,
      page: request.page,
      pageRecordCount: records.length,
    );
    return GameRecordRemoteSearchResult(
      status: const ApiStatus.success(),
      records: records,
      page: request.page,
      count: request.count,
      total: total,
      totalPage: totalPage,
      hydratedRecords:
          deferRemotePgn ? _hydrateRecordsFromBackend(backendRecords) : null,
    );
  }

  Future<int> _resolveTotal({
    required int explicitTotal,
    required int totalPage,
    required int page,
    required int count,
    required int pageRecordCount,
    required Future<ApiResult<PgnListResult>> Function(int page) loadPage,
  }) async {
    if (explicitTotal > 0) return explicitTotal;
    if (totalPage <= 1) return pageRecordCount;
    if (page == totalPage) {
      return ((totalPage - 1) * count) + pageRecordCount;
    }
    final lastPage = await loadPage(totalPage);
    if (lastPage.isSuccess && lastPage.data != null) {
      final lastData = lastPage.data!;
      if (lastData.total > 0) return lastData.total;
      return ((totalPage - 1) * count) + lastData.records.length;
    }
    return totalPage * count;
  }

  int _resolveTotalPage({
    required int reportedTotalPage,
    required int explicitTotal,
    required int total,
    required int count,
    required int page,
    required int pageRecordCount,
  }) {
    if (reportedTotalPage > 0) return reportedTotalPage;
    if (explicitTotal > 0 && count > 0) {
      return math.max(1, (explicitTotal / count).ceil());
    }
    if (pageRecordCount >= count) return page + 1;
    return math.max(1, page);
  }

  Future<ApiResult<bool>> deleteRecord({required int pgnId}) async {
    final result = await apiClient.deletePgn(pgnId: pgnId);
    if (result.isSuccess) await pgnCache.delete(pgnId);
    return result;
  }

  /// Finds an existing server record before a new game or analysis PGN is
  /// uploaded. Platform IDs use targeted search; PGNs without IDs fall back
  /// to matching against the account archive.
  Future<GameRecord?> findExistingRecord({
    required String pgn,
    String lichessGameId = '',
    String chessnutGameId = '',
  }) async {
    final target = GameRecordIdentity.fromPgn(
      pgn,
      lichessGameId: lichessGameId,
      chessnutGameId: chessnutGameId,
    );
    final checkedRecordIds = <int>{};
    GameRecord? analysisFallback;

    GameRecord? preferMatches(Iterable<GameRecord> records) {
      final matches = records
          .where(
            (record) =>
                (record.pgnId ?? 0) > 0 &&
                target.matches(GameRecordIdentity.fromRecord(record)),
          )
          .toList(growable: false);
      if (matches.isEmpty) return null;
      return matches.reduce(
        (best, candidate) => _preferRecord(candidate, best) ? candidate : best,
      );
    }

    GameRecord? acceptMatch(GameRecord? match) {
      if (match == null) return null;
      if (!_isAnalysisRecord(match)) return match;
      if (analysisFallback == null || _preferRecord(match, analysisFallback!)) {
        analysisFallback = match;
      }
      return null;
    }

    Future<GameRecord?> inspect(List<PgnRecord> rawRecords) async {
      final records = await _recordsFromBackend(rawRecords);
      return preferMatches(
        records.where(
          (record) => checkedRecordIds.add(record.pgnId ?? 0),
        ),
      );
    }

    final targetedQueries = <(String, String)>[
      if (target.lichessGameId.isNotEmpty) (target.lichessGameId, 'lichess'),
      if (target.chessnutGameId.isNotEmpty) (target.chessnutGameId, ''),
    ];
    for (final (query, mode) in targetedQueries) {
      final result = await searchRecords(
        GameRecordSearchRequest(
          page: 1,
          count: 100,
          query: query,
          mode: mode,
          sort: 'newest',
        ),
      );
      if (!result.isSuccess) continue;
      final accepted = acceptMatch(preferMatches(result.records));
      if (accepted != null) return accepted;
    }
    if (targetedQueries.isNotEmpty) return analysisFallback;

    const pageSize = 100;
    final first = await apiClient.getPgnList(page: 1, count: pageSize);
    if (!first.isSuccess || first.data == null) return analysisFallback;
    final firstMatch = acceptMatch(await inspect(first.data!.records));
    if (firstMatch != null) return firstMatch;

    final totalPage = first.data!.totalPage > 0
        ? first.data!.totalPage
        : first.data!.total > 0
            ? math.max(1, (first.data!.total / pageSize).ceil())
            : first.data!.records.length >= pageSize
                ? 2
                : 1;
    for (var page = 2; page <= totalPage; page++) {
      final result = await apiClient.getPgnList(page: page, count: pageSize);
      if (!result.isSuccess || result.data == null) break;
      final match = acceptMatch(await inspect(result.data!.records));
      if (match != null) return match;
      if (result.data!.records.isEmpty) break;
    }
    return analysisFallback;
  }

  Future<ApiResult<bool>> endRecord(GameRecord record) async {
    final pgnId = record.pgnId;
    if (pgnId == null) {
      return const ApiResult(
        ApiStatus.api(
          code: 400,
          message: 'This local game record cannot be updated in the cloud.',
        ),
      );
    }
    final pgn = _pgnWithResult(record.pgn, '1/2-1/2');
    final result = await apiClient.updatePgn(
      pgnId: pgnId,
      pgn: pgn,
      whiteName: record.displayWhiteName,
      blackName: record.displayBlackName,
      winId: 3,
      gameStatus: 2,
      gameStep: record.gameStep,
      metadata: PgnSaveMetadata(
        lichessGameId: record.lichessGameId,
        lichessToken: record.lichessToken,
        lichessName: record.lichessName,
        playerColor: record.playerColorOverride,
        speed: record.speedOverride,
        timeControl: record.timeControlOverride,
        opponentName: record.opponentNameOverride,
      ),
    );
    if (result.isSuccess) await pgnCache.delete(pgnId);
    return ApiResult<bool>(result.status, data: result.isSuccess);
  }

  Future<List<GameRecord>> _recordsFromBackend(
    List<PgnRecord> backendRecords,
  ) async {
    return Future.wait([
      for (final record in backendRecords)
        _resolvePgn(record).then((pgn) => _recordFromBackend(record, pgn)),
    ]);
  }

  List<GameRecord> _placeholderRecordsFromBackend(
    List<PgnRecord> backendRecords,
  ) {
    return [
      for (final record in backendRecords)
        _recordFromBackend(record, _inlinePgn(record) ?? ''),
    ];
  }

  List<Future<GameRecord>> _hydrateRecordsFromBackend(
    List<PgnRecord> backendRecords,
  ) {
    return [
      for (final record in backendRecords)
        _resolveCachedPgn(record)
            .then((pgn) => _recordFromBackend(record, pgn)),
    ];
  }

  bool _preferRecord(GameRecord candidate, GameRecord existing) {
    final candidateIsAnalysis = _isAnalysisRecord(candidate);
    final existingIsAnalysis = _isAnalysisRecord(existing);
    if (candidateIsAnalysis != existingIsAnalysis) {
      return !candidateIsAnalysis;
    }
    final candidateFinished =
        candidate.hasFinishedResult || candidate.declaredGameStatus == 2;
    final existingFinished =
        existing.hasFinishedResult || existing.declaredGameStatus == 2;
    if (candidateFinished != existingFinished) return candidateFinished;
    if (candidate.gameStep != existing.gameStep) {
      return candidate.gameStep > existing.gameStep;
    }
    final candidateSortAt = candidate.sortAt;
    final existingSortAt = existing.sortAt;
    if (candidateSortAt != null && existingSortAt != null) {
      return candidateSortAt.isAfter(existingSortAt);
    }
    return (candidate.pgnId ?? 0) > (existing.pgnId ?? 0);
  }

  bool _isAnalysisRecord(GameRecord record) {
    return record.playMode.trim().toLowerCase() == 'analysis';
  }

  GameRecord _recordFromBackend(PgnRecord record, String pgn) {
    final whiteName = _resolvedSideName(
      backendName: record.whiteName,
      pgn: pgn,
      header: 'White',
      fallback: 'White',
    );
    final blackName = _resolvedSideName(
      backendName: record.blackName,
      pgn: pgn,
      header: 'Black',
      fallback: 'Black',
    );
    final result = _resolvedResult(record.winId, pgn);
    return GameRecord(
      pgnId: record.id,
      shareId: record.shareId,
      result: result,
      title: '$whiteName vs $blackName',
      subtitle: '${_playModeLabel(record.playMode)} / ${record.gameStep} moves',
      pgn: pgn,
      pgnSource: record.pgnUrl?.trim() ?? '',
      playMode: record.playMode,
      gameStatus: record.gameStatus,
      gameStep: record.gameStep,
      winId: record.winId,
      whiteName: whiteName,
      blackName: blackName,
      commentId: record.commentId,
      sortAt: record.sortAt,
      hasGrandeurReport: record.hasGrandeurReport,
      lichessGameIdOverride: record.lichessGameId,
      chessnutGameIdOverride: record.clientGameId,
      lichessTokenOverride: record.lichessToken,
      lichessNameOverride: record.lichessName,
      playerColorOverride: record.playerColor,
      speedOverride: record.speed,
      timeControlOverride: record.timeControl,
      opponentNameOverride: record.opponentName,
    );
  }

  Future<String> _resolvePgn(PgnRecord record) async {
    final source = record.pgnUrl?.trim();
    if (source == null || source.isEmpty) {
      return '';
    }
    final inlinePgn = _resolvedInlinePgn(source);
    if (inlinePgn != null) {
      return inlinePgn;
    }
    final uri = Uri.tryParse(source);
    if (uri == null) {
      return source;
    }
    if (!uri.hasScheme) {
      if (!source.startsWith('/')) return source;
      return _fetchPgn(apiClient.baseUri.resolveUri(uri));
    }
    return _fetchPgn(uri);
  }

  String? _inlinePgn(PgnRecord record) {
    final source = record.pgnUrl?.trim();
    if (source == null || source.isEmpty) return '';
    return _resolvedInlinePgn(source);
  }

  Future<String> _resolveCachedPgn(PgnRecord record) async {
    final inline = _inlinePgn(record);
    if (inline != null) return inline;
    final cached = await pgnCache.read(record.id);
    if (cached != null) return cached;
    final pgn = await _resolvePgn(record);
    if (pgn.trim().isNotEmpty) await pgnCache.write(record.id, pgn);
    return pgn;
  }

  Future<ApiResult<GameRecord>> refreshRecordPgn(GameRecord record) async {
    final pgnId = record.pgnId ?? 0;
    if (pgnId <= 0 || record.pgnSource.trim().isEmpty) {
      return const ApiResult(
        ApiStatus.api(code: 400, message: 'This record has no remote PGN.'),
      );
    }
    await pgnCache.delete(pgnId);
    final backend = PgnRecord(
      id: pgnId,
      whiteName: record.whiteName,
      blackName: record.blackName,
      playMode: record.playMode,
      playTime: record.sortAt?.toIso8601String() ?? '',
      gameStatus: record.gameStatus,
      gameStep: record.gameStep,
      winId: record.winId,
      commentId: record.commentId,
      pgnUrl: record.pgnSource,
      shareId: record.shareId,
      sortAt: record.sortAt,
      hasGrandeurReport: record.hasGrandeurReport,
      lichessGameId: record.lichessGameIdOverride,
      clientGameId: record.chessnutGameIdOverride,
      lichessToken: record.lichessTokenOverride,
      lichessName: record.lichessNameOverride,
    );
    final pgn = await _resolvePgn(backend);
    if (pgn.trim().isEmpty) {
      return const ApiResult(
        ApiStatus.network('Unable to download this PGN.'),
      );
    }
    await pgnCache.write(pgnId, pgn);
    return ApiResult(
      const ApiStatus.success(),
      data: _recordFromBackend(backend, pgn),
    );
  }

  Future<String> _fetchPgn(Uri uri) async {
    return _resolvedFetchedPgn(await apiClient.getString(uri));
  }

  String _resolvedFetchedPgn(String? body) {
    if (body == null) return '';
    return _resolvedInlinePgn(body) ?? body;
  }

  String? _resolvedInlinePgn(String source) {
    final trimmed = source.trim();
    if (_looksLikePgn(trimmed)) return trimmed;
    final decoded = _decodeBase64Pgn(trimmed);
    if (decoded != null) return decoded;
    return null;
  }

  String? _decodeBase64Pgn(String value) {
    if (value.isEmpty ||
        value.contains('://') ||
        value.startsWith('/') ||
        value.startsWith('[')) {
      return null;
    }
    try {
      final normalized = base64.normalize(value);
      final decoded = utf8.decode(base64Decode(normalized)).trim();
      if (_looksLikePgn(decoded)) {
        return decoded;
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  bool _looksLikePgn(String value) {
    if (value.isEmpty) return false;
    return value.startsWith('[Event ') ||
        value.startsWith('[Site ') ||
        value.startsWith('[White ') ||
        value.startsWith('[Black ') ||
        value.contains('\n[Event ') ||
        value.contains('\n[White ') ||
        value.contains('\n[Black ');
  }

  String _resultLabel(int winId) {
    return switch (winId) {
      1 => '1-0',
      2 => '0-1',
      3 => '1/2-1/2',
      _ => '*',
    };
  }

  String _resolvedResult(int winId, String pgn) {
    final byWinId = _resultLabel(winId);
    if (byWinId != '*') return byWinId;
    final pgnResult = _pgnHeader(pgn, 'Result');
    return _isFinishedResult(pgnResult) ? pgnResult : '*';
  }

  String _playModeLabel(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'Game';
    }
    return normalized
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
      if (part.length == 1) return part.toUpperCase();
      return part[0].toUpperCase() + part.substring(1);
    }).join(' ');
  }

  String _fallbackName(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String _resolvedSideName({
    required String backendName,
    required String pgn,
    required String header,
    required String fallback,
  }) {
    final pgnName = _pgnHeader(pgn, header);
    final backend = backendName.trim();
    if (backend.isNotEmpty && !_isChessComPlaceholder(backend)) {
      return backend;
    }
    if (pgnName.isNotEmpty && pgnName != '?') return pgnName;
    if (_isChessComPlaceholder(backend)) return fallback;
    return _fallbackName(backend, fallback);
  }

  bool _isChessComPlaceholder(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'chess.com white' ||
        normalized == 'chess.com black' ||
        normalized == 'chesscom white' ||
        normalized == 'chesscom black';
  }

  bool _isFinishedResult(String value) {
    return value == '1-0' || value == '0-1' || value == '1/2-1/2';
  }

  String _pgnWithResult(String pgn, String result) {
    var next = pgn;
    if (RegExp(r'^\[Result\s+".*"\]$', multiLine: true).hasMatch(next)) {
      next = next.replaceFirst(
        RegExp(r'^\[Result\s+".*"\]$', multiLine: true),
        '[Result "$result"]',
      );
    } else {
      next = '[Result "$result"]\n$next';
    }
    final escaped = RegExp.escape(result);
    final resultPattern = RegExp(r'\s+(1-0|0-1|1/2-1/2|\*)\s*$');
    if (resultPattern.hasMatch(next)) {
      next = next.replaceFirst(resultPattern, ' $result');
    } else if (!RegExp('\\s$escaped\\s*\$').hasMatch(next)) {
      next = '${next.trimRight()} $result';
    }
    return next;
  }

  String _pgnHeader(String pgn, String name) {
    final match =
        RegExp('^\\[$name\\s+"(.*)"\\]\$', multiLine: true).firstMatch(pgn);
    return match?.group(1)?.replaceAll(r'\"', '"').replaceAll(r'\\', '\\') ??
        '';
  }
}
