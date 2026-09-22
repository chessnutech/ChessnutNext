import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dartchess/dartchess.dart' as dc;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import '../l10n/app_strings.dart';
import '../l10n/localized_material.dart';

import '../models/app_models.dart';
import '../services/chessnut_api_client.dart';
import '../services/game_record_filter.dart';
import '../services/game_record_repository.dart';
import '../services/lc0_weight_library_service.dart';
import '../services/lichess_pgn_service.dart';
import '../services/model_build_policy.dart';
import '../services/model_build_source_service.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_feedback.dart';
import '../widgets/chess_board.dart';
import '../widgets/chessnut_loading.dart';
import '../widgets/chessnut_motion.dart';

typedef ModelBuildPgnFileLoader = Future<List<String>> Function();
typedef ModelBuildGameRecordPreviewCallback
    = Future<ApiResult<ModelBuildGameRecordJob>> Function(
  GameRecordFilter filter,
  int limit,
);
typedef ModelBuildGameRecordPushCallback
    = Future<ApiResult<ModelBuildGameRecordJob>> Function(
  GameRecordFilter filter,
  String title,
  String remark,
  int limit,
);
typedef ModelBuildGameRecordStatusCallback
    = Future<ApiResult<ModelBuildGameRecordJob>> Function(String jobId);
typedef ModelBuildGameRecordCancelCallback
    = Future<ApiResult<ModelBuildGameRecordJob>> Function(String jobId);
typedef ModelBuildGameRecordSearchCallback
    = Future<GameRecordRemoteSearchResult> Function(
  GameRecordFilter filter,
  int page,
  int count,
);
typedef ModelBuildGameRecordSummaryCallback
    = Future<GameRecordRemoteSearchResult> Function(GameRecordFilter filter);
typedef ModelBuildTrainingAvailabilityCallback = Future<String?> Function();

const int _modelBuildGameRecordPreviewPageSize = 20;

const String _personalEngineTrainingUnavailableMessage =
    'Personal engine training is unavailable. Check Premium, points, or try again later.';
const String _personalEngineTrainingAlreadyRunningMessage =
    'A personal engine training job is already running. Please wait for it to finish before starting a new one.';
const _personalEngineTrainingStartedMessage =
    'Personal engine training started. You can keep using the app while Chessnut trains it.';

String _readablePersonalEngineTrainingMessage(String message) {
  return message
      .replaceAll(
        'Model Build preparation was canceled.',
        'Personal engine training preview was canceled.',
      )
      .replaceAll(
        'Model Build preparation queued.',
        'Personal engine training preview started.',
      )
      .replaceAll(
        'games are ready for Model Build',
        'games are ready for personal engine training',
      )
      .replaceAll(
        'Model Build queued',
        'Personal engine training started',
      )
      .replaceAll(
        'Model Build started',
        'Personal engine training started',
      )
      .replaceAll('Model Build', 'personal engine training')
      .replaceAll('queued from', 'started from')
      .replaceAll('queued.', 'started.')
      .replaceAll('queued', 'pending');
}

class EngineLabScreen extends StatefulWidget {
  const EngineLabScreen({
    required this.onNavigate,
    required this.apiClient,
    this.pgnFileLoader = loadModelBuildPgnFilesFromDesktop,
    this.fileImportAvailable = true,
    this.onCompletedModelsChanged,
    this.onPreviewGameRecordBuild,
    this.onSubmitGameRecordBuild,
    this.onCheckGameRecordBuild,
    this.onCancelGameRecordBuild,
    this.onSummarizeGameRecords,
    this.onSearchGameRecords,
    this.lc0WeightLibraryStore,
    this.unseenCompletedModelIds = const <int>{},
    this.onModelSeen,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final ChessnutApiClient apiClient;
  final ModelBuildPgnFileLoader pgnFileLoader;
  final bool fileImportAvailable;
  final ValueChanged<Set<int>>? onCompletedModelsChanged;
  final ModelBuildGameRecordPreviewCallback? onPreviewGameRecordBuild;
  final ModelBuildGameRecordPushCallback? onSubmitGameRecordBuild;
  final ModelBuildGameRecordStatusCallback? onCheckGameRecordBuild;
  final ModelBuildGameRecordCancelCallback? onCancelGameRecordBuild;
  final ModelBuildGameRecordSummaryCallback? onSummarizeGameRecords;
  final ModelBuildGameRecordSearchCallback? onSearchGameRecords;
  final Lc0WeightLibraryStore? lc0WeightLibraryStore;
  final Set<int> unseenCompletedModelIds;
  final ValueChanged<int>? onModelSeen;

  @override
  State<EngineLabScreen> createState() => _EngineLabScreenState();
}

class _EngineLabScreenState extends State<EngineLabScreen> {
  List<_EngineTrainingJob> jobs = const [];
  List<_CuratedEngine> curatedEngines = const [];
  List<Lc0WeightLibraryEntry> libraryEntries = const [];
  _EngineLabWorkspace workspace = _EngineLabWorkspace.library;
  SubscriptionStatus? subscription;
  bool loading = true;
  bool loadingCurated = true;
  bool loadingLibrary = true;
  final Set<String> updatingLibraryKeys = {};

  Future<bool> _toggleCuratedEngineLike(
    _CuratedEngine engine,
    bool liked,
  ) async {
    if (engine.modelId <= 0) {
      showAppFeedback(
        context,
        'This engine cannot be liked yet.',
        tone: AppFeedbackTone.warning,
      );
      return false;
    }
    final result = liked
        ? await widget.apiClient.starTrain(engine.modelId)
        : await widget.apiClient.unstarTrain(engine.modelId);
    if (result.isSuccess && result.data == true) return true;
    if (!mounted) return false;
    showAppFeedback(
      context,
      result.status.errorMessage ?? 'Unable to update like. Try again later.',
      tone: AppFeedbackTone.error,
    );
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadTrainingData();
    _loadLibraryEntries();
  }

  Future<void> _loadTrainingData() async {
    final listResult = await _loadAllPersonalEngineModels();
    final curatedResult = await widget.apiClient.officialSharedList();
    final statusResult = await widget.apiClient.subStatus();
    if (!mounted) return;
    setState(() {
      if (listResult.isSuccess) {
        final models = listResult.data?.models ?? const <TrainModel>[];
        jobs = models.map(_jobFromTrainModel).toList();
        widget.onCompletedModelsChanged?.call(
          {
            for (final model in models)
              if (model.trainStatus == 2 && model.id > 0) model.id,
          },
        );
      }
      if (statusResult.isSuccess) {
        subscription = statusResult.data;
      }
      if (curatedResult.isSuccess) {
        curatedEngines = (curatedResult.data?.models ?? const <TrainModel>[])
            .map(_curatedEngineFromTrainModel)
            .toList();
      }
      loading = false;
      loadingCurated = false;
    });
  }

  Future<ApiResult<TrainListResult>> _loadAllPersonalEngineModels() async {
    const pageSize = 100;
    const maxPages = 50;
    final models = <TrainModel>[];
    final keys = <String>{};
    var reportedTotal = 0;
    var reportedTotalPage = 0;

    for (var page = 1; page <= maxPages; page++) {
      final result = await widget.apiClient.trainList(
        page: page,
        count: pageSize,
      );
      if (!result.isSuccess) return result;
      final data = result.data ?? const TrainListResult(models: []);
      if (page == 1) {
        reportedTotal = data.total;
        reportedTotalPage = data.totalPage;
      }
      var added = 0;
      for (final model in data.models) {
        if (keys.add(_trainModelListKey(model))) {
          models.add(model);
          added++;
        }
      }
      final totalPage = data.totalPage > 0 ? data.totalPage : reportedTotalPage;
      if (totalPage > 0 && page >= totalPage) break;
      if (data.models.isEmpty) break;
      if (page > 1 && added == 0) break;
    }

    return ApiResult(
      const ApiStatus.success(),
      data: TrainListResult(
        models: models,
        page: 1,
        totalPage: reportedTotalPage,
        total: reportedTotal > 0 ? reportedTotal : models.length,
      ),
    );
  }

  Future<void> _loadLibraryEntries() async {
    final store = widget.lc0WeightLibraryStore;
    if (store == null) {
      if (!mounted) return;
      setState(() {
        libraryEntries = const [Lc0WeightLibraryEntry.defaultWeight];
        loadingLibrary = false;
      });
      return;
    }
    final entries = await store.listAll();
    if (!mounted) return;
    setState(() {
      libraryEntries = entries;
      loadingLibrary = false;
    });
  }

  void _markTrainingJobSeen(_EngineTrainingJob job) {
    if (job.completed && job.modelId > 0) {
      widget.onModelSeen?.call(job.modelId);
    }
  }

  Future<void> _setLibraryEnabled(String key, bool enabled) async {
    final store = widget.lc0WeightLibraryStore;
    if (store == null || key == defaultLc0WeightKey) return;
    setState(() => updatingLibraryKeys.add(key));
    try {
      await store.setEnabled(key, enabled);
      await _loadLibraryEntries();
      if (!mounted) return;
      showAppFeedback(
        context,
        enabled ? 'Engine enabled for Bot game.' : 'Engine disabled.',
        tone: enabled ? AppFeedbackTone.success : AppFeedbackTone.info,
      );
    } catch (_) {
      if (!mounted) return;
      showAppFeedback(
        context,
        'Unable to update this engine. Try again later.',
        tone: AppFeedbackTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => updatingLibraryKeys.remove(key));
      }
    }
  }

  Future<void> _downloadCuratedEngine(_CuratedEngine engine) async {
    final store = widget.lc0WeightLibraryStore;
    final key = lc0WeightKeyForTrainModel(engine.modelId);
    if (store == null || engine.modelId <= 0 || engine.modelPath.isEmpty) {
      showAppFeedback(
        context,
        'This LC0 engine is not ready to download yet.',
        tone: AppFeedbackTone.warning,
      );
      return;
    }
    setState(() => updatingLibraryKeys.add(key));
    try {
      await store.download(
        modelId: engine.modelId,
        title: engine.title,
        modelUrl: engine.modelPath,
      );
      await store.setEnabled(key, true);
      await _loadLibraryEntries();
      if (!mounted) return;
      showAppFeedback(
        context,
        '${engine.title} is ready for Bot game.',
        tone: AppFeedbackTone.success,
      );
    } catch (_) {
      if (!mounted) return;
      showAppFeedback(
        context,
        'Unable to download this LC0 engine. Check your connection and try again.',
        tone: AppFeedbackTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => updatingLibraryKeys.remove(key));
      }
    }
  }

  Future<void> _downloadPersonalEngine(_EngineTrainingJob job) async {
    final store = widget.lc0WeightLibraryStore;
    final key = job.libraryKey;
    if (store == null || key.isEmpty) return;
    if (!job.completed) {
      showAppFeedback(
        context,
        'This personal engine is still training.',
        tone: AppFeedbackTone.info,
      );
      return;
    }
    if (job.modelPath.trim().isEmpty) {
      showAppFeedback(
        context,
        'This personal engine does not have a weight file yet.',
        tone: AppFeedbackTone.warning,
      );
      return;
    }
    setState(() => updatingLibraryKeys.add(key));
    try {
      await store.download(
        modelId: job.modelId,
        title: job.title,
        modelUrl: job.modelPath,
        source: 'Personal engine',
      );
      await store.setEnabled(key, true);
      await _loadLibraryEntries();
      if (!mounted) return;
      showAppFeedback(
        context,
        '${job.title} is ready for Bot game.',
        tone: AppFeedbackTone.success,
      );
    } catch (_) {
      if (!mounted) return;
      showAppFeedback(
        context,
        'Unable to download this personal engine. Check your connection and try again.',
        tone: AppFeedbackTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => updatingLibraryKeys.remove(key));
      }
    }
  }

  Future<void> _setPersonalEngineEnabled(
    _EngineTrainingJob job,
    bool enabled,
  ) async {
    final store = widget.lc0WeightLibraryStore;
    final key = job.libraryKey;
    if (store == null || key.isEmpty) return;
    if (!job.completed) {
      showAppFeedback(
        context,
        'This personal engine is still training.',
        tone: AppFeedbackTone.info,
      );
      return;
    }
    if (job.modelPath.trim().isEmpty) {
      showAppFeedback(
        context,
        'This personal engine does not have a weight file yet.',
        tone: AppFeedbackTone.warning,
      );
      return;
    }
    setState(() => updatingLibraryKeys.add(key));
    try {
      if (!await store.containsKey(key)) {
        await store.download(
          modelId: job.modelId,
          title: job.title,
          modelUrl: job.modelPath,
          source: 'Personal engine',
        );
      }
      await store.setEnabled(key, enabled);
      await _loadLibraryEntries();
      if (!mounted) return;
      showAppFeedback(
        context,
        enabled
            ? '${job.title} is enabled for Bot game.'
            : '${job.title} is disabled.',
        tone: enabled ? AppFeedbackTone.success : AppFeedbackTone.info,
      );
    } catch (_) {
      if (!mounted) return;
      showAppFeedback(
        context,
        'Unable to update this personal engine. Check your connection and try again.',
        tone: AppFeedbackTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => updatingLibraryKeys.remove(key));
      }
    }
  }

  Future<bool> _deletePersonalEngine(_EngineTrainingJob job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => _DeletePersonalEngineDialog(job: job),
    );
    if (confirmed != true || !mounted) return false;
    final key = job.libraryKey;
    setState(() => updatingLibraryKeys.add(key));
    try {
      if (job.localOnly) {
        await widget.lc0WeightLibraryStore?.remove(key);
        await _loadLibraryEntries();
        if (!mounted) return false;
        showAppFeedback(
          context,
          'Personal engine deleted.',
          tone: AppFeedbackTone.success,
        );
        return true;
      }
      final result = await widget.apiClient.trainDel(job.modelId);
      if (!result.isSuccess) {
        if (!mounted) return false;
        showAppFeedback(
          context,
          result.status.errorMessage ??
              'Unable to delete this personal engine. Try again later.',
          tone: AppFeedbackTone.error,
        );
        return false;
      }
      await widget.lc0WeightLibraryStore?.remove(key);
      await _loadLibraryEntries();
      await _loadTrainingData();
      if (!mounted) return false;
      showAppFeedback(
        context,
        'Personal engine deleted.',
        tone: AppFeedbackTone.success,
      );
      return true;
    } catch (_) {
      if (!mounted) return false;
      showAppFeedback(
        context,
        'Unable to delete this personal engine. Try again later.',
        tone: AppFeedbackTone.error,
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => updatingLibraryKeys.remove(key));
      }
    }
  }

  Future<bool> _renamePersonalEngine(
    _EngineTrainingJob job,
    String title,
  ) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      showAppFeedback(
        context,
        'Enter an engine name before saving.',
        tone: AppFeedbackTone.warning,
      );
      return false;
    }
    if (job.modelId <= 0) {
      showAppFeedback(
        context,
        'This personal engine cannot be renamed yet.',
        tone: AppFeedbackTone.warning,
      );
      return false;
    }
    try {
      if (job.localOnly) {
        await widget.lc0WeightLibraryStore?.rename(job.libraryKey, trimmed);
        await _loadLibraryEntries();
        if (!mounted) return true;
        showAppFeedback(
          context,
          'Engine name updated.',
          tone: AppFeedbackTone.success,
        );
        return true;
      }
      final result = await widget.apiClient.trainEdit(
        id: job.modelId,
        title: trimmed,
        remark: job.editRemark,
      );
      if (!result.isSuccess || result.data != true) {
        if (!mounted) return false;
        showAppFeedback(
          context,
          result.status.errorMessage ??
              'Unable to update this engine name. Try again later.',
          tone: AppFeedbackTone.error,
        );
        return false;
      }
      await _loadTrainingData();
      await widget.lc0WeightLibraryStore?.rename(job.libraryKey, trimmed);
      await _loadLibraryEntries();
      if (!mounted) return true;
      showAppFeedback(
        context,
        'Engine name updated.',
        tone: AppFeedbackTone.success,
      );
      return true;
    } catch (_) {
      if (!mounted) return false;
      showAppFeedback(
        context,
        'Unable to update this engine name. Try again later.',
        tone: AppFeedbackTone.error,
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayJobs = _mergeLocalPersonalEngines(jobs, libraryEntries);
    final displayCurated = curatedEngines;
    final headerTitle = switch (workspace) {
      _EngineLabWorkspace.library => 'Engine Lab',
      _EngineLabWorkspace.personal => 'Personal engine',
      _EngineLabWorkspace.market => 'Engine market',
    };
    final headerSubtitle = switch (workspace) {
      _EngineLabWorkspace.library => 'Train engines from your own games',
      _EngineLabWorkspace.personal =>
        'Manage custom LC0 models trained from your own games.',
      _EngineLabWorkspace.market => 'Download Chessnut-provided LC0 engines.',
    };
    return ResponsivePage(
      children: (context, spec) => [
        ScreenHeader(
          title: headerTitle,
          subtitle: headerSubtitle,
          leading: IconButton.filledTonal(
            onPressed: () {
              if (workspace == _EngineLabWorkspace.library) {
                widget.onNavigate('Back');
                return;
              }
              setState(() => workspace = _EngineLabWorkspace.library);
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        SizedBox(height: spec.gutter),
        _EngineLabDashboard(
          spacing: spec.gutter,
          workspace: workspace,
          onWorkspaceChanged: (value) => setState(() => workspace = value),
          library: _PlayableEngineLibrarySection(
            entries: libraryEntries.where((entry) => entry.enabled).toList(),
            loading: loadingLibrary,
            onDisable: (entry) => _setLibraryEnabled(entry.key, false),
            updatingKeys: updatingLibraryKeys,
          ),
          personalWorkspace: _EngineLabPersonalWorkspace(
            trainRecords: _TrainRecordsSection(
              jobs: displayJobs,
              loading: loading,
              libraryEntries: libraryEntries,
              updatingKeys: updatingLibraryKeys,
              onCreate: () => _showModelBuildDialog(context),
              onDownload: _downloadPersonalEngine,
              onOpenReport: (job) => _showTrainingReport(context, job),
              onOpenDetails: (job) => _showTrainingDetails(context, job),
              unseenCompletedModelIds: widget.unseenCompletedModelIds,
              onToggleEnabled: _setPersonalEngineEnabled,
            ),
          ),
          marketWorkspace: _CuratedEngineMarketSection(
            engines: displayCurated,
            loading: loadingCurated,
            libraryEntries: libraryEntries,
            updatingKeys: updatingLibraryKeys,
            onDownload: _downloadCuratedEngine,
            onSetEnabled: _setLibraryEnabled,
            onToggleLike: _toggleCuratedEngineLike,
          ),
          readyCount: libraryEntries.where((entry) => entry.enabled).length,
          personalCount: displayJobs.length,
          marketCount: displayCurated.length,
        ),
      ],
    );
  }

  void _showTrainingDetails(BuildContext context, _EngineTrainingJob job) {
    _markTrainingJobSeen(job);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => _TrainingDetailsDialog(
        job: job,
        onRename: _renamePersonalEngine,
        onOpenReport: (detailsJob) {
          Navigator.of(dialogContext).pop();
          _showTrainingReport(context, detailsJob);
        },
        onDelete: (detailsJob) async {
          final deleted = await _deletePersonalEngine(detailsJob);
          if (deleted && dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
          return deleted;
        },
      ),
    );
  }

  void _showTrainingReport(BuildContext context, _EngineTrainingJob job) {
    _markTrainingJobSeen(job);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => AppDialogShell(
        icon: Icons.analytics_rounded,
        title: 'Engine Report',
        subtitle: job.gameCount > 0
            ? '${job.title} / ${job.gameCount} games'
            : '${job.title} / ${job.sourceLabel}',
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: job.completed
                  ? () async {
                      await _setPersonalEngineEnabled(job, true);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    }
                  : null,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Use this model'),
            ),
          ),
        ],
        child: _TrainingReport(job: job),
      ),
    );
  }

  void _showModelBuildDialog(BuildContext context) {
    final session = widget.apiClient.session;
    final gameRecordPlayerName =
        session is ChessnutLoginSession ? session.username : '';
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (_) => _ModelBuildDialog(
        gameRecordPlayerName: gameRecordPlayerName,
        onOpenGameRecords: () {
          Navigator.of(context).pop();
          widget.onNavigate('Records');
        },
        onPreviewGameRecords: widget.onPreviewGameRecordBuild,
        onSubmitGameRecords: widget.onSubmitGameRecordBuild,
        onCheckGameRecords: widget.onCheckGameRecordBuild,
        onCancelGameRecords: widget.onCancelGameRecordBuild,
        onSummarizeGameRecords: widget.onSummarizeGameRecords,
        onSearchGameRecords: widget.onSearchGameRecords,
        onCheckTrainingAvailability: _checkModelBuildTrainingAvailability,
        onGameRecordBuildCompleted: _loadTrainingData,
        onTrainingStarted: () {
          if (!context.mounted) return;
          showAppFeedback(
            context,
            _personalEngineTrainingStartedMessage,
            tone: AppFeedbackTone.success,
          );
        },
        subscription: subscription,
        fileImportAvailable: widget.fileImportAvailable,
        pgnFileLoader: widget.pgnFileLoader,
        lichessPgnService: LichessPgnService(
          httpClient: widget.apiClient.httpClient,
        ),
        onSubmitPgn: (title, remark, pgn) async {
          final unavailableMessage =
              await _checkModelBuildTrainingAvailability();
          if (unavailableMessage != null) {
            if (!context.mounted) return false;
            showAppFeedback(
              context,
              unavailableMessage,
              tone: AppFeedbackTone.warning,
            );
            return false;
          }

          final result = await widget.apiClient.modelBuildPush(
            pgn: pgn,
            title: title,
            remark: remark,
          );
          if (!context.mounted) return false;
          final model = result.data;
          if (!result.isSuccess || model == null || model.id <= 0) {
            showAppFeedback(
              context,
              result.status.errorMessage ??
                  'Unable to start personal engine training.',
              tone: AppFeedbackTone.error,
            );
            return false;
          }

          await _loadTrainingData();
          return true;
        },
      ),
    );
  }

  Future<String?> _checkModelBuildTrainingAvailability() async {
    final status = await widget.apiClient.modelBuildStatus();
    if (!status.isSuccess) {
      return null;
    }
    if (status.data == true) {
      return null;
    }

    final listResult = await widget.apiClient.trainList(page: 1, count: 100);
    if (listResult.isSuccess &&
        (listResult.data?.models.any((model) => model.trainStatus == 1) ??
            false)) {
      return _personalEngineTrainingAlreadyRunningMessage;
    }
    return status.status.errorMessage ??
        _personalEngineTrainingUnavailableMessage;
  }

  _EngineTrainingJob _jobFromTrainModel(TrainModel model) {
    final metrics = _metricsFromAnalyzeData(model.analyzeData);
    final source = _personalEngineSource(model);
    final gameCount = _personalEngineGameCount(model);
    final styleTags = _personalEngineTags(model);
    final remark = _personalEngineDescription(
      model: model,
      source: source,
      gameCount: gameCount,
      metrics: metrics,
    );
    return _EngineTrainingJob(
      modelId: model.id,
      title: model.title.isEmpty ? 'Personal engine ${model.id}' : model.title,
      remark: remark,
      editRemark: model.remark,
      detailsDescription: _personalEngineDetailDescription(model, remark),
      rawFile: model.rawFile.isEmpty ? 'PGN batch' : model.rawFile,
      modelFile: model.modelPath.isEmpty ? 'pending' : model.modelPath,
      sourceLabel: source,
      gameCount: gameCount,
      styleTags: styleTags,
      status: switch (model.trainStatus) {
        2 => _TrainingStatus.completed,
        1 => _TrainingStatus.training,
        _ => _TrainingStatus.queued,
      },
      progress: _progressFromTrainStatus(model.trainStatus),
      modelAccuracy: metrics.modelAccuracy,
      modelFitting: metrics.modelFitting,
      dataEffectiveness: metrics.dataEffectiveness,
      likes: model.likes,
      modelPath: model.modelPath,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      pgnSamples: model.analyzePgn.isEmpty
          ? const []
          : [
              _ReportPgnSample(
                name: model.sharedName.isEmpty ? model.title : model.sharedName,
                moves: _movesFromPgn(model.analyzePgn.first),
              ),
            ],
    );
  }

  _CuratedEngine _curatedEngineFromTrainModel(TrainModel model) {
    final metrics = _metricsFromAnalyzeData(model.analyzeData);
    return _CuratedEngine(
      title: model.title.isEmpty ? 'LC0 weight ${model.id}' : model.title,
      description: _curatedEngineDescription(model),
      modelPath: model.modelPath,
      modelId: model.id,
      likes: model.likes,
      tags: model.tags.isEmpty ? _personalEngineTags(model) : model.tags,
      modelAccuracy: metrics.modelAccuracy,
      dataEffectiveness: metrics.dataEffectiveness,
      downloaded: false,
    );
  }
}

List<_EngineTrainingJob> _mergeLocalPersonalEngines(
  List<_EngineTrainingJob> serverJobs,
  List<Lc0WeightLibraryEntry> libraryEntries,
) {
  final jobs = [...serverJobs];
  final serverIds = {
    for (final job in serverJobs)
      if (job.modelId > 0) job.modelId,
  };
  for (final entry in libraryEntries) {
    if (!_isDownloadedPersonalEngineEntry(entry)) continue;
    if (serverIds.contains(entry.modelId)) continue;
    jobs.add(_jobFromLocalPersonalEngine(entry));
  }
  return jobs;
}

bool _isDownloadedPersonalEngineEntry(Lc0WeightLibraryEntry entry) {
  return !entry.isDefault &&
      entry.modelId > 0 &&
      entry.key == lc0WeightKeyForTrainModel(entry.modelId) &&
      entry.source.trim().toLowerCase() == 'personal engine';
}

String _trainModelListKey(TrainModel model) {
  if (model.id > 0) return 'id:${model.id}';
  return [
    model.title,
    model.rawFile,
    model.modelPath,
    model.createdAt,
  ].map((value) => value.trim()).join('|');
}

_EngineTrainingJob _jobFromLocalPersonalEngine(Lc0WeightLibraryEntry entry) {
  final title = entry.label.trim().isEmpty
      ? 'Personal engine ${entry.modelId}'
      : entry.label.trim();
  return _EngineTrainingJob(
    modelId: entry.modelId,
    title: title,
    remark: 'Downloaded personal engine',
    editRemark: 'Downloaded personal engine',
    detailsDescription:
        'This personal engine is downloaded locally and ready for Bot game.',
    rawFile: 'Local engine library',
    modelFile: entry.path,
    sourceLabel: 'Local download',
    gameCount: 0,
    styleTags: const ['Downloaded', 'Local'],
    status: _TrainingStatus.completed,
    progress: 1,
    modelAccuracy: 0,
    modelFitting: 0,
    dataEffectiveness: 0,
    likes: 0,
    modelPath: entry.path,
    createdAt: '',
    updatedAt: '',
    pgnSamples: const [],
    localOnly: true,
  );
}

enum _EngineLabWorkspace { library, personal, market }

bool _useEngineLabLandscapeGrid(BuildContext context, double width) {
  final size = MediaQuery.sizeOf(context);
  return size.width > size.height && width >= 560;
}

class _EngineLabDashboard extends StatelessWidget {
  const _EngineLabDashboard({
    required this.spacing,
    required this.workspace,
    required this.onWorkspaceChanged,
    required this.library,
    required this.personalWorkspace,
    required this.marketWorkspace,
    required this.readyCount,
    required this.personalCount,
    required this.marketCount,
  });

  final double spacing;
  final _EngineLabWorkspace workspace;
  final ValueChanged<_EngineLabWorkspace> onWorkspaceChanged;
  final Widget library;
  final Widget personalWorkspace;
  final Widget marketWorkspace;
  final int readyCount;
  final int personalCount;
  final int marketCount;

  @override
  Widget build(BuildContext context) {
    final content = switch (workspace) {
      _EngineLabWorkspace.library => SectionColumn(
          spacing: spacing,
          children: [
            _EngineLabEntryGrid(
              personalCount: personalCount,
              marketCount: marketCount,
              onSelected: onWorkspaceChanged,
            ),
            library,
          ],
        ),
      _EngineLabWorkspace.personal => SectionColumn(
          spacing: spacing,
          children: [
            personalWorkspace,
          ],
        ),
      _EngineLabWorkspace.market => SectionColumn(
          spacing: spacing,
          children: [
            marketWorkspace,
          ],
        ),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: KeyedSubtree(
        key: ValueKey('engine-lab-workspace-${workspace.name}'),
        child: content,
      ),
    );
  }
}

class _EngineLabEntryGrid extends StatelessWidget {
  const _EngineLabEntryGrid({
    required this.personalCount,
    required this.marketCount,
    required this.onSelected,
  });

  final int personalCount;
  final int marketCount;
  final ValueChanged<_EngineLabWorkspace> onSelected;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _EngineLabWorkspaceEntry(
        workspace: _EngineLabWorkspace.personal,
        title: 'Personal engine',
        subtitle: 'Build your own LC0 engines and enable completed models.',
        count: personalCount,
        icon: Icons.person_search_rounded,
        key: const ValueKey('engine-lab-entry-personal'),
      ),
      _EngineLabWorkspaceEntry(
        workspace: _EngineLabWorkspace.market,
        title: 'Engine market',
        subtitle: 'Download Chessnut-provided LC0 engines for Bot game.',
        count: marketCount,
        icon: Icons.storefront_rounded,
        key: const ValueKey('engine-lab-entry-market'),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final landscapeGrid =
            _useEngineLabLandscapeGrid(context, constraints.maxWidth);
        if (constraints.maxWidth < 640 && !landscapeGrid) {
          return Column(
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                _EngineLabEntryCard(
                  entry: cards[index],
                  compact: constraints.maxWidth < 430,
                  onTap: () => onSelected(cards[index].workspace),
                ),
                if (index != cards.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              Expanded(
                child: _EngineLabEntryCard(
                  entry: cards[index],
                  onTap: () => onSelected(cards[index].workspace),
                ),
              ),
              if (index != cards.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _EngineLabWorkspaceEntry {
  const _EngineLabWorkspaceEntry({
    required this.workspace,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.key,
  });

  final _EngineLabWorkspace workspace;
  final String title;
  final String subtitle;
  final int count;
  final IconData icon;
  final Key key;
}

class _ResponsiveCardGrid extends StatelessWidget {
  const _ResponsiveCardGrid({
    required this.children,
    required this.columns,
    this.spacing = 10,
    this.runSpacing = 10,
  });

  final List<Widget> children;
  final int columns;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    if (columns <= 1) {
      return Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1) SizedBox(height: runSpacing),
          ],
        ],
      );
    }

    final rows = <Widget>[];
    for (var index = 0; index < children.length; index += columns) {
      final rowChildren = children.skip(index).take(columns).toList();
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var column = 0; column < columns; column++) ...[
              Expanded(
                child: column < rowChildren.length
                    ? rowChildren[column]
                    : const SizedBox.shrink(),
              ),
              if (column != columns - 1) SizedBox(width: spacing),
            ],
          ],
        ),
      );
      if (index + columns < children.length) {
        rows.add(SizedBox(height: runSpacing));
      }
    }
    return Column(children: rows);
  }
}

class _EngineLabEntryCard extends StatelessWidget {
  const _EngineLabEntryCard({
    required this.entry,
    required this.onTap,
    this.compact = false,
  });

  final _EngineLabWorkspaceEntry entry;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = entry.workspace == _EngineLabWorkspace.personal
        ? scheme.primary
        : scheme.secondary;
    return InkWell(
      key: entry.key,
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.all(compact ? 12 : 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: compact ? 40 : 48,
              height: compact ? 40 : 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(entry.icon, color: color, size: compact ? 22 : 26),
            ),
            SizedBox(width: compact ? 10 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontSize: compact ? 16 : 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _MiniStatusPill(
                        label: entry.count.toString(),
                        color: color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }
}

class _PlayableEngineLibrarySection extends StatefulWidget {
  const _PlayableEngineLibrarySection({
    required this.entries,
    required this.loading,
    required this.onDisable,
    required this.updatingKeys,
  });

  final List<Lc0WeightLibraryEntry> entries;
  final bool loading;
  final ValueChanged<Lc0WeightLibraryEntry> onDisable;
  final Set<String> updatingKeys;

  @override
  State<_PlayableEngineLibrarySection> createState() =>
      _PlayableEngineLibrarySectionState();
}

class _PlayableEngineLibrarySectionState
    extends State<_PlayableEngineLibrarySection> {
  final searchController = TextEditingController();
  String query = '';
  String sourceFilter = 'All';
  int pageIndex = 0;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<String> get _sources {
    final sources = widget.entries.map((entry) => entry.source).toSet().toList()
      ..sort();
    return ['All', ...sources];
  }

  List<Lc0WeightLibraryEntry> _filtered() {
    Iterable<Lc0WeightLibraryEntry> filtered = widget.entries;
    if (sourceFilter != 'All') {
      filtered = filtered.where((entry) => entry.source == sourceFilter);
    }
    final search = query.trim().toLowerCase();
    if (search.isNotEmpty) {
      filtered = filtered.where((entry) {
        return entry.label.toLowerCase().contains(search) ||
            entry.source.toLowerCase().contains(search) ||
            entry.path.toLowerCase().contains(search);
      });
    }
    return filtered.toList(growable: false);
  }

  int _pageSizeFor(BuildContext context, double width) {
    if (_useEngineLabLandscapeGrid(context, width)) return 4;
    if (width < 560) return 5;
    return 6;
  }

  int _columnsFor(BuildContext context, double width) {
    if (_useEngineLabLandscapeGrid(context, width) || width >= 720) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bot game engine library',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Enabled personal and market engines appear in Bot game LC0 choices.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              _MiniStatusPill(
                label: '${widget.entries.length} enabled',
                color: scheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.loading) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 10),
          ],
          _EngineLibraryFilters(
            searchController: searchController,
            query: query,
            sources: _sources,
            selectedSource: sourceFilter,
            onSearchChanged: (value) => setState(() {
              query = value;
              pageIndex = 0;
            }),
            onSourceChanged: (value) => setState(() {
              sourceFilter = value;
              pageIndex = 0;
            }),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final filtered = _filtered();
              final pageSize = _pageSizeFor(context, constraints.maxWidth);
              final columns = _columnsFor(context, constraints.maxWidth);
              final pageCount =
                  math.max(1, (filtered.length / pageSize).ceil());
              final currentPage = math.min(pageIndex, pageCount - 1);
              if (currentPage != pageIndex) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => pageIndex = currentPage);
                });
              }
              final visible = filtered
                  .skip(currentPage * pageSize)
                  .take(pageSize)
                  .toList(growable: false);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (pageCount > 1 || filtered.length != widget.entries.length)
                    _CuratedEnginePager(
                      pageIndex: currentPage,
                      pageCount: pageCount,
                      totalCount: filtered.length,
                      onPrevious: currentPage == 0
                          ? null
                          : () => setState(() => pageIndex = currentPage - 1),
                      onNext: currentPage >= pageCount - 1
                          ? null
                          : () => setState(() => pageIndex = currentPage + 1),
                    ),
                  if (pageCount > 1 || filtered.length != widget.entries.length)
                    const SizedBox(height: 10),
                  if (visible.isEmpty)
                    _EngineLibraryEmptyState(color: scheme.secondary)
                  else
                    _ResponsiveCardGrid(
                      columns: columns,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        for (final entry in visible)
                          _PlayableEngineRow(
                            entry: entry,
                            busy: widget.updatingKeys.contains(entry.key),
                            onDisable: entry.isDefault
                                ? null
                                : () => widget.onDisable(entry),
                          ),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EngineLibraryFilters extends StatelessWidget {
  const _EngineLibraryFilters({
    required this.searchController,
    required this.query,
    required this.sources,
    required this.selectedSource,
    required this.onSearchChanged,
    required this.onSourceChanged,
  });

  final TextEditingController searchController;
  final String query;
  final List<String> sources;
  final String selectedSource;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSourceChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final search = TextField(
          key: const ValueKey('engine-library-search'),
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            isDense: true,
            labelText: 'Search enabled engines',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      searchController.clear();
                      onSearchChanged('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            border: const OutlineInputBorder(),
          ),
        );
        final source = DropdownButtonFormField<String>(
          value: selectedSource,
          isExpanded: true,
          decoration: const InputDecoration(
            isDense: true,
            labelText: 'Source',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final item in sources)
              DropdownMenuItem(value: item, child: Text(item)),
          ],
          onChanged: (value) {
            if (value != null) onSourceChanged(value);
          },
        );
        if (compact) {
          return Column(
            children: [
              search,
              const SizedBox(height: 8),
              source,
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 3, child: search),
            const SizedBox(width: 8),
            Expanded(child: source),
          ],
        );
      },
    );
  }
}

class _PlayableEngineRow extends StatelessWidget {
  const _PlayableEngineRow({
    required this.entry,
    required this.busy,
    required this.onDisable,
  });

  final Lc0WeightLibraryEntry entry;
  final bool busy;
  final VoidCallback? onDisable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = entry.isDefault ? scheme.secondary : scheme.primary;
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: 13,
      tint: color.withValues(alpha: 0.06),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.memory_rounded, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.source} / ${entry.path.split(RegExp(r'[\\/]')).last}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (entry.isDefault)
            _MiniStatusPill(label: 'Built-in', color: scheme.secondary)
          else
            Switch.adaptive(
              value: true,
              onChanged: busy ? null : (_) => onDisable?.call(),
            ),
        ],
      ),
    );
  }
}

class _EngineLibraryEmptyState extends StatelessWidget {
  const _EngineLibraryEmptyState({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      tint: color.withValues(alpha: 0.07),
      child: Row(
        children: [
          Icon(Icons.sports_esports_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No enabled engines match these filters. Enable personal builds or downloaded market engines to use them in Bot game.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatusPill extends StatelessWidget {
  const _MiniStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EngineLabPersonalWorkspace extends StatelessWidget {
  const _EngineLabPersonalWorkspace({
    required this.trainRecords,
  });

  final Widget trainRecords;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('engine-lab-personal-records'),
      child: trainRecords,
    );
  }
}

bool get isDesktopModelBuildFileImportAvailable {
  return switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
}

Future<List<String>> loadModelBuildPgnFilesFromDesktop() async {
  const pgnGroup = XTypeGroup(
    label: 'PGN',
    extensions: ['pgn', 'txt'],
    mimeTypes: ['application/x-chess-pgn', 'text/plain'],
  );
  final files = await openFiles(acceptedTypeGroups: const [pgnGroup]);
  final contents = <String>[];
  for (final file in files) {
    contents.add(await file.readAsString());
  }
  return contents;
}

enum _TrainingStatus { completed, training, queued }

class _EngineTrainingJob {
  const _EngineTrainingJob({
    required this.modelId,
    required this.title,
    required this.remark,
    required this.editRemark,
    required this.detailsDescription,
    required this.rawFile,
    required this.modelFile,
    required this.sourceLabel,
    required this.gameCount,
    required this.styleTags,
    required this.status,
    required this.progress,
    required this.modelAccuracy,
    required this.modelFitting,
    required this.dataEffectiveness,
    required this.likes,
    required this.modelPath,
    required this.createdAt,
    required this.updatedAt,
    required this.pgnSamples,
    this.localOnly = false,
  });

  final int modelId;
  final String title;
  final String remark;
  final String editRemark;
  final String detailsDescription;
  final String rawFile;
  final String modelFile;
  final String sourceLabel;
  final int gameCount;
  final List<String> styleTags;
  final _TrainingStatus status;
  final double progress;
  final double modelAccuracy;
  final double modelFitting;
  final double dataEffectiveness;
  final int likes;
  final String modelPath;
  final String createdAt;
  final String updatedAt;
  final List<_ReportPgnSample> pgnSamples;
  final bool localOnly;

  bool get completed => status == _TrainingStatus.completed;
  String get libraryKey =>
      modelId > 0 ? lc0WeightKeyForTrainModel(modelId) : '';

  String get statusLabel {
    return switch (status) {
      _TrainingStatus.completed => 'Completed',
      _TrainingStatus.training => 'Building',
      _TrainingStatus.queued => 'Pending',
    };
  }
}

class _ReportPgnSample {
  const _ReportPgnSample({
    required this.name,
    required this.moves,
  });

  final String name;
  final List<String> moves;
}

class _CuratedEngine {
  const _CuratedEngine({
    required this.modelId,
    required this.title,
    required this.description,
    required this.modelPath,
    required this.likes,
    required this.tags,
    required this.modelAccuracy,
    required this.dataEffectiveness,
    required this.downloaded,
  });

  final int modelId;
  final String title;
  final String description;
  final String modelPath;
  final int likes;
  final List<String> tags;
  final double modelAccuracy;
  final double dataEffectiveness;
  final bool downloaded;

  String get fileName => modelPath.split(RegExp(r'[\\/]')).last;
}

class _CuratedEngineMarketSection extends StatefulWidget {
  const _CuratedEngineMarketSection({
    required this.engines,
    required this.loading,
    required this.libraryEntries,
    required this.updatingKeys,
    required this.onDownload,
    required this.onSetEnabled,
    required this.onToggleLike,
  });

  final List<_CuratedEngine> engines;
  final bool loading;
  final List<Lc0WeightLibraryEntry> libraryEntries;
  final Set<String> updatingKeys;
  final ValueChanged<_CuratedEngine> onDownload;
  final void Function(String key, bool enabled) onSetEnabled;
  final Future<bool> Function(_CuratedEngine engine, bool liked) onToggleLike;

  @override
  State<_CuratedEngineMarketSection> createState() =>
      _CuratedEngineMarketSectionState();
}

class _CuratedEngineMarketSectionState
    extends State<_CuratedEngineMarketSection> {
  final searchController = TextEditingController();
  final Map<int, int> likeOverrides = {};
  final Set<int> likedEngineIds = {};
  final Set<int> likingEngineIds = {};
  String searchQuery = '';
  int pageIndex = 0;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CuratedEngineMarketSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.engines, widget.engines)) {
      pageIndex = 0;
    }
  }

  List<_CuratedEngine> _filteredEngines() {
    Iterable<_CuratedEngine> filtered = widget.engines;
    final query = searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((engine) {
        return engine.title.toLowerCase().contains(query) ||
            engine.description.toLowerCase().contains(query) ||
            engine.tags.any((tag) => tag.toLowerCase().contains(query));
      });
    }
    return filtered.toList();
  }

  int _pageSizeFor(double width, bool compactLandscape) {
    if (compactLandscape) return 4;
    if (width < 560) return 5;
    if (width >= 720) return 4;
    return 5;
  }

  int _columnsFor(double width, bool compactLandscape) {
    if (compactLandscape || width >= 720) return 2;
    return 1;
  }

  void _setSearchQuery(String value) {
    setState(() {
      searchQuery = value;
      pageIndex = 0;
    });
  }

  int _likesFor(_CuratedEngine engine) {
    return likeOverrides[engine.modelId] ?? engine.likes;
  }

  Future<void> _toggleLike(_CuratedEngine engine) async {
    final modelId = engine.modelId;
    if (modelId <= 0 || likingEngineIds.contains(modelId)) return;
    final wasLiked = likedEngineIds.contains(modelId);
    final nextLiked = !wasLiked;
    final previousLikes = _likesFor(engine);
    final nextLikes = math.max(0, previousLikes + (nextLiked ? 1 : -1)).toInt();
    setState(() {
      likingEngineIds.add(modelId);
      likeOverrides[modelId] = nextLikes;
      if (nextLiked) {
        likedEngineIds.add(modelId);
      } else {
        likedEngineIds.remove(modelId);
      }
    });
    final ok = await widget.onToggleLike(engine, nextLiked);
    if (!mounted) return;
    setState(() {
      likingEngineIds.remove(modelId);
      if (!ok) {
        likeOverrides[modelId] = previousLikes;
        if (wasLiked) {
          likedEngineIds.add(modelId);
        } else {
          likedEngineIds.remove(modelId);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Curated LC0 engines',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Popular LC0 community weights selected and provided by Chessnut. Download and enable the engines you want in Bot game.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(label: 'Provided by Chessnut', color: scheme.primary),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.loading) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 10),
          ],
          if (widget.engines.isEmpty)
            _CuratedEngineEmptyState(color: scheme.secondary)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final compactLandscape = isCompactLandscapeDevice(context);
                final filtered = _filteredEngines();
                final pageSize =
                    _pageSizeFor(constraints.maxWidth, compactLandscape);
                final pageCount =
                    math.max(1, (filtered.length / pageSize).ceil());
                final currentPage = math.min(pageIndex, pageCount - 1);
                if (currentPage != pageIndex) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => pageIndex = currentPage);
                  });
                }
                final start = currentPage * pageSize;
                final visible =
                    filtered.skip(start).take(pageSize).toList(growable: false);
                final columns =
                    _columnsFor(constraints.maxWidth, compactLandscape);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CuratedEngineMarketSearch(
                      totalCount: widget.engines.length,
                      filteredCount: filtered.length,
                      searchController: searchController,
                      onSearchChanged: _setSearchQuery,
                    ),
                    const SizedBox(height: 10),
                    if (pageCount > 1 ||
                        filtered.length != widget.engines.length) ...[
                      _CuratedEnginePager(
                        pageIndex: currentPage,
                        pageCount: pageCount,
                        totalCount: filtered.length,
                        onPrevious: currentPage == 0
                            ? null
                            : () => setState(() => pageIndex = currentPage - 1),
                        onNext: currentPage >= pageCount - 1
                            ? null
                            : () => setState(() => pageIndex = currentPage + 1),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (visible.isEmpty)
                      _CuratedEngineEmptyState(color: scheme.secondary)
                    else
                      _CuratedEngineGrid(
                        engines: visible,
                        columns: columns,
                        compact: compactLandscape,
                        libraryEntries: widget.libraryEntries,
                        updatingKeys: widget.updatingKeys,
                        likesFor: _likesFor,
                        likedIds: likedEngineIds,
                        likingIds: likingEngineIds,
                        onDownload: widget.onDownload,
                        onSetEnabled: widget.onSetEnabled,
                        onToggleLike: _toggleLike,
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _CuratedEngineMarketSearch extends StatelessWidget {
  const _CuratedEngineMarketSearch({
    required this.totalCount,
    required this.filteredCount,
    required this.searchController,
    required this.onSearchChanged,
  });

  final int totalCount;
  final int filteredCount;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('curated-engine-search'),
            controller: searchController,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              labelText: 'Search engines',
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$filteredCount / $totalCount',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ],
    );
  }
}

class _CuratedEngineFilterChip extends StatelessWidget {
  const _CuratedEngineFilterChip({
    required this.filterKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key filterKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: filterKey,
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.15)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.55)
                : scheme.outlineVariant.withValues(alpha: 0.38),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _CuratedEngineGrid extends StatelessWidget {
  const _CuratedEngineGrid({
    required this.engines,
    required this.columns,
    required this.compact,
    required this.libraryEntries,
    required this.updatingKeys,
    required this.likesFor,
    required this.likedIds,
    required this.likingIds,
    required this.onDownload,
    required this.onSetEnabled,
    required this.onToggleLike,
  });

  final List<_CuratedEngine> engines;
  final int columns;
  final bool compact;
  final List<Lc0WeightLibraryEntry> libraryEntries;
  final Set<String> updatingKeys;
  final int Function(_CuratedEngine engine) likesFor;
  final Set<int> likedIds;
  final Set<int> likingIds;
  final ValueChanged<_CuratedEngine> onDownload;
  final void Function(String key, bool enabled) onSetEnabled;
  final ValueChanged<_CuratedEngine> onToggleLike;

  bool _downloaded(_CuratedEngine engine) {
    final key = lc0WeightKeyForTrainModel(engine.modelId);
    return engine.downloaded || libraryEntries.any((entry) => entry.key == key);
  }

  bool _enabled(_CuratedEngine engine) {
    final key = lc0WeightKeyForTrainModel(engine.modelId);
    return libraryEntries.any((entry) => entry.key == key && entry.enabled);
  }

  @override
  Widget build(BuildContext context) {
    if (columns <= 1) {
      return Column(
        children: [
          for (var index = 0; index < engines.length; index++) ...[
            _CuratedEngineCard(
              engine: engines[index],
              compact: compact,
              downloaded: _downloaded(engines[index]),
              enabled: _enabled(engines[index]),
              likes: likesFor(engines[index]),
              liked: likedIds.contains(engines[index].modelId),
              busy: updatingKeys.contains(
                lc0WeightKeyForTrainModel(engines[index].modelId),
              ),
              likeBusy: likingIds.contains(engines[index].modelId),
              onDownload: () => onDownload(engines[index]),
              onSetEnabled: (enabled) => onSetEnabled(
                lc0WeightKeyForTrainModel(engines[index].modelId),
                enabled,
              ),
              onToggleLike: () => onToggleLike(engines[index]),
            ),
            if (index != engines.length - 1) const SizedBox(height: 10),
          ],
        ],
      );
    }

    final rows = <Widget>[];
    for (var index = 0; index < engines.length; index += columns) {
      final rowEngines = engines.skip(index).take(columns).toList();
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var column = 0; column < columns; column++) ...[
              Expanded(
                child: column < rowEngines.length
                    ? _CuratedEngineCard(
                        engine: rowEngines[column],
                        compact: compact,
                        downloaded: _downloaded(rowEngines[column]),
                        enabled: _enabled(rowEngines[column]),
                        likes: likesFor(rowEngines[column]),
                        liked: likedIds.contains(rowEngines[column].modelId),
                        busy: updatingKeys.contains(
                          lc0WeightKeyForTrainModel(
                            rowEngines[column].modelId,
                          ),
                        ),
                        likeBusy:
                            likingIds.contains(rowEngines[column].modelId),
                        onDownload: () => onDownload(rowEngines[column]),
                        onSetEnabled: (enabled) => onSetEnabled(
                          lc0WeightKeyForTrainModel(
                            rowEngines[column].modelId,
                          ),
                          enabled,
                        ),
                        onToggleLike: () => onToggleLike(rowEngines[column]),
                      )
                    : const SizedBox.shrink(),
              ),
              if (column != columns - 1) const SizedBox(width: 10),
            ],
          ],
        ),
      );
      if (index + columns < engines.length) {
        rows.add(const SizedBox(height: 10));
      }
    }
    return Column(children: rows);
  }
}

class _CuratedEnginePager extends StatelessWidget {
  const _CuratedEnginePager({
    required this.pageIndex,
    required this.pageCount,
    required this.totalCount,
    required this.onPrevious,
    required this.onNext,
  });

  final int pageIndex;
  final int pageCount;
  final int totalCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Previous page',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Page ${pageIndex + 1} / $pageCount',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          '$totalCount engines',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Next page',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _CuratedEngineEmptyState extends StatelessWidget {
  const _CuratedEngineEmptyState({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      tint: color.withValues(alpha: 0.07),
      child: Row(
        children: [
          Icon(Icons.storefront_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No curated LC0 engines are available right now. Pull to refresh later.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _CuratedEngineLikeButton extends StatelessWidget {
  const _CuratedEngineLikeButton({
    required this.likes,
    required this.liked,
    required this.busy,
    required this.compact,
    required this.onPressed,
    super.key,
  });

  final int likes;
  final bool liked;
  final bool busy;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = liked ? scheme.primary : scheme.onSurfaceVariant;
    return Tooltip(
      message: liked ? 'Unlike this engine' : 'Like this engine',
      child: Material(
        color: (liked ? scheme.primary : scheme.surfaceContainerHighest)
            .withValues(alpha: liked ? 0.14 : 0.62),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: busy ? null : onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 9,
              vertical: compact ? 6 : 7,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  SizedBox.square(
                    dimension: compact ? 14 : 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                else
                  Icon(
                    liked
                        ? Icons.thumb_up_alt_rounded
                        : Icons.thumb_up_off_alt_rounded,
                    size: compact ? 15 : 17,
                    color: color,
                  ),
                const SizedBox(width: 5),
                Text(
                  likes.toString(),
                  style: TextStyle(
                    color: color,
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CuratedEngineCard extends StatelessWidget {
  const _CuratedEngineCard({
    required this.engine,
    required this.compact,
    required this.downloaded,
    required this.enabled,
    required this.likes,
    required this.liked,
    required this.busy,
    required this.likeBusy,
    required this.onDownload,
    required this.onSetEnabled,
    required this.onToggleLike,
  });

  final _CuratedEngine engine;
  final bool compact;
  final bool downloaded;
  final bool enabled;
  final int likes;
  final bool liked;
  final bool busy;
  final bool likeBusy;
  final VoidCallback onDownload;
  final ValueChanged<bool> onSetEnabled;
  final VoidCallback onToggleLike;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = this.compact;
    final tags = engine.tags.isEmpty
        ? const ['Community LC0', 'Bot game']
        : engine.tags.take(compact ? 2 : 4).toList();
    return GlassPanel(
      padding: EdgeInsets.all(compact ? 10 : 12),
      borderRadius: 14,
      tint: scheme.primary.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 34 : 42,
                height: compact ? 34 : 42,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(compact ? 10 : 12),
                ),
                child: Icon(
                  Icons.hub_rounded,
                  color: scheme.primary,
                  size: compact ? 19 : 24,
                ),
              ),
              SizedBox(width: compact ? 8 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      engine.title,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 14 : 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: compact ? 2 : 3),
                    Text(
                      engine.description,
                      maxLines: compact ? 1 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 6 : 8),
              _CuratedEngineLikeButton(
                key: ValueKey('curated-engine-like-${engine.modelId}'),
                likes: likes,
                liked: liked,
                busy: likeBusy,
                compact: compact,
                onPressed: onToggleLike,
              ),
            ],
          ),
          SizedBox(height: compact ? 7 : 10),
          Wrap(
            spacing: compact ? 6 : 8,
            runSpacing: compact ? 6 : 8,
            children: [
              for (final tag in tags)
                _MetaChip(icon: Icons.sell_rounded, label: tag),
              _MetaChip(
                icon: Icons.inventory_2_rounded,
                label: downloaded ? 'Ready in Bot game' : 'LC0 weight ready',
              ),
            ],
          ),
          SizedBox(height: compact ? 7 : 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _WrapSafeFilledButton(
                onPressed: downloaded || busy ? null : onDownload,
                busy: busy && !downloaded,
                icon: downloaded
                    ? Icons.check_circle_rounded
                    : Icons.download_rounded,
                label: downloaded
                    ? 'Downloaded'
                    : busy
                        ? 'Downloading'
                        : 'Download',
              ),
              if (downloaded)
                _EngineEnableSwitch(
                  value: enabled,
                  busy: busy,
                  onChanged: onSetEnabled,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _PersonalEngineFilter { all, completed, enabled, building }

class _TrainRecordsSection extends StatefulWidget {
  const _TrainRecordsSection({
    required this.jobs,
    required this.loading,
    required this.libraryEntries,
    required this.updatingKeys,
    required this.onCreate,
    required this.onDownload,
    required this.onOpenReport,
    required this.onOpenDetails,
    required this.unseenCompletedModelIds,
    required this.onToggleEnabled,
  });

  final List<_EngineTrainingJob> jobs;
  final bool loading;
  final List<Lc0WeightLibraryEntry> libraryEntries;
  final Set<String> updatingKeys;
  final VoidCallback onCreate;
  final ValueChanged<_EngineTrainingJob> onDownload;
  final ValueChanged<_EngineTrainingJob> onOpenReport;
  final ValueChanged<_EngineTrainingJob> onOpenDetails;
  final Set<int> unseenCompletedModelIds;
  final void Function(_EngineTrainingJob job, bool enabled) onToggleEnabled;

  @override
  State<_TrainRecordsSection> createState() => _TrainRecordsSectionState();
}

class _TrainRecordsSectionState extends State<_TrainRecordsSection> {
  final searchController = TextEditingController();
  String query = '';
  _PersonalEngineFilter filter = _PersonalEngineFilter.all;
  int pageIndex = 0;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  bool _enabled(_EngineTrainingJob job) {
    return widget.libraryEntries.any(
      (entry) => entry.key == job.libraryKey && entry.enabled,
    );
  }

  bool _downloaded(_EngineTrainingJob job) {
    return widget.libraryEntries.any((entry) => entry.key == job.libraryKey);
  }

  List<_EngineTrainingJob> _filteredJobs() {
    Iterable<_EngineTrainingJob> filtered = widget.jobs;
    switch (filter) {
      case _PersonalEngineFilter.all:
        break;
      case _PersonalEngineFilter.completed:
        filtered = filtered.where((job) => job.completed);
      case _PersonalEngineFilter.enabled:
        filtered = filtered.where(_enabled);
      case _PersonalEngineFilter.building:
        filtered = filtered.where((job) => !job.completed);
    }
    final search = query.trim().toLowerCase();
    if (search.isNotEmpty) {
      filtered = filtered.where((job) {
        return job.title.toLowerCase().contains(search) ||
            job.remark.toLowerCase().contains(search) ||
            job.sourceLabel.toLowerCase().contains(search) ||
            job.styleTags.any((tag) => tag.toLowerCase().contains(search));
      });
    }
    return filtered.toList(growable: false);
  }

  int _pageSizeFor(BuildContext context, double width) {
    if (_useEngineLabLandscapeGrid(context, width)) return 4;
    if (width < 560) return 5;
    return 4;
  }

  int _columnsFor(BuildContext context, double width) {
    if (_useEngineLabLandscapeGrid(context, width) || width >= 720) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Personal engines',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              FilledButton.icon(
                onPressed: widget.onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('New personal engine'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.loading) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 10),
          ],
          _PersonalEngineFilters(
            selected: filter,
            searchController: searchController,
            query: query,
            onFilterChanged: (value) => setState(() {
              filter = value;
              pageIndex = 0;
            }),
            onSearchChanged: (value) => setState(() {
              query = value;
              pageIndex = 0;
            }),
          ),
          const SizedBox(height: 10),
          if (!widget.loading && widget.jobs.isEmpty) ...[
            const _ModelBuildsEmptyState(),
          ] else
            LayoutBuilder(
              builder: (context, constraints) {
                final filtered = _filteredJobs();
                final pageSize = _pageSizeFor(context, constraints.maxWidth);
                final columns = _columnsFor(context, constraints.maxWidth);
                final compactCards =
                    _useEngineLabLandscapeGrid(context, constraints.maxWidth);
                final pageCount =
                    math.max(1, (filtered.length / pageSize).ceil());
                final currentPage = math.min(pageIndex, pageCount - 1);
                if (currentPage != pageIndex) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => pageIndex = currentPage);
                  });
                }
                final visible = filtered
                    .skip(currentPage * pageSize)
                    .take(pageSize)
                    .toList(growable: false);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (pageCount > 1 ||
                        filtered.length != widget.jobs.length) ...[
                      _CuratedEnginePager(
                        pageIndex: currentPage,
                        pageCount: pageCount,
                        totalCount: filtered.length,
                        onPrevious: currentPage == 0
                            ? null
                            : () => setState(() => pageIndex = currentPage - 1),
                        onNext: currentPage >= pageCount - 1
                            ? null
                            : () => setState(() => pageIndex = currentPage + 1),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (visible.isEmpty)
                      _EngineLibraryEmptyState(
                        color: Theme.of(context).colorScheme.secondary,
                      )
                    else
                      _ResponsiveCardGrid(
                        columns: columns,
                        children: [
                          for (var index = 0; index < visible.length; index++)
                            ChessnutFadeSlide(
                              delay: Duration(milliseconds: 32 * index),
                              child: _TrainingRecordCard(
                                job: visible[index],
                                compact: compactCards,
                                unseen: widget.unseenCompletedModelIds
                                    .contains(visible[index].modelId),
                                downloaded: _downloaded(visible[index]),
                                enabled: _enabled(visible[index]),
                                updating: widget.updatingKeys.contains(
                                  visible[index].libraryKey,
                                ),
                                onDownload: () =>
                                    widget.onDownload(visible[index]),
                                onOpenReport: widget.onOpenReport,
                                onOpenDetails: widget.onOpenDetails,
                                onToggleEnabled: (enabled) =>
                                    widget.onToggleEnabled(
                                  visible[index],
                                  enabled,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _PersonalEngineFilters extends StatelessWidget {
  const _PersonalEngineFilters({
    required this.selected,
    required this.searchController,
    required this.query,
    required this.onFilterChanged,
    required this.onSearchChanged,
  });

  final _PersonalEngineFilter selected;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<_PersonalEngineFilter> onFilterChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('personal-engine-search'),
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            isDense: true,
            labelText: 'Search personal engines',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      searchController.clear();
                      onSearchChanged('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _CuratedEngineFilterChip(
              filterKey: const ValueKey('personal-filter-all'),
              label: 'All',
              selected: selected == _PersonalEngineFilter.all,
              onTap: () => onFilterChanged(_PersonalEngineFilter.all),
            ),
            _CuratedEngineFilterChip(
              filterKey: const ValueKey('personal-filter-completed'),
              label: 'Completed',
              selected: selected == _PersonalEngineFilter.completed,
              onTap: () => onFilterChanged(_PersonalEngineFilter.completed),
            ),
            _CuratedEngineFilterChip(
              filterKey: const ValueKey('personal-filter-enabled'),
              label: 'Enabled',
              selected: selected == _PersonalEngineFilter.enabled,
              onTap: () => onFilterChanged(_PersonalEngineFilter.enabled),
            ),
            _CuratedEngineFilterChip(
              filterKey: const ValueKey('personal-filter-building'),
              label: 'Building',
              selected: selected == _PersonalEngineFilter.building,
              onTap: () => onFilterChanged(_PersonalEngineFilter.building),
            ),
          ],
        ),
      ],
    );
  }
}

double _progressFromTrainStatus(int trainStatus) {
  return switch (trainStatus) {
    2 => 1,
    _ => 0,
  };
}

class _ModelBuildsEmptyState extends StatelessWidget {
  const _ModelBuildsEmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      tint: scheme.secondary.withValues(alpha: 0.07),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scheme.secondary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.cloud_queue_rounded, color: scheme.secondary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No personal engines yet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start training from Game Record, Lichess, or PGN files. Your real cloud jobs will appear here after they are created.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingRecordCard extends StatelessWidget {
  const _TrainingRecordCard({
    required this.job,
    this.compact = false,
    required this.unseen,
    required this.downloaded,
    required this.enabled,
    required this.updating,
    required this.onDownload,
    required this.onOpenReport,
    required this.onOpenDetails,
    required this.onToggleEnabled,
  });

  final _EngineTrainingJob job;
  final bool compact;
  final bool unseen;
  final bool downloaded;
  final bool enabled;
  final bool updating;
  final VoidCallback onDownload;
  final ValueChanged<_EngineTrainingJob> onOpenReport;
  final ValueChanged<_EngineTrainingJob> onOpenDetails;
  final ValueChanged<bool> onToggleEnabled;

  @override
  Widget build(BuildContext context) {
    final color = switch (job.status) {
      _TrainingStatus.completed => Theme.of(context).colorScheme.primary,
      _TrainingStatus.training => Theme.of(context).colorScheme.secondary,
      _TrainingStatus.queued => const Color(0xFFF59E0B),
    };
    final card = GlassPanel(
      padding: EdgeInsets.all(compact ? 10 : 12),
      borderRadius: 14,
      tint: color.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 14 : 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: compact ? 2 : 3),
                  Text(
                    job.remark,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
              final icon = Container(
                width: compact ? 34 : 42,
                height: compact ? 34 : 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(compact ? 10 : 12),
                ),
                child: Icon(
                  Icons.developer_board_rounded,
                  color: color,
                  size: compact ? 19 : 24,
                ),
              );
              final status = _StatusPill(label: job.statusLabel, color: color);
              if (constraints.maxWidth < 430) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        icon,
                        const SizedBox(width: 10),
                        if (unseen) ...[
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: _NewEngineDot(),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(child: status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    titleBlock,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  icon,
                  const SizedBox(width: 10),
                  Expanded(child: titleBlock),
                  const SizedBox(width: 8),
                  if (unseen) ...[
                    const _NewEngineDot(),
                    const SizedBox(width: 8),
                  ],
                  status,
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          ChessnutEngineTrainingProgress(
            value: job.progress,
            color: color,
            active: job.status == _TrainingStatus.training,
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.sports_esports_rounded,
                label: job.gameCount > 0
                    ? 'Trained from ${job.gameCount} games'
                    : 'Training games ready',
              ),
              _MetaChip(
                  icon: Icons.person_search_rounded, label: job.sourceLabel),
              for (final tag in job.styleTags.take(3))
                _MetaChip(icon: Icons.sell_rounded, label: tag),
              if (job.completed)
                _MetaChip(
                  icon: downloaded
                      ? Icons.inventory_2_rounded
                      : Icons.cloud_download_rounded,
                  label: downloaded ? 'Downloaded' : 'Download to use',
                ),
              if (job.completed && downloaded)
                _MetaChip(
                  icon: enabled
                      ? Icons.toggle_on_rounded
                      : Icons.toggle_off_rounded,
                  label: enabled ? 'Enabled for Bot game' : 'Disabled',
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (job.completed) ...[
            if (!compact) ...[
              _InlineEngineReportSummary(
                job: job,
                onOpenReport: () => onOpenReport(job),
              ),
              const SizedBox(height: 10),
            ],
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _WrapSafeFilledButton(
                onPressed: job.completed ? () => onOpenReport(job) : null,
                icon: job.completed
                    ? Icons.analytics_rounded
                    : Icons.hourglass_top_rounded,
                label: job.completed ? 'Open report' : 'Building',
              ),
              if (job.completed)
                _WrapSafeFilledButton(
                  onPressed: downloaded || updating ? null : onDownload,
                  busy: updating && !downloaded,
                  icon: downloaded
                      ? Icons.check_circle_rounded
                      : Icons.download_rounded,
                  label: downloaded
                      ? 'Downloaded'
                      : updating
                          ? 'Downloading'
                          : 'Download',
                ),
              _WrapSafeOutlinedButton(
                onPressed: () => onOpenDetails(job),
                icon: Icons.info_outline_rounded,
                label: 'Details',
              ),
              if (job.completed && downloaded)
                _EngineEnableSwitch(
                  value: enabled,
                  busy: updating,
                  onChanged: onToggleEnabled,
                ),
            ],
          ),
        ],
      ),
    );
    return ChessnutAttentionBorder(
      active: job.completed,
      color: color,
      borderRadius: 14,
      child: card,
    );
  }
}

class _NewEngineDot extends StatelessWidget {
  const _NewEngineDot();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'New personal engine',
      child: Container(
        key: const ValueKey('new-personal-engine-dot'),
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.surface,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _InlineEngineReportSummary extends StatelessWidget {
  const _InlineEngineReportSummary({
    required this.job,
    required this.onOpenReport,
  });

  final _EngineTrainingJob job;
  final VoidCallback onOpenReport;

  @override
  Widget build(BuildContext context) {
    final color = _qualityColor(context, job.modelAccuracy);
    return GlassPanel(
      padding: const EdgeInsets.all(11),
      borderRadius: 13,
      tint: color.withValues(alpha: 0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_rounded,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Engine report',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed: onOpenReport,
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
                label: const Text('Open'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ScoreDial(
            label: 'Model Accuracy',
            value: job.modelAccuracy,
            color: color,
          ),
        ],
      ),
    );
  }
}

class _WrapSafeFilledButton extends StatelessWidget {
  const _WrapSafeFilledButton({
    required this.label,
    required this.icon,
    this.onPressed,
    this.busy = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.visible,
        textAlign: TextAlign.center,
      ),
      style: FilledButton.styleFrom(
        minimumSize: const Size(128, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}

class _WrapSafeOutlinedButton extends StatelessWidget {
  const _WrapSafeOutlinedButton({
    required this.label,
    required this.icon,
    this.onPressed,
    this.busy = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.visible,
        textAlign: TextAlign.center,
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(128, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}

class _EngineEnableSwitch extends StatelessWidget {
  const _EngineEnableSwitch({
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = value ? scheme.primary : scheme.onSurfaceVariant;
    final switchFill = value
        ? scheme.primary.withValues(alpha: 0.22)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.7);
    final knobFill = value ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      toggled: value,
      enabled: !busy,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: busy ? null : () => onChanged(!value),
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          borderRadius: 12,
          tint:
              (value ? scheme.primary : scheme.outline).withValues(alpha: 0.07),
          child: SizedBox(
            height: 30,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value ? 'Enabled' : 'Disabled',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 10),
                if (busy)
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  )
                else
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    width: 44,
                    height: 26,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: switchFill,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment:
                        value ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: knobFill,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _ModelBuildSource { gameRecords, lichess, pgnFiles }

class _LichessModelBuildOptions {
  const _LichessModelBuildOptions({
    required this.fetchOptions,
    required this.maxGames,
  });

  final LichessPgnFetchOptions fetchOptions;
  final int maxGames;
}

class _LichessPgnPreviewSnapshot {
  const _LichessPgnPreviewSnapshot({
    required this.pgnPages,
    required this.nextUntilCursor,
    required this.hasMore,
  });

  final List<String> pgnPages;
  final int? nextUntilCursor;
  final bool hasMore;

  String get pgn => mergeModelBuildPgnFiles(pgnPages);

  int get gameCount => countModelBuildPgnGames(pgn);
}

_LichessPgnPreviewSnapshot _lichessSnapshotFromPage(
  LichessPgnPage page, {
  required int maxGames,
  required List<String> existingPages,
}) {
  final existingCount = countModelBuildPgnGames(
    mergeModelBuildPgnFiles(existingPages),
  );
  final remaining = math.max(0, maxGames - existingCount);
  final pages = List<String>.from(existingPages);
  if (remaining > 0) {
    final pageGames = splitPgnGames(page.pgn, limit: remaining);
    for (var index = 0;
        index < pageGames.length;
        index += _modelBuildGameRecordPreviewPageSize) {
      final pagePgn = mergeModelBuildPgnFiles(
        pageGames
            .skip(index)
            .take(_modelBuildGameRecordPreviewPageSize)
            .toList(growable: false),
      );
      if (pagePgn.trim().isNotEmpty) {
        pages.add(pagePgn);
      }
    }
  }
  final gameCount = countModelBuildPgnGames(mergeModelBuildPgnFiles(pages));
  return _LichessPgnPreviewSnapshot(
    pgnPages: pages,
    nextUntilCursor: page.nextUntil,
    hasMore: page.hasMore && page.nextUntil != null && gameCount < maxGames,
  );
}

String _lichessSourceLabel(String playerId) {
  return 'Lichess ${playerId.trim()}';
}

class _ModelBuildDialog extends StatefulWidget {
  const _ModelBuildDialog({
    required this.gameRecordPlayerName,
    required this.onOpenGameRecords,
    required this.lichessPgnService,
    required this.onSubmitPgn,
    required this.fileImportAvailable,
    required this.pgnFileLoader,
    required this.subscription,
    required this.onTrainingStarted,
    this.onPreviewGameRecords,
    this.onSubmitGameRecords,
    this.onCheckGameRecords,
    this.onCancelGameRecords,
    this.onSummarizeGameRecords,
    this.onSearchGameRecords,
    required this.onCheckTrainingAvailability,
    this.onGameRecordBuildCompleted,
  });

  final String gameRecordPlayerName;
  final VoidCallback onOpenGameRecords;
  final LichessPgnService lichessPgnService;
  final Future<bool> Function(String title, String remark, String pgn)
      onSubmitPgn;
  final ModelBuildGameRecordPreviewCallback? onPreviewGameRecords;
  final ModelBuildGameRecordPushCallback? onSubmitGameRecords;
  final ModelBuildGameRecordStatusCallback? onCheckGameRecords;
  final ModelBuildGameRecordCancelCallback? onCancelGameRecords;
  final ModelBuildGameRecordSummaryCallback? onSummarizeGameRecords;
  final ModelBuildGameRecordSearchCallback? onSearchGameRecords;
  final ModelBuildTrainingAvailabilityCallback onCheckTrainingAvailability;
  final Future<void> Function()? onGameRecordBuildCompleted;
  final VoidCallback onTrainingStarted;
  final SubscriptionStatus? subscription;
  final bool fileImportAvailable;
  final ModelBuildPgnFileLoader pgnFileLoader;

  @override
  State<_ModelBuildDialog> createState() => _ModelBuildDialogState();
}

class _ModelBuildDialogState extends State<_ModelBuildDialog> {
  final titleController = TextEditingController(text: 'My personal engine');
  final remarkController = TextEditingController();
  final lichessPlayerController = TextEditingController();
  final lichessMaxGamesController = TextEditingController(text: '200');
  final lichessSinceController = TextEditingController();
  final lichessUntilController = TextEditingController();
  final gameRecordSearchController = TextEditingController();
  _ModelBuildSource source = _ModelBuildSource.gameRecords;
  GameRecordFilter gameRecordFilter = const GameRecordFilter();
  String lichessSpeed = '';
  String lichessRated = '';
  String lichessColor = '';
  ModelBuildGameRecordJob? gameRecordJob;
  Set<int> selectedGameRecordIndexes = <int>{};
  Map<int, List<GameRecord>> gameRecordPageCache = const {};
  int gameRecordTotalMatches = 0;
  String? gameRecordError;
  ModelBuildPreview? preview;
  List<String> lichessPgnPages = const [];
  int? lichessNextUntilCursor;
  bool lichessHasMore = false;
  String? pgnFromFiles;
  int fileGameCount = 0;
  String? fileSourceLabel;
  bool gameRecordRunning = false;
  bool gameRecordCanceling = false;
  bool previewing = false;
  bool loadingFiles = false;
  bool submitting = false;
  String? localizedDefaultTitle;
  String? trainingUnavailableMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_checkTrainingAvailability());
  }

  @override
  void dispose() {
    titleController.dispose();
    remarkController.dispose();
    lichessPlayerController.dispose();
    lichessMaxGamesController.dispose();
    lichessSinceController.dispose();
    lichessUntilController.dispose();
    gameRecordSearchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextDefault = AppStrings.of(context).t('My personal engine');
    final currentDefault = localizedDefaultTitle;
    if (currentDefault == null || titleController.text == currentDefault) {
      titleController.value = TextEditingValue(
        text: nextDefault,
        selection: TextSelection.collapsed(offset: nextDefault.length),
      );
    }
    localizedDefaultTitle = nextDefault;
  }

  Future<void> _checkTrainingAvailability() async {
    final message = await widget.onCheckTrainingAvailability();
    if (!mounted) return;
    setState(() {
      trainingUnavailableMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = switch (source) {
      _ModelBuildSource.gameRecords => selectedGameRecordIndexes.length,
      _ModelBuildSource.lichess => preview?.gameCount ?? 0,
      _ModelBuildSource.pgnFiles => fileGameCount,
    };
    final canTryQueue =
        !submitting && !gameRecordRunning && !previewing && !loadingFiles;
    final primaryLabel = submitting ? 'Submitting' : 'Start training';
    const primaryIcon = Icons.cloud_upload_rounded;

    return _ModelBuildWorkspaceDialog(
      onClose: submitting ? null : () => Navigator.of(context).pop(),
      leftColumn: SectionColumn(
        spacing: 12,
        children: [
          _ModelBuildCostCard(subscription: widget.subscription),
          _ModelBuildSetupCard(
            titleController: titleController,
            remarkController: remarkController,
            onTitleChanged: (_) => setState(() {}),
          ),
          const _ModelBuildRulesCard(),
        ],
      ),
      rightColumn: SectionColumn(
        spacing: 12,
        children: [
          _SourceSegment(
            source: source,
            fileImportAvailable: widget.fileImportAvailable,
            onChanged: _selectSource,
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: switch (source) {
              _ModelBuildSource.gameRecords => _GameRecordSourcePanel(
                  onOpen: widget.onOpenGameRecords,
                  filter: gameRecordFilter,
                  job: gameRecordJob,
                  trainingUnavailableMessage: trainingUnavailableMessage,
                  matchedCount: gameRecordTotalMatches,
                  totalCount: gameRecordTotalMatches,
                  selectedCount: selectedGameRecordIndexes.length,
                  running: gameRecordRunning,
                  canceling: gameRecordCanceling,
                  error: gameRecordError,
                  searchController: gameRecordSearchController,
                  enabled: widget.onSearchGameRecords != null,
                  onFilterChanged: _setGameRecordFilter,
                  onPreview: _previewGameRecords,
                  onOpenPreview: _showGameRecordPreview,
                  onCancel: _cancelGameRecordJob,
                ),
              _ModelBuildSource.lichess => _LichessSourcePanel(
                  controller: lichessPlayerController,
                  maxGamesController: lichessMaxGamesController,
                  sinceController: lichessSinceController,
                  untilController: lichessUntilController,
                  speed: lichessSpeed,
                  rated: lichessRated,
                  color: lichessColor,
                  preview: preview,
                  hasMore: lichessHasMore,
                  previewing: previewing,
                  onPlayerIdChanged: _clearLichessPreview,
                  onMaxGamesChanged: (_) => _clearLichessPreview(),
                  onSinceChanged: (_) => _clearLichessPreview(),
                  onUntilChanged: (_) => _clearLichessPreview(),
                  onSpeedChanged: (value) => setState(() {
                    lichessSpeed = value;
                    _resetLichessPreview();
                  }),
                  onRatedChanged: (value) => setState(() {
                    lichessRated = value;
                    _resetLichessPreview();
                  }),
                  onColorChanged: (value) => setState(() {
                    lichessColor = value;
                    _resetLichessPreview();
                  }),
                  onPreview: _previewLichess,
                  onOpenPreview: _showLichessPreview,
                ),
              _ModelBuildSource.pgnFiles => _PgnFilesSourcePanel(
                  fileImportAvailable: widget.fileImportAvailable,
                  loading: loadingFiles,
                  gameCount: fileGameCount,
                  sourceLabel: fileSourceLabel,
                  onChooseFiles: _chooseFiles,
                ),
            },
          ),
          _ModelBuildCountBanner(gameCount: activeCount),
        ],
      ),
      actionBar: _ModelBuildActionBar(
        primaryLabel: primaryLabel,
        primaryIcon: primaryIcon,
        submitting: submitting,
        onCancel: submitting ? null : () => Navigator.of(context).pop(),
        onPrimaryPressed: canTryQueue ? _submit : null,
      ),
    );
  }

  void _selectSource(_ModelBuildSource value) {
    setState(() => source = value);
  }

  void _clearLichessPreview([String? _]) {
    setState(_resetLichessPreview);
  }

  void _resetLichessPreview() {
    preview = null;
    lichessPgnPages = const [];
    lichessNextUntilCursor = null;
    lichessHasMore = false;
  }

  _LichessModelBuildOptions? _lichessOptions() {
    final playerId = lichessPlayerController.text.trim();
    final rawMaxGames = lichessMaxGamesController.text.trim();
    final since = lichessSinceController.text.trim();
    final until = lichessUntilController.text.trim();
    final parsedMaxGames =
        rawMaxGames.isEmpty ? 200 : int.tryParse(rawMaxGames);
    if (playerId.isEmpty) {
      showAppFeedback(
        context,
        'Enter a Lichess player id first.',
        tone: AppFeedbackTone.warning,
      );
      return null;
    }
    if (parsedMaxGames == null || parsedMaxGames < 1) {
      showAppFeedback(
        context,
        'Import at least 1 game.',
        tone: AppFeedbackTone.warning,
      );
      return null;
    }
    if (parsedMaxGames > modelBuildMaximumGameCount) {
      showAppFeedback(
        context,
        'Import at most $modelBuildMaximumGameCount games for training.',
        tone: AppFeedbackTone.warning,
      );
      return null;
    }
    return _LichessModelBuildOptions(
      maxGames: parsedMaxGames,
      fetchOptions: LichessPgnFetchOptions(
        playerId: playerId,
        since: since,
        until: until,
        speed: lichessSpeed,
        rated: lichessRated,
        color: lichessColor,
      ),
    );
  }

  void _setGameRecordFilter(GameRecordFilter next) {
    setState(() {
      gameRecordFilter = next;
      gameRecordJob = null;
      selectedGameRecordIndexes = <int>{};
      gameRecordPageCache = const {};
      gameRecordTotalMatches = 0;
      gameRecordError = null;
    });
  }

  Future<void> _previewGameRecords() async {
    final summarizer = widget.onSummarizeGameRecords;
    final searcher = widget.onSearchGameRecords;
    if (searcher == null || gameRecordRunning) return;
    setState(() {
      gameRecordRunning = true;
      gameRecordCanceling = false;
      gameRecordError = null;
      gameRecordJob = null;
      selectedGameRecordIndexes = <int>{};
      gameRecordPageCache = const {};
      gameRecordTotalMatches = 0;
    });
    final result = summarizer != null
        ? await summarizer(gameRecordFilter)
        : await searcher(
            gameRecordFilter,
            1,
            _modelBuildGameRecordPreviewPageSize,
          );
    if (!mounted) return;
    if (!result.isSuccess) {
      setState(() {
        gameRecordRunning = false;
        gameRecordError =
            result.status.errorMessage ?? 'Unable to preview Game Record.';
      });
      return;
    }
    final total = result.total > 0 ? result.total : result.records.length;
    final cachedPages = result.records.isEmpty
        ? const <int, List<GameRecord>>{}
        : <int, List<GameRecord>>{1: result.records};
    setState(() {
      gameRecordRunning = false;
      selectedGameRecordIndexes = {
        for (var index = 0;
            index < math.min(total, modelBuildMaximumGameCount);
            index += 1)
          index,
      };
      gameRecordPageCache = cachedPages;
      gameRecordTotalMatches = total;
      gameRecordError =
          total <= 0 ? 'No usable PGN games matched these filters.' : null;
    });
    if (total > 0) await _showGameRecordPreview();
  }

  Future<List<GameRecord>?> _loadGameRecordPreviewPage(int page) async {
    final searcher = widget.onSearchGameRecords;
    if (searcher == null) return null;
    final cached = gameRecordPageCache[page];
    if (cached != null) return cached;
    final result = await searcher(
      gameRecordFilter,
      page,
      _modelBuildGameRecordPreviewPageSize,
    );
    if (!mounted) return null;
    if (!result.isSuccess) {
      showAppFeedback(
        context,
        result.status.errorMessage ??
            'Unable to load the matched Game Record preview.',
        tone: AppFeedbackTone.warning,
      );
      return null;
    }
    final nextCache = Map<int, List<GameRecord>>.from(gameRecordPageCache)
      ..[page] = result.records;
    setState(() {
      gameRecordPageCache = nextCache;
      if (result.total > gameRecordTotalMatches) {
        gameRecordTotalMatches = result.total;
      }
    });
    return result.records;
  }

  Future<void> _cancelGameRecordJob() async {
    final job = gameRecordJob;
    final canceler = widget.onCancelGameRecords;
    if (job == null || canceler == null || gameRecordCanceling || job.isDone) {
      return;
    }
    setState(() => gameRecordCanceling = true);
    final result = await canceler(job.jobId);
    if (!mounted) return;
    setState(() {
      gameRecordCanceling = false;
      gameRecordRunning = false;
      if (result.isSuccess && result.data != null) {
        gameRecordJob = result.data;
        gameRecordError = null;
      } else {
        gameRecordError = result.status.errorMessage ??
            'Unable to cancel personal engine training.';
      }
    });
  }

  Future<void> _previewLichess() async {
    final options = _lichessOptions();
    if (options == null || previewing) {
      return;
    }

    setState(() {
      _resetLichessPreview();
      previewing = true;
    });
    try {
      final page = await widget.lichessPgnService.fetchGames(
        options: options.fetchOptions,
        pageSize: options.maxGames,
      );
      if (!mounted) return;
      final snapshot = _lichessSnapshotFromPage(
        page,
        maxGames: options.maxGames,
        existingPages: const [],
      );
      setState(() {
        previewing = false;
        _setLichessSnapshot(options.fetchOptions.playerId, snapshot);
      });
      if (snapshot.gameCount <= 0) {
        showAppFeedback(
          context,
          'No usable PGN games matched this Lichess player and filters.',
          tone: AppFeedbackTone.warning,
        );
      }
    } on LichessPgnException catch (error) {
      if (!mounted) return;
      setState(() => previewing = false);
      showAppFeedback(context, error.message, tone: AppFeedbackTone.warning);
    } on TimeoutException {
      if (!mounted) return;
      setState(() => previewing = false);
      showAppFeedback(
        context,
        'Lichess did not respond in time. Try again.',
        tone: AppFeedbackTone.warning,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => previewing = false);
      showAppFeedback(
        context,
        'Unable to preview Lichess games for this player.',
        tone: AppFeedbackTone.warning,
      );
    }
  }

  Future<void> _showLichessPreview() async {
    final current = preview;
    final options = _lichessOptions();
    if (current == null || options == null) {
      return;
    }
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (dialogContext) => _LichessPreviewDialog(
        options: options,
        service: widget.lichessPgnService,
        initialSnapshot: _LichessPgnPreviewSnapshot(
          pgnPages: lichessPgnPages,
          nextUntilCursor: lichessNextUntilCursor,
          hasMore: lichessHasMore,
        ),
        onChanged: (snapshot) {
          if (!mounted) return;
          setState(() {
            _setLichessSnapshot(options.fetchOptions.playerId, snapshot);
          });
        },
      ),
    );
  }

  void _setLichessSnapshot(
    String playerId,
    _LichessPgnPreviewSnapshot snapshot,
  ) {
    lichessPgnPages = snapshot.pgnPages;
    lichessNextUntilCursor = snapshot.nextUntilCursor;
    lichessHasMore = snapshot.hasMore;
    preview = ModelBuildPreview(
      gameCount: snapshot.gameCount,
      pgn: snapshot.pgn,
      sourceLabel: _lichessSourceLabel(playerId),
    );
  }

  Future<void> _showGameRecordPreview() async {
    if (gameRecordTotalMatches <= 0) return;
    final selected = await showDialog<Set<int>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (dialogContext) => _GameRecordSelectionDialog(
        totalCount: gameRecordTotalMatches,
        selectedIndexes: selectedGameRecordIndexes,
        cachedPages: gameRecordPageCache,
        onLoadPage: _loadGameRecordPreviewPage,
        onSelectionChanged: (selection) {
          if (!mounted) return;
          setState(() {
            selectedGameRecordIndexes = selection;
            gameRecordError = null;
          });
        },
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      selectedGameRecordIndexes = selected;
      gameRecordError = null;
    });
  }

  Future<void> _chooseFiles() async {
    if (!widget.fileImportAvailable) {
      showAppFeedback(
        context,
        'PGN file import is available on desktop.',
        tone: AppFeedbackTone.info,
      );
      return;
    }

    setState(() => loadingFiles = true);
    final files = await widget.pgnFileLoader();
    if (!mounted) return;
    final merged = mergeModelBuildPgnFiles(files);
    setState(() {
      loadingFiles = false;
      pgnFromFiles = merged;
      fileGameCount = countModelBuildPgnGames(merged);
      fileSourceLabel = files.isEmpty
          ? null
          : '${files.length} PGN file${files.length == 1 ? '' : 's'}';
    });
  }

  Future<void> _submit() async {
    final title = titleController.text.trim();
    final remark = remarkController.text.trim();
    final gameCount = switch (source) {
      _ModelBuildSource.gameRecords => selectedGameRecordIndexes.length,
      _ModelBuildSource.lichess => preview?.gameCount ?? 0,
      _ModelBuildSource.pgnFiles => fileGameCount,
    };
    final canSubmitWithoutPreview = switch (source) {
      _ModelBuildSource.gameRecords => gameRecordTotalMatches <= 0,
      _ModelBuildSource.lichess => false,
      _ModelBuildSource.pgnFiles => false,
    };
    final unavailableMessage = trainingUnavailableMessage;
    if (unavailableMessage != null) {
      if (source == _ModelBuildSource.gameRecords) {
        setState(() => gameRecordError = unavailableMessage);
      }
      showAppFeedback(
        context,
        unavailableMessage,
        tone: AppFeedbackTone.warning,
      );
      return;
    }
    if (title.isEmpty ||
        (!canSubmitWithoutPreview &&
            !isModelBuildGameCountSubmittable(gameCount))) {
      showAppFeedback(
        context,
        title.isEmpty
            ? 'Add an engine name before starting training.'
            : _notEnoughGamesMessage(gameCount),
        tone: AppFeedbackTone.warning,
      );
      return;
    }
    if (source == _ModelBuildSource.pgnFiles &&
        (pgnFromFiles == null || pgnFromFiles!.trim().isEmpty)) {
      showAppFeedback(
        context,
        'Import PGN files before starting training.',
        tone: AppFeedbackTone.warning,
      );
      return;
    }
    if (source == _ModelBuildSource.lichess &&
        (preview == null || lichessPgnPages.isEmpty)) {
      showAppFeedback(
        context,
        'Preview Lichess games before starting training.',
        tone: AppFeedbackTone.warning,
      );
      return;
    }
    if (source == _ModelBuildSource.lichess && _lichessOptions() == null) {
      return;
    }
    if (source == _ModelBuildSource.gameRecords &&
        gameRecordTotalMatches <= 0) {
      await _submitGameRecords(title, remark);
      return;
    }

    setState(() => submitting = true);
    var ok = false;
    try {
      ok = switch (source) {
        _ModelBuildSource.lichess => await _submitLichess(title, remark),
        _ModelBuildSource.pgnFiles => await widget.onSubmitPgn(
            title,
            remark,
            pgnFromFiles ?? '',
          ),
        _ModelBuildSource.gameRecords =>
          await _submitGameRecords(title, remark),
      };
    } catch (_) {
      if (mounted) {
        const message = 'Unable to start personal engine training.';
        setState(() {
          if (source == _ModelBuildSource.gameRecords) {
            gameRecordError = message;
          }
        });
        showAppFeedback(context, message, tone: AppFeedbackTone.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          submitting = false;
          if (source == _ModelBuildSource.gameRecords) {
            gameRecordRunning = false;
          }
        });
      }
    }
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      widget.onTrainingStarted();
    }
  }

  Future<bool> _submitGameRecords(String title, String remark) async {
    if (gameRecordRunning) {
      return false;
    }
    if (gameRecordTotalMatches <= 0) {
      await _previewGameRecords();
      return false;
    }
    final selectedIndexes = selectedGameRecordIndexes.toList()..sort();
    if (!isModelBuildGameCountSubmittable(selectedIndexes.length)) {
      final message = _notEnoughGamesMessage(selectedIndexes.length);
      setState(() => gameRecordError = message);
      showAppFeedback(context, message, tone: AppFeedbackTone.warning);
      return false;
    }
    showAppFeedback(
      context,
      'Preparing ${selectedIndexes.length} selected Game Record PGNs for training...',
      duration: const Duration(seconds: 2),
    );
    final selected = await _loadSelectedGameRecordsForSubmit(selectedIndexes);
    if (!mounted) return false;
    if (selected == null) {
      return false;
    }
    final usable = selected.where(_isUsableModelBuildRecord).toList();
    if (!isModelBuildGameCountSubmittable(usable.length)) {
      final message = _notEnoughGamesMessage(usable.length);
      setState(() => gameRecordError = message);
      showAppFeedback(context, message, tone: AppFeedbackTone.warning);
      return false;
    }
    final pgn = mergeModelBuildPgnFiles(
      usable.expand(
        (record) => splitPgnGames(record.pgn).map(
          (game) => addModelBuildTrainTag(
            game,
            playerName: widget.gameRecordPlayerName,
            whiteName: record.whiteName,
            blackName: record.blackName,
          ),
        ),
      ),
    );
    if (pgn.trim().isEmpty) {
      const message = 'Selected games do not include usable PGN text.';
      setState(() => gameRecordError = message);
      showAppFeedback(context, message, tone: AppFeedbackTone.warning);
      return false;
    }
    showAppFeedback(
      context,
      'Submitting selected games for personal engine training...',
      duration: const Duration(seconds: 2),
    );
    final ok = await widget.onSubmitPgn(title, remark, pgn);
    if (ok) {
      await widget.onGameRecordBuildCompleted?.call();
    } else if (mounted) {
      setState(() {
        gameRecordError ??= _personalEngineTrainingUnavailableMessage;
      });
    }
    return ok;
  }

  Future<bool> _submitLichess(String title, String remark) async {
    final playerId = lichessPlayerController.text.trim();
    final pgn = mergeModelBuildPgnFiles(
      lichessPgnPages.expand(splitPgnGames).map(
            (game) => addModelBuildTrainTag(
              game,
              playerName: playerId,
            ),
          ),
    );
    final gameCount = countModelBuildPgnGames(pgn);
    if (!isModelBuildGameCountSubmittable(gameCount)) {
      showAppFeedback(
        context,
        _notEnoughGamesMessage(gameCount),
        tone: AppFeedbackTone.warning,
      );
      return false;
    }
    showAppFeedback(
      context,
      'Submitting $gameCount Lichess PGNs for personal engine training...',
      duration: const Duration(seconds: 2),
    );
    final ok = await widget.onSubmitPgn(title, remark, pgn);
    return ok;
  }

  Future<List<GameRecord>?> _loadSelectedGameRecordsForSubmit(
    List<int> selectedIndexes,
  ) async {
    final searcher = widget.onSearchGameRecords;
    if (searcher == null) {
      const message = 'Game Record search is unavailable.';
      setState(() => gameRecordError = message);
      showAppFeedback(context, message, tone: AppFeedbackTone.warning);
      return null;
    }
    setState(() => gameRecordRunning = true);
    final selected = <GameRecord>[];
    final pages = {
      for (final index in selectedIndexes)
        (index ~/ _modelBuildGameRecordPreviewPageSize) + 1,
    }.toList()
      ..sort();
    for (final page in pages) {
      final cached = gameRecordPageCache[page];
      List<GameRecord> records;
      if (cached != null) {
        records = cached;
      } else {
        final result = await searcher(
          gameRecordFilter,
          page,
          _modelBuildGameRecordPreviewPageSize,
        );
        if (!mounted) return null;
        if (!result.isSuccess) {
          final message = result.status.errorMessage ??
              'Unable to load selected Game Record PGNs.';
          setState(() {
            gameRecordRunning = false;
            gameRecordError = message;
          });
          showAppFeedback(context, message, tone: AppFeedbackTone.warning);
          return null;
        }
        records = result.records;
      }
      if (!mounted) return null;
      if (cached == null) {
        gameRecordPageCache =
            Map<int, List<GameRecord>>.from(gameRecordPageCache)
              ..[page] = records;
      }
      final pageStart = (page - 1) * _modelBuildGameRecordPreviewPageSize;
      for (final index in selectedIndexes) {
        if (index < pageStart ||
            index >= pageStart + _modelBuildGameRecordPreviewPageSize) {
          continue;
        }
        final recordIndex = index - pageStart;
        if (recordIndex >= 0 && recordIndex < records.length) {
          selected.add(records[recordIndex]);
        }
      }
    }
    if (mounted) {
      setState(() => gameRecordRunning = false);
    }
    return selected;
  }

  String _notEnoughGamesMessage(int gameCount) {
    if (gameCount <= 0) {
      return 'Import or preview games before starting training.';
    }
    if (gameCount > modelBuildMaximumGameCount) {
      return 'Select at most $modelBuildMaximumGameCount games before starting training.';
    }
    return 'Only $gameCount usable games were selected. At least $modelBuildMinimumGameCount games are required before starting training.';
  }
}

bool _isUsableModelBuildRecord(GameRecord record) {
  return record.pgn.trim().isNotEmpty &&
      countModelBuildPgnGames(record.pgn) > 0;
}

class _ModelBuildWorkspaceDialog extends StatelessWidget {
  const _ModelBuildWorkspaceDialog({
    required this.leftColumn,
    required this.rightColumn,
    required this.actionBar,
    required this.onClose,
  });

  final Widget leftColumn;
  final Widget rightColumn;
  final Widget actionBar;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final compactLandscape = isCompactLandscapeDevice(context);
    final useFullscreen = compactLandscape || size.width < 560;
    final horizontalInset = useFullscreen ? 0.0 : 24.0;
    final verticalInset = useFullscreen ? 0.0 : 20.0;
    final maxWidth = math.min(size.width - horizontalInset * 2, 980.0);
    final maxHeight =
        size.height - viewPadding.top - viewPadding.bottom - verticalInset * 2;

    return Dialog(
      alignment: Alignment.center,
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: verticalInset,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: useFullscreen ? size.width : maxWidth,
          maxHeight: math.max(320, maxHeight),
        ),
        child: GlassPanel(
          borderRadius: useFullscreen ? 0 : 18,
          padding: EdgeInsets.zero,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 860;
              final compact = constraints.maxHeight <= 430;
              final body = SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 16,
                  compact ? 10 : 14,
                  compact ? 12 : 16,
                  compact ? 10 : 14,
                ),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: leftColumn),
                          const SizedBox(width: 14),
                          Expanded(child: rightColumn),
                        ],
                      )
                    : SectionColumn(
                        spacing: 12,
                        children: [rightColumn, leftColumn],
                      ),
              );

              return Column(
                children: [
                  _ModelBuildWorkspaceHeader(onClose: onClose),
                  const Divider(height: 1),
                  Expanded(child: body),
                  const Divider(height: 1),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 12 : 16,
                      compact ? 8 : 12,
                      compact ? 12 : 16,
                      compact ? 10 : 14,
                    ),
                    child: actionBar,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ModelBuildWorkspaceHeader extends StatelessWidget {
  const _ModelBuildWorkspaceHeader({required this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = isCompactLandscapeDevice(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 10 : 14, 10, compact ? 8 : 12),
      child: Row(
        children: [
          Container(
            width: compact ? 38 : 42,
            height: compact ? 38 : 42,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.hub_rounded, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New personal engine',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 2),
                Text(
                  'Choose one PGN source. Minimum 20 games, 50+ recommended.',
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _ModelBuildCostCard extends StatelessWidget {
  const _ModelBuildCostCard({required this.subscription});

  final SubscriptionStatus? subscription;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final premiumActive = subscription?.isActive == true;
    final color = premiumActive ? scheme.primary : scheme.secondary;
    final title = premiumActive
        ? 'Premium training is unlimited'
        : '$personalEngineTrainingCostPoints points per training';
    final detail = premiumActive && subscription!.expireTime.isNotEmpty
        ? 'Premium active until ${subscription!.expireTime}.'
        : 'Use one clean source and keep games from the same player or style for better results.';
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 12,
      tint: color.withValues(alpha: 0.07),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              premiumActive
                  ? Icons.workspace_premium_rounded
                  : Icons.toll_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelBuildSetupCard extends StatelessWidget {
  const _ModelBuildSetupCard({
    required this.titleController,
    required this.remarkController,
    required this.onTitleChanged,
  });

  final TextEditingController titleController;
  final TextEditingController remarkController;
  final ValueChanged<String> onTitleChanged;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_note_rounded, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Engine details',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: titleController,
            textInputAction: TextInputAction.next,
            onChanged: onTitleChanged,
            decoration: const InputDecoration(
              labelText: 'Engine name',
              prefixIcon: Icon(Icons.memory_rounded),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: remarkController,
            textInputAction: TextInputAction.next,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelBuildActionBar extends StatelessWidget {
  const _ModelBuildActionBar({
    required this.primaryLabel,
    required this.primaryIcon,
    required this.submitting,
    required this.onCancel,
    required this.onPrimaryPressed,
  });

  final String primaryLabel;
  final IconData primaryIcon;
  final bool submitting;
  final VoidCallback? onCancel;
  final VoidCallback? onPrimaryPressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final primary = FilledButton.icon(
          onPressed: onPrimaryPressed,
          icon: submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(primaryIcon),
          label: Text(
            primaryLabel,
            maxLines: 2,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
          ),
        );
        final cancel = OutlinedButton(
          onPressed: onCancel,
          child: const Text(
            'Cancel',
            maxLines: 2,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primary,
              const SizedBox(height: 8),
              cancel,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cancel),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: primary),
          ],
        );
      },
    );
  }
}

class _ModelBuildRulesCard extends StatelessWidget {
  const _ModelBuildRulesCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 12,
      tint: scheme.primary.withValues(alpha: 0.07),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Training rules',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 6),
          Text(
            'Use one source only. Choose games from the same player or style. Training continues in the background after submission.',
          ),
        ],
      ),
    );
  }
}

class _SourceSegment extends StatelessWidget {
  const _SourceSegment({
    required this.source,
    required this.fileImportAvailable,
    required this.onChanged,
  });

  final _ModelBuildSource source;
  final bool fileImportAvailable;
  final ValueChanged<_ModelBuildSource> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_ModelBuildSource>(
      segments: [
        const ButtonSegment(
          value: _ModelBuildSource.gameRecords,
          icon: Icon(Icons.history_rounded),
          label: Text('Game Record'),
        ),
        const ButtonSegment(
          value: _ModelBuildSource.lichess,
          icon: Icon(Icons.public_rounded),
          label: Text('Lichess Player'),
        ),
        if (fileImportAvailable)
          const ButtonSegment(
            value: _ModelBuildSource.pgnFiles,
            icon: Icon(Icons.upload_file_rounded),
            label: Text('PGN Files'),
          ),
      ],
      selected: {source},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        if (selection.isEmpty) return;
        onChanged(selection.first);
      },
    );
  }
}

class _GameRecordSourcePanel extends StatelessWidget {
  const _GameRecordSourcePanel({
    required this.onOpen,
    required this.filter,
    required this.job,
    required this.trainingUnavailableMessage,
    required this.matchedCount,
    required this.totalCount,
    required this.selectedCount,
    required this.running,
    required this.canceling,
    required this.error,
    required this.searchController,
    required this.enabled,
    required this.onFilterChanged,
    required this.onPreview,
    required this.onOpenPreview,
    required this.onCancel,
  });

  final VoidCallback onOpen;
  final GameRecordFilter filter;
  final ModelBuildGameRecordJob? job;
  final String? trainingUnavailableMessage;
  final int matchedCount;
  final int totalCount;
  final int selectedCount;
  final bool running;
  final bool canceling;
  final String? error;
  final TextEditingController searchController;
  final bool enabled;
  final ValueChanged<GameRecordFilter> onFilterChanged;
  final VoidCallback onPreview;
  final VoidCallback onOpenPreview;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      key: const ValueKey('game-record-source'),
      padding: const EdgeInsets.all(12),
      borderRadius: 12,
      child: SectionColumn(
        spacing: 10,
        children: [
          Row(
            children: [
              Icon(Icons.manage_search_rounded,
                  size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Choose from Game Record',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Open'),
              ),
            ],
          ),
          const Text(
            'Filter your saved games here, preview the usable PGNs, then start training without leaving Engine Lab.',
          ),
          if (trainingUnavailableMessage != null)
            _ModelBuildTrainingUnavailableNotice(
              message: trainingUnavailableMessage!,
            ),
          TextField(
            key: const ValueKey('engine-model-record-query'),
            controller: searchController,
            decoration: const InputDecoration(
              labelText: 'Search player or event',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) =>
                onFilterChanged(filter.copyWith(query: value)),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 640;
              final fields = [
                _ModelBuildChoiceMenu<RecordModeFilter>(
                  key: const ValueKey('engine-model-record-source'),
                  label: 'Source',
                  value: filter.mode,
                  values: RecordModeFilter.values,
                  labelFor: _modeLabel,
                  onChanged: (value) =>
                      onFilterChanged(filter.copyWith(mode: value)),
                ),
                _ModelBuildChoiceMenu<RecordResultFilter>(
                  key: const ValueKey('engine-model-record-result'),
                  label: 'Result',
                  value: filter.result,
                  values: RecordResultFilter.values,
                  labelFor: _resultLabel,
                  onChanged: (value) =>
                      onFilterChanged(filter.copyWith(result: value)),
                ),
                _ModelBuildChoiceMenu<RecordColorFilter>(
                  key: const ValueKey('engine-model-record-color'),
                  label: 'Color',
                  value: filter.color,
                  values: RecordColorFilter.values,
                  labelFor: _colorLabel,
                  onChanged: (value) =>
                      onFilterChanged(filter.copyWith(color: value)),
                ),
                _ModelBuildChoiceMenu<RecordSpeedFilter>(
                  key: const ValueKey('engine-model-record-speed'),
                  label: 'Speed',
                  value: filter.speed,
                  values: RecordSpeedFilter.values,
                  labelFor: _speedLabel,
                  onChanged: (value) =>
                      onFilterChanged(filter.copyWith(speed: value)),
                ),
              ];
              if (!twoColumns) {
                return SectionColumn(spacing: 8, children: fields);
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: fields[0]),
                      const SizedBox(width: 8),
                      Expanded(child: fields[1]),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: fields[2]),
                      const SizedBox(width: 8),
                      Expanded(child: fields[3]),
                    ],
                  ),
                ],
              );
            },
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: const ValueKey('engine-model-record-min-moves'),
                  initialValue:
                      filter.minMoves <= 0 ? '' : filter.minMoves.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Min moves',
                    prefixIcon: Icon(Icons.format_list_numbered_rounded),
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value.trim()) ?? 0;
                    onFilterChanged(filter.copyWith(minMoves: parsed));
                  },
                ),
              ),
            ],
          ),
          _WrapSafeFilledButton(
            key: const ValueKey('engine-model-record-preview'),
            onPressed: enabled && !running ? onPreview : null,
            icon: Icons.fact_check_rounded,
            busy: running,
            label: running ? 'Checking games' : 'Preview matching games',
          ),
          if (matchedCount > 0 || error != null)
            _ModelBuildGameRecordSelectionCard(
              matchedCount: matchedCount,
              totalCount: totalCount,
              selectedCount: selectedCount,
              error: error,
              running: running,
              onOpenPreview: onOpenPreview,
            )
          else if (job != null)
            _ModelBuildGameRecordStatusCard(
              job: job,
              error: error,
              running: running,
              canceling: canceling,
              onOpenPreview: onOpenPreview,
              onCancel: onCancel,
            ),
        ],
      ),
    );
  }

  String _modeLabel(RecordModeFilter value) {
    return switch (value) {
      RecordModeFilter.all => 'All',
      RecordModeFilter.local => 'Chessnut',
      RecordModeFilter.bot => 'Bot',
      RecordModeFilter.otb => 'OTB',
      RecordModeFilter.lichess => 'Lichess',
      RecordModeFilter.chesscom => 'Chess.com',
    };
  }

  String _resultLabel(RecordResultFilter value) {
    return switch (value) {
      RecordResultFilter.all => 'All',
      RecordResultFilter.win => 'Win',
      RecordResultFilter.loss => 'Loss',
      RecordResultFilter.draw => 'Draw',
      RecordResultFilter.unfinished => 'Unfinished',
    };
  }

  String _colorLabel(RecordColorFilter value) {
    return switch (value) {
      RecordColorFilter.all => 'Any',
      RecordColorFilter.white => 'White',
      RecordColorFilter.black => 'Black',
    };
  }

  String _speedLabel(RecordSpeedFilter value) {
    return switch (value) {
      RecordSpeedFilter.all => 'Any',
      RecordSpeedFilter.casual => 'Casual',
      RecordSpeedFilter.bullet => 'Bullet',
      RecordSpeedFilter.blitz => 'Blitz',
      RecordSpeedFilter.rapid => 'Rapid',
      RecordSpeedFilter.daily => 'Daily',
      RecordSpeedFilter.classical => 'Classical',
    };
  }
}

class _ModelBuildChoiceMenu<T> extends StatelessWidget {
  const _ModelBuildChoiceMenu({
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
    super.key,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final item in values)
          DropdownMenuItem<T>(
            value: item,
            child: Text(
              labelFor(item),
              maxLines: 2,
              overflow: TextOverflow.visible,
            ),
          ),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

class _ModelBuildTrainingUnavailableNotice extends StatelessWidget {
  const _ModelBuildTrainingUnavailableNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.error.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: scheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: scheme.error,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelBuildGameRecordSelectionCard extends StatelessWidget {
  const _ModelBuildGameRecordSelectionCard({
    required this.matchedCount,
    required this.totalCount,
    required this.selectedCount,
    required this.error,
    required this.running,
    required this.onOpenPreview,
  });

  final int matchedCount;
  final int totalCount;
  final int selectedCount;
  final String? error;
  final bool running;
  final VoidCallback onOpenPreview;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasError = error != null;
    final tone = hasError ? scheme.error : scheme.primary;
    final totalLabel = totalCount > matchedCount ? ' / $totalCount total' : '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                hasError
                    ? Icons.error_outline_rounded
                    : Icons.fact_check_rounded,
                color: tone,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasError ? 'Training needs attention' : 'Preview ready',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      error ??
                          '$matchedCount matched$totalLabel / $selectedCount selected. Select 20-$modelBuildMaximumGameCount games for training.',
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!running && matchedCount > 0) ...[
            const SizedBox(height: 10),
            _WrapSafeOutlinedButton(
              key: const ValueKey('engine-model-record-preview-pgn'),
              onPressed: onOpenPreview,
              icon: Icons.checklist_rounded,
              label: 'Preview found games',
            ),
          ],
        ],
      ),
    );
  }
}

class _GameRecordSelectionDialog extends StatefulWidget {
  const _GameRecordSelectionDialog({
    required this.totalCount,
    required this.selectedIndexes,
    required this.cachedPages,
    required this.onLoadPage,
    required this.onSelectionChanged,
  });

  final int totalCount;
  final Set<int> selectedIndexes;
  final Map<int, List<GameRecord>> cachedPages;
  final Future<List<GameRecord>?> Function(int page) onLoadPage;
  final ValueChanged<Set<int>> onSelectionChanged;

  @override
  State<_GameRecordSelectionDialog> createState() =>
      _GameRecordSelectionDialogState();
}

class _GameRecordSelectionDialogState
    extends State<_GameRecordSelectionDialog> {
  late final Set<int> selectedIndexes = Set<int>.from(widget.selectedIndexes);
  late final Map<int, List<GameRecord>> pageCache =
      Map<int, List<GameRecord>>.from(widget.cachedPages);
  int page = 0;
  bool loadingPage = false;
  String? pageError;
  int loadPageSerial = 0;

  int get totalPage => math.max(
        1,
        (widget.totalCount / _modelBuildGameRecordPreviewPageSize).ceil(),
      );

  int get _currentPageNumber => page + 1;

  List<GameRecord>? get visibleRecords => pageCache[_currentPageNumber];

  int get visibleStartIndex => page * _modelBuildGameRecordPreviewPageSize;

  int get visibleEndIndex => math.min(
        widget.totalCount,
        visibleStartIndex + _modelBuildGameRecordPreviewPageSize,
      );

  @override
  void initState() {
    super.initState();
    _ensurePageLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final records = visibleRecords;
    final selectedCount = selectedIndexes.length;
    final canUseSelection = selectedCount >= modelBuildMinimumGameCount &&
        selectedCount <= modelBuildMaximumGameCount;
    final overflow = selectedCount > modelBuildMaximumGameCount;
    final underflow =
        selectedCount > 0 && selectedCount < modelBuildMinimumGameCount;
    final title = overflow
        ? 'Too many games selected'
        : underflow
            ? 'Select more games'
            : '$selectedCount selected';
    final subtitle =
        '${widget.totalCount} matched / page ${page + 1} of $totalPage';
    final screenHeight = MediaQuery.sizeOf(context).height;
    final listMaxHeight = (screenHeight * 0.30).clamp(180.0, 430.0);

    return AppDialogShell(
      icon: Icons.checklist_rounded,
      title: 'Preview found games',
      subtitle: subtitle,
      actions: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(selectedIndexes),
            child: const Text('Close'),
          ),
        ),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: canUseSelection
                ? () => Navigator.of(context).pop(selectedIndexes)
                : null,
            icon: const Icon(Icons.done_rounded),
            label: const Text('Use selected'),
          ),
        ),
      ],
      child: SizedBox(
        width: 720,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GameRecordSelectionToolbar(
              title: title,
              selectedCount: selectedCount,
              visibleStartIndex: visibleStartIndex,
              visibleEndIndex: visibleEndIndex,
              selectedIndexes: selectedIndexes,
              onSelectPage: _selectVisible,
              onClearPage: _clearVisible,
              onSelectFirstMax: _selectFirstMax,
            ),
            if (overflow || underflow) ...[
              const SizedBox(height: 8),
              _ModelBuildPreviewSampleNotice(
                message: overflow
                    ? 'Select at most $modelBuildMaximumGameCount games before starting training.'
                    : 'Select at least $modelBuildMinimumGameCount games before starting training.',
              ),
            ],
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: listMaxHeight),
              child: SingleChildScrollView(
                child: SectionColumn(
                  spacing: 8,
                  children: [
                    if (loadingPage)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (pageError != null)
                      _ModelBuildPreviewSampleNotice(message: pageError!)
                    else if (records == null || records.isEmpty)
                      const _ModelBuildPreviewSampleNotice(
                        message: 'No games loaded for this page.',
                      )
                    else
                      for (var i = 0; i < records.length; i += 1)
                        _SelectableGameRecordPreviewTile(
                          record: records[i],
                          selected:
                              selectedIndexes.contains(visibleStartIndex + i),
                          onChanged: (selected) =>
                              _setSelected(visibleStartIndex + i, selected),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _GameRecordSelectionPager(
              page: page,
              totalPage: totalPage,
              onPrevious:
                  page <= 0 ? null : () => _setPage(math.max(0, page - 1)),
              onNext: page >= totalPage - 1
                  ? null
                  : () => _setPage(math.min(totalPage - 1, page + 1)),
            ),
          ],
        ),
      ),
    );
  }

  void _setSelected(int index, bool selected) {
    setState(() {
      if (selected) {
        selectedIndexes.add(index);
      } else {
        selectedIndexes.remove(index);
      }
    });
    _notifySelectionChanged();
  }

  void _selectVisible() {
    setState(() {
      for (var index = visibleStartIndex; index < visibleEndIndex; index += 1) {
        selectedIndexes.add(index);
      }
    });
    _notifySelectionChanged();
  }

  void _clearVisible() {
    setState(() {
      for (var index = visibleStartIndex; index < visibleEndIndex; index += 1) {
        selectedIndexes.remove(index);
      }
    });
    _notifySelectionChanged();
  }

  void _selectFirstMax() {
    setState(() {
      selectedIndexes
        ..clear()
        ..addAll(
          List<int>.generate(
            math.min(modelBuildMaximumGameCount, widget.totalCount),
            (index) => index,
          ),
        );
    });
    _notifySelectionChanged();
  }

  void _notifySelectionChanged() {
    widget.onSelectionChanged(Set<int>.from(selectedIndexes));
  }

  void _setPage(int nextPage) {
    setState(() => page = nextPage);
    _ensurePageLoaded();
  }

  Future<void> _ensurePageLoaded() async {
    final pageNumber = _currentPageNumber;
    if (pageCache.containsKey(pageNumber)) return;
    final serial = ++loadPageSerial;
    setState(() {
      loadingPage = true;
      pageError = null;
    });
    final records = await widget.onLoadPage(pageNumber);
    if (!mounted || serial != loadPageSerial) return;
    if (pageNumber != _currentPageNumber) {
      setState(() => loadingPage = false);
      await _ensurePageLoaded();
      return;
    }
    setState(() {
      loadingPage = false;
      if (records == null) {
        pageError = 'Unable to load games for this page.';
      } else {
        pageCache[pageNumber] = records;
      }
    });
  }
}

class _LichessPreviewDialog extends StatefulWidget {
  const _LichessPreviewDialog({
    required this.options,
    required this.service,
    required this.initialSnapshot,
    required this.onChanged,
  });

  final _LichessModelBuildOptions options;
  final LichessPgnService service;
  final _LichessPgnPreviewSnapshot initialSnapshot;
  final ValueChanged<_LichessPgnPreviewSnapshot> onChanged;

  @override
  State<_LichessPreviewDialog> createState() => _LichessPreviewDialogState();
}

class _LichessPreviewDialogState extends State<_LichessPreviewDialog> {
  late _LichessPgnPreviewSnapshot snapshot = widget.initialSnapshot;
  int page = 0;
  bool loadingPage = false;
  String? pageError;

  int get totalPage => math.max(1, snapshot.pgnPages.length);

  bool get canLoadMore =>
      snapshot.hasMore &&
      !loadingPage &&
      snapshot.gameCount < widget.options.maxGames;

  String get visiblePgn =>
      snapshot.pgnPages.isEmpty ? '' : snapshot.pgnPages[page];

  List<_ModelBuildPreviewGame> get visibleGames {
    return [
      for (final pgn in splitPgnGames(visiblePgn))
        _ModelBuildPreviewGame(
          pgn: pgn,
          headers: _previewHeadersFromPgn(pgn),
          fen: _previewFinalFenFromPgn(pgn),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final listMaxHeight = (screenHeight * 0.30).clamp(180.0, 430.0);
    final subtitle =
        '${snapshot.gameCount} loaded / page ${page + 1} of $totalPage';
    return AppDialogShell(
      icon: Icons.article_rounded,
      title: 'Preview found games',
      subtitle:
          '${_lichessSourceLabel(widget.options.fetchOptions.playerId)} / $subtitle',
      actions: [
        Expanded(
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ),
      ],
      child: SizedBox(
        width: 720,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LichessPreviewToolbar(
              gameCount: snapshot.gameCount,
              maxGames: widget.options.maxGames,
              hasMore: snapshot.hasMore,
            ),
            if (pageError != null) ...[
              const SizedBox(height: 8),
              _ModelBuildPreviewSampleNotice(message: pageError!),
            ],
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: listMaxHeight),
              child: SingleChildScrollView(
                child: SectionColumn(
                  spacing: 8,
                  children: [
                    if (visibleGames.isEmpty)
                      const _ModelBuildPreviewSampleNotice(
                        message: 'No games loaded for this page.',
                      )
                    else
                      for (final game in visibleGames)
                        _ModelBuildPreviewGameTile(game: game),
                  ],
                ),
              ),
            ),
            if (loadingPage) ...[
              const SizedBox(height: 10),
              const Center(child: CircularProgressIndicator()),
            ],
            const SizedBox(height: 10),
            _GameRecordSelectionPager(
              page: page,
              totalPage: totalPage,
              onPrevious: page <= 0 ? null : () => setState(() => page -= 1),
              onNext: _nextPageHandler(),
            ),
          ],
        ),
      ),
    );
  }

  VoidCallback? _nextPageHandler() {
    if (page < totalPage - 1) {
      return () => setState(() => page += 1);
    }
    if (!canLoadMore) return null;
    return _loadNextPage;
  }

  Future<void> _loadNextPage() async {
    if (!canLoadMore) return;
    setState(() {
      loadingPage = true;
      pageError = null;
    });
    try {
      final remaining = widget.options.maxGames - snapshot.gameCount;
      final pageResult = await widget.service.fetchGames(
        options: widget.options.fetchOptions,
        pageSize: remaining,
        untilCursor: snapshot.nextUntilCursor,
      );
      if (!mounted) return;
      final nextSnapshot = _lichessSnapshotFromPage(
        pageResult,
        maxGames: widget.options.maxGames,
        existingPages: snapshot.pgnPages,
      );
      setState(() {
        snapshot = nextSnapshot;
        loadingPage = false;
        page = math.max(0, snapshot.pgnPages.length - 1);
      });
      widget.onChanged(snapshot);
      if (pageResult.pgn.trim().isEmpty) {
        setState(() {
          pageError = 'Lichess returned no more PGN games for these filters.';
        });
      }
    } on LichessPgnException catch (error) {
      if (!mounted) return;
      setState(() {
        loadingPage = false;
        pageError = error.message;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        loadingPage = false;
        pageError = 'Lichess did not respond in time. Try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingPage = false;
        pageError = 'Unable to load more Lichess games.';
      });
    }
  }
}

class _LichessPreviewToolbar extends StatelessWidget {
  const _LichessPreviewToolbar({
    required this.gameCount,
    required this.maxGames,
    required this.hasMore,
  });

  final int gameCount;
  final int maxGames;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final complete = !hasMore || gameCount >= maxGames;
    final message = complete
        ? '$gameCount PGN games loaded.'
        : '$gameCount PGN games loaded. Use next page to fetch more.';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(Icons.public_rounded, color: scheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$message Max $maxGames games.',
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameRecordSelectionToolbar extends StatelessWidget {
  const _GameRecordSelectionToolbar({
    required this.title,
    required this.selectedCount,
    required this.visibleStartIndex,
    required this.visibleEndIndex,
    required this.selectedIndexes,
    required this.onSelectPage,
    required this.onClearPage,
    required this.onSelectFirstMax,
  });

  final String title;
  final int selectedCount;
  final int visibleStartIndex;
  final int visibleEndIndex;
  final Set<int> selectedIndexes;
  final VoidCallback onSelectPage;
  final VoidCallback onClearPage;
  final VoidCallback onSelectFirstMax;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pageSelected = [
      for (var index = visibleStartIndex; index < visibleEndIndex; index += 1)
        index,
    ].where(selectedIndexes.contains).length;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '$title / $pageSelected on this page',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          OutlinedButton.icon(
            onPressed: onSelectPage,
            icon: const Icon(Icons.select_all_rounded, size: 18),
            label: const Text('Select page'),
          ),
          OutlinedButton.icon(
            onPressed: onClearPage,
            icon: const Icon(Icons.remove_done_rounded, size: 18),
            label: const Text('Clear page'),
          ),
          if (selectedCount > modelBuildMaximumGameCount)
            FilledButton.icon(
              onPressed: onSelectFirstMax,
              icon: const Icon(Icons.filter_alt_rounded, size: 18),
              label: const Text('Keep first 200'),
            ),
        ],
      ),
    );
  }
}

class _GameRecordSelectionPager extends StatelessWidget {
  const _GameRecordSelectionPager({
    required this.page,
    required this.totalPage,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int totalPage;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Previous page',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            'Page ${page + 1} / $totalPage',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Next page',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _SelectableGameRecordPreviewTile extends StatelessWidget {
  const _SelectableGameRecordPreviewTile({
    required this.record,
    required this.selected,
    required this.onChanged,
  });

  final GameRecord record;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final game = _previewGameFromRecord(record);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!selected),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            onChanged: (value) => onChanged(value ?? false),
          ),
          Expanded(child: _ModelBuildPreviewGameTile(game: game)),
        ],
      ),
    );
  }
}

class _ModelBuildGameRecordStatusCard extends StatelessWidget {
  const _ModelBuildGameRecordStatusCard({
    required this.job,
    required this.error,
    required this.running,
    required this.canceling,
    required this.onOpenPreview,
    required this.onCancel,
  });

  final ModelBuildGameRecordJob? job;
  final String? error;
  final bool running;
  final bool canceling;
  final VoidCallback onOpenPreview;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = job;
    final tone = error != null || current?.status == 'failed'
        ? scheme.error
        : current?.status == 'completed'
            ? scheme.primary
            : scheme.secondary;
    final title = error != null
        ? 'Training needs attention'
        : switch (current?.status) {
            'completed' => current?.trainingId == 0
                ? 'Preview ready'
                : 'Personal engine training started',
            'running' => 'Collecting matching games',
            'queued' => 'Preparing preview',
            'failed' => 'Training failed',
            'canceled' => 'Training canceled',
            _ => 'Game Record preview',
          };
    final subtitle = error ?? _statusSubtitle(current);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.fact_check_rounded, color: tone),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(subtitle),
                    ],
                  ],
                ),
              ),
              if (running && current != null && !current.isDone)
                TextButton.icon(
                  onPressed: canceling ? null : onCancel,
                  icon: canceling
                      ? const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.stop_circle_outlined),
                  label: Text(
                    canceling ? 'Canceling' : 'Cancel',
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
          if (current?.progressPercent != null) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: (current!.progressPercent.clamp(0, 100)) / 100,
            ),
          ],
          if (current != null &&
              current.status == 'completed' &&
              current.trainingId == 0) ...[
            const SizedBox(height: 10),
            _WrapSafeOutlinedButton(
              key: const ValueKey('engine-model-record-preview-pgn'),
              onPressed: onOpenPreview,
              icon: Icons.article_rounded,
              label: 'Preview found games',
            ),
          ],
        ],
      ),
    );
  }

  String _statusSubtitle(ModelBuildGameRecordJob? job) {
    if (job == null) return '';
    final message = job.userMessage.trim().isNotEmpty
        ? job.userMessage.trim()
        : job.statusDetail.trim();
    final readableMessage =
        message.isEmpty ? '' : _readablePersonalEngineTrainingMessage(message);
    final stats =
        '${job.processedCount}/${job.matchedCount} checked / ${job.usableCount} usable / ${job.skippedCount} skipped / ${job.failedCount} failed';
    if (readableMessage.isNotEmpty) return '$readableMessage $stats';
    if (job.status == 'running' || job.status == 'queued') {
      return '$stats Chessnut keeps working in the background.';
    }
    if (job.status == 'completed' && job.trainingId == 0) {
      return '$stats Start training when the usable game count is enough.';
    }
    return stats;
  }
}

class _LichessSourcePanel extends StatelessWidget {
  const _LichessSourcePanel({
    required this.controller,
    required this.maxGamesController,
    required this.sinceController,
    required this.untilController,
    required this.speed,
    required this.rated,
    required this.color,
    required this.preview,
    required this.hasMore,
    required this.previewing,
    required this.onPlayerIdChanged,
    required this.onMaxGamesChanged,
    required this.onSinceChanged,
    required this.onUntilChanged,
    required this.onSpeedChanged,
    required this.onRatedChanged,
    required this.onColorChanged,
    required this.onPreview,
    required this.onOpenPreview,
  });

  final TextEditingController controller;
  final TextEditingController maxGamesController;
  final TextEditingController sinceController;
  final TextEditingController untilController;
  final String speed;
  final String rated;
  final String color;
  final ModelBuildPreview? preview;
  final bool hasMore;
  final bool previewing;
  final ValueChanged<String> onPlayerIdChanged;
  final ValueChanged<String> onMaxGamesChanged;
  final ValueChanged<String> onSinceChanged;
  final ValueChanged<String> onUntilChanged;
  final ValueChanged<String> onSpeedChanged;
  final ValueChanged<String> onRatedChanged;
  final ValueChanged<String> onColorChanged;
  final VoidCallback onPreview;
  final VoidCallback onOpenPreview;

  @override
  Widget build(BuildContext context) {
    return _SourcePanelShell(
      key: const ValueKey('lichess-source'),
      icon: Icons.public_rounded,
      title: 'Import by Lichess player id',
      body:
          'The app fetches public Lichess PGNs directly, then uploads the loaded PGNs when training starts.',
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            onChanged: onPlayerIdChanged,
            decoration: const InputDecoration(
              labelText: 'Lichess player id',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final fieldWidth = constraints.maxWidth < 520
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: TextField(
                      key: const ValueKey('engine-model-lichess-max-games'),
                      controller: maxGamesController,
                      keyboardType: TextInputType.number,
                      onChanged: onMaxGamesChanged,
                      decoration: const InputDecoration(
                        labelText: 'Max games',
                        prefixIcon: Icon(Icons.format_list_numbered_rounded),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _ModelBuildChoiceMenu<String>(
                      key: const ValueKey('engine-model-lichess-speed'),
                      label: 'Speed',
                      value: speed,
                      values: const [
                        '',
                        'bullet',
                        'blitz',
                        'rapid',
                        'classical',
                      ],
                      labelFor: (value) => value.isEmpty
                          ? 'Any speed'
                          : value[0].toUpperCase() + value.substring(1),
                      onChanged: onSpeedChanged,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: TextField(
                      key: const ValueKey('engine-model-lichess-since'),
                      controller: sinceController,
                      keyboardType: TextInputType.text,
                      onChanged: onSinceChanged,
                      decoration: const InputDecoration(
                        labelText: 'Since',
                        hintText: 'Optional date or text',
                        prefixIcon: Icon(Icons.date_range_rounded),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: TextField(
                      key: const ValueKey('engine-model-lichess-until'),
                      controller: untilController,
                      keyboardType: TextInputType.text,
                      onChanged: onUntilChanged,
                      decoration: const InputDecoration(
                        labelText: 'Until',
                        hintText: 'Optional date or text',
                        prefixIcon: Icon(Icons.event_rounded),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _ModelBuildChoiceMenu<String>(
                      key: const ValueKey('engine-model-lichess-rated'),
                      label: 'Rated',
                      value: rated,
                      values: const ['', 'true', 'false'],
                      labelFor: (value) => switch (value) {
                        'true' => 'Rated only',
                        'false' => 'Casual only',
                        _ => 'Rated and casual',
                      },
                      onChanged: onRatedChanged,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _ModelBuildChoiceMenu<String>(
                      key: const ValueKey('engine-model-lichess-color'),
                      label: 'Color',
                      value: color,
                      values: const ['', 'white', 'black'],
                      labelFor: (value) => switch (value) {
                        'white' => 'White games',
                        'black' => 'Black games',
                        _ => 'Any color',
                      },
                      onChanged: onColorChanged,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          _WrapSafeOutlinedButton(
            key: const ValueKey('engine-model-lichess-preview'),
            onPressed: previewing ? null : onPreview,
            icon: Icons.travel_explore_rounded,
            busy: previewing,
            label: previewing ? 'Checking games' : 'Preview games',
          ),
          if (preview != null) ...[
            const SizedBox(height: 8),
            _PreviewLine(
              label: 'Loaded ${preview!.gameCount} games',
              detail: hasMore
                  ? '${preview!.sourceLabel} / more pages available'
                  : preview!.sourceLabel,
            ),
            const SizedBox(height: 8),
            _WrapSafeOutlinedButton(
              key: const ValueKey('engine-model-lichess-preview-pgn'),
              onPressed: onOpenPreview,
              icon: Icons.article_rounded,
              label: 'Preview found games',
            ),
          ],
        ],
      ),
    );
  }
}

class _PgnFilesSourcePanel extends StatelessWidget {
  const _PgnFilesSourcePanel({
    required this.fileImportAvailable,
    required this.loading,
    required this.gameCount,
    required this.sourceLabel,
    required this.onChooseFiles,
  });

  final bool fileImportAvailable;
  final bool loading;
  final int gameCount;
  final String? sourceLabel;
  final VoidCallback onChooseFiles;

  @override
  Widget build(BuildContext context) {
    return _SourcePanelShell(
      key: const ValueKey('pgn-files-source'),
      icon: Icons.folder_open_rounded,
      title: 'Choose PGN files',
      body:
          'Desktop can select one multi-game PGN or multiple single-game PGNs. The app merges them before upload.',
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WrapSafeOutlinedButton(
            onPressed: loading || !fileImportAvailable ? null : onChooseFiles,
            icon: Icons.upload_file_rounded,
            busy: loading,
            label: loading ? 'Reading files' : 'Choose PGN files',
          ),
          if (gameCount > 0) ...[
            const SizedBox(height: 8),
            _PreviewLine(
              label: 'Detected $gameCount games',
              detail: sourceLabel ?? 'Selected PGN files',
            ),
          ],
        ],
      ),
    );
  }
}

class _SourcePanelShell extends StatelessWidget {
  const _SourcePanelShell({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(body),
          const SizedBox(height: 10),
          action,
        ],
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.label, required this.detail});

  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.fact_check_rounded, color: scheme.secondary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelBuildCountBanner extends StatelessWidget {
  const _ModelBuildCountBanner({required this.gameCount});

  final int gameCount;

  @override
  Widget build(BuildContext context) {
    final recommended = isModelBuildGameCountRecommended(gameCount);
    final submittable = isModelBuildGameCountSubmittable(gameCount);
    final scheme = Theme.of(context).colorScheme;
    final color = recommended
        ? scheme.primary
        : submittable
            ? const Color(0xFFB7791F)
            : scheme.error;
    final text = recommended
        ? '$gameCount games ready'
        : submittable
            ? '$gameCount games ready / $modelBuildRecommendedGameCount+ recommended'
            : gameCount > modelBuildMaximumGameCount
                ? '$gameCount games / maximum $modelBuildMaximumGameCount'
                : '$gameCount games / minimum $modelBuildMinimumGameCount';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            submittable
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelBuildPreviewGame {
  const _ModelBuildPreviewGame({
    required this.pgn,
    required this.headers,
    required this.fen,
  });

  final String pgn;
  final Map<String, String> headers;
  final String fen;

  String get white => _header('White', fallback: 'White');
  String get black => _header('Black', fallback: 'Black');
  String get mode {
    final event = _header('Event');
    if (event.toLowerCase().contains('otb')) return 'OTB';
    if (event.toLowerCase().contains('bot')) return 'Bot';
    if (_header('Site').toLowerCase().contains('lichess')) return 'Lichess';
    return event.isEmpty ? 'Bot' : event;
  }

  String get time => _header('TimeControl', fallback: '10+5');
  String get date {
    final value = _header('Date');
    if (value.isEmpty || value == '????.??.??') return 'Unknown';
    return value.replaceAll('.', '-');
  }

  String get location {
    final site = _header('Site');
    if (site.isEmpty || site == '?' || site == '-') return 'Chessnut App';
    return site;
  }

  String _header(String name, {String fallback = ''}) {
    final value = headers[name]?.trim() ?? '';
    return value.isEmpty ? fallback : value;
  }
}

class _ModelBuildPreviewGameTile extends StatelessWidget {
  const _ModelBuildPreviewGameTile({required this.game});

  final _ModelBuildPreviewGame game;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const boardSize = 82.0;
    return Container(
      key: const ValueKey('engine-model-preview-game-tile'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox.square(
              dimension: boardSize,
              child: ChessBoard(
                pieces: _previewPiecesFromFen(game.fen),
                size: boardSize,
                targets: const [],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'White: ${game.white} / Black: ${game.black}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${game.mode} / Time: ${game.time}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  'Date: ${game.date}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Location: ${game.location}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelBuildPreviewSampleNotice extends StatelessWidget {
  const _ModelBuildPreviewSampleNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: scheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

_ModelBuildPreviewGame _previewGameFromRecord(GameRecord record) {
  final pgn = record.pgn.trim();
  return _ModelBuildPreviewGame(
    pgn: pgn,
    headers: _previewHeadersFromPgn(pgn),
    fen: _previewFinalFenFromPgn(pgn),
  );
}

Map<String, String> _previewHeadersFromPgn(String pgn) {
  final headers = <String, String>{};
  final matcher = RegExp(r'^\[([A-Za-z0-9_]+)\s+"(.*)"\]$', multiLine: true);
  for (final match in matcher.allMatches(pgn)) {
    headers[match.group(1)!] = match.group(2) ?? '';
  }
  return headers;
}

String _previewFinalFenFromPgn(String pgn) {
  try {
    final game = dc.PgnGame.parsePgn(pgn);
    var position = dc.PgnGame.startingPosition(game.headers);
    for (final node in game.moves.mainline()) {
      final move = position.parseSan(node.san);
      if (move == null) break;
      position = position.play(move);
    }
    return position.fen;
  } catch (_) {
    return standardStartFen;
  }
}

List<BoardPiece> _previewPiecesFromFen(String fen) {
  return ChessBoardState.fromFen(fen)
      .pieces
      .entries
      .map((entry) => BoardPiece(entry.key, entry.value))
      .toList(growable: false);
}

class _DeletePersonalEngineDialog extends StatelessWidget {
  const _DeletePersonalEngineDialog({required this.job});

  final _EngineTrainingJob job;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppDialogShell(
      icon: Icons.delete_outline_rounded,
      title: 'Delete personal engine?',
      subtitle: job.title,
      actions: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ),
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('personal-engine-delete-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
          ),
        ),
      ],
      child: Text(
        'This removes the training record from your Chessnut account. If this engine was downloaded for Bot game, it will also be removed from the local engine library. This action cannot be undone.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _TrainingDetailsDialog extends StatefulWidget {
  const _TrainingDetailsDialog({
    required this.job,
    required this.onRename,
    required this.onOpenReport,
    required this.onDelete,
  });

  final _EngineTrainingJob job;
  final Future<bool> Function(_EngineTrainingJob job, String title) onRename;
  final ValueChanged<_EngineTrainingJob> onOpenReport;
  final Future<bool> Function(_EngineTrainingJob job) onDelete;

  @override
  State<_TrainingDetailsDialog> createState() => _TrainingDetailsDialogState();
}

class _TrainingDetailsDialogState extends State<_TrainingDetailsDialog> {
  late final TextEditingController titleController;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.job.title);
    titleController.addListener(_handleTitleChanged);
  }

  @override
  void dispose() {
    titleController
      ..removeListener(_handleTitleChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTitleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _saveName() async {
    if (saving || !_canSaveName) return;
    setState(() => saving = true);
    final saved = await widget.onRename(widget.job, titleController.text);
    if (!mounted) return;
    setState(() => saving = false);
    if (saved) {
      Navigator.of(context).pop();
    }
  }

  bool get _canSaveName {
    final next = titleController.text.trim();
    return next.isNotEmpty && next != widget.job.title.trim();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      icon: Icons.info_outline_rounded,
      title: 'Engine Details',
      subtitle: widget.job.title,
      actions: [
        OutlinedButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: saving || !widget.job.completed
              ? null
              : () => widget.onOpenReport(widget.job),
          icon: const Icon(Icons.analytics_rounded),
          label: const Text('Open report'),
        ),
      ],
      child: _TrainingDetails(
        job: widget.job,
        titleController: titleController,
        saving: saving,
        canSaveName: _canSaveName,
        onSaveName: _saveName,
        onDelete: saving ? null : () => widget.onDelete(widget.job),
      ),
    );
  }
}

class _TrainingDetails extends StatelessWidget {
  const _TrainingDetails({
    required this.job,
    required this.titleController,
    required this.saving,
    required this.canSaveName,
    required this.onSaveName,
    required this.onDelete,
  });

  final _EngineTrainingJob job;
  final TextEditingController titleController;
  final bool saving;
  final bool canSaveName;
  final VoidCallback? onSaveName;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = switch (job.status) {
      _TrainingStatus.completed => scheme.primary,
      _TrainingStatus.training => scheme.secondary,
      _TrainingStatus.queued => const Color(0xFFF59E0B),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassPanel(
          padding: const EdgeInsets.all(12),
          borderRadius: 14,
          tint: statusColor.withValues(alpha: 0.07),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('personal-engine-name-field'),
                      controller: titleController,
                      enabled: !saving,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => onSaveName?.call(),
                      decoration: const InputDecoration(
                        labelText: 'Engine name',
                        prefixIcon: Icon(Icons.memory_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusPill(label: job.statusLabel, color: statusColor),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                job.detailsDescription,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('personal-engine-name-save'),
                    onPressed: canSaveName && !saving ? onSaveName : null,
                    icon: saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(saving ? 'Saving' : 'Save name'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ResponsiveGrid(
          minTileWidth: 150,
          maxColumns: _trainingDetailColumns(context),
          spacing: 10,
          childAspectRatio: _trainingDetailAspectRatio(context),
          children: [
            _TrainingDetailTile(
              label: 'Source',
              value: job.sourceLabel,
              icon: Icons.person_search_rounded,
            ),
            _TrainingDetailTile(
              label: 'Training games',
              value: job.gameCount > 0 ? '${job.gameCount}' : 'Selected games',
              icon: Icons.sports_esports_rounded,
            ),
            _TrainingDetailTile(
              label: 'Created',
              value: _formatTrainingTimestamp(job.createdAt),
              icon: Icons.event_available_rounded,
            ),
            _TrainingDetailTile(
              label: 'Updated',
              value: _formatTrainingTimestamp(job.updatedAt),
              icon: Icons.update_rounded,
            ),
            _TrainingDetailTile(
              label: 'Model accuracy',
              value: job.modelAccuracy > 0 ? _percent(job.modelAccuracy) : '-',
              icon: Icons.verified_rounded,
            ),
          ],
        ),
        if (job.styleTags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in job.styleTags)
                _MetaChip(icon: Icons.sell_rounded, label: tag),
            ],
          ),
        ],
      ],
    );
  }
}

class _TrainingDetailTile extends StatelessWidget {
  const _TrainingDetailTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      padding: const EdgeInsets.all(10),
      borderRadius: 12,
      tint: scheme.surfaceContainerHighest.withValues(alpha: 0.18),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: scheme.primary),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '-' : value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

int _trainingDetailColumns(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (_useEngineLabLandscapeGrid(context, width)) return 3;
  if (width < 430) return 1;
  return 2;
}

double _trainingDetailAspectRatio(BuildContext context) {
  final columns = _trainingDetailColumns(context);
  if (columns == 1) return 4.4;
  if (columns == 3) return 2.45;
  return 2.35;
}

class _TrainingReport extends StatelessWidget {
  const _TrainingReport({required this.job});

  final _EngineTrainingJob job;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassPanel(
          padding: const EdgeInsets.all(12),
          borderRadius: 14,
          tint: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.07),
          child: Text(
            'Chessnut checks your uploaded games for style consistency and keeps a separate quality check set before the model is offered for play.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 12),
        ResponsiveGrid(
          minTileWidth: 128,
          maxColumns: 3,
          spacing: 10,
          childAspectRatio: 0.76,
          children: [
            _ReportMetricCard(
              title: 'Model Accuracy',
              value: job.modelAccuracy,
              target: '> 50%',
              icon: Icons.verified_rounded,
              color: Theme.of(context).colorScheme.primary,
              description:
                  'Expected move prediction quality on games kept out of training.',
            ),
            _ReportMetricCard(
              title: 'Model Fitting Degree',
              value: job.modelFitting,
              target: '95% ± 5%',
              icon: Icons.tune_rounded,
              color: const Color(0xFFF59E0B),
              description: 'Whether the uploaded games follow one clear style.',
            ),
            _ReportMetricCard(
              title: 'Data Effectiveness',
              value: job.dataEffectiveness,
              target: '95% ± 5%',
              icon: Icons.dataset_rounded,
              color: Theme.of(context).colorScheme.secondary,
              description:
                  'How useful the held-out games are for checking the model.',
            ),
          ],
        ),
        if (job.pgnSamples.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'PGN samples',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          for (final sample in job.pgnSamples) ...[
            _PgnSampleCard(sample: sample),
            if (sample != job.pgnSamples.last) const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _ReportMetricCard extends StatelessWidget {
  const _ReportMetricCard({
    required this.title,
    required this.value,
    required this.target,
    required this.icon,
    required this.color,
    required this.description,
  });

  final String title;
  final double value;
  final String target;
  final IconData icon;
  // Kept for older call sites; the displayed color follows the quality score.
  // ignore: unused_field
  final Color color;
  final String description;

  @override
  Widget build(BuildContext context) {
    final qualityColor = _qualityColor(context, value);
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      tint: qualityColor.withValues(alpha: 0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: qualityColor, size: 19),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatPercent(value),
            style: TextStyle(
              color: qualityColor,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: value.clamp(0, 1),
            minHeight: 6,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: qualityColor.withValues(alpha: 0.13),
            valueColor: AlwaysStoppedAnimation<Color>(qualityColor),
          ),
          const SizedBox(height: 6),
          Text(
            'Target $target',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: qualityColor),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PgnSampleCard extends StatelessWidget {
  const _PgnSampleCard({required this.sample});

  final _ReportPgnSample sample;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(11),
      borderRadius: 13,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sample.name,
              style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < sample.moves.length; i++)
                _MoveChip(
                  move: sample.moves[i],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoveChip extends StatelessWidget {
  const _MoveChip({required this.move});

  final String move;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        move,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _ScoreDial extends StatelessWidget {
  const _ScoreDial({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: value,
                strokeWidth: 8,
                backgroundColor: color.withValues(alpha: 0.13),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatPercent(value),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 10.5,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                'Report generated from your training games and quality checks.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.visible,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? math.min(constraints.maxWidth, 280.0)
            : 280.0;
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.14)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(icon, size: 14, color: color),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _formatPercent(double value) => _percent(value);

String _percent(double value) => '${(value * 100).toStringAsFixed(1)}%';

Color _qualityColor(BuildContext context, double value) {
  final scheme = Theme.of(context).colorScheme;
  if (value >= 0.85) return scheme.primary;
  if (value >= 0.70) return const Color(0xFFEAB308);
  if (value >= 0.50) return const Color(0xFFF97316);
  return const Color(0xFFEF4444);
}

({double modelAccuracy, double modelFitting, double dataEffectiveness})
    _metricsFromAnalyzeData(String raw) {
  if (raw.trim().isEmpty) {
    return (
      modelAccuracy: 0,
      modelFitting: 0,
      dataEffectiveness: 0,
    );
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return (
        modelAccuracy: _metricValue(decoded['TestCorrect']),
        modelFitting: _metricValue(decoded['TestRepeatiion']),
        dataEffectiveness: _metricValue(decoded['TrainCorrect']),
      );
    }
  } catch (_) {
    // Bad backend analysis data should not become a fake quality report.
  }
  return (
    modelAccuracy: 0,
    modelFitting: 0,
    dataEffectiveness: 0,
  );
}

double _metricValue(Object? value) {
  final raw = switch (value) {
    num() => value.toDouble(),
    _ => double.tryParse(
        (value?.toString() ?? '').trim().replaceAll('%', ''),
      ),
  };
  if (raw == null || raw.isNaN || raw.isInfinite || raw <= 0) return 0;
  if (raw > 1) return (raw / 100).clamp(0, 1);
  return raw.clamp(0, 1);
}

String _personalEngineSource(TrainModel model) {
  if (model.sourceLabel.trim().isNotEmpty) return model.sourceLabel.trim();
  if (model.playerName.trim().isNotEmpty) {
    return "${model.playerName.trim()}'s games";
  }
  final remark = model.remark.trim();
  if (_looksLikeUrl(remark)) return 'Imported training games';
  if (remark.toLowerCase().contains('lichess')) return 'Lichess games';
  if (remark.toLowerCase().contains('game record')) {
    return 'Chessnut game records';
  }
  if (remark.toLowerCase().contains('pgn')) return 'Imported PGN batch';
  if (model.rawFile.trim().isNotEmpty) {
    final raw = model.rawFile.trim();
    if (_looksLikeUrl(raw)) return 'Imported PGN batch';
    if (raw.toLowerCase().contains('lichess')) return 'Lichess games';
    return 'Imported PGN batch';
  }
  if (model.sharedName.trim().isNotEmpty) return model.sharedName.trim();
  return 'Chessnut training games';
}

int _personalEngineGameCount(TrainModel model) {
  if (model.gameCount > 0) return model.gameCount;
  if (model.analyzePgn.isNotEmpty) return model.analyzePgn.length;
  final match = RegExp(r'(\d{2,5})\s*(games|game)', caseSensitive: false)
      .firstMatch('${model.title} ${model.remark} ${model.rawFile}');
  return int.tryParse(match?.group(1) ?? '') ?? 0;
}

String _personalEngineDescription({
  required TrainModel model,
  required String source,
  required int gameCount,
  required ({
    double modelAccuracy,
    double modelFitting,
    double dataEffectiveness,
  }) metrics,
}) {
  final parts = <String>[];
  if (gameCount > 0) {
    parts.add('Trained from $gameCount games');
  } else {
    parts.add('Trained from selected games');
  }
  parts.add('Source: $source');
  if (metrics.modelAccuracy > 0) {
    parts.add('Model accuracy ${_percent(metrics.modelAccuracy)}');
  } else if (model.trainStatus == 2) {
    parts.add('Ready for Bot game');
  } else if (model.trainStatus == 1) {
    parts.add('Training in cloud');
  } else {
    parts.add('Waiting for training');
  }
  return '${parts.join(' / ')}.';
}

String _personalEngineDetailDescription(
  TrainModel model,
  String fallbackDescription,
) {
  final remark = model.remark.trim();
  if (remark.isNotEmpty && !_looksLikeUrl(remark)) return remark;
  return fallbackDescription;
}

List<String> _personalEngineTags(TrainModel model) {
  if (model.tags.isNotEmpty) return model.tags;
  final text = '${model.title} ${model.remark} ${model.rawFile}'.toLowerCase();
  final tags = <String>[];
  void addIf(bool condition, String label) {
    if (condition && !tags.contains(label)) tags.add(label);
  }

  addIf(text.contains('rapid'), 'Rapid');
  addIf(text.contains('blitz'), 'Blitz');
  addIf(text.contains('bullet'), 'Bullet');
  addIf(text.contains('otb'), 'OTB');
  addIf(text.contains('lichess'), 'Lichess');
  addIf(text.contains('endgame'), 'Endgame');
  addIf(text.contains('sicilian') || text.contains('najdorf'), 'Opening');
  addIf(text.contains('pgn'), 'PGN');
  if (tags.isEmpty) tags.add('Personal style');
  return tags;
}

String _curatedEngineDescription(TrainModel model) {
  final remark = model.remark.trim();
  final readableRemark = _readableCuratedRemark(remark);
  if (readableRemark.isNotEmpty) {
    return '$readableRemark Provided by Chessnut for Bot game use.';
  }
  return 'Popular LC0 community weight selected and packaged by Chessnut for Bot game play.';
}

String _formatTrainingTimestamp(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '-';
  final parsed = DateTime.tryParse(trimmed);
  if (parsed == null) return trimmed;
  String two(int number) => number.toString().padLeft(2, '0');
  return '${parsed.year}-${two(parsed.month)}-${two(parsed.day)} '
      '${two(parsed.hour)}:${two(parsed.minute)}';
}

String _readableCuratedRemark(String remark) {
  final trimmed = remark.trim();
  if (trimmed.isEmpty || _looksLikeUrl(trimmed)) return '';
  final withoutRef = trimmed.replaceFirst(
    RegExp(r'^Ref:\s*https?://\S+\s*', caseSensitive: false),
    '',
  );
  final cleaned = withoutRef
      .replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.isEmpty || _looksLikeUrl(cleaned)) return '';
  return cleaned;
}

bool _looksLikeUrl(String value) {
  final lower = value.trim().toLowerCase();
  return lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.contains('.pb.gz') ||
      lower.contains('.onnx') ||
      lower.contains('.model');
}

List<String> _movesFromPgn(String pgn) {
  final cleaned = pgn
      .replaceAll(RegExp(r'\{[^}]*\}'), ' ')
      .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
      .replaceAll(RegExp(r'\d+\.(\.\.)?'), ' ')
      .replaceAll(RegExp(r'1-0|0-1|1/2-1/2|\*'), ' ');
  return cleaned
      .split(RegExp(r'\s+'))
      .where((item) => item.trim().isNotEmpty)
      .take(10)
      .toList();
}
