import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_preferences_store.dart';
import 'chessnut_api_client.dart';

enum Maia3HumanReviewTaskState { running, completed, failed }

class Maia3HumanReviewTaskSnapshot {
  const Maia3HumanReviewTaskSnapshot({
    required this.state,
    required this.status,
    this.progress = 0,
    this.completedPly = 0,
    this.totalPly = 0,
    this.report,
  });

  final Maia3HumanReviewTaskState state;
  final String status;
  final double progress;
  final int completedPly;
  final int totalPly;
  final Maia3HumanReviewReport? report;
}

class Maia3HumanReviewTask extends ValueNotifier<Maia3HumanReviewTaskSnapshot> {
  Maia3HumanReviewTask({
    required this.cacheKey,
    required this.pgn,
    required this.pgnId,
    required this.apiClient,
    required this.cacheStore,
    required this.onReportCacheChanged,
    this.elo = 1500,
    this.model = 'maia3-5m',
    this.multiPv = 5,
    this.pollInterval = const Duration(seconds: 1),
  }) : super(const Maia3HumanReviewTaskSnapshot(
          state: Maia3HumanReviewTaskState.running,
          status: 'Starting Maia3 Human Review...',
        )) {
    done = _run();
  }

  final String cacheKey;
  final String pgn;
  final int? pgnId;
  final ChessnutApiClient apiClient;
  final AppPreferencesAnalysisReportCacheStore? cacheStore;
  final FutureOr<void> Function()? onReportCacheChanged;
  final int elo;
  final String model;
  final int multiPv;
  final Duration pollInterval;
  late final Future<Maia3HumanReviewTaskSnapshot> done;

  Future<Maia3HumanReviewTaskSnapshot> _run() async {
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        final start = await apiClient.startMaia3HumanReview(
          pgn: pgn,
          pgnId: pgnId,
          model: model,
          elo: elo,
          multiPv: multiPv,
          force: attempt > 0,
        );
        if (!start.isSuccess || start.data == null) {
          return _fail(_requestFailureMessage(
            'Maia3 Human Review could not start',
            start.status.errorMessage,
            fallback:
                'Maia3 Human Review could not start. Please try again later.',
          ));
        }
        var job = start.data!;
        _applyJob(job);
        while (!job.isDone) {
          if (pollInterval > Duration.zero) {
            await Future<void>.delayed(pollInterval);
          }
          final status = await apiClient.maia3HumanReviewStatus(job.jobId);
          if (!status.isSuccess || status.data == null) {
            return _fail(_requestFailureMessage(
              'Unable to refresh Maia3 progress',
              status.status.errorMessage,
              fallback:
                  'Unable to refresh Maia3 progress. Check your connection and try again.',
            ));
          }
          job = status.data!;
          _applyJob(job);
        }
        if (job.status == 'failed' && attempt == 0) {
          value = const Maia3HumanReviewTaskSnapshot(
            state: Maia3HumanReviewTaskState.running,
            status:
                'Retrying Maia3 Human Review with a fresh cloud analysis...',
          );
          continue;
        }
        if (job.status == 'failed') {
          return _fail(job.errorMessage.isEmpty
              ? 'Maia3 Human Review failed. Please try again.'
              : job.errorMessage);
        }
        final report = job.report;
        if (report == null) {
          return _fail(
              'Maia3 finished, but the Human Review report was not available. Please try again.');
        }
        await cacheStore?.writeMaia3(cacheKey, pgn, report);
        await onReportCacheChanged?.call();
        final snapshot = Maia3HumanReviewTaskSnapshot(
          state: Maia3HumanReviewTaskState.completed,
          progress: 1,
          completedPly: report.moves.length,
          totalPly: report.moves.length,
          status: 'Maia3 Human Review ready.',
          report: report,
        );
        value = snapshot;
        return snapshot;
      }
      return _fail('Maia3 Human Review failed. Please try again.');
    } catch (_) {
      return _fail(
        'Maia3 Human Review could not start. Please try again, or reopen this game from Game Record.',
      );
    }
  }

  void _applyJob(Maia3HumanReviewJob job) {
    final progress = job.progressPercent == null
        ? 0.0
        : (job.progressPercent!.clamp(0, 100) / 100).toDouble();
    value = Maia3HumanReviewTaskSnapshot(
      state: Maia3HumanReviewTaskState.running,
      progress: progress,
      completedPly: job.analyzedPly,
      totalPly: job.totalPly,
      status: _jobStatusLabel(job),
      report: job.report,
    );
  }

  Maia3HumanReviewTaskSnapshot _fail(String status) {
    final snapshot = Maia3HumanReviewTaskSnapshot(
      state: Maia3HumanReviewTaskState.failed,
      status: status,
    );
    value = snapshot;
    return snapshot;
  }

  String _requestFailureMessage(
    String prefix,
    String? detail, {
    required String fallback,
  }) {
    final trimmed = detail?.trim() ?? '';
    if (trimmed.isEmpty) return fallback;
    if (trimmed.startsWith(prefix)) return trimmed;
    return '$prefix. $trimmed';
  }

  String _jobStatusLabel(Maia3HumanReviewJob job) {
    final percent = job.progressPercent;
    if (percent != null) {
      return 'Maia3 Human Review is $percent% complete. You can leave this page and reopen it later.';
    }
    switch (job.stage) {
      case 'queued':
        return 'Maia3 Human Review is queued.';
      case 'analyzing':
        return 'Maia3 is estimating likely human moves for this game.';
      default:
        return 'Maia3 Human Review is running...';
    }
  }
}

class Maia3HumanReviewTaskCoordinator {
  final Map<String, Maia3HumanReviewTask> _tasks = {};

  Maia3HumanReviewTask startOrAttach({
    required String cacheKey,
    required String pgn,
    required int? pgnId,
    required ChessnutApiClient apiClient,
    required AppPreferencesAnalysisReportCacheStore? cacheStore,
    required FutureOr<void> Function()? onReportCacheChanged,
    int elo = 1500,
    String model = 'maia3-5m',
    int multiPv = 5,
    Duration pollInterval = const Duration(seconds: 1),
  }) {
    final taskKey = '$cacheKey:$model:$elo:$multiPv';
    final existing = _tasks[taskKey];
    if (existing != null) return existing;
    final task = Maia3HumanReviewTask(
      cacheKey: cacheKey,
      pgn: pgn,
      pgnId: pgnId,
      apiClient: apiClient,
      cacheStore: cacheStore,
      onReportCacheChanged: onReportCacheChanged,
      elo: elo,
      model: model,
      multiPv: multiPv,
      pollInterval: pollInterval,
    );
    _tasks[taskKey] = task;
    task.done.whenComplete(() {
      if (identical(_tasks[taskKey], task)) {
        _tasks.remove(taskKey);
      }
    });
    return task;
  }
}

final maia3HumanReviewTaskCoordinator = Maia3HumanReviewTaskCoordinator();
