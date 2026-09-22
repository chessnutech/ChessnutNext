import 'dart:async';

import 'package:dartchess/dartchess.dart' as dc;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

import '../l10n/game_record_strings.dart';
import '../l10n/localized_material.dart';
import '../models/app_models.dart';
import '../services/analysis_report_cache_service.dart';
import 'app_chrome.dart';
import 'chess_board.dart';

enum _RecordContextAction {
  review,
  continueGame,
  copyPgn,
  refreshPgn,
  endGame,
  deleteRecord,
}

class GameRecordTile extends StatelessWidget {
  const GameRecordTile({
    required this.record,
    required this.recordKey,
    required this.onTap,
    this.continuing = false,
    this.deleting = false,
    this.refreshingPgn = false,
    this.selectionMode = false,
    this.selected = false,
    this.selectable = false,
    this.onContinue,
    this.onCopyPgn,
    this.onRefreshPgn,
    this.onDelete,
    this.onEnd,
    this.reportStatus = const GameAnalysisReportStatus(),
    this.isChessnutClockDevice = false,
    this.onSelect,
    this.footer,
    super.key,
  });

  final GameRecord record;
  final String recordKey;
  final VoidCallback onTap;
  final bool continuing;
  final bool deleting;
  final bool refreshingPgn;
  final bool selectionMode;
  final bool selected;
  final bool selectable;
  final FutureOr<void> Function()? onContinue;
  final VoidCallback? onCopyPgn;
  final FutureOr<void> Function()? onRefreshPgn;
  final VoidCallback? onDelete;
  final VoidCallback? onEnd;
  final GameAnalysisReportStatus reportStatus;
  final bool isChessnutClockDevice;
  final VoidCallback? onSelect;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final boardSize = screenSize.width < 390 ? 70.0 : 82.0;
    final portraitPhone =
        screenSize.height > screenSize.width && screenSize.shortestSide < 600;
    final showPortraitPlayerNames = !kIsWeb &&
        portraitPhone &&
        ((defaultTargetPlatform == TargetPlatform.android &&
                !isChessnutClockDevice) ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final showContinueButton = onContinue != null && !portraitPhone;
    final strings = GameRecordStrings.of(context);
    final fen = gameRecordFinalFenFromPgn(record.pgn);
    final modeLabel = strings.modeLabel(record);
    final resultLabel = strings.resultLabel(record);
    final tileContent = GlassPanel(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (selectionMode) ...[
                _RecordSelectionControl(
                  recordKey: recordKey,
                  selected: selected,
                  enabled: selectable && !deleting,
                  onTap: selectable && !deleting ? (onSelect ?? onTap) : null,
                ),
                const SizedBox(width: 10),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox.square(
                  dimension: boardSize,
                  child: record.isPgnPending
                      ? const _RecordPgnPlaceholder()
                      : ChessBoard(
                          pieces: gameRecordPiecesFromFen(fen),
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
                    if (showPortraitPlayerNames) ...[
                      Text(
                        strings.playerName('White', record.displayWhiteName),
                        key: ValueKey('game-record-white-player-$recordKey'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        strings.playerName('Black', record.displayBlackName),
                        key: ValueKey('game-record-black-player-$recordKey'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ] else
                      Text(
                        strings.playerSummary(record),
                        key: ValueKey('game-record-player-summary-$recordKey'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '$modeLabel / ${strings.timeSummary(record)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    _RecordMetaWrap(
                      items: [
                        strings.dateSummary(record),
                        strings.locationSummary(record),
                      ],
                    ),
                    if (resultLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        strings.resultSummary(resultLabel),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                    if (reportStatus.hasAny) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (reportStatus.standard)
                            const _ReportStatusChip(
                              key: ValueKey(
                                'game-record-standard-report-chip',
                              ),
                              icon: Icons.analytics_rounded,
                              label: 'Report',
                            ),
                          if (reportStatus.grandeur)
                            const _GrandeurReportStatusBadge(
                              key: ValueKey(
                                'game-record-grandeur-report-chip',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (showContinueButton) ...[
                const SizedBox(width: 10),
                _RecordTileActions(
                  continuing: continuing,
                  onContinue: onContinue,
                ),
              ],
              const SizedBox(width: 4),
              _RecordMoreButton(
                key: ValueKey('game-record-more-$recordKey'),
                enabled: !deleting && !refreshingPgn,
                onPressed: (position) => _showContextMenu(context, position),
              ),
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: 10),
            footer!,
          ],
        ],
      ),
    );
    final tile = GestureDetector(
      key: ValueKey('game-record-context-target-$recordKey'),
      behavior: HitTestBehavior.translucent,
      onLongPressStart: selectionMode
          ? null
          : (details) => _showContextMenu(
                context,
                details.globalPosition,
              ),
      onSecondaryTapUp: selectionMode
          ? null
          : (details) => _showContextMenu(
                context,
                details.globalPosition,
              ),
      child: tileContent,
    );
    return tile;
  }

  Future<void> _showContextMenu(
    BuildContext context,
    Offset globalPosition,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final strings = GameRecordStrings.of(context);
    final actions = <PopupMenuEntry<_RecordContextAction>>[
      if (!record.isInProgress)
        PopupMenuItem(
          value: _RecordContextAction.review,
          child: _RecordContextMenuItem(
            icon: Icons.analytics_rounded,
            label: strings.t('Review'),
          ),
        ),
      if (onContinue != null)
        PopupMenuItem(
          value: _RecordContextAction.continueGame,
          child: _RecordContextMenuItem(
            icon: Icons.play_arrow_rounded,
            label: strings.t('Continue'),
          ),
        ),
      if (onCopyPgn != null)
        PopupMenuItem(
          value: _RecordContextAction.copyPgn,
          child: _RecordContextMenuItem(
            icon: Icons.content_copy_rounded,
            label: strings.t('Copy PGN'),
          ),
        ),
      if (onRefreshPgn != null)
        PopupMenuItem(
          value: _RecordContextAction.refreshPgn,
          child: _RecordContextMenuItem(
            icon: Icons.refresh_rounded,
            label: strings.t('Refresh PGN'),
          ),
        ),
      if (onEnd != null)
        PopupMenuItem(
          value: _RecordContextAction.endGame,
          child: _RecordContextMenuItem(
            icon: Icons.flag_rounded,
            label: strings.t('End game'),
            destructive: true,
          ),
        ),
      if (onDelete != null)
        PopupMenuItem(
          value: _RecordContextAction.deleteRecord,
          child: _RecordContextMenuItem(
            icon: Icons.delete_outline_rounded,
            label: strings.t('Delete record'),
            destructive: true,
          ),
        ),
    ];
    if (actions.isEmpty) return;
    final selected = await showMenu<_RecordContextAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem<_RecordContextAction>(
          enabled: false,
          height: 0,
          padding: EdgeInsets.zero,
          child: SizedBox.shrink(
            key: ValueKey('game-record-context-menu'),
          ),
        ),
        ...actions,
      ],
    );
    if (selected == null) return;
    switch (selected) {
      case _RecordContextAction.review:
        onTap();
      case _RecordContextAction.continueGame:
        onContinue?.call();
      case _RecordContextAction.copyPgn:
        onCopyPgn?.call();
      case _RecordContextAction.refreshPgn:
        onRefreshPgn?.call();
      case _RecordContextAction.endGame:
        onEnd?.call();
      case _RecordContextAction.deleteRecord:
        onDelete?.call();
    }
  }
}

class _RecordContextMenuItem extends StatelessWidget {
  const _RecordContextMenuItem({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = destructive ? scheme.error : scheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _RecordPgnPlaceholder extends StatelessWidget {
  const _RecordPgnPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _RecordMoreButton extends StatelessWidget {
  const _RecordMoreButton({
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final bool enabled;
  final ValueChanged<Offset> onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 36,
      child: Tooltip(
        message: 'More actions',
        child: IconButton(
          onPressed: enabled
              ? () {
                  final box = context.findRenderObject() as RenderBox;
                  onPressed(box.localToGlobal(box.size.center(Offset.zero)));
                }
              : null,
          style: ButtonStyle(
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            minimumSize: const WidgetStatePropertyAll(Size.square(36)),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? scheme.onSurface.withValues(alpha: 0.28)
                  : scheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          icon: const Icon(Icons.more_vert_rounded, size: 22),
        ),
      ),
    );
  }
}

class _RecordMetaWrap extends StatelessWidget {
  const _RecordMetaWrap({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const SizedBox(height: 2),
          Text(
            items[index],
            softWrap: true,
            style: style,
          ),
        ],
      ],
    );
  }
}

class _RecordSelectionControl extends StatelessWidget {
  const _RecordSelectionControl({
    required this.recordKey,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String recordKey;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.outline;
    return Semantics(
      selected: selected,
      button: true,
      enabled: enabled,
      label: selected ? 'Selected record' : 'Select record',
      child: InkWell(
        key: ValueKey('game-record-select-$recordKey'),
        borderRadius: BorderRadius.circular(999),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.18)
                  : scheme.surface.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: selected ? 2 : 1.5),
            ),
            child: Icon(
              selected ? Icons.check_rounded : Icons.circle_outlined,
              size: selected ? 18 : 14,
              color: enabled ? color : scheme.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordTileActions extends StatelessWidget {
  const _RecordTileActions({
    required this.continuing,
    this.onContinue,
  });

  final bool continuing;
  final FutureOr<void> Function()? onContinue;

  @override
  Widget build(BuildContext context) {
    if (onContinue == null) {
      return const SizedBox.shrink();
    }
    final strings = GameRecordStrings.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 520;
    final buttonStyle = FilledButton.styleFrom(
      visualDensity: VisualDensity.standard,
      minimumSize: Size(narrow ? 110 : 154, narrow ? 40 : 44),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.symmetric(horizontal: narrow ? 8 : 12, vertical: 8),
      textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
    return FilledButton.icon(
      key: const ValueKey('game-record-continue'),
      onPressed: continuing ? null : () => onContinue!(),
      style: buttonStyle,
      icon: continuing
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.play_arrow_rounded, size: 18),
      label: Text(
        continuing ? strings.t('Checking') : strings.t('Continue'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ReportStatusChip extends StatelessWidget {
  const _ReportStatusChip({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.34)),
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

class _GrandeurReportStatusBadge extends StatelessWidget {
  const _GrandeurReportStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC18422);
    const deepGold = Color(0xFF7A4E12);
    return Container(
      key: const ValueKey('game-record-grandeur-premium-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF4C2),
            Color(0xFFFFD66B),
            Color(0xFFE8A82E),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: gold.withValues(alpha: 0.70)),
        boxShadow: [
          BoxShadow(
            color: gold.withValues(alpha: 0.20),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 13, color: deepGold),
          SizedBox(width: 4),
          Text(
            'Premium',
            style: TextStyle(
              color: deepGold,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

String gameRecordFinalFenFromPgn(String pgn) {
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

List<BoardPiece> gameRecordPiecesFromFen(String fen) {
  return ChessBoardState.fromFen(fen)
      .pieces
      .entries
      .map((entry) => BoardPiece(entry.key, entry.value))
      .toList(growable: false);
}
