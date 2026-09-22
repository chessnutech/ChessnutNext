import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'lichess_pgn_service.dart' show splitPgnGames;

class ChessComPgnFetchOptions {
  const ChessComPgnFetchOptions({
    required this.username,
    this.since = '',
    this.until = '',
  });

  final String username;
  final String since;
  final String until;
}

class ChessComPgnResult {
  const ChessComPgnResult({required this.games});

  final List<String> games;
}

class ChessComPgnService {
  const ChessComPgnService({
    required this.httpClient,
    this.baseUri = const String.fromEnvironment(
      'CHESSNUT_CHESSCOM_BASE_URL',
      defaultValue: 'https://api.chess.com',
    ),
  });

  final http.Client httpClient;
  final String baseUri;

  Future<ChessComPgnResult> fetchGames({
    required ChessComPgnFetchOptions options,
    int maxGames = 500,
  }) async {
    final username = options.username.trim();
    if (username.isEmpty) {
      throw const ChessComPgnException('Enter a Chess.com username.');
    }
    final limit = maxGames.clamp(1, 500);
    final since = _parseDate(options.since, endOfDay: false);
    final until = _parseDate(options.until, endOfDay: true);
    if (since != null && until != null && since.isAfter(until)) {
      throw const ChessComPgnException(
        'The start date must not be after the end date.',
      );
    }

    final archiveMonths = await _fetchArchiveMonths(username);
    final firstMonth =
        until == null ? null : DateTime.utc(until.year, until.month);
    final earliestMonth =
        since == null ? null : DateTime.utc(since.year, since.month);
    final games = <String>[];

    for (final month in archiveMonths) {
      if (firstMonth != null && month.isAfter(firstMonth)) continue;
      if (earliestMonth != null && month.isBefore(earliestMonth)) continue;
      if (games.length >= limit) break;
      final uri = buildArchiveUri(username: username, month: month);
      http.Response response;
      try {
        response = await httpClient.get(
          uri,
          headers: const {
            'Accept': 'application/x-chess-pgn',
            'User-Agent': 'Chessnut-Next-GameRecordImport',
          },
        ).timeout(const Duration(minutes: 5));
      } catch (error) {
        throw ChessComPgnException('Unable to load Chess.com games: $error');
      }
      if (response.statusCode == 404) continue;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ChessComPgnException(
          'Chess.com returned ${response.statusCode}',
        );
      }
      for (final pgn in splitPgnGames(response.body)) {
        final playedAt = _pgnDate(pgn);
        if (since != null && playedAt != null && playedAt.isBefore(since)) {
          continue;
        }
        if (until != null && playedAt != null && playedAt.isAfter(until)) {
          continue;
        }
        games.add(pgn);
        if (games.length >= limit) break;
      }
    }
    return ChessComPgnResult(games: games);
  }

  Future<List<DateTime>> _fetchArchiveMonths(String username) async {
    final parsedBase = Uri.parse(baseUri);
    final prefix = parsedBase.path.endsWith('/')
        ? parsedBase.path.substring(0, parsedBase.path.length - 1)
        : parsedBase.path;
    final uri = parsedBase.replace(
      path:
          '$prefix/pub/player/${Uri.encodeComponent(username)}/games/archives',
      query: null,
    );
    http.Response response;
    try {
      response = await httpClient.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'Chessnut-Next-GameRecordImport',
        },
      ).timeout(const Duration(minutes: 5));
    } catch (error) {
      throw ChessComPgnException('Unable to load Chess.com games: $error');
    }
    if (response.statusCode == 404) return const [];
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ChessComPgnException('Chess.com returned ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['archives'] is! List) {
      throw const ChessComPgnException('Chess.com returned invalid archives.');
    }
    final months = <DateTime>[];
    final pattern = RegExp(r'/games/(\d{4})/(\d{2})$');
    for (final value in decoded['archives'] as List) {
      final match = pattern.firstMatch(value.toString());
      final year = int.tryParse(match?.group(1) ?? '');
      final month = int.tryParse(match?.group(2) ?? '');
      if (year == null || month == null || month < 1 || month > 12) continue;
      months.add(DateTime.utc(year, month));
    }
    months.sort((left, right) => right.compareTo(left));
    return months;
  }

  Uri buildArchiveUri({
    required String username,
    required DateTime month,
  }) {
    final parsedBase = Uri.parse(baseUri);
    final prefix = parsedBase.path.endsWith('/')
        ? parsedBase.path.substring(0, parsedBase.path.length - 1)
        : parsedBase.path;
    return parsedBase.replace(
      path: '$prefix/pub/player/${Uri.encodeComponent(username.trim())}'
          '/games/${month.year}/${month.month.toString().padLeft(2, '0')}/pgn',
      query: null,
    );
  }
}

class ChessComPgnException implements Exception {
  const ChessComPgnException(this.message);

  final String message;

  @override
  String toString() => message;
}

DateTime? _parseDate(String value, {required bool endOfDay}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final normalized = trimmed.replaceAll('.', '-');
  if (!RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$').hasMatch(normalized)) {
    throw const ChessComPgnException('Use YYYY-MM-DD for date filters.');
  }
  final parsed = DateTime.tryParse('${normalized}T00:00:00Z');
  if (parsed == null) {
    throw const ChessComPgnException('Use YYYY-MM-DD for date filters.');
  }
  return endOfDay
      ? parsed
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1))
      : parsed;
}

DateTime? _pgnDate(String pgn) {
  final utcDate = RegExp(r'^\[UTCDate\s+"([^"]+)"\]$', multiLine: true)
      .firstMatch(pgn)
      ?.group(1);
  final date = utcDate ??
      RegExp(r'^\[Date\s+"([^"]+)"\]$', multiLine: true)
          .firstMatch(pgn)
          ?.group(1);
  if (date == null || date.contains('?')) return null;
  return DateTime.tryParse('${date.replaceAll('.', '-')}T00:00:00Z');
}
