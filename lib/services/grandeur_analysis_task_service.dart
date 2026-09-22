import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'app_preferences_store.dart';
import 'chessnut_api_client.dart';

enum GrandeurAnalysisTaskState { queued, running, completed, failed }

class GrandeurAnalysisTaskSnapshot {
  const GrandeurAnalysisTaskSnapshot({
    required this.state,
    required this.status,
    this.progress = 0,
    this.job,
    this.report,
  });

  final GrandeurAnalysisTaskState state;
  final String status;
  final double progress;
  final GrandeurReviewJob? job;
  final GrandeurAnalysisResult? report;
}

class GrandeurAnalysisTask extends ValueNotifier<GrandeurAnalysisTaskSnapshot> {
  GrandeurAnalysisTask({
    required this.cacheKey,
    required this.pgn,
    required this.apiClient,
    required this.initialJob,
    required this.styleId,
    required this.cacheStore,
    required this.onReportCacheChanged,
    this.pollInterval = const Duration(seconds: 8),
    this.maxPolls = 120,
  }) : super(GrandeurAnalysisTaskSnapshot(
          state: GrandeurAnalysisTaskState.queued,
          status: 'Grandeur report is preparing.',
          progress: _progressForJob(initialJob, 0),
          job: initialJob,
        )) {
    done = _run();
  }

  final String cacheKey;
  final String pgn;
  final ChessnutApiClient apiClient;
  final GrandeurReviewJob initialJob;
  final String styleId;
  final AppPreferencesAnalysisReportCacheStore? cacheStore;
  final FutureOr<void> Function()? onReportCacheChanged;
  final Duration pollInterval;
  final int maxPolls;
  late final Future<GrandeurAnalysisTaskSnapshot> done;

  Future<GrandeurAnalysisTaskSnapshot> _run() async {
    try {
      var job = initialJob;
      for (var poll = 0; poll < maxPolls; poll++) {
        if (poll > 0 || !job.completed) {
          final result = await apiClient.getGrandeurReview(job.commentId);
          if (!result.isSuccess || result.data == null) {
            final snapshot = GrandeurAnalysisTaskSnapshot(
              state: GrandeurAnalysisTaskState.failed,
              progress: 0,
              job: job,
              status: result.status.errorMessage ??
                  'Grandeur is temporarily unavailable. Please try again later.',
            );
            value = snapshot;
            return snapshot;
          }
          job = result.data!;
        }

        if (job.completed) {
          value = GrandeurAnalysisTaskSnapshot(
            state: GrandeurAnalysisTaskState.running,
            progress: 0.85,
            job: job,
            status: 'Grandeur report is ready. Downloading coach notes...',
          );
          final report = await _loadReport(job);
          if (report == null) {
            final snapshot = GrandeurAnalysisTaskSnapshot(
              state: GrandeurAnalysisTaskState.failed,
              progress: 0.85,
              job: job,
              status:
                  'Grandeur report is ready, but the report file could not be loaded.',
            );
            value = snapshot;
            return snapshot;
          }
          await cacheStore?.writeGrandeur(cacheKey, pgn, report,
              styleId: styleId);
          await onReportCacheChanged?.call();
          final snapshot = GrandeurAnalysisTaskSnapshot(
            state: GrandeurAnalysisTaskState.completed,
            progress: 1,
            job: job,
            report: report,
            status:
                'Grandeur analysis ready / ${report.moves.length} move explanations loaded.',
          );
          value = snapshot;
          return snapshot;
        }

        if (job.failed) {
          final snapshot = GrandeurAnalysisTaskSnapshot(
            state: GrandeurAnalysisTaskState.failed,
            progress: 0,
            job: job,
            status:
                'Grandeur report generation failed. Please try again later.',
          );
          value = snapshot;
          return snapshot;
        }

        value = GrandeurAnalysisTaskSnapshot(
          state: poll == 0
              ? GrandeurAnalysisTaskState.queued
              : GrandeurAnalysisTaskState.running,
          progress: _progressForJob(job, poll),
          job: job,
          status:
              'Grandeur report is generating. You can leave this page and reopen the report later.',
        );
        if (pollInterval > Duration.zero) {
          await Future<void>.delayed(pollInterval);
        }
      }

      final snapshot = GrandeurAnalysisTaskSnapshot(
        state: GrandeurAnalysisTaskState.failed,
        progress: value.progress,
        job: job,
        status:
            'Grandeur is taking longer than expected. Your report is saved; reopen it later to continue checking.',
      );
      value = snapshot;
      return snapshot;
    } catch (error) {
      const snapshot = GrandeurAnalysisTaskSnapshot(
        state: GrandeurAnalysisTaskState.failed,
        status: 'Grandeur analysis failed. Please try again.',
      );
      value = snapshot;
      return snapshot;
    }
  }

  Future<GrandeurAnalysisResult?> _loadReport(GrandeurReviewJob job) async {
    final uri = _reportUri(job.commentFile);
    if (uri == null) return null;
    final body = await apiClient.getString(uri);
    if (body == null || body.trim().isEmpty) return null;
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      return GrandeurAnalysisResult.fromJson(
        decoded.cast<String, dynamic>(),
      ).withPreferredLanguage(job.language);
    }
    return null;
  }

  Uri? _reportUri(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null) return null;
    if (parsed.hasScheme) return parsed;
    return apiClient.baseUri.resolveUri(parsed);
  }

  static double _progressForJob(GrandeurReviewJob job, int poll) {
    final progress = job.progress;
    if (progress != null) return progress.clamp(0, 1).toDouble();
    if (job.completed) return 0.85;
    final staged = 0.15 + poll * 0.08;
    return staged.clamp(0.15, 0.78).toDouble();
  }
}

class GrandeurAnalysisTaskCoordinator {
  final Map<String, GrandeurAnalysisTask> _tasks = {};

  GrandeurAnalysisTask startOrAttach({
    required String cacheKey,
    required String pgn,
    required ChessnutApiClient apiClient,
    required GrandeurReviewJob initialJob,
    required String styleId,
    required AppPreferencesAnalysisReportCacheStore? cacheStore,
    required FutureOr<void> Function()? onReportCacheChanged,
    Duration pollInterval = const Duration(seconds: 8),
    int maxPolls = 120,
  }) {
    final existing = _tasks[cacheKey];
    if (existing != null) return existing;
    final task = GrandeurAnalysisTask(
      cacheKey: cacheKey,
      pgn: pgn,
      apiClient: apiClient,
      initialJob: initialJob,
      styleId: styleId,
      cacheStore: cacheStore,
      onReportCacheChanged: onReportCacheChanged,
      pollInterval: pollInterval,
      maxPolls: maxPolls,
    );
    _tasks[cacheKey] = task;
    task.done.whenComplete(() {
      if (identical(_tasks[cacheKey], task)) {
        _tasks.remove(cacheKey);
      }
    });
    return task;
  }
}

final grandeurAnalysisTaskCoordinator = GrandeurAnalysisTaskCoordinator();
