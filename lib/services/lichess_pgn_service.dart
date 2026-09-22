import 'dart:async';

import 'package:http/http.dart' as http;

class LichessPgnFetchOptions {
  const LichessPgnFetchOptions({
    required this.playerId,
    this.since = '',
    this.until = '',
    this.speed = '',
    this.rated = '',
    this.color = '',
  });

  final String playerId;
  final String since;
  final String until;
  final String speed;
  final String rated;
  final String color;
}

class LichessPgnPage {
  const LichessPgnPage({
    required this.pgn,
    required this.requestedUrl,
    required this.hasMore,
    this.nextUntil,
  });

  final String pgn;
  final Uri requestedUrl;
  final bool hasMore;
  final int? nextUntil;
}

class LichessPgnService {
  const LichessPgnService({
    required this.httpClient,
    this.baseUri = const String.fromEnvironment(
      'CHESSNUT_LICHESS_BASE_URL',
      defaultValue: 'https://lichess.org',
    ),
  });

  final http.Client httpClient;
  final String baseUri;

  Future<LichessPgnPage> fetchGames({
    required LichessPgnFetchOptions options,
    int pageSize = 20,
    int? untilCursor,
  }) async {
    final uri = buildGamesUri(
      options: options,
      pageSize: pageSize,
      untilCursor: untilCursor,
    );
    final response = await httpClient.get(
      uri,
      headers: const {
        'Accept': 'application/x-chess-pgn',
        'User-Agent': 'Chessnut-V3-App-ModelBuild',
      },
    ).timeout(const Duration(minutes: 5));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LichessPgnException('Lichess returned ${response.statusCode}');
    }
    final pgn = response.body;
    final games = splitPgnGames(pgn);
    final nextUntil = nextUntilCursorFromPgn(pgn);
    return LichessPgnPage(
      pgn: pgn,
      requestedUrl: uri,
      hasMore: games.length >= pageSize,
      nextUntil: nextUntil,
    );
  }

  Uri buildGamesUri({
    required LichessPgnFetchOptions options,
    int pageSize = 20,
    int? untilCursor,
  }) {
    final playerId = options.playerId.trim();
    if (playerId.isEmpty) {
      throw const LichessPgnException('Enter a Lichess player id first.');
    }
    final parsedBase = Uri.parse(baseUri);
    final pathPrefix = parsedBase.path.endsWith('/')
        ? parsedBase.path.substring(0, parsedBase.path.length - 1)
        : parsedBase.path;
    final values = <String, String>{
      'max': pageSize.clamp(1, 5000).toString(),
      'pgnInJson': 'false',
      'clocks': 'false',
      'evals': 'false',
      'opening': 'true',
      'tags': 'true',
    };
    final since = _dateMillis(options.since);
    if (since != null) values['since'] = since.toString();
    final until = untilCursor ?? _dateMillis(options.until);
    if (until != null) values['until'] = until.toString();
    if (options.speed.trim().isNotEmpty && options.speed != 'all') {
      values['perfType'] = options.speed.trim();
    }
    if (options.rated == 'true' || options.rated == 'false') {
      values['rated'] = options.rated;
    }
    if (options.color == 'white' || options.color == 'black') {
      values['color'] = options.color;
    }
    final uri = parsedBase.replace(
      path: '$pathPrefix/api/games/user/${Uri.encodeComponent(playerId)}',
      queryParameters: values,
    );
    return uri;
  }
}

class LichessPgnException implements Exception {
  const LichessPgnException(this.message);

  final String message;

  @override
  String toString() => message;
}

List<String> splitPgnGames(String pgn, {int? limit}) {
  final trimmed = pgn.trim();
  if (trimmed.isEmpty || limit == 0) return const [];
  final eventMatches =
      RegExp(r'(?=^\[Event\s+")', multiLine: true).allMatches(trimmed);
  final games = <String>[];
  int? currentStart;
  for (final match in eventMatches) {
    final start = match.start;
    if (currentStart != null) {
      final game = trimmed.substring(currentStart, start).trim();
      if (game.isNotEmpty) {
        games.add(game);
        if (limit != null && games.length >= limit) return games;
      }
    }
    currentStart = start;
  }
  if (currentStart == null) return [trimmed];
  if (limit == null || games.length < limit) {
    final game = trimmed.substring(currentStart).trim();
    if (game.isNotEmpty) games.add(game);
  }
  return games;
}

int? nextUntilCursorFromPgn(String pgn) {
  final starts = <int>[];
  final utcDate = RegExp(r'^\[UTCDate\s+"([^"]+)"\]$', multiLine: true);
  final utcTime = RegExp(r'^\[UTCTime\s+"([^"]+)"\]$', multiLine: true);
  for (final game in splitPgnGames(pgn)) {
    final date = utcDate.firstMatch(game)?.group(1);
    final time = utcTime.firstMatch(game)?.group(1);
    if (date == null || time == null) continue;
    final normalizedDate = date.replaceAll('.', '-');
    final parsed = DateTime.tryParse('${normalizedDate}T${time}Z');
    if (parsed != null) starts.add(parsed.millisecondsSinceEpoch);
  }
  if (starts.isEmpty) return null;
  starts.sort();
  return starts.first - 1;
}

int? _dateMillis(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  if (RegExp(r'^\d+$').hasMatch(trimmed)) return int.tryParse(trimmed);
  final normalized = trimmed.replaceAll('.', '-');
  final dateOnly = RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$');
  final parsed = DateTime.tryParse(
    dateOnly.hasMatch(normalized) ? '${normalized}T00:00:00Z' : normalized,
  );
  if (parsed == null) {
    throw const LichessPgnException(
      'Use YYYY-MM-DD or a millisecond timestamp for Lichess date filters.',
    );
  }
  return parsed.toUtc().millisecondsSinceEpoch;
}
