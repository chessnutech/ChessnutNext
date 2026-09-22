import '../l10n/localized_material.dart';
import 'package:flutter/services.dart';

import '../services/chessnut_endpoint_config.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_feedback.dart';
import '../widgets/chess_board.dart';

class SpectatorScreen extends StatefulWidget {
  const SpectatorScreen({
    required this.onNavigate,
    this.snapshot = const SpectatorGameSnapshot.empty(),
    this.showBoardCoordinates = false,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final SpectatorGameSnapshot snapshot;
  final bool showBoardCoordinates;

  @override
  State<SpectatorScreen> createState() => _SpectatorScreenState();
}

class SpectatorGameSnapshot {
  const SpectatorGameSnapshot({
    required this.pgn,
    required this.fen,
    required this.sanMoves,
    required this.lastMove,
    required this.whiteName,
    required this.blackName,
    required this.whiteTime,
    required this.blackTime,
    required this.whiteActive,
    required this.blackActive,
    required this.liveUrl,
  });

  const SpectatorGameSnapshot.empty()
      : pgn = '[Event "Chessnut Live"]\n\n*',
        fen = standardStartFen,
        sanMoves = const [],
        lastMove = const [],
        whiteName = 'White',
        blackName = 'Black',
        whiteTime = '--',
        blackTime = '--',
        whiteActive = false,
        blackActive = false,
        liveUrl = '';

  final String pgn;
  final String fen;
  final List<String> sanMoves;
  final List<String> lastMove;
  final String whiteName;
  final String blackName;
  final String whiteTime;
  final String blackTime;
  final bool whiteActive;
  final bool blackActive;
  final String liveUrl;

  String get resolvedLiveUrl {
    final url = liveUrl.trim();
    if (url.isNotEmpty) return url;
    return ChessnutEndpointConfig.watchUri(_SpectatorInfoCard.roomPath)
        .toString();
  }
}

class _SpectatorScreenState extends State<SpectatorScreen> {
  bool followingLive = true;
  bool flipped = false;

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final topName = flipped ? snapshot.whiteName : snapshot.blackName;
    final topTime = flipped ? snapshot.whiteTime : snapshot.blackTime;
    final topActive = flipped ? snapshot.whiteActive : snapshot.blackActive;
    final topSource = flipped ? 'White / PGN live' : 'Black / PGN live';
    final bottomName = flipped ? snapshot.blackName : snapshot.whiteName;
    final bottomTime = flipped ? snapshot.blackTime : snapshot.whiteTime;
    final bottomActive = flipped ? snapshot.blackActive : snapshot.whiteActive;
    final bottomSource = flipped ? 'Black / PGN live' : 'White / PGN live';
    return ResponsivePage(
      children: (context, spec) => [
        ScreenHeader(
          title: 'Live Game',
          subtitle: 'Live',
          leading: IconButton.filledTonal(
            onPressed: () => widget.onNavigate('Back'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          trailing: const _LiveBadge(),
        ),
        SizedBox(height: spec.gutter),
        const _SharedLinkBanner(),
        SizedBox(height: spec.gutter),
        ResponsiveSplit(
          breakpoint: 900,
          spacing: spec.gutter,
          leadingFlex: 7,
          trailingFlex: 4,
          leading: SectionColumn(
            spacing: 10,
            children: [
              _SpectatorClock(
                name: topName,
                source: topSource,
                time: topTime,
                active: topActive,
                alignRight: true,
              ),
              ResponsiveBoardFrame(
                maxSize: spec.canSplit ? 560 : 292,
                tint: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xAA050608)
                    : const Color(0xE8FFFFFF),
                builder: (size) => InteractiveChessBoard(
                  key: ValueKey('spectator-$flipped-${snapshot.fen}'),
                  size: size,
                  initialFen: snapshot.fen,
                  flipped: flipped,
                  enabledColors: const {},
                  lastMove: snapshot.lastMove,
                  showCoordinates: widget.showBoardCoordinates,
                  interactionEnabled: false,
                ),
              ),
              _SpectatorClock(
                name: bottomName,
                source: bottomSource,
                time: bottomTime,
                active: bottomActive,
              ),
            ],
          ),
          trailing: SectionColumn(
            spacing: 10,
            children: [
              _SpectatorInfoCard(
                followingLive: followingLive,
                liveUrl: snapshot.resolvedLiveUrl,
              ),
              _SpectatorMoves(
                moves: snapshot.sanMoves,
                onHistoryTap: () => setState(() => followingLive = false),
              ),
              _SpectatorActions(
                followingLive: followingLive,
                snapshot: snapshot,
                onFollowLive: () => setState(() => followingLive = true),
                onFlip: () => setState(() => flipped = !flipped),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SharedLinkBanner extends StatelessWidget {
  const _SharedLinkBanner();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: 14,
      tint: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(Icons.link_rounded,
              color: Theme.of(context).colorScheme.primary, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Watching via shared link',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record_rounded,
              size: 13, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          const Text(
            'Live',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SpectatorInfoCard extends StatelessWidget {
  const _SpectatorInfoCard({
    required this.followingLive,
    required this.liveUrl,
  });

  static const roomPath = 'watch/rapid-42';

  final bool followingLive;
  final String liveUrl;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spectator room',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 10),
          _InfoLine(
            icon: Icons.visibility_rounded,
            label: 'Mode',
            value: 'Read-only',
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          _InfoLine(
            icon: Icons.link_rounded,
            label: 'URL',
            value: _displayUrl(liveUrl),
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(height: 8),
          _InfoLine(
            icon: followingLive ? Icons.sensors_rounded : Icons.history_rounded,
            label: 'Status',
            value: followingLive ? 'Following live' : 'Reviewing history',
            color: const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }
}

class _SpectatorMoves extends StatelessWidget {
  const _SpectatorMoves({
    required this.moves,
    required this.onHistoryTap,
  });

  final List<String> moves;
  final VoidCallback onHistoryTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      borderRadius: 12,
      child: Row(
        children: [
          Icon(Icons.notes_rounded,
              size: 16, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: moves.isEmpty
                ? const Text(
                    'No moves yet',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < moves.length; i++) ...[
                          if (i.isEven)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(
                                '${(i ~/ 2) + 1}.',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: OutlinedButton(
                              onPressed: onHistoryTap,
                              child: Text(moves[i]),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SpectatorActions extends StatelessWidget {
  const _SpectatorActions({
    required this.followingLive,
    required this.snapshot,
    required this.onFollowLive,
    required this.onFlip,
  });

  final bool followingLive;
  final SpectatorGameSnapshot snapshot;
  final VoidCallback onFollowLive;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    final watchUrl = snapshot.resolvedLiveUrl;
    return SectionColumn(
      spacing: 8,
      children: [
        FilledButton.icon(
          onPressed: onFollowLive,
          icon: Icon(followingLive
              ? Icons.check_circle_rounded
              : Icons.play_arrow_rounded),
          label: const Text('Follow live'),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onFlip,
                icon: const Icon(Icons.swap_vert_rounded),
                label: const Text('Flip'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async => _copySpectatorText(
                  context,
                  snapshot.pgn,
                  'PGN copied',
                ),
                icon: const Icon(Icons.content_copy_rounded),
                label: const Text('Copy PGN'),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async => _copySpectatorText(
                  context,
                  snapshot.fen,
                  'FEN copied',
                ),
                icon: const Icon(Icons.copy_all_rounded),
                label: const Text('Copy FEN'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async => _copySpectatorText(
                  context,
                  watchUrl,
                  'URL copied',
                ),
                icon: const Icon(Icons.link_rounded),
                label: const Text('Copy URL'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _displayUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty) return value;
  return uri.host + uri.path;
}

Future<void> _copySpectatorText(
  BuildContext context,
  String value,
  String message,
) async {
  try {
    await Clipboard.setData(ClipboardData(text: value));
  } catch (_) {
    if (!context.mounted) return;
    showAppFeedback(
      context,
      'Copy failed. Please try again.',
      tone: AppFeedbackTone.error,
    );
    return;
  }
  if (!context.mounted) return;
  showAppFeedback(context, message, tone: AppFeedbackTone.success);
}

class _SpectatorClock extends StatelessWidget {
  const _SpectatorClock({
    required this.name,
    required this.source,
    required this.time,
    this.active = false,
    this.alignRight = false,
  });

  final String name;
  final String source;
  final String time;
  final bool active;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final clock = Container(
      width: 96,
      height: 47,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? primary.withValues(alpha: 0.18)
            : Colors.black.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        time,
        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
      ),
    );

    final info = Expanded(
      child: Column(
        crossAxisAlignment:
            alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(source,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );

    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderRadius: 10,
      tint: active ? primary.withValues(alpha: 0.10) : null,
      child: Row(
        children: alignRight
            ? [clock, const SizedBox(width: 10), info]
            : [info, const SizedBox(width: 10), clock],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}
