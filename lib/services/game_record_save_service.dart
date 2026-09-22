import 'dart:async';

import '../models/app_models.dart';
import 'chessnut_api_client.dart';
import 'game_record_repository.dart';
import 'local_game_record_store.dart';

class GameRecordSaveResult {
  const GameRecordSaveResult({
    required this.status,
    this.record,
    this.savedLocally = false,
    this.alreadyUploaded = false,
  });

  final ApiStatus status;
  final GameRecord? record;
  final bool savedLocally;
  final bool alreadyUploaded;
}

/// Online-first saving for the active game. Historical fallback records are
/// uploaded ONLY by [uploadLocal]; there is deliberately no background sync job.
class GameRecordSaveService {
  GameRecordSaveService({
    required this.apiClient,
    required this.localStore,
    this.requestTimeout = const Duration(seconds: 8),
    this.offlineRetryDelay = const Duration(seconds: 10),
  });

  final ChessnutApiClient apiClient;
  final LocalGameRecordStore localStore;
  final Duration requestTimeout;
  final Duration offlineRetryDelay;
  final Map<String, Future<void>> _operations = {};
  DateTime? _retryOnlineAfter;

  Future<T> _serial<T>(String id, Future<T> Function() operation) {
    final previous = _operations[id] ?? Future<void>.value();
    final result = previous.then((_) => operation());
    final tail =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _operations[id] = tail;
    unawaited(tail.then((_) {
      if (identical(_operations[id], tail)) _operations.remove(id);
    }));
    return result;
  }

  Future<void> get idle => Future.wait(_operations.values.toList());

  Future<void> finishPendingSaves() async {
    do {
      await idle;
      // Let game-screen coordinators enqueue their final coalesced snapshot.
      await Future<void>.delayed(Duration.zero);
    } while (_operations.isNotEmpty);
  }

  Future<GameRecordSaveResult> saveLive(
    GameRecordDraft draft, {
    required int? ownerUserId,
    int? pgnId,
    String? shareId,
  }) =>
      _serial(draft.id, () async {
        LocalGameRecord? local;
        try {
          local = localStore.peek(draft.id);
        } catch (_) {
          // A local storage failure must not prevent a healthy cloud save.
        }
        final session = apiClient.session;
        // Local games are shared. Only keep an active request tied to the
        // account captured when this game was opened.
        final canUpload = session != null &&
            (ownerUserId == null || ownerUserId == session.userId);
        final usesLocalReference =
            local != null && (pgnId == null || pgnId == local.pgnId);
        final remoteUserId =
            usesLocalReference ? local.remoteUserId : ownerUserId;
        final remotePgnId = pgnId ?? local?.pgnId;
        final remoteShareId = shareId ?? local?.shareId;
        final coolingDown = _retryOnlineAfter?.isAfter(DateTime.now()) ?? false;
        if (canUpload && !coolingDown) {
          final result = await _upload(
            draft,
            session: session,
            pgnId: remoteUserId == session.userId ? remotePgnId : null,
            shareId: remoteUserId == session.userId ? remoteShareId : null,
            findPlatformRecord: local == null && draft.playMode == 'lichess',
          );
          if (result.status.isSuccess && result.record != null) {
            _retryOnlineAfter = null;
            if (local != null) {
              try {
                await localStore.markUploaded(
                  local: local,
                  userId: session.userId,
                  pgnId: result.record!.pgnId!,
                  shareId: result.record!.shareId,
                );
              } catch (_) {
                // The cloud acknowledgement is still valid. Keep the local
                // copy instead of deleting data when a receipt write fails.
                return GameRecordSaveResult(
                  status: const ApiStatus.api(
                    code: 507,
                    message:
                        'Saved online, but the local upload status could not be saved.',
                  ),
                  record: result.record,
                );
              }
            }
            return result;
          }
          if (result.status.networkError != null) {
            _retryOnlineAfter = DateTime.now().add(offlineRetryDelay);
          }
        }
        try {
          await localStore.saveFallback(
            draft,
            remoteUserId: remoteUserId,
            pgnId: remotePgnId,
            shareId: remoteShareId,
          );
          return GameRecordSaveResult(
            status: const ApiStatus.success(),
            record: draft.toRecord(
              pgnId: pgnId ?? local?.pgnId,
              shareId: shareId ?? local?.shareId,
              local: true,
            ),
            savedLocally: true,
          );
        } catch (_) {
          return const GameRecordSaveResult(
            status: ApiStatus.api(
              code: 507,
              message:
                  'Game could not be saved locally. Check available storage and try again.',
            ),
          );
        }
      });

  /// Explicit user action. Already-uploaded games are skipped even if their
  /// local copy has since changed. No remote list is read or reconciled.
  Future<GameRecordSaveResult> uploadLocal(String id) => _serial(id, () async {
        final session = apiClient.session;
        if (session == null) {
          return const GameRecordSaveResult(
            status: ApiStatus.api(
                code: 401, message: 'Sign in to upload local games.'),
          );
        }
        final local = await localStore.find(id);
        if (local == null) {
          return const GameRecordSaveResult(
            status: ApiStatus.api(
                code: 404, message: 'Local game no longer exists.'),
          );
        }
        if (local.isSynced) {
          return GameRecordSaveResult(
            status: const ApiStatus.success(),
            record: local.record,
            alreadyUploaded: true,
          );
        }
        final result = await _upload(
          local.draft,
          session: session,
          pgnId: local.remoteUserId == session.userId ? local.pgnId : null,
          shareId: local.remoteUserId == session.userId ? local.shareId : null,
        );
        if (result.status.isSuccess && result.record != null) {
          await localStore.markUploaded(
            local: local,
            userId: session.userId,
            pgnId: result.record!.pgnId!,
            shareId: result.record!.shareId,
          );
        }
        return result;
      });

  Future<GameRecordSaveResult> _upload(
    GameRecordDraft draft, {
    required ChessnutApiSession session,
    int? pgnId,
    String? shareId,
    bool findPlatformRecord = false,
  }) async {
    // Freeze the request's account. A later account switch cannot retarget an
    // in-flight upload or its token refresh, nor navigate away from a game.
    final client = ChessnutApiClient(
      httpClient: apiClient.httpClient,
      baseUri: apiClient.baseUri,
      session: session,
      language: apiClient.language.value,
      onSessionRefreshed: (refreshed) async {
        if (apiClient.session?.userId != session.userId ||
            apiClient.session?.token != session.token) {
          return;
        }
        apiClient.session = refreshed;
        await apiClient.onSessionRefreshed?.call(refreshed);
      },
    );
    try {
      if (pgnId == null && findPlatformRecord) {
        final existing = await GameRecordRepository(apiClient: client)
            .findExistingRecord(
              pgn: draft.pgn,
              lichessGameId: draft.metadata.lichessGameId ?? '',
              chessnutGameId: draft.id,
            )
            .timeout(requestTimeout);
        pgnId = existing?.pgnId;
        shareId = existing?.shareId;
      }
      ApiStatus status;
      if (pgnId == null || pgnId <= 0) {
        Future<ApiResult<UploadPgnResult>> send() => client
            .uploadPgn(
              pgn: draft.archivePgn,
              whiteName: draft.whiteName,
              blackName: draft.blackName,
              playTime: draft.playTime,
              playMode: draft.playMode,
              winId: draft.winId,
              gameStatus: draft.gameStatus,
              gameStep: draft.gameStep,
              metadata: _metadata(draft),
            )
            .timeout(requestTimeout);
        var result = await send();
        if (result.status.apiErrorCode == authTokenRefreshedRetryCode) {
          result = await send();
        }
        status = result.status;
        if (result.isSuccess) {
          pgnId = result.data?.pgnId;
          shareId = result.data?.shareId;
        }
      } else {
        Future<ApiResult<PgnUpdateResult>> send() => client
            .updatePgn(
              pgnId: pgnId!,
              pgn: draft.archivePgn,
              whiteName: draft.whiteName,
              blackName: draft.blackName,
              playTime: draft.playTime,
              playMode: draft.playMode,
              winId: draft.winId,
              gameStatus: draft.gameStatus,
              gameStep: draft.gameStep,
              metadata: _metadata(draft),
            )
            .timeout(requestTimeout);
        var result = await send();
        if (result.status.apiErrorCode == authTokenRefreshedRetryCode) {
          result = await send();
        }
        status = result.status;
      }
      if (!status.isSuccess) return GameRecordSaveResult(status: status);
      if (pgnId == null || pgnId <= 0) {
        return const GameRecordSaveResult(
          status:
              ApiStatus.network('The server did not confirm the saved game.'),
        );
      }
      return GameRecordSaveResult(
        status: const ApiStatus.success(),
        record: draft.toRecord(pgnId: pgnId, shareId: shareId),
      );
    } catch (_) {
      return const GameRecordSaveResult(
        status: ApiStatus.network('Game upload failed. Please try again.'),
      );
    } finally {
      client.language.dispose();
      client.grandeurLanguage.dispose();
      // The HTTP transport belongs to the app, not this scoped client.
    }
  }

  PgnSaveMetadata _metadata(GameRecordDraft draft) => PgnSaveMetadata(
        clientGameId: draft.id,
        lichessGameId: draft.metadata.lichessGameId,
        lichessName: draft.metadata.lichessName,
        lichessToken: draft.metadata.lichessToken,
        playerColor: draft.metadata.playerColor,
        speed: draft.metadata.speed,
        timeControl: draft.metadata.timeControl,
        opponentName: draft.metadata.opponentName,
      );
}
