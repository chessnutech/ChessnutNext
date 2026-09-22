import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

import '../l10n/localized_material.dart';
import '../theme/chessnut_theme.dart';
import '../widgets/app_chrome.dart';

class TrainingScreen extends StatelessWidget {
  const TrainingScreen({
    required this.onNavigate,
    this.isChessnutClockDevice = false,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final bool isChessnutClockDevice;

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      children: (context, spec) {
        final canSplit = spec.canSplit;
        final compactLandscape = spec.compactLandscape;
        final expandedDesktopFullscreen = !kIsWeb &&
            spec.width >= 1100 &&
            ((defaultTargetPlatform == TargetPlatform.macOS &&
                    spec.height >= 700) ||
                (defaultTargetPlatform == TargetPlatform.windows &&
                    spec.height >= 600));
        final topPanels = ResponsiveSplit(
          breakpoint: 900,
          spacing: canSplit ? 10 : spec.gutter,
          leadingFlex: 6,
          trailingFlex: 5,
          leading: _InteractiveCoursePanel(
            onTap: () => onNavigate('Courses'),
            compact: canSplit,
            expandedDesktopFullscreen: expandedDesktopFullscreen,
          ),
          trailing: _TrainingModesPanel(
            onNavigate: onNavigate,
            compact: canSplit,
            expandedDesktopFullscreen: expandedDesktopFullscreen,
            isChessnutClockDevice: isChessnutClockDevice,
          ),
        );
        final practiceFlow = _TodayPracticePanel(
          onNavigate: onNavigate,
          horizontal: canSplit,
        );
        return [
          ScreenHeader(
            title: 'Practice',
            subtitle: 'Lessons & puzzles',
            leading: IconButton.filledTonal(
              onPressed: () => onNavigate('Back'),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          SizedBox(height: spec.gutter),
          if (compactLandscape)
            SizedBox(
              height: spec.heightAfterHeader(min: 372),
              child: Column(
                children: [
                  Expanded(flex: 7, child: topPanels),
                  const SizedBox(height: 8),
                  Expanded(flex: 3, child: practiceFlow),
                ],
              ),
            )
          else ...[
            topPanels,
            SizedBox(height: canSplit ? 10 : spec.gutter),
            practiceFlow,
          ],
        ];
      },
    );
  }
}

class _InteractiveCoursePanel extends StatelessWidget {
  const _InteractiveCoursePanel({
    required this.onTap,
    this.compact = false,
    this.expandedDesktopFullscreen = false,
  });

  final VoidCallback onTap;
  final bool compact;
  final bool expandedDesktopFullscreen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = ChessnutTheme.tokensOf(context);
    final compactLandscape = isCompactLandscapeDevice(context);
    final classic = tokens.visualTheme == ChessnutVisualTheme.classic;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final panel = GlassPanel(
      key: const ValueKey('interactive-course-panel'),
      borderRadius: classic ? 10 : 18,
      padding: EdgeInsets.all(compact ? 10 : 14),
      tint: classic
          ? tokens.panelFill
          : (dark ? const Color(0xF20B1220) : const Color(0xFAFFFFFF)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _PracticeIcon(
                icon: Icons.ondemand_video_rounded,
                color: scheme.primary,
                size: compact ? 44 : 48,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Interactive Courses',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Video lessons with board checkpoints',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 12 : 14),
          Text(
            'How course lessons work',
            key: const ValueKey('course-description-heading'),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 360;
              final itemWidth = stacked
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 16) / 3;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _CourseDescriptionItem(
                      key: const ValueKey('course-value-video'),
                      icon: Icons.play_circle_rounded,
                      label: 'Watch',
                      value: 'Video',
                      color: scheme.primary,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _CourseDescriptionItem(
                      key: const ValueKey('course-value-checkpoint'),
                      icon: Icons.pause_circle_rounded,
                      label: 'Pause',
                      value: 'Checkpoint',
                      color: scheme.secondary,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: const _CourseDescriptionItem(
                      key: ValueKey('course-value-lights'),
                      icon: Icons.lightbulb_rounded,
                      label: 'Board',
                      value: 'Lights',
                      color: ChessnutTheme.green,
                    ),
                  ),
                ],
              );
            },
          ),
          SizedBox(height: compact ? 10 : 12),
          PrimaryButton(
            label: 'Open course library',
            icon: Icons.auto_stories_rounded,
            onPressed: onTap,
          ),
        ],
      ),
    );
    if (!compact || compactLandscape) return panel;
    return SizedBox(
      height: expandedDesktopFullscreen ? 320 : 268,
      child: panel,
    );
  }
}

class _TrainingModesPanel extends StatelessWidget {
  const _TrainingModesPanel({
    required this.onNavigate,
    this.compact = false,
    this.expandedDesktopFullscreen = false,
    this.isChessnutClockDevice = false,
  });

  final ValueChanged<String> onNavigate;
  final bool compact;
  final bool expandedDesktopFullscreen;
  final bool isChessnutClockDevice;

  @override
  Widget build(BuildContext context) {
    final specWidth = MediaQuery.sizeOf(context).width;
    final compactGrid = compact || specWidth < 520;
    final compactLandscape = isCompactLandscapeDevice(context);
    final screenSize = MediaQuery.sizeOf(context);
    final useAndroidGameRecordCardSize = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !isChessnutClockDevice &&
        screenSize.height > screenSize.width &&
        screenSize.shortestSide < 600;
    final useNeutralBoardAnalyzerBackground = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !isChessnutClockDevice;
    final modes = [
      _TrainingModeItem(
        key: const ValueKey('practice-mode-board-analyzer'),
        title: 'Board analyzer',
        subtitle: 'Live Stockfish board',
        icon: Icons.analytics_rounded,
        selected: true,
        selectedBackground: !useNeutralBoardAnalyzerBackground,
        onTap: () => onNavigate('BoardAnalyzer'),
      ),
      _TrainingModeItem(
        key: const ValueKey('practice-mode-puzzle-storm'),
        title: 'Puzzle storm',
        subtitle: 'Fast pattern training',
        icon: Icons.bolt_rounded,
        onTap: () => onNavigate('PuzzleStorm'),
      ),
      _TrainingModeItem(
        key: const ValueKey('practice-mode-puzzle-themes'),
        title: 'Puzzle themes',
        subtitle: 'Practice by motif',
        icon: Icons.extension_rounded,
        onTap: () => onNavigate('PuzzleThemes'),
      ),
      _TrainingModeItem(
        key: const ValueKey('practice-mode-mistake-book'),
        title: 'Mistake book',
        subtitle: 'From your games',
        icon: Icons.menu_book_rounded,
        onTap: () => onNavigate('MistakeBook'),
      ),
    ];
    final panel = GlassPanel(
      key: const ValueKey('training-modes-panel'),
      padding: useAndroidGameRecordCardSize
          ? const EdgeInsets.all(14)
          : EdgeInsets.all(compact ? 10 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.zero,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: (MediaQuery.sizeOf(context).width - 92)
                        .clamp(180.0, 520.0),
                  ),
                  child: const Text(
                    'Training modes',
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 8 : 12),
          if (compactLandscape || expandedDesktopFullscreen)
            Expanded(
              child: _TrainingModeLandscapeGrid(modes: modes),
            )
          else
            ResponsiveGrid(
              minTileWidth:
                  useAndroidGameRecordCardSize ? 120 : (compact ? 132 : 148),
              maxColumns: 2,
              spacing: useAndroidGameRecordCardSize ? 10 : (compact ? 8 : 10),
              childAspectRatio: useAndroidGameRecordCardSize
                  ? 1.08
                  : (compact ? 3.25 : (compactGrid ? 1.05 : 1.12)),
              children: [
                for (final mode in modes)
                  ActionTile(
                    key: mode.key,
                    title: mode.title,
                    subtitle: mode.subtitle,
                    icon: mode.icon,
                    selected: mode.selected,
                    selectedBackground: mode.selectedBackground,
                    onTap: mode.onTap,
                  ),
              ],
            ),
        ],
      ),
    );
    if (!compact || compactLandscape) return panel;
    return SizedBox(
      height: expandedDesktopFullscreen ? 320 : 268,
      child: panel,
    );
  }
}

class _TrainingModeItem {
  const _TrainingModeItem({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.selectedBackground = true,
  });

  final Key key;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
  final bool selectedBackground;
}

class _TrainingModeLandscapeGrid extends StatelessWidget {
  const _TrainingModeLandscapeGrid({required this.modes});

  final List<_TrainingModeItem> modes;

  @override
  Widget build(BuildContext context) {
    const spacing = 8.0;
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _TrainingModeLandscapeCard(mode: modes[0])),
              const SizedBox(width: spacing),
              Expanded(child: _TrainingModeLandscapeCard(mode: modes[1])),
            ],
          ),
        ),
        const SizedBox(height: spacing),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _TrainingModeLandscapeCard(mode: modes[2])),
              const SizedBox(width: spacing),
              Expanded(child: _TrainingModeLandscapeCard(mode: modes[3])),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrainingModeLandscapeCard extends StatelessWidget {
  const _TrainingModeLandscapeCard({required this.mode});

  final _TrainingModeItem mode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = mode.selected ? scheme.primary : scheme.secondary;
    final backgroundColor = mode.selected && mode.selectedBackground
        ? scheme.primary
        : scheme.secondary;
    final radius = BorderRadius.circular(13);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        key: mode.key,
        onTap: mode.onTap,
        borderRadius: radius,
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: backgroundColor.withValues(
              alpha: mode.selected && mode.selectedBackground ? 0.10 : 0.07,
            ),
            borderRadius: radius,
            border: Border.all(
              color: backgroundColor.withValues(
                alpha: mode.selected && mode.selectedBackground ? 0.26 : 0.16,
              ),
              width: mode.selected && mode.selectedBackground ? 1.2 : 1,
            ),
          ),
          child: Row(
            children: [
              _PracticeIcon(icon: mode.icon, color: iconColor, size: 42),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mode.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            height: 1.05,
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

class _TodayPracticePanel extends StatelessWidget {
  const _TodayPracticePanel({
    required this.onNavigate,
    this.horizontal = false,
  });

  final ValueChanged<String> onNavigate;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      key: const ValueKey('practice-flow-panel'),
      padding: horizontal
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
          : const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: horizontal
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: const [
              Expanded(
                child: Text(
                  'Practice flow',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
            ],
          ),
          SizedBox(height: horizontal ? 2 : 12),
          if (horizontal)
            SizedBox(
              height: 64,
              child: Row(
                children: [
                  Expanded(
                    child: _PracticeStep(
                      number: '1',
                      title: 'Warm up with tactics',
                      subtitle: 'Quick tactics',
                      compact: true,
                      onTap: () => onNavigate('PuzzleStorm'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PracticeStep(
                      number: '2',
                      title: 'Review one weak spot',
                      subtitle: 'Personal review',
                      compact: true,
                      onTap: () => onNavigate('MistakeBook'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PracticeStep(
                      number: '3',
                      title: 'Analyze freely',
                      subtitle: 'Free analysis',
                      compact: true,
                      onTap: () => onNavigate('BoardAnalyzer'),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            _PracticeStep(
              number: '1',
              title: 'Warm up with tactics',
              subtitle: 'Quick tactics',
              onTap: () => onNavigate('PuzzleStorm'),
            ),
            const SizedBox(height: 8),
            _PracticeStep(
              number: '2',
              title: 'Review one weak spot',
              subtitle: 'Personal review',
              onTap: () => onNavigate('MistakeBook'),
            ),
            const SizedBox(height: 8),
            _PracticeStep(
              number: '3',
              title: 'Analyze freely',
              subtitle: 'Free analysis',
              onTap: () => onNavigate('BoardAnalyzer'),
            ),
          ],
        ],
      ),
    );
  }
}

class _CourseDescriptionItem extends StatelessWidget {
  const _CourseDescriptionItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$value, $label',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeStep extends StatelessWidget {
  const _PracticeStep({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.compact = false,
  });

  final String number;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = switch (number) {
      '1' => scheme.secondary,
      '2' => ChessnutTheme.green,
      _ => scheme.primary,
    };
    final radius = BorderRadius.circular(compact ? 10 : 12);
    return Material(
      key: ValueKey('practice-flow-step-$number'),
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Ink(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
              : const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: compact ? 0.2 : 0.055),
            borderRadius: radius,
            border: Border.all(
              color: accent.withValues(alpha: compact ? 0.46 : 0.18),
              width: compact ? 1.2 : 1,
            ),
          ),
          child: compact
              ? Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            number,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                height: 1.04,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(height: 1.04),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            number,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded, color: scheme.primary),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PracticeIcon extends StatelessWidget {
  const _PracticeIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color),
    );
  }
}
