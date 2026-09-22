import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_windows/webview_windows.dart' as windows_webview;

import '../l10n/localized_material.dart';
import '../services/course_lesson_engine.dart';
import '../services/course_lesson_service.dart';
import '../services/course_progress_service.dart';
import '../services/course_thumbnail_cache.dart';
import '../services/board_settings_service.dart';
import '../services/physical_board_gateway.dart';
import '../services/physical_board_orientation.dart';
import '../services/physical_board_protocol.dart';
import '../theme/chessnut_theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/chess_board.dart';
import '../widgets/webview_zoom_guard.dart';

class InteractiveCoursesScreen extends StatefulWidget {
  InteractiveCoursesScreen({
    required this.onNavigate,
    this.boardGateway,
    this.boardSettings = const BoardSettingsState(),
    this.showBoardCoordinates = false,
    CourseLessonRepository? courseService,
    CourseProgressStore? progressStore,
    this.videoAdapterFactory = createCourseVideoAdapter,
    this.hidePhysicalBoardConnectionUi = false,
    this.isChessnutClockDevice = false,
    super.key,
  })  : courseService = courseService ?? NetworkCourseLessonRepository(),
        progressStore = progressStore ?? const NullCourseProgressStore();

  final ValueChanged<String> onNavigate;
  final PhysicalBoardGateway? boardGateway;
  final BoardSettingsState boardSettings;
  final bool showBoardCoordinates;
  final CourseLessonRepository courseService;
  final CourseProgressStore progressStore;
  final CourseVideoAdapter Function() videoAdapterFactory;
  final bool hidePhysicalBoardConnectionUi;
  final bool isChessnutClockDevice;

  @override
  State<InteractiveCoursesScreen> createState() =>
      _InteractiveCoursesScreenState();
}

class _InteractiveCoursesScreenState extends State<InteractiveCoursesScreen> {
  late final CourseLessonRepository _courseService;
  late final CourseThumbnailCache _thumbnailCache;
  late Future<List<CourseCatalogItem>> _catalogFuture;
  CourseCatalogItem? _selectedCourse;

  @override
  void initState() {
    super.initState();
    _courseService = widget.courseService;
    _thumbnailCache = CourseThumbnailCache();
    _catalogFuture = _courseService.fetchCatalog();
  }

  @override
  void dispose() {
    _thumbnailCache.dispose();
    super.dispose();
  }

  void _refreshCatalog() {
    setState(() => _catalogFuture = _courseService.fetchCatalog());
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedCourse;
    if (selected != null) {
      return _CourseLessonPlayer(
        course: selected,
        service: _courseService,
        progressStore: widget.progressStore,
        locale: Localizations.localeOf(context),
        boardGateway: widget.boardGateway,
        boardSettings: widget.boardSettings,
        showBoardCoordinates: widget.showBoardCoordinates,
        videoAdapterFactory: widget.videoAdapterFactory,
        isChessnutClockDevice: widget.isChessnutClockDevice,
        onBack: () => setState(() => _selectedCourse = null),
      );
    }

    return ResponsivePage(
      children: (context, spec) => [
        ScreenHeader(
          title: 'Interactive Courses',
          subtitle: 'Video lessons that pause for your Chessnut board',
          leading: IconButton.filledTonal(
            onPressed: () => widget.onNavigate('Back'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          trailing: IconButton.filledTonal(
            tooltip: 'Refresh courses',
            onPressed: _refreshCatalog,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        SizedBox(height: spec.gutter),
        FutureBuilder<List<CourseCatalogItem>>(
          future: _catalogFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _CourseLoadingPanel(
                title: 'Loading courses',
                subtitle: 'Fetching the latest Chessnut lesson library.',
              );
            }
            if (snapshot.hasError) {
              return _CourseErrorPanel(
                title: 'Courses could not load',
                error:
                    'Check your connection and try refreshing the course library.',
                onRetry: _refreshCatalog,
              );
            }
            final courses = snapshot.data ?? const <CourseCatalogItem>[];
            if (courses.isEmpty) {
              return _CourseErrorPanel(
                title: 'No courses found',
                error: 'The course catalog is empty right now.',
                onRetry: _refreshCatalog,
              );
            }
            return _CourseCatalogView(
              courses: courses,
              boardConnected: widget.boardGateway?.currentState ==
                  PhysicalBoardConnectionState.connected,
              hidePhysicalBoardConnectionUi:
                  widget.hidePhysicalBoardConnectionUi,
              thumbnailCache: _thumbnailCache,
              progressStore: widget.progressStore,
              onSelect: (course) => setState(() => _selectedCourse = course),
            );
          },
        ),
      ],
    );
  }
}

class _CourseCatalogView extends StatefulWidget {
  const _CourseCatalogView({
    required this.courses,
    required this.boardConnected,
    required this.hidePhysicalBoardConnectionUi,
    required this.thumbnailCache,
    required this.progressStore,
    required this.onSelect,
  });

  final List<CourseCatalogItem> courses;
  final bool boardConnected;
  final bool hidePhysicalBoardConnectionUi;
  final CourseThumbnailCache thumbnailCache;
  final CourseProgressStore progressStore;
  final ValueChanged<CourseCatalogItem> onSelect;

  @override
  State<_CourseCatalogView> createState() => _CourseCatalogViewState();
}

class _CourseCatalogViewState extends State<_CourseCatalogView> {
  String? _preloadSignature;
  late Future<Map<String, CourseProgressEntry>> _progressFuture;

  @override
  void initState() {
    super.initState();
    _progressFuture = widget.progressStore.readAll();
    _startSequentialPreload();
  }

  @override
  void didUpdateWidget(_CourseCatalogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progressStore != widget.progressStore) {
      _progressFuture = widget.progressStore.readAll();
    }
    _startSequentialPreload();
  }

  void _startSequentialPreload() {
    final urls = widget.courses
        .map((course) => course.thumbnailUrl)
        .where((url) => url.trim().isNotEmpty)
        .toList(growable: false);
    final signature = urls.join('\n');
    if (signature == _preloadSignature) return;
    _preloadSignature = signature;
    unawaited(widget.thumbnailCache.preloadSequential(urls));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, CourseProgressEntry>>(
      future: _progressFuture,
      builder: (context, snapshot) {
        final progress = snapshot.data ?? const <String, CourseProgressEntry>{};
        final latest = _latestProgress(progress, widget.courses);
        final compactLandscape = isCompactLandscapeDevice(context);
        return SectionColumn(
          spacing: compactLandscape ? 8 : 16,
          children: [
            ResponsiveSplit(
              breakpoint: 900,
              spacing: compactLandscape ? 8 : 16,
              leadingFlex: 6,
              trailingFlex: 4,
              leading: _CourseHeroPanel(
                firstCourse: widget.courses.first,
                lessonCount: widget.courses.length,
                thumbnailCache: widget.thumbnailCache,
                onStart: () => widget.onSelect(widget.courses.first),
                compactLandscape: compactLandscape,
              ),
              trailing: _CourseProgressSummary(
                total: widget.courses.length,
                progress: progress,
                boardConnected: widget.boardConnected,
                hidePhysicalBoardConnectionUi:
                    widget.hidePhysicalBoardConnectionUi,
                compactLandscape: compactLandscape,
              ),
            ),
            if (latest != null)
              _ContinueLearningPanel(
                course: latest.$1,
                progress: latest.$2,
                onTap: () => widget.onSelect(latest.$1),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Course library',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                _StatusPill(
                  icon: Icons.ondemand_video_rounded,
                  label: '${widget.courses.length} lessons',
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ],
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 720;
                final spacing =
                    compactLandscape ? 8.0 : (compact ? 12.0 : 16.0);
                final width = compact
                    ? constraints.maxWidth
                    : (constraints.maxWidth -
                            spacing * (compactLandscape ? 2 : 1)) /
                        (compactLandscape ? 3 : 2);
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final course in widget.courses)
                      SizedBox(
                        width: width,
                        child: _CourseTile(
                          course: course,
                          progress: progress[course.id],
                          thumbnailCache: widget.thumbnailCache,
                          onTap: () => widget.onSelect(course),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  (CourseCatalogItem, CourseProgressEntry)? _latestProgress(
    Map<String, CourseProgressEntry> progress,
    List<CourseCatalogItem> courses,
  ) {
    (CourseCatalogItem, CourseProgressEntry)? latest;
    for (final course in courses) {
      final entry = progress[course.id];
      if (entry == null || !entry.isStarted || entry.isComplete) continue;
      if (latest == null || entry.updatedAt.isAfter(latest.$2.updatedAt)) {
        latest = (course, entry);
      }
    }
    return latest;
  }
}

class _ContinueLearningPanel extends StatelessWidget {
  const _ContinueLearningPanel({
    required this.course,
    required this.progress,
    required this.onTap,
  });

  final CourseCatalogItem course;
  final CourseProgressEntry progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      tint: scheme.primary.withValues(alpha: 0.07),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.play_arrow_rounded, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Continue learning',
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  course.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                _CourseProgressBar(progress: progress),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 112),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(progress.percent * 100).round()}% complete',
                  maxLines: 2,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Resume at ${progress.resumeLabel}',
                  maxLines: 2,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.visible,
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

class _CourseHeroPanel extends StatelessWidget {
  const _CourseHeroPanel({
    required this.firstCourse,
    required this.lessonCount,
    required this.thumbnailCache,
    required this.onStart,
    this.compactLandscape = false,
  });

  final CourseCatalogItem firstCourse;
  final int lessonCount;
  final CourseThumbnailCache thumbnailCache;
  final VoidCallback onStart;
  final bool compactLandscape;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: AspectRatio(
              aspectRatio: compactLandscape ? 16 / 5.6 : 16 / 8.5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _CourseThumbnailImage(
                    url: firstCourse.thumbnailUrl,
                    cache: thumbnailCache,
                    fit: BoxFit.cover,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.62),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 14,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        const _StatusPill(
                          icon: Icons.sensors_rounded,
                          label: 'Interactive',
                          color: ChessnutTheme.green,
                        ),
                        _StatusPill(
                          icon: Icons.auto_stories_rounded,
                          label: '$lessonCount lessons',
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Text(
                      firstCourse.title,
                      maxLines: compactLandscape ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(compactLandscape ? 10 : 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Learn with your board',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      if (!compactLandscape)
                        Text(
                          'Videos pause for hands-on checkpoints.',
                          maxLines: 2,
                          overflow: TextOverflow.visible,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseProgressSummary extends StatelessWidget {
  const _CourseProgressSummary({
    required this.total,
    required this.progress,
    required this.boardConnected,
    required this.hidePhysicalBoardConnectionUi,
    this.compactLandscape = false,
  });

  final int total;
  final Map<String, CourseProgressEntry> progress;
  final bool boardConnected;
  final bool hidePhysicalBoardConnectionUi;
  final bool compactLandscape;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _summaryTitle,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _summarySubtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _CourseCountBadge(total: total),
            ],
          ),
          SizedBox(height: compactLandscape ? 8 : 12),
          if (compactLandscape && !hidePhysicalBoardConnectionUi)
            _CourseMetricTile(
              icon: boardConnected
                  ? Icons.check_circle_rounded
                  : Icons.sensors_off_rounded,
              label: 'Board checks',
              value: boardConnected ? 'Connected' : 'Optional',
              tone: boardConnected
                  ? ChessnutTheme.green
                  : Theme.of(context).colorScheme.secondary,
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 360;
                final tileWidth = compact
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: tileWidth,
                      child: _CourseMetricTile(
                        icon: Icons.trending_up_rounded,
                        label: 'Progress',
                        value: '${(_overallPercent * 100).round()}%',
                        tone: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: const _CourseMetricTile(
                        icon: Icons.lightbulb_rounded,
                        label: 'Board lights',
                        value: 'Guided',
                      ),
                    ),
                    if (!hidePhysicalBoardConnectionUi)
                      SizedBox(
                        width: constraints.maxWidth,
                        child: _CourseMetricTile(
                          icon: boardConnected
                              ? Icons.check_circle_rounded
                              : Icons.sensors_off_rounded,
                          label: 'Physical board',
                          value: boardConnected ? 'Connected' : 'Optional',
                          tone: boardConnected
                              ? ChessnutTheme.green
                              : Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                  ],
                );
              },
            ),
            if (!hidePhysicalBoardConnectionUi) ...[
              const SizedBox(height: 12),
              Text(
                boardConnected
                    ? 'Checkpoints can resume automatically when the position matches.'
                    : 'You can start now; connect a board whenever you want hands-on checks.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ],
      ),
    );
  }

  int get _startedCount =>
      progress.values.where((entry) => entry.isStarted).length;

  double get _overallPercent {
    if (total <= 0 || progress.isEmpty) return 0;
    final sum = progress.values.fold<double>(
      0,
      (value, entry) => value + entry.percent.clamp(0.0, 1.0),
    );
    return (sum / total).clamp(0.0, 1.0);
  }

  String get _summaryTitle =>
      _startedCount == 0 ? 'Course readiness' : 'Learning progress';

  String get _summarySubtitle => _startedCount == 0
      ? 'Everything needed for guided board lessons.'
      : '$_startedCount of $total lessons started.';
}

class _CourseCountBadge extends StatelessWidget {
  const _CourseCountBadge({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      width: 70,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          Text(
            '$total',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            'Lessons',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseMetricTile extends StatelessWidget {
  const _CourseMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.tone,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
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

class _CourseTile extends StatelessWidget {
  const _CourseTile({
    required this.course,
    required this.progress,
    required this.thumbnailCache,
    required this.onTap,
  });

  final CourseCatalogItem course;
  final CourseProgressEntry? progress;
  final CourseThumbnailCache thumbnailCache;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 520;
    final compactLandscape = isCompactLandscapeDevice(context);
    return GlassPanel(
      key: ValueKey('course-tile-${course.id}'),
      onTap: onTap,
      borderRadius: 14,
      padding: EdgeInsets.all(compactLandscape ? 8 : 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: compactLandscape ? 82 : (compact ? 92 : 118),
              height: compactLandscape ? 50 : (compact ? 56 : 70),
              child: _CourseThumbnailImage(
                url: course.thumbnailUrl,
                cache: thumbnailCache,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  maxLines: compactLandscape ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(height: compactLandscape ? 3 : 6),
                Text(
                  _subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                SizedBox(height: compactLandscape ? 5 : 7),
                if (progress case final entry?)
                  _CourseProgressBar(progress: entry, compact: true)
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _MiniCourseTag(
                        icon: Icons.play_circle_rounded,
                        label: 'Video',
                        color: scheme.primary,
                      ),
                      _MiniCourseTag(
                        icon: Icons.sensors_rounded,
                        label: 'Board',
                        color: scheme.secondary,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: scheme.primary),
        ],
      ),
    );
  }

  String get _subtitle {
    final entry = progress;
    if (entry == null || !entry.isStarted) {
      return 'Video lesson with board prompts';
    }
    if (entry.isComplete) return 'Completed';
    return 'Resume at ${entry.resumeLabel}';
  }
}

class _CourseProgressBar extends StatelessWidget {
  const _CourseProgressBar({required this.progress, this.compact = false});

  final CourseProgressEntry progress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = progress.isComplete
        ? ChessnutTheme.green
        : Theme.of(context).colorScheme.primary;
    final percentText = '${(progress.percent * 100).round()}%';
    return LayoutBuilder(
      builder: (context, constraints) {
        final showText = constraints.maxWidth >= 112 || !compact;
        final label = compact || constraints.maxWidth < 160
            ? percentText
            : '$percentText complete';
        return Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: progress.percent.clamp(0.0, 1.0),
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.14),
                ),
              ),
            ),
            if (showText) ...[
              const SizedBox(width: 8),
              Flexible(
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
              ),
            ],
          ],
        );
      },
    );
  }
}

class _CourseThumbnailImage extends StatefulWidget {
  const _CourseThumbnailImage({
    required this.url,
    required this.cache,
    required this.fit,
  });

  final String url;
  final CourseThumbnailCache cache;
  final BoxFit fit;

  @override
  State<_CourseThumbnailImage> createState() => _CourseThumbnailImageState();
}

class _CourseThumbnailImageState extends State<_CourseThumbnailImage> {
  @override
  void initState() {
    super.initState();
    widget.cache.addListener(_onCacheChanged);
  }

  @override
  void didUpdateWidget(_CourseThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cache != widget.cache) {
      oldWidget.cache.removeListener(_onCacheChanged);
      widget.cache.addListener(_onCacheChanged);
    }
  }

  @override
  void dispose() {
    widget.cache.removeListener(_onCacheChanged);
    super.dispose();
  }

  void _onCacheChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.cache.fileFor(widget.url);
    if (file == null) {
      return const _CourseThumbnailPlaceholder();
    }
    return Image.file(
      file,
      fit: widget.fit,
      errorBuilder: (_, __, ___) => const _CourseThumbnailPlaceholder(),
    );
  }
}

class _CourseThumbnailPlaceholder extends StatelessWidget {
  const _CourseThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dark
              ? const [Color(0xFF07111F), Color(0xFF123326)]
              : const [Color(0xFFE8F7FF), Color(0xFFEAFBF0)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.ondemand_video_rounded,
          color: scheme.primary.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}

class _MiniCourseTag extends StatelessWidget {
  const _MiniCourseTag({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseLessonPlayer extends StatefulWidget {
  const _CourseLessonPlayer({
    required this.course,
    required this.service,
    required this.progressStore,
    required this.locale,
    required this.onBack,
    required this.videoAdapterFactory,
    this.boardGateway,
    this.boardSettings = const BoardSettingsState(),
    this.showBoardCoordinates = false,
    this.isChessnutClockDevice = false,
  });

  final CourseCatalogItem course;
  final CourseLessonRepository service;
  final CourseProgressStore progressStore;
  final Locale locale;
  final PhysicalBoardGateway? boardGateway;
  final BoardSettingsState boardSettings;
  final bool showBoardCoordinates;
  final bool isChessnutClockDevice;
  final CourseVideoAdapter Function() videoAdapterFactory;
  final VoidCallback onBack;

  @override
  State<_CourseLessonPlayer> createState() => _CourseLessonPlayerState();
}

class _CourseLessonPlayerState extends State<_CourseLessonPlayer> {
  CourseVideoAdapter? _videoAdapter;
  late Future<CourseLessonBundle> _lessonFuture;
  CourseLessonBundle? _lesson;
  CourseLessonEngine? _engine;
  Timer? _syncTimer;
  Timer? _checkpointLightHoldTimer;
  StreamSubscription<String>? _fenSub;
  late final PhysicalBoardOrientationResolver _boardOrientation;
  CourseProgressEntry? _initialProgress;
  bool _initialVideoSeekApplied = false;
  bool _initialEngineSeekApplied = false;
  bool _savingProgress = false;
  String _boardFen = standardStartFen;
  String _subtitle = '';
  String? _lessonFen;
  Set<String> _litSquares = const {};
  Set<String> _physicalLitSquares = const {};
  Set<String> _checkpointLightHoldSquares = const {};
  CourseScriptItem? _runningCheckpoint;
  bool _videoReady = false;
  String? _videoError;
  String? _videoStatus;
  bool _hasBoardFen = false;
  bool _lessonBoardFlipped = false;
  int _boardLightGeneration = 0;
  Future<void> _boardLightOperation = Future.value();
  String? _lastMoveBoardTargetFen;
  Future<void> _moveBoardOperation = Future.value();
  bool _lessonSyncInFlight = false;
  int _boardFenRevision = 0;
  int? _runningCheckpointBoardFenRevision;
  String? _runningCheckpointStartBoardFen;
  bool _runningCheckpointSawBoardChange = false;

  @override
  void initState() {
    super.initState();
    _boardOrientation = PhysicalBoardOrientationResolver(
      settings: widget.boardSettings,
    );
    _lessonFuture = widget.service.fetchLesson(
      widget.course,
      locale: widget.locale,
    );
    unawaited(_loadInitialProgress());
    unawaited(_initializeVideo());
    unawaited(_startBoardSync());
  }

  @override
  void didUpdateWidget(covariant _CourseLessonPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_boardOrientation.updateSettings(widget.boardSettings)) {
      _resetPhysicalBoardOrientationCache();
      _queueMoveBoardFen(_lessonFen, force: true);
      _queueBoardLights(_litSquares, force: true);
    }
    if (oldWidget.locale != widget.locale ||
        oldWidget.course != widget.course ||
        oldWidget.service != widget.service) {
      _lesson = null;
      _engine = null;
      _subtitle = '';
      _lessonFuture = widget.service.fetchLesson(
        widget.course,
        locale: widget.locale,
      );
    }
  }

  Future<void> _loadInitialProgress() async {
    final progress = await widget.progressStore.read(widget.course.id);
    if (!mounted) return;
    _initialProgress = progress;
    _restoreCompletedCheckpoints();
    await _applyInitialSeekIfReady();
    _queueLessonSync();
  }

  Future<void> _initializeVideo() async {
    try {
      final adapter = widget.videoAdapterFactory();
      if (mounted) {
        setState(() {
          _videoError = null;
          _videoStatus = 'Loading video...';
        });
      }
      await adapter.initialize(
        videoUrl: widget.course.videoUrl,
        onStatus: (status) {
          if (mounted) setState(() => _videoStatus = status);
        },
      );
      if (!mounted) {
        await adapter.dispose();
        return;
      }
      setState(() {
        _videoAdapter = adapter;
        _videoReady = true;
        _videoStatus = null;
      });
      await _applyInitialSeekIfReady();
      await adapter.play();
      _syncTimer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _queueLessonSync(),
      );
      _queueLessonSync();
    } catch (_) {
      if (!mounted) return;
      setState(
        () {
          _videoStatus = null;
          _videoError =
              'Video could not load. Check your connection and try again.';
        },
      );
    }
  }

  Future<void> _startBoardSync() async {
    final gateway = widget.boardGateway;
    if (gateway == null) return;
    _queueBoardLights(const {}, force: true);
    final latestBoardFen = gateway.latestBoardFen;
    if (latestBoardFen != null) {
      _boardFen = _normalizePhysicalBoardFen(latestBoardFen);
      _hasBoardFen = true;
    }
    unawaited(gateway.enableRealtimeFen());
    _fenSub = gateway.boardFenStream.listen((fen) {
      final normalizedFen = _normalizePhysicalBoardFen(fen);
      _boardFen = normalizedFen;
      _hasBoardFen = true;
      _boardFenRevision += 1;
      final engine = _engine;
      if (engine == null ||
          !_shouldHandleBoardFenForRunningCheckpoint(normalizedFen)) {
        return;
      }
      final event = engine.handleBoardFen(normalizedFen);
      _applyEngineEvent(event);
    });
  }

  String _normalizePhysicalBoardFen(String fen) {
    final references = <String>[
      if (_lessonFen != null) _lessonFen!,
      if (_runningCheckpoint?.destFen != null) _runningCheckpoint!.destFen!,
    ];
    return _boardOrientation.normalizeAndTrack(
      fen,
      referenceFens: references,
      onMappingChanged: (_) => _resetPhysicalBoardOrientationCache(),
    );
  }

  void _resetPhysicalBoardOrientationCache() {
    _lastMoveBoardTargetFen = null;
    _physicalLitSquares = const {};
  }

  void _installLesson(CourseLessonBundle lesson) {
    if (_lesson != null) return;
    _lesson = lesson;
    _engine = CourseLessonEngine(scriptItems: lesson.scriptItems);
    _restoreCompletedCheckpoints();
    unawaited(_applyInitialSeekIfReady().whenComplete(_queueLessonSync));
  }

  void _restoreCompletedCheckpoints() {
    final engine = _engine;
    if (engine == null) return;
    engine.restoreCheckedCheckpoints(
      _initialProgress?.completedCheckpointIndexes ?? const <int>{},
    );
  }

  Future<void> _applyInitialSeekIfReady() async {
    final progress = _initialProgress;
    if (progress == null || progress.positionMs <= 0) {
      return;
    }
    final target = Duration(milliseconds: progress.positionMs);
    final adapter = _videoAdapter;
    if (!_initialVideoSeekApplied && adapter != null) {
      await adapter.seek(target);
      _initialVideoSeekApplied = true;
    }
    if (!_initialEngineSeekApplied && _engine != null) {
      _engine?.seek(target);
      _initialEngineSeekApplied = true;
    }
  }

  void _queueLessonSync() {
    if (_lessonSyncInFlight) return;
    _lessonSyncInFlight = true;
    unawaited(_syncLesson().whenComplete(() {
      _lessonSyncInFlight = false;
    }));
  }

  Future<void> _syncLesson() async {
    final lesson = _lesson;
    final engine = _engine;
    if (lesson == null || engine == null) return;
    final position = await _currentVideoPosition();
    if (!mounted) return;
    final subtitle = _subtitleFor(position, lesson.subtitles);
    var event = engine.advance(position);
    final runningCheckpoint = engine.runningCheckpoint;
    final enteringCheckpoint = event.runningCheckpoint != null &&
        event.runningCheckpoint != _runningCheckpoint;
    if (!enteringCheckpoint &&
        runningCheckpoint != null &&
        _checkpointWaitsForBoard(runningCheckpoint) &&
        _hasFreshBoardFenForRunningCheckpoint &&
        _boardFenCanConfirmRunningCheckpoint(_boardFen)) {
      final boardEvent = engine.handleBoardFen(_boardFen);
      if (_hasNewEngineVisualChange(boardEvent)) {
        event = _mergeCheckpointEvents(event, boardEvent);
      }
    }
    if (event.shouldPauseVideo && event.runningCheckpoint != null) {
      _jumpToCheckpoint(
        event.runningCheckpoint!,
        subtitle: subtitle,
        fallbackEvent: event,
      );
      return;
    }
    if (subtitle != _subtitle || _hasNewEngineVisualChange(event)) {
      _applyEngineEvent(event, subtitle: subtitle);
    }
  }

  Future<Duration> _currentVideoPosition() async {
    final adapter = _videoAdapter;
    if (adapter == null) return Duration.zero;
    try {
      return await adapter.readPosition().timeout(
            const Duration(milliseconds: 70),
            onTimeout: () => adapter.position,
          );
    } catch (_) {
      return adapter.position;
    }
  }

  CourseLessonEngineEvent _mergeCheckpointEvents(
    CourseLessonEngineEvent timedEvent,
    CourseLessonEngineEvent boardEvent,
  ) {
    final shouldResume = boardEvent.shouldResumeVideo;
    return CourseLessonEngineEvent(
      shouldPauseVideo: !shouldResume &&
          (timedEvent.shouldPauseVideo || boardEvent.shouldPauseVideo),
      shouldResumeVideo:
          timedEvent.shouldResumeVideo || boardEvent.shouldResumeVideo,
      runningCheckpoint: shouldResume
          ? boardEvent.runningCheckpoint
          : boardEvent.runningCheckpoint ?? timedEvent.runningCheckpoint,
      boardFen: timedEvent.boardFenChanged
          ? timedEvent.boardFen
          : boardEvent.boardFen,
      boardFenChanged: timedEvent.boardFenChanged || boardEvent.boardFenChanged,
      ledSquares: shouldResume || boardEvent.ledSquares.isNotEmpty
          ? boardEvent.ledSquares
          : timedEvent.ledSquares,
      physicalLedSquares:
          shouldResume || boardEvent.physicalLedSquares.isNotEmpty
              ? boardEvent.physicalLedSquares
              : timedEvent.physicalLedSquares,
      boardFlipped: boardEvent.boardFlipped ?? timedEvent.boardFlipped,
    );
  }

  void _applyEngineEvent(
    CourseLessonEngineEvent event, {
    String? subtitle,
  }) {
    final enteringCheckpoint = event.runningCheckpoint != null &&
        event.runningCheckpoint != _runningCheckpoint;
    if (enteringCheckpoint) {
      _runningCheckpointBoardFenRevision = _boardFenRevision;
      _runningCheckpointStartBoardFen =
          _hasBoardFen ? CourseLessonEngine.boardOnlyFen(_boardFen) : null;
      _runningCheckpointSawBoardChange = false;
    }
    if (event.runningCheckpoint == null || event.shouldResumeVideo) {
      _runningCheckpointBoardFenRevision = null;
      _runningCheckpointStartBoardFen = null;
      _runningCheckpointSawBoardChange = false;
    }
    if (event.shouldPauseVideo) {
      unawaited(_pauseVideo());
    }
    if (event.shouldResumeVideo) {
      unawaited(_playVideo());
    }
    _queueMoveBoardFen(
      event.boardFenChanged ? event.boardFen : event.runningCheckpoint?.destFen,
      force: enteringCheckpoint,
    );
    if (event.physicalLedSquares.isNotEmpty) {
      _queueBoardLights(
        event.physicalLedSquares,
        force: event.shouldPauseVideo || enteringCheckpoint,
      );
      if (event.runningCheckpoint != null) {
        _startCheckpointLightHold(event.physicalLedSquares);
      }
    } else if (event.shouldResumeVideo) {
      _stopCheckpointLightHold();
      _queueBoardLights(const {});
    } else if (event.runningCheckpoint == null) {
      _stopCheckpointLightHold();
    }
    if (!mounted) return;
    setState(() {
      if (subtitle != null) _subtitle = subtitle;
      if (event.boardFenChanged) _lessonFen = event.boardFen;
      if (event.boardFlipped != null) {
        _lessonBoardFlipped = event.boardFlipped!;
      }
      _runningCheckpoint = event.runningCheckpoint;
      if (event.ledSquares.isNotEmpty || event.shouldResumeVideo) {
        _litSquares = event.ledSquares;
      }
    });
  }

  bool _hasNewEngineVisualChange(CourseLessonEngineEvent event) {
    if (event.shouldPauseVideo || event.shouldResumeVideo) return true;
    if (event.boardFenChanged && event.boardFen != _lessonFen) return true;
    if (event.boardFlipped != null &&
        event.boardFlipped != _lessonBoardFlipped) {
      return true;
    }
    final nextRunning = event.runningCheckpoint;
    if (nextRunning != null && nextRunning != _runningCheckpoint) return true;
    if (event.ledSquares.isNotEmpty &&
        !setEquals(event.ledSquares, _litSquares)) {
      return true;
    }
    if (event.physicalLedSquares.isNotEmpty &&
        !setEquals(event.physicalLedSquares, _physicalLitSquares)) {
      return true;
    }
    return false;
  }

  bool get _hasFreshBoardFenForRunningCheckpoint {
    if (!_hasBoardFen) return false;
    final checkpoint = _engine?.runningCheckpoint;
    if (checkpoint != null &&
        _engine?.canConfirmExistingBoardFen(checkpoint, _boardFen) == true) {
      return true;
    }
    final startRevision = _runningCheckpointBoardFenRevision;
    return startRevision == null || _boardFenRevision > startRevision;
  }

  bool _shouldHandleBoardFenForRunningCheckpoint(String fen) {
    final checkpoint = _engine?.runningCheckpoint;
    if (checkpoint == null || !_checkpointWaitsForBoard(checkpoint)) {
      return true;
    }
    return _boardFenCanConfirmRunningCheckpoint(fen);
  }

  bool _boardFenCanConfirmRunningCheckpoint(String fen) {
    final runningCheckpoint = _engine?.runningCheckpoint;
    if (runningCheckpoint != null &&
        _engine?.canConfirmExistingBoardFen(runningCheckpoint, fen) == true) {
      return true;
    }
    final boardFen = CourseLessonEngine.boardOnlyFen(fen);
    final startFen = _runningCheckpointStartBoardFen;
    if (startFen == null) {
      _runningCheckpointStartBoardFen = boardFen;
      return false;
    }
    if (boardFen != startFen) {
      _runningCheckpointSawBoardChange = true;
      return true;
    }
    return _runningCheckpointSawBoardChange;
  }

  void _queueBoardLights(Set<String> squares, {bool force = false}) {
    if (!force && setEquals(squares, _physicalLitSquares)) return;
    final generation = ++_boardLightGeneration;
    final stableSquares = Set<String>.unmodifiable(squares);
    _boardLightOperation = _boardLightOperation.then((_) async {
      if (generation != _boardLightGeneration) return;
      final sent = stableSquares.isEmpty
          ? await _clearBoardLights()
          : await _setBoardLights(stableSquares);
      if (generation != _boardLightGeneration) return;
      if (sent) {
        _physicalLitSquares = stableSquares;
      }
    }).catchError((_) {});
    unawaited(_boardLightOperation);
  }

  void _startCheckpointLightHold(Set<String> squares) {
    if (squares.isEmpty) {
      _stopCheckpointLightHold();
      return;
    }
    final stableSquares = Set<String>.unmodifiable(squares);
    if (_checkpointLightHoldTimer != null &&
        setEquals(stableSquares, _checkpointLightHoldSquares)) {
      return;
    }
    _checkpointLightHoldSquares = stableSquares;
    _checkpointLightHoldTimer?.cancel();
    _checkpointLightHoldTimer = Timer.periodic(
      const Duration(milliseconds: 300),
      (_) {
        if (_runningCheckpoint == null || _checkpointLightHoldSquares.isEmpty) {
          _stopCheckpointLightHold();
          return;
        }
        _queueBoardLights(_checkpointLightHoldSquares, force: true);
      },
    );
  }

  void _stopCheckpointLightHold() {
    _checkpointLightHoldTimer?.cancel();
    _checkpointLightHoldTimer = null;
    _checkpointLightHoldSquares = const {};
  }

  Future<bool> _setBoardLights(Set<String> squares) async {
    final gateway = widget.boardGateway;
    if (gateway == null || squares.isEmpty) return false;
    final physicalSquares = _boardOrientation.toPhysicalSquares(squares);
    if (gateway.boardModel == PhysicalBoardModel.move) {
      return gateway.setMoveLedSquares({
        for (final square in physicalSquares)
          square: ChessnutMoveLedColor.green,
      });
    }
    return gateway.setGeneralLedSquares(physicalSquares);
  }

  Future<bool> _clearBoardLights() async {
    final gateway = widget.boardGateway;
    if (gateway == null) return false;
    if (gateway.boardModel == PhysicalBoardModel.move) {
      return gateway.clearMoveLeds();
    }
    return gateway.clearGeneralLeds();
  }

  void _queueMoveBoardFen(String? fen, {bool force = false}) {
    final targetFen = fen?.trim();
    if (targetFen == null || targetFen.isEmpty) return;
    if (!force && _lastMoveBoardTargetFen == targetFen) return;
    _moveBoardOperation = _moveBoardOperation.then((_) async {
      final gateway = widget.boardGateway;
      if (gateway == null ||
          gateway.boardModel != PhysicalBoardModel.move ||
          gateway.currentState != PhysicalBoardConnectionState.connected) {
        return;
      }
      try {
        final sent = await gateway.setMoveBoardFen(
          targetFen,
          isReverse: _boardOrientation.isReversed,
        );
        if (sent) _lastMoveBoardTargetFen = targetFen;
      } catch (_) {}
    });
    unawaited(_moveBoardOperation);
  }

  String _subtitleFor(Duration position, List<CourseSubtitleCue> cues) {
    return courseSubtitleTextAtPosition(position, cues);
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _stopCheckpointLightHold();
    unawaited(_saveProgress(pauseVideo: false));
    unawaited(_fenSub?.cancel());
    _queueBoardLights(const {});
    unawaited(_videoAdapter?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final androidPhoneDevice = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !widget.isChessnutClockDevice &&
        mediaSize.longestSide < 1000 &&
        mediaSize.shortestSide < 600;
    final iosPhoneDevice = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        !widget.isChessnutClockDevice &&
        mediaSize.longestSide < 1000 &&
        mediaSize.shortestSide < 600;
    final androidPhoneLandscape =
        androidPhoneDevice && mediaSize.width > mediaSize.height;
    final iosPhoneLandscape =
        iosPhoneDevice && mediaSize.width > mediaSize.height;
    final macosLandscape = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.macOS &&
        mediaSize.width > mediaSize.height;
    final phoneLandscape =
        androidPhoneLandscape || iosPhoneLandscape || macosLandscape;
    final androidPhonePortrait = androidPhoneDevice && !androidPhoneLandscape;
    final scrollablePhoneLayout =
        androidPhoneDevice || iosPhoneLandscape || macosLandscape;
    final page = ResponsivePage(
      compactLandscapeOverride: phoneLandscape,
      children: (context, spec) => [
        ScreenHeader(
          title: widget.course.title,
          subtitle: 'Interactive lesson',
          leading: IconButton.filledTonal(
            onPressed: _handleBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        SizedBox(height: spec.gutter),
        FutureBuilder<CourseLessonBundle>(
          future: _lessonFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _CourseLoadingPanel(
                title: 'Preparing lesson',
                subtitle: 'Loading subtitles and board checkpoints.',
              );
            }
            if (snapshot.hasError) {
              return _CourseErrorPanel(
                title: 'Lesson could not load',
                error:
                    'Check your connection and try opening this lesson again.',
                onRetry: () => setState(() {
                  _lesson = null;
                  _lessonFuture = widget.service.fetchLesson(
                    widget.course,
                    locale: widget.locale,
                  );
                }),
              );
            }
            final lesson = snapshot.data!;
            _installLesson(lesson);
            final compactLandscape = spec.compactLandscape;
            final layout = _LessonThreePaneLayout(
              compactLandscape: compactLandscape,
              phoneLandscape: phoneLandscape,
              phoneLandscapeKey: ValueKey(
                macosLandscape
                    ? 'lesson-macos-ios-landscape'
                    : iosPhoneLandscape
                        ? 'lesson-ios-phone-landscape'
                        : 'lesson-android-phone-landscape',
              ),
              androidPhonePortrait: androidPhonePortrait,
              phoneLandscapeTopRowHeight: phoneLandscape
                  ? (spec.heightAfterHeader(min: 0) * 1.02)
                      .clamp(300.0, 320.0)
                      .toDouble()
                  : null,
              spacing: spec.gutter,
              board: _LessonBoardPanel(
                fen: _lessonFen ?? standardStartFen,
                litSquares: _litSquares,
                runningCheckpoint: _runningCheckpoint,
                compactLandscape: compactLandscape,
                flipped: _lessonBoardFlipped,
                showCoordinates: widget.showBoardCoordinates,
              ),
              video: _VideoPanel(
                adapter: _videoAdapter,
                subtitle: _subtitle,
                loading: !_videoReady,
                status: _videoStatus,
                error: _videoError,
              ),
              checkpoints: _CheckpointPanel(
                checkpoints: lesson.checkpoints,
                checked: _engine?.checkedCheckpoints ?? const {},
                running: _runningCheckpoint,
                onSelect: _jumpToCheckpoint,
                expandContent: scrollablePhoneLayout,
              ),
            );
            if (scrollablePhoneLayout) return layout;
            return SizedBox(
              height: spec.heightAfterHeader(
                min: compactLandscape ? 330 : 480,
              ),
              child: layout,
            );
          },
        ),
      ],
    );
    if (!iosPhoneLandscape) return page;
    return SafeArea(
      top: false,
      bottom: false,
      child: page,
    );
  }

  void _jumpToCheckpoint(
    CourseScriptItem checkpoint, {
    String? subtitle,
    CourseLessonEngineEvent? fallbackEvent,
  }) {
    final engineEvent = _engine?.jumpToCheckpoint(checkpoint);
    unawaited(_videoAdapter?.seek(checkpoint.startTime));
    var event = engineEvent ??
        CourseLessonEngineEvent(
          shouldPauseVideo: true,
          runningCheckpoint: checkpoint,
          boardFen: checkpoint.destFen,
          boardFenChanged: true,
          ledSquares: CourseLessonEngine.squaresFromLedArray(checkpoint.led),
        );
    final fallback = fallbackEvent;
    if (fallback != null &&
        event.physicalLedSquares.isEmpty &&
        fallback.physicalLedSquares.isNotEmpty) {
      event = CourseLessonEngineEvent(
        shouldPauseVideo: event.shouldPauseVideo,
        shouldResumeVideo: event.shouldResumeVideo,
        runningCheckpoint: event.runningCheckpoint,
        boardFen: event.boardFen,
        boardFenChanged: event.boardFenChanged,
        ledSquares:
            event.ledSquares.isEmpty ? fallback.ledSquares : event.ledSquares,
        physicalLedSquares: fallback.physicalLedSquares,
        boardFlipped: event.boardFlipped ?? fallback.boardFlipped,
      );
    }
    _applyEngineEvent(event, subtitle: subtitle);
  }

  bool _checkpointWaitsForBoard(CourseScriptItem checkpoint) {
    final destFen = checkpoint.destFen;
    return (checkpoint.destFenMatchToContinue || checkpoint.startTimePause) &&
        destFen != null &&
        destFen.isNotEmpty;
  }

  Future<void> _playVideo() async {
    await _videoAdapter?.play();
  }

  Future<void> _pauseVideo() async {
    await _videoAdapter?.pause();
  }

  Future<void> _handleBack() async {
    await _saveProgress();
    if (!mounted) return;
    widget.onBack();
  }

  Future<void> _saveProgress({bool pauseVideo = true}) async {
    if (_savingProgress) return;
    _savingProgress = true;
    try {
      final adapter = _videoAdapter;
      if (pauseVideo && adapter != null) {
        await adapter.pause();
      }
      final lesson = _lesson;
      final checkpoints = lesson?.checkpoints ?? const <CourseScriptItem>[];
      final position = adapter?.position ?? _initialProgressPosition;
      final existing = _initialProgress;
      final completedCheckpoints = math.max(
        _engine?.checkedCheckpoints.length ?? 0,
        existing?.completedCheckpoints ?? 0,
      );
      final completedCheckpointIndexes = _engine?.checkedCheckpointIndexes ??
          existing?.completedCheckpointIndexes ??
          const <int>{};
      final totalMs = _estimatedTotalMs(
        lesson: lesson,
        position: position,
        existing: existing,
        completedCheckpoints: completedCheckpoints,
      );
      final entry = CourseProgressEntry(
        courseId: widget.course.id,
        courseTitle: widget.course.title,
        positionMs: position.inMilliseconds,
        totalMs: totalMs,
        completedCheckpoints: completedCheckpoints,
        totalCheckpoints: checkpoints.length,
        completedCheckpointIndexes: completedCheckpointIndexes,
        updatedAt: DateTime.now(),
      );
      if (entry.isStarted || existing != null) {
        await widget.progressStore.write(entry);
        _initialProgress = entry;
      }
    } finally {
      _savingProgress = false;
    }
  }

  int _estimatedTotalMs({
    required CourseLessonBundle? lesson,
    required Duration position,
    required CourseProgressEntry? existing,
    required int completedCheckpoints,
  }) {
    final candidates = <int>[
      existing?.totalMs ?? 0,
      for (final cue in lesson?.subtitles ?? const <CourseSubtitleCue>[])
        cue.end.inMilliseconds,
      for (final item in lesson?.scriptItems ?? const <CourseScriptItem>[])
        item.startTime.inMilliseconds,
    ];
    var totalMs = candidates.fold<int>(0, (a, b) => a > b ? a : b);
    final totalCheckpoints = lesson?.checkpoints.length ?? 0;
    final hasCompletedAllCheckpoints =
        totalCheckpoints > 0 && completedCheckpoints >= totalCheckpoints;
    if (!hasCompletedAllCheckpoints && totalMs <= position.inMilliseconds) {
      totalMs =
          position.inMilliseconds + const Duration(minutes: 1).inMilliseconds;
    }
    return totalMs;
  }

  Duration get _initialProgressPosition {
    final progress = _initialProgress;
    if (progress == null) return Duration.zero;
    return Duration(milliseconds: progress.positionMs);
  }
}

abstract interface class CourseVideoAdapter {
  Duration get position;

  Future<Duration> readPosition();

  Future<void> initialize({
    required String videoUrl,
    ValueChanged<String>? onStatus,
  });

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Widget build();

  Future<void> dispose();
}

CourseVideoAdapter createCourseVideoAdapter() {
  if (defaultTargetPlatform == TargetPlatform.windows) {
    return WindowsCourseVideoAdapter();
  }
  return NativeCourseVideoAdapter();
}

String _courseVideoHtml(String videoUrl) {
  final escapedVideoUrl = const HtmlEscape().convert(videoUrl);
  return '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { box-sizing: border-box; }
    html, body {
      margin: 0;
      width: 100%;
      height: 100%;
      min-width: 0;
      min-height: 0;
      background: #000;
      overflow: hidden;
    }
    body {
      position: fixed;
      inset: 0;
    }
    video {
      position: absolute;
      inset: 0;
      display: block;
      width: 100%;
      height: 100%;
      min-width: 0;
      min-height: 0;
      max-width: 100%;
      max-height: 100%;
      object-fit: contain;
      background: #000;
    }
    video::-webkit-media-controls-enclosure,
    video::-webkit-media-controls-panel {
      max-width: 100%;
    }
  </style>
</head>
<body>
  <video id="lessonVideo" src="$escapedVideoUrl" playsinline controls preload="auto"></video>
  <script>
    window.lessonVideo = document.getElementById('lessonVideo');
    window.lessonVideo.muted = false;
    window.lessonVideo.defaultMuted = false;
    window.lessonVideo.volume = 1;
    var lessonRetryTimer = null;
    var lessonLastPosition = 0;
    function postLessonState(reason) {
      if (!window.chrome || !window.chrome.webview) return;
      window.chrome.webview.postMessage({
        type: 'courseVideoState',
        reason: reason,
        position: window.lessonVideo.currentTime || lessonLastPosition || 0,
        paused: !!window.lessonVideo.paused,
        ended: !!window.lessonVideo.ended,
        readyState: window.lessonVideo.readyState || 0
      });
    }
    window.lessonVideo.addEventListener('timeupdate', function() {
      lessonLastPosition = window.lessonVideo.currentTime || lessonLastPosition;
      postLessonState('timeupdate');
    });
    ['play', 'playing', 'pause', 'waiting', 'seeking', 'seeked', 'ended'].forEach(function(name) {
      window.lessonVideo.addEventListener(name, function() {
        lessonLastPosition = window.lessonVideo.currentTime || lessonLastPosition;
        postLessonState(name);
      });
    });
    window.lessonVideo.addEventListener('error', function() {
      if (lessonRetryTimer) return;
      lessonRetryTimer = setTimeout(function() {
        lessonRetryTimer = null;
        var target = window.lessonVideo.currentTime || lessonLastPosition || 0;
        window.lessonVideo.load();
        window.lessonVideo.addEventListener('loadedmetadata', function restore() {
          window.lessonVideo.removeEventListener('loadedmetadata', restore);
          try { window.lessonVideo.currentTime = target; } catch (e) {}
          window.lessonVideo.play().catch(function() {});
        });
      }, 1000);
    });
    window.lessonVideo.addEventListener('loadedmetadata', function() {
      postLessonState('loadedmetadata');
      window.lessonVideo.play().catch(function() {});
    });
  </script>
</body>
</html>
''';
}

final Set<String> _courseVideoDownloadsInProgress = <String>{};

class _CourseVideoSource {
  const _CourseVideoSource({
    required this.playbackUrl,
    this.originalUri,
    this.cacheFile,
    this.fromCache = false,
  });

  final String playbackUrl;
  final Uri? originalUri;
  final File? cacheFile;
  final bool fromCache;

  bool get canCache => originalUri != null && cacheFile != null && !fromCache;
}

Future<_CourseVideoSource> _resolveCourseVideoSource(String videoUrl) async {
  final uri = Uri.tryParse(videoUrl);
  if (uri == null ||
      !uri.hasScheme ||
      uri.scheme == 'file' ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    return _CourseVideoSource(playbackUrl: videoUrl);
  }
  try {
    final file = await _courseVideoCacheFile(videoUrl);
    if (await file.exists() && await file.length() > 0) {
      return _CourseVideoSource(
        playbackUrl: file.uri.toString(),
        originalUri: uri,
        cacheFile: file,
        fromCache: true,
      );
    }
    return _CourseVideoSource(
      playbackUrl: videoUrl,
      originalUri: uri,
      cacheFile: file,
    );
  } catch (_) {
    // A cache lookup should never prevent immediate network playback.
  }
  return _CourseVideoSource(playbackUrl: videoUrl);
}

Future<void> _cacheCourseVideoInBackground(
  String videoUrl,
  Uri uri,
  File file,
) async {
  if (!_courseVideoDownloadsInProgress.add(videoUrl)) return;
  final tempFile = File('${file.path}.part');
  try {
    if (await file.exists() && await file.length() > 0) return;

    final request = http.Request('GET', uri);
    final response = await request.send();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return;
    }

    await file.parent.create(recursive: true);
    if (await tempFile.exists()) await tempFile.delete();
    final sink = tempFile.openWrite();
    try {
      await response.stream.pipe(sink);
    } finally {
      await sink.close();
    }
    if (await tempFile.length() == 0) {
      await tempFile.delete().catchError((_) => tempFile);
      return;
    }
    if (await file.exists()) await file.delete();
    await tempFile.rename(file.path);
  } catch (_) {
    if (await tempFile.exists()) {
      await tempFile.delete().catchError((_) => tempFile);
    }
  } finally {
    _courseVideoDownloadsInProgress.remove(videoUrl);
  }
}

Future<File> _downloadCourseVideoCache(
  String videoUrl,
  Uri uri,
  File file, {
  ValueChanged<String>? onStatus,
}) async {
  if (await file.exists() && await file.length() > 0) return file;
  final tempFile = File('${file.path}.part');
  final client = http.Client();
  try {
    await file.parent.create(recursive: true);
    if (await tempFile.exists()) await tempFile.delete();

    final response = await client
        .send(http.Request('GET', uri))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Course video request failed with ${response.statusCode}.',
        uri: uri,
      );
    }

    final total = response.contentLength;
    var received = 0;
    var lastProgress = -1;
    final sink = tempFile.openWrite();
    try {
      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (total != null && total > 0) {
          final progress = (received * 100 ~/ total);
          if (progress != lastProgress && progress % 5 == 0) {
            lastProgress = progress;
            onStatus?.call('Caching video... $progress%');
          }
        } else if (received ~/ (1024 * 1024) !=
            (received - chunk.length) ~/ (1024 * 1024)) {
          onStatus?.call('Caching video... ${received ~/ (1024 * 1024)} MB');
        }
      }
    } finally {
      await sink.close();
    }

    if (await tempFile.length() == 0) {
      throw const FileSystemException('Course video cache is empty.');
    }
    if (await file.exists()) await file.delete();
    await tempFile.rename(file.path);
    onStatus?.call('Opening cached video...');
    return file;
  } catch (_) {
    if (await tempFile.exists()) {
      await tempFile.delete().catchError((_) => tempFile);
    }
    rethrow;
  } finally {
    client.close();
  }
}

Future<File> _courseVideoCacheFile(String videoUrl) async {
  final dir = await getApplicationSupportDirectory();
  final digest = md5.convert(utf8.encode(videoUrl)).toString();
  final extension = _videoExtension(videoUrl);
  return File('${dir.path}${Platform.pathSeparator}course_video_cache'
      '${Platform.pathSeparator}$digest$extension');
}

String _videoExtension(String videoUrl) {
  final path = Uri.tryParse(videoUrl)?.path.toLowerCase() ?? '';
  for (final extension in const ['.mp4', '.m4v', '.webm', '.mov']) {
    if (path.endsWith(extension)) return extension;
  }
  return '.mp4';
}

class NativeCourseVideoAdapter implements CourseVideoAdapter {
  VideoPlayerController? _controller;
  _CourseVideoSource? _source;
  Timer? _cacheTimer;
  bool _cacheStarted = false;
  bool _disposed = false;

  @override
  Duration get position => _controller?.value.position ?? Duration.zero;

  @override
  Future<Duration> readPosition() async => position;

  @override
  Future<void> initialize({
    required String videoUrl,
    ValueChanged<String>? onStatus,
  }) async {
    final source = await _resolveCourseVideoSource(videoUrl);
    _source = source;
    onStatus?.call(
        source.fromCache ? 'Opening cached video...' : 'Loading video...');
    try {
      await _openVideoSource(source.playbackUrl);
    } catch (_) {
      if (!source.canCache) rethrow;
      onStatus?.call('Network is slow. Caching video...');
      final uri = source.originalUri;
      final file = source.cacheFile;
      if (uri == null || file == null) rethrow;
      final cachedFile = await _downloadCourseVideoCache(
        source.playbackUrl,
        uri,
        file,
        onStatus: onStatus,
      );
      _source = _CourseVideoSource(
        playbackUrl: cachedFile.uri.toString(),
        originalUri: uri,
        cacheFile: cachedFile,
        fromCache: true,
      );
      await _openVideoSource(cachedFile.uri.toString());
    }
  }

  Future<void> _openVideoSource(String playbackUrl) async {
    await _controller?.dispose();
    final uri = Uri.parse(playbackUrl);
    final controller = uri.scheme == 'file'
        ? VideoPlayerController.file(File.fromUri(uri))
        : VideoPlayerController.networkUrl(
            uri,
            formatHint: VideoFormat.other,
          );
    _controller = controller;
    await controller.initialize();
    await controller.setVolume(1);
  }

  @override
  Future<void> play() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.setVolume(1);
    await controller.play();
    _scheduleBackgroundCache();
  }

  @override
  Future<void> pause() async {
    await _controller?.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _controller?.seekTo(position);
  }

  @override
  Widget build() {
    final controller = _controller;
    return controller == null
        ? const ColoredBox(color: Colors.black)
        : _NativeCourseVideoView(controller: controller);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _cacheTimer?.cancel();
    await _controller?.dispose();
  }

  void _scheduleBackgroundCache() {
    if (_disposed || _cacheStarted || _cacheTimer != null) return;
    final source = _source;
    if (source == null || !source.canCache) return;
    _cacheTimer = Timer(const Duration(seconds: 45), () {
      _cacheTimer = null;
      if (_disposed || _cacheStarted) return;
      final controller = _controller;
      if (controller == null) return;
      final value = controller.value;
      if (!value.isInitialized ||
          !value.isPlaying ||
          value.isBuffering ||
          value.position < const Duration(seconds: 3)) {
        _scheduleBackgroundCache();
        return;
      }
      final uri = source.originalUri;
      final file = source.cacheFile;
      if (uri == null || file == null) return;
      _cacheStarted = true;
      unawaited(_cacheCourseVideoInBackground(source.playbackUrl, uri, file));
    });
  }
}

class _NativeCourseVideoView extends StatefulWidget {
  const _NativeCourseVideoView({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_NativeCourseVideoView> createState() => _NativeCourseVideoViewState();
}

class _NativeCourseVideoViewState extends State<_NativeCourseVideoView> {
  bool _muted = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            _buildVideo(value),
            if (value.isBuffering)
              const Center(child: CircularProgressIndicator()),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _NativeVideoControls(
                controller: widget.controller,
                value: value,
                muted: _muted,
                onToggleMuted: _toggleMuted,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVideo(VideoPlayerValue value) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: value.aspectRatio,
          child: VideoPlayer(widget.controller),
        ),
      ),
    );
  }

  Future<void> _toggleMuted() async {
    final nextMuted = !_muted;
    await widget.controller.setVolume(nextMuted ? 0 : 1);
    if (mounted) setState(() => _muted = nextMuted);
  }
}

class _NativeVideoControls extends StatelessWidget {
  const _NativeVideoControls({
    required this.controller,
    required this.value,
    required this.muted,
    required this.onToggleMuted,
  });

  final VideoPlayerController controller;
  final VideoPlayerValue value;
  final bool muted;
  final VoidCallback onToggleMuted;

  static const ButtonStyle _transparentButtonStyle = ButtonStyle(
    backgroundColor: WidgetStatePropertyAll<Color>(Colors.transparent),
    foregroundColor: WidgetStatePropertyAll<Color>(Colors.white),
    overlayColor: WidgetStatePropertyAll<Color>(Colors.transparent),
    shadowColor: WidgetStatePropertyAll<Color>(Colors.transparent),
    surfaceTintColor: WidgetStatePropertyAll<Color>(Colors.transparent),
    elevation: WidgetStatePropertyAll<double>(0),
    side: WidgetStatePropertyAll<BorderSide?>(BorderSide.none),
    minimumSize: WidgetStatePropertyAll<Size>(Size.square(40)),
    shape: WidgetStatePropertyAll<OutlinedBorder?>(CircleBorder()),
  );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.74),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
        child: Row(
          children: [
            IconButton(
              tooltip: value.isPlaying ? 'Pause' : 'Play',
              onPressed: () =>
                  value.isPlaying ? controller.pause() : controller.play(),
              style: _transparentButtonStyle,
              icon: Icon(
                value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '${formatCourseVideoTime(value.position)} / '
                '${formatCourseVideoTime(value.duration)}',
                key: const ValueKey('course-video-time'),
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(vertical: 14),
                colors: VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white.withValues(alpha: 0.42),
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                ),
              ),
            ),
            IconButton(
              tooltip: muted ? 'Unmute' : 'Mute',
              onPressed: onToggleMuted,
              style: _transparentButtonStyle,
              icon: Icon(
                muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WindowsCourseVideoAdapter implements CourseVideoAdapter {
  final windows_webview.WebviewController _controller =
      windows_webview.WebviewController();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Duration _position = Duration.zero;
  bool _refreshInFlight = false;
  bool _disposed = false;

  @override
  Duration get position => _position;

  @override
  Future<Duration> readPosition() async {
    _refreshPositionInBackground();
    return position;
  }

  @override
  Future<void> initialize({
    required String videoUrl,
    ValueChanged<String>? onStatus,
  }) async {
    final source = await _resolveCourseVideoSource(videoUrl);
    onStatus?.call(
        source.fromCache ? 'Opening cached video...' : 'Loading video...');
    await _controller.initialize();
    await configureWindowsWebViewZoomGuard(_controller);
    await _controller.setPopupWindowPolicy(
      windows_webview.WebviewPopupWindowPolicy.deny,
    );
    _subscriptions.add(_controller.loadingState.listen((state) {
      if (state == windows_webview.LoadingState.navigationCompleted) {
        unawaited(injectWindowsWebViewTextScaleGuard(_controller));
      }
    }));
    _subscriptions.add(_controller.webMessage.listen(_handleWebMessage));
    await _controller.loadStringContent(_courseVideoHtml(source.playbackUrl));
    await injectWindowsWebViewTextScaleGuard(_controller);
  }

  @override
  Future<void> play() async {
    unawaited(
      _controller.executeScript(
        "if (window.lessonVideo) { window.lessonVideo.muted = false; window.lessonVideo.defaultMuted = false; window.lessonVideo.volume = 1; window.lessonVideo.play && window.lessonVideo.play(); }",
      ),
    );
  }

  @override
  Future<void> pause() async {
    unawaited(
      _controller.executeScript(
        "window.lessonVideo && window.lessonVideo.pause && window.lessonVideo.pause();",
      ),
    );
    _refreshPositionInBackground();
  }

  @override
  Future<void> seek(Duration position) async {
    _setPosition(position);
    unawaited(
      _controller.executeScript(
        "if (window.lessonVideo) window.lessonVideo.currentTime = ${position.inMilliseconds / 1000};",
      ),
    );
  }

  Future<void> _refreshPosition() async {
    final result = await _controller.executeScript(
      "window.lessonVideo ? window.lessonVideo.currentTime : 0",
    );
    _setPosition(_durationFromJsSeconds(result));
  }

  void _refreshPositionInBackground() {
    if (_disposed || _refreshInFlight) return;
    _refreshInFlight = true;
    unawaited(
      _refreshPosition().catchError((error) {}).whenComplete(() {
        _refreshInFlight = false;
      }),
    );
  }

  void _setPosition(Duration position) {
    _position = position;
  }

  void _handleWebMessage(dynamic message) {
    if (message is! Map) return;
    if (message['type'] != 'courseVideoState') return;
    _setPosition(_durationFromJsSeconds(message['position']));
  }

  @override
  Widget build() {
    _refreshPositionInBackground();
    return buildWebViewTextScaleGuard(
      child: windows_webview.Webview(_controller),
    );
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _controller.dispose();
  }
}

Duration _durationFromJsSeconds(Object? raw) {
  final text = raw?.toString().replaceAll('"', '').trim() ?? '';
  final seconds = double.tryParse(text) ?? 0;
  return Duration(milliseconds: (seconds * 1000).round());
}

class _LessonThreePaneLayout extends StatelessWidget {
  const _LessonThreePaneLayout({
    required this.board,
    required this.video,
    required this.checkpoints,
    required this.spacing,
    required this.compactLandscape,
    this.phoneLandscape = false,
    this.phoneLandscapeKey = const ValueKey('lesson-phone-landscape'),
    this.androidPhonePortrait = false,
    this.phoneLandscapeTopRowHeight,
  });

  final Widget board;
  final Widget video;
  final Widget checkpoints;
  final double spacing;
  final bool compactLandscape;
  final bool phoneLandscape;
  final Key phoneLandscapeKey;
  final bool androidPhonePortrait;
  final double? phoneLandscapeTopRowHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (phoneLandscape) {
          final topRowHeight = phoneLandscapeTopRowHeight ?? 180;
          final boardWidth =
              math.min(width * 0.40, topRowHeight + 20).clamp(190.0, 280.0);
          return Column(
            key: phoneLandscapeKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: topRowHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      key: const ValueKey('lesson-board-pane'),
                      width: boardWidth,
                      child: board,
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      key: const ValueKey('lesson-video-pane'),
                      child: video,
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing),
              KeyedSubtree(
                key: const ValueKey('lesson-checkpoint-pane'),
                child: checkpoints,
              ),
            ],
          );
        }
        if (androidPhonePortrait) {
          final videoHeight = (width * 9 / 16).clamp(220.0, 360.0);
          return Column(
            key: const ValueKey('lesson-android-phone-portrait'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                key: const ValueKey('lesson-board-pane'),
                height: 300,
                child: board,
              ),
              SizedBox(height: spacing),
              SizedBox(
                key: const ValueKey('lesson-video-pane'),
                height: videoHeight,
                child: video,
              ),
              SizedBox(height: spacing),
              KeyedSubtree(
                key: const ValueKey('lesson-checkpoint-pane'),
                child: checkpoints,
              ),
            ],
          );
        }
        if (width >= 980 && height.isFinite) {
          final boardWidth = math
              .min(height, (width - spacing * 2) * 0.31)
              .clamp(220.0, 420.0);
          final checkpointWidth = (width * 0.24).clamp(220.0, 320.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                key: const ValueKey('lesson-board-pane'),
                width: boardWidth,
                child: board,
              ),
              SizedBox(width: spacing),
              Expanded(
                key: const ValueKey('lesson-video-pane'),
                child: video,
              ),
              SizedBox(width: spacing),
              SizedBox(
                key: const ValueKey('lesson-checkpoint-pane'),
                width: checkpointWidth,
                child: checkpoints,
              ),
            ],
          );
        }

        final compactBoardHeight = compactLandscape ? 220.0 : 300.0;
        final videoHeight = width >= 720
            ? (height.isFinite ? height * 0.46 : 320.0)
            : width * 9 / 16;
        final checkpointHeight = height.isFinite
            ? math.max(
                220.0, height - compactBoardHeight - videoHeight - spacing * 2)
            : 260.0;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                key: const ValueKey('lesson-board-pane'),
                height: compactBoardHeight,
                child: board,
              ),
              SizedBox(height: spacing),
              SizedBox(
                key: const ValueKey('lesson-video-pane'),
                height: videoHeight.clamp(220.0, 360.0),
                child: video,
              ),
              SizedBox(height: spacing),
              SizedBox(
                key: const ValueKey('lesson-checkpoint-pane'),
                height: checkpointHeight.clamp(220.0, 360.0),
                child: checkpoints,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LessonBoardPanel extends StatelessWidget {
  const _LessonBoardPanel({
    required this.fen,
    required this.litSquares,
    required this.runningCheckpoint,
    required this.flipped,
    required this.showCoordinates,
    this.compactLandscape = false,
  });

  final String fen;
  final Set<String> litSquares;
  final CourseScriptItem? runningCheckpoint;
  final bool flipped;
  final bool showCoordinates;
  final bool compactLandscape;

  @override
  Widget build(BuildContext context) {
    final pieces = piecesFromBoardOnlyFen(fen);
    return GlassPanel(
      padding: EdgeInsets.all(compactLandscape ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Lesson board',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: compactLandscape ? 14 : 16,
                  ),
                ),
              ),
              _StatusPill(
                icon: runningCheckpoint == null
                    ? Icons.play_circle_rounded
                    : Icons.pause_circle_rounded,
                label: runningCheckpoint == null ? 'Playing' : 'Checkpoint',
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
          SizedBox(height: compactLandscape ? 6 : 10),
          Expanded(
            child: ResponsiveBoardFrame(
              maxSize: compactLandscape ? 360 : 420,
              padding: EdgeInsets.all(compactLandscape ? 2 : 4),
              borderRadius: 12,
              builder: (size) => Stack(
                children: [
                  ChessBoard(
                    key: ValueKey('lesson-board-$fen-$flipped'),
                    pieces: pieces,
                    size: size,
                    showCoordinates: showCoordinates,
                    flipped: flipped,
                  ),
                  _LessonSquareOverlay(
                    size: size,
                    squares: litSquares,
                    flipped: flipped,
                  ),
                ],
              ),
            ),
          ),
          if (!compactLandscape) ...[
            const SizedBox(height: 8),
            Text(
              runningCheckpoint == null
                  ? 'Watch the video. The board will pause when a move is needed.'
                  : 'Place the pieces on your physical board to match the lesson position.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _LessonSquareOverlay extends StatelessWidget {
  const _LessonSquareOverlay({
    required this.size,
    required this.squares,
    required this.flipped,
  });

  final double size;
  final Set<String> squares;
  final bool flipped;

  @override
  Widget build(BuildContext context) {
    if (squares.isEmpty) return const SizedBox.shrink();
    final squareSize = size / 8;
    final color = Theme.of(context).colorScheme.tertiary;
    return IgnorePointer(
      child: Stack(
        children: [
          for (final square in squares)
            if (_squareOffset(square, squareSize) case final offset?)
              Positioned(
                left: offset.dx,
                top: offset.dy,
                width: squareSize,
                height: squareSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.20),
                    border: Border.all(
                      color: color.withValues(alpha: 0.80),
                      width: (squareSize * 0.05).clamp(2.0, 4.0),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Offset? _squareOffset(String square, double squareSize) {
    if (square.length != 2) return null;
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.tryParse(square[1]);
    if (file < 0 || file > 7 || rank == null || rank < 1 || rank > 8) {
      return null;
    }
    final visualFile = flipped ? 7 - file : file;
    final visualRank = flipped ? rank - 1 : 8 - rank;
    return Offset(visualFile * squareSize, visualRank * squareSize);
  }
}

class _VideoPanel extends StatelessWidget {
  const _VideoPanel({
    required this.adapter,
    required this.subtitle,
    required this.loading,
    required this.status,
    required this.error,
  });

  final CourseVideoAdapter? adapter;
  final String subtitle;
  final bool loading;
  final String? status;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final currentError = error;
    const subtitleHeight = 48.0;
    const subtitleGap = 6.0;
    const panelInset = 10.0;
    return GlassPanel(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth.isFinite
              ? math.max(0.0, constraints.maxWidth - panelInset * 2)
              : constraints.maxWidth;
          final maxHeight = constraints.maxHeight.isFinite
              ? math.max(0.0, constraints.maxHeight - panelInset * 2)
              : constraints.maxHeight;
          final availableVideoHeight = maxHeight.isFinite
              ? math.max(0.0, maxHeight - subtitleHeight - subtitleGap)
              : maxHeight;
          final videoWidth = maxWidth.isFinite && maxHeight.isFinite
              ? math.min(maxWidth, availableVideoHeight * 16 / 9)
              : maxWidth;
          final videoHeight = maxWidth.isFinite && maxHeight.isFinite
              ? math.min(availableVideoHeight, videoWidth * 9 / 16)
              : maxWidth * 9 / 16;
          return Padding(
            padding: const EdgeInsets.all(panelInset),
            child: Center(
              child: SizedBox(
                width: videoWidth,
                height: videoHeight + subtitleGap + subtitleHeight,
                child: Column(
                  children: [
                    SizedBox(
                      key: const ValueKey('lesson-video-frame'),
                      width: videoWidth,
                      height: videoHeight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: ClipRect(
                          child: Stack(
                            fit: StackFit.expand,
                            clipBehavior: Clip.hardEdge,
                            children: [
                              adapter?.build() ??
                                  const ColoredBox(color: Colors.black),
                              if (loading && currentError == null)
                                Center(
                                  child: _VideoLoadingStatus(
                                    status: status ?? 'Loading video...',
                                  ),
                                ),
                              if (currentError != null)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      currentError,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: subtitleGap),
                    SizedBox(
                      height: subtitleHeight,
                      child: _VideoSubtitleStrip(subtitle: subtitle),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VideoSubtitleStrip extends StatelessWidget {
  const _VideoSubtitleStrip({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w800,
          height: 1.15,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(
        child: Text(
          subtitle,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    );
  }
}

class _VideoLoadingStatus extends StatelessWidget {
  const _VideoLoadingStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              status,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckpointPanel extends StatelessWidget {
  const _CheckpointPanel({
    required this.checkpoints,
    required this.checked,
    required this.running,
    required this.onSelect,
    this.expandContent = false,
  });

  final List<CourseScriptItem> checkpoints;
  final Set<CourseScriptItem> checked;
  final CourseScriptItem? running;
  final ValueChanged<CourseScriptItem> onSelect;
  final bool expandContent;

  @override
  Widget build(BuildContext context) {
    final checkpointContent = checkpoints.isEmpty
        ? Align(
            alignment: Alignment.topLeft,
            child: Text(
              'No checkpoints in this lesson.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        : Column(
            children: [
              for (var index = 0; index < checkpoints.length; index += 1) ...[
                _CheckpointRow(
                  item: checkpoints[index],
                  index: index,
                  checked: checked.contains(checkpoints[index]),
                  running: running == checkpoints[index],
                  onTap: () => onSelect(checkpoints[index]),
                ),
                if (index != checkpoints.length - 1) const SizedBox(height: 8),
              ],
            ],
          );
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: expandContent ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Checkpoints',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 10),
          if (expandContent)
            checkpointContent
          else
            Expanded(
              child: SingleChildScrollView(child: checkpointContent),
            ),
        ],
      ),
    );
  }
}

class _CheckpointRow extends StatelessWidget {
  const _CheckpointRow({
    required this.item,
    required this.index,
    required this.checked,
    required this.running,
    required this.onTap,
  });

  final CourseScriptItem item;
  final int index;
  final bool checked;
  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = checked
        ? ChessnutTheme.green
        : running
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.secondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: running ? 0.13 : 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Icon(
              checked
                  ? Icons.check_circle_rounded
                  : running
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.checkpointTitle ?? 'Checkpoint ${index + 1}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatCourseVideoTime(item.startTime),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _CourseLoadingPanel extends StatelessWidget {
  const _CourseLoadingPanel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseErrorPanel extends StatelessWidget {
  const _CourseErrorPanel({
    required this.title,
    required this.error,
    required this.onRetry,
  });

  final String title;
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      tint: scheme.error.withValues(alpha: 0.05),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(
                  error,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

@visibleForTesting
String formatCourseVideoTime(Duration duration) {
  final totalSeconds = duration.inSeconds.clamp(0, 359999);
  final hours = totalSeconds ~/ 3600;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    final minutePart = (minutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutePart:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
