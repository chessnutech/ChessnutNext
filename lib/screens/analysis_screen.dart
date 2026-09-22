import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import '../l10n/app_strings.dart';
import '../l10n/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';

import '../models/app_models.dart';
import '../services/analysis_report_cache_service.dart';
import '../services/app_preferences_store.dart';
import '../services/app_shared_preferences.dart';
import '../services/board_settings_service.dart';
import '../services/chessnut_api_client.dart';
import '../services/commentary_tts_cache_service_stub.dart'
    if (dart.library.io) '../services/commentary_tts_cache_service.dart';
import '../services/game_notation_service.dart';
import '../services/grandeur_analysis_task_service.dart';
import '../services/grandeur_report_html_service.dart';
import '../services/maia3_human_review_task_service.dart';
import '../services/physical_board_gateway.dart';
import '../services/physical_board_orientation.dart';
import '../services/physical_board_protocol.dart';
import '../services/report_share_service.dart';
import '../services/standard_analysis_task_service.dart';
import '../services/stockfish_analysis_service.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_feedback.dart';
import '../widgets/chess_board.dart';

const _grandeurReviewCost = 100;
const _analysisScoreBarWidth = 30.0;

Future<void> _configureCommentaryAudioPlayer(AudioPlayer player) async {
  await player.setAudioContext(
    AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.speech,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {AVAudioSessionOptions.mixWithOthers},
      ),
    ),
  );
  await player.setVolume(1.0);
}

bool _isAndroidPhoneLandscapeLayout(
  BuildContext context, {
  required bool isChessnutClockDevice,
}) {
  final size = MediaQuery.sizeOf(context);
  return !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      !isChessnutClockDevice &&
      size.width > size.height &&
      size.width < 1000 &&
      size.height < 600;
}

double _androidPhoneLandscapeBoardMax(BuildContext context) {
  return (MediaQuery.sizeOf(context).height - 160)
      .clamp(190.0, 280.0)
      .toDouble();
}

String _buildGrandeurSummaryText(
  GrandeurAnalysisResult? analysis,
) {
  final backendSummary = analysis?.summaryText.trim() ?? '';
  if (backendSummary.isNotEmpty) return backendSummary;
  if (analysis == null) {
    return 'The Grandeur summary is still being generated. Once it is ready, this page will show the full-game summary.';
  }
  return 'No Grandeur summary was returned for this game.';
}

class _GrandeurJsonStatistics {
  const _GrandeurJsonStatistics({
    this.whiteAccuracy,
    this.blackAccuracy,
    this.whiteAccuracyText,
    this.blackAccuracyText,
    this.hasWhiteAccuracy = false,
    this.hasBlackAccuracy = false,
    this.whiteCounts = const {},
    this.blackCounts = const {},
  });

  final double? whiteAccuracy;
  final double? blackAccuracy;
  final String? whiteAccuracyText;
  final String? blackAccuracyText;
  final bool hasWhiteAccuracy;
  final bool hasBlackAccuracy;
  final Map<String, int> whiteCounts;
  final Map<String, int> blackCounts;

  /// The tag keys that are actually present in the response.  The order is
  /// the order defined by the Grandeur response schema (a through h), rather
  /// than an order inferred from move data or from the UI buckets.
  List<String> get tagKeys {
    final present = <String>{...whiteCounts.keys, ...blackCounts.keys};
    final known = _grandeurTagDefinitions.keys
        .where(present.contains)
        .toList(growable: false);
    final unknown = present
        .where((key) => !_grandeurTagDefinitions.containsKey(key))
        .toList()
      ..sort();
    return List<String>.unmodifiable([...known, ...unknown]);
  }
}

class _GrandeurTagDefinition {
  const _GrandeurTagDefinition({
    required this.key,
    required this.label,
    required this.symbol,
    required this.color,
  });

  final String key;
  final String label;
  final String symbol;
  final Color color;
}

// These are the meanings documented by the Grandeur JSON response PDF.
// Keep this list independent from the Stockfish/report classifications: the
// summary must render only tags supplied in statistics.{white,black}.tags.
const _grandeurTagDefinitions = <String, _GrandeurTagDefinition>{
  'a': _GrandeurTagDefinition(
    key: 'a',
    label: 'Brilliant',
    symbol: '!!',
    color: Color(0xFF34D399),
  ),
  'b': _GrandeurTagDefinition(
    key: 'b',
    label: 'Great',
    symbol: '!',
    color: Color(0xFF22D3EE),
  ),
  'c': _GrandeurTagDefinition(
    key: 'c',
    label: 'Best',
    symbol: '!!',
    color: Color(0xFFA3E635),
  ),
  'd': _GrandeurTagDefinition(
    key: 'd',
    label: 'Accurate',
    symbol: '·',
    color: Color(0xFF84CC16),
  ),
  'e': _GrandeurTagDefinition(
    key: 'e',
    label: 'Normal',
    symbol: '·',
    color: Color(0xFF64748B),
  ),
  'f': _GrandeurTagDefinition(
    key: 'f',
    label: 'Inaccuracy',
    symbol: '?!',
    color: Color(0xFFEAC84A),
  ),
  'g': _GrandeurTagDefinition(
    key: 'g',
    label: 'Mistake',
    symbol: '?',
    color: Color(0xFFF0A252),
  ),
  'h': _GrandeurTagDefinition(
    key: 'h',
    label: 'Blunder',
    symbol: '??',
    color: Color(0xFFE2574C),
  ),
};

_GrandeurJsonStatistics _grandeurJsonStatistics(
  GrandeurAnalysisResult? analysis,
) {
  final raw = analysis?.statistics;
  if (raw == null) return const _GrandeurJsonStatistics();

  Map<String, dynamic> side(String key) {
    final value = raw[key];
    return value is Map ? value.cast<String, dynamic>() : const {};
  }

  Map<String, int> tags(Map<String, dynamic> side) {
    final value = side['tags'];
    if (value is! Map) return const {};
    final result = <String, int>{};
    for (final entry in value.entries) {
      final key = entry.key.toString().trim().toLowerCase();
      if (key.isEmpty) continue;
      final count = entry.value is num
          ? (entry.value as num).toInt()
          : int.tryParse(entry.value.toString()) ?? 0;
      result[key] = count;
    }
    return result;
  }

  double? score(Map<String, dynamic> side) {
    final value = side['score'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String? scoreText(Map<String, dynamic> side) {
    final value = side['score'];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  final white = side('white');
  final black = side('black');
  final whiteScore = score(white);
  final blackScore = score(black);
  return _GrandeurJsonStatistics(
    whiteAccuracy: whiteScore,
    blackAccuracy: blackScore,
    whiteAccuracyText: scoreText(white),
    blackAccuracyText: scoreText(black),
    hasWhiteAccuracy: whiteScore != null,
    hasBlackAccuracy: blackScore != null,
    // The PDF defines statistics as statistics.{white,black}.tags (a-h).
    // Keep only keys actually present in the JSON; do not infer missing tags.
    whiteCounts: tags(white),
    blackCounts: tags(black),
  );
}

_GrandeurTagDefinition _grandeurTagDefinition(String key) {
  return _grandeurTagDefinitions[key] ??
      _GrandeurTagDefinition(
        key: key,
        // The documented response uses a-h. Preserve any additional key
        // verbatim instead of dropping data returned by the service.
        label: key,
        symbol: key,
        color: const Color(0xFF64748B),
      );
}

String? _grandeurStatsBucket(String label) {
  final trimmed = label.trim();
  final key = trimmed
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_\-]+'), '')
      .replaceFirst(RegExp(r'(count|counts|moves)$'), '');
  final exact = switch (key) {
    'a' || 'brilliant' => 'Brilliant',
    'b' || 'great' => 'Great',
    'c' || 'best' || 'book' => 'Best',
    'd' || 'accurate' => 'Excellent',
    'e' || 'normal' || 'good' => 'Good',
    'excellent' => 'Excellent',
    'f' || 'inaccuracy' || 'inaccurate' => 'Inaccuracy',
    'g' || 'mistake' || 'mistakes' || 'criticalswing' => 'Mistake',
    'h' || 'blunder' || 'blunders' => 'Blunder',
    'missedwin' || 'miss' || 'missed' => 'Miss',
    _ => null,
  };
  if (exact != null) return exact;

  // The report may localize `classification`; keep this fallback independent
  // from the UI language so localized labels still contribute to totals.
  final localized = key;
  if (localized.contains('精彩') ||
      localized.contains('神来之笔') ||
      localized.contains('神來之筆') ||
      localized.contains('brillante') ||
      localized.contains('brillant')) {
    return 'Brilliant';
  }
  if (localized.contains('很棒') ||
      localized.contains('出色') ||
      localized.contains('genial') ||
      localized.contains('super') ||
      localized.contains('ottimo') ||
      localized.contains('훌륭') ||
      localized.contains('отлично')) {
    return 'Great';
  }
  if (localized.contains('错失胜机') ||
      localized.contains('錯過勝機') ||
      localized.contains('missedwin') ||
      localized.contains('victoriaperdida') ||
      localized.contains('gemistewinst') ||
      localized.contains('упущеннаяпобеда')) {
    return 'Miss';
  }
  if (localized.contains('失误') ||
      localized.contains('失誤') ||
      localized.contains('重大失误') ||
      localized.contains('重大失誤') ||
      localized.contains('严重失误') ||
      localized.contains('嚴重失誤') ||
      localized.contains('blunder') ||
      localized.contains('patzer') ||
      localized.contains('gaf') ||
      localized.contains('errograve') ||
      localized.contains('грубаяошибка')) {
    return 'Blunder';
  }
  if (localized.contains('不准确') ||
      localized.contains('不準確') ||
      localized.contains('不精确') ||
      localized.contains('不精確') ||
      localized.contains('不正確') ||
      localized.contains('inaccuracy') ||
      localized.contains('imprecision') ||
      localized.contains('imprecis') ||
      localized.contains('ungena') ||
      localized.contains('inexact') ||
      localized.contains('неточ') ||
      localized.contains('부정확')) {
    return 'Inaccuracy';
  }
  if (localized.contains('错误') ||
      localized.contains('錯誤') ||
      localized.contains('mistake') ||
      localized.contains('erreur') ||
      localized.contains('fehler') ||
      localized.contains('greșeală') ||
      localized.contains('błąd') ||
      localized.contains('ошибка') ||
      localized.contains('실수')) {
    return 'Mistake';
  }
  if (localized.contains('优秀') ||
      localized.contains('優秀') ||
      localized.contains('excellent') ||
      localized.contains('ausgezeichnet') ||
      localized.contains('excelente') ||
      localized.contains('eccellente') ||
      localized.contains('uitstekend') ||
      localized.contains('отличный') ||
      localized.contains('우수')) {
    return 'Excellent';
  }
  if (localized.contains('最佳') ||
      localized.contains('最善') ||
      localized.contains('best') ||
      localized.contains('meilleur') ||
      localized.contains('mejor') ||
      localized.contains('migliore') ||
      localized.contains('лучший')) {
    return 'Best';
  }
  if (localized.contains('良好') ||
      localized.contains('准确') ||
      localized.contains('準確') ||
      localized.contains('精确') ||
      localized.contains('精確') ||
      localized.contains('good') ||
      localized.contains('accurate') ||
      localized.contains('normal') ||
      localized.contains('gut') ||
      localized.contains('buono') ||
      localized.contains('bon') ||
      localized.contains('goed') ||
      localized.contains('хорошо') ||
      localized.contains('良い') ||
      localized.contains('좋음')) {
    return 'Good';
  }
  return null;
}

typedef AnalysisPgnFileLoader = Future<String?> Function();

enum _Maia3ReviewTab { insight, moves, rating, summary }

const bool _showMaia3RatingTab = false;

int _normalizeMaia3ReviewElo(int value) {
  final clamped = value.clamp(maia3MinElo, maia3MaxElo).toInt();
  return (clamped / maia3EloStep).round() * maia3EloStep;
}

Future<String?> loadAnalysisPgnFileFromDesktop() async {
  const pgnGroup = XTypeGroup(
    label: 'PGN',
    extensions: ['pgn', 'txt'],
    mimeTypes: ['application/x-chess-pgn', 'text/plain'],
  );
  final file = await openFile(acceptedTypeGroups: const [pgnGroup]);
  if (file == null) return null;
  final content = await file.readAsString();
  return content.trim().isEmpty ? null : content;
}

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({
    required this.onNavigate,
    required this.apiClient,
    this.positionAnalyzer,
    this.boardGateway,
    this.boardSettings = const BoardSettingsState(),
    this.showBoardCoordinates = false,
    this.isChessnutClockDevice = false,
    required this.attachedPgn,
    required this.onStartReview,
    required this.onOpenLastGame,
    this.pgnFileLoader = loadAnalysisPgnFileFromDesktop,
    this.onAnalysisStarted,
    this.onReportShared,
    this.onReportCacheChanged,
    this.reviewBackTarget = 'Analysis',
    this.reportCacheKey,
    this.initialReportPly,
    this.attachedCommentId = 0,
    this.reportCacheStore,
    this.reportShareService = const SystemReportShareService(),
    this.initialMaia3ReviewElo = 1500,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final ChessnutApiClient apiClient;
  final PositionAnalyzer? positionAnalyzer;
  final PhysicalBoardGateway? boardGateway;
  final BoardSettingsState boardSettings;
  final bool showBoardCoordinates;
  final bool isChessnutClockDevice;
  final String? attachedPgn;
  final FutureOr<void> Function(String pgn) onStartReview;
  final VoidCallback onOpenLastGame;
  final AnalysisPgnFileLoader pgnFileLoader;
  final VoidCallback? onAnalysisStarted;
  final VoidCallback? onReportShared;
  final FutureOr<void> Function()? onReportCacheChanged;
  final String reviewBackTarget;
  final String? reportCacheKey;
  final int? initialReportPly;
  final int attachedCommentId;
  final AppPreferencesAnalysisReportCacheStore? reportCacheStore;
  final ReportShareService reportShareService;
  final int initialMaia3ReviewElo;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  late final TextEditingController pgnController;
  String? parseError;

  @override
  void initState() {
    super.initState();
    pgnController = TextEditingController();
  }

  @override
  void dispose() {
    pgnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attachedPgn = widget.attachedPgn;
    if (attachedPgn != null) {
      return _ReviewState(
        onNavigate: widget.onNavigate,
        apiClient: widget.apiClient,
        positionAnalyzer: widget.positionAnalyzer,
        boardGateway: widget.boardGateway,
        boardSettings: widget.boardSettings,
        showBoardCoordinates: widget.showBoardCoordinates,
        isChessnutClockDevice: widget.isChessnutClockDevice,
        pgn: attachedPgn,
        onReportShared: widget.onReportShared,
        onReportCacheChanged: widget.onReportCacheChanged,
        reviewBackTarget: widget.reviewBackTarget,
        reportCacheKey: widget.reportCacheKey,
        initialReportPly: widget.initialReportPly,
        attachedCommentId: widget.attachedCommentId,
        reportCacheStore: widget.reportCacheStore,
        reportShareService: widget.reportShareService,
        initialMaia3ReviewElo: widget.initialMaia3ReviewElo,
        onAnalysisStarted: widget.onAnalysisStarted,
      );
    }

    return _PgnEntryState(
      onNavigate: widget.onNavigate,
      controller: pgnController,
      parseError: parseError,
      onStartReview: _startReviewFromInput,
      onOpenLastGame: widget.onOpenLastGame,
      onImportPgnFile: _importPgnFile,
      isChessnutClockDevice: widget.isChessnutClockDevice,
    );
  }

  Future<void> _importPgnFile() async {
    String? content;
    try {
      content = await widget.pgnFileLoader();
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        parseError = error.message ??
            'Unable to open this PGN file. Choose another file and try again.';
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        parseError =
            'Unable to open this PGN file. Choose another file and try again.';
      });
      return;
    }
    if (!mounted || content == null) return;
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      setState(() => parseError = 'The selected PGN file is empty.');
      return;
    }
    pgnController.text = trimmed;
    setState(() => parseError = null);
  }

  Future<void> _startReviewFromInput() async {
    final enteredPgn = pgnController.text.trim();
    if (enteredPgn.isEmpty) {
      setState(() => parseError = 'Paste a PGN before starting review.');
      return;
    }
    try {
      GameNotationService.parsePgn(enteredPgn);
    } on FormatException catch (error) {
      setState(() => parseError = _readablePgnError(error.message));
      return;
    } catch (error) {
      setState(
        () => parseError =
            'This PGN could not be read. Check the PGN text and try again.',
      );
      return;
    }
    setState(() => parseError = null);
    widget.onAnalysisStarted?.call();
    await widget.onStartReview(enteredPgn);
  }

  String _readablePgnError(String message) {
    if (message.contains('no legal mainline moves')) {
      return 'This PGN has no playable moves. Check the PGN text and try again.';
    }
    if (message.contains('Illegal')) {
      return 'This PGN includes a move Chessnut cannot read. Check the move list and try again.';
    }
    return 'This PGN could not be read. Check the PGN text and try again.';
  }
}

class _PgnEntryState extends StatelessWidget {
  const _PgnEntryState({
    required this.onNavigate,
    required this.controller,
    required this.parseError,
    required this.onStartReview,
    required this.onOpenLastGame,
    required this.onImportPgnFile,
    required this.isChessnutClockDevice,
  });

  final ValueChanged<String> onNavigate;
  final TextEditingController controller;
  final String? parseError;
  final FutureOr<void> Function() onStartReview;
  final VoidCallback onOpenLastGame;
  final FutureOr<void> Function() onImportPgnFile;
  final bool isChessnutClockDevice;

  @override
  Widget build(BuildContext context) {
    final androidPhoneLandscape = _isAndroidPhoneLandscapeLayout(
      context,
      isChessnutClockDevice: isChessnutClockDevice,
    );
    return ResponsivePage(
      compactLandscapeOverride: androidPhoneLandscape,
      children: (context, spec) {
        final media = MediaQuery.sizeOf(context);
        final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
        final landscapeCompact =
            media.width > media.height && media.height <= 620;
        final useAndroidSingleLineTitle = !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.android &&
            !isChessnutClockDevice;
        final stableHeight = keyboardInset > 0 && spec.height.isFinite
            ? (spec.height + keyboardInset).clamp(0.0, media.height).toDouble()
            : spec.height;
        final compactMinHeight = androidPhoneLandscape
            ? 0.0
            : stableHeight.isFinite && stableHeight < 332
                ? stableHeight
                : 332.0;
        final bodyHeight = landscapeCompact
            ? ResponsiveSpec(
                spec.width,
                height: stableHeight,
                compactLandscapeOverride: androidPhoneLandscape,
              ).heightAfterHeader(min: compactMinHeight)
            : 0.0;
        final leading = SectionColumn(
          spacing: landscapeCompact ? 8 : 12,
          children: [
            if (!landscapeCompact) const _AnalysisSourceCard(),
            _PgnInputCard(
              controller: controller,
              errorText: parseError,
              compact: landscapeCompact,
              expandedHeight: landscapeCompact ? bodyHeight : null,
              tall: !landscapeCompact && media.width >= 900,
            ),
          ],
        );
        final trailing = SectionColumn(
          spacing: landscapeCompact ? 8 : 12,
          children: [
            _ParserPreview(
              controller: controller,
              compact: landscapeCompact,
            ),
            PrimaryButton(
              label: 'Start review',
              icon: Icons.analytics_rounded,
              onPressed: onStartReview,
            ),
            _AnalysisEntryGrid(
              onNavigate: onNavigate,
              onOpenLastGame: onOpenLastGame,
              onImportPgnFile: onImportPgnFile,
              compact: landscapeCompact,
              compactLandscapeOverride: androidPhoneLandscape,
            ),
          ],
        );

        return [
          ScreenHeader(
            title: 'Analyze PGN',
            subtitle: 'Analysis',
            titleKey: const ValueKey('analysis-header-title'),
            titleMaxLines: useAndroidSingleLineTitle ? 1 : null,
            titleOverflow:
                useAndroidSingleLineTitle ? TextOverflow.ellipsis : null,
            compactTrailingFraction: useAndroidSingleLineTitle ? 0.18 : 0.34,
            leading: IconButton.filledTonal(
              onPressed: () => onNavigate('Back'),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            trailing: IconButton.filledTonal(
              key: const ValueKey('analysis-records-action'),
              onPressed: () => onNavigate('Records'),
              icon: const Icon(Icons.history_rounded),
            ),
          ),
          SizedBox(height: spec.gutter),
          if (landscapeCompact)
            SizedBox(
              key: androidPhoneLandscape
                  ? const ValueKey('analysis-entry-android-phone-landscape')
                  : null,
              height: bodyHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 6,
                    child: leading,
                  ),
                  SizedBox(width: spec.gutter),
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(
                      key: androidPhoneLandscape
                          ? const ValueKey('analysis-entry-right-scroll')
                          : null,
                      primary: false,
                      child: trailing,
                    ),
                  ),
                ],
              ),
            )
          else
            ResponsiveSplit(
              breakpoint: 900,
              spacing: spec.gutter,
              leadingFlex: 6,
              trailingFlex: 5,
              leading: leading,
              trailing: trailing,
            ),
        ];
      },
    );
  }
}

class _ReviewState extends StatefulWidget {
  const _ReviewState({
    required this.onNavigate,
    required this.apiClient,
    required this.positionAnalyzer,
    required this.boardGateway,
    required this.boardSettings,
    required this.showBoardCoordinates,
    required this.isChessnutClockDevice,
    required this.pgn,
    required this.reportShareService,
    this.onReportShared,
    this.onReportCacheChanged,
    this.reviewBackTarget = 'Analysis',
    this.reportCacheKey,
    this.initialReportPly,
    this.attachedCommentId = 0,
    this.reportCacheStore,
    this.initialMaia3ReviewElo = 1500,
    this.onAnalysisStarted,
  });

  final ValueChanged<String> onNavigate;
  final ChessnutApiClient apiClient;
  final PositionAnalyzer? positionAnalyzer;
  final PhysicalBoardGateway? boardGateway;
  final BoardSettingsState boardSettings;
  final bool showBoardCoordinates;
  final bool isChessnutClockDevice;
  final String pgn;
  final VoidCallback? onReportShared;
  final FutureOr<void> Function()? onReportCacheChanged;
  final String reviewBackTarget;
  final String? reportCacheKey;
  final int? initialReportPly;
  final int attachedCommentId;
  final AppPreferencesAnalysisReportCacheStore? reportCacheStore;
  final ReportShareService reportShareService;
  final int initialMaia3ReviewElo;
  final VoidCallback? onAnalysisStarted;

  @override
  State<_ReviewState> createState() => _ReviewStateState();
}

class _ReviewStateState extends State<_ReviewState> {
  late List<ReviewMove> moves;
  late int selectedPly;
  late ParsedPgnGame parsedGame;
  bool analysisStartNotified = false;
  GrandeurCoachProfile selectedGrandeurStyle = defaultGrandeurReviewStyle;
  bool voiceMuted = false;
  bool showGrandeurPage = false;
  bool showGrandeurSummary = false;
  bool showStandardReport = false;
  bool showMaia3Page = false;
  bool analysisBoardFlipped = false;
  bool grandeurBoardFlipped = false;
  bool grandeurAutoPlaying = false;
  bool grandeurLoading = false;
  bool grandeurWalletLoading = false;
  bool grandeurWalletUnlocked = false;
  double grandeurProgress = 0;
  bool stockfishLoading = false;
  bool stockfishBacked = false;
  bool stockfishComplete = false;
  double stockfishProgress = 0;
  int stockfishCompletedPositions = 0;
  int stockfishTotalPositions = 0;
  String? grandeurStatus;
  String? stockfishStatus;
  String? maia3Status;
  GrandeurAnalysisResult? grandeurAnalysis;
  Maia3HumanReviewReport? maia3Analysis;
  GrandeurReviewJob? grandeurJob;
  int _grandeurRecordId = 0;
  GrandeurAnalysisTask? grandeurTask;
  Maia3HumanReviewTask? maia3Task;
  StandardAnalysisTaskHandle? standardAnalysisTask;
  VoidCallback? standardAnalysisTaskListener;
  VoidCallback? grandeurTaskListener;
  VoidCallback? maia3TaskListener;
  StreamSubscription<String>? boardFenSubscription;
  StreamSubscription<PhysicalBoardConnectionState>? boardStateSubscription;
  late final BoardFenStabilityBuffer boardFenStabilityBuffer;
  late final PhysicalBoardOrientationResolver _boardOrientation;
  String? physicalBoardFen;
  String? lastMoveBoardTargetFen;
  String? lastAnalysisLedSignature;
  final GlobalKey _standardReportShareKey = GlobalKey();
  final GlobalKey _grandeurReportShareKey = GlobalKey();
  final GlobalKey _grandeurSummaryShareKey = GlobalKey();
  bool reportSharing = false;
  bool reportDownloading = false;
  late int selectedMaia3ReviewElo;
  late int standardAnalysisDepth;
  late String commentaryVoiceGender;
  bool maia3CompareStockfish = true;
  int _standardAnalysisGeneration = 0;
  String get _cacheKey =>
      widget.reportCacheKey ?? gameAnalysisReportCacheKeyForPgn(widget.pgn);
  String get _grandeurCacheKey =>
      _grandeurRecordId > 0 ? 'pgn:$_grandeurRecordId' : _cacheKey;
  String get _maia3BaseCacheKey => maia3HumanReviewCacheKey(_cacheKey);
  String get _maia3CacheKey => maia3HumanReviewSettingsCacheKey(
        _maia3BaseCacheKey,
        elo: selectedMaia3ReviewElo,
      );
  bool get _returnsHomeOnBack => widget.reviewBackTarget == 'Home';
  bool get _canShowStockfishMoveAnalysis =>
      widget.pgn.trim() == _sampleReviewPgn.trim() || stockfishBacked;

  @override
  void initState() {
    super.initState();
    _boardOrientation = PhysicalBoardOrientationResolver(
      settings: widget.boardSettings,
    );
    boardFenStabilityBuffer = BoardFenStabilityBuffer(
      onStableFen: (fen) => unawaited(_handlePhysicalBoardFen(fen)),
    );
    parsedGame = GameNotationService.parsePgn(widget.pgn);
    if (widget.attachedCommentId > 0) {
      _grandeurRecordId = _recordIdFromCacheKey() ?? 0;
    }
    selectedMaia3ReviewElo = _normalizeMaia3ReviewElo(
      widget.initialMaia3ReviewElo,
    );
    standardAnalysisDepth = AppSharedPreferences.get<int>(
      AppSettingKeys.standardAnalysisDepth,
    ).clamp(6, 20).toInt();
    commentaryVoiceGender = AppSharedPreferences.get<String>(
      AppSettingKeys.commentaryVoiceGender,
    );
    moves = widget.pgn.trim() == _sampleReviewPgn.trim()
        ? reviewMoves
        : buildReviewMovesFromParsedGame(parsedGame);
    final initialReportPly = widget.initialReportPly;
    selectedPly = initialReportPly != null &&
            moves.any((move) => move.ply == initialReportPly)
        ? initialReportPly
        : moves.first.ply;
    showStandardReport = initialReportPly != null;
    if (widget.pgn.trim() != _sampleReviewPgn.trim()) {
      _notifyAnalysisStarted();
      stockfishLoading = true;
      stockfishTotalPositions = parsedGame.snapshots.length;
      stockfishStatus = 'Stockfish is evaluating every PGN position...';
    }
    _startPhysicalBoardSync();
    _hydrateCachedReportThenStartStockfish();
  }

  @override
  void didUpdateWidget(covariant _ReviewState oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_boardOrientation.updateSettings(widget.boardSettings)) {
      _resetPhysicalBoardOrientationCache();
      unawaited(_syncSelectedMoveToPhysicalBoard(force: true));
    }
    if (!identical(oldWidget.boardGateway, widget.boardGateway)) {
      boardFenSubscription?.cancel();
      boardStateSubscription?.cancel();
      boardFenSubscription = null;
      boardStateSubscription = null;
      physicalBoardFen = null;
      lastMoveBoardTargetFen = null;
      lastAnalysisLedSignature = null;
      boardFenStabilityBuffer.cancelPending();
      _startPhysicalBoardSync();
    }
  }

  @override
  void dispose() {
    boardFenSubscription?.cancel();
    boardStateSubscription?.cancel();
    boardFenStabilityBuffer.dispose();
    unawaited(_clearAnalysisBoardLeds());
    _detachStandardAnalysisTask(cancel: true);
    _detachGrandeurTask();
    _detachMaia3Task();
    super.dispose();
  }

  ReviewMove get selectedMove => moves.firstWhere(
        (move) => move.ply == selectedPly,
        orElse: () => moves.first,
      );

  void _startPhysicalBoardSync() {
    final gateway = widget.boardGateway;
    if (gateway == null) return;
    boardFenSubscription = gateway.boardFenStream.listen((fen) {
      final boardFen = _normalizePhysicalBoardFen(fen);
      if (boardFen.isEmpty) return;
      boardFenStabilityBuffer.add(boardFen);
    });
    boardStateSubscription = gateway.stateStream.listen((state) {
      if (state != PhysicalBoardConnectionState.connected) return;
      final latestFen = gateway.latestBoardFen;
      if (latestFen != null && latestFen.trim().isNotEmpty) {
        boardFenStabilityBuffer.add(_normalizePhysicalBoardFen(latestFen));
      } else {
        unawaited(_syncSelectedMoveToPhysicalBoard(force: true));
      }
    });
    if (gateway.currentState == PhysicalBoardConnectionState.connected) {
      final latestFen = gateway.latestBoardFen;
      if (latestFen != null && latestFen.trim().isNotEmpty) {
        boardFenStabilityBuffer.add(_normalizePhysicalBoardFen(latestFen));
      } else {
        unawaited(_syncSelectedMoveToPhysicalBoard(force: true));
      }
    }
  }

  String _normalizePhysicalBoardFen(String fen) {
    return _boardOrientation.normalizeAndTrack(
      fen,
      referenceFens: [for (final move in moves) move.fen],
      onMappingChanged: (_) => _resetPhysicalBoardOrientationCache(),
    );
  }

  void _resetPhysicalBoardOrientationCache() {
    lastMoveBoardTargetFen = null;
    lastAnalysisLedSignature = null;
  }

  Future<void> _handlePhysicalBoardFen(String fen) async {
    final boardFen = _analysisBoardOnlyFen(fen);
    if (boardFen.isEmpty) return;
    physicalBoardFen = boardFen;
    await _syncSelectedMoveToPhysicalBoard(fromPhysicalBoard: true);
  }

  void _notifyAnalysisStarted() {
    if (analysisStartNotified) return;
    analysisStartNotified = true;
    widget.onAnalysisStarted?.call();
  }

  void _selectPly(int ply) {
    if (ply == selectedPly) {
      unawaited(_syncSelectedMoveToPhysicalBoard(force: true));
      return;
    }
    setState(() => selectedPly = ply);
    unawaited(_syncSelectedMoveToPhysicalBoard(force: true));
  }

  void _selectPreviousPly() {
    final index = moves.indexWhere((move) => move.ply == selectedPly);
    if (index > 0) _selectPly(moves[index - 1].ply);
  }

  void _selectNextPly() {
    final index = moves.indexWhere((move) => move.ply == selectedPly);
    if (index >= 0 && index < moves.length - 1) {
      _selectPly(moves[index + 1].ply);
    }
  }

  void _selectFirstPly() {
    _selectPly(moves.first.ply);
  }

  void _selectLastPly() {
    _selectPly(moves.last.ply);
  }

  Future<void> _syncSelectedMoveToPhysicalBoard({
    bool force = false,
    bool fromPhysicalBoard = false,
  }) async {
    final gateway = widget.boardGateway;
    if (gateway == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      return;
    }
    final move = selectedMove;
    final targetFen = move.fen;
    final targetBoardFen = _analysisBoardOnlyFen(targetFen);
    final physicalFen = physicalBoardFen;
    final diff = physicalFen == null
        ? const <String>{}
        : _analysisDifferentSquares(physicalFen, targetBoardFen);
    if (gateway.boardModel == PhysicalBoardModel.evo2) {
      await _sendEvo2AnalysisLeds(move);
      return;
    }
    if (gateway.boardModel == PhysicalBoardModel.move) {
      await _sendMoveAnalysisLeds(diff);
      final shouldRestoreMismatch = fromPhysicalBoard && diff.isNotEmpty;
      if (!force && !shouldRestoreMismatch && physicalFen == targetBoardFen) {
        lastMoveBoardTargetFen = targetFen;
        return;
      }
      if (!force &&
          !shouldRestoreMismatch &&
          lastMoveBoardTargetFen == targetFen) {
        return;
      }
      final sent = await gateway.setMoveBoardFen(
        targetFen,
        isReverse: _boardOrientation.isReversed,
      );
      if (sent) lastMoveBoardTargetFen = targetFen;
      return;
    }
    if (gateway.boardModel.usesGeneralProtocol) {
      await _sendGeneralAnalysisLeds(diff);
    }
  }

  Future<void> _sendEvo2AnalysisLeds(ReviewMove move) async {
    final gateway = widget.boardGateway;
    if (gateway == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected ||
        gateway.boardModel != PhysicalBoardModel.evo2) {
      return;
    }
    final markerKey = move.hasBoardMarker
        ? _evo2AnalysisMarkerPatternKey(move.classification)
        : null;
    final focusSquare = move.focusSquare.clampSquareName();
    final nextSignature = _analysisLedSignature(
      gateway.boardModel,
      markerKey == null ? const <String>{} : {focusSquare},
      extra: '${widget.boardSettings.evo2LedPatterns.hashCode}:$markerKey',
    );
    if (lastAnalysisLedSignature == nextSignature) return;
    final keys = List<String?>.filled(64, null);
    if (markerKey != null) {
      final index = _analysisSquareIndex(focusSquare);
      if (index != null) keys[index] = markerKey;
    }
    final sent = await gateway.setEvo2LedPatternKeys(
      keys,
      widget.boardSettings.evo2LedPatterns,
    );
    if (sent) lastAnalysisLedSignature = nextSignature;
  }

  Future<void> _sendMoveAnalysisLeds(Set<String> squares) async {
    final gateway = widget.boardGateway;
    if (gateway == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected ||
        gateway.boardModel != PhysicalBoardModel.move) {
      return;
    }
    final normalized = Set<String>.unmodifiable(
      _boardOrientation.toPhysicalSquares(squares.where(_isSquareName)),
    );
    final nextSignature = _analysisLedSignature(gateway.boardModel, normalized);
    if (lastAnalysisLedSignature == nextSignature) return;
    final sent = normalized.isEmpty
        ? await gateway.clearMoveLeds()
        : await gateway.setMoveLedSquares({
            for (final square in normalized) square: ChessnutMoveLedColor.red,
          });
    if (sent) lastAnalysisLedSignature = nextSignature;
  }

  Future<void> _sendGeneralAnalysisLeds(Set<String> squares) async {
    final gateway = widget.boardGateway;
    if (gateway == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected ||
        !gateway.boardModel.usesGeneralProtocol) {
      return;
    }
    final normalized = Set<String>.unmodifiable(
      _boardOrientation.toPhysicalSquares(squares.where(_isSquareName)),
    );
    final nextSignature = _analysisLedSignature(gateway.boardModel, normalized);
    if (lastAnalysisLedSignature == nextSignature) return;
    final sent = normalized.isEmpty
        ? await gateway.clearGeneralLeds()
        : await gateway.setGeneralLedSquares(normalized);
    if (sent) lastAnalysisLedSignature = nextSignature;
  }

  Future<void> _clearAnalysisBoardLeds() async {
    lastAnalysisLedSignature = null;
    final gateway = widget.boardGateway;
    if (gateway == null ||
        gateway.currentState != PhysicalBoardConnectionState.connected) {
      return;
    }
    if (gateway.boardModel == PhysicalBoardModel.move) {
      await gateway.clearMoveLeds();
      await gateway.stopMoveBoard();
    } else if (gateway.boardModel == PhysicalBoardModel.evo2) {
      await gateway.setEvo2LedPatternKeys(
        List<String?>.filled(64, null),
        widget.boardSettings.evo2LedPatterns,
      );
    } else if (gateway.boardModel.usesGeneralProtocol) {
      await gateway.clearGeneralLeds();
    }
  }

  void _openStandardReport() {
    setState(() => showStandardReport = true);
  }

  void _closeStandardReport() {
    if (_returnsHomeOnBack) {
      widget.onNavigate('Home');
      return;
    }
    if (widget.reviewBackTarget == 'MistakeBook') {
      widget.onNavigate('MistakeBook');
      return;
    }
    setState(() => showStandardReport = false);
  }

  void _openMaia3Page() {
    setState(() => showMaia3Page = true);
  }

  void _closeMaia3Page() {
    if (_returnsHomeOnBack) {
      widget.onNavigate('Home');
      return;
    }
    setState(() => showMaia3Page = false);
  }

  void _openGrandeurPage() {
    setState(() {
      showGrandeurPage = true;
      showGrandeurSummary = false;
      grandeurAutoPlaying = false;
    });
    if (grandeurAnalysis == null && !grandeurLoading) {
      _startGrandeurAnalysis();
    }
  }

  Future<void> _openGrandeurWithWalletGate() async {
    if (grandeurWalletLoading) return;
    if (widget.attachedCommentId > 0) {
      _attachExistingGrandeurJob();
      await _persistGrandeurUnlock();
      _openGrandeurPage();
      return;
    }
    if (await _unlockCachedGrandeurIfAvailable()) {
      _openGrandeurPage();
      return;
    }
    if (grandeurAnalysis != null) {
      grandeurWalletUnlocked = true;
      _openGrandeurPage();
      return;
    }
    if (grandeurWalletUnlocked) {
      _openGrandeurPage();
      return;
    }
    if (widget.apiClient.session == null) {
      _showGrandeurSignInDialog();
      return;
    }
    final style = await _chooseGrandeurReviewStyle();
    if (!mounted || style == null) return;
    setState(() => selectedGrandeurStyle = style);
    setState(() => grandeurWalletLoading = true);
    final balanceResult = await widget.apiClient.walletBalance();
    if (!mounted) return;
    setState(() => grandeurWalletLoading = false);
    final balanceUnavailable =
        !balanceResult.isSuccess || balanceResult.data == null;
    final errorText = balanceResult.status.errorMessage?.toLowerCase() ?? '';
    final walletRouteMissing = balanceResult.status.apiErrorCode == 404 ||
        errorText.contains('wallet service is not available') ||
        errorText.contains('wallet is not available') ||
        errorText.contains('wallet unavailable') ||
        errorText.contains('not found') ||
        errorText.contains('404');
    if (balanceUnavailable && !walletRouteMissing) {
      _showGrandeurWalletError(
        balanceResult.status.errorMessage ?? 'Unable to load wallet.',
      );
      return;
    }
    final balance = balanceResult.data;
    if (balance != null) {
      if (!balance.memberActive && balance.balance < _grandeurReviewCost) {
        _showGrandeurInsufficientPointsDialog(balance.balance);
        return;
      }
    }
    final confirmed = balance == null
        ? await _confirmGrandeurServerVerifiedSpend()
        : await _confirmGrandeurPointSpend(balance);
    if (!mounted || !confirmed) return;
    setState(() => grandeurWalletLoading = true);
    final reviewResult = await widget.apiClient.startGrandeurReview(
      pgn: widget.pgn,
      language: widget.apiClient.grandeurLanguage.value,
      gameStep: parsedGame.moves.length,
      style: selectedGrandeurStyle.id,
    );
    if (!mounted) return;
    setState(() => grandeurWalletLoading = false);
    if (!reviewResult.isSuccess || reviewResult.data == null) {
      final message = reviewResult.status.errorMessage ??
          'Unable to start Grandeur review.';
      if (message.toLowerCase().contains('insufficient')) {
        _showGrandeurInsufficientPointsDialog(balance?.balance ?? 0);
      } else {
        _showGrandeurWalletError(message);
      }
      return;
    }
    grandeurJob = reviewResult.data;
    _grandeurRecordId = reviewResult.data!.pgnId;
    grandeurWalletUnlocked = true;
    await _persistGrandeurUnlock(job: reviewResult.data);
    _openGrandeurPage();
  }

  Future<bool> _unlockCachedGrandeurIfAvailable() async {
    if (grandeurAnalysis != null) {
      if (!grandeurWalletUnlocked && mounted) {
        setState(() => grandeurWalletUnlocked = true);
      }
      return true;
    }
    final cached = await _readCachedGrandeurReport();
    if (!mounted) return false;
    if (cached == null) return false;
    _applyCachedGrandeurStyle(cached);
    final cachedGrandeur = cached.grandeurReport;
    if (cached.grandeurCommentId > 0) {
      _attachGrandeurJobFromIds(
        commentId: cached.grandeurCommentId,
        pgnId: cached.serverPgnId,
      );
    }
    if (cachedGrandeur == null) {
      if (!cached.hasGrandeur) return false;
      setState(() {
        grandeurWalletUnlocked = true;
        grandeurStatus =
            'Grandeur is unlocked. Continuing the coach analysis...';
      });
      return true;
    }
    setState(() {
      grandeurAnalysis = cachedGrandeur;
      grandeurWalletUnlocked = true;
      grandeurStatus =
          'Grandeur analysis ready / ${cachedGrandeur.moves.length} move explanations loaded.';
    });
    return true;
  }

  void _closeGrandeurPage() {
    if (_returnsHomeOnBack) {
      grandeurAutoPlaying = false;
      widget.onNavigate('Home');
      return;
    }
    setState(() {
      showGrandeurPage = false;
      showGrandeurSummary = false;
      grandeurAutoPlaying = false;
    });
  }

  void _toggleGrandeurAutoPlay() {
    if (grandeurAnalysis == null) return;
    setState(() {
      grandeurAutoPlaying = !grandeurAutoPlaying;
      if (grandeurAutoPlaying) voiceMuted = false;
    });
  }

  void _handleGrandeurSpeechComplete() {
    if (!grandeurAutoPlaying) return;
    final index = moves.indexWhere((move) => move.ply == selectedPly);
    if (index >= 0 && index < moves.length - 1) {
      _selectPly(moves[index + 1].ply);
      return;
    }
    setState(() => grandeurAutoPlaying = false);
  }

  void _toggleGrandeurVoice() {
    setState(() {
      voiceMuted = !voiceMuted;
      if (voiceMuted) grandeurAutoPlaying = false;
    });
  }

  void _changeCommentaryVoiceGender(String gender) {
    final normalized = gender == 'male' ? 'male' : 'female';
    if (normalized == commentaryVoiceGender) return;
    AppSharedPreferences.set(
      AppSettingKeys.commentaryVoiceGender,
      normalized,
    );
    setState(() => commentaryVoiceGender = normalized);
  }

  void _openGrandeurSummary() {
    setState(() {
      grandeurAutoPlaying = false;
      showGrandeurSummary = true;
    });
  }

  void _closeGrandeurSummary() {
    if (_returnsHomeOnBack) {
      widget.onNavigate('Home');
      return;
    }
    setState(() => showGrandeurSummary = false);
  }

  void _applyCachedGrandeurStyle(GameAnalysisReportCacheEntry cached) {
    final style = grandeurReviewStyleForId(cached.grandeurStyleId);
    if (style.id == selectedGrandeurStyle.id) return;
    setState(() => selectedGrandeurStyle = style);
  }

  @override
  Widget build(BuildContext context) {
    if (showMaia3Page) {
      return _Maia3HumanReviewPage(
        selectedMove: selectedMove,
        selectedPly: selectedPly,
        status: maia3Status,
        analysis: maia3Analysis,
        task: maia3Task,
        selectedElo: selectedMaia3ReviewElo,
        compareStockfish: maia3CompareStockfish,
        stockfishLoading: stockfishLoading,
        stockfishBacked: stockfishBacked,
        stockfishProgress: stockfishProgress,
        stockfishStatus: stockfishStatus,
        showEngineAnalysis: _canShowStockfishMoveAnalysis,
        onBack: _closeMaia3Page,
        onStart: _startMaia3HumanReview,
        onRetry: _retryMaia3HumanReview,
        onEloChanged: _changeMaia3ReviewElo,
        onToggleCompareStockfish: (value) {
          setState(() => maia3CompareStockfish = value);
        },
        onSelectPly: _selectPly,
        onFirstPly: _selectFirstPly,
        onPreviousPly: _selectPreviousPly,
        onNextPly: _selectNextPly,
        onLastPly: _selectLastPly,
        moves: moves,
        whiteName: parsedGame.headers['White'] ?? 'White',
        blackName: parsedGame.headers['Black'] ?? 'Black',
        showBoardCoordinates: widget.showBoardCoordinates,
        isChessnutClockDevice: widget.isChessnutClockDevice,
      );
    }

    if (showGrandeurPage) {
      final grandeurMoves = _grandeurDisplayMoves();
      final grandeurSelectedMove = grandeurMoves.firstWhere(
        (move) => move.ply == selectedPly,
        orElse: () => _grandeurPgnMove(selectedMove),
      );
      return _GrandeurAnalysisPage(
        selectedMove: grandeurSelectedMove,
        selectedPly: selectedPly,
        coach: selectedGrandeurStyle,
        voiceGender: commentaryVoiceGender,
        onVoiceGenderChanged: _changeCommentaryVoiceGender,
        voiceMuted: voiceMuted,
        status: grandeurStatus,
        generationProgress: grandeurProgress,
        showGenerationProgress: grandeurAnalysis == null &&
            (grandeurLoading || grandeurProgress > 0),
        analysis: grandeurAnalysis,
        // Grandeur must not consume or display the standard Stockfish report.
        showEngineAnalysis: false,
        showGrandeurQuality: grandeurAnalysis != null,
        onBack: _closeGrandeurPage,
        onSelectPly: _selectPly,
        onFirstPly: _selectFirstPly,
        onPreviousPly: _selectPreviousPly,
        onNextPly: _selectNextPly,
        onLastPly: _selectLastPly,
        autoPlaying: grandeurAutoPlaying,
        onToggleAutoPlay: _toggleGrandeurAutoPlay,
        onSpeechComplete: _handleGrandeurSpeechComplete,
        onToggleMute: _toggleGrandeurVoice,
        onToggleBoardFlip: () => setState(
          () => grandeurBoardFlipped = !grandeurBoardFlipped,
        ),
        onOpenSummary: _openGrandeurSummary,
        onCloseSummary: _closeGrandeurSummary,
        moves: grandeurMoves,
        whiteName: parsedGame.headers['White'] ?? 'White',
        blackName: parsedGame.headers['Black'] ?? 'Black',
        statistics: _grandeurJsonStatistics(grandeurAnalysis),
        showSummary: showGrandeurSummary,
        reportSharing: reportSharing,
        onShareReport: _shareReport,
        reportDownloading: reportDownloading,
        onDownloadReport: _downloadGrandeurReport,
        reportShareKey: _grandeurReportShareKey,
        summaryShareKey: _grandeurSummaryShareKey,
        boardFlipped: grandeurBoardFlipped,
        showBoardCoordinates: widget.showBoardCoordinates,
      );
    }

    if (showStandardReport) {
      return _buildStandardReport();
    }

    return _buildAnalysisWorkbench();
  }

  Widget _buildAnalysisWorkbench() {
    final androidPhoneLandscape = _isAndroidPhoneLandscapeLayout(
      context,
      isChessnutClockDevice: widget.isChessnutClockDevice,
    );
    final page = ResponsivePage(
      key: const ValueKey('analysis-workbench-page'),
      children: (context, spec) => [
        ScreenHeader(
          title: 'Analysis board',
          subtitle: 'PGN workbench',
          leading: IconButton.filledTonal(
            onPressed: () => widget.onNavigate(_reviewBackDestination()),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          trailing: _AnalysisBoardFlipButton(
            key: const ValueKey('analysis-board-flip-button'),
            flipped: analysisBoardFlipped,
            onPressed: () => setState(
              () => analysisBoardFlipped = !analysisBoardFlipped,
            ),
          ),
        ),
        SizedBox(height: spec.gutter),
        ResponsiveSplit(
          breakpoint: 900,
          spacing: spec.gutter,
          leadingFlex: 7,
          trailingFlex: 4,
          leading: SectionColumn(
            spacing: 12,
            children: [
              ResponsiveBoardFrame(
                maxSize: androidPhoneLandscape
                    ? _androidPhoneLandscapeBoardMax(context)
                    : spec.compactLandscape
                        ? 344
                        : (spec.canSplit ? 760 : 720),
                extraWidth: _analysisScoreBarWidth,
                padding: EdgeInsets.all(spec.compactLandscape ? 0 : 0),
                builder: (size) => _AnalysisBoardWithEvalBar(
                  size: size,
                  selectedMove: selectedMove,
                  flipped: analysisBoardFlipped,
                  showReviewMarker: selectedMove.hasBoardMarker,
                  showCoordinates: widget.showBoardCoordinates,
                ),
              ),
              _AnalysisMoveControls(
                onFirst: _selectFirstPly,
                onPrevious: _selectPreviousPly,
                onNext: _selectNextPly,
                onLast: _selectLastPly,
              ),
              _StockfishCompactStatus(
                loading: stockfishLoading,
                engineBacked: stockfishBacked,
                complete: stockfishComplete,
                status: stockfishStatus,
                progress: stockfishProgress,
                completedPositions: stockfishCompletedPositions,
                totalPositions: stockfishTotalPositions,
                selectedMove: selectedMove,
              ),
              if (widget.pgn.trim() != _sampleReviewPgn.trim())
                _StandardAnalysisControls(
                  depth: standardAnalysisDepth,
                  onDepthChanged: (depth) =>
                      unawaited(_changeStandardAnalysisDepth(depth)),
                  onRegenerate: () => unawaited(_regenerateStandardReport()),
                ),
            ],
          ),
          trailing: SectionColumn(
            spacing: 10,
            children: [
              const _AttachedPgnBadge(),
              _AnalysisPgnPanel(
                moves: moves,
                selectedPly: selectedPly,
                onSelectPly: _selectPly,
                showEngineAnalysis: _canShowStockfishMoveAnalysis,
              ),
              _StandardEngineCard(
                selectedMove: selectedMove,
              ),
              _WorkbenchActionPanel(
                onOpenReport: _openStandardReport,
                onOpenGrandeur: _openGrandeurWithWalletGate,
                onOpenMaia3: _openMaia3Page,
                grandeurLoading: grandeurWalletLoading,
              ),
            ],
          ),
        ),
      ],
    );
    return androidPhoneLandscape
        ? SafeArea(top: false, bottom: false, child: page)
        : page;
  }

  String _reviewBackDestination() {
    return widget.reviewBackTarget == 'Records'
        ? 'Back'
        : widget.reviewBackTarget;
  }

  Widget _buildStandardReport() {
    final whiteName = parsedGame.headers['White'] ?? 'White';
    final blackName = parsedGame.headers['Black'] ?? 'Black';
    final androidPhoneLandscape = _isAndroidPhoneLandscapeLayout(
      context,
      isChessnutClockDevice: widget.isChessnutClockDevice,
    );
    final page = ResponsivePage(
      key: const ValueKey('analysis-standard-report-page'),
      children: (context, spec) => [
        RepaintBoundary(
          key: _standardReportShareKey,
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SectionColumn(
              spacing: 12,
              children: [
                ScreenHeader(
                  title: 'Standard report',
                  subtitle: 'Game review',
                  leading: IconButton.filledTonal(
                    onPressed: _closeStandardReport,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _AnalysisBoardFlipButton(
                        key: const ValueKey(
                          'analysis-standard-report-flip-board-button',
                        ),
                        flipped: analysisBoardFlipped,
                        onPressed: () => setState(
                          () => analysisBoardFlipped = !analysisBoardFlipped,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ReportHeaderActions(
                        shareKey: const ValueKey(
                          'analysis-standard-report-share-button',
                        ),
                        sharing: reportSharing,
                        onShare: () => _shareReport(
                          boundaryKey: _standardReportShareKey,
                          fileName: 'chessnut-standard-report.png',
                          subject: 'Chessnut Standard Report',
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.isChessnutClockDevice &&
                    widget.pgn.trim() != _sampleReviewPgn.trim())
                  _StandardAnalysisControls(
                    depth: standardAnalysisDepth,
                    onDepthChanged: (depth) =>
                        unawaited(_changeStandardAnalysisDepth(depth)),
                    onRegenerate: () => unawaited(_regenerateStandardReport()),
                  ),
                ResponsiveBoardFrame(
                  maxSize: androidPhoneLandscape
                      ? _androidPhoneLandscapeBoardMax(context)
                      : spec.compactLandscape
                          ? 344
                          : (spec.canSplit ? 520 : 720),
                  extraWidth: _analysisScoreBarWidth,
                  padding: EdgeInsets.all(spec.compactLandscape ? 2 : 8),
                  builder: (size) => _AnalysisBoardWithEvalBar(
                    size: size,
                    selectedMove: selectedMove,
                    flipped: analysisBoardFlipped,
                    showReviewMarker: selectedMove.hasBoardMarker,
                    showCoordinates: widget.showBoardCoordinates,
                  ),
                ),
                _AnalysisMoveControls(
                  key: const ValueKey('standard-report-move-controls'),
                  onFirst: _selectFirstPly,
                  onPrevious: _selectPreviousPly,
                  onNext: _selectNextPly,
                  onLast: _selectLastPly,
                ),
                if (widget.isChessnutClockDevice &&
                    widget.pgn.trim() != _sampleReviewPgn.trim())
                  _StandardAnalysisControls(
                    depth: standardAnalysisDepth,
                    onDepthChanged: (depth) =>
                        unawaited(_changeStandardAnalysisDepth(depth)),
                    onRegenerate: () => unawaited(_regenerateStandardReport()),
                  ),
                stockfishLoading
                    ? _StockfishReportLoadingCard(
                        progress: stockfishProgress,
                        completedPositions: stockfishCompletedPositions,
                        totalPositions: stockfishTotalPositions,
                      )
                    : _EvaluationCard(
                        moves: moves,
                        selectedPly: selectedPly,
                        onSelectPly: _selectPly,
                        compactReview: true,
                      ),
                _playerComparisonCard(
                  moves: moves,
                  whiteName: whiteName,
                  blackName: blackName,
                ),
                KeyedSubtree(
                  key: const ValueKey('standard-report-pgn-panel'),
                  child: _AnalysisPgnPanel(
                    moves: moves,
                    selectedPly: selectedPly,
                    onSelectPly: _selectPly,
                    showEngineAnalysis: _canShowStockfishMoveAnalysis,
                  ),
                ),
                PrimaryButton(
                  label: 'Grandeur review',
                  icon: Icons.auto_awesome_rounded,
                  onPressed: grandeurWalletLoading
                      ? null
                      : _openGrandeurWithWalletGate,
                  labelMaxLines: 1,
                  labelSoftWrap: false,
                  labelOverflow: TextOverflow.ellipsis,
                  scaleLabel: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
    return androidPhoneLandscape
        ? SafeArea(top: false, bottom: false, child: page)
        : page;
  }

  Future<void> _shareReport({
    required GlobalKey boundaryKey,
    required String fileName,
    required String subject,
  }) async {
    if (reportSharing) return;
    setState(() => reportSharing = true);
    try {
      final shared = await widget.reportShareService.shareReportImage(
        context: context,
        boundaryKey: boundaryKey,
        fileName: fileName,
        subject: subject,
      );
      if (!mounted) return;
      if (shared) {
        showAppFeedback(
          context,
          'Report image ready to share.',
          tone: AppFeedbackTone.success,
          duration: const Duration(seconds: 2),
        );
        widget.onReportShared?.call();
      }
    } catch (error) {
      if (!mounted) return;
      showAppFeedback(
        context,
        'Unable to share report image.',
        tone: AppFeedbackTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => reportSharing = false);
      }
    }
  }

  Future<void> _downloadGrandeurReport() async {
    final analysis = grandeurAnalysis;
    if (analysis == null || reportDownloading) return;
    setState(() => reportDownloading = true);
    try {
      final jsonStatistics = _grandeurJsonStatistics(analysis);
      final avatarDataUri = await _grandeurCoachAvatarDataUri();
      final pieceImageDataUris = await _grandeurPieceImageDataUris();
      if (!mounted) return;
      final html = buildGrandeurReportHtml(
        GrandeurHtmlReportData(
          title: 'Chessnut Grandeur Report',
          whiteName: parsedGame.headers['White'] ?? 'White',
          blackName: parsedGame.headers['Black'] ?? 'Black',
          language: analysis.language,
          summary: _buildGrandeurSummaryText(analysis),
          coachName: selectedGrandeurStyle.name,
          coachRole: selectedGrandeurStyle.role,
          coachAvatarDataUri: avatarDataUri,
          accentColor:
              '#${(selectedGrandeurStyle.color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
          pieceImageDataUris: pieceImageDataUris,
          whiteAccuracy: jsonStatistics.whiteAccuracy ?? 0,
          blackAccuracy: jsonStatistics.blackAccuracy ?? 0,
          whiteAccuracyText: jsonStatistics.whiteAccuracyText,
          blackAccuracyText: jsonStatistics.blackAccuracyText,
          hasWhiteAccuracy: jsonStatistics.hasWhiteAccuracy,
          hasBlackAccuracy: jsonStatistics.hasBlackAccuracy,
          whiteCounts: jsonStatistics.whiteCounts,
          blackCounts: jsonStatistics.blackCounts,
          moves: _grandeurHtmlMoves(analysis),
          generatedAt: DateTime.now(),
        ),
      );
      final downloaded = await widget.reportShareService.downloadReportHtml(
        context: context,
        html: html,
        fileName: 'chessnut-grandeur-report.html',
        subject: 'Chessnut Grandeur Report',
      );
      if (!mounted) return;
      if (downloaded) {
        showAppFeedback(
          context,
          'Grandeur HTML report downloaded.',
          tone: AppFeedbackTone.success,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (error) {
      if (!mounted) return;
      showAppFeedback(
        context,
        'Unable to download Grandeur report.',
        tone: AppFeedbackTone.error,
      );
    } finally {
      if (mounted) setState(() => reportDownloading = false);
    }
  }

  Future<String> _grandeurCoachAvatarDataUri() async {
    try {
      final asset = selectedGrandeurStyle.avatarAsset;
      final bytes = await rootBundle.load(asset);
      final mimeType = asset.toLowerCase().endsWith('.webp')
          ? 'image/webp'
          : asset.toLowerCase().endsWith('.jpg') ||
                  asset.toLowerCase().endsWith('.jpeg')
              ? 'image/jpeg'
              : 'image/png';
      return 'data:$mimeType;base64,${base64Encode(bytes.buffer.asUint8List())}';
    } catch (_) {
      return '';
    }
  }

  Future<Map<String, String>> _grandeurPieceImageDataUris() async {
    const assetNames = [
      'wK.svg',
      'wQ.svg',
      'wR.svg',
      'wB.svg',
      'wN.svg',
      'wP.svg',
      'bK.svg',
      'bQ.svg',
      'bR.svg',
      'bB.svg',
      'bN.svg',
      'bP.svg',
    ];
    final entries = await Future.wait(
      assetNames.map((assetName) async {
        try {
          final svg = await rootBundle.loadString(
            'assets/pieces/cburnett/$assetName',
          );
          return MapEntry(
            assetName,
            'data:image/svg+xml;base64,${base64Encode(utf8.encode(svg))}',
          );
        } catch (_) {
          return MapEntry(assetName, '');
        }
      }),
    );
    return Map<String, String>.fromEntries(entries);
  }

  List<GrandeurHtmlMove> _grandeurHtmlMoves(
    GrandeurAnalysisResult analysis,
  ) {
    final result = <GrandeurHtmlMove>[];
    for (var index = 0; index < moves.length; index++) {
      final reviewMove = moves[index];
      // The report JSON move list is guaranteed to follow the PGN SAN order.
      // Match by index so its evaluation cannot be misassigned by an
      // incomplete or non-standard ply value.
      final backendMove =
          index < analysis.moves.length ? analysis.moves[index] : null;
      result.add(
        GrandeurHtmlMove(
          ply: reviewMove.ply,
          // Keep the PGN SAN and move order authoritative for navigation and
          // export; Grandeur JSON supplies only its own explanation fields.
          san: _stripDisplayMoveNumber(reviewMove.move),
          fen: reviewMove.fen,
          tag: backendMove?.tag ?? '',
          commentary: backendMove?.commentary ?? '',
          purpose: backendMove?.purpose ?? '',
          why: backendMove?.why ?? '',
          betterMove: backendMove?.betterMove ?? '',
          classification: backendMove == null
              ? 'Unclassified'
              : _grandeurMoveClassification(backendMove),
        ),
      );
    }
    return result;
  }

  List<ReviewMove> _grandeurDisplayMoves() {
    final reportMoves =
        grandeurAnalysis?.moves ?? const <GrandeurMoveExplanation>[];
    return List<ReviewMove>.unmodifiable([
      for (var index = 0; index < moves.length; index++)
        if (index < reportMoves.length)
          _grandeurPgnMove(
            moves[index],
            classification: _grandeurMoveClassification(reportMoves[index]),
            color: _grandeurMoveQualityColor(reportMoves[index]),
            keyMoment: _isGrandeurKeyMoment(reportMoves[index]),
          )
        else
          _grandeurPgnMove(
            moves[index],
            classification: 'Unclassified',
            color: _classificationColor('Unclassified'),
            keyMoment: false,
          ),
    ]);
  }

  /// Builds the minimal move model Grandeur needs: PGN navigation data plus
  /// classification from the Grandeur JSON.  Standard-analysis values are
  /// deliberately not carried into this page's model.
  ReviewMove _grandeurPgnMove(
    ReviewMove move, {
    String classification = 'Unclassified',
    Color? color,
    bool keyMoment = false,
  }) {
    return ReviewMove(
      ply: move.ply,
      move: move.move,
      evalBefore: 0,
      evalAfter: 0,
      classification: classification,
      summary: '',
      color: color ?? _classificationColor(classification),
      fen: move.fen,
      lastMove: move.lastMove,
      focusSquare: move.focusSquare,
      engineLine: '',
      bestMove: '',
      keyMoment: keyMoment,
      engineDepth: null,
      scoreMapAccuracy: null,
      scoreMapLevel: null,
      isEngineBacked: false,
      candidateVariations: const [],
    );
  }

  String? _reportBucketForMove(ReviewMove move) {
    return switch (move.classification) {
      'Brilliant' => 'Brilliant',
      'Best' || 'Book' => 'Best',
      'Great' => 'Great',
      'Excellent' => 'Excellent',
      'Good' => 'Good',
      'Inaccuracy' => 'Inaccuracy',
      'Mistake' || 'Critical swing' => 'Mistake',
      'Missed win' => 'Miss',
      'Blunder' => 'Blunder',
      _ => null,
    };
  }

  Map<String, int> _sideReportCounts(bool white) {
    final counts = <String, int>{
      for (final bucket in _reportBuckets) bucket.label: 0,
    };
    for (final move in moves.where((move) => move.isWhiteMove == white)) {
      final label = _reportBucketForMove(move);
      if (label == null) continue;
      counts[label] = (counts[label] ?? 0) + 1;
    }
    return counts;
  }

  double _sideAccuracy(bool white) {
    final sideMoves = moves
        .where((move) => move.isWhiteMove == white)
        .where((move) => move.scoreMapAccuracy != null)
        .toList();
    if (sideMoves.isEmpty) return 0;
    var total = 0.0;
    for (final move in sideMoves) {
      total += move.scoreMapAccuracy!;
    }
    return (total / sideMoves.length).clamp(0, 100).toDouble();
  }

  bool _sideHasAccuracy(bool white) {
    return moves.any(
      (move) => move.isWhiteMove == white && move.scoreMapAccuracy != null,
    );
  }

  Widget _playerComparisonCard({
    required List<ReviewMove> moves,
    required String whiteName,
    required String blackName,
  }) {
    final whiteCounts = _sideReportCounts(true);
    final blackCounts = _sideReportCounts(false);
    final whiteAccuracy = _sideAccuracy(true);
    final blackAccuracy = _sideAccuracy(false);
    return _ReviewPlayerComparisonCard(
      whiteName: whiteName,
      blackName: blackName,
      whiteAccuracy: whiteAccuracy,
      blackAccuracy: blackAccuracy,
      hasWhiteAccuracy: _sideHasAccuracy(true),
      hasBlackAccuracy: _sideHasAccuracy(false),
      whiteCounts: whiteCounts,
      blackCounts: blackCounts,
    );
  }

  Future<void> _startGrandeurAnalysis() async {
    if (grandeurAnalysis != null) return;
    if (widget.apiClient.session == null) {
      setState(() {
        grandeurStatus =
            'Sign in to run Grandeur. Guest mode can review locally but cannot call the LLM coach.';
      });
      return;
    }
    _notifyAnalysisStarted();
    setState(() {
      grandeurLoading = true;
      grandeurStatus = grandeurJob == null
          ? 'Grandeur review is being prepared...'
          : 'Grandeur review is preparing. You can come back later.';
    });
    final job = grandeurJob;
    if (job != null && job.commentId > 0) {
      _attachGrandeurTask(job);
      await _persistGrandeurUnlock(job: job);
      return;
    }
    final result = await widget.apiClient.startGrandeurReview(
      pgn: widget.pgn,
      language: widget.apiClient.grandeurLanguage.value,
      gameStep: parsedGame.moves.length,
      style: selectedGrandeurStyle.id,
    );
    final jobResult = result.data;
    if (!mounted) return;
    if (result.isSuccess && jobResult != null) {
      grandeurJob = jobResult;
      _grandeurRecordId = jobResult.pgnId;
      grandeurWalletUnlocked = true;
      _attachGrandeurTask(jobResult);
      await _persistGrandeurUnlock(job: jobResult);
      return;
    }
    setState(() {
      grandeurLoading = false;
      grandeurProgress = 0;
      grandeurStatus = result.status.errorMessage ??
          'Grandeur is temporarily unavailable. Please try again later.';
    });
  }

  void _attachGrandeurTask(GrandeurReviewJob job) {
    final task = grandeurAnalysisTaskCoordinator.startOrAttach(
      cacheKey: _grandeurCacheKey,
      pgn: widget.pgn,
      apiClient: widget.apiClient,
      initialJob: job,
      styleId: selectedGrandeurStyle.id,
      cacheStore: widget.reportCacheStore,
      onReportCacheChanged: widget.onReportCacheChanged,
    );
    if (!identical(grandeurTask, task)) {
      _detachGrandeurTask();
      grandeurTask = task;
      grandeurTaskListener = () => _applyGrandeurTaskSnapshot(task.value);
      task.addListener(grandeurTaskListener!);
      unawaited(task.done.then((snapshot) {
        if (!mounted || !identical(grandeurTask, task)) return;
        _applyGrandeurTaskSnapshot(snapshot);
      }));
    }
    _applyGrandeurTaskSnapshot(task.value);
  }

  void _detachGrandeurTask() {
    final task = grandeurTask;
    final listener = grandeurTaskListener;
    if (task != null && listener != null) {
      task.removeListener(listener);
    }
    grandeurTask = null;
    grandeurTaskListener = null;
  }

  Future<void> _startMaia3HumanReview() async {
    if (maia3Analysis?.elo == selectedMaia3ReviewElo) return;
    if (widget.apiClient.session == null) {
      setState(() {
        maia3Status =
            'Sign in to run Maia3 Human Review. It runs on Chessnut cloud services.';
      });
      return;
    }
    _notifyAnalysisStarted();
    final task = maia3HumanReviewTaskCoordinator.startOrAttach(
      cacheKey: _maia3CacheKey,
      pgn: widget.pgn,
      pgnId: _recordIdFromCacheKey(),
      apiClient: widget.apiClient,
      cacheStore: widget.reportCacheStore,
      onReportCacheChanged: widget.onReportCacheChanged,
      elo: selectedMaia3ReviewElo,
    );
    if (!identical(maia3Task, task)) {
      _detachMaia3Task();
      maia3Task = task;
      maia3TaskListener = () => _applyMaia3TaskSnapshot(task.value);
      task.addListener(maia3TaskListener!);
      unawaited(task.done.then((snapshot) {
        if (!mounted || !identical(maia3Task, task)) return;
        _applyMaia3TaskSnapshot(snapshot);
      }));
    }
    _applyMaia3TaskSnapshot(task.value);
  }

  void _retryMaia3HumanReview() {
    _detachMaia3Task();
    setState(() {
      maia3Analysis = null;
      maia3Status = 'Restarting Maia3 Human Review...';
    });
    unawaited(_startMaia3HumanReview());
  }

  void _changeMaia3ReviewElo(int elo) {
    final normalized = _normalizeMaia3ReviewElo(elo);
    if (normalized == selectedMaia3ReviewElo) return;
    _detachMaia3Task();
    setState(() {
      selectedMaia3ReviewElo = normalized;
      maia3Analysis = null;
      maia3Status = null;
    });
    unawaited(_hydrateCachedMaia3ForSelectedElo());
  }

  Future<void> _hydrateCachedMaia3ForSelectedElo() async {
    final cached = await _readCachedMaia3Report();
    if (!mounted || cached == null) return;
    if (cached.elo != selectedMaia3ReviewElo) return;
    setState(() {
      maia3Analysis = cached;
      maia3Status = 'Maia3 Human Review ready.';
    });
  }

  void _detachMaia3Task() {
    final task = maia3Task;
    final listener = maia3TaskListener;
    if (task != null && listener != null) {
      task.removeListener(listener);
    }
    maia3Task = null;
    maia3TaskListener = null;
  }

  void _applyMaia3TaskSnapshot(Maia3HumanReviewTaskSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      maia3Status = snapshot.status;
      if (snapshot.report != null) {
        maia3Analysis = snapshot.report;
      }
    });
    if (snapshot.state != Maia3HumanReviewTaskState.running) {
      _detachMaia3Task();
    }
  }

  void _applyGrandeurTaskSnapshot(GrandeurAnalysisTaskSnapshot snapshot) {
    if (!mounted) return;
    final progress = snapshot.progress.clamp(0, 1).toDouble();
    final jobRecordId = snapshot.job?.pgnId ?? 0;
    if (jobRecordId > 0) _grandeurRecordId = jobRecordId;
    setState(() {
      grandeurJob = snapshot.job ?? grandeurJob;
      grandeurStatus = snapshot.status;
      grandeurProgress = progress;
      grandeurWalletUnlocked = true;
      switch (snapshot.state) {
        case GrandeurAnalysisTaskState.queued:
        case GrandeurAnalysisTaskState.running:
          grandeurLoading = true;
        case GrandeurAnalysisTaskState.completed:
          grandeurLoading = false;
          grandeurProgress = 1;
          if (snapshot.report != null) {
            grandeurAnalysis = snapshot.report;
          }
        case GrandeurAnalysisTaskState.failed:
          grandeurLoading = false;
          if (snapshot.report != null) {
            grandeurAnalysis = snapshot.report;
          }
      }
    });
  }

  Future<GrandeurCoachProfile?> _chooseGrandeurReviewStyle() {
    return showDialog<GrandeurCoachProfile>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => _GrandeurStylePickerDialog(
        selectedStyleId: selectedGrandeurStyle.id,
      ),
    );
  }

  Future<bool> _confirmGrandeurPointSpend(WalletBalance balance) async {
    final memberActive = balance.memberActive;
    final costToday = memberActive ? 0 : _grandeurReviewCost;
    final afterBalance =
        (balance.balance - costToday).clamp(0, balance.balance);
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => AppDialogShell(
        icon: Icons.auto_awesome_rounded,
        title: 'Spend 100 points?',
        subtitle: 'Grandeur uses wallet points for the LLM coach review.',
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: _AnalysisButtonLabel(
                memberActive ? 'Spend 0 points' : 'Spend 100 points',
              ),
            ),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GrandeurWalletLine(
              label: 'Current balance',
              value: balance.balance,
            ),
            const SizedBox(height: 8),
            if (memberActive) ...[
              const _GrandeurWalletLine(
                label: 'Original cost',
                value: _grandeurReviewCost,
                strikethrough: true,
              ),
              const SizedBox(height: 8),
              const _GrandeurWalletLine(
                label: 'Member discount',
                value: -_grandeurReviewCost,
              ),
              const SizedBox(height: 8),
              const _GrandeurWalletLine(label: 'Pay today', value: 0),
              const SizedBox(height: 8),
            ],
            _GrandeurWalletLine(
              label: 'Balance after review',
              value: afterBalance,
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  Future<bool> _confirmGrandeurServerVerifiedSpend() async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => AppDialogShell(
        icon: Icons.auto_awesome_rounded,
        title: 'Start Grandeur review?',
        subtitle: 'Chessnut checks membership and wallet balance.',
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const _AnalysisButtonLabel('Start Grandeur review'),
            ),
          ),
        ],
        child: const Text(
          'Grandeur normally costs 100 wallet points. Members pay 0 points automatically. If your points are not enough, you can earn more from Daily Tasks.',
        ),
      ),
    );
    return result ?? false;
  }

  void _showGrandeurInsufficientPointsDialog(int balance) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => AppDialogShell(
        icon: Icons.account_balance_wallet_rounded,
        title: 'Not enough points',
        subtitle: 'Grandeur review costs 100 wallet points.',
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                widget.onNavigate('DailyTasks');
              },
              child: const _AnalysisButtonLabel('Go to Daily Tasks'),
            ),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GrandeurWalletLine(label: 'Current balance', value: balance),
            const SizedBox(height: 8),
            const Text(
              'Go to Daily Tasks to earn points, then return to Analysis.',
            ),
          ],
        ),
      ),
    );
  }

  void _showGrandeurSignInDialog() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => AppDialogShell(
        icon: Icons.login_rounded,
        title: 'Sign in required',
        subtitle: 'Grandeur review uses your wallet balance.',
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                widget.onNavigate('Auth');
              },
              child: const Text('Sign in'),
            ),
          ),
        ],
      ),
    );
  }

  void _showGrandeurWalletError(String message) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => AppDialogShell(
        icon: Icons.warning_amber_rounded,
        title: 'Wallet unavailable',
        subtitle: message,
        actions: [
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startStockfishAnalysis() async {
    if (widget.pgn.trim() == _sampleReviewPgn.trim()) return;
    final generation = ++_standardAnalysisGeneration;
    final analysisDepth = standardAnalysisDepth;
    final sourceMoves = buildReviewMovesFromParsedGame(parsedGame);
    _notifyAnalysisStarted();
    setState(() {
      stockfishLoading = true;
      stockfishComplete = false;
      stockfishProgress = 0;
      stockfishCompletedPositions = 0;
      stockfishTotalPositions = parsedGame.snapshots.length;
      stockfishStatus = 'Stockfish is evaluating every PGN position...';
    });
    final task = standardAnalysisTaskCoordinator.startOrAttachLocal(
      cacheKey: _cacheKey,
      pgn: widget.pgn,
      parsedGame: parsedGame,
      engine: widget.positionAnalyzer ?? const StockfishPositionAnalyzer(),
      cacheStore: widget.reportCacheStore,
      onReportCacheChanged: widget.onReportCacheChanged,
      depth: analysisDepth,
      reportBuilder: (insights) {
        final analyzedMoves = applyEngineInsightsToReviewMoves(
          sourceMoves,
          insights,
        );
        final engineBackedMoves =
            insights.where((insight) => insight.isEngineBacked).length;
        final totalMoves = parsedGame.moves.length;
        final complete =
            insights.length == totalMoves && engineBackedMoves == totalMoves;
        final analyzedDepth = insights
            .where((insight) => insight.isEngineBacked)
            .map((insight) => insight.depth)
            .fold<int?>(
                null,
                (lowest, depth) =>
                    lowest == null || depth < lowest ? depth : lowest);
        final depthLabel =
            analyzedDepth == null ? '' : ' at depth $analyzedDepth';
        return GameStandardAnalysisReport(
          moves: analyzedMoves.map(_reviewMoveToCachedMove).toList(
                growable: false,
              ),
          stockfishBacked: engineBackedMoves > 0,
          stockfishStatus: complete
              ? 'Stockfish analysis ready / $totalMoves moves$depthLabel.'
              : 'Stockfish analysis partially ready / $engineBackedMoves of $totalMoves moves$depthLabel.',
          generatedAt: DateTime.now(),
          analysisDepth: analysisDepth,
          isComplete: complete,
        );
      },
    );
    _detachStandardAnalysisTask(cancel: false);
    standardAnalysisTask = task;
    _applyStandardAnalysisSnapshot(task.value);
    void handleTaskUpdate() {
      if (generation != _standardAnalysisGeneration) return;
      _applyStandardAnalysisSnapshot(task.value);
    }

    standardAnalysisTaskListener = handleTaskUpdate;
    task.addListener(handleTaskUpdate);
    final snapshot = await task.done.whenComplete(
      () {
        task.removeListener(handleTaskUpdate);
        if (identical(standardAnalysisTask, task)) {
          standardAnalysisTask = null;
          standardAnalysisTaskListener = null;
        }
      },
    );
    if (!mounted || generation != _standardAnalysisGeneration) return;
    _applyStandardAnalysisSnapshot(snapshot);
  }

  Future<void> _changeStandardAnalysisDepth(int depth) async {
    final normalized = depth.clamp(6, 20).toInt();
    if (normalized == standardAnalysisDepth) return;
    AppSharedPreferences.set(
      AppSettingKeys.standardAnalysisDepth,
      normalized,
    );
    setState(() => standardAnalysisDepth = normalized);
    await _regenerateStandardReport();
  }

  Future<void> _regenerateStandardReport() async {
    if (widget.pgn.trim() == _sampleReviewPgn.trim()) return;
    ++_standardAnalysisGeneration;
    final task = standardAnalysisTask;
    _detachStandardAnalysisTask(cancel: false);
    await task?.cancel();
    if (!mounted) return;
    final currentPly = selectedPly;
    final resetMoves = buildReviewMovesFromParsedGame(parsedGame);
    setState(() {
      moves = resetMoves;
      selectedPly = resetMoves.any((move) => move.ply == currentPly)
          ? currentPly
          : resetMoves.first.ply;
      stockfishLoading = true;
      stockfishBacked = false;
      stockfishComplete = false;
      stockfishProgress = 0;
      stockfishCompletedPositions = 0;
      stockfishTotalPositions = parsedGame.snapshots.length;
      stockfishStatus = 'Stockfish is evaluating every PGN position...';
    });
    await _startStockfishAnalysis();
  }

  void _detachStandardAnalysisTask({required bool cancel}) {
    final task = standardAnalysisTask;
    final listener = standardAnalysisTaskListener;
    standardAnalysisTask = null;
    standardAnalysisTaskListener = null;
    if (task == null) return;
    if (listener != null) task.removeListener(listener);
    if (cancel) unawaited(task.cancel());
  }

  Future<void> _hydrateCachedReportThenStartStockfish() async {
    final cached = await _readCachedReport();
    final cachedGrandeur = await _readCachedGrandeurReport();
    final cachedMaia3 = await _readCachedMaia3Report();
    if (!mounted) return;
    final standard = cached?.standardReport;
    final cachedGrandeurStyle = cachedGrandeur == null
        ? null
        : grandeurReviewStyleForId(cachedGrandeur.grandeurStyleId);
    if (standard != null &&
        standard.analysisDepth == standardAnalysisDepth &&
        standard.moves.isNotEmpty) {
      setState(() {
        if (cachedGrandeurStyle != null) {
          selectedGrandeurStyle = cachedGrandeurStyle;
        }
        moves =
            standard.moves.map(_reviewMoveFromCache).toList(growable: false);
        stockfishLoading = false;
        stockfishProgress = 1;
        stockfishCompletedPositions = moves.length + 1;
        stockfishTotalPositions = moves.length + 1;
        stockfishBacked = standard.stockfishBacked;
        stockfishComplete = standard.isComplete;
        stockfishStatus = standard.stockfishStatus.isEmpty
            ? 'Report ready'
            : standard.stockfishStatus;
        grandeurAnalysis = cachedGrandeur?.grandeurReport;
        maia3Analysis = cachedMaia3;
        grandeurWalletUnlocked =
            widget.attachedCommentId > 0 || cachedGrandeur?.hasGrandeur == true;
        if (widget.attachedCommentId > 0) {
          _attachExistingGrandeurJob();
        }
        selectedPly = moves.any((move) => move.ply == selectedPly)
            ? selectedPly
            : moves.first.ply;
      });
      unawaited(_syncSelectedMoveToPhysicalBoard(force: true));
      return;
    }
    setState(() {
      if (cachedGrandeurStyle != null) {
        selectedGrandeurStyle = cachedGrandeurStyle;
      }
      grandeurAnalysis = cachedGrandeur?.grandeurReport;
      maia3Analysis = cachedMaia3;
      grandeurWalletUnlocked =
          widget.attachedCommentId > 0 || cachedGrandeur?.hasGrandeur == true;
      if (widget.attachedCommentId > 0) {
        _attachExistingGrandeurJob();
      }
    });
    await _startStockfishAnalysis();
  }

  void _attachExistingGrandeurJob() {
    final commentId = widget.attachedCommentId;
    if (commentId <= 0) return;
    _attachGrandeurJobFromIds(
      commentId: commentId,
      pgnId: _recordIdFromCacheKey() ?? 0,
    );
  }

  void _attachGrandeurJobFromIds({
    required int commentId,
    required int pgnId,
  }) {
    if (commentId <= 0) return;
    if (pgnId > 0) _grandeurRecordId = pgnId;
    grandeurJob ??= GrandeurReviewJob(
      commentId: commentId,
      trainStatus: 0,
      commentFile: '',
      pointsConsumed: 0,
      alreadyUnlocked: true,
      memberUnlimited: false,
      pgnId: pgnId,
      shareId: '',
    );
    grandeurWalletUnlocked = true;
  }

  void _applyStandardAnalysisSnapshot(StandardAnalysisTaskSnapshot snapshot) {
    if (!mounted) return;
    switch (snapshot.state) {
      case StandardAnalysisTaskState.running:
        setState(() {
          stockfishLoading = true;
          stockfishComplete = false;
          stockfishProgress = snapshot.progress;
          stockfishCompletedPositions = snapshot.completedPositions;
          stockfishTotalPositions = snapshot.totalPositions > 0
              ? snapshot.totalPositions
              : moves.length + 1;
          stockfishStatus = snapshot.status;
        });
      case StandardAnalysisTaskState.completed:
        final report = snapshot.report;
        if (report == null || report.moves.isEmpty) {
          setState(() {
            stockfishLoading = false;
            stockfishProgress = 0;
            stockfishBacked = false;
            stockfishComplete = false;
            stockfishStatus = snapshot.status;
          });
          return;
        }
        setState(() {
          moves =
              report.moves.map(_reviewMoveFromCache).toList(growable: false);
          stockfishLoading = false;
          stockfishProgress = 1;
          stockfishCompletedPositions = report.moves.length + 1;
          stockfishTotalPositions = report.moves.length + 1;
          stockfishBacked = report.stockfishBacked;
          stockfishComplete = report.isComplete;
          stockfishStatus = report.stockfishStatus.isEmpty
              ? 'Report ready'
              : report.stockfishStatus;
          selectedPly = moves.any((move) => move.ply == selectedPly)
              ? selectedPly
              : moves.first.ply;
        });
        unawaited(_syncSelectedMoveToPhysicalBoard(force: true));
      case StandardAnalysisTaskState.failed:
        setState(() {
          stockfishLoading = false;
          stockfishProgress = 0;
          stockfishBacked = false;
          stockfishComplete = false;
          stockfishStatus = snapshot.status;
        });
      case StandardAnalysisTaskState.cancelled:
        setState(() {
          stockfishLoading = false;
          stockfishComplete = false;
          stockfishStatus = snapshot.status;
        });
    }
  }

  Future<GameAnalysisReportCacheEntry?> _readCachedReport() async {
    final store = widget.reportCacheStore;
    if (store == null) return null;
    final primary = await store.read(_cacheKey);
    if (primary != null &&
        primary.standardReport != null &&
        gameAnalysisReportCacheEntryMatchesPgn(primary, widget.pgn)) {
      return primary;
    }
    final pgnKey = gameAnalysisReportCacheKeyForPgn(widget.pgn);
    if (pgnKey == _cacheKey) return null;
    final byPgn = await store.read(pgnKey);
    return byPgn != null &&
            byPgn.standardReport != null &&
            gameAnalysisReportCacheEntryMatchesPgn(byPgn, widget.pgn)
        ? byPgn
        : null;
  }

  Future<GameAnalysisReportCacheEntry?> _readCachedGrandeurReport() async {
    final store = widget.reportCacheStore;
    if (store == null ||
        (widget.attachedCommentId <= 0 && _grandeurRecordId <= 0)) {
      return null;
    }
    return store.read(_grandeurCacheKey);
  }

  Future<Maia3HumanReviewReport?> _readCachedMaia3Report() async {
    final store = widget.reportCacheStore;
    if (store == null) return null;
    final primary = await store.read(_maia3CacheKey);
    if (primary?.maia3Report != null) return primary!.maia3Report;
    final pgnKey = gameAnalysisReportCacheKeyForPgn(widget.pgn);
    if (pgnKey != _cacheKey) {
      final byPgn = await store.read(maia3HumanReviewSettingsCacheKey(
        maia3HumanReviewCacheKey(pgnKey),
        elo: selectedMaia3ReviewElo,
      ));
      if (byPgn?.maia3Report != null) return byPgn!.maia3Report;
    }
    final legacyPrimary = await store.read(_maia3BaseCacheKey);
    final legacyReport = legacyPrimary?.maia3Report;
    if (legacyReport != null && legacyReport.elo == selectedMaia3ReviewElo) {
      return legacyReport;
    }
    if (pgnKey == _cacheKey) return null;
    final legacyByPgn = await store.read(maia3HumanReviewCacheKey(pgnKey));
    final legacyByPgnReport = legacyByPgn?.maia3Report;
    return legacyByPgnReport?.elo == selectedMaia3ReviewElo
        ? legacyByPgnReport
        : null;
  }

  Future<void> _persistGrandeurUnlock({GrandeurReviewJob? job}) async {
    final store = widget.reportCacheStore;
    if (store == null) return;
    final activeJob = job ?? grandeurJob;
    final serverPgnId = activeJob?.pgnId ?? _grandeurRecordId;
    if (serverPgnId > 0) _grandeurRecordId = serverPgnId;
    await store.markGrandeurUnlocked(
      _grandeurCacheKey,
      widget.pgn,
      commentId: activeJob?.commentId ?? 0,
      serverPgnId: serverPgnId,
      styleId: selectedGrandeurStyle.id,
    );
    await widget.onReportCacheChanged?.call();
  }

  int? _recordIdFromCacheKey() {
    final key = _cacheKey;
    if (!key.startsWith('pgn:')) return null;
    return int.tryParse(key.substring(4));
  }

  ReviewMove _reviewMoveFromCache(CachedReviewMove move) {
    return ReviewMove(
      ply: move.ply,
      move: move.move,
      evalBefore: move.evalBefore,
      evalAfter: move.evalAfter,
      classification: move.classification,
      summary: move.summary,
      color: _classificationColor(move.classification),
      fen: move.fen,
      lastMove: move.lastMove,
      focusSquare: move.focusSquare,
      engineLine: move.engineLine,
      bestMove: move.bestMove,
      keyMoment: move.keyMoment,
      engineDepth: move.engineDepth,
      scoreMapAccuracy: move.scoreMapAccuracy,
      scoreMapLevel: move.scoreMapLevel,
      isEngineBacked: move.isEngineBacked,
      candidateVariations: move.candidateVariations
          .map(
            (variation) => EngineVariationInsight(
              moveUci: variation.moveUci,
              line: variation.line,
              whiteEval: variation.whiteEval,
              whiteMate: variation.whiteMate,
            ),
          )
          .toList(growable: false),
    );
  }
}

CachedReviewMove _reviewMoveToCachedMove(ReviewMove move) {
  return CachedReviewMove(
    ply: move.ply,
    move: move.move,
    evalBefore: move.evalBefore,
    evalAfter: move.evalAfter,
    classification: move.classification,
    summary: move.summary,
    fen: move.fen,
    lastMove: move.lastMove,
    focusSquare: move.focusSquare,
    engineLine: move.engineLine,
    bestMove: move.bestMove,
    keyMoment: move.keyMoment,
    engineDepth: move.engineDepth,
    scoreMapAccuracy: move.scoreMapAccuracy,
    scoreMapLevel: move.scoreMapLevel,
    isEngineBacked: move.isEngineBacked,
    candidateVariations: move.candidateVariations
        .map(
          (variation) => CachedEngineVariation(
            moveUci: variation.moveUci,
            line: variation.line,
            whiteEval: variation.whiteEval,
            whiteMate: variation.whiteMate,
          ),
        )
        .toList(growable: false),
  );
}

String _analysisBoardOnlyFen(String fen) {
  return normalizeFenInput(fen).trim().split(RegExp(r'\s+')).first;
}

bool _isSquareName(String value) {
  return RegExp(r'^[a-h][1-8]$').hasMatch(value);
}

Set<String> _analysisDifferentSquares(String sourceBoardFen, String targetFen) {
  final source = _analysisExpandBoardFen(sourceBoardFen);
  final target = _analysisExpandBoardFen(_analysisBoardOnlyFen(targetFen));
  if (source == null || target == null) return const {};
  final squares = <String>{};
  for (var index = 0; index < source.length; index += 1) {
    if (source[index] == target[index]) continue;
    final file = index % 8;
    final rank = index ~/ 8;
    squares.add('${ChessBoard.files[file]}${8 - rank}');
  }
  return Set<String>.unmodifiable(squares);
}

String _analysisLedSignature(
  PhysicalBoardModel model,
  Set<String> squares, {
  String? extra,
}) {
  final sorted = squares.toList()..sort();
  return '${model.name}:${extra ?? ''}:${sorted.join(',')}';
}

int? _analysisSquareIndex(String square) {
  if (!_isSquareName(square)) return null;
  final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
  final rank = int.tryParse(square[1]);
  if (rank == null) return null;
  return (8 - rank) * 8 + file;
}

String _evo2AnalysisMarkerPatternKey(String classification) {
  return switch (classification) {
    'Brilliant' || 'Best' => 'analysis_best',
    'Great' || 'Good' => 'analysis_great',
    'Inaccuracy' || 'Missed win' => 'analysis_inaccuracy',
    'Mistake' || 'Critical swing' => 'analysis_mistake',
    'Blunder' => 'analysis_blunder',
    _ => 'analysis_other',
  };
}

List<String>? _analysisExpandBoardFen(String fen) {
  final ranks = _analysisBoardOnlyFen(fen).split('/');
  if (ranks.length != 8) return null;
  final squares = <String>[];
  for (final rank in ranks) {
    for (final char in rank.characters) {
      final empty = int.tryParse(char);
      if (empty != null) {
        squares.addAll(List<String>.filled(empty, ''));
        continue;
      }
      if (!RegExp(r'^[prnbqkPRNBQK]$').hasMatch(char)) return null;
      squares.add(char);
    }
  }
  return squares.length == 64 ? squares : null;
}

class _GrandeurWalletLine extends StatelessWidget {
  const _GrandeurWalletLine({
    required this.label,
    required this.value,
    this.strikethrough = false,
  });

  final String label;
  final int value;
  final bool strikethrough;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w900,
            decoration: strikethrough
                ? TextDecoration.lineThrough
                : TextDecoration.none,
          ),
    );
  }
}

class _AnalysisSourceCard extends StatelessWidget {
  const _AnalysisSourceCard();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(13),
      tint: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              'PGN',
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No game attached yet',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  'Paste PGN here, open a saved record, or review the last finished game.',
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

class _AnalysisMoveControls extends StatelessWidget {
  const _AnalysisMoveControls({
    super.key,
    required this.onFirst,
    required this.onPrevious,
    required this.onNext,
    required this.onLast,
    this.extraAction,
  });

  final VoidCallback onFirst;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onLast;
  final Widget? extraAction;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderRadius: 13,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton.filledTonal(
            tooltip: 'First move',
            onPressed: onFirst,
            icon: const Icon(Icons.first_page_rounded),
          ),
          IconButton.filledTonal(
            tooltip: 'Previous move',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton.filledTonal(
            tooltip: 'Next move',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          IconButton.filledTonal(
            tooltip: 'Last move',
            onPressed: onLast,
            icon: const Icon(Icons.last_page_rounded),
          ),
          if (extraAction != null) extraAction!,
        ],
      ),
    );
  }
}

class _AnalysisPgnPanel extends StatelessWidget {
  const _AnalysisPgnPanel({
    required this.moves,
    required this.selectedPly,
    required this.onSelectPly,
    this.showFullMoveLabels = false,
    this.showEngineAnalysis = true,
    this.showGrandeurQuality = false,
    this.showMoveNumbers = true,
    this.showFooter = true,
  });

  final List<ReviewMove> moves;
  final int selectedPly;
  final ValueChanged<int> onSelectPly;
  final bool showFullMoveLabels;
  final bool showEngineAnalysis;
  final bool showGrandeurQuality;
  final bool showMoveNumbers;
  final bool showFooter;

  @override
  Widget build(BuildContext context) {
    final rows = _pgnRows(moves);
    final compactLandscape = isCompactLandscapeDevice(context);
    final selectedMove = moves.firstWhere(
      (move) => move.ply == selectedPly,
      orElse: () => moves.first,
    );
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Move list',
            subtitle:
                compactLandscape ? null : 'Tap any move to jump the board',
          ),
          SizedBox(height: compactLandscape ? 6 : 10),
          Container(
            constraints: BoxConstraints(
              maxHeight: compactLandscape ? 188 : 320,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.16),
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: rows.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 12,
                endIndent: 12,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
              ),
              itemBuilder: (context, index) {
                final row = rows[index];
                return _AnalysisPgnMoveRow(
                  moveNumber: row.moveNumber,
                  whiteMove: row.white,
                  blackMove: row.black,
                  selectedPly: selectedPly,
                  onSelectPly: onSelectPly,
                  showFullMoveLabels: showFullMoveLabels,
                  showEngineAnalysis: showEngineAnalysis,
                  showGrandeurQuality: showGrandeurQuality,
                  showMoveNumbers: showMoveNumbers,
                );
              },
            ),
          ),
          if (showEngineAnalysis) ...[
            SizedBox(height: compactLandscape ? 6 : 10),
            _PgnEngineAnnotation(move: selectedMove),
          ],
          if (showFooter &&
              !compactLandscape &&
              (showEngineAnalysis || showGrandeurQuality)) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _ReviewQualityMarker(spec: selectedMove.marker, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedMove.move,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selectedMove.color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _TinyBadge(
                  label: selectedMove.classification,
                  color: selectedMove.color,
                ),
              ],
            ),
          ],
          if (showFooter && !compactLandscape) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (showEngineAnalysis) ...[
                  _TinyBadge(
                    label:
                        '${moves.where((move) => move.keyMoment).length} moments',
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                ],
                _TinyBadge(
                  label: '${moves.length} plies',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<_PgnMovePair> _pgnRows(List<ReviewMove> moves) {
    final rowsByMoveNumber = <int, _PgnMovePair>{};
    for (final move in moves) {
      final current = rowsByMoveNumber[move.moveNumber];
      rowsByMoveNumber[move.moveNumber] = _PgnMovePair(
        moveNumber: move.moveNumber,
        white: move.isWhiteMove ? move : current?.white,
        black: move.isWhiteMove ? current?.black : move,
      );
    }
    return List.unmodifiable(rowsByMoveNumber.values);
  }
}

class _AttachedPgnBadge extends StatelessWidget {
  const _AttachedPgnBadge();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderRadius: 12,
      tint: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
      child: Row(
        children: [
          _TinyBadge(
            label: 'PGN',
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Loaded mainline for board analysis',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PgnMovePair {
  const _PgnMovePair({
    required this.moveNumber,
    this.white,
    this.black,
  });

  final int moveNumber;
  final ReviewMove? white;
  final ReviewMove? black;
}

class _AnalysisPgnMoveRow extends StatelessWidget {
  const _AnalysisPgnMoveRow({
    required this.moveNumber,
    required this.whiteMove,
    required this.blackMove,
    required this.selectedPly,
    required this.onSelectPly,
    required this.showFullMoveLabels,
    required this.showEngineAnalysis,
    required this.showGrandeurQuality,
    required this.showMoveNumbers,
  });

  final int moveNumber;
  final ReviewMove? whiteMove;
  final ReviewMove? blackMove;
  final int selectedPly;
  final ValueChanged<int> onSelectPly;
  final bool showFullMoveLabels;
  final bool showEngineAnalysis;
  final bool showGrandeurQuality;
  final bool showMoveNumbers;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        children: [
          if (showMoveNumbers)
            SizedBox(
              key: ValueKey('analysis-pgn-move-number-$moveNumber'),
              width: 40,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$moveNumber.',
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.54),
                      ),
                ),
              ),
            ),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey('analysis-pgn-white-$moveNumber'),
              child: whiteMove == null
                  ? const SizedBox.shrink()
                  : _AnalysisPgnMoveText(
                      move: whiteMove!,
                      selected: whiteMove!.ply == selectedPly,
                      onTap: () => onSelectPly(whiteMove!.ply),
                      showFullMoveLabels: showFullMoveLabels,
                      showEngineAnalysis: showEngineAnalysis,
                      showGrandeurQuality: showGrandeurQuality,
                    ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey('analysis-pgn-black-$moveNumber'),
              child: blackMove == null
                  ? const SizedBox.shrink()
                  : _AnalysisPgnMoveText(
                      move: blackMove!,
                      selected: blackMove!.ply == selectedPly,
                      onTap: () => onSelectPly(blackMove!.ply),
                      showFullMoveLabels: showFullMoveLabels,
                      showEngineAnalysis: showEngineAnalysis,
                      showGrandeurQuality: showGrandeurQuality,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisPgnMoveText extends StatelessWidget {
  const _AnalysisPgnMoveText({
    required this.move,
    required this.selected,
    required this.onTap,
    required this.showFullMoveLabels,
    required this.showEngineAnalysis,
    required this.showGrandeurQuality,
  });

  final ReviewMove move;
  final bool selected;
  final VoidCallback onTap;
  final bool showFullMoveLabels;
  final bool showEngineAnalysis;
  final bool showGrandeurQuality;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showQuality = showEngineAnalysis || showGrandeurQuality;
    final moveColor = showQuality ? move.color : scheme.onSurface;
    final selectionColor = showQuality ? move.color : scheme.primary;
    final sanText =
        showFullMoveLabels ? move.move : _stripMoveNumber(move.move);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        key: ValueKey('analysis-san-ply-${move.ply}'),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: selectionColor.withValues(alpha: selected ? 0.18 : 0.00),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selectionColor.withValues(alpha: selected ? 0.42 : 0.00),
            ),
          ),
          child: Row(
            children: [
              if (showQuality && move.keyMoment) ...[
                _ReviewQualityMarker(spec: move.marker, size: 16),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Text(
                  key: ValueKey('analysis-san-label-ply-${move.ply}'),
                  sanText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: moveColor,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (showEngineAnalysis) ...[
                const SizedBox(width: 4),
                Text(
                  key: ValueKey('analysis-eval-label-ply-${move.ply}'),
                  _formatEval(move.evalAfter),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected
                            ? moveColor
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.52),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _stripMoveNumber(String move) {
    return move.replaceFirst(RegExp(r'^\d+\.\.\.\s*'), '').replaceFirst(
          RegExp(r'^\d+\.\s*'),
          '',
        );
  }
}

class _PgnEngineAnnotation extends StatelessWidget {
  const _PgnEngineAnnotation({required this.move});

  final ReviewMove move;

  @override
  Widget build(BuildContext context) {
    final marker = move.marker;
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      borderRadius: 12,
      tint: marker.color.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReviewQualityMarker(spec: marker, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  move.summary,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.28,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.alt_route_rounded, color: marker.color, size: 16),
              Text(
                'Best continuation',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: marker.color,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            move.engineLine,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.28,
                ),
          ),
        ],
      ),
    );
  }
}

class _WorkbenchActionPanel extends StatelessWidget {
  const _WorkbenchActionPanel({
    required this.onOpenReport,
    required this.onOpenGrandeur,
    required this.onOpenMaia3,
    required this.grandeurLoading,
  });

  final VoidCallback onOpenReport;
  final VoidCallback onOpenGrandeur;
  final VoidCallback onOpenMaia3;
  final bool grandeurLoading;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Review options',
            subtitle: 'Switch from board analysis to a full report',
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 420;
              final standard = OutlinedButton.icon(
                key: const ValueKey('analysis-standard-report-button'),
                onPressed: onOpenReport,
                icon: const Icon(Icons.assessment_rounded),
                label: const _AnalysisButtonLabel('Standard report'),
              );
              final maia3 = OutlinedButton.icon(
                key: const ValueKey('analysis-maia3-human-review-button'),
                onPressed: onOpenMaia3,
                icon: const Icon(Icons.psychology_alt_rounded),
                label: const _AnalysisButtonLabel('Maia3 review'),
              );
              final grandeur = PrimaryButton(
                key: const ValueKey('analysis-grandeur-review-button'),
                label: grandeurLoading ? 'Checking wallet' : 'Grandeur review',
                icon: Icons.auto_awesome_rounded,
                onPressed: grandeurLoading ? null : onOpenGrandeur,
                labelMaxLines: 1,
                labelSoftWrap: false,
                labelOverflow: TextOverflow.ellipsis,
                scaleLabel: true,
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 48, child: standard),
                    const SizedBox(height: 8),
                    SizedBox(height: 48, child: maia3),
                    const SizedBox(height: 8),
                    grandeur,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: SizedBox(height: 48, child: standard)),
                  const SizedBox(width: 10),
                  Expanded(child: SizedBox(height: 48, child: maia3)),
                  const SizedBox(width: 10),
                  Expanded(child: grandeur),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AnalysisButtonLabel extends StatelessWidget {
  const _AnalysisButtonLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ReportBucket {
  const _ReportBucket({
    required this.label,
    required this.symbol,
    required this.color,
  });

  final String label;
  final String symbol;
  final Color color;
}

const _reportBuckets = [
  _ReportBucket(
    label: 'Brilliant',
    symbol: '!!',
    color: Color(0xFF34D399),
  ),
  _ReportBucket(
    label: 'Great',
    symbol: '!',
    color: Color(0xFF22D3EE),
  ),
  _ReportBucket(
    label: 'Best',
    symbol: '!!',
    color: Color(0xFFA3E635),
  ),
  _ReportBucket(
    label: 'Excellent',
    symbol: '·',
    color: Color(0xFF84CC16),
  ),
  _ReportBucket(
    label: 'Good',
    symbol: '!',
    color: Color(0xFF2DD4BF),
  ),
  _ReportBucket(
    label: 'Inaccuracy',
    symbol: '?!',
    color: Color(0xFFEAC84A),
  ),
  _ReportBucket(
    label: 'Mistake',
    symbol: '?',
    color: Color(0xFFF0A252),
  ),
  _ReportBucket(
    label: 'Miss',
    symbol: 'x',
    color: Color(0xFFE97866),
  ),
  _ReportBucket(
    label: 'Blunder',
    symbol: '??',
    color: Color(0xFFE2574C),
  ),
];

class _ReviewPlayerComparisonCard extends StatelessWidget {
  const _ReviewPlayerComparisonCard({
    required this.whiteName,
    required this.blackName,
    required this.whiteAccuracy,
    required this.blackAccuracy,
    required this.hasWhiteAccuracy,
    required this.hasBlackAccuracy,
    required this.whiteCounts,
    required this.blackCounts,
  });

  final String whiteName;
  final String blackName;
  final double whiteAccuracy;
  final double blackAccuracy;
  final bool hasWhiteAccuracy;
  final bool hasBlackAccuracy;
  final Map<String, int> whiteCounts;
  final Map<String, int> blackCounts;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      key: const ValueKey('review-player-comparison-table'),
      padding: const EdgeInsets.all(14),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Players',
            subtitle: 'Engine score map accuracy and move quality by side',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 104),
              Expanded(child: _PlayerHeader(name: whiteName, isWhite: true)),
              const SizedBox(width: 54),
              Expanded(child: _PlayerHeader(name: blackName, isWhite: false)),
            ],
          ),
          const SizedBox(height: 12),
          _ComparisonAccuracyRow(
            whiteAccuracy: whiteAccuracy,
            blackAccuracy: blackAccuracy,
            hasWhiteAccuracy: hasWhiteAccuracy,
            hasBlackAccuracy: hasBlackAccuracy,
          ),
          Divider(
            height: 24,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.22),
          ),
          for (final bucket in _reportBuckets) ...[
            _ComparisonBucketRow(
              bucket: bucket,
              whiteCount: whiteCounts[bucket.label] ?? 0,
              blackCount: blackCounts[bucket.label] ?? 0,
            ),
            if (bucket != _reportBuckets.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({
    required this.name,
    required this.isWhite,
  });

  final String name;
  final bool isWhite;

  @override
  Widget build(BuildContext context) {
    final color = isWhite
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.secondary;
    return Column(
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isWhite
                ? Colors.white.withValues(alpha: 0.90)
                : const Color(0xFF111827).withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.38), width: 2),
          ),
          child: Icon(
            Icons.person_rounded,
            color: isWhite ? const Color(0xFF64748B) : Colors.white70,
            size: 34,
          ),
        ),
      ],
    );
  }
}

class _ComparisonAccuracyRow extends StatelessWidget {
  const _ComparisonAccuracyRow({
    required this.whiteAccuracy,
    required this.blackAccuracy,
    required this.hasWhiteAccuracy,
    required this.hasBlackAccuracy,
  });

  final double whiteAccuracy;
  final double blackAccuracy;
  final bool hasWhiteAccuracy;
  final bool hasBlackAccuracy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 104,
          child: Text(
            'Accuracy',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        Expanded(
          child: _AccuracyPill(
            value: whiteAccuracy,
            light: true,
            available: hasWhiteAccuracy,
          ),
        ),
        const SizedBox(width: 54),
        Expanded(
          child: _AccuracyPill(
            value: blackAccuracy,
            light: false,
            available: hasBlackAccuracy,
          ),
        ),
      ],
    );
  }
}

class _AccuracyPill extends StatelessWidget {
  const _AccuracyPill({
    required this.value,
    required this.light,
    required this.available,
  });

  final double value;
  final bool light;
  final bool available;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: light
            ? Colors.white.withValues(alpha: 0.92)
            : Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        available ? value.toStringAsFixed(1) : '--',
        style: TextStyle(
          color: light ? const Color(0xFF222222) : Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ComparisonBucketRow extends StatelessWidget {
  const _ComparisonBucketRow({
    required this.bucket,
    required this.whiteCount,
    required this.blackCount,
  });

  final _ReportBucket bucket;
  final int whiteCount;
  final int blackCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Text(
            bucket.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        Expanded(
          child: _BucketCount(value: whiteCount, color: bucket.color),
        ),
        SizedBox(
          width: 54,
          child: Center(
            child: _ReportBucketMarker(bucket: bucket),
          ),
        ),
        Expanded(
          child: _BucketCount(value: blackCount, color: bucket.color),
        ),
      ],
    );
  }
}

class _BucketCount extends StatelessWidget {
  const _BucketCount({required this.value, required this.color});

  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      value.toString(),
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontSize: 21,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _ReportBucketMarker extends StatelessWidget {
  const _ReportBucketMarker({required this.bucket, this.compact = false});

  final _ReportBucket bucket;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 24 : 34,
      height: compact ? 24 : 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bucket.color,
        shape: BoxShape.circle,
      ),
      child: Text(
        bucket.symbol,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: compact ? 12 : 17,
          height: 1,
        ),
      ),
    );
  }
}

class _GrandeurAnalysisPage extends StatelessWidget {
  const _GrandeurAnalysisPage({
    required this.selectedMove,
    required this.selectedPly,
    required this.coach,
    required this.voiceGender,
    required this.onVoiceGenderChanged,
    required this.voiceMuted,
    required this.status,
    required this.generationProgress,
    required this.showGenerationProgress,
    required this.analysis,
    required this.showEngineAnalysis,
    required this.showGrandeurQuality,
    required this.onBack,
    required this.onSelectPly,
    required this.onFirstPly,
    required this.onPreviousPly,
    required this.onNextPly,
    required this.onLastPly,
    required this.autoPlaying,
    required this.onToggleAutoPlay,
    required this.onSpeechComplete,
    required this.onToggleMute,
    required this.onToggleBoardFlip,
    required this.onOpenSummary,
    required this.onCloseSummary,
    required this.moves,
    required this.whiteName,
    required this.blackName,
    required this.statistics,
    required this.showSummary,
    required this.reportSharing,
    required this.onShareReport,
    required this.reportDownloading,
    required this.onDownloadReport,
    required this.reportShareKey,
    required this.summaryShareKey,
    required this.boardFlipped,
    required this.showBoardCoordinates,
  });

  final ReviewMove selectedMove;
  final int selectedPly;
  final GrandeurCoachProfile coach;
  final String voiceGender;
  final ValueChanged<String> onVoiceGenderChanged;
  final bool voiceMuted;
  final String? status;
  final double generationProgress;
  final bool showGenerationProgress;
  final GrandeurAnalysisResult? analysis;
  final bool showEngineAnalysis;
  final bool showGrandeurQuality;
  final VoidCallback onBack;
  final ValueChanged<int> onSelectPly;
  final VoidCallback onFirstPly;
  final VoidCallback onPreviousPly;
  final VoidCallback onNextPly;
  final VoidCallback onLastPly;
  final bool autoPlaying;
  final VoidCallback onToggleAutoPlay;
  final VoidCallback onSpeechComplete;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleBoardFlip;
  final VoidCallback onOpenSummary;
  final VoidCallback onCloseSummary;
  final List<ReviewMove> moves;
  final String whiteName;
  final String blackName;
  final _GrandeurJsonStatistics statistics;
  final bool showSummary;
  final bool reportSharing;
  final bool reportDownloading;
  final Future<void> Function({
    required GlobalKey boundaryKey,
    required String fileName,
    required String subject,
  }) onShareReport;
  final VoidCallback onDownloadReport;
  final GlobalKey reportShareKey;
  final GlobalKey summaryShareKey;
  final bool boardFlipped;
  final bool showBoardCoordinates;

  @override
  Widget build(BuildContext context) {
    if (showSummary) {
      return _buildSummaryPage(context, coach);
    }
    return LayoutBuilder(
      key: const ValueKey('analysis-grandeur-page'),
      builder: (context, constraints) {
        final size = MediaQuery.sizeOf(context);
        final width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : size.width;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : size.height;
        final compactLandscape = width > height && height < 600;
        final scheme = Theme.of(context).colorScheme;
        final boardMax = compactLandscape
            ? (height - 160).clamp(200.0, 300.0).toDouble()
            : (width >= 840 ? 560.0 : 720.0);
        final boardPanel = _GrandeurBoardPanel(
          selectedMove: selectedMove,
          boardFlipped: boardFlipped,
          boardMaxSize: boardMax,
          compact: false,
          onBack: onBack,
          onFirstPly: onFirstPly,
          onPreviousPly: onPreviousPly,
          onNextPly: onNextPly,
          onLastPly: onLastPly,
          autoPlaying: autoPlaying,
          autoPlayAvailable: analysis != null,
          onToggleAutoPlay: onToggleAutoPlay,
          showCoordinates: showBoardCoordinates,
        );
        final coachRegion = _GrandeurCoachRegion(
          selectedMove: selectedMove,
          coach: coach,
          analysis: analysis,
          backendMove: _backendMoveForSelectedPly(),
          voiceGender: voiceGender,
          voiceMuted: voiceMuted,
          playbackActive: autoPlaying,
          onPlaybackComplete: onSpeechComplete,
          onToggleMute: onToggleMute,
          status: showGenerationProgress ? null : status,
          showGenerationProgress: showGenerationProgress,
          generationProgress: generationProgress,
          compact: false,
        );
        final movesRegion = _GrandeurMovesRegion(
          selectedPly: selectedPly,
          moves: moves,
          onSelectPly: onSelectPly,
          onOpenSummary: onOpenSummary,
          autoPlaying: autoPlaying,
          autoPlayAvailable: analysis != null,
          onToggleAutoPlay: onToggleAutoPlay,
          compact: false,
          showEngineAnalysis: showEngineAnalysis,
          showGrandeurQuality: showGrandeurQuality,
        );
        final sidePanel = _GrandeurSidePanel(
          coachRegion: coachRegion,
          movesRegion: movesRegion,
        );
        final shareButton = _GrandeurHeaderActions(
          shareKey: const ValueKey('analysis-grandeur-report-share-button'),
          sharing: reportSharing,
          onShare: () => onShareReport(
            boundaryKey: reportShareKey,
            fileName: 'chessnut-grandeur-report.png',
            subject: 'Chessnut Grandeur Report',
          ),
          downloading: reportDownloading,
          downloadEnabled: analysis != null,
          onDownload: onDownloadReport,
        );
        final headerActions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (commentaryTtsSupportsMaleVoice(_commentaryLanguage())) ...[
              PopupMenuButton<String>(
                key: const ValueKey('analysis-commentary-voice-gender'),
                tooltip: AppStrings.of(context).t('Commentary voice'),
                initialValue: voiceGender,
                onSelected: onVoiceGenderChanged,
                icon: Icon(
                  voiceGender == 'male'
                      ? Icons.male_rounded
                      : Icons.female_rounded,
                ),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'female', child: Text('Female voice')),
                  PopupMenuItem(value: 'male', child: Text('Male voice')),
                ],
              ),
              const SizedBox(width: 8),
            ],
            IconButton.filledTonal(
              key: const ValueKey('analysis-grandeur-flip-board-button'),
              tooltip: 'Flip board',
              onPressed: onToggleBoardFlip,
              isSelected: boardFlipped,
              icon: const Icon(Icons.flip_camera_android_rounded),
            ),
            const SizedBox(width: 8),
            shareButton,
          ],
        );
        final content = RepaintBoundary(
          key: reportShareKey,
          child: ColoredBox(
            key: const ValueKey('grandeur-page-background'),
            color: scheme.surface,
            child: compactLandscape
                ? SafeArea(
                    top: false,
                    bottom: false,
                    child: Column(
                      children: [
                        _GrandeurCompactHeader(
                          title: 'Grandeur Analysis',
                          subtitle: _stripDisplayMoveNumber(selectedMove.move),
                          onBack: onBack,
                          trailing: headerActions,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                            child: Row(
                              key: const ValueKey(
                                'grandeur-landscape-layout',
                              ),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: boardMax + 16,
                                  child: KeyedSubtree(
                                    key: const ValueKey(
                                      'grandeur-board-region',
                                    ),
                                    child: Center(child: boardPanel),
                                  ),
                                ),
                                const VerticalDivider(width: 16),
                                Expanded(
                                  child: SingleChildScrollView(
                                    key: const ValueKey(
                                      'grandeur-landscape-commentary',
                                    ),
                                    primary: false,
                                    child: sidePanel,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ResponsivePage(
                    children: (context, spec) => [
                      ScreenHeader(
                        title: 'Grandeur Analysis',
                        subtitle: _stripDisplayMoveNumber(selectedMove.move),
                        leading: IconButton.filledTonal(
                          key: const ValueKey('analysis-grandeur-back-button'),
                          onPressed: onBack,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        trailing: headerActions,
                      ),
                      ResponsiveSplit(
                        breakpoint: 840,
                        spacing: spec.gutter,
                        leadingFlex: 6,
                        trailingFlex: 5,
                        leading: KeyedSubtree(
                          key: const ValueKey('grandeur-board-region'),
                          child: boardPanel,
                        ),
                        trailing: sidePanel,
                      ),
                    ],
                  ),
          ),
        );
        return content;
      },
    );
  }

  Widget _buildSummaryPage(BuildContext context, GrandeurCoachProfile coach) {
    final summaryGenerating = analysis == null;
    final summaryText = summaryGenerating ? '' : _summarySpeechText();
    return LayoutBuilder(
      key: const ValueKey('analysis-grandeur-summary-page'),
      builder: (context, constraints) {
        final size = MediaQuery.sizeOf(context);
        final width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : size.width;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : size.height;
        final clockLayout = width >= 920 && height <= 560;
        final scheme = Theme.of(context).colorScheme;
        final shareActions = _SummaryHeaderActions(
          sharing: reportSharing,
          onShare: () => onShareReport(
            boundaryKey: summaryShareKey,
            fileName: 'chessnut-grandeur-summary.png',
            subject: 'Chessnut Grandeur Summary',
          ),
          onClose: onBack,
        );
        return RepaintBoundary(
          key: summaryShareKey,
          child: ColoredBox(
            key: const ValueKey('grandeur-summary-background'),
            color: scheme.surface,
            child: clockLayout
                ? Column(
                    children: [
                      _GrandeurCompactHeader(
                        title: 'Grandeur Summary',
                        subtitle: 'Full-game review',
                        onBack: onCloseSummary,
                        trailing: shareActions,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 11,
                                child: _GrandeurSummaryCard(
                                  coach: coach,
                                  summaryText: summaryText,
                                  language: analysis?.language ?? '',
                                  voiceGender: voiceGender,
                                  generating: summaryGenerating,
                                  moveCount: moves.length,
                                  explanationCount: analysis?.moves.length ?? 0,
                                  voiceMuted: voiceMuted,
                                  onToggleMute: onToggleMute,
                                  compact: true,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                flex: 10,
                                child: _GrandeurStatisticsList(
                                  whiteName: whiteName,
                                  blackName: blackName,
                                  statistics: statistics,
                                  compact: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ResponsivePage(
                    children: (context, spec) => [
                      ScreenHeader(
                        title: 'Summary',
                        subtitle: 'Grandeur Analysis',
                        leading: IconButton.filledTonal(
                          onPressed: onCloseSummary,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        trailing: shareActions,
                      ),
                      ResponsiveSplit(
                        breakpoint: 840,
                        spacing: spec.gutter,
                        leading: _GrandeurSummaryCard(
                          coach: coach,
                          summaryText: summaryText,
                          language: analysis?.language ?? '',
                          voiceGender: voiceGender,
                          generating: summaryGenerating,
                          moveCount: moves.length,
                          explanationCount: analysis?.moves.length ?? 0,
                          voiceMuted: voiceMuted,
                          onToggleMute: onToggleMute,
                        ),
                        trailing: _GrandeurStatisticsList(
                          whiteName: whiteName,
                          blackName: blackName,
                          statistics: statistics,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  String _summarySpeechText() {
    return _buildGrandeurSummaryText(analysis);
  }

  String _commentaryLanguage() {
    final report = analysis;
    if (report == null) return '';
    return resolveCommentaryTtsLanguage(
      text: _summarySpeechText(),
      language: report.language,
    );
  }

  GrandeurMoveExplanation? _backendMoveForSelectedPly() {
    final reportMoves = analysis?.moves ?? const <GrandeurMoveExplanation>[];
    final pgnIndex = moves.indexWhere((move) => move.ply == selectedPly);
    if (pgnIndex < 0 || pgnIndex >= reportMoves.length) return null;
    // Grandeur's SAN list is in the same order as the PGN.  Use that stable
    // relationship instead of trusting a report ply value that may be absent
    // or synthesized by the parser.
    return reportMoves[pgnIndex];
  }
}

class _ReportHeaderActions extends StatelessWidget {
  const _ReportHeaderActions({
    required this.shareKey,
    required this.sharing,
    required this.onShare,
  });

  final Key shareKey;
  final bool sharing;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return _ReportShareButton(
      key: shareKey,
      sharing: sharing,
      onPressed: onShare,
    );
  }
}

class _AnalysisBoardFlipButton extends StatelessWidget {
  const _AnalysisBoardFlipButton({
    required this.flipped,
    required this.onPressed,
    super.key,
  });

  final bool flipped;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: 'Flip board',
      onPressed: onPressed,
      isSelected: flipped,
      icon: const Icon(Icons.flip_camera_android_rounded),
    );
  }
}

class _Maia3HumanReviewPage extends StatefulWidget {
  const _Maia3HumanReviewPage({
    required this.selectedMove,
    required this.selectedPly,
    required this.status,
    required this.analysis,
    required this.task,
    required this.selectedElo,
    required this.compareStockfish,
    required this.stockfishLoading,
    required this.stockfishBacked,
    required this.stockfishProgress,
    required this.stockfishStatus,
    required this.showEngineAnalysis,
    required this.onBack,
    required this.onStart,
    required this.onRetry,
    required this.onEloChanged,
    required this.onToggleCompareStockfish,
    required this.onSelectPly,
    required this.onFirstPly,
    required this.onPreviousPly,
    required this.onNextPly,
    required this.onLastPly,
    required this.moves,
    required this.whiteName,
    required this.blackName,
    required this.showBoardCoordinates,
    required this.isChessnutClockDevice,
  });

  final ReviewMove selectedMove;
  final int selectedPly;
  final String? status;
  final Maia3HumanReviewReport? analysis;
  final Maia3HumanReviewTask? task;
  final int selectedElo;
  final bool compareStockfish;
  final bool stockfishLoading;
  final bool stockfishBacked;
  final double stockfishProgress;
  final String? stockfishStatus;
  final bool showEngineAnalysis;
  final VoidCallback onBack;
  final VoidCallback onStart;
  final VoidCallback onRetry;
  final ValueChanged<int> onEloChanged;
  final ValueChanged<bool> onToggleCompareStockfish;
  final ValueChanged<int> onSelectPly;
  final VoidCallback onFirstPly;
  final VoidCallback onPreviousPly;
  final VoidCallback onNextPly;
  final VoidCallback onLastPly;
  final List<ReviewMove> moves;
  final String whiteName;
  final String blackName;
  final bool showBoardCoordinates;
  final bool isChessnutClockDevice;

  @override
  State<_Maia3HumanReviewPage> createState() => _Maia3HumanReviewPageState();
}

class _Maia3HumanReviewPageState extends State<_Maia3HumanReviewPage> {
  _Maia3ReviewTab currentTab = _Maia3ReviewTab.insight;
  late bool reviewSettingsExpanded;
  bool boardFlipped = false;

  @override
  void initState() {
    super.initState();
    reviewSettingsExpanded = widget.analysis == null && widget.task == null;
  }

  @override
  void didUpdateWidget(covariant _Maia3HumanReviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasStarted = oldWidget.analysis != null || oldWidget.task != null;
    final isStarted = widget.analysis != null || widget.task != null;
    if (!wasStarted && isStarted && reviewSettingsExpanded) {
      reviewSettingsExpanded = false;
    }
  }

  Maia3HumanReviewMove? get selectedHumanMove {
    final report = widget.analysis;
    if (report == null) return null;
    for (final move in report.moves) {
      if (move.ply == widget.selectedPly) return move;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.task?.value;
    final report = widget.analysis;
    final progress = snapshot?.progress ?? (report == null ? 0.0 : 1.0);
    final progressText = widget.status ??
        (report == null
            ? 'Maia3 Human Review is preparing...'
            : 'Maia3 Human Review ready.');
    final scheme = Theme.of(context).colorScheme;
    final maia3Running =
        snapshot?.state == Maia3HumanReviewTaskState.running && report == null;
    final activeElo = report?.elo ?? widget.selectedElo;
    final headerBadgeLabel = report == null && snapshot != null
        ? '${(progress * 100).round().clamp(0, 100)}%'
        : '$activeElo Elo';
    final androidPhoneLandscape = _isAndroidPhoneLandscapeLayout(
      context,
      isChessnutClockDevice: widget.isChessnutClockDevice,
    );
    final page = ResponsivePage(
      key: const ValueKey('analysis-maia3-human-review-page'),
      children: (context, spec) => [
        ScreenHeader(
          title: 'Maia3 Human Review',
          subtitle: 'Human move probabilities',
          leading: IconButton.filledTonal(
            key: const ValueKey('analysis-maia3-back-button'),
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              KeyedSubtree(
                key: const ValueKey('maia3-review-header-elo-badge'),
                child: _TinyBadge(
                  label: headerBadgeLabel,
                  color: scheme.secondary,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                key: const ValueKey('maia3-review-help-button'),
                tooltip: 'How Maia3 works',
                onPressed: _showHelpDialog,
                icon: const Icon(Icons.help_outline_rounded),
              ),
            ],
          ),
        ),
        SizedBox(height: spec.gutter),
        ResponsiveSplit(
          breakpoint: 900,
          spacing: spec.gutter,
          leadingFlex: 7,
          trailingFlex: 5,
          leading: SectionColumn(
            spacing: 12,
            children: [
              ResponsiveBoardFrame(
                maxSize: androidPhoneLandscape
                    ? _androidPhoneLandscapeBoardMax(context)
                    : spec.compactLandscape
                        ? 344
                        : (spec.canSplit ? 620 : 720),
                extraWidth: _analysisScoreBarWidth,
                padding: EdgeInsets.all(spec.compactLandscape ? 2 : 8),
                builder: (size) => _AnalysisBoardWithEvalBar(
                  size: size,
                  selectedMove: widget.selectedMove,
                  flipped: boardFlipped,
                  showReviewMarker: true,
                  showCoordinates: widget.showBoardCoordinates,
                ),
              ),
              _AnalysisMoveControls(
                onFirst: widget.onFirstPly,
                onPrevious: widget.onPreviousPly,
                onNext: widget.onNextPly,
                onLast: widget.onLastPly,
                extraAction: _AnalysisBoardFlipButton(
                  key: const ValueKey('analysis-maia3-flip-board-button'),
                  flipped: boardFlipped,
                  onPressed: () => setState(() => boardFlipped = !boardFlipped),
                ),
              ),
              _Maia3StatusBanner(
                progress: progress,
                status: progressText,
                report: report,
                snapshotState: snapshot?.state,
                selectedElo: widget.selectedElo,
                task: widget.task,
                whiteName: widget.whiteName,
                blackName: widget.blackName,
                onStart: _startReview,
                onRetry: widget.onRetry,
              ),
            ],
          ),
          trailing: SectionColumn(
            spacing: 12,
            children: [
              _Maia3ReviewSettingsCard(
                selectedElo: widget.selectedElo,
                compareStockfish: widget.compareStockfish,
                canEditElo: !maia3Running,
                expanded: reviewSettingsExpanded,
                onEloChanged: widget.onEloChanged,
                onCompareStockfishChanged: widget.onToggleCompareStockfish,
                onExpandChanged: (expanded) =>
                    setState(() => reviewSettingsExpanded = expanded),
              ),
              _Maia3TabStrip(
                selected: currentTab,
                onChanged: (tab) => setState(() => currentTab = tab),
              ),
              _Maia3TabContent(
                tab: currentTab,
                analysis: report,
                reviewMove: widget.selectedMove,
                selectedMove: selectedHumanMove,
                selectedPly: widget.selectedPly,
                compareStockfish: widget.compareStockfish,
                stockfishLoading: widget.stockfishLoading,
                stockfishBacked: widget.stockfishBacked,
                stockfishProgress: widget.stockfishProgress,
                stockfishStatus: widget.stockfishStatus,
                showEngineAnalysis: widget.showEngineAnalysis,
                moves: widget.moves,
                whiteName: widget.whiteName,
                blackName: widget.blackName,
                status: progressText,
                progress: progress,
                onSelectPly: widget.onSelectPly,
              ),
            ],
          ),
        ),
      ],
    );
    return androidPhoneLandscape
        ? SafeArea(top: false, bottom: false, child: page)
        : page;
  }

  void _startReview() {
    if (reviewSettingsExpanded) {
      setState(() => reviewSettingsExpanded = false);
    }
    widget.onStart();
  }

  void _showHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialogShell(
        icon: Icons.help_outline_rounded,
        title: 'How Maia3 Review works',
        subtitle: 'Mobile view',
        actions: [
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Got it'),
            ),
          ),
        ],
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Maia3 focuses on how a human at the selected strength is likely to move.',
              style: TextStyle(height: 1.35),
            ),
            SizedBox(height: 10),
            Text(
              'Insight shows the current move and likely human alternatives.',
              style: TextStyle(height: 1.35),
            ),
            SizedBox(height: 10),
            Text(
              'Moves keeps the full game easy to scrub and reopen later.',
              style: TextStyle(height: 1.35),
            ),
            SizedBox(height: 10),
            Text(
              'Summary condenses the whole game into human match and key moments.',
              style: TextStyle(height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _Maia3SummaryCard extends StatelessWidget {
  const _Maia3SummaryCard({
    required this.analysis,
    required this.progress,
    required this.status,
    required this.whiteName,
    required this.blackName,
  });

  final Maia3HumanReviewReport? analysis;
  final double progress;
  final String status;
  final String whiteName;
  final String blackName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final report = analysis;
    final percent = (progress * 100).round().clamp(0, 100);
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: 14,
      tint: scheme.secondary.withValues(alpha: 0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_alt_rounded,
                  color: scheme.secondary, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: _SectionTitle(
                  title: 'Human likelihood',
                  subtitle:
                      'Maia3 estimates what humans at this strength are likely to play.',
                ),
              ),
              _TinyBadge(
                label: report == null ? '$percent%' : '${report.elo} Elo',
                color: scheme.secondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (report == null) ...[
            LinearProgressIndicator(
              value: progress <= 0 ? null : progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
              color: scheme.secondary,
              backgroundColor: scheme.secondary.withValues(alpha: 0.14),
            ),
            const SizedBox(height: 8),
            Text(status, style: Theme.of(context).textTheme.bodySmall),
          ] else ...[
            _Maia3MetricRow(
              label: 'Human match',
              value: '${report.summary.humanMatchPercent.toStringAsFixed(1)}%',
            ),
            const SizedBox(height: 8),
            _Maia3MetricRow(
              label: 'More typical side',
              value: _sideLabel(
                report.summary.mostHumanSide,
                whiteName,
                blackName,
              ),
              valueMaxLines: 1,
            ),
            if (report.summary.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                report.summary.notes.first,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.32,
                    ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _sideLabel(String side, String whiteName, String blackName) {
    return switch (side.trim().toLowerCase()) {
      'white' => whiteName,
      'black' => blackName,
      _ => '--',
    };
  }
}

class _Maia3StatusBanner extends StatelessWidget {
  const _Maia3StatusBanner({
    required this.progress,
    required this.status,
    required this.report,
    required this.snapshotState,
    required this.selectedElo,
    required this.task,
    required this.whiteName,
    required this.blackName,
    required this.onStart,
    required this.onRetry,
  });

  final double progress;
  final String status;
  final Maia3HumanReviewReport? report;
  final Maia3HumanReviewTaskState? snapshotState;
  final int selectedElo;
  final Maia3HumanReviewTask? task;
  final String whiteName;
  final String blackName;
  final VoidCallback onStart;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = (progress * 100).round().clamp(0, 100);
    final failed = snapshotState == Maia3HumanReviewTaskState.failed;
    final ready = report != null;
    final waitingToStart = report == null && task == null && !failed;
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: 14,
      tint: scheme.secondary.withValues(alpha: 0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ready
                    ? Icons.psychology_alt_rounded
                    : failed
                        ? Icons.error_outline_rounded
                        : Icons.sync_rounded,
                color: failed ? scheme.error : scheme.secondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: _SectionTitle(
                  title: 'Human move model',
                  subtitle:
                      'Maia3 estimates likely human choices, not engine-best moves.',
                ),
              ),
              _TinyBadge(
                label: ready
                    ? '${report!.elo} Elo'
                    : waitingToStart
                        ? '$selectedElo Elo'
                        : '$percent%',
                color: failed ? scheme.error : scheme.secondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (waitingToStart) ...[
            Text(
              'Choose the human rating to review against, then start Maia3.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const ValueKey('maia3-review-start-button'),
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const _AnalysisButtonLabel('Start Maia3 Review'),
              ),
            ),
          ] else if (!ready) ...[
            LinearProgressIndicator(
              value: progress <= 0 || failed ? null : progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
              color: failed ? scheme.error : scheme.secondary,
              backgroundColor: (failed ? scheme.error : scheme.secondary)
                  .withValues(alpha: 0.14),
            ),
            const SizedBox(height: 8),
            Text(status, style: Theme.of(context).textTheme.bodySmall),
            if (failed) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ),
            ],
          ] else ...[
            _Maia3MetricRow(
              label: 'Human match',
              value: '${report!.summary.humanMatchPercent.toStringAsFixed(1)}%',
            ),
            const SizedBox(height: 8),
            _Maia3MetricRow(
              label: 'More typical side',
              value: _sideLabel(
                report!.summary.mostHumanSide,
                whiteName,
                blackName,
              ),
              valueMaxLines: 1,
            ),
          ],
        ],
      ),
    );
  }

  String _sideLabel(String side, String whiteName, String blackName) {
    return switch (side.trim().toLowerCase()) {
      'white' => whiteName,
      'black' => blackName,
      _ => '--',
    };
  }
}

class _Maia3TabStrip extends StatelessWidget {
  const _Maia3TabStrip({
    required this.selected,
    required this.onChanged,
  });

  final _Maia3ReviewTab selected;
  final ValueChanged<_Maia3ReviewTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(6),
      borderRadius: 14,
      child: Row(
        children: [
          for (final tab in _Maia3ReviewTab.values.where(
            (tab) => _showMaia3RatingTab || tab != _Maia3ReviewTab.rating,
          ))
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _Maia3TabButton(
                  tab: tab,
                  selected: selected == tab,
                  onTap: () => onChanged(tab),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Maia3TabButton extends StatelessWidget {
  const _Maia3TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _Maia3ReviewTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurface;
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.13)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 42),
          child: Center(
            child: Text(
              _maia3TabLabel(tab),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _maia3TabLabel(_Maia3ReviewTab tab) {
  return switch (tab) {
    _Maia3ReviewTab.insight => 'Insight',
    _Maia3ReviewTab.moves => 'Moves',
    _Maia3ReviewTab.rating => 'Rating',
    _Maia3ReviewTab.summary => 'Summary',
  };
}

class _Maia3TabContent extends StatelessWidget {
  const _Maia3TabContent({
    required this.tab,
    required this.analysis,
    required this.reviewMove,
    required this.selectedMove,
    required this.selectedPly,
    required this.compareStockfish,
    required this.stockfishLoading,
    required this.stockfishBacked,
    required this.stockfishProgress,
    required this.stockfishStatus,
    required this.showEngineAnalysis,
    required this.moves,
    required this.whiteName,
    required this.blackName,
    required this.status,
    required this.progress,
    required this.onSelectPly,
  });

  final _Maia3ReviewTab tab;
  final Maia3HumanReviewReport? analysis;
  final ReviewMove reviewMove;
  final Maia3HumanReviewMove? selectedMove;
  final int selectedPly;
  final bool compareStockfish;
  final bool stockfishLoading;
  final bool stockfishBacked;
  final double stockfishProgress;
  final String? stockfishStatus;
  final bool showEngineAnalysis;
  final List<ReviewMove> moves;
  final String whiteName;
  final String blackName;
  final String status;
  final double progress;
  final ValueChanged<int> onSelectPly;

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      _Maia3ReviewTab.insight => _Maia3InsightPanel(
          move: selectedMove,
          reviewMove: reviewMove,
          analysis: analysis,
          status: status,
          progress: progress,
          compareStockfish: compareStockfish,
          stockfishLoading: stockfishLoading,
          stockfishBacked: stockfishBacked,
          stockfishProgress: stockfishProgress,
          stockfishStatus: stockfishStatus,
        ),
      _Maia3ReviewTab.moves => _AnalysisPgnPanel(
          moves: moves,
          selectedPly: selectedPly,
          onSelectPly: onSelectPly,
          showEngineAnalysis: showEngineAnalysis,
        ),
      _Maia3ReviewTab.rating => _Maia3RatingPanel(
          analysis: analysis,
          selectedMove: selectedMove,
        ),
      _Maia3ReviewTab.summary => _Maia3FullSummaryPanel(
          analysis: analysis,
          moves: moves,
          whiteName: whiteName,
          blackName: blackName,
          onSelectPly: onSelectPly,
        ),
    };
  }
}

class _Maia3InsightPanel extends StatelessWidget {
  const _Maia3InsightPanel({
    required this.move,
    required this.reviewMove,
    required this.analysis,
    required this.status,
    required this.progress,
    required this.compareStockfish,
    required this.stockfishLoading,
    required this.stockfishBacked,
    required this.stockfishProgress,
    required this.stockfishStatus,
  });

  final Maia3HumanReviewMove? move;
  final ReviewMove reviewMove;
  final Maia3HumanReviewReport? analysis;
  final String status;
  final double progress;
  final bool compareStockfish;
  final bool stockfishLoading;
  final bool stockfishBacked;
  final double stockfishProgress;
  final String? stockfishStatus;

  @override
  Widget build(BuildContext context) {
    final current = move;
    if (analysis == null) {
      return _Maia3LoadingPanel(status: status, progress: progress);
    }
    return SectionColumn(
      spacing: 12,
      children: [
        _Maia3MoveCard(move: current),
        if (compareStockfish)
          _Maia3EngineCompareCard(
            reviewMove: reviewMove,
            humanMove: current,
            stockfishLoading: stockfishLoading,
            stockfishBacked: stockfishBacked,
            stockfishProgress: stockfishProgress,
            stockfishStatus: stockfishStatus,
          ),
      ],
    );
  }
}

class _Maia3LoadingPanel extends StatelessWidget {
  const _Maia3LoadingPanel({
    required this.status,
    required this.progress,
  });

  final String status;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: 14,
      tint: scheme.secondary.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Preparing insight',
            subtitle: 'Maia3 is estimating likely human choices for each move.',
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress <= 0 ? null : progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(999),
            color: scheme.secondary,
            backgroundColor: scheme.secondary.withValues(alpha: 0.14),
          ),
          const SizedBox(height: 8),
          Text(status, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Maia3ReviewSettingsCard extends StatefulWidget {
  const _Maia3ReviewSettingsCard({
    required this.selectedElo,
    required this.compareStockfish,
    required this.canEditElo,
    required this.expanded,
    required this.onEloChanged,
    required this.onCompareStockfishChanged,
    required this.onExpandChanged,
  });

  final int selectedElo;
  final bool compareStockfish;
  final bool canEditElo;
  final bool expanded;
  final ValueChanged<int> onEloChanged;
  final ValueChanged<bool> onCompareStockfishChanged;
  final ValueChanged<bool> onExpandChanged;

  @override
  State<_Maia3ReviewSettingsCard> createState() =>
      _Maia3ReviewSettingsCardState();
}

class _Maia3ReviewSettingsCardState extends State<_Maia3ReviewSettingsCard> {
  int? draftElo;

  int get displayElo => draftElo ?? widget.selectedElo;

  @override
  void didUpdateWidget(covariant _Maia3ReviewSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedElo != widget.selectedElo ||
        oldWidget.canEditElo != widget.canEditElo) {
      draftElo = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shownElo = displayElo;
    if (!widget.expanded) {
      return GlassPanel(
        key: const ValueKey('maia3-review-settings-summary'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        borderRadius: 14,
        tint: scheme.secondary.withValues(alpha: 0.05),
        onTap: () => widget.onExpandChanged(true),
        child: Row(
          children: [
            Icon(Icons.tune_rounded, color: scheme.secondary, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Review settings',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  _TinyBadge(
                    label: '$shownElo Elo',
                    color: scheme.secondary,
                  ),
                  _TinyBadge(
                    label: widget.compareStockfish
                        ? 'Compare with Stockfish'
                        : 'Maia3 official rating model',
                    color: widget.compareStockfish
                        ? const Color(0xFFF59E0B)
                        : scheme.secondary,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              key: const ValueKey('maia3-review-settings-expand'),
              tooltip: 'Review settings',
              onPressed: () => widget.onExpandChanged(true),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ],
        ),
      );
    }

    return GlassPanel(
      key: const ValueKey('maia3-review-settings-expanded'),
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      tint: scheme.secondary.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, color: scheme.secondary, size: 19),
              const SizedBox(width: 8),
              const Expanded(
                child: _SectionTitle(
                  title: 'Review settings',
                  subtitle: 'Maia3 official rating model',
                ),
              ),
              _TinyBadge(label: '$shownElo Elo', color: scheme.secondary),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                key: const ValueKey('maia3-review-settings-collapse'),
                tooltip: 'Review settings',
                onPressed: () => widget.onExpandChanged(false),
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton.filledTonal(
                key: const ValueKey('maia3-review-elo-decrease'),
                icon: const Icon(Icons.remove_rounded),
                onPressed: widget.canEditElo && widget.selectedElo > maia3MinElo
                    ? () => _commitElo(widget.selectedElo - maia3EloStep)
                    : null,
              ),
              Expanded(
                child: Slider(
                  key: const ValueKey('maia3-review-elo-slider'),
                  value: shownElo.toDouble(),
                  min: maia3MinElo.toDouble(),
                  max: maia3MaxElo.toDouble(),
                  divisions: (maia3MaxElo - maia3MinElo) ~/ maia3EloStep,
                  label: '$shownElo',
                  onChanged: widget.canEditElo
                      ? (value) => setState(
                            () => draftElo = _normalizeMaia3ReviewElo(
                              value.round(),
                            ),
                          )
                      : null,
                  onChangeEnd: widget.canEditElo
                      ? (value) => _commitElo(
                            _normalizeMaia3ReviewElo(value.round()),
                          )
                      : null,
                ),
              ),
              IconButton.filledTonal(
                key: const ValueKey('maia3-review-elo-increase'),
                icon: const Icon(Icons.add_rounded),
                onPressed: widget.canEditElo && widget.selectedElo < maia3MaxElo
                    ? () => _commitElo(widget.selectedElo + maia3EloStep)
                    : null,
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$maia3MinElo',
                  style: Theme.of(context).textTheme.labelSmall),
              Text('$maia3MaxElo',
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: SwitchListTile.adaptive(
              key: const ValueKey('maia3-review-stockfish-compare-switch'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: widget.compareStockfish,
              onChanged: widget.onCompareStockfishChanged,
              title: const Text('Compare with Stockfish'),
              subtitle: const Text(
                'Show human likelihood next to the engine verdict.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _commitElo(int elo) {
    final normalized = _normalizeMaia3ReviewElo(elo);
    setState(() => draftElo = null);
    widget.onEloChanged(normalized);
  }
}

class _Maia3EngineCompareCard extends StatelessWidget {
  const _Maia3EngineCompareCard({
    required this.reviewMove,
    required this.humanMove,
    required this.stockfishLoading,
    required this.stockfishBacked,
    required this.stockfishProgress,
    required this.stockfishStatus,
  });

  final ReviewMove reviewMove;
  final Maia3HumanReviewMove? humanMove;
  final bool stockfishLoading;
  final bool stockfishBacked;
  final double stockfishProgress;
  final String? stockfishStatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final human = humanMove;
    final stockfishPercent = (stockfishProgress * 100).round().clamp(0, 100);
    final verdict = _maia3StockfishVerdict(reviewMove, human);
    final humanLabel = human == null
        ? '--'
        : human.humanLabel.isEmpty
            ? human.typicality
            : human.humanLabel;
    final probability = human == null
        ? '--'
        : '${(human.playedProbability * 100).toStringAsFixed(1)}%';
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      tint: scheme.primary.withValues(alpha: 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Engine comparison',
            subtitle:
                'Maia3 explains human likelihood. Stockfish checks objective quality.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TinyBadge(
                  label: verdict, color: _maia3VerdictColor(scheme, verdict)),
              _TinyBadge(
                label: stockfishBacked
                    ? 'Stockfish ready'
                    : stockfishLoading
                        ? 'Stockfish $stockfishPercent%'
                        : 'Stockfish pending',
                color:
                    stockfishBacked ? scheme.primary : const Color(0xFFF59E0B),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Maia3MetricRow(
            label: 'Human likelihood',
            value: '$probability / $humanLabel',
          ),
          const SizedBox(height: 8),
          if (stockfishBacked) ...[
            _Maia3MetricRow(
              label: 'Engine verdict',
              value:
                  '${reviewMove.classification} / ${_formatEval(reviewMove.evalAfter)}',
            ),
            const SizedBox(height: 8),
            _Maia3MetricRow(
              label: 'Best move',
              value: reviewMove.bestMove,
            ),
          ] else ...[
            LinearProgressIndicator(
              value: stockfishLoading && stockfishProgress > 0
                  ? stockfishProgress
                  : null,
              minHeight: 5,
              borderRadius: BorderRadius.circular(999),
              color: const Color(0xFFF59E0B),
              backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.16),
            ),
            const SizedBox(height: 8),
            Text(
              stockfishStatus ??
                  'Stockfish comparison will appear when Standard Analysis is ready.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

String _maia3StockfishVerdict(
  ReviewMove reviewMove,
  Maia3HumanReviewMove? humanMove,
) {
  final humanProbability = humanMove?.playedProbability ?? 0;
  final isLikelyHuman = humanProbability >= 0.20;
  final isGoodEngineMove = _isGoodEngineMove(reviewMove);
  if (isLikelyHuman && isGoodEngineMove) return 'Natural and strong';
  if (isLikelyHuman && !isGoodEngineMove) return 'Common mistake';
  if (!isLikelyHuman && isGoodEngineMove) return 'Engine-like move';
  return 'Unusual mistake';
}

bool _isGoodEngineMove(ReviewMove move) {
  if (move.scoreMapLevel != null) return move.scoreMapLevel! <= 3;
  const goodClassifications = {
    'Brilliant',
    'Best',
    'Great',
    'Excellent',
    'Good',
    'Book',
  };
  return goodClassifications.contains(move.classification);
}

Color _maia3VerdictColor(ColorScheme scheme, String verdict) {
  return switch (verdict) {
    'Natural and strong' => const Color(0xFF16A34A),
    'Common mistake' => const Color(0xFFF97316),
    'Engine-like move' => scheme.secondary,
    _ => scheme.error,
  };
}

class _Maia3RatingPanel extends StatelessWidget {
  const _Maia3RatingPanel({
    required this.analysis,
    required this.selectedMove,
  });

  final Maia3HumanReviewReport? analysis;
  final Maia3HumanReviewMove? selectedMove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = selectedMove;
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: 14,
      tint: scheme.secondary.withValues(alpha: 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Moves by rating',
            subtitle:
                'Official Maia can compare moves across rating levels. This mobile view keeps the selected model compact.',
          ),
          const SizedBox(height: 12),
          if (analysis == null || current == null) ...[
            Text(
              'Rating trends will appear after Maia3 finishes this review.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else ...[
            _Maia3MetricRow(label: 'Current model', value: analysis!.model),
            const SizedBox(height: 8),
            _Maia3MetricRow(
                label: 'Selected strength', value: '${analysis!.elo} Elo'),
            const SizedBox(height: 12),
            for (final candidate in current.candidates.take(4)) ...[
              _Maia3CandidateLine(
                label: candidate.move,
                san: candidate.san,
                probability: candidate.probability,
                color: scheme.secondary,
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _Maia3FullSummaryPanel extends StatelessWidget {
  const _Maia3FullSummaryPanel({
    required this.analysis,
    required this.moves,
    required this.whiteName,
    required this.blackName,
    required this.onSelectPly,
  });

  final Maia3HumanReviewReport? analysis;
  final List<ReviewMove> moves;
  final String whiteName;
  final String blackName;
  final ValueChanged<int> onSelectPly;

  @override
  Widget build(BuildContext context) {
    final report = analysis;
    final scheme = Theme.of(context).colorScheme;
    return SectionColumn(
      spacing: 12,
      children: [
        _Maia3SummaryCard(
          analysis: report,
          progress: report == null ? 0 : 1,
          status: report == null
              ? 'Maia3 Human Review is preparing...'
              : 'Maia3 Human Review ready.',
          whiteName: whiteName,
          blackName: blackName,
        ),
        GlassPanel(
          padding: const EdgeInsets.all(14),
          borderRadius: 14,
          tint: scheme.primary.withValues(alpha: 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                title: 'Key moments',
                subtitle: 'Tap a move to jump back to the board.',
              ),
              const SizedBox(height: 12),
              if (report == null) ...[
                Text(
                  'Key moments will be available after the cloud review finishes.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ] else ...[
                for (final ply in report.summary.sharpestMoments.take(4)) ...[
                  _Maia3MomentRow(
                    ply: ply,
                    fallbackMove: _moveForPly(ply),
                    onTap: () => onSelectPly(ply),
                  ),
                  const SizedBox(height: 8),
                ],
                if (report.summary.sharpestMoments.isEmpty)
                  Text(
                    'No unusually sharp human-choice swings were found.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  ReviewMove? _moveForPly(int ply) {
    for (final move in moves) {
      if (move.ply == ply) return move;
    }
    return null;
  }
}

class _Maia3MomentRow extends StatelessWidget {
  const _Maia3MomentRow({
    required this.ply,
    required this.fallbackMove,
    required this.onTap,
  });

  final int ply;
  final ReviewMove? fallbackMove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final move = fallbackMove;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              _TinyBadge(label: 'Ply $ply', color: scheme.secondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  move?.move ?? 'Move $ply',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _Maia3MetricRow extends StatelessWidget {
  const _Maia3MetricRow({
    required this.label,
    required this.value,
    this.valueMaxLines = 2,
  });

  final String label;
  final String value;
  final int valueMaxLines;

  @override
  Widget build(BuildContext context) {
    final valueStyle = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(fontWeight: FontWeight.w900);
    final valueText = Text(
      value,
      maxLines: valueMaxLines,
      overflow:
          valueMaxLines == 1 ? TextOverflow.visible : TextOverflow.ellipsis,
      softWrap: valueMaxLines != 1,
      textAlign: TextAlign.right,
      style: valueStyle,
    );
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: valueMaxLines == 1
              ? Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: valueText,
                  ),
                )
              : valueText,
        ),
      ],
    );
  }
}

class _Maia3MoveCard extends StatelessWidget {
  const _Maia3MoveCard({required this.move});

  final Maia3HumanReviewMove? move;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = move;
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      tint: scheme.secondary.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Move likelihood',
            subtitle:
                'Candidate moves are human probabilities, not best-move scores.',
          ),
          const SizedBox(height: 12),
          if (current == null) ...[
            Text(
              'Select a move after Maia3 finishes to see human move probabilities.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else ...[
            Row(
              children: [
                _TinyBadge(
                  label: current.move,
                  color: scheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    current.humanLabel.isEmpty
                        ? current.typicality
                        : current.humanLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Maia3CandidateLine(
              label: 'Played move',
              san: current.move,
              probability: current.playedProbability,
              color: scheme.primary,
            ),
            const SizedBox(height: 10),
            for (final candidate in current.candidates.take(5)) ...[
              _Maia3CandidateLine(
                label: candidate.move,
                san: candidate.san,
                probability: candidate.probability,
                color: scheme.secondary,
              ),
              const SizedBox(height: 7),
            ],
          ],
        ],
      ),
    );
  }
}

class _Maia3CandidateLine extends StatelessWidget {
  const _Maia3CandidateLine({
    required this.label,
    required this.san,
    required this.probability,
    required this.color,
  });

  final String label;
  final String san;
  final double probability;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percent = (probability * 100).clamp(0, 100).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                san.isEmpty ? label : '$san  $label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${percent.toStringAsFixed(1)}%',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percent / 100,
          minHeight: 5,
          borderRadius: BorderRadius.circular(999),
          color: color,
          backgroundColor: color.withValues(alpha: 0.14),
        ),
      ],
    );
  }
}

class _GrandeurCompactHeader extends StatelessWidget {
  const _GrandeurCompactHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              IconButton.filledTonal(
                key: const ValueKey('analysis-grandeur-back-button'),
                tooltip: 'Back',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _GrandeurSurface extends StatelessWidget {
  const _GrandeurSurface({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.accent,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accent?.withValues(alpha: 0.34) ?? scheme.outlineVariant,
        ),
      ),
      child: child,
    );
  }
}

class _GrandeurBoardPanel extends StatelessWidget {
  const _GrandeurBoardPanel({
    required this.selectedMove,
    required this.boardFlipped,
    required this.boardMaxSize,
    required this.compact,
    required this.showCoordinates,
    required this.onBack,
    required this.onFirstPly,
    required this.onPreviousPly,
    required this.onNextPly,
    required this.onLastPly,
    required this.autoPlaying,
    required this.autoPlayAvailable,
    required this.onToggleAutoPlay,
  });

  final ReviewMove selectedMove;
  final bool boardFlipped;
  final double boardMaxSize;
  final bool compact;
  final bool showCoordinates;
  final VoidCallback onBack;
  final VoidCallback onFirstPly;
  final VoidCallback onPreviousPly;
  final VoidCallback onNextPly;
  final VoidCallback onLastPly;
  final bool autoPlaying;
  final bool autoPlayAvailable;
  final VoidCallback onToggleAutoPlay;

  @override
  Widget build(BuildContext context) {
    final board = ResponsiveBoardFrame(
      maxSize: boardMaxSize,
      extraWidth: 0,
      padding: EdgeInsets.all(compact ? 0 : 8),
      builder: (size) => _AnalysisBoardWithEvalBar(
        size: size,
        selectedMove: selectedMove,
        flipped: boardFlipped,
        showReviewMarker: selectedMove.hasBoardMarker,
        showCoordinates: showCoordinates,
        showEvaluationBar: false,
      ),
    );
    if (compact) return board;
    return SectionColumn(
      spacing: 10,
      children: [
        board,
        _GrandeurBoardControls(
          onFirst: onFirstPly,
          onPrevious: onPreviousPly,
          onNext: onNextPly,
          onLast: onLastPly,
          autoPlaying: autoPlaying,
          autoPlayAvailable: autoPlayAvailable,
          onToggleAutoPlay: onToggleAutoPlay,
        ),
      ],
    );
  }
}

class _GrandeurSidePanel extends StatelessWidget {
  const _GrandeurSidePanel({
    required this.coachRegion,
    required this.movesRegion,
  });

  final Widget coachRegion;
  final Widget movesRegion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        coachRegion,
        const SizedBox(height: 12),
        movesRegion,
      ],
    );
  }
}

class _GrandeurCoachRegion extends StatelessWidget {
  const _GrandeurCoachRegion({
    required this.selectedMove,
    required this.coach,
    required this.analysis,
    required this.backendMove,
    required this.voiceGender,
    required this.voiceMuted,
    required this.playbackActive,
    required this.onPlaybackComplete,
    required this.onToggleMute,
    required this.status,
    required this.showGenerationProgress,
    required this.generationProgress,
    required this.compact,
  });

  final ReviewMove selectedMove;
  final GrandeurCoachProfile coach;
  final GrandeurAnalysisResult? analysis;
  final GrandeurMoveExplanation? backendMove;
  final String voiceGender;
  final bool voiceMuted;
  final bool playbackActive;
  final VoidCallback? onPlaybackComplete;
  final VoidCallback onToggleMute;
  final String? status;
  final bool showGenerationProgress;
  final double generationProgress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final coachContent = analysis == null
        ? _GrandeurGenerationHintCard(
            coach: coach,
            compact: compact,
          )
        : _GrandeurMoveNarration(
            move: selectedMove,
            coach: coach,
            reportLanguage: analysis?.language ?? '',
            backendMove: backendMove,
            hasBackendReport: true,
            voiceGender: voiceGender,
            voiceMuted: voiceMuted,
            playbackActive: playbackActive,
            onPlaybackComplete: onPlaybackComplete,
            status: status,
            onToggleMute: onToggleMute,
            compact: compact,
          );
    final content = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: coachContent),
              if (showGenerationProgress) ...[
                const SizedBox(height: 8),
                _GrandeurGenerationProgressCard(
                  progress: generationProgress,
                  status: null,
                  compact: true,
                ),
              ],
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              coachContent,
              if (showGenerationProgress) ...[
                const SizedBox(height: 12),
                _GrandeurGenerationProgressCard(
                  progress: generationProgress,
                  status: null,
                ),
              ],
            ],
          );
    return KeyedSubtree(
      key: const ValueKey('grandeur-coach-region'),
      child: content,
    );
  }
}

class _GrandeurMovesRegion extends StatelessWidget {
  const _GrandeurMovesRegion({
    required this.selectedPly,
    required this.moves,
    required this.onSelectPly,
    required this.onOpenSummary,
    required this.autoPlaying,
    required this.autoPlayAvailable,
    required this.onToggleAutoPlay,
    required this.compact,
    required this.showEngineAnalysis,
    required this.showGrandeurQuality,
  });

  final int selectedPly;
  final List<ReviewMove> moves;
  final ValueChanged<int> onSelectPly;
  final VoidCallback onOpenSummary;
  final bool autoPlaying;
  final bool autoPlayAvailable;
  final VoidCallback onToggleAutoPlay;
  final bool compact;
  final bool showEngineAnalysis;
  final bool showGrandeurQuality;

  @override
  Widget build(BuildContext context) {
    final movePanel = compact
        ? _GrandeurMoveListPanel(
            moves: moves,
            selectedPly: selectedPly,
            onSelectPly: onSelectPly,
            showEngineAnalysis: showEngineAnalysis,
            showGrandeurQuality: showGrandeurQuality,
          )
        : _AnalysisPgnPanel(
            moves: moves,
            selectedPly: selectedPly,
            onSelectPly: onSelectPly,
            // Keep the row's standalone move number ("1.", "2.") and show
            // only SAN in each side's cell, matching the standard report.
            showFullMoveLabels: false,
            showEngineAnalysis: showEngineAnalysis,
            showGrandeurQuality: showGrandeurQuality,
            showMoveNumbers: true,
            showFooter: false,
          );
    final actions = compact
        ? Row(
            key: const ValueKey('grandeur-board-controls'),
            children: [
              Expanded(
                child: PrimaryButton(
                  key: const ValueKey('analysis-grandeur-summary-button'),
                  label: 'Summary',
                  icon: Icons.auto_awesome_rounded,
                  onPressed: onOpenSummary,
                ),
              ),
              const SizedBox(width: 8),
              _GrandeurCircleAction(
                tooltip: 'Previous move',
                icon: Icons.chevron_left_rounded,
                onPressed: () {
                  final index =
                      moves.indexWhere((move) => move.ply == selectedPly);
                  if (index > 0) onSelectPly(moves[index - 1].ply);
                },
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton.filledTonal(
                  key: const ValueKey('grandeur-autoplay-button'),
                  tooltip: autoPlaying
                      ? 'Pause automatic commentary'
                      : 'Play automatic commentary',
                  onPressed: autoPlayAvailable ? onToggleAutoPlay : null,
                  isSelected: autoPlaying,
                  icon: Icon(
                    autoPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _GrandeurCircleAction(
                tooltip: 'Next move',
                icon: Icons.chevron_right_rounded,
                onPressed: () {
                  final index =
                      moves.indexWhere((move) => move.ply == selectedPly);
                  if (index >= 0 && index < moves.length - 1) {
                    onSelectPly(moves[index + 1].ply);
                  }
                },
              ),
            ],
          )
        : PrimaryButton(
            key: const ValueKey('analysis-grandeur-summary-button'),
            label: 'Summary',
            icon: Icons.auto_awesome_rounded,
            onPressed: onOpenSummary,
          );
    return KeyedSubtree(
      key: const ValueKey('grandeur-moves-region'),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: movePanel),
                const SizedBox(height: 8),
                actions,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [movePanel, const SizedBox(height: 12), actions],
            ),
    );
  }
}

class _GrandeurGenerationHintCard extends StatelessWidget {
  const _GrandeurGenerationHintCard({
    required this.coach,
    required this.compact,
  });

  final GrandeurCoachProfile coach;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      key: const ValueKey('grandeur-coach-loading-card'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GrandeurAvatar(
          key: ValueKey('coach-avatar-${coach.id}'),
          profile: coach,
          size: compact ? 88 : 74,
        ),
        SizedBox(width: compact ? 12 : 10),
        Expanded(
          child: _GrandeurSurface(
            key: const ValueKey('grandeur-generation-hint'),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 14,
              vertical: compact ? 10 : 12,
            ),
            accent: coach.color,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: coach.color,
                      size: compact ? 17 : 19,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Report in progress',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'The Grandeur coach report is still being generated. Your selected coach will stay visible here and add move-by-move commentary when it is ready.',
                  maxLines: compact ? 3 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GrandeurCircleAction extends StatelessWidget {
  const _GrandeurCircleAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 44,
        height: 44,
        child: IconButton.filledTonal(
          onPressed: onPressed,
          icon: Icon(icon, size: 26),
        ),
      ),
    );
  }
}

class _GrandeurMoveListPanel extends StatelessWidget {
  const _GrandeurMoveListPanel({
    required this.moves,
    required this.selectedPly,
    required this.onSelectPly,
    required this.showEngineAnalysis,
    required this.showGrandeurQuality,
  });

  final List<ReviewMove> moves;
  final int selectedPly;
  final ValueChanged<int> onSelectPly;
  final bool showEngineAnalysis;
  final bool showGrandeurQuality;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _GrandeurSurface(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.format_list_numbered_rounded,
                  color: scheme.primary, size: 18),
              const SizedBox(width: 7),
              Text(
                'Move list',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 7,
                children: moves
                    .map(
                      (move) => _GrandeurMoveChip(
                        move: move,
                        selected: move.ply == selectedPly,
                        onTap: () => onSelectPly(move.ply),
                        showEngineAnalysis: showEngineAnalysis,
                        showGrandeurQuality: showGrandeurQuality,
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GrandeurMoveChip extends StatelessWidget {
  const _GrandeurMoveChip({
    required this.move,
    required this.selected,
    required this.onTap,
    required this.showEngineAnalysis,
    required this.showGrandeurQuality,
  });

  final ReviewMove move;
  final bool selected;
  final VoidCallback onTap;
  final bool showEngineAnalysis;
  final bool showGrandeurQuality;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final qualityColor = showGrandeurQuality || showEngineAnalysis
        ? move.color
        : scheme.onSurface;
    final qualityTextColor = (showGrandeurQuality || showEngineAnalysis) &&
            scheme.brightness == Brightness.light &&
            ThemeData.estimateBrightnessForColor(qualityColor) ==
                Brightness.light
        ? Color.lerp(qualityColor, scheme.onSurface, 0.34)!
        : qualityColor;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        key: ValueKey('grandeur-move-chip-${move.ply}'),
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: qualityColor.withValues(alpha: selected ? 0.18 : 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: qualityColor.withValues(alpha: selected ? 0.62 : 0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: ValueKey('grandeur-move-quality-${move.ply}'),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: qualityColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              _stripDisplayMoveNumber(move.move),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: qualityTextColor,
                fontSize: 14,
                height: 1.05,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GrandeurHeaderActions extends StatelessWidget {
  const _GrandeurHeaderActions({
    required this.shareKey,
    required this.sharing,
    required this.onShare,
    required this.downloading,
    required this.downloadEnabled,
    required this.onDownload,
  });

  final Key shareKey;
  final bool sharing;
  final VoidCallback onShare;
  final bool downloading;
  final bool downloadEnabled;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ReportDownloadButton(
          key: const ValueKey('analysis-grandeur-report-download-button'),
          downloading: downloading,
          enabled: downloadEnabled,
          onPressed: onDownload,
        ),
        const SizedBox(width: 8),
        _ReportShareButton(
          key: shareKey,
          sharing: sharing,
          onPressed: onShare,
        ),
      ],
    );
  }
}

class _GrandeurAvatar extends StatelessWidget {
  const _GrandeurAvatar({
    required this.profile,
    required this.size,
    super.key,
  });

  final GrandeurCoachProfile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = size * 0.18;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: profile.color.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.asset(profile.avatarAsset, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _GrandeurStylePickerDialog extends StatelessWidget {
  const _GrandeurStylePickerDialog({
    required this.selectedStyleId,
  });

  final String selectedStyleId;

  @override
  Widget build(BuildContext context) {
    final compact = isCompactLandscapeDevice(context);
    final size = MediaQuery.sizeOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      key: const ValueKey('grandeur-style-picker'),
      alignment: Alignment.center,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: scheme.surface,
      elevation: 18,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: compact ? 760 : 430,
          maxHeight:
              (size.height - viewPadding.top - viewPadding.bottom - 48) * 0.92,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        Icon(Icons.auto_awesome_rounded, color: scheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose review style',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pick how Grandeur should explain this game before the report starts.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (final profile in grandeurReviewStyleProfiles) ...[
                _GrandeurStyleOption(
                  profile: profile,
                  selected: profile.id == selectedStyleId,
                  compact: compact,
                  onTap: () => Navigator.of(context).pop(profile),
                ),
                if (profile != grandeurReviewStyleProfiles.last)
                  const SizedBox(height: 10),
              ],
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GrandeurStyleOption extends StatelessWidget {
  const _GrandeurStyleOption({
    required this.profile,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final GrandeurCoachProfile profile;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avatarSize = compact ? 62.0 : 58.0;
    return Material(
      color: selected ? profile.color.withValues(alpha: 0.14) : scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? profile.color
                  : scheme.outlineVariant.withValues(alpha: 0.5),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  profile.avatarAsset,
                  width: avatarSize,
                  height: avatarSize,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        _TinyBadge(
                            label: profile.timeLabel, color: profile.color),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.role,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: profile.color,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile.style,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            height: 1.28,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GrandeurBoardControls extends StatelessWidget {
  const _GrandeurBoardControls({
    required this.onFirst,
    required this.onPrevious,
    required this.onNext,
    required this.onLast,
    required this.autoPlaying,
    required this.autoPlayAvailable,
    required this.onToggleAutoPlay,
  });

  final VoidCallback onFirst;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onLast;
  final bool autoPlaying;
  final bool autoPlayAvailable;
  final VoidCallback onToggleAutoPlay;

  @override
  Widget build(BuildContext context) {
    return _GrandeurSurface(
      key: const ValueKey('grandeur-board-controls'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton.filledTonal(
            tooltip: 'First move',
            onPressed: onFirst,
            icon: const Icon(Icons.first_page_rounded),
          ),
          IconButton.filledTonal(
            tooltip: 'Previous move',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton.filledTonal(
            key: const ValueKey('grandeur-autoplay-button'),
            tooltip: autoPlaying
                ? 'Pause automatic commentary'
                : 'Play automatic commentary',
            onPressed: autoPlayAvailable ? onToggleAutoPlay : null,
            isSelected: autoPlaying,
            icon: Icon(
              autoPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Next move',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          IconButton.filledTonal(
            tooltip: 'Last move',
            onPressed: onLast,
            icon: const Icon(Icons.last_page_rounded),
          ),
        ],
      ),
    );
  }
}

class _SummaryHeaderActions extends StatelessWidget {
  const _SummaryHeaderActions({
    required this.sharing,
    required this.onShare,
    required this.onClose,
  });

  final bool sharing;
  final VoidCallback onShare;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ReportShareButton(
          key: const ValueKey('analysis-grandeur-summary-share-button'),
          sharing: sharing,
          onPressed: onShare,
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          key: const ValueKey('analysis-grandeur-back-button'),
          tooltip: 'Close Grandeur',
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class _ReportDownloadButton extends StatelessWidget {
  const _ReportDownloadButton({
    required super.key,
    required this.downloading,
    required this.enabled,
    required this.onPressed,
  });

  final bool downloading;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: 'Download HTML report',
      onPressed: enabled && !downloading ? onPressed : null,
      icon: downloading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_rounded),
    );
  }
}

class _ReportShareButton extends StatelessWidget {
  const _ReportShareButton({
    required super.key,
    required this.sharing,
    required this.onPressed,
  });

  final bool sharing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: 'Share report image',
      onPressed: sharing ? null : onPressed,
      icon: sharing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.ios_share_rounded),
    );
  }
}

class _GrandeurSummaryCard extends StatefulWidget {
  const _GrandeurSummaryCard({
    required this.coach,
    required this.summaryText,
    required this.language,
    required this.voiceGender,
    required this.generating,
    required this.moveCount,
    required this.explanationCount,
    required this.voiceMuted,
    required this.onToggleMute,
    this.compact = false,
  });

  final GrandeurCoachProfile coach;
  final String summaryText;
  final String language;
  final String voiceGender;
  final bool generating;
  final int moveCount;
  final int explanationCount;
  final bool voiceMuted;
  final VoidCallback onToggleMute;
  final bool compact;

  @override
  State<_GrandeurSummaryCard> createState() => _GrandeurSummaryCardState();
}

class _GrandeurSummaryCardState extends State<_GrandeurSummaryCard> {
  static final CommentaryTtsCacheService _ttsCache =
      CommentaryTtsCacheService.shared;

  AudioPlayer? _audioPlayer;
  StreamSubscription<PlayerState>? _audioPlayerStateSubscription;
  String? _audioPath;
  int _audioRequest = 0;
  bool _playWhenReady = false;
  bool _audioPreparing = false;
  bool _audioPlaying = false;
  String? _audioError;

  String get _ttsLanguage => resolveCommentaryTtsLanguage(
        text: widget.summaryText,
        language: widget.language,
      );

  @override
  void initState() {
    super.initState();
    commentaryTtsPreparationStatuses.addListener(_handleTtsStatusChanged);
    if (!widget.generating) {
      _prepareAudio(autoPlay: !widget.voiceMuted);
    }
  }

  @override
  void didUpdateWidget(_GrandeurSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summaryText != widget.summaryText ||
        oldWidget.coach.id != widget.coach.id ||
        oldWidget.language != widget.language ||
        oldWidget.voiceGender != widget.voiceGender ||
        oldWidget.generating != widget.generating) {
      if (widget.generating) {
        _disposeAudio();
      } else {
        _resetAudio(autoPlay: !widget.voiceMuted);
      }
    }
    if (oldWidget.voiceMuted != widget.voiceMuted && !widget.generating) {
      if (widget.voiceMuted) {
        _pauseAudio();
      } else {
        _playAudio();
      }
    }
  }

  @override
  void dispose() {
    _audioRequest++;
    commentaryTtsPreparationStatuses.removeListener(_handleTtsStatusChanged);
    unawaited(_audioPlayerStateSubscription?.cancel());
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _handleTtsStatusChanged() {
    if (mounted) setState(() {});
  }

  void _disposeAudio() {
    _audioRequest++;
    final player = _audioPlayer;
    _audioPlayer = null;
    unawaited(_audioPlayerStateSubscription?.cancel());
    _audioPlayerStateSubscription = null;
    _audioPath = null;
    _audioPreparing = false;
    _audioPlaying = false;
    _audioError = null;
    player?.dispose();
  }

  void _resetAudio({required bool autoPlay}) {
    _disposeAudio();
    _prepareAudio(autoPlay: autoPlay);
  }

  Future<void> _prepareAudio({required bool autoPlay}) async {
    final text = widget.summaryText.trim();
    _playWhenReady = autoPlay;
    if (text.isEmpty || widget.generating) return;

    final request = ++_audioRequest;
    _audioPreparing = true;
    _audioError = null;
    if (mounted) setState(() {});
    AudioPlayer? pendingPlayer;
    StreamSubscription<PlayerState>? pendingPlayerStateSubscription;

    try {
      final file = await _ttsCache.getOrCreate(
        text: text,
        language: widget.language,
        coachId: widget.coach.id,
        voice: widget.voiceGender,
        style: widget.coach.id,
      );
      if (!mounted || request != _audioRequest) return;

      pendingPlayer = AudioPlayer();
      pendingPlayerStateSubscription =
          pendingPlayer.onPlayerStateChanged.listen(_handlePlayerStateChanged);
      await _configureCommentaryAudioPlayer(pendingPlayer);
      await pendingPlayer.setReleaseMode(ReleaseMode.stop);
      await pendingPlayer.setSource(DeviceFileSource(file.path));
      if (!mounted || request != _audioRequest) {
        await pendingPlayerStateSubscription.cancel();
        await pendingPlayer.dispose();
        return;
      }

      _audioPlayer = pendingPlayer;
      _audioPlayerStateSubscription = pendingPlayerStateSubscription;
      _audioPath = file.path;
      _audioPreparing = false;
      setState(() {});
      if (_playWhenReady && !widget.voiceMuted) {
        try {
          await pendingPlayer.resume();
        } catch (_) {}
      }
    } catch (_) {
      await pendingPlayerStateSubscription?.cancel();
      await pendingPlayer?.dispose();
      if (request == _audioRequest) {
        _audioPreparing = false;
        final status = commentaryTtsPreparationStatuses.value[_ttsLanguage];
        _audioError = status?.errorMessage.trim().isNotEmpty == true
            ? status!.errorMessage
            : 'Voice preparation failed. Tap retry to try again.';
        if (mounted) setState(() {});
      }
    } finally {
      if (request == _audioRequest) {
        _audioPreparing = false;
        if (mounted) setState(() {});
      }
    }
  }

  void _handlePlayerStateChanged(PlayerState state) {
    final playing = state == PlayerState.playing;
    if (!mounted || _audioPlaying == playing) return;
    setState(() => _audioPlaying = playing);
  }

  Future<void> _playAudio() async {
    _playWhenReady = true;
    final player = _audioPlayer;
    final audioPath = _audioPath;
    if (player == null || audioPath == null) {
      if (!_audioPreparing) _prepareAudio(autoPlay: true);
      return;
    }
    try {
      final position = await player.getCurrentPosition();
      if (position == null || position == Duration.zero) {
        await player.play(DeviceFileSource(audioPath));
      } else {
        await player.resume();
      }
    } catch (_) {}
  }

  Future<void> _pauseAudio() async {
    _playWhenReady = false;
    try {
      await _audioPlayer?.pause();
    } catch (_) {}
  }

  Future<void> _replayAudio() async {
    final player = _audioPlayer;
    final audioPath = _audioPath;
    if (player == null || audioPath == null) return;
    try {
      await player.stop();
      if (!widget.voiceMuted) {
        _playWhenReady = true;
        await player.play(DeviceFileSource(audioPath));
      }
    } catch (_) {}
  }

  void _retryAudio() {
    if (_audioPreparing) return;
    _audioError = null;
    _prepareAudio(autoPlay: !widget.voiceMuted);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = _GrandeurSurface(
      padding: EdgeInsets.all(widget.compact ? 14 : 14),
      accent: widget.coach.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _GrandeurAvatar(
                profile: widget.coach,
                size: widget.compact ? 86 : 62,
                key: ValueKey('coach-avatar-${widget.coach.id}'),
              ),
              SizedBox(width: widget.compact ? 18 : 12),
              Expanded(
                child: Text(
                  'Grandeur Summary',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w900,
                    fontSize: widget.compact ? 20 : 18,
                    height: 1.08,
                  ),
                ),
              ),
              if (!widget.generating) ...[
                TextButton(
                  key: const ValueKey('grandeur-summary-replay-button'),
                  onPressed: _audioPath == null ? null : _replayAudio,
                  child: const Text('Replay'),
                ),
                IconButton.filledTonal(
                  tooltip: widget.voiceMuted
                      ? 'Unmute Grandeur voice'
                      : 'Mute Grandeur voice',
                  onPressed: widget.onToggleMute,
                  icon: Icon(
                    widget.voiceMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: widget.compact ? 18 : 14),
          Expanded(
            child: SingleChildScrollView(
              child: widget.generating
                  ? _GrandeurSummaryGenerationHint(
                      compact: widget.compact,
                      accent: scheme.primary,
                    )
                  : _GrandeurSpeechText(
                      text: widget.summaryText,
                      color: widget.coach.color,
                      muted: widget.voiceMuted,
                      playing: _audioPlaying,
                      bulletMode: true,
                    ),
            ),
          ),
          if (!widget.generating &&
              (_audioPreparing || _audioError != null)) ...[
            const SizedBox(height: 8),
            _CommentaryVoicePreparationStatus(
              status: commentaryTtsPreparationStatuses.value[_ttsLanguage],
              error: _audioError,
              compact: widget.compact,
              onRetry: _audioError == null ? null : _retryAudio,
            ),
          ],
        ],
      ),
    );
    if (widget.compact) return card;
    return SizedBox(height: 360, child: card);
  }
}

class _GrandeurSummaryGenerationHint extends StatelessWidget {
  const _GrandeurSummaryGenerationHint({
    required this.compact,
    required this.accent,
  });

  final bool compact;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('grandeur-summary-generation-hint'),
      padding: EdgeInsets.all(compact ? 14 : 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 34 : 32,
            height: compact ? 34 : 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.hourglass_top_rounded,
              color: accent,
              size: compact ? 20 : 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Summary in progress',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  'The Grandeur summary is still being generated. The full-game summary will appear here when the report is ready.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.34,
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

class _GrandeurStatisticsList extends StatelessWidget {
  const _GrandeurStatisticsList({
    required this.whiteName,
    required this.blackName,
    required this.statistics,
    this.compact = false,
  });

  final String whiteName;
  final String blackName;
  final _GrandeurJsonStatistics statistics;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final panel = _GrandeurSurface(
      key: const ValueKey('grandeur-statistics-list'),
      padding: EdgeInsets.all(compact ? 10 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                compact ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              if (compact)
                Expanded(
                  child: Divider(
                    color: scheme.outlineVariant,
                  ),
                ),
              if (compact) const SizedBox(width: 10),
              Icon(Icons.layers_rounded, color: scheme.primary, size: 18),
              const SizedBox(width: 7),
              Text(
                'Statistics List',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: compact ? 18 : 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (compact) const SizedBox(width: 10),
              if (compact)
                Expanded(
                  child: Divider(
                    color: scheme.outlineVariant,
                  ),
                ),
            ],
          ),
          SizedBox(height: compact ? 8 : 12),
          _GrandeurStatsHeader(
            whiteName: whiteName,
            blackName: blackName,
            compact: compact,
          ),
          SizedBox(height: compact ? 10 : 14),
          _GrandeurStatsRow(
            label: 'Accuracy',
            white: statistics.hasWhiteAccuracy
                ? statistics.whiteAccuracyText ??
                    statistics.whiteAccuracy.toString()
                : '--',
            black: statistics.hasBlackAccuracy
                ? statistics.blackAccuracyText ??
                    statistics.blackAccuracy.toString()
                : '--',
            color: scheme.primary,
            compact: compact,
          ),
          Divider(
            height: compact ? 12 : 20,
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
          for (final key in statistics.tagKeys) ...[
            _GrandeurStatsRow(
              label: _grandeurTagDefinition(key).label,
              white: (statistics.whiteCounts[key] ?? 0).toString(),
              black: (statistics.blackCounts[key] ?? 0).toString(),
              color: _grandeurTagDefinition(key).color,
              marker: _GrandeurTagMarker(
                definition: _grandeurTagDefinition(key),
                compact: compact,
              ),
              compact: compact,
            ),
            if (key != statistics.tagKeys.last)
              SizedBox(height: compact ? 4 : 8),
          ],
        ],
      ),
    );
    if (compact) return panel;
    return panel;
  }
}

class _GrandeurTagMarker extends StatelessWidget {
  const _GrandeurTagMarker({
    required this.definition,
    this.compact = false,
  });

  final _GrandeurTagDefinition definition;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 24 : 34,
      height: compact ? 24 : 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: definition.color,
        shape: BoxShape.circle,
      ),
      child: Text(
        definition.symbol,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: compact ? 12 : 17,
          height: 1,
        ),
      ),
    );
  }
}

class _GrandeurStatsHeader extends StatelessWidget {
  const _GrandeurStatsHeader({
    required this.whiteName,
    required this.blackName,
    this.compact = false,
  });

  final String whiteName;
  final String blackName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        const SizedBox(width: 98),
        Expanded(
          child: Text(
            whiteName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: compact ? 12 : null,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 44),
        Expanded(
          child: Text(
            blackName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: compact ? 12 : null,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _GrandeurStatsRow extends StatelessWidget {
  const _GrandeurStatsRow({
    required this.label,
    required this.white,
    required this.black,
    required this.color,
    this.marker,
    this.compact = false,
  });

  final String label;
  final String white;
  final String black;
  final Color color;
  final Widget? marker;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 98,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: compact ? 12 : null,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: _GrandeurStatValue(
            textKey: ValueKey('grandeur-stat-row-$label-white-value'),
            value: white,
            color: color,
            compact: compact,
          ),
        ),
        SizedBox(
          width: 44,
          child: Center(
            child: marker ??
                Icon(
                  Icons.speed_rounded,
                  color: color,
                  size: compact ? 18 : 22,
                ),
          ),
        ),
        Expanded(
          child: _GrandeurStatValue(
            textKey: ValueKey('grandeur-stat-row-$label-black-value'),
            value: black,
            color: color,
            compact: compact,
          ),
        ),
      ],
    );
  }
}

class _GrandeurStatValue extends StatelessWidget {
  const _GrandeurStatValue({
    required this.value,
    required this.color,
    this.textKey,
    this.compact = false,
  });

  final String value;
  final Color color;
  final Key? textKey;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 25 : 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        key: textKey,
        value,
        style: TextStyle(
          color: color,
          fontSize: compact ? 14 : 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _GrandeurGenerationProgressCard extends StatelessWidget {
  const _GrandeurGenerationProgressCard({
    required this.progress,
    required this.status,
    this.compact = false,
  });

  final double progress;
  final String? status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final safeProgress = progress.clamp(0, 1).toDouble();
    final percent = (safeProgress * 100).round().clamp(0, 100);
    final statusText = status?.trim();
    final showStatus = statusText != null &&
        statusText.isNotEmpty &&
        !statusText.toLowerCase().contains('you can leave this page');
    return _GrandeurSurface(
      key: const ValueKey('grandeur-generation-progress'),
      padding: EdgeInsets.all(compact ? 10 : 14),
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: compact ? 32 : 42,
                height: compact ? 32 : 42,
                child: CircularProgressIndicator(
                  value: safeProgress <= 0 ? null : safeProgress,
                  strokeWidth: 4,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grandeur report generating',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (!compact)
                      Text(
                        'You can leave this page. Chessnut will keep working and save the report when it is ready.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _TinyBadge(label: '$percent%', color: color),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: safeProgress <= 0 ? null : safeProgress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(999),
            color: color,
            backgroundColor: color.withValues(alpha: 0.14),
          ),
          if (showStatus) ...[
            const SizedBox(height: 8),
            Text(
              statusText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.66),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GrandeurMoveNarration extends StatelessWidget {
  const _GrandeurMoveNarration({
    required this.move,
    required this.coach,
    required this.reportLanguage,
    required this.backendMove,
    required this.hasBackendReport,
    required this.voiceGender,
    required this.voiceMuted,
    required this.playbackActive,
    required this.onPlaybackComplete,
    required this.status,
    required this.onToggleMute,
    required this.compact,
  });

  final ReviewMove move;
  final GrandeurCoachProfile coach;
  final String reportLanguage;
  final GrandeurMoveExplanation? backendMove;
  final bool hasBackendReport;
  final String voiceGender;
  final bool voiceMuted;
  final bool playbackActive;
  final VoidCallback? onPlaybackComplete;
  final String? status;
  final VoidCallback onToggleMute;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final speechText = _speechText();
    final reportMove = backendMove;
    final qualityLabel =
        reportMove == null ? '' : _grandeurMoveClassification(reportMove);
    final prominent = isCompactLandscapeDevice(context);
    return Row(
      key: const ValueKey('grandeur-speech-card'),
      crossAxisAlignment:
          compact ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: _GrandeurAvatar(
            key: ValueKey('coach-avatar-${coach.id}'),
            profile: coach,
            size: prominent ? 88 : 74,
          ),
        ),
        SizedBox(width: prominent ? 12 : 10),
        Expanded(
          child: _GrandeurSpeechBubble(
            key: ValueKey(
                'grandeur-bubble-${backendMove?.ply ?? 0}-${speechText.hashCode}'),
            move: move,
            qualityLabel: qualityLabel,
            coach: coach,
            speechText: speechText,
            language: reportLanguage.trim().isNotEmpty
                ? reportLanguage
                : backendMove?.language ?? '',
            voiceGender: voiceGender,
            voiceMuted: voiceMuted,
            playbackActive: playbackActive,
            onPlaybackComplete: onPlaybackComplete,
            status: status,
            onToggleMute: onToggleMute,
            compact: compact,
          ),
        ),
      ],
    );
  }

  String _speechText() {
    // Use the new commentary field if available
    if (backendMove?.commentary.trim().isNotEmpty ?? false) {
      return backendMove!.commentary.trim();
    }
    // Fallback to legacy fields for backward compatibility
    final backendParts = [
      backendMove?.purpose.trim() ?? '',
      backendMove?.why.trim() ?? '',
      backendMove?.betterMove.trim() ?? '',
    ].where((part) => part.isNotEmpty).toList(growable: false);
    if (backendParts.isNotEmpty) return backendParts.join(' ');
    if (!hasBackendReport) return '';
    return 'No Grandeur commentary is available for this move yet.';
  }
}

class _GrandeurSpeechBubble extends StatefulWidget {
  const _GrandeurSpeechBubble({
    super.key,
    required this.move,
    required this.qualityLabel,
    required this.coach,
    required this.speechText,
    required this.language,
    required this.voiceGender,
    required this.voiceMuted,
    required this.playbackActive,
    required this.onPlaybackComplete,
    required this.status,
    required this.onToggleMute,
    required this.compact,
  });

  final ReviewMove move;
  final String qualityLabel;
  final GrandeurCoachProfile coach;
  final String speechText;
  final String language;
  final String voiceGender;
  final bool voiceMuted;
  final bool playbackActive;
  final VoidCallback? onPlaybackComplete;
  final String? status;
  final VoidCallback onToggleMute;
  final bool compact;

  @override
  State<_GrandeurSpeechBubble> createState() => _GrandeurSpeechBubbleState();
}

class _GrandeurSpeechBubbleState extends State<_GrandeurSpeechBubble> {
  static final CommentaryTtsCacheService _ttsCache =
      CommentaryTtsCacheService.shared;

  AudioPlayer? _audioPlayer;
  StreamSubscription<PlayerState>? _audioPlayerStateSubscription;
  StreamSubscription<void>? _playerCompleteSubscription;
  String? _audioPath;
  int _audioRequest = 0;
  bool _playWhenReady = false;
  bool _audioPreparing = false;
  bool _audioPlaying = false;
  String? _audioError;

  String get _ttsLanguage => resolveCommentaryTtsLanguage(
        text: widget.speechText,
        language: widget.language,
      );

  @override
  void initState() {
    super.initState();
    commentaryTtsPreparationStatuses.addListener(_handleTtsStatusChanged);
    _prepareAudio(autoPlay: !widget.voiceMuted && widget.playbackActive);
  }

  @override
  void didUpdateWidget(_GrandeurSpeechBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speechText != widget.speechText ||
        oldWidget.coach.id != widget.coach.id ||
        oldWidget.language != widget.language ||
        oldWidget.voiceGender != widget.voiceGender) {
      _resetAudio(
        autoPlay: !widget.voiceMuted && widget.playbackActive,
      );
    }
    if (oldWidget.voiceMuted != widget.voiceMuted ||
        oldWidget.playbackActive != widget.playbackActive) {
      if (widget.playbackActive && !widget.voiceMuted) {
        _playAudio();
      } else {
        _pauseAudio();
      }
    }
  }

  @override
  void dispose() {
    _audioRequest++;
    commentaryTtsPreparationStatuses.removeListener(_handleTtsStatusChanged);
    unawaited(_audioPlayerStateSubscription?.cancel());
    unawaited(_playerCompleteSubscription?.cancel());
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _handleTtsStatusChanged() {
    if (mounted) setState(() {});
  }

  void _resetAudio({required bool autoPlay}) {
    _audioRequest++;
    final player = _audioPlayer;
    unawaited(_playerCompleteSubscription?.cancel());
    _playerCompleteSubscription = null;
    _audioPlayer = null;
    unawaited(_audioPlayerStateSubscription?.cancel());
    _audioPlayerStateSubscription = null;
    _audioPath = null;
    _audioPreparing = false;
    _audioPlaying = false;
    _audioError = null;
    player?.dispose();
    _prepareAudio(autoPlay: autoPlay);
  }

  Future<void> _prepareAudio({required bool autoPlay}) async {
    final text = widget.speechText.trim();
    _playWhenReady = autoPlay;
    if (text.isEmpty) return;

    final request = ++_audioRequest;
    _audioPreparing = true;
    _audioError = null;
    if (mounted) setState(() {});
    AudioPlayer? pendingPlayer;
    StreamSubscription<PlayerState>? pendingPlayerStateSubscription;

    try {
      final file = await _ttsCache.getOrCreate(
        text: text,
        language: widget.language,
        coachId: widget.coach.id,
        voice: widget.voiceGender,
        style: widget.coach.id,
      );
      if (!mounted || request != _audioRequest) return;

      pendingPlayer = AudioPlayer();
      pendingPlayerStateSubscription =
          pendingPlayer.onPlayerStateChanged.listen(_handlePlayerStateChanged);
      await _configureCommentaryAudioPlayer(pendingPlayer);
      await pendingPlayer.setReleaseMode(ReleaseMode.stop);
      await pendingPlayer.setSource(DeviceFileSource(file.path));
      if (!mounted || request != _audioRequest) {
        await pendingPlayerStateSubscription.cancel();
        await pendingPlayer.dispose();
        pendingPlayer = null;
        pendingPlayerStateSubscription = null;
        return;
      }

      final player = pendingPlayer;
      pendingPlayer = null;
      _audioPlayer = player;
      _audioPlayerStateSubscription = pendingPlayerStateSubscription;
      pendingPlayerStateSubscription = null;
      _playerCompleteSubscription = player.onPlayerComplete.listen((_) {
        if (!mounted ||
            !_playWhenReady ||
            widget.voiceMuted ||
            !widget.playbackActive) {
          return;
        }
        widget.onPlaybackComplete?.call();
      });
      _audioPath = file.path;
      _audioPreparing = false;
      setState(() {});
      if (_playWhenReady && !widget.voiceMuted && widget.playbackActive) {
        try {
          await player.resume();
        } catch (_) {}
      }
    } catch (_) {
      await pendingPlayerStateSubscription?.cancel();
      await pendingPlayer?.dispose();
      if (request == _audioRequest) {
        _audioPreparing = false;
        final status = commentaryTtsPreparationStatuses.value[_ttsLanguage];
        _audioError = status?.errorMessage.trim().isNotEmpty == true
            ? status!.errorMessage
            : 'Voice preparation failed. Tap retry to try again.';
        if (mounted) setState(() {});
      }
    } finally {
      if (request == _audioRequest) {
        _audioPreparing = false;
        if (mounted) setState(() {});
      }
    }
  }

  void _retryAudio() {
    if (_audioPreparing) return;
    _audioError = null;
    _prepareAudio(autoPlay: !widget.voiceMuted && widget.playbackActive);
  }

  void _handlePlayerStateChanged(PlayerState state) {
    final playing = state == PlayerState.playing;
    if (!mounted || _audioPlaying == playing) return;
    setState(() => _audioPlaying = playing);
  }

  Future<void> _playAudio() async {
    _playWhenReady = true;
    final player = _audioPlayer;
    final audioPath = _audioPath;
    if (player == null || audioPath == null) {
      if (!_audioPreparing) {
        _prepareAudio(autoPlay: true);
      }
      return;
    }
    try {
      final position = await player.getCurrentPosition();
      if (position == null || position == Duration.zero) {
        await player.play(DeviceFileSource(audioPath));
        return;
      }
      await player.resume();
    } catch (_) {}
  }

  Future<void> _pauseAudio() async {
    _playWhenReady = false;
    if (_audioPlayer == null) return;
    try {
      await _audioPlayer!.pause();
    } catch (_) {}
  }

  Future<void> _replayAudio() async {
    final player = _audioPlayer;
    final audioPath = _audioPath;
    if (player == null || audioPath == null) return;
    try {
      await player.stop();
      if (!widget.voiceMuted) {
        _playWhenReady = true;
        await player.play(DeviceFileSource(audioPath));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final preparationStatus =
        commentaryTtsPreparationStatuses.value[_ttsLanguage];
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 310;
        final scheme = Theme.of(context).colorScheme;
        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: widget.compact ? 96 : 112),
          child: _GrandeurSurface(
            padding: EdgeInsets.fromLTRB(
              widget.compact ? 12 : 14,
              widget.compact ? 10 : 12,
              widget.compact ? 10 : 12,
              widget.compact ? 9 : 11,
            ),
            accent: widget.coach.color,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize:
                  widget.compact ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            widget.move.move,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: widget.compact ? 16 : 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (widget.qualityLabel.trim().isNotEmpty)
                            _TinyBadge(
                              label: widget.qualityLabel,
                              color: widget.coach.color,
                            ),
                        ],
                      ),
                    ),
                    if (!narrow)
                      TextButton(
                        onPressed: _audioPath == null ? null : _replayAudio,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          foregroundColor: scheme.primary,
                        ),
                        child: const Text('Replay'),
                      ),
                    IconButton.filledTonal(
                      tooltip: widget.voiceMuted
                          ? 'Unmute Grandeur voice'
                          : 'Mute Grandeur voice',
                      onPressed: widget.onToggleMute,
                      constraints:
                          const BoxConstraints.tightFor(width: 38, height: 38),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        widget.voiceMuted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: widget.compact ? 6 : 8),
                if (widget.compact)
                  Expanded(
                    child: SingleChildScrollView(
                      child: _GrandeurSpeechText(
                        text: widget.speechText,
                        color: widget.coach.color,
                        muted: widget.voiceMuted || !widget.playbackActive,
                        playing: _audioPlaying,
                      ),
                    ),
                  )
                else
                  _GrandeurSpeechText(
                    text: widget.speechText,
                    color: widget.coach.color,
                    muted: widget.voiceMuted || !widget.playbackActive,
                    playing: _audioPlaying,
                  ),
                if (widget.status != null) ...[
                  SizedBox(height: widget.compact ? 4 : 7),
                  Text(
                    widget.status!,
                    maxLines: widget.compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
                if (_audioPreparing ||
                    _audioError != null ||
                    preparationStatus?.state ==
                        CommentaryTtsPreparationState.downloading ||
                    preparationStatus?.state ==
                        CommentaryTtsPreparationState.installing) ...[
                  SizedBox(height: widget.compact ? 5 : 8),
                  _CommentaryVoicePreparationStatus(
                    status: preparationStatus,
                    error: _audioError,
                    compact: widget.compact,
                    onRetry: _audioError == null ? null : _retryAudio,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CommentaryVoicePreparationStatus extends StatelessWidget {
  const _CommentaryVoicePreparationStatus({
    required this.status,
    required this.error,
    required this.compact,
    required this.onRetry,
  });

  final CommentaryTtsPreparationStatus? status;
  final String? error;
  final bool compact;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = status?.progress;
    final message = error ?? _statusText(progress);
    return Row(
      key: const ValueKey('grandeur-voice-preparation-status'),
      children: [
        Icon(
          error == null
              ? Icons.downloading_rounded
              : Icons.error_outline_rounded,
          size: compact ? 16 : 18,
          color: error == null ? scheme.primary : scheme.error,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            message,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: error == null ? scheme.onSurfaceVariant : scheme.error,
                ),
          ),
        ),
        if (onRetry != null)
          TextButton(
            key: const ValueKey('grandeur-voice-retry'),
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
      ],
    );
  }

  String _statusText(double? progress) {
    if (status?.state == CommentaryTtsPreparationState.installing) {
      return 'Installing voice model...';
    }
    if (status?.state == CommentaryTtsPreparationState.downloading) {
      return progress == null
          ? 'Downloading voice model...'
          : 'Downloading voice model ${(progress * 100).round()}%';
    }
    return 'Preparing voice...';
  }
}

class _GrandeurSpeechText extends StatelessWidget {
  const _GrandeurSpeechText({
    required this.text,
    required this.color,
    this.muted = false,
    this.playing,
    this.bulletMode = false,
  });

  final String text;
  final Color color;
  final bool muted;
  final bool? playing;
  final bool bulletMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
          height: 1.34,
        );
    return _SpeechSyncedText(
      key: ValueKey('grandeur-speech-${text.hashCode}-$muted'),
      text: text,
      highlightColor: color,
      muted: muted,
      playing: playing,
      bulletMode: bulletMode,
      baseStyle: base,
      inactiveColor: scheme.onSurface,
    );
  }
}

class _SpeechSyncedText extends StatefulWidget {
  const _SpeechSyncedText({
    required this.text,
    required this.highlightColor,
    required this.muted,
    required this.playing,
    required this.bulletMode,
    required this.baseStyle,
    required this.inactiveColor,
    super.key,
  });

  final String text;
  final Color highlightColor;
  final bool muted;
  final bool? playing;
  final bool bulletMode;
  final TextStyle? baseStyle;
  final Color inactiveColor;

  @override
  State<_SpeechSyncedText> createState() => _SpeechSyncedTextState();
}

class _SpeechSyncedTextState extends State<_SpeechSyncedText>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: _durationForText(widget.text),
    );
    if (_shouldAnimate) controller.forward();
  }

  @override
  void didUpdateWidget(covariant _SpeechSyncedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      controller
        ..duration = _durationForText(widget.text)
        ..reset();
    }
    if (!_shouldAnimate) {
      controller.stop();
    } else if (!controller.isAnimating) {
      if (controller.value >= 1) {
        controller
          ..reset()
          ..forward();
      } else {
        controller.forward();
      }
    }
  }

  bool get _shouldAnimate => !widget.muted && (widget.playing ?? true);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayText =
        _displayText(widget.text, bulletMode: widget.bulletMode);
    if (displayText.trim().isEmpty) {
      return Text(
        widget.text,
        style: widget.baseStyle,
      );
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final offsets = _runeOffsets(displayText);
        final runeCount = offsets.length - 1;
        final progress = controller.value.clamp(0.0, 1.0).toDouble();
        final runeProgress = runeCount * progress;
        final highlightedRunes = runeProgress.floor().clamp(0, runeCount);
        final activeRuneProgress =
            (runeProgress - highlightedRunes).clamp(0.0, 1.0).toDouble();
        final highlightedEnd = offsets[highlightedRunes];
        final activeEnd = highlightedRunes < runeCount
            ? offsets[highlightedRunes + 1]
            : highlightedEnd;
        final spans = <InlineSpan>[];
        if (highlightedEnd > 0) {
          spans.add(
            TextSpan(
              text: displayText.substring(0, highlightedEnd),
              style: TextStyle(color: widget.highlightColor),
            ),
          );
        }
        if (activeEnd > highlightedEnd) {
          spans.add(
            TextSpan(
              text: displayText.substring(highlightedEnd, activeEnd),
              style: TextStyle(
                color: Color.lerp(
                  widget.inactiveColor,
                  widget.highlightColor,
                  activeRuneProgress,
                ),
              ),
            ),
          );
        }
        if (activeEnd < displayText.length) {
          spans.add(
            TextSpan(
              text: displayText.substring(activeEnd),
              style: TextStyle(color: widget.inactiveColor),
            ),
          );
        }
        return Text.rich(
          TextSpan(
            style: widget.baseStyle,
            children: spans,
          ),
          softWrap: true,
        );
      },
    );
  }

  Duration _durationForText(String text) {
    final characters = text.trim().runes.length;
    return Duration(milliseconds: (characters * 46).clamp(2600, 16000));
  }

  String _displayText(String text, {required bool bulletMode}) {
    if (!bulletMode) return text;
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.startsWith('- ') ? line : '- $line')
        .toList(growable: false);
    return lines.join('\n');
  }
}

List<int> _runeOffsets(String text) {
  final offsets = <int>[0];
  var codeUnitOffset = 0;
  for (final rune in text.runes) {
    codeUnitOffset += rune > 0xFFFF ? 2 : 1;
    offsets.add(codeUnitOffset);
  }
  return offsets;
}

class _PgnInputCard extends StatelessWidget {
  const _PgnInputCard({
    required this.controller,
    required this.errorText,
    this.compact = false,
    this.expandedHeight,
    this.tall = false,
  });

  final TextEditingController controller;
  final String? errorText;
  final bool compact;
  final double? expandedHeight;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final useExpandedField = expandedHeight != null;
    final panel = GlassPanel(
      padding: EdgeInsets.all(compact ? 10 : 12),
      borderRadius: 13,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                final text = data?.text?.trim();
                if (text != null && text.isNotEmpty) {
                  controller.text = text;
                }
              },
              icon: const Icon(Icons.content_paste_rounded, size: 17),
              label: const _AnalysisButtonLabel('Paste PGN'),
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          if (useExpandedField)
            Expanded(
              child: TextField(
                key: const ValueKey('analysis-pgn-input'),
                controller: controller,
                expands: true,
                minLines: null,
                maxLines: null,
                scrollPadding: EdgeInsets.zero,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText:
                      'Paste a legal PGN from Chessnut, Lichess, or Chess.com',
                  alignLabelWithHint: true,
                  errorText: errorText,
                  isDense: compact,
                ),
              ),
            )
          else
            TextField(
              key: const ValueKey('analysis-pgn-input'),
              controller: controller,
              minLines: compact
                  ? 3
                  : tall
                      ? 8
                      : 5,
              maxLines: compact
                  ? 4
                  : tall
                      ? 10
                      : 7,
              scrollPadding: const EdgeInsets.only(bottom: 16),
              decoration: InputDecoration(
                hintText:
                    'Paste a legal PGN from Chessnut, Lichess, or Chess.com',
                alignLabelWithHint: true,
                errorText: errorText,
                isDense: compact,
              ),
            ),
          SizedBox(height: compact ? 6 : 9),
          Text(
            'Chessnut will turn this PGN into a review board, move list, and analysis report.',
            maxLines: compact ? 2 : null,
            overflow: compact ? TextOverflow.ellipsis : null,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
    if (expandedHeight == null) return panel;
    return SizedBox(height: expandedHeight, child: panel);
  }
}

class _AnalysisEntryGrid extends StatelessWidget {
  const _AnalysisEntryGrid({
    required this.onNavigate,
    required this.onOpenLastGame,
    required this.onImportPgnFile,
    this.compact = false,
    this.compactLandscapeOverride = false,
  });

  final ValueChanged<String> onNavigate;
  final VoidCallback onOpenLastGame;
  final FutureOr<void> Function() onImportPgnFile;
  final bool compact;
  final bool compactLandscapeOverride;

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      minTileWidth: compact ? 164 : 120,
      maxColumns: compact ? 2 : 4,
      spacing: compact ? 8 : 10,
      childAspectRatio: compactLandscapeOverride
          ? 1.75
          : compact
              ? 2.2
              : 1.08,
      children: [
        ActionTile(
          key: const ValueKey('analysis-game-record-entry'),
          title: 'Game Record',
          subtitle: 'Saved PGNs',
          icon: Icons.history_rounded,
          compactLandscapeProminent: compact,
          compactLandscapeOverride: compactLandscapeOverride,
          onTap: () => onNavigate('Records'),
        ),
        ActionTile(
          key: const ValueKey('analysis-last-game-entry'),
          title: 'Last game',
          subtitle: 'Finished game',
          icon: Icons.flag_rounded,
          compactLandscapeProminent: compact,
          compactLandscapeOverride: compactLandscapeOverride,
          onTap: onOpenLastGame,
        ),
        if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS)
          ActionTile(
            key: const ValueKey('analysis-import-entry'),
            title: 'Import',
            subtitle: 'PGN file',
            icon: Icons.upload_file_rounded,
            compactLandscapeProminent: compact,
            compactLandscapeOverride: compactLandscapeOverride,
            onTap: onImportPgnFile,
          ),
        ActionTile(
          key: const ValueKey('analysis-live-analysis-entry'),
          title: 'Live analysis',
          subtitle: 'Board analyzer',
          icon: Icons.analytics_rounded,
          compactLandscapeProminent: compact,
          compactLandscapeOverride: compactLandscapeOverride,
          onTap: () => onNavigate('BoardAnalyzer'),
        ),
      ],
    );
  }
}

class _ParserPreview extends StatelessWidget {
  const _ParserPreview({
    required this.controller,
    this.compact = false,
  });

  final TextEditingController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final text = value.text.trim();
        final moveCount = RegExp(r'\d+\.').allMatches(text).length;
        final legalLooking = text.contains('.') && text.split(' ').length > 6;
        return GlassPanel(
          padding: EdgeInsets.all(compact ? 10 : 12),
          borderRadius: 13,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PGN check',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: compact ? 15 : null,
                    ),
              ),
              SizedBox(height: compact ? 8 : 10),
              _PreviewLine(
                icon: legalLooking
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                label: 'Format',
                value: legalLooking ? 'Looks valid' : 'Waiting',
                color: legalLooking
                    ? Theme.of(context).colorScheme.primary
                    : const Color(0xFFF59E0B),
                compact: compact,
              ),
              SizedBox(height: compact ? 6 : 8),
              _PreviewLine(
                icon: Icons.list_alt_rounded,
                label: 'Moves',
                value: moveCount == 0 ? '--' : '$moveCount turns',
                color: Theme.of(context).colorScheme.secondary,
                compact: compact,
              ),
              SizedBox(height: compact ? 6 : 8),
              _PreviewLine(
                icon: Icons.auto_awesome_rounded,
                label: 'Grandeur',
                value: 'Ready',
                color: const Color(0xFF8B5CF6),
                compact: compact,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: compact ? 30 : 34,
          height: compact ? 30 : 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: compact ? 16 : 18),
        ),
        SizedBox(width: compact ? 8 : 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: compact ? 12 : null,
          ),
        ),
      ],
    );
  }
}

class _AnalysisBoardWithEvalBar extends StatelessWidget {
  const _AnalysisBoardWithEvalBar({
    required this.size,
    required this.selectedMove,
    this.flipped = false,
    this.showReviewMarker = false,
    this.showCoordinates = false,
    this.showEvaluationBar = true,
  });

  final double size;
  final ReviewMove selectedMove;
  final bool flipped;
  final bool showReviewMarker;
  final bool showCoordinates;
  final bool showEvaluationBar;

  @override
  Widget build(BuildContext context) {
    final boardSize = size.clamp(180.0, 720.0).toDouble();
    return SizedBox(
      width: boardSize + (showEvaluationBar ? _analysisScoreBarWidth : 0),
      height: boardSize,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showEvaluationBar)
            SizedBox(
              key: const ValueKey('eval-bar'),
              width: _analysisScoreBarWidth,
              child: _EvaluationBar(move: selectedMove),
            ),
          SizedBox.square(
            dimension: boardSize,
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveChessBoard(
                    size: boardSize,
                    initialFen: selectedMove.fen,
                    lastMove: selectedMove.lastMove,
                    flipped: flipped,
                    showCoordinates: showCoordinates,
                    interactionEnabled: false,
                  ),
                ),
                if (showReviewMarker)
                  _BoardReviewMarker(
                    move: selectedMove,
                    boardSize: boardSize,
                    flipped: flipped,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EvaluationBar extends StatelessWidget {
  const _EvaluationBar({required this.move});

  final ReviewMove move;

  @override
  Widget build(BuildContext context) {
    final normalized = ((move.evalAfter + 4) / 8).clamp(0.06, 0.94);
    final scheme = Theme.of(context).colorScheme;
    const labelHeight = 58.0;
    return Tooltip(
      message: 'Evaluation bar',
      child: Semantics(
        label: 'Evaluation bar',
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            final boundaryY = height.isFinite ? height * (1 - normalized) : 0.0;
            final labelTop = height.isFinite
                ? (boundaryY - labelHeight / 2)
                    .clamp(0.0, (height - labelHeight).clamp(0.0, height))
                    .toDouble()
                : 0.0;
            return Stack(
              fit: StackFit.expand,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 14,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: const Color(0xFF101827)),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0.5,
                              end: normalized.toDouble(),
                            ),
                            duration: const Duration(milliseconds: 360),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) => Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: value,
                                widthFactor: 1,
                                child: child,
                              ),
                            ),
                            child: Container(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.92)
                                  : const Color(0xFFF8FAFC),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                  top: labelTop,
                  left: 6,
                  right: 6,
                  height: labelHeight,
                  child: SizedBox(
                    key: const ValueKey('analysis-score-label'),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.66),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: RotatedBox(
                          key: const ValueKey(
                            'analysis-score-label-vertical',
                          ),
                          quarterTurns: 3,
                          child: Text(
                            _formatEval(move.evalAfter),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: scheme.primary,
                              fontSize: 10,
                              height: 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BoardReviewMarker extends StatelessWidget {
  const _BoardReviewMarker({
    required this.move,
    required this.boardSize,
    required this.flipped,
  });

  final ReviewMove move;
  final double boardSize;
  final bool flipped;

  @override
  Widget build(BuildContext context) {
    final square = move.focusSquare;
    final marker = move.marker;
    final boardFile = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.tryParse(square.substring(1)) ?? 1;
    final file = flipped ? 7 - boardFile : boardFile;
    final rankFromTop = flipped ? rank - 1 : 8 - rank;
    final squareSize = boardSize / 8;
    final badgeSize = (squareSize * 0.34).clamp(18.0, 26.0).toDouble();
    return Positioned(
      key: ValueKey('review-board-marker-${move.classification}'),
      left: (file * squareSize).clamp(0, boardSize - squareSize),
      top: (rankFromTop * squareSize).clamp(0, boardSize - squareSize),
      width: squareSize,
      height: squareSize,
      child: IgnorePointer(
        child: Container(
          alignment: Alignment.topRight,
          decoration: BoxDecoration(
            color: marker.color.withValues(alpha: 0.10),
            border: Border.all(
              color: marker.color.withValues(alpha: 0.70),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2.5),
            child: _ReviewQualityMarker(
              key: ValueKey('review-board-marker-badge-${move.classification}'),
              spec: marker,
              size: badgeSize,
              elevated: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewQualityMarker extends StatelessWidget {
  const _ReviewQualityMarker({
    required this.spec,
    this.size = 26,
    this.elevated = false,
    super.key,
  });

  final ReviewMarkerSpec spec;
  final double size;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final textSize = spec.symbol.length > 1 ? size * 0.34 : size * 0.52;
    return Semantics(
      label: spec.label,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: spec.color,
          border: Border.all(
            color: spec.borderColor ?? Colors.white.withValues(alpha: 0.78),
            width: elevated ? 2 : 1.4,
          ),
          boxShadow: [
            if (elevated)
              BoxShadow(
                color: spec.color.withValues(alpha: 0.42),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Text(
          spec.symbol,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: textSize,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _StandardEngineCard extends StatelessWidget {
  const _StandardEngineCard({
    required this.selectedMove,
  });

  final ReviewMove selectedMove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = [scheme.primary, scheme.secondary, const Color(0xFF64748B)];
    final candidates = [
      for (var i = 0; i < selectedMove.candidateVariations.length && i < 3; i++)
        _EngineCandidate(
          rank: '${i + 1}',
          line: selectedMove.candidateVariations[i].line,
          score: _formatEngineVariationScore(
            selectedMove.candidateVariations[i],
          ),
          color: colors[i],
        ),
    ];
    if (candidates.isEmpty) return const SizedBox.shrink();
    return GlassPanel(
      padding: const EdgeInsets.all(10),
      tint: scheme.primary.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.travel_explore_rounded,
                  color: scheme.primary, size: 19),
              const SizedBox(width: 7),
              Text(
                'Best moves',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              _TinyBadge(
                label: _formatEngineVariationScore(
                  selectedMove.candidateVariations.first,
                ),
                color: scheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < candidates.length; i++) ...[
            if (i > 0) const SizedBox(height: 4),
            _EngineCandidateLine(
              key: ValueKey('analysis-candidate-line-${candidates[i].rank}'),
              candidate: candidates[i],
            ),
          ],
        ],
      ),
    );
  }
}

class _StandardAnalysisControls extends StatelessWidget {
  const _StandardAnalysisControls({
    required this.depth,
    required this.onDepthChanged,
    required this.onRegenerate,
  });

  final int depth;
  final ValueChanged<int> onDepthChanged;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final depthSelector = PopupMenuButton<int>(
      key: const ValueKey('standard-analysis-depth-menu'),
      initialValue: depth,
      tooltip: 'Analysis depth',
      onSelected: onDepthChanged,
      itemBuilder: (context) => [
        for (var value = 6; value <= 20; value++)
          PopupMenuItem<int>(
            value: value,
            child: Text('$value'),
          ),
      ],
      child: Container(
        width: 72,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$depth',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const Icon(Icons.arrow_drop_down_rounded, size: 18),
          ],
        ),
      ),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        depthSelector,
        const SizedBox(width: 8),
        IconButton.filledTonal(
          key: const ValueKey('standard-analysis-regenerate-button'),
          tooltip: 'Regenerate report',
          onPressed: onRegenerate,
          icon: const Icon(Icons.restart_alt_rounded),
        ),
      ],
    );
    return GlassPanel(
      key: const ValueKey('standard-analysis-controls'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: 8,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final label = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.layers_rounded, color: scheme.primary, size: 19),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Analysis depth',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          );
          if (constraints.maxWidth < 280) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label,
                const SizedBox(height: 8),
                Align(
                    alignment: AlignmentDirectional.centerEnd, child: actions),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: label),
              const SizedBox(width: 8),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _StockfishCompactStatus extends StatelessWidget {
  const _StockfishCompactStatus({
    required this.loading,
    required this.engineBacked,
    required this.complete,
    required this.status,
    required this.progress,
    required this.completedPositions,
    required this.totalPositions,
    required this.selectedMove,
  });

  final bool loading;
  final bool engineBacked;
  final bool complete;
  final String? status;
  final double progress;
  final int completedPositions;
  final int totalPositions;
  final ReviewMove selectedMove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = complete ? scheme.primary : const Color(0xFFF59E0B);
    final percent = (progress * 100).round().clamp(0, 100);
    return GlassPanel(
      key: const ValueKey('stockfish-compact-status'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      borderRadius: 13,
      tint: color.withValues(alpha: 0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                loading
                    ? Icons.sync_rounded
                    : complete
                        ? Icons.verified_rounded
                        : Icons.memory_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              _TinyBadge(label: 'Stockfish 18', color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  message: status ?? 'Local analysis status',
                  child: Text(
                    complete
                        ? 'Report ready'
                        : loading
                            ? 'Pre-analyzing report'
                            : engineBacked
                                ? 'Partial report'
                                : 'Local estimate',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                loading
                    ? '$percent%'
                    : selectedMove.engineDepth == null
                        ? _formatEval(selectedMove.evalAfter)
                        : 'd${selectedMove.engineDepth}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (loading) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress <= 0 ? null : progress,
              minHeight: 4,
              borderRadius: BorderRadius.circular(999),
              color: color,
              backgroundColor: color.withValues(alpha: 0.14),
            ),
            if (totalPositions > 0) ...[
              const SizedBox(height: 4),
              Text(
                '$completedPositions / $totalPositions positions',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _StockfishReportLoadingCard extends StatelessWidget {
  const _StockfishReportLoadingCard({
    required this.progress,
    required this.completedPositions,
    required this.totalPositions,
  });

  final double progress;
  final int completedPositions;
  final int totalPositions;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final percent = (progress * 100).round().clamp(0, 100);
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: 14,
      tint: color.withValues(alpha: 0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(
                  value: progress <= 0 ? null : progress,
                  strokeWidth: 4,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stockfish analysis in progress',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalPositions > 0
                          ? '$completedPositions / $totalPositions PGN positions evaluated.'
                          : 'Preparing PGN positions for evaluation.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _TinyBadge(label: '$percent%', color: color),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            key: const ValueKey('stockfish-report-progress-bar'),
            value: progress <= 0 ? null : progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(999),
            color: color,
            backgroundColor: color.withValues(alpha: 0.14),
          ),
        ],
      ),
    );
  }
}

class _EngineCandidate {
  const _EngineCandidate({
    required this.rank,
    required this.line,
    required this.score,
    required this.color,
  });

  final String rank;
  final String line;
  final String score;
  final Color color;
}

class _EngineCandidateLine extends StatelessWidget {
  const _EngineCandidateLine({
    required this.candidate,
    super.key,
  });

  final _EngineCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final color = candidate.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: color.withValues(alpha: 0.055),
        border: Border.all(color: color.withValues(alpha: 0.13)),
      ),
      child: Row(
        children: [
          Text(
            candidate.rank,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              candidate.line,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            candidate.score,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class ReviewMove {
  const ReviewMove({
    required this.ply,
    required this.move,
    required this.evalBefore,
    required this.evalAfter,
    required this.classification,
    required this.summary,
    required this.color,
    this.fen = standardStartFen,
    this.lastMove = const [],
    this.focusSquare = 'e4',
    this.engineLine = 'Nf3 d6 d4 cxd4 Nxd4',
    this.bestMove = 'Best: Nf3',
    this.keyMoment = false,
    this.engineDepth,
    this.scoreMapAccuracy,
    this.scoreMapLevel,
    this.isEngineBacked = false,
    this.candidateVariations = const [],
  });

  final int ply;
  final String move;
  final double evalBefore;
  final double evalAfter;
  final String classification;
  final String summary;
  final Color color;
  final String fen;
  final List<String> lastMove;
  final String focusSquare;
  final String engineLine;
  final String bestMove;
  final bool keyMoment;
  final int? engineDepth;
  final double? scoreMapAccuracy;
  final int? scoreMapLevel;
  final bool isEngineBacked;
  final List<EngineVariationInsight> candidateVariations;

  bool get isWhiteMove {
    final fields = fen.trim().split(RegExp(r'\s+'));
    if (fields.length > 1) return fields[1] == 'b';
    return ply.isOdd;
  }

  int get moveNumber {
    final fields = fen.trim().split(RegExp(r'\s+'));
    final afterMoveNumber = fields.length > 5 ? int.tryParse(fields[5]) : null;
    if (afterMoveNumber == null || afterMoveNumber < 1) {
      return (ply + 1) ~/ 2;
    }
    return isWhiteMove ? afterMoveNumber : afterMoveNumber - 1;
  }

  String get evalDeltaLabel =>
      '${_formatEval(evalBefore)} -> ${_formatEval(evalAfter)}';

  ReviewMarkerSpec get marker => ReviewMarkerSpec.fromClassification(
        classification,
        fallbackColor: color,
      );

  bool get isSeriousMistake =>
      move.contains('?') ||
      classification == 'Mistake' ||
      classification == 'Blunder' ||
      classification == 'Missed win' ||
      classification == 'Critical swing';

  bool get hasBoardMarker =>
      classification != 'Not analyzed' &&
      classification != 'Book' &&
      classification != 'Good';

  bool get isScoreMapBacked =>
      scoreMapAccuracy != null && scoreMapLevel != null;

  ReviewMove copyWith({
    double? evalBefore,
    double? evalAfter,
    String? classification,
    String? summary,
    Color? color,
    String? engineLine,
    String? bestMove,
    bool? keyMoment,
    int? engineDepth,
    double? scoreMapAccuracy,
    int? scoreMapLevel,
    bool? isEngineBacked,
    List<EngineVariationInsight>? candidateVariations,
  }) {
    return ReviewMove(
      ply: ply,
      move: move,
      evalBefore: evalBefore ?? this.evalBefore,
      evalAfter: evalAfter ?? this.evalAfter,
      classification: classification ?? this.classification,
      summary: summary ?? this.summary,
      color: color ?? this.color,
      fen: fen,
      lastMove: lastMove,
      focusSquare: focusSquare,
      engineLine: engineLine ?? this.engineLine,
      bestMove: bestMove ?? this.bestMove,
      keyMoment: keyMoment ?? this.keyMoment,
      engineDepth: engineDepth ?? this.engineDepth,
      scoreMapAccuracy: scoreMapAccuracy ?? this.scoreMapAccuracy,
      scoreMapLevel: scoreMapLevel ?? this.scoreMapLevel,
      isEngineBacked: isEngineBacked ?? this.isEngineBacked,
      candidateVariations: candidateVariations ?? this.candidateVariations,
    );
  }
}

class ReviewMarkerSpec {
  const ReviewMarkerSpec({
    required this.symbol,
    required this.color,
    required this.label,
    this.borderColor,
  });

  final String symbol;
  final Color color;
  final Color? borderColor;
  final String label;

  factory ReviewMarkerSpec.fromClassification(
    String classification, {
    required Color fallbackColor,
  }) {
    switch (classification) {
      case 'Brilliant':
      case 'Best':
        return const ReviewMarkerSpec(
          symbol: '!!',
          color: Color(0xFFA3E635),
          label: 'Best move marker',
        );
      case 'Great':
        return const ReviewMarkerSpec(
          symbol: '!',
          color: Color(0xFF22D3EE),
          label: 'Great move marker',
        );
      case 'Inaccuracy':
        return const ReviewMarkerSpec(
          symbol: '?!',
          color: Color(0xFFEAC84A),
          label: 'Inaccuracy marker',
        );
      case 'Mistake':
      case 'Critical swing':
        return const ReviewMarkerSpec(
          symbol: '?',
          color: Color(0xFFF0A252),
          label: 'Mistake marker',
        );
      case 'Missed win':
        return const ReviewMarkerSpec(
          symbol: '??',
          color: Color(0xFFE2574C),
          label: 'Missed win marker',
        );
      case 'Blunder':
        return const ReviewMarkerSpec(
          symbol: '??',
          color: Color(0xFFE2574C),
          label: 'Blunder marker',
        );
      default:
        return ReviewMarkerSpec(
          symbol: classification == 'Good' ? '!' : '·',
          color: fallbackColor,
          label: '$classification marker',
        );
    }
  }
}

List<ReviewMove> buildReviewMovesFromPgn(String pgn) {
  if (pgn.trim() == _sampleReviewPgn.trim()) {
    return reviewMoves;
  }
  return buildReviewMovesFromParsedGame(GameNotationService.parsePgn(pgn));
}

List<ReviewMove> buildReviewMovesFromParsedGame(ParsedPgnGame game) {
  final moves = <ReviewMove>[];
  for (final move in game.moves) {
    final reviewMove = _reviewMoveFromParsed(move);
    moves.add(reviewMove);
  }
  return List<ReviewMove>.unmodifiable(moves);
}

List<ReviewMove> applyEngineInsightsToReviewMoves(
  List<ReviewMove> moves,
  List<MoveEngineInsight> insights,
) {
  final insightByPly = {for (final insight in insights) insight.ply: insight};
  return List<ReviewMove>.unmodifiable([
    for (final move in moves)
      if (insightByPly[move.ply] case final insight?)
        move.copyWith(
          evalBefore: insight.evalBefore,
          evalAfter: insight.evalAfter,
          classification: insight.classification,
          summary: _summaryForClassification(insight.classification, move.move),
          color: _classificationColor(insight.classification),
          engineLine:
              insight.engineLine.isEmpty ? 'PV pending' : insight.engineLine,
          bestMove: insight.bestMoveUci == null
              ? 'Best line pending'
              : 'Best: ${insight.bestMoveSan ?? insight.bestMoveUci}',
          keyMoment: _isKeyMoment(
            insight.classification,
            insight.evalBefore,
            insight.evalAfter,
          ),
          engineDepth: insight.depth,
          scoreMapAccuracy: insight.scoreMap?.accuracyPercent,
          scoreMapLevel: insight.scoreMap?.legacyLevel,
          isEngineBacked: insight.isEngineBacked,
          candidateVariations: insight.candidateVariations,
        )
      else
        move,
  ]);
}

ReviewMove _reviewMoveFromParsed(ParsedPgnMove move) {
  const evalBefore = 0.0;
  const evalAfter = 0.0;
  const classification = 'Not analyzed';
  final color = _classificationColor(classification);
  final displayMove =
      _displayMoveForFenAfter(move.fenAfter, move.san, fallbackPly: move.ply);
  final focusSquare =
      move.lastMove.isEmpty ? 'e4' : move.lastMove.last.clampSquareName();
  return ReviewMove(
    ply: move.ply,
    move: displayMove,
    evalBefore: evalBefore,
    evalAfter: evalAfter,
    classification: classification,
    summary: _summaryForClassification(classification, move.san),
    color: color,
    fen: move.fenAfter,
    lastMove: move.lastMove,
    focusSquare: focusSquare,
    engineLine: 'Stockfish analysis pending',
    bestMove: 'Best line pending',
    keyMoment: false,
  );
}

String _displayMoveForFenAfter(
  String fen,
  String san, {
  required int fallbackPly,
}) {
  final fields = fen.trim().split(RegExp(r'\s+'));
  final whiteMoved = fields.length > 1 ? fields[1] == 'b' : fallbackPly.isOdd;
  final afterMoveNumber = fields.length > 5 ? int.tryParse(fields[5]) : null;
  final moveNumber = afterMoveNumber == null || afterMoveNumber < 1
      ? (fallbackPly + 1) ~/ 2
      : whiteMoved
          ? afterMoveNumber
          : afterMoveNumber - 1;
  return whiteMoved ? '$moveNumber. $san' : '$moveNumber... $san';
}

String _stripDisplayMoveNumber(String move) {
  return move
      .replaceFirst(RegExp(r'^\d+\.\.\.\s*'), '')
      .replaceFirst(RegExp(r'^\d+\.\s*'), '');
}

String _grandeurMoveClassification(GrandeurMoveExplanation move) {
  final classification = move.classification.trim();
  if (classification.isNotEmpty) {
    return _grandeurStatsBucket(classification) ?? classification;
  }
  final tag = move.tag.trim();
  return _grandeurClassificationForTag(tag) ??
      _grandeurStatsBucket(tag) ??
      (tag.isNotEmpty ? tag : 'Unclassified');
}

String? _grandeurClassificationForTag(String tag) {
  return switch (tag.trim().toLowerCase()) {
    'a' => 'Brilliant',
    'b' => 'Great',
    'c' => 'Best',
    'd' => 'Accurate',
    'e' => 'Normal',
    'f' => 'Inaccuracy',
    'g' => 'Mistake',
    'h' => 'Blunder',
    _ => null,
  };
}

Color _grandeurMoveQualityColor(GrandeurMoveExplanation move) {
  final tagged = _grandeurClassificationForTag(move.tag);
  return _classificationColor(tagged ?? _grandeurMoveClassification(move));
}

bool _isGrandeurKeyMoment(GrandeurMoveExplanation move) {
  return const {'a', 'b', 'f', 'g', 'h'}
      .contains(move.tag.trim().toLowerCase());
}

Color _classificationColor(String classification) {
  switch (classification) {
    case 'Brilliant':
      return const Color(0xFF34D399);
    case 'Great':
      return const Color(0xFF22D3EE);
    case 'Best':
      return const Color(0xFFA3E635);
    case 'Excellent':
      return const Color(0xFF84CC16);
    case 'Good':
      return const Color(0xFF2DD4BF);
    case 'Accurate':
      return const Color(0xFF2DD4BF);
    case 'Normal':
      return const Color(0xFF64748B);
    case 'Inaccuracy':
      return const Color(0xFFEAC84A);
    case 'Mistake':
      return const Color(0xFFF0A252);
    case 'Missed win':
      return const Color(0xFFFB923C);
    case 'Blunder':
      return const Color(0xFFE2574C);
    case 'Book':
      return const Color(0xFFA855F7);
    default:
      return const Color(0xFF64748B);
  }
}

String _summaryForClassification(String classification, String san) {
  switch (classification) {
    case 'Book':
      return '$san is still inside the opening book for this lightweight review.';
    case 'Brilliant':
      return '$san creates a tactical or strategic turning point worth reviewing.';
    case 'Great':
      return '$san improves piece activity while keeping the plan clear.';
    case 'Best':
      return '$san matches the strongest candidate in this review pass.';
    case 'Inaccuracy':
      return '$san is playable, but there may be a cleaner plan.';
    case 'Mistake':
      return '$san changes the evaluation enough to deserve a closer look.';
    case 'Missed win':
      return '$san lets a winning chance slip away; compare it with the engine line.';
    case 'Blunder':
      return '$san likely drops material or allows a forcing tactic.';
    default:
      return '$san keeps the game flowing without a major evaluation swing.';
  }
}

bool _isKeyMoment(String classification, double before, double after) {
  return classification == 'Brilliant' ||
      classification == 'Mistake' ||
      classification == 'Missed win' ||
      classification == 'Blunder' ||
      (after - before).abs() >= 0.7;
}

List<ReviewMove> _timelineMoves(
  List<ReviewMove> moves, {
  required bool compactReview,
}) {
  final selected = compactReview
      ? moves.where((move) => move.keyMoment).toList(growable: false)
      : moves;
  final source = selected.isEmpty ? moves : selected;
  final byPly = <int, ReviewMove>{};
  for (final move in source) {
    byPly[move.ply] = move;
  }
  final deduped = byPly.values.toList(growable: false)
    ..sort((a, b) => a.ply.compareTo(b.ply));
  return List<ReviewMove>.unmodifiable(deduped);
}

extension _SquareNameClamp on String {
  String clampSquareName() {
    if (length == 2 &&
        codeUnitAt(0) >= 'a'.codeUnitAt(0) &&
        codeUnitAt(0) <= 'h'.codeUnitAt(0) &&
        codeUnitAt(1) >= '1'.codeUnitAt(0) &&
        codeUnitAt(1) <= '8'.codeUnitAt(0)) {
      return this;
    }
    return 'e4';
  }
}

const reviewMoves = [
  ReviewMove(
    ply: 1,
    move: '1. e4',
    evalBefore: 0.2,
    evalAfter: 0.3,
    classification: 'Book',
    summary: 'Claims central space and opens the bishop.',
    color: Color(0xFF64748B),
    fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
    lastMove: ['e2', 'e4'],
    focusSquare: 'e4',
    engineLine: 'e4 c5 Nf3 d6 d4',
    bestMove: 'Best: e4',
    candidateVariations: [
      EngineVariationInsight(
        moveUci: 'e2e4',
        line: 'e4 c5 Nf3 d6 d4',
        whiteEval: 0.3,
      ),
    ],
  ),
  ReviewMove(
    ply: 2,
    move: '1... c5',
    evalBefore: 0.3,
    evalAfter: 0.2,
    classification: 'Book',
    summary: 'Creates an imbalanced Sicilian structure.',
    color: Color(0xFF64748B),
    fen: 'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 2',
    lastMove: ['c7', 'c5'],
    focusSquare: 'c5',
    engineLine: 'c5 Nf3 d6 d4 cxd4',
    bestMove: 'Book: c5',
    candidateVariations: [
      EngineVariationInsight(
        moveUci: 'c7c5',
        line: 'c5 Nf3 d6 d4 cxd4',
        whiteEval: 0.2,
      ),
    ],
  ),
  ReviewMove(
    ply: 3,
    move: '2. Nf3',
    evalBefore: 0.2,
    evalAfter: 0.4,
    classification: 'Great',
    summary: 'Develops while keeping d4 available.',
    color: Color(0xFF8EA9CE),
    fen: 'rnbqkbnr/pp1ppppp/8/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2',
    lastMove: ['g1', 'f3'],
    focusSquare: 'f3',
    engineLine: 'Nf3 d6 d4 cxd4 Nxd4',
    bestMove: 'Best: Nf3',
    candidateVariations: [
      EngineVariationInsight(
        moveUci: 'g1f3',
        line: 'Nf3 d6 d4 cxd4 Nxd4',
        whiteEval: 0.4,
      ),
    ],
  ),
  ReviewMove(
    ply: 4,
    move: '10. Qh5',
    evalBefore: 0.4,
    evalAfter: 0.7,
    classification: 'Inaccuracy',
    summary: 'Creates pressure, but castling first was cleaner.',
    color: Color(0xFFEAC84A),
    fen: 'r1bqkbnr/pp2pppp/2np4/2p4Q/4P3/5N2/PPPP1PPP/RNB1KB1R b KQkq - 4 5',
    lastMove: ['d1', 'h5'],
    focusSquare: 'h5',
    engineLine: 'Qh5 g6 Qh4 Bg7 O-O',
    bestMove: 'Cleaner: O-O',
    candidateVariations: [
      EngineVariationInsight(
        moveUci: 'd1h5',
        line: 'Qh5 g6 Qh4 Bg7 O-O',
        whiteEval: 0.7,
      ),
    ],
  ),
  ReviewMove(
    ply: 8,
    move: '12. Nxf7!',
    evalBefore: 0.6,
    evalAfter: 2.4,
    classification: 'Brilliant',
    summary:
        'The tactical point is that the rook cannot move without mate threats.',
    color: Color(0xFF38BDF8),
    fen: 'r1bqkb1r/pp2pNpp/2np1n2/2p4Q/4P3/8/PPPP1PPP/RNB1KB1R b KQkq - 0 6',
    lastMove: ['g5', 'f7'],
    focusSquare: 'f7',
    engineLine: 'Nxf7 Qe7 Nxh8 Qxe4+ Be2',
    bestMove: 'Tactic: Nxf7',
    candidateVariations: [
      EngineVariationInsight(
        moveUci: 'g5f7',
        line: 'Nxf7 Qe7 Nxh8 Qxe4+ Be2',
        whiteEval: 2.4,
      ),
    ],
    keyMoment: true,
  ),
  ReviewMove(
    ply: 12,
    move: '18... Qc7?',
    evalBefore: 1.7,
    evalAfter: -0.4,
    classification: 'Mistake',
    summary: 'Black misses ...Qe7, allowing the attack to flip the game.',
    color: Color(0xFFF0A252),
    fen: 'r1b1kb1r/ppq1pNpp/2np1n2/2p4Q/4P3/8/PPPP1PPP/RNB1KB1R w KQkq - 1 7',
    lastMove: ['d8', 'c7'],
    focusSquare: 'c7',
    engineLine: 'Qc7 Bc4 e6 Nxh8 Nxh5',
    bestMove: 'Better: ...Qe7',
    candidateVariations: [
      EngineVariationInsight(
        moveUci: 'd8c7',
        line: 'Qc7 Bc4 e6 Nxh8 Nxh5',
        whiteEval: -0.4,
      ),
    ],
    keyMoment: true,
  ),
  ReviewMove(
    ply: 16,
    move: '24. Re1',
    evalBefore: 1.1,
    evalAfter: 1.8,
    classification: 'Best',
    summary: 'Consolidates activity before converting into a winning endgame.',
    color: Color(0xFF14B8A6),
    fen: 'r1b1kb1r/ppq1p1pp/2np1n2/2p4Q/4P3/8/PPPPBPPP/RNB1R1K1 b kq - 3 9',
    lastMove: ['f1', 'e1'],
    focusSquare: 'e1',
    engineLine: 'Re1 e6 Bc4 Be7 d3',
    bestMove: 'Best: Re1',
    candidateVariations: [
      EngineVariationInsight(
        moveUci: 'f1e1',
        line: 'Re1 e6 Bc4 Be7 d3',
        whiteEval: 1.8,
      ),
    ],
    keyMoment: true,
  ),
];

const _sampleReviewPgn = '''
[Event "Chessnut Review"]
[Site "Chessnut App"]
[White "Chessnut Player"]
[Black "Opponent"]
[Result "*"]

1. e4 c5 2. Nf3 *
''';

String _formatEval(double value) {
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(1)}';
}

String _formatEngineVariationScore(EngineVariationInsight variation) {
  final mate = variation.whiteMate;
  if (mate == null) return _formatEval(variation.whiteEval);
  return mate > 0 ? '#${mate.abs()}' : '-#${mate.abs()}';
}

class _EvaluationCard extends StatelessWidget {
  const _EvaluationCard({
    required this.moves,
    required this.selectedPly,
    required this.onSelectPly,
    this.compactReview = false,
  });

  final List<ReviewMove> moves;
  final int selectedPly;
  final ValueChanged<int> onSelectPly;
  final bool compactReview;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;
    final chartMoves = _timelineMoves(
      moves,
      compactReview: compactReview,
    );
    final selected = moves.firstWhere(
      (move) => move.ply == selectedPly,
      orElse: () => moves.first,
    );
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Evaluation timeline',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              _TinyBadge(label: 'Score trend', color: primary),
            ],
          ),
          const SizedBox(height: 3),
          Text('PGN score map', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          SizedBox(
            height: 158,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final chartSize =
                    Size(constraints.maxWidth, constraints.maxHeight);
                return Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _EvalTrendPainter(
                        moves: chartMoves,
                        selectedPly: selectedPly,
                        lineColor: primary,
                        fillColor: secondary.withValues(alpha: 0.14),
                        gridColor: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.24),
                      ),
                    ),
                    for (final move in chartMoves)
                      _EvalPointButton(
                        moves: chartMoves,
                        move: move,
                        selected: move.ply == selectedPly,
                        chartSize: chartSize,
                        onTap: () => onSelectPly(move.ply),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          compactReview
              ? _CriticalPointCard(move: selected)
              : _SelectedMoveCard(move: selected),
        ],
      ),
    );
  }
}

class _EvalTrendPainter extends CustomPainter {
  const _EvalTrendPainter({
    required this.moves,
    required this.selectedPly,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
  });

  final List<ReviewMove> moves;
  final int selectedPly;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final y in [0.25, 0.5, 0.75]) {
      final dy = size.height * y;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    final path = Path();
    for (var i = 0; i < moves.length; i++) {
      final point = _pointForMove(moves[i], size);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  Offset _pointForMove(ReviewMove move, Size size) {
    final minPly = moves.first.ply.toDouble();
    final maxPly = moves.last.ply.toDouble();
    final span = (maxPly - minPly).clamp(1.0, double.infinity);
    final x = size.width * (move.ply - minPly) / span;
    final normalized = ((move.evalAfter + 3) / 6).clamp(0.0, 1.0);
    final y = size.height * (1 - normalized);
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant _EvalTrendPainter oldDelegate) {
    return selectedPly != oldDelegate.selectedPly ||
        moves != oldDelegate.moves ||
        lineColor != oldDelegate.lineColor ||
        fillColor != oldDelegate.fillColor ||
        gridColor != oldDelegate.gridColor;
  }
}

class _EvalPointButton extends StatelessWidget {
  const _EvalPointButton({
    required this.moves,
    required this.move,
    required this.selected,
    required this.chartSize,
    required this.onTap,
  });

  final List<ReviewMove> moves;
  final ReviewMove move;
  final bool selected;
  final Size chartSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final minPly = moves.first.ply.toDouble();
    final maxPly = moves.last.ply.toDouble();
    final span = (maxPly - minPly).clamp(1.0, double.infinity);
    final x = chartSize.width * (move.ply - minPly) / span;
    final normalized = ((move.evalAfter + 3) / 6).clamp(0.0, 1.0);
    final y = chartSize.height * (1 - normalized);
    return Positioned(
      left: x - 22,
      top: y - 22,
      child: Tooltip(
        message: move.move,
        child: InkWell(
          key: ValueKey('eval-point-${move.ply}'),
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: selected ? 30 : (move.keyMoment ? 25 : 19),
                height: selected ? 30 : (move.keyMoment ? 25 : 19),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: move.color.withValues(alpha: 0.16),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: selected ? 18 : (move.keyMoment ? 13 : 9),
                  height: selected ? 18 : (move.keyMoment ? 13 : 9),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: move.color,
                    border: Border.all(
                      color: selected ? Colors.white : move.color,
                      width: selected ? 2 : 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedMoveCard extends StatelessWidget {
  const _SelectedMoveCard({required this.move});

  final ReviewMove move;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(10),
      borderRadius: 12,
      tint: move.color.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Selected move',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _TinyBadge(
                    label: move.classification,
                    color: move.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(move.move, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            move.evalDeltaLabel,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Engine impact',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(move.summary, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _CriticalPointCard extends StatelessWidget {
  const _CriticalPointCard({required this.move});

  final ReviewMove move;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(10),
      borderRadius: 12,
      tint: move.color.withValues(alpha: 0.08),
      child: Row(
        children: [
          _ReviewQualityMarker(spec: move.marker, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Critical point',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  move.move,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  move.evalDeltaLabel,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _TinyBadge(label: move.classification, color: move.color),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class GrandeurCoachProfile {
  const GrandeurCoachProfile({
    required this.id,
    required this.name,
    required this.role,
    required this.timeLabel,
    required this.style,
    required this.avatarAsset,
    required this.color,
  });

  final String id;
  final String name;
  final String role;
  final String timeLabel;
  final String style;
  final String avatarAsset;
  final Color color;
}

const defaultGrandeurReviewStyle = GrandeurCoachProfile(
  id: 'deep',
  name: 'Deep analyst',
  role: 'Calm, careful, detailed',
  timeLabel: 'About 2 min',
  style:
      'A full-game study with patient explanations, turning points, plans, missed chances, move quality, and concrete training takeaways. Best when you want the richest report and can wait longer.',
  avatarAsset: 'assets/avatars/avatar-30.png',
  color: Color(0xFF8B6DFF),
);

const grandeurReviewStyleProfiles = [
  defaultGrandeurReviewStyle,
  GrandeurCoachProfile(
    id: 'rapid',
    name: 'Rapid coach',
    role: 'Faster, focused review',
    timeLabel: 'About 30 sec',
    style:
        'Highlights the most important moments first, keeps explanations shorter, and gives clear next steps. Good for quickly understanding what changed the game.',
    avatarAsset: 'assets/avatars/avatar-26.png',
    color: Color(0xFF65D1E3),
  ),
  GrandeurCoachProfile(
    id: 'friendly',
    name: 'Friendly guide',
    role: 'Beginner and kid friendly',
    timeLabel: 'Guided',
    style:
        'Uses plain language, encouragement, and guiding questions. It explains ideas gently so newer players can understand mistakes, strong moves, and better habits.',
    avatarAsset: 'assets/avatars/avatar-15.png',
    color: Color(0xFF9F8CFF),
  ),
];

GrandeurCoachProfile grandeurReviewStyleForId(String id) {
  final normalized = id.trim().toLowerCase();
  for (final profile in grandeurReviewStyleProfiles) {
    if (profile.id == normalized) return profile;
  }
  return defaultGrandeurReviewStyle;
}
