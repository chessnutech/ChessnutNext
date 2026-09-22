import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class LichessSeekRequest {
  const LichessSeekRequest({
    required this.timeMinutes,
    required this.incrementSeconds,
    this.rated = false,
    this.variant = 'standard',
    this.color = 'random',
    this.ratingRange,
  });

  final bool rated;
  final int timeMinutes;
  final int incrementSeconds;
  final String variant;
  final String color;
  final String? ratingRange;

  Map<String, String> toFormFields() {
    return {
      'rated': rated.toString(),
      'time': timeMinutes.toString(),
      'increment': incrementSeconds.toString(),
      'variant': variant,
      'color': color,
      if (ratingRange != null && ratingRange!.trim().isNotEmpty)
        'ratingRange': ratingRange!,
    };
  }
}

class LichessFriend {
  const LichessFriend({
    required this.id,
    required this.username,
    this.title = '',
    this.online = false,
    this.disabled = false,
    this.ratings = const {},
  });

  factory LichessFriend.fromJson(Map<String, dynamic> json) {
    final perfs = json['perfs'];
    final ratings = <String, int>{};
    if (perfs is Map) {
      for (final entry in perfs.entries) {
        final value = entry.value;
        if (value is Map) {
          final rating = _optionalInt(value['rating']);
          if (rating != null) ratings[entry.key.toString()] = rating;
        }
      }
    }
    return LichessFriend(
      id: _string(json['id']).trim(),
      username: (_string(json['username']).trim().isNotEmpty
              ? _string(json['username'])
              : _string(json['name']))
          .trim(),
      title: _string(json['title']).trim(),
      online: _optionalBool(json['online']) ?? false,
      disabled: _optionalBool(json['disabled']) ?? false,
      ratings: Map.unmodifiable(ratings),
    );
  }

  final String id;
  final String username;
  final String title;
  final bool online;
  final bool disabled;
  final Map<String, int> ratings;

  int? ratingFor(String speed) => ratings[speed.trim().toLowerCase()];
}

class LichessChallengeRequest {
  const LichessChallengeRequest({
    required this.username,
    required this.timeMinutes,
    required this.incrementSeconds,
    this.rated = false,
    this.variant = 'standard',
    this.color = 'random',
  });

  final String username;
  final int timeMinutes;
  final int incrementSeconds;
  final bool rated;
  final String variant;
  final String color;

  Map<String, String> toFormFields() => {
        if (timeMinutes > 0) 'clock.limit': '${timeMinutes * 60}',
        if (timeMinutes > 0) 'clock.increment': '$incrementSeconds',
        'rated': rated.toString(),
        'variant': variant,
        'color': color,
        'keepAliveStream': 'true',
      };
}

class LichessChallenge {
  const LichessChallenge({
    required this.id,
    this.opponentName = '',
    this.opponentTitle = '',
    this.direction = '',
    this.status = '',
    this.variant = '',
    this.speed = '',
    this.color = 'random',
    this.rated = false,
    this.timeMinutes = 0,
    this.incrementSeconds = 0,
  });

  factory LichessChallenge.fromJson(
    Map<String, dynamic> json, {
    String localLichessName = '',
  }) {
    final challenger = _map(json['challenger']);
    final destination = _map(json['destUser']);
    final direction = _string(json['direction']).trim().toLowerCase();
    final local = _normalizeName(localLichessName);
    Map<String, dynamic> opponent;
    if (direction == 'in') {
      opponent = challenger;
    } else if (direction == 'out') {
      opponent = destination;
    } else if (_normalizeName(_challengeUserName(challenger)) == local) {
      opponent = destination;
    } else {
      opponent = challenger;
    }
    final timeControl = _map(json['timeControl']);
    final limitSeconds = _optionalInt(timeControl['limit']) ?? 0;
    final variant = _map(json['variant']);
    return LichessChallenge(
      id: _string(json['id']).trim(),
      opponentName: _challengeUserName(opponent),
      opponentTitle: _string(opponent['title']).trim(),
      direction: direction,
      status: _string(json['status']).trim().toLowerCase(),
      variant: (_string(variant['key']).trim().isNotEmpty
              ? _string(variant['key'])
              : _string(json['variant']))
          .trim()
          .toLowerCase(),
      speed: _string(json['speed']).trim().toLowerCase(),
      color: _string(json['color']).trim().toLowerCase(),
      rated: _optionalBool(json['rated']) ?? false,
      timeMinutes: limitSeconds <= 0 ? 0 : limitSeconds ~/ 60,
      incrementSeconds: _optionalInt(timeControl['increment']) ?? 0,
    );
  }

  final String id;
  final String opponentName;
  final String opponentTitle;
  final String direction;
  final String status;
  final String variant;
  final String speed;
  final String color;
  final bool rated;
  final int timeMinutes;
  final int incrementSeconds;

  bool get supportsBoardApi =>
      variant == 'standard' &&
      const {'blitz', 'rapid', 'classical', 'correspondence', 'unlimited'}
          .contains(speed);
}

enum LichessChallengeProgressState {
  created,
  accepted,
  declined,
  canceled,
  expired,
  failed,
}

class LichessChallengeProgress {
  const LichessChallengeProgress({
    required this.state,
    this.challenge,
    this.message,
  });

  final LichessChallengeProgressState state;
  final LichessChallenge? challenge;
  final String? message;
}

enum LichessBoardEventType {
  gameFull,
  gameState,
  gameStart,
  challenge,
  challengeCanceled,
  challengeDeclined,
  gameFinish,
  unknown,
}

enum LichessPlayerSide { white, black, none }

class LichessOngoingGame {
  const LichessOngoingGame({
    required this.gameId,
    this.fullId = '',
    this.color = LichessPlayerSide.none,
    this.fen = '',
    this.lastMove = '',
    this.opponentName = '',
    this.source = '',
    this.opponentIsAi = false,
    this.speed = '',
    this.variant = '',
    this.secondsLeft,
    this.hasMoved = false,
    this.isMyTurn = false,
  });

  factory LichessOngoingGame.fromJson(Map<String, dynamic> json) {
    final opponent = json['opponent'];
    final opponentMap = opponent is Map
        ? opponent.cast<String, dynamic>()
        : const <String, dynamic>{};
    final variant = json['variant'];
    final variantMap = variant is Map
        ? variant.cast<String, dynamic>()
        : const <String, dynamic>{};
    final color = json['color']?.toString().trim().toLowerCase();
    return LichessOngoingGame(
      gameId: _string(json['gameId']).trim(),
      fullId: _string(json['fullId']).trim(),
      color: switch (color) {
        'white' => LichessPlayerSide.white,
        'black' => LichessPlayerSide.black,
        _ => LichessPlayerSide.none,
      },
      fen: _string(json['fen']).trim(),
      lastMove: _string(json['lastMove']).trim(),
      opponentName: (_string(opponentMap['username']).trim().isNotEmpty
              ? _string(opponentMap['username'])
              : _string(opponentMap['id']))
          .trim(),
      source: _string(json['source']).trim(),
      opponentIsAi: opponentMap['ai'] != null,
      speed: _string(json['speed']).trim(),
      variant: (_string(variantMap['key']).trim().isNotEmpty
              ? _string(variantMap['key'])
              : _string(variant))
          .trim(),
      secondsLeft: _optionalInt(json['secondsLeft']),
      hasMoved: _optionalBool(json['hasMoved']) ?? false,
      isMyTurn: _optionalBool(json['isMyTurn']) ?? false,
    );
  }

  final String gameId;
  final String fullId;
  final LichessPlayerSide color;
  final String fen;
  final String lastMove;
  final String opponentName;

  /// Lichess game source. Board API games are reported with source `api`.
  final String source;
  final bool opponentIsAi;
  final String speed;
  final String variant;
  final int? secondsLeft;
  final bool hasMoved;
  final bool isMyTurn;

  /// Whether the game is compatible with the Lichess Board API.
  ///
  /// This mirrors Lichess' `Game.isBoardCompatible` rule using the fields
  /// returned by `/api/account/playing`: rapid and slower games are compatible;
  /// faster games are compatible only when created by the Board API, a friend,
  /// or an AI opponent. Correspondence/unlimited games have no live clock and
  /// are also supported. No per-game Board API request is needed.
  bool get supportsBoardApi {
    final normalizedSpeed = speed.trim().toLowerCase();
    if (normalizedSpeed == 'correspondence' ||
        normalizedSpeed == 'classical' ||
        normalizedSpeed == 'rapid' ||
        normalizedSpeed == 'unlimited') {
      return true;
    }
    if (normalizedSpeed == 'blitz') {
      final normalizedSource = source.trim().toLowerCase();
      return opponentIsAi ||
          normalizedSource == 'friend' ||
          normalizedSource == 'api';
    }
    return false;
  }
}

class LichessBoardEvent {
  const LichessBoardEvent({
    required this.type,
    this.gameId,
    this.initialFen,
    this.moves,
    this.status,
    this.winner,
    this.whiteTimeMs,
    this.blackTimeMs,
    this.clockInitialMs,
    this.clockIncrementMs,
    this.rated,
    this.whiteName,
    this.blackName,
    this.whiteRating,
    this.blackRating,
    this.drawOfferFrom,
    this.localSide = LichessPlayerSide.none,
    this.raw = const {},
  });

  factory LichessBoardEvent.fromJson(
    Map<String, dynamic> json, {
    String localLichessName = '',
  }) {
    final type = json['type']?.toString() ?? '';
    final state = json['state'];
    final stateMap = state is Map ? state.cast<String, dynamic>() : null;
    final game = json['game'];
    final gameMap = game is Map ? game.cast<String, dynamic>() : null;
    final clock = json['clock'];
    final clockMap = clock is Map
        ? clock.cast<String, dynamic>()
        : stateMap?['clock'] is Map
            ? (stateMap!['clock'] as Map).cast<String, dynamic>()
            : null;
    final initialFen = json['initialFen']?.toString();
    final white = _player(json['white']);
    final black = _player(json['black']);
    final localSide = _localSide(
      localLichessName: localLichessName,
      white: white,
      black: black,
    );

    return LichessBoardEvent(
      type: switch (type) {
        'gameFull' => LichessBoardEventType.gameFull,
        'gameState' => LichessBoardEventType.gameState,
        'gameStart' => LichessBoardEventType.gameStart,
        'challenge' => LichessBoardEventType.challenge,
        'challengeCanceled' => LichessBoardEventType.challengeCanceled,
        'challengeDeclined' => LichessBoardEventType.challengeDeclined,
        'gameFinish' => LichessBoardEventType.gameFinish,
        _ => LichessBoardEventType.unknown,
      },
      gameId: (json['id'] ?? gameMap?['id'])?.toString(),
      initialFen: initialFen == 'startpos'
          ? LichessBoardService.startposFen
          : initialFen,
      moves: (json['moves'] ?? stateMap?['moves'])?.toString(),
      status: _normalizedLichessStateValue(
        json['status'] ?? stateMap?['status'],
      ),
      winner: _normalizedLichessStateValue(
        json['winner'] ?? stateMap?['winner'],
      ),
      whiteTimeMs: _optionalInt(json['wtime'] ?? stateMap?['wtime']),
      blackTimeMs: _optionalInt(json['btime'] ?? stateMap?['btime']),
      clockInitialMs: _optionalInt(clockMap?['initial']),
      clockIncrementMs: _optionalInt(clockMap?['increment']),
      rated: _optionalBool(json['rated'] ?? gameMap?['rated']),
      whiteName: white.displayName,
      blackName: black.displayName,
      whiteRating: white.rating,
      blackRating: black.rating,
      drawOfferFrom: _drawOfferFrom(
        json['wdraw'] ?? stateMap?['wdraw'],
        json['bdraw'] ?? stateMap?['bdraw'],
      ),
      localSide: localSide,
      raw: Map.unmodifiable(json),
    );
  }

  final LichessBoardEventType type;
  final String? gameId;
  final String? initialFen;
  final String? moves;
  final String? status;
  final String? winner;
  final int? whiteTimeMs;
  final int? blackTimeMs;
  final int? clockInitialMs;
  final int? clockIncrementMs;
  final bool? rated;
  final String? whiteName;
  final String? blackName;
  final int? whiteRating;
  final int? blackRating;
  final LichessPlayerSide? drawOfferFrom;
  final LichessPlayerSide localSide;
  final Map<String, dynamic> raw;

  String get opponentName {
    return switch (localSide) {
      LichessPlayerSide.white => blackName ?? '',
      LichessPlayerSide.black => whiteName ?? '',
      LichessPlayerSide.none => '',
    };
  }
}

LichessPlayerSide? _drawOfferFrom(Object? whiteOffer, Object? blackOffer) {
  bool isTrue(Object? value) => value == true || value?.toString() == 'true';
  if (isTrue(whiteOffer)) return LichessPlayerSide.white;
  if (isTrue(blackOffer)) return LichessPlayerSide.black;
  return null;
}

class LichessGameSnapshot {
  const LichessGameSnapshot({
    required this.canContinue,
    this.status,
    this.winner,
    this.moves,
    this.initialFen,
    this.whiteTimeMs,
    this.blackTimeMs,
    this.clockInitialMs,
    this.clockIncrementMs,
    this.whiteName,
    this.blackName,
    this.localSide = LichessPlayerSide.none,
    this.rated,
    this.errorMessage,
  });

  final bool canContinue;
  final String? status;
  final String? winner;
  final String? moves;
  final String? initialFen;
  final int? whiteTimeMs;
  final int? blackTimeMs;
  final int? clockInitialMs;
  final int? clockIncrementMs;
  final String? whiteName;
  final String? blackName;
  final LichessPlayerSide localSide;
  final bool? rated;
  final String? errorMessage;

  String get resultToken {
    if (winner == 'white') return '1-0';
    if (winner == 'black') return '0-1';
    final normalized = status ?? '';
    if (normalized == 'draw' ||
        normalized == 'stalemate' ||
        normalized == 'outoftime' ||
        normalized == 'mate' ||
        normalized == 'timeout' ||
        normalized == 'resign' ||
        normalized == 'aborted') {
      return '1/2-1/2';
    }
    return '*';
  }
}

class LichessBoardService {
  LichessBoardService({
    required this.token,
    this.localLichessName = '',
    this.commandRateLimit = const Duration(seconds: 1),
    http.Client? httpClient,
    Uri? baseUri,
    DateTime Function()? commandClock,
    Future<void> Function(Duration)? commandDelay,
  })  : _httpClient = httpClient ?? http.Client(),
        _commandClock = commandClock ?? DateTime.now,
        _commandDelay = commandDelay ?? Future<void>.delayed,
        baseUri = baseUri ?? Uri.https('lichess.org');

  static const startposFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  static const unlimitedClockThresholdMs = 999999000;

  static bool isUnlimitedClock(int? initialMs) =>
      initialMs != null && initialMs >= unlimitedClockThresholdMs;

  final String token;
  final String localLichessName;
  final Duration commandRateLimit;
  final http.Client _httpClient;
  final DateTime Function() _commandClock;
  final Future<void> Function(Duration) _commandDelay;
  final Uri baseUri;
  Future<void> _commandQueue = Future<void>.value();
  DateTime? _lastCommandStartedAt;
  String? _lastErrorMessage;
  String? _lastStreamErrorMessage;
  int? _lastStatusCode;

  Map<String, String> get authHeaders => {'Authorization': 'Bearer $token'};
  String? get lastErrorMessage => _lastErrorMessage;
  String? get lastStreamErrorMessage => _lastStreamErrorMessage;
  int? get lastStatusCode => _lastStatusCode;

  Future<List<LichessFriend>?> getFollowing() async {
    _clearLastError();
    final request = http.Request('GET', _uri('api/rel/following'))
      ..headers.addAll(authHeaders);
    late final http.StreamedResponse response;
    try {
      response = await _httpClient.send(request);
    } catch (error) {
      _setLastError(_networkErrorMessage(error));
      return null;
    }
    _lastStatusCode = response.statusCode;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      _setLastError(_lichessErrorMessageFromResponse(
        statusCode: response.statusCode,
        reasonPhrase: response.reasonPhrase,
        body: body,
      ));
      return null;
    }
    final friends = <LichessFriend>[];
    try {
      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          final friend = LichessFriend.fromJson(
            decoded.cast<String, dynamic>(),
          );
          if (friend.id.isNotEmpty && friend.username.isNotEmpty) {
            friends.add(friend);
          }
        }
      }
      friends.sort((a, b) {
        if (a.online != b.online) return a.online ? -1 : 1;
        return a.username.toLowerCase().compareTo(b.username.toLowerCase());
      });
      return List.unmodifiable(friends);
    } catch (_) {
      _setLastError('Lichess returned an unreadable response.');
      return null;
    }
  }

  Future<List<LichessChallenge>?> getChallenges() async {
    _clearLastError();
    late final http.Response response;
    try {
      response = await _httpClient.get(
        _uri('api/challenge'),
        headers: authHeaders,
      );
    } catch (error) {
      _setLastError(_networkErrorMessage(error));
      return null;
    }
    _lastStatusCode = response.statusCode;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _setLastError(_lichessErrorMessageFromResponse(
        statusCode: response.statusCode,
        reasonPhrase: response.reasonPhrase,
        body: response.body,
      ));
      return null;
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw const FormatException();
      final incoming = decoded['in'];
      if (incoming is! List) return const [];
      return List.unmodifiable([
        for (final item in incoming)
          if (item is Map)
            LichessChallenge.fromJson(
              item.cast<String, dynamic>(),
              localLichessName: localLichessName,
            ),
      ].where((challenge) => challenge.id.isNotEmpty));
    } catch (_) {
      _setLastError('Lichess returned an unreadable response.');
      return null;
    }
  }

  Stream<LichessChallengeProgress> createChallenge(
    LichessChallengeRequest challengeRequest,
  ) async* {
    _clearLastError(stream: true);
    final request = http.Request(
      'POST',
      _uri('api/challenge/${Uri.encodeComponent(challengeRequest.username)}'),
    )
      ..headers.addAll(authHeaders)
      ..bodyFields = challengeRequest.toFormFields();
    late final http.StreamedResponse response;
    try {
      response = await _httpClient.send(request);
    } catch (error) {
      final message = _networkErrorMessage(error);
      _setLastError(message, stream: true);
      yield LichessChallengeProgress(
        state: LichessChallengeProgressState.failed,
        message: message,
      );
      return;
    }
    _lastStatusCode = response.statusCode;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      final message = _lichessErrorMessageFromResponse(
        statusCode: response.statusCode,
        reasonPhrase: response.reasonPhrase,
        body: body,
      );
      _setLastError(message, stream: true);
      yield LichessChallengeProgress(
        state: LichessChallengeProgressState.failed,
        message: message,
      );
      return;
    }

    LichessChallenge? challenge;
    var terminal = false;
    try {
      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final decoded = jsonDecode(trimmed);
        if (decoded is! Map) continue;
        final map = decoded.cast<String, dynamic>();
        final challengeJson = map['challenge'] is Map
            ? (map['challenge'] as Map).cast<String, dynamic>()
            : map.containsKey('id')
                ? map
                : null;
        if (challengeJson != null) {
          challenge = LichessChallenge.fromJson(
            challengeJson,
            localLichessName: localLichessName,
          );
          yield LichessChallengeProgress(
            state: LichessChallengeProgressState.created,
            challenge: challenge,
          );
        }
        final done = _string(map['done']).trim().toLowerCase();
        final state = switch (done) {
          'accepted' => LichessChallengeProgressState.accepted,
          'declined' => LichessChallengeProgressState.declined,
          'canceled' || 'cancelled' => LichessChallengeProgressState.canceled,
          'expired' => LichessChallengeProgressState.expired,
          _ => null,
        };
        if (state != null) {
          terminal = true;
          yield LichessChallengeProgress(
            state: state,
            challenge: challenge,
          );
        }
      }
      if (!terminal) {
        yield LichessChallengeProgress(
          state: LichessChallengeProgressState.expired,
          challenge: challenge,
        );
      }
    } catch (error) {
      final message = _networkErrorMessage(error);
      _setLastError(message, stream: true);
      yield LichessChallengeProgress(
        state: LichessChallengeProgressState.failed,
        challenge: challenge,
        message: message,
      );
    }
  }

  Future<bool> acceptChallenge(String challengeId) {
    return _postCommandOk(_uri('api/challenge/$challengeId/accept'));
  }

  Future<bool> declineChallenge(String challengeId) {
    return _postCommandOk(_uri('api/challenge/$challengeId/decline'));
  }

  Future<bool> cancelChallenge(String challengeId) {
    return _postCommandOk(_uri('api/challenge/$challengeId/cancel'));
  }

  Future<List<LichessOngoingGame>?> getOngoingGames() async {
    _clearLastError();
    late final http.Response response;
    try {
      response = await _httpClient.get(
        _uri('api/account/playing', queryParameters: const {'nb': '50'}),
        headers: authHeaders,
      );
    } catch (error) {
      _setLastError(_networkErrorMessage(error));
      return null;
    }
    _lastStatusCode = response.statusCode;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _setLastError(_lichessErrorMessageFromResponse(
        statusCode: response.statusCode,
        reasonPhrase: response.reasonPhrase,
        body: response.body,
      ));
      return null;
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        _setLastError('Lichess returned an unreadable response.');
        return null;
      }
      final nowPlaying = decoded['nowPlaying'];
      if (nowPlaying == null) return const [];
      if (nowPlaying is! List) {
        _setLastError('Lichess returned an unreadable response.');
        return null;
      }
      return [
        for (final item in nowPlaying)
          if (item is Map)
            LichessOngoingGame.fromJson(item.cast<String, dynamic>()),
      ].where((game) => game.gameId.isNotEmpty).toList(growable: false);
    } catch (_) {
      _setLastError('Lichess returned an unreadable response.');
      return null;
    }
  }

  Future<bool> createSeek(LichessSeekRequest request) async {
    _clearLastError();
    final httpRequest = http.Request('POST', _uri('api/board/seek'))
      ..headers.addAll(authHeaders)
      ..bodyFields = request.toFormFields();
    late final http.StreamedResponse response;
    try {
      response = await _httpClient.send(httpRequest);
    } catch (error) {
      _setLastError(_networkErrorMessage(error));
      return false;
    }
    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (!ok) {
      final body = await response.stream.bytesToString();
      _setLastError(_lichessErrorMessageFromResponse(
        statusCode: response.statusCode,
        reasonPhrase: response.reasonPhrase,
        body: body,
      ));
      return false;
    }
    unawaited(response.stream.drain<void>());
    return ok;
  }

  Stream<LichessBoardEvent> streamEvents() {
    return _streamNdjson(_uri('api/stream/event'));
  }

  Stream<LichessBoardEvent> streamGame(String gameId) {
    return _streamNdjson(_uri('api/board/game/stream/$gameId'));
  }

  Future<LichessGameSnapshot> checkGame(String gameId) async {
    await for (final event in streamGame(gameId)) {
      if (event.type != LichessBoardEventType.gameFull &&
          event.type != LichessBoardEventType.gameState) {
        continue;
      }
      final status = event.status?.toLowerCase();
      final winner = event.winner?.toLowerCase();
      final canContinue =
          status == null || status == 'started' || status == 'created';
      return LichessGameSnapshot(
        canContinue: canContinue,
        status: status,
        winner: winner,
        moves: event.moves,
        initialFen: event.initialFen,
        whiteTimeMs: event.whiteTimeMs,
        blackTimeMs: event.blackTimeMs,
        clockInitialMs: event.clockInitialMs,
        clockIncrementMs: event.clockIncrementMs,
        whiteName: event.whiteName,
        blackName: event.blackName,
        localSide: event.localSide,
        rated: event.rated,
      );
    }
    return LichessGameSnapshot(
      canContinue: false,
      errorMessage: lastErrorMessage,
    );
  }

  Future<String?> waitForGameStart({
    Duration timeout = const Duration(minutes: 3),
    void Function(bool ready)? onConnectionReady,
    int? expectedInitialTimeMs,
    int? expectedIncrementMs,
  }) async {
    try {
      await for (final event in _streamNdjson(
        _uri('api/stream/event'),
        onConnectionReady: onConnectionReady,
      ).timeout(timeout)) {
        if (event.type == LichessBoardEventType.gameStart &&
            event.gameId != null &&
            event.gameId!.isNotEmpty) {
          if ((expectedInitialTimeMs != null || expectedIncrementMs != null) &&
              !await _gameMatchesTimeControl(
                event.gameId!,
                expectedInitialTimeMs: expectedInitialTimeMs,
                expectedIncrementMs: expectedIncrementMs,
              )) {
            continue;
          }
          return event.gameId;
        }
      }
    } on TimeoutException {
      return null;
    }
    return null;
  }

  Future<bool> _gameMatchesTimeControl(
    String gameId, {
    int? expectedInitialTimeMs,
    int? expectedIncrementMs,
  }) async {
    await for (final event in streamGame(gameId)) {
      if (event.type != LichessBoardEventType.gameFull) continue;
      final initialMatches = expectedInitialTimeMs == null ||
          (expectedInitialTimeMs <= 0
              ? isUnlimitedClock(event.clockInitialMs)
              : event.clockInitialMs == expectedInitialTimeMs);
      final incrementMatches = expectedIncrementMs == null ||
          event.clockIncrementMs == expectedIncrementMs;
      return initialMatches && incrementMatches;
    }
    return false;
  }

  Future<bool> makeMove({
    required String gameId,
    required String uci,
    bool offeringDraw = false,
  }) {
    final uri = _uri(
      'api/board/game/$gameId/move/$uci',
      queryParameters: offeringDraw ? const {'offeringDraw': 'true'} : const {},
    );
    return _postCommandOk(uri);
  }

  Future<bool> resign(String gameId) {
    return _postCommandOk(_uri('api/board/game/$gameId/resign'));
  }

  Future<bool> offerOrAcceptDraw({
    required String gameId,
    required bool accept,
  }) {
    return _postCommandOk(
        _uri('api/board/game/$gameId/draw/${accept ? 'yes' : 'no'}'));
  }

  Future<bool> offerOrAcceptTakeback({
    required String gameId,
    required bool accept,
  }) {
    return _postCommandOk(
      _uri('api/board/game/$gameId/takeback/${accept ? 'yes' : 'no'}'),
    );
  }

  Future<bool> _postCommandOk(Uri uri) {
    return _runCommand(() => _postOk(uri));
  }

  Future<T> _runCommand<T>(Future<T> Function() operation) {
    final previous = _commandQueue;
    final current = Completer<void>();
    _commandQueue = current.future;
    return () async {
      await previous;
      try {
        await _waitForCommandSlot();
        return await operation();
      } finally {
        if (!current.isCompleted) current.complete();
      }
    }();
  }

  Future<void> _waitForCommandSlot() async {
    final lastStartedAt = _lastCommandStartedAt;
    if (lastStartedAt != null && commandRateLimit > Duration.zero) {
      final elapsed = _commandClock().difference(lastStartedAt);
      final remaining = commandRateLimit - elapsed;
      if (remaining > Duration.zero) {
        await _commandDelay(remaining);
      }
    }
    _lastCommandStartedAt = _commandClock();
  }

  Future<bool> _postOk(Uri uri) async {
    _clearLastError();
    late final http.Response response;
    try {
      response = await _httpClient.post(uri, headers: authHeaders);
    } catch (error) {
      _setLastError(_networkErrorMessage(error));
      return false;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _setLastError(_lichessErrorMessageFromResponse(
        statusCode: response.statusCode,
        reasonPhrase: response.reasonPhrase,
        body: response.body,
      ));
      return false;
    }
    final body = response.body.trim();
    if (body.isEmpty) return true;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final ok = decoded['ok'] == true;
        if (!ok) {
          _setLastError(
            _lichessErrorMessageFromBody(body) ??
                'Lichess rejected the request.',
          );
        }
        return ok;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  Stream<LichessBoardEvent> _streamNdjson(
    Uri uri, {
    void Function(bool ready)? onConnectionReady,
  }) async* {
    _clearLastError(stream: true);
    final request = http.Request('GET', uri)..headers.addAll(authHeaders);
    late final http.StreamedResponse response;
    try {
      response = await _httpClient.send(request);
    } catch (error) {
      if (_lastStreamErrorMessage == null) {
        _setLastError(_networkErrorMessage(error), stream: true);
      }
      onConnectionReady?.call(false);
      return;
    }
    final ok = response.statusCode >= 200 && response.statusCode < 300;
    _lastStatusCode = response.statusCode;
    if (!ok) {
      final body = await response.stream.bytesToString();
      _setLastError(
          _lichessErrorMessageFromResponse(
            statusCode: response.statusCode,
            reasonPhrase: response.reasonPhrase,
            body: body,
          ),
          stream: true);
      onConnectionReady?.call(false);
      return;
    }
    onConnectionReady?.call(true);
    final lines =
        response.stream.transform(utf8.decoder).transform(const LineSplitter());
    try {
      await for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        late final Object? decoded;
        try {
          decoded = jsonDecode(trimmed);
        } catch (_) {
          _setLastError('Lichess returned an unreadable response.',
              stream: true);
          rethrow;
        }
        if (decoded is Map<String, dynamic>) {
          yield LichessBoardEvent.fromJson(
            decoded,
            localLichessName: localLichessName,
          );
        } else if (decoded is Map) {
          yield LichessBoardEvent.fromJson(
            decoded.cast<String, dynamic>(),
            localLichessName: localLichessName,
          );
        }
      }
    } catch (error) {
      if (_lastStreamErrorMessage == null) {
        _setLastError(_networkErrorMessage(error), stream: true);
      }
      rethrow;
    }
  }

  Uri _uri(String path, {Map<String, String> queryParameters = const {}}) {
    return baseUri.replace(
      path: path,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
  }

  void _clearLastError({bool stream = false}) {
    _lastErrorMessage = null;
    _lastStatusCode = null;
    if (stream) _lastStreamErrorMessage = null;
  }

  void _setLastError(String message, {bool stream = false}) {
    final compact = _compactLichessUserMessage(message);
    _lastErrorMessage = compact;
    if (stream) _lastStreamErrorMessage = compact;
  }
}

int? _optionalInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool? _optionalBool(Object? value) {
  if (value is bool) return value;
  return switch (value?.toString().trim().toLowerCase()) {
    'true' => true,
    'false' => false,
    _ => null,
  };
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : const <String, dynamic>{};

String _challengeUserName(Map<String, dynamic> user) {
  for (final value in [user['name'], user['username'], user['id']]) {
    final text = _string(value).trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

_LichessPlayer _player(Object? value) {
  if (value is! Map) return const _LichessPlayer();
  final map = value.cast<String, dynamic>();
  // Board API normally returns the player fields directly.  Some Lichess
  // game types (notably games against the built-in AI) wrap the account in a
  // `user` object and expose only `aiLevel` at the player level.  Accept both
  // shapes so the opponent never falls back to a generic label.
  final nestedUser = map['user'];
  final userMap = nestedUser is Map
      ? nestedUser.cast<String, dynamic>()
      : const <String, dynamic>{};
  String firstText(List<Object?> values) {
    for (final value in values) {
      final text = _string(value).trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  final id = firstText([map['id'], userMap['id']]);
  final explicitName = firstText([
    map['name'],
    map['username'],
    userMap['name'],
    userMap['username'],
  ]);
  final aiLevel = _optionalInt(map['aiLevel'] ?? userMap['aiLevel']);
  return _LichessPlayer(
    id: id,
    name: explicitName,
    aiLevel: aiLevel,
    rating: _optionalInt(
      map['rating'] ?? map['elo'] ?? userMap['rating'] ?? userMap['elo'],
    ),
  );
}

LichessPlayerSide _localSide({
  required String localLichessName,
  required _LichessPlayer white,
  required _LichessPlayer black,
}) {
  final local = _normalizeName(localLichessName);
  if (local.isEmpty) return LichessPlayerSide.none;
  if (white.matches(local)) return LichessPlayerSide.white;
  if (black.matches(local)) return LichessPlayerSide.black;
  return LichessPlayerSide.none;
}

String _normalizeName(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
}

String? _normalizedLichessStateValue(Object? value) {
  final normalized = value?.toString().trim().toLowerCase();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String _string(Object? value) => value?.toString() ?? '';

String _lichessErrorMessageFromResponse({
  required int statusCode,
  required String? reasonPhrase,
  required String body,
}) {
  final parsed = _lichessErrorMessageFromBody(body);
  if (parsed != null) return parsed;
  final reason = reasonPhrase?.trim();
  if (reason != null && reason.isNotEmpty) {
    return 'HTTP $statusCode $reason';
  }
  return 'HTTP $statusCode';
}

String? _lichessErrorMessageFromBody(String body) {
  final compact = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.isEmpty) return null;
  try {
    final decoded = jsonDecode(body);
    final parsed = _lichessErrorMessageFromJson(decoded);
    if (parsed != null) return parsed;
  } catch (_) {
    return _compactLichessUserMessage(compact);
  }
  return _compactLichessUserMessage(compact);
}

String? _lichessErrorMessageFromJson(Object? value) {
  if (value == null) return null;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is List) {
    for (final item in value) {
      final parsed = _lichessErrorMessageFromJson(item);
      if (parsed != null) return parsed;
    }
    return null;
  }
  if (value is Map) {
    for (final key in const ['error', 'message', 'info', 'reason']) {
      final parsed = _lichessErrorMessageFromJson(value[key]);
      if (parsed != null) return parsed;
    }
    final errors = _lichessErrorMessageFromJson(value['errors']);
    if (errors != null) return errors;
  }
  return null;
}

String _networkErrorMessage(Object error) {
  final text = error.toString().trim();
  if (text.isEmpty) return 'Network error';
  return 'Network error: $text';
}

String _compactLichessUserMessage(String message) {
  final compact = message.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= 240) return compact;
  return '${compact.substring(0, 240)}...';
}

class _LichessPlayer {
  const _LichessPlayer({
    this.id = '',
    this.name = '',
    this.aiLevel,
    this.rating,
  });

  final String id;
  final String name;
  final int? aiLevel;
  final int? rating;

  String? get displayName {
    final cleanName = name.trim();
    if (cleanName.isNotEmpty) return cleanName;
    final level = aiLevel;
    if (level != null) return 'Lichess AI level $level';
    final cleanId = id.trim();
    if (cleanId.isNotEmpty) return cleanId;
    return null;
  }

  bool matches(String normalizedLocalName) {
    return _normalizeName(id) == normalizedLocalName ||
        _normalizeName(name) == normalizedLocalName;
  }
}
