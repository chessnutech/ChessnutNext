import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'chessnut_endpoint_config.dart';
import 'model_build_source_service.dart';

class ChessnutApiSession {
  const ChessnutApiSession({
    required this.userId,
    required this.token,
    this.refreshToken,
  });

  final int userId;
  final String token;
  final String? refreshToken;
}

class ApiStatus {
  const ApiStatus._({
    required this.isSuccess,
    this.networkError,
    this.apiErrorCode,
    this.errorMessage,
  });

  const ApiStatus.success() : this._(isSuccess: true);

  const ApiStatus.network(String message)
      : this._(isSuccess: false, networkError: message, errorMessage: message);

  const ApiStatus.api({
    required int code,
    required String message,
  }) : this._(
          isSuccess: false,
          apiErrorCode: code,
          errorMessage: message,
        );

  final bool isSuccess;
  final String? networkError;
  final int? apiErrorCode;
  final String? errorMessage;
}

class ApiResult<T> {
  const ApiResult(this.status, {this.data});

  final ApiStatus status;
  final T? data;

  bool get isSuccess => status.isSuccess;
}

class MoveFirmwareRelease {
  const MoveFirmwareRelease({
    required this.version,
    required this.downloadUri,
  });

  final String version;
  final Uri downloadUri;

  static MoveFirmwareRelease? tryParse(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) return null;
      final version = decoded['version']?.toString().trim() ?? '';
      final download = decoded['download']?.toString().trim() ?? '';
      final uri = Uri.tryParse(download);
      if (version.isEmpty ||
          uri == null ||
          !uri.hasScheme ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        return null;
      }
      return MoveFirmwareRelease(version: version, downloadUri: uri);
    } catch (_) {
      return null;
    }
  }
}

bool isLichessAuthorizationExpiredStatus(ApiStatus status) {
  if (status.apiErrorCode == 600) return false;
  final message = (status.errorMessage ?? '').toLowerCase();
  if (!message.contains('lichess')) return false;
  return message.contains('expired') ||
      message.contains('失效') ||
      message.contains('重新绑定') ||
      message.contains('login again');
}

bool _isRefreshTokenExpiredStatus(ApiStatus status) {
  if (status.networkError != null) return false;
  return status.apiErrorCode == 501 || status.apiErrorCode == 600;
}

const walletServiceUnavailableMessage =
    'Wallet is not available right now. Check your connection and try again.';
const networkConnectionErrorMessage =
    'No internet connection. Check Wi-Fi or mobile data, then try again.';
const authTokenRefreshedRetryMessage = 'Login refreshed. Please try again.';
const authSessionExpiredMessage =
    'Your login has expired. Please sign in again.';
const int authTokenRefreshedRetryCode = 601;

const int _dailyCheckInWalletRewardPoints = 100;
const int _dailyTaskWalletRewardPoints = 20;

final Map<String, int> _walletRewardCorrectionsByAccount = {};

class ChessnutLoginSession extends ChessnutApiSession {
  const ChessnutLoginSession({
    required super.userId,
    required super.token,
    super.refreshToken,
    required this.avatarUrl,
    required this.bindApple,
    required this.bindChess,
    required this.bindGoogle,
    required this.bindLichess,
    required this.chessName,
    required this.email,
    required this.lichessName,
    required this.noPassword,
    required this.phone,
    required this.region,
    required this.username,
  });

  factory ChessnutLoginSession.fromJson(Map<String, dynamic> json) {
    return ChessnutLoginSession(
      avatarUrl: _string(json['avatar_url']),
      bindApple: _bool(json['bind_apple']),
      bindChess: _bool(json['bind_chess']),
      bindGoogle: _bool(json['bind_google']),
      bindLichess: _bool(json['bind_lichess']),
      chessName: _string(json['chess_name']),
      email: _string(json['email']),
      lichessName: _string(json['lichess_name']),
      noPassword: _bool(json['no_password']),
      phone: _string(json['phone']),
      region: _string(json['region']),
      token: _string(json['token']),
      refreshToken: _nullableString(json['refresh_token']),
      userId: _int(json['user_id']),
      username: _string(json['username']),
    );
  }

  final String avatarUrl;
  final bool bindApple;
  final bool bindChess;
  final bool bindGoogle;
  final bool bindLichess;
  final String chessName;
  final String email;
  final String lichessName;
  final bool noPassword;
  final String phone;
  final String region;
  final String username;

  ChessnutLoginSession copyWith({
    String? avatarUrl,
    bool? bindApple,
    bool? bindChess,
    bool? bindGoogle,
    bool? bindLichess,
    String? chessName,
    String? email,
    String? lichessName,
    bool? noPassword,
    String? phone,
    String? region,
    String? token,
    String? refreshToken,
    int? userId,
    String? username,
  }) {
    return ChessnutLoginSession(
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bindApple: bindApple ?? this.bindApple,
      bindChess: bindChess ?? this.bindChess,
      bindGoogle: bindGoogle ?? this.bindGoogle,
      bindLichess: bindLichess ?? this.bindLichess,
      chessName: chessName ?? this.chessName,
      email: email ?? this.email,
      lichessName: lichessName ?? this.lichessName,
      noPassword: noPassword ?? this.noPassword,
      phone: phone ?? this.phone,
      region: region ?? this.region,
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
      userId: userId ?? this.userId,
      username: username ?? this.username,
    );
  }
}

class AppVersionInfo {
  const AppVersionInfo({
    required this.changeLog,
    required this.downloadUrl,
    required this.platform,
    required this.version,
    this.updateAvailable = false,
    this.forceUpdate = false,
    this.updateMethod = '',
    this.currentVersion = '',
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      changeLog: _string(json['change_log']),
      downloadUrl: _string(json['download_url']),
      platform: _int(json['platform']),
      version: _string(json['version']),
      updateAvailable: _bool(json['update_available']),
      forceUpdate: _bool(json['force_update']),
      updateMethod: _string(json['update_method']),
      currentVersion: _string(json['current_version']),
    );
  }

  final String changeLog;
  final String downloadUrl;
  final int platform;
  final String version;
  final bool updateAvailable;
  final bool forceUpdate;
  final String updateMethod;
  final String currentVersion;
}

class CaptchaImage {
  const CaptchaImage({
    required this.base64,
    required this.captchaId,
  });

  factory CaptchaImage.fromJson(Map<String, dynamic> json) {
    return CaptchaImage(
      base64: _string(json['base64']),
      captchaId: _string(json['captchaId']),
    );
  }

  final String base64;
  final String captchaId;
}

class AuthOptionsResult {
  const AuthOptionsResult({
    required this.country,
    required this.preferredLoginMethod,
    required this.methods,
  });

  factory AuthOptionsResult.fromJson(Map<String, dynamic> json) {
    final rawMethods = json['methods'];
    return AuthOptionsResult(
      country: _string(json['country']),
      preferredLoginMethod: _string(json['preferred_login_method']),
      methods: rawMethods is List
          ? rawMethods.map(_string).where((value) => value.isNotEmpty).toList()
          : const <String>[],
    );
  }

  final String country;
  final String preferredLoginMethod;
  final List<String> methods;

  bool get prefersPhone => preferredLoginMethod == 'phone';
  bool get supportsPhone => methods.contains('phone');
  bool get supportsEmailPassword => methods.contains('email_password');
}

class PhoneLoginCodeResult {
  const PhoneLoginCodeResult({
    required this.phone,
    required this.expiresIn,
  });

  factory PhoneLoginCodeResult.fromJson(Map<String, dynamic> json) {
    return PhoneLoginCodeResult(
      phone: _string(json['phone']),
      expiresIn: _int(json['expires_in']),
    );
  }

  final String phone;
  final int expiresIn;
}

class UserElo {
  const UserElo({required this.elo});

  factory UserElo.fromJson(Map<String, dynamic> json) {
    return UserElo(elo: _int(json['elo']));
  }

  final int elo;
}

class CareerEloSettlement {
  const CareerEloSettlement({
    required this.elo,
    required this.previousElo,
    required this.delta,
    this.dailyTaskReward,
  });

  factory CareerEloSettlement.fromJson(Map<String, dynamic> json) {
    final rawReward = json['daily_task_reward'];
    return CareerEloSettlement(
      elo: _int(json['elo']),
      previousElo: _int(json['previous_elo']),
      delta: _int(json['delta']),
      dailyTaskReward: rawReward is Map
          ? DailyClaimResult.fromJson(rawReward.cast<String, dynamic>())
          : null,
    );
  }

  final int elo;
  final int previousElo;
  final int delta;
  final DailyClaimResult? dailyTaskReward;
}

class SubscriptionStatus {
  const SubscriptionStatus({
    required this.expireTime,
    required this.expireCount,
    required this.subStatus,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      expireTime: _string(json['expire_time']),
      expireCount: _int(json['expire_count']),
      subStatus: _int(json['sub_status']),
    );
  }

  final String expireTime;
  final int expireCount;
  final int subStatus;

  bool get isActive => subStatus == 1;
}

class UploadPgnResult {
  const UploadPgnResult({
    required this.pgnId,
    required this.shareId,
    this.dailyTaskReward,
  });

  factory UploadPgnResult.fromJson(Map<String, dynamic> json) {
    final rawReward = json['daily_task_reward'];
    return UploadPgnResult(
      pgnId: _int(json['pgn_id']),
      shareId: _string(json['s_id']),
      dailyTaskReward: rawReward is Map
          ? DailyClaimResult.fromJson(rawReward.cast<String, dynamic>())
          : null,
    );
  }

  final int pgnId;
  final String shareId;
  final DailyClaimResult? dailyTaskReward;
}

class PgnUpdateResult {
  const PgnUpdateResult({this.dailyTaskReward});

  factory PgnUpdateResult.fromJson(Map<String, dynamic> json) {
    final rawReward = json['daily_task_reward'];
    return PgnUpdateResult(
      dailyTaskReward: rawReward is Map
          ? DailyClaimResult.fromJson(rawReward.cast<String, dynamic>())
          : null,
    );
  }

  final DailyClaimResult? dailyTaskReward;
}

class PgnSaveMetadata {
  const PgnSaveMetadata({
    this.lichessGameId,
    this.lichessToken,
    this.lichessName,
    this.clientGameId,
    this.playerColor,
    this.speed,
    this.timeControl,
    this.opponentName,
  });

  final String? lichessGameId;
  final String? lichessToken;
  final String? lichessName;
  final String? clientGameId;
  final String? playerColor;
  final String? speed;
  final String? timeControl;
  final String? opponentName;

  Map<String, String> toFields() {
    return {
      if (lichessGameId != null && lichessGameId!.trim().isNotEmpty)
        'lichess_game_id': lichessGameId!,
      if (lichessToken != null && lichessToken!.trim().isNotEmpty)
        'lichess_token': lichessToken!,
      if (lichessName != null && lichessName!.trim().isNotEmpty)
        'lichess_name': lichessName!,
      if (clientGameId != null && clientGameId!.trim().isNotEmpty)
        'client_game_id': clientGameId!,
      'player_color': playerColor?.trim() ?? '',
      'speed': speed?.trim() ?? '',
      'time_control': timeControl?.trim() ?? '',
      'opponent_name': opponentName?.trim() ?? '',
    };
  }
}

class LichessTokenResult {
  const LichessTokenResult({
    required this.token,
    required this.lichessName,
  });

  factory LichessTokenResult.fromJson(Map<String, dynamic> json) {
    return LichessTokenResult(
      token: _string(json['token']),
      lichessName: _string(json['lichess_name']),
    );
  }

  final String token;
  final String lichessName;
}

class PgnRecord {
  const PgnRecord({
    required this.id,
    required this.whiteName,
    required this.blackName,
    required this.playMode,
    required this.playTime,
    required this.gameStatus,
    required this.gameStep,
    required this.winId,
    this.commentId = 0,
    this.pgnUrl,
    this.shareId,
    this.sortAt,
    this.hasGrandeurReport = false,
    this.lichessGameId = '',
    this.clientGameId = '',
    this.lichessToken = '',
    this.lichessName = '',
    this.playerColor = '',
    this.speed = '',
    this.timeControl = '',
    this.opponentName = '',
  });

  factory PgnRecord.fromJson(Map<String, dynamic> json) {
    return PgnRecord(
      id: _int(json['id'] ?? json['pgn_id']),
      whiteName: _string(json['white_name']),
      blackName: _string(json['black_name']),
      playMode: _string(json['play_mode']),
      playTime: _string(json['play_time']),
      gameStatus: _int(json['game_status']),
      gameStep: _int(json['game_step']),
      winId: _int(json['win_id']),
      pgnUrl: _nullableString(json['pgn'] ?? json['pgn_url'] ?? json['url']),
      shareId: _nullableString(json['s_id']),
      commentId: _int(json['comment_id']),
      sortAt: _dateTimeFromBackend(json['play_time']),
      hasGrandeurReport: _bool(json['has_grandeur_report']),
      lichessGameId: _string(json['lichess_game_id']),
      clientGameId: _string(
        json['client_game_id'] ?? json['chessnut_game_id'],
      ),
      lichessToken: _string(json['lichess_token']),
      lichessName: _string(json['lichess_name']),
      playerColor: _string(json['player_color']),
      speed: _string(json['speed']),
      timeControl: _string(json['time_control']),
      opponentName: _string(json['opponent_name']),
    );
  }

  final int id;
  final String whiteName;
  final String blackName;
  final String playMode;
  final String playTime;
  final int gameStatus;
  final int gameStep;
  final int winId;
  final String? pgnUrl;
  final String? shareId;
  final int commentId;
  final DateTime? sortAt;
  final bool hasGrandeurReport;
  final String lichessGameId;
  final String clientGameId;
  final String lichessToken;
  final String lichessName;
  final String playerColor;
  final String speed;
  final String timeControl;
  final String opponentName;
}

class PgnListResult {
  const PgnListResult({
    required this.records,
    required this.totalPage,
    this.total = 0,
  });

  factory PgnListResult.fromJson(Map<String, dynamic> json) {
    final rawList = json['pgnList'] ?? json['records'];
    final records = rawList is List
        ? rawList
            .whereType<Map>()
            .map((item) => PgnRecord.fromJson(item.cast<String, dynamic>()))
            .toList()
        : <PgnRecord>[];
    final total = _firstPositiveInt([
      json['total'],
      json['total_count'],
      json['totalCount'],
      json['total_records'],
      json['totalRecords'],
      json['records_count'],
      json['recordsCount'],
      json['record_total'],
      json['recordTotal'],
      json['pgn_total'],
      json['pgnTotal'],
      json['pgn_count'],
      json['pgnCount'],
      json['total_num'],
      json['totalNum'],
      json['all_count'],
      json['allCount'],
      json['total_rows'],
      json['totalRows'],
    ]);

    return PgnListResult(
      records: records,
      totalPage: _int(
        json['total_page'] ??
            json['totalPage'] ??
            json['total_pages'] ??
            json['totalPages'] ??
            json['pages'] ??
            json['page_count'] ??
            json['pageCount'],
      ),
      total: total,
    );
  }

  final List<PgnRecord> records;
  final int totalPage;
  final int total;
}

class GameRecordSourceCounts {
  const GameRecordSourceCounts({
    required this.all,
    required this.local,
    required this.lichess,
    required this.chessCom,
  });

  factory GameRecordSourceCounts.fromJson(Map<String, dynamic> json) {
    return GameRecordSourceCounts(
      all: _int(json['all']),
      local: _int(json['local']),
      lichess: _int(json['lichess']),
      chessCom: _int(json['chess_com']),
    );
  }

  final int all;
  final int local;
  final int lichess;
  final int chessCom;
}

class GameRecordSearchRequest {
  const GameRecordSearchRequest({
    this.page = 1,
    this.count = 20,
    this.query = '',
    this.mode = '',
    this.result = '',
    this.speed = '',
    this.color = '',
    this.report = '',
    this.minMoves = 0,
    this.sort = 'newest',
  });

  final int page;
  final int count;
  final String query;
  final String mode;
  final String result;
  final String speed;
  final String color;
  final String report;
  final int minMoves;
  final String sort;

  Map<String, String> toForm() {
    return {
      'page': page.toString(),
      'count': count.toString(),
      if (query.trim().isNotEmpty) 'query': query.trim(),
      if (mode.trim().isNotEmpty) 'mode': mode.trim(),
      if (result.trim().isNotEmpty) 'result': result.trim(),
      if (speed.trim().isNotEmpty) 'speed': speed.trim(),
      if (color.trim().isNotEmpty) 'color': color.trim(),
      if (report.trim().isNotEmpty) 'report': report.trim(),
      if (minMoves > 0) 'min_moves': minMoves.toString(),
      if (sort.trim().isNotEmpty) 'sort': sort.trim(),
    };
  }
}

class LichessImportJob {
  const LichessImportJob({
    required this.jobId,
    required this.playerId,
    required this.status,
    required this.maxGames,
    required this.inserted,
    required this.skipped,
    required this.failed,
    required this.processed,
    required this.total,
    required this.progressPercent,
    this.latestCursor = '',
    this.errorMessage = '',
    this.statusDetail = '',
    this.userMessage = '',
    this.nextRetryAt = '',
    this.startedAt = '',
    this.completedAt = '',
  });

  factory LichessImportJob.fromJson(Map<String, dynamic> json) {
    return LichessImportJob(
      jobId: _string(json['job_id']),
      playerId: _string(json['player_id']),
      status: _string(json['status']),
      maxGames: _int(json['max_games']),
      inserted: _int(json['inserted']),
      skipped: _int(json['skipped']),
      failed: _int(json['failed']),
      processed: _int(json['processed']),
      total: _int(json['total']),
      progressPercent: _int(json['progress_percent']),
      latestCursor: _string(json['latest_cursor']),
      errorMessage: _string(json['error_message']),
      statusDetail: _string(json['status_detail']),
      userMessage: _string(json['user_message']),
      nextRetryAt: _string(json['next_retry_at']),
      startedAt: _string(json['started_at']),
      completedAt: _string(json['completed_at']),
    );
  }

  final String jobId;
  final String playerId;
  final String status;
  final int maxGames;
  final int inserted;
  final int skipped;
  final int failed;
  final int processed;
  final int total;
  final int progressPercent;
  final String latestCursor;
  final String errorMessage;
  final String statusDetail;
  final String userMessage;
  final String nextRetryAt;
  final String startedAt;
  final String completedAt;

  bool get isDone =>
      status == 'completed' || status == 'failed' || status == 'canceled';
}

class ModelBuildGameRecordJob {
  const ModelBuildGameRecordJob({
    required this.jobId,
    required this.status,
    required this.requestedCount,
    required this.matchedCount,
    required this.processedCount,
    required this.usableCount,
    required this.skippedCount,
    required this.failedCount,
    required this.progressPercent,
    required this.submitTraining,
    required this.trainingId,
    this.title = '',
    this.remark = '',
    this.statusDetail = '',
    this.errorMessage = '',
    this.userMessage = '',
    this.startedAt = '',
    this.completedAt = '',
    this.preview = const ModelBuildPreview(
      gameCount: 0,
      pgn: '',
      sourceLabel: '',
    ),
  });

  factory ModelBuildGameRecordJob.fromJson(Map<String, dynamic> json) {
    return ModelBuildGameRecordJob(
      jobId: _string(json['job_id']),
      status: _string(json['status']),
      title: _string(json['title']),
      remark: _string(json['remark']),
      requestedCount: _int(json['requested_count']),
      matchedCount: _int(json['matched_count']),
      processedCount: _int(json['processed_count']),
      usableCount: _int(json['usable_count']),
      skippedCount: _int(json['skipped_count']),
      failedCount: _int(json['failed_count']),
      progressPercent: _int(json['progress_percent']),
      submitTraining: _bool(json['submit_training']),
      trainingId: _int(json['training_id']),
      statusDetail: _string(json['status_detail']),
      errorMessage: _string(json['error_message']),
      userMessage: _string(json['user_message']),
      startedAt: _string(json['started_at']),
      completedAt: _string(json['completed_at']),
      preview: ModelBuildPreview.fromJson(json),
    );
  }

  final String jobId;
  final String status;
  final String title;
  final String remark;
  final int requestedCount;
  final int matchedCount;
  final int processedCount;
  final int usableCount;
  final int skippedCount;
  final int failedCount;
  final int progressPercent;
  final bool submitTraining;
  final int trainingId;
  final String statusDetail;
  final String errorMessage;
  final String userMessage;
  final String startedAt;
  final String completedAt;
  final ModelBuildPreview preview;

  bool get isDone =>
      status == 'completed' || status == 'failed' || status == 'canceled';
}

class Maia3MoveCandidate {
  const Maia3MoveCandidate({
    required this.move,
    required this.san,
    required this.probability,
    this.wdl = const [],
    this.centipawns = 0,
  });

  factory Maia3MoveCandidate.fromJson(Map<String, dynamic> json) {
    final rawWdl = json['wdl'];
    return Maia3MoveCandidate(
      move: _string(json['move']),
      san: _string(json['san']),
      probability: _double(json['probability']),
      wdl: rawWdl is List
          ? rawWdl.map((value) => _int(value)).toList(growable: false)
          : const <int>[],
      centipawns: _int(json['centipawns']),
    );
  }

  final String move;
  final String san;
  final double probability;
  final List<int> wdl;
  final int centipawns;
}

class Maia3BotMoveResult {
  const Maia3BotMoveResult({
    required this.move,
    required this.san,
    required this.probability,
    required this.model,
    required this.elo,
    required this.candidates,
  });

  factory Maia3BotMoveResult.fromJson(Map<String, dynamic> json) {
    final rawCandidates = json['candidates'];
    return Maia3BotMoveResult(
      move: _string(json['move']),
      san: _string(json['san']),
      probability: _double(json['probability']),
      model: _string(json['model']),
      elo: _int(json['elo']),
      candidates: rawCandidates is List
          ? rawCandidates
              .whereType<Map>()
              .map((item) => Maia3MoveCandidate.fromJson(
                    item.cast<String, dynamic>(),
                  ))
              .toList(growable: false)
          : const <Maia3MoveCandidate>[],
    );
  }

  final String move;
  final String san;
  final double probability;
  final String model;
  final int elo;
  final List<Maia3MoveCandidate> candidates;
}

class Maia3HumanReviewSummary {
  const Maia3HumanReviewSummary({
    required this.humanMatchPercent,
    required this.mostHumanSide,
    required this.sharpestMoments,
    required this.notes,
  });

  factory Maia3HumanReviewSummary.fromJson(Map<String, dynamic> json) {
    final rawMoments = json['sharpest_moments'];
    final rawNotes = json['notes'];
    return Maia3HumanReviewSummary(
      humanMatchPercent: _double(json['human_match_percent']),
      mostHumanSide: _string(json['most_human_side']),
      sharpestMoments: rawMoments is List
          ? rawMoments.map((value) => _int(value)).toList(growable: false)
          : const <int>[],
      notes: rawNotes is List
          ? rawNotes.map((value) => _string(value)).toList(growable: false)
          : const <String>[],
    );
  }

  final double humanMatchPercent;
  final String mostHumanSide;
  final List<int> sharpestMoments;
  final List<String> notes;
}

class Maia3HumanReviewMove {
  const Maia3HumanReviewMove({
    required this.ply,
    required this.move,
    required this.moveUci,
    required this.fen,
    required this.lastMove,
    required this.playedProbability,
    required this.typicality,
    required this.humanLabel,
    required this.candidates,
  });

  factory Maia3HumanReviewMove.fromJson(Map<String, dynamic> json) {
    final rawLastMove = json['last_move'];
    final rawCandidates = json['candidates'];
    return Maia3HumanReviewMove(
      ply: _int(json['ply']),
      move: _string(json['move']),
      moveUci: _string(json['move_uci']),
      fen: _string(json['fen']),
      lastMove: rawLastMove is List
          ? rawLastMove.map((value) => _string(value)).toList(growable: false)
          : const <String>[],
      playedProbability: _double(json['played_probability']),
      typicality: _string(json['typicality']),
      humanLabel: _string(json['human_label']),
      candidates: rawCandidates is List
          ? rawCandidates
              .whereType<Map>()
              .map((item) => Maia3MoveCandidate.fromJson(
                    item.cast<String, dynamic>(),
                  ))
              .toList(growable: false)
          : const <Maia3MoveCandidate>[],
    );
  }

  final int ply;
  final String move;
  final String moveUci;
  final String fen;
  final List<String> lastMove;
  final double playedProbability;
  final String typicality;
  final String humanLabel;
  final List<Maia3MoveCandidate> candidates;
}

class Maia3HumanReviewReport {
  const Maia3HumanReviewReport({
    required this.version,
    required this.source,
    required this.model,
    required this.elo,
    required this.generatedAt,
    required this.summary,
    required this.moves,
  });

  factory Maia3HumanReviewReport.fromJson(Map<String, dynamic> json) {
    final rawMoves = json['moves'];
    final rawSummary = json['summary'] ?? json['overall_summary'];
    return Maia3HumanReviewReport(
      version: _int(json['version']),
      source: _string(json['source']),
      model: _string(json['model']),
      elo: _int(json['elo']),
      generatedAt: _dateTimeFromBackend(json['generated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      summary: rawSummary is Map
          ? Maia3HumanReviewSummary.fromJson(rawSummary.cast<String, dynamic>())
          : const Maia3HumanReviewSummary(
              humanMatchPercent: 0,
              mostHumanSide: '',
              sharpestMoments: [],
              notes: [],
            ),
      moves: rawMoves is List
          ? rawMoves
              .whereType<Map>()
              .map((item) => Maia3HumanReviewMove.fromJson(
                    item.cast<String, dynamic>(),
                  ))
              .toList(growable: false)
          : const <Maia3HumanReviewMove>[],
    );
  }

  final int version;
  final String source;
  final String model;
  final int elo;
  final DateTime generatedAt;
  final Maia3HumanReviewSummary summary;
  final List<Maia3HumanReviewMove> moves;
}

class Maia3HumanReviewJob {
  const Maia3HumanReviewJob({
    required this.jobId,
    required this.pgnId,
    required this.status,
    required this.stage,
    required this.reused,
    required this.model,
    required this.elo,
    required this.multiPv,
    required this.totalPly,
    required this.analyzedPly,
    this.progressPercent,
    this.errorMessage = '',
    this.report,
  });

  factory Maia3HumanReviewJob.fromJson(Map<String, dynamic> json) {
    final rawReport = json['report'];
    return Maia3HumanReviewJob(
      jobId: _string(json['job_id']),
      pgnId: _int(json['pgn_id']),
      status: _string(json['status']),
      stage: _string(json['stage']),
      reused: _bool(json['reused']),
      model: _string(json['model']),
      elo: _int(json['elo']),
      multiPv: _int(json['multipv']),
      totalPly: _int(json['total_ply']),
      analyzedPly: _int(json['analyzed_ply']),
      progressPercent: json['progress_percent'] == null
          ? null
          : _int(json['progress_percent']),
      errorMessage: _string(json['error_message']),
      report: rawReport is Map
          ? Maia3HumanReviewReport.fromJson(rawReport.cast<String, dynamic>())
          : null,
    );
  }

  final String jobId;
  final int pgnId;
  final String status;
  final String stage;
  final bool reused;
  final String model;
  final int elo;
  final int multiPv;
  final int totalPly;
  final int analyzedPly;
  final int? progressPercent;
  final String errorMessage;
  final Maia3HumanReviewReport? report;

  bool get isDone => status == 'completed' || status == 'failed';
}

class Puzzle {
  const Puzzle({
    required this.id,
    required this.fen,
    required this.move,
    required this.lichessId,
    required this.tags,
    this.rating,
    this.ratingMin,
    this.ratingMax,
    this.pgn,
  });

  factory Puzzle.fromJson(Map<String, dynamic> json) {
    return Puzzle(
      id: _int(json['id']),
      fen: _string(json['fen']),
      move: _string(json['move']),
      lichessId: _string(json['lichess_id']),
      tags: _string(json['tags']),
      rating: _nullableInt(json['rating'] ?? json['Rating'] ?? json['elo']),
      ratingMin: _nullableInt(
        json['rating_min'] ??
            json['ratingMin'] ??
            json['min_rating'] ??
            json['minRating'],
      ),
      ratingMax: _nullableInt(
        json['rating_max'] ??
            json['ratingMax'] ??
            json['max_rating'] ??
            json['maxRating'],
      ),
      pgn: _nullableString(json['pgn']),
    );
  }

  final int id;
  final String fen;
  final String move;
  final String lichessId;
  final String tags;
  final int? rating;
  final int? ratingMin;
  final int? ratingMax;
  final String? pgn;
}

class PuzzleTag {
  const PuzzleTag({
    required this.id,
    required this.key,
    required this.name,
    required this.description,
    required this.total,
  });

  factory PuzzleTag.fromJson(Map<String, dynamic> json) {
    return PuzzleTag(
      id: _int(json['id']),
      key: _string(json['key']),
      name: _string(json['name']),
      description: _string(json['desc']),
      total: _int(json['total']),
    );
  }

  final int id;
  final String key;
  final String name;
  final String description;
  final int total;
}

class PuzzleInfo {
  const PuzzleInfo({
    required this.total,
    required this.tags,
  });

  factory PuzzleInfo.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    return PuzzleInfo(
      total: _int(json['total']),
      tags: rawTags is List
          ? rawTags
              .whereType<Map>()
              .map((item) => PuzzleTag.fromJson(item.cast<String, dynamic>()))
              .toList()
          : const <PuzzleTag>[],
    );
  }

  final int total;
  final List<PuzzleTag> tags;
}

class TrainModel {
  const TrainModel({
    required this.id,
    required this.rawFile,
    required this.trainStatus,
    required this.title,
    required this.remark,
    required this.likes,
    required this.modelPath,
    required this.analyzeData,
    required this.sharedName,
    required this.shared,
    required this.analyzePgn,
    this.gameCount = 0,
    this.sourceLabel = '',
    this.playerName = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.tags = const [],
  });

  factory TrainModel.fromJson(Map<String, dynamic> json) {
    final rawAnalyzePgn = json['analyze_pgn'];
    final rawTags = json['tags'];
    return TrainModel(
      id: _int(json['id']),
      rawFile: _string(json['raw_file']),
      trainStatus: _int(json['train_status']),
      title: _string(json['title']),
      remark: _string(json['remark']),
      likes: _int(json['likes']),
      modelPath: _string(json['model_path']),
      analyzeData: _decodeBackendBase64(_string(json['analyze_data'])),
      sharedName: _string(json['shared_name']),
      shared: _bool(json['shared']),
      analyzePgn: rawAnalyzePgn is List
          ? rawAnalyzePgn
              .map((item) => _decodeBackendBase64(_string(item)))
              .toList()
          : const <String>[],
      gameCount: _int(
        json['game_count'] ??
            json['games'] ??
            json['usable_count'] ??
            json['training_games'],
      ),
      sourceLabel: _string(
        json['source_label'] ?? json['source'] ?? json['source_name'],
      ),
      playerName: _string(
        json['player_name'] ?? json['username'] ?? json['owner_name'],
      ),
      createdAt: _string(json['created_at'] ?? json['create_time']),
      updatedAt: _string(
        json['updated_at'] ?? json['completed_at'] ?? json['finish_time'],
      ),
      tags: rawTags is List
          ? rawTags.map(_string).where((value) => value.isNotEmpty).toList()
          : const <String>[],
    );
  }

  final int id;
  final String rawFile;
  final int trainStatus;
  final String title;
  final String remark;
  final int likes;
  final String modelPath;
  final String analyzeData;
  final String sharedName;
  final bool shared;
  final List<String> analyzePgn;
  final int gameCount;
  final String sourceLabel;
  final String playerName;
  final String createdAt;
  final String updatedAt;
  final List<String> tags;
}

class TrainListResult {
  const TrainListResult({
    required this.models,
    this.page = 1,
    this.totalPage = 0,
    this.total = 0,
  });

  factory TrainListResult.fromJson(Object? json) {
    final source =
        json is Map<String, dynamic> ? json : const <String, dynamic>{};
    final rawModels = source['list'] ??
        source['records'] ??
        source['models'] ??
        source['items'] ??
        source['data'] ??
        json;
    return TrainListResult(
      models: rawModels is List
          ? rawModels
              .whereType<Map>()
              .map((item) => TrainModel.fromJson(item.cast<String, dynamic>()))
              .toList()
          : const <TrainModel>[],
      page: math.max(
        1,
        _int(source['page'] ?? source['current_page'] ?? source['currentPage']),
      ),
      totalPage: _int(
        source['total_page'] ??
            source['totalPage'] ??
            source['total_pages'] ??
            source['totalPages'] ??
            source['pages'] ??
            source['page_count'] ??
            source['pageCount'],
      ),
      total: _int(
        source['total'] ??
            source['total_count'] ??
            source['totalCount'] ??
            source['count'] ??
            source['records_count'] ??
            source['recordsCount'],
      ),
    );
  }

  final List<TrainModel> models;
  final int page;
  final int totalPage;
  final int total;
}

class WalletBalance {
  const WalletBalance({
    required this.balance,
    required this.claimedToday,
    required this.dailyClaimPoints,
    required this.lastClaimedAt,
    required this.memberActive,
    required this.memberExpireAt,
    this.claimedTaskKeys = const <String>[],
  });

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    final rawClaimedTasks = json['claimed_tasks'];
    return WalletBalance(
      balance: _int(json['balance']),
      claimedToday: _bool(json['claimed_today']),
      dailyClaimPoints: _int(json['daily_claim_points']),
      lastClaimedAt: _string(json['last_claimed_at']),
      memberActive: _bool(json['member_active']),
      memberExpireAt: _string(json['member_expire_at']),
      claimedTaskKeys: rawClaimedTasks is List
          ? rawClaimedTasks.map(_string).where((key) => key.isNotEmpty).toList()
          : const <String>[],
    );
  }

  final int balance;
  final bool claimedToday;
  final int dailyClaimPoints;
  final String lastClaimedAt;
  final bool memberActive;
  final String memberExpireAt;
  final List<String> claimedTaskKeys;
}

class DailyClaimResult {
  const DailyClaimResult({
    required this.balance,
    required this.pointsAdded,
    required this.claimedToday,
  });

  factory DailyClaimResult.fromJson(Map<String, dynamic> json) {
    return DailyClaimResult(
      balance: _int(json['balance']),
      pointsAdded: _int(json['points_added']),
      claimedToday: _bool(json['claimed_today']),
    );
  }

  final int balance;
  final int pointsAdded;
  final bool claimedToday;
}

class WalletLedgerItem {
  const WalletLedgerItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.createdAt,
    required this.type,
  });

  factory WalletLedgerItem.fromJson(Map<String, dynamic> json) {
    return WalletLedgerItem(
      id: _string(json['id']),
      title: _string(json['title']),
      amount: _int(json['amount']),
      createdAt: _string(json['created_at']),
      type: _string(json['type']),
    );
  }

  final String id;
  final String title;
  final int amount;
  final String createdAt;
  final String type;
}

class WalletLedger {
  const WalletLedger({required this.items});

  factory WalletLedger.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return WalletLedger(
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((item) =>
                  WalletLedgerItem.fromJson(item.cast<String, dynamic>()))
              .toList()
          : const <WalletLedgerItem>[],
    );
  }

  final List<WalletLedgerItem> items;
}

class InboxMessage {
  const InboxMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.messageType,
    required this.actionLabel,
    required this.actionRoute,
    required this.publishedAt,
    required this.read,
    required this.readAt,
  });

  factory InboxMessage.fromJson(Map<String, dynamic> json) {
    return InboxMessage(
      id: _int(json['id']),
      title: _string(json['title']),
      body: _string(json['body']),
      messageType: _string(json['message_type']),
      actionLabel: _string(json['action_label']),
      actionRoute: _string(json['action_route']),
      publishedAt: _string(json['published_at']),
      read: _bool(json['read']),
      readAt: _string(json['read_at']),
    );
  }

  final int id;
  final String title;
  final String body;
  final String messageType;
  final String actionLabel;
  final String actionRoute;
  final String publishedAt;
  final bool read;
  final String readAt;

  InboxMessage copyWith({
    int? id,
    String? title,
    String? body,
    String? messageType,
    String? actionLabel,
    String? actionRoute,
    String? publishedAt,
    bool? read,
    String? readAt,
  }) {
    return InboxMessage(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      messageType: messageType ?? this.messageType,
      actionLabel: actionLabel ?? this.actionLabel,
      actionRoute: actionRoute ?? this.actionRoute,
      publishedAt: publishedAt ?? this.publishedAt,
      read: read ?? this.read,
      readAt: readAt ?? this.readAt,
    );
  }
}

class InboxList {
  const InboxList({
    required this.unreadCount,
    required this.items,
  });

  factory InboxList.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return InboxList(
      unreadCount: _int(json['unread_count']),
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((item) => InboxMessage.fromJson(
                    item.cast<String, dynamic>(),
                  ))
              .toList()
          : const <InboxMessage>[],
    );
  }

  final int unreadCount;
  final List<InboxMessage> items;
}

class InboxMarkReadResult {
  const InboxMarkReadResult({
    required this.messageId,
    required this.read,
    required this.unreadCount,
  });

  factory InboxMarkReadResult.fromJson(Map<String, dynamic> json) {
    return InboxMarkReadResult(
      messageId: _int(json['message_id']),
      read: _bool(json['read']),
      unreadCount: _int(json['unread_count']),
    );
  }

  final int messageId;
  final bool read;
  final int unreadCount;
}

enum WalletConsumeReason {
  grandeur,
  engineModelBuild,
}

extension WalletConsumeReasonApi on WalletConsumeReason {
  String get apiValue {
    return switch (this) {
      WalletConsumeReason.grandeur => 'grandeur',
      WalletConsumeReason.engineModelBuild => 'engine_model_build',
    };
  }
}

class WalletConsumeResult {
  const WalletConsumeResult({
    required this.balance,
    required this.pointsConsumed,
    required this.memberUnlimited,
  });

  factory WalletConsumeResult.fromJson(Map<String, dynamic> json) {
    return WalletConsumeResult(
      balance: _int(json['balance']),
      pointsConsumed: _int(json['points_consumed']),
      memberUnlimited: _bool(json['member_unlimited']),
    );
  }

  final int balance;
  final int pointsConsumed;
  final bool memberUnlimited;
}

class MembershipProduct {
  const MembershipProduct({
    required this.id,
    required this.title,
    required this.price,
    required this.priceCents,
    required this.currency,
    required this.period,
    required this.renewing,
    required this.durationMonths,
    required this.platformProductId,
    required this.recommended,
  });

  factory MembershipProduct.fromJson(Map<String, dynamic> json) {
    return MembershipProduct(
      id: _string(json['id']),
      title: _string(json['title']),
      price: _string(json['price']),
      priceCents: _int(json['price_cents']),
      currency: _string(json['currency']),
      period: _string(json['period']),
      renewing: _bool(json['renewing']),
      durationMonths: _int(json['duration_months']),
      platformProductId: _string(json['platform_product_id']),
      recommended: _bool(json['recommended']),
    );
  }

  final String id;
  final String title;
  final String price;
  final int priceCents;
  final String currency;
  final String period;
  final bool renewing;
  final int durationMonths;
  final String platformProductId;
  final bool recommended;
}

class MembershipProducts {
  const MembershipProducts({required this.products});

  factory MembershipProducts.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['products'];
    return MembershipProducts(
      products: rawProducts is List
          ? rawProducts
              .whereType<Map>()
              .map((item) =>
                  MembershipProduct.fromJson(item.cast<String, dynamic>()))
              .toList()
          : const <MembershipProduct>[],
    );
  }

  final List<MembershipProduct> products;
}

class MembershipVerificationResult {
  const MembershipVerificationResult({
    required this.active,
    required this.expireAt,
  });

  factory MembershipVerificationResult.fromJson(Map<String, dynamic> json) {
    return MembershipVerificationResult(
      active: _bool(json['active']),
      expireAt: _string(json['expire_at']),
    );
  }

  final bool active;
  final String expireAt;
}

class GrandeurMoveExplanation {
  const GrandeurMoveExplanation({
    required this.ply,
    required this.san,
    required this.tag,
    required this.commentary,
    this.language = '',
    // Legacy fields for backward compatibility
    this.purpose = '',
    this.why = '',
    this.betterMove = '',
    this.classification = '',
  });

  factory GrandeurMoveExplanation.fromJson(Map<String, dynamic> json) {
    return GrandeurMoveExplanation(
      ply: _int(json['ply']),
      san: _string(json['san'] ?? json['move']),
      tag: _string(json['tag']),
      commentary: _string(json['commentary'] ?? json['why']),
      language: _string(json['language'] ?? json['lang'] ?? json['locale']),
      // Legacy fields
      purpose: _string(json['purpose']),
      why: _string(json['why'] ?? json['commentary']),
      betterMove: _string(json['better_move'] ?? json['betterMove']),
      classification: _string(json['classification']),
    );
  }

  final int ply;
  final String san;
  final String tag;
  final String commentary;
  final String language;
  // Legacy fields for backward compatibility
  final String purpose;
  final String why;
  final String betterMove;
  final String classification;
}

class GrandeurAnalysisResult {
  const GrandeurAnalysisResult({
    required this.analysisId,
    required this.moves,
    this.language = '',
    this.summary = const <String>[],
    this.statistics,
  });

  factory GrandeurAnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawMoves = json['moves'] ?? json['steps'];
    var nextPly = 1;
    final moves = rawMoves is List
        ? rawMoves.whereType<Map>().map((item) {
            final map = item.cast<String, dynamic>();
            final ply = _int(map['ply']);
            final withPly = ply > 0 ? map : {...map, 'ply': nextPly};
            nextPly = _int(withPly['ply']) + 1;
            return GrandeurMoveExplanation.fromJson(withPly);
          }).toList()
        : const <GrandeurMoveExplanation>[];

    final rawSummary = json['summary'] ?? json['overall_summary'];
    final summaryList = rawSummary is List
        ? rawSummary.map((item) => _string(item)).toList(growable: false)
        : rawSummary is String && rawSummary.trim().isNotEmpty
            ? [rawSummary.trim()]
            : const <String>[];

    final rawStats = json['statistics'];
    final stats = rawStats is Map ? rawStats.cast<String, dynamic>() : null;

    return GrandeurAnalysisResult(
      analysisId: _string(json['analysis_id'] ?? json['id']),
      moves: moves,
      language: _string(json['language'] ?? json['lang'] ?? json['locale']),
      summary: summaryList,
      statistics: stats,
    );
  }

  final String analysisId;
  final List<GrandeurMoveExplanation> moves;
  final String language;
  final List<String> summary;
  final Map<String, dynamic>? statistics;

  // Keep the backend array structure when presenting the summary. Each JSON
  // item represents one logical line in the report.
  String get summaryText => summary.join('\n');

  GrandeurAnalysisResult withPreferredLanguage(String preferredLanguage) {
    final preferred = preferredLanguage.trim();
    if (preferred.isEmpty || language.trim() == preferred) return this;
    return GrandeurAnalysisResult(
      analysisId: analysisId,
      moves: moves,
      language: preferred,
      summary: summary,
      statistics: statistics,
    );
  }
}

class GrandeurReviewJob {
  const GrandeurReviewJob({
    required this.commentId,
    required this.trainStatus,
    required this.commentFile,
    required this.pointsConsumed,
    required this.alreadyUnlocked,
    required this.memberUnlimited,
    required this.pgnId,
    required this.shareId,
    this.language = '',
    this.progress,
  });

  factory GrandeurReviewJob.fromJson(Map<String, dynamic> json) {
    return GrandeurReviewJob(
      commentId: _int(json['comment_id'] ?? json['id']),
      trainStatus: _int(json['train_status']),
      commentFile: _string(json['comment_file']),
      pointsConsumed: _int(json['points_consumed']),
      alreadyUnlocked: _bool(json['already_unlocked']),
      memberUnlimited: _bool(json['member_unlimited']),
      pgnId: _int(json['pgn_id']),
      shareId: _string(json['share_id']),
      language: _string(json['language'] ?? json['lang'] ?? json['locale']),
      progress: _progress(json['progress'] ??
          json['percent'] ??
          json['progress_percent'] ??
          json['progressPercent']),
    );
  }

  final int commentId;
  final int trainStatus;
  final String commentFile;
  final int pointsConsumed;
  final bool alreadyUnlocked;
  final bool memberUnlimited;
  final int pgnId;
  final String shareId;
  final String language;
  final double? progress;

  bool get completed => trainStatus == 2 && commentFile.trim().isNotEmpty;

  bool get failed => trainStatus == 3;
}

class GrandeurVoiceProfile {
  const GrandeurVoiceProfile({
    required this.id,
    required this.name,
    required this.voice,
    required this.style,
  });

  factory GrandeurVoiceProfile.fromJson(Map<String, dynamic> json) {
    return GrandeurVoiceProfile(
      id: _string(json['id']),
      name: _string(json['name']),
      voice: _string(json['voice']),
      style: _string(json['style']),
    );
  }

  final String id;
  final String name;
  final String voice;
  final String style;
}

class GrandeurVoiceProfiles {
  const GrandeurVoiceProfiles({required this.profiles});

  factory GrandeurVoiceProfiles.fromJson(Map<String, dynamic> json) {
    final rawProfiles = json['profiles'];
    return GrandeurVoiceProfiles(
      profiles: rawProfiles is List
          ? rawProfiles
              .whereType<Map>()
              .map((item) =>
                  GrandeurVoiceProfile.fromJson(item.cast<String, dynamic>()))
              .toList()
          : const <GrandeurVoiceProfile>[],
    );
  }

  final List<GrandeurVoiceProfile> profiles;
}

class GrandeurHistoryItem {
  const GrandeurHistoryItem({
    required this.analysisId,
    required this.title,
    required this.createdAt,
  });

  factory GrandeurHistoryItem.fromJson(Map<String, dynamic> json) {
    return GrandeurHistoryItem(
      analysisId: _string(json['analysis_id']),
      title: _string(json['title']),
      createdAt: _string(json['created_at']),
    );
  }

  final String analysisId;
  final String title;
  final String createdAt;
}

class GrandeurAnalysisHistory {
  const GrandeurAnalysisHistory({required this.items});

  factory GrandeurAnalysisHistory.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return GrandeurAnalysisHistory(
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((item) =>
                  GrandeurHistoryItem.fromJson(item.cast<String, dynamic>()))
              .toList()
          : const <GrandeurHistoryItem>[],
    );
  }

  final List<GrandeurHistoryItem> items;
}

class BugReportDiagnostics {
  const BugReportDiagnostics({
    required this.appVersion,
    this.appBuildNumber = '',
    required this.platform,
    required this.locale,
    required this.route,
    required this.boardModel,
    required this.boardConnected,
    required this.signedIn,
    required this.log,
    this.generatedAt = '',
    this.deviceManufacturer = '',
    this.deviceModel = '',
    this.osVersion = '',
    this.osSdk = 0,
  });

  final String appVersion;
  final String appBuildNumber;
  final String platform;
  final String locale;
  final String route;
  final String boardModel;
  final bool boardConnected;
  final bool signedIn;
  final String log;
  final String generatedAt;
  final String deviceManufacturer;
  final String deviceModel;
  final String osVersion;
  final int osSdk;

  Map<String, Object> toJson() {
    return {
      'app_version': appVersion,
      'app_build_number': appBuildNumber,
      'platform': platform,
      'locale': locale,
      'route': route,
      'board_model': boardModel,
      'board_connected': boardConnected,
      'signed_in': signedIn,
      'log': log,
      'generated_at': generatedAt,
      'device_manufacturer': deviceManufacturer,
      'device_model': deviceModel,
      'os_version': osVersion,
      'os_sdk': osSdk,
    };
  }
}

class BugReportAttachment {
  const BugReportAttachment({
    required this.filename,
    required this.bytes,
    required this.contentType,
  });

  final String filename;
  final List<int> bytes;
  final String contentType;
}

class BugReportResult {
  const BugReportResult({required this.reportId});

  factory BugReportResult.fromJson(Map<String, dynamic> json) {
    return BugReportResult(reportId: _string(json['report_id']));
  }

  final String reportId;
}

class ChessnutApiClient {
  ChessnutApiClient({
    http.Client? httpClient,
    this.session,
    this.onAuthExpired,
    this.onSessionRefreshed,
    this.onAuthTokenRefreshed,
    this.onNetworkError,
    String language = 'en',
    String? grandeurLanguage,
    Uri? baseUri,
    Uri? puzzleBaseUri,
    Uri? moveUpdateUri,
  })  : _httpClient = httpClient ?? http.Client(),
        baseUri = baseUri ?? ChessnutEndpointConfig.apiBaseUri,
        puzzleBaseUri = puzzleBaseUri ?? ChessnutEndpointConfig.puzzleBaseUri,
        moveUpdateUri = moveUpdateUri ?? ChessnutEndpointConfig.moveUpdateUri,
        language = ValueNotifier<String>(language),
        grandeurLanguage = ValueNotifier<String>(grandeurLanguage ?? language);

  final http.Client _httpClient;
  final FutureOr<void> Function()? onAuthExpired;
  final FutureOr<void> Function(ChessnutLoginSession session)?
      onSessionRefreshed;
  final void Function(String message)? onAuthTokenRefreshed;
  final void Function(String message)? onNetworkError;
  final ValueNotifier<String> language;
  final ValueNotifier<String> grandeurLanguage;
  final Uri baseUri;
  final Uri puzzleBaseUri;
  final Uri moveUpdateUri;
  ChessnutApiSession? session;
  Future<ApiResult<ChessnutLoginSession>>? _tokenRefreshInFlight;
  int? _cachedCareerElo;
  int? _cachedCareerEloUserId;

  http.Client get httpClient => _httpClient;

  int? get cachedCareerElo {
    final userId = session?.userId;
    if (userId == null || userId != _cachedCareerEloUserId) return null;
    return _cachedCareerElo;
  }

  String get _walletCorrectionKey {
    final activeSession = session;
    final userId = activeSession?.userId ?? 0;
    return '${baseUri.toString()}#$userId';
  }

  int get _walletRewardCorrection =>
      _walletRewardCorrectionsByAccount[_walletCorrectionKey] ?? 0;

  void _rememberWalletRewardCorrection(int extraPoints) {
    if (extraPoints <= 0) return;
    final key = _walletCorrectionKey;
    _walletRewardCorrectionsByAccount[key] =
        (_walletRewardCorrectionsByAccount[key] ?? 0) + extraPoints;
  }

  int _correctWalletBalance(int balance) {
    final correction = _walletRewardCorrection;
    if (correction <= 0) return balance;
    final corrected = balance - correction;
    return corrected < 0 ? 0 : corrected;
  }

  DailyClaimResult _normalizeWalletReward(
    DailyClaimResult result,
    int requestedPoints,
    int defaultExpectedPoints,
  ) {
    final expectedPoints = requestedPoints <= 0
        ? defaultExpectedPoints
        : requestedPoints > defaultExpectedPoints
            ? defaultExpectedPoints
            : requestedPoints;
    final remotePoints = result.pointsAdded;
    if (remotePoints <= expectedPoints) {
      return DailyClaimResult(
        balance: _correctWalletBalance(result.balance),
        pointsAdded: remotePoints,
        claimedToday: result.claimedToday,
      );
    }

    final extraPoints = remotePoints - expectedPoints;
    _rememberWalletRewardCorrection(extraPoints);
    return DailyClaimResult(
      balance: _correctWalletBalance(result.balance),
      pointsAdded: expectedPoints,
      claimedToday: result.claimedToday,
    );
  }

  bool get isLocalTestBackend {
    final host = baseUri.host.toLowerCase();
    if (host == 'localhost' || host == '127.0.0.1') return true;
    if (host.startsWith('10.')) return true;
    if (host.startsWith('192.168.')) return true;
    if (host.startsWith('172.')) {
      final parts = host.split('.');
      if (parts.length == 4) {
        final second = int.tryParse(parts[1]);
        return second != null && second >= 16 && second <= 31;
      }
    }
    return false;
  }

  Future<ApiResult<ChessnutLoginSession>> login(
    String account,
    String password,
  ) {
    return _postForm(
      _apiUri('api/login'),
      {'account': account, 'password': _legacyPasswordDigest(password)},
      parser: (json) {
        final parsed = ChessnutLoginSession.fromJson(json);
        session = parsed;
        return parsed;
      },
    );
  }

  Future<ApiResult<AuthOptionsResult>> authOptions({String country = ''}) {
    return _postForm(
      _apiUri('api/v3/authOptions'),
      {
        if (country.trim().isNotEmpty) 'country': country.trim(),
      },
      parser: AuthOptionsResult.fromJson,
      timeout: const Duration(seconds: 5),
    );
  }

  Future<ApiResult<PhoneLoginCodeResult>> sendPhoneLoginCode(String phone) {
    return _postForm(
      _apiUri('api/v3/sendPhoneLoginCode'),
      {'phone': phone.trim()},
      parser: PhoneLoginCodeResult.fromJson,
      timeout: const Duration(seconds: 8),
    );
  }

  Future<ApiResult<ChessnutLoginSession>> loginWithPhoneCode({
    required String phone,
    required String code,
  }) {
    return _postForm(
      _apiUri('api/v3/loginWithPhoneCode'),
      {
        'phone': phone.trim(),
        'code': code.trim(),
      },
      parser: (json) {
        final parsed = ChessnutLoginSession.fromJson(json);
        session = parsed;
        return parsed;
      },
      timeout: const Duration(seconds: 8),
    );
  }

  Future<ApiResult<ChessnutLoginSession>> loginWithGoogle(String idToken) {
    return _socialLogin('api/loginWithGoogle', {'id_token': idToken});
  }

  Future<ApiResult<ChessnutLoginSession>> loginWithApple(
    String identityToken, {
    String? authorizationCode,
  }) {
    return _socialLogin(
      'api/loginWithApple',
      {
        'identity_token': identityToken,
        if (authorizationCode != null && authorizationCode.trim().isNotEmpty)
          'authorization_code': authorizationCode.trim(),
      },
    );
  }

  Future<ApiResult<ChessnutLoginSession>> refreshToken(
    int userId,
    String refreshToken,
  ) {
    return _refreshTokenAndRestoreSession(userId, refreshToken);
  }

  Future<ApiResult<ChessnutLoginSession>> _refreshTokenAndRestoreSession(
    int userId,
    String refreshToken,
  ) async {
    final result = await _requestRefreshToken(userId, refreshToken);
    final refreshed = result.data;
    if (!result.isSuccess || refreshed == null) return result;
    final restoredSession = refreshed.refreshToken?.trim().isNotEmpty == true
        ? refreshed
        : refreshed.copyWith(refreshToken: refreshToken);
    session = restoredSession;
    return ApiResult(result.status, data: restoredSession);
  }

  Future<ApiResult<ChessnutLoginSession>> _requestRefreshToken(
    int userId,
    String refreshToken,
  ) {
    return _postForm(
      _apiUri('api/Token/Refresh'),
      {
        'user_id': userId.toString(),
        'refresh_token': refreshToken,
      },
      parser: ChessnutLoginSession.fromJson,
      timeout: const Duration(seconds: 5),
    );
  }

  Future<ApiResult<ChessnutLoginSession>> _refreshExpiredAccessToken(
    ChessnutApiSession expiredSession,
  ) {
    final existing = _tokenRefreshInFlight;
    if (existing != null) return existing;

    final refreshToken = expiredSession.refreshToken?.trim() ?? '';
    if (refreshToken.isEmpty) {
      return Future.value(
        const ApiResult(
          ApiStatus.api(code: 600, message: authSessionExpiredMessage),
        ),
      );
    }

    final future = _performExpiredAccessTokenRefresh(
      expiredSession.userId,
      refreshToken,
    );
    _tokenRefreshInFlight = future;
    future.whenComplete(() {
      if (identical(_tokenRefreshInFlight, future)) {
        _tokenRefreshInFlight = null;
      }
    });
    return future;
  }

  Future<ApiResult<ChessnutLoginSession>> _performExpiredAccessTokenRefresh(
    int userId,
    String refreshToken,
  ) async {
    final result = await _requestRefreshToken(userId, refreshToken);
    if (!result.isSuccess || result.data == null) return result;

    final refreshed = result.data!;
    final restoredSession = refreshed.refreshToken?.trim().isNotEmpty == true
        ? refreshed
        : refreshed.copyWith(refreshToken: refreshToken);
    session = restoredSession;
    await onSessionRefreshed?.call(restoredSession);
    return ApiResult(result.status, data: restoredSession);
  }

  Future<ApiResult<AppVersionInfo>> version(
    int platform, {
    String? currentVersion,
    String? buildNumber,
    String? platformName,
  }) {
    return _postForm(
      _apiUri('api/version'),
      {
        'platform': platform.toString(),
        if (currentVersion?.trim().isNotEmpty ?? false)
          'current_version': currentVersion!.trim(),
        if (buildNumber?.trim().isNotEmpty ?? false)
          'build_number': buildNumber!.trim(),
        if (platformName?.trim().isNotEmpty ?? false)
          'platform_name': platformName!.trim(),
      },
      parser: AppVersionInfo.fromJson,
    );
  }

  Future<ApiResult<UploadPgnResult>> uploadPgn({
    required String pgn,
    required String whiteName,
    required String blackName,
    required String playTime,
    required String playMode,
    int winId = 0,
    int gameStatus = 1,
    int gameStep = 0,
    PgnSaveMetadata metadata = const PgnSaveMetadata(),
  }) {
    return _authorizedPostForm(
      _apiUri('api/uploadPgn'),
      {
        'pgn': pgn,
        'white_name': whiteName,
        'black_name': blackName,
        'play_time': playTime,
        'play_mode': playMode,
        'win_id': winId.toString(),
        'game_status': gameStatus.toString(),
        'game_step': gameStep.toString(),
        ...metadata.toFields(),
      },
      parser: UploadPgnResult.fromJson,
    );
  }

  Future<ApiResult<int>> uploadPgnList({
    required String pgnList,
    String source = '',
  }) {
    return _authorizedPostAny(
      _apiUri('api/uploadPgnList'),
      {
        'pgnList': pgnList,
        if (source.trim().isNotEmpty) 'source': source.trim(),
      },
      parser: _int,
    );
  }

  Future<ApiResult<PgnUpdateResult>> updatePgn({
    required int pgnId,
    required String pgn,
    required String whiteName,
    required String blackName,
    String? playTime,
    String? playMode,
    int winId = 0,
    int gameStatus = 1,
    int gameStep = 0,
    PgnSaveMetadata metadata = const PgnSaveMetadata(),
  }) {
    final normalizedPlayTime = playTime?.trim();
    final normalizedPlayMode = playMode?.trim();
    return _authorizedPostAny(
      _apiUri('api/updatePgn'),
      {
        'pgn': pgn,
        'pgn_id': pgnId.toString(),
        'white_name': whiteName,
        'black_name': blackName,
        if (normalizedPlayTime != null && normalizedPlayTime.isNotEmpty)
          'play_time': normalizedPlayTime,
        if (normalizedPlayMode != null && normalizedPlayMode.isNotEmpty)
          'play_mode': normalizedPlayMode,
        'win_id': winId.toString(),
        'game_status': gameStatus.toString(),
        'game_step': gameStep.toString(),
        ...metadata.toFields(),
      },
      parser: (data) => data is Map<String, dynamic>
          ? PgnUpdateResult.fromJson(data)
          : const PgnUpdateResult(),
    );
  }

  Future<ApiResult<bool>> deletePgn({required int pgnId}) {
    return _authorizedPostAny(
      _apiUri('api/delPgn'),
      {'pgn_id': pgnId.toString()},
      parser: (_) => true,
    );
  }

  Future<ApiResult<bool>> setCollectd({required int pgnId}) {
    return _authorizedPostAny(
      _apiUri('api/setCollectd'),
      {'pgn_id': pgnId.toString()},
      parser: (_) => true,
    );
  }

  Future<ApiResult<bool>> deleteCollectd({required int pgnId}) {
    return _authorizedPostAny(
      _apiUri('api/delCollectd'),
      {'pgn_id': pgnId.toString()},
      parser: (_) => true,
    );
  }

  Future<ApiResult<bool>> updateInfo({required String username}) {
    return _authorizedPostAny(
      _apiUri('api/updateInfo'),
      {'username': username},
      parser: (_) => true,
    );
  }

  Future<ApiResult<ChessnutLoginSession>> updateProfile({
    required String username,
    required String avatarUrl,
  }) async {
    final activeSession = session;
    if (activeSession == null) {
      return const ApiResult(
          ApiStatus.api(code: 401, message: 'Not logged in'));
    }

    final result = await _authorizedPostAny(
      _apiUri('api/v3/updateProfile'),
      {
        'username': username,
        'avatar_url': avatarUrl,
      },
      parser: (data) => _profileSessionFromResponse(
        data,
        activeSession,
        username: username,
        avatarUrl: avatarUrl,
      ),
    );
    if (result.isSuccess) {
      if (result.data != null) {
        session = result.data;
      }
      return result;
    }
    if (!_isProfileEndpointMissing(result.status)) {
      return result;
    }
    return _updateProfileLegacy(
      username: username,
      avatarUrl: avatarUrl,
      activeSession: activeSession,
    );
  }

  Future<ApiResult<CaptchaImage>> getRegisterImage() {
    return _postForm(
      _apiUri('api/getRegisterImage'),
      {},
      parser: CaptchaImage.fromJson,
    );
  }

  Future<ApiResult<CaptchaImage>> getDeleteUserImage() {
    return _authorizedPostForm(
      _apiUri('api/getDeleteUserImage'),
      {},
      parser: CaptchaImage.fromJson,
    );
  }

  Future<ApiResult<bool>> deleteUser({
    required String code,
    required String captchaId,
  }) {
    return _authorizedPostAny(
      _apiUri('api/deleteUser'),
      {
        'code': code,
        'captchaId': captchaId,
      },
      parser: (_) => true,
    );
  }

  Future<ApiResult<LichessTokenResult>> getLichessToken() {
    return _authorizedPostForm(
      _apiUri('api/getLichessToken'),
      {},
      parser: LichessTokenResult.fromJson,
    );
  }

  Future<ApiResult<LichessTokenResult>> waitForLichessToken({
    int maxAttempts = 5,
    Duration retryDelay = const Duration(milliseconds: 800),
  }) async {
    final attempts = maxAttempts < 1 ? 1 : maxAttempts;
    ApiResult<LichessTokenResult>? lastResult;
    for (var attempt = 0; attempt < attempts; attempt += 1) {
      final result = await getLichessToken();
      if (result.isSuccess && result.data != null) return result;
      lastResult = result;
      if (attempt < attempts - 1 && retryDelay > Duration.zero) {
        await Future<void>.delayed(retryDelay);
      }
    }
    return lastResult ??
        const ApiResult<LichessTokenResult>(
          ApiStatus.network(
            'Lichess sign-in status could not be checked. Please try again later.',
          ),
        );
  }

  Future<ApiResult<String>> bindLichess() {
    return _authorizedPostAny(
      _apiUri('api/bindLichess'),
      {},
      parser: (data) => _string(data),
    );
  }

  Future<ApiResult<bool>> bindChessCom(String chessName) {
    return _authorizedPostAny(
      _apiUri('api/bindChessCom'),
      {'chess_name': chessName},
      parser: (_) => true,
    );
  }

  Future<ApiResult<bool>> bindGoogle(String idToken) {
    return _authorizedPostAny(
      _apiUri('api/bindGoogle'),
      {'id_token': idToken},
      parser: (_) => true,
    );
  }

  Future<ApiResult<bool>> bindApple(String identityToken) {
    return _authorizedPostAny(
      _apiUri('api/bindApple'),
      {'identity_token': identityToken},
      parser: (_) => true,
    );
  }

  Future<ApiResult<bool>> freeUserBind(String bindType) {
    return _authorizedPostAny(
      _apiUri('api/freeUserBind'),
      {'bind_type': bindType},
      parser: (_) => true,
    );
  }

  Future<ApiResult<bool>> logout() async {
    final result = await _authorizedPostAny(
      _apiUri('api/logout'),
      {},
      parser: (_) => true,
    );
    if (result.isSuccess) {
      session = null;
    }
    return result;
  }

  Future<ApiResult<bool>> sendResetPasswordEmail(String email) {
    return _postAny(
      _apiUri('api/sendResetPasswordEmail'),
      {'email': email},
      parser: (_) => true,
    );
  }

  Future<ApiResult<bool>> resetPassword({
    required String email,
    required String password,
    required String code,
  }) {
    return _postAny(
      _apiUri('api/resetPassword'),
      {
        'email': email,
        'password': _legacyPasswordDigest(password),
        'code': code,
      },
      parser: (_) => true,
    );
  }

  Future<ApiResult<ChessnutLoginSession>> registerWithCaptcha({
    required String username,
    required String password,
    required String email,
    required String code,
    required String captchaId,
  }) {
    return _postForm(
      _apiUri('api/registerWithCaptcha'),
      {
        'username': username,
        'password': _legacyPasswordDigest(password),
        'email': email,
        'code': code,
        'captchaId': captchaId,
      },
      parser: (json) {
        final parsed = ChessnutLoginSession.fromJson(json);
        session = parsed;
        return parsed;
      },
    );
  }

  Future<ApiResult<ChessnutLoginSession>> registerWithTurnstile({
    required String username,
    required String password,
    required String email,
    required String code,
    String avatarUrl = '',
  }) {
    return _postForm(
      _apiUri('api/v3/registerWithTurnstile'),
      {
        'username': username,
        'password': _legacyPasswordDigest(password),
        'password_plain': password.trim(),
        'email': email,
        'code': code,
        if (avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
      },
      parser: (json) {
        final parsed = ChessnutLoginSession.fromJson(json);
        session = parsed;
        return parsed;
      },
    );
  }

  Future<ApiResult<TrainListResult>> trainList({
    int page = 1,
    int count = 100,
  }) {
    return _authorizedTrainList('api/train/list', page: page, count: count);
  }

  Future<ApiResult<bool>> trainStatus() {
    return _authorizedPostAny(
      _apiUri('api/train/status'),
      {},
      parser: _bool,
    );
  }

  Future<ApiResult<TrainModel>> trainPush({
    required String pgn,
    required String title,
    required String remark,
  }) {
    return _authorizedPostForm(
      _apiUri('api/train/push'),
      {
        'pgn': pgn,
        'title': title,
        'remark': remark,
      },
      parser: TrainModel.fromJson,
    );
  }

  Future<ApiResult<bool>> modelBuildStatus() {
    return _authorizedPostAny(
      _apiUri('api/v3/modelBuild/status'),
      {},
      parser: _bool,
    );
  }

  Future<ApiResult<TrainModel>> modelBuildPush({
    required String pgn,
    required String title,
    required String remark,
  }) {
    return _authorizedPostForm(
      _apiUri('api/v3/modelBuild/push'),
      {
        'pgn': pgn,
        'title': title,
        'remark': remark,
      },
      parser: TrainModel.fromJson,
    );
  }

  Future<ApiResult<ModelBuildPreview>> previewModelBuildFromLichess({
    required String playerId,
    int maxGames = 200,
    String since = '',
    String until = '',
    String speed = '',
    String rated = '',
    String color = '',
  }) {
    return _authorizedPostForm(
      _apiUri('api/v3/modelBuild/previewLichess'),
      {
        'player_id': playerId,
        'max_games': maxGames.toString(),
        if (since.trim().isNotEmpty) 'since': since.trim(),
        if (until.trim().isNotEmpty) 'until': until.trim(),
        if (speed.trim().isNotEmpty) 'speed': speed.trim(),
        if (rated.trim().isNotEmpty) 'rated': rated.trim(),
        if (color.trim().isNotEmpty) 'color': color.trim(),
      },
      parser: ModelBuildPreview.fromJson,
    );
  }

  Future<ApiResult<bool>> pushModelBuildFromLichess({
    required String playerId,
    required String title,
    required String remark,
    int maxGames = 200,
    String since = '',
    String until = '',
    String speed = '',
    String rated = '',
    String color = '',
  }) {
    return _authorizedPostAny(
      _apiUri('api/v3/modelBuild/pushLichess'),
      {
        'player_id': playerId,
        'title': title,
        'remark': remark,
        'max_games': maxGames.toString(),
        if (since.trim().isNotEmpty) 'since': since.trim(),
        if (until.trim().isNotEmpty) 'until': until.trim(),
        if (speed.trim().isNotEmpty) 'speed': speed.trim(),
        if (rated.trim().isNotEmpty) 'rated': rated.trim(),
        if (color.trim().isNotEmpty) 'color': color.trim(),
      },
      parser: (_) => true,
    );
  }

  Future<ApiResult<ModelBuildPreview>> previewModelBuildFromGameRecords(
    GameRecordSearchRequest request,
  ) {
    return _authorizedPostForm(
      _apiUri('api/v3/modelBuild/previewGameRecords'),
      request.toForm(),
      parser: ModelBuildPreview.fromJson,
    );
  }

  Future<ApiResult<TrainModel>> pushModelBuildFromGameRecords({
    required GameRecordSearchRequest request,
    required String title,
    required String remark,
  }) {
    return _authorizedPostForm(
      _apiUri('api/v3/modelBuild/pushGameRecords'),
      {
        ...request.toForm(),
        'title': title,
        'remark': remark,
      },
      parser: TrainModel.fromJson,
    );
  }

  Future<ApiResult<ModelBuildGameRecordJob>> startModelBuildGameRecordsPreview({
    required GameRecordSearchRequest request,
    int limit = 200,
  }) {
    return _authorizedPostForm(
      _apiUri('api/v3/modelBuild/gameRecords/previewStart'),
      {
        ...request.toForm(),
        'limit': limit.toString(),
      },
      parser: ModelBuildGameRecordJob.fromJson,
    );
  }

  Future<ApiResult<ModelBuildGameRecordJob>> startModelBuildGameRecordsPush({
    required GameRecordSearchRequest request,
    required String title,
    required String remark,
    int limit = 200,
  }) {
    return _authorizedPostForm(
      _apiUri('api/v3/modelBuild/gameRecords/pushStart'),
      {
        ...request.toForm(),
        'limit': limit.toString(),
        'title': title,
        'remark': remark,
      },
      parser: ModelBuildGameRecordJob.fromJson,
    );
  }

  Future<ApiResult<ModelBuildGameRecordJob>> modelBuildGameRecordsStatus(
    String jobId,
  ) {
    return _authorizedPostForm(
      _apiUri('api/v3/modelBuild/gameRecords/status'),
      {'job_id': jobId},
      parser: ModelBuildGameRecordJob.fromJson,
    );
  }

  Future<ApiResult<ModelBuildGameRecordJob>> cancelModelBuildGameRecordsJob(
    String jobId,
  ) {
    return _authorizedPostForm(
      _apiUri('api/v3/modelBuild/gameRecords/cancel'),
      {'job_id': jobId},
      parser: ModelBuildGameRecordJob.fromJson,
    );
  }

  Future<ApiResult<bool>> trainEdit({
    required int id,
    required String title,
    required String remark,
  }) {
    return _authorizedPostAny(
      _apiUri('api/train/edit'),
      {
        'id': id.toString(),
        'title': title,
        'remark': remark,
      },
      parser: (_) => true,
    );
  }

  Future<ApiResult<TrainModel>> trainGet(int id) {
    return _authorizedPostForm(
      _apiUri('api/train/get'),
      {'id': id.toString()},
      parser: TrainModel.fromJson,
    );
  }

  Future<ApiResult<bool>> applySharedTrain({
    required int trainId,
    required String title,
    required String remark,
    required String sharedName,
  }) {
    return _authorizedPostAny(
      _apiUri('api/train/do_shared'),
      {
        'train_id': trainId.toString(),
        'title': title,
        'remark': remark,
        'shared_name': sharedName,
      },
      parser: (_) => true,
    );
  }

  Future<ApiResult<bool>> starTrain(int trainId) {
    return _authorizedPostAny(
      _apiUri('api/train/star'),
      {'train_id': trainId.toString()},
      parser: (_) => true,
    );
  }

  Future<ApiResult<bool>> unstarTrain(int trainId) {
    return _authorizedPostAny(
      _apiUri('api/train/unstar'),
      {'train_id': trainId.toString()},
      parser: (_) => true,
    );
  }

  Future<ApiResult<String>> nextMove(String json) {
    return _authorizedPostAny(
      _apiUri('api/train/next_move'),
      {'json': json},
      parser: _string,
    );
  }

  Future<ApiResult<WalletBalance>> walletBalance() {
    return _authorizedPostForm(
      _apiUri('api/wallet/balance'),
      {},
      parser: (json) {
        final balance = WalletBalance.fromJson(json);
        return WalletBalance(
          balance: _correctWalletBalance(balance.balance),
          claimedToday: balance.claimedToday,
          dailyClaimPoints: _dailyCheckInWalletRewardPoints,
          lastClaimedAt: balance.lastClaimedAt,
          memberActive: balance.memberActive,
          memberExpireAt: balance.memberExpireAt,
          claimedTaskKeys: balance.claimedTaskKeys,
        );
      },
    );
  }

  Future<ApiResult<DailyClaimResult>> claimDailyPoints({int? points}) {
    return _authorizedPostForm(
      _apiUri('api/wallet/claimDaily'),
      {
        if (points != null && points > 0) 'points': points.toString(),
      },
      parser: (json) {
        final result = DailyClaimResult.fromJson(json);
        return _normalizeWalletReward(
          result,
          points ?? 0,
          _dailyCheckInWalletRewardPoints,
        );
      },
    );
  }

  Future<ApiResult<DailyClaimResult>> claimDailyTask({
    required String taskKey,
    int? points,
  }) {
    return _authorizedPostForm(
      _apiUri('api/wallet/claimTask'),
      {
        'task_key': taskKey,
        if (points != null && points > 0) 'points': points.toString(),
      },
      parser: (json) {
        final result = DailyClaimResult.fromJson(json);
        return _normalizeWalletReward(
          result,
          points ?? 0,
          _dailyTaskWalletRewardPoints,
        );
      },
    );
  }

  Future<ApiResult<DailyClaimResult>> debugAdjustWalletPoints({
    required int amount,
  }) {
    return _authorizedPostForm(
      _apiUri('api/wallet/debugAdjust'),
      {
        'amount': amount.toString(),
        'reason': 'debug_adjust',
      },
      parser: DailyClaimResult.fromJson,
    );
  }

  Future<ApiResult<WalletLedger>> walletLedger({int page = 1, int count = 20}) {
    return _authorizedPostForm(
      _apiUri('api/wallet/ledger'),
      {
        'page': page.toString(),
        'count': count.toString(),
      },
      parser: WalletLedger.fromJson,
    );
  }

  Future<ApiResult<WalletConsumeResult>> consumePoints({
    required WalletConsumeReason reason,
    String referenceId = '',
  }) {
    return _authorizedPostForm(
      _apiUri('api/wallet/consumePoints'),
      {
        'reason': reason.apiValue,
        if (referenceId.isNotEmpty) 'reference_id': referenceId,
      },
      parser: WalletConsumeResult.fromJson,
    );
  }

  Future<ApiResult<InboxList>> inboxList({int page = 1, int count = 20}) {
    return _authorizedPostForm(
      _apiUri('api/v3/inbox/list'),
      {
        'page': page.toString(),
        'count': count.toString(),
      },
      parser: InboxList.fromJson,
    );
  }

  Future<ApiResult<int>> inboxUnreadCount() {
    return _authorizedPostForm(
      _apiUri('api/v3/inbox/unreadCount'),
      {},
      parser: (json) => _int(json['unread_count']),
    );
  }

  Future<ApiResult<InboxMarkReadResult>> markInboxMessageRead(int messageId) {
    return _authorizedPostForm(
      _apiUri('api/v3/inbox/markRead'),
      {'message_id': messageId.toString()},
      parser: InboxMarkReadResult.fromJson,
    );
  }

  Future<ApiResult<MembershipProducts>> membershipProducts() {
    return _authorizedPostForm(
      _apiUri('api/membership/products'),
      {},
      parser: MembershipProducts.fromJson,
    );
  }

  Future<ApiResult<MembershipVerificationResult>> verifyMembershipPurchase({
    required String platform,
    required String productId,
    required String receipt,
    String transactionId = '',
    String purchaseToken = '',
  }) {
    return _authorizedPostForm(
      _apiUri('api/membership/purchaseReceiptVerify'),
      {
        'platform': platform,
        'product_id': productId,
        'receipt': receipt,
        if (transactionId.isNotEmpty) 'transaction_id': transactionId,
        if (purchaseToken.isNotEmpty) 'purchase_token': purchaseToken,
      },
      parser: MembershipVerificationResult.fromJson,
    );
  }

  Future<ApiResult<GrandeurAnalysisResult>> analyzeGrandeurGame({
    required String pgn,
    required String coachProfileId,
    required String language,
  }) {
    return _authorizedPostForm(
      _apiUri('api/grandeur/analyzeGame'),
      {
        'pgn': pgn,
        'coach_profile_id': coachProfileId,
        'language': language,
      },
      parser: GrandeurAnalysisResult.fromJson,
    );
  }

  Future<ApiResult<GrandeurReviewJob>> startGrandeurReview({
    required String pgn,
    String? language,
    int? gameStep,
    String? style,
  }) {
    return _authorizedPostForm(
      _apiUri('api/v3/grandeur/push'),
      {
        'pgn': pgn,
        'lang': language?.trim().isNotEmpty == true
            ? language!.trim()
            : grandeurLanguage.value,
        if (gameStep != null && gameStep > 0) 'game_step': gameStep.toString(),
        if (style != null && style.trim().isNotEmpty)
          'style': style.trim().toLowerCase(),
      },
      parser: GrandeurReviewJob.fromJson,
    );
  }

  Future<ApiResult<GrandeurReviewJob>> getGrandeurReview(int commentId) {
    return _authorizedPostForm(
      _apiUri('api/v3/grandeur/get'),
      {'comment_id': commentId.toString()},
      parser: GrandeurReviewJob.fromJson,
    );
  }

  Future<ApiResult<GrandeurMoveExplanation>> explainGrandeurMove({
    required String analysisId,
    required int ply,
  }) {
    return _authorizedPostForm(
      _apiUri('api/grandeur/explainMove'),
      {
        'analysis_id': analysisId,
        'ply': ply.toString(),
      },
      parser: GrandeurMoveExplanation.fromJson,
    );
  }

  Future<ApiResult<GrandeurVoiceProfiles>> grandeurVoiceProfiles() {
    return _authorizedPostForm(
      _apiUri('api/grandeur/voiceProfiles'),
      {},
      parser: GrandeurVoiceProfiles.fromJson,
    );
  }

  Future<ApiResult<GrandeurAnalysisHistory>> grandeurAnalysisHistory({
    int page = 1,
    int count = 20,
  }) {
    return _authorizedPostForm(
      _apiUri('api/grandeur/analysisHistory'),
      {
        'page': page.toString(),
        'count': count.toString(),
      },
      parser: GrandeurAnalysisHistory.fromJson,
    );
  }

  Future<ApiResult<BugReportResult>> submitBugReport({
    required String description,
    required String contact,
    required BugReportDiagnostics diagnostics,
    List<BugReportAttachment> attachments = const [],
  }) {
    return _multipart(
      _apiUri('api/v3/bugReport'),
      {
        'description': description,
        'contact': contact,
        'diagnostics': jsonEncode(diagnostics.toJson()),
      },
      files: attachments
          .map(
            (attachment) => http.MultipartFile.fromBytes(
              'attachments',
              attachment.bytes,
              filename: attachment.filename,
              contentType: _mediaTypeFromString(attachment.contentType),
            ),
          )
          .toList(),
      parser: BugReportResult.fromJson,
    );
  }

  Future<ApiResult<TrainListResult>> officialSharedList({
    int page = 1,
    int count = 100,
  }) {
    return _authorizedTrainList(
      'api/train/official_shared_list',
      page: page,
      count: count,
    );
  }

  Future<ApiResult<TrainListResult>> sharedList({
    int page = 1,
    int count = 100,
  }) {
    return _authorizedTrainList(
      'api/train/shared_list',
      page: page,
      count: count,
    );
  }

  Future<ApiResult<bool>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) {
    return _authorizedPostAny(
      _apiUri('api/changePassword'),
      {
        'old_password': _legacyPasswordDigest(oldPassword),
        'password': _legacyPasswordDigest(newPassword),
      },
      parser: (_) => true,
    );
  }

  Future<ApiResult<SubscriptionStatus>> subStatus() {
    return _authorizedPostForm(
      _apiUri('api/train/subStatus'),
      {},
      parser: SubscriptionStatus.fromJson,
    );
  }

  Future<ApiResult<bool>> trainDel(int trainId) {
    return _authorizedPostAny(
      _apiUri('api/train/del'),
      {'train_id': trainId.toString()},
      parser: (_) => true,
    );
  }

  Future<ApiResult<UserElo>> getElo() async {
    final requestedUserId = session?.userId;
    final result = await _authorizedPostForm(
      _apiUri('api/getElo'),
      {},
      parser: UserElo.fromJson,
    );
    final elo = result.data?.elo;
    if (result.isSuccess &&
        elo != null &&
        requestedUserId != null &&
        session?.userId == requestedUserId) {
      _cachedCareerElo = elo;
      _cachedCareerEloUserId = requestedUserId;
    }
    return result;
  }

  Future<ApiResult<bool>> updateElo(int elo) {
    return _authorizedPostAny(
      _apiUri('api/updateElo'),
      {'elo': elo.toString()},
      parser: (_) => true,
    );
  }

  Future<ApiResult<CareerEloSettlement>> settleCareerElo(String result) {
    return _authorizedPostForm(
      _apiUri('api/updateElo'),
      {'career_result': result},
      parser: CareerEloSettlement.fromJson,
    );
  }

  Future<ApiResult<String>> getOpenaiKey() {
    return _authorizedPostAny(
      _apiUri('api/get_openai_key'),
      {},
      parser: _openAiKeyFromResponse,
    );
  }

  Future<ApiResult<PgnListResult>> getPgnList({
    int page = 1,
    int count = 10,
    bool collectd = false,
    String filter = '',
  }) {
    return _authorizedPostForm(
      _apiUri('api/getPgnList'),
      {
        'page': page.toString(),
        'count': count.toString(),
        'collectd': collectd ? '1' : '0',
        'filter': filter,
      },
      parser: PgnListResult.fromJson,
    );
  }

  Future<ApiResult<PgnListResult>> searchGameRecords(
    GameRecordSearchRequest request,
  ) {
    return _authorizedPostForm(
      _apiUri('api/v3/gameRecords/search'),
      request.toForm(),
      parser: PgnListResult.fromJson,
    );
  }

  Future<ApiResult<GameRecordSourceCounts>> getGameRecordSourceCounts() {
    return _authorizedPostForm(
      _apiUri('api/v3/gameRecords/sourceCounts'),
      const {},
      parser: GameRecordSourceCounts.fromJson,
    );
  }

  Future<ApiResult<LichessImportJob>> startLichessHistoryImport({
    required String playerId,
    int maxGames = 200,
    String since = '',
    String until = '',
    String speed = '',
    String rated = '',
    String color = '',
  }) {
    return _authorizedPostForm(
      _apiUri('api/v3/lichess/import/start'),
      {
        'player_id': playerId,
        'max_games': maxGames.toString(),
        if (since.trim().isNotEmpty) 'since': since.trim(),
        if (until.trim().isNotEmpty) 'until': until.trim(),
        if (speed.trim().isNotEmpty) 'speed': speed.trim(),
        if (rated.trim().isNotEmpty) 'rated': rated.trim(),
        if (color.trim().isNotEmpty) 'color': color.trim(),
      },
      parser: LichessImportJob.fromJson,
    );
  }

  Future<ApiResult<LichessImportJob>> lichessHistoryImportStatus(
    String jobId,
  ) {
    return _authorizedPostForm(
      _apiUri('api/v3/lichess/import/status'),
      {'job_id': jobId},
      parser: LichessImportJob.fromJson,
    );
  }

  Future<ApiResult<LichessImportJob>> cancelLichessHistoryImport(
    String jobId,
  ) {
    return _authorizedPostForm(
      _apiUri('api/v3/lichess/import/cancel'),
      {'job_id': jobId},
      parser: LichessImportJob.fromJson,
    );
  }

  Future<ApiResult<LichessImportJob>> startChessComHistoryImport({
    required String playerId,
    int maxGames = 200,
    String since = '',
    String until = '',
  }) {
    return _authorizedPostForm(
      _apiUri('api/v3/chesscom/import/start'),
      {
        'player_id': playerId,
        'max_games': maxGames.toString(),
        if (since.trim().isNotEmpty) 'since': since.trim(),
        if (until.trim().isNotEmpty) 'until': until.trim(),
      },
      parser: LichessImportJob.fromJson,
    );
  }

  Future<ApiResult<LichessImportJob>> chessComHistoryImportStatus(
    String jobId,
  ) {
    return _authorizedPostForm(
      _apiUri('api/v3/chesscom/import/status'),
      {'job_id': jobId},
      parser: LichessImportJob.fromJson,
    );
  }

  Future<ApiResult<LichessImportJob>> cancelChessComHistoryImport(
    String jobId,
  ) {
    return _authorizedPostForm(
      _apiUri('api/v3/chesscom/import/cancel'),
      {'job_id': jobId},
      parser: LichessImportJob.fromJson,
    );
  }

  Future<ApiResult<Maia3BotMoveResult>> maia3BotMove({
    required String fen,
    List<String> moves = const [],
    String model = 'maia3-5m',
    int elo = 1500,
    int multiPv = 5,
  }) {
    return _authorizedPostForm(
      _apiUri('api/v3/maia3/botMove'),
      {
        'fen': fen,
        'moves': moves.join(' '),
        'model': model,
        'elo': elo.toString(),
        'multipv': multiPv.toString(),
      },
      parser: Maia3BotMoveResult.fromJson,
    );
  }

  Future<ApiResult<Maia3HumanReviewJob>> startMaia3HumanReview({
    required String pgn,
    int? pgnId,
    String model = 'maia3-5m',
    int elo = 1500,
    int multiPv = 5,
    bool force = false,
  }) {
    return _authorizedPostForm(
      _apiUri('api/v3/analysis/maia3/start'),
      {
        'pgn': pgn,
        if (pgnId != null && pgnId > 0) 'pgn_id': pgnId.toString(),
        'model': model,
        'elo': elo.toString(),
        'multipv': multiPv.toString(),
        if (force) 'force': '1',
      },
      parser: Maia3HumanReviewJob.fromJson,
    );
  }

  Future<ApiResult<Maia3HumanReviewJob>> maia3HumanReviewStatus(
    String jobId,
  ) {
    return _authorizedPostForm(
      _apiUri('api/v3/analysis/maia3/status'),
      {'job_id': jobId},
      parser: Maia3HumanReviewJob.fromJson,
    );
  }

  Future<Puzzle?> puzzleTagRandom(int tag) async {
    return _getPuzzle('$tag/random');
  }

  Future<PuzzleInfo?> puzzleInfo() async {
    final body = await _getString(_puzzleUri('info'));
    if (body == null) {
      return null;
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return PuzzleInfo.fromJson(decoded);
  }

  Future<Puzzle?> puzzleRandom() => _getPuzzle('random');

  Future<Puzzle?> puzzle(int id) => _getPuzzle('get/$id');

  Future<String?> chesscomJs() =>
      _getString(_apiUri('static/js/chess-helper.js'));

  Future<String?> macVersion() => _getString(_apiUri('static/mac_version.txt'));

  Future<String?> appVersionText() => _getString(_apiUri('static/version.txt'));

  Future<String?> moveVersion() {
    return _getString(moveUpdateUri);
  }

  Future<MoveFirmwareRelease?> moveFirmwareRelease() async {
    final source = await moveVersion();
    return source == null ? null : MoveFirmwareRelease.tryParse(source);
  }

  Future<Uint8List?> downloadMoveFirmware(Uri uri) async {
    try {
      final response = await _httpClient.get(uri);
      if (response.statusCode != HttpStatus.ok || response.bodyBytes.isEmpty) {
        return null;
      }
      return Uint8List.fromList(response.bodyBytes);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getString(Uri uri) => _getString(uri);

  Uri shareUrl(String shareId) => _serviceUri(baseUri, 'v3/share/$shareId');

  Uri _apiUri(String path) => _serviceUri(baseUri, path);

  Uri _puzzleUri(String path) => _serviceUri(puzzleBaseUri, path);

  Uri _serviceUri(Uri base, String path) {
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final pathSuffix = path.startsWith('/') ? path.substring(1) : path;
    final joinedPath = basePath.isEmpty ? pathSuffix : '$basePath/$pathSuffix';
    return base.replace(path: joinedPath);
  }

  String _legacyPasswordDigest(String password) {
    return sha256.convert(utf8.encode(password.trim())).toString();
  }

  Future<ApiResult<ChessnutLoginSession>> _socialLogin(
    String path,
    Map<String, String> fields,
  ) {
    return _postForm(
      _apiUri(path),
      fields,
      parser: (json) {
        final parsed = ChessnutLoginSession.fromJson(json);
        session = parsed;
        return parsed;
      },
    );
  }

  Future<ApiResult<T>> _authorizedPostForm<T>(
    Uri uri,
    Map<String, String> fields, {
    required T Function(Map<String, dynamic> json) parser,
  }) {
    final activeSession = session;
    if (activeSession == null) {
      return Future.value(
        const ApiResult(ApiStatus.api(code: 401, message: 'Not logged in')),
      );
    }

    return _postForm(
      uri,
      {
        ...fields,
        'user_id': activeSession.userId.toString(),
        'token': activeSession.token,
      },
      parser: parser,
      authorized: true,
      authorizedSession: activeSession,
    );
  }

  Future<ApiResult<T>> _authorizedPostAny<T>(
    Uri uri,
    Map<String, String> fields, {
    required T Function(Object? data) parser,
  }) {
    final activeSession = session;
    if (activeSession == null) {
      return Future.value(
        const ApiResult(ApiStatus.api(code: 401, message: 'Not logged in')),
      );
    }

    return _postAny(
      uri,
      {
        ...fields,
        'user_id': activeSession.userId.toString(),
        'token': activeSession.token,
      },
      parser: parser,
      authorized: true,
      authorizedSession: activeSession,
    );
  }

  Future<ApiResult<T>> _multipart<T>(
    Uri uri,
    Map<String, String> fields, {
    required List<http.MultipartFile> files,
    required T Function(Map<String, dynamic> json) parser,
    bool authorized = false,
  }) async {
    final activeSession = session;
    final form = {
      ...fields,
      if (activeSession != null) ...{
        'user_id': activeSession.userId.toString(),
        'token': activeSession.token,
      },
      'lang': language.value,
    };

    try {
      final request = http.MultipartRequest('POST', uri)
        ..fields.addAll(form)
        ..files.addAll(files);
      final streamedResponse = await _httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode != HttpStatus.ok) {
        final deploymentMessage = _deploymentErrorMessage(uri, response);
        if (deploymentMessage != null) {
          return ApiResult(ApiStatus.network(deploymentMessage));
        }
        if (response.statusCode == HttpStatus.notFound) {
          return const ApiResult(
            ApiStatus.api(code: HttpStatus.notFound, message: 'Not found'),
          );
        }
        return _networkFailure<T>();
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return _networkFailure<T>();
      }

      final code = _int(decoded['code']);
      final info = _string(decoded['info']);
      if (code != 200) {
        if (authorized && code == 600) {
          return await _recoverExpiredAuthorization<T>(activeSession);
        }
        return ApiResult(ApiStatus.api(
          code: code,
          message: _apiErrorMessage(uri, code, info),
        ));
      }

      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        return _networkFailure<T>();
      }
      return ApiResult(const ApiStatus.success(), data: parser(data));
    } catch (error) {
      return _networkFailure<T>();
    }
  }

  Future<ApiResult<ChessnutLoginSession>> _updateProfileLegacy({
    required String username,
    required String avatarUrl,
    required ChessnutApiSession activeSession,
  }) async {
    final files = <http.MultipartFile>[];
    if (avatarUrl.startsWith('assets/')) {
      try {
        final bytes = await rootBundle.load(avatarUrl);
        files.add(http.MultipartFile.fromBytes(
          'avatar_img',
          bytes.buffer.asUint8List(),
          filename: avatarUrl.split('/').last,
          contentType: _mediaTypeFromAssetPath(avatarUrl),
        ));
      } catch (_) {
        return const ApiResult(
          ApiStatus.network('Unable to load selected avatar.'),
        );
      }
    }

    final result = await _multipart(
      _apiUri('api/updateInfo'),
      {'username': username},
      files: files,
      parser: (json) => _profileSessionFromResponse(
        json,
        activeSession,
        username: username,
        avatarUrl: avatarUrl,
      ),
      authorized: true,
    );
    if (result.isSuccess && result.data != null) {
      session = result.data;
    }
    return result;
  }

  Future<ApiResult<TrainListResult>> _authorizedTrainList(
    String path, {
    required int page,
    required int count,
  }) {
    return _authorizedPostAny(
      _apiUri(path),
      {
        'page': page.toString(),
        'count': count.toString(),
      },
      parser: TrainListResult.fromJson,
    );
  }

  Future<ApiResult<T>> _postForm<T>(
    Uri uri,
    Map<String, String> fields, {
    required T Function(Map<String, dynamic> json) parser,
    bool authorized = false,
    ChessnutApiSession? authorizedSession,
    Duration? timeout,
  }) {
    return _postAny(
      uri,
      fields,
      parser: (data) {
        if (data is! Map<String, dynamic>) {
          throw const FormatException('Invalid response data');
        }
        return parser(data);
      },
      authorized: authorized,
      authorizedSession: authorizedSession,
      timeout: timeout,
    );
  }

  Future<ApiResult<T>> _postAny<T>(
    Uri uri,
    Map<String, String> fields, {
    required T Function(Object? data) parser,
    bool authorized = false,
    ChessnutApiSession? authorizedSession,
    Duration? timeout,
  }) async {
    final form = {'lang': language.value, ...fields};

    try {
      final responseFuture = _httpClient.post(uri, body: form);
      final response = timeout == null
          ? await responseFuture
          : await responseFuture.timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        final deploymentMessage = _deploymentErrorMessage(uri, response);
        if (deploymentMessage != null) {
          return ApiResult(ApiStatus.network(deploymentMessage));
        }
        if (response.statusCode == HttpStatus.notFound) {
          return const ApiResult(
            ApiStatus.api(code: HttpStatus.notFound, message: 'Not found'),
          );
        }
        return _networkFailure<T>();
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return _networkFailure<T>();
      }

      final code = _int(decoded['code']);
      final info = _string(decoded['info']);
      if (code != 200) {
        if (authorized && code == 600) {
          return await _recoverExpiredAuthorization<T>(authorizedSession);
        }
        return ApiResult(ApiStatus.api(
          code: code,
          message: _apiErrorMessage(uri, code, info),
        ));
      }

      return ApiResult(const ApiStatus.success(),
          data: parser(decoded['data']));
    } catch (error) {
      return _networkFailure<T>();
    }
  }

  Future<ApiResult<T>> _recoverExpiredAuthorization<T>(
    ChessnutApiSession? expiredSession,
  ) async {
    if (expiredSession == null) {
      await _expireSession();
      return const ApiResult(
        ApiStatus.api(code: 600, message: authSessionExpiredMessage),
      );
    }

    final currentSession = session;
    if (currentSession != null &&
        currentSession.userId == expiredSession.userId &&
        currentSession.token != expiredSession.token) {
      onAuthTokenRefreshed?.call(authTokenRefreshedRetryMessage);
      return const ApiResult(
        ApiStatus.api(
          code: authTokenRefreshedRetryCode,
          message: authTokenRefreshedRetryMessage,
        ),
      );
    }

    final refreshResult = await _refreshExpiredAccessToken(expiredSession);
    if (refreshResult.status.networkError != null) {
      return _networkFailure<T>(notify: false);
    }
    if (refreshResult.isSuccess && refreshResult.data != null) {
      onAuthTokenRefreshed?.call(authTokenRefreshedRetryMessage);
      return const ApiResult(
        ApiStatus.api(
          code: authTokenRefreshedRetryCode,
          message: authTokenRefreshedRetryMessage,
        ),
      );
    }
    if (_isRefreshTokenExpiredStatus(refreshResult.status)) {
      await _expireSession();
      return const ApiResult(
        ApiStatus.api(code: 600, message: authSessionExpiredMessage),
      );
    }
    return ApiResult<T>(refreshResult.status);
  }

  Future<void> _expireSession() async {
    try {
      await onAuthExpired?.call();
    } finally {
      session = null;
    }
  }

  ApiResult<T> _networkFailure<T>({bool notify = true}) {
    if (notify) onNetworkError?.call(networkConnectionErrorMessage);
    return const ApiResult(ApiStatus.network(networkConnectionErrorMessage));
  }

  Future<String?> _getString(Uri uri) async {
    try {
      final response = await _httpClient.get(uri);
      if (response.statusCode == HttpStatus.ok) {
        return utf8.decode(response.bodyBytes);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Puzzle?> _getPuzzle(String path) async {
    final body = await _getString(_puzzleUri(path));
    if (body == null) {
      return null;
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return Puzzle.fromJson(decoded);
  }
}

String? _deploymentErrorMessage(Uri uri, http.Response response) {
  if (response.statusCode == HttpStatus.notFound) {
    final routeMessage = _friendlyMissingRouteMessage(uri.path);
    if (routeMessage != null) return routeMessage;
  }
  return null;
}

String _openAiKeyFromResponse(Object? data) {
  if (data is Map) {
    for (final key in const [
      'key',
      'value',
      'openai_key',
      'openAIKey',
      'token',
      'session',
      'client_secret',
    ]) {
      final raw = data[key];
      final value =
          raw is Map ? _openAiKeyFromResponse(raw).trim() : _string(raw).trim();
      if (value.isNotEmpty) return value;
    }
    final nested = data['data'];
    if (nested != null && !identical(nested, data)) {
      final value = _openAiKeyFromResponse(nested).trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }
  return _string(data);
}

String _apiErrorMessage(Uri uri, int code, String info) {
  if (code == HttpStatus.notFound) {
    final routeMessage = _friendlyMissingRouteMessage(uri.path);
    if (routeMessage != null) return routeMessage;
  }
  final trimmed = info.trim();
  return trimmed.isEmpty
      ? 'Unable to reach Chessnut services. Please try again later.'
      : trimmed;
}

String? _friendlyMissingRouteMessage(String path) {
  if (path.startsWith('/api/wallet/') || path.startsWith('/api/membership/')) {
    return walletServiceUnavailableMessage;
  }
  if (path.startsWith('/api/inbox/')) {
    return 'Inbox is not available right now. Check your connection and try again.';
  }
  if (path == '/api/bindLichess') {
    return 'Lichess authorization is not available right now. Please try again later.';
  }
  if (path == '/api/getLichessToken') {
    return 'Lichess sign-in status could not be checked. Please try again later.';
  }
  if (path == '/api/bindGoogle' ||
      path == '/api/bindApple' ||
      path == '/api/freeUserBind') {
    return 'Linked account update failed. Please try again.';
  }
  if (path == '/api/updateInfo') {
    return 'Profile update is not available right now. Please try again later.';
  }
  return null;
}

bool _isProfileEndpointMissing(ApiStatus status) {
  if (status.apiErrorCode == HttpStatus.notFound) return true;
  return status.networkError?.contains('404') == true;
}

class LichessBoardApi {
  const LichessBoardApi({required this.token});

  final String token;

  Uri gameStreamUri(String gameId) {
    return Uri.https('lichess.org', 'api/board/game/stream/$gameId');
  }

  Uri moveUri({required String gameId, required String uci}) {
    return Uri.https('lichess.org', 'api/board/game/$gameId/move/$uci');
  }

  Map<String, String> get authHeaders => {'Authorization': 'Bearer $token'};
}

String _string(Object? value) => value?.toString() ?? '';

String? _nullableString(Object? value) => value?.toString();

DateTime? _dateTimeFromBackend(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is num) return _dateTimeFromUnix(value.toInt());
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  final numeric = int.tryParse(text);
  if (numeric != null) return _dateTimeFromUnix(numeric);
  return DateTime.tryParse(text);
}

DateTime? _dateTimeFromUnix(int value) {
  if (value <= 0) return null;
  final milliseconds =
      value > 1000000000000 ? value : value * Duration.millisecondsPerSecond;
  return DateTime.fromMillisecondsSinceEpoch(milliseconds);
}

double? _progress(Object? value) {
  if (value == null) return null;
  final parsed =
      value is num ? value.toDouble() : double.tryParse(value.toString());
  if (parsed == null) return null;
  if (parsed <= 1) return parsed.clamp(0, 1).toDouble();
  return (parsed / 100).clamp(0, 1).toDouble();
}

MediaType _mediaTypeFromString(String value) {
  final parts = value.split('/');
  if (parts.length == 2 && parts.every((part) => part.isNotEmpty)) {
    return MediaType(parts[0], parts[1]);
  }
  return MediaType('application', 'octet-stream');
}

MediaType _mediaTypeFromAssetPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return MediaType('image', 'png');
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return MediaType('image', 'jpeg');
  }
  if (lower.endsWith('.webp')) return MediaType('image', 'webp');
  return MediaType('application', 'octet-stream');
}

ChessnutLoginSession _profileSessionFromResponse(
  Object? data,
  ChessnutApiSession activeSession, {
  required String username,
  required String avatarUrl,
}) {
  final json = data is Map<String, dynamic> ? data : const <String, dynamic>{};
  final parsed = ChessnutLoginSession.fromJson(json);
  final fallback =
      activeSession is ChessnutLoginSession ? activeSession : parsed;
  return fallback.copyWith(
    avatarUrl: parsed.avatarUrl.isNotEmpty ? parsed.avatarUrl : avatarUrl,
    bindApple: json.containsKey('bind_apple') ? parsed.bindApple : null,
    bindChess: json.containsKey('bind_chess') ? parsed.bindChess : null,
    bindGoogle: json.containsKey('bind_google') ? parsed.bindGoogle : null,
    bindLichess: json.containsKey('bind_lichess') ? parsed.bindLichess : null,
    chessName: parsed.chessName.isNotEmpty ? parsed.chessName : null,
    email: parsed.email.isNotEmpty ? parsed.email : null,
    lichessName: parsed.lichessName.isNotEmpty ? parsed.lichessName : null,
    noPassword: json.containsKey('no_password') ? parsed.noPassword : null,
    phone: parsed.phone.isNotEmpty ? parsed.phone : null,
    region: parsed.region.isNotEmpty ? parsed.region : null,
    token: parsed.token.isEmpty ? activeSession.token : parsed.token,
    refreshToken: parsed.refreshToken?.isEmpty ?? true
        ? activeSession.refreshToken
        : parsed.refreshToken,
    userId: parsed.userId == 0 ? activeSession.userId : parsed.userId,
    username: parsed.username.isEmpty ? username : parsed.username,
  );
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int _firstPositiveInt(Iterable<Object?> values) {
  for (final value in values) {
    final parsed = _int(value);
    if (parsed > 0) return parsed;
  }
  return 0;
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return int.tryParse(text);
}

double _double(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

bool _bool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  return value?.toString().toLowerCase() == 'true';
}

String _decodeBackendBase64(String value) {
  if (value.isEmpty) {
    return '';
  }
  try {
    return utf8.decode(base64Decode(value));
  } on FormatException {
    return value;
  }
}
