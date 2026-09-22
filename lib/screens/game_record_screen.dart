import 'dart:async';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

import '../l10n/game_record_strings.dart';
import '../l10n/localized_material.dart';

import '../models/app_models.dart';
import '../services/analysis_report_cache_service.dart';
import '../services/chessnut_api_client.dart';
import '../services/game_record_filter.dart';
import '../services/game_record_repository.dart';
import '../services/game_record_save_service.dart';
import '../services/local_game_record_store.dart';
import 'local_game_records_screen.dart';
import '../services/game_notation_service.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_feedback.dart';
import '../widgets/chess_board.dart';
import '../widgets/chessnut_motion.dart';
import '../widgets/game_record_tile.dart';

typedef AnalyzeRecordCallback = FutureOr<void> Function(GameRecord record);
typedef ContinueRecordCallback = FutureOr<void> Function(GameRecord record);
typedef DeleteRecordCallback = Future<ApiResult<bool>> Function(
  GameRecord record,
);
typedef EndRecordCallback = Future<ApiResult<bool>> Function(GameRecord record);
typedef RefreshRecordPgnCallback = Future<ApiResult<GameRecord>> Function(
  GameRecord record,
);
typedef LoadRecordPageCallback = Future<void> Function(int page);
typedef GameRecordRemoteSearchCallback = Future<GameRecordRemoteSearchResult>
    Function(
  GameRecordFilter filter,
  int page,
  int count,
);
typedef HistoryPgnFetchCallback = Future<List<String>> Function(
  LichessHistoryImportOptions options,
);
typedef HistoryPgnBatchImportCallback = Future<ApiResult<int>> Function(
  String pgnList,
  String source,
);
const int historyPgnBatchLimit = 500;
typedef LichessHistoryImportStartCallback = Future<ApiResult<LichessImportJob>>
    Function(
  LichessHistoryImportOptions options,
);
typedef LichessHistoryImportStatusCallback = Future<ApiResult<LichessImportJob>>
    Function(String jobId);
typedef LichessHistoryImportCancelCallback = Future<ApiResult<LichessImportJob>>
    Function(String jobId);

class LichessHistoryImportOptions {
  const LichessHistoryImportOptions({
    required this.playerId,
    this.maxGames = 200,
    this.since = '',
    this.until = '',
    this.speed = '',
    this.rated = '',
    this.color = '',
  });

  final String playerId;
  final int maxGames;
  final String since;
  final String until;
  final String speed;
  final String rated;
  final String color;
}

enum RecordSourceTab { all, local, lichess, chesscom }

class GameRecordScreen extends StatefulWidget {
  const GameRecordScreen({
    required this.signedIn,
    required this.records,
    required this.onNavigate,
    required this.onAnalyzeRecord,
    this.currentSession,
    this.localStore,
    this.recordSaveService,
    this.localUserId,
    this.onContinueRecord,
    this.onDeleteRecord,
    this.onEndRecord,
    this.onRefreshRecordPgn,
    this.loading = false,
    this.loadingMoreRecords = false,
    this.hasMoreRecords = false,
    this.currentPage = 1,
    this.totalPage = 1,
    this.totalCount = 0,
    this.sourceCounts,
    this.errorMessage,
    this.onRefresh,
    this.onAutoRefreshCurrentPage,
    this.onLoadRecordPage,
    this.onImportPgnFile,
    this.onSearchRemoteRecords,
    this.onFetchLichessGames,
    this.onFetchChessComGames,
    this.onImportHistoryPgnBatch,
    this.onStartLichessHistoryImport,
    this.onCheckLichessHistoryImport,
    this.onCancelLichessHistoryImport,
    this.onStartChessComHistoryImport,
    this.onCheckChessComHistoryImport,
    this.onCancelChessComHistoryImport,
    this.reportStatuses = const {},
    this.isChessnutClockDevice = false,
    super.key,
  });

  final bool signedIn;
  final LocalGameRecordStore? localStore;
  final GameRecordSaveService? recordSaveService;
  final int? localUserId;
  final List<GameRecord> records;
  final ValueChanged<String> onNavigate;
  final AnalyzeRecordCallback onAnalyzeRecord;
  final ChessnutLoginSession? currentSession;
  final ContinueRecordCallback? onContinueRecord;
  final DeleteRecordCallback? onDeleteRecord;
  final EndRecordCallback? onEndRecord;
  final RefreshRecordPgnCallback? onRefreshRecordPgn;
  final bool loading;
  final bool loadingMoreRecords;
  final bool hasMoreRecords;
  final int currentPage;
  final int totalPage;
  final int totalCount;
  final Map<RecordSourceTab, int>? sourceCounts;
  final String? errorMessage;
  final Future<void> Function()? onRefresh;
  final Future<void> Function()? onAutoRefreshCurrentPage;
  final LoadRecordPageCallback? onLoadRecordPage;
  final FutureOr<void> Function()? onImportPgnFile;
  final GameRecordRemoteSearchCallback? onSearchRemoteRecords;
  final HistoryPgnFetchCallback? onFetchLichessGames;
  final HistoryPgnFetchCallback? onFetchChessComGames;
  final HistoryPgnBatchImportCallback? onImportHistoryPgnBatch;
  final LichessHistoryImportStartCallback? onStartLichessHistoryImport;
  final LichessHistoryImportStatusCallback? onCheckLichessHistoryImport;
  final LichessHistoryImportCancelCallback? onCancelLichessHistoryImport;
  final LichessHistoryImportStartCallback? onStartChessComHistoryImport;
  final LichessHistoryImportStatusCallback? onCheckChessComHistoryImport;
  final LichessHistoryImportCancelCallback? onCancelChessComHistoryImport;
  final Map<String, GameAnalysisReportStatus> reportStatuses;
  final bool isChessnutClockDevice;

  @override
  State<GameRecordScreen> createState() => _GameRecordScreenState();
}

class _GameRecordScreenState extends State<GameRecordScreen>
    with WidgetsBindingObserver {
  static const _autoRefreshInterval = Duration(seconds: 10);
  final ScrollController _scrollController = ScrollController();
  Timer? _autoRefreshTimer;
  bool _autoRefreshInFlight = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  GameRecordFilter filter = const GameRecordFilter();
  RecordSourceTab sourceTab = RecordSourceTab.all;
  int? continuingRecordId;
  String? deletingRecordKey;
  String? refreshingPgnRecordKey;
  final deletedRecordKeys = <String>{};
  static const int _remotePageSize = 10;
  GameRecordRemoteSearchResult? remoteSearch;
  bool remoteSearchLoading = false;
  String? remoteSearchError;
  LichessImportJob? importJob;
  bool importRunning = false;
  bool importCanceling = false;
  String? importError;
  bool filtersExpanded = false;
  bool selectionMode = false;
  bool batchDeleting = false;
  int _remoteSearchGeneration = 0;
  String importSourceLabel = 'Lichess';
  final selectedRecordKeys = <String>{};
  bool? _showLocalGames;
  static const _archiveSelectionKey = 'game-record-archive-selection';
  bool get _localSelected => _showLocalGames ?? !widget.signedIn;

  List<GameRecord> get filteredRecords {
    final sourceRecords = remoteSearch?.records ?? widget.records;
    // Remote searches are already filtered by the API. Keep the response
    // intact; PGN hydration must not re-run client-side filters on placeholders.
    if (remoteSearch != null) {
      return sourceRecords
          .where(
            (record) =>
                !deletedRecordKeys.contains(_recordSelectionKey(record)),
          )
          .toList(growable: false);
    }
    final query = filter.query.trim().toLowerCase();
    final items = sourceRecords.where((record) {
      if (deletedRecordKeys.contains(_recordSelectionKey(record))) return false;
      if (!_matchesSourceTab(record)) return false;
      if (!_matchesMode(record)) return false;
      if (!_matchesResult(record)) return false;
      if (!_matchesColor(record)) return false;
      if (!_matchesSpeed(record)) return false;
      if (!_matchesReport(record)) return false;
      if (filter.onlyAnalyzed &&
          !gameAnalysisReportStatusForRecord(record, widget.reportStatuses)
              .hasAny) {
        return false;
      }
      if (filter.minMoves > 0 && record.fullMoveCount < filter.minMoves) {
        return false;
      }
      if (query.isNotEmpty) {
        final haystack = [
          record.title,
          record.subtitle,
          record.playerSummary,
          record.timeSummary,
          record.dateSummary,
          record.locationSummary,
          record.resultLabel,
          record.whiteName,
          record.blackName,
          record.opponentName,
          record.openingLabel,
          record.playMode,
        ].join(' ').toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      return true;
    }).toList();
    items.sort((a, b) => _compareRecords(a, b, filter.sort));
    return items;
  }

  int _sourceCount(RecordSourceTab tab) {
    var count = _loadedSourceCount(tab);
    final sourceCount = widget.sourceCounts?[tab];
    if (sourceCount != null && sourceCount > count) {
      count = sourceCount;
    }
    if (tab == sourceTab) {
      final remoteTotal = remoteSearch?.total;
      if (remoteTotal != null && remoteTotal > count) {
        count = remoteTotal;
      }
    }
    return count;
  }

  int _loadedSourceCount(RecordSourceTab tab) {
    return activeRecords
        .where((record) => _matchesSourceTab(record, tab))
        .length;
  }

  int _compareRecords(
    GameRecord a,
    GameRecord b,
    RecordSortMode sortMode,
  ) {
    final aTime = a.sortAt;
    final bTime = b.sortAt;
    if (aTime != null && bTime != null) {
      final compared = aTime.compareTo(bTime);
      if (compared != 0) {
        return sortMode == RecordSortMode.oldest ? compared : -compared;
      }
    } else if (aTime != null || bTime != null) {
      final compared = aTime == null ? 1 : -1;
      return sortMode == RecordSortMode.oldest ? -compared : compared;
    }

    final aId = a.pgnId ?? 0;
    final bId = b.pgnId ?? 0;
    final idCompared = aId.compareTo(bId);
    if (idCompared != 0) {
      return sortMode == RecordSortMode.oldest ? idCompared : -idCompared;
    }
    return 0;
  }

  List<GameRecord> get activeRecords => remoteSearch?.records ?? widget.records;

  bool get showingRemoteResults => remoteSearch != null;

  bool get _canLoadPreviousRemotePage =>
      remoteSearch != null &&
      !remoteSearchLoading &&
      remoteSearch!.page > 1 &&
      widget.onSearchRemoteRecords != null;

  bool get _canLoadNextRemotePage =>
      remoteSearch != null &&
      !remoteSearchLoading &&
      remoteSearch!.page < remoteSearch!.totalPage &&
      widget.onSearchRemoteRecords != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.onAutoRefreshCurrentPage == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_autoRefreshCurrentRecords());
    });
    _autoRefreshTimer = Timer.periodic(
      _autoRefreshInterval,
      (_) => unawaited(_autoRefreshCurrentRecords()),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_showLocalGames != null || widget.localStore == null) return;
    final storage = PageStorage.maybeOf(context);
    _showLocalGames = storage?.readState(context,
            identifier: _archiveSelectionKey) as bool? ??
        !widget.signedIn;
    storage?.writeState(context, _showLocalGames,
        identifier: _archiveSelectionKey);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _autoRefreshCurrentRecords() async {
    if ((widget.localStore != null && _localSelected) ||
        !widget.signedIn ||
        _lifecycleState != AppLifecycleState.resumed ||
        _autoRefreshInFlight ||
        widget.loading ||
        widget.loadingMoreRecords ||
        remoteSearchLoading) {
      return;
    }
    _autoRefreshInFlight = true;
    try {
      if (remoteSearch != null) {
        await _searchRemoteRecords(page: remoteSearch!.page, silent: true);
      } else {
        await widget.onAutoRefreshCurrentPage?.call();
      }
    } finally {
      _autoRefreshInFlight = false;
    }
  }

  Future<void> _refreshAfterLocalUpload() async {
    if (!mounted || !widget.signedIn) return;
    final userId = widget.recordSaveService?.apiClient.session?.userId;
    await widget.onRefresh?.call();
    if (!mounted ||
        widget.recordSaveService?.apiClient.session?.userId != userId) {
      return;
    }
    // A retained server-side search takes precedence over widget.records.
    // Refresh that result too, including an earlier search still in flight.
    if (remoteSearch != null || remoteSearchLoading) {
      await _searchRemoteRecords(page: 1);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      unawaited(_autoRefreshCurrentRecords());
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.localStore;
    final service = widget.recordSaveService;
    if (store == null || service == null) return _buildRemote(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
                value: true,
                label: Text('Local games'),
                icon: Icon(Icons.phone_android_rounded)),
            ButtonSegment(
                value: false,
                label: Text('Cloud games'),
                icon: Icon(Icons.cloud_outlined)),
          ],
          selected: {_localSelected},
          onSelectionChanged: (selection) {
            setState(() => _showLocalGames = selection.first);
            PageStorage.maybeOf(context)?.writeState(context, _showLocalGames,
                identifier: _archiveSelectionKey);
          },
        ),
      ),
      Expanded(
          child: _localSelected
              ? LocalGameRecordsScreen(
                  store: store,
                  saveService: service,
                  userId: widget.localUserId,
                  onNavigate: widget.onNavigate,
                  onReview: widget.onAnalyzeRecord,
                  onContinue: widget.onContinueRecord,
                  onUploaded: _refreshAfterLocalUpload,
                  isChessnutClockDevice: widget.isChessnutClockDevice,
                )
              : _buildRemote(context)),
    ]);
  }

  Widget _buildRemote(BuildContext context) {
    final visibleRecords = filteredRecords;
    final canSelectRecords = widget.signedIn &&
        widget.onDeleteRecord != null &&
        visibleRecords.any(
          (record) => !deletedRecordKeys.contains(_recordSelectionKey(record)),
        );
    return ResponsivePage(
      scrollController: _scrollController,
      children: (context, spec) => [
        ScreenHeader(
          title: 'Game records',
          subtitle: 'PGN archive',
          leading: IconButton.filledTonal(
            onPressed: () => widget.onNavigate('Back'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _GameRecordImportMenu(
                importRunning: importRunning,
                onImportPgn: widget.signedIn && widget.onImportPgnFile != null
                    ? _importPgnFile
                    : null,
                onImportLichess: widget.signedIn &&
                        (widget.onFetchLichessGames != null ||
                            widget.onStartLichessHistoryImport != null)
                    ? _showLichessImportDialog
                    : null,
                onImportChessCom: widget.signedIn &&
                        (widget.onFetchChessComGames != null ||
                            widget.onStartChessComHistoryImport != null)
                    ? _showChessComImportDialog
                    : null,
              ),
              if (canSelectRecords) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const ValueKey('game-record-select-mode'),
                  tooltip: selectionMode
                      ? 'Exit record selection'
                      : 'Select records',
                  onPressed:
                      selectionMode ? _exitSelectionMode : _enterSelectionMode,
                  icon: Icon(selectionMode
                      ? Icons.close_rounded
                      : Icons.checklist_rounded),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: spec.gutter),
        if (widget.signedIn) ...[
          _SourceTabs(
            key: const ValueKey('game-record-source-tabs'),
            selected: sourceTab,
            counts: {
              for (final tab in RecordSourceTab.values) tab: _sourceCount(tab),
            },
            onChanged: _selectSourceTab,
          ),
          SizedBox(height: spec.gutter),
        ],
        SectionColumn(
          spacing: 8,
          children: [
            if (widget.signedIn)
              _FilterPanel(
                filter: filter,
                expanded: filtersExpanded,
                isChessnutClockDevice: widget.isChessnutClockDevice,
                activeCount: _activeFilterCount,
                showingRemoteResults: showingRemoteResults,
                remoteSearch: remoteSearch,
                remoteSearchLoading: remoteSearchLoading,
                remoteSearchError: remoteSearchError,
                importJob: importJob,
                importRunning: importRunning,
                importCanceling: importCanceling,
                importError: importError,
                importSourceLabel: importSourceLabel,
                onSearchAll: widget.onSearchRemoteRecords == null
                    ? null
                    : () => _searchRemoteRecords(page: 1),
                onClearRemote: showingRemoteResults ? _clearRemoteSearch : null,
                onCancelImport:
                    _currentCancelImportCallback == null ? null : _cancelImport,
                onToggleExpanded: () =>
                    setState(() => filtersExpanded = !filtersExpanded),
                onChanged: _setFilter,
              ),
            _contentForState(context, visibleRecords),
          ],
        ),
      ],
    );
  }

  int get _activeFilterCount {
    var count = 0;
    if (filter.result != RecordResultFilter.all) count++;
    if (filter.color != RecordColorFilter.all) count++;
    if (filter.speed != RecordSpeedFilter.all) count++;
    if (filter.report != RecordReportFilter.all) count++;
    if (filter.minMoves > 0) count++;
    if (filter.onlyAnalyzed) count++;
    if (filter.query.trim().isNotEmpty) count++;
    return count;
  }

  Widget _contentForState(
      BuildContext context, List<GameRecord> visibleRecords) {
    final sourceRecords = activeRecords;
    final selectableRecords = visibleRecords
        .where((record) => widget.onDeleteRecord != null)
        .toList();
    final selectedRecords = selectableRecords
        .where((record) =>
            selectedRecordKeys.contains(_recordSelectionKey(record)))
        .toList();
    final showLocalPager = widget.signedIn &&
        sourceTab == RecordSourceTab.all &&
        !showingRemoteResults &&
        (widget.totalPage > 1 ||
            widget.hasMoreRecords ||
            widget.currentPage > 1);
    final showRemotePager = widget.signedIn &&
        showingRemoteResults &&
        (remoteSearch!.totalPage > 1 || remoteSearch!.page > 1);
    if (!widget.signedIn) {
      return _RecordsStateCard(
        icon: Icons.lock_outline_rounded,
        title: 'Sign in to view records',
        message:
            'Your PGN archive, synced board games, and review history are tied to your Chessnut account.',
        actionLabel: 'Sign in',
        onAction: () => widget.onNavigate('Auth'),
      );
    }

    if (widget.loading &&
        !showingRemoteResults &&
        sourceRecords.isEmpty &&
        deletedRecordKeys.isEmpty) {
      return const _RecordsStateCard(
        icon: Icons.sync_rounded,
        title: 'Loading records',
        message: 'Syncing your PGN archive from Chessnut.',
        actionLabel: 'Loading',
        onAction: null,
      );
    }

    final error = widget.errorMessage;
    if (error != null && error.isNotEmpty) {
      return _RecordsStateCard(
        icon: Icons.cloud_off_rounded,
        title: 'Unable to load records',
        message: error,
        actionLabel: 'Try again',
        onAction: widget.onRefresh,
      );
    }

    if (sourceRecords.isEmpty && !showingRemoteResults) {
      return _RecordsStateCard(
        icon: Icons.history_rounded,
        title: 'No games yet',
        message: 'Games played on Chessnut will appear here after they sync.',
        actionLabel: 'Start a game',
        onAction: () => widget.onNavigate('Setup'),
      );
    }

    if (sourceRecords.isEmpty && showingRemoteResults) {
      return _RecordsStateCard(
        icon: Icons.manage_search_rounded,
        title: 'No cloud games found',
        message: 'Try fewer filters or import games from Lichess first.',
        actionLabel: 'Back to local list',
        onAction: _clearRemoteSearch,
      );
    }

    if (visibleRecords.isEmpty) {
      return _RecordsStateCard(
        icon: Icons.manage_search_rounded,
        title: 'No games match filters',
        message: 'Adjust the filters or clear the search terms.',
        actionLabel: 'Clear filters',
        onAction: () => _setFilter(const GameRecordFilter()),
      );
    }

    return SectionColumn(
      spacing: 10,
      children: [
        if (selectableRecords.isNotEmpty)
          _RecordSelectionToolbar(
            selectionMode: selectionMode,
            selectedCount: selectedRecords.length,
            totalCount: selectableRecords.length,
            deleting: batchDeleting,
            onEnterSelection: _enterSelectionMode,
            onCancelSelection: _exitSelectionMode,
            onSelectAll: () => _selectAllRecords(selectableRecords),
            onDeleteSelected: selectedRecords.isEmpty
                ? null
                : () => _confirmDeleteRecords(selectedRecords),
          ),
        for (var index = 0; index < visibleRecords.length; index++)
          ChessnutFadeSlide(
            key: ValueKey(
                'game-record-row-${visibleRecords[index].pgnId ?? index}'),
            delay: Duration(milliseconds: 24 * index.clamp(0, 8)),
            child: GameRecordTile(
              record: visibleRecords[index],
              recordKey: _recordSelectionKey(visibleRecords[index]),
              onTap: selectionMode && widget.onDeleteRecord != null
                  ? () => _toggleRecordSelection(visibleRecords[index])
                  : () => _analyzeRecord(context, visibleRecords[index]),
              onContinue: visibleRecords[index].canContinueGame &&
                      widget.onContinueRecord != null &&
                      !selectionMode
                  ? () => _continueRecord(visibleRecords[index])
                  : null,
              onCopyPgn: selectionMode
                  ? null
                  : () => _copyRecordPgn(visibleRecords[index]),
              onRefreshPgn: widget.onRefreshRecordPgn != null &&
                      visibleRecords[index].pgnId != null &&
                      visibleRecords[index].hasRemotePgnSource &&
                      !selectionMode
                  ? () => _refreshRecordPgn(visibleRecords[index])
                  : null,
              onDelete: widget.onDeleteRecord != null && !selectionMode
                  ? () => _confirmDeleteRecords([visibleRecords[index]])
                  : null,
              onEnd: widget.onEndRecord != null &&
                      visibleRecords[index].isInProgress &&
                      !selectionMode
                  ? () => _confirmEndRecord(visibleRecords[index])
                  : null,
              continuing: continuingRecordId == visibleRecords[index].pgnId,
              selectionMode: selectionMode,
              selected: selectedRecordKeys
                  .contains(_recordSelectionKey(visibleRecords[index])),
              selectable: widget.onDeleteRecord != null,
              deleting: deletingRecordKey ==
                  _recordSelectionKey(visibleRecords[index]),
              refreshingPgn: refreshingPgnRecordKey ==
                  _recordSelectionKey(visibleRecords[index]),
              reportStatus: gameAnalysisReportStatusForRecord(
                visibleRecords[index],
                widget.reportStatuses,
              ),
              isChessnutClockDevice: widget.isChessnutClockDevice,
            ),
          ),
        if (showLocalPager || showRemotePager)
          _RecordPageControls(
            currentPage:
                showRemotePager ? remoteSearch!.page : widget.currentPage,
            totalPage:
                showRemotePager ? remoteSearch!.totalPage : widget.totalPage,
            loading: showRemotePager
                ? remoteSearchLoading
                : widget.loadingMoreRecords,
            onPrevious: showRemotePager
                ? (_canLoadPreviousRemotePage
                    ? () => _searchRemoteRecords(page: remoteSearch!.page - 1)
                    : null)
                : widget.onLoadRecordPage != null &&
                        widget.currentPage > 1 &&
                        !widget.loadingMoreRecords
                    ? () => widget.onLoadRecordPage!(widget.currentPage - 1)
                    : null,
            onNext: showRemotePager
                ? (_canLoadNextRemotePage
                    ? () => _searchRemoteRecords(page: remoteSearch!.page + 1)
                    : null)
                : widget.onLoadRecordPage != null &&
                        (widget.hasMoreRecords ||
                            widget.currentPage < widget.totalPage) &&
                        !widget.loadingMoreRecords
                    ? () => widget.onLoadRecordPage!(widget.currentPage + 1)
                    : null,
          ),
      ],
    );
  }

  void _enterSelectionMode() {
    setState(() => selectionMode = true);
  }

  void _exitSelectionMode() {
    setState(() {
      selectionMode = false;
      selectedRecordKeys.clear();
    });
  }

  void _toggleRecordSelection(GameRecord record) {
    if (widget.onDeleteRecord == null || batchDeleting) return;
    final key = _recordSelectionKey(record);
    setState(() {
      if (!selectedRecordKeys.add(key)) {
        selectedRecordKeys.remove(key);
      }
    });
  }

  void _selectAllRecords(List<GameRecord> records) {
    if (batchDeleting) return;
    setState(() {
      final keys = records.map(_recordSelectionKey).toList(growable: false);
      final allSelected = keys.every(selectedRecordKeys.contains);
      if (allSelected) {
        selectedRecordKeys.clear();
      } else {
        selectedRecordKeys
          ..clear()
          ..addAll(keys);
      }
    });
  }

  String _recordSelectionKey(GameRecord record) {
    return gameAnalysisReportCacheKeyForRecord(record);
  }

  void _analyzeRecord(BuildContext context, GameRecord record) {
    if (record.isPgnPending) {
      showAppFeedback(
        context,
        GameRecordStrings.of(context)
            .t('The PGN is still loading. Try again shortly.'),
        tone: AppFeedbackTone.info,
      );
      return;
    }
    if (record.isInProgress) {
      showAppFeedback(
        context,
        'Finish this game before generating an analysis report.',
        tone: AppFeedbackTone.warning,
      );
      return;
    }
    try {
      GameNotationService.parsePgn(record.pgn);
    } on FormatException catch (error) {
      showAppFeedback(
        context,
        error.message.contains('no legal mainline moves')
            ? 'This game ended before any playable moves, so there is no position to analyze.'
            : 'This PGN includes a move Chessnut cannot read. Check the move list and try again.',
        tone: AppFeedbackTone.warning,
      );
      return;
    } catch (_) {
      showAppFeedback(
        context,
        'This PGN could not be read. Check the move list and try again.',
        tone: AppFeedbackTone.warning,
      );
      return;
    }
    widget.onAnalyzeRecord(record);
  }

  Future<void> _continueRecord(GameRecord record) async {
    if (continuingRecordId != null) return;
    setState(() => continuingRecordId = record.pgnId ?? -1);
    try {
      await Future<void>.sync(() => widget.onContinueRecord!(record));
    } finally {
      if (mounted) setState(() => continuingRecordId = null);
    }
  }

  Future<void> _copyRecordPgn(GameRecord record) async {
    if (record.isPgnPending) {
      showAppFeedback(
        context,
        GameRecordStrings.of(context)
            .t('The PGN is still loading. Try again shortly.'),
        tone: AppFeedbackTone.info,
      );
      return;
    }
    if (record.pgn.trim().isEmpty) {
      showAppFeedback(
        context,
        'No PGN available for this record.',
        tone: AppFeedbackTone.warning,
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: record.pgn));
    if (!mounted) return;
    showAppFeedback(
      context,
      GameRecordStrings.of(context).t('PGN copied'),
      tone: AppFeedbackTone.success,
    );
  }

  Future<void> _refreshRecordPgn(GameRecord record) async {
    final callback = widget.onRefreshRecordPgn;
    if (callback == null || refreshingPgnRecordKey != null) return;
    final key = _recordSelectionKey(record);
    setState(() => refreshingPgnRecordKey = key);
    final result = await callback(record);
    if (!mounted) return;
    setState(() {
      refreshingPgnRecordKey = null;
      final refreshed = result.data;
      final currentSearch = remoteSearch;
      if (result.isSuccess && refreshed != null && currentSearch != null) {
        remoteSearch = GameRecordRemoteSearchResult(
          status: currentSearch.status,
          records: [
            for (final current in currentSearch.records)
              if (current.pgnId == refreshed.pgnId) refreshed else current,
          ],
          page: currentSearch.page,
          count: currentSearch.count,
          total: currentSearch.total,
          totalPage: currentSearch.totalPage,
        );
      }
    });
    showAppFeedback(
      context,
      result.isSuccess
          ? GameRecordStrings.of(context).t('PGN refreshed.')
          : GameRecordStrings.of(context).t(
              result.status.errorMessage ?? 'Unable to refresh this PGN.',
            ),
      tone: result.isSuccess ? AppFeedbackTone.success : AppFeedbackTone.error,
    );
  }

  Future<void> _confirmEndRecord(GameRecord record) async {
    final callback = widget.onEndRecord;
    if (callback == null || batchDeleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => const _EndRecordDialog(),
    );
    if (confirmed != true || !mounted) return;

    setState(() => deletingRecordKey = _recordSelectionKey(record));
    final result = await callback(record);
    if (!mounted) return;
    setState(() => deletingRecordKey = null);
    if (result.isSuccess && result.data == true) {
      showAppFeedback(
        context,
        GameRecordStrings.of(context).t('Game marked as ended.'),
        tone: AppFeedbackTone.success,
      );
    } else {
      showAppFeedback(
        context,
        result.status.errorMessage ??
            GameRecordStrings.of(context).t('Unable to end this game record.'),
        tone: AppFeedbackTone.warning,
      );
    }
  }

  Future<void> _confirmDeleteRecords(List<GameRecord> records) async {
    final callback = widget.onDeleteRecord;
    if (callback == null || records.isEmpty || batchDeleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _DeleteRecordsDialog(count: records.length),
    );
    if (confirmed != true || !mounted) return;

    final deleteEntries = [
      for (final record in records)
        MapEntry(_recordSelectionKey(record), record),
    ];
    final deleteKeys = deleteEntries.map((entry) => entry.key).toList();

    setState(() {
      batchDeleting = true;
      deletingRecordKey = null;
      selectionMode = false;
      deletedRecordKeys.addAll(deleteKeys);
      selectedRecordKeys.removeAll(deleteKeys);
    });
    final deletedKeys = <String>[];
    final failedKeys = <String>[];
    String? firstError;
    for (final entry in deleteEntries) {
      final key = entry.key;
      final record = entry.value;
      if (!mounted) return;
      final ApiResult<bool> result;
      try {
        result = await callback(record);
      } catch (_) {
        failedKeys.add(key);
        firstError ??= 'Unable to delete this game record.';
        continue;
      }
      if (result.isSuccess) {
        deletedKeys.add(key);
      } else {
        failedKeys.add(key);
        firstError ??=
            result.status.errorMessage ?? 'Unable to delete this game record.';
      }
    }
    if (!mounted) return;
    setState(() {
      batchDeleting = false;
      deletingRecordKey = null;
      deletedRecordKeys.removeAll(failedKeys);
      if (selectedRecordKeys.isEmpty) selectionMode = false;
    });

    if (deletedKeys.isNotEmpty) {
      showAppFeedback(
        context,
        deletedKeys.length == 1
            ? 'Game record deleted.'
            : '${deletedKeys.length} game records deleted.',
        tone: AppFeedbackTone.success,
      );
    }
    if (firstError != null) {
      showAppFeedback(context, firstError, tone: AppFeedbackTone.error);
    }
  }

  bool _matchesMode(GameRecord record) {
    final mode = record.playMode.toLowerCase();
    return switch (filter.mode) {
      RecordModeFilter.all => true,
      RecordModeFilter.local => _isLocalRecordMode(mode),
      RecordModeFilter.bot => mode.contains('bot'),
      RecordModeFilter.otb => mode.contains('otb'),
      RecordModeFilter.lichess => mode.contains('lichess'),
      RecordModeFilter.chesscom =>
        mode.contains('chesscom') || mode.contains('chess.com'),
    };
  }

  bool _matchesSourceTab(GameRecord record, [RecordSourceTab? tab]) {
    final source = tab ?? sourceTab;
    final mode = record.playMode.trim().toLowerCase();
    return switch (source) {
      RecordSourceTab.all => true,
      RecordSourceTab.local => _isLocalRecordMode(mode),
      RecordSourceTab.lichess => mode.contains('lichess'),
      RecordSourceTab.chesscom =>
        mode.contains('chesscom') || mode.contains('chess.com'),
    };
  }

  bool _isLocalRecordMode(String mode) {
    return !mode.contains('lichess') &&
        !mode.contains('chesscom') &&
        !mode.contains('chess.com');
  }

  bool _matchesResult(GameRecord record) {
    final result = record.finishedResultToken;
    return switch (filter.result) {
      RecordResultFilter.all => true,
      RecordResultFilter.win => _isPlayerWin(record),
      RecordResultFilter.loss => _isPlayerLoss(record),
      RecordResultFilter.draw => result == '1/2-1/2',
      RecordResultFilter.unfinished => result == '*',
    };
  }

  bool _isPlayerWin(GameRecord record) {
    final result = record.finishedResultToken;
    return switch (_playerColorFor(record)) {
      'white' => result == '1-0',
      'black' => result == '0-1',
      _ => result == '1-0',
    };
  }

  bool _isPlayerLoss(GameRecord record) {
    final result = record.finishedResultToken;
    return switch (_playerColorFor(record)) {
      'white' => result == '0-1',
      'black' => result == '1-0',
      _ => result == '0-1',
    };
  }

  bool _matchesColor(GameRecord record) {
    final playerColor = _playerColorFor(record);
    return switch (filter.color) {
      RecordColorFilter.all => true,
      RecordColorFilter.white => playerColor == 'white',
      RecordColorFilter.black => playerColor == 'black',
    };
  }

  String _playerColorFor(GameRecord record) {
    final declared = record.declaredPlayerColor;
    if (declared.isNotEmpty) return declared;
    final names = _currentPlayerNames(record);
    if (names.isNotEmpty) {
      if (_nameMatchesAny(record.displayWhiteName, names)) return 'white';
      if (_nameMatchesAny(record.displayBlackName, names)) return 'black';
    }
    return record.playerColor;
  }

  Set<String> _currentPlayerNames(GameRecord record) {
    final session = widget.currentSession;
    final names = <String>{
      if (session != null) ...[
        session.username,
        session.email,
        session.email.split('@').first,
        session.lichessName,
        session.chessName,
        session.phone,
      ],
      record.lichessName,
    };
    names.removeWhere((name) => _normalizePlayerName(name).isEmpty);
    return names.map(_normalizePlayerName).toSet();
  }

  bool _nameMatchesAny(String candidate, Set<String> names) {
    final normalized = _normalizePlayerName(candidate);
    return normalized.isNotEmpty && names.contains(normalized);
  }

  bool _matchesSpeed(GameRecord record) {
    return filter.speed == RecordSpeedFilter.all ||
        record.speed == filter.speed.name;
  }

  bool _matchesReport(GameRecord record) {
    final status =
        gameAnalysisReportStatusForRecord(record, widget.reportStatuses);
    return switch (filter.report) {
      RecordReportFilter.all => true,
      RecordReportFilter.unanalyzed => !status.hasAny,
      RecordReportFilter.standard => status.standard,
      RecordReportFilter.grandeur => status.grandeurReady,
    };
  }

  GameRecordFilter get _effectiveServerFilter {
    final mode = switch (sourceTab) {
      RecordSourceTab.local => RecordModeFilter.local,
      RecordSourceTab.lichess => RecordModeFilter.lichess,
      RecordSourceTab.chesscom => RecordModeFilter.chesscom,
      _ => filter.mode,
    };
    return filter.copyWith(mode: mode);
  }

  Future<void> _selectSourceTab(RecordSourceTab tab) async {
    setState(() {
      sourceTab = tab;
      filter = filter.copyWith(mode: RecordModeFilter.all);
      remoteSearch = null;
      remoteSearchError = null;
    });
    if (tab != RecordSourceTab.all && widget.onSearchRemoteRecords != null) {
      await _searchRemoteRecords(page: 1);
    }
  }

  void _setFilter(GameRecordFilter value) {
    setState(() {
      filter = value;
      remoteSearch = null;
      remoteSearchError = null;
    });
    if (widget.onSearchRemoteRecords != null) {
      unawaited(_searchRemoteRecords(page: 1));
    }
  }

  Future<void> _searchRemoteRecords({
    required int page,
    bool silent = false,
  }) async {
    final callback = widget.onSearchRemoteRecords;
    if (callback == null) return;
    final generation = ++_remoteSearchGeneration;
    final searchFilter = _effectiveServerFilter;
    if (!silent) {
      setState(() {
        remoteSearchLoading = true;
        remoteSearchError = null;
      });
    }
    final result = await callback(searchFilter, page, _remotePageSize);
    if (!mounted || generation != _remoteSearchGeneration) return;
    setState(() {
      if (!silent) remoteSearchLoading = false;
      if (result.isSuccess) {
        remoteSearch = result;
      } else if (!silent) {
        remoteSearchError = result.status.errorMessage ??
            'Unable to search your cloud archive. Check your connection and try again.';
      }
    });
    final hydratedRecords = result.hydratedRecords;
    if (!result.isSuccess || hydratedRecords == null) return;
    for (final hydratedRecord in hydratedRecords) {
      unawaited(
        _applyHydratedRemoteSearchRecord(
          hydratedRecord,
          result: result,
          generation: generation,
        ),
      );
    }
  }

  Future<void> _applyHydratedRemoteSearchRecord(
    Future<GameRecord> hydratedRecord, {
    required GameRecordRemoteSearchResult result,
    required int generation,
  }) async {
    GameRecord record;
    try {
      record = await hydratedRecord;
    } catch (_) {
      return;
    }
    if (!mounted || generation != _remoteSearchGeneration) return;
    final currentSearch = remoteSearch;
    if (currentSearch == null || currentSearch.page != result.page) return;
    final pgnId = record.pgnId;
    if (pgnId == null) return;
    final index = currentSearch.records.indexWhere(
      (current) => current.pgnId == pgnId && current.isPgnPending,
    );
    if (index < 0) return;
    final records = [...currentSearch.records]..[index] = record;
    setState(() {
      remoteSearch = GameRecordRemoteSearchResult(
        status: currentSearch.status,
        records: records,
        page: currentSearch.page,
        count: currentSearch.count,
        total: currentSearch.total,
        totalPage: currentSearch.totalPage,
      );
    });
  }

  void _clearRemoteSearch() {
    setState(() {
      remoteSearch = null;
      remoteSearchError = null;
    });
  }

  Future<void> _showLichessImportDialog() async {
    final result = await showDialog<Object>(
      context: context,
      builder: (context) => _HistoryImportDialog(
        source: _HistoryImportSource.lichess,
        fetchGames: widget.onFetchLichessGames,
        importGames: widget.onImportHistoryPgnBatch,
      ),
    );
    if (result == null || !mounted) return;
    if (result is int) {
      final message = GameRecordStrings.of(context)
          .t('Imported {count} games.')
          .replaceAll('{count}', result.toString());
      showAppFeedback(context, message, tone: AppFeedbackTone.success);
      await widget.onRefresh?.call();
      return;
    }
    if (result is LichessHistoryImportOptions) {
      await _startLichessImport(result);
    }
  }

  Future<void> _importPgnFile() async {
    final importer = widget.onImportPgnFile;
    if (importer == null || importRunning) return;
    setState(() {
      importRunning = true;
      importError = null;
      importJob = null;
      importSourceLabel = 'PGN';
    });
    try {
      await importer();
    } finally {
      if (mounted) setState(() => importRunning = false);
    }
  }

  Future<void> _showChessComImportDialog() async {
    final result = await showDialog<Object>(
      context: context,
      builder: (context) => _HistoryImportDialog(
        source: _HistoryImportSource.chesscom,
        fetchGames: widget.onFetchChessComGames,
        importGames: widget.onImportHistoryPgnBatch,
      ),
    );
    if (result == null || !mounted) return;
    if (result is int) {
      final message = GameRecordStrings.of(context)
          .t('Imported {count} games.')
          .replaceAll('{count}', result.toString());
      showAppFeedback(context, message, tone: AppFeedbackTone.success);
      await widget.onRefresh?.call();
      return;
    }
    if (result is LichessHistoryImportOptions) {
      await _startChessComImport(result);
    }
  }

  Future<void> _startLichessImport(
    LichessHistoryImportOptions options,
  ) async {
    await _startHistoryImport(
      label: 'Lichess',
      starter: widget.onStartLichessHistoryImport,
      checker: widget.onCheckLichessHistoryImport,
      options: options,
    );
  }

  Future<void> _startChessComImport(
    LichessHistoryImportOptions options,
  ) async {
    await _startHistoryImport(
      label: 'Chess.com',
      starter: widget.onStartChessComHistoryImport,
      checker: widget.onCheckChessComHistoryImport,
      options: options,
    );
  }

  Future<void> _startHistoryImport({
    required String label,
    required LichessHistoryImportStartCallback? starter,
    required LichessHistoryImportStatusCallback? checker,
    required LichessHistoryImportOptions options,
  }) async {
    if (starter == null || importRunning) return;
    importSourceLabel = label;
    setState(() {
      importRunning = true;
      importCanceling = false;
      importError = null;
      importJob = null;
    });
    var result = await starter(options);
    if (!mounted) return;
    if (!result.isSuccess || result.data == null) {
      setState(() {
        importRunning = false;
        importError =
            result.status.errorMessage ?? 'Unable to start $label import.';
      });
      return;
    }

    var job = result.data!;
    setState(() => importJob = job);
    var attempts = 0;
    while (mounted &&
        importRunning &&
        !job.isDone &&
        checker != null &&
        attempts < 60) {
      attempts++;
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      result = await checker(job.jobId);
      if (!mounted) return;
      if (!result.isSuccess || result.data == null) {
        setState(() {
          importRunning = false;
          importError =
              result.status.errorMessage ?? 'Unable to check $label import.';
        });
        return;
      }
      job = result.data!;
      setState(() => importJob = job);
    }

    if (!mounted) return;
    setState(() {
      importRunning = false;
      importJob = job;
      if (!job.isDone && checker != null) {
        importError = null;
      } else if (job.status == 'failed') {
        importError = job.userMessage.isNotEmpty
            ? job.userMessage
            : job.errorMessage.isEmpty
                ? '$label import failed.'
                : job.errorMessage;
      }
    });
    if (job.status == 'completed') {
      await widget.onRefresh?.call();
    }
  }

  Future<void> _cancelImport() async {
    final job = importJob;
    final canceler = importSourceLabel == 'Chess.com'
        ? widget.onCancelChessComHistoryImport
        : widget.onCancelLichessHistoryImport;
    if (job == null || canceler == null || importCanceling || job.isDone) {
      return;
    }
    setState(() => importCanceling = true);
    final result = await canceler(job.jobId);
    if (!mounted) return;
    setState(() {
      importCanceling = false;
      importRunning = false;
      if (result.isSuccess && result.data != null) {
        importJob = result.data;
        importError = null;
      } else {
        importError = result.status.errorMessage ??
            'Unable to cancel $importSourceLabel import.';
      }
    });
  }

  LichessHistoryImportCancelCallback? get _currentCancelImportCallback {
    if (importSourceLabel == 'Chess.com') {
      return widget.onCancelChessComHistoryImport;
    }
    return widget.onCancelLichessHistoryImport;
  }
}

class _RecordSelectionToolbar extends StatelessWidget {
  const _RecordSelectionToolbar({
    required this.selectionMode,
    required this.selectedCount,
    required this.totalCount,
    required this.deleting,
    required this.onEnterSelection,
    required this.onCancelSelection,
    required this.onSelectAll,
    required this.onDeleteSelected,
  });

  final bool selectionMode;
  final int selectedCount;
  final int totalCount;
  final bool deleting;
  final VoidCallback onEnterSelection;
  final VoidCallback onCancelSelection;
  final VoidCallback onSelectAll;
  final VoidCallback? onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final narrow = MediaQuery.sizeOf(context).width < 420;
    final compactTextButtonStyle = TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      minimumSize: Size(narrow ? 44 : 56, 36),
      padding: EdgeInsets.symmetric(horizontal: narrow ? 6 : 10),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return GlassPanel(
      key: const ValueKey('game-record-selection-toolbar'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderRadius: 14,
      tint: selectionMode
          ? scheme.primary.withValues(alpha: 0.08)
          : scheme.surface.withValues(alpha: 0.02),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: selectionMode
            ? Row(
                key: const ValueKey('game-record-selection-active'),
                children: [
                  Expanded(
                    child: Text(
                      '$selectedCount selected',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('game-record-select-all'),
                    onPressed: deleting ? null : onSelectAll,
                    style: compactTextButtonStyle,
                    child: Text(
                      selectedCount == totalCount ? 'Clear' : 'All',
                      maxLines: 1,
                    ),
                  ),
                  SizedBox(width: narrow ? 4 : 6),
                  FilledButton.icon(
                    key: const ValueKey('game-record-batch-delete'),
                    onPressed: deleting ? null : onDeleteSelected,
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                      disabledBackgroundColor:
                          scheme.error.withValues(alpha: 0.28),
                      disabledForegroundColor:
                          scheme.onError.withValues(alpha: 0.72),
                      padding: EdgeInsets.symmetric(
                        horizontal: narrow ? 8 : 12,
                        vertical: 8,
                      ),
                      minimumSize: Size(narrow ? 80 : 92, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: deleting
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline_rounded),
                    label: const Text(
                      'Delete',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: narrow ? 4 : 6),
                  TextButton(
                    onPressed: deleting ? null : onCancelSelection,
                    style: compactTextButtonStyle,
                    child: const Text('Cancel', maxLines: 1),
                  ),
                ],
              )
            : Row(
                key: const ValueKey('game-record-selection-idle'),
                children: [
                  const Expanded(
                    child: Text(
                      'Select records to delete',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('game-record-selection-toolbar-enter'),
                    onPressed: onEnterSelection,
                    icon: const Icon(Icons.checklist_rounded),
                    label: const Text('Select'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _DeleteRecordsDialog extends StatelessWidget {
  const _DeleteRecordsDialog({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      icon: Icons.delete_outline_rounded,
      title: 'Delete selected records?',
      subtitle: '$count selected',
      actions: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('delete-records-dialog-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
          ),
        ),
      ],
      child: Text(
        'This removes the selected PGNs from your Chessnut account. This action cannot be undone.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _EndRecordDialog extends StatelessWidget {
  const _EndRecordDialog();

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      icon: Icons.flag_rounded,
      title: GameRecordStrings.of(context).t('End this game?'),
      subtitle: GameRecordStrings.of(context).t('Mark as finished'),
      actions: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('end-record-dialog-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.flag_rounded),
            label: Text(GameRecordStrings.of(context).t('End game')),
          ),
        ),
      ],
      child: Text(
        GameRecordStrings.of(context).t(
          'This will mark the saved PGN as a completed draw so it no longer appears as a game you can continue.',
        ),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _GameRecordImportMenu extends StatelessWidget {
  const _GameRecordImportMenu({
    required this.importRunning,
    required this.onImportPgn,
    required this.onImportLichess,
    required this.onImportChessCom,
  });

  final bool importRunning;
  final VoidCallback? onImportPgn;
  final VoidCallback? onImportLichess;
  final VoidCallback? onImportChessCom;

  @override
  Widget build(BuildContext context) {
    final strings = GameRecordStrings.of(context);
    return SizedBox.square(
      key: const ValueKey('game-record-import-menu'),
      dimension: 44,
      child: MenuAnchor(
        builder: (context, controller, child) {
          final icon = importRunning
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_for_offline_rounded);
          return IconButton.filledTonal(
            tooltip: strings.t('Import records'),
            onPressed: importRunning
                ? null
                : () =>
                    controller.isOpen ? controller.close() : controller.open(),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            icon: icon,
          );
        },
        menuChildren: [
          if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS)
            MenuItemButton(
              key: const ValueKey('game-record-import-pgn-menu'),
              onPressed: onImportPgn,
              leadingIcon: const Icon(Icons.file_upload_rounded),
              child: Text(strings.t('From PGN')),
            ),
          MenuItemButton(
            key: const ValueKey('game-record-import-lichess'),
            onPressed: onImportLichess,
            leadingIcon: const Icon(Icons.bolt_rounded),
            child: Text(strings.t('From Lichess player')),
          ),
          MenuItemButton(
            key: const ValueKey('game-record-import-chesscom'),
            onPressed: onImportChessCom,
            leadingIcon: const Icon(Icons.language_rounded),
            child: Text(strings.t('From Chess.com username')),
          ),
        ],
      ),
    );
  }
}

class _SourceTabs extends StatelessWidget {
  const _SourceTabs({
    super.key,
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  final RecordSourceTab selected;
  final Map<RecordSourceTab, int> counts;
  final ValueChanged<RecordSourceTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      borderRadius: 14,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const tabs = RecordSourceTab.values;
          final itemWidth =
              ((constraints.maxWidth - 18) / tabs.length).clamp(64.0, 180.0);
          return SizedBox(
            height: 38,
            child: Row(
              children: [
                for (var index = 0; index < tabs.length; index++) ...[
                  if (index > 0) const SizedBox(width: 6),
                  SizedBox(
                    width: itemWidth,
                    child: _SourceTabButton(
                      key: ValueKey('game-record-source-${tabs[index].name}'),
                      selected: selected == tabs[index],
                      icon: _sourceIcon(tabs[index]),
                      label: _sourceLabel(tabs[index]),
                      count: counts[tabs[index]] ?? 0,
                      onTap: () => onChanged(tabs[index]),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _sourceIcon(RecordSourceTab tab) {
    return switch (tab) {
      RecordSourceTab.all => Icons.apps_rounded,
      RecordSourceTab.local => Icons.devices_rounded,
      RecordSourceTab.lichess => Icons.bolt_rounded,
      RecordSourceTab.chesscom => Icons.language_rounded,
    };
  }

  String _sourceLabel(RecordSourceTab tab) {
    return switch (tab) {
      RecordSourceTab.all => 'All',
      RecordSourceTab.local => 'Chessnut',
      RecordSourceTab.lichess => 'Lichess',
      RecordSourceTab.chesscom => 'Chess.com',
    };
  }
}

class _SourceTabButton extends StatelessWidget {
  const _SourceTabButton({
    super.key,
    required this.selected,
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = selected
        ? scheme.primary.withValues(alpha: 0.18)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.46);
    final border = selected
        ? scheme.primary.withValues(alpha: 0.50)
        : scheme.outlineVariant.withValues(alpha: 0.55);
    final foreground = selected ? scheme.primary : scheme.onSurface;
    return Tooltip(
      message: '$label $count',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Text(
                count.toString(),
                maxLines: 1,
                style: TextStyle(
                  color: foreground,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordPageControls extends StatelessWidget {
  const _RecordPageControls({
    required this.currentPage,
    required this.totalPage,
    required this.loading,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final int totalPage;
  final bool loading;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedTotalPage = totalPage < 1 ? 1 : totalPage;
    final resolvedCurrentPage = currentPage.clamp(1, resolvedTotalPage).toInt();
    return Center(
      key: const ValueKey('game-record-page-controls'),
      child: Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.filledTonal(
              tooltip: 'Previous records page',
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: loading
                  ? SizedBox.square(
                      key: const ValueKey('record-page-loading'),
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.primary,
                      ),
                    )
                  : Text(
                      key: ValueKey(
                        'record-page-$resolvedCurrentPage-$resolvedTotalPage',
                      ),
                      'Page $resolvedCurrentPage of $resolvedTotalPage',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Next records page',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveStatusList extends StatelessWidget {
  const _ArchiveStatusList({
    required this.remoteSearch,
    required this.remoteSearchError,
    required this.importJob,
    required this.importRunning,
    required this.importCanceling,
    required this.importError,
    required this.importSourceLabel,
    required this.onCancelImport,
  });

  final GameRecordRemoteSearchResult? remoteSearch;
  final String? remoteSearchError;
  final LichessImportJob? importJob;
  final bool importRunning;
  final bool importCanceling;
  final String? importError;
  final String importSourceLabel;
  final VoidCallback? onCancelImport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final job = importJob;
    final search = remoteSearch;
    if (search == null &&
        remoteSearchError == null &&
        job == null &&
        importError == null) {
      return const SizedBox.shrink();
    }
    return SectionColumn(
      spacing: 8,
      children: [
        if (search != null || remoteSearchError != null)
          _ArchiveStatusStrip(
            icon: remoteSearchError == null
                ? Icons.cloud_done_rounded
                : Icons.cloud_off_rounded,
            tone: remoteSearchError == null ? scheme.primary : scheme.error,
            title: remoteSearchError == null
                ? '${search?.total ?? 0} games found'
                : 'Cloud search failed',
            subtitle: remoteSearchError ??
                'Page ${search?.page ?? 1} of ${(search?.totalPage ?? 1).clamp(1, 999999)}. Analysis filters use reports already saved on this device.',
          ),
        if (job != null || importError != null)
          _ArchiveStatusStrip(
            icon: _importStatusIcon(job, importError),
            tone: _importStatusColor(context, job, importError),
            title: importError != null
                ? '$importSourceLabel import needs attention'
                : _importStatusTitle(job, importSourceLabel),
            subtitle:
                _importStatusSubtitle(job, importError, importSourceLabel),
            progressPercent: job?.progressPercent,
            trailing: job != null && importRunning && !job.isDone
                ? TextButton.icon(
                    onPressed: importCanceling ? null : onCancelImport,
                    icon: importCanceling
                        ? const SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.stop_circle_outlined),
                    label: Text(
                      importCanceling ? 'Canceling' : 'Cancel',
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                      textAlign: TextAlign.center,
                    ),
                  )
                : null,
          ),
      ],
    );
  }

  IconData _importStatusIcon(LichessImportJob? job, String? error) {
    if (error != null || job?.status == 'failed') {
      return Icons.error_outline_rounded;
    }
    if (job?.status == 'completed') return Icons.task_alt_rounded;
    if (job?.status == 'canceled') return Icons.stop_circle_outlined;
    return Icons.hourglass_top_rounded;
  }

  Color _importStatusColor(
    BuildContext context,
    LichessImportJob? job,
    String? error,
  ) {
    final scheme = Theme.of(context).colorScheme;
    if (error != null || job?.status == 'failed') return scheme.error;
    if (job?.status == 'completed') return scheme.tertiary;
    if (job?.status == 'canceled') return scheme.outline;
    return scheme.secondary;
  }

  String _importStatusTitle(LichessImportJob? job, String sourceLabel) {
    return switch (job?.status) {
      'completed' => '$sourceLabel import completed',
      'failed' => '$sourceLabel import failed',
      'canceled' => '$sourceLabel import canceled',
      'running' => 'Importing $sourceLabel history',
      'queued' => '$sourceLabel import preparing',
      _ => '$sourceLabel import',
    };
  }

  String _importStatusSubtitle(
    LichessImportJob? job,
    String? error,
    String sourceLabel,
  ) {
    if (error != null && error.isNotEmpty) return error;
    if (job == null) return '';
    final pieces = <String>[];
    if (job.userMessage.isNotEmpty) {
      pieces.add(job.userMessage);
    } else if (job.statusDetail.isNotEmpty) {
      pieces.add(job.statusDetail);
    } else {
      final totalLabel =
          job.total > 0 ? '${job.processed}/${job.total}' : '${job.processed}';
      pieces.add(
        '$totalLabel processed / ${job.inserted} new / ${job.skipped} skipped / ${job.failed} failed',
      );
    }
    if (job.status == 'completed') {
      pieces.add('Records have been refreshed.');
    } else if (job.status == 'running' || job.status == 'queued') {
      pieces.add('You can leave this page and refresh records later.');
    }
    if (job.nextRetryAt.isNotEmpty) {
      pieces.add('Waiting for $sourceLabel until ${job.nextRetryAt}.');
    }
    return pieces.join(' ');
  }
}

class _ArchiveStatusStrip extends StatelessWidget {
  const _ArchiveStatusStrip({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    this.progressPercent,
    this.trailing,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String subtitle;
  final int? progressPercent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: tone),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 4,
                  overflow: TextOverflow.visible,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (progressPercent != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: progressPercent!.clamp(0, 100) / 100,
                      backgroundColor: tone.withValues(alpha: 0.14),
                      valueColor: AlwaysStoppedAnimation<Color>(tone),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }
}

enum _HistoryImportSource { lichess, chesscom }

class _HistoryImportDialog extends StatefulWidget {
  const _HistoryImportDialog({
    required this.source,
    this.fetchGames,
    this.importGames,
  });

  @override
  State<_HistoryImportDialog> createState() => _HistoryImportDialogState();

  final _HistoryImportSource source;
  final HistoryPgnFetchCallback? fetchGames;
  final HistoryPgnBatchImportCallback? importGames;
}

class _HistoryImportDialogState extends State<_HistoryImportDialog> {
  final playerController = TextEditingController();
  final maxGamesController = TextEditingController(
    text: historyPgnBatchLimit.toString(),
  );
  final sinceController = TextEditingController();
  final untilController = TextEditingController();
  String speed = '';
  String rated = '';
  String color = '';
  String? error;
  List<_HistoryImportGame> games = const [];
  final selectedIndexes = <int>{};
  bool loading = false;
  bool importing = false;

  bool get _usesAppImport =>
      widget.fetchGames != null && widget.importGames != null;

  @override
  void dispose() {
    playerController.dispose();
    maxGamesController.dispose();
    sinceController.dispose();
    untilController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = GameRecordStrings.of(context);
    final isChessCom = widget.source == _HistoryImportSource.chesscom;
    final title = strings
        .t(isChessCom ? 'Import Chess.com games' : 'Import Lichess games');
    final description = isChessCom
        ? strings.t(
            'Import public finished games from one Chess.com username into Game Record. Chess.com archives can take a little time to publish very recent games.',
          )
        : strings.t(
            'Import finished games from one Lichess player into Game Record. Duplicate games are skipped automatically.',
          );
    final playerKey = isChessCom
        ? const ValueKey('chesscom-import-player-id')
        : const ValueKey('lichess-import-player-id');
    final maxKey = isChessCom
        ? const ValueKey('chesscom-import-max-games')
        : const ValueKey('lichess-import-max-games');
    final size = MediaQuery.sizeOf(context);
    final maxWidth = size.width < 720 ? size.width - 24 : 680.0;
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: size.height - 24,
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.download_for_offline_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: strings.t('Close'),
                  onPressed: loading || importing
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ]),
              const SizedBox(height: 10),
              Expanded(
                child: games.isEmpty
                    ? SingleChildScrollView(
                        child: _buildOptions(
                          strings: strings,
                          isChessCom: isChessCom,
                          description: description,
                          playerKey: playerKey,
                          maxKey: maxKey,
                        ),
                      )
                    : _buildGameSelection(strings),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  strings.t(error!),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _buildActions(strings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptions({
    required GameRecordStrings strings,
    required bool isChessCom,
    required String description,
    required Key playerKey,
    required Key maxKey,
  }) {
    return SectionColumn(
      spacing: 14,
      children: [
        Text(description, style: Theme.of(context).textTheme.bodyMedium),
        TextField(
          key: playerKey,
          controller: playerController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: strings.t('Player ID'),
            prefixIcon: const Icon(Icons.alternate_email_rounded),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final fieldWidth = constraints.maxWidth < 520
                ? constraints.maxWidth
                : (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: fieldWidth,
                  child: TextField(
                    key: maxKey,
                    controller: maxGamesController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: strings.t('Max games'),
                      helperText: strings.t('Up to 500 games per import.'),
                      prefixIcon: const Icon(
                        Icons.format_list_numbered_rounded,
                      ),
                    ),
                  ),
                ),
                if (!isChessCom)
                  SizedBox(
                    width: fieldWidth,
                    child: _ImportChoiceMenu(
                      label: strings.t('Speed'),
                      value: speed,
                      values: const [
                        '',
                        'bullet',
                        'blitz',
                        'rapid',
                        'classical'
                      ],
                      labelFor: (value) => value.isEmpty
                          ? strings.t('Any speed')
                          : strings.t(
                              value[0].toUpperCase() + value.substring(1),
                            ),
                      onChanged: (value) => setState(() => speed = value),
                    ),
                  ),
                SizedBox(
                  width: fieldWidth,
                  child: TextField(
                    controller: sinceController,
                    decoration: InputDecoration(
                      labelText: strings.t('Since'),
                      hintText: 'YYYY-MM-DD',
                      prefixIcon: const Icon(Icons.date_range_rounded),
                    ),
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: TextField(
                    controller: untilController,
                    decoration: InputDecoration(
                      labelText: strings.t('Until'),
                      hintText: 'YYYY-MM-DD',
                      prefixIcon: const Icon(Icons.event_rounded),
                    ),
                  ),
                ),
                if (!isChessCom)
                  SizedBox(
                    width: fieldWidth,
                    child: _ImportChoiceMenu(
                      label: strings.t('Rated'),
                      value: rated,
                      values: const ['', 'true', 'false'],
                      labelFor: (value) => switch (value) {
                        'true' => strings.t('Rated only'),
                        'false' => strings.t('Casual only'),
                        _ => strings.t('Rated and casual'),
                      },
                      onChanged: (value) => setState(() => rated = value),
                    ),
                  ),
                if (!isChessCom)
                  SizedBox(
                    width: fieldWidth,
                    child: _ImportChoiceMenu(
                      label: strings.t('Color'),
                      value: color,
                      values: const ['', 'white', 'black'],
                      labelFor: (value) => switch (value) {
                        'white' => strings.t('White games'),
                        'black' => strings.t('Black games'),
                        _ => strings.t('Any color'),
                      },
                      onChanged: (value) => setState(() => color = value),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildGameSelection(GameRecordStrings strings) {
    final allSelected = selectedIndexes.length == games.length;
    final previewBoardSize =
        MediaQuery.sizeOf(context).width < 420 ? 70.0 : 82.0;
    final selectedText = strings
        .t('Selected {selected} of {total}')
        .replaceAll('{selected}', selectedIndexes.length.toString())
        .replaceAll('{total}', games.length.toString());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                selectedText,
                key: const ValueKey('history-import-selected-count'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton.icon(
              key: const ValueKey('history-import-toggle-all'),
              onPressed: importing
                  ? null
                  : () => setState(() {
                        if (allSelected) {
                          selectedIndexes.clear();
                        } else {
                          selectedIndexes.addAll(
                            List<int>.generate(games.length, (index) => index),
                          );
                        }
                      }),
              icon: Icon(allSelected
                  ? Icons.deselect_rounded
                  : Icons.select_all_rounded),
              label: Text(strings.t(allSelected ? 'Clear all' : 'Select all')),
            ),
          ],
        ),
        Text(
          strings.t('You can import up to 500 games at a time.'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            key: const ValueKey('history-import-game-list'),
            itemCount: games.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final game = games[index];
              return _HistoryImportGameTile(
                key: ValueKey('history-import-game-$index'),
                game: game,
                sourceLabel: widget.source == _HistoryImportSource.chesscom
                    ? 'Chess.com'
                    : 'Lichess',
                boardSize: previewBoardSize,
                selected: selectedIndexes.contains(index),
                enabled: !importing,
                strings: strings,
                onChanged: importing
                    ? null
                    : () => setState(() {
                          if (!selectedIndexes.add(index)) {
                            selectedIndexes.remove(index);
                          }
                        }),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActions(GameRecordStrings strings) {
    final cancelButton = TextButton(
      onPressed: loading || importing
          ? null
          : games.isNotEmpty
              ? () => setState(() {
                    games = const [];
                    selectedIndexes.clear();
                    error = null;
                  })
              : () => Navigator.of(context).pop(),
      child: Text(strings.t(games.isNotEmpty ? 'Back' : 'Cancel')),
    );
    final primaryButton = FilledButton.icon(
      key: const ValueKey('history-import-primary-action'),
      onPressed: loading || importing
          ? null
          : games.isNotEmpty
              ? _importSelected
              : _usesAppImport
                  ? _fetchGames
                  : _submitLegacy,
      icon: loading || importing
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(games.isNotEmpty
              ? Icons.file_download_done_rounded
              : _usesAppImport
                  ? Icons.search_rounded
                  : Icons.play_arrow_rounded),
      label: Text(strings.t(games.isNotEmpty
          ? 'Import selected games'
          : _usesAppImport
              ? 'Fetch games'
              : 'Start import')),
    );
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (constraints.maxWidth < 400)
            Expanded(child: cancelButton)
          else
            cancelButton,
          const SizedBox(width: 8),
          if (constraints.maxWidth < 400)
            Expanded(flex: 2, child: primaryButton)
          else
            primaryButton,
        ],
      ),
    );
  }

  LichessHistoryImportOptions? _readOptions() {
    final playerId = playerController.text.trim();
    final maxGames =
        int.tryParse(maxGamesController.text.trim()) ?? historyPgnBatchLimit;
    if (playerId.isEmpty) {
      setState(() => error = widget.source == _HistoryImportSource.chesscom
          ? 'Enter a Chess.com username.'
          : 'Enter a Lichess player ID.');
      return null;
    }
    if (maxGames < 1 || maxGames > historyPgnBatchLimit) {
      setState(() => error = 'Enter a number from 1 to 500.');
      return null;
    }
    return LichessHistoryImportOptions(
      playerId: playerId,
      maxGames: maxGames,
      since: sinceController.text.trim(),
      until: untilController.text.trim(),
      speed: speed,
      rated: rated,
      color: color,
    );
  }

  void _submitLegacy() {
    final options = _readOptions();
    if (options != null) Navigator.of(context).pop(options);
  }

  Future<void> _fetchGames() async {
    FocusScope.of(context).unfocus();
    final options = _readOptions();
    final fetcher = widget.fetchGames;
    if (options == null || fetcher == null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final fetched = await fetcher(options);
      if (!mounted) return;
      final unique = <String>{};
      final parsed = <_HistoryImportGame>[];
      for (final pgn in fetched) {
        final game = _HistoryImportGame.fromPgn(pgn);
        if (!game.isFinished || !unique.add(pgn.trim())) continue;
        parsed.add(game);
        if (parsed.length >= historyPgnBatchLimit) break;
      }
      setState(() {
        loading = false;
        games = parsed;
        selectedIndexes
          ..clear()
          ..addAll(List<int>.generate(parsed.length, (index) => index));
        if (parsed.isEmpty) error = 'No finished games found.';
      });
    } catch (fetchError) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = fetchError.toString();
      });
    }
  }

  Future<void> _importSelected() async {
    final importer = widget.importGames;
    if (importer == null || importing) return;
    final indexes = selectedIndexes.toList()..sort();
    if (indexes.isEmpty) {
      setState(() => error = 'Choose at least one game.');
      return;
    }
    if (indexes.length > historyPgnBatchLimit) {
      setState(() => error = 'You can import up to 500 games at a time.');
      return;
    }
    setState(() {
      importing = true;
      error = null;
    });
    final source =
        widget.source == _HistoryImportSource.chesscom ? 'chesscom' : 'lichess';
    final result = await importer(
      indexes.map((index) => games[index].pgn).join('\n\n\n'),
      source,
    );
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      Navigator.of(context).pop(result.data!);
      return;
    }
    setState(() {
      importing = false;
      error = result.status.errorMessage ?? 'Unable to import selected games.';
    });
  }
}

class _HistoryImportGame {
  const _HistoryImportGame({
    required this.pgn,
    required this.fen,
    required this.white,
    required this.black,
    required this.result,
    required this.date,
    required this.timeControl,
    required this.location,
  });

  factory _HistoryImportGame.fromPgn(String pgn) {
    String tag(String name) =>
        RegExp(
          '^\\[$name\\s+"([^"]*)"\\]\$',
          multiLine: true,
        ).firstMatch(pgn)?.group(1)?.trim() ??
        '';
    return _HistoryImportGame(
      pgn: pgn.trim(),
      fen: gameRecordFinalFenFromPgn(pgn),
      white: tag('White').isEmpty ? '?' : tag('White'),
      black: tag('Black').isEmpty ? '?' : tag('Black'),
      result: tag('Result'),
      date: tag('UTCDate').isNotEmpty ? tag('UTCDate') : tag('Date'),
      timeControl: tag('TimeControl'),
      location: tag('Site'),
    );
  }

  final String pgn;
  final String fen;
  final String white;
  final String black;
  final String result;
  final String date;
  final String timeControl;
  final String location;

  bool get isFinished =>
      result == '1-0' || result == '0-1' || result == '1/2-1/2';
}

class _HistoryImportGameTile extends StatelessWidget {
  const _HistoryImportGameTile({
    required this.game,
    required this.sourceLabel,
    required this.boardSize,
    required this.selected,
    required this.enabled,
    required this.strings,
    required this.onChanged,
    super.key,
  });

  final _HistoryImportGame game;
  final String sourceLabel;
  final double boardSize;
  final bool selected;
  final bool enabled;
  final GameRecordStrings strings;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = game.date.isEmpty || game.date.contains('?')
        ? strings.t('Unknown')
        : game.date.replaceAll('.', '-');
    final timeControl = game.timeControl.isEmpty || game.timeControl == '-'
        ? strings.t('Unknown')
        : game.timeControl;
    final location = game.location.isEmpty || game.location == '-'
        ? sourceLabel
        : game.location;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.34)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected
              ? scheme.primary.withValues(alpha: 0.58)
              : scheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onChanged : null,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox.square(
                  dimension: boardSize,
                  child: ChessBoard(
                    pieces: gameRecordPiecesFromFen(game.fen),
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
                      '${strings.t('White')}: ${game.white} / '
                      '${strings.t('Black')}: ${game.black}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$sourceLabel / ${strings.t('Time')}: $timeControl',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${strings.t('Date')}: $date / '
                      '${strings.t('Result')}: ${game.result}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${strings.t('Location')}: $location',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Checkbox(
                value: selected,
                onChanged: enabled ? (_) => onChanged?.call() : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportChoiceMenu extends StatelessWidget {
  const _ImportChoiceMenu({
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final String Function(String value) labelFor;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final item in values)
          DropdownMenuItem<String>(
            value: item,
            child: Text(
              labelFor(item),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.filter,
    required this.expanded,
    required this.isChessnutClockDevice,
    required this.activeCount,
    required this.showingRemoteResults,
    required this.remoteSearch,
    required this.remoteSearchLoading,
    required this.remoteSearchError,
    required this.importJob,
    required this.importRunning,
    required this.importCanceling,
    required this.importError,
    required this.importSourceLabel,
    required this.onSearchAll,
    required this.onClearRemote,
    required this.onCancelImport,
    required this.onToggleExpanded,
    required this.onChanged,
  });

  final GameRecordFilter filter;
  final bool expanded;
  final bool isChessnutClockDevice;
  final int activeCount;
  final bool showingRemoteResults;
  final GameRecordRemoteSearchResult? remoteSearch;
  final bool remoteSearchLoading;
  final String? remoteSearchError;
  final LichessImportJob? importJob;
  final bool importRunning;
  final bool importCanceling;
  final String? importError;
  final String importSourceLabel;
  final VoidCallback? onSearchAll;
  final VoidCallback? onClearRemote;
  final VoidCallback? onCancelImport;
  final VoidCallback onToggleExpanded;
  final ValueChanged<GameRecordFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = GameRecordStrings.of(context);
    final mediaSize = MediaQuery.sizeOf(context);
    final stackAndroidPortraitActions = expanded &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !isChessnutClockDevice &&
        mediaSize.height > mediaSize.width &&
        mediaSize.width < 600;

    Widget headerRow({required bool includeArchiveActions}) {
      return Row(
        children: [
          const Icon(Icons.tune_rounded),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Filters',
              key: ValueKey('game-record-filter-title'),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          if (activeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$activeCount active',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          if (includeArchiveActions) ...[
            const SizedBox(width: 8),
            _FilterArchiveActions(
              showingRemoteResults: showingRemoteResults,
              remoteSearchLoading: remoteSearchLoading,
              onSearchAll: onSearchAll,
              onClearRemote: onClearRemote,
            ),
          ],
          const SizedBox(width: 8),
          Icon(
              expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
        ],
      );
    }

    return GlassPanel(
      key: const ValueKey('game-record-filter-panel'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: 14,
      child: SectionColumn(
        spacing: 8,
        children: [
          InkWell(
            key: const ValueKey('game-record-filter-toggle'),
            onTap: onToggleExpanded,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: stackAndroidPortraitActions
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        headerRow(includeArchiveActions: false),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _FilterArchiveActions(
                            showingRemoteResults: showingRemoteResults,
                            remoteSearchLoading: remoteSearchLoading,
                            onSearchAll: onSearchAll,
                            onClearRemote: onClearRemote,
                          ),
                        ),
                      ],
                    )
                  : headerRow(includeArchiveActions: expanded),
            ),
          ),
          if (expanded) ...[
            _ArchiveStatusList(
              remoteSearch: remoteSearch,
              remoteSearchError: remoteSearchError,
              importJob: importJob,
              importRunning: importRunning,
              importCanceling: importCanceling,
              importError: importError,
              importSourceLabel: importSourceLabel,
              onCancelImport: onCancelImport,
            ),
            TextField(
              onChanged: (value) => onChanged(filter.copyWith(query: value)),
              decoration: const InputDecoration(
                labelText: 'Search games',
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Opponent, opening, event, source',
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final menuWidth = constraints.maxWidth < 360
                    ? constraints.maxWidth
                    : ((constraints.maxWidth - 8) / 2).clamp(150.0, 220.0);
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ChoiceMenu<RecordResultFilter>(
                      key: const ValueKey('game-record-filter-result'),
                      width: menuWidth,
                      label: 'Result',
                      value: filter.result,
                      values: RecordResultFilter.values,
                      labelFor: strings.resultFilterLabel,
                      onChanged: (value) =>
                          onChanged(filter.copyWith(result: value)),
                    ),
                    _ChoiceMenu<RecordColorFilter>(
                      key: const ValueKey('game-record-filter-color'),
                      width: menuWidth,
                      label: 'Color',
                      value: filter.color,
                      values: RecordColorFilter.values,
                      labelFor: strings.colorFilterLabel,
                      onChanged: (value) =>
                          onChanged(filter.copyWith(color: value)),
                    ),
                    _ChoiceMenu<RecordSpeedFilter>(
                      key: const ValueKey('game-record-filter-speed'),
                      width: menuWidth,
                      label: 'Speed',
                      value: filter.speed,
                      values: RecordSpeedFilter.values,
                      labelFor: strings.speedFilterLabel,
                      onChanged: (value) =>
                          onChanged(filter.copyWith(speed: value)),
                    ),
                    _ChoiceMenu<RecordReportFilter>(
                      key: const ValueKey('game-record-filter-report'),
                      width: menuWidth,
                      label: 'Analysis type',
                      value: filter.report,
                      values: RecordReportFilter.values,
                      labelFor: _reportLabel,
                      onChanged: (value) =>
                          onChanged(filter.copyWith(report: value)),
                    ),
                    _ChoiceMenu<RecordSortMode>(
                      key: const ValueKey('game-record-filter-sort'),
                      width: menuWidth,
                      label: 'Sort',
                      value: filter.sort,
                      values: RecordSortMode.values,
                      labelFor: _sortLabel,
                      onChanged: (value) =>
                          onChanged(filter.copyWith(sort: value)),
                    ),
                  ],
                );
              },
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('15+ moves'),
                  selected: filter.minMoves >= 15,
                  onSelected: (selected) =>
                      onChanged(filter.copyWith(minMoves: selected ? 15 : 0)),
                ),
                FilterChip(
                  label: const Text('30+ moves'),
                  selected: filter.minMoves >= 30,
                  onSelected: (selected) =>
                      onChanged(filter.copyWith(minMoves: selected ? 30 : 0)),
                ),
                FilterChip(
                  label: const Text('Analyzed'),
                  selected: filter.onlyAnalyzed,
                  onSelected: (selected) =>
                      onChanged(filter.copyWith(onlyAnalyzed: selected)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _reportLabel(RecordReportFilter value) {
    return switch (value) {
      RecordReportFilter.all => 'All analysis reports',
      RecordReportFilter.unanalyzed => 'No analysis',
      RecordReportFilter.standard => 'Standard analysis',
      RecordReportFilter.grandeur => 'Grandeur analysis',
    };
  }

  String _sortLabel(RecordSortMode value) {
    return switch (value) {
      RecordSortMode.newest => 'Newest',
      RecordSortMode.oldest => 'Oldest',
    };
  }
}

class _FilterArchiveActions extends StatelessWidget {
  const _FilterArchiveActions({
    required this.showingRemoteResults,
    required this.remoteSearchLoading,
    required this.onSearchAll,
    required this.onClearRemote,
  });

  final bool showingRemoteResults;
  final bool remoteSearchLoading;
  final VoidCallback? onSearchAll;
  final VoidCallback? onClearRemote;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          key: const ValueKey('game-record-search-all'),
          height: 34,
          child: FilledButton.tonalIcon(
            onPressed: remoteSearchLoading ? null : onSearchAll,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            icon: remoteSearchLoading
                ? const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.manage_search_rounded, size: 17),
            label: Text(
              showingRemoteResults ? 'Search' : 'History',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (showingRemoteResults) ...[
          const SizedBox(width: 6),
          SizedBox(
            height: 34,
            child: TextButton.icon(
              onPressed: onClearRemote,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.devices_rounded, size: 18),
              label: const Text(
                'Local list',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChoiceMenu<T> extends StatelessWidget {
  const _ChoiceMenu({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
    required this.width,
  });

  final double width;
  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget menuText(T item) {
      return Text(
        labelFor(item),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      );
    }

    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        selectedItemBuilder: (context) => [
          for (final item in values)
            Align(
              alignment: Alignment.centerLeft,
              child: menuText(item),
            ),
        ],
        items: [
          for (final item in values)
            DropdownMenuItem<T>(
              value: item,
              child: menuText(item),
            ),
        ],
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }
}

class _RecordsStateCard extends StatelessWidget {
  const _RecordsStateCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      key: const ValueKey('game-record-state-card'),
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: scheme.secondary),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

String _normalizePlayerName(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
}
